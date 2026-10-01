import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';
import USER_ID from '@salesforce/user/Id';

import getUnitRecords from '@salesforce/apex/MBP_ManagePropertiesController.getRecords';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import getOfferData from '@salesforce/apex/MBP_BrokerLeadcontroller.getOfferData';
import generateOfferPDF from '@salesforce/apex/MBP_BrokerLeadcontroller.generateOfferPDF';
import handleOfferAction from '@salesforce/apex/MBP_BrokerLeadcontroller.handleOfferAction';

const SMART_RESULT_LIMIT = 40;
/* While the keyboard is up, the picker sheet is capped to the visual
   viewport minus this reserve, keeping the focused control visible. */
const SHEET_TOP_RESERVE_PX = 118;
const SHEET_MIN_HEIGHT_PX = 160;
const LEADS_PERIOD = 'Current FY';
const GENERIC_SEND_OFFER_ERROR = 'Something went wrong. Please try again.';
/* The Apex response is an operational string ("Success: 1 offer email(s) sent
   to <address> for 1 unit(s)") that leaked the customer's email address into
   the toast and the inline status. Show fixed copy instead; the raw response
   is still returned and kept in `result` for debugging. */
const OFFER_SENT_TITLE = 'Offer sent successfully';
const OFFER_SENT_MESSAGE = "The offer PDF has been sent to the customer's email address.";

const UNIT_FIELDS = [
    'CreatedDate',
    'Status__c',
    'BasePrice__c',
    'TotalPrice__c',
    'Number_of_Bedrooms__c',
    'Phase__c',
    'Phase__r.Name',
    'Phase__r.Project__r.Name',
    'UnitClassification__c',
    'Typology__c',
    'View__c',
    'TotalArea__c',
    'Masterplan_URL__c'
];


/* Lead status 'Qualified' is shown as 'Converted To Opportunity'. Exact
   match on the whole trimmed value, because 'Lead Qualified' is a separate
   status that keeps its own name. Presentation only: the raw value still
   drives counting, filtering and tones. */
function leadStatusLabel(status) {
    const raw = String(status || '').trim();
    return raw.toLowerCase() === 'qualified' ? 'Converted To Opportunity' : raw;
}

export default class MbprGuidedOfferWorkspace extends LightningElement {
    @api open = false;
    @api launchToken = '';
    @api preselectedLeadId = '';
    @api preselectedUnitIds = [];

    leadRecords = [];
    unitRecords = [];
    paymentPlanOptions = [];
    rawPaymentPlans = [];
    selectedDesign = '';
    showFacadeError = false;

    offerLeadId = '';
    offerUnitId = '';
    offerPaymentPlanId = '';
    previewUrl = '';
    lastPreviewKey = '';
    pendingPreviewKey = '';
    previewRequestSequence = 0;

    leadSearch = '';
    unitSearch = '';
    paymentPlanSearch = '';
    leadActiveIndex = 0;
    unitActiveIndex = 0;
    paymentPlanActiveIndex = 0;
    activeSelector = '';
    selectorBlurTimeout;

    isLoading = false;
    isPaymentLoading = false;
    isGeneratingPdf = false;
    isSendingOffer = false;
    loadError = '';
    statusMessage = '';
    statusTone = 'info';
    isPreviewExpanded = false;
    handledLaunchToken = '';
    isCompactViewport = false;

    // Compact-viewport accordion state; desktop always renders every
    // section expanded (see the show*Body getters).
    isSelectorsSectionOpen = true;
    isScheduleSectionOpen = false;
    isPreviewSectionOpen = false;

    connectedCallback() {
        if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return;
        this._compactMedia = window.matchMedia(
            '(max-width: 767px), (min-width: 768px) and (max-width: 1199px) and (pointer: coarse), (min-width: 768px) and (max-width: 1199px) and (hover: none)'
        );
        this._boundCompactMediaChange = (event) => {
            this.isCompactViewport = Boolean(event.matches);
            this.syncSectionsWithSelection();
        };
        this.isCompactViewport = Boolean(this._compactMedia.matches);
        this.syncSectionsWithSelection();
        if (typeof this._compactMedia.addEventListener === 'function') {
            this._compactMedia.addEventListener('change', this._boundCompactMediaChange);
        } else if (typeof this._compactMedia.addListener === 'function') {
            this._compactMedia.addListener(this._boundCompactMediaChange);
        }
    }

    renderedCallback() {
        this.syncSheetViewportBinding();
        // Move the caret into the sheet's search bar right after it renders;
        // an input-to-input hand-off inside the tap's gesture keeps the
        // keyboard up. If a browser drops the transfer, the sheet bar still
        // echoes the typed text through its value binding.
        if (this._sheetSearchFocusPending) {
            this._sheetSearchFocusPending = false;
            const sheetInput = this.template.querySelector('.sheet-search input');
            if (sheetInput) {
                sheetInput.focus();
                if (typeof sheetInput.select === 'function') sheetInput.select();
            }
        }
        if (!this.open || !this.launchToken || this.launchToken === this.handledLaunchToken) return;
        this.handledLaunchToken = this.launchToken;
        this.startWorkspace();
    }

    /* ============ Touch-band keyboard fit ============ */
    /* The sheet is fixed to the layout viewport, which the keyboard does not
       shrink on iOS or Chrome 108+, so the keys used to cover the lower
       results. visualViewport is the only API that sees the keyboard; its
       geometry drives two CSS vars that lift the sheet and cap its height.
       With no keyboard the vars are removed and desktop never binds. */

    syncSheetViewportBinding() {
        const shouldBind = this.isCompactViewport && Boolean(this.activeSelector);
        if (shouldBind && !this._boundSheetViewportSync) {
            if (typeof window === 'undefined' || !window.visualViewport) return;
            this._boundSheetViewportSync = () => this.syncSheetViewport();
            window.visualViewport.addEventListener('resize', this._boundSheetViewportSync);
            window.visualViewport.addEventListener('scroll', this._boundSheetViewportSync);
            this.syncSheetViewport();
        } else if (!shouldBind && this._boundSheetViewportSync) {
            this.teardownSheetViewportSync();
        }
    }

    teardownSheetViewportSync() {
        if (!this._boundSheetViewportSync) return;
        window.visualViewport.removeEventListener('resize', this._boundSheetViewportSync);
        window.visualViewport.removeEventListener('scroll', this._boundSheetViewportSync);
        this._boundSheetViewportSync = null;
        this.clearSheetViewportVars();
    }

    syncSheetViewport() {
        const viewport = window.visualViewport;
        if (!viewport) return;
        // Keyboard overlap measured from the layout viewport's bottom edge.
        const keyboardInset = Math.max(0, Math.round(window.innerHeight - viewport.height - viewport.offsetTop));
        if (!keyboardInset) {
            this.clearSheetViewportVars();
            return;
        }
        const sheetMax = Math.max(Math.round(viewport.height) - SHEET_TOP_RESERVE_PX, SHEET_MIN_HEIGHT_PX);
        const host = this.template.host;
        host.style.setProperty('--go-kb-inset', `${keyboardInset}px`);
        host.style.setProperty('--go-sheet-max', `${sheetMax}px`);
    }

    clearSheetViewportVars() {
        const host = this.template.host;
        host.style.removeProperty('--go-kb-inset');
        host.style.removeProperty('--go-sheet-max');
    }

    disconnectedCallback() {
        window.clearTimeout(this.selectorBlurTimeout);
        this.teardownSheetViewportSync();
        if (this._compactMedia && this._boundCompactMediaChange) {
            if (typeof this._compactMedia.removeEventListener === 'function') {
                this._compactMedia.removeEventListener('change', this._boundCompactMediaChange);
            } else if (typeof this._compactMedia.removeListener === 'function') {
                this._compactMedia.removeListener(this._boundCompactMediaChange);
            }
        }
    }

    get showOfferFooter() {
        // The picker bottom sheet owns the bottom edge on compact viewports;
        // un-rendering the slotted footer collapses the modal footer bar so
        // it can never paint over the sheet's options (same deterministic
        // pattern as the units filter sheet fix in mbpr_homeGateway).
        return !(this.isCompactViewport && this.activeSelector);
    }

    get showSelectorsBody() {
        return !this.isCompactViewport || this.isSelectorsSectionOpen;
    }

    get showScheduleBody() {
        return !this.isCompactViewport || this.isScheduleSectionOpen;
    }

    get showPreviewBody() {
        return !this.isCompactViewport || this.isPreviewSectionOpen;
    }

    get showContextUnitsBody() {
        return this.showContextUnits && this.showSelectorsBody;
    }

    get showFacadeBody() {
        return this.isAlNaseemUnit && this.showSelectorsBody;
    }

    get selectorsSectionSummary() {
        if (this.offerSelectionKey) {
            return [this.summaryLeadName, this.summaryUnitName, this.summaryPaymentName]
                .filter(Boolean)
                .join(' · ');
        }
        return 'Choose lead, unit, and payment plan';
    }

    get scheduleSectionSummary() {
        return this.selectedPlanName || '';
    }

    get previewSectionSummary() {
        return this.previewStateLabel;
    }

    handleSectionToggle(event) {
        const section = event.currentTarget.dataset.section;
        if (section === 'selectors') {
            this.isSelectorsSectionOpen = !this.isSelectorsSectionOpen;
        } else if (section === 'schedule') {
            this.isScheduleSectionOpen = !this.isScheduleSectionOpen;
        } else if (section === 'preview') {
            this.isPreviewSectionOpen = !this.isPreviewSectionOpen;
        }
    }

    syncSectionsWithSelection() {
        // Auto-flow on compact viewports only: completing the selection
        // collapses the input sections and opens the preview; clearing or
        // changing anything reopens the inputs. Manual toggles apply in
        // between (this runs only on selection mutations / band entry).
        if (!this.isCompactViewport) return;
        if (this.offerSelectionKey) {
            this.isSelectorsSectionOpen = false;
            this.isScheduleSectionOpen = false;
            this.isPreviewSectionOpen = true;
        } else {
            this.isSelectorsSectionOpen = true;
            this.isPreviewSectionOpen = false;
        }
    }

    async startWorkspace() {
        this.resetWorkspaceState();
        this.isLoading = true;
        this.loadError = '';

        try {
            await Promise.all([this.loadLeads(), this.loadUnits()]);
            await this.applyLaunchContext();
        } catch (error) {
            this.loadError = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    resetWorkspaceState() {
        this.isSelectorsSectionOpen = true;
        this.isScheduleSectionOpen = false;
        this.isPreviewSectionOpen = false;
        this.offerLeadId = '';
        this.offerUnitId = '';
        this.offerPaymentPlanId = '';
        this.paymentPlanOptions = [];
        this.rawPaymentPlans = [];
        this.selectedDesign = '';
        this.showFacadeError = false;
        this.previewUrl = '';
        this.lastPreviewKey = '';
        this.pendingPreviewKey = '';
        this.previewRequestSequence = 0;
        this.activeSelector = '';
        this.leadSearch = '';
        this.unitSearch = '';
        this.paymentPlanSearch = '';
        this.leadActiveIndex = 0;
        this.unitActiveIndex = 0;
        this.paymentPlanActiveIndex = 0;
        this.statusMessage = '';
        this.statusTone = 'info';
        this.isPreviewExpanded = false;
    }

    async loadLeads() {
        this.leadRecords = (await getFilteredLeads({
            userId: USER_ID,
            filterType: LEADS_PERIOD,
            startDate: null,
            endDate: null
        })) || [];
    }

    async loadUnits() {
        this.unitRecords = (await getUnitRecords({
            objectName: 'Unit__c',
            filters: {},
            fields: UNIT_FIELDS
        })) || [];
    }

    async applyLaunchContext() {
        if (this.preselectedLeadId && this.leadRows.some((lead) => lead.id === this.preselectedLeadId)) {
            this.offerLeadId = this.preselectedLeadId;
        }

        const validUnitIds = this.normalizedPreselectedUnitIds.filter((unitId) =>
            this.unitRows.some((unit) => unit.id === unitId)
        );
        if (validUnitIds.length) {
            this.offerUnitId = validUnitIds[0];
            await this.loadPaymentPlans();
        }

        this.maybeAutoGeneratePreview();
    }

    get normalizedPreselectedUnitIds() {
        if (!Array.isArray(this.preselectedUnitIds)) return [];
        return [...new Set(this.preselectedUnitIds.filter(Boolean))];
    }

    get leadRows() {
        return this.leadRecords.map((lead, index) => {
            const name = this.getLeadName(lead);
            const project = lead.Project || lead.ProjectInterest || '';
            const status = lead.Status || 'New';
            const isMasked = this.isMaskedValue(lead.Email) || this.isMaskedValue(lead.Mobile);
            const isRetired = this.isRetiredStatus(status);
            return {
                ...lead,
                id: lead.Id,
                key: lead.Id || `lead-${index}`,
                name,
                projectLabel: project || 'Not specified',
                unitTypeLabel: lead.UnitType || 'Not specified',
                statusLabel: leadStatusLabel(status),
                isRetired,
                contactLabel:
                    [
                        lead.Email ? `Email ${lead.Email}` : '',
                        lead.Mobile ? `Phone ${lead.Mobile}` : ''
                    ]
                        .filter(Boolean)
                        .join('  ·  ') || 'Restricted',
                isMasked
            };
        });
    }

    get unitRows() {
        const contextSet = new Set(this.normalizedPreselectedUnitIds);
        return this.unitRecords
            .map((unit, index) => {
                const price = unit.TotalPrice__c != null ? unit.TotalPrice__c : unit.BasePrice__c;
                return {
                    id: unit.Id,
                    key: unit.Id || `unit-${index}`,
                    name: unit.Name || 'Unit',
                    phaseId: unit.Phase__c || '',
                    phaseLabel: unit.Phase__r?.Name || 'Project',
                    projectLabel: unit.Phase__r?.Project__r?.Name || unit.Phase__r?.Name || 'Project',
                    statusLabel: unit.Status__c || 'Available',
                    typeLabel: unit.UnitClassification__c || unit.Typology__c || 'Unit',
                    bedroomsLabel: this.formatBedrooms(unit.Number_of_Bedrooms__c),
                    priceLabel: this.formatCurrency(price),
                    priceValue: Number(price) || 0,
                    tourUrl: this.normalizeTourUrl(unit.Masterplan_URL__c),
                    isContextUnit: contextSet.has(unit.Id)
                };
            })
            .sort((a, b) => {
                if (a.isContextUnit !== b.isContextUnit) return a.isContextUnit ? -1 : 1;
                return a.name.localeCompare(b.name);
            });
    }

    get selectedLead() {
        return this.leadRows.find((lead) => lead.id === this.offerLeadId) || null;
    }

    get selectedUnit() {
        return this.unitRows.find((unit) => unit.id === this.offerUnitId) || null;
    }

    get selectedPaymentPlan() {
        return this.paymentPlanOptions.find((option) => option.value === this.offerPaymentPlanId) || null;
    }

    get showContextUnits() {
        return this.contextUnitChips.length > 1;
    }

    get contextUnitChips() {
        return this.normalizedPreselectedUnitIds
            .map((id) => this.unitRows.find((unit) => unit.id === id))
            .filter(Boolean)
            .map((unit) => ({
                ...unit,
                className: unit.id === this.offerUnitId ? 'context-unit context-unit--active' : 'context-unit'
            }));
    }

    get pathSteps() {
        const steps = [
            {
                key: 'lead',
                title: 'Customer',
                detail: this.selectedLead?.name || 'Select customer',
                done: Boolean(this.offerLeadId),
                active: !this.offerLeadId
            },
            {
                key: 'unit',
                title: 'Unit',
                detail: this.selectedUnit?.name || 'Select unit',
                done: Boolean(this.offerUnitId),
                active: Boolean(this.offerLeadId) && !this.offerUnitId
            },
            {
                key: 'plan',
                title: 'Payment',
                detail: this.selectedPaymentPlan?.label || 'Select payment plan',
                done: Boolean(this.offerPaymentPlanId),
                active: Boolean(this.offerLeadId && this.offerUnitId) && !this.offerPaymentPlanId
            },
            {
                key: 'pdf',
                title: 'Review',
                detail: this.hasPreview ? 'Ready to send' : 'Review before sending',
                done: this.hasPreview,
                active: Boolean(this.offerSelectionKey) && !this.hasPreview
            }
        ];

        return steps.map((step, index) => ({
            ...step,
            marker: step.done ? '✓' : String(index + 1),
            className: [
                'offer-path__step',
                step.done ? 'offer-path__step--done' : '',
                step.active ? 'offer-path__step--active' : ''
            ]
                .filter(Boolean)
                .join(' ')
        }));
    }

    get pathProgressStyle() {
        const completed = [this.offerLeadId, this.offerUnitId, this.offerPaymentPlanId, this.hasPreview].filter(Boolean).length;
        return `width: ${(completed / 4) * 100}%`;
    }

    get isLeadSelectorOpen() {
        return this.activeSelector === 'lead';
    }

    get isUnitSelectorOpen() {
        return this.activeSelector === 'unit';
    }

    get isPaymentSelectorOpen() {
        return this.activeSelector === 'paymentPlan';
    }

    get hasLeadSelection() {
        return Boolean(this.offerLeadId);
    }

    get hasUnitSelection() {
        return Boolean(this.offerUnitId);
    }

    get hasPaymentSelection() {
        return Boolean(this.offerPaymentPlanId);
    }

    get leadSelectorClass() {
        return this.getSelectorClass('lead');
    }

    get unitSelectorClass() {
        return this.getSelectorClass('unit');
    }

    get paymentSelectorClass() {
        return this.getSelectorClass('paymentPlan', this.isPaymentSelectorDisabled);
    }

    get isPaymentSelectorDisabled() {
        return !this.offerUnitId || this.isPaymentLoading || !this.paymentPlanOptions.length;
    }

    get leadInputValue() {
        return this.isLeadSelectorOpen ? this.leadSearch : this.getSelectedLabel('lead');
    }

    get unitInputValue() {
        return this.isUnitSelectorOpen ? this.unitSearch : this.getSelectedLabel('unit');
    }

    get paymentInputValue() {
        return this.isPaymentSelectorOpen ? this.paymentPlanSearch : this.getSelectedLabel('paymentPlan');
    }

    get leadPlaceholder() {
        return this.offerLeadId ? 'Search to change lead' : 'Search by name, email, mobile, or project';
    }

    get unitPlaceholder() {
        return this.offerUnitId ? 'Search to change unit' : 'Search by unit, project, type, bedrooms, or price';
    }

    get paymentPlaceholder() {
        if (!this.offerUnitId) return 'Select a unit first';
        if (this.isPaymentLoading) return 'Loading payment plans...';
        if (!this.paymentPlanOptions.length) return 'No payment plans available';
        return this.offerPaymentPlanId ? 'Search to change payment plan' : 'Search payment plans';
    }

    get filteredLeadOptions() {
        return this.getFilteredOptions('lead');
    }

    get filteredUnitOptions() {
        return this.getFilteredOptions('unit');
    }

    get filteredPaymentOptions() {
        return this.getFilteredOptions('paymentPlan');
    }

    get hasFilteredLeadOptions() {
        return this.filteredLeadOptions.length > 0;
    }

    get hasFilteredUnitOptions() {
        return this.filteredUnitOptions.length > 0;
    }

    get hasFilteredPaymentOptions() {
        return this.filteredPaymentOptions.length > 0;
    }

    get leadNoResultsMessage() {
        return this.leadSearch?.trim() ? 'No leads match your search.' : 'No available lead records found.';
    }

    get unitNoResultsMessage() {
        return this.unitSearch?.trim() ? 'No units match your search.' : 'No units available.';
    }

    get paymentNoResultsMessage() {
        if (!this.offerUnitId) return 'Select a unit to load payment plans.';
        if (this.isPaymentLoading) return 'Loading payment plans...';
        return this.paymentPlanSearch?.trim() ? 'No payment plans match your search.' : 'No payment plans returned for this unit.';
    }

    get showLeadLimitNote() {
        return this.countMatches('lead') > SMART_RESULT_LIMIT;
    }

    get showUnitLimitNote() {
        return this.countMatches('unit') > SMART_RESULT_LIMIT;
    }

    get showPaymentLimitNote() {
        return this.countMatches('paymentPlan') > SMART_RESULT_LIMIT;
    }

    get summaryLeadName() {
        return this.selectedLead?.name || 'Select lead';
    }

    get summaryUnitName() {
        return this.selectedUnit ? `${this.selectedUnit.name} · ${this.selectedUnit.projectLabel}` : 'Select unit';
    }

    get summaryPaymentName() {
        return this.selectedPaymentPlan?.label || 'Select payment plan';
    }

    get hasPreview() {
        return Boolean(this.previewUrl);
    }

    get previewTitle() {
        return this.hasPreview ? 'Customer offer PDF' : 'PDF will appear here';
    }

    get previewStateLabel() {
        if (this.isGeneratingPdf) return 'Generating';
        if (this.isSendingOffer) return 'Sending';
        if (this.hasPreview) return 'PDF ready';
        if (!this.offerSelectionKey) return 'Draft';
        return 'Ready';
    }

    get previewStateClass() {
        const classes = ['pdf-panel__state'];
        if (this.isGeneratingPdf || this.isSendingOffer) classes.push('pdf-panel__state--working');
        else if (this.hasPreview) classes.push('pdf-panel__state--ready');
        else classes.push('pdf-panel__state--draft');
        return classes.join(' ');
    }

    get previewDocumentClass() {
        const classes = ['pdf-panel__document'];
        if (this.isGeneratingPdf) classes.push('pdf-panel__document--working');
        if (this.hasPreview) classes.push('pdf-panel__document--ready');
        // Class-based collapse (not lwc:if) so the PDF iframe survives a
        // collapse/expand cycle without refetching the document.
        if (!this.showPreviewBody) classes.push('pdf-panel__document--collapsed');
        return classes.join(' ');
    }

    get previewIframeTitle() {
        const leadName = this.selectedLead?.name || 'selected lead';
        const unitName = this.selectedUnit?.name || 'selected unit';
        return `${leadName} - ${unitName}`;
    }

    get previewEmptyTitle() {
        if (!this.offerLeadId) return 'Select a lead';
        if (!this.offerUnitId) return 'Select a unit';
        if (!this.offerPaymentPlanId) return 'Select a payment plan';
        return 'Generate PDF preview';
    }

    get previewEmptyMessage() {
        if (this.isFacadeMissing) return 'Select a Facade Style for this Al Naseem unit to continue.';
        if (!this.offerSelectionKey) return 'Complete the required fields to generate the customer-facing offer PDF.';
        return 'The PDF will generate automatically. Use Generate PDF if it does not appear.';
    }

    get offerSelectionKey() {
        if (!this.offerLeadId || !this.offerUnitId || !this.offerPaymentPlanId) return '';
        if (this.isFacadeMissing) return '';
        return `${this.offerLeadId}|${this.offerUnitId}|${this.offerPaymentPlanId}|${this.designForPayload}`;
    }

    /* ---------------------------------------------------------------- */
    /* Al Naseem facade - legacy contract: label "Facade Style",        */
    /* options South California / Contemporary, required before the     */
    /* offer generates; other projects send "Not Applicable".           */
    /* ---------------------------------------------------------------- */

    get isAlNaseemUnit() {
        const project = (this.selectedUnit?.projectLabel || '').toLowerCase();
        return project.includes('al naseem');
    }

    get facadeOptions() {
        return [
            { label: 'South California', value: 'South California' },
            { label: 'Contemporary', value: 'Contemporary' }
        ].map((option) => ({ ...option, isSelected: option.value === this.selectedDesign }));
    }

    get isFacadeMissing() {
        return this.isAlNaseemUnit && !(this.selectedDesign || '').trim();
    }

    get designForPayload() {
        return this.isAlNaseemUnit ? this.selectedDesign : 'Not Applicable';
    }

    handleFacadeChange(event) {
        this.selectedDesign = event.target.value || '';
        this.showFacadeError = false;
        this.resetPreviewState();
        this.clearStatusMessage();
        this.maybeAutoGeneratePreview();
    }

    /* ---------------------------------------------------------------- */
    /* Installment schedule - same data the legacy offer step showed:   */
    /* the plan's Payment_Installments__r with amounts computed from the  */
    /* unit price (unitPrice * Milestone__c / 100).                     */
    /* ---------------------------------------------------------------- */

    get selectedRawPlan() {
        return this.rawPaymentPlans.find((plan) => plan.Id === this.offerPaymentPlanId) || null;
    }

    get showInstallments() {
        return Boolean(this.offerPaymentPlanId) && !this.isPaymentLoading;
    }

    get installmentRows() {
        const plan = this.selectedRawPlan;
        const unitPrice = this.selectedUnit?.priceValue || 0;
        const rows = (plan && plan.Payment_Installments__r) || [];
        return rows.map((inst, index) => {
            const percent = inst.Milestone__c || 0;
            return {
                id: inst.Id || `inst-${index}`,
                number: inst.MilestoneNumber__c || index + 1,
                milestone: inst.MilestoneDescription__c || 'Milestone Payment',
                percentLabel: `${percent}%`,
                amount: (unitPrice * percent) / 100,
                date: inst.MilestoneDate__c
            };
        });
    }

    get hasInstallments() {
        return this.installmentRows.length > 0;
    }

    get selectedPlanName() {
        const option = this.paymentPlanOptions.find((candidate) => candidate.value === this.offerPaymentPlanId);
        return option ? option.label : '';
    }

    get isBusy() {
        return this.isLoading || this.isPaymentLoading || this.isGeneratingPdf || this.isSendingOffer;
    }

    get isGenerateDisabled() {
        return this.isLoading || this.isPaymentLoading || this.isGeneratingPdf || this.isSendingOffer || !this.offerSelectionKey;
    }

    get isSendDisabled() {
        return this.isBusy || !this.offerSelectionKey || !this.hasPreview;
    }

    get generateButtonLabel() {
        if (this.isGeneratingPdf) return 'Generating...';
        return this.hasPreview ? 'Refresh PDF' : 'Generate PDF';
    }

    get sendButtonLabel() {
        return this.isSendingOffer ? 'Sending offer...' : 'Send offer';
    }

    get statusMessageClass() {
        return ['form-message', `form-message--${this.statusTone || 'info'}`].join(' ');
    }

    getSelectorClass(field, disabled = false) {
        const classes = ['smart-select'];
        if (this.activeSelector === field) classes.push('smart-select--open');
        if (disabled) classes.push('smart-select--disabled');
        if (this.getSelectedValue(field)) classes.push('smart-select--selected');
        return classes.join(' ');
    }

    getSelectedValue(field) {
        if (field === 'lead') return this.offerLeadId;
        if (field === 'unit') return this.offerUnitId;
        if (field === 'paymentPlan') return this.offerPaymentPlanId;
        return '';
    }

    getSelectedLabel(field) {
        if (field === 'lead') return this.selectedLead?.name || '';
        if (field === 'unit') return this.selectedUnit?.name || '';
        if (field === 'paymentPlan') return this.selectedPaymentPlan?.label || '';
        return '';
    }

    getSmartSearch(field) {
        if (field === 'lead') return this.leadSearch;
        if (field === 'unit') return this.unitSearch;
        if (field === 'paymentPlan') return this.paymentPlanSearch;
        return '';
    }

    setSmartSearch(field, value) {
        const normalizedValue = value || '';
        if (field === 'lead') {
            this.leadSearch = normalizedValue;
            this.leadActiveIndex = 0;
        } else if (field === 'unit') {
            this.unitSearch = normalizedValue;
            this.unitActiveIndex = 0;
        } else if (field === 'paymentPlan') {
            this.paymentPlanSearch = normalizedValue;
            this.paymentPlanActiveIndex = 0;
        }
    }

    getActiveIndex(field) {
        if (field === 'lead') return this.leadActiveIndex;
        if (field === 'unit') return this.unitActiveIndex;
        if (field === 'paymentPlan') return this.paymentPlanActiveIndex;
        return 0;
    }

    setActiveIndex(field, value) {
        const safeValue = Math.max(Number(value) || 0, 0);
        if (field === 'lead') this.leadActiveIndex = safeValue;
        else if (field === 'unit') this.unitActiveIndex = safeValue;
        else if (field === 'paymentPlan') this.paymentPlanActiveIndex = safeValue;
    }

    isRetiredStatus(status) {
        return String(status || '')
            .toLowerCase()
            .includes('retired');
    }

    getBaseOptions(field) {
        if (field === 'lead') {
            return this.leadRows
                /* Retired leads are not offerable. Filtered from the searchable
                   list only, so an already-selected lead still displays. */
                .filter((lead) => !lead.isMasked && !lead.isRetired)
                .map((lead) => ({
                    value: lead.id,
                    title: lead.name,
                    meta: lead.projectLabel,
                    detail: lead.contactLabel,
                    badge: lead.statusLabel,
                    searchText: [lead.name, lead.projectLabel, lead.unitTypeLabel, lead.contactLabel, lead.statusLabel, lead.LeadNumber].join(' ')
                }));
        }

        if (field === 'unit') {
            return this.unitRows.map((unit) => ({
                value: unit.id,
                title: unit.name,
                meta: `${unit.projectLabel} · ${unit.typeLabel} · ${unit.bedroomsLabel}`,
                detail: unit.priceLabel,
                badge: unit.statusLabel,
                searchText: [unit.name, unit.projectLabel, unit.phaseLabel, unit.typeLabel, unit.bedroomsLabel, unit.priceLabel, unit.statusLabel].join(' ')
            }));
        }

        if (field === 'paymentPlan') {
            return this.paymentPlanOptions.map((option) => ({
                value: option.value,
                title: option.label,
                meta: this.selectedUnit?.name || 'Selected unit',
                detail: this.selectedUnit?.projectLabel || 'Payment plan',
                badge: 'Plan',
                searchText: [option.label, this.selectedUnit?.name, this.selectedUnit?.projectLabel].join(' ')
            }));
        }

        return [];
    }

    getFilteredOptions(field) {
        const selectedValue = this.getSelectedValue(field);
        const activeIndex = this.getActiveIndex(field);
        return this.filterOptions(field)
            .slice(0, SMART_RESULT_LIMIT)
            .map((option, index) => {
                const classes = ['smart-option'];
                if (option.value === selectedValue) classes.push('smart-option--selected');
                if (index === activeIndex) classes.push('smart-option--active');
                return {
                    ...option,
                    key: `${field}-${option.value}`,
                    index,
                    isSelected: option.value === selectedValue,
                    className: classes.join(' ')
                };
            });
    }

    filterOptions(field) {
        const query = this.normalizeSearch(this.getSmartSearch(field));
        const tokens = query ? query.split(/\s+/).filter(Boolean) : [];
        return this.getBaseOptions(field).filter((option) => {
            if (!tokens.length) return true;
            const haystack = this.normalizeSearch(option.searchText);
            return tokens.every((token) => haystack.includes(token));
        });
    }

    countMatches(field) {
        return this.filterOptions(field).length;
    }

    normalizeSearch(value) {
        return (value || '').toString().trim().toLowerCase();
    }

    handleSmartFocus(event) {
        const field = event.currentTarget.dataset.field;
        if (!field || (field === 'paymentPlan' && this.isPaymentSelectorDisabled)) return;
        window.clearTimeout(this.selectorBlurTimeout);
        this.activeSelector = field;
        this.setSmartSearch(field, this.getSelectedLabel(field));
        this.setActiveIndex(field, this.getSelectedOptionIndex(field));
        window.requestAnimationFrame(() => {
            if (event.currentTarget && typeof event.currentTarget.select === 'function') {
                event.currentTarget.select();
            }
        });
        // Touch band: typing moves into the sheet's own search bar - the
        // page-level field can sit behind the sheet, so the caret must live
        // where the user can see it ( addendum).
        if (this.isCompactViewport) {
            this._sheetSearchFocusPending = true;
        }
    }

    /* The sheet input taking focus must cancel the page input's pending
       focusout close; the hand-off stays within the wrapper. */
    handleSheetSearchFocus() {
        window.clearTimeout(this.selectorBlurTimeout);
    }

    handleSmartInput(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;
        this.activeSelector = field;
        this.setSmartSearch(field, event.target.value || '');
    }

    handleSmartKeydown(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;

        if (event.key === 'Escape') {
            event.preventDefault();
            // Keep the Escape inside the picker: without this it bubbles to
            // the workspace modal's keydown and closes the whole workspace.
            event.stopPropagation();
            this.closeSelector(field);
            return;
        }

        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp' && event.key !== 'Enter') return;

        const options = this.getFilteredOptions(field);
        if (!options.length) return;

        if (event.key === 'Enter') {
            event.preventDefault();
            const selectedOption = options[this.getActiveIndex(field)] || options[0];
            this.selectSmartOption(field, selectedOption.value);
            return;
        }

        event.preventDefault();
        const direction = event.key === 'ArrowDown' ? 1 : -1;
        const nextIndex = (this.getActiveIndex(field) + direction + options.length) % options.length;
        this.setActiveIndex(field, nextIndex);
    }

    handleSmartBlur(event) {
        const field = event.currentTarget.dataset.field;
        window.clearTimeout(this.selectorBlurTimeout);
        this.selectorBlurTimeout = window.setTimeout(() => {
            if (!field || this.activeSelector !== field) return;
            this.closeSelector(field);
        }, 120);
    }

    handleSmartOptionMouseDown(event) {
        event.preventDefault();
        const field = event.currentTarget.dataset.field;
        const value = event.currentTarget.dataset.value;
        if (!field || !value) return;
        this.selectSmartOption(field, value);
    }

    handleSmartClear(event) {
        event.preventDefault();
        event.stopPropagation();
        const field = event.currentTarget.dataset.field;
        if (!field) return;
        this.clearSmartSelection(field);
    }

    handleContextUnit(event) {
        const unitId = event.currentTarget.dataset.id;
        if (unitId) {
            this.selectOfferUnit(unitId);
        }
    }

    getSelectedOptionIndex(field) {
        const selectedValue = this.getSelectedValue(field);
        if (!selectedValue) return 0;
        const index = this.filterOptions(field).findIndex((option) => option.value === selectedValue);
        return index >= 0 ? Math.min(index, SMART_RESULT_LIMIT - 1) : 0;
    }

    closeSelector(field) {
        this.activeSelector = '';
        this.setSmartSearch(field, this.getSelectedLabel(field));
    }

    async selectSmartOption(field, value) {
        this.activeSelector = '';
        this.setSmartSearch(field, '');
        if (field === 'lead') {
            this.selectOfferLead(value);
        } else if (field === 'unit') {
            await this.selectOfferUnit(value);
        } else if (field === 'paymentPlan') {
            this.selectPaymentPlan(value);
        }
    }

    async clearSmartSelection(field) {
        this.activeSelector = field;
        this.setSmartSearch(field, '');
        if (field === 'lead') {
            this.selectOfferLead('');
        } else if (field === 'unit') {
            await this.selectOfferUnit('');
        } else if (field === 'paymentPlan') {
            this.selectPaymentPlan('');
        }
    }

    selectOfferLead(value) {
        const nextValue = value || '';
        if (this.offerLeadId === nextValue) return;
        this.offerLeadId = nextValue;
        this.resetPreviewState();
        this.clearStatusMessage();
        this.maybeAutoGeneratePreview();
    }

    async selectOfferUnit(value) {
        const nextValue = value || '';
        if (this.offerUnitId === nextValue) return;
        this.offerUnitId = nextValue;
        this.offerPaymentPlanId = '';
        this.paymentPlanOptions = [];
        this.rawPaymentPlans = [];
        this.selectedDesign = '';
        this.showFacadeError = false;
        this.paymentPlanSearch = '';
        this.resetPreviewState();
        this.clearStatusMessage();
        if (this.offerUnitId) {
            await this.loadPaymentPlans();
        }
        this.maybeAutoGeneratePreview();
    }

    selectPaymentPlan(value) {
        const nextValue = value || '';
        if (this.offerPaymentPlanId === nextValue) return;
        this.offerPaymentPlanId = nextValue;
        this.resetPreviewState();
        this.clearStatusMessage();
        this.maybeAutoGeneratePreview();
    }

    async loadPaymentPlans() {
        if (!this.offerUnitId) return;
        this.isPaymentLoading = true;
        this.clearStatusMessage();
        try {
            const result = await getOfferData({
                recordId: this.offerUnitId,
                recordType: 'unit',
                unitIdsJson: JSON.stringify([this.offerUnitId]),
                startDate: null,
                endDate: null,
                filterType: LEADS_PERIOD
            });
            if (!result?.success) {
                throw new Error(result?.errorMessage || 'Offer data could not be loaded.');
            }
            const unit = this.selectedUnit;
            const plans = (result.paymentPlans || []).filter((plan) =>
                plan.Unit__c === this.offerUnitId || (unit?.phaseId && plan.Phase__c === unit.phaseId)
            );
            this.rawPaymentPlans = plans;
            this.paymentPlanOptions = plans.map((plan) => ({
                label: plan.Name || 'Payment Plan',
                value: plan.Id
            }));
            if (!this.paymentPlanOptions.length) {
                this.setStatusMessage('No payment plans returned for this unit.', 'warning');
            }
        } catch (error) {
            this.setStatusMessage(this.reduceError(error), 'error');
        } finally {
            this.isPaymentLoading = false;
        }
    }

    maybeAutoGeneratePreview() {
        this.syncSectionsWithSelection();
        const selectionKey = this.offerSelectionKey;
        if (!selectionKey || this.isBusy) return;
        if (this.previewUrl && this.lastPreviewKey === selectionKey) return;
        if (this.pendingPreviewKey === selectionKey) return;

        this.pendingPreviewKey = selectionKey;
        Promise.resolve().then(() => {
            if (this.pendingPreviewKey !== selectionKey) return;
            this.pendingPreviewKey = '';
            if (!this.open || this.offerSelectionKey !== selectionKey || this.isBusy) return;
            this.generatePreview({ force: false });
        });
    }

    async handleGeneratePdf() {
        await this.generatePreview({ force: true });
    }

    async generatePreview({ force = false } = {}) {
        const selectionKey = this.offerSelectionKey;
        if (!selectionKey || this.isGeneratingPdf || this.isSendingOffer) return;
        if (!force && this.previewUrl && this.lastPreviewKey === selectionKey) return;

        this.isGeneratingPdf = true;
        const requestSequence = this.previewRequestSequence + 1;
        this.previewRequestSequence = requestSequence;
        // The PDF panel's own state chip covers the generating/ready
        // lifecycle - the status pill is reserved for errors and warnings.
        this.clearStatusMessage();

        try {
            const url = await generateOfferPDF({
                leadId: this.offerLeadId,
                unitId: this.offerUnitId,
                paymentPlanId: this.offerPaymentPlanId,
                selectedDesign: this.designForPayload,
                unitOption: '',
                dpgLink: this.selectedUnit?.tourUrl || '',
                selectedPayment: this.offerPaymentPlanId
            });

            if (requestSequence !== this.previewRequestSequence || selectionKey !== this.offerSelectionKey) return;
            this.previewUrl = url;
            this.lastPreviewKey = selectionKey;
            this.clearStatusMessage();
        } catch (error) {
            if (requestSequence === this.previewRequestSequence && selectionKey === this.offerSelectionKey) {
                this.previewUrl = '';
                this.lastPreviewKey = '';
                this.setStatusMessage(this.reduceError(error), 'error');
            }
        } finally {
            if (requestSequence === this.previewRequestSequence) {
                this.isGeneratingPdf = false;
                if (selectionKey !== this.offerSelectionKey) {
                    this.resetPreviewState();
                    this.maybeAutoGeneratePreview();
                }
            }
        }
    }

    async handleSendOffer() {
        if (this.isSendDisabled) return;
        if (this.isFacadeMissing) {
            this.showFacadeError = true;
            this.setStatusMessage('Please select a Facade Style for Al Naseem units.', 'error');
            return;
        }
        this.isSendingOffer = true;
        this.setStatusMessage('Sending offer...', 'info');

        try {
            const result = await handleOfferAction({
                actionType: 'send',
                unitId: this.offerUnitId,
                leadId: this.offerLeadId,
                paymentPlanId: this.offerPaymentPlanId,
                selectedOptions: JSON.stringify({
                    design: this.designForPayload,
                    unitIds: [this.offerUnitId],
                    dpgLink: this.selectedUnit?.tourUrl || ''
                }),
                customerName: this.selectedLead?.name || ''
            });
            void result; // raw Apex response retained for debugging, not displayed
            this.setStatusMessage(OFFER_SENT_MESSAGE, 'success');
            this.showToast(OFFER_SENT_TITLE, OFFER_SENT_MESSAGE, 'success');
            this.dispatchEvent(
                new CustomEvent('offercomplete', {
                    detail: {
                        scope: 'offer',
                        leadId: this.offerLeadId,
                        unitId: this.offerUnitId
                    },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (error) {
            this.setStatusMessage(GENERIC_SEND_OFFER_ERROR, 'error');
        } finally {
            this.isSendingOffer = false;
        }
    }

    resetPreviewState() {
        this.previewUrl = '';
        this.lastPreviewKey = '';
        this.pendingPreviewKey = '';
        this.isPreviewExpanded = false;
    }

    openExpandedPreview() {
        if (!this.hasPreview) return;
        this.isPreviewExpanded = true;
        // Focus the overlay once it renders so Escape closes it immediately.
        window.requestAnimationFrame(() => {
            const panel = this.template.querySelector('.preview-expanded');
            if (panel && typeof panel.focus === 'function') {
                panel.focus();
            }
        });
    }

    closeExpandedPreview() {
        this.isPreviewExpanded = false;
    }

    handleExpandedPreviewKeydown(event) {
        if (event.key !== 'Escape') return;
        event.stopPropagation();
        this.closeExpandedPreview();
    }

    handleRetryLoad() {
        this.startWorkspace();
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    setStatusMessage(message, tone = 'info') {
        this.statusMessage = message || '';
        this.statusTone = tone || 'info';
    }

    clearStatusMessage() {
        this.statusMessage = '';
        this.statusTone = 'info';
    }

    showToast(title, message, variant = 'info') {
        try {
            Toast.show({ label: title, message, mode: 'dismissible', variant }, this);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title, message, mode: 'dismissible', variant }));
        }
    }

    getLeadName(lead) {
        const parts = [lead.FirstName, lead.LastName].filter(Boolean);
        return lead.Name || parts.join(' ') || lead.Company || 'Lead';
    }

    isMaskedValue(value) {
        return typeof value === 'string' && value.includes('***');
    }

    formatCurrency(amount) {
        const num = Number(amount);
        if (Number.isNaN(num)) return 'AED 0';
        return new Intl.NumberFormat('en-AE', {
            style: 'currency',
            currency: 'AED',
            maximumFractionDigits: 0
        }).format(num);
    }

    formatBedrooms(value) {
        if (value === null || value === undefined || value === '') return 'Not specified';
        const num = Number(value);
        if (Number.isNaN(num)) return String(value);
        if (num === 0) return 'Studio';
        if (num === 1) return '1 BR';
        return `${num} BR`;
    }

    normalizeHttpUrl(value) {
        if (!value || typeof value !== 'string') return '';
        const trimmed = value.trim();
        return /^https?:\/\//i.test(trimmed) ? trimmed: '';
    }

    // Masterplan / DPG plan links are rendered inside the HTTPS portal. world.modon.com
    // 301-redirects a slash-less path down to plain http
    // (https://…/abu-dhabi/hudayriyat?x → http://…/abu-dhabi/hudayriyat/?x), and the
    // browser blocks that insecure hop as mixed content - Chrome renders
    // "This content is blocked. Contact the site owner to fix the issue." Normalising the
    // path here makes the frame request the final secure URL directly.
    normalizeTourUrl(value) {
        const raw = this.normalizeHttpUrl(value);
        if (!raw) return '';
        const parts = /^(https?:)(\/\/[^/?#]+)([^?#]*)([\s\S]*)$/i.exec(raw);
        if (!parts) return raw;
        const authority = parts[2];
        const path = parts[3] || '';
        const tail = parts[4] || '';
        const securePath = path.endsWith('/') ? path : `${path}/`;
        return `https:${authority}${securePath}${tail}`;
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (Array.isArray(error?.body)) return error.body.map((item) => item.message).join(', ');

        const fieldErrors = error?.body?.output?.fieldErrors || error?.body?.fieldErrors;
        if (fieldErrors) {
            const messages = Object.keys(fieldErrors).flatMap((fieldName) =>
                (fieldErrors[fieldName] || []).map((fieldError) => fieldError.message)
            );
            if (messages.length) return messages.join(', ');
        }

        const pageErrors = error?.body?.output?.errors || error?.body?.output?.pageErrors || error?.body?.pageErrors;
        if (pageErrors?.length) return pageErrors.map((item) => item.message).join(', ');

        if (error?.body?.message) return error.body.message;
        if (error?.detail?.message) return error.detail.message;
        if (error?.message) return error.message;

        try {
            const serializedError = JSON.stringify(error);
            return serializedError && serializedError !== '{}' ? serializedError : 'Unknown error';
        } catch (serializationError) {
            return 'Unknown error';
        }
    }
}