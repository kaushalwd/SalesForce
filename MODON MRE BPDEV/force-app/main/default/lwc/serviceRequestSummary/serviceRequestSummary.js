/**
* Description: LWC for Service Request Summary Customer 360 dashboard
* Author: Chaitanya N
* Name: ServiceRequestSummary
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import getServiceRequestData from '@salesforce/apex/ServiceRequestHistoryController.getServiceRequestData';

export default class ServiceRequestSummary extends LightningElement {
    @api recordId;
    @api startDate; // optional - passed from parent
    @api endDate;   // optional - passed from parent

    @track totalSR = 0;
    @track openSR = 0;
    @track closedSR = 0;
    @track breachedSR = 0;

    @wire(getServiceRequestData, {
        recordId: '$recordId',
        startDate: '$startDate',
        endDate: '$endDate'
    })
    wiredServiceRequests({ data, error }) {
        if (data) {
           
            this.totalSR = Number(data['Total SR'] ?? 0);
            this.openSR = Number(data['Open SR'] ?? 0);
            this.closedSR = Number(data['Closed SR'] ?? 0);
            this.breachedSR = Number(data['SR Breached Cases'] ?? 0);
        } else if (error) {
            console.error('Error fetching SR data:', error);
        }
    }

     handleCardClick(event) {
        const filterType = event.currentTarget.dataset.type; // total/open/closed/breached

        this.dispatchEvent(
            new CustomEvent('opensrdrawer', {
                detail: { filterType },
                bubbles: true,
                composed: true
            })
        );
    }
}