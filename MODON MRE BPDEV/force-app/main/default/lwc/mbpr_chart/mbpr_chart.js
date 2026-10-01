import { LightningElement, api } from 'lwc';

const DONUT_CIRCUMFERENCE = 100;
const DONUT_GAP = 2.4;
const DONUT_START_OFFSET = 25;
const Y_TICK_COUNT = 5;
const STAGGER_MS = 70;
const TIP_WIDTH_GUESS = 190;
const TIP_EDGE = 8;

export default class Mbpr_chart extends LightningElement {
    @api variant = 'donut';
    @api header;
    @api mode = 'count';
    @api currencyPrefix = 'AED';
    @api centerCaption;
    @api emptyMessage;
    /* Renders an enlarge button and dispatches 'expand'. The host owns the
       lightbox; this stays presentational. */
    @api expandable = false;
    /* Ring-only: donut without the legend list, which lives in the enlarge view. */
    @api hideLegend = false;
    /* No card chrome, for panels that already draw their own surface. */
    @api frameless = false;

    _segments = [];
    _columns = [];
    _centerValue = null;
    _entered = false;

    // Interaction state: which slice/row/column the pointer is on, plus the
    // floating tooltip card (position is relative to .chart-card).
    hoverScope = '';
    hoverIndex = -1;
    tipOn = false;
    tipTitle = '';
    tipRows = [];
    tipX = 0;
    tipY = 0;

    @api
    get segments() {
        return this._segments;
    }
    set segments(value) {
        this._segments = Array.isArray(value) ? value : [];
    }

    @api
    get columns() {
        return this._columns;
    }
    set columns(value) {
        this._columns = Array.isArray(value) ? value : [];
    }

    @api
    get centerValue() {
        return this._centerValue;
    }
    set centerValue(value) {
        this._centerValue = value === undefined || value === null || value === '' ? null : Number(value);
    }

    renderedCallback() {
        if (this._entered) {
            return;
        }
        this._entered = true;
        /* Modifiers go through classList, not a computed class binding: the
           static "chart-card" is written once, so re-renders never clobber
           them. Frameless lands pre-paint. */
        const card = this.template.querySelector('.chart-card');
        if (card && this.frameless) {
            card.classList.add('chart-card--frameless');
        }
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                const target = this.template.querySelector('.chart-card');
                if (target) {
                    target.classList.add('chart-card--in');
                }
            });
        });
    }

    @api
    focusExpand() {
        const button = this.template.querySelector('.chart-card__expand');
        if (button && typeof button.focus === 'function') {
            button.focus();
        }
    }

    get showExpand() {
        return Boolean(this.expandable) && this.hasData;
    }

    get expandLabel() {
        return `Enlarge ${this.header || 'chart'}`;
    }

    handleExpandClick() {
        this.dispatchEvent(new CustomEvent('expand'));
    }

    get donutLayoutClass() {
        return this.hideLegend ? 'donut-layout donut-layout--solo' : 'donut-layout';
    }

    get showLegend() {
        return !this.hideLegend;
    }

    get isDonut() {
        return this.variant !== 'bars' && this.variant !== 'columns';
    }

    get isBars() {
        return this.variant === 'bars';
    }

    get isColumns() {
        return this.variant === 'columns';
    }

    get isPriceMode() {
        return this.mode === 'price';
    }

    get cleanSegments() {
        return this._segments
            .filter((seg) => seg && seg.label !== undefined && seg.label !== null)
            .map((seg) => ({ label: String(seg.label), value: Math.max(Number(seg.value) || 0, 0) }));
    }

    get segmentTotal() {
        return this.cleanSegments.reduce((sum, seg) => sum + seg.value, 0);
    }

    get cleanColumns() {
        return this._columns
            .filter((col) => col && col.label !== undefined && col.label !== null)
            .map((col) => ({
                label: String(col.label),
                stacks: Array.isArray(col.stacks)
                    ? col.stacks
                          .filter((st) => st && st.name !== undefined && st.name !== null)
                          .map((st) => ({ name: String(st.name), value: Math.max(Number(st.value) || 0, 0) }))
                    : []
            }));
    }

    get columnsTotal() {
        return this.cleanColumns.reduce(
            (sum, col) => sum + col.stacks.reduce((s, st) => s + st.value, 0),
            0
        );
    }

    get hasData() {
        if (this.isColumns) {
            return this.columnsTotal > 0;
        }
        return this.segmentTotal > 0;
    }

    get emptyMessageResolved() {
        return this.emptyMessage || 'No data to display for this period.';
    }

    formatValue(value) {
        const num = Number(value) || 0;
        if (this.isPriceMode) {
            return `${this.currencyPrefix} ${this.formatShort(num)}`;
        }
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(num);
    }

    formatShort(value) {
        const num = Number(value) || 0;
        if (num >= 1000000000) {
            return `${(num / 1000000000).toFixed(1)}B`;
        }
        if (num >= 1000000) {
            return `${(num / 1000000).toFixed(1)}M`;
        }
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(num);
    }

    paletteVar(index) {
        /* Gray is both the fifth slot and the overflow colour, so rank 5 onward
           all lands on it. Callers cap at 4 + "Other" so a real category
           never sits beside Other in the same gray. */
        if (index >= 4) return 'var(--chart-c5)';
        return `var(--chart-c${index + 1})`;
    }

    /* ------------------------------------------------------------ */
    /* Tooltip + hover interaction                                  */
    /* ------------------------------------------------------------ */

    get hasHover() {
        return this.hoverIndex > -1;
    }

    setTipPosition(event) {
        const card = this.template.querySelector('.chart-card');
        if (!card) return;
        const rect = card.getBoundingClientRect();
        let x = event.clientX - rect.left + 14;
        let y = event.clientY - rect.top - 12;
        x = Math.min(Math.max(x, TIP_EDGE), Math.max(rect.width - TIP_WIDTH_GUESS, TIP_EDGE));
        y = Math.min(Math.max(y, TIP_EDGE), Math.max(rect.height - 48, TIP_EDGE));
        this.tipX = Math.round(x);
        this.tipY = Math.round(y);
    }

    get tooltipClass() {
        return this.tipOn ? 'tip tip--on' : 'tip';
    }

    get tooltipStyle() {
        return `left: ${this.tipX}px; top: ${this.tipY}px;`;
    }

    handleSegmentEnter(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index)) return;
        const seg = this.cleanSegments[index];
        if (!seg) return;
        const total = this.segmentTotal;
        const pct = total > 0 ? `${Math.round((seg.value / total) * 100)}%` : '';
        this.hoverScope = 'donut';
        this.hoverIndex = index;
        this.tipTitle = '';
        this.tipRows = [
            {
                key: seg.label,
                label: seg.label,
                value: this.formatValue(seg.value),
                pct,
                swatchStyle: `background: ${this.paletteVar(index)};`
            }
        ];
        this.tipOn = true;
        this.setTipPosition(event);
    }

    handleBarEnter(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index)) return;
        const seg = this.cleanSegments[index];
        if (!seg) return;
        const total = this.segmentTotal;
        const pct = total > 0 ? `${Math.round((seg.value / total) * 100)}%` : '';
        this.hoverScope = 'bars';
        this.hoverIndex = index;
        this.tipTitle = '';
        this.tipRows = [
            {
                key: seg.label,
                label: seg.label,
                value: this.formatValue(seg.value),
                pct,
                swatchStyle: `background: ${this.paletteVar(index)};`
            }
        ];
        this.tipOn = true;
        this.setTipPosition(event);
    }

    handleColumnEnter(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index)) return;
        const col = this.cleanColumns[index];
        if (!col) return;
        const names = this.columnSeriesNames;
        const rows = col.stacks
            .filter((st) => st.value > 0)
            .map((st) => ({
                key: st.name,
                label: st.name,
                value: this.formatValue(st.value),
                pct: '',
                swatchStyle: `background: ${this.paletteVar(names.indexOf(st.name))};`
            }));
        const total = col.stacks.reduce((sum, st) => sum + st.value, 0);
        if (rows.length > 1) {
            rows.push({
                key: '__total__',
                label: 'Total',
                value: this.formatValue(total),
                pct: '',
                swatchStyle: 'background: transparent;'
            });
        }
        this.hoverScope = 'columns';
        this.hoverIndex = index;
        this.tipTitle = col.label;
        this.tipRows = rows;
        this.tipOn = true;
        this.setTipPosition(event);
    }

    handleTipMove(event) {
        if (!this.tipOn) return;
        this.setTipPosition(event);
    }

    handleHoverLeave() {
        this.hoverScope = '';
        this.hoverIndex = -1;
        this.tipOn = false;
    }

    /* ------------------------------------------------------------ */
    /* Donut                                                        */
    /* ------------------------------------------------------------ */

    get centerDisplay() {
        if (this.hoverScope === 'donut' && this.hasHover) {
            const seg = this.cleanSegments[this.hoverIndex];
            if (seg) {
                return this.isPriceMode ? this.formatShort(seg.value) : this.formatValue(seg.value);
            }
        }
        const value = this._centerValue === null ? this.segmentTotal : this._centerValue;
        return this.isPriceMode ? this.formatShort(value) : this.formatValue(value);
    }

    get centerPrefix() {
        return this.isPriceMode ? this.currencyPrefix : '';
    }

    // The value must stay inside the donut hole: longer strings step down in
    // size (the hole is ~58% of the ring's box).
    get centerValueClass() {
        const length = String(this.centerDisplay || '').length;
        if (length > 9) return 'donut__value donut__value--xs';
        if (length > 6) return 'donut__value donut__value--sm';
        return 'donut__value';
    }

    get centerCaptionResolved() {
        if (this.hoverScope === 'donut' && this.hasHover) {
            const seg = this.cleanSegments[this.hoverIndex];
            if (seg) return seg.label;
        }
        return this.centerCaption;
    }

    get donutSegments() {
        const segments = this.cleanSegments;
        const total = this.segmentTotal;
        if (!total) {
            return [];
        }
        const visible = segments
            .map((seg, originalIndex) => ({ ...seg, originalIndex }))
            .filter((seg) => seg.value > 0);
        const gapped = visible.length > 1;
        const gap = gapped ? DONUT_GAP : 0;
        const usable = DONUT_CIRCUMFERENCE - gap * visible.length;
        let consumed = 0;
        const anyHover = this.hoverScope === 'donut' && this.hasHover;
        return visible.map((seg, index) => {
            const colorIndex = seg.originalIndex;
            const length = Math.max((seg.value / total) * usable, 0.4);
            const offset = DONUT_START_OFFSET - consumed;
            consumed += length + gap;
            const percent = Math.round((seg.value / total) * 100);
            const classes = ['donut__seg'];
            if (gapped) classes.push('donut__seg--round');
            if (anyHover) {
                classes.push(colorIndex === this.hoverIndex ? 'donut__seg--hot' : 'donut__seg--dim');
            }
            return {
                key: `${seg.label}-${index}`,
                index: colorIndex,
                className: classes.join(' '),
                ariaLabel: `${seg.label}: ${this.formatValue(seg.value)} (${percent}%)`,
                style: [
                    `stroke-dasharray: ${length} ${DONUT_CIRCUMFERENCE - length};`,
                    `stroke-dashoffset: ${offset};`,
                    `--seg-color: ${this.paletteVar(colorIndex)};`,
                    `--seg-delay: ${index * STAGGER_MS}ms;`
                ].join(' ')
            };
        });
    }

    get legendRows() {
        const total = this.segmentTotal;
        const anyHover = this.hoverScope === 'donut' && this.hasHover;
        return this.cleanSegments.map((seg, index) => {
            const percent = total > 0 ? Math.round((seg.value / total) * 100) : 0;
            const classes = ['legend__row'];
            if (anyHover) {
                classes.push(index === this.hoverIndex ? 'legend__row--hot' : 'legend__row--dim');
            }
            return {
                key: `${seg.label}-${index}`,
                index,
                className: classes.join(' '),
                label: seg.label,
                display: this.formatValue(seg.value),
                percent: `${percent}%`,
                swatchStyle: `background: ${this.paletteVar(index)};`
            };
        });
    }

    /* ------------------------------------------------------------ */
    /* Bars                                                         */
    /* ------------------------------------------------------------ */

    get barRows() {
        const segments = this.cleanSegments;
        const max = segments.reduce((m, seg) => Math.max(m, seg.value), 0);
        const anyHover = this.hoverScope === 'bars' && this.hasHover;
        return segments.map((seg, index) => {
            const widthPercent = max > 0 ? Math.max((seg.value / max) * 100, 1.5) : 0;
            const classes = ['bars__row'];
            if (anyHover) {
                classes.push(index === this.hoverIndex ? 'bars__row--hot' : 'bars__row--dim');
            }
            return {
                key: `${seg.label}-${index}`,
                index,
                className: classes.join(' '),
                label: seg.label,
                display: this.formatValue(seg.value),
                fillStyle: [
                    `width: ${widthPercent}%;`,
                    `--bar-color: ${this.paletteVar(index)};`,
                    `--row-delay: ${index * STAGGER_MS}ms;`
                ].join(' ')
            };
        });
    }

    /* ------------------------------------------------------------ */
    /* Columns                                                      */
    /* ------------------------------------------------------------ */

    get columnSeriesNames() {
        const names = [];
        this.cleanColumns.forEach((col) => {
            col.stacks.forEach((st) => {
                if (!names.includes(st.name)) {
                    names.push(st.name);
                }
            });
        });
        return names;
    }

    get columnMax() {
        return this.cleanColumns.reduce((max, col) => {
            const total = col.stacks.reduce((sum, st) => sum + st.value, 0);
            return Math.max(max, total);
        }, 0);
    }

    get columnCells() {
        const max = this.columnMax;
        const names = this.columnSeriesNames;
        const anyHover = this.hoverScope === 'columns' && this.hasHover;
        return this.cleanColumns.map((col, colIndex) => {
            const classes = ['columns__cell'];
            if (anyHover) {
                classes.push(colIndex === this.hoverIndex ? 'columns__cell--hot' : 'columns__cell--dim');
            }
            return {
                key: `${col.label}-${colIndex}`,
                index: colIndex,
                className: classes.join(' '),
                label: col.label,
                barStyle: `--col-delay: ${colIndex * 45}ms;`,
                stacks: col.stacks
                    .filter((st) => st.value > 0)
                    .map((st, stackIndex) => {
                        const heightPercent = max > 0 ? (st.value / max) * 100 : 0;
                        return {
                            key: `${st.name}-${stackIndex}`,
                            style: `height: ${heightPercent}%; background: ${this.paletteVar(names.indexOf(st.name))};`
                        };
                    })
            };
        });
    }

    get columnsLegend() {
        return this.columnSeriesNames.map((name, index) => ({
            key: name,
            label: name,
            swatchStyle: `background: ${this.paletteVar(index)};`
        }));
    }

    get yTicks() {
        const max = this.columnMax;
        const ticks = [];
        for (let i = Y_TICK_COUNT; i >= 0; i--) {
            const value = max * (i / Y_TICK_COUNT);
            ticks.push({ key: `tick-${i}`, label: this.isPriceMode ? this.formatShort(value) : this.formatValue(value) });
        }
        return ticks;
    }

    get ariaSummary() {
        if (this.isColumns) {
            const parts = this.cleanColumns
                .map((col) => {
                    const total = col.stacks.reduce((sum, st) => sum + st.value, 0);
                    return total > 0 ? `${col.label} ${this.formatValue(total)}` : null;
                })
                .filter(Boolean);
            return `${this.header || 'Chart'}. ${parts.join(', ')}`;
        }
        const parts = this.cleanSegments.map((seg) => `${seg.label} ${this.formatValue(seg.value)}`);
        return `${this.header || 'Chart'}. ${parts.join(', ')}`;
    }
}