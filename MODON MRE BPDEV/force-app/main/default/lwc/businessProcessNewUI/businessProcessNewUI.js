import { LightningElement, track, api, wire } from 'lwc';
import getBusinessProcessSteps from '@salesforce/apex/BusinessProcessController.getBusinessProcessSteps';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import assignStepToCurrentUser from '@salesforce/apex/BusinessProcessController.assignStepToCurrentUser';
import getTimelineMetadata from '@salesforce/apex/StepTimeCalculatorRealTime.getTimelineMetadata';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { getRecord } from 'lightning/uiRecordApi';
import isUserInQueue from '@salesforce/apex/LwcApproveRejectBpstepController.isUserInQueue';
const FIELDS = ['Business_Process__c.BP_Department_Name__c'];
import PROCESS_FLOW_NAME from '@salesforce/schema/Business_Process__c.Process_Flow__r.Name';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import getUserRoleName from '@salesforce/apex/BPFileUploaderController.getUserRoleName';
import BP_WINDOW_SIZE from '@salesforce/label/c.BP_Steps_Window_Size';
const WINDOW_SIZE = parseInt(BP_WINDOW_SIZE, 10) || 10;

const ACTIVE_STATUSES = new Set(['Open', 'Re Open', 'Accepted', 'Provided Info','Assigned','Re Assigned']);
//const WINDOW_SIZE     = 10;   // ① default visible steps

// 3-state section colours
const COL_ACTIVE    = { border:'#0070d2', bg:'#e8f3ff', head:'#0070d2', num:'#0070d2', conn:'#4fa8e8' };
const COL_COMPLETED = { border:'#27ae60', bg:'#edfaf3', head:'#27ae60', num:'#27ae60', conn:'#5dd98a' };
const COL_INACTIVE  = { border:'#b0bec5', bg:'#f5f7f8', head:'#90a4ae', num:'#9eb0c0', conn:'#c5d8ea' };

function sectionState(subItems) {
    const hasActive    = subItems.some(s => ['Open','Re Open','Accepted','Provided Info',,'Assigned','Re Assigned'].includes(s.Status));
    const allCompleted = subItems.length > 0 && subItems.every(s => s.Status === 'Completed');
    if (hasActive)    return COL_ACTIVE;
    if (allCompleted) return COL_COMPLETED;
    return COL_INACTIVE;
}

export default class VerticalGridComponent extends LightningElement {

    @api  recordId;
    @track records      = [];
    @track flatSteps    = [];
    @track selectedStep = {};
    @track windowStart  = 0;

    // ⑦ Collapse/expand state — shown by default
    @track isExpanded   = true;

    acceptedByUser       = false;
    enableMarketingModal = false;
    businessProcessName;
    openReAssign         = false;
    isModalOpen          = false;

    @track hideMeta     = false;
    @track userRoleName;
    userId = USER_ID;

    _rawRecords          = [];
    _allSteps            = [];
    _wrapBound           = false;
    _dragState           = { isDragging: false, startX: 0, scrollLeft: 0 };


    // ── Computed getters ───────────────────────────────────────────────────────

    // ⑦ Toggle bar
    get toggleIcon()  { return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright'; }
    get toggleHint()  { return this.isExpanded ? 'Click to collapse' : 'Click to expand'; }

    // Always show both arrows when there are steps
    get showLeftArrow()  { return this._allSteps.length > 0; }
    get showRightArrow() { return this._allSteps.length > 0; }

    // Arrow symbols — static direction
    get leftArrowSymbol()  { return '\u2039'; }
    get rightArrowSymbol() { return '\u203A'; }
    get leftBtnClass()     { return 'bp-nav-btn bp-nav-btn--left'; }
    get rightBtnClass()    { return 'bp-nav-btn bp-nav-btn--right'; }

    // ── Lifecycle ──────────────────────────────────────────────────────────────
    connectedCallback() { this.loadSteps(); }

    renderedCallback() {
        // Inject meta HTML
        this.records.forEach(record => {
            (record.visibleSteps || []).forEach(step => {
                const el = this.template.querySelector(`.meta-html[data-id="${step.Id}"]`);
                if (el && step.metaDisplay) el.innerHTML = step.metaDisplay;
            });
        });

        // Scroll wrapper so first active step is visible (centred in view)
        const wrapper = this.template.querySelector('.bp-track-wrapper');
        if (wrapper && !wrapper._scrolledToActive && this._allSteps.length > 0) {
            wrapper._scrolledToActive = true;
            const firstActiveIdx = this._allSteps.findIndex(
                s => ['Open','Re Open','Accepted','Provided Info','Assigned','Re Assigned'].includes(s.Status)
            );
            if (firstActiveIdx > 0) {
                // Each step is 124px wide. Scroll so active step is near left edge with some context.
                const STEP_PX = 124;
                const scrollTo = Math.max(0, (firstActiveIdx - 1) * STEP_PX);
                requestAnimationFrame(() => {
                    wrapper.scrollLeft = scrollTo;
                });
            }
        }
    }

    // ── Wires ──────────────────────────────────────────────────────────────────
    @wire(getRecord, { recordId: '$recordId', fields: [PROCESS_FLOW_NAME, NAME_FIELD] })
    wiredBP({ data, error }) {
        if (data) {
            const pfn = data.fields?.Process_Flow__r?.value?.fields?.Name?.value;
            this.hideMeta = pfn === 'Clash Approval';
        } else if (error) { console.error(error); }
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.enableMarketingModal = data.fields.BP_Department_Name__c.value === 'Marketing';
        } else if (error) { console.error(error); }
    }

    // ── Data loading ───────────────────────────────────────────────────────────
    async loadSteps() {
        try { this.userRoleName = await getUserRoleName({ userId: this.userId }); }
        catch (e) { console.error(e); }

        getBusinessProcessSteps({ recordId: this.recordId })
            .then(result => {
                if (!result || result.length === 0) {
                    this.records = []; this.flatSteps = []; this._allSteps = []; return;
                }
                this._rawRecords = result;
                this._buildFromRaw(result);
            })
            .catch(err => console.error('loadSteps error', err));
    }

    _isHidden(sub) {
        const isSM       = sub.Name?.toLowerCase().includes('sm');
        const isAssigned = sub.AssignedTo === USER_ID;
        const isOwner    = sub.ownerId    === USER_ID;
        const isAdmin    = this.userRoleName?.toLowerCase().includes('admin');
        return isSM && !isAssigned && !isOwner && !isAdmin;
    }

    _buildFromRaw(result) {
        const allSteps = [];
        let globalIdx = 0;

        result.forEach(record => {
            record.subItems.forEach(sub => {
                if (this._isHidden(sub)) return;
                globalIdx++;
                allSteps.push({
                    ...sub,
                    stepNumber        : globalIdx,
                    sectionName       : record.Name,
                    parentId          : record.Id,
                    iconName          : this._getIcon(sub.Status),
                    iconClass         : this._getIconClass(sub.Status),
                    metaDisplay       : this._buildMeta(sub),
                    isExpanded        : false,
                    iconChevron       : 'utility:chevronright',
                    timelines         : {},
                    showReassignButton: ['Re Open','Accepted','Provided Info','Assigned','Re Assigned'].includes(sub.Status),
                    cardClass         : this._cardClass(sub.Status),
                    numClass          : this._numClass(sub.Status),
                    statusBadgeClass  : this._badgeClass(sub.Status),
                    dotTitle          : `[${record.Name}] ${sub.Name} · ${sub.Status}`
                });
            });
        });
        this._allSteps = allSteps;

        // Auto-center window on active steps
        const activeIdxs = allSteps
            .map((s, i) => ACTIVE_STATUSES.has(s.Status) ? i : -1)
            .filter(i => i >= 0);

        if (activeIdxs.length > 0) {
            const mid = Math.round((activeIdxs[0] + activeIdxs[activeIdxs.length - 1]) / 2);
            let start = Math.max(0, mid - Math.floor(WINDOW_SIZE / 2));
            if (start + WINDOW_SIZE > allSteps.length) start = Math.max(0, allSteps.length - WINDOW_SIZE);
            this.windowStart = start;
        } else {
            this.windowStart = 0;
        }

        // Reset scroll flag so renderedCallback re-centres on active step
        const w = this.template.querySelector('.bp-track-wrapper');
        if (w) w._scrolledToActive = false;
        this._applyWindow();
    }

    _applyWindow() {
        // Always show ALL steps — scrolling handled by CSS overflow on wrapper
        const visible = new Set(this._allSteps.map(s => s.Id));

        this.flatSteps = this._allSteps.map(s => ({
            ...s,
            dotClass: this._dotClass(s.Status, true)
        }));

        this.records = this._rawRecords.map(record => {
            const col = sectionState(record.subItems);

            const visibleSteps = this._allSteps
                .filter(s => s.parentId === record.Id)
                .map((step, idx, arr) => ({
                    ...step,
                    isLastInSection: idx === arr.length - 1
                }));

            if (visibleSteps.length === 0) return null;

            return {
                ...record,
                stepCount        : visibleSteps.length,
                visibleSteps,
                sectionGroupClass: 'bp-sec-group',
                sectionGroupStyle: `border:2px solid ${col.border};background:${col.bg};`,
                sectionHeadStyle : `background:${col.head};`,
                connLineStyle    : `background:${col.conn};`,
                chevronStyle     : `border-color:${col.conn};`,
                legendDotStyle   : `background:${col.head};`
            };
        }).filter(Boolean);
    }

    // ── Navigation toggle logic ────────────────────────────────────────────────
    handleNavLeft() {
        const wrapper = this.template.querySelector('.bp-track-wrapper');
        if (!wrapper) return;
        // Snap to previous section: find the section group element just before current scroll
        const sections = this.template.querySelectorAll('.bp-sec-group');
        let target = null;
        for (let i = sections.length - 1; i >= 0; i--) {
            if (sections[i].offsetLeft < wrapper.scrollLeft - 4) {
                target = sections[i];
                break;
            }
        }
        wrapper.scrollTo({ left: target ? target.offsetLeft : 0, behavior: 'smooth' });
    }

    handleNavRight() {
        const wrapper = this.template.querySelector('.bp-track-wrapper');
        if (!wrapper) return;
        const rightEdge    = wrapper.scrollLeft + wrapper.clientWidth;
        const maxScroll    = wrapper.scrollWidth - wrapper.clientWidth;
        const sections     = this.template.querySelectorAll('.bp-sec-group');
        let target = null;
        for (let i = 0; i < sections.length; i++) {
            if (sections[i].offsetLeft >= rightEdge - 4) {
                target = sections[i];
                break;
            }
        }
        if (target) {
            const targetLeft   = target.offsetLeft;
            const targetRight  = targetLeft + target.offsetWidth;
            // If the full section fits within the scroll area from targetLeft, scroll there.
            // If scrolling to targetLeft would cut the end, scroll to maxScroll instead so
            // the last card is fully visible.
            const scrollTo = (targetRight > targetLeft + wrapper.clientWidth)
                ? targetLeft                                     // section wider than viewport — show its start
                : Math.min(targetLeft, maxScroll);               // normal case — clamp to max so last card never clips
            wrapper.scrollTo({ left: scrollTo, behavior: 'smooth' });
        } else {
            // Already past last section — scroll to very end so final card is fully visible
            wrapper.scrollTo({ left: maxScroll, behavior: 'smooth' });
        }
    }

    // ⑦ Collapse toggle
    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    // ── Class helpers ──────────────────────────────────────────────────────────
    _stateSlug(status) {
        if (ACTIVE_STATUSES.has(status)) return 'active';
        if (status === 'Completed')      return 'completed';
        return 'inactive';
    }
    _cardClass(status)  { return `bp-card bp-card--${this._stateSlug(status)}`; }
    _numClass(status)   {
        const pulse = ACTIVE_STATUSES.has(status) ? ' bp-num--pulse' : '';
        return `bp-num bp-num--${this._stateSlug(status)}${pulse}`;
    }
    _badgeClass(status) { return `bp-status-badge bp-badge--${this._stateSlug(status)}`; }
    _dotClass(status, inWindow) {
        const base = `bp-dot bp-dot--${this._stateSlug(status)}`;
        return inWindow ? base + ' bp-dot--inwin' : base;
    }

    _buildMeta(sub) {
        const parts = [];
        if (!this.hideMeta) {
            if (sub.ownerName)    parts.push(`<strong>${sub.ownerName}</strong>`);
            if (sub.AssignedName) parts.push(`<strong>${sub.AssignedName}</strong>`);
        }
        if (sub.Status) parts.push(`<span>${sub.Status}</span>`);
        return parts.length ? parts.join(' · ') : null;
    }

    _getIcon(status) {
        return {
            'Open':'utility:open_folder','Re Open':'utility:open_folder',
            'Accepted':'utility:open_folder','Provided Info':'utility:open_folder',
            'Not Actioned':'utility:pause','Completed':'utility:check','Rejected':'utility:close'
        }[status] || 'utility:question';
    }
    _getIconClass(status) {
        return {
            'Open':'icon-open','Re Open':'icon-open','Accepted':'icon-open','Provided Info':'icon-open',
            'Not Actioned':'icon-not-actioned','Completed':'icon-completed','Rejected':'icon-rejected'
        }[status] || '';
    }

    // ── Drag scroll (kept for touch) ───────────────────────────────────────────
    _dragStart(e, el) { this._dragState = { isDragging:true, startX:e.pageX, scrollLeft:el.scrollLeft }; el.style.cursor='grabbing'; }
    _dragMove(e, el)  { if (!this._dragState.isDragging) return; e.preventDefault(); el.scrollLeft = this._dragState.scrollLeft - (e.pageX - this._dragState.startX) * 1.2; }
    _dragEnd(el)      { this._dragState.isDragging = false; el.style.cursor = 'default'; }
    _touchStart(e,el) { this._dragState = { isDragging:true, startX:e.touches[0].pageX, scrollLeft:el.scrollLeft }; }
    _touchMove(e,el)  { el.scrollLeft = this._dragState.scrollLeft - (e.touches[0].pageX - this._dragState.startX); }

    // ── Event handlers ─────────────────────────────────────────────────────────
    stopProp(event) { event.stopPropagation(); }

   /* handleStepClick(event) {
        const stepId = event.currentTarget.dataset.id;
        const step   = this._allSteps.find(s => s.Id === stepId);
        if (!step || !ACTIVE_STATUSES.has(step.Status)) return;
        this.selectedStep   = step;
        this.isModalOpen    = true;
        this.acceptedByUser = false;
    }*/

    async handleStepClick(event) {
    const stepId = event.currentTarget.dataset.id;
    const step   = this._allSteps.find(s => s.Id === stepId);

    if (!step || !ACTIVE_STATUSES.has(step.Status)) return;
    let hasAccess = false;


    if (step.AssignedTo === this.userId) {
        hasAccess = true;
    }


    else if (step.ownerId === this.userId) {
        hasAccess = true;
    }


    else if (step.ownerId && !step.AssignedTo) {
        try {
            const isInQueue = await isUserInQueue({
                queueId: step.ownerId,
                userId: this.userId
            });

            if (isInQueue) {
                hasAccess = true;
            }
        } catch (error) {
            console.error('Queue check error', error);
        }
    }

    if (!hasAccess) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Access Denied',
                message: 'You are not assigned to this step or part of the queue.',
                variant: 'error'
            })
        );
        return;
    }


    this.selectedStep   = step;
    this.isModalOpen    = true;
    this.acceptedByUser = false;
}

    handleReAssign(event) {
        event.stopPropagation();
        const stepId = event.currentTarget.dataset.id;
        this.selectedStep = this._allSteps.find(s => s.Id === stepId);
        this.openReAssign = true;
    }

    handleExpandClick(event) {
        event.stopPropagation();
        const subId = event.currentTarget.dataset.id;
        const idx   = this._allSteps.findIndex(s => s.Id === subId);
        if (idx === -1) return;
        const step   = this._allSteps[idx];
        const expand = !step.isExpanded;

        const apply = (timelines) => {
            this._allSteps[idx] = {
                ...step,
                isExpanded  : expand,
                iconChevron : expand ? 'utility:chevrondown' : 'utility:chevronright',
                timelines   : timelines || {}
            };
            this._applyWindow();
        };

        if (expand) {
            getTimelineMetadata({ stepId: step.Id }).then(apply).catch(() => apply({}));
        } else {
            apply({});
        }
    }

    handleDotClick(event) {
        const stepId = event.currentTarget.dataset.id;
        const idx    = this._allSteps.findIndex(s => s.Id === stepId);
        if (idx === -1) return;
        let start = Math.max(0, idx - Math.floor(WINDOW_SIZE / 2));
        if (start + WINDOW_SIZE > this._allSteps.length) start = Math.max(0, this._allSteps.length - WINDOW_SIZE);
        this._applyWindow();
    }

    handleModalSubmit() {
        this.openReAssign = false; this.isModalOpen = false;
        this.selectedStep = {}; this.acceptedByUser = false;
        this.loadSteps();
        getRecordNotifyChange([{ recordId: this.recordId }]);
    }

    handleStepAccepted(event) {
        assignStepToCurrentUser({ stepId: event.detail.step.Id })
            .then(() => { this.acceptedByUser = true; })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title:'Error', message:err?.body?.message||'Failed', variant:'error' }));
                this.closeModal();
            });
    }

    closeModal() { this.openReAssign = false; this.isModalOpen = false; this.selectedStep = {}; }
}