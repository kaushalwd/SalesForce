import { LightningElement, api } from 'lwc';

import getEventsDynamic from '@salesforce/apex/MBP_ManageEventsandActivities.getEventsDynamic';

const PAGE_SIZE = 10;
const COMPACT_UPCOMING_LIMIT = 3;
const MONTH_LABELS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
];
const WEEKDAY_LABELS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const DAY_MS = 86400000;
/** Bars stack in lanes under the day numbers. Anything past this many lanes
 *  in a week collapses into a "+N more" link on each affected day. */
const MAX_LANES = 4;
/** One colour per Type__c family, keyed by the picklist label. A type that is
 *  not listed (or blank) falls back to a neutral grey so it still reads. */
const TYPE_COLORS = {
    'Open House': '#2fbfb3',
    'Launch': '#e0a83f',
    'Road Show': '#e0a83f',
    'Exhibition': '#e0a83f',
    'Broker Training': '#9a8cf0',
    'Training Academy': '#9a8cf0',
    'Webinar': '#7fcf78',
    'Annual Awards': '#ef8a72',
    'Kiosks': '#63aef3',
    'Presentation': '#63aef3',
    'Seminars': '#63aef3',
    'Broker Meeting': '#d98ad1',
    'Broker Briefing': '#d98ad1'
};
const FALLBACK_COLOR = '#8a8f96';

/** Local midnight for a timestamp, as epoch millis. */
function startOfDay(ms) {
    const date = new Date(ms);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
}

/** Inline custom properties for a bar: the solid colour for the edge and
 *  swatch, plus two tints for the fill. Pre-computed here so the stylesheet
 *  stays plain rgba and no colour maths runs in CSS. */
function barStyle(hex) {
    const value = parseInt(hex.replace('#', ''), 16);
    const r = (value >> 16) & 255;
    const g = (value >> 8) & 255;
    const b = value & 255;
    return `--bar-color: ${hex}; --bar-tint: rgba(${r}, ${g}, ${b}, 0.2); --bar-tint-strong: rgba(${r}, ${g}, ${b}, 0.36);`;
}

export default class MbprEngagementEvents extends LightningElement {
    /** 'full' renders the filter, calendar and three lists; 'compact' renders
     *  the next few upcoming events only. */
    @api variant = 'full';

    isInitializing = true;
    loadError = '';

    events = [];
    typeFilter = '';
    dayFilter = null;
    calendarMonth = new Date().getMonth();
    calendarSlideDir = '';
    calendarSlideTick = false;

    pages = { today: 1, upcoming: 1, previous: 1 };

    selectedEventId = null;
    /** ISO date of the day whose "+N more" list is open, or null. */
    dayListIso = null;

    _loadSequence = 0;
    _detailOpener = null;
    _dayListOpener = null;
    _overlayFocusPending = false;

    connectedCallback() {
        this.initializeWorkspace();
    }

    /** When an overlay has just opened, move focus to its close button so
     *  Escape and the keyboard work from inside it. */
    renderedCallback() {
        if (!this._overlayFocusPending) return;
        this._overlayFocusPending = false;
        const closeButton = this.template.querySelector('.detail__close');
        if (closeButton) closeButton.focus();
    }

    get isFullVariant() {
        return this.variant !== 'compact';
    }

    get isCompactVariant() {
        return this.variant === 'compact';
    }

    async initializeWorkspace() {
        const sequence = ++this._loadSequence;
        this.isInitializing = true;
        this.loadError = '';
        try {
            // Only the Future and Past modes work server-side; together they
            // cover the complete current-year dataset. Today/Range always
            // return empty from the existing service, so the buckets below are
            // derived client-side to match the intended mode semantics.
            const [futureResult, pastResult] = await Promise.all([
                getEventsDynamic({ mode: 'Future' }),
                getEventsDynamic({ mode: 'Past' })
            ]);
            if (sequence !== this._loadSequence) return;

            const merged = new Map();
            [...(futureResult || []), ...(pastResult || [])].forEach((event) => {
                if (event && event.Id && !merged.has(event.Id)) {
                    merged.set(event.Id, this.toEventRow(event));
                }
            });
            this.events = Array.from(merged.values());
        } catch (error) {
            this.loadError = this.reduceError(error) || 'Unable to load events right now. Please try again.';
        } finally {
            if (sequence === this._loadSequence) {
                this.isInitializing = false;
            }
        }
    }

    handleRetryLoad() {
        this.initializeWorkspace();
    }

    toEventRow(event) {
        const startMs = event.Start_Date_and_Time__c
            ? new Date(event.Start_Date_and_Time__c).getTime()
            : event.CreatedDate
              ? new Date(event.CreatedDate).getTime()
              : null;
        const endMs = event.End_Date_and_Time__c ? new Date(event.End_Date_and_Time__c).getTime() : startMs;
        const color = TYPE_COLORS[event.Type__c] || FALLBACK_COLOR;
        const isSingleDay =
            startMs != null && new Date(startMs).toDateString() === new Date(endMs == null ? startMs : endMs).toDateString();
        return {
            id: event.Id,
            name: event.Name || '',
            type: event.Type__c || '',
            status: event.Status__c || '',
            location: event.Location__c || '',
            description: event.Description__c || '',
            externalLink: event.External_Link__c || '',
            socialMediaLink: event.Social_Media_Link__c || '',
            virtualTourLink: event.Virtual_Tour_Link__c || '',
            startMs,
            endMs,
            isSingleDay,
            timeLabel: startMs != null ? this.formatTime(new Date(startMs)) : '',
            color,
            barStyle: barStyle(color),
            formattedDateTime: this.formatDateTimeRange(event.Start_Date_and_Time__c, event.End_Date_and_Time__c)
        };
    }

    formatTime(date) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    /** Locale date plus 2-digit time. When the end falls on the same day only
     *  the end time is appended. */
    formatDateTimeRange(startValue, endValue) {
        if (!startValue) return '';
        const start = new Date(startValue);
        const timeOptions = { hour: '2-digit', minute: '2-digit' };
        // Explicit locale + options. Previously the date was formatted with no
        // locale argument, so it followed the viewer's browser and a US-locale
        // broker saw "8/25/2026" instead of the portal standard.
        const DATE_OPTS = { day: '2-digit', month: 'short', year: 'numeric' };
        let formatted = `${start.toLocaleDateString('en-AE', DATE_OPTS)} ${start.toLocaleTimeString([], timeOptions)}`;
        if (endValue) {
            const end = new Date(endValue);
            if (start.toDateString() === end.toDateString()) {
                formatted += ` - ${end.toLocaleTimeString([], timeOptions)}`;
            } else {
                formatted += ` - ${end.toLocaleDateString('en-AE', DATE_OPTS)} ${end.toLocaleTimeString([], timeOptions)}`;
            }
        }
        return formatted;
    }

    // ------------------------------------------------------------------
    // Filtering + derivation
    // ------------------------------------------------------------------

    get typeOptions() {
        const unique = new Set();
        this.events.forEach((event) => {
            if (event.type) unique.add(event.type);
        });
        return [
            { label: 'All Types', value: '' },
            ...Array.from(unique)
                .sort((a, b) => a.localeCompare(b))
                .map((value) => ({ label: value, value }))
        ];
    }

    handleTypeChange(event) {
        this.typeFilter = event.detail.value;
        this.pages = { today: 1, upcoming: 1, previous: 1 };
    }

    get filteredEvents() {
        let rows = this.events;
        if (this.typeFilter) {
            rows = rows.filter((event) => event.type === this.typeFilter);
        }
        if (this.dayFilter) {
            const dayStart = new Date(this.dayFilter);
            dayStart.setHours(0, 0, 0, 0);
            const dayEnd = new Date(this.dayFilter);
            dayEnd.setHours(23, 59, 59, 999);
            rows = rows.filter(
                (event) =>
                    event.startMs != null &&
                    event.startMs <= dayEnd.getTime() &&
                    (event.endMs == null || event.endMs >= dayStart.getTime())
            );
        }
        return rows;
    }

    /** The buckets overlap: an in-progress event is today's, upcoming and
     *  previous at once. They are windows, not partitions. */
    deriveBuckets() {
        const now = Date.now();
        const startOfToday = new Date();
        startOfToday.setHours(0, 0, 0, 0);
        const endOfToday = new Date();
        endOfToday.setHours(23, 59, 59, 999);

        const today = [];
        const upcoming = [];
        const previous = [];
        this.filteredEvents.forEach((event) => {
            if (event.startMs == null) return;
            const endMs = event.endMs == null ? event.startMs : event.endMs;
            if (event.startMs <= endOfToday.getTime() && endMs >= startOfToday.getTime()) {
                today.push(event);
            }
            if (endMs > now) {
                upcoming.push(event);
            }
            if (event.startMs < now) {
                previous.push(event);
            }
        });
        today.sort((a, b) => a.startMs - b.startMs);
        upcoming.sort((a, b) => a.startMs - b.startMs);
        previous.sort((a, b) => b.startMs - a.startMs);
        return { today, upcoming, previous };
    }

    get buckets() {
        return this.deriveBuckets();
    }

    get hasAnyEvents() {
        return this.events.length > 0;
    }

    // ---- Per-bucket presentation ----

    buildBucketView(rows, bucketKey) {
        const page = this.pages[bucketKey] || 1;
        const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
        const safePage = Math.min(page, totalPages);
        const start = (safePage - 1) * PAGE_SIZE;
        return {
            rows: rows.slice(start, start + PAGE_SIZE),
            hasRows: rows.length > 0,
            showPagination: rows.length > PAGE_SIZE,
            pageLabel: `Page ${safePage} of ${totalPages}`,
            isPrevDisabled: safePage <= 1,
            isNextDisabled: safePage >= totalPages
        };
    }

    get todayView() {
        return this.buildBucketView(this.buckets.today, 'today');
    }

    get upcomingView() {
        return this.buildBucketView(this.buckets.upcoming, 'upcoming');
    }

    get previousView() {
        return this.buildBucketView(this.buckets.previous, 'previous');
    }

    handleBucketPrev(event) {
        const bucket = event.currentTarget.dataset.bucket;
        if (!bucket) return;
        const current = this.pages[bucket] || 1;
        if (current > 1) {
            this.pages = { ...this.pages, [bucket]: current - 1 };
        }
    }

    handleBucketNext(event) {
        const bucket = event.currentTarget.dataset.bucket;
        if (!bucket) return;
        const rows = this.buckets[bucket] || [];
        const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
        const current = this.pages[bucket] || 1;
        if (current < totalPages) {
            this.pages = { ...this.pages, [bucket]: current + 1 };
        }
    }

    get compactUpcomingCards() {
        return this.buckets.upcoming.slice(0, COMPACT_UPCOMING_LIMIT);
    }

    get hasCompactUpcoming() {
        return this.compactUpcomingCards.length > 0;
    }

    // ------------------------------------------------------------------
    // Calendar (current-year only, matching the service's hard clamp;
    // desktop/tablet only via CSS). Each event is cut into one segment per
    // week row and drawn as a titled bar; overlapping bars stack in lanes.
    // ------------------------------------------------------------------

    get calendarModel() {
        const today = new Date();
        const year = today.getFullYear();
        const month = this.calendarMonth;
        const todayKey = today.toDateString();
        const selectedKey = this.dayFilter ? new Date(this.dayFilter).toDateString() : null;

        const firstOfMonth = new Date(year, month, 1);
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        // Monday-first offset; leading cells belong to the previous month.
        const leadingDays = (firstOfMonth.getDay() + 6) % 7;
        const weekCount = Math.ceil((leadingDays + daysInMonth) / 7);
        const gridStart = new Date(year, month, 1 - leadingDays);

        // Earliest start first, then longest first. A multi-week bar is
        // therefore placed before anything that starts inside its span, so
        // it keeps the same lane from one week row to the next.
        const placed = this.filteredForCalendar
            .filter((event) => event.startMs != null)
            .map((event) => ({
                event,
                startDay: startOfDay(event.startMs),
                endDay: startOfDay(event.endMs == null ? event.startMs : event.endMs)
            }))
            .sort(
                (a, b) =>
                    a.startDay - b.startDay ||
                    (b.endDay - b.startDay) - (a.endDay - a.startDay) ||
                    a.event.startMs - b.event.startMs
            );

        const weeks = [];
        for (let w = 0; w < weekCount; w += 1) {
            const weekStartDate = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + w * 7);
            const weekStart = weekStartDate.getTime();
            const weekEnd = new Date(
                weekStartDate.getFullYear(),
                weekStartDate.getMonth(),
                weekStartDate.getDate() + 6,
                23, 59, 59, 999
            ).getTime();

            const lanes = [];
            const bars = [];
            const overflow = [0, 0, 0, 0, 0, 0, 0];
            const dayCounts = [0, 0, 0, 0, 0, 0, 0];

            placed.forEach(({ event, startDay, endDay }) => {
                if (endDay < weekStart || startDay > weekEnd) return;
                const continuesFrom = startDay < weekStart;
                const continuesTo = endDay > weekEnd;
                const startIndex = continuesFrom ? 0 : Math.min(6, Math.max(0, Math.round((startDay - weekStart) / DAY_MS)));
                const endIndex = continuesTo ? 6 : Math.min(6, Math.max(startIndex, Math.round((endDay - weekStart) / DAY_MS)));
                for (let i = startIndex; i <= endIndex; i += 1) dayCounts[i] += 1;

                // First lane with no overlap, else a new one.
                let lane = lanes.findIndex((taken) => taken.every((slot) => startIndex > slot.end || endIndex < slot.start));
                if (lane === -1) {
                    lane = lanes.length;
                    lanes.push([]);
                }
                lanes[lane].push({ start: startIndex, end: endIndex });

                if (lane >= MAX_LANES) {
                    for (let i = startIndex; i <= endIndex; i += 1) overflow[i] += 1;
                    return;
                }

                const classes = ['calendar__bar'];
                if (continuesFrom) classes.push('calendar__bar--from');
                if (continuesTo) classes.push('calendar__bar--to');
                if (event.id === this.selectedEventId) classes.push('calendar__bar--selected');
                bars.push({
                    key: `bar-${event.id}-${w}`,
                    id: event.id,
                    label: event.name,
                    timeLabel: event.isSingleDay ? event.timeLabel : '',
                    tooltip: `${event.name} · ${event.formattedDateTime}`,
                    ariaLabel: `${event.name}, ${event.formattedDateTime}`,
                    className: classes.join(' '),
                    style: `grid-row: ${lane + 1}; grid-column: ${startIndex + 1} / span ${endIndex - startIndex + 1}; ${event.barStyle}`
                });
            });

            const days = [];
            for (let i = 0; i < 7; i += 1) {
                const date = new Date(weekStartDate.getFullYear(), weekStartDate.getMonth(), weekStartDate.getDate() + i);
                const dateKey = date.toDateString();
                const isOutside = date.getMonth() !== month;
                const isToday = dateKey === todayKey;
                const isSelected = selectedKey != null && dateKey === selectedKey;
                const count = dayCounts[i];

                let cellClass = 'calendar__cell';
                if (isOutside) cellClass += ' calendar__cell--outside';
                if (i >= 5) cellClass += ' calendar__cell--weekend';

                let className = 'calendar__day';
                if (isToday) className += ' calendar__day--today';
                if (isSelected) className += ' calendar__day--selected';
                if (count > 0) className += ' calendar__day--has-events';

                days.push({
                    key: `day-${date.getTime()}`,
                    day: date.getDate(),
                    iso: date.toISOString(),
                    isOutside,
                    cellClass,
                    className,
                    ariaLabel: count > 0 ? `${dateKey}, ${count} ${count === 1 ? 'event' : 'events'}` : dateKey,
                    ariaPressed: isSelected ? 'true' : 'false'
                });
            }

            const more = [];
            overflow.forEach((count, i) => {
                if (!count) return;
                const date = new Date(weekStartDate.getFullYear(), weekStartDate.getMonth(), weekStartDate.getDate() + i);
                more.push({
                    key: `more-${w}-${i}`,
                    iso: date.toISOString(),
                    label: `+${count} more`,
                    ariaLabel: `${count} more ${count === 1 ? 'event' : 'events'} on ${date.toDateString()}`,
                    style: `grid-row: ${MAX_LANES + 1}; grid-column: ${i + 1} / span 1;`
                });
            });

            weeks.push({ key: `week-${w}`, days, bars, more });
        }

        return {
            title: `${MONTH_LABELS[month]} ${year}`,
            weekdays: WEEKDAY_LABELS,
            weeks,
            isPrevDisabled: month <= 0,
            isNextDisabled: month >= 11
        };
    }

    /** Bars reflect the type filter but not the day filter itself. */
    get filteredForCalendar() {
        return this.typeFilter ? this.events.filter((event) => event.type === this.typeFilter) : this.events;
    }

    /** One swatch per type that has an event touching the visible month. */
    get calendarLegend() {
        const year = new Date().getFullYear();
        const monthStart = new Date(year, this.calendarMonth, 1).getTime();
        const monthEnd = new Date(year, this.calendarMonth + 1, 0, 23, 59, 59, 999).getTime();
        const seen = new Map();
        this.filteredForCalendar.forEach((event) => {
            if (event.startMs == null) return;
            const endMs = event.endMs == null ? event.startMs : event.endMs;
            if (event.startMs > monthEnd || endMs < monthStart) return;
            const label = event.type || 'Other';
            if (!seen.has(label)) {
                seen.set(label, { key: label, label, style: `--bar-color: ${event.color};` });
            }
        });
        return Array.from(seen.values()).sort((a, b) => a.label.localeCompare(b.label));
    }

    get hasCalendarLegend() {
        return this.calendarLegend.length > 0;
    }

    handleCalendarPrev() {
        if (this.calendarMonth > 0) {
            this.calendarMonth -= 1;
            this.calendarSlideDir = 'prev';
            this.calendarSlideTick = !this.calendarSlideTick;
        }
    }

    handleCalendarNext() {
        if (this.calendarMonth < 11) {
            this.calendarMonth += 1;
            this.calendarSlideDir = 'next';
            this.calendarSlideTick = !this.calendarSlideTick;
        }
    }

    handleCalendarToday() {
        const currentMonth = new Date().getMonth();
        if (this.calendarMonth === currentMonth) return;
        this.calendarSlideDir = this.calendarMonth < currentMonth ? 'next' : 'prev';
        this.calendarSlideTick = !this.calendarSlideTick;
        this.calendarMonth = currentMonth;
    }

    /** Two identical keyframes alternate so the slide retriggers on every
        navigation, including same-direction. */
    get calendarGridClass() {
        if (!this.calendarSlideDir) return 'calendar__grid';
        const variant = this.calendarSlideTick ? 'a' : 'b';
        return `calendar__grid calendar__grid--${this.calendarSlideDir}-${variant}`;
    }

    handleCalendarDayClick(event) {
        const iso = event.currentTarget.dataset.iso;
        if (!iso) return;
        if (this.dayFilter && new Date(this.dayFilter).toDateString() === new Date(iso).toDateString()) {
            this.dayFilter = null;
        } else {
            this.dayFilter = iso;
        }
        this.pages = { today: 1, upcoming: 1, previous: 1 };
    }

    // ---- "+N more" day list ----

    handleCalendarMoreClick(event) {
        const iso = event.currentTarget.dataset.iso;
        if (!iso) return;
        this._dayListOpener = event.currentTarget;
        this.dayListIso = iso;
        this._overlayFocusPending = true;
    }

    handleCloseDayList() {
        this.dayListIso = null;
        if (this._dayListOpener && this._dayListOpener.isConnected) {
            this._dayListOpener.focus();
        }
        this._dayListOpener = null;
    }

    handleDayListKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.handleCloseDayList();
        }
    }

    /** A row in the day list opens the event detail in its place. Focus goes
     *  back to the "+N more" link once the detail closes. */
    handleOpenDetailFromDayList(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this._detailOpener = this._dayListOpener;
        this._dayListOpener = null;
        this.dayListIso = null;
        this.selectedEventId = id;
        this._overlayFocusPending = true;
    }

    get dayListView() {
        if (!this.dayListIso) return null;
        const day = new Date(this.dayListIso);
        const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
        const dayEnd = dayStart + DAY_MS - 1;
        const rows = this.filteredForCalendar
            .filter((event) => {
                if (event.startMs == null) return false;
                const endMs = event.endMs == null ? event.startMs : event.endMs;
                return event.startMs <= dayEnd && endMs >= dayStart;
            })
            .sort((a, b) => a.startMs - b.startMs)
            .map((event) => ({
                id: event.id,
                name: event.name,
                type: event.type,
                timeLabel: startOfDay(event.startMs) === dayStart ? event.timeLabel : 'All day',
                style: event.barStyle
            }));
        return {
            title: day.toLocaleDateString('en-AE', { weekday: 'long', day: 'numeric', month: 'long' }),
            rows,
            countLabel: `${rows.length} ${rows.length === 1 ? 'event' : 'events'}`
        };
    }

    get showDayList() {
        return this.dayListIso != null && !this.selectedEvent;
    }

    // ------------------------------------------------------------------
    // Detail overlay
    // ------------------------------------------------------------------

    handleOpenDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this._detailOpener = event.currentTarget;
        this.selectedEventId = id;
        this._overlayFocusPending = true;
    }

    handleCloseDetail() {
        this.selectedEventId = null;
        if (this._detailOpener && this._detailOpener.isConnected) {
            this._detailOpener.focus();
        }
        this._detailOpener = null;
    }

    handleDetailKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.handleCloseDetail();
        }
    }

    stopEventPropagation(event) {
        event.stopPropagation();
    }

    get selectedEvent() {
        return this.events.find((event) => event.id === this.selectedEventId) || null;
    }

    get selectedEventHasLinks() {
        const selected = this.selectedEvent;
        return Boolean(selected && (selected.externalLink || selected.socialMediaLink || selected.virtualTourLink));
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

    reduceError(error) {
        if (!error) return '';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (typeof error.body.message === 'string') return error.body.message;
            if (Array.isArray(error.body) && error.body.length && error.body[0].message) {
                return error.body[0].message;
            }
        }
        return error.message || '';
    }
}