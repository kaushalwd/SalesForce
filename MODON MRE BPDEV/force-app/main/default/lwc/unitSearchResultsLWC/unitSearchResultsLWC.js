/**
* @description       : Lightning Web Component responsible for displaying Unit search results.
*                      Handles multi-step navigation (Project → Phase → Zone → Units),
*                      applies dynamic filters received via Lightning Message Service,
*                      manages pagination, currency-based pricing, and navigation to Unit records.
* @author            : Mostafa Abdelrehem
* @company           : CloudzLab
* @last modified on  : 08-12-2025
* @last modified by  : Mostafa Abdelrehem
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   08-12-2025   Mostafa Abdelrehem   Initial Version
* 1.1   16-01-2026   Mostafa Abdelrehem   Filtered the result based on the VisibletoMRESalesTeam Boolean picklist value.
* 1.2   22-01-2026.  Mostafa Abdelrehem.  Filtered the result based on the AprrovalStatus and SubStatus picklist value.
**/
import { LightningElement, wire, api, track } from 'lwc';
import { CurrentPageReference } from "lightning/navigation";
import msg from '@salesforce/messageChannel/msg__c';
import { MessageContext, subscribe, unsubscribe } from 'lightning/messageService';
import { NavigationMixin } from 'lightning/navigation';
import getAllDataForSearch from '@salesforce/apex/UnitSearchResultController.getAllDataForSearch';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import UnitImages from '@salesforce/resourceUrl/UnitImages';
import updatePreferredUnits from '@salesforce/apex/UnitSearchResultController.updatePreferredUnits';

export default class UnitSearchResultsLWC extends NavigationMixin(LightningElement) {
    @api sourceEntity;
    
    // Filter properties
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
    @api selectedUnitStatusValue = 'Available';
    @api selectedVisibletoMRESalesTeamValue = 'false';
    @api selectedApprovalStatusValue = 'Released';
    @api selectedSubStatusValue = 'Un-Assigned';
    @api saveCheck;
    // path step
    currentStep = 1;
    @track showSpinner = false;
    
    // All data loaded once
    allUnits = [];
    allProjects = [];
    allPhases = [];
    allZones = [];
    
    // Filtered data
    @track filteredProjects = [];
    @track filteredPhases = [];
    @track filteredZones = [];
    @track filteredUnits = [];
    @track displayedUnits = [];
    
    
    // Current selections
    selectedProjectId;
    selectedPhaseId;
    selectedZoneId;
    currentCurrency = 'EGP';
    defaultCurrency = 'EGP';
    @track selectedUnitIds = new Set();
    
    recordId;
    recordType;

    unitSelectedList = [];
    unitSelectedString ='';

    // Pagination
    page = 1;
    startingRecord = 1;
    endingRecord = 0;
    pageSize = 20;
    totalRecountCount = 0;
    totalPage = 0;

    @wire(MessageContext)
    messageContext;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.state) {
            this.recordId = pageRef.state.c__recordId;
            this.recordType = this.getRecordTypeFromId (this.recordId);
        }
    }
    
    // method to get the record type form id
    getRecordTypeFromId(recordId_2) {
    if (!recordId_2 || recordId_2.length < 3) {
        return null;
    }

    const prefix = recordId_2.substring(0, 3);

    switch (prefix) {
        case '00Q':
            return 'Lead';
        case '006':
            return 'Opportunity';
        default:
            return 'Unknown';
    }
    }
    // get standard images
    getUnitImage(unitType) {
        const imageMap = {
            'Villa': UnitImages + '/villa.jpg',
            'Apartment': UnitImages + '/apartment.jpg',
            'Townhouse': UnitImages + '/townHouse.jpg',
            'Plot': UnitImages + '/Penthouse.jpg',
            'Duplex': UnitImages + '/Studio.jpg',
            'Mansion': UnitImages + '/Penthouse.jpg',
            'Mega Mansion': UnitImages + '/Studio.jpg'
        };
        return imageMap[unitType] || UnitImages + '/Default.jpg';
    }

    getPhaseImage() {
        // Static image for phases
        return UnitImages + '/apartment.jpg';
    }

    getZoneImage() {
        // Static image for zones
        return UnitImages + '/townhouse.jpg';
    }

    connectedCallback() {
        this.loadAllData();
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }
    // Subscribe to message channel
    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            msg,
            (message) => this.handleFilterChange(message)
        );
    }
    // Unsubscribe from message channel
    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }
    // Handle filter changes from message channel
    handleFilterChange(message) {
        // Map message channel fields
        this.selectedProjectValue = message.project || '';
        this.selectedPhaseValue = message.phase || '';
        this.selectedZoneValue = message.zone || '';
        this.selectedBuildingNoValue = message.buildingNo || '';
        this.selectedUnitTypeValue = message.unitType || '';
        this.selectedPriceToValue = message.priceTo || '';
        this.selectedNumberOfBedroomsValue = message.numberOfBedrooms || '';
        this.selectedGrossFloorAreaValue = message.grossFloorArea || '';
        this.selectedFloorValue = message.floor || '';
        this.selectedUnitNameValue = message.unitName || '';
        this.selectedCurrencyValue = message.currency || '';
        this.selectedUnitStatusValue = message.unitStatus || '';
        this.selectedVisibletoMRESalesTeamValue = message.visibletoMRESalesTeam || '';
        this.selectedApprovalStatusValue = message.approvalStatus || '';
        this.selectedSubStatusValue = message.subStatus || '';
        this.saveCheck = message.save || false;

        // Update current currency
        if (this.selectedCurrencyValue) {
            this.currentCurrency = this.selectedCurrencyValue;
        }
        // save lead changes
        if (this.saveCheck == true)
        {
            this.saveCheck = false;
            this.updateLeadUnits();
        }

        this.applyFilters();
    }

    // Load all data for search
    loadAllData() {
        this.showSpinner = true;
        
        getAllDataForSearch({ sourceEntity: this.sourceEntity })
            .then(result => {
                this.allUnits = result.units || [];
                this.allProjects = result.projects || [];
                this.allPhases = result.phases || [];
                this.allZones = result.zones || [];
                this.defaultCurrency = result.defaultCurrency || 'EGP';
                this.currentCurrency = this.defaultCurrency;
                
                this.applyFilters();
                this.showSpinner = false;
            })
            .catch(error => {
                this.showSpinner = false;
                console.error('Error loading data:', JSON.stringify(error));
                this.showToast('Error', 'Failed to load data', 'error');
            });
    }

    // Apply filters based on current step
    applyFilters() {
        // Filter based on current step
        if (this.currentStep === 1) {
            this.filterProjects();
        } else if (this.currentStep === 2) {
            this.filterPhases();
        } else if (this.currentStep === 3) {
            this.filterZones();
        } else if (this.currentStep === 4) {
            this.filterUnits();
        }
    }

    // Filter projects based on current filters
    filterProjects() {
    // First, get units that match current unit-level filters
    const matchingUnits = this.getUnitsMatchingFilters();

    // Filter by zone if selected v1.2
    let unitsToConsider = matchingUnits;
    if (this.selectedZoneValue) {
        unitsToConsider = matchingUnits.filter(unit => 
            unit.ZoneName && unit.ZoneName.toLowerCase().includes(this.selectedZoneValue.toLowerCase())
        );
    }
    
    // Filter by phase if selected v1.2
    if (this.selectedPhaseId) {
        unitsToConsider = unitsToConsider.filter(unit => unit.PhaseId === this.selectedPhaseId);
    }

    // Get unique project IDs from matching units
    const projectIdsWithUnits = new Set(unitsToConsider.map(unit => unit.ProjectId)); 

        this.filteredProjects = this.allProjects.filter(project => {
            // Apply project filter if exists
            if (this.selectedProjectValue) {
                
            if (this.selectedProjectValue && project.id !== this.selectedProjectValue) {
                return false;
            }
            }
            // NEW: Only show project if it has matching units
        return projectIdsWithUnits.has(project.id);
        });
    }

    
    // Filter phases based on current filters
    filterPhases() {
        // First, get units that match current unit-level filters AND selected project
    const matchingUnits = this.getUnitsMatchingFilters().filter(unit => {
        // Must match selected project if one is selected
        if (this.selectedProjectId && unit.ProjectId !== this.selectedProjectId) {
            return false;
        }
        return true;
    });

    // Filter by zone if selected v1.2
    let unitsToConsider = matchingUnits;
    if (this.selectedZoneValue) {
        unitsToConsider = matchingUnits.filter(unit => 
            unit.ZoneName && unit.ZoneName.toLowerCase().includes(this.selectedZoneValue.toLowerCase())
        );
    }
    
    // Get unique phase IDs from matching units
    const phaseIdsWithUnits = new Set(unitsToConsider.map(unit => unit.PhaseId)); 
        this.filteredPhases = this.allPhases.filter(phase => {
            // Must match selected project
            if (this.selectedProjectId && phase.projectId !== this.selectedProjectId) {
                return false;
            }
            // Apply phase filter if exists
            if (this.selectedPhaseValue && phase.id !== this.selectedPhaseValue) {
                return false;
            }
            // NEW: Only show phase if it has matching units
            return phaseIdsWithUnits.has(phase.id);
        });
    }

    // Filter zones based on current filters
    filterZones() {
        // First, get units that match current unit-level filters AND selected project/phase
    const matchingUnits = this.getUnitsMatchingFilters().filter(unit => {
        // Must match selected project if one is selected
        if (this.selectedProjectId && unit.ProjectId !== this.selectedProjectId) {
            return false;
        }
        // Must match selected phase if one is selected
        if (this.selectedPhaseId && unit.PhaseId !== this.selectedPhaseId) {
            return false;
        }
        return true;
    });
    
    // Get unique zone IDs/names from matching units
    const zoneIdsWithUnits = new Set(matchingUnits.map(unit => unit.ZoneName));
        this.filteredZones = this.allZones.filter(zone => {
            // Must match selected project
            if (this.selectedProjectId && zone.projectId !== this.selectedProjectId) {
                return false;
            }
            // Must match selected phase
            if (this.selectedPhaseId && zone.phaseId !== this.selectedPhaseId) {
                return false;
            }
            // Apply zone filter if exists
            if (this.selectedZoneValue) {
                return zone.name.toLowerCase().includes(this.selectedZoneValue.toLowerCase());
            }
            // NEW: Only show zone if it has matching units
        // Match by zone id or name depending on what ZoneName stores
        return zoneIdsWithUnits.has(zone.id) || zoneIdsWithUnits.has(zone.name);
        }).map(zone => ({
            ...zone,
            imageUrl: this.getZoneImage()
        }));
    }

    //Extract the unit filtering logic to reuse
getUnitsMatchingFilters() {
    return this.allUnits.filter(unit => {
        let isValid = true;

        // Unit Type filter
        if (this.selectedUnitTypeValue && unit.UnitClassification !== this.selectedUnitTypeValue) {
            isValid = false;
        }

        // Unit Status filter
        if (this.selectedUnitStatusValue && unit.Status !== this.selectedUnitStatusValue) {
            isValid = false;
        }

        // Unit Approval Status filter
        if (this.selectedApprovalStatusValue && unit.ApprovalStatus !== this.selectedApprovalStatusValue) {
            isValid = false;
        }

        // Unit Sub Status filter
        if (this.selectedSubStatusValue && unit.SubStatus !== this.selectedSubStatusValue) {
            isValid = false;
        }

        // selected Visible to MRE Sales Team filter
        if (this.selectedVisibletoMRESalesTeamValue && unit.VisibletoMRESalesTeam !== this.selectedVisibletoMRESalesTeamValue) {
            isValid = false;
        }

        // Price filter
        let displayPrice = 0;
        if (this.currentCurrency === 'EGP') {
            displayPrice = unit.PriceEGP || unit.TotalPrice;
        } else if (this.currentCurrency === 'USD') {
            displayPrice = unit.PriceUSD || unit.TotalPrice;
        } else if (this.currentCurrency === 'AED') {
            displayPrice = unit.PriceAED || unit.TotalPrice;
        }

        if (this.selectedPriceToValue && displayPrice > this.selectedPriceToValue) {
            isValid = false;
        }

        // Number of Bedrooms filter
        if (this.selectedNumberOfBedroomsValue && unit.NumberOfBedrooms !== this.selectedNumberOfBedroomsValue) {
            isValid = false;
        }

        // Gross Floor Area filter
        if (this.selectedGrossFloorAreaValue && unit.GrossFloorArea > this.selectedGrossFloorAreaValue) {
            isValid = false;
        }

        // Floor filter
        if (this.selectedFloorValue && unit.FloorNumber !== this.selectedFloorValue) {
            isValid = false;
        }

        // Building Number filter
        if (this.selectedBuildingNoValue) {
            if (!unit.BuildingNo || !unit.BuildingNo.toLowerCase().includes(this.selectedBuildingNoValue.toLowerCase())) {
                isValid = false;
            }
        }

        // Unit Name filter
        if (this.selectedUnitNameValue) {
            if (!unit.Name || !unit.Name.toLowerCase().includes(this.selectedUnitNameValue.toLowerCase())) {
                isValid = false;
            }
        }
        

        return isValid;
    });
}
    
    // Filter units based on current filters
    filterUnits() {
        this.filteredUnits = this.allUnits.map(unit => {
            // Get the price based on selected currency
            let displayPrice = 0;
            if (this.currentCurrency === 'EGP') {
                displayPrice = unit.PriceEGP || unit.TotalPrice;
            } else if (this.currentCurrency === 'USD') {
                displayPrice = unit.PriceUSD || unit.TotalPrice;
            } else if (this.currentCurrency === 'AED') {
                displayPrice = unit.PriceAED || unit.TotalPrice;
            }

            return {
                ...unit,
                DisplayPrice: displayPrice,
                DisplayCurrency: this.currentCurrency,
                UnitImageUrl: this.getUnitImage(unit.UnitClassification)
            };
        }).filter(unit => {
            let isValid = true;

            // Must match selected zone
            if (this.selectedZoneId && unit.ZoneName !== this.selectedZoneId) {
                return false;
            }

            // Must match selected phase
            if (this.selectedPhaseId && unit.PhaseId !== this.selectedPhaseId) {
                return false;
            }


            // Must match selected Project 
            if (this.selectedProjectId && unit.ProjectId !== this.selectedProjectId) {
                isValid = false;
            }

            // Project filter
            if (this.selectedProjectValue && unit.ProjectId !== this.selectedProjectValue) {
                isValid = false;
            }
            
            // Phase filter
            if (this.selectedPhaseValue && unit.PhaseId !== this.selectedPhaseValue) {
                isValid = false;
            }
             
            // zone filter
            if (this.selectedZoneValue) {
            if (!unit.ZoneName || !unit.ZoneName.toLowerCase().includes(this.selectedZoneValue.toLowerCase())) {
                isValid = false;
            }
            }

            // Building Number filter
            if (this.selectedBuildingNoValue) {
            if (!unit.BuildingNo || !unit.BuildingNo.toLowerCase().includes(this.selectedBuildingNoValue.toLowerCase())) {
                isValid = false;
            }
            }

            // Unit Type filter
            if (this.selectedUnitTypeValue && unit.UnitClassification !== this.selectedUnitTypeValue) {
                isValid = false;
            }

            // Unit Status filter
            if (this.selectedUnitStatusValue && unit.Status !== this.selectedUnitStatusValue) {
                isValid = false;
            }

            // Unit Approval Status filter
           if (this.selectedApprovalStatusValue && unit.ApprovalStatus !== this.selectedApprovalStatusValue) {
                isValid = false;
            }

           // Unit Sub Status filter
           if (this.selectedSubStatusValue && unit.SubStatus !== this.selectedSubStatusValue) {
                isValid = false;
           }

            // selected Visible to MRE Sales Team filter
            if (this.selectedVisibletoMRESalesTeamValue && unit.VisibletoMRESalesTeam !== this.selectedVisibletoMRESalesTeamValue) {
                isValid = false;
            }

            // Price filter (using display price)
            if (this.selectedPriceToValue && unit.DisplayPrice > this.selectedPriceToValue) {
                isValid = false;
            }

            // Number of Bedrooms filter
            if (this.selectedNumberOfBedroomsValue && unit.NumberOfBedrooms !== this.selectedNumberOfBedroomsValue) {
                isValid = false;
            }

            // Gross Floor Area filter
            if (this.selectedGrossFloorAreaValue && unit.GrossFloorArea > this.selectedGrossFloorAreaValue) {
                isValid = false;
            }

            // Floor filter
            if (this.selectedFloorValue && unit.FloorNumber !== this.selectedFloorValue) {
                isValid = false;
            }

            // Unit Name filter
            if (this.selectedUnitNameValue) {
                if (!unit.Name || !unit.Name.toLowerCase().includes(this.selectedUnitNameValue.toLowerCase())) {
                    isValid = false;
                }
            }

            return isValid;
        });
        this.updatePagination();
    }

    
    updatePagination() {
        this.totalRecountCount = this.filteredUnits.length;
        this.totalPage = Math.ceil(this.totalRecountCount / this.pageSize);
        this.page = 1;
        this.displayRecordPerPage(1);
    }

    // Display records per page
    displayRecordPerPage(page) {
    this.startingRecord = ((page - 1) * this.pageSize);
    this.endingRecord = (this.pageSize * page);
    this.endingRecord = (this.endingRecord > this.totalRecountCount) ? this.totalRecountCount : this.endingRecord;
    this.displayedUnits = this.filteredUnits.slice(this.startingRecord, this.endingRecord).map(unit => ({
        ...unit,
        isSelected: this.selectedUnitIds.has(unit.Id),
        selectButtonVariant: this.selectedUnitIds.has(unit.Id) ? 'neutral' : 'brand',
        selectButtonLabel: this.selectedUnitIds.has(unit.Id) ? 'Selected' : 'Select',
        selectButtonIcon: this.selectedUnitIds.has(unit.Id) ? 'utility:check' : 'utility:add'
    }));
    this.startingRecord = this.startingRecord + 1;
}

    // Handle project, phase, and zone clicks
    handleProjectClick(event) {
        this.selectedProjectId = event.currentTarget.dataset.projectId;
        this.currentStep = 2;
        this.applyFilters();
    }

    handlePhaseClick(event) {
        this.selectedPhaseId = event.currentTarget.dataset.phaseId;
        this.currentStep = 3;
        this.applyFilters();
    }

    handleZoneClick(event) {
        this.selectedZoneId = event.currentTarget.dataset.zoneId;
        this.currentStep = 4;
        this.applyFilters();
    }

    handlePathClick(event) {
        const pathIndex = parseInt(event.currentTarget.dataset.pathIndex);

        if (this.currentStep > pathIndex) {
            this.currentStep = pathIndex;
            
            if (pathIndex === 1) {
                this.selectedProjectId = null;
                this.selectedPhaseId = null;
                this.selectedZoneId = null;
            } else if (pathIndex === 2) {
                this.selectedPhaseId = null;
                this.selectedZoneId = null;
            } else if (pathIndex === 3) {
                this.selectedZoneId = null;
            }
            
            this.applyFilters();
        }
    }

    // Handle link and select clicks
    handleLinkClick(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.unitId,
                objectApiName: 'Unit__c',
                actionName: 'view'
            }
        });
    }

    // handle select clicks for leads and opportunities
   handleSelectClick(event) {
    const unitId = event.target.dataset.unitId;
    const unitName = event.target.dataset.unitName;
    
    if(this.recordType === 'Lead') {
        // Check if unit is already selected
        if (this.selectedUnitIds.has(unitId)) {
            // Remove from selection
            this.selectedUnitIds.delete(unitId);
            this.unitSelectedList = this.unitSelectedList.filter(name => name !== unitName);
            this.unitSelectedString = this.unitSelectedList.join(',');
            this.showToast('Info', 'Unit deselected.', 'info');
        } else {
            // Add to selection
            this.unitSelectedList.push(unitName);
            this.unitSelectedString = this.unitSelectedList.join(',');
            this.selectedUnitIds.add(unitId);
            this.showToast('Success', 'Unit selected successfully.', 'success');
        }
        
        // Refresh the displayed units to update button styles
        this.displayRecordPerPage(this.page);
    }
}
    
    // handle update lead preffered units
    updateLeadUnits() {
    updatePreferredUnits({ leadId: this.recordId, units: this.unitSelectedString })
        .then(() => {
            this.showToast('Success', 'Lead updated successfully', 'success');

            // Navigate to Lead record page after toast
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Lead',
                    actionName: 'view'
                }
            });
        })
        .catch(error => {
            this.showToast('Error updating lead', error.body.message, 'error');
        });
}


    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1;
            this.displayRecordPerPage(this.page);
        }
    }

    nextHandler() {
        if (this.page < this.totalPage) {
            this.page = this.page + 1;
            this.displayRecordPerPage(this.page);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // Getters
    get showProjectsList() {
        return this.filteredProjects.length > 0 && this.currentStep === 1;
    }

    get showPhasesList() {
        return this.filteredPhases.length > 0 && this.currentStep === 2;
    }

    get showZonesList() {
        return this.filteredZones.length > 0 && this.currentStep === 3;
    }

    get showUnitsList() {
        return this.displayedUnits.length > 0 && this.currentStep === 4 && !this.showSpinner;
    }

    get projectPathCSS() {
        let cssClass = 'slds-path__item ';
        cssClass += this.currentStep === 1 ? 'slds-is-active' : this.currentStep > 1 ? 'slds-is-complete' : 'slds-is-incomplete';
        return cssClass;
    }

    get phasePathCSS() {
        let cssClass = 'slds-path__item ';
        cssClass += this.currentStep === 2 ? 'slds-is-active' : this.currentStep > 2 ? 'slds-is-complete' : 'slds-is-incomplete';
        return cssClass;
    }

    get zonePathCSS() {
        let cssClass = 'slds-path__item ';
        cssClass += this.currentStep === 3 ? 'slds-is-active' : this.currentStep > 3 ? 'slds-is-complete' : 'slds-is-incomplete';
        return cssClass;
    }

    get unitPathCSS() {
        let cssClass = 'slds-path__item ';
        cssClass += this.currentStep === 4 ? 'slds-is-active' : this.currentStep > 4 ? 'slds-is-complete' : 'slds-is-incomplete';
        return cssClass;
    }

    get isPreviousDisable() {
        return this.page <= 1;
    }

    get isNextDisable() {
        return this.page >= this.totalPage;
    }
}