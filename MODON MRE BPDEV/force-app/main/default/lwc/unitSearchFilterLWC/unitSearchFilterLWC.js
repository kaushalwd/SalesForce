/**
* @description       : Lightning Web Component to handle Unit search and filtering.
*                      Publishes filter criteria using Lightning Message Service
*                      and dynamically loads picklist values and max unit metrics.
* @author            : Mostafa Abdelrehem
* @company           : CloudzLab
* @last modified on  : 08-12-2025
* @last modified by  : Mostafa Abdelrehem
* Modifications Log
* Ver   Date         Author               Modification
* 1.0   08-12-2025   Mostafa Abdelrehem   Initial Version
* 1.1   16-01-2026   Mostafa Abdelrehem   Introducing the VisibletoMRESalesTeam Boolean picklist filter.
* 1.2.  22-01-2026.  Mostafa Abdelrehem   Introducing the ApprovalStatus And Substatus filter and put All option in all picklists.
**/
import { LightningElement, wire, api, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference } from "lightning/navigation";
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { MessageContext, publish } from 'lightning/messageService';
import UNIT_OBJECT from '@salesforce/schema/Unit__c';
import UNIT_TYPE_FIELD from '@salesforce/schema/Unit__c.UnitClassification__c';
import UNIT_CURRENCY_FIELD from '@salesforce/schema/Unit__c.CurrencyIsoCode';
import UNIT_NUMBER_OF_BEDROOMS_FIELD from '@salesforce/schema/Unit__c.Number_of_Bedrooms__c';
import UNIT_FLOOR_FIELD from '@salesforce/schema/Unit__c.floor__c';
import UNIT_STATUS_FIELD from '@salesforce/schema/Unit__c.Status__c';
import UNIT_APPROVAL_STATUS_FIELD from '@salesforce/schema/Unit__c.ApprovalStatus__c';
import UNIT_SUB_STATUS_FIELD from '@salesforce/schema/Unit__c.Sub_Status__c';
import msg from '@salesforce/messageChannel/msg__c';
import getAllUnitPhases from '@salesforce/apex/UnitSearchResultController.getAllUnitPhases';
import getAllUnitProjects from '@salesforce/apex/UnitSearchResultController.getAllUnitProjects';
import getMaximumUnitValues from '@salesforce/apex/UnitSearchResultController.getMaximumUnitValues';
import getUserRoleAndProfile from '@salesforce/apex/UnitSearchResultController.getUserRoleAndProfile';


export default class UnitSearchFilterLWC extends LightningElement {
    @api sourceEntity;
    
    // Properties matching message channel fields
    @api selectedProjectValue;
    @api selectedPhaseValue;
    @api selectedUnitTypeValue;
    @api selectedPriceToValue;
    @api selectedNumberOfBedroomsValue;
    @api selectedGrossFloorAreaValue;
    @api selectedFloorValue;
    @api selectedUnitNameValue;
    @api selectedCurrencyValue;
    @api selectedZoneValue;
    @api selectedBuildingNoValue;
    @api selectedUnitStatusValue;
    @api selectedVisibletoMRESalesTeamValue;
    @api selectedApprovalStatusValue;
    @api selectedSubStatusValue;
    @api saveCheck = false;
    @track isSaving = false;
    recordId;
    @api minPrice = 0;
    @api maxPrice;
    @api minArea = 0;
    @api maxArea;
    
    // visibleToMREOptions
    visibleToMREOptions = [
        { label: 'All', value: '' },
        { label: 'True', value: 'true' },
        { label: 'False', value: 'false' }
    ];

    // User Role and Profile Name
    userRole = '';
    profileName = '';

    // Debounce properties
    searchTimeout;

    @track unitPhaseOptions = [];
    @track unitProjectOptions = [];

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.loadUserInfo();
        this.resetButtonClick();
        this.sendFilterMessage();
    }

    async loadUserInfo() {
        try {
            const userInfo = await getUserRoleAndProfile();
            this.userRole = userInfo.userRole;
            this.profileName = userInfo.profileName;
        } catch (error) {
            console.error('Error loading user info:', error);
        }

    }

    @wire(getObjectInfo, { objectApiName: UNIT_OBJECT })
    unitInfo;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.state) {
            this.recordId = pageRef.state.c__recordId;
        }
    }
    
    // add All option to picklist values 1.2v
    addAllOption(options) {
    return [{ label: 'All', value: '' }, ...options];
   }
   // get Type Options
   @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_TYPE_FIELD,
    })
    UnitTypeValues;
    get unitTypeOptions() {
        return this.UnitTypeValues?.data?.values
        ? this.addAllOption(this.UnitTypeValues.data.values)
        : [{ label: 'All', value: '' }];
    }

    // get Status Options
    @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_STATUS_FIELD,
    })
    UnitStatusValues;
    get unitStatusOptions() {
        return this.UnitStatusValues?.data?.values
        ? this.addAllOption(this.UnitStatusValues.data.values)
        : [{ label: 'All', value: '' }];
    }

    // get Approval Status Options
    @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_APPROVAL_STATUS_FIELD,
    })
    UnitApprovalStatusValues;
    get unitApprovalStatusOptions() {
        return this.UnitApprovalStatusValues?.data?.values
        ? this.addAllOption(this.UnitApprovalStatusValues.data.values)
        : [{ label: 'All', value: '' }];
    }

    // get Sub Status Options
    @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_SUB_STATUS_FIELD,
    })
    UnitSubStatusValues;
    get unitSubStatusOptions() {
        return this.UnitSubStatusValues?.data?.values
        ? this.addAllOption(this.UnitSubStatusValues.data.values)
        : [{ label: 'All', value: '' }];
    }

    // get Number Of Bedrooms Options
    @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_NUMBER_OF_BEDROOMS_FIELD,
    })
    UnitNumberOfBedroomsValues;
    get unitBedroomsOptions() {
        return this.UnitNumberOfBedroomsValues?.data?.values
        ? this.addAllOption(this.UnitNumberOfBedroomsValues.data.values)
        : [{ label: 'All', value: '' }];
    }

    // get Floor Options
    @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_FLOOR_FIELD,
    })
    UnitFloorValues;
    get unitFloorOptions() {
        return this.UnitFloorValues?.data?.values
        ? this.addAllOption(this.UnitFloorValues.data.values)
        : [{ label: 'All', value: '' }];
    }

    // get Currency Options
    @wire(getPicklistValues, {
        recordTypeId: '$unitInfo.data.defaultRecordTypeId',
        fieldApiName: UNIT_CURRENCY_FIELD,
    })
    UnitCurrencyValues;

   // get Phases Options
    @wire(getAllUnitPhases, { sourceEntity: '$sourceEntity' })
    wiredUnitPhases({ error, data }) {
        if (data) {
            this.unitPhaseOptions = this.addAllOption(data);
        } else if (error) {
            console.error('Error fetching Unit Phases:', error);
        }
    }
    // get Projects Options
    @wire(getAllUnitProjects, { sourceEntity: '$sourceEntity' })
    wiredUnitProjects({ error, data }) {
        if (data) {
            this.unitProjectOptions = this.addAllOption(data);
        } else if (error) {
            console.error('Error fetching Unit Projects:', error);
        }
    }
   // get Max Values for Price and Area
    @wire(getMaximumUnitValues, { sourceEntity: '$sourceEntity' ,currencyCode: '$selectedCurrencyValue' })
    wiredMaxValues({ error, data }) {
        if (data) {
            this.maxPrice = data.MaxPrice || 0;
            this.maxArea = data.MaxArea || 0;
        } else if (error) {
            console.error('Error fetching max values:', error);
        }
    }

    

    // Event Handlers
    handleProjectChange(event) {
        this.selectedProjectValue = event.detail.value;
        this.sendFilterMessage();
    }
    
    handlePhaseChange(event) {
        this.selectedPhaseValue = event.detail.value;
        this.sendFilterMessage();
    }

    handleZoneChange(event) {
        this.selectedZoneValue = event.target.value;
        this.debounceSearch();
    }

    handleBuildingNoChange(event) {
        this.selectedBuildingNoValue = event.target.value;
        this.debounceSearch();
    }

    handleUnitNameChange(event) {
        this.selectedUnitNameValue = event.target.value;
        this.debounceSearch();
    }

    handleUnitTypeChange(event) {
        this.selectedUnitTypeValue = event.detail.value;
        this.sendFilterMessage();
    }

    handleVisibletoMRESalesTeamChange(event) {
        this.selectedVisibletoMRESalesTeamValue = event.detail.value;
        this.sendFilterMessage();
    }

    handleUnitStatusChange(event) {
        this.selectedUnitStatusValue = event.detail.value;
        this.sendFilterMessage();
    }


    handleApprovalStatusChange(event) {
        this.selectedApprovalStatusValue = event.detail.value;
        this.sendFilterMessage();
    }

    handleSubStatusChange(event) {
        this.selectedSubStatusValue = event.detail.value;
        this.sendFilterMessage();
    }

    handlePriceChange(event) {
        this.selectedPriceToValue = event.target.value;
        this.sendFilterMessage();
    }

    handleGrossFloorAreaChange(event) {
        this.selectedGrossFloorAreaValue = event.target.value;
        this.sendFilterMessage();
    }

    handleNumberOfBedroomsChange(event) {
        this.selectedNumberOfBedroomsValue = event.target.value;
        this.sendFilterMessage();
    }

    handleFloorChange(event) {
        this.selectedFloorValue = event.target.value;
        this.sendFilterMessage();
    }

    handleCurrencyChange(event) {
        this.selectedCurrencyValue = event.detail.value;
        this.sendFilterMessage();
    }
    handleSave() {
    this.isSaving = true;
    this.saveCheck = true;
    this.sendFilterMessage();
    
    // Reset after 3 seconds (adjust time as needed)
    setTimeout(() => {
        this.isSaving = false;
    }, 3000);
}
get saveButtonLabel() {
    return this.isSaving ? 'Saving...' : 'Save';
}

get saveButtonVariant() {
    return this.isSaving ? 'neutral' : 'brand';
}

    // Debounce helper for text inputs
    debounceSearch() {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        this.searchTimeout = setTimeout(() => {
            this.sendFilterMessage();
        }, 2000);
    }

    // Show/hide filters based on user role and profile
    get showUnitStatusFilter() {
    const allowedProfiles = ['System Administrator', 'Modon Egypt - Sales Operations'];
    const allowedRoles = ['Modon Egypt - Head of Sale'];
    return allowedProfiles.includes(this.profileName) || allowedRoles.includes(this.userRole);
    }
    

    // Reset all filters
    async resetButtonClick() {
        this.selectedProjectValue = '';
        this.selectedPhaseValue = '';
        this.selectedUnitTypeValue = '';
        this.selectedPriceToValue = this.minPrice;
        this.selectedGrossFloorAreaValue = this.minArea;
        this.selectedNumberOfBedroomsValue = '';
        this.selectedFloorValue = '';
        this.selectedUnitNameValue = '';
        this.selectedCurrencyValue = '';
        this.selectedZoneValue = '';
        this.selectedBuildingNoValue = '';
        
        if(this.showUnitStatusFilter)
        {
            this.selectedUnitStatusValue = '';
            this.selectedVisibletoMRESalesTeamValue = '';
            this.selectedApprovalStatusValue = '';
            this.selectedSubStatusValue = '';

        }
        else
        {
            this.selectedUnitStatusValue = 'Available';
            this.selectedVisibletoMRESalesTeamValue = 'false';
            this.selectedApprovalStatusValue = 'Released';
            this.selectedSubStatusValue = 'Un-Assigned';
        }
        
        this.sendFilterMessage();
    }

    // Publish filter changes via Lightning Message Service
    sendFilterMessage() {
        const payload = {
            project: this.selectedProjectValue,
            phase: this.selectedPhaseValue,
            zone: this.selectedZoneValue,
            buildingNo: this.selectedBuildingNoValue,
            unitType: this.selectedUnitTypeValue,
            priceTo: this.selectedPriceToValue,
            numberOfBedrooms: this.selectedNumberOfBedroomsValue,
            grossFloorArea: this.selectedGrossFloorAreaValue,
            floor: this.selectedFloorValue,
            unitName: this.selectedUnitNameValue,
            currency: this.selectedCurrencyValue,
            unitStatus: this.selectedUnitStatusValue,
            visibletoMRESalesTeam: this.selectedVisibletoMRESalesTeamValue,
            approvalStatus: this.selectedApprovalStatusValue,
            subStatus: this.selectedSubStatusValue,
            save: this.saveCheck
        };
        this.savecheck = false;
        publish(this.messageContext, msg, payload);
    }
}