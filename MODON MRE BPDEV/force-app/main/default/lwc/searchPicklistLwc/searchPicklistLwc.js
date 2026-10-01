import { LightningElement, api, track } from 'lwc';

export default class SearchPicklistLwc extends LightningElement {
  /** Public API */
  @api label;
  @api placeholder = 'Search…';
  @api disabled = false;
  @api required = false;

  _mouseDownOnOption = false;


  _value = '';
  @api
  get value() {
    return this._value;
  }
  set value(v) {
    this._value = v || '';
    this.inputValue = this._findLabelByValue(this._value);
    this._refreshOptionStates();
  }

  _options = [];
  @api
  get options() {
    return this._options;
  }
  set options(arr) {
    const list = Array.isArray(arr) ? arr : [];
    // Expect [{label, value}]
    this._options = list;
    this._normalized = list.map((o, i) => ({
      id: `opt-${i}`,
      label: o.label,
      value: o.value,
      className: 'slds-listbox__option slds-listbox__option_plain',
      ariaSelected: 'false'
    }));
    this.filterOptions();
  }

  /** Internal state */
  @track filteredOptions = [];
  @track inputValue = '';
  @track expanded = false;
  @track focusedIndex = -1;
  @track errorMessage = '';

  _normalized = [];
  _blurTimeout;

  connectedCallback() {
    this.filterOptions();
  }

  /** Classes & ARIA */
  get containerClass() {
    const base = 'slds-combobox_container slds-has-input slds-combobox';
    return `${base} ${this.expanded ? 'slds-is-open' : 'slds-is-closed'}`;
  }
  get activeOptionId() {
    return this.focusedIndex >= 0 && this.filteredOptions[this.focusedIndex]
      ? this.filteredOptions[this.focusedIndex].id
      : null;
  }

  /** Behavior */
  open = () => {
    if (this.disabled) return;
    this.expanded = true;
    this.filterOptions();
  };

  close = () => {
    this.expanded = false;
    this.focusedIndex = -1;
    this._refreshOptionStates();
  };

  handleOptionMouseDown = (e) => {
  const idx = Number(e.currentTarget.parentElement.dataset.index);
  const opt = this.filteredOptions[idx];
  if (opt) {
    this._mouseDownOnOption = true;
    this._selectOption(opt);
  }
};

  handleBlur = () => {
  if (this._mouseDownOnOption) {
    setTimeout(() => {
      this._mouseDownOnOption = false;
      this.close();
    }, 0);
    return;
  }
  setTimeout(() => this.close(), 120);
};

  handleInput = (e) => {
    this.inputValue = e.target.value || '';
    this.filterOptions();
    this.expanded = true;
    this.focusedIndex = this.filteredOptions.length ? 0 : -1;
    this._refreshOptionStates();
    this._validateRequired();
  };

  filterOptions() {
    const q = this.inputValue || '';
    const normQ = q.toLowerCase();

    const list = (this._normalized || []).filter((o) =>
      o.label.toLowerCase().includes(normQ)
    );

    this.filteredOptions = list.map(o => ({ ...o }));
    this._refreshOptionStates();
  }

  _refreshOptionStates() {
    const base = 'slds-listbox__option slds-listbox__option_plain';
    this.filteredOptions = (this.filteredOptions || []).map((o, idx) => {
      const isSelected = o.value === this._value;
      const isActive = idx === this.focusedIndex;
      const classes = [base];
      if (isActive) classes.push('slds-has-focus');
      if (isSelected) classes.push('slds-is-selected');
      return {
        ...o,
        className: classes.join(' '),
        ariaSelected: isSelected ? 'true' : 'false'
      };
    });
  }

  handleKeydown = (e) => {
    if (!this.expanded && (e.key === 'ArrowDown' || e.key === 'Enter')) {
      this.open();
      e.preventDefault();
      return;
    }
    switch (e.key) {
      case 'ArrowDown':
        if (this.filteredOptions.length) {
          this.focusedIndex = Math.min(
            this.focusedIndex + 1,
            this.filteredOptions.length - 1
          );
          this._refreshOptionStates();
          e.preventDefault();
        }
        break;
      case 'ArrowUp':
        if (this.filteredOptions.length) {
          this.focusedIndex = Math.max(this.focusedIndex - 1, 0);
          this._refreshOptionStates();
          e.preventDefault();
        }
        break;
      case 'Enter':
        if (this.focusedIndex >= 0 && this.filteredOptions[this.focusedIndex]) {
          this._selectOption(this.filteredOptions[this.focusedIndex]);
          e.preventDefault();
        } else if (this.filteredOptions.length === 1) {
          this._selectOption(this.filteredOptions[0]);
          e.preventDefault();
        }
        break;
      case 'Escape':
        this.close();
        e.preventDefault();
        break;
      default:
        break;
    }
  };

  handleClick = (e) => {
  const index = Number(e.currentTarget.parentElement.dataset.index);
  const opt = this.filteredOptions[index];
  if (opt) this._selectOption(opt);
};

  _selectOption(opt) {
    this._value = opt.value;
    this.inputValue = opt.label;
    this._validateRequired();

    this.dispatchEvent(
      new CustomEvent('valuechange', {
        detail: { value: this._value, label: opt.label }
      })
    );

    this.close();
  }

  @api
  reportValidity() {
    return this._validateRequired();
  }

  _validateRequired() {
    if (this.required && !this._value) {
      this.errorMessage = 'Selection is required.';
      return false;
    }
    this.errorMessage = '';
    return true;
  }

  _findLabelByValue(val) {
    const match = (this._options || []).find(o => o.value === val);
    return match ? match.label : '';
  }

  open = () => {
  if (this.disabled) return;
  this.expanded = true;
  this.filterOptions();
  // wait for DOM to paint, then position
  requestAnimationFrame(() => this.positionDropdown());
  this._bindGlobalListeners();
};

close = () => {
  this.expanded = false;
  this.focusedIndex = -1;
  this._refreshOptionStates();
  this._unbindGlobalListeners();
};

positionDropdown() {
  const input = this.template.querySelector('#search-input');
  const dd = this.template.querySelector('.picklist-dropdown');
  if (!input || !dd || !this.expanded) return;

  const r = input.getBoundingClientRect();
  dd.style.left = `${r.left + window.scrollX}px`;
  dd.style.top  = `${r.bottom + window.scrollY + 4}px`; // 4px gap
  dd.style.width = `${r.width}px`;
}

_bindGlobalListeners() {
  if (this._bound) return;
  this._onResize = () => this.positionDropdown();
  this._onScroll = () => this.positionDropdown();
  window.addEventListener('resize', this._onResize);
  window.addEventListener('scroll', this._onScroll, true); // capture scroll in ancestors
  this._bound = true;
}

_unbindGlobalListeners() {
  if (!this._bound) return;
  window.removeEventListener('resize', this._onResize);
  window.removeEventListener('scroll', this._onScroll, true);
  this._bound = false;
}


}