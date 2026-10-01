import { LightningElement, track, api, wire } from 'lwc';
import getBusinessProcessSteps from '@salesforce/apex/BusinessProcessController.getBusinessProcessSteps';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import assignStepToCurrentUser from '@salesforce/apex/BusinessProcessController.assignStepToCurrentUser';
import getTimelineMetadata from '@salesforce/apex/StepTimeCalculatorRealTime.getTimelineMetadata';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { getRecord } from 'lightning/uiRecordApi';
const FIELDS = ['Business_Process__c.BP_Department_Name__c'];
 import PROCESS_FLOW_NAME from '@salesforce/schema/Business_Process__c.Process_Flow__r.Name';// By Ramanand Clash Approval BP
 import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import getUserRoleName from '@salesforce/apex/BPFileUploaderController.getUserRoleName';
export default class VerticalGridComponent extends LightningElement {
    @api recordId;
    @track records = [];
    @track selectedStep = {};
    acceptedByUser = false;
    enableMarketingModal = false;
    businessProcessName;
    openReAssign = false;
    isModalOpen = false;
    isLoading = false;
    @track hideMeta = false;
    @track currentUserName;
    @track processFNames;
    @track bpOwnerId;
    @track userRoleName;
    userId = USER_ID;

    connectedCallback() {
       this.loadSteps()
    }
    // By Ramanand Clash Approval BP
    @wire(getRecord, { recordId: '$recordId', fields: [PROCESS_FLOW_NAME,NAME_FIELD] })
        wiredBusinessProcess({ data, error }) {
            if (data) {
                const processFlowName = data.fields?.Process_Flow__r?.value?.fields?.Name?.value;
                this.processFNames = processFlowName;
                this.hideMeta = processFlowName === 'Clash Approval';
                this.currentUserName = data.fields.Name.value;
            } else if (error) {
                console.error('Error fetching Business Process record:', error);
            }
        }


    async loadSteps(){
        try{
        this.userRoleName = await getUserRoleName({ userId: this.userId });
    getBusinessProcessSteps({ recordId: this.recordId })
        .then(result => {

            if (!result || result.length === 0) {
                this.records = [];
                return;
            }
            
            this.records = result.map(record => ({
                ...record,
                subItems: record.subItems.map(sub => {
                    let isHidden = false;
                    const isSMStep = sub.Name && sub.Name.toLowerCase().includes('sm');
                    const isAssignedUser = sub.AssignedTo === USER_ID;
                    const isOwnerUser = sub.ownerId === USER_ID;
                    const isAuditRole = this.userRoleName && (
                        this.userRoleName.toLowerCase().includes('admin') ||
                        this.userRoleName === 'Admin'  // Exact matches as needed
                    );

                    const isAuditUser = sub.Name === 'Sales audit' || sub.Name === 'Business audit manager';
                    if (isSMStep && !isAssignedUser && !isOwnerUser) {
                        isHidden = !isAuditRole;
                    }
                   
                    return {
                        ...sub,
                        isHidden,
                        iconName: this.getIcon(sub.Status),
                        iconClass: this.getIconClass(sub.Status),
                        gridClass: `sub-grid-item ${this.getGridClass(sub.Status)}`,
                        metaDisplay: this.buildMetaDisplay(sub),
                        isExpanded: false,
                        isNextSectionAvailable: sub.isNextSectionAvailable,//Added By Ashok To Identify When the DropDown should render for next step Creation
                        processIdenOptions: sub.processIdenOptions,
                        formRendering: sub.formRendering,
                        fieldRendering: sub.fieldRendering,
                        iconChevron: 'utility:chevronright',
                        timelines: {},
                        showReassignButton:
                            (sub.Status === 'Re Open' ||
                             sub.Status === 'Accepted' ||
                             sub.Status === 'Provided Info')
                    };
                })
            }));

        })
        .catch(error => {
            console.error('Error loading process steps:', error);
        });
}
catch (error) {
        console.error('Error fetching role name:', error);
    }
    }

    
    //Ashok added this block to get the current record field values
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            //const deptName = data.fields.BP_Department_Name__c.value;
            this.enableMarketingModal = deptName === 'Marketing';
        } else if (error) {
            console.error('Error retrieving record:', error);
        }
    }

    renderedCallback() {
        // Loop over all records/subItems and set HTML manually
        this.records.forEach(record => {
            record.subItems.forEach(sub => {
                const el = this.template.querySelector(`.meta-html[data-id="${sub.Id}"]`);
                if (el && sub.metaDisplay) {
                    el.innerHTML = sub.metaDisplay;
                }
            });
        });
    }

    buildMetaDisplay(sub) {
        const parts = [];
        //if (sub.ownerName && this.hideMeta == false) parts.push(`<strong>${sub.ownerName}</strong>`);
        //if (sub.AssignedName) parts.push(`<strong>${sub.AssignedName}</strong>`);
        // By Ramanand Clash Approval BP
        if (!this.hideMeta) {
            if (sub.ownerName) parts.push(`<strong>${sub.ownerName}</strong>`);
            if (sub.AssignedName) parts.push(`<strong>${sub.AssignedName}</strong>`);
        }
        if (sub.Status) parts.push(`<strong>${sub.Status}</strong>`);
        return parts.length ? parts.join(' ') : null;
    }

    handleReAssign(event){
        event.stopPropagation();
        const stepId = event.currentTarget.dataset.id;
        const parentId = event.currentTarget.dataset.parent;
        
        const parent = this.records.find(r => r.Id === parentId);
        const step = parent.subItems.find(s => s.Id === stepId);  
        this.selectedStep = step;
        this.openReAssign=true;
    }


    handleStepClick(event) {
        const stepId = event.currentTarget.dataset.id;
        const parentId = event.currentTarget.dataset.parent;

        const parent = this.records.find(r => r.Id === parentId);
        const step = parent.subItems.find(s => s.Id === stepId);

        if (['Open', 'Re Open', 'Accepted', 'Provided Info'].includes(step.Status)) {
            this.selectedStep = step;
            this.isModalOpen = true;
            this.acceptedByUser = false;
        }
    }

    handleModalSubmit() {
        this.openReAssign=false;
        this.isModalOpen = false;
        this.selectedStep = {};
        this.acceptedByUser = false;

        // Re-fetch records logic can be added here
         this.loadSteps()
         getRecordNotifyChange([{ recordId: this.recordId }]);
    }

    handleStepAccepted(event) {
        const { step } = event.detail;
        assignStepToCurrentUser({ stepId: step.Id })
            .then(() => {
                this.acceptedByUser = true;
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Assigning Step',
                    message: error?.body?.message || 'Assignment failed.',
                    variant: 'error'
                }));
                this.acceptedByUser = false;
                this.closeModal();
            });
    }

    closeModal() {
        this.openReAssign=false;
        this.isModalOpen = false;
        this.selectedStep = {};
    }

    handleExpandClick(event) {
       event.stopPropagation();
    const subId = event.currentTarget.dataset.id;
    const parentId = event.currentTarget.dataset.parent;

    const parentIdx = this.records.findIndex(r => r.Id === parentId);
    const subIdx = this.records[parentIdx].subItems.findIndex(s => s.Id === subId);
    const subStep = this.records[parentIdx].subItems[subIdx];
    const isExpanded = !subStep.isExpanded;

    if (isExpanded) {
        
        getTimelineMetadata({ stepId: subStep.Id })
            .then(result => {
                this.records[parentIdx].subItems[subIdx] = {
                    ...subStep,
                    isExpanded: true,
                    iconChevron: 'utility:chevrondown',
                    timelines: result || {}
                };
            })
            .catch(error => {
                console.error('Timeline metadata error:', error);
                this.records[parentIdx].subItems[subIdx] = {
                    ...subStep,
                    isExpanded: true,
                    iconChevron: 'utility:chevrondown',
                    timelines: {}
                };
            });
    } else {
        // Collapse logic
        this.records[parentIdx].subItems[subIdx] = {
            ...subStep,
            isExpanded: false,
            iconChevron: 'utility:chevronright',
            timelines: {}
        };
    }


/*

        this.records[parentIdx].subItems[subIdx] = {
            ...subStep,
            isExpanded,
            iconChevron: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
            timelines: isExpanded ? mockTimelineResponse : {}
        };
*/
    }

    get showReopenCount() {
    return this.sub?.timelines?.reOpenCount > 0 && this.sub?.timelines?.reOpenTime;
    }


    getIcon(status) {
        switch (status) {
            case 'Open':
            case 'Re Open':
            case 'Accepted':
            case 'Provided Info':
                return 'utility:open_folder';
            case 'Not Actioned':
                return 'utility:pause';
            case 'Completed':
                return 'utility:check';
            case 'Rejected':
                return 'utility:close';
            default:
                return 'utility:question';
        }
    }

    getIconClass(status) {
        switch (status) {
            case 'Open':
            case 'Re Open':
            case 'Accepted':
            case 'Provided Info':
                return 'icon-open';
            case 'Not Actioned':
                return 'icon-not-actioned';
            case 'Completed':
                return 'icon-completed';
            case 'Rejected':
                return 'icon-rejected';
            default:
                return '';
        }
    }

    getGridClass(status) {
        switch (status) {
            case 'Open':
            case 'Re Open':
            case 'Accepted':
            case 'Provided Info':
                return 'grid-open';
            case 'Not Actioned':
                return 'grid-not-actioned';
            case 'Completed':
                return 'grid-completed';
            case 'Rejected':
                return 'grid-rejected';
            default:
                return '';
        }
    }
}