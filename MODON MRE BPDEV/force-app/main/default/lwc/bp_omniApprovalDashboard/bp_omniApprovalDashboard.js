import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getApprovalDashboard from '@salesforce/apex/BP_OmniApprovalLwcController.getApprovalDashboard';

export default class BpOmniApprovalDashboard extends NavigationMixin(LightningElement) {

    @track dashboardList = [];
    wiredDashboardResult;

    // ============================================================
    // APPROVAL FORM
    // ============================================================
    showApprovalForm = false;
    businessProcessId;
    bpStepRecordId;
    businessProcessName;
    paymentRequestId;
    selectedProcessType;

    // ============================================================
    // DEEP LINK (EMAIL / DIRECT NAVIGATION)
    // ============================================================
    deepLinkProcessed = false;

    // ============================================================
    // LOADING
    // ============================================================
    isLoading = false;

    // ============================================================
    // WIRE
    // ============================================================
    @wire(getApprovalDashboard)
    wiredApprovalDashboard(result) {
        this.wiredDashboardResult = result;

        const { data, error } = result;

        if (data) {
            this.dashboardList = this.prepareDashboard(data);
        } else if (error) {
            console.error('Dashboard error', JSON.stringify(error));
            this.dashboardList = [];
        }
    }

    // ============================================================
    // DEEP LINK (EMAIL / DIRECT NAVIGATION)
    //
    // Lets an email (or any external link) open this page directly
    // on the approval/child screen for a specific step, instead of
    // landing on the dashboard list first.
    //
    // Expected URL query params (Lightning requires the "c__" prefix
    // for custom parameters on App Pages / Tabs):
    //
    //   ...?c__bpId=<Business_Process__c Id>&c__stepId=<Business_Process_Step__c Id>
    // ============================================================
    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        if (this.deepLinkProcessed) {
            return;
        }

        if (!pageRef || !pageRef.state) {
            return;
        }

        const bpId = pageRef.state.c__bpId;
        const stepId = pageRef.state.c__stepId;

        if (bpId && stepId) {
            this.deepLinkProcessed = true;

            this.businessProcessId = bpId;
            this.bpStepRecordId = stepId;
            this.selectedProcessType = 'Business_Process__c';
            this.showApprovalForm = true;
        }
    }

    // ============================================================
    // PREPARE DASHBOARD
    // ============================================================
    prepareDashboard(records) {
        if (!Array.isArray(records)) {
            console.error('prepareDashboard expected array:', records);
            return [];
        }

        return records
            .map((record) => {
                if (!record || typeof record !== 'object') {
                    return null;
                }

                const previousStepList = Array.isArray(record.previousSteps)
                    ? record.previousSteps
                    : [];

                const previousSteps = previousStepList
                    .filter((step) => step && typeof step === 'object')
                    .map((step) => ({
                        ...step,
                        fields: this.prepareFields(step.fields)
                    }));

                const currentStepFields = this.prepareFields(
                    record.currentStepFields
                );

                return {
                    ...record,
                    currentStepFields,
                    previousSteps,
                    expanded: false,
                    previousStepCount: previousSteps.length,
                    hasPreviousSteps: previousSteps.length > 0
                };
            })
            .filter((record) => record !== null);
    }

    // ============================================================
    // PREPARE FIELDS
    // ============================================================
    prepareFields(fields) {
        if (!Array.isArray(fields)) {
            return [];
        }

        const fieldList = fields.map((field) => {
            if (!field) {
                return null;
            }

            let sequence = 9999;

            if (
                field.sequence !== null &&
                field.sequence !== undefined &&
                field.sequence !== ''
            ) {
                const parsedSequence = Number(field.sequence);

                if (!Number.isNaN(parsedSequence)) {
                    sequence = parsedSequence;
                }
            }

            return {
                apiName: field.apiName || '',
                label: field.label || '',
                value:
                    field.value === null || field.value === undefined
                        ? ''
                        : String(field.value),
                sequence,
                mobile: field.mobile === true,
                desktop: field.desktop === true,
                isVisibleMobile: field.mobile === true,
                isVisibleDesktop: field.desktop === true
            };
        });

        const validFields = fieldList.filter((field) => field !== null);

        return [...validFields].sort(
            (a, b) => a.sequence - b.sequence
        );
    }

    // ============================================================
    // COMBINED PENDING / IN PROGRESS LIST
    // Completed/Approved records are intentionally excluded.
    // ============================================================
    get filteredList() {
        const allowedStatuses = [
            'Open',
            'Provided Info',
            'Not Valid',
            'Accepted',
            'Re Open',
            'Assigned'
        ];

        return this.dashboardList.filter((record) =>
            allowedStatuses.includes(record.status)
        );
    }

    get pendingInProgressCount() {
        return this.filteredList.length;
    }

   get sectionHeaderText() {
    return 'Pending / In Progress';
   }

    // ============================================================
    // EMPTY
    // ============================================================
    get showEmpty() {
        return !this.isLoading && this.filteredList.length === 0;
    }

    // ============================================================
    // EXPAND / COLLAPSE PREVIOUS STEPS
    // ============================================================
    toggleBusinessProcess(event) {
        event.stopPropagation();

        const currentStepId = event.currentTarget.dataset.id;

        this.dashboardList = this.dashboardList.map((record) => {
            if (record.currentStepId === currentStepId) {
                return {
                    ...record,
                    expanded: !record.expanded
                };
            }

            return record;
        });
    }

    // ============================================================
    // APPROVAL ACTION
    // ============================================================
    handleAction(event) {
        const bpId = event.currentTarget.dataset.id;
        const stepId = event.currentTarget.dataset.stepId;
        const bpName = event.currentTarget.dataset.name;

        this.businessProcessId = bpId;
        this.bpStepRecordId = stepId;
        this.businessProcessName = bpName;
        this.selectedProcessType = 'Business_Process__c';
        this.showApprovalForm = true;
    }

    // ============================================================
    // OPEN BUSINESS PROCESS
    // ============================================================
    openRecord(event) {
        event.stopPropagation();

        const recordId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Business_Process__c',
                actionName: 'view'
            }
        });
    }

    // ============================================================
    // BACK FROM APPROVAL
    // ============================================================
    async backBtnHandler() {
        this.clearSelectedApproval();
        await this.refreshDashboard();
    }

    // ============================================================
    // REFRESH
    // ============================================================
    async handleRefresh() {
        await this.refreshDashboard();
    }

    async refreshDashboard() {
        this.isLoading = true;

        try {
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            console.error('Refresh error', error);
        } finally {
            this.isLoading = false;
        }
    }

    // ============================================================
    // CHILD ACTION COMPLETE
    // ============================================================
    async handleChildActionComplete() {
        this.clearSelectedApproval();
        await this.refreshDashboard();
    }

    clearSelectedApproval() {
        this.showApprovalForm = false;
        this.businessProcessId = null;
        this.bpStepRecordId = null;
        this.businessProcessName = null;
        this.paymentRequestId = null;
        this.selectedProcessType = null;
    }
}