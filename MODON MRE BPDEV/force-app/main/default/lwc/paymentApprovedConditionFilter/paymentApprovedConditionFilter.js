/**
 * description       : 
 * author            : Kumaravel Mathivanan
 * group             : 
 * Created modified on  : 10-02-2025 * 
 * * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Kumaravel Mathivanan        10-02-2025     Initial Draft 
* 2.0 			Manoj						12-12-2025     Updated SOQL to add advanced search filters
*                                              (Project, Phase, Receipt Date, Transaction Date, Receipt Name)
 3.0 			Manoj						23-12-2025     Updated SOQL to add advanced search filters
*                                              (Project, Phase, Receipt Date, Transaction Date, Receipt Name, Unit Name)
**/
import { LightningElement, track, api } from 'lwc';
import getProjects from '@salesforce/apex/paymentApprovedController.getProjects';
import getPhasesByProject from '@salesforce/apex/paymentApprovedController.getPhasesByProject';
import getAllPhases from '@salesforce/apex/paymentApprovedController.getAllPhases';

export default class PaymentApprovedConditionFilter extends LightningElement {
    @track projectOptions = [];
    @track phaseOptions = [];

    selectedProjectId = 'ALL';
    selectedPhaseId = 'ALL';
    startDate = null;
    endDate = null;
    startDateTrans = null;
    endDateTrans = null;
    receiptName = null; //2.0 create varable
    unitName = null; //3.0 create varable

    connectedCallback() {
        this.loadProjects();
        this.loadAllPhases();
    }

    async loadProjects() {
        try {
            const projects = await getProjects();

            this.projectOptions = [
                { label: 'All', value: 'ALL' },
                ...projects.map(p => ({ label: p.Name, value: p.Id }))
            ];
            this.selectedProjectId = 'ALL';           
        } catch (error) {
            console.error('Error loading projects:', error);
        }
    }

    async loadAllPhases() {
        try {
            const allPhases = await getAllPhases();
            this.phaseOptions = [
                { label: 'All', value: 'ALL' },
                ...allPhases.map(p => ({ label: p.Name, value: p.Id }))
            ];

            this.selectedPhaseId = 'ALL'; 
            this.dispatchFilterChange();
        } catch (error) {
            console.error('Error loading all phases:', error);
        }
    }

    async handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        this.selectedPhaseId = 'ALL';

        if (this.selectedProjectId === 'ALL') {
            this.loadAllPhases();
        } else {
            try {
                const phases = await getPhasesByProject({ projectId: this.selectedProjectId });

                this.phaseOptions = [
                    { label: 'All', value: 'ALL' },
                    ...phases.map(p => ({ label: p.Name, value: p.Id }))
                ];
                this.selectedPhaseId = 'ALL';
                this.dispatchFilterChange();                
            } catch (error) {
                console.error('Error loading filtered phases:', error);
            }
        }
    }

    handlePhaseChange(event) {
        this.selectedPhaseId = event.detail.value;
        this.dispatchFilterChange();
    }

    handleDateChange(event) {
        const field = event.target.name;
        if (field === 'startDate') {
            this.startDate = event.target.value;
        } else if (field === 'endDate') {
            this.endDate = event.target.value;
        }else if (field === 'startDateTrans') {
            this.startDateTrans = event.target.value;
        } else if (field === 'endDateTrans') {
            this.endDateTrans = event.target.value;
        }

        this.dispatchFilterChange();
    }    
    // 2.0 Add the handleReceipt
    handleReceipt(event){       
        
        this.receiptName = event.target.value;
         this.dispatchFilterChange();
    }
    // 3.0 Add the handleReceipt
    handleUnitName(event){       
        
        this.unitName = event.target.value;
         this.dispatchFilterChange();
    }
    dispatchFilterChange() {
        let endDateToSend = this.endDate;
        let startDateToSend = this.startDate;
        let endDateToSendTrans = this.endDateTrans;
        let startDateToSendTrans = this.startDateTrans;
      
        /*if (!endDateToSend) {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            // Format as yyyy-mm-dd to match input type="date" format
            endDateToSend = today.toISOString().slice(0, 10);
        }*/

        if(startDateToSend != null){
            const enddateformatted = new Date(this.startDate);
            //startDateToSend = enddateformatted.toISOString().slice(0, 10);
            startDateToSend = enddateformatted.toISOString();
        }
        if(endDateToSend != null){
            const enddateformatted1 = new Date(this.endDate);
            //endDateToSend = enddateformatted1.toISOString().slice(0, 10);
            enddateformatted1.setUTCHours(23, 59, 59, 999);
            endDateToSend = enddateformatted1.toISOString();
        }         
// for transaction date

        if(startDateToSendTrans != null){
            const enddateformattedTrans = new Date(this.startDateTrans);
            startDateToSendTrans = enddateformattedTrans.toISOString();
        }
        if(endDateToSendTrans != null){
            const enddateformatted1Trans = new Date(this.endDateTrans);
            enddateformatted1Trans.setUTCHours(23, 59, 59, 999);
            endDateToSendTrans = enddateformatted1Trans.toISOString();
        } 
        // 2.0 Add the ReceiptName
        const detail = {
            projectId: this.selectedProjectId === 'ALL' ? 'ALL' : this.selectedProjectId,
            phaseId: this.selectedPhaseId === 'ALL' ? 'ALL' : this.selectedPhaseId,
            startDate: this.startDate === null ? null : startDateToSend,
            endDate:  this.endDate === null ? null : endDateToSend,
            startDateTrans: this.startDateTrans === null ? null : startDateToSendTrans,
            endDateTrans:  this.endDateTrans === null ? null : endDateToSendTrans,           
            receiptName:  this.receiptName === null ? null : this.receiptName,
            unitName:  this.unitName === null ? null : this.unitName          
        };

        this.dispatchEvent(new CustomEvent('filterchange', { detail }));
    }
}