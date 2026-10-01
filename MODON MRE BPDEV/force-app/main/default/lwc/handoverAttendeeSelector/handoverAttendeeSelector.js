import { LightningElement, api, track, wire } from 'lwc';
import {
    FlowNavigationNextEvent,
    FlowNavigationBackEvent,
    FlowAttributeChangeEvent
} from 'lightning/flowSupport';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getJointOwners from '@salesforce/apex/HandoverAttendeeController.getJointOwners';

import HO_ATTENDED_BY   from '@salesforce/schema/Handover_Details__c.Home_Orientation_Attended_By__c';
import DS_ATTENDED_BY   from '@salesforce/schema/Handover_Details__c.De_Snagging_Attended_By__c';
import HO_POA_RESIDENT  from '@salesforce/schema/Handover_Details__c.HO_Attendee_POA_Resident_Status__c';
import DS_POA_RESIDENT  from '@salesforce/schema/Handover_Details__c.De_Snagging_Attendee_POA_Resident_Status__c';
import HO_AUTH_TYPE     from '@salesforce/schema/Handover_Details__c.HO_Type_of_Authorized_Party__c';

const HO_RECORD_FIELDS = [HO_ATTENDED_BY, HO_POA_RESIDENT, HO_AUTH_TYPE];
const DS_RECORD_FIELDS = [DS_ATTENDED_BY, DS_POA_RESIDENT];

// All HO-specific fields cleared when another option is selected
const HO_CLEAR = [
    'HO_Attendee_Owner__c', 'HO_Attendee_Joint_Owner__c',
    'HO_Attendee_POA_Name__c', 'HO_Attendee_POA_Email_Address__c',
    'HO_Attendee_POA_Mobile_Number__c', 'HO_Attendee_POA_Resident_Status__c',
    'HO_Attendee_Emirates_Id__c', 'HO_Attendee_Passport_Number__c',
    'HO_Authorized_Person_Name__c', 'HO_Authorized_Person_Email__c',
    'HO_Authorized_Person_Phone__c', 'HO_Type_of_Authorized_Party__c',
    'HO_Authorized_Company_Name__c', 'HO_Authorized_Company_Trade_License__c',
    'HO_Attendee_Third_Party_Engineer_Name__c', 'HO_Attendee_Third_Party_Engineer_Email__c',
    'HO_Attendee_Third_Party_Engineer_Mobile__c', 'HO_Attendee_Company_Name__c',
    'HO_Attendee_Trade_License__c', 'Home_Orientation_Attended_By__c'
];

// All DS-specific fields cleared when another option is selected
const DS_CLEAR = [
    'De_Snagging_Attendee_Owner__c', 'HO_Attendee_Joint_Owner__c',
    'De_Snagging_Attendee_POA_Name__c', 'De_Snagging_Attendee_POA_Email_Address__c',
    'De_Snagging_Attendee_POA_Mobile_Number__c', 'De_Snagging_Attendee_POA_Resident_Status__c',
    'De_Snagging_Attendee_Emirates_Id__c', 'De_Snagging_Attendee_Passport_Number__c',
    'De_Snagging_Attended_By__c'
];

export default class HandoverAttendeeSelector extends LightningElement {
    // ── Flow inputs ────────────────────────────────────────────────────
    @api recordId;
    /** 'Home_Orientation' | 'De_Snagging' */
    @api mode = 'Home_Orientation';
    /** CustomerAccount Id from the Sales Order — used for Owner assignment & JO query */
    @api ownerAccountId;
    /** Related record Id for file upload (formula-computed in flow) */
    @api docRelatedId;

    // ── Flow outputs ───────────────────────────────────────────────────
    @api attendedBy = '';

    // ── Internal state ─────────────────────────────────────────────────
    @track selectedAttendedBy   = '';
    @track selectedResidentStatus = '';
    @track authPartyType        = '';
    @track selectedJOId         = '';
    @track errorMessage         = '';
    @track jointOwners          = [];
    _recordPreloaded            = false;

    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];

    // ── Wire: load existing record values for initial rendering ────────
    @wire(getRecord, { recordId: '$recordId', fields: '$_recordFields' })
    wiredRecord({ data }) {
        if (data && !this._recordPreloaded) {
            this._recordPreloaded = true;
            if (this.isHO) {
                this.selectedAttendedBy    = getFieldValue(data, HO_ATTENDED_BY)  || '';
                this.selectedResidentStatus = getFieldValue(data, HO_POA_RESIDENT) || '';
                this.authPartyType         = getFieldValue(data, HO_AUTH_TYPE)     || '';
            } else {
                this.selectedAttendedBy    = getFieldValue(data, DS_ATTENDED_BY)   || '';
                this.selectedResidentStatus = getFieldValue(data, DS_POA_RESIDENT)  || '';
            }
            if (this.selectedAttendedBy) {
                this.dispatchEvent(new FlowAttributeChangeEvent('attendedBy', this.selectedAttendedBy));
            }
        }
    }

    // ── Wire: joint owners for picker ─────────────────────────────────
    @wire(getJointOwners, { accountId: '$ownerAccountId' })
    wiredJO({ data }) {
        if (data) {
            this.jointOwners = data.map(jo => ({
                Id: jo.Id,
                Name: jo.Name,
                isSelected: false,
                cardClass: 'jo-card'
            }));
        }
    }

    // ── Getters ────────────────────────────────────────────────────────
    get isHO()              { return this.mode === 'Home_Orientation'; }
    get isDS()              { return this.mode === 'De_Snagging'; }
    get isOwner()           { return this.selectedAttendedBy === 'Owner'; }
    get isJointOwner()      { return this.selectedAttendedBy === 'Joint Owner'; }
    get isPOA()             { return this.selectedAttendedBy === 'POA'; }
    get isAuthorisedPerson(){ return this.selectedAttendedBy === 'Authorised Person'; }
    get isThirdParty()      { return this.selectedAttendedBy === 'Third Party'; }
    get isUAEResident()     { return this.selectedResidentStatus === 'UAE Resident'; }
    get isNonResident()     { return this.selectedResidentStatus === 'Non-Resident'; }
    get isCompany()         { return this.authPartyType === 'Company'; }
    get ownerAvailable()    { return !!this.ownerAccountId; }
    get hasJointOwners()    { return this.jointOwners && this.jointOwners.length > 0; }

    get _recordFields() {
        return this.isHO ? HO_RECORD_FIELDS : DS_RECORD_FIELDS;
    }

    get showHODocUpload() {
        return this.isHO &&
            this.selectedAttendedBy &&
            this.selectedAttendedBy !== 'Owner' &&
            this.selectedAttendedBy !== 'Joint Owner';
    }

    get isNextDisabled() {
        if (!this.selectedAttendedBy) return true;
        if (this.isOwner && !this.ownerAvailable) return true;
        if (this.isJointOwner && !this.selectedJOId) return true;
        return false;
    }

    // ── Event handlers ─────────────────────────────────────────────────
    handleAttendedByChange(event) {
        this.selectedAttendedBy     = event.detail.value;
        this.selectedJOId           = '';
        this.selectedResidentStatus = '';
        this.authPartyType          = '';
        this.errorMessage           = '';
        this.jointOwners = this.jointOwners.map(jo => ({ ...jo, isSelected: false, cardClass: 'jo-card' }));
        this.dispatchEvent(new FlowAttributeChangeEvent('attendedBy', this.selectedAttendedBy));
    }

    handleResidentStatusChange(event) {
        this.selectedResidentStatus = event.detail.value;
    }

    handleAuthPartyTypeChange(event) {
        this.authPartyType = event.detail.value;
    }

    handleJOSelect(event) {
        const joId = event.currentTarget.dataset.id;
        this.selectedJOId  = joId;
        this.errorMessage  = '';
        this.jointOwners   = this.jointOwners.map(jo => ({
            ...jo,
            isSelected: jo.Id === joId,
            cardClass: jo.Id === joId ? 'jo-card jo-card--selected' : 'jo-card'
        }));
    }

    handleSubmit(event) {
        event.preventDefault();

        if (!this._validate()) return;

        // Merge lightning-input-field values with programmatic overrides
        const fields = { ...event.detail.fields };
        this._applyFieldOverrides(fields);

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.errorMessage = '';
        this.dispatchEvent(new FlowNavigationNextEvent());
    }

    handleError(event) {
        this.errorMessage =
            (event.detail && (event.detail.detail || event.detail.message)) ||
            'An unexpected error occurred while saving.';
    }

    handleBack() {
        this.dispatchEvent(new FlowNavigationBackEvent());
    }

    // ── Private helpers ────────────────────────────────────────────────
    _validate() {
        this.errorMessage = '';

        if (!this.selectedAttendedBy) {
            this.errorMessage = 'Please select an attendee type to continue.';
            return false;
        }
        if (this.isOwner && !this.ownerAvailable) {
            this.errorMessage = 'No Owner account is linked to this record. Please select another option.';
            return false;
        }
        if (this.isJointOwner) {
            if (!this.hasJointOwners) {
                this.errorMessage = 'No Joint Owner is available. Please select another option.';
                return false;
            }
            if (!this.selectedJOId) {
                this.errorMessage = 'Please select a Joint Owner from the list above.';
                return false;
            }
        }

        // Standard field-level validation for visible input fields
        const allValid = [
            ...this.template.querySelectorAll('lightning-input-field')
        ].reduce((valid, field) => field.reportValidity() && valid, true);

        return allValid;
    }

    _applyFieldOverrides(fields) {
        // Start with a clean slate for all mode fields to avoid stale data
        if (this.isHO) {
            HO_CLEAR.forEach(f => { if (!(f in fields)) fields[f] = null; });
            fields['Home_Orientation_Attended_By__c'] = this.selectedAttendedBy;
            if (this.isOwner)      fields['HO_Attendee_Owner__c']      = this.ownerAccountId;
            if (this.isJointOwner) fields['HO_Attendee_Joint_Owner__c'] = this.selectedJOId;
        } else if (this.isDS) {
            DS_CLEAR.forEach(f => { if (!(f in fields)) fields[f] = null; });
            fields['De_Snagging_Attended_By__c'] = this.selectedAttendedBy;
            if (this.isOwner)      fields['De_Snagging_Attendee_Owner__c'] = this.ownerAccountId;
            if (this.isJointOwner) fields['HO_Attendee_Joint_Owner__c']    = this.selectedJOId;
        }
    }
}