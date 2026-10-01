import { LightningElement, api, wire } from 'lwc';
import reAssignUser from '@salesforce/apex/LwcApproveRejectBpstepController.reAssignUser';
import getqueueMembers from '@salesforce/apex/LwcApproveRejectBpstepController.getqueueMembers';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import checkSysAdmin from '@salesforce/apex/LwcApproveRejectBpstepController.checkSysAdmin'; 


export default class StepReAssignment extends LightningElement {
    @api step;
    reAssignToUserOptions = [];
    usrId;
    comment;
    isSysAdmin = false;
    isUserInQueue = false;
    assignToSelf = false;
    loading = false;
    assignToAdminChecked=false; 

    // get logged-in user's profile
  
    handleReAssignChange(e) {
        this.usrId = e.detail.value;
    }

    handleCommentChange(event) {
        this.comment = event.detail.value;
    }

    handleCheckboxChange(event) {
        this.assignToSelf = event.target.checked;
    }

    closeModal() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleSave() {
        this.saveUser();
    }

    connectedCallback() {
        this.queueDetails();
        this.checkAdmin();
    }

    checkAdmin() {
        checkSysAdmin({ usrId: USER_ID })
            .then(result => {
                this.isSysAdmin = result;
            })
            .catch(error => {
                console.error('Error checking SysAdmin:', error);
            });
    }

    queueDetails() {
        getqueueMembers({ bpsId: this.step.Id })
            .then(res => {
                this.reAssignToUserOptions = res;

                //Check if current user is in the queue
                this.checkIfUserInQueue(res);
            })
            .catch(err => this.showToast('Error loading queue users', err.body.message, 'error'));
    }

    checkIfUserInQueue(queueMembers) {
        if (queueMembers && queueMembers.length > 0) {
            // Assuming queueMembers is an array of objects with 'value' (userId) property
            this.isUserInQueue = queueMembers.some(member => member.value === USER_ID);
        }
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async saveUser() {
        try {
            this.loading = true;

            // if sysadmin checked the box → assign to self
            let targetUserId = this.assignToSelf ? USER_ID : this.usrId;

            if(!this.isUserInQueue && !this.isSysAdmin){ //USER_ID!=this.step.AssignedTo    
                this.loading = false;
                return this.showToast('Error', 'You are not System Admin or not the part of the Queue to Re-Assign the step', 'error');
                //return this.showToast('Error', 'You are not System Admin or assigned User to Re-Assign the step', 'error');
            }

            if (!targetUserId) {
                this.showToast('Validation', 'Please select a user or check "Assign to me".', 'warning');
                this.loading = false;
                return;
            }

            if (!this.comment) {
                this.showToast('Validation', 'Please add Comment', 'warning');
                this.loading = false;
                return;
            }

            await reAssignUser({
                bpsId: this.step.Id,
                usrId: targetUserId,
                comment: this.comment
            });

            this.loading = false;
            this.dispatchEvent(new CustomEvent('submit'));
            this.showToast('Info', 'Reassigned Successfully', 'success');
        } catch (error) {
            this.loading = false;
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        }
    }
}