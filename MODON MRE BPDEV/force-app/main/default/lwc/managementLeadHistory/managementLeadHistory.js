import { LightningElement, track, wire } from 'lwc';
import getManagementLeads from '@salesforce/apex/ManagementLeadController.getManagementLeads';
import reassignLeadOwnersAction from '@salesforce/apex/ManagementLeadController.reassignLeadOwners';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// Record Picker preview (Name — Email)
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import USER_EMAIL_FIELD from '@salesforce/schema/User.Email';
const USER_FIELDS = [USER_NAME_FIELD, USER_EMAIL_FIELD];

export default class ManagementLeadHistory extends NavigationMixin(LightningElement) {
  // data
  @track rawData = [];
  @track data = []; // normalized rows
  @track isLoading = false;

  // filters
  @track selectedDateRange = 'all';
  @track selectedAllocStatus = 'all';
  @track selectedConverted = 'all'; // new filter
  @track selectedProject = 'all';
  @track unitFilterText = '';
  @track isHideCheckboxColumn = true;
  @track blockedUntil;

  // pagination
  pageSize = 10;
  @track currentPage = 1;

  // selection
  @track selectedRowIds = [];

  // modal state for reassign
  @track isReassignModalOpen = false;
  reassignTarget = null;

  // record picker state
  @track selectedUserId = null;
  @track pickedPreview = ''; // "Name — Email"

  // table columns (ellipsis + tooltip for Project & Unit)
  columns = [
    { label: 'Lead', fieldName: 'LeadUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    { label: 'Mobile', fieldName: 'Mobile', type: 'phone' },
    { label: 'Owner', fieldName: 'OwnerName', type: 'text' },
    { label: 'Lead Age', fieldName: 'LeadAgeHistory', type: 'text' },
    { label: 'Status', fieldName: 'leadStatus', type: 'text' },

    {
      label: 'Project',
      fieldName: 'projectName',
      type: 'text',
      cellAttributes: {
        class: 'project-column',
        tooltip: { fieldName: 'projectName' }
      }
    },
    {
      label: 'Unit(s)',
      fieldName: 'ReferralUnitName',
      type: 'text',
      cellAttributes: {
        class: 'unit-column',
        tooltip: { fieldName: 'ReferralUnitName' }
      }
    },

    { label: 'Unit Allocated Status', fieldName: 'UnitAllocatedStatus', type: 'text' },
    { label: 'Converted', fieldName: 'IsConverted', type: 'text' }, // show Yes/No

    {
      label: 'Created Date',
      fieldName: 'CreatedDate',
      type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' }
    },
    {
      type: 'button',
      fieldName: 'reassignAction',
      typeAttributes: {
        label: 'Re-Assign',
        name: 'reassign',
        title: 'Re-Assign',
        variant: 'destructive',
        class: 'reassign-btn',
        disabled: { fieldName: 'reassignDisabled' },    // 🔒 disabled for converted
        tooltip: { fieldName: 'reassignTooltip' }       // shows reason
      }
    }
  ];

  _wiredLeadsResult;

  // ===== Wire: load leads =====
  @wire(getManagementLeads)
  wiredLeads(result) {
    this.isLoading = true;
    this._wiredLeadsResult = result;
    const { data, error } = result;

    if (data) {
      this.rawData = data;
      this.data = (data || []).map(r => {
        const id = r.Id ? String(r.Id) : null;

        // Converted logic (wrapper sends 'Yes' / 'No')
        const isConvertedYes = (r.IsConverted || '').toLowerCase() === 'yes';

        return {
          ...r,
          Id: id,
          LeadUrl: id ? `/lightning/r/Lead/${id}/view` : null,
          Name: r.Name || '',
          Email: r.Email || '',
          Mobile: r.Mobile || '',
          OwnerName: r.OwnerName || '(Unassigned)',
          LeadAgeHistory: r.LeadAgeHistory || '0 Days',
          leadStatus: r.leadStatus || '',
          CreatedDate: r.CreatedDate || null,

          // multi-value strings
          projectName: r.projectName || '',
          ReferralUnitName: r.ReferralUnitName || '',
          UnitAllocatedStatus: r.UnitAllocatedStatus || '',

          // Converted flags for UI
          IsConverted: r.IsConverted || 'No',
          reassignDisabled: isConvertedYes,                         // <- used by button
          reassignTooltip: isConvertedYes ? 'Cannot re-assign a converted lead' : 'Re-assign this lead'
        };
      });
      this.currentPage = 1;
    } else if (error) {
      this.showToast('Error', 'Failed to load leads', 'error');
    }
    this.isLoading = false;
  }

  async _reloadFromServer() {
    try { await refreshApex(this._wiredLeadsResult); } catch (e) { /* no-op */ }
  }

  // ===== Record picker preview =====
  @wire(getRecord, { recordId: '$selectedUserId', fields: USER_FIELDS })
  wiredPickedUser({ data, error }) {
    if (error) { this.pickedPreview = ''; return; }
    if (data) {
      const name = getFieldValue(data, USER_NAME_FIELD) || '';
      const email = getFieldValue(data, USER_EMAIL_FIELD) || '';
      this.pickedPreview = [name, email].filter(Boolean).join(' — ');
    } else { this.pickedPreview = ''; }
  }

  // ===== Filter change handlers =====
  handleDateRangeChange = (e) => { this.selectedDateRange = e.detail.value || 'all'; this.currentPage = 1; };
  handleAllocStatusChange = (e) => { this.selectedAllocStatus = e.detail.value || 'all'; this.currentPage = 1; };
  handleConvertedChange = (e) => { this.selectedConverted = e.detail.value || 'all'; this.currentPage = 1; };
  handleProjectDropdownChange = (e) => { this.selectedProject = e.detail.value || 'all'; this.currentPage = 1; };
  handleUnitFilterChange = (e) => { this.unitFilterText = e.target.value || ''; this.currentPage = 1; };

  // ===== Helpers (tokenize comma/newline lists) =====
  _normalizeTokens(str) {
    return String(str || '')
      .split(/[,|\n]/g)
      .map(s => s.trim().toLowerCase())
      .filter(Boolean);
  }
  _fieldTokens(val) {
    return String(val || '')
      .split(/[,|\n]/g)
      .map(s => s.trim().toLowerCase())
      .filter(Boolean);
  }

  // Build Project dropdown from data
  get projectNameOptions() {
    const map = new Map(); // lower -> display label
    (this.data || []).forEach(r => {
      this._fieldTokens(r.projectName).forEach(tok => {
        if (!map.has(tok)) {
          const raw = (r.projectName || '')
            .split(/[,|\n]/g).map(s => s.trim())
            .find(s => s.toLowerCase() === tok);
          map.set(tok, raw || tok);
        }
      });
    });

    const opts = Array.from(map.entries())
      .sort((a, b) => a[1].localeCompare(b[1], undefined, { sensitivity: 'base' }))
      .map(([lower, label]) => ({ label, value: lower }));

    return [{ label: 'All', value: 'all' }, ...opts];
  }

  // Converted filter options
  get convertedOptions() {
    return [
      { label: 'All', value: 'all' },
      { label: 'Converted', value: 'converted' },
      { label: 'Not Converted', value: 'not' }
    ];
  }

  // Compute threshold date for selected range (inclusive)
  get _createdDateThreshold() {
    const today = new Date();
    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const map = { today: 0, last7: 6, last30: 29, last180: 179, last365: 364 };
    if (this.selectedDateRange === 'all') return null;
    const daysBack = map[this.selectedDateRange];
    if (daysBack == null) return null;
    const threshold = new Date(startOfToday);
    threshold.setDate(threshold.getDate() - daysBack);
    return threshold;
  }

  // ===== Main filtering =====
  get filteredData() {
    const threshold = this._createdDateThreshold;
    const statusFilter = this.selectedAllocStatus;
    const selectedProjectLower = (this.selectedProject || 'all');
    const unitTokens = this._normalizeTokens(this.unitFilterText);

    return (this.data || []).filter(r => {
      // Date
      let passDate = true;
      if (threshold) {
        const created = r.CreatedDate ? new Date(r.CreatedDate) : null;
        passDate = created ? (created >= threshold) : false;
      }

      // Alloc status
      let passStatus = true;
      if (statusFilter !== 'all') {
        const val = r.UnitAllocatedStatus || r.Unit_Allocated_Status__c || '';
        passStatus = (val === statusFilter);
      }

      // Converted filter
      let passConverted = true;
      const isYes = (r.IsConverted || '').toLowerCase() === 'yes';
      if (this.selectedConverted === 'converted') passConverted = isYes;
      else if (this.selectedConverted === 'not') passConverted = !isYes;

      // Project dropdown (record may be multi-valued)
      let passProject = true;
      if (selectedProjectLower !== 'all') {
        const recProjectTokens = this._fieldTokens(r.projectName);
        passProject = recProjectTokens.some(p =>
          p === selectedProjectLower || p.includes(selectedProjectLower) || selectedProjectLower.includes(p)
        );
      }

      // Unit text input (record may be multi-valued)
      let passUnit = true;
      if (unitTokens.length) {
        const recUnitTokens = this._fieldTokens(r.ReferralUnitName);
        passUnit = unitTokens.some(tok =>
          recUnitTokens.some(u => u.includes(tok) || tok.includes(u))
        );
      }

      return passDate && passStatus && passConverted && passProject && passUnit;
    });
  }

  // ===== Pagination getters =====
  get totalRows() { return this.filteredData.length; }
  get totalPages() { return Math.max(1, Math.ceil(this.totalRows / this.pageSize)); }
  get pagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    return this.filteredData.slice(start, start + this.pageSize);
  }
  get startRow() { return this.totalRows === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1; }
  get endRow() { return Math.min(this.totalRows, this.currentPage * this.pageSize); }
  get isFirstPage() { return this.currentPage <= 1; }
  get isLastPage() { return this.currentPage >= this.totalPages; }

  // selection helpers (kept for future multi-select use)
  get selectedRowsForTable() {
    const pageIds = new Set((this.pagedData || []).map(r => String(r.Id)));
    return (this.selectedRowIds || []).filter(id => pageIds.has(String(id)));
  }
  handleRowSelection(event) {
    const selectedRows = event.detail.selectedRows || [];
    const selectedOnPageIds = new Set(selectedRows.map(r => String(r.Id)));
    const pageRowIds = new Set((this.pagedData || []).map(r => String(r.Id)));
    const globalSet = new Set((this.selectedRowIds || []).map(id => String(id)));
    selectedOnPageIds.forEach(id => globalSet.add(id));
    pageRowIds.forEach(id => { if (!selectedOnPageIds.has(id)) globalSet.delete(id); });
    this.selectedRowIds = Array.from(globalSet);
  }

  // row action
  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    if (actionName === 'reassign') this.openReassignModal(row);
  }

  // modal open/close
  openReassignModal(row) {
    this.reassignTarget = row;
    this.selectedUserId = null;
    this.pickedPreview = '';
    this.isReassignModalOpen = true;
  }
  closeReassignModal = () => {
    this.isReassignModalOpen = false;
    this.reassignTarget = null;
    this.selectedUserId = null;
    this.pickedPreview = '';
  };

  // record picker handler
  handleUserPicked(e) {
    let val = null;
    if (e?.detail?.value) val = e.detail.value;
    if (!val && e?.detail?.recordId) val = e.detail.recordId;
    if (!val && Array.isArray(e?.detail?.values) && e.detail.values.length) val = e.detail.values[0];
    if (!val && e?.target?.value) val = e.target.value;
    this.selectedUserId = val || null;
  }
  handleBlockedUntilChange(event){
    this.blockedUntil = event.target.value;
  }
  // apply / validation
  get isApplyDisabled() { return !this.selectedUserId; }
  get reassignSelectedCount() { return (this.selectedRowIds || []).length; }
  get reassignTargetName() { return (this.reassignTarget && this.reassignTarget.Name) ? this.reassignTarget.Name : '(No lead)'; }
  get reassignTargetOwnerName() { return (this.reassignTarget && this.reassignTarget.OwnerName) ? this.reassignTarget.OwnerName : ''; }
  get selectedOwnerPreview() { return this.pickedPreview; }
  get selectedOwnerName() { return (this.pickedPreview || '').split(' — ')[0] || ''; }

  // Apply to single row
  async applyReassignToSingle() {
    if (!this.selectedUserId){
      this.showToast('Error', 'Please select a user to re-assign the lead to.', 'error');
      return;
    }
    if (!this.blockedUntil && this.reassignTarget.UnitAllocatedStatus === 'Allocated'){
      this.showToast('Error', 'Please select "Blocked Until" Time.', 'error');
      return;
    } 
    this.isLoading = true;
    this.isReassignModalOpen = false;
    if (!this.reassignTarget || !this.selectedUserId) return;
    await this._reassignOwnerOnServer([this.reassignTarget.Id]);
  }

  // Server call
  _afterPaint() { return new Promise(resolve => requestAnimationFrame(resolve)); }
  async _reassignOwnerOnServer(leadIds) {
    if (!leadIds || leadIds.length === 0) return;
    this.isLoading = true;
    await this._afterPaint();

    try {
      const res = await reassignLeadOwnersAction({ leadIds, newOwnerId: this.selectedUserId, blockedUntil: this.blockedUntil });

      const successIds   = res?.successIds   || [];
      const successCount = res?.successCount || successIds.length;
      const errorCount   = res?.errorCount   || 0;
      const ownerName    = res?.ownerName    || this.selectedOwnerName || '(New Owner)';

      if (successIds.length) this._applyOwnerToIds(successIds, ownerName);

      this.closeReassignModal();

      if (errorCount > 0 && successCount > 0) {
        this.showToast('Partial Success', `${successCount} reassigned to ${ownerName}. ${errorCount} failed.`, 'warning');
      } else if (errorCount > 0) {
        const preview = (res.errors || []).slice(0, 5).map(e => `• ${e.id || ''} ${e.message}`).join('\n');
        this.showToast('Failed', `No records reassigned.\n${preview}`, 'error');
      } else {
        this.showToast('Success', `Assigned ${successCount} lead(s) to ${ownerName}`, 'success');
      }

      await this._reloadFromServer();
    } catch (e) {
      this.showToast('Error', e?.body?.message || e?.message || 'Failed to reassign leads', 'error');
    } finally {
      this.isLoading = false;
    }
  }

  _applyOwnerToIds(ids, ownerName) {
    const idSet = new Set(ids.map(i => String(i)));
    this.data = (this.data || []).map(r => (idSet.has(String(r.Id)) ? { ...r, OwnerName: ownerName } : r));
  }

  // pagination controls
  prevPage = () => { if (this.currentPage > 1) this.currentPage -= 1; };
  nextPage = () => { if (this.currentPage < this.totalPages) this.currentPage += 1; };
  refreshData = () => { this.currentPage = 1; this.showToast('Info', 'Refreshed view (client-side)', 'info'); };

  // toast helper
  showToast(title, message, variant = 'info') {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
  }

  navigateToTab() {
    this[NavigationMixin.Navigate]({
      type: 'standard__navItemPage',
      attributes: { apiName: 'Management_Lead' }
    });
  }

  // Static options
  get dateRangeOptions() {
    return [
      { label: 'All', value: 'all' },
      { label: 'Today', value: 'today' },
      { label: 'Last 7 days', value: 'last7' },
      { label: 'Last 30 days', value: 'last30' },
      { label: 'Last 6 months', value: 'last180' },
      { label: 'Last 1 year', value: 'last365' }
    ];
  }
  get allocStatusOptions() {
    return [
      { label: 'All', value: 'all' },
      { label: 'Allocated', value: 'Allocated' },
      { label: 'Un-Allocated', value: 'Un-Allocated' }
    ];
  }
}