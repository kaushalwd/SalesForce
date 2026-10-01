/**
* Description: LWC for Intenral information Customer 360 dashboard
* Author: Chaitanya N
* Name: InternalInfo
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import getInternalInformationData from '@salesforce/apex/InternalInformationController.getInternalInformationData';

export default class InternalInfo extends LightningElement {
    @api recordId;
    @api startDate;  // optional custom filters from parent
    @api endDate;

    @track apexResponse = {};
    @track groupedFields = [];
    loadUI = false;

    @wire(getInternalInformationData, {
        recordId: "$recordId",
        startDate: "$startDate",
        endDate: "$endDate"
    })
    wiredData({ error, data }) {

        if (error) {
            console.error('❌ Error fetching internal info:', error);
            this.loadUI = false;
        } else if (data) {

            this.apexResponse = { ...data };
            this.groupedFields = [];


            for (const key in this.apexResponse) {
                if (key !== 'RecordTypeLabel') {
                    this.groupedFields.push({
                        label: key,
                        value: this.apexResponse[key]
                    });
                }
            }

            // Add NPS/CSAT dummy value
            this.groupedFields.push({
                label: 'NPS/CSAT',
                value: '⭐️⭐️⭐️⭐️'
            });

            this.loadUI = Object.keys(this.apexResponse).length > 0;

        } else {
            console.warn('⚠️ No data returned from Apex.');
            this.loadUI = false;
        }
    }

    get titleLabel() {
        const label = this.apexResponse?.RecordTypeLabel === 'Organization'
            ? 'Org. Information'
            : 'Personal Information';
        return label;
    }
}