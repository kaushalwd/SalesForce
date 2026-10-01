import { LightningElement, api, track } from 'lwc';
import getSalesOrderDetails from '@salesforce/apex/SalesOrderPathController.getSalesOrderDetails';
import getStatusAndSubstatusData from '@salesforce/apex/SalesOrderPathController.getStatusAndSubstatusData';

export default class SalesOrderPathContainer extends LightningElement {
    @api recordId;
    @track status = '';
    @track subStatus = '';
    @track isReservationFormRequired = true;
    @track isDirectSales = false;
    @track orderedStatuses = [];
    @track dynamicMap = {};
    @track selectedStatusForSubstatus = '';

    hoveredStatusLabel = null;
hoveredSubStatusIndex = null;

    connectedCallback() {
        this.loadSalesOrder();
        this.loadPathMetadata();
    }

    async loadSalesOrder() {
        try {
            const data = await getSalesOrderDetails({ recordId: this.recordId });
            this.status = data.Status;
            this.subStatus = data.SubStatus;

            const flow = (data.SalesJourneyFlow || '').toLowerCase();

            this.isDirectSales = flow.includes('without broker');
            this.isReservationFormRequired = flow.includes('reservation');
        } catch (error) {
            console.error('Error loading Sales Order:', error);
        }
    }

    async loadPathMetadata() {
        try {
            const pathData = await getStatusAndSubstatusData();
            this.orderedStatuses = pathData.orderedStatuses || [];
            this.dynamicMap = pathData.statusToSubstatusMap || {};
        } catch (error) {
            console.error('Error loading Path metadata:', error);
        }
    }

    handleStatusClick(event) {
        const li = event.target.closest('li[data-label]');
        if (!li) return;

        const clickedLabel = li.dataset.label;

        this.selectedStatusForSubstatus = clickedLabel;

        this.hoveredSubStatusIndex = null;
    }

    handleStageMouseEnter(event) {
    const path = event.currentTarget.dataset.path;

    if (path === 'status') {
        this.hoveredStatusLabel = event.currentTarget.dataset.label;
    } else {
        this.hoveredSubStatusIndex = Number(event.currentTarget.dataset.index);
    }
}

handleStageMouseLeave(event) {
    const path = event.currentTarget.dataset.path;

    if (path === 'status') {
        this.hoveredStatusLabel = null;
    } else {
        this.hoveredSubStatusIndex = null;
    }
}

handlePathMouseLeave(event) {
    const path = event.currentTarget.dataset.path;

    if (path === 'status') {
        this.hoveredStatusLabel = null;
    } else {
        this.hoveredSubStatusIndex = null;
    }
}
    get processedStatuses() {
        return this.computeStatuses(this.orderedStatuses);
    }

    get processedSubStatuses() {
        const normalize = (s) => (s || '').trim().toLowerCase();
        const keys = Object.keys(this.dynamicMap);

        const selectedKey = keys.find(
            (k) => normalize(k) === normalize(this.selectedStatusForSubstatus)
        );
        const currentKey = keys.find((k) => normalize(k) === normalize(this.status));

        const baseStatus = selectedKey ? selectedKey : currentKey ? currentKey : null;
        let list = baseStatus ? [...this.dynamicMap[baseStatus]] : [];

        if (!this.isReservationFormRequired) {
            list = list.filter(
                (i) =>
                    ![
                        'Reservation Form Signed',
                        'Reservation Form Generated',
                        'Signed SPA (Customer)',
                        'SPA In-Progress'
                    ].includes(i)
            );
        } else {
            list = list.filter(
                (i) => !['SPA In Progress', 'SPA Signed (Customer)'].includes(i)
            );
        }

        if (this.isDirectSales) {
            list = list.filter(
                (i) => !['Broker Form Signed', 'Broker Form Generated'].includes(i)
            );
        }

        return this.computeSubstatusesForBase(list, baseStatus);
    }

    computeStatuses(list) {
    const hovered = this.hoveredStatusLabel;
    const hasHover = !!hovered;

    return list.map((label, index) => {
        let className = 'slds-path__item ';
        let isComplete = false;
        let textClass = 'slds-path__title';

        if (label === this.status) {
            className += 'slds-is-current slds-is-active';
            textClass += ' slds-text-color_inverse';
        } else if (index < list.indexOf(this.status)) {
            className += 'slds-is-complete';
            isComplete = true;
        } else {
            className += 'slds-is-incomplete';
        }

        let inlineStyle = '';
        let linkStyle = '';
        let stageStyle = '';

        if (hasHover) {
            if (label === hovered) {
                inlineStyle = `
                    flex: 1 1 100%;
                    min-width: 0;
                    width: 100%;
                    margin: 0;
                    padding: 0;
                    overflow: visible;
                `;
                linkStyle = `
                    width: 100%;
                    max-width: 100%;
                    min-width: 0;
                    border-radius: 999px;
                    justify-content: center;
                    padding: 0 1.25rem;
                    margin: 0;
                    box-sizing: border-box;
                `;
                stageStyle = 'display:none;';
            } else {
                inlineStyle = 'flex:0 0 0; width:0; min-width:0; margin:0; padding:0; overflow:hidden;';
                linkStyle = 'width:0; min-width:0; padding:0; margin:0; overflow:hidden;';
                stageStyle = 'display:none;';
            }
        }

        return { label, className, isComplete, textClass, inlineStyle, linkStyle, stageStyle };
    });
}

    computeSubstatusesForBase(list, baseStatus) {
    const out = [];
    const statusOrder = this.orderedStatuses;
    const currentStatusIdx = statusOrder.indexOf(this.status);
    const baseIdx = statusOrder.indexOf(baseStatus);
    const hoveredIdx = this.hoveredSubStatusIndex;
    const hasHover = hoveredIdx !== null && hoveredIdx !== undefined;

    const pushRow = (label, state, idx) => {
        let className = 'slds-path__item ';
        let textClass = 'slds-path__title';
        let isComplete = false;

        if (state === 'complete') {
            className += 'slds-is-complete';
            isComplete = true;
            textClass += ' slds-text-color_inverse';
        } else if (state === 'current') {
            className += 'slds-is-current slds-is-active';
            textClass += ' slds-text-color_inverse';
        } else {
            className += 'slds-is-incomplete';
        }

        let inlineStyle = '';
        let linkStyle = '';
        let stageStyle = '';

        if (hasHover) {
            if (idx === hoveredIdx) {
                inlineStyle = `
                    flex: 1 1 100%;
                    min-width: 0;
                    width: 100%;
                    margin: 0;
                    padding: 0;
                    overflow: visible;
                `;
                linkStyle = `
                    width: 100%;
                    max-width: 100%;
                    min-width: 0;
                    border-radius: 999px;
                    justify-content: center;
                    padding: 0 1.25rem;
                    margin: 0;
                    box-sizing: border-box;
                `;
                stageStyle = 'display:none;';
            } else {
                inlineStyle = 'flex:0 0 0; width:0; min-width:0; margin:0; padding:0; overflow:hidden;';
                linkStyle = 'width:0; min-width:0; padding:0; margin:0; overflow:hidden;';
                stageStyle = 'display:none;';
            }
        }

        out.push({ label, className, isComplete, textClass, inlineStyle, linkStyle, stageStyle });
    };

    if (baseIdx === -1 || list.length === 0) {
        return out;
    }

    if (baseIdx < currentStatusIdx) {
        list.forEach((l, i) => pushRow(l, 'complete', i));
    } else if (baseIdx > currentStatusIdx) {
        list.forEach((l, i) => pushRow(l, 'incomplete', i));
    } else {
        const curIdxInList = list.indexOf(this.subStatus);
        list.forEach((l, i) => {
            const state = i < curIdxInList ? 'complete' : i === curIdxInList ? 'current' : 'incomplete';
            pushRow(l, state, i);
        });
    }

    return out;
}

    get displayStatuses() {
    return this.processedStatuses;
}

get displaySubStatuses() {
    return this.processedSubStatuses;
}

    get statusStageWidthStyle() {
    return this.hoveredStatusLabel
        ? 'width:100%; min-width:0; max-width:none; text-align:center; margin:0; padding:0; display:block;'
        : `width:${(100 / (this.displayStatuses.length || 1)).toFixed(2)}%; min-width:80px; max-width:140px; text-align:center; margin:0; padding:0; display:block;`;
}

    get subStageWidthStyle() {
    return this.hoveredSubStatusIndex !== null
        ? 'width:100%; min-width:0; max-width:none; text-align:center; margin:0; padding:0; display:block;'
        : `width:${(100 / (this.displaySubStatuses.length || 1)).toFixed(2)}%; min-width:80px; max-width:140px; text-align:center; margin:0; padding:0; display:block;`;
}

    get statusLabelStyle() {
    return this.hoveredStatusLabel
        ? 'white-space:nowrap; overflow:visible; text-overflow:clip; margin:0; display:block; width:100%; text-align:center;'
        : 'white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin:0; display:block; width:100%; text-align:center;';
}

    get subLabelStyle() {
    return this.hoveredSubStatusIndex !== null
        ? 'white-space:nowrap; overflow:visible; text-overflow:clip; margin:0; display:block; width:100%; text-align:center;'
        : 'white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin:0; display:block; width:100%; text-align:center;';
}
}