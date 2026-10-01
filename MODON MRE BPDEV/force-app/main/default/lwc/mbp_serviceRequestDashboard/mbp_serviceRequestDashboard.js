import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getServiceRequests from '@salesforce/apex/MBP_ServiceRequestDashboardController.getServiceRequests';

const STATUS_CLASS_MAP = {
    'Closed': 'pill pill-success',
    'Cancelled': 'pill pill-danger',
    'Rejected': 'pill pill-danger',
    'In-progress': 'pill pill-warning'
};

const BR_STATUS_CLASS_MAP = {
    'Approved': 'pill pill-success',
    'Rejected': 'pill pill-danger',
    'RMI': 'pill pill-warning',
    'Require more Information': 'pill pill-warning',
    'Completed': 'pill pill-success',
    'Signed': 'pill pill-success'
};

export default class ServiceRequestDashboard extends LightningElement {
    allRequests = [];
    searchTerm = '';
    isLoading = true;
    error;
    wiredResult;

    @wire(getServiceRequests)
    wiredSRs(result) {
        this.wiredResult = result;
        this.isLoading = false;
        const { data, error } = result;
        if (data) {
            this.allRequests = data.map((req) => this.decorate(req));
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.allRequests = [];
        }
    }

    decorate(req) {
        const comments = req.brManagerComments;

        return {
            ...req,
            statusClass: STATUS_CLASS_MAP[req.status] || 'pill pill-neutral',
            brStatusClass: BR_STATUS_CLASS_MAP[req.activeBrStatus] || 'pill pill-neutral',
            activeStepDisplay: req.activeTaskSubject || '—',
            activeTaskStatusDisplay: req.activeTaskStatus || '—',
            activeTaskOwnerDisplay: req.activeTaskOwner || '—',
            rmiClosedByDisplay: req.rmiClosedByName || '—',
            rmiClosedDateDisplay: req.rmiClosedDate
                ? new Date(req.rmiClosedDate).toLocaleDateString('en-GB', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric'
                  })
                : '—',
            commentsDisplay: comments
                ? (comments.length > 60 ? comments.substring(0, 60) + '…' : comments)
                : '—'
        };
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    get filteredRequests() {
        if (!this.searchTerm) {
            return this.allRequests;
        }
        return this.allRequests.filter((req) =>
            req.srNumber && req.srNumber.toLowerCase().includes(this.searchTerm)
        );
    }
}