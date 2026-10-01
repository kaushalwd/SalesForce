import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import loadForm from '@salesforce/apex/AccountKycController.loadForm';
import saveForm from '@salesforce/apex/AccountKycController.saveForm';

// Existing geo service - two step: search returns coordinates, then reverse lookup
import searchLocation from '@salesforce/apex/GeoapifyLocationController.searchLocation';
import getAddressFromLatLong from '@salesforce/apex/GeoapifyLocationController.getAddressFromLatLong';

const SEARCH_DEBOUNCE_MS = 350;
const MIN_SEARCH_CHARS = 3;

const INPUT_TYPE_MAP = {
    string: 'text',
    email: 'email',
    phone: 'tel',
    url: 'url',
    date: 'date',
    datetime: 'datetime',
    number: 'number',
    currency: 'number',
    percent: 'number'
};

/**
 * Fields that are forced to a fixed value and greyed out while a condition
 * holds. When Employment Status is Employed, Source of Income is set to
 * Salary and cannot be changed. Switching Employment Status to anything else
 * clears the value and unlocks the field again.
 *
 * - whenField / setField: matched loosely against the fields Apex sent, so
 *   Source_of_Income__c, SourceOfIncome__c and SourceOfIncome__pc are all
 *   treated as the same field. Underscores, casing and the __c / __pc suffix
 *   are ignored when matching.
 * - whenValues: lower case, compared against the trimmed controlling value.
 * - setValue: must be the picklist API value, not the label.
 */
const LOCKED_DEFAULT_RULES = [
    {
        whenField: 'EmploymentStatus__c',
        whenValues: ['employed'],
        setField: 'SourceOfIncome__c',
        setValue: 'Salary',
        note: 'Set to Salary because Employment Status is Employed'
    }
];

/**
 * Strips the __c / __pc suffix, underscores and casing so a rule written as
 * Source_of_Income__c still matches a field called SourceOfIncome__pc.
 */
function baseFieldName(apiName) {
    return String(apiName || '')
        .replace(/__(c|pc)$/i, '')
        .replace(/_/g, '')
        .toLowerCase();
}

// Address field names now come from each section's addressFields, supplied by
// Apex, so the component does not need to know about Billing vs Mailing vs
// PersonMailing.

export default class AccountKycForm extends NavigationMixin(LightningElement) {

    /**
     * recordId is not always populated by the time connectedCallback runs -
     * quick actions and flow screens can set it afterwards. Loading from the
     * setter means the form starts as soon as the framework supplies the Id,
     * whenever that happens.
     */
    _recordId;
    _loadStarted = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this._loadStarted) {
            this._loadStarted = true;
            this.loadDefinition();
        }
    }

    @track sections = [];
    @track accountValues = {};
    @track contactValues = {};

    context = {};
    isLoading = true;
    isSaving = false;
    loadError = '';
    errorMessage = '';

    _searchTimers = {};
    _searchState = {};
    autoSetRules = [];
    _lockRules = [];
    @track _villaNumbers = {};

    /* ------------------------------------------------------------------ */
    /*  Input masks                                                        */
    /* ------------------------------------------------------------------ */

    /**
     * Emirates ID is always 784-YYYY-NNNNNNN-C, 15 digits in a 3-4-7-1 grouping.
     * Strips anything that is not a digit and re-inserts the hyphens, so the
     * user can paste with or without them and still end up with a valid value.
     */
    formatEmiratesId(raw) {
        if (raw === null || raw === undefined) return '';

        const digits = String(raw).replace(/\D/g, '').slice(0, 15);
        if (!digits) return '';

        const parts = [
            digits.slice(0, 3),
            digits.slice(3, 7),
            digits.slice(7, 14),
            digits.slice(14, 15)
        ].filter((p) => p.length);

        return parts.join('-');
    }

    applyMask(maskName, value) {
        if (maskName === 'emiratesId') return this.formatEmiratesId(value);
        return value;
    }

    /* ------------------------------------------------------------------ */
    /*  Lifecycle                                                          */
    /* ------------------------------------------------------------------ */

    connectedCallback() {
        // If the Id was already set the setter has started the load. If it is
        // still missing after the current tick the component was placed
        // somewhere that supplies no record context.
        if (this._loadStarted) return;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            if (this._loadStarted) return;
            this.isLoading = false;
            this.loadError =
                'This form needs a record to work from. Open it from an Account, ' +
                'Contact or Opportunity record, or pass recordId in if you are ' +
                'launching it from a flow.';
        }, 0);
    }

    async loadDefinition() {
        this.isLoading = true;
        this.loadError = '';

        try {
            const def = await loadForm({ sourceRecordId: this._recordId });

            this.context = def.context || {};
            this.autoSetRules = def.autoSetRules || [];
            this.accountValues = { ...(def.accountValues || {}) };
            this.contactValues = { ...(def.contactValues || {}) };

            const villas = {};

            this.sections = (def.sections || []).map((s) => {
                this._searchState[s.key] = {
                    searchTerm: '',
                    results: [],
                    isSearching: false,
                    searchError: ''
                };
                // Apex pulls any previously saved villa back out of the street
                if (s.isAddress) {
                    villas[s.key] = s.villaValue || '';
                }
                return { ...s };
            });

            this._villaNumbers = villas;

            // Work out which locked-value rules apply to this form, then make
            // sure a record that is already Employed shows Salary straight away.
            this.resolveLockRules();
            this.enforceLockedValues();

        } catch (error) {
            this.loadError = this.extractError(error);
        } finally {
            this.isLoading = false;
        }
    }

    /* ------------------------------------------------------------------ */
    /*  Locked values (Employed -> Source of Income = Salary)              */
    /* ------------------------------------------------------------------ */

    normalise(value) {
        return value === null || value === undefined
            ? ''
            : String(value).trim().toLowerCase();
    }

    objectKeyFor(section) {
        return section.targetObject === 'contact' ? 'contact' : 'account';
    }

    /**
     * Matches each rule in LOCKED_DEFAULT_RULES against the fields Apex put on
     * the form. A rule only applies when both the controlling field and the
     * locked field are on the same object, so the org account's own
     * SourceOfIncome__c is never locked by the contact's Employment Status.
     */
    resolveLockRules() {
        // Each object gets a lookup of baseFieldName -> the exact API name Apex
        // used, so the rules do not have to know the org's naming convention.
        const fieldsByObject = {};
        this.sections.forEach((s) => {
            const key = this.objectKeyFor(s);
            if (!fieldsByObject[key]) fieldsByObject[key] = {};
            (s.fields || []).forEach((f) => {
                fieldsByObject[key][baseFieldName(f.apiName)] = f.apiName;
            });
        });

        const pick = (lookup, name) => lookup[baseFieldName(name)];

        const resolved = [];
        LOCKED_DEFAULT_RULES.forEach((rule) => {
            Object.keys(fieldsByObject).forEach((objectKey) => {
                const set = fieldsByObject[objectKey];
                const whenField = pick(set, rule.whenField);
                const setField = pick(set, rule.setField);

                if (whenField && setField) {
                    resolved.push({ ...rule, targetObject: objectKey, whenField, setField });
                } else if (whenField && !setField) {
                    // eslint-disable-next-line no-console
                    console.warn(
                        `accountKycForm: ${rule.setField} is not on the form, so it ` +
                        `cannot be locked when ${rule.whenField} changes. Check the ` +
                        'section definition in AccountKycController.'
                    );
                }
            });
        });

        this._lockRules = resolved;
    }

    ruleMatches(rule, values) {
        return rule.whenValues.indexOf(this.normalise(values[rule.whenField])) !== -1;
    }

    getLock(objectKey, apiName, values) {
        return this._lockRules.find(
            (r) => r.targetObject === objectKey
                && r.setField === apiName
                && this.ruleMatches(r, values)
        ) || null;
    }

    /**
     * Forces locked fields to their fixed value while the rule matches. When
     * the controlling field moves away from a matching value, the fixed value
     * is cleared so the user picks a new Source of Income themselves.
     */
    enforceLockedValues(changedField) {
        ['account', 'contact'].forEach((objectKey) => {
            const current = objectKey === 'contact' ? this.contactValues : this.accountValues;
            const patch = {};

            this._lockRules
                .filter((r) => r.targetObject === objectKey)
                .forEach((r) => {
                    if (this.ruleMatches(r, current)) {
                        if (current[r.setField] !== r.setValue) patch[r.setField] = r.setValue;
                    } else if (changedField === r.whenField && current[r.setField] === r.setValue) {
                        patch[r.setField] = '';
                    }
                });

            if (!Object.keys(patch).length) return;

            if (objectKey === 'contact') {
                this.contactValues = { ...this.contactValues, ...patch };
            } else {
                this.accountValues = { ...this.accountValues, ...patch };
            }
        });
    }

    /* ------------------------------------------------------------------ */
    /*  Rendering                                                          */
    /* ------------------------------------------------------------------ */

    get renderSections() {
        return this.sections
            .map((section) => this.decorateSection(section))
            // A section whose fields are all hidden (Emirates ID for a
            // non-resident) would otherwise leave a stray heading behind.
            .filter((section) => section.isAddress || section.fields.length);
    }

    decorateSection(section) {
        const values = section.targetObject === 'contact'
            ? this.contactValues
            : this.accountValues;

        const search = this._searchState[section.key] || {};

        return {
            ...section,
            searchTerm: search.searchTerm || '',
            results: search.results || [],
            isSearching: !!search.isSearching,
            hasResults: !!(search.results && search.results.length),
            searchError: search.searchError || '',
            villaNumber: this._villaNumbers[section.key] || '',
            villaLabel: section.villaLabel || 'Villa / building number',
            fields: section.fields
                .map((f) => this.decorateField(f, values, section))
                .filter((f) => f.isVisible)
        };
    }

    decorateField(f, values, section) {
        const rawValue = values[f.apiName];
        const isCheckbox = f.type === 'boolean';
        const isPicklist = f.type === 'picklist' || f.type === 'multipicklist';
        const isTextarea = f.type === 'textarea';

        // A locked field (Source of Income while Employed) renders like any
        // other read-only field: greyed out, showing the fixed value.
        const lock = this.getLock(this.objectKeyFor(section), f.apiName, values);
        const isReadOnly = !!f.readOnly || !!lock;

        const isRequiredNow = !!f.required;
        const isFullWidth = isTextarea || /Street$/.test(f.apiName);

        // Narrow the picklist when another field controls which options apply,
        // e.g. Source of Income depends on Employment Status.
        let options = f.options;
        if (f.optionsControlledBy && f.dependentOptions) {
            const normalised = this.normalise(values[f.optionsControlledBy]);
            const match = f.dependentOptions.find(
                (set) => set.controllingValue === normalised
            );
            // No entry for this value means the full picklist applies
            if (match) options = match.options;
        }

        // A field with a visibility rule disappears when the rule is not met
        let isVisible = true;
        if (f.visibleWhenField && f.visibleWhenValues) {
            const normalised = this.normalise(values[f.visibleWhenField]);
            const matched = f.visibleWhenValues.indexOf(normalised) !== -1;
            isVisible = f.visibleWhenNegate ? !matched : matched;
        }

        let value;
        if (lock) value = lock.setValue;
        else if (isCheckbox) value = !!rawValue;
        else value = rawValue === null || rawValue === undefined ? '' : rawValue;

        return {
            ...f,
            isVisible,
            value,
            isCheckbox,
            isPicklist: isPicklist && !isReadOnly,
            isTextarea: isTextarea && !isReadOnly,
            isInput: !isCheckbox && !isPicklist && !isTextarea && !isReadOnly,
            isReadOnly,
            isLocked: !!lock,
            readOnlyNote: lock ? lock.note : 'Read only',
            isRequiredNow,
            options,
            inputType: INPUT_TYPE_MAP[f.type] || 'text',
            maxLength: f.maxLength > 0 ? f.maxLength : undefined,
            hasMask: !!f.mask,
            wrapperClass: isFullWidth ? 'field-cell field-cell-full' : 'field-cell',
            sectionKey: section.key
        };
    }

    get headerSubtitle() {
        if (this.context.includeContactSection) {
            return `${this.context.contactName || 'Contact'} and ${this.context.accountName || 'account'}`;
        }
        return `${this.context.accountName || 'Account'} \u00b7 person account`;
    }

    get fieldCountLabel() {
        let required = 0;
        this.renderSections.forEach((s) => {
            s.fields.forEach((f) => {
                if (f.isRequiredNow && !f.isReadOnly) required += 1;
            });
        });
        return `${required} required ${required === 1 ? 'field' : 'fields'}`;
    }

    /* ------------------------------------------------------------------ */
    /*  Field changes                                                      */
    /* ------------------------------------------------------------------ */

    handleFieldChange(event) {
        const target = event.currentTarget.dataset.target;
        const field = event.currentTarget.dataset.field;
        const mask = event.currentTarget.dataset.mask;
        if (!field) return;

        let value = event.detail
            ? (event.detail.checked !== undefined ? event.detail.checked : event.detail.value)
            : event.target.value;

        if (mask && typeof value === 'string') {
            const masked = this.applyMask(mask, value);
            if (masked !== value) {
                value = masked;
                // Reflect the reformatted value straight back into the input
                event.currentTarget.value = masked;
            }
        }

        if (target === 'contact') {
            this.contactValues = { ...this.contactValues, [field]: value };
        } else {
            this.accountValues = { ...this.accountValues, [field]: value };
        }

        this.applyAutoSetRules(target, field);

        // Runs after the auto-set rules, because those may clear Source of
        // Income when Employment Status changes.
        this.enforceLockedValues(field);

        if (this.errorMessage) this.errorMessage = '';
    }

    /**
     * Employment status drives several other fields. When it changes we clear
     * the dependants, then apply whatever the rule says to set - a literal
     * value (Source of Income becomes Salary) or a copy of another field
     * (Company Name comes from EID Sponsor).
     */
    applyAutoSetRules(target, changedField) {
        const objectKey = target === 'contact' ? 'contact' : 'account';

        const rules = this.autoSetRules.filter(
            (r) => r.targetObject === objectKey && r.whenField === changedField
        );
        if (!rules.length) return;

        const current = objectKey === 'contact' ? this.contactValues : this.accountValues;
        const patch = {};

        rules.forEach((rule) => {
            const value = this.normalise(current[rule.whenField]);
            const matched = (rule.whenValues || []).indexOf(value) !== -1;

            // Dependants are cleared whether or not the rule matched, so a
            // stale Position does not survive a switch to Unemployed.
            (rule.clearFields || []).forEach((f) => { patch[f] = ''; });

            if (!matched) return;

            Object.keys(rule.setLiteral || {}).forEach((f) => {
                patch[f] = rule.setLiteral[f];
            });

            Object.keys(rule.copyFromField || {}).forEach((f) => {
                const sourceField = rule.copyFromField[f];
                const sourceValue = current[sourceField];
                if (sourceValue) patch[f] = sourceValue;
            });
        });

        if (objectKey === 'contact') {
            this.contactValues = { ...this.contactValues, ...patch };
        } else {
            this.accountValues = { ...this.accountValues, ...patch };
        }
    }

    handleVillaChange(event) {
        const sectionKey = event.currentTarget.dataset.section;
        this._villaNumbers = {
            ...this._villaNumbers,
            [sectionKey]: event.detail.value
        };
        if (this.errorMessage) this.errorMessage = '';
    }

    /* ------------------------------------------------------------------ */
    /*  Address search - GeoapifyLocationController (Google Geocoding v4)  */
    /*                                                                     */
    /*  Step 1  searchLocation(searchText)                                 */
    /*            -> [{ label, lat, lon, placeId }]                        */
    /*  Step 2  getAddressFromLatLong(latitude, longitude)                 */
    /*            -> { formatted, addressLine1, street, city, state,       */
    /*                 country, countryCode, postcode, latitude,           */
    /*                 longitude }                                         */
    /* ------------------------------------------------------------------ */

    handleGeoSearchChange(event) {
        const sectionKey = event.currentTarget.dataset.section;
        const term = event.detail.value;

        const state = this._searchState[sectionKey];
        if (!state) return;

        state.searchTerm = term;
        state.searchError = '';

        window.clearTimeout(this._searchTimers[sectionKey]);

        if (!term || term.trim().length < MIN_SEARCH_CHARS) {
            state.results = [];
            state.isSearching = false;
            this.refreshSections();
            return;
        }

        state.isSearching = true;
        this.refreshSections();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimers[sectionKey] = window.setTimeout(() => {
            this.runGeoSearch(sectionKey, term);
        }, SEARCH_DEBOUNCE_MS);
    }

    async runGeoSearch(sectionKey, term) {
        const state = this._searchState[sectionKey];
        if (!state) return;

        try {
            const raw = await searchLocation({ searchText: term });

            // Discard a stale response if the user has kept typing
            if (state.searchTerm !== term) return;

            state.results = (raw || []).map((r, i) => ({
                key: r.placeId || `${sectionKey}-${i}`,
                label: r.label,
                lat: r.lat,
                lon: r.lon
            }));

            state.searchError = state.results.length
                ? ''
                : 'No matches. Enter the address manually.';

        } catch (error) {
            state.results = [];
            state.searchError = this.extractError(error);
        } finally {
            state.isSearching = false;
            this.refreshSections();
        }
    }

    async handleGeoSelect(event) {
        const sectionKey = event.currentTarget.dataset.section;
        const index = parseInt(event.currentTarget.dataset.index, 10);

        const state = this._searchState[sectionKey];
        const section = this.sections.find((s) => s.key === sectionKey);
        if (!state || !section) return;

        const chosen = state.results[index];
        if (!chosen) return;

        state.searchTerm = chosen.label;
        state.results = [];
        state.isSearching = true;
        state.searchError = '';
        this.refreshSections();

        try {
            const detail = await getAddressFromLatLong({
                latitude: parseFloat(chosen.lat),
                longitude: parseFloat(chosen.lon)
            });

            if (!detail) {
                state.searchError = 'No address returned. Enter it manually.';
                return;
            }

            this.applyAddress(section, detail, chosen.label);

        } catch (error) {
            state.searchError = this.extractError(error);
        } finally {
            state.isSearching = false;
            this.refreshSections();
        }
    }

    applyAddress(section, detail, fallbackLabel) {
        const map = section.addressFields;
        if (!map) return;

        const patch = {};

        // The wrapper builds street from Google's addressComponents, so it never
        // contains city, state or country. Fall back to the picked label only if
        // Google returned no street-level components at all.
        const street = this.deriveStreet(detail) || fallbackLabel;

        if (street && map.street)               patch[map.street] = street;
        if (detail.city && map.city)            patch[map.city] = detail.city;
        if (detail.state && map.state)          patch[map.state] = detail.state;
        if (detail.country && map.country)      patch[map.country] = detail.country;
        if (detail.postcode && map.postalCode)  patch[map.postalCode] = detail.postcode;

        // Google frequently omits city for UAE addresses - fall back to the emirate
        if (map.city && !patch[map.city] && detail.state) {
            patch[map.city] = detail.state;
        }

        if (section.targetObject === 'contact') {
            this.contactValues = { ...this.contactValues, ...patch };
        } else {
            this.accountValues = { ...this.accountValues, ...patch };
        }
    }

    deriveStreet(detail) {
        // GeoapifyLocationController builds both from Google's addressComponents.
        // street is the fuller form (premise, route, sublocality joined) and is
        // already capped at 250 chars, so it is the better fit for BillingStreet.
        // addressLine1 is the short "<number> <route>" form.
        if (detail.street) return detail.street;
        if (detail.addressLine1) return detail.addressLine1;

        // Safety net only - should not be reached with the current wrapper
        if (!detail.formatted) return '';

        const drop = [detail.city, detail.state, detail.country, detail.postcode]
            .filter((v) => v && String(v).trim())
            .map((v) => String(v).trim());

        const remaining = detail.formatted
            .split(',')
            .map((part) => part.trim())
            .filter((part) => part && drop.indexOf(part) === -1);

        return remaining.join(', ');
    }

    refreshSections() {
        this.sections = [...this.sections];
    }

    /* ------------------------------------------------------------------ */
    /*  Save                                                               */
    /* ------------------------------------------------------------------ */

    async handleSave() {
        this.errorMessage = '';

        // Belt and braces: make sure the locked value is in the payload even
        // if something cleared it after the last change.
        this.enforceLockedValues();

        const missing = this.collectMissingFields();
        if (missing.length) {
            this.errorMessage = `Complete these fields before saving: ${missing.join(', ')}`;
            this.scrollToTop();
            return;
        }

        const badFormat = this.collectFormatErrors();
        if (badFormat.length) {
            this.errorMessage = badFormat.join(' ');
            this.scrollToTop();
            return;
        }

        const allValid = [...this.template.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        )].reduce((acc, cmp) => {
            const valid = cmp.reportValidity();
            return acc && valid;
        }, true);

        if (!allValid) {
            this.errorMessage = 'Some fields need attention. Check the highlighted entries.';
            return;
        }

        this.isSaving = true;

        // The villa number is not a field of its own - Apex prefixes it onto
        // the street line for whichever object owns that address section.
        const accountPayload = { ...this.accountValues };
        const contactPayload = { ...this.contactValues };

        this.sections.forEach((s) => {
            if (!s.isAddress) return;
            const villa = this._villaNumbers[s.key];
            if (!villa || !villa.trim()) return;
            if (s.targetObject === 'contact') contactPayload.villaNumber = villa.trim();
            else                              accountPayload.villaNumber = villa.trim();
        });

        try {
            await saveForm({
                payloadJson: JSON.stringify({
                    sourceRecordId: this._recordId,
                    accountValues: accountPayload,
                    contactValues: contactPayload
                })
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved',
                message: this.context.includeContactSection
                    ? 'Contact and account details updated'
                    : 'Account details updated',
                variant: 'success'
            }));

            this.closeForm();

        } catch (error) {
            this.errorMessage = this.extractError(error);
            this.scrollToTop();
        } finally {
            this.isSaving = false;
        }
    }

    collectFormatErrors() {
        const errors = [];
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        this.renderSections.forEach((section) => {
            section.fields.forEach((f) => {
                if (f.isReadOnly) return;

                const value = f.value;
                if (value === null || value === undefined || String(value).trim() === '') return;

                if (f.formatPattern && !new RegExp(f.formatPattern).test(String(value))) {
                    errors.push(f.formatMessage || `${f.label} is not in the expected format.`);
                }

                if (f.dateRule) {
                    const d = new Date(value);
                    if (isNaN(d.getTime())) {
                        errors.push(`${f.label} is not a valid date.`);
                    } else if (f.dateRule === 'future' && d <= today) {
                        errors.push(`${f.label} must be a future date.`);
                    } else if (f.dateRule === 'past' && d > today) {
                        errors.push(`${f.label} cannot be in the future.`);
                    }
                }
            });
        });
        return errors;
    }

    collectMissingFields() {
        const missing = [];
        this.renderSections.forEach((section) => {

            if (section.isAddress && section.villaRequired) {
                const villa = this._villaNumbers[section.key];
                if (!villa || !String(villa).trim()) {
                    missing.push(section.villaLabel);
                }
            }

            section.fields.forEach((f) => {
                if (f.isReadOnly || f.isCheckbox || !f.isRequiredNow) return;
                const value = f.value;
                if (value === null || value === undefined || String(value).trim() === '') {
                    missing.push(f.label);
                }
            });
        });
        return missing;
    }

    /* ------------------------------------------------------------------ */
    /*  Helpers                                                            */
    /* ------------------------------------------------------------------ */

    handleCancel() {
        this.closeForm();
    }

    closeForm() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('close'));
    }

    scrollToTop() {
        const card = this.template.querySelector('.kyc-card');
        if (card && card.scrollIntoView) {
            card.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    extractError(error) {
        if (!error) return 'Something went wrong.';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((e) => e.message).join(', ');
            }
            if (error.body.message) return error.body.message;
            if (error.body.pageErrors && error.body.pageErrors.length) {
                return error.body.pageErrors.map((e) => e.message).join(', ');
            }
        }
        return error.message || 'Something went wrong.';
    }
}