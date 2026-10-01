import { LightningElement, track, wire } from 'lwc';
import getPendingApprovalLeads from '@salesforce/apex/ManagementLeadController.getPendingApprovalLeads';
import updateReferralApprovalStatus from '@salesforce/apex/ManagementLeadController.updateReferralApprovalStatus';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ManagementLeadRetiredApproval extends LightningElement {
  // data + ui
  @track isLoading = false;
  @track data = [];
  rawWire; // store wire result to refresh
  pageSize = 10;
  @track currentPage = 1;
  @track selectedRowIds = [];

  // Unit name search
  @track unitSearch = '';   // shown in input
  _unitSearchNorm = '';     // normalized for matching
  _searchTimer;             // debounce timer
  get hasUnitSearch() { return this._unitSearchNorm.length > 0; }

  // update on blur/Enter
  handleUnitSearchChange = (e) => {
    const raw = e.target.value || '';
    this._applyUnitSearch(raw);
  };

  // live search (debounced)
  handleUnitSearchKeyup = (e) => {
    const raw = e.target.value || '';
    clearTimeout(this._searchTimer);
    this._searchTimer = setTimeout(() => this._applyUnitSearch(raw), 200);
  };

  _applyUnitSearch(raw) {
    this.unitSearch = raw;
    this._unitSearchNorm = raw.trim().toLowerCase();
    this.currentPage = 1;
  }

  clearUnitSearch = () => {
    this.unitSearch = '';
    this._unitSearchNorm = '';
    this.currentPage = 1;
  };

  _getSearchTerms() {
    if (!this._unitSearchNorm) return [];
    // split on commas or whitespace; keep non-empty
    return this._unitSearchNorm
      .split(/[,\s]+/)
      .map(s => s.trim())
      .filter(Boolean);
  }

  // Date filter
  @track selectedDateRange = 'all';
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
  handleDateRangeChange = (e) => {
    this.selectedDateRange = e.detail.value || 'all';
    this.currentPage = 1;
  };

  columns = [
    { label: 'Lead', fieldName: 'LeadUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    { label: 'Mobile', fieldName: 'Mobile', type: 'phone' },
    { label: 'Owner', fieldName: 'OwnerName', type: 'text' },
    { label: 'Lead Age', fieldName: 'LeadAgeHistory', type: 'text' },
    { label: 'Status', fieldName: 'leadStatus', type: 'text' },
    { label: 'Unit', fieldName: 'ReferralUnitName', type: 'text'},
    { label: 'Unit Allocated Status', fieldName: 'UnitAllocatedStatus', type: 'text' },
    { label: 'Retire Lead Reason', fieldName: 'RetireLeadReason', type: 'text', wrapText: true, initialWidth: 320 },
    { label: 'Retire Lead Comments', fieldName: 'RetireLeadComments', type: 'text', wrapText: true, initialWidth: 320 },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
    {
      type: 'action',
      typeAttributes: {
        rowActions: [
          { label: 'Approve', name: 'approve' },
          { label: 'Reject',  name: 'reject' }
        ]
      }
    }
  ];

  @wire(getPendingApprovalLeads)
  wired(result) {
    this.rawWire = result;
    const { data, error } = result;
    if (data) {
      this.data = (data || []).map(r => {
        const id = r.Id ? String(r.Id) : null;
        const unitStr = (r.ReferralUnitName || '').toString();
        return {
          ...r,
          Id: id,
          LeadUrl: id ? `/lightning/r/Lead/${id}/view` : null,
          // cached fields for robust searching
          _unitLower: unitStr.toLowerCase(),
          _unitTokensLower: unitStr
            .split(',')                 // handles "Unit 1,Unit 2"
            .map(s => s.trim().toLowerCase())
            .filter(Boolean)
        };
      });
      this.currentPage = 1;
    } else if (error) {
      this.toast('Error', 'Failed to load pending approvals', 'error');
    }
  }

  // Filters (date + unit search)
  get _createdDateThreshold() {
    const today = new Date();
    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const map = { today: 0, last7: 6, last30: 29, last180: 179, last365: 364 };
    if (this.selectedDateRange === 'all') return null;
    const daysBack = map[this.selectedDateRange];
    if (daysBack == null) return null;
    const d = new Date(startOfToday);
    d.setDate(d.getDate() - daysBack);
    return d;
  }

  get filteredData() {
    const threshold = this._createdDateThreshold;

    // date filter first
    const byDate = (this.data || []).filter(r => {
      if (!threshold) return true;
      const created = r.CreatedDate ? new Date(r.CreatedDate) : null;
      return created ? (created >= threshold) : false;
    });

    // unit filter
    const terms = this._getSearchTerms();
    if (!terms.length) return byDate;

    return byDate.filter(r => {
      const whole = r._unitLower || '';
      const tokens = r._unitTokensLower || [];
      // Match if EVERY term is found somewhere (whole or tokens).
      // Also ignore spaces when comparing (so "unit2" matches "unit 2").
      return terms.every(t => {
        const tNoSpace = t.replace(/\s+/g, '');
        return (
          whole.includes(t) ||
          whole.replace(/\s+/g, '').includes(tNoSpace) ||
          tokens.some(tok => tok.includes(t) || tok.replace(/\s+/g, '').includes(tNoSpace))
        );
      });
    });
  }

  // Paging
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
  prevPage = () => { if (this.currentPage > 1) this.currentPage -= 1; };
  nextPage = () => { if (this.currentPage < this.totalPages) this.currentPage += 1; };

  // Selection
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

  // Actions
  handleRowAction(e) {
    const action = e.detail.action.name;
    const row = e.detail.row;
    if (action === 'approve') this._act('Approve', [row.Id]);
    if (action === 'reject')  this._act('Rejected', [row.Id]);
  }
  approveSelected = () => {
    if (!this.selectedRowIds.length) { this.toast('Info', 'No rows selected', 'info'); return; }
    this._act('Approve', this.selectedRowIds);
  }
  rejectSelected = () => {
    if (!this.selectedRowIds.length) { this.toast('Info', 'No rows selected', 'info'); return; }
    this._act('Rejected', this.selectedRowIds);
  }

  async _act(decision, ids) {
    if (!ids || !ids.length) return;
    this.isLoading = true;
    try {
      const res = await updateReferralApprovalStatus({ leadIds: ids, decision });
      const successIds = res?.successIds || [];
      const successCount = res?.successCount || successIds.length;
      const errorCount = res?.errorCount || 0;

      // Optimistic removal
      if (successIds.length) {
        const successSet = new Set(successIds.map(i => String(i)));
        this.data = (this.data || []).filter(r => !successSet.has(String(r.Id)));
        this.selectedRowIds = (this.selectedRowIds || []).filter(id => !successSet.has(String(id)));
      }

      if (errorCount > 0 && successCount > 0) {
        this.toast('Partial Success', `${successCount} marked ${decision}. ${errorCount} failed.`, 'warning');
      } else if (errorCount > 0) {
        this.toast('Failed', 'No records updated.', 'error');
      } else {
        this.toast('Success', `${successCount} record(s) marked ${decision}.`, 'success');
      }

      await refreshApex(this.rawWire);
    } catch (e) {
      this.toast('Error', e?.body?.message || e?.message || 'Update failed', 'error');
    } finally {
      this.isLoading = false;
    }
  }

  refresh = async () => { await refreshApex(this.rawWire); };

  // Toast helper
  toast(title, message, variant='info') {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
  }
}