/**
 * unitBookingJourney
 * Opportunity "Book Units" quick action. Search available units, quote an offer, or book:
 * a single unit goes through pay-to-hold (hold placed at payment initiation, resumable with a
 * live countdown), while more than one unit is booked directly with no hold. Search, offer,
 * booking fee lines and Sales Order creation reuse the existing controllers unchanged; only the
 * payment-initiation hold is our own (UnitBookingJourneyController).
 */
import { LightningElement, api } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningConfirm from 'lightning/confirm';
import MODON_PAY_URL from '@salesforce/label/c.Modon_Pay_Terminal_URL';
import ORG_URL from '@salesforce/label/c.OrgURL';

import checkExistingSalesOrder from '@salesforce/apex/UnitSearchLwcController.checkExistingSalesOrder';
import checkBookingEligibility from '@salesforce/apex/UnitSearchLwcController.checkBookingEligibility';
import getAllProjects from '@salesforce/apex/UnitSearchLwcController.getAllProjects';
import getAllBuildings from '@salesforce/apex/UnitSearchLwcController.getAllBuildings';
import getUnitDetails from '@salesforce/apex/UnitSearchLwcController.getUnitDetails';
import generateSalesOffer from '@salesforce/apex/UnitSearchLwcController.generateSalesOffer';
import sendSalesOfferPDF from '@salesforce/apex/UnitSearchLwcController.sendSalesOfferPDF';
import saveSalesOrder from '@salesforce/apex/UnitSearchLwcController.saveSalesOrder';

import syncBookingFeeLines from '@salesforce/apex/BookingFeeLineController.syncBookingFeeLines';
import getBookingFeeStatus from '@salesforce/apex/BookingFeeLineController.getBookingFeeStatus';
import previewBookingFees from '@salesforce/apex/BookingFeeLineController.previewBookingFees';

import initiatePaymentHold from '@salesforce/apex/UnitBookingJourneyController.initiatePaymentHold';
import getActiveJourneyState from '@salesforce/apex/UnitBookingJourneyController.getActiveJourneyState';
import releasePaymentHold from '@salesforce/apex/UnitBookingJourneyController.releasePaymentHold';
import getPaidUnbookedUnit from '@salesforce/apex/UnitBookingJourneyController.getPaidUnbookedUnit';
import isPaymentRequired from '@salesforce/apex/UnitBookingJourneyController.isPaymentRequired';

// Address capture (gating step) reuses the Save Address controllers as-is.
import resolveAccountId from '@salesforce/apex/AccountAddressController.resolveAccountId';
import loadAccount from '@salesforce/apex/AccountAddressController.loadAccount';
import getPicklistOptions from '@salesforce/apex/AccountAddressController.getPicklistOptions';
import saveAccount from '@salesforce/apex/AccountAddressController.saveAccount';
import searchLocation from '@salesforce/apex/GeoapifyLocationController.searchLocation';
import getAddressFromLatLong from '@salesforce/apex/GeoapifyLocationController.getAddressFromLatLong';

const ADDR_DEFAULT_COUNTRY = 'United Arab Emirates';

export default class UnitBookingJourney extends LightningElement {
    // recordId is not reliably set in connectedCallback for a quick action, so drive the initial
    // load from the setter (the same pattern as eoiHomeJourney), guarded to run once.
    _recordId;
    _initialized = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.init();
    }

    loading = false;
    blockedExisting = false;
    blockedMessage = '';
    step = 'search'; // 'search' | 'plan' | 'payment'
    actionType = '';  // 'OFFER' | 'BOOK'

    // Ongoing-payment guard: an active hold was found on open, so the search UI must never show and a
    // new booking cannot be started. _resumeUnit keeps the held unit for a resume retry.
    hasActiveHold = false;
    resumeFailed = false;
    _resumeUnit;
    _resumeSeconds = 0;

    projectOptions = [];
    selectedProject = '';
    phaseOptions = [];
    selectedPhase = '';

    units = [];        // search result rows
    planUnits = [];    // selected units carried into the plan step
    offerPreviews = []; // offer PDF previews (one per unit) for the offer branch
    customerName = '';

    // payment step (single unit)
    payUnitId;
    payUnitName;
    payUnitPrice;
    payInterior;
    payFacade;
    payPlanOptions = [];
    paySelectedPlan = '';
    payPlansById = {};
    payInstallments = [];
    feeStatus;
    remainingSeconds = 0;
    countdownLabel = '';
    _timer;
    _holdExpiryMs;
    _widthStyleEl;

    // ── address step (gating, reuses the Save Address controllers) ───────────
    needsAddress = false;
    addressSaving = false;
    isPersonAccount = false;
    isOrgAccount = false;
    resolvedAccountId;
    resolvedOpportunityId;
    villaNumber = '';
    streetWithoutVilla = '';
    _originalAccountStreet = '';
    mailingCity = '';
    mailingState = '';
    mailingCountry = ADDR_DEFAULT_COUNTRY;
    mailingPostalCode = '';
    mailingLatitude = null;
    mailingLongitude = null;
    billingSameAsMailing = true;
    billingStreet = '';
    billingCity = '';
    billingState = '';
    billingCountry = ADDR_DEFAULT_COUNTRY;
    billingPostalCode = '';
    billingLatitude = null;
    billingLongitude = null;
    nationality = '';
    uaeResident = '';
    nationalityOptions = [];
    uaeResidentOptions = [];
    unifiedNumber = '';
    mailingSearchText = '';
    mailingSearchResults = [];
    showMailingSearchResults = false;
    isMailingSearching = false;
    billingSearchText = '';
    billingSearchResults = [];
    showBillingSearchResults = false;
    isBillingSearching = false;

    // ── lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        // Fallback in case recordId was already set before this fires; init() is guarded to run once.
        this.init();
        // Recompute the countdown the instant the tab becomes visible again (e.g. returning from the Modon Pay
        // tab), so it snaps to the true remaining time rather than waiting for the next throttled tick.
        this._onVisible = () => {
            if (!document.hidden && this._timer) this.syncRemaining();
        };
        document.addEventListener('visibilitychange', this._onVisible);
    }

    async init() {
        if (this._initialized || !this._recordId) return;
        this._initialized = true;
        this.loading = true;
        try {
            const exists = await checkExistingSalesOrder({ oppId: this._recordId });
            if (exists) {
                this.blockedMessage = 'A sales order already exists for this opportunity.';
                this.blockedExisting = true;
                return;
            }
            const held = await getActiveJourneyState({ oppId: this._recordId });
            if (held && held.length) {
                // Ongoing payment: resume to the payment step and block any new booking. hasActiveHold
                // keeps the search UI hidden even if the resume itself hits a transient error.
                this.actionType = 'BOOK';
                const h = held[0];
                this._resumeUnit = { unitId: h.unitId, name: h.unitName, price: h.price, selectedPlan: h.paymentPlanId };
                this._resumeSeconds = h.remainingSeconds;
                this.hasActiveHold = true;
                await this.resumePayment();
                return;
            }
            // Money already collected on a unit but not yet booked: route the agent to complete THAT
            // unit (Book), not to start a new one.
            const paid = await getPaidUnbookedUnit({ oppId: this._recordId });
            // That unit's booking was cancelled but the fee is still collected: nothing can be booked here
            // until the money is refunded or reallocated.
            if (paid && paid.blockReason) {
                this.blockedMessage = paid.blockReason;
                this.blockedExisting = true;
                return;
            }
            if (paid && paid.unitId) {
                this.actionType = 'BOOK';
                this._resumeUnit = { unitId: paid.unitId, name: paid.unitName, price: paid.price, selectedPlan: paid.paymentPlanId };
                this._resumeSeconds = 0;
                this.hasActiveHold = true;
                await this.resumePayment();
                return;
            }
            // Booking-eligibility gate. Only reached for a fresh booking - an existing Sales Order, an active
            // hold, and a paid-unbooked unit have all returned above, so an in-flight booking is never blocked;
            // this gates only starting a new one. Rendered in the journey's own blocked card.
            const eligibility = await checkBookingEligibility({ oppId: this._recordId });
            if (eligibility && eligibility.blocked) {
                // Instead of dead-ending, capture the missing address / Nationality / Resident Status inline.
                try {
                    await this.loadAddressForm();
                    this.needsAddress = true;
                } catch (formErr) {
                    this.blockedMessage = eligibility.message;
                    this.blockedExisting = true;
                }
                return;
            }
            await this.loadProjects();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    // Enter the payment step for an active hold; never let a transient failure expose the search UI.
    async resumePayment() {
        try {
            this.resumeFailed = false;
            await this.enterPaymentStep(this._resumeUnit, this._resumeSeconds);
        } catch (e) {
            this.resumeFailed = true;
            this.toastError(e);
        }
    }

    async handleResumeRetry() {
        this.loading = true;
        try {
            await this.resumePayment();
        } finally {
            this.loading = false;
        }
    }

    async handleCancelResume() {
        this.loading = true;
        try {
            if (this._resumeUnit) await releasePaymentHold({ unitIds: [this._resumeUnit.unitId] });
            this.clearTimer();
            this.close();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    renderedCallback() {
        this.widenModal();
    }

    disconnectedCallback() {
        // Deliberately do NOT release the hold on close/refresh - that is what makes the journey
        // resumable. The hold is released only via the explicit Cancel button, or it expires.
        this.clearTimer();
        if (this._onVisible) {
            document.removeEventListener('visibilitychange', this._onVisible);
            this._onVisible = undefined;
        }
        if (this._widthStyleEl && this._widthStyleEl.parentNode) {
            this._widthStyleEl.parentNode.removeChild(this._widthStyleEl);
            this._widthStyleEl = undefined;
        }
    }

    // The quick action opens in a narrow, fixed-width modal whose container is outside this
    // component's shadow DOM, so widen it by injecting a document-level style while open.
    widenModal() {
        if (this._widthStyleEl) return;
        try {
            const style = document.createElement('style');
            style.textContent =
                '.slds-modal__container{width:90vw !important;max-width:90vw !important;}' +
                '.slds-modal__content{max-height:90vh !important;}';
            document.head.appendChild(style);
            this._widthStyleEl = style;
        } catch (e) {
            // If the environment blocks the injection, fall back to the default modal width.
        }
    }

    // ── search step ──────────────────────────────────────────────────────────
    async loadProjects() {
        const rows = await getAllProjects({ oppId: this.recordId });
        let interest = '';
        const opts = [];
        (rows || []).forEach((r) => {
            if (r.type === 'meta') {
                interest = r.projectInterest || '';
            } else {
                opts.push({ label: r.label, value: r.value });
            }
        });
        this.projectOptions = opts;
        const match = opts.find((o) => o.label === interest);
        this.selectedProject = match ? match.value : opts.length ? opts[0].value : '';
        if (this.selectedProject) {
            await this.loadBuildings();
        }
    }

    async loadBuildings() {
        this.phaseOptions = [];
        this.selectedPhase = '';
        this.units = [];
        const rows = await getAllBuildings({ projectId: this.selectedProject });
        this.phaseOptions = (rows || []).map((r) => ({ label: r.label, value: r.value }));
        // Default to the first phase and load its units so the agent lands on results.
        if (this.phaseOptions.length) {
            this.selectedPhase = this.phaseOptions[0].value;
            await this.loadUnits();
        }
    }

    async loadUnits() {
        this.units = [];
        if (!this.selectedPhase) return;
        const wrapper = await getUnitDetails({
            buildingsId: this.selectedPhase,
            oppId: this.recordId,
            unitType: null,
            qualityType: null,
            numberOfBedrooms: null,
            gfaRange: null,
            floor: null,
            unitNumber: null,
            isModonProfile: false
        });
        const list = (wrapper && wrapper.units) || [];
        this.units = list.map((u) => ({
            id: u.Id,
            name: u.Name,
            totalArea: u.TotalGrossSellableAreaGSA__c || u.TotalArea__c || u.GrossFloorAreaGFA__c,
            bedrooms: u.Number_of_Bedrooms__c,
            typology: u.Typology__c,
            price: u.TotalPrice__c,
            interior: u.Interior__c,
            facadeStyle: u.FacadeStyle__c,
            blockComment: u.BlockComment__c,
            selected: false,
            rowClass: 'ubj-row'
        }));
        if (!this.units.length) {
            this.toast('No units', 'No available units for the selected phase.', 'info');
        }
    }

    async handleProjectChange(event) {
        this.selectedProject = event.detail.value;
        this.loading = true;
        try {
            await this.loadBuildings();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    async handlePhaseChange(event) {
        this.selectedPhase = event.detail.value;
        this.loading = true;
        try {
            await this.loadUnits();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    handleUnitToggle(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;
        this.units = this.units.map((u) =>
            u.id === id
                ? { ...u, selected: checked, rowClass: checked ? 'ubj-row ubj-row_selected' : 'ubj-row' }
                : u
        );
    }

    get selectedUnits() {
        return this.units.filter((u) => u.selected);
    }

    get noSelection() {
        return this.selectedUnits.length === 0;
    }

    get selectedCount() {
        return this.selectedUnits.length;
    }

    // ── plan step ────────────────────────────────────────────────────────────
    handleGenerateOfferClick() {
        this.actionType = 'OFFER';
        this.goToPlan();
    }

    handleProceedBookClick() {
        this.actionType = 'BOOK';
        this.goToPlan();
    }

    async goToPlan() {
        this.loading = true;
        try {
            const selected = this.selectedUnits;
            const built = [];
            for (const u of selected) {
                // eslint-disable-next-line no-await-in-loop
                const offer = await generateSalesOffer({ selectedUnitId: u.id, isModonEgyptProfile: false });
                const pd = (offer && offer.unitPaymentDetailObj) || {};
                const plansById = this.buildPlansById(pd, u.price);
                const selectedPlan = pd.selectedPayment || '';
                // Fees are collected only in the single-unit pay-to-hold flow.
                // eslint-disable-next-line no-await-in-loop
                const fees =
                    this.actionType === 'BOOK' && selected.length === 1
                        ? await this.fetchFees(u.id, selectedPlan, u.price)
                        : {};
                built.push({
                    unitId: u.id,
                    name: u.name,
                    price: u.price,
                    interior: u.interior,
                    facadeStyle: u.facadeStyle,
                    planOptions: pd.availablePaymentPlans || [],
                    selectedPlan,
                    planLabel: this.planLabelFor(pd.availablePaymentPlans, selectedPlan),
                    plansById,
                    installments: plansById[selectedPlan] || [],
                    admFee: fees.admFee,
                    downPayment: fees.downPayment,
                    feesTotal: fees.feesTotal
                });
            }
            this.planUnits = built;
            this.step = 'plan';
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    async handlePlanChange(event) {
        const id = event.target.dataset.id;
        const value = event.detail.value;
        this.planUnits = this.planUnits.map((u) =>
            u.unitId === id
                ? {
                      ...u,
                      selectedPlan: value,
                      planLabel: this.planLabelFor(u.planOptions, value),
                      installments: (u.plansById && u.plansById[value]) || []
                  }
                : u
        );
        const changed = this.planUnits.find((u) => u.unitId === id);
        if (this.actionType === 'BOOK' && this.isSingleUnit && changed) {
            const fees = await this.fetchFees(id, value, changed.price);
            this.planUnits = this.planUnits.map((u) =>
                u.unitId === id
                    ? { ...u, admFee: fees.admFee, downPayment: fees.downPayment, feesTotal: fees.feesTotal }
                    : u
            );
        }
    }

    planLabelFor(options, value) {
        const o = (options || []).find((x) => x.value === value);
        return o ? o.label : '';
    }

    // Preview the ADM & Dari fee and Down Payment for a unit + plan (no records created).
    async fetchFees(unitId, planId, price) {
        if (!planId) return {};
        try {
            const f = await previewBookingFees({ unitId, planId, totalAmount: price });
            const admFee = f.admFee;
            const downPayment = f.downPayment;
            return { admFee, downPayment, feesTotal: (Number(admFee) || 0) + (Number(downPayment) || 0) };
        } catch (e) {
            return {};
        }
    }

    // Build a { planId: [installment rows] } map from the offer's payment plans for this unit.
    buildPlansById(pd, price) {
        const map = {};
        ((pd && pd.paymentLst) || []).forEach((p) => {
            if (p.paymentObj && p.paymentObj.Id) {
                map[p.paymentObj.Id] = this.computeInstallments(p.paymentInstallment, price);
            }
        });
        return map;
    }

    computeInstallments(installments, price) {
        return (installments || []).map((pi) => ({
            key: pi.Id,
            number: pi.MilestoneNumber__c,
            description: pi.MilestoneDescription__c,
            percent: pi.Milestone__c,
            amount: price != null && pi.Milestone__c != null ? (price * pi.Milestone__c) / 100 : null,
            date:
                pi.MilestoneDate__c ||
                (pi.MilestoneInstallment__r && pi.MilestoneInstallment__r.Milestone_Due_Date__c) ||
                null
        }));
    }

    get isSingleUnit() {
        return this.planUnits.length === 1;
    }

    get isOffer() {
        return this.actionType === 'OFFER';
    }

    get missingPlan() {
        return this.planUnits.some((u) => !u.selectedPlan);
    }

    buildSalesOrders() {
        return this.planUnits.map((u) => ({
            sobjectType: 'SalesOrder__c',
            Unit__c: u.unitId,
            PaymentPlan__c: u.selectedPlan,
            TotalAmount__c: u.price,
            FitoutPalete__c: u.interior,
            FacadeStyle__c: u.facadeStyle
        }));
    }

    // YAMM and Ras El Hekma use the older OfferDetailsPDF page; every other project uses _v1
    // (mirrors unitSearchLwc.handlePDFActive).
    get isOlderOfferProject() {
        const p = this.selectedProjectName;
        return p === 'YAMM' || p === 'Ras El Hekma, Egypt' || p === 'Ras El Hekma, Egypt(Egypt Only)';
    }

    get selectedProjectName() {
        const opt = this.projectOptions.find((o) => o.value === this.selectedProject);
        return opt ? opt.label : '';
    }

    // OrgURL may point at the core My Domain (which refuses to be iframed); convert it to the
    // Visualforce domain so the offer page can render inside the modal.
    vfBase() {
        let base = ORG_URL || '';
        try {
            const url = new URL(base);
            let host = url.hostname;
            if (host.indexOf('.sandbox.my.salesforce.com') !== -1) {
                host = host.replace('.sandbox.my.salesforce.com', '--c.sandbox.vf.force.com');
                base = url.protocol + '//' + host;
            } else if (host.indexOf('.my.salesforce.com') !== -1) {
                host = host.replace('.my.salesforce.com', '--c.vf.force.com');
                base = url.protocol + '//' + host;
            }
        } catch (e) {
            // keep OrgURL as-is if it cannot be parsed
        }
        return base;
    }

    buildOfferPreviews() {
        const base = this.vfBase();
        const older = this.isOlderOfferProject;
        const page = older ? 'OfferDetailsPDF' : 'OfferDetailsPDF_v1';
        const cust = encodeURIComponent(this.customerName || '');
        this.offerPreviews = this.planUnits.map((u) => {
            let src =
                base +
                '/apex/' +
                page +
                '?id=' +
                this.recordId +
                '&currentUnit=' +
                u.unitId +
                '&selectedPayment=' +
                u.selectedPlan +
                '&customerName=' +
                cust +
                '&unitOption=';
            if (!older) src += '&selectedDesign=&dpgLink=';
            return { unitId: u.unitId, name: u.name, src };
        });
    }

    handlePreviewOffer() {
        if (this.missingPlan) {
            this.toast('Payment plan required', 'Select a payment plan for each unit.', 'warning');
            return;
        }
        this.buildOfferPreviews();
        this.step = 'offer';
    }

    handleCustomerNameChange(event) {
        this.customerName = event.detail.value;
        this.buildOfferPreviews();
    }

    handleBackToPlan() {
        this.step = 'plan';
    }

    async handleSendOffer() {
        if (this.missingPlan) {
            this.toast('Payment plan required', 'Select a payment plan for each unit.', 'warning');
            return;
        }
        this.loading = true;
        try {
            await Promise.all(
                this.planUnits.map((u) =>
                    sendSalesOfferPDF({
                        unitId: u.unitId,
                        unitName: u.name,
                        opportunityId: this.recordId,
                        customerName: this.customerName,
                        selectedPymnt: u.selectedPlan,
                        unitOption: ''
                    })
                )
            );
            this.toast('Offer sent', 'The offer has been emailed to the customer.', 'success');
            this.close();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    handleGoReview() {
        if (this.missingPlan) {
            this.toast('Payment plan required', 'Select a payment plan for each unit.', 'warning');
            return;
        }
        this.step = 'review';
    }

    async handleConfirmBook() {
        if (this.missingPlan) {
            this.toast('Payment plan required', 'Select a payment plan for each unit.', 'warning');
            return;
        }
        this.loading = true;
        try {
            const sos = this.buildSalesOrders();
            // Pay-first only where the Phase asks for it and the Opportunity has not opted out; otherwise a
            // single unit books directly, exactly like the multi-unit path.
            const payFirst =
                this.isSingleUnit &&
                (await isPaymentRequired({ unitId: this.planUnits[0].unitId, oppId: this.recordId }));
            if (payFirst) {
                // Single unit -> collect payment via the pay-to-hold flow.
                const sync = await syncBookingFeeLines({ salesOrderList: sos, oppId: this.recordId });
                if (sync !== 'Success') {
                    this.toast('Cannot continue', sync, 'error');
                    return;
                }
                const hold = await initiatePaymentHold({ unitId: this.planUnits[0].unitId, oppId: this.recordId });
                if (!hold || hold.status !== 'Success') {
                    this.toast('Cannot hold unit', (hold && hold.status) || 'Unable to place the hold.', 'error');
                    return;
                }
                await this.enterPaymentStep(this.planUnits[0], hold.remainingSeconds);
            } else {
                // More than one unit, or a phase that does not require payment first -> book directly.
                const res = await saveSalesOrder({
                    salesOrderList: sos,
                    oppId: this.recordId,
                    offerLinesListStr: null,
                    eoiMappingStr: null
                });
                if (res === 'Success') {
                    this.toast('Booked', 'Sales Orders created for the selected units.', 'success');
                    this.close();
                } else {
                    this.toast('Booking failed', res, 'error');
                }
            }
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    // ── payment step (single unit) ───────────────────────────────────────────
    async enterPaymentStep(unit, remainingSeconds) {
        this.payUnitId = unit.unitId;
        this.payUnitName = unit.name;
        this.payUnitPrice = unit.price;
        this.payInterior = unit.interior;
        this.payFacade = unit.facadeStyle;

        const offer = await generateSalesOffer({ selectedUnitId: unit.unitId, isModonEgyptProfile: false });
        const pd = (offer && offer.unitPaymentDetailObj) || {};
        this.payPlanOptions = pd.availablePaymentPlans || [];
        this.paySelectedPlan = unit.selectedPlan || pd.selectedPayment || '';
        this.payPlansById = this.buildPlansById(pd, this.payUnitPrice);
        this.payInstallments = this.payPlansById[this.paySelectedPlan] || [];

        await this.refreshFeeStatus();
        this.startCountdown(remainingSeconds);
        this.step = 'payment';
    }

    // The plan is fixed once the payment step is reached (fee lines are already synced to it), so it is
    // shown read-only rather than as an editable picklist.
    get paySelectedPlanLabel() {
        return this.planLabelFor(this.payPlanOptions, this.paySelectedPlan);
    }

    async refreshFeeStatus() {
        this.feeStatus = await getBookingFeeStatus({ oppId: this.recordId, unitId: this.payUnitId });
    }

    handleOpenModonPay() {
        const base = MODON_PAY_URL || '';
        window.open(base + '?op=' + this.recordId, '_blank');
    }

    async handleRefreshStatus() {
        this.loading = true;
        try {
            await this.refreshFeeStatus();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    // Release the hold and close, only when no payment has been collected (see showCancelHold). Confirmed
    // first so an accidental click does not drop the unit.
    async handleCancelHold() {
        const confirmed = await LightningConfirm.open({
            label: 'Cancel booking',
            theme: 'warning',
            variant: 'header',
            message: 'Release the hold on this unit and cancel this booking?'
        });
        if (!confirmed) return;
        this.loading = true;
        try {
            if (this.payUnitId) await releasePaymentHold({ unitIds: [this.payUnitId] });
            this.clearTimer();
            this.close();
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    get feeLines() {
        const lines = (this.feeStatus && this.feeStatus.lines) || [];
        return lines.map((l) => {
            // Show the Booking Fee Line's Fee_Status__c (the real payment lifecycle status). Status__c is
            // not advanced by the payment flow, so fall back to the paid/balance roll-up only if blank.
            const paid = Number(l.paidAmount) || 0;
            const balance = Number(l.balance);
            const fullyPaid = paid > 0 && balance <= 0;
            const statusLabel = l.feeStatus || (fullyPaid ? 'Paid' : paid > 0 ? 'Partially Paid' : 'Pending');
            return {
                ...l,
                statusLabel,
                statusClass: fullyPaid
                    ? 'ubj-badge ubj-badge_success'
                    : paid > 0
                    ? 'ubj-badge ubj-badge_warning'
                    : 'ubj-badge ubj-badge_neutral'
            };
        });
    }

    get holdExpired() {
        return this.remainingSeconds <= 0;
    }

    get isFullyPaid() {
        return !!(this.feeStatus && this.feeStatus.isFullyPaid);
    }

    // Any booking fee already collected on this unit. Even a partial payment (e.g. ADM paid, down payment
    // pending) leaves money on the unit and reserves it, so an expired hold must not tell the agent to abandon it.
    get hasAnyPayment() {
        return !!(this.feeStatus && this.feeStatus.totalPaid > 0);
    }

    // "Start a new booking" only when the hold expired and nothing at all has been collected.
    get showExpiredAlert() {
        return this.holdExpired && !this.hasAnyPayment;
    }

    // Hold expired but part of the fee is already paid: the collected payment is retained and the unit stays
    // reserved, so guide the agent to complete the balance rather than start over.
    get showPartialExpired() {
        return this.holdExpired && this.hasAnyPayment && !this.isFullyPaid;
    }

    get countdownClass() {
        return this.remainingSeconds <= 60 ? 'ubj-timer ubj-timer_danger' : 'ubj-timer';
    }

    // start Partial booking approval
    // Management approved this unit for partial-payment booking from Manage Inventory.
    get partialApproved() {
        return !!(this.feeStatus && this.feeStatus.allowPartialBooking);
    }

    // Note shown when Book is open below full payment because of a partial-booking approval.
    get showPartialApprovedNote() {
        return this.partialApproved && !this.isFullyPaid;
    }
    // end Partial booking approval

    // Book only once the fees are fully paid - unless management approved this unit for partial booking, in which
    // case whatever has been collected is enough. The collected payment, not the hold, is what secures the unit.
    get bookDisabled() {
        return !this.feeStatus || !this.paySelectedPlan || (!this.isFullyPaid && !this.partialApproved);
    }

    // Cancel is offered only before any money is collected. Once a payment exists the unit is retained
    // (see hasAnyPayment / showPartialExpired) and must never be released from here.
    get showCancelHold() {
        return !this.hasAnyPayment;
    }

    async handleBook() {
        this.loading = true;
        try {
            const so = {
                sobjectType: 'SalesOrder__c',
                Unit__c: this.payUnitId,
                PaymentPlan__c: this.paySelectedPlan,
                TotalAmount__c: this.payUnitPrice,
                FitoutPalete__c: this.payInterior,
                FacadeStyle__c: this.payFacade
            };
            const res = await saveSalesOrder({
                salesOrderList: [so],
                oppId: this.recordId,
                offerLinesListStr: null,
                eoiMappingStr: null
            });
            if (res === 'Success') {
                this.clearTimer();
                // The Sales Order now reserves the unit, so the hold has done its job. Clear it - a stale
                // hold would make the journey resume onto this unit if the booking is later cancelled.
                try {
                    await releasePaymentHold({ unitIds: [this.payUnitId] });
                } catch (e) {
                    // Booking already succeeded; an uncleared hold expires on its own.
                }
                this.toast('Booked', 'Sales Order created for ' + this.payUnitName + '.', 'success');
                this.close();
            } else {
                this.toast('Booking failed', res, 'error');
            }
        } catch (e) {
            this.toastError(e);
        } finally {
            this.loading = false;
        }
    }

    // ── navigation ───────────────────────────────────────────────────────────
    handleBackToSearch() {
        // Only reachable before a hold is placed, so nothing to release.
        this.step = 'search';
        this.planUnits = [];
        this.actionType = '';
    }

    handleClose() {
        this.close();
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ── address step ─────────────────────────────────────────────────────────
    // Ported from the Save Address action (gelocationlwc); reuses AccountAddressController /
    // GeoapifyLocationController unchanged so the same capture happens inside the journey.
    async loadAddressForm() {
        this.resolvedAccountId = await resolveAccountId({ sourceRecordId: this._recordId });
        this.resolvedOpportunityId = this._recordId;
        const [data, picklists] = await Promise.all([
            loadAccount({ accountId: this.resolvedAccountId }),
            getPicklistOptions()
        ]);
        this.nationalityOptions = picklists.nationalityOptions || [];
        this.uaeResidentOptions = picklists.uaeResidentOptions || [];
        this.isPersonAccount = data.isPersonAccount === true;
        this.isOrgAccount = !this.isPersonAccount;
        if (this.isPersonAccount) {
            this._originalAccountStreet = data.personMailingStreet || '';
            const split = this.splitVillaFromStreet(data.personMailingStreet);
            this.villaNumber = split.villa;
            this.streetWithoutVilla = split.street;
            this.mailingCity = data.personMailingCity || '';
            this.mailingState = data.personMailingState || '';
            this.mailingCountry = data.personMailingCountry || '';
            this.mailingPostalCode = data.personMailingPostalCode || '';
            this.mailingLatitude = data.personMailingLatitude != null ? data.personMailingLatitude : null;
            this.mailingLongitude = data.personMailingLongitude != null ? data.personMailingLongitude : null;
            this.nationality = data.nationality || '';
            this.uaeResident = data.uaeResidentStatus || '';
            this.billingSameAsMailing = true;
            this.mirrorBillingFromMailing();
        } else {
            this.unifiedNumber = data.unifiedNumber || '';
            this.billingStreet = data.billingStreet || '';
            this.billingCity = data.billingCity || '';
            this.billingState = data.billingState || '';
            this.billingCountry = data.billingCountry || '';
            this.billingPostalCode = data.billingPostalCode || '';
            this.billingLatitude = data.billingLatitude != null ? data.billingLatitude : null;
            this.billingLongitude = data.billingLongitude != null ? data.billingLongitude : null;
        }
    }

    get addressSubtitle() {
        return this.isPersonAccount
            ? 'Person account, mailing and billing information'
            : 'Organization account, billing information';
    }

    get billingReadOnly() {
        return this.billingSameAsMailing;
    }

    get billingGridClass() {
        return this.billingSameAsMailing ? 'ubj-addr-grid ubj-addr-grid_muted' : 'ubj-addr-grid';
    }

    // Villa number is captured separately, then merged into the single street field on save.
    get mailingStreetDisplayValue() {
        return this.streetWithoutVilla || '';
    }

    buildMergedMailingStreet() {
        const villa = (this.villaNumber || '').trim();
        const baseStreet = (this.streetWithoutVilla || '').trim();
        return villa ? villa + (baseStreet ? ', ' + baseStreet : '') : baseStreet;
    }

    splitVillaFromStreet(savedStreet) {
        const raw = (savedStreet || '').trim();
        if (!raw) return { villa: '', street: '' };
        const commaIndex = raw.indexOf(',');
        if (commaIndex === -1) return { villa: '', street: raw };
        const firstPart = raw.substring(0, commaIndex).trim();
        const rest = raw.substring(commaIndex + 1).trim();
        const looksLikeVilla = firstPart.length > 0 && firstPart.length <= 20;
        return looksLikeVilla && rest ? { villa: firstPart, street: rest } : { villa: '', street: raw };
    }

    handleVillaNumberChange(e) { this.villaNumber = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingStreetChange(e) { this.streetWithoutVilla = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingCityChange(e) { this.mailingCity = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingStateChange(e) { this.mailingState = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingCountryChange(e) { this.mailingCountry = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingPostalChange(e) { this.mailingPostalCode = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }

    handleBillingSameToggle(event) {
        this.billingSameAsMailing = event.target.checked;
        if (this.billingSameAsMailing) this.mirrorBillingFromMailing();
        else this.clearBillingFields();
    }

    clearBillingFields() {
        this.billingStreet = '';
        this.billingCity = '';
        this.billingState = '';
        this.billingCountry = ADDR_DEFAULT_COUNTRY;
        this.billingPostalCode = '';
        this.billingLatitude = null;
        this.billingLongitude = null;
    }

    handleBillingStreetChange(e) { if (!this.billingSameAsMailing) this.billingStreet = e.target.value; }
    handleBillingCityChange(e) { if (!this.billingSameAsMailing) this.billingCity = e.target.value; }
    handleBillingStateChange(e) { if (!this.billingSameAsMailing) this.billingState = e.target.value; }
    handleBillingCountryChange(e) { if (!this.billingSameAsMailing) this.billingCountry = e.target.value; }
    handleBillingPostalChange(e) { if (!this.billingSameAsMailing) this.billingPostalCode = e.target.value; }

    mirrorBillingFromMailing() {
        this.billingStreet = this.buildMergedMailingStreet();
        this.billingCity = this.mailingCity;
        this.billingState = this.mailingState;
        this.billingCountry = this.mailingCountry;
        this.billingPostalCode = this.mailingPostalCode;
        this.billingLatitude = this.mailingLatitude;
        this.billingLongitude = this.mailingLongitude;
    }

    handleNationalityChange(e) { this.nationality = e.detail.value; }
    handleUaeResidentChange(e) { this.uaeResident = e.detail.value; }
    handleUnifiedNumberChange(e) { this.unifiedNumber = e.target.value; }

    stripEmirateSuffix(value) {
        if (!value) return '';
        return value.replace(/\s+emirate$/i, '').trim();
    }

    findYesNoOption(wantYes) {
        const list = this.uaeResidentOptions || [];
        const target = wantYes ? ['yes', 'true'] : ['no', 'false'];
        const match = list.find(
            (o) => target.includes((o.value || '').toLowerCase()) || target.includes((o.label || '').toLowerCase())
        );
        return match ? match.value : (list[0] ? list[0].value : '');
    }

    findUaeNationalityOption() {
        const list = this.nationalityOptions || [];
        const match = list.find(
            (o) => (o.label || '').toLowerCase().includes('emirates') || (o.value || '').toLowerCase() === 'ae'
        );
        return match ? match.value : '';
    }

    handleMailingSearchChange(event) {
        this.mailingSearchText = event.target.value;
        if (!this.mailingSearchText || this.mailingSearchText.length < 3) {
            this.mailingSearchResults = [];
            this.showMailingSearchResults = false;
            return;
        }
        this.isMailingSearching = true;
        searchLocation({ searchText: this.mailingSearchText })
            .then((result) => {
                this.mailingSearchResults = result || [];
                this.showMailingSearchResults = this.mailingSearchResults.length > 0;
            })
            .catch((e) => this.toastError(e))
            .finally(() => { this.isMailingSearching = false; });
    }

    async handleMailingLocationSelect(event) {
        const lat = parseFloat(event.currentTarget.dataset.lat);
        const lon = parseFloat(event.currentTarget.dataset.lon);
        this.mailingSearchText = event.currentTarget.dataset.label;
        this.mailingSearchResults = [];
        this.showMailingSearchResults = false;
        this.isMailingSearching = true;
        try {
            const geo = await getAddressFromLatLong({ latitude: lat, longitude: lon });
            const isUae = (geo.countryCode || '').toLowerCase() === 'ae';
            this.streetWithoutVilla = geo.street || geo.addressLine1 || '';
            this.mailingCity = isUae ? this.stripEmirateSuffix(geo.city) : (geo.city || '');
            this.mailingState = isUae ? this.stripEmirateSuffix(geo.state) : (geo.state || '');
            this.mailingCountry = geo.country || '';
            this.mailingPostalCode = geo.postcode || '';
            this.mailingLatitude = lat;
            this.mailingLongitude = lon;
            this.uaeResident = this.findYesNoOption(isUae);
            if (isUae) this.nationality = this.findUaeNationalityOption() || this.nationality;
            if (this.billingSameAsMailing) this.mirrorBillingFromMailing();
            this.toast('Address found', 'Mailing address filled from location. You can still edit it.', 'success');
        } catch (e) {
            this.toastError(e);
        } finally {
            this.isMailingSearching = false;
        }
    }

    handleBillingSearchChange(event) {
        this.billingSearchText = event.target.value;
        if (!this.billingSearchText || this.billingSearchText.length < 3) {
            this.billingSearchResults = [];
            this.showBillingSearchResults = false;
            return;
        }
        this.isBillingSearching = true;
        searchLocation({ searchText: this.billingSearchText })
            .then((result) => {
                this.billingSearchResults = result || [];
                this.showBillingSearchResults = this.billingSearchResults.length > 0;
            })
            .catch((e) => this.toastError(e))
            .finally(() => { this.isBillingSearching = false; });
    }

    async handleBillingLocationSelect(event) {
        const lat = parseFloat(event.currentTarget.dataset.lat);
        const lon = parseFloat(event.currentTarget.dataset.lon);
        this.billingSearchText = event.currentTarget.dataset.label;
        this.billingSearchResults = [];
        this.showBillingSearchResults = false;
        this.isBillingSearching = true;
        try {
            const geo = await getAddressFromLatLong({ latitude: lat, longitude: lon });
            const isUae = (geo.countryCode || '').toLowerCase() === 'ae';
            this.billingStreet = geo.street || geo.addressLine1 || '';
            this.billingCity = isUae ? this.stripEmirateSuffix(geo.city) : (geo.city || '');
            this.billingState = isUae ? this.stripEmirateSuffix(geo.state) : (geo.state || '');
            this.billingCountry = geo.country || '';
            this.billingPostalCode = geo.postcode || '';
            this.billingLatitude = lat;
            this.billingLongitude = lon;
            this.toast('Address found', 'Billing address filled from location. You can still edit it.', 'success');
        } catch (e) {
            this.toastError(e);
        } finally {
            this.isBillingSearching = false;
        }
    }

    async handleSaveAddress() {
        const missing = [];
        if (this.isPersonAccount) {
            if (!(this.villaNumber || '').trim()) missing.push('Villa / building number');
            if (!(this.streetWithoutVilla || '').trim() && !(this._originalAccountStreet || '').trim()) missing.push('Street');
            if (!(this.mailingCity || '').trim()) missing.push('City');
            if (!(this.mailingState || '').trim()) missing.push('State / province (mailing)');
            if (!(this.mailingCountry || '').trim()) missing.push('Country (mailing)');
            if (!(this.mailingPostalCode || '').trim()) missing.push('Postal code (mailing)');
            if (!(this.nationality || '').trim()) missing.push('Nationality');
            if (!(this.uaeResident || '').trim()) missing.push('UAE resident');
            if (!this.billingSameAsMailing) {
                if (!(this.billingStreet || '').trim()) missing.push('Billing street');
                if (!(this.billingCity || '').trim()) missing.push('Billing city');
                if (!(this.billingState || '').trim()) missing.push('Billing state / province');
                if (!(this.billingCountry || '').trim()) missing.push('Billing country');
                if (!(this.billingPostalCode || '').trim()) missing.push('Billing postal code');
            }
        } else {
            if (!(this.unifiedNumber || '').trim()) missing.push('Unified number');
            if (!(this.billingStreet || '').trim()) missing.push('Street');
            if (!(this.billingCity || '').trim()) missing.push('City');
            if (!(this.billingState || '').trim()) missing.push('State / province');
            if (!(this.billingCountry || '').trim()) missing.push('Country');
            if (!(this.billingPostalCode || '').trim()) missing.push('Postal code');
            if (!(this.nationality || '').trim()) missing.push('Nationality');
            if (!(this.uaeResident || '').trim()) missing.push('UAE resident');
        }
        if (missing.length) {
            this.toast('Required fields missing', 'Fill in: ' + missing.join(', '), 'error');
            return;
        }
        this.addressSaving = true;
        try {
            if (!this.resolvedAccountId) {
                this.resolvedAccountId = await resolveAccountId({ sourceRecordId: this._recordId });
                this.resolvedOpportunityId = this._recordId;
            }
            const payload = {
                accountId: this.resolvedAccountId,
                opportunityId: this.resolvedOpportunityId,
                isPersonAccount: this.isPersonAccount,
                personMailingStreet: this.buildMergedMailingStreet(),
                personMailingCity: this.mailingCity,
                personMailingState: this.mailingState,
                personMailingCountry: this.mailingCountry,
                personMailingPostalCode: this.mailingPostalCode,
                personMailingLatitude: this.mailingLatitude,
                personMailingLongitude: this.mailingLongitude,
                billingStreet: this.billingStreet,
                billingCity: this.billingCity,
                billingState: this.billingState,
                billingCountry: this.billingCountry,
                billingPostalCode: this.billingPostalCode,
                billingLatitude: this.billingLatitude,
                billingLongitude: this.billingLongitude,
                nationality: this.nationality,
                uaeResidentStatus: this.uaeResident,
                unifiedNumber: this.unifiedNumber
            };
            await saveAccount({ accountData: JSON.stringify(payload) });
            // Only advance once the eligibility gate actually clears.
            const eligibility = await checkBookingEligibility({ oppId: this._recordId });
            if (eligibility && eligibility.blocked) {
                this.toast('Almost there', eligibility.message, 'warning');
                return;
            }
            this.needsAddress = false;
            this.loading = true;
            try {
                await this.loadProjects();
            } finally {
                this.loading = false;
            }
        } catch (e) {
            this.toastError(e);
        } finally {
            this.addressSaving = false;
        }
    }

    handleCancelAddress() {
        this.close();
    }

    // ── countdown ────────────────────────────────────────────────────────────
    startCountdown(seconds) {
        this.clearTimer();
        // Anchor to an absolute expiry and recompute from the clock each tick, rather than decrementing a
        // counter. A backgrounded tab (e.g. while the agent is on the Modon Pay tab) throttles setInterval, so a
        // per-tick decrement would drift; recomputing from Date.now() stays correct and snaps to the true value
        // the moment the tab is visible again.
        const total = seconds > 0 ? seconds : 0;
        this._holdExpiryMs = Date.now() + total * 1000;
        this.syncRemaining();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timer = setInterval(() => this.syncRemaining(), 1000);
    }

    syncRemaining() {
        const left = this._holdExpiryMs ? Math.round((this._holdExpiryMs - Date.now()) / 1000) : 0;
        this.remainingSeconds = left > 0 ? left : 0;
        this.updateCountdownLabel();
        if (this.remainingSeconds <= 0) {
            this.clearTimer();
        }
    }

    updateCountdownLabel() {
        const m = Math.floor(this.remainingSeconds / 60);
        const s = this.remainingSeconds % 60;
        this.countdownLabel = m + ':' + (s < 10 ? '0' + s : s);
    }

    clearTimer() {
        if (this._timer) {
            clearInterval(this._timer);
            this._timer = undefined;
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────
    get currentStep() {
        if (this.needsAddress) return 'address';
        if (this.step === 'offer') return 'plan';
        if (this.step === 'review') return 'payment';
        return this.step;
    }

    get stepTitle() {
        if (this.needsAddress) return 'Customer address';
        if (this.isPayment) return 'Collect payment and book';
        if (this.isReview) return 'Review and confirm';
        if (this.isOfferPreview) return 'Offer preview';
        if (this.isPlan) return this.isOffer ? 'Generate offer' : 'Choose payment plan';
        return 'Find and select units';
    }

    get isOfferPreview() {
        return this.step === 'offer';
    }

    get isReview() {
        return this.step === 'review';
    }

    get selectedPhaseName() {
        const opt = this.phaseOptions.find((o) => o.value === this.selectedPhase);
        return opt ? opt.label : '';
    }

    get totalPrice() {
        return this.planUnits.reduce((s, u) => s + (Number(u.price) || 0), 0);
    }

    get isSearch() {
        return this.step === 'search';
    }

    // Never show the search UI while a payment is in progress - forces resume, blocks a new booking.
    get showSearch() {
        return this.isSearch && !this.hasActiveHold && !this.needsAddress;
    }

    // Blocking card shown only if resuming an active hold failed; otherwise the payment step renders.
    get showResumeFailed() {
        return this.hasActiveHold && this.resumeFailed;
    }

    get isPlan() {
        return this.step === 'plan';
    }

    get isPayment() {
        return this.step === 'payment';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    toastError(e) {
        const message = (e && e.body && e.body.message) || (e && e.message) || 'Unexpected error.';
        this.toast('Error', message, 'error');
    }
}