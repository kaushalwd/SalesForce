import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchSimilarParties
from '@salesforce/apex/ProspectAccountMatcherController.searchSimilarParties';

import resolveAccountOrContact
from '@salesforce/apex/ProspectAccountMatcherController.resolveAccountOrContact';

import getSRState
from '@salesforce/apex/ProspectAccountMatcherController.getSRState';

import { getObjectInfo } from 'lightning/uiObjectInfoApi';

import PROSPECT_OBJECT
from '@salesforce/schema/Prospect_Account__c';

export default class ProspectRecordManager extends LightningElement {

    @api recordId;

    @track candidates = [];
    @track showCandidates = false;

    selectedType;
    hasOrgContact = false;
    isSaving = false;
    selectedAccountId;
    selectedContactId;

    searchName = '';
    searchEmail = '';
    searchPhone = '';
    searchEid = '';
    searchPassport = '';

    hasOrg = false;
    hasPrimary = false;

    parentProspectId;

    orgRtId;
    sharedRtId;

    columns = [
        { label: 'Type', fieldName: 'recordType' },
        { label: 'Name', fieldName: 'name' },
        { label: 'Email', fieldName: 'email' },
        { label: 'Phone', fieldName: 'phone' },
        { label: 'EID', fieldName: 'eid' },
        { label: 'Passport', fieldName: 'passport' }
    ];

    typeOptions = [
        { label: 'Org', value: 'ORG' },
        { label: 'Individual', value: 'PERSON' },
        { label: 'Contact', value: 'CONTACT' }
    ];

    // =====================================================
    // RECORD TYPES
    // =====================================================

    @wire(getObjectInfo, {
        objectApiName: PROSPECT_OBJECT
    })
    objectInfoHandler({ data, error }) {

        if (data) {

            const rtInfos =
                data.recordTypeInfos;

            Object.keys(rtInfos).forEach(rtId => {

                const rt =
                    rtInfos[rtId];

                if (rt.name === 'Org Account') {
                    this.orgRtId = rtId;
                }

                if (rt.name === 'Individual Acc / Contact') {
                    this.sharedRtId = rtId;
                }
            });
        }

        if (error) {
            console.error(error);
        }
    }

    // =====================================================
    // INIT
    // =====================================================

    connectedCallback() {
        this.loadState();
    }

    async loadState() {

    try {

        const res = await getSRState({
            srId: this.recordId
        });

        this.hasOrg = res.hasOrg;
        this.hasPrimary = res.hasPrimary;
        this.parentProspectId = res.orgProspectId;
        this.hasOrgContact = res.hasOrgContact;

        if (
            this.hasOrg &&
            !this.hasOrgContact
        ) {

            this.selectedType = 'CONTACT';
        }

    } catch (e) {

        console.error(e);
    }
}
    // =====================================================
    // GETTERS
    // =====================================================
    get showExistingOrgContactError() {

        return this.hasOrgContact;
    }
    get disableSaveButton() {

        return this.isSaving;
    }

    get disableFullScreen() {

        return this.hasOrgContact;
    }
    get isOrg() {
        return this.selectedType === 'ORG';
    }

    get isIndividual() {
        return this.selectedType === 'PERSON';
    }

    get isContact() {
        return this.selectedType === 'CONTACT';
    }

    get currentRecordTypeId() {

        if (this.isOrg) {
            return this.orgRtId;
        }

        return this.sharedRtId;
    }

    get isPersonValue() {
        return this.isIndividual;
    }
    get saveLabel() {

    return this.isSaving
        ? 'Saving...'
        : 'Save';
}
    get isPrimaryValue() {

    // ORG
    if (this.isOrg) {
        return false;
    }

    // CONTACT
    if (this.isContact) {
        return true;
    }

    // FIRST INDIVIDUAL
    if (
        this.isIndividual &&
        !this.hasPrimary
    ) {

        return true;
    }

    return false;
}

    get disablePrimary() {

        if (this.isOrg) {
            return true;
        }

        if (this.isContact) {
            return true;
        }

        if (this.hasPrimary) {
            return true;
        }

        return false;
    }

    get showOwnership() {
        return this.isIndividual || this.isContact;
    }

    get showParentProspect() {
        return this.isContact && this.parentProspectId;
    }

    get showOrgError() {
        return this.isContact && !this.hasOrg;
    }

    // =====================================================
    // TYPE CHANGE
    // =====================================================

   handleTypeChange(event) {

    if (this.hasOrgContact) {
        return;
    }

    this.selectedType =
        event.detail.value;

    this.selectedAccountId = null;
    this.selectedContactId = null;

    this.candidates = [];
    this.showCandidates = false;
}
    
    // =====================================================
    // SEARCH INPUT
    // =====================================================

    handleSearchInput(event) {

        const field =
            event.target.dataset.field;

        this[field] =
            event.target.value;
    }

    // =====================================================
    // SEARCH
    // =====================================================

    async handleSearchClick() {

        try {

            const result =
                await searchSimilarParties({

                    name:
                        this.searchName || null,

                    email:
                        this.searchEmail || null,

                    phone:
                        this.searchPhone || null,

                    eid:
                        this.searchEid || null,

                    passport:
                        this.searchPassport || null
                });

            this.candidates =
                (result || []).filter(row => {

                    // ORG
                    if (this.isOrg) {

                        return (
                            row.accountId &&
                            !row.contactId &&
                            row.isPersonAccount === false
                        );
                    }

                    // PERSON
                    if (this.isIndividual) {

                        return (
                            row.accountId &&
                            !row.contactId &&
                            row.isPersonAccount === true
                        );
                    }

                    // CONTACT
                    if (this.isContact) {

                        return (
                            row.contactId != null
                        );
                    }

                    return false;
                });

            this.showCandidates =
                this.candidates.length > 0;

        } catch (e) {

            console.error(e);
        }
    }
get showRelationshipSubType() {

    return (
        this.isIndividual &&
        this.hasPrimary === true
    );
}
    // =====================================================
    // ROW SELECT
    // =====================================================

    handleRowSelection(event) {

        const row =
            event.detail.selectedRows[0];

        this.selectedAccountId =
            row?.accountId || null;

        this.selectedContactId =
            row?.contactId || null;
    }

    // =====================================================
    // SUBMIT
    // =====================================================

    async handleSubmit(event) {

    event.preventDefault();

    this.isSaving = true;

    try {

        let fields =
            { ...event.detail.fields };

       // =================================================
            // COMMON
            // =================================================

            fields.RecordTypeId =
                this.currentRecordTypeId;

            fields.Service_Request__c =
                this.recordId;

            fields.Email__c =
                this.searchEmail;

            fields.Mobile__c =
                this.searchPhone;

            fields.EIDNumber__c =
                this.searchEid;

            fields.PassportNumber__c =
                this.searchPassport;

            // =================================================
            // ORG
            // =================================================

            if (this.isOrg) {

                fields.Account_Name__c =
                    this.searchName || 'Unknown Organisation';

                fields.IsPersonAccount__c =
                    false;

                fields.Is_Primary__c =
                    false;

                fields.Prospect_Account__c =
                    null;
            }

            // =================================================
            // PERSON / CONTACT
            // =================================================

            if (this.isIndividual || this.isContact) {

                let names =
                    (this.searchName || '')
                        .trim()
                        .split(' ');

                fields.First_Name__c =
                    names.length > 1
                        ? names.slice(0, -1).join(' ')
                        : '';

                fields.Last_Name__c =
                    names.length > 0
                        ? names[names.length - 1]
                        : 'Unknown';
            }

            // =================================================
            // PERSON
            // =================================================

            if (this.isIndividual) {

                fields.IsPersonAccount__c =
                    true;

                if (this.hasPrimary) {

                    fields.Is_Primary__c =
                        false;
                }
            }

            // =================================================
            // CONTACT
            // =================================================

            if (this.isContact) {

                fields.IsPersonAccount__c =
                    false;

                fields.Is_Primary__c =
                    true;

                fields.Prospect_Account__c =
                    this.parentProspectId;
            }

            // =================================================
            // RESOLVE
            // =================================================

        const res =
            await resolveAccountOrContact({

                recordTypeLabel:
                    this.isOrg
                        ? 'Org Account'
                        : 'Individual Acc / Contact',

                prospectFields:
                    fields,

                selectedAccountId:
                    this.selectedAccountId,

                selectedContactId:
                    this.selectedContactId
            });

        if (res.accountId) {
            fields.Account__c =
                res.accountId;
        }

        if (res.contactId) {
            fields.Contact__c =
                res.contactId;
        }

        this.template
            .querySelector('lightning-record-edit-form')
            .submit(fields);

    } catch (e) {

        this.isSaving = false;

        console.error(e);
    }
}
    // =====================================================
    // SUCCESS
    // =====================================================

    handleSuccess() {

    this.isSaving = false;

    window.location.reload();
}

    // handleError(event) {
    //     console.error(event);
    // }

  handleError(event) {

    this.isSaving = false;

    console.error(event);

    let message = 'Unknown Error';

    if (
        event.detail &&
        event.detail.output &&
        event.detail.output.fieldErrors
    ) {

        const fieldErrors =
            event.detail.output.fieldErrors;

        const allErrors = [];

        Object.keys(fieldErrors).forEach(field => {

            fieldErrors[field].forEach(err => {
                allErrors.push(err.message);
            });
        });

        if (allErrors.length > 0) {
            message = allErrors.join(', ');
        }
    }

    else if (
        event.detail &&
        event.detail.output &&
        event.detail.output.errors &&
        event.detail.output.errors.length
    ) {

        message =
            event.detail.output.errors[0].message;
    }

    else if (
        event.detail &&
        event.detail.message
    ) {

        message =
            event.detail.message;
    }

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
            mode: 'sticky'
        })
    );
}
}