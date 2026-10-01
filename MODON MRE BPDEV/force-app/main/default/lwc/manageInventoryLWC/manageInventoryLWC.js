import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getBuckets from '@salesforce/apex/ManageBucketLwcController.getBuckets';
import loadInventories from '@salesforce/apex/ManageInventoryLWCController.loadInventories';
import updateUnitStatus from '@salesforce/apex/ManageInventoryLWCController.updateUnitStatus';
import getBlockingHours from '@salesforce/apex/UnitSearchLwcController.getBlockingHours';
import blockSelectedUnits from '@salesforce/apex/ManageInventoryLWCController.blockSelectedUnits';
import transferBucket from '@salesforce/apex/ManageInventoryLWCController.transferBucket';
// import updateRejectedUnits from '@salesforce/apex/ManageInventoryLWCController.updateRejectedUnits';
import fetchPhases from '@salesforce/apex/ManageInventoryLWCController.fetchPhases';
import getUnitData from '@salesforce/apex/ManageInventoryLWCController.getUnitData';
// start Reserved payment progress badge
import getReservedPaymentProgress from '@salesforce/apex/ManageInventoryLWCController.getReservedPaymentProgress';
// end Reserved payment progress badge
// start Partial booking approval
import setPartialBookingApproval from '@salesforce/apex/ManageInventoryLWCController.setPartialBookingApproval';
import getUnitsWithSalesOrder from '@salesforce/apex/ManageInventoryLWCController.getUnitsWithSalesOrder';
// end Partial booking approval
import fetchAgingColorMetadata from '@salesforce/apex/ManageInventoryLWCController.fetchAgingColorMetadata';
import isUserAllowedToEdit from '@salesforce/apex/ManageInventoryLWCController.isUserAllowedToEdit';
// Keep these if you plan to re-enable bucket mapping later
// import fetchBucketQueueMappings from '@salesforce/apex/ManageInventoryLWCController.fetchBucketQueueMappings';
// import assignUnitsToBucket from '@salesforce/apex/ManageInventoryLWCController.assignUnitsToBucket';

import { processBucketRecords } from 'c/utils';
import { ALL_COMBOBOX_OPTION } from 'c/constants';

// 2.3 - A sales agent is collecting booking fees for this unit right now. The hold is time-boxed, so an
// EXPIRED one is free - exactly how the server treats it. Only greys out the checkbox; the server guard in
// ManageInventoryLWCController is what actually enforces this.
function isPayingNow(u) {
    return u.Payment_In_Progress__c === true
        && !!u.Payment_Hold_Expiry__c
        && new Date(u.Payment_Hold_Expiry__c).getTime() > Date.now();
}

/*
  @description       : 
  @author            : ChangeMeIn@UserSettingsUnder.SFDoc
  @group             : 
  @last modified on  : 12-28-2024
  @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
  2.2 - Arvind - 28 Jun 2026 - Added disabled={unitObj.isDisabled} to active
        checkboxes in tbody so Sold and Reserved units cannot be selected.
        No other change made to this file.
  2.4 - Modon IT - 16 Jul 2026 - Added a "Payment in progress" badge to the Status
        cell. Such a unit still reads "Available" but its checkbox is greyed out,
        so the badge is what explains why.
  2.5 - Modon IT - 16 Jul 2026 - "{n}% paid" badge on a reserved but part-paid unit.
        Shown inline in the Status cell so it does not push the row height.
  2.6 - Modon IT - 16 Jul 2026 - Approve partial booking: tick reserved part-paid
        units and click "Allow Partial Booking (N)"; approved rows show Revoke.
  3.0 - Arvind - 23 Jul 2026 - Added Floor, Zone and Unit Classification filters
        (state, handlers, normalizeFilters, filterUnits, loadInventoryDetails population).
*/
export default class ManageInventoryLWC extends LightningElement {
    // ====== UI State ======
    isLoading = false;
    isScrollLoading = false;

    // Filters / selections
    selectedProject = '';
    selectedPhase = '';
    selectedBedrooms = '';
    selectedListView = '';
    selectedUnit = '';
    selectedmetaView = '';
    selectedmetaValue = '';
    isavailable = '';
    selectedsubView = 'All';
    selectedBucket = 'All';
    //selectedType = 'All';
    //selectedClassification = 'All';
    selectedFacadeStyle = 'All';

    // start 3.0 - Arvind - 23 Jul 2026 - Floor / Zone / Unit Classification filters
    selectedFloor = 'All';
    FloorOptions = [];

    selectedZone = 'All';
    ZoneOptions = [];

    selectedClassification = 'All';
    allClassification = [];
    // end 3.0

    // Buckets (filter + release flow)
    isShowBucketSelection = false;
    showReleaseOption = false;
    selectedBucketId = '';
    selectedBucketName = '';
    validBucketNames = new Set();
    bucketAssignmentOptions = [];
    // bucketOptions = []; // filter combobox (if re-enabled)

    // Blocking modal / assign flow
    showBlockRequestModal = false;
    isModalOpen = false;
    isModalAssign = false;
    selectedOption = '';
    commentValue = '';
    userOptions = [];
    selectedUserId = '';
    blockingHourOptions = [];
    selectedBlockingHours = '';

    // Errors
    errorMessage = '';
    showErrorMessage = false;
    errorMessageonpopup = false;

    // Data lists
    allListView = [];
    allProjects = [];
    //alltype = [];
    //allClassification = [];
    availablePhases = [];
    FacadeStyleOptions = [];
    UnitBedroomFilterOptions = [];
    bucketOptions = [];

    unitLst = [];               // paginated/viewport units
    allAvailUnits = [];         // full unit dataset from server (post-Apex)
    filteredUnitLst = [];       // client-side filtered list
    checkboxUnitLst = [];       // rows shown (with isSelected etc.)
    checkboxUnitLst_copy = [];  // mirror of rows for search reset
    // start Reserved payment progress badge
    paidPercentByUnit = {};     // unitId -> % of booking fee collected, for reserved-but-unpaid units only
    // end Reserved payment progress badge
    // start Partial booking approval
    approvalSelectedIds = [];   // unit ids ticked for partial-booking approval
    // end Partial booking approval

    // Sorting
    sortColumn = '';
    isAscending = true;

    // Misc UI flags
    newpick = false;       // controls unit meta filter visibility
    newcheck = false;      // controls assigned/unassigned filter visibility
    hideProjectvalue = false;
    hideProjectcolume = true;
    showdownload = false;
    showSendForRelease = false;   // show "Assign" when sub-status filter = Un-Assigned
    showSendForUnAssign = false;  // show "Un-Assign" when sub-status filter = Assigned
    isUnReleaseModalOpen = false;


    // Infinite scroll
    limit = 50;
    totalCount = 0;
    isUpdateUnitDataCall = false;

    // Other
    selectedUnitIds = [];
    colorMappings = [];
    bedroomOptionList = [];

    buttonActionName = '';

    userCanModify = '';

    // Static picklists
    SubUnitpickOptions = [
        { label: 'All', value: 'All', default: true },
        { label: 'Assigned', value: 'Assigned' },
        { label: 'Un-Assigned', value: 'Un-Assigned' }
    ];

    Assignedpicklist = [
        { label: 'Assigned', value: 'Assigned', default: true }
    ];

    UnitpiclistOptions = [];

    // record picker filter
    userIdFilter = '';
    filter = {
        criteria: [{ fieldPath: 'IsActive', operator: 'eq', value: true }]
    };


    // ====== Lifecycle ======
    connectedCallback() {
        this.checkUser();
        this.loadInventoryDetails();
        this.loadBucketOptionsForFilter(); // currently stubbed
    }

    // ====== Derived Getters ======
    get priceColumnName() {
        return this.isWadeemProject ? 'Base Price' : 'Price';
    }
    get isWadeemProject() {
        return this.allProjects?.find(p => p.value === this.selectedProject)?.label === 'Wadeem';
    }
    get showUnitData() {
        return Array.isArray(this.checkboxUnitLst) && this.checkboxUnitLst.length > 0;
    }
    get disableSendForApproval() {
        return !(this.selectedUnitIds.length > 0);
    }
    get showAllInventories() {
        return this.selectedListView === 'All';
    }
    get rejectedListViewSelected() {
        return this.selectedListView === 'Rejected';
    }
    get showSendForApproval() {
        return this.selectedListView === 'Draft';
    }
    get showAwaitingApproval() {
        return this.selectedListView === 'Awaiting Approval';
    }
    get showReleasedInventories() {
        return this.selectedListView === 'Released';
    }
    get showUnReleasedInventories() {
        return this.selectedListView === 'UnReleased';
    }
    get showManageInventory() {
        return this.selectedListView === 'Manage Inventory';
    }
    get showBlockingHours() {
        return Array.isArray(this.blockingHourOptions) && this.blockingHourOptions.length > 0;
    }
    get sortingIcon() {
        return this.isAscending ? 'utility:arrowdown' : 'utility:arrowup';
    }

    get directSaveBucket() {
        return this.isTransferModelOpen || this.isUnReleaseModalOpen;
    }

    get showBucketFilter(){
        return (this.selectedListView == 'Released' || this.selectedListView == 'UnRelease');
    }

    // ====== Normalizers ======
    // 3.0 - Arvind - 23 Jul 2026 - added floor/zone/unitClassification normalization
    normalizeFilters() {
        const projectName = (!this.selectedProject || this.selectedProject === 'All') ? null : this.selectedProject;
        const phaseId     = (!this.selectedPhase   || this.selectedPhase   === 'All') ? null : this.selectedPhase;
        const bedroomName = (!this.selectedBedrooms|| this.selectedBedrooms=== 'All') ? null : this.selectedBedrooms;
        const bucket      = (!this.selectedBucket  || this.selectedBucket  === 'All') ? null : this.selectedBucket;

        const statusvalues = (this.selectedListView === 'All') ? null : this.selectedListView; // Draft | UnReleased | Released | null
        const unitstatus   = (this.selectedmetaView && this.selectedmetaView !== 'All') ? this.selectedmetaView : null;
        const unitassigned = (this.isavailable && this.isavailable !== 'All') ? this.isavailable : null;
        //const unitType = (!this.selectedType || this.selectedType === 'All') ? null : this.selectedType;
        //const unitClassification = (!this.selectedClassification || this.selectedClassification === 'All') ? null : this.selectedClassification;
        const unitFacadeStyle = (!this.selectedFacadeStyle || this.selectedFacadeStyle === 'All') ? null : this.selectedFacadeStyle;

        // start 3.0 - Arvind - 23 Jul 2026
        const floorNumber = (!this.selectedFloor || this.selectedFloor === 'All') ? null : this.selectedFloor;
        const zone = (!this.selectedZone || this.selectedZone === 'All') ? null : this.selectedZone;
        const unitClassification = (!this.selectedClassification || this.selectedClassification === 'All') ? null : this.selectedClassification;
        // end 3.0

        return { projectName, phaseId, bedroomName, statusvalues, unitstatus, unitassigned, bucket, unitFacadeStyle, floorNumber, zone, unitClassification };
    }

    // ====== Data Loading ======
    loadInventoryDetails(isScrollCall = false) {
        this.isLoading = !isScrollCall;
        this.isScrollLoading = isScrollCall;

        loadInventories()
            .then(data => {
                this.totalCount = data?.unitLst?.length || 0;

                const initialList = (data?.unitLst || []).slice(0, 50);
                // 🔧 Map to {label,value} if server returns strings
                const rawLV = Array.isArray(data.allListView) ? data.allListView : [];
                const asObjects = rawLV.length && typeof rawLV[0] === 'object' && ('label' in rawLV[0]) && ('value' in rawLV[0]);

                this.allListView = asObjects
                    ? rawLV
                    : (rawLV.length
                        ? rawLV.map(v => ({ label: v, value: v }))
                        : [{ label: 'All', value: 'All' }]
                    );

                // Ensure selectedListView matches an available option
                const serverSelected = data.selectedListView || 'All';
                const hasServerSelected = this.allListView.some(o => o.value === serverSelected);
                this.selectedListView = hasServerSelected ? serverSelected : this.allListView[0].value;
                
                this.picklistOptions = (Array.isArray(data.metaoptions) && data.metaoptions.length)
                ? data.metaoptions
                : [
                    { label: 'Available', value: 'Available' },
                    { label: 'Assigned',  value: 'Assigned'  },
                    { label: 'Blocked',   value: 'Blocked'   },
                    ];

                // Ensure the modal has a selected value ready
                if (!this.selectedOption) {
                    this.selectedOption = '';
                }

                this.UnitpiclistOptions = data.unitStatusoptions || [];
                this.allProjects = data.availableProjects || [];
                this.selectedProject = data.selectedProjects || (this.allProjects[0]?.value || '');
                //this.alltype = data.unitTypeFilters || [];
                //this.allClassification = data.unitClassificationFilters || [];
                this.unitLst = initialList;
                this.FacadeStyleOptions = data.facadeStyleFilters || [];
                this.UnitBedroomFilterOptions = data.bedroomoptions || [];
                this.setAvailableBedrooms();

                this.selectedmetaView = this.UnitpiclistOptions.length > 0 ? this.UnitpiclistOptions[0].value : '';

                // start 3.0 - Arvind - 23 Jul 2026 - Floor / Zone / Unit Classification options from server
                this.FloorOptions = [{ label: 'All', value: 'All' }, ...(data.floorOptions || [])];
                this.selectedFloor = 'All';

                this.allClassification = [{ label: 'All', value: 'All' }, ...(data.unitClassificationOptions || [])];
                this.selectedClassification = 'All';

                this.ZoneOptions = [{ label: 'All', value: 'All' }, ...((data.zoneOptions || []).map(z => ({ label: z, value: z })))];
                this.selectedZone = 'All';
                // end 3.0

                this.allAvailUnits = JSON.parse(JSON.stringify(initialList));
                this.handleUnitList();
                // start Reserved payment progress badge
                this.loadPaymentProgress();
                // end Reserved payment progress badge
                this.showdownload = true;

                if (this.selectedProject) {
                    this.fetchAndSetPhases(this.selectedProject);
                }

                if (Array.isArray(data?.buckets)) {
                    this.bucketOptions = data?.buckets?.map(bucket => ({ label: bucket?.Name, value: bucket?.Id }));
                    this.bucketOptions.unshift(ALL_COMBOBOX_OPTION);
                }


                this.isLoading = false;
                this.isScrollLoading = false;
                this.limit += 50;
            })
            .catch(() => {
                this.isLoading = false;
                this.isScrollLoading = false;
                this.toast('Error', 'Failed to load inventories.', 'error');
            });
    }


    fetchAndSetPhases(projectName) {
        this.isLoading = true;
        fetchPhases({ projectName })
            .then(phases => {
                this.availablePhases = [
                    { label: 'All', value: 'All' },
                    ...(phases || []).map(p => ({ label: p.Name, value: p.Id }))
                ];
                this.selectedPhase = this.availablePhases[0]?.value || 'All';
                this.updateUnitData();
            })
            .catch(() => {})
            .finally(() => { this.isLoading = false; });
    }

    updateUnitData(isBedroomChange = false, isScrollCall = false) {
        this.isUpdateUnitDataCall = true;
        if (!isBedroomChange) this.bedroomOptionList = [];
        this.isScrollLoading = isScrollCall;

        const params = this.normalizeFilters();
        getUnitData(params)
            .then(data => {
                this.isLoading = !isScrollCall;
                const list = data || [];
                this.totalCount = list.length;
                this.allAvailUnits = JSON.parse(JSON.stringify(list));

                // Client filtering (kept for parity with existing logic)
                this.filteredUnitLst = this.filterUnits(list);
                this.unitLst = this.filteredUnitLst.slice(0, this.limit);

                this.handleUnitList();   // builds checkboxUnitLst
                this.searchdata();       // reapplies search if any
                // start Reserved payment progress badge
                this.loadPaymentProgress();
                // end Reserved payment progress badge
                this.showdownload = true;

                if (!isScrollCall) this.selectedUnit = '';
                if (!list.length) this.toast('Info', 'No units found for the selected filters.', 'info');

                this.isLoading = false;
                this.isScrollLoading = false;
                this.limit += 50;
            })
            .catch(err => {
                this.isLoading = false;
                this.isScrollLoading = false;
                const msg = err?.body?.message || err?.message || 'Failed to load units. Check Apex logs.';
                this.toast('Error', `getUnitData: ${msg}`, 'error');
            });
    }

    // ====== Aging color mapping ======
    fetchAgingColorMetadata() {
        fetchAgingColorMetadata()
            .then((data) => {
                this.colorMappings = (data || []).map(m => ({
                    minDays: m.Min_Days__c,
                    maxDays: m.Max_Days__c,
                    colorCode: m.Color_Code__c
                }));

                const styleFor = (u) => {
                    const color = this.getColorForAging(u.Aging__c);
                    return `background-color: ${color}; border-radius: 50%; width: 20px; height: 20px;`;
                };

                if (Array.isArray(this.checkboxUnitLst) && this.colorMappings.length > 0) {
                    this.checkboxUnitLst = this.checkboxUnitLst.map(u => ({ ...u, colorStyle: styleFor(u) }));
                }
                if (Array.isArray(this.allAvailUnits) && this.colorMappings.length > 0) {
                    this.allAvailUnits = this.allAvailUnits.map(u => ({ ...u, colorStyle: styleFor(u) }));
                }
            })
            .catch(() => {
                // swallow quietly; not critical
            });
    }

    getColorForAging(aging) {
        if (aging === 'Not yet Released') return 'gray';
        const agingNumber = this.extractNumericValue(aging);
        if (agingNumber !== null) {
            for (const r of this.colorMappings) {
                if (agingNumber >= r.minDays && (r.maxDays === null || agingNumber <= r.maxDays)) {
                    return r.colorCode;
                }
            }
        }
        return 'gray';
    }

    extractNumericValue(aging) {
        const match = (aging || '').match(/^(\d+)\s*days$/);
        return match ? parseInt(match[1], 10) : null;
    }

    // ====== Filters / Handlers ======
    handleListViewChange(event) {
        const newVal = event?.detail?.value;
        if (typeof newVal === 'undefined') {
            this.toast('Error', 'Invalid Inventory Status option.', 'error');
            return;
        }

        this.isLoading = true;
        this.selectedListView = newVal;
        this.limit = 50;

        // reset these on every inventory status change
        this.showSendForRelease = false;
        this.showSendForUnAssign = false;

        // Only show the meta/assignment pickers for Released
        if (this.selectedListView === 'Released') {
            this.newpick = true;
            this.UnitpiclistOptions = (this.UnitpiclistOptions || []).filter(opt => opt.value !== 'UnReleased');
            this.selectedmetaView = this.UnitpiclistOptions[0].value;
        } else {
            this.newpick = false;
            this.newcheck = false;
            this.selectedmetaView = '';
            this.selectedmetaValue = '';
            this.isavailable = '';
        }

        this.updateUnitData();
        this.handleDeSelectAll();
    }

    handleMetaViewChange(event) {
        this.isLoading = true;
        this.selectedmetaView = event.detail.value;

        this.showSendForRelease = false;
        this.showSendForUnAssign = false;

        this.selectedmetaValue = (this.selectedmetaView === 'All') ? '' : this.selectedmetaView;
        this.newcheck = (this.selectedmetaView === 'Available');
        if (!this.newcheck) this.isavailable = '';

        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }

    handleAssignedChange(event) {
        const val = event.detail.value;
        if (val === 'All') {
            this.isavailable = '';
            this.showSendForRelease = false;
            this.showSendForUnAssign = false;
        } else {
            this.isavailable = val;
            // If Un-Assigned, show the "Assign" action
            this.showSendForRelease = (val === 'Un-Assigned');

            // If Assigned, show the "Un-Assign" action
            this.showSendForUnAssign = (val === 'Assigned');
        }
        this.getselectedUnitIds();
        this.handleDeSelectAll();
        this.updateUnitData();
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value;

        if (this.selectedProject !== 'All') {
            this.hideProjectvalue = true;
            this.hideProjectcolume = false;
        } else {
            this.hideProjectvalue = false;
            this.hideProjectcolume = true;
        }
        this.limit = 50;
        this.fetchAndSetPhases(this.selectedProject);
        this.handleDeSelectAll();
    }

    handlePhaseChange(event) {
        this.isLoading = true;
        this.selectedPhase = event.detail.value;
        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }
    handleFacadeStyleChange(event){
        this.isLoading = true;
        this.selectedFacadeStyle = event.detail.value;
        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }
    handleBucketChange(event) {
        this.isLoading = true;
        this.selectedBucket = event.detail.value;
        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }

    // start 3.0 - Arvind - 23 Jul 2026 - Floor / Zone / Unit Classification handlers
    handleFloorChange(event) {
        this.isLoading = true;
        this.selectedFloor = event.detail.value;
        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }

    handleZoneChange(event) {
        this.isLoading = true;
        this.selectedZone = event.detail.value;
        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }

    handleUnitClassificationChange(event) {
        this.isLoading = true;
        this.selectedClassification = event.detail.value;
        this.limit = 50;
        this.updateUnitData();
        this.handleDeSelectAll();
    }
    // end 3.0

    // Bedrooms
    setAvailableBedrooms() {
        if (Array.isArray(this.UnitBedroomFilterOptions) && this.UnitBedroomFilterOptions.length > 0) {
            this.UnitBedroomFilterOptions = [{ label: 'All', value: 'All' }, ...this.UnitBedroomFilterOptions];
            this.selectedBedrooms = this.UnitBedroomFilterOptions[0].value || 'All';
        } else {
            this.UnitBedroomFilterOptions = [{ label: 'All', value: 'All' }];
            this.selectedBedrooms = 'All';
        }
    }

    handleBedroomChange(event) {
        this.selectedBedrooms = event.detail.value;
        this.bedroomOptionList = JSON.parse(JSON.stringify(this.bedroomOptions));
        this.limit = 50;
        this.updateUnitData(true);
        this.handleDeSelectAll();
    }
    get bedroomOptions() {
        if (this.bedroomOptionList?.length > 0) return this.bedroomOptionList;
        const uniques = (this.checkboxUnitLst || [])
            .filter(u => u?.Number_of_Bedrooms__c)
            .map(u => u.Number_of_Bedrooms__c)
            .filter((v, i, self) => v && self.indexOf(v) === i)
            .sort((a, b) => a - b);

        return [{ label: 'All', value: 'All' }, ...uniques.map(v => ({ label: String(v), value: String(v) }))];
    }

    // Search
    handleUnitSerchChange(event) {
        this.isLoading = true;
        this.selectedUnit = (event.detail.value || '').toLowerCase();
        this.searchdata();
        this.getselectedUnitIds();
    }

    searchdata() {
        if (this.selectedUnit) {
            const filterUnits = (this.allAvailUnits || []).filter(rec =>
                rec.Name?.toLowerCase().includes(this.selectedUnit) ||
                rec.BlockComment__c?.toLowerCase().includes(this.selectedUnit)
            );
            this.checkboxUnitLst = JSON.parse(JSON.stringify(filterUnits));
        } else {
            this.checkboxUnitLst = this.checkboxUnitLst_copy || [];
        }
        this.isLoading = false;
        this.fetchAgingColorMetadata();
    }

    // start Reserved payment progress badge
    // Fetch the paid % for reserved part-paid units and patch the badge onto the rows in place.
    loadPaymentProgress() {
        const ids = (this.allAvailUnits || []).map(u => u.Id);
        if (!ids.length) { this.paidPercentByUnit = {}; return; }
        Promise.all([
            getReservedPaymentProgress({ unitIds: ids }),
            getUnitsWithSalesOrder({ unitIds: ids })
        ])
            .then(([map, bookedIds]) => {
                this.paidPercentByUnit = map || {};
                const bookedSet = new Set(bookedIds || []);
                const patch = (u) => ({
                    ...u,
                    paidPercent: this.paidPercentByUnit[u.Id],
                    // one pill once reserved - the % shows whether the hold is live or expired
                    isPartiallyPaid: this.paidPercentByUnit[u.Id] != null,
                    // start Partial booking approval
                    // approved, and not yet booked - drop the indicator once a live Sales Order exists
                    partialApproved: u.Allow_Partial_Booking__c === true && !bookedSet.has(u.Id),
                    canApprovePartial: this.paidPercentByUnit[u.Id] != null && u.Allow_Partial_Booking__c !== true,
                    approvalSelected: this.approvalSelectedIds.includes(u.Id)
                    // end Partial booking approval
                });
                this.allAvailUnits  = (this.allAvailUnits  || []).map(patch);
                this.checkboxUnitLst = (this.checkboxUnitLst || []).map(patch);
            })
            .catch(() => { this.paidPercentByUnit = {}; });
    }
    // end Reserved payment progress badge

    // start Partial booking approval
    get showApproveButton() {
        return this.approvalSelectedIds.length > 0;
    }
    get approveButtonLabel() {
        return 'Allow Partial Booking (' + this.approvalSelectedIds.length + ')';
    }

    // Tick / untick a reserved-part-paid unit for approval, then re-mark the rows so the checkbox stays in sync.
    handleApprovalSelect(event) {
        const id = event.target.dataset.id;
        const sel = new Set(this.approvalSelectedIds);
        if (event.target.checked) { sel.add(id); } else { sel.delete(id); }
        this.approvalSelectedIds = [...sel];
        const mark = (u) => ({ ...u, approvalSelected: sel.has(u.Id) });
        this.checkboxUnitLst = (this.checkboxUnitLst || []).map(mark);
        this.allAvailUnits = (this.allAvailUnits || []).map(mark);
    }

    handleApprovePartial() {
        this.setApproval([...this.approvalSelectedIds], true);
    }

    handleRevokePartial(event) {
        this.setApproval([event.target.dataset.id], false);
    }

    // Set/clear Allow_Partial_Booking__c on the units, then refresh so the grid re-derives the approval state.
    setApproval(unitIds, allow) {
        if (!unitIds.length) { return; }
        setPartialBookingApproval({ unitIds, allow })
            .then(data => {
                if (data && data.isSuccess) {
                    this.toast('Done', allow ? 'Partial booking approved.' : 'Approval revoked.', 'success');
                    this.approvalSelectedIds = [];
                    this.updateUnitData();
                } else {
                    this.toast('Error', (data && data.errorMsg) || 'Could not update the approval.', 'error');
                }
            })
            .catch(() => this.toast('Error', 'Could not update the approval.', 'error'));
    }
    // end Partial booking approval

    // ====== Row build / selection ======
    handleUnitList() {
        const getBucketName = (u) => (u.Owner?.Name && this.validBucketNames.has(u.Owner.Name)) ? u.Owner.Name : '';

        // 2.2 - Arvind - 28 Jun 2026
        // Added isDisabled flag: any unit with Status__c === 'Sold' or 'Reserved'
        // will have isDisabled = true. The HTML template binds this to the checkbox
        // disabled attribute so the manager cannot select those units.
        // 2.3 - Also disable a unit an agent is currently collecting booking fees for, so it cannot be
        // pulled back mid-payment. Server-side guard in ManageInventoryLWCController is the enforcement.
        // 2.4 - isPaymentInProgress drives the badge: such a unit still reads "Available", so the greyed
        // checkbox needs a visible reason. Set on both lists - searchdata() rebuilds checkboxUnitLst from
        // allAvailUnits, so a flag on one list only would vanish when the admin searches by unit name.
        this.checkboxUnitLst = (this.unitLst || []).map(u => ({
            ...u,
            isSelected: false,
            isDisabled: u.Status__c === 'Sold' || u.Status__c === 'Reserved' || isPayingNow(u), // 2.2 Arvind, 2.3
            isPaymentInProgress: isPayingNow(u) && u.Status__c !== 'Reserved', // 2.4 (before reserved only; reserved shows the % pill)
            bucketName: getBucketName(u)
        }));

        this.allAvailUnits = (this.allAvailUnits || []).map(u => ({
            ...u,
            isSelected: false,
            isDisabled: u.Status__c === 'Sold' || u.Status__c === 'Reserved' || isPayingNow(u), // 2.2 Arvind, 2.3
            isPaymentInProgress: isPayingNow(u) && u.Status__c !== 'Reserved', // 2.4 (before reserved only; reserved shows the % pill)
            bucketName: getBucketName(u)
        }));
        this.checkboxUnitLst_copy = this.checkboxUnitLst;
        this.fetchAgingColorMetadata();
    }

    getselectedUnitIds() {
        const selected = [];
        (this.checkboxUnitLst || []).forEach(u => { if (u.isSelected) selected.push(u.Id); });
        this.selectedUnitIds = selected;
    }

    handleSelectAll() {
        const boxes = this.template.querySelectorAll('lightning-input.rowSelector');
        const ids = [];
        boxes.forEach(b => { if (!b.disabled) { b.checked = true; ids.push(b.dataset.id); } });

        const setTrue = (u) => ids.includes(u.Id) ? { ...u, isSelected: true } : u;
        this.checkboxUnitLst = (this.checkboxUnitLst || []).map(setTrue);
        this.checkboxUnitLst_copy = (this.checkboxUnitLst_copy || []).map(setTrue);
        this.allAvailUnits = (this.allAvailUnits || []).map(setTrue);
        this.getselectedUnitIds();
    }

    handleDeSelectAll() {
        const boxes = this.template.querySelectorAll('lightning-input.rowSelector');
        const ids = [];
        boxes.forEach(b => { if (!b.disabled) { b.checked = false; ids.push(b.dataset.id); } });

        const setFalse = (u) => ids.includes(u.Id) ? { ...u, isSelected: false } : u;
        this.checkboxUnitLst = (this.checkboxUnitLst || []).map(setFalse);
        this.checkboxUnitLst_copy = (this.checkboxUnitLst_copy || []).map(setFalse);
        this.allAvailUnits = (this.allAvailUnits || []).map(setFalse);
        this.getselectedUnitIds();
    }

    handleRowSelect(event) {
        this.isLoading = true;
        const id = event.target.dataset.id;
        const isChecked = event.target.checked;

        const apply = (u) => u.Id === id ? { ...u, isSelected: isChecked } : u;
        this.allAvailUnits = (this.allAvailUnits || []).map(apply);
        this.checkboxUnitLst_copy = (this.checkboxUnitLst_copy || []).map(apply);
        this.checkboxUnitLst = (this.checkboxUnitLst || []).map(apply);

        this.getselectedUnitIds();
        this.isLoading = false;
    }

    // ====== Scrolling ======
    handleScroll(event) {
        const el = event.target;
        const threshold = 30;
        const hasMoreToLoad = (this.unitLst?.length || 0) < (this.filteredUnitLst.length || 0);
        const isNearBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - threshold;

        if (hasMoreToLoad && isNearBottom) {
            if (this.isUpdateUnitDataCall) {
                this.updateUnitData(false, true);   // scroll call
            } else {
                this.loadInventoryDetails(true);
            }
        }
    }

    // ====== Client Filter ======
    // 3.0 - Arvind - 23 Jul 2026 - Floor / Zone / Unit Classification client-side filter
    filterUnits(units) {
        const listView = this.selectedListView; // values: All, Draft, UnReleased, Released
        const phaseId  = this.selectedPhase;
        const bedrooms = this.selectedBedrooms;
        const floor = this.selectedFloor;
        const zone = this.selectedZone;
        const classification = this.selectedClassification;

        return (units || []).filter(unit => {
            let matchesListView = true;

            if (listView && listView !== 'All') {
            switch (listView) {
                case 'Draft':
                matchesListView = unit.ApprovalStatus__c === 'Draft';
                break;

                case 'UnReleased':
                // Your UnRelease action sets both ApprovalStatus__c and Status__c to 'UnReleased'
                // Use either-or in case only one is set by data.
                matchesListView = (unit.ApprovalStatus__c === 'UnReleased');
                break;

                case 'Released':
                matchesListView =
                    unit.ApprovalStatus__c === 'Released' &&
                    ['Available','Sold','CCMD','Reserved'].includes(unit.Status__c);
                break;

                default:
                matchesListView = true;
            }
            }

            const matchesPhase   = (!phaseId || phaseId === 'All') ? true : (unit.Phase__c === phaseId);
            const matchesBedroom = (!bedrooms || bedrooms === 'All') ? true : (String(unit.Number_of_Bedrooms__c) === String(bedrooms));
            // start 3.0
            // NOTE: the org's actual field API name is lowercase "floor__c" (see Object Manager),
            // so the JS property must match that exact casing - Apex/SOQL is case-insensitive but
            // the JSON returned to the client is not.
            const matchesFloor = (!floor || floor === 'All') ? true : (String(unit.floor__c) === String(floor));
            const matchesZone = (!zone || zone === 'All') ? true : (unit.Zone__c === zone);
            const matchesClassification = (!classification || classification === 'All') ? true : (unit.UnitClassification__c === classification);
            // end 3.0

            return matchesListView && matchesPhase && matchesBedroom && matchesFloor && matchesZone && matchesClassification;
        });
    }

    // ====== Comment/Modal ======
    updateCommentValue(event) {
        this.commentValue = event.target.value;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isLoading = false;
        this.commentValue = '';
        this.selectedOption = '';
        this.isModalAssign = false;
        this.isUnReleaseModalOpen = false;
        this.isTransferModelOpen = false;

        document.body.style.overflow = '';
        this.resetErrorState();
    }

    // ====== Actions ======
    async handleButtonAction(event) {
        const actionName = event.target.name;

        let unitApprovalStatus = '';
        let unitStatus = '';

        this.buttonActionName = actionName;
        switch (actionName) {
            case 'Transfer Bucket':
                this.isTransferModelOpen = true;
                this.handleChangeBucket();
                return;
            case 'UnRelease':
                // unitApprovalStatus = 'UnReleased';
                // unitStatus = 'UnReleased';

                if (this.selectedListView == 'Draft') {
                    this.isUnReleaseModalOpen = true;
                    this.handleReleaseAction();
                } else {
                    this.updateUnitStatus('UnReleased', 'UnReleased');
                }
                
                break;
            case 'Back to Draft':
                unitApprovalStatus = 'Draft';
                unitStatus = '';
                break;
            case 'UnAssign':
                unitApprovalStatus = 'Released';
                unitStatus = 'Available';
                break;
            case 'Submit':
                this.handleSubmitAction();
                return;
            case 'Release':
                this.handleReleaseAction();
                return;
            case 'Assign':
                await this.handleAssignAction();
                return;
            default:
                break;
        }

        if ((actionName === 'Back to Draft' || actionName === 'UnAssign') && actionName !== 'UnRelease' && actionName !== 'Release') {
            this.updateUnitStatus(unitApprovalStatus, unitStatus);
            this.getselectedUnitIds();
            this.selectedUnitIds = [];
        }

        if (this.isModalOpen && actionName !== 'Release' && actionName !== 'UnRelease') {
            this.closeModal();
            this.getselectedUnitIds();
            this.selectedUnitIds = [];
        }
    }

    handleChangeBucket(){
        this.isModalOpen = true;
        this.isShowBucketSelection = true;
        this.isUnReleaseModalOpen = true;
        this.showReleaseOption = false;
        //this.isTransferModelOpen = true;
    }

    handleTransferBucket() {
        this.closeModal();
        this.isLoading = true;
        transferBucket({
            unitIds: this.selectedUnitIds,
            bucketId: this.selectedBucketId
        })
        .then(data => {
            if (data.isSuccess) {
                this.toast('Success', 'Unit status is successfully updated!', 'success');
                this.updateUnitData();
                this.handleDeSelectAll();
            } else {
                this.rejectSelection(data); // 2.3 - e.g. a unit is being paid for
            }
        })
        .catch(() => {
            this.toast('Error', 'Failed to update unit status.', 'error');
        })
        .finally(() => (this.isLoading = false));
    }

    handleSubmitAction() {
        this.resetErrorState();
        this.isLoading = true;

        const isAssigned = this.selectedOption === 'Assigned';
        if (!this.selectedOption) {
            this.showError('Please select a status');
            return;
        }

        if (isAssigned) {
            if (!this.commentValue) {
                this.showError('Please enter comment');
                return;
            }
            if (!this.selectedUserId) {
                this.showError('Please select the blocking User');
                return;
            }
            this.saveBlockUnits();
        } else {
            const unitApprovalStatus = this.isUnReleaseModalOpen ? 'UnReleased' : 'Released';
            const unitStatus = this.isUnReleaseModalOpen ? 'UnReleased' : this.selectedOption;
            this.updateUnitStatus(unitApprovalStatus, unitStatus);
        }

        if (!this.showErrorMessage && this.isModalOpen) {
            this.closeModal();
            this.getselectedUnitIds();
            this.selectedUnitIds = [];
        }

        this.isLoading = false;
    }

    handlePicklistChange(event) {
        this.selectedOption = event.detail.value;

        if (this.selectedOption === 'Assigned') {
            this.showBlockRequestModal = true;
            this.loadBlockingHours();
        } else {
            this.showBlockRequestModal = false;
        }
    }

    handleReleaseAction() {
        this.openReleaseModal('Available'); // uses first picklist option by default
    }

    // make Assign use the exact same modal, but preselect "Assigned"
    async handleAssignAction() {
        await this.openReleaseModal('Assigned');
    }

    async openReleaseModal(defaultStatus) {
        // pick a status (default or first option)
        this.selectedOption = defaultStatus ?? (this.picklistOptions[0]?.value || '');

        // show/hide the block UI based on status
        this.showBlockRequestModal = (this.selectedOption === 'Assigned');
        if (this.showBlockRequestModal) this.loadBlockingHours();

        // open the same modal path as Release
        this.isShowBucketSelection = !this.showUnReleasedInventories;
        if ((this.showReleasedInventories && this.buttonActionName == 'Assign') || (this.showUnReleasedInventories && this.buttonActionName == 'Release')) {
            this.isShowBucketSelection = false;
            const selectedUnit = this.checkboxUnitLst.filter(unit => unit.isSelected);
            const bucketIds = new Set(selectedUnit.map(u => u.Bucket__c));
            if (bucketIds.size > 1) {
                this.toast('Error', 'Please select units with identical bucket', 'error');
                return;
            }

            this.selectedBucketId = selectedUnit[0]?.Bucket__c;
            this.selectedBucketName = selectedUnit[0]?.Bucket__r?.Name;
            await this.loadBuckets();
        }

        this.releaseOptionOfUnreleased = (this.showUnReleasedInventories && this.buttonActionName == 'Release')  || (this.showReleasedInventories && this.buttonActionName == 'Assign');
        this.showReleaseOption = this.releaseOptionOfUnreleased;    // then status/user/comment screen after bucket
        
        this.isModalOpen = true;
        document.body.style.overflow = 'hidden';
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });  
    }

    manageBlockingHours(event) {
        this.selectedBlockingHours = event.detail?.value || ''; // lightning-combobox uses event.detail.value
    }

    // handleReleaseAction() {
    //     this.selectedOption = '';
    //     this.showBlockRequestModal = (this.selectedOption === 'Assigned');
    //     if (this.showBlockRequestModal) this.loadBlockingHours();
    //     this.isModalOpen = true;
    //     this.isShowBucketSelection = true;
    //     this.showReleaseOption = false;
    // }

    // handleAssignAction() {
    //     this.selectedOption = 'Assigned';
    //     this.isModalOpen = true;
    //     this.showBlockRequestModal = true;
    //     this.loadBlockingHours();
    //     this.isShowBucketSelection = true;
    //     this.showReleaseOption = false;
    // }

    updateUnitStatus(unitApprovalStatus, unitStatus) {
        this.isLoading = true;

        const bucketId = this.unitApprovalStatus == 'UnRelease' ? null : this.selectedBucketId;
        updateUnitStatus({
            unitIds: this.selectedUnitIds,
            newApprovalStatus: unitApprovalStatus,
            unitStatus: unitStatus,
            comment: this.commentValue,
            bucketId
        })
            .then(data => {
                if (data.isSuccess) {
                    this.toast('Success', 'Unit status is successfully updated!', 'success');
                    this.updateUnitData();
                } else {
                    this.rejectSelection(data); // 2.3 - e.g. a unit is being paid for
                }
            })
            .catch(() => {
                this.toast('Error', 'Failed to update unit status.', 'error');
            })
            .finally(() => (this.isLoading = false));
    }

    validateBlockForm() {
        let isInvalid = false;
        const inputs = this.template.querySelectorAll('.blockDetails');
        inputs.forEach(i => {
            if (!i.checkValidity()) {
                i.reportValidity();
                isInvalid = true;
            }
        });
        if (isInvalid) this.toast('Error', 'Please review all the errors', 'error');
        return isInvalid;
    }

    saveBlockUnits() {
        this.isLoading = true;

        if (this.validateBlockForm()) {
            this.isLoading = false;
            return;
        }

        blockSelectedUnits({
            unitIds: this.selectedUnitIds,
            comment: this.commentValue,
            blockFor: this.selectedUserId,
            blockUntil: this.selectedBlockingHours,
            bucketId: this.selectedBucketId
        })
            .then(data => {
                if (data.isSuccess) {
                    this.showBlockRequestModal = false;
                    this.toast('Success', 'Units are blocked successfully!', 'success');
                    this.updateUnitData();
                } else if (data.messageVariant === 'warning') {
                    this.showBlockRequestModal = false; // 2.3 - e.g. a unit is being paid for
                    this.rejectSelection(data);
                } else {
                    this.toast('Error', data.errorMsg || 'Failed to block units.', 'error');
                }
                this.isModalAssign = false;
            })
            .catch(() => {
                this.toast('Error', 'Failed to block units.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
                this.closeModal();
            });
    }

    // ====== Helpers ======
    // 2.3 - The action was refused because something in the selection is not actionable right now (a unit is
    // being paid for). Nothing was changed. Say so politely, refresh so the grid re-evaluates isDisabled and
    // the offending rows come back greyed out, and clear the selection so the admin starts clean.
    rejectSelection(data) {
        this.toast(
            'Please recheck your selection',
            data.errorMsg || 'Some of the selected units cannot be changed right now.',
            'warning'
        );
        this.updateUnitData();
        this.handleDeSelectAll();
    }

    resetErrorState() {
        this.errorMessage = '';
        this.showErrorMessage = false;
        this.errorMessageonpopup = false;
    }

    showError(message) {
        this.showErrorMessage = true;
        this.errorMessage = message;
        this.isLoading = false;
        this.isModalOpen = true;
        this.errorMessageonpopup = true;
        this.toast('Error', message, 'error');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }

    handleLinkClick(event) {
        const unitId = event.currentTarget.getAttribute('data-id');
        window.open(`/${unitId}`, '_blank');
    }

    // ====== Sorting ======
    get sortbyProjectName() { return this.sortColumn === 'ProjectName'; }
    get sortbyUnitName() { return this.sortColumn === 'unitName'; }
    get sortbyNumberOfBedrooms() { return this.sortColumn === 'bedrooms'; }
    get sortbyPhase() { return this.sortColumn === 'phase'; }
    get sortbyTotalPrice() { return this.sortColumn === 'price'; }
    get sortbyStatus() { return this.sortColumn === 'status'; }
    get sortbyPlotArea() { return this.sortColumn === 'plotArea'; }
    get sortbyPlotNo() { return this.sortColumn === 'plotNo'; }
    get sortbyBucket() { return this.sortColumn === 'bucket'; }
    get sortbyBlockFor() { return this.showReleasedInventories && this.sortColumn === 'blockFor'; }
    get sortbyBlockUntil() { return this.showReleasedInventories && this.sortColumn === 'blockUntil'; }
    get sortbyBlockBy() { return this.showReleasedInventories && this.sortColumn === 'blockBy'; }
    get sortbyBlockTime() { return this.showReleasedInventories && this.sortColumn === 'blockTime'; }

    sortData(event) {
        const column = event.currentTarget.getAttribute('name');
        this.sortColumn = column;

        const cmp = (a, b) => {
            if (a < b) return this.isAscending ? -1 : 1;
            if (a > b) return this.isAscending ? 1 : -1;
            return 0;
        };
        const toDate = (v) => (v ? new Date(v).getTime() : 0);
        const toLower = (v) => (v || '').toString().toLowerCase();

        const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
        const cmpAlphaNum = (x, y) => this.isAscending ? collator.compare(x, y) : collator.compare(y, x);

        this.checkboxUnitLst = [...(this.checkboxUnitLst || [])].sort((a, b) => {
            let valA, valB;

            switch (column) {
                case 'ProjectName':
                    valA = toLower(a.Project_Name__c);
                    valB = toLower(b.Project_Name__c);
                    return cmp(valA, valB);

                case 'unitName':
                    valA = a.Name || '';
                    valB = b.Name || '';
                    return cmpAlphaNum(valA, valB);

                case 'phase':
                    valA = toLower(a.Phase__r?.Name);
                    valB = toLower(b.Phase__r?.Name);
                    return cmp(valA, valB);

                case 'bedrooms':
                    valA = a.Number_of_Bedrooms__c || 0;
                    valB = b.Number_of_Bedrooms__c || 0;
                    return cmp(valA, valB);

                case 'price':
                    valA = a.TotalPrice__c || 0;
                    valB = b.TotalPrice__c || 0;
                    return cmp(valA, valB);

                case 'status':
                    valA = toLower(a.Status__c);
                    valB = toLower(b.Status__c);
                    return cmp(valA, valB);

                case 'plotArea':
                    valA = a.PlotAreasqm__c || 0;
                    valB = b.PlotAreasqm__c || 0;
                    return cmp(valA, valB);

                case 'plotNo':
                    valA = a.PlotNo__c || '';
                    valB = b.PlotNo__c || '';
                    return cmpAlphaNum(valA, valB);

                case 'bucket':
                    valA = toLower(a.bucketName);
                    valB = toLower(b.bucketName);
                    return cmp(valA, valB);

                case 'blockFor':
                    valA = toLower(a.BlockedFor__r?.Name);
                    valB = toLower(b.BlockedFor__r?.Name);
                    return cmp(valA, valB);

                case 'blockBy':
                    valA = toLower(a.BlockedBy__r?.Name);
                    valB = toLower(b.BlockedBy__r?.Name);
                    return cmp(valA, valB);

                case 'blockUntil':
                    valA = toDate(a.BlockUntil__c);
                    valB = toDate(b.BlockUntil__c);
                    return cmp(valA, valB);

                case 'blockTime':
                    valA = toDate(a.Blocked_Time__c);
                    valB = toDate(b.Blocked_Time__c);
                    return cmp(valA, valB);

                case 'blockComment':
                    valA = a.BlockComment__c || '';
                    valB = b.BlockComment__c || '';
                    return cmpAlphaNum(valA, valB);

                default:
                    return 0;
            }
        });

        this.isAscending = !this.isAscending;
    }

    // ====== Export ======
    handleExportDocment() {
    
        // Mapping headers to display names
        let headerValueMap = new Map([
            ['Project_Name__c', 'Project Name'],
            ['TotalPrice__c', 'Total Price'],
            ['Status__c', 'Status'],
            ['Name', 'Name'],
            ['ApprovalStatus__c', 'Inventory Status'],
            ['Number_of_Bedrooms__c', 'Number of Bedrooms'],
            ['PlotNo__c', 'Plot No'],
            ['Phase__r', 'Phase'],
            ['BlockedFor__r', 'Blocked For'],
            ['Aging__c', 'Aging'],
            ['Blocked_Time__c', 'Blocked Time'],
            ['BlockUntil__c', 'Block Until'],
            ['BlockedBy__r', 'Blocked By'],
            ['PlotAreasqm__c', 'Plot Area'],
            ['Status_Change_Time__c', 'Status Change Time'],
            ['IsUnitAvailable__c ','IsUnitAvailable ']
        ]);
    
        const excludedColumns = ['Id', 'Phase__c', 'BlockedFor__c', 'BlockedBy__c', 'isSelected', 'colorStyle'];
    
        // Extract all unique headers from the entire unitLst
        let headers = Array.from(
            new Set(
                this.checkboxUnitLst.flatMap(record => Object.keys(record))
            )
        ).filter(header => !excludedColumns.includes(header));
    
        // Start creating the table
        let csvData = '<table border="1">';
    
        // Header Row
        csvData += '<tr>';
        headers.forEach(header => {
            let displayName = headerValueMap.get(header) || header;
            csvData += `<th>${displayName}</th>`;
        });
        csvData += '</tr>';
    
        // Data Rows
        this.checkboxUnitLst.forEach(record => {
            csvData += '<tr>';
            headers.forEach(header => {
                let value = record;
                let keys = header.split('.');
    
                // Traverse nested objects to get the value
                keys.forEach(key => {
                    value = value ? value[key] : undefined;
                });
    
                if (typeof value === 'object' && value !== null) {
                    value = value.Name ? value.Name : '';
                }
    
                // Ensure empty cells for undefined/null
                csvData += `<td>${value !== undefined && value !== null ? value : ''}</td>`;
            });
            csvData += '</tr>';
        });
    
        csvData += '</table>';
    
    
        // Create a Blob from the CSV data
        const blob = new Blob([csvData], { type: 'text/csv' });
    
        // Prepare for download
        var element = 'data:application/vnd.ms-excel,' + encodeURIComponent(csvData);
        let downloadElement = document.createElement('a');
        downloadElement.href = element;
        downloadElement.target = '_self';
        downloadElement.download = 'Units.xls';
        document.body.appendChild(downloadElement);
        downloadElement.click();
    }

    // ====== Blocking hours loader ======
    loadBlockingHours() {
        this.blockingHourOptions = [];
        getBlockingHours()
            .then(data => {
                this.isLoading = true;
                this.blockingHourOptions = data || [];
                this.selectedBlockingHours = (this.blockingHourOptions[0]?.value) || '';
            })
            .catch(() => {})
            .finally(() => { this.isLoading = false; });
    }

    // ====== Buckets (stubbed – re-enable when needed) ======
    loadBucketOptionsForFilter() {
        // Example:
        // fetchBucketQueueMappings().then(data => {
        //   this.bucketOptions = [{ label: 'All', value: 'All' },
        //     ...data.filter(m => m.bucketName !== 'ALL').map(m => ({ label:m.bucketName, value:m.bucketName }))];
        //   this.validBucketNames = new Set(data.map(m => m.bucketName));
        // });
    }

    handleBack() {
        this.isShowBucketSelection = true;
        this.showReleaseOption = false;
    }

    handleBucketSelection(event) {
        const { bucketId, bucketName, selectedAssignment } = event.detail;

        this.selectedBucketId = bucketId;
        this.selectedBucketName = bucketName;
        if (this.isTransferModelOpen) {
            this.handleTransferBucket();
        } else if (this.isUnReleaseModalOpen) {
            this.updateUnitStatus('UnReleased', 'UnReleased');
            this.closeModal();
        } else {
            this.userOptions = (selectedAssignment || []).map(a => ({ label: a.Name, value: a.userId }));
            this.selectedUserId = this.userOptions[0]?.value || '';
            this.showReleaseOption = true;
            this.isShowBucketSelection = false;
        }

        
    }

    handleUserChange(event) {
        this.selectedUserId = event.detail.value;
    }

    async loadBuckets() {
        this.isLoading = true;
        try {
            const data = await getBuckets();
            const assignments = (data || [])?.find(bucket => bucket.bucketObj?.Id === this.selectedBucketId)?.baLst || [];
            const userAssignments = assignments?.map(ba => ({
                ...ba.UserOrGroup,
                userId: ba.UserOrGroupId,
                profileName: ba.UserOrGroup?.Profile?.Name,
            }));

            const processedData = processBucketRecords(userAssignments);
            this.userOptions = (processedData || []).map(a => ({ label: a.Name, value: a.userId }));
            this.selectedUserId = this.userOptions[0]?.value || '';

        } catch (e) {
            console.error('[Buckets Load Error]', e);
        } finally {
            this.isLoading = false;
        }
    }

    checkUser(){
        isUserAllowedToEdit()
        .then(result => {
            this.userCanModify = result;
        })
        .catch(error => {
            console.error(error);
        });
    }}