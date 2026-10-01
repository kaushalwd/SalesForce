import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import loadAccount from '@salesforce/apex/AccountAddressController.loadAccount';
import saveAccount from '@salesforce/apex/AccountAddressController.saveAccount';
import resolveAccountId from '@salesforce/apex/AccountAddressController.resolveAccountId';
import getPicklistOptions from '@salesforce/apex/AccountAddressController.getPicklistOptions';
import searchLocation from '@salesforce/apex/GeoapifyLocationController.searchLocation';
import getAddressFromLatLong from '@salesforce/apex/GeoapifyLocationController.getAddressFromLatLong';

const DEFAULT_COUNTRY = 'United Arab Emirates';
const OPPORTUNITY_KEY_PREFIX = '006';

export default class AccountAddressForm extends LightningElement {
    @api recordId;

    pageRefRecordId;
    resolvedAccountId;
    resolvedOpportunityId;
    hasLoaded = false;

    // 30/09/2026 - Org accounts: Nationality / UAE resident live on the Opportunity's
    // PrimaryContact__c (Contact.Nationality__c / Contact.UAE_Resident_Status__c)
    primaryContactId = null;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.attributes && pageRef.attributes.recordId) {
            this.pageRefRecordId = pageRef.attributes.recordId;
        }
        this.tryLoad();
    }

    @track isLoading = true;
    @track isSaving = false;
    @track isPersonAccount = true;
    @track isOrgAccount = false;

    // mailing - all plain text, whatever the geo API or user types
    @track villaNumber = '';
    @track streetWithoutVilla = '';
    originalAccountStreet = '';
    @track mailingCity = '';
    @track mailingState = '';
    @track mailingCountry = DEFAULT_COUNTRY;
    @track mailingPostalCode = '';

    // billing - all plain text
    @track billingSameAsMailing = true;
    @track billingStreet = '';
    @track billingCity = '';
    @track billingState = '';
    @track billingCountry = DEFAULT_COUNTRY;
    @track billingPostalCode = '';

    // person extras
    @track nationality = '';
    @track uaeResident = '';
    @track nationalityOptions = [];
    @track uaeResidentOptions = [];

    // org extra
    @track unifiedNumber = '';
    // Arvind (11/08/2026) - new mandatory Org account fields: Trade License Number and UAE VAT Register Number
    @track tradeLicenseNumber = '';
    @track uaeVatRegisterNumber = '';
    // Arvind (12/08/2026) - new mandatory Org account field: Trade Name
    @track tradeName = '';

    // geo search state - mailing (person accounts)
    @track mailingSearchText = '';
    @track mailingSearchResults = [];
    @track showMailingSearchResults = false;
    @track isMailingSearching = false;

    // geo search state - billing (org accounts)
    @track billingSearchText = '';
    @track billingSearchResults = [];
    @track showBillingSearchResults = false;
    @track isBillingSearching = false;

    // hidden lat/long, never rendered in UI
    mailingLatitude = null;
    mailingLongitude = null;
    billingLatitude = null;
    billingLongitude = null;

    connectedCallback() {
        this.tryLoad();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (!this.hasLoaded) {
                this.isLoading = false;
                this.toast(
                    'Error',
                    'Could not determine which record to load. Please close this window and try the action again.',
                    'error'
                );
            }
        }, 6000);
    }

    @api
    invoke() {
        this.tryLoad();
    }

    get effectiveRecordId() {
        return this.recordId || this.pageRefRecordId || this.urlRecordId;
    }

    get urlRecordId() {
        try {
            const href = window.location.href;
            let match = href.match(/\/lightning\/r\/[^/]+\/([a-zA-Z0-9]{15,18})\/view/);
            if (match) return match[1];
            match = href.match(/[?&]recordId=([a-zA-Z0-9]{15,18})/);
            if (match) return match[1];
            return null;
        } catch (e) {
            return null;
        }
    }

    // 30/09/2026 - detect an Opportunity by its key prefix instead of comparing Ids.
    // The old `effectiveRecordId !== resolvedAccountId` check treated a 15-char
    // Account Id from the URL as an "Opportunity", because Apex returns 18 chars.
    isOpportunityId(id) {
        return !!id && String(id).startsWith(OPPORTUNITY_KEY_PREFIX);
    }

    tryLoad() {
        if (this.hasLoaded) return;
        if (!this.effectiveRecordId) return;
        this.hasLoaded = true;
        this.loadRecord();
    }

    async loadRecord() {
        this.isLoading = true;
        try {
            this.resolvedAccountId = await resolveAccountId({ sourceRecordId: this.effectiveRecordId });
            this.resolvedOpportunityId = this.isOpportunityId(this.effectiveRecordId) ? this.effectiveRecordId : null;

            // 30/09/2026 - pass the Opportunity Id so Apex can read PrimaryContact__c
            const [data, picklists] = await Promise.all([
                loadAccount({ accountId: this.resolvedAccountId, opportunityId: this.resolvedOpportunityId }),
                getPicklistOptions()
            ]);

            this.nationalityOptions = picklists.nationalityOptions || [];
            this.uaeResidentOptions = picklists.uaeResidentOptions || [];

            this.isPersonAccount = data.isPersonAccount === true;
            this.isOrgAccount = !this.isPersonAccount;

            if (this.isPersonAccount) {
                this.originalAccountStreet = data.personMailingStreet || '';

                const split = this.splitVillaFromStreet(data.personMailingStreet);
                this.villaNumber = split.villa;
                this.streetWithoutVilla = split.street;

                this.mailingCity = data.personMailingCity || '';
                this.mailingState = data.personMailingState || '';
                this.mailingCountry = data.personMailingCountry || '';
                this.mailingPostalCode = data.personMailingPostalCode || '';
                this.mailingLatitude = data.personMailingLatitude != null ? data.personMailingLatitude : null;
                this.mailingLongitude = data.personMailingLongitude != null ? data.personMailingLongitude : null;

                // Show exactly what is saved on the record - no default
                this.nationality = this.matchOptionValue(this.nationalityOptions, data.nationality);
                this.uaeResident = this.matchOptionValue(this.uaeResidentOptions, data.uaeResidentStatus);

                this.billingSameAsMailing = true;
                this.mirrorBillingFromMailing();
            } else {
                this.unifiedNumber = data.unifiedNumber || '';
                this.tradeLicenseNumber = data.tradeLicenseNumber || '';
                this.uaeVatRegisterNumber = data.uaeVatRegisterNumber || '';
                this.tradeName = data.tradeName || '';

                // Org accounts never mirror mailing (see Arvind 11/08/2026 fix)
                this.billingSameAsMailing = false;

                // 30/09/2026 - Nationality / UAE resident come from the Opportunity's
                // Primary Contact, not the business Account.
                this.primaryContactId = data.primaryContactId || null;
                // Apex resolves these from the Primary Contact (falling back to the Opportunity)
                this.nationality = this.matchOptionValue(this.nationalityOptions, data.nationality);
                this.uaeResident = this.matchOptionValue(this.uaeResidentOptions, data.uaeResidentStatus);

                if (!this.primaryContactId) {
                    this.toast(
                        'Primary contact missing',
                        this.resolvedOpportunityId
                            ? 'This opportunity has no Primary Contact, so Nationality and UAE resident cannot be saved.'
                            : 'Open this action from the Opportunity so Nationality and UAE resident can be saved to its Primary Contact.',
                        'warning'
                    );
                }

                this.hydrateBilling(data);
            }
        } catch (err) {
            console.error('gelocationLWC: loadRecord failed', err);
            this.toast('Error', this.extractError(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // 30/09/2026 - lightning-combobox shows blank when `value` isn't exactly one of the
    // option values. Match case-insensitively on value or label so a stored value like
    // "yes" still selects the "Yes" option.
    matchOptionValue(options, raw) {
        if (raw == null || raw === '') return '';
        const needle = String(raw).trim().toLowerCase();
        const hit = (options || []).find(
            o => (o.value || '').toLowerCase() === needle || (o.label || '').toLowerCase() === needle
        );
        return hit ? hit.value : String(raw);
    }

    hydrateBilling(data) {
        this.billingStreet = data.billingStreet || '';
        this.billingCity = data.billingCity || '';
        this.billingState = data.billingState || '';
        this.billingCountry = data.billingCountry || '';
        this.billingPostalCode = data.billingPostalCode || '';
        this.billingLatitude = data.billingLatitude != null ? data.billingLatitude : null;
        this.billingLongitude = data.billingLongitude != null ? data.billingLongitude : null;
    }

    // ---------- getters ----------

    get billingReadOnly() { return this.billingSameAsMailing; }

    get billingSectionDisabledClass() {
        return this.billingSameAsMailing ? 'address-grid billing-disabled' : 'address-grid';
    }

    get saveButtonLabel() { return this.isSaving ? 'Saving...' : 'Save to account'; }

    // ---------- handlers: mailing ----------

    handleVillaNumberChange(e) {
        this.villaNumber = e.target.value;
        if (this.billingSameAsMailing) this.mirrorBillingFromMailing();
    }

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
        if (!raw) {
            return { villa: '', street: '' };
        }
        const commaIndex = raw.indexOf(',');
        if (commaIndex === -1) {
            return { villa: '', street: raw };
        }
        const firstPart = raw.substring(0, commaIndex).trim();
        const rest = raw.substring(commaIndex + 1).trim();
        const looksLikeVilla = firstPart.length > 0 && firstPart.length <= 20;
        if (looksLikeVilla && rest) {
            return { villa: firstPart, street: rest };
        }
        return { villa: '', street: raw };
    }

    handleMailingStreetChange(e) {
        this.streetWithoutVilla = e.target.value;
        if (this.billingSameAsMailing) this.mirrorBillingFromMailing();
    }
    handleMailingCityChange(e) { this.mailingCity = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingStateChange(e) { this.mailingState = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingCountryChange(e) { this.mailingCountry = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }
    handleMailingPostalChange(e) { this.mailingPostalCode = e.target.value; if (this.billingSameAsMailing) this.mirrorBillingFromMailing(); }

    // ---------- handlers: billing ----------

    handleBillingSameToggle(event) {
        this.billingSameAsMailing = event.target.checked;
        if (this.billingSameAsMailing) {
            this.mirrorBillingFromMailing();
        } else {
            this.clearBillingFields();
        }
    }

    clearBillingFields() {
        this.billingStreet = '';
        this.billingCity = '';
        this.billingState = '';
        this.billingCountry = DEFAULT_COUNTRY;
        this.billingPostalCode = '';
        this.billingLatitude = null;
        this.billingLongitude = null;
    }

    handleBillingStreetChange(e) { if (this.isOrgAccount || !this.billingSameAsMailing) this.billingStreet = e.target.value; }
    handleBillingCityChange(e) { if (this.isOrgAccount || !this.billingSameAsMailing) this.billingCity = e.target.value; }
    handleBillingStateChange(e) { if (this.isOrgAccount || !this.billingSameAsMailing) this.billingState = e.target.value; }
    handleBillingCountryChange(e) { if (this.isOrgAccount || !this.billingSameAsMailing) this.billingCountry = e.target.value; }
    handleBillingPostalChange(e) { if (this.isOrgAccount || !this.billingSameAsMailing) this.billingPostalCode = e.target.value; }

    mirrorBillingFromMailing() {
        this.billingStreet = this.buildMergedMailingStreet();
        this.billingCity = this.mailingCity;
        this.billingState = this.mailingState;
        this.billingCountry = this.mailingCountry;
        this.billingPostalCode = this.mailingPostalCode;
        this.billingLatitude = this.mailingLatitude;
        this.billingLongitude = this.mailingLongitude;
    }

    // ---------- handlers: nationality / residency ----------

    handleNationalityChange(e) { this.nationality = e.detail.value; }

    stripEmirateSuffix(value) {
        if (!value) return '';
        return value.replace(/\s+emirate$/i, '').trim();
    }

    findYesNoOption(wantYes) {
        const list = this.uaeResidentOptions || [];
        const target = wantYes ? ['yes', 'true'] : ['no', 'false'];
        const match = list.find(o => target.includes((o.value || '').toLowerCase()) || target.includes((o.label || '').toLowerCase()));
        return match ? match.value : (list[0] ? list[0].value : '');
    }

    findUaeNationalityOption() {
        const list = this.nationalityOptions || [];
        const match = list.find(o => (o.label || '').toLowerCase().includes('emirates') || (o.value || '').toLowerCase() === 'ae');
        return match ? match.value : '';
    }

    handleUaeResidentChange(event) { this.uaeResident = event.detail.value; }

    // ---------- org account ----------

    handleUnifiedNumberChange(e) { this.unifiedNumber = e.target.value; }
    handleTradeLicenseNumberChange(e) { this.tradeLicenseNumber = e.target.value; }
    handleUaeVatRegisterNumberChange(e) { this.uaeVatRegisterNumber = e.target.value; }
    handleTradeNameChange(e) { this.tradeName = e.target.value; }

    // ---------- geo location search: mailing (person accounts) ----------

    handleMailingSearchChange(event) {
        this.mailingSearchText = event.target.value;

        if (!this.mailingSearchText || this.mailingSearchText.length < 3) {
            this.mailingSearchResults = [];
            this.showMailingSearchResults = false;
            return;
        }

        this.isMailingSearching = true;
        searchLocation({ searchText: this.mailingSearchText })
            .then(result => {
                this.mailingSearchResults = result || [];
                this.showMailingSearchResults = this.mailingSearchResults.length > 0;
            })
            .catch(err => {
                this.toast('Error', this.extractError(err), 'error');
            })
            .finally(() => {
                this.isMailingSearching = false;
            });
    }

    async handleMailingLocationSelect(event) {
        const lat = parseFloat(event.currentTarget.dataset.lat);
        const lon = parseFloat(event.currentTarget.dataset.lon);
        const label = event.currentTarget.dataset.label;

        this.mailingSearchText = label;
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

            // 01/10/2026 - UAE resident follows the address; Nationality is NOT inferred from it
            // (a UAE address doesn't mean UAE nationality - it was overwriting the user's choice).
            this.uaeResident = this.findYesNoOption(isUae);

            if (this.billingSameAsMailing) {
                this.mirrorBillingFromMailing();
            }

            this.toast('Address found', 'Mailing address filled from location. You can still edit it.', 'success');
        } catch (err) {
            this.toast('Error', this.extractError(err), 'error');
        } finally {
            this.isMailingSearching = false;
        }
    }

    // ---------- geo location search: billing (org accounts) ----------

    handleBillingSearchChange(event) {
        this.billingSearchText = event.target.value;

        if (!this.billingSearchText || this.billingSearchText.length < 3) {
            this.billingSearchResults = [];
            this.showBillingSearchResults = false;
            return;
        }

        this.isBillingSearching = true;
        searchLocation({ searchText: this.billingSearchText })
            .then(result => {
                this.billingSearchResults = result || [];
                this.showBillingSearchResults = this.billingSearchResults.length > 0;
            })
            .catch(err => {
                this.toast('Error', this.extractError(err), 'error');
            })
            .finally(() => {
                this.isBillingSearching = false;
            });
    }

    async handleBillingLocationSelect(event) {
        const lat = parseFloat(event.currentTarget.dataset.lat);
        const lon = parseFloat(event.currentTarget.dataset.lon);
        const label = event.currentTarget.dataset.label;

        this.billingSearchText = label;
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

            // 30/09/2026 - Org accounts: only auto-fill UAE resident / Nationality when the
            // Primary Contact didn't already supply a value (contact data wins).
            if (!this.uaeResident) {
                this.uaeResident = this.findYesNoOption(isUae);
            }
            // 01/10/2026 - Nationality is never inferred from the address

            this.toast('Address found', 'Billing address filled from location. You can still edit it.', 'success');
        } catch (err) {
            this.toast('Error', this.extractError(err), 'error');
        } finally {
            this.isBillingSearching = false;
        }
    }

    // ---------- save ----------

    async handleSave() {
        const missing = [];

        if (this.isPersonAccount) {
            if (!(this.villaNumber || '').trim()) missing.push('Villa / building number');
            if (!(this.streetWithoutVilla || '').trim() && !(this.originalAccountStreet || '').trim()) missing.push('Street');
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
            if (!(this.tradeLicenseNumber || '').trim()) missing.push('Trade license number');
            if (!(this.uaeVatRegisterNumber || '').trim()) missing.push('UAE VAT register number');
            if (!(this.tradeName || '').trim()) missing.push('Trade name');
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

        // 30/09/2026 - Org Nationality / UAE resident are saved on the Primary Contact
        if (this.isOrgAccount && !this.primaryContactId) {
            this.toast(
                'Primary contact missing',
                'Set a Primary Contact on the Opportunity before saving Nationality and UAE resident.',
                'error'
            );
            return;
        }

        this.isSaving = true;
        try {
            if (!this.resolvedAccountId) {
                this.resolvedAccountId = await resolveAccountId({ sourceRecordId: this.effectiveRecordId });
                this.resolvedOpportunityId = this.isOpportunityId(this.effectiveRecordId) ? this.effectiveRecordId : null;
            }
            if (!this.resolvedAccountId) {
                this.toast('Error', 'Could not determine which account to save. Please close and reopen this form.', 'error');
                this.isSaving = false;
                return;
            }

            const payload = {
                accountId: this.resolvedAccountId,
                opportunityId: this.resolvedOpportunityId,
                isPersonAccount: this.isPersonAccount,
                // 30/09/2026 - Contact to receive Nationality__c / UAE_Resident_Status__c (Org only)
                primaryContactId: this.primaryContactId,

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

                unifiedNumber: this.unifiedNumber,
                tradeLicenseNumber: this.tradeLicenseNumber,
                uaeVatRegisterNumber: this.uaeVatRegisterNumber,
                tradeName: this.tradeName
            };

            await saveAccount({ accountData: JSON.stringify(payload) });
            this.toast('Saved', 'Account address details saved.', 'success');

            const recordIdsToRefresh = [{ recordId: this.effectiveRecordId }];
            if (this.resolvedAccountId && this.resolvedAccountId !== this.effectiveRecordId) {
                recordIdsToRefresh.push({ recordId: this.resolvedAccountId });
            }
            // 30/09/2026 - refresh the Primary Contact too, since it was updated
            if (this.isOrgAccount && this.primaryContactId) {
                recordIdsToRefresh.push({ recordId: this.primaryContactId });
            }
            getRecordNotifyChange(recordIdsToRefresh);

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (err) {
            this.toast('Error', this.extractError(err), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(err) {
        return (err && err.body && err.body.message) ? err.body.message : (err.message || 'Something went wrong.');
    }
}