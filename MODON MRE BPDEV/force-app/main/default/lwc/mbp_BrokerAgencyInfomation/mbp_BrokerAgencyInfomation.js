/**********************************************************************************************************************
* Name               : agencyOverviewCard
* Description        : Compact overview of an Agency's current status and its last 5 status-change/suspension
*                       history entries — clear from -> to transition, full status names, who and when.
* Usage              : Record page component on Account (Broker Agency)
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com          16 jun 2026      Initial Draft
* 2.0         upendra.asam@modon.com          30 aug 2026      Rebuilt as a compact card, pulling reason/history
*                                                                from Broker_Status_Log__c.
* 3.0         upendra.asam@modon.com          30 aug 2026      Chip-based timeline, flat compliance row.
* 4.0         upendra.asam@modon.com          30 aug 2026      Removed VAT/Bank and duplicate top reason. Added
*                                                                Trade License countdown ring.
* 5.0         upendra.asam@modon.com          30 aug 2026      Removed Trade License section entirely. Removed
*                                                                the colored left border accent (plain card now).
*                                                                Timeline chips now show the full status name
*                                                                instead of a 3-letter code.
**********************************************************************************************************************/

import { LightningElement, api, wire } from 'lwc';
import getAgencyOverview from '@salesforce/apex/MBP_BrokerAgencyLevelController.getAgencyOverview';

const STATUS_CLASS = {
    'Active':               'chip-green',
    'Suspended':            'chip-amber',
    'Pending Verification': 'chip-blue',
    'Rejected':             'chip-red',
    'Blocked':              'chip-red',
    'In Active':            'chip-grey'
};

export default class AgencyOverviewCard extends LightningElement {

    @api recordId;

    account;
    history = [];
    error;

    @wire(getAgencyOverview, { recordId: '$recordId' })
    wiredOverview({ data, error }) {

        if (data) {
            this.account = data.acc;
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
        const cls = STATUS_CLASS[this.account?.Agency_Status__c];
        return cls ? 'status-badge ' + cls.replace('chip-', 'badge-') : 'status-badge badge-grey';
    }

    get hasHistory() {
        return this.history.length > 0;
    }
}