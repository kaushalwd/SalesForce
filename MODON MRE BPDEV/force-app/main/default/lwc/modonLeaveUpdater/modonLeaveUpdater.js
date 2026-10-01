import { LightningElement,track, wire} from 'lwc';
import getCurrentUser from '@salesforce/apex/RoundRobbinController.getCurrentUser';
//import getApplicationTypes from '@salesforce/apex/RoundRobbinController.getApplicationTypes';
//import isManager from '@salesforce/apex/RoundRobbinController.isManager';
import hasManagerPermission from '@salesforce/apex/RoundRobbinController.hasManagerPermission';
import getAllUsers from '@salesforce/apex/RoundRobbinController.getAllUsers';
import saveRoundRobinRecord from '@salesforce/apex/RoundRobbinController.saveRoundRobinRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class ModonLeaveUpdater extends LightningElement {
    @track isModalOpen = false;
    @track leaveToday = false;
    @track fromDate = '';
    @track toDate = '';
    @track selectedUserId = '';
    @track selectedApplicationType = 'Service Cloud'; // Fixed value
    @track currentUser = {};
    @track isManager = false;
    @track userOptions = [];
    @track role = 'User'; // Default role
    @track isUserRole = true;
    @track isManagerRole = false;
    @track cancelLeave = false; // to cancelleave method

    roleOptions = [
        { label: 'User', value: 'User' },
        { label: 'Manager', value: 'Manager'}
    ];

    @wire(getCurrentUser)
    wiredCurrentUser({ error, data }) {
        if (data) {
            this.currentUser = data;
            this.selectedUserId = data.Id;
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading current user',
                    message: error.body.message,
                    variant: 'error',
                }),
            );
        }
    }
    connectedCallback() {
        // Check if the user has the Manager Permission Set
        hasManagerPermission()
        .then((result) => {
            this.isManager = result;

            // Disable the Manager option if user doesn't have permission
            if (!this.isManager) {
                this.roleOptions = [
                    { label: 'User', value: 'User' }];
                }
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error checking permissions',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
    }


    @wire(getAllUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.userOptions = data.map(user => {
                return { label: user.Name, value: user.Id };
            });
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading users',
                    message: error.body.message,
                    variant: 'error',
                }),
            );
        }
    }
   /* updateRoleOptions() {
        this.roleOptions = this.isManager ? this.allRoleOptions : this.allRoleOptions.filter(role => role.value === 'User');
    }*/
    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }
// thi s is used to cancel the leaves
    handleCancelLeaveChange(event) {
        this.cancelLeave = event.target.checked;
        if (this.cancelLeave) {
            this.fromDate = '';
            this.toDate = '';
            this.leaveToday = false; // Ensure "Leave Today" is unchecked
        }
    }




    handleCheckboxChange(event) {
        this.leaveToday = event.target.checked;
        if (this.leaveToday) {
            const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format
            this.fromDate = today;
            this.toDate = today;
        } else {
            this.fromDate = '';
            this.toDate = '';
        }
    }

    handleFieldChange(event) {
        const field = event.target.label;
        if (field === 'From Date') {
            this.fromDate = event.target.value;
        } else if (field === 'To Date') {
            this.toDate = event.target.value;
        }
    }
    handleRoleChange(event) {
        this.role = event.detail.value;
        this.isUserRole = this.role === 'User';
        this.isManagerRole = this.role === 'Manager';
        if (this.isUserRole) {
            this.selectedUserId = this.currentUser.Id;
        } else if (this.isManagerRole && this.isManager) {
            this.selectedUserId = '';
        }else if (this.isManagerRole && !this.isManager) {
            this.showErrorToast('Access Denied', 'You do not have permission to act as a Manager.');
            this.role = 'User'; // Revert to User role
        }
    }
        
    

    handleUserChange(event) {
        this.selectedUserId = event.detail.value;
    }
    saveRecord() {
        const leaveTodayBoolean = this.leaveToday;
        const cancelLeaveBoolean = this.cancelLeave;// leave cancelcheckbox

        saveRoundRobinRecord({
            leaveToday: leaveTodayBoolean,
            fromDate: cancelLeaveBoolean ? null : this.fromDate,
            toDate: cancelLeaveBoolean ? null : this.toDate,
            userId: this.selectedUserId,
            applicationType: this.selectedApplicationType,
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: cancelLeaveBoolean
                            ? 'Leave has been cancelled successfully'
                            : 'Leave Information updated successfully',
                        variant: 'success',
                    }),
                );
                this.closeModal();
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error saving record',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
    
        /*saveRoundRobinRecord({ leaveToday: leaveTodayBoolean, fromDate: this.fromDate, 
            toDate: this.toDate, userId: this.selectedUserId, applicationType: this.selectedApplicationType })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Leave Information updated Successfully',
                        variant: 'success',
                    }),
                );
                this.closeModal();
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error saving record',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });*/
    }

}