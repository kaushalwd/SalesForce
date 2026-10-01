/**********************************************************************************************************************
* Name               : mbpunitsdisplayproperties
* Description        : This class is used as the Lwc for Broker Portal units displaying.
* Usage              : LWC components for managing Broker Displayed Units
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com       27 Oct 2025    Units Displying from the backend to the portal and Managing them

*  1.1        Raghu.chilukuri@activemindsit.com    10 Nov 2025   Generate offer New implemation using offer Screen
*
* 1.2        Raghu.chilukuri@activemindsit.com     15 dec 2025       Mobile view Enhancements Using seperate html
* 1.3        Raghu.chilukuri@activemindsit.com     24 jan 2026      The id Is removed from Export of the Units 
**********************************************************************************************************************/
import { LightningElement, wire, track } from 'lwc';
import getFieldSetColumns from '@salesforce/apex/MBP_PropertiesFieldSetController.getFieldSetColumns';
import getUnitRecords from '@salesforce/apex/MBP_ManagePropertiesController.getUnitRecords';
import getRecords from '@salesforce/apex/MBP_ManagePropertiesController.getRecords';


import { NavigationMixin } from 'lightning/navigation';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import fetchUnits from '@salesforce/apex/MBP_ProjectDetailPageController.fetchUnits';
import fetchProjects from '@salesforce/apex/MBP_ManagePropertiesController.fetchProjects';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
/*import updateAllocations from '@salesforce/apex/MBP_ProjectDetailPageController.updateAllocations';
import removeAllAllocations from '@salesforce/apex/MBP_ProjectDetailPageController.removeAllAllocations';
import searchContacts from '@salesforce/apex/MBP_ProjectDetailPageController.searchContacts';
*/

import USER_ID from '@salesforce/user/Id';
const FILTER_EXCLUDE_FIELDS = new Set(['Name', 'Unit_Name__c', 'BasePrice__c', 'TotalPrice__c', 'Status__c',]);
const FILTER_EXCLUDE_LABELS = new Set(['unit name', 'total price']);
import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';


// Offer related Apex
import getOfferData from '@salesforce/apex/MBP_BrokerLeadcontroller.getOfferData';
import handleOfferAction from '@salesforce/apex/MBP_BrokerLeadcontroller.handleOfferAction';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
// Add this import to use the EXACT SAME DPG method
import makeDPGApiCall from '@salesforce/apex/UnitSearchLwcController.makeDPGApiCall';


const CIPHER_KEY = 'cipher_key_amgs_properties';

function b64urlEncode(bytes) {
    return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64urlDecode(str) {
    const pad = '='.repeat((4 - (str.length % 4)) % 4);
    const s = str.replace(/-/g, '+').replace(/_/g, '/') + pad;
    return Uint8Array.from(atob(s), c => c.charCodeAt(0));
}
function cipherEncode(plain, key = CIPHER_KEY) {
    const p = new TextEncoder().encode(plain);
    const k = new TextEncoder().encode(key);
    const out = new Uint8Array(p.length);
    for (let i = 0; i < p.length; i++) out[i] = p[i] ^ k[i % k.length];
    return b64urlEncode(out);
}


export default class MbpUnitsDisplayProperties extends NavigationMixin(LightningElement) {
    filterIcon = FilterIcon;
    @track showFilterBox = false;
    keyField = 'Id';
    @track showNoAccess = false;
    columns = [];
    _allData = [];
    filteredData = [];
    sortedBy = '';
    sortedDirection = 'asc';
    selectedRowIds = new Set();
    @track unitList = [];
    @track projectOptions = [];
    @track selectedProjectId = null;
    @track brokerType = '';

    // Component Properties
    filterIcon = FilterIcon;
    userId = USER_ID;
    keyField = 'Id';
    toast;
    // Tracking main UI state
    @track showFilterBox = false;
    @track showNoAccess = false;
    @track brokerType = '';
    @track contactId = '';
    @track columns = [];
    @track searchTerm = '';
    @track filterValues = {};
    @track currentPage = 1;
    @track pageNumber = 1;
    @track pageSize = 10;
    @track isLoading = false;
    @track showUnitAllocationModal = false;


    // Data
    _allData = [];
    filteredData = [];
    sortedBy = '';
    sortedDirection = 'asc';
    selectedRowIds = new Set();
    filterOptionsMap = {};

    // Unit Search Modal / Offer flow
    @track showUnitSearchModal = false;
    @track currentStep = 1;
    @track selectedLeads = [];
    @track selectedUnits = [];
    @track selectedUnitsData = [];
    @track leads = [];
    @track selectedPaymentPlan = '';
    @track paymentPlanOptions = [];
    @track paymentPlanDetails = null;
    @track showPaymentDetails = false;
    @track offerPdfUrl = '';
    @track activeUnitIndex = 0;
    @track activeUnitData = null;
    @track allPaymentPlans = [];
    @track unitPreviewUrls = {};
    @track activePreviewUnitId = '';
    @track isStepTwoLoading = false;

    // Lead Filters
    @track showUnitLeadFilterBox = false;
    @track leadFilters = {
        searchKey: '',
        status: '',
        startDate: '',
        endDate: ''
    };
    @track leadStatusOptions = [];
    @track filteredLeads = [];
    @track allLeads = [];
    @track currentLeadPage = 1;
    @track leadPageSize = 5;

    // Payment/installment data
    @track installments = [];

    // Offer generation tracking
    @track offerGenerationResults = [];

    // Facade design selection
    @track selectedDesign = '';

    // Validation flags
    @track showLeadValidationError = false;
    @track showPaymentPlanValidationError = false;
    @track showFacadeValidationError = false;
    // Add these track properties after your existing track properties
    @track showUnavailableUnitsError = false;
    @track unavailableUnitsMessage = '';
    @track showMobileFilter = false;
    _boundMobileClick = null;
    @track isPdfLoading = false;


    // Constants
    alNaseemDesignOptions = [
        { label: "South California", value: "South California" },
        { label: "Contemporary", value: "Contemporary" }
    ];

    filterTypeOptions = [
        { label: 'Current FY', value: 'Current FY' },
        { label: 'Previous FY', value: 'Previous FY' },
        { label: 'Current Year', value: 'Current Year' },
        { label: 'Previous Year', value: 'Previous Year' },
        { label: 'Custom', value: 'Custom' }
    ];

    leadColumns = [
        { label: 'Lead Name', fieldName: 'fullName', type: 'text', sortable: true },
        { label: 'Email', fieldName: 'email', type: 'email', sortable: true },
        { label: 'Mobile', fieldName: 'mobile', type: 'phone', sortable: true },
        { label: 'Status', fieldName: 'status', type: 'text', sortable: true },
        { label: 'Lead Number', fieldName: 'leadNumber', type: 'text', sortable: true },
        {
            label: 'Created Date',
            fieldName: 'createdDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit'
            },
            sortable: true
        }
    ];


    //mobile
    // Mobile specific tracked properties
    @track isMobileView = false;
    @track showMobileFilter = false;
    @track mobileUnitsData = [];
    @track currentMobilePage = 1;
    @track mobilePageSize = 10;
    @track mobileFilterValues = {};
    @track showUnavailableUnitsError = false;
    @track unavailableUnitsMessage = '';

    projectModal;
    unitModal;
    renderedCallback() {
        // if (!this.projectModal) this.projectModal = this.template.querySelector('.project-modal');
        // if (!this.unitModal) this.unitModal = this.template.querySelector('.unit-modal');
        if (!this.toast) {
            this.toast = this.template.querySelector('c-mbp_customshowtoast');
        }
    }
    get exportDisabled() { /*return this.selectedRowIds.size === 0;*/ return false; }

    get selectedRowsOnPage() {
        const key = this.keyField;
        const idsOnPage = new Set(this.pagedData.map(r => r[key]));
        return [...this.selectedRowIds].filter(id => idsOnPage.has(id));
    }

    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    toggleFilterBox() {
        this.showFilterBox = !this.showFilterBox;
    }
    @track isLoading = false;
    @track searchTerm = '';
    @track filterValues = {};
    @track currentPage = 1;
    filterOptionsMap = {};

    pageNumber = 1;
    pageSize = 10;
    get disablePrev() {
        return this.currentPage <= 1;
    }
    get disableNext() {
        return this.currentPage >= this.totalPages;
    }
    get prevButtonClass() {
        return this.disablePrev
            ? 'small-pagination-button slds-text-color_weak'
            : 'small-pagination-button';
    }

    get nextButtonClass() {
        return this.disableNext
            ? 'small-pagination-button slds-text-color_weak'
            : 'small-pagination-button';
    }


    countdownInterval;
    connectedCallback() {
        this.detectMobileView();
        window.addEventListener('resize', this.handleResize.bind(this));

        getEditableAccount()
            .then(result => {
                this.isLoading = false;

                this.brokerType = result?.brokerType || '';   // ✅ FIX

                if (this.brokerType === 'Agent') {
                    this.showNoAccess = true;
                } else {
                    this.showNoAccess = false;
                    this.fetchPicklistValues();
                    this.fetchCommissionData();
                }
            })

    }

    ensureAllocatedColumn() {
        const shouldShow =
            this.brokerType === 'Agency Admin' || this.brokerType === 'Owner';
        const exists = this.columns.some(c => c.fieldName === 'allocatedAgentName');

        if (shouldShow && !exists) {
            this.columns = [
                ...this.columns
                , { label: 'Unit Allocated To', fieldName: 'allocatedAgentName', type: 'text', sortable: true }
            ];
        }
    }


    get totalPages() { return Math.max(1, Math.ceil((this.filteredData?.length || 0) / this.pageSize)); }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }

    get pagedData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        return (this.filteredData || []).slice(start, start + this.pageSize);
    }

    get filterableColumns() {
        return this.columns.filter(c => {
            const label = (c.label || '').trim().toLowerCase();
            const byApi = FILTER_EXCLUDE_FIELDS.has(c.fieldName);
            const byLabel = FILTER_EXCLUDE_LABELS.has(label);
            const noLabel = !label;
            return !(byApi || byLabel || noLabel);
        });
    }


    get filterableColumnsWithFilters() {
        return this.filterableColumns.map(c => ({
            ...c,
            filterValue: this.filterValues[c.fieldName] || '',
            filterOptions: this.filterOptionsMap[c.fieldName] || [{ label: 'All', value: '' }]
        }));
    }

    @wire(getFieldSetColumns, { objectName: 'Unit__c', fieldSetName: 'Properties_Fields' })
    async wiredColumns({ error, data }) {
        if (data) {
            /*   this.columns = data
            .filter(col => (col.label || '').trim() !== '')
            .map(col => ({ 
                label: col.label, 
                fieldName: col.fieldName, 
                type: 'text', 
                sortable: true 
            }));*/

            this.columns = data
                .filter(col => (col.label || '').trim() !== '')
                .map(col => {
                    // Rename BasePrice__c column if it exists
                    if (col.fieldName === 'BasePrice__c') {
                        return {
                            label: 'Total Price', // Updated label
                            fieldName: 'BasePrice__c',
                            type: 'currency',
                            typeAttributes: {
                                currencyCode: 'AED',
                                minimumFractionDigits: '2'
                            },
                            sortable: true
                        };
                    }
                    return {
                        label: col.label,
                        fieldName: col.fieldName,
                        type: 'text',
                        sortable: true
                    };
                });

            /* ADD NEW COLUMN HERE
            this.columns.push({
                label: 'Expires In',
                fieldName: 'expiresIn',
                type: 'text',
                sortable: false
            });*/
            /* Add Allocated Agent column ONLY for non-Agent users
            if (this.brokerType !== 'Agent') {
                this.columns.push({
                    label: 'Allocated Agent',
                    fieldName: 'allocatedAgentName',
                    type: 'text',
                    sortable: false
                });
            }*/

            this.columns = [
                ...this.columns,
                {
                    label: '',
                    fieldName: 'Id',
                    type: 'button-icon',
                    sortable: false,
                    initialWidth: 40,
                    cellAttributes: { alignment: 'center' },
                    typeAttributes: {
                        iconName: 'utility:preview',
                        name: 'view',
                        title: 'view',
                        alternativeText: 'View',
                        variant: 'bare'
                    }
                }
            ];

            // initialize filter object
            const init = {};
            this.filterableColumns.forEach(c => { init[c.fieldName] = ''; });
            this.filterValues = init;

            //this.ensureAllocatedColumn();

            // Commented out eye icon button for now

            // this.columns.push({
            //     type: 'button-icon',
            //     fixedWidth: 40,
            //     typeAttributes: {
            //         iconName: 'utility:preview',
            //         name: 'view',
            //         title: 'Preview',
            //         variant: 'bare',
            //         alternativeText: 'Preview'
            //     }
            // });


            this.isLoading = true;
            try {
                await this.loadData();
                // Update mobile data after loading
                if (this.isMobileView) {
                    this.updateMobileUnitsData();
                }
            } catch (err) {
                console.error('Error loading data in wiredColumns:', err);
            } finally {
                this.isLoading = false;
            }
        } else if (error) {
            console.error(error);
        }
    }




    /*  async loadData() {
          try {
  
              const fields = Array.from(new Set([
                  ...this.columns.map(col => col.fieldName),
                  'Allocate_to_Agent__c',
                  'Allocate_to_Agent__r.Name'
              ]));
  
              const result = await getRecords({
                  objectName: 'Unit__c',
                  filters: this.filterValues,
              });
  
              // ADD THIS ONE LINE - Filter out sold units
              this._allData = (result || []).filter(unit => unit.Status__c === 'Available');
  
              this._allData = (result || []).map(r => ({
                  ...r,
                  allocatedAgentName: r?.Allocate_to_Agent__r?.Name || null
              }));
              if (this.brokerType === 'Agent' && this.contactId) {
                  this._allData = this._allData.filter(r => r.Allocate_to_Agent__c === this.contactId);
              }
  
  
              this.buildFilterOptions(this._allData);
              this.applyFilters();
          } catch (error) {
              console.error('Error loading data:', error);
          }
          const baseFields = Array.from(
              new Set(
                  (this.columns || [])
                      .map(c => c.fieldName)
                      .filter(Boolean)
                      .concat(['Id', 'Blocked_Time__c', 'Masterplan_URL__c'])
              )
          );
  
          const result = await getRecords({
              objectName: 'Unit__c',
              filters: this.filterValues,
              fields: baseFields
          });
  
          this._allData = (result || []).map(r => ({
              ...r,
              expiresIn: this.calculateExpiresIn(r.Blocked_Time__c) // 👈 NEW COLUMN
          }));
  
          if (this.brokerType === 'Agent' && this.contactId) {
              this._allData = this._allData.filter(
                  r => r.Allocate_to_Agent__c === this.contactId
              );
          }
  
          this.buildFilterOptions(this._allData);
          this.applyFilters();
      } catch(error) {
          console.error('Error loading data:', error);
  
      }*/

    async loadData() {
        try {
            const fields = Array.from(new Set([
                ...this.columns.map(col => col.fieldName),
                'Allocate_to_Agent__c',
                'Allocate_to_Agent__r.Name'
            ]));

            const result = await getRecords({
                objectName: 'Unit__c',
                filters: this.filterValues,
            });

            this._allData = (result || []).map(r => ({
                ...r,
                allocatedAgentName: r?.Allocate_to_Agent__r?.Name || null
            }));

            if (this.brokerType === 'Agent' && this.contactId) {
                this._allData = this._allData.filter(r => r.Allocate_to_Agent__c === this.contactId);
            }

            const baseFields = Array.from(
                new Set(
                    (this.columns || [])
                        .map(c => c.fieldName)
                        .filter(Boolean)
                        .concat([
                            'Id',
                            'Blocked_Time__c',
                            'Masterplan_URL__c',
                            'Allocate_to_Agent__c',
                            'Allocate_to_Agent__r.Name'   // ✅ REQUIRED
                        ])
                )
            );


            const fullResult = await getRecords({
                objectName: 'Unit__c',
                filters: this.filterValues,
                fields: baseFields
            });

            // ✅ ONE LINE CHANGE - Add expiresIn AND filter for Available units
            this._allData = (fullResult || [])
                .filter(unit => unit.Status__c === 'Available')  // ✅ Filter for Available only
                .map(r => ({
                    ...r,
                    allocatedAgent: r?.Allocate_to_Agent__r?.Name || null,
                    allocatedAgentName: r?.Allocate_to_Agent__r?.Name || null,
                    expiresIn: this.calculateExpiresIn(r.Blocked_Time__c)
                }));


            // ✅ Keep agent filter if needed
            if (this.brokerType === 'Agent' && this.contactId) {
                this._allData = this._allData.filter(r => r.Allocate_to_Agent__c === this.contactId);
            }


            this.buildFilterOptions(this._allData);
            this.applyFilters();
        } catch (error) {
            console.error('Error loading data:', error);
        }
    }


    calculateExpiresIn(blockedTime) {
        if (!blockedTime) return '';

        const blocked = new Date(blockedTime);
        const expiry = new Date(blocked.getTime() + 48 * 60 * 60 * 1000);
        const now = new Date();

        const diffMs = expiry - now;
        if (diffMs <= 0) return 'Expired';

        const hours = Math.floor(diffMs / (1000 * 60 * 60));
        const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((diffMs % (1000 * 60)) / 1000);

        return `${hours}h ${minutes}m ${seconds}s`;
    }

    // ⏱ UPDATE TIMER FOR VISIBLE ROWS EVERY SECOND
    updateCountdown() {
        this._allData = this._allData.map(row => ({
            ...row,
            expiresIn: this.calculateExpiresIn(row.Blocked_Time__c)
        }));

        this.applyFilters(); // re-render only
    }
    resetFilters() {
        this.searchTerm = '';
        const resetVals = {};
        this.filterableColumns.forEach(c => { resetVals[c.fieldName] = ''; });
        this.filterValues = resetVals;


    }

    handleSearchChange(e) {
        this.searchTerm = (e.target.value || '').trim();

    }

    handleColumnFilterChange(e) {
        const field = e.target.dataset.field;
        const value = e.detail.value;
        this.filterValues = { ...this.filterValues, [field]: value };

    }

    buildFilterOptions(rows) {
        const fields = this.filterableColumns.map(c => c.fieldName);
        const optionsByField = {};
        const collator = new Intl.Collator(undefined, { sensitivity: 'base', numeric: true });

        fields.forEach(f => {
            const set = new Set();
            (rows || []).forEach(r => {
                const v = r[f];
                if (v !== null && v !== undefined && String(v).trim() !== '') {
                    set.add(String(v));
                }
            });

            const sorted = [...set].sort((a, b) => collator.compare(a, b));
            optionsByField[f] = [{ label: 'All', value: '' }, ...sorted.map(v => ({ label: v, value: v }))];
        });

        this.filterOptionsMap = optionsByField;
    }


    applyFilters() {
        const fieldsAll = this.columns.map(c => c.fieldName);
        const term = (this.searchTerm || '').toLowerCase();
        const includes = (val, needle) => {
            if (!needle) return true;
            if (val === null || val === undefined) return false;
            return String(val).toLowerCase().includes(needle);
        };

        let rows = (this._allData || []).filter(r => !term || fieldsAll.some(f => includes(r[f], term)));

        const filterFields = this.filterableColumns.map(c => c.fieldName);
        rows = rows.filter(r => filterFields.every(f => {
            const chosen = this.filterValues[f] || '';
            return !chosen || String(r[f]) === String(chosen);
        }));

        rows = this.sortRows(rows, this.sortedBy, this.sortedDirection);
        this.filteredData = rows;
        this.pageNumber = 1;
        this.currentPage = 1;
        this.showFilterBox = false;
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.filteredData = this.sortRows(this.filteredData, this.sortedBy, this.sortedDirection);
    }
    handlePageSizeChange(e) {
        this.pageSize = Number(e.detail.value) || 25;
        this.pageNumber = 1;
        this.currentPage = 1;
    }

    sortRows(rows, field, direction) {
        if (!field) return rows;
        const isAsc = (direction || 'asc') === 'asc';
        const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
        return [...rows].sort((a, b) => {
            const av = a[field]; const bv = b[field];
            if (av === bv) return 0;
            if (av === null || av === undefined) return isAsc ? -1 : 1;
            if (bv === null || bv === undefined) return isAsc ? 1 : -1;
            const cmp = typeof av === 'number' && typeof bv === 'number'
                ? (av - bv)
                : collator.compare(String(av), String(bv));
            return isAsc ? cmp : -cmp;
        });
    }

    handlePageSizeChange(e) { this.pageSize = Number(e.detail.value) || 25; this.pageNumber = 1; }
    prevPage() { if (!this.isFirstPage) this.pageNumber -= 1; }
    nextPage() { if (!this.isLastPage) this.pageNumber += 1; }

    handleRowSelection(event) {
        const key = this.keyField;
        const selectedOnPage = new Set((event.detail.selectedRows || []).map(r => r[key]));
        const idsOnPage = new Set(this.pagedData.map(r => r[key]));

        // Filter out unavailable units
        const availableSelectedOnPage = new Set();
        selectedOnPage.forEach(id => {
            if (this.isUnitAvailable(id)) {
                availableSelectedOnPage.add(id);
            }
        });

        const merged = new Set(this.selectedRowIds);
        availableSelectedOnPage.forEach(id => merged.add(id));
        for (const id of idsOnPage) {
            if (!availableSelectedOnPage.has(id)) merged.delete(id);
        }

        this.selectedRowIds = merged;

        // Show error message if user tried to select unavailable units
        const attemptedUnavailable = [...selectedOnPage].filter(id => !this.isUnitAvailable(id));
        if (attemptedUnavailable.length > 0) {
            const unavailableUnits = attemptedUnavailable.map(id => {
                const unit = this._allData.find(u => u.Id === id);
                return unit ? { id: unit.Id, name: unit.Name, status: unit.Status__c } : { id, name: 'Unknown unit', status: 'Unknown' };
            });
            this.handleUnavailableUnitsError(unavailableUnits);
        } else {
            this.showUnavailableUnitsError = false;
        }
    }

    /*   handleSendOffer() {  }
       handleGenerateOffer() {  }*/

    handleExport() {
    const key = this.keyField;
    const selectedKeys = [...this.selectedRowIds];


    let rowsToExport;
    if (!selectedKeys.length) {
        rowsToExport = this._allData || [];
    } else {
        rowsToExport = (this._allData || []).filter(r => selectedKeys.includes(r[key]));
    }

    if (!rowsToExport.length) {
        this.template.querySelector('c-mbp_customshowtoast').show(
            'No data to export',
            'Warning'
        );
        return;
    }

    //update version 1.3 The id Is removed from Export of the Units

    const fields = this.columns.filter(c => c.fieldName !== 'Id').map(c => c.fieldName);
    const headers = this.columns.filter(c => c.fieldName !== 'Id').map(c => c.label || c.fieldName);

    //update version 1.3 ends here 
    const csv = this.toCSV(headers, fields, rowsToExport);
    this.downloadCSV(csv, `Units_${new Date().toISOString().slice(0, 10)}.csv`);
}


    toCSV(headers, fields, records) {
        const esc = (val) => {
            if (val === null || val === undefined) return '';
            const s = String(val);
            return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
        };
        const header = headers.map(esc).join(',');
        const lines = (records || []).map(r => fields.map(f => esc(r[f])).join(','));
        return [header, ...lines].join('\n');
    }

    downloadCSV(csvContent, filename) {
        const base64 = btoa(unescape(encodeURIComponent(csvContent)));
        const a = this.template.querySelector('[data-id="download-anchor"]');
        if (!a) return console.error('Download anchor not found');
        a.href = `data:text/csv;charset=utf-8;base64,${base64}`;
        a.download = filename;
        a.click();
    }

    handlePreviewNavigation(event) {
        const row = event.detail.row;
        const enc = cipherEncode(row.Id);
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Unit_Detail_Page__c' },
            state: { uid: enc }
        });

    }


    handleRowAction(event) {
        const { action, row } = event.detail;

        if (action.name === 'view') {
            this.openMasterplanForRow(row);
        }
    }

    openMasterplanForRow(row) {
        const url = row.Masterplan_URL__c;

        if (url) {
            window.open(url, '_blank');
        } else {
            this.showToast(
                'Masterplan URL not available for this unit. Please contact admin or wait for next sync.',
                'error'
            );
            console.warn('No Masterplan_URL__c on row for unit:', row.Id, row.Name);
        }
    }


    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
            this.currentPage = this.pageNumber;
        }
    }
    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
            this.currentPage = this.pageNumber;
        }
    }



    async openUnitModal() {
        try {
            if (!this.projectOptions.length) {
                const projects = await fetchProjects();
                this.projectOptions = projects.map(p => ({ label: p.Name, value: p.Id }));
            }
            this.showProjectModal();
        } catch (err) {
            console.error('Error fetching projects:', err);
        }
    }

    showProjectModal() {
        this.projectModal.style.display = 'block';
        this.unitModal.style.display = 'none';
    }

    hideProjectModal() {
        this.projectModal.style.display = 'none';
    }

    showUnitModal() {
        this.unitModal.style.display = 'block';
    }

    hideUnitModal() {
        this.unitModal.style.display = 'none';
    }

    closeAll() {
        this.hideProjectModal();
        this.hideUnitModal();
    }

    async handleProjectChange(event) {
        this.selectedProjectId = event.target.value;
        if (this.selectedProjectId) {
            this.hideProjectModal();
            await this.loadUnits();
            this.showUnitModal();
        }
    }

    async loadUnits() {
        try {
            this.unitList = await fetchUnits({ projectId: this.selectedProjectId });
        } catch (err) {
            console.error('Error fetching units:', err);
        }
    }

    async handleLookupSearch(event) {
        const unitId = event.target.dataset.id;
        const keyword = event.target.value;
        if (!keyword || keyword.length < 2) {
            this.updateSearchResults(unitId, []);
            return;
        }
        try {
            const results = await searchContacts({ searchKey: keyword });

            const options = results.map(c => ({ label: c.Name, value: c.Id }));
            this.updateSearchResults(unitId, options);
        } catch (err) {
            console.error('Lookup search error:', err);
        }
    }

    handleLookupFocus(event) {
        const unitId = event.target.dataset.id;
        searchContacts({ accountId: this.accountId, searchKey: '' })
            .then(result => {
                const options = result.map(c => ({ label: c.Name, value: c.Id }));
                this.updateSearchResults(unitId, options);
            })
            .catch(error => {
                console.error('Lookup focus fetch error:', error);
            });
    }

    openLookup(event) {
        const unitId = event.target.dataset.id;


        this.unitList = this.unitList.map(u =>
            u.unitId === unitId ? { ...u, isEditing: true, agentOptions: [] } : u
        );


        searchContacts({ accountId: this.accountId, searchKey: '' })
            .then(result => {
                const options = result.map(c => ({ label: c.Name, value: c.Id }));


                this.unitList = this.unitList.map(u =>
                    u.unitId === unitId ? { ...u, agentOptions: options, searchResults: options } : u
                );
            })
            .catch(error => {
                console.error('Error fetching contacts', error);
            });
    }



    // New

    renderedCallback() {
        if (!this._outsideClickHandlerAdded) {
            this._outsideClickHandler = this.handleOutsideClick.bind(this);
            document.addEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = true;
        }
    }

    handleOutsideClick(event) {
        if (!this.showFilterBox) return;

        const filterWrapper = this.template.querySelector('.filter-wrapper');
        const filterIcon = this.template.querySelector('.filter-icon');

        //  Check composed path for shadow DOM elements
        const path = event.composedPath ? event.composedPath() : [];
        const clickedInside =
            (filterWrapper && path.includes(filterWrapper)) ||
            (filterIcon && path.includes(filterIcon));

        if (!clickedInside) {
            this.showFilterBox = false;
        }
    }

    toggleFilterBox(event) {
        event.stopPropagation();
        this.showFilterBox = !this.showFilterBox;
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    disconnectedCallback() {
        this.removeMobileClickOutsideListener();

        clearInterval(this.countdownInterval);
        if (this._outsideClickHandlerAdded) {
            document.removeEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = false;
        }
    }

    handleSelectAgent(event) {
        const unitId = event.currentTarget.dataset.id;
        const contactId = event.currentTarget.dataset.value;
        const unit = this.unitList.find(u => u.unitId === unitId);

        const selectedAgent = unit?.searchResults?.find(a => a.value === contactId);
        const contactName = selectedAgent ? selectedAgent.label : null;

        if (contactId) {
            this.unitList = this.unitList.map(u =>
                u.unitId === unitId
                    ? {
                        ...u,
                        allocatedAgentId: contactId,
                        allocatedAgentName: contactName,
                        isEditing: false,
                        searchResults: []
                    }
                    : u
            );
        }
    }


    handleClearAgent(event) {
        const unitId = event.target.dataset.id;
        this.unitList = this.unitList.map(u =>
            u.unitId === unitId ? { ...u, allocatedAgentId: null, allocatedAgentName: null, isEditing: false } : u
        );
    }

    updateSearchResults(unitId, results) {
        this.unitList = this.unitList.map(u =>
            u.unitId === unitId ? { ...u, searchResults: results } : u
        );
    }

    async handleSubmit() {
        try {

            const changedUnits = this.unitList
                .filter(u => u.allocatedAgentId !== undefined)
                .map(u => ({
                    unitId: u.unitId,
                    allocatedAgentId: u.allocatedAgentId || null
                }));

            if (changedUnits.length > 0) {
                await updateAllocations({ unitsToUpdate: changedUnits });
            }

            await this.loadUnits();
        } catch (err) {
            console.error('Update failed:', err);
        } finally {
            this.showUnitModal = false;
        }
    }

    async handleRemoveAll() {
        try {
            await removeAllAllocations({ projectId: this.projectId });
            await this.loadUnits();
        } catch (err) {
            console.error('Remove failed:', err);
        } finally {
            this.showUnitModal = false;
        }
    }



    //offers and Mobile

    // Mobile View Getters
    // ===== MOBILE VIEW DETECTION =====
    detectMobileView() {
        this.isMobileView = window.innerWidth <= 768;
    }

    handleResize() {
        const wasMobile = this.isMobileView;
        this.detectMobileView();

        if (this.isMobileView && !wasMobile) {
            this.updateMobileUnitsData();
        }
    }

    // ===== MOBILE FILTER METHODS =====
    toggleMobileFilter() {
        this.showMobileFilter = !this.showMobileFilter;

    }

    handleMobileFilterChange(event) {
        const field = event.target.dataset.id;
        const value = event.detail?.value || event.target?.value;

        this.mobileFilterValues = {
            ...this.mobileFilterValues,
            [field]: value
        };
    }

    resetMobileFilters() {
        this.searchTerm = '';
        // Clear all filter values but don't apply yet
        this.filterableColumns.forEach(col => {
            this.mobileFilterValues[col.fieldName] = '';
        });
        // Don't call applyMobileFilters() here - let the user click Apply
    }


    // ===== MOBILE DATA METHODS =====
    applyMobileFilters() {
        // Use the same filtering logic as desktop
        const fieldsAll = this.columns.map(c => c.fieldName);
        const term = (this.searchTerm || '').toLowerCase();


        let rows = (this._allData || []).filter(r => {
            if (term) {
                const hasMatch = fieldsAll.some(f => {
                    const value = r[f];
                    return value && String(value).toLowerCase().includes(term);
                });
                if (!hasMatch) return false;
            }
            return true;
        });

        // Apply column filters
        const filterFields = this.filterableColumns.map(c => c.fieldName);
        rows = rows.filter(r => {
            return filterFields.every(f => {
                const chosen = this.mobileFilterValues[f] || '';
                if (!chosen) return true;
                const value = r[f];
                return value && String(value) === String(chosen);
            });
        });

        rows = this.sortRows(rows, this.sortedBy, this.sortedDirection);

        // Update BOTH filteredData and force mobile update
        this.filteredData = rows;
        this.currentMobilePage = 1;

        // Force mobile data update
        this.updateMobileUnitsData();

        this.closeMobileFilter();

        this.showToast(`Applied ${this.getAppliedFilterCount()} filter(s) - Found ${rows.length} units`, 'success');
    }

    // Add helper method to count applied filters
    getAppliedFilterCount() {
        let count = 0;
        if (this.searchTerm) count++;

        this.filterableColumns.forEach(col => {
            if (this.mobileFilterValues[col.fieldName]) {
                count++;
            }
        });

        return count;
    }


    resetMobileFilterValues() {
        this.searchTerm = '';

        // Clear all filter values
        this.filterableColumns.forEach(col => {
            this.mobileFilterValues[col.fieldName] = '';
        });

        // Reset the UI components
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            if (input.type === 'search') {
                input.value = '';
            }
        });

        const comboboxes = this.template.querySelectorAll('lightning-combobox');
        comboboxes.forEach(combobox => {
            combobox.value = '';
        });

        // Show message that values are reset but not applied
        this.showToast('Filter values cleared. Click "Apply Filters" to update results.', 'info');
    }

    // Update mobile data method to use filteredData
    updateMobileUnitsData() {
        if (!this.filteredData || this.filteredData.length === 0) {
            this.mobileUnitsData = [];
            return;
        }

        const startIndex = (this.currentMobilePage - 1) * this.mobilePageSize;
        const endIndex = startIndex + this.mobilePageSize;
        const pagedData = this.filteredData.slice(startIndex, endIndex);

        this.mobileUnitsData = pagedData.map((unit, index) => {
            const isAvailable = this.isUnitAvailable(unit.Id);
            const isSelected = this.selectedRowIds.has(unit.Id);

            return {
                ...unit,
                SNo: startIndex + index + 1,
                isSelected: isSelected,
                isAvailable: isAvailable,
                actionBtnClass: isAvailable ?
                    (isSelected ? 'mobile-action-btn selected' : 'mobile-action-btn') :
                    'mobile-action-btn unavailable',
                actionBtnLabel: isAvailable ?
                    (isSelected ? 'Selected ✓' : 'Select') :
                    `${unit.Status__c}`,
                unitCssClass: isSelected ? 'mobile-unit-item selected' : 'mobile-unit-item'
            };
        });
    }

    // ===== MOBILE SELECTION METHODS =====
    handleMobileSelectUnit(event) {
        const unitId = event.currentTarget.dataset.id;

        if (this.selectedRowIds.has(unitId)) {
            this.selectedRowIds.delete(unitId);
        } else {
            if (this.isUnitAvailable(unitId)) {
                this.selectedRowIds.add(unitId);
            } else {
                const unit = this._allData.find(u => u.Id === unitId);
                if (unit) {
                    // REUSE desktop error handling
                    this.handleUnavailableUnitsError([{ id: unit.Id, name: unit.Name, status: unit.Status__c }]);
                }
            }
        }

        this.updateMobileUnitsData();
    }

    handleMobileViewDetails(event) {
        const unitId = event.currentTarget.dataset.id;
        const unit = this.filteredData.find(u => u.Id === unitId);
        if (unit) {
            // REUSE desktop navigation method
            this.handlePreviewNavigation({ detail: { row: unit } });
        }
    }

    // ===== MOBILE ACTION METHODS =====
    handleMobileSendOffer() {
        // REUSE desktop validation logic
        const unavailableUnits = this.getUnavailableUnits();

        if (unavailableUnits.length > 0) {
            this.handleUnavailableUnitsError(unavailableUnits);
            return;
        }

        if (this.selectedRowIds.size === 0) {
            // REUSE desktop toast method
            this.showToast('Please select at least one unit first.', 'error');
            return;
        }

        // REUSE desktop send offer logic
        this.handleSendOffer();
    }

    handleMobileExport() {
        // Export ALL filtered units (like desktop Export button)
        const rowsToExport = this.filteredData || [];

        if (!rowsToExport.length) {
            console.warn('No units available to export');
            this.showToast('No units available to export', 'warning');
            return;
        }

        // update version 1.3 The id Is removed  from Export of the Units
       const fields = this.columns.filter(c => c.fieldName !== 'Id').map(c => c.fieldName);
    const headers = this.columns.filter(c => c.fieldName !== 'Id').map(c => c.label || c.fieldName);

    //update version 1.3 ends here 
        const csv = this.toCSV(headers, fields, rowsToExport);
        this.downloadCSV(csv, `Units_${new Date().toISOString().slice(0, 10)}.csv`);

        this.showToast(`Exported ${rowsToExport.length} units`, 'success');
    }

    // ===== MOBILE PAGINATION =====
    handleMobilePrevPage() {
        if (this.currentMobilePage > 1) {
            this.currentMobilePage--;
        }
    }

    handleMobileNextPage() {
        if (this.currentMobilePage < this.totalMobilePages) {
            this.currentMobilePage++;
        }
    }

    // ===== MOBILE UTILITY METHODS =====
    isUnitAvailable(unitId) {
        // REUSE desktop availability check
        const unit = this._allData.find(u => u.Id === unitId);
        return unit && unit.Status__c && unit.Status__c.toLowerCase() === 'available';
    }

    getUnavailableUnits() {
        // REUSE desktop unavailable units logic
        const unavailable = [];
        this.selectedRowIds.forEach(unitId => {
            if (!this.isUnitAvailable(unitId)) {
                const unit = this._allData.find(u => u.Id === unitId);
                if (unit) {
                    unavailable.push({
                        id: unit.Id,
                        name: unit.Name,
                        status: unit.Status__c
                    });
                }
            }
        });
        return unavailable;
    }

    handleUnavailableUnitsError(unavailableUnits) {
        // REUSE desktop error display logic
        if (unavailableUnits.length > 0) {
            const unavailableNames = unavailableUnits.map(unit => `${unit.name} (${unit.status})`).join(', ');
            this.unavailableUnitsMessage = unavailableNames;
            this.showUnavailableUnitsError = true;

            setTimeout(() => {
                this.showUnavailableUnitsError = false;
            }, 5000);
        } else {
            this.showUnavailableUnitsError = false;
        }
    }

    // ===== MOBILE GETTERS =====
    get disableMobilePrev() {
        return this.currentMobilePage === 1;
    }

    get disableMobileNext() {
        return this.currentMobilePage === this.totalMobilePages;
    }

    get totalMobilePages() {
        return Math.max(1, Math.ceil((this.filteredData?.length || 0) / this.mobilePageSize));
    }


    get mobileFilterableColumns() {
        if (!this.columns || this.columns.length === 0) return [];

        // REUSE desktop filterable columns but limit for mobile
        return this.filterableColumns.slice(0, 3).map(col => ({
            ...col,
            filterValue: this.mobileFilterValues[col.fieldName] || '',
            filterOptions: this.filterOptionsMap[col.fieldName] || [{ label: 'All', value: '' }]
        }));
    }

    detectMobileView() {
        this.isMobileView = window.innerWidth <= 768;
    }
    handleResize() {
        const wasMobile = this.isMobileView;
        this.detectMobileView();

        if (this.isMobileView && !wasMobile) {
            this.updateMobileUnitsData();
        }
    }

    handleMobileFilterChange(event) {
        const field = event.target.dataset.id;
        const value = event.detail?.value || event.target?.value;

        this.mobileFilterValues = {
            ...this.mobileFilterValues,
            [field]: value
        };
    }


    handleMobileSelectUnit(event) {
        const unitId = event.currentTarget.dataset.id;

        if (this.selectedRowIds.has(unitId)) {
            this.selectedRowIds.delete(unitId);
        } else {
            if (this.isUnitAvailable(unitId)) {
                this.selectedRowIds.add(unitId);
            } else {
                const unit = this._allData.find(u => u.Id === unitId);
                if (unit) {
                    // REUSE desktop error handling
                    this.handleUnavailableUnitsError([{ id: unit.Id, name: unit.Name, status: unit.Status__c }]);
                }
            }
        }

        this.updateMobileUnitsData();
    }

    handleMobileViewDetails(event) {
        const unitId = event.currentTarget.dataset.id;
        const unit = this.filteredData.find(u => u.Id === unitId);
        if (unit) {
            // REUSE desktop navigation method
            this.handlePreviewNavigation({ detail: { row: unit } });
        }
    }

    handleMobileSendOffer() {
        // REUSE desktop validation logic
        const unavailableUnits = this.getUnavailableUnits();

        if (unavailableUnits.length > 0) {
            this.handleUnavailableUnitsError(unavailableUnits);
            return;
        }

        if (this.selectedRowIds.size === 0) {
            // REUSE desktop toast method
            this.showToast('Please select at least one unit first.', 'error');
            return;
        }

        // REUSE desktop send offer logic
        this.handleSendOffer();
    }
    handleMobilePrevPage() {
        if (this.currentMobilePage > 1) {
            this.currentMobilePage--;
        }
    }
    handleMobileNextPage() {
        if (this.currentMobilePage < this.totalMobilePages) {
            this.currentMobilePage++;
        }
    }




    // Click outside bound handler (for adding/removing listeners)
    _boundClick = null;



    // ===== COMPUTED GETTERS =====
    get isStepOne() { return this.currentStep === 1; }
    get isStepTwo() { return this.currentStep === 2; }
    get isStepThree() { return this.currentStep === 3; }
    get isFirstStep() { return this.currentStep === 1; }
    get isNotLastStep() { return this.currentStep < 3; }
    get isLastStep() { return this.currentStep === 3; }

    get isGenerateOfferDisabled() {
        const hasSelectedLeads = this.selectedLeads.length > 0;
        const hasSelectedUnits = this.selectedUnits.length > 0;
        const hasPaymentPlan = !!this.selectedPaymentPlan;
        return !(hasSelectedLeads && hasSelectedUnits && hasPaymentPlan && !this.isLoading);
    }

    get isSendOfferDisabled() {
        return this.selectedRowIds.size === 0;
    }

    get exportDisabled() { return false; }

    get selectedRowsOnPage() {
        const key = this.keyField;
        const idsOnPage = new Set(this.pagedData.map(r => r[key]));
        return [...this.selectedRowIds].filter(id => idsOnPage.has(id));
    }

    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    get unitLeadFilterBoxClass() {
        return this.showUnitLeadFilterBox ? 'unit-lead-filter-box visible' : 'unit-lead-filter-box';
    }

    get disablePrev() { return this.currentPage <= 1; }
    get disableNext() { return this.currentPage >= this.totalPages; }

    get prevButtonClass() {
        return this.disablePrev ? 'small-pagination-button slds-text-color_weak' : 'small-pagination-button';
    }

    get nextButtonClass() {
        return this.disableNext ? 'small-pagination-button slds-text-color_weak' : 'small-pagination-button';
    }

    get totalPages() {
        return Math.max(1, Math.ceil((this.filteredData?.length || 0) / this.pageSize));
    }

    get pagedData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        return (this.filteredData || []).slice(start, start + this.pageSize);
    }

    get filterableColumns() {
        return this.columns.filter(c => {
            const label = (c.label || '').trim().toLowerCase();
            const byApi = FILTER_EXCLUDE_FIELDS.has(c.fieldName);
            const byLabel = FILTER_EXCLUDE_LABELS.has(label);
            const noLabel = !label;
            return !(byApi || byLabel || noLabel);
        });
    }

    get filterableColumnsWithFilters() {
        return this.filterableColumns.map(c => ({
            ...c,
            filterValue: this.filterValues[c.fieldName] || '',
            filterOptions: this.filterOptionsMap[c.fieldName] || [{ label: 'All', value: '' }]
        }));
    }

    get decoratedLeads() {
        return this.leads.map(lead => ({
            ...lead,
            rowClass: lead.isSelected ? 'slds-is-selected' : ''
        }));
    }

    get paymentPlanName() {
        // prefer per-unit stored name on the currently active unit
        const active = this.activeUnitData;
        if (active && active.selectedPaymentPlanName) {
            return active.selectedPaymentPlanName;
        }

        // fallback to currently loaded paymentPlanDetails (from step 2)
        if (this.paymentPlanDetails && this.paymentPlanDetails.Name) {
            return this.paymentPlanDetails.Name;
        }

        return '';
    }
    get totalOfferValue() {
        return this.selectedUnitsData.reduce((total, unit) => total + (unit.totalPrice || 0), 0);
    }

    get firstInstallmentDebug() {
        return this.installments && this.installments.length > 0
            ? JSON.stringify(this.installments[0])
            : '';
    }

    // Lead page helpers
    get totalLeadPages() {
        return Math.max(1, Math.ceil((this.filteredLeads?.length || 0) / this.leadPageSize));
    }

    get pagedLeads() {
        const start = (this.currentLeadPage - 1) * this.leadPageSize;
        const end = start + this.leadPageSize;
        const pagedData = (this.filteredLeads || []).slice(start, end);

        return pagedData.map(lead => ({
            ...lead,
            isSelected: this.selectedLeads.includes(lead.id)
        }));
    }

    get disableLeadPrev() { return this.currentLeadPage <= 1; }
    get disableLeadNext() { return this.currentLeadPage >= this.totalLeadPages; }

    get leadPrevButtonClass() {
        return this.disableLeadPrev ? 'small-pagination-button slds-text-color_weak' : 'small-pagination-button';
    }

    get leadNextButtonClass() {
        return this.disableLeadNext ? 'small-pagination-button slds-text-color_weak' : 'small-pagination-button';
    }

    get selectedLeadName() {
        if (this.selectedLeads.length === 0) return 'None selected';
        const selectedLead = this.allLeads.find(lead => lead.id === this.selectedLeads[0]);
        return selectedLead ? selectedLead.fullName : 'Unknown lead';
    }

    get noLeadsAvailable() {
        return !this.isLoading && this.filteredLeads.length === 0;
    }

    get activeUnitName() {
        return this.activeUnitData ? this.activeUnitData.name : '';
    }

    // Add this getter to check if the active unit is Al Naseem
    get isActiveUnitAlNaseem() {
        return this.activeUnitData && this.activeUnitData.projectName === 'Al Naseem';
    }

    get hasAlNaseemUnit() {
        return this.selectedUnitsData && this.selectedUnitsData.some(unit =>
            unit.projectName === 'Al Naseem' ||
            unit.projectName === 'Al Naseem C' ||
            (unit.projectName && unit.projectName.toLowerCase().includes('al naseem'))
        );
    }

    get hasActivePreview() {
        return !!this.offerPdfUrl && this.offerPdfUrl.startsWith('/apex/');
    }

    get activePreviewUrl() {
        return this.offerPdfUrl;
    }

    get activePreviewUnitName() {
        return this.activeUnitData?.name || 'Unknown Unit';
    }


    handleMobileGenerateOffer() {
        if (this.selectedRowIds.size === 0) {
            this.showToast('Please select at least one unit first.', 'error');
            return;
        }
        this.handleSendOffer();
    }



    // ===== UNIT SEARCH / OFFER FLOW =====
    async handleSendOffer() {
        // Check if any selected units are unavailable
        const unavailableUnits = this.getUnavailableUnits();

        if (unavailableUnits.length > 0) {
            const unavailableNames = unavailableUnits.map(unit => `${unit.name} (${unit.status})`).join(', ');
            this.handleUnavailableUnitsError(unavailableUnits);
            return;
        }

        if (this.selectedRowIds.size === 0) {
            this.showToast('Please select at least one unit first.', 'error');
            return;
        }

        this.selectedUnits = [...this.selectedRowIds];

        try {
            this.isLoading = true;
            this.showUnitSearchModal = true;
            this.currentStep = 1;

            await this.loadLeadsWithFilters();
            await this.loadOfferData();
        } catch (error) {
            console.error('Error in handleSendOffer:', error);
            this.showToast('Error loading offer data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadOfferData() {
        try {
            this.isLoading = true;
            const response = await getOfferData({
                recordId: null,
                recordType: 'unit',
                unitIdsJson: JSON.stringify(this.selectedUnits),
                startDate: null,
                endDate: null,
                filterType: null
            });

            if (response?.success) {
                // Map availableUnits into selectedUnitsData and initialize per-unit fields
                this.selectedUnitsData = (response.availableUnits || []).map((unit) => ({
                    id: unit.Id,
                    name: unit.Name,
                    unitName: unit.Name,
                    projectName: unit.Phase__r?.Project__r?.Name || unit.Project__c || '',
                    phaseName: unit.Phase__r?.Name || '',
                    totalPrice: unit.TotalPrice__c || unit.BasePrice__c || 0,
                    bedrooms: unit.Number_of_Bedrooms__c || '',
                    unitClassification: unit.UnitClassification__c || '',
                    status: unit.Status__c || '',
                    isSelected: true,
                    phaseId: unit.Phase__c || null,
                    projectId: unit.Project__c || null,
                    // per-unit persisted selection fields
                    selectedPaymentPlanName: unit.selectedPaymentPlanName || '',
                    selectedPaymentPlanId: unit.selectedPaymentPlanId || '',
                    selectedDesign: unit.selectedDesign || '',
                    // UI/tab state
                    isActive: false,
                    isActivePreview: false,
                    tabIndex: '-1',
                    hasPreview: false,
                    previewUrl: ''
                }));

                this.allPaymentPlans = response.paymentPlans || [];
                this.initializeUnitTabs();

            } else {
                throw new Error(response?.errorMessage || 'Failed to load offer data');
            }
        } catch (error) {
            console.error('Error loading offer data:', error);
            this.showToast('Error loading offer data: ' + this.getErrorMessage(error), 'error');
            throw error;
        } finally {
            this.isLoading = false;
        }
    }

    // ===== LEADS =====
    async loadLeadsWithFilters() {
        try {
            this.isLoading = true;
            if (!this.leadFilters.startDate || !this.leadFilters.endDate) {
                this.initializeDefaultDates();
            }

            const startDateObj = this.leadFilters.startDate ? new Date(this.leadFilters.startDate) : null;
            const endDateObj = this.leadFilters.endDate ? new Date(this.leadFilters.endDate) : null;

            const leadWrappers = await getFilteredLeads({
                userId: this.userId,
                startDate: startDateObj,
                endDate: endDateObj,
                filterType: 'Custom'
            });

            if (leadWrappers && leadWrappers.length > 0) {
                const allIndividualLeads = [];
                leadWrappers.forEach(wrapper => {
                    if (wrapper.children && wrapper.children.length > 0) {
                        allIndividualLeads.push(...wrapper.children);
                    } else {
                        allIndividualLeads.push(wrapper);
                    }
                });

                this.allLeads = allIndividualLeads.map(lead => ({
                    id: lead.Id,
                    firstName: lead.FirstName || '',
                    lastName: lead.LastName || '',
                    email: lead.Email || '',
                    mobile: lead.Mobile || lead.MobilePhone || '',
                    status: lead.Status || '',
                    leadNumber: lead.LeadNumber || '',
                    createdDate: lead.CreatedDate,
                    fullName: lead.Name || `${lead.FirstName || ''} ${lead.LastName || ''}`.trim(),
                    isSelected: false,
                    rowClass: ''
                }));

                this.filteredLeads = [...this.allLeads];
                this.initializeLeadStatusOptions();
            } else {
                this.allLeads = [];
                this.filteredLeads = [];
                this.showToast('No leads found for the selected date range', 'info');
            }
        } catch (error) {
            console.error('Error loading leads:', error);
            this.allLeads = [];
            this.filteredLeads = [];
            this.showToast('Error loading leads: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }


    initializeDefaultDates() {
        const today = new Date();
        const startOfYear = new Date(today.getFullYear(), 0, 1);

        const formatDate = (date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        };

        this.leadFilters = {
            ...this.leadFilters,
            startDate: formatDate(startOfYear),
            endDate: formatDate(today)
        };
    }

    initializeLeadStatusOptions() {
        const fixedStatuses = [
            'New',
            'Qualified',
            'In Progress',
            'Lead Qualified',
            'Retired'
        ];

        const dynamicStatuses = new Set();
        this.allLeads.forEach(lead => {
            if (lead.status) {
                dynamicStatuses.add(lead.status);
            }
        });

        const allStatuses = Array.from(new Set([...fixedStatuses, ...dynamicStatuses])).sort();

        this.leadStatusOptions = [
            { label: 'All', value: '' },
            ...allStatuses.map(status => ({
                label: status,
                value: status
            }))
        ];
    }

    handleLeadRadioSelection(event) {
        const selectedLeadId = event.target.value;

        if (selectedLeadId && this.showLeadValidationError) {
            this.showLeadValidationError = false;
        }

        if (selectedLeadId) {
            this.selectedLeads = [selectedLeadId];

            this.allLeads = this.allLeads.map(lead => ({
                ...lead,
                isSelected: lead.id === selectedLeadId
            }));

            this.filteredLeads = this.filteredLeads.map(lead => ({
                ...lead,
                isSelected: lead.id === selectedLeadId,
                rowClass: lead.id === selectedLeadId ? 'slds-is-selected' : ''
            }));

            const selectedLead = this.allLeads.find(lead => lead.id === selectedLeadId);
            if (selectedLead) {
                this.showToast(`Selected lead: ${selectedLead.fullName}`, 'success');
            }
        }
    }

    updateLeadRowClasses() {
        this.filteredLeads = this.filteredLeads.map(lead => ({
            ...lead,
            rowClass: lead.isSelected ? 'slds-is-selected' : ''
        }));
    }

    toggleUnitLeadFilterBox(event) {
        if (event) event.stopPropagation();
        this.showUnitLeadFilterBox = !this.showUnitLeadFilterBox;
        /* if (this.showUnitLeadFilterBox) this.addClickOutsideListener();
         else this.removeClickOutsideListener();*/
    }

    stopPropagation(event) {
        if (event && event.stopPropagation) {
            event.stopPropagation();
        }
    }


    handleMobileOutsideClick(event) {
        const filterBox = this.template.querySelector('.mobile-filter-box');
        const filterIcon = this.template.querySelector('.mobile-filter-icon');

        if (!filterBox || !this.showMobileFilter) return;

        const isClickInside = filterBox.contains(event.target) ||
            filterIcon.contains(event.target);
        const isDateInput = event.target.type === 'date';

        if (!isClickInside && !isDateInput) {
            this.closeMobileFilter();
        }
    }


    handleLeadFilterChange(event) {
        const field = event.target.dataset.id;
        const value = event.detail?.value || event.target?.value;

        let processedValue = value;
        if ((field === 'startDate' || field === 'endDate') && value) {
            const date = new Date(value);
            if (!isNaN(date)) {
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                processedValue = `${year}-${month}-${day}`;
            }
        }

        this.leadFilters = {
            ...this.leadFilters,
            [field]: processedValue
        };
    }

 async resetLeadFilters(event) {
    if (event) event.stopPropagation();

    // reset to current year defaults
    this.initializeDefaultDates();

    this.leadFilters = {
        ...this.leadFilters,
        searchKey: '',
        status: ''
    };

    try {
        this.isLoading = true;

        //  IMPORTANT: reload from Apex based on default date range
        await this.loadLeadsWithFilters();

        this.currentLeadPage = 1;
        this.showToast('Filters reset to default', 'info');
    } catch (e) {
        console.error('resetLeadFilters error:', e);
        this.showToast('Failed to reset lead filters: ' + this.getErrorMessage(e), 'error');
    } finally {
        this.isLoading = false;
    }
}


 async applyLeadFilters(event) {
    if (event) event.stopPropagation();

    const { searchKey, status } = this.leadFilters;

    try {
        this.isLoading = true;

        //  IMPORTANT: fetch leads again from Apex for the selected date range
        await this.loadLeadsWithFilters(); // this uses leadFilters.startDate/endDate already

        //  Now apply ONLY search + status on the freshly fetched leads
        let filtered = (this.allLeads || []).filter(lead => {
            const search = (searchKey || '').trim().toLowerCase();

            const searchMatch =
                !search ||
                (lead.fullName && lead.fullName.toLowerCase().includes(search)) ||
                (lead.email && lead.email.toLowerCase().includes(search)) ||
                (lead.mobile && String(lead.mobile).includes(searchKey)) ||
                (lead.leadNumber && lead.leadNumber.toLowerCase().includes(search)) ||
                (lead.firstName && lead.firstName.toLowerCase().includes(search)) ||
                (lead.lastName && lead.lastName.toLowerCase().includes(search));

            const statusMatch = !status || lead.status === status;

            return searchMatch && statusMatch;
        });

        this.filteredLeads = filtered;
        this.currentLeadPage = 1;

        this.showToast(`Found ${filtered.length} leads matching your filters`, 'success');
    } catch (e) {
        console.error('applyLeadFilters error:', e);
        this.showToast('Failed to apply lead filters: ' + this.getErrorMessage(e), 'error');
    } finally {
        this.isLoading = false;
    }
}


    // ===== UNIT TABS (STEP 2) =====
    initializeUnitTabs() {
        if (this.selectedUnitsData && this.selectedUnitsData.length > 0) {
            this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
                ...unit,
                isActive: index === 0,
                isActivePreview: index === 0,
                tabIndex: index === 0 ? '0' : '-1'
            }));

            this.activeUnitIndex = 0;
            this.activeUnitData = this.selectedUnitsData[0];

            // Load payment plans for the first active unit
            this.loadPaymentPlansForActiveUnit();
        }
    }

    handleUnitTabClick(event) {
        event.preventDefault();
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (isNaN(idx)) return;

        // Clear any transient validation/errors when user switches units
        this.clearAllValidationErrors();
        this.showUnavailableUnitsError = false;

        this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
            ...unit,
            isActive: index === idx,
            tabIndex: index === idx ? '0' : '-1'
        }));

        this.activeUnitIndex = idx;
        this.activeUnitData = this.selectedUnitsData[idx];

        // Sync the component-level selectedDesign with the active unit's design (per-unit)
        this.selectedDesign = this.activeUnitData.selectedDesign || '';

        // Set selectedPaymentPlan to persisted value for the active unit
        this.selectedPaymentPlan = this.activeUnitData.selectedPaymentPlanId || '';

        // Reset payment details/progress then load for the active unit
        this.paymentPlanDetails = null;
        this.showPaymentDetails = false;
        this.installments = [];

        // Load payment plans for active unit
        this.loadPaymentPlansForActiveUnit();
    }

    // ===== PAYMENT PLAN METHODS =====
    async loadPaymentPlansForActiveUnit() {
        if (!this.activeUnitData) return;

        try {
            this.isStepTwoLoading = true;
            this.paymentPlanOptions = [];
            this.paymentPlanDetails = null;
            this.showPaymentDetails = false;
            this.installments = [];
            this.selectedPaymentPlan = this.activeUnitData.selectedPaymentPlanId || '';

            const unitId = this.activeUnitData.id;
            // Filter from allPaymentPlans already loaded in loadOfferData
            const unitPaymentPlans = (this.allPaymentPlans || []).filter(plan => {
                if (!plan) return false;
                const matchesUnit = plan.Unit__c === unitId;
                const matchesPhase = plan.Phase__c && plan.Phase__c === this.activeUnitData.phaseId;
                const matchesProject = plan.Project__c && plan.Project__c === this.activeUnitData.projectId;
                return matchesUnit || matchesPhase || matchesProject;
            });

            if (unitPaymentPlans.length > 0) {
                this.paymentPlanOptions = unitPaymentPlans.map(plan => ({ label: plan.Name, value: plan.Id }));

                // If the active unit already has a persisted payment plan id, use that, else pick the first
                if (this.selectedPaymentPlan) {
                    const existingPlan = unitPaymentPlans.find(p => p.Id === this.selectedPaymentPlan);
                    if (existingPlan) {
                        await this.loadPaymentPlanDetails(existingPlan);
                        return;
                    } else {
                        // persisted plan not in available plans for this unit => clear it
                        this.selectedPaymentPlan = '';
                    }
                }

                // default to first plan for the unit
                this.selectedPaymentPlan = this.paymentPlanOptions[0].value;
                await this.loadPaymentPlanDetails(unitPaymentPlans[0]);
            } else {
                // no plans for this unit
                this.paymentPlanOptions = [];
                this.selectedPaymentPlan = '';
                this.paymentPlanDetails = null;
                this.showPaymentDetails = false;
                this.installments = [];
                // we do not block the user here; validation will catch missing per-unit plan on Next
            }
        } catch (error) {
            console.error('Error loading payment plans for unit:', error);
            this.showToast('Error loading payment plans: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isStepTwoLoading = false;
        }
    }

    async loadPaymentPlanDetails(paymentPlanData = null) {
        try {
            if (!paymentPlanData && !this.selectedPaymentPlan) return;

            this.isStepTwoLoading = true;

            // If data passed, use it; else find in allPaymentPlans by id
            let paymentPlanWithInstallments = paymentPlanData;
            if (!paymentPlanWithInstallments && this.selectedPaymentPlan) {
                paymentPlanWithInstallments = (this.allPaymentPlans || []).find(plan => plan.Id === this.selectedPaymentPlan);
            }

            if (paymentPlanWithInstallments) {
                this.paymentPlanDetails = paymentPlanWithInstallments;

                // Persist plan name+id for the active unit
                if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number') {
                    const planName = paymentPlanWithInstallments.Name || '';
                    const planId = paymentPlanWithInstallments.Id || this.selectedPaymentPlan || '';
                    this.selectedUnitsData = this.selectedUnitsData.map((u, idx) => {
                        if (idx === this.activeUnitIndex) {
                            return { ...u, selectedPaymentPlanName: planName, selectedPaymentPlanId: planId };
                        }
                        return u;
                    });
                }

                // process installments using active unit price
                const installmentsData = paymentPlanWithInstallments.Payment_Installments__r || [];
                const activeUnit = this.activeUnitData;
                this.installments = this.processInstallmentsData(installmentsData, activeUnit?.totalPrice || 0);

                this.showPaymentDetails = true;
            } else {
                this.installments = [];
                this.showPaymentDetails = false;
                this.paymentPlanDetails = null;
            }
        } catch (error) {
            console.error('Error loading payment plan details:', error);
            this.installments = [];
            this.showPaymentDetails = false;
            this.showToast('Error loading payment details: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isStepTwoLoading = false;
        }
    }


    processInstallmentsData(installmentsData, unitPrice) {
        if (!installmentsData || unitPrice === undefined || unitPrice === null) return [];

        return installmentsData.map((inst, index) => {
            const milestonePercent = inst.Milestone__c || 0;
            const amount = (unitPrice * milestonePercent) / 100;

            return {
                Id: inst.Id || `inst-${index}`,
                milestoneNumber: inst.MilestoneNumber__c || index + 1,
                milestoneDescription: inst.MilestoneDescription__c || 'Milestone Payment',
                milestonePercentage: milestonePercent,
                amount: amount,
                brokerPayout: inst.BrokerPayout__c || 0,
                milestoneDate: inst.MilestoneDate__c
            };
        });
    }

    handlePaymentPlanChange(event) {
        const newPlanId = event.detail.value;
        this.selectedPaymentPlan = newPlanId;

        if (this.selectedPaymentPlan && this.showPaymentPlanValidationError) {
            this.showPaymentPlanValidationError = false;
        }

        if (this.selectedPaymentPlan) {
            // find plan in allPaymentPlans
            const selectedPlan = (this.allPaymentPlans || []).find(p => p.Id === this.selectedPaymentPlan);
            if (selectedPlan) {
                // persist to active unit
                if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number' && this.selectedUnitsData[this.activeUnitIndex]) {
                    const planLabel = selectedPlan.Name || '';
                    const planId = selectedPlan.Id || '';
                    this.selectedUnitsData = this.selectedUnitsData.map((u, idx) => {
                        if (idx === this.activeUnitIndex) {
                            return { ...u, selectedPaymentPlanName: planLabel, selectedPaymentPlanId: planId };
                        }
                        return u;
                    });
                }
                // load installments for UI
                this.loadPaymentPlanDetails(selectedPlan);
            } else {
                // plan id not found in allPaymentPlans (edge case)
                this.paymentPlanDetails = null;
                this.installments = [];
                this.showPaymentDetails = false;
            }
        } else {
            // deselected
            if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number' && this.selectedUnitsData[this.activeUnitIndex]) {
                this.selectedUnitsData = this.selectedUnitsData.map((u, idx) => {
                    if (idx === this.activeUnitIndex) {
                        return { ...u, selectedPaymentPlanName: '', selectedPaymentPlanId: '' };
                    }
                    return u;
                });
            }
            this.paymentPlanDetails = null;
            this.installments = [];
            this.showPaymentDetails = false;
        }
    }

    handleDesignChange(event) {
        const selected = event.detail.value;

        // Store design selection per active unit
        if (this.selectedUnitsData && typeof this.activeUnitIndex === 'number' && this.selectedUnitsData[this.activeUnitIndex]) {
            this.selectedUnitsData = this.selectedUnitsData.map((u, idx) => {
                if (idx === this.activeUnitIndex) {
                    return { ...u, selectedDesign: selected };
                }
                return u;
            });

            // Also update component-level for the dropdown display
            this.selectedDesign = selected;
        }

        if (selected && this.showFacadeValidationError) {
            this.showFacadeValidationError = false;
        }
    }

    // ===== STEP NAVIGATION & VALIDATION =====
    async handleNextStep() {
        this.clearAllValidationErrors();

        // If Step 1 -> move to Step 2
        if (this.currentStep === 1) {
            if (!await this.validateCurrentStep()) return;
            this.currentStep = 2;
            if (this.selectedUnitsData.length > 0) {
                this.ensurePaymentPlansLoaded();
            }
            return;
        }

        // If Step 2 -> validate all units (payment plans + facades) then Step 3
        if (this.currentStep === 2) {
            const ok = await this.validateCurrentStep();
            if (!ok) return;

            // All validated; prepare per-unit preview data then generate previews
            this.currentStep = 3;
            await this.generateOfferPreview();
            return;
        }
    }


    async navigateToStep(stepNumber) {
        if (!await this.validateCurrentStep()) return;
        this.currentStep = stepNumber;
        this.clearAllValidationErrors();
        if (this.currentStep === 2 && this.selectedUnitsData.length > 0) {
            this.ensurePaymentPlansLoaded();
        } else if (this.currentStep === 3) {
            await this.generateOfferPreview();
        }
    }

    async validateCurrentStep() {
        if (this.currentStep === 1) {
            if (this.selectedLeads.length === 0) {
                this.showLeadValidationError = true;
                this.showToast('Please select one lead to tag with the offer.', 'error');
                return false;
            }
            if (this.selectedLeads.length > 1) {
                this.showLeadValidationError = true;
                this.showToast('Please select only one lead.', 'error');
                return false;
            }
            return true;
        }

        if (this.currentStep === 2) {
            const unitsMissingPlan = [];
            const unitsMissingFacade = [];

            await this.assignPaymentPlanNamesToSelectedUnits();

            (this.selectedUnitsData || []).forEach(unit => {
                const isAlNaseem = unit.projectName === 'Al Naseem' ||
                    unit.projectName === 'Al Naseem C' ||
                    (unit.projectName && unit.projectName.toLowerCase().includes('al naseem'));

                const hasPlan = !!(unit.selectedPaymentPlanId);
                if (!hasPlan) unitsMissingPlan.push(unit.name || unit.id);

                // Only require facade for actual Al Naseem units
                if (isAlNaseem) {
                    const facade = unit.selectedDesign || '';
                    if (!facade || facade.trim() === '') unitsMissingFacade.push(unit.name || unit.id);
                }
            });

            if (unitsMissingPlan.length > 0 || unitsMissingFacade.length > 0) {
                if (unitsMissingPlan.length > 0) {
                    this.showPaymentPlanValidationError = true;
                }
                if (unitsMissingFacade.length > 0) {
                    this.showFacadeValidationError = true;
                }

                const parts = [];
                if (unitsMissingPlan.length > 0) {
                    parts.push(`Missing payment plan for: ${unitsMissingPlan.join(', ')}`);
                }
                if (unitsMissingFacade.length > 0) {
                    parts.push(`Facade style required for Al Naseem units: ${unitsMissingFacade.join(', ')}`);
                }
                this.showToast(parts.join(' — '), 'error');
                return false;
            }

            this.showPaymentPlanValidationError = false;
            this.showFacadeValidationError = false;
            return true;
        }

        return true;
    }


    async assignPaymentPlanNamesToSelectedUnits() {
        try {
            if (!this.selectedUnitsData || this.selectedUnitsData.length === 0) return;

            // Use allPaymentPlans already present from loadOfferData; if not present fetch getOfferData
            if (!this.allPaymentPlans || this.allPaymentPlans.length === 0) {
                const res = await getOfferData({
                    recordId: this.selectedLeads[0] || null,
                    recordType: 'unit',
                    unitIdsJson: JSON.stringify(this.selectedUnits),
                    startDate: null,
                    endDate: null,
                    filterType: null
                });
                this.allPaymentPlans = res?.paymentPlans || [];
            }

            const plans = this.allPaymentPlans || [];

            // For every unit find the best matching plan and write to selectedUnitsData if missing
            this.selectedUnitsData = this.selectedUnitsData.map(unit => {
                // If already has selectedPaymentPlanId, keep it
                if (unit.selectedPaymentPlanId) return unit;

                let planMatch = plans.find(p => p.Unit__c === unit.id
                    || (p.Unit__r && p.Unit__r.Name === unit.name)
                );

                if (!planMatch) {
                    planMatch = plans.find(p => p.Phase__c === unit.phaseId || p.Project__c === unit.projectId);
                }

                const planName = planMatch ? (planMatch.Name || '') : '';
                const planId = planMatch ? (planMatch.Id || '') : '';

                return {
                    ...unit,
                    selectedPaymentPlanName: unit.selectedPaymentPlanName || planName,
                    selectedPaymentPlanId: unit.selectedPaymentPlanId || planId
                };
            });

        } catch (err) {
            console.warn('Failed to assign per-unit payment plan names:', err);
        }
    }
    ensurePaymentPlansLoaded() {
        if (this.currentStep === 2 && this.selectedUnitsData.length > 0) {
            // If no payment plan options or they're empty, load them
            if (!this.paymentPlanOptions || this.paymentPlanOptions.length === 0) {
                this.loadPaymentPlansForActiveUnit();
            }
            // If we have a selected payment plan but no details shown, load them
            else if (this.selectedPaymentPlan && !this.showPaymentDetails) {
                this.loadPaymentPlanDetails();
            }
            // If nothing is selected, select the first payment plan
            else if (!this.selectedPaymentPlan && this.paymentPlanOptions.length > 0) {
                this.selectedPaymentPlan = this.paymentPlanOptions[0].value;
                this.loadPaymentPlanDetails();
            }
        }
    }

    // ===== PREVIEW & OFFER GENERATION =====
    /*async generateOfferPreview() {
        try {
            this.isLoading = true;
            this.isPdfLoading = true;
    
            if (!this.selectedLeads.length || !this.selectedUnits.length) {
                this.showToast('Please select leads and units first', 'error');
                return;
            }
    
            // Ensure per-unit plan names/ids and any per-unit selections are populated
            await this.assignPaymentPlanNamesToSelectedUnits();
    
            // For each selected unit generate a preview call (store per-unit preview URLs)
            const unitIds = [...this.selectedUnits];
            const previews = {}; // accumulate per-unit preview urls
    
            for (const unitId of unitIds) {
                const unit = this.selectedUnitsData.find(u => u.id === unitId);
                if (!unit) continue;
    
                try {
                    const previewUrl = await handleOfferAction({
                        actionType: 'preview',
                        unitId: unitId,
                        leadId: this.selectedLeads[0],
                        // send the unit's selected payment plan id (may be empty string if none)
                        paymentPlanId: unit.selectedPaymentPlanId || '',
                        selectedOptions: JSON.stringify({
                            design: unit.selectedDesign || 'Not Applicable',
                            unitIds: [unitId],
                            unitOption: ''
                        }),
                        customerName: this.selectedLeadName
                    });
    
                    if (previewUrl && previewUrl.startsWith('/apex/')) {
                        previews[unitId] = previewUrl;
                    } else {
                        previews[unitId] = null;
                    }
                } catch (err) {
                    console.error('Preview error for unit', unitId, err);
                    previews[unitId] = null;
                }
            }
    
            // Save preview urls and mark hasPreview per unit
            this.unitPreviewUrls = { ...this.unitPreviewUrls, ...previews };
    
            this.selectedUnitsData = this.selectedUnitsData.map(unit => ({
                ...unit,
                hasPreview: !!this.unitPreviewUrls[unit.id],
                previewUrl: this.unitPreviewUrls[unit.id] || ''
            }));
    
            // Set active preview to the first selected unit that has a preview, otherwise first unit
            const firstWithPreview = unitIds.find(id => this.unitPreviewUrls[id]);
            const initialUnitId = firstWithPreview || unitIds[0];
            const idx = this.selectedUnitsData.findIndex(u => u.id === initialUnitId);
            if (idx !== -1) {
                this.selectedUnitsData = this.selectedUnitsData.map((u, i) => ({ ...u, isActivePreview: i === idx }));
                this.activeUnitData = this.selectedUnitsData[idx];
                this.activePreviewUnitId = initialUnitId;
                this.offerPdfUrl = this.unitPreviewUrls[initialUnitId] || '';
            } else if (this.selectedUnitsData.length > 0) {
                this.selectedUnitsData = this.selectedUnitsData.map((u, i) => ({ ...u, isActivePreview: i === 0 }));
                this.activeUnitData = this.selectedUnitsData[0];
                this.activePreviewUnitId = this.selectedUnitsData[0].id;
                this.offerPdfUrl = this.unitPreviewUrls[this.activePreviewUnitId] || '';
            }
    
            this.showToast('Previews generated', 'success');
              setTimeout(() => {
                this.isPdfLoading = false;
            }, 15000);
        } catch (error) {
            console.error('Error generating previews:', error);
            this.showToast('Preview generation failed: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }*/


    // In your mbpUnitsDisplayProperties.js, update the generateOfferPreview method:

    async generateOfferPreview() {
        try {
            this.isLoading = true;
            this.isPdfLoading = true;

            if (!this.selectedLeads.length || !this.selectedUnits.length) {
                this.showToast('Please select leads and units first', 'error');
                return;
            }

            // Ensure per-unit plan names/ids and any per-unit selections are populated
            await this.assignPaymentPlanNamesToSelectedUnits();

            // NEW: Get unit names for DPG API call
            const unitNames = this.selectedUnitsData.map(unit => unit.name).filter(name => name);

            // Call the SAME DPG API method that UnitSearchLwc uses
            const virtualTourUrls = await makeDPGApiCall({ unitNames: unitNames });

            // For each selected unit generate a preview call
            const unitIds = [...this.selectedUnits];
            const previews = {};

            for (const unitId of unitIds) {
                const unit = this.selectedUnitsData.find(u => u.id === unitId);
                if (!unit) continue;

                try {
                    const previewUrl = await handleOfferAction({
                        actionType: 'preview',
                        unitId: unitId,
                        leadId: this.selectedLeads[0],
                        paymentPlanId: unit.selectedPaymentPlanId || '',
                        selectedOptions: JSON.stringify({
                            design: unit.selectedDesign || 'Not Applicable',
                            unitIds: [unitId],
                            unitOption: '',
                            // Pass the virtual tour URL from DPG
                            dpgLink: virtualTourUrls[unit.name] || ''
                        }),
                        customerName: this.selectedLeadName
                    });

                    if (previewUrl && previewUrl.startsWith('/apex/')) {
                        previews[unitId] = previewUrl;
                    } else {
                        previews[unitId] = null;
                    }
                } catch (err) {
                    console.error('Preview error for unit', unitId, err);
                    previews[unitId] = null;
                }
            }

            // Save preview urls
            this.unitPreviewUrls = { ...this.unitPreviewUrls, ...previews };

            this.selectedUnitsData = this.selectedUnitsData.map(unit => ({
                ...unit,
                hasPreview: !!this.unitPreviewUrls[unit.id],
                previewUrl: this.unitPreviewUrls[unit.id] || '',
                // Store the virtual tour URL
                virtualTourUrl: virtualTourUrls[unit.name] || null
            }));

            // Set active preview
            const firstWithPreview = unitIds.find(id => this.unitPreviewUrls[id]);
            const initialUnitId = firstWithPreview || unitIds[0];
            const idx = this.selectedUnitsData.findIndex(u => u.id === initialUnitId);

            if (idx !== -1) {
                this.selectedUnitsData = this.selectedUnitsData.map((u, i) => ({
                    ...u,
                    isActivePreview: i === idx
                }));
                this.activeUnitData = this.selectedUnitsData[idx];
                this.activePreviewUnitId = initialUnitId;
                this.offerPdfUrl = this.unitPreviewUrls[initialUnitId] || '';
            } else if (this.selectedUnitsData.length > 0) {
                this.selectedUnitsData = this.selectedUnitsData.map((u, i) => ({
                    ...u,
                    isActivePreview: i === 0
                }));
                this.activeUnitData = this.selectedUnitsData[0];
                this.activePreviewUnitId = this.selectedUnitsData[0].id;
                this.offerPdfUrl = this.unitPreviewUrls[this.activePreviewUnitId] || '';
            }

            this.showToast('Previews generated', 'success');

            setTimeout(() => {
                this.isPdfLoading = false;
            }, 15000);

        } catch (error) {
            console.error('Error generating previews:', error);
            this.showToast('Preview generation failed: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handlePreviewUnitTabClick(event) {
        event.preventDefault();
        const unitId = event.currentTarget.dataset.unitid;
        this.isPdfLoading = true;
        if (!unitId) {
            console.warn('handlePreviewUnitTabClick: no unitid on event');
            return;
        }

        const clickedIndex = this.selectedUnitsData.findIndex(u => u.id === unitId);
        if (clickedIndex === -1) {
            console.warn('handlePreviewUnitTabClick: unit not found', unitId);
            return;
        }

        // Clear any validation errors when switching preview tabs
        this.clearAllValidationErrors();
        this.showUnavailableUnitsError = false;

        this.selectedUnitsData = this.selectedUnitsData.map((unit, index) => ({
            ...unit,
            isActivePreview: index === clickedIndex,
            previewTabClass: index === clickedIndex ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item'
        }));

        // Update active unit data and per-component selectedDesign to reflect the unit's own selection
        this.activeUnitData = this.selectedUnitsData[clickedIndex];
        this.activePreviewUnitId = unitId;
        this.selectedDesign = this.activeUnitData.selectedDesign || '';
        this.selectedPaymentPlan = this.activeUnitData.selectedPaymentPlanId || '';

        if (this.unitPreviewUrls && this.unitPreviewUrls[unitId]) {
            this.offerPdfUrl = this.unitPreviewUrls[unitId];
        } else {
            // generate preview for this unit with its own selections
            await this.generatePreviewForSingleUnit(unitId);
        }
    }

    async generatePreviewForSingleUnit(unitId) {
        try {
            this.isLoading = true;

            const unit = this.selectedUnitsData.find(u => u.id === unitId);
            if (!unit) {
                throw new Error('Unit data not found for preview');
            }

            const previewUrl = await handleOfferAction({
                actionType: 'preview',
                unitId: unitId,
                leadId: this.selectedLeads[0],
                paymentPlanId: unit.selectedPaymentPlanId || '',
                // In generatePreviewForSingleUnit method, update the selectedOptions:
                selectedOptions: JSON.stringify({
                    design: unit.selectedDesign || 'Not Applicable',  // Use unit's design, not component-level
                    unitIds: [unitId],
                    unitOption: ''
                }),
                customerName: this.selectedLeadName
            });

            if (previewUrl && previewUrl.startsWith('/apex/')) {
                this.unitPreviewUrls = { ...this.unitPreviewUrls, [unitId]: previewUrl };
                this.offerPdfUrl = previewUrl;
                this.unitPreviewUrls[unitId] = previewUrl;

                // update selectedUnitsData entry
                this.selectedUnitsData = this.selectedUnitsData.map(u => {
                    if (u.id === unitId) return { ...u, hasPreview: true, previewUrl: previewUrl };
                    return u;
                });
            } else {
                throw new Error('Invalid preview URL received');
            }
        } catch (error) {
            console.error('Error generating preview for unit:', unitId, error);
            this.showToast('Error generating preview for unit: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateOffer() {
        if (this.selectedUnits.length === 0 || this.selectedLeads.length === 0) {
            this.showToast('Please select at least one lead and one unit.', 'error');
            return;
        }

        // Validate that every selected unit has a per-unit payment plan selected
        const unitsMissingPlan = (this.selectedUnitsData || []).filter(u => !u.selectedPaymentPlanId || !u.selectedPaymentPlanId.trim());
        if (unitsMissingPlan.length > 0) {
            const names = unitsMissingPlan.map(u => u.name || u.id).join(', ');
            this.showPaymentPlanValidationError = true;
            this.showToast(`Please select a payment plan for: ${names}`, 'error');
            return;
        }

        // Validate facade per Al Naseem unit using per-unit selectedDesign (NOT component-level selectedDesign)
        const unitsMissingFacade = (this.selectedUnitsData || []).filter(unit => {
            const projectName = (unit.projectName || '').toLowerCase();
            const isAlNaseem = projectName === 'al naseem' || projectName === 'al naseem c' || projectName.includes('al naseem');
            return isAlNaseem && (!unit.selectedDesign || !unit.selectedDesign.trim());
        });

        if (unitsMissingFacade.length > 0) {
            const names = unitsMissingFacade.map(u => u.name || u.id).join(', ');
            this.showFacadeValidationError = true;
            this.showToast(`Please select a Facade Style for Al Naseem units: ${names}`, 'error');
            return;
        }

        try {
            this.isLoading = true;

            // Prepare per-unit selectedOptions array using per-unit selectedDesign
            const perUnitSelectedOptions = {
                designByUnit: (this.selectedUnitsData || []).reduce((acc, u) => {
                    acc[u.id] = u.selectedDesign || 'Not Applicable';
                    return acc;
                }, {})
            };

            const result = await handleOfferAction({
                actionType: 'send',
                unitId: this.selectedUnits[0],
                leadId: this.selectedLeads[0],
                paymentPlanId: this.selectedPaymentPlan, // still send the top-level if needed by backend, but per-unit IDs were validated above
                selectedOptions: JSON.stringify({
                    // Backwards-compatible: include a single design key if caller expects it, but also include per-unit map
                    design: this.selectedDesign || 'Not Applicable',
                    unitIds: this.selectedUnits,
                    unitOption: '',
                    perUnitDesigns: perUnitSelectedOptions.designByUnit
                }),
                customerName: this.selectedLeadName
                
            });

            if (result && result.includes('Success')) {

                // 🔹 Get selected lead + email
                const selectedLead = this.allLeads.find(
                    lead => lead.id === this.selectedLeads[0]
                );
                const leadEmail = selectedLead ? selectedLead.email : 'Unknown email';

                // 🔹 Success toast with email
                this.showToast(`Offer sent successfully to ${leadEmail}`, 'success');

                // 🔹 Build results per unit
                this.offerGenerationResults = this.selectedUnits.map(unitId => {
                    const unit = this.selectedUnitsData.find(u => u.id === unitId);
                    return {
                        success: true,
                        unitId: unitId,
                        unitName: unit?.name || 'Unknown Unit',
                        message: result
                    };
                });

                // 🔹 Close search after delay
                setTimeout(() => this.closeUnitSearch(), 2000);

            } else {
                throw new Error(result || 'Failed to send offer');
            }


            this.refreshUnitData();
        } catch (error) {
            console.error('Error generating offers:', error);
            this.showToast('Error generating offers: ' + this.getErrorMessage(error), 'error');

            this.offerGenerationResults = this.selectedUnits.map(unitId => {
                const unit = this.selectedUnitsData.find(u => u.id === unitId);
                return {
                    success: false,
                    unitId: unitId,
                    unitName: unit?.name || 'Unknown Unit',
                    message: 'Error: ' + this.getErrorMessage(error)
                };
            });
        } finally {
            this.isLoading = false;
        }
    }

    downloadOfferPDF() {
        if (this.hasActivePreview) {
            const link = document.createElement('a');
            link.href = this.offerPdfUrl;
            link.target = '_blank';
            link.download = `Sales_Offer_${this.activePreviewUnitName}_${new Date().toISOString().split('T')[0]}.pdf`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } else {
            this.showToast('No PDF available to download. Please generate preview first.', 'warning');
        }
    }

    calculateInstallmentAmount(percentage) {
        if (!percentage || this.selectedUnitsData.length === 0 || !this.activeUnitData) return 0;
        const unitPrice = this.activeUnitData.totalPrice || 0;
        const percentageValue = parseFloat(percentage) || 0;
        return (unitPrice * percentageValue) / 100;
    }

    closeUnitSearch() {
        this.showUnitSearchModal = false;
        this.removeClickOutsideListener();
    }

    resetUnitSearch() {
        this.currentStep = 1;
        this.selectedLeads = [];
        this.selectedPaymentPlan = '';
        this.selectedDesign = '';
        this.paymentPlanDetails = null;
        this.showPaymentDetails = false;
        this.offerPdfUrl = '';
        this.unitPreviewUrls = {};
        this.activeUnitIndex = 0;
        this.activeUnitData = null;
        this.removeClickOutsideListener();
    }

    closePreview() {
        // kept for compatibility if used elsewhere
        this.isPreviewOpen = false;
    }

    closeUnitLeadFilterBox() {
        this.showUnitLeadFilterBox = false;
        this.removeClickOutsideListener();
    }


    /* handleClickOutside(event) {
        const filterWrapper = this.template.querySelector('.unit-lead-filter-wrapper');
        const filterBox = this.template.querySelector('.unit-lead-filter-box');

        if (!filterWrapper || !filterBox) {
            return;
        }

        const isClickInsideFilter = filterWrapper.contains(event.target) || filterBox.contains(event.target);
        const isFilterInput =
            event.target.closest('lightning-input') ||
            event.target.closest('lightning-combobox') ||
            event.target.closest('.slds-dropdown') ||
            event.target.closest('.slds-listbox') ||
            event.target.closest('.button-row') ||
            event.target.closest('.unit-lead-filter-buttons') ||
            ['INPUT', 'SELECT', 'BUTTON', 'LABEL', 'SPAN'].includes(event.target.tagName);

        if (!isClickInsideFilter && !isFilterInput) {
            this.closeUnitLeadFilterBox();
        }
    }*/

    handleClickOutside(event) {
        const filterWrapper = this.template.querySelector('.unit-lead-filter-wrapper');
        const filterBox = this.template.querySelector('.unit-lead-filter-box');

        if (!filterWrapper || !filterBox) {
            return;
        }

        const isClickInsideFilter = filterWrapper.contains(event.target) || filterBox.contains(event.target);
        const isFilterInput =
            event.target.closest('lightning-input') ||
            event.target.closest('lightning-combobox') ||
            event.target.closest('.slds-dropdown') ||
            event.target.closest('.slds-listbox') ||
            event.target.closest('.button-row') ||
            event.target.closest('.unit-lead-filter-buttons') ||
            ['INPUT', 'SELECT', 'BUTTON', 'LABEL', 'SPAN'].includes(event.target.tagName);

        // ADD THIS: Check if it's a date input specifically
        const isDateInput = event.target.type === 'date' ||
            (event.target.closest && event.target.closest('input[type="date"]'));

        // MODIFY THIS CONDITION: Include date inputs as valid clicks
        if (!isClickInsideFilter && !isFilterInput && !isDateInput) {
            this.closeUnitLeadFilterBox();
        }
    }

    addClickOutsideListener() {
        if (!this._boundClick) this._boundClick = this.handleClickOutside.bind(this);
        document.addEventListener('click', this._boundClick, true);
        document.addEventListener('touchstart', this._boundClick, true);
    }

    removeClickOutsideListener() {
        if (this._boundClick) {
            document.removeEventListener('click', this._boundClick, true);
            document.removeEventListener('touchstart', this._boundClick, true);
        }
    }

    refreshUnitData() {
        this.loadData();
    }

    showToast(message, variant = 'info') {
        const toastCmp = this.template.querySelector('c-mbp_customshowtoast');
        if (toastCmp && typeof toastCmp.show === 'function') {

            const v = (variant || 'info').toLowerCase();
            const mapped =
                v === 'error' ? 'Error' :
                    v === 'success' ? 'Success' :
                        v === 'warning' ? 'Warning' :
                            'Info';

            toastCmp.show(message, mapped);
            return;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Notification',
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (!error) return 'Unknown error occurred';

        if (error.body?.message) {
            if (error.body.message.includes('List has no rows for assignment to SObject')) {
                return 'No payment plan found for the selected unit. Please try a different unit or contact administrator.';
            }
            return error.body.message;
        }

        if (error.message) {
            return error.message;
        }

        return String(error);
    }

    // Progress UI helpers
    get progressFillStyle() {
        const progressPercentage = ((this.currentStep - 1) / 2) * 100;
        return `width: ${progressPercentage}%`;
    }

    handleStepClick(event) {
        const targetStep = parseInt(event.currentTarget.dataset.step);

        // Only allow navigation to completed steps or next logical step
        if (targetStep <= this.currentStep) {
            this.clearAllValidationErrors();
            if (targetStep > this.currentStep && !this.validateCurrentStep()) {
                return;
            }
            this.navigateToStep(targetStep);
        }
    }

    // Step circle classes
    get stepOneClass() {
        if (this.currentStep >= 1) {
            return this.currentStep > 1 ? 'step-circle completed' : 'step-circle active';
        }
        return 'step-circle';
    }

    get stepTwoClass() {
        if (this.currentStep >= 2) {
            return this.currentStep > 2 ? 'step-circle completed' : 'step-circle active';
        }
        return 'step-circle';
    }

    get stepThreeClass() {
        return this.currentStep >= 3 ? 'step-circle completed' : 'step-circle';
    }

    // Validation clearing
    clearAllValidationErrors() {
        this.showLeadValidationError = false;
        this.showPaymentPlanValidationError = false;
        this.showFacadeValidationError = false;
    }

    handlePreviousStep() {
        if (this.currentStep === 3) {
            // Clear any preview data when going back from step 3
            this.offerPdfUrl = '';
            this.unitPreviewUrls = {};
            this.activePreviewUnitId = '';
            this.offerGenerationResults = [];
        }

        if (this.currentStep > 1) {
            this.currentStep -= 1;
            this.clearAllValidationErrors();
        }

        // If going back to step 2, ensure payment plans are loaded
        if (this.currentStep === 2 && this.selectedUnitsData.length > 0) {
            this.ensurePaymentPlansLoaded();
        }
    }

    // Add this method to handle the error display
    handleUnavailableUnitsError(unavailableUnits) {
        if (unavailableUnits.length > 0) {
            const unavailableNames = unavailableUnits.map(unit => `${unit.name} (${unit.status})`).join(', ');
            this.unavailableUnitsMessage = unavailableNames;
            this.showUnavailableUnitsError = true;

            // Auto-hide after 5 seconds
            setTimeout(() => {
                this.showUnavailableUnitsError = false;
            }, 5000);
        } else {
            this.showUnavailableUnitsError = false;
        }
    }

    // Add this method to check if unit is available
    isUnitAvailable(unitId) {
        const unit = this._allData.find(u => u.Id === unitId);
        return unit && unit.Status__c && unit.Status__c.toLowerCase() === 'available';
    }

    // Add this method to get unavailable units
    getUnavailableUnits() {
        const unavailable = [];
        this.selectedRowIds.forEach(unitId => {
            if (!this.isUnitAvailable(unitId)) {
                const unit = this._allData.find(u => u.Id === unitId);
                if (unit) {
                    unavailable.push({
                        id: unit.Id,
                        name: unit.Name,
                        status: unit.Status__c
                    });
                }
            }
        });
        return unavailable;
    }

    get mobileFilterBoxClass() {
        return this.showMobileFilter ? 'mobile-filter-box visible' : 'mobile-filter-box';

        // Set data attributes for mobile view
        if (this.isMobileView && this.showUnitSearchModal) {
            this.updateMobileDataAttributes();
        }
    }

    closeMobileFilter() {
        this.showMobileFilter = false;
        this.removeMobileClickOutsideListener();
    }

    // Update existing mobile filter methods:
    handleMobileSearchChange(event) {
        this.searchTerm = event.target.value;

    }

    handleMobileColumnFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value;

        this.mobileFilterValues = { ...this.mobileFilterValues, [field]: value };

    }

    // Mobile checkbox methods
    handleMobileSelectAll(event) {
        const isChecked = event.target.checked;

        if (isChecked) {
            // Select only available units
            this.mobileUnitsData.forEach(unit => {
                if (this.isUnitAvailable(unit.Id)) {
                    this.selectedRowIds.add(unit.Id);
                }
            });
        } else {
            // Deselect all
            this.selectedRowIds.clear();
        }

        this.updateMobileUnitsData();
    }

    handleMobileUnitCheckbox(event) {
        const unitId = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (this.isUnitAvailable(unitId)) {
                this.selectedRowIds.add(unitId);
            } else {
                // Show error and uncheck
                event.target.checked = false;
                const unit = this._allData.find(u => u.Id === unitId);
                if (unit) {
                    this.handleUnavailableUnitsError([{ id: unit.Id, name: unit.Name, status: unit.Status__c }]);
                }
            }
        } else {
            this.selectedRowIds.delete(unitId);
        }

        this.updateMobileUnitsData();
    }

    // Update the existing updateMobileUnitsData method:
    updateMobileUnitsData() {
        if (!this.filteredData || this.filteredData.length === 0) {
            this.mobileUnitsData = [];
            return;
        }

        const startIndex = (this.currentMobilePage - 1) * this.mobilePageSize;
        const endIndex = startIndex + this.mobilePageSize;
        const pagedData = this.filteredData.slice(startIndex, endIndex);

        this.mobileUnitsData = pagedData.map((unit, index) => {
            const isAvailable = this.isUnitAvailable(unit.Id);
            const isSelected = this.selectedRowIds.has(unit.Id);

            return {
                ...unit,
                SNo: startIndex + index + 1,
                isSelected: isSelected,
                isAvailable: isAvailable,
                unitCssClass: isSelected ? 'mobile-unit-item selected' : 'mobile-unit-item'
            };
        });
    }

    // Add getter for select all checkbox state
    get isAllMobileUnitsSelected() {
        if (!this.mobileUnitsData || this.mobileUnitsData.length === 0) return false;

        const availableUnits = this.mobileUnitsData.filter(unit => this.isUnitAvailable(unit.Id));
        if (availableUnits.length === 0) return false;

        return availableUnits.every(unit => this.selectedRowIds.has(unit.Id));
    }

    // Track mobile lead filter state
    @track showMobileLeadFilter = false;
    @track mobileLeadFilterBoxClass = 'mobile-lead-filter-box';

    // Mobile Lead Filter Methods
    toggleMobileLeadFilter() {
        this.showMobileLeadFilter = !this.showMobileLeadFilter;
        this.mobileLeadFilterBoxClass = this.showMobileLeadFilter
            ? 'mobile-lead-filter-box visible'
            : 'mobile-lead-filter-box';
    }

    closeMobileLeadFilter() {
        this.showMobileLeadFilter = false;
        this.mobileLeadFilterBoxClass = 'mobile-lead-filter-box';
    }

    // Add data attributes to handle visibility in CSS
    get mobileLeadFilterBoxClass() {
        return this.showMobileLeadFilter ? 'mobile-lead-filter-box visible' : 'mobile-lead-filter-box';
    }

    // Mobile step classes based on current step
    get mobileStepOneClass() {
        if (this.currentStep === 1) {
            return 'mobile-step-active';
        }
        return 'mobile-step-hidden';
    }

    get mobileStepTwoClass() {
        if (this.currentStep === 2) {
            return 'mobile-step-active';
        }
        return 'mobile-step-hidden';
    }

    get mobileStepThreeClass() {
        if (this.currentStep === 3) {
            return 'mobile-step-active';
        }
        return 'mobile-step-hidden';
    }



    // Mobile lead cards data
    get mobilePagedLeads() {
        const startIndex = (this.currentLeadPage - 1) * this.leadPageSize;
        const endIndex = startIndex + this.leadPageSize;
        const leads = this.filteredLeads || [];
        const pagedData = leads.slice(startIndex, endIndex);

        const result = [];

        for (let i = 0; i < pagedData.length; i++) {
            const lead = pagedData[i];
            const isSelected = this.selectedLeads.includes(lead.id);

            result.push({
                ...lead,
                isSelected: isSelected,
                cardClass: isSelected ? 'mobile-lead-card selected' : 'mobile-lead-card',
                radioClass: isSelected ? 'mobile-radio selected' : 'mobile-radio'
            });
        }

        return result;
    }

    // Mobile visibility getters
    get hasMobileLeads() {
        const leads = this.filteredLeads || [];
        return leads.length > 0;
    }

    get noMobileLeads() {
        if (this.isLoading) {
            return false;
        }
        const leads = this.filteredLeads || [];
        return leads.length === 0;
    }

    get emptyInstallments() {
        const installments = this.installments || [];
        return installments.length === 0;
    }

    get showFacadeInSummary() {
        if (!this.activeUnitData) {
            return false;
        }
        if (!this.activeUnitData.projectName) {
            return false;
        }

        const projectName = this.activeUnitData.projectName;
        if (projectName === 'Al Naseem') {
            return true;
        }
        if (projectName === 'Al Naseem C') {
            return true;
        }
        if (projectName.toLowerCase().includes('al naseem')) {
            return true;
        }

        return false;
    }

    get activeUnitDesign() {
        if (!this.activeUnitData) {
            return '';
        }
        if (!this.activeUnitData.selectedDesign) {
            return 'Not Selected';
        }
        return this.activeUnitData.selectedDesign;
    }

    get hasActivePreview() {
        if (!this.offerPdfUrl) {
            return false;
        }
        return this.offerPdfUrl.startsWith('/apex/');
    }

    get noActivePreview() {
        if (this.isLoading) {
            return false;
        }
        return !this.hasActivePreview;
    }

    get isLoadingPreview() {
        return this.isLoading && this.currentStep === 3;
    }

    get notLoading() {
        return !this.isLoading;
    }

    // Mobile event handlers
    handleMobileLeadCardClick(event) {
        const leadId = event.currentTarget.dataset.id;

        if (!leadId) {
            return;
        }

        // Clear any previous selection
        this.selectedLeads = [leadId];
        this.showLeadValidationError = false;

        // Update leads selection state
        this.updateLeadsSelectionState();
    }

    handleMobileUnitTabClick(event) {
        const idx = event.currentTarget.dataset.index;
        const index = parseInt(idx, 10);

        if (isNaN(index)) {
            return;
        }

        // Create a mock event object
        const mockEvent = {
            currentTarget: event.currentTarget,
            preventDefault: function () { }
        };

        this.handleUnitTabClick(mockEvent);
    }

    handleMobilePreviewTabClick(event) {
        const unitId = event.currentTarget.dataset.unitid;

        if (!unitId) {
            return;
        }

        // Create a mock event object
        const mockEvent = {
            currentTarget: event.currentTarget,
            preventDefault: function () { }
        };

        this.handlePreviewUnitTabClick(mockEvent);
    }

    // Helper method to update leads selection
    updateLeadsSelectionState() {
        // This will automatically update the mobilePagedLeads getter
        // which will refresh the card classes
        this.filteredLeads = [...this.filteredLeads];
    }

    // Also update the existing handleLeadRadioSelection for mobile compatibility
    handleLeadRadioSelection(event) {
        const selectedLeadId = event.target ? event.target.value : event.detail.value;

        if (selectedLeadId) {
            this.selectedLeads = [selectedLeadId];
            this.showLeadValidationError = false;
            this.updateLeadsSelectionState();
        }
    }

    updateMobileDataAttributes() {
        const elements = this.template.querySelectorAll('[data-loading], [data-error], [data-has-leads], [data-empty]');

        elements.forEach(element => {
            const attr = element.dataset.loading ? 'data-loading' :
                element.dataset.error ? 'data-error' :
                    element.dataset.hasLeads ? 'data-has-leads' :
                        element.dataset.empty ? 'data-empty' : null;

            if (attr) {
                const propName = attr.replace('data-', '');
                const value = this[propName];
                element.setAttribute(attr, value);
            }
        });
    }


    get isStepOneCompleted() {
        return this.currentStep > 1;
    }

    get isStepTwoCompleted() {
        return this.currentStep > 2;
    }

    get isStepThreeCompleted() {
        // Step 3 is completed when we're on step 3 and offer can be generated
        return this.currentStep === 3 && !this.isGenerateOfferDisabled;
    }

    handleStepClick(event) {
        const targetStep = parseInt(event.currentTarget.dataset.step);

        // Only allow navigation to completed steps or next logical step
        if (targetStep <= this.currentStep) {
            this.clearAllValidationErrors();
            if (targetStep > this.currentStep && !this.validateCurrentStep()) {
                return;
            }
            this.navigateToStep(targetStep);
        }
    }


    // Add this getter to determine if preview should be disabled
    get isPreviewDisabled() {
        return !this.hasActivePreview || this.isLoadingPreview;
    }

    // Add this method to open preview in new window
    openPreviewInNewWindow() {
        if (!this.hasActivePreview || this.isLoadingPreview) {
            return;
        }

        // Open the preview URL in a new window/tab
        window.open(this.activePreviewUrl, '_blank', 'noopener,noreferrer');
    }

    // Update this getter to check if we have an active preview
    get hasActivePreview() {
        return !!this.activePreviewUrl && this.activePreviewUrl.startsWith('/apex/');
    }

    get showPreviousButton() {
        return !this.isFirstStep;
    }
    openUnitAllocation() {
        this.showUnitAllocationModal = true;
    }

    closeUnitAllocation() {
        this.showUnitAllocationModal = false;
    }

    handleShowToast(event) {
        const { message, variant } = event.detail;
        this.refs.toast.show(message, variant);
    }

    handleCloseUnitAllocation() {
        this.showUnitAllocationModal = false;
    }


    get showGenerateOffer() {
    return this.brokerType === 'Owner' || this.brokerType === 'Agent';
}


    //Upto above offers and Mobile
}