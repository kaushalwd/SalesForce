/**********************************************************************************************************************
* Name               : agentOverviewCard
* Description        : Compact overview of an Agent's current status, role, EID/Passport/Broker Certificate
*                       expiry, and its last 5 status-change/suspension history entries — clear from -> to
*                       transition, full status names, who and when.
* Usage              : Record page component on Contact (Broker Agent)
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com          16 jun 2026      Initial Draft (as mbp_brokeragentInformation)
* 2.0         upendra.asam@modon.com          30 aug 2026      Rebuilt to match agencyOverviewCard's compact,
*                                                                Google-level design: plain border (no colored
*                                                                accent), full status names instead of abbreviated
*                                                                codes, real status history pulled from
*                                                                Broker_Status_Log__c (Agent_Status_Reason__c no
*                                                                longer exists on Contact), flat document rows
*                                                                instead of large hover-animated cards.
**********************************************************************************************************************/

import { LightningElement, api, wire } from 'lwc';
import getAgentOverview from '@salesforce/apex/MBP_BrokerAgencyLevelController.getAgentOverview';

const STATUS_CLASS = {
    'Active':               'chip-green',
    'Suspended':            'chip-amber',
    'Pending Verification': 'chip-blue',
    'Rejected':             'chip-red',
    'Blocked':              'chip-red',
    'In Active':            'chip-grey'
};

export default class AgentOverviewCard extends LightningElement {

    @api recordId;

    contact;
    history = [];
    error;

    @wire(getAgentOverview, { recordId: '$recordId' })
    wiredOverview({ data, error }) {

        if (data) {
            this.contact = data.con;
            this.history = (data.recentHistory || []).map((log) => this.mapLog(log));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.error(JSON.stringify(error));
        }
    }

    mapLog(log) {

        const changedDate = log.Status_Changed_Date__c
            ? new Date(log.Status_Changed_Date__c).toLocaleString(undefined, {
                day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
            })
            : '—';

        let suspensionRange = '';
        let suspensionNote = '';

        if (log.Is_Suspension__c && log.Suspension_End_Date__c) {

            const end = new Date(log.Suspension_End_Date__c);
            const today = new Date();
            const diffDays = Math.ceil((end - today) / (1000 * 60 * 60 * 24));
            const endLabel = end.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });

            if (log.Suspension_Start_Date__c) {
                const start = new Date(log.Suspension_Start_Date__c);
                const startLabel = start.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
                suspensionRange = `${startLabel} → ${endLabel}`;
            } else {
                suspensionRange = `Until ${endLabel}`;
            }

            suspensionNote = diffDays > 0
                ? `${diffDays} day${diffDays === 1 ? '' : 's'} left`
                : 'Ended';
        }

        const chipCls = STATUS_CLASS[log.New_Status__c] || 'chip-grey';

        return {
            key: log.Id,
            fromLabel: log.Previous_Status__c || '—',
            toLabel: log.New_Status__c || '—',
            reason: log.Status_Reason__c || 'No reason provided',
            changedBy: log.Status_Changed_By__r ? log.Status_Changed_By__r.Name : 'Unknown',
            changedDate,
            suspensionRange,
            suspensionNote,
            hasSuspension: !!suspensionRange,
            chipLabel: log.New_Status__c || 'Unknown',
            chipClass: 'timeline-chip ' + chipCls
        };
    }

    get badgeClass() {
        const cls = STATUS_CLASS[this.contact?.Agent_Status__c];
        return cls ? 'status-badge ' + cls.replace('chip-', 'badge-') : 'status-badge badge-grey';
    }

    get hasHistory() {
        return this.history.length > 0;
    }

    get showPrimaryOwner() {
        return this.contact?.Primary_Owner__c;
    }

    get showAgencyAdmin() {
        return this.contact?.Primary_Agency_Admin__c;
    }

    get showBrokerSection() {
        return this.contact?.IsBroker__c;
    }

    get eidExpiryDisplay() {
        return this.contact?.EID_Expiry_Date__c || 'None';
    }

    get eidDaysLeft() {
        return this.calculateDays(this.contact?.EID_Expiry_Date__c);
    }

    get passportExpiryDisplay() {
        return this.contact?.PassportExpiryDate__c || 'None';
    }

    get passportDaysLeft() {
        return this.calculateDays(this.contact?.PassportExpiryDate__c);
    }

    get brokerCertNumberDisplay() {
        return this.contact?.Broker_Certificate_Number__c || 'None';
    }

    get brokerCertExpiryDisplay() {
        return this.contact?.Broker_Certificate_Expiry_Date__c || 'None';
    }

    get brokerDaysLeft() {
        return this.calculateDays(this.contact?.Broker_Certificate_Expiry_Date__c);
    }

    calculateDays(dateValue) {
        if (!dateValue) {
            return 'None';
        }
        const today = new Date();
        const expiry = new Date(dateValue);
        const diffDays = Math.ceil((expiry.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays < 0) {
            return 'Expired';
        }
        return diffDays + ' days';
    }
}