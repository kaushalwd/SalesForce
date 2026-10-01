import {LightningElement, track,api, wire} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {NavigationMixin} from 'lightning/navigation';
import getPendingStepFields from '@salesforce/apex/BP_OmniApprovalLwcController.getPendingStepFields';
import getCompletedBPStepRecords from '@salesforce/apex/BP_OmniApprovalLwcController.getCompletedBPStepRecords';
import getActiveBpStepRecord  from '@salesforce/apex/BP_OmniApprovalLwcController.getActiveBpStepRecord';
import assignStepToCurrentUser from '@salesforce/apex/BusinessProcessController.assignStepToCurrentUser';
import getDocumentsWithFiles from '@salesforce/apex/fileUploadCompController.getDocumentsWithFiles';


export default class BpOmniApprovalChild extends NavigationMixin(LightningElement) {

    // ============================================================
    // API PARAMETERS
    // ============================================================

    @api bpRecordId;
    @api bpStepId;
    @api businessProcessName;

    @track pendingStepFields = [];

    @track documentsWithFiles = [];


    // ============================================================
    // STATE
    // ============================================================

    @track completedStepsList = [];

    @track selectedStep = {};

    @track isLoading = false;

    @track isApprvalModalOpen = false;

    @track isModalOpen = false;

    @track acceptedByUser = false;

    @track recordApproved = false;

    @track stepopen = true;


    // ============================================================
    // CURRENT STEP
    // ============================================================

    currentStepName = '';

    currentAssignedTo = '';

    currentStatus = 'Pending';
    // ============================================================
    // SOA (STATEMENT OF ACCOUNT)
    // ============================================================

    businessProcessType = '';

    salesOrderId = '';

    @track isSoaModalOpen = false;

    @track isSoaFullScreen = false;


    // ============================================================
    // LOAD CURRENT STEP
    // ============================================================

    @wire(
        getActiveBpStepRecord,
        {
            recordId: '$bpRecordId',
            bpStepRecordId: '$bpStepId'
        }
    )
    wiredActiveBPStepRecord({
        error,
        data
    }) {

        if (data) {

            this.selectedStep = data;

            this.currentStepName =
                data.Name || '';

            this.currentAssignedTo =
                data.AssignedName ||
                data.ownerName ||
                '';

            this.currentStatus =
                data.Status ||
                'Pending';

            this.businessProcessType =
                data.businessProcessType || '';

            this.salesOrderId =
                data.salesOrderId || '';

            /*
             * businessProcessName can be passed from parent.
             * If not passed, use Apex value.
             */
            if (!this.businessProcessName) {
                this.businessProcessName =
                    data.businessProcessName;
            }

        } else if (error) {

            console.error(
                'Error loading active step:',
                error
            );

        }

    }

    @wire(
    getPendingStepFields,
    {
        stepRecordId: '$bpStepId'
    }
)
wiredPendingStepFields({
    error,
    data
}) {

    if (data) {

        this.pendingStepFields = data;

    } else if (error) {

        console.error(
            'Error loading metadata fields:',
            error
        );

        this.pendingStepFields = [];
    }
}


    // ============================================================
    // LOAD APPROVED HIERARCHY
    // ============================================================

    @wire(
        getCompletedBPStepRecords,
        {
            bpRecordId: '$bpRecordId'
        }
    )
    wiredBpStepRecord({
        error,
        data
    }) {

        if (data) {


            this.completedStepsList =
                data
                    .filter(item =>
                        item.Status__c !== 'Not Actioned'
                    )
                    .map((item, index) => {

                        const assignedTo =
                            item.Assigned_To__r?.Name ||
                            item.Owner?.Name ||
                            '';

                        const stepStartTime =
                            item.Step_Open_Time__c ||
                            item.Assigned_Time__c;

                        return {

                            id: index + 1,

                            name:
                                item.Name || '',

                            status:
                                item.Status__c || '',

                            owner:
                                assignedTo || '-',

                            remarks:
                                item.Remarks_Comments__c || '-',

                            stepStartTime:
                                this.formatDateTime(stepStartTime),

                            stepEndTime:
                                this.formatDateTime(item.Completed_Time__c),

                            cardClass:
                                'step-card ' +
                                this.getStatusClass(
                                    item.Status__c
                                )
                        };

                    });

} else if (error) {

            console.error(
                'Error loading hierarchy:',
                error
            );

            this.completedStepsList = [];

        }

    }


    // ============================================================
    // DOCUMENTS
    // Only documents that already have at least one uploaded file
    // are shown here; this is a read-only reference list, not the
    // upload workflow (see c-file-upload-viewer-latest_-test).
    // ============================================================

    @wire(
        getDocumentsWithFiles,
        {
            businessProcessId: '$bpRecordId'
        }
    )
    wiredDocumentsWithFiles({
        error,
        data
    }) {

        if (data) {

            this.documentsWithFiles = data
                .filter(doc =>
                    doc.files &&
                    doc.files.length > 0
                )
                .map(doc => ({
                    ...doc,
                    files: doc.files.map(file => ({
                        ...file,
                        formattedDate: this.formatDateTime(file.createdDate)
                    }))
                }));

        } else if (error) {

            console.error(
                'Error loading documents:',
                error
            );

            this.documentsWithFiles = [];

        }

    }


    get hasDocuments() {

        return this.documentsWithFiles.length > 0;
    }


    navigateToFile(event) {

        const fileId = event.currentTarget.dataset.fileId;

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: fileId }
        });

    }


    // ============================================================
    // STATUS CSS
    // ============================================================

    getStatusClass(status) {

        if (status === 'Completed') {
            return 'status-completed';
        }

        return 'status-other';
    }


    formatDateTime(value) {

        if (!value) {
            return '-';
        }

        return new Date(value).toLocaleString();
    }


    // ============================================================
    // TOGGLE MAIN HIERARCHY
    // ============================================================

    toggleStepOpen() {

        this.stepopen =
            !this.stepopen;

    }


    // ============================================================
    // SOA (STATEMENT OF ACCOUNT)
    // ============================================================

    get showSoaLink() {

        return !!this.salesOrderId;
    }


    get isPaymentExtension() {

        return (
            this.businessProcessType ===
                'Payment Extension'
        );
    }


    get isEOIRefundApproval() {

        return (
            this.businessProcessType ===
                'EOI Refund Approval'
        );
    }


    handleViewSoa() {

        /*
         * The modal embeds c-bp-statement-of-account, which
         * fetches and renders the SOA data itself. There is
         * no PDF/iframe involved, so nothing needs to be
         * pre-loaded here.
         */
        this.isSoaModalOpen = true;
    }


    closeSoaModal() {

        this.isSoaModalOpen = false;
        this.isSoaFullScreen = false;
    }


    toggleSoaFullScreen() {

        this.isSoaFullScreen = !this.isSoaFullScreen;
    }


    get soaModalContainerClass() {

        return this.isSoaFullScreen
            ? 'soa-modal-container is-fullscreen'
            : 'soa-modal-container';
    }


    get soaFullScreenIcon() {

        return this.isSoaFullScreen
            ? 'utility:contract'
            : 'utility:expand';
    }


    get soaFullScreenLabel() {

        return this.isSoaFullScreen
            ? 'Exit Full Screen'
            : 'Full Screen';
    }


    // ============================================================
    // ACTION
    // ============================================================

    handleAction() {

        /*
         * Same behavior as parent component.
         *
         * Business Process uses the existing
         * c-approval-modal component.
         */
        this.isApprvalModalOpen = true;

        this.isModalOpen = true;

    }


    // ============================================================
    // STEP ACCEPTED
    // ============================================================

    handleStepAccepted(event) {

        const step =
            event.detail?.step ||
            this.selectedStep;


        if (!step || !step.Id) {

            this.showNotification(
                'Error',
                'Unable to identify the Business Process Step.',
                'error'
            );

            return;

        }


        this.isLoading = true;


        assignStepToCurrentUser({
            stepId: step.Id
        })
        .then(() => {

            this.acceptedByUser = true;

        })
        .catch(error => {

            console.error(
                'Assignment failed:',
                error
            );

            this.showNotification(
                'Error Assigning Step',
                error?.body?.message ||
                'Assignment failed.',
                'error'
            );

            this.acceptedByUser = false;

            this.closeModal();

        })
        .finally(() => {

            this.isLoading = false;

        });

    }


    // ============================================================
    // APPROVAL MODAL SUBMIT
    // ============================================================

    handleModalSubmit(event) {

        this.isApprvalModalOpen = false;

        this.isModalOpen = false;

        this.acceptedByUser = false;

        this.recordApproved = true;


        /*
         * Tell parent that the action is complete.
         */
        this.dispatchEvent(
            new CustomEvent(
                'actioncomplete',
                {
                    detail: {
                        stepId: this.bpStepId,
                        recordId: this.bpRecordId
                    }
                }
            )
        );

    }


    // ============================================================
    // CLOSE MODAL
    // ============================================================

    closeModal() {

        this.isModalOpen = false;

        this.isApprvalModalOpen = false;

        this.acceptedByUser = false;

    }


    // ============================================================
    // BACK
    // ============================================================

    handleBack() {

        this.dispatchEvent(
            new CustomEvent(
                'backhandle',
                {
                    detail: true
                }
            )
        );

    }


    // ============================================================
    // TOAST
    // ============================================================

    showNotification(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );

    }

}