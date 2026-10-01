import { LightningElement, api, wire, track } from 'lwc';
import saveCallTask from '@salesforce/apex/GenericTaskController.saveCallTask';
import getTaskScreenData from '@salesforce/apex/GenericTaskController.getTaskScreenData';
import getPicklistValues from '@salesforce/apex/GenericTaskController.getPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const TASK_OBJECT = 'Task';
const STATUS_FIELD = 'Status';
const DISCUSSION_OUTCOME_FIELD = 'D_T_Customer_Discussion_Outcome__c';
const CUSTOMER_SOLUTION_STATUS = 'Customer Solution';

export default class GenericTaskCreator extends LightningElement {
    @api recordId;

    subject;
    status;
    priority;
    activityDate;
    comments;
    milestone;
    nextMilestone;
    taskId;
    discussionOutcome;

    isLoading = false;
    hasData = false;
    currentTaskAvailable = false;

    @track closedTasks = [];
    statusOptions = [];
    discussionOutcomeOptions = [];

    wiredTaskResult;

   /* @wire(getPicklistValues, {
        objectName: TASK_OBJECT,
        fieldName: STATUS_FIELD
    })
    wiredStatusPicklist({ data, error }) {
        if (data) {
            this.statusOptions = data.map(item => ({
                label: item,
                value: item
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load Status picklist values', 'error');
        }
    }*/

    @wire(getPicklistValues, {
    objectName: TASK_OBJECT,
    fieldName: STATUS_FIELD
})
wiredStatusPicklist({ data, error }) {
    if (data) {

        const allowedStatuses = [
            'Open',
            'Customer Reached',
            'Customer Not Reachable'

        ];

        this.statusOptions = allowedStatuses
            .filter(status => data.includes(status))
            .map(status => ({
                label: status,
                value: status
            }));

    } else if (error) {
        this.showToast('Error', 'Failed to load Status picklist values', 'error');
    }
}

    @wire(getPicklistValues, {
        objectName: TASK_OBJECT,
        fieldName: DISCUSSION_OUTCOME_FIELD
    })
    wiredDiscussionOutcomePicklist({ data, error }) {
        if (data) {
            this.discussionOutcomeOptions = data.map(item => ({
                label: item,
                value: item
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load Discussion Outcome picklist values', 'error');
        }
    }

    @wire(getTaskScreenData, { recordId: '$recordId' })
    wiredTask(result) {
        this.wiredTaskResult = result;
        const { data, error } = result;

        if (data) {
            this.hasData = true;
            this.closedTasks = data.closedTasks || [];

            if (data.currentOpenTask) {
                const t = data.currentOpenTask;

                this.currentTaskAvailable = true;
                this.taskId = t.Id;
                this.subject = t.Subject;
                this.status = t.Status;
                this.priority = t.Priority;
                this.activityDate = t.ActivityDate;
                this.comments = t.Description;
                this.milestone = t.Milestone__c;
                this.nextMilestone = t.NextTaskMilestone__c;
                this.discussionOutcome = t.D_T_Customer_Discussion_Outcome__c;
            } else {
                this.resetOpenTaskFields();
            }
        } else if (error) {
            this.hasData = false;
            this.showToast('Error', 'Failed to load task data', 'error');
        }
    }

    resetOpenTaskFields() {
        this.currentTaskAvailable = false;
        this.taskId = null;
        this.subject = null;
        this.status = null;
        this.priority = null;
        this.activityDate = null;
        this.comments = null;
        this.milestone = null;
        this.nextMilestone = null;
        this.discussionOutcome = null;
    }

    get hasClosedTasks() {
        return this.closedTasks && this.closedTasks.length > 0;
    }

    get closedTaskCountLabel() {
        return `Total Closed: ${this.closedTasks.length}`;
    }

    get showDiscussionOutcome() {
        return this.status === CUSTOMER_SOLUTION_STATUS;
    }

    handleStatusChange(event) {
        this.status = event.detail.value;

        if (!this.showDiscussionOutcome) {
            this.discussionOutcome = null;
        }
    }

    handleDiscussionOutcomeChange(event) {
        this.discussionOutcome = event.detail.value;
    }

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    saveTask() {
        if (!this.taskId) {
            this.showToast('Error', 'No open task available to save', 'error');
            return;
        }

        if (this.showDiscussionOutcome && !this.discussionOutcome) {
            this.showToast('Error', 'Please select Customer Discussion Outcome', 'error');
            return;
        }

        const taskObj = {
            Id: this.taskId,
            Subject: this.subject,
            Status: this.status,
            Priority: this.priority,
            ActivityDate: this.activityDate,
            Description: this.comments,
            WhatId: this.recordId,
            Milestone__c: this.milestone,
            NextTaskMilestone__c: this.nextMilestone,
            TaskSubtype: 'Call',
            D_T_Customer_Discussion_Outcome__c: this.discussionOutcome
        };

        this.isLoading = true;

        saveCallTask({ t: taskObj })
            .then(() => {
                this.showToast('Success', 'Task Saved Successfully', 'success');
                return refreshApex(this.wiredTaskResult);
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast(
                    'Error',
                    error?.body?.message || 'Error while saving task',
                    'error'
                );
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}