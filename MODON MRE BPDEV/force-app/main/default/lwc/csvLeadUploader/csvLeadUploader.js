import { LightningElement, api, track, wire } from 'lwc';
import getNamesByEmail from '@salesforce/apex/ManagementLeadController.getNamesByEmail';
import createLeadsFromCsv from '@salesforce/apex/ManagementLeadController.createLeadsFromCsv';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// UI API fields for lightning-record-picker preview
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import USER_EMAIL_FIELD from '@salesforce/schema/User.Email';
const USER_FIELDS = [USER_NAME_FIELD, USER_EMAIL_FIELD];

export default class CsvLeadUploader extends LightningElement {
  @api pageSize = 10;
  @track isLoading = false;
  @track rows = [];
  @track columns = [];
  @track errorMessage = '';
  @track successMessage = '';
  @track page = 1;

  // Detected columns
  personEmailColumn; // "Sales Person Email" etc.
  unitColumn;        // "Unit"

  // email -> name
  @track personNames = {};
  nameColumnLabel = 'Sales Name';

  // Reassign modal
  @track isReassignOpen = false;
  @track reassignRowId = null;

  // record picker
  @track selectedUserId = null;
  @track pickedPreview = '';

  // apply to all
  @track applyToAll = false;

  _rowIdCounter = 0;

  // ----- wire selected user -> preview -----
  @wire(getRecord, { recordId: '$selectedUserId', fields: USER_FIELDS })
  wiredPickedUser({ data, error }) {
    if (error) {
      this.pickedPreview = '';
      this.errorMessage = 'Could not read selected user.';
      return;
    }
    if (data) {
      const name = getFieldValue(data, USER_NAME_FIELD) || '';
      const email = getFieldValue(data, USER_EMAIL_FIELD) || '';
      this.pickedPreview = [name, email].filter(Boolean).join(' — ');
    } else {
      this.pickedPreview = '';
    }
  }

  // ----- getters -----
  get hasRows() { return this.rows.length > 0; }
  get totalRows() { return this.rows.length; }
  get totalPages() { return Math.max(1, Math.ceil(this.rows.length / this.pageSize)); }
  get isFirstPage() { return this.page <= 1; }
  get isLastPage() { return this.page >= this.totalPages; }
  get isCreateDisabled() { return !this.hasRows || this.isLoading; }
  get isAssignDisabled() { return !this.selectedUserId; }

  // label normalization for display
  _displayLabelFor(col) {
    const norm = (s) => (s || '').toLowerCase().replace(/[\s_\-]+/g, ' ').trim();
    if (this.personEmailColumn && col === this.personEmailColumn && norm(col) === 'sales person') {
      return 'Sales Person Email';
    }
    return col;
  }

  get visibleColumns() {
    return this.columns.map(c => ({ label: this._displayLabelFor(c), fieldName: c }));
  }

  // Inject Sales Name after the email column + append Result, Reason
  get displayColumns() {
    const base = this.visibleColumns;
    const out = [];
    if (this.personEmailColumn) {
      for (const col of base) {
        out.push(col);
        if (col.fieldName === this.personEmailColumn) {
          out.push({ label: this.nameColumnLabel, fieldName: '_personName' });
        }
      }
    } else {
      out.push(...base);
    }
    out.push({ label: 'Result', fieldName: '_result' });
    out.push({ label: 'Reason', fieldName: '_reason' });
    return out;
  }

  get visibleRows() {
    const start = (this.page - 1) * this.pageSize;
    return this.rows.slice(start, start + this.pageSize);
  }

  get renderedRows() {
    const cols = this.displayColumns;
    return this.visibleRows.map(r => {
      const email = this.personEmailColumn ? (r[this.personEmailColumn] || '') : '';
      const personName = email ? (this.personNames[email] || '') : '';
      return {
        _rowId: r._rowId,
        cells: cols.map(c => {
          let val = '';
          if (c.fieldName === '_personName') val = personName;
          else if (c.fieldName === '_result') val = r._result || '';
          else if (c.fieldName === '_reason') val = r._reason || '';
          else val = (r[c.fieldName] ?? '');
          return { key: c.fieldName, value: val };
        })
      };
    });
  }

  // ----- pagination -----
  handlePrev() { if (this.page > 1) this.page--; }
  handleNext() { if (this.page < this.totalPages) this.page++; }

  // ----- file handling -----
  handleFileChange(event) {
    this.errorMessage = '';
    this.successMessage = '';
    const file = event.target.files && event.target.files[0];
    if (!file) return;

    if (!file.name.toLowerCase().endsWith('.csv')) {
      this.errorMessage = 'Please upload a CSV file.';
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      try {
        this.parseCSV(reader.result);
        this.page = 1;
      } catch (err) {
        this.errorMessage = 'Error parsing CSV: ' + (err?.message || err);
      }
    };
    reader.onerror = () => { this.errorMessage = 'Error reading file.'; };
    reader.readAsText(file);
  }

  parseCSV(csvText) {
    const lines = csvText.split(/\r?\n/).filter(l => l.trim().length > 0);
    if (lines.length === 0) throw new Error('CSV is empty');

    const header = this._parseCSVLine(lines[0]);
    if (header.length && header[0] && header[0].charCodeAt(0) === 0xFEFF) {
      header[0] = header[0].slice(1);
    }

    this.columns = header.map(h => (h || '').trim());
    this.personEmailColumn = this._detectPersonEmailColumn(this.columns);
    this.unitColumn = this._detectUnitColumn(this.columns);

    const parsed = [];
    for (let i = 1; i < lines.length; i++) {
      const values = this._parseCSVLine(lines[i]);
      while (values.length < this.columns.length) values.push('');
      const row = { _rowId: ++this._rowIdCounter };
      this.columns.forEach((col, idx) => { row[col] = (values[idx] || '').trim(); });
      // init outcome fields
      row._result = '';
      row._reason = '';
      parsed.push(row);
    }
    this.rows = parsed;

    // Resolve names for the detected email column
    if (this.personEmailColumn) {
      const uniqueEmails = Array.from(new Set(
        this.rows.map(r => r[this.personEmailColumn]).filter(Boolean)
      ));
      if (uniqueEmails.length) {
        getNamesByEmail({ emails: uniqueEmails })
          .then(mapper => { this.personNames = mapper || {}; })
          .catch(() => { this.errorMessage = 'Could not resolve sales names.'; });
      }
    }
  }

  _parseCSVLine(line) {
    const result = [];
    let cur = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (ch === '"') {
        if (inQuotes && line[i + 1] === '"') { cur += '"'; i++; }
        else { inQuotes = !inQuotes; }
      } else if (ch === ',' && !inQuotes) { result.push(cur); cur = ''; }
      else { cur += ch; }
    }
    result.push(cur);
    return result;
  }

  _detectPersonEmailColumn(cols) {
    const norm = (s) => (s || '').toLowerCase().replace(/[\s_\-]+/g, ' ').trim();
    const lc = cols.map(norm);
    const salesTests = [
      c => c === 'sales person',
      c => c === 'salesperson',
      c => c === 'sales person email',
      c => c === 'salesperson email',
      c => c.includes('sales') && c.includes('person') && c.includes('email'),
      c => c.includes('sales') && c.includes('email'),
      c => c.includes('sales') && c.includes('person') && !c.includes('name')
    ];
    for (const t of salesTests) { const idx = lc.findIndex(t); if (idx >= 0) { this.nameColumnLabel = 'Sales Name'; return cols[idx]; } }
    const ownerTests = [
      c => c === 'lead owner',
      c => c === 'owner email',
      c => c.includes('owner') && c.includes('email'),
      c => c === 'owner',
      c => c === 'leadowner'
    ];
    for (const t of ownerTests) { const idx = lc.findIndex(t); if (idx >= 0) { this.nameColumnLabel = 'Owner Name'; return cols[idx]; } }
    return undefined;
  }

  _detectUnitColumn(cols) {
    const norm = (s) => (s || '').toLowerCase().replace(/[\s_\-]+/g, ' ').trim();
    for (const c of cols) {
      const n = norm(c);
      if (n === 'unit' || n === 'unit name' || n.includes('unit')) return c;
    }
    return undefined;
  }

  // ----- delete -----
  handleDeleteRow(event) {
    const rowId = Number((event.currentTarget || event.target).dataset.rowid);
    const idx = this.rows.findIndex(r => r._rowId === rowId);
    if (idx !== -1) {
      this.rows.splice(idx, 1);
      this.rows = [...this.rows];
      if (this.page > this.totalPages) this.page = this.totalPages;
    }
  }

  // ----- reassign modal -----
  openReassign(event) {
    this.reassignRowId = Number((event.currentTarget || event.target).dataset.rowid);
    this.selectedUserId = null;
    this.pickedPreview = '';
    this.applyToAll = false;
    this.isReassignOpen = true;
  }
  closeReassign() {
    this.isReassignOpen = false;
    this.reassignRowId = null;
    this.selectedUserId = null;
    this.pickedPreview = '';
    this.applyToAll = false;
  }
  get activeReassign() {
    if (!this.isReassignOpen || !this.reassignRowId) return {};
    const row = this.rows.find(r => r._rowId === this.reassignRowId);
    if (!row) return {};
    const currentEmail = this.personEmailColumn ? (row[this.personEmailColumn] || '') : '';
    const currentName = currentEmail ? (this.personNames[currentEmail] || '') : '';
    return { row, currentEmail, currentName };
  }
  handleUserPicked(e) {
    let val = null;
    if (e?.detail?.value) val = e.detail.value;
    if (!val && e?.detail?.recordId) val = e.detail.recordId;
    if (!val && Array.isArray(e?.detail?.values) && e.detail.values.length) val = e.detail.values[0];
    if (!val && e?.target?.value) val = e.target.value;

    this.selectedUserId = val || null;
    if (!this.selectedUserId) this.pickedPreview = '';
  }
  toggleApplyAll(e) { this.applyToAll = !!e.target.checked; }

  confirmReassign() {
    if (!this.personEmailColumn || !this.selectedUserId) return;

    const parts = (this.pickedPreview || '').split(' — ');
    const pickedName = parts[0] || '';
    const pickedEmail = parts[1] || '';
    if (!pickedEmail) return;

    if (this.applyToAll) {
      this.rows = this.rows.map(r => ({ ...r, [this.personEmailColumn]: pickedEmail }));
    } else if (this.reassignRowId) {
      const idx = this.rows.findIndex(r => r._rowId === this.reassignRowId);
      if (idx !== -1) {
        const updated = { ...this.rows[idx] };
        updated[this.personEmailColumn] = pickedEmail;
        this.rows = this.rows.map((r, i) => (i === idx ? updated : r));
      }
    }
    if (pickedName) this.personNames = { ...this.personNames, [pickedEmail]: pickedName };
    this.closeReassign();
  }

  // ----- validations -----
  _validateAllSalesPersonsPresent() {
    if (!this.personEmailColumn) {
      this.errorMessage = 'Missing "Sales Person Email" column in the CSV.';
      return false;
    }
    const missing = [];
    for (let i = 0; i < this.rows.length; i++) {
      const r = this.rows[i];
      const email = (r[this.personEmailColumn] || '').trim();
      const name = email ? (this.personNames[email] || '').trim() : '';
      if (!email || !name) {
        missing.push(i + 1);
        if (missing.length >= 10) break;
      }
    }
    if (missing.length) {
      const more = this.rows.length - missing.length;
      this.errorMessage =
        `Each lead must have a Sales Person Email and a resolved Sales Name.\n` +
        `Missing on rows: ${missing.join(', ')}${more > 0 ? ` ... (+${more} more)` : ''}`;
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  // ----- create leads -----
  async handleCreate() {
    this.isLoading = true;
    this.successMessage = '';
    this.errorMessage = '';

    try {
      if (!this.hasRows) {
        this.errorMessage = 'Please upload at least one record to create leads.';
        return;
      }
      if (!this._validateAllSalesPersonsPresent()) return;

      const result = await createLeadsFromCsv({
        rows: this.rows, // contains _rowId for each row
        salesPersonEmailColumn: this.personEmailColumn,
        unitColumn: this.unitColumn
      });

      // Merge per-row outcomes
      if (Array.isArray(result?.outcomes) && result.outcomes.length) {
        const byId = new Map(result.outcomes.map(o => [Number(o.rowId), o]));
        this.rows = this.rows.map(r => {
          const oc = byId.get(Number(r._rowId));
          if (!oc) return r;
          return {
            ...r,
            _result: oc.success ? 'Success' : 'Failed',
            _reason: oc.message || (oc.success ? 'Created' : 'Unknown error')
          };
        });
      }

      // Top summary
      if (result?.errorCount > 0) {
        const preview = (result.errors || []).slice(0, 10)
          .map(e => `Row ${e.rowNumber}: ${e.message}`).join('\n');
        this.errorMessage = `Some of the leads failed to create : ${result.errorCount}.`;//\n${preview}${result.errorCount > 10 ? '\n... more errors' : ''}`;
        this.successMessage = result.createdCount ? `${result.createdCount} leads created successfully.` : '';
      } else {
        this.errorMessage = '';
        this.successMessage = `${result?.createdCount || 0} leads created successfully.`;
        this.page = 1;
      }
    } catch (err) {
      this.errorMessage = 'Failed to create leads: ' + (err?.body?.message || err?.message || err);
    } finally {
      this.isLoading = false;
    }
  }

  // ----- export CSV (with results) -----
    exportCsv() {
    try {
      if (!this.rows?.length) return;

      // Define headers and field order
      const headers = [
        ...this.columns,
        this.personEmailColumn ? this.nameColumnLabel : null,
        'Result',
        'Reason'
      ].filter(Boolean);

      const fieldOrder = [
        ...this.columns,
        this.personEmailColumn ? '_personName' : null,
        '_result',
        '_reason'
      ].filter(Boolean);

      const nameByEmail = this.personNames || {};
      const lines = [];

      const BOM = '\uFEFF';
      lines.push(BOM + headers.join(','));

      // Build CSV rows
      for (const r of this.rows) {
        const vals = fieldOrder.map(f => {
          let v = '';
          if (f === '_personName') {
            const email = this.personEmailColumn ? (r[this.personEmailColumn] || '') : '';
            v = email ? (nameByEmail[email] || '') : '';
          } else {
            v = (r[f] ?? '');
          }
          const s = String(v);
          return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
        });
        lines.push(vals.join(','));
      }

      const csv = lines.join('\n');

      const blob = new Blob([csv], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);

      const a = this.template.querySelector('[data-id="csv-download"]');
      if (a) {
        a.href = url;
        a.click();
        a.removeAttribute('href');
      }

      setTimeout(() => URL.revokeObjectURL(url), 0);

    } catch (e) {
      console.error('Export CSV failed', e);
    }
}


}