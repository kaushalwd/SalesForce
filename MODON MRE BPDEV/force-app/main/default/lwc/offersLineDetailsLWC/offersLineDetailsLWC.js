import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ADD_OFFER_LABEL from '@salesforce/label/c.AddOfferButton';
import getCurrentUserEmail from '@salesforce/apex/OpportunityGenerateOfferCtrl.getCurrentUserEmail';
import defaulofferdetails from '@salesforce/apex/OpportunityGenerateOfferCtrl.queryOffers';
//import addofferdetails from '@salesforce/apex/OpportunityGenerateOfferCtrl.getOfferLineDetails';
import offerdetails from '@salesforce/apex/OpportunityGenerateOfferCtrl.getOfferDetails';

export default class OffersLineDetailsLWC extends LightningElement {
    @track projectId;
    @track opptyId;
    @track unitId;
    @track unitIdList = [];
    @track selectedValue = '';
    @track isShowModal = false;

    showAddOfferButton = true;
    isOfferExist = true;
    isOfferDetailsExist = true;
    offerdetails=[];
    addOffersList = [];
    applyOffer = true;
    @track selectedValue = '';
    @track options = [];
    @track selectedOffersData = [];
    @track selectedSaveOffersData = [];
    @track addOfferstableData = [];
    @track selectedOffersRowsIds = [];
    @track allOffersData = [];

    @track tableData = [];
    @track offertableData = [];
    addOffrcolumns = [
        { label: 'Offer Type', fieldName: 'OfferType__c', type: 'text' },
        { label: 'Offer On', fieldName: 'OfferOn__c', type: 'text' },
        { label: 'Value', fieldName: 'PromoValue__c', type: 'text' },
        { label: 'Promotion', fieldName: 'OfferNameFormula__c', type: 'text' }
        
    ];
    columns = [
        { label: 'Offer Type', fieldName: 'OfferType__c', type: 'text' },
        { label: 'Offer On', fieldName: 'OfferOn__c', type: 'text' },
        { label: 'Value', fieldName: 'PromoValue__c', type: 'text' },
        { label: 'Promotion', fieldName: 'OfferNameFormula__c', type: 'text' },
        {
            label:'Action',
            type:"button-icon",
            typeAttributes:{
               name:'Delete',
               title:'Delete',
               iconName:'utility:delete',
               iconClass:'slds-icon-text-error',
               disabled: { fieldName: 'Is_Default_Offer__c' } // Disable based on a field
            }
         }
        
    ];

    connectedCallback(){
        getCurrentUserEmail()
            .then(email => {
                const allowedEmails = ADD_OFFER_LABEL.split(',').map(e => e.trim().toLowerCase());
                if (allowedEmails.includes(email.toLowerCase())) {
                    this.showAddOfferButton = false;
                }
            })
            .catch(error => {
                console.error('Error fetching user email', error);
            });
    }
    disconnectedCallback(){
     //   alert('disconnecting');
    }
    renderedCallback(){
        
    }
    get showAddOfferButton() {
        return this.isOfferDetailsExist;
        //return this.showAddOfferButton && this.isOfferDetailsExist;
    }
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === this.totalPages;
    }
    @api 
    invokeOfferDetails(projectId,opptyId,unitId,selectedUnitIds){
      //  alert('projectId:'+projectId);
       
        this.projectId = projectId;
        this.unitId = unitId;
        this.opptyId = opptyId;
        this.unitIdList = selectedUnitIds;
       // alert('opptyId:'+this.opptyId);
      //  alert('unitId: '+this.unitId);
      //  alert('projectId: '+this.projectId);
        //this.getdefaultOffers();
        //this.addMoreOffers(););
        this.getdefaultOffers();
       
    }
    @api
    getTableData() {
        //return this.tableData;
        return this.offertableData;
    }

    getOfferDetails(){
     //   alert('offer details call apex');
     offerdetails({projectId : this.projectId})
        .then(data => {
            this.isOfferExist = true;
            this.offerdetails = data;
          //  alert('this.offerdetails apex '+this.offerdetails.length);
            if(this.offerdetails.length > 0){
                let uniqueOptions = new Set(); // Use Set to store unique values
                uniqueOptions.add(JSON.stringify({
                    label: 'Choose Offers',
                    value: 'Choose Offers'
                }));
                this.offerdetails.forEach(offer => {
                    uniqueOptions.add(JSON.stringify({
                        label: offer.OfferName__c,
                        value: offer.Id
                    }));
                });
            
                // Convert Set back to an array
                this.options = Array.from(uniqueOptions).map(item => JSON.parse(item));
                this.options = [...this.options];
            //alert('this.options apex '+JSON.stringify(this.options));         
            }
        })
        .catch(error => {
            this.error = error;
            this.isOfferExist = false;
        });
    }
    getdefaultOffers(offerIdval){
        this.addOfferstableData = [];
        this.tableData = [];
        defaulofferdetails({projectId: this.projectId,opptyId:this.opptyId,unitId:this.unitId,offerId:offerIdval,unitIdList:this.unitIdList})
        .then(data => {
           // this.tableData = data;
            if( data.offerLinesList.length > 0){
                for(var i=0;i < data.offerLinesList.length;i++){
                    
                    //if(data.offerLinesList[i].Is_Default_Offer__c === true){
                        this.tableData.push({
                            Id: data.offerLinesList[i].Id,
                            OfferType__c: data.offerLinesList[i].OfferType__c,
                            OfferOn__c: data.offerLinesList[i].OfferOn__c,
                            PromoValue__c: data.offerLinesList[i].PromoValue__c,
                            OfferNameFormula__c: data.offerLinesList[i].OfferNameFormula__c
                        });
                    //}

                        this.allOffersData.push({
                            Id: data.offerLinesList[i].Id,
                            OfferType__c: data.offerLinesList[i].OfferType__c,
                            OfferOn__c: data.offerLinesList[i].OfferOn__c,
                            PromoValue__c: data.offerLinesList[i].PromoValue__c,
                            OfferNameFormula__c: data.offerLinesList[i].OfferNameFormula__c
                        });
                    
                this.allOffersData = [...this.allOffersData];

                }
                const uniqueMap = new Map();
                this.addOfferstableData.forEach(item => {
                    uniqueMap.set(item.Id, item);
                });
                this.addOfferstableData = [...uniqueMap.values()];
                
              
                this.tableData = [...this.tableData];
               this.offertableData.push({
                    unitId: this.unitId,
                    offerLinesList:  this.tableData
                   });
                this.updateAddOffersTable();
                this.isOfferExist = true;
            }else{
                this.isOfferDetailsExist = true;
                this.isOfferExist = false;
            }
        })
        .catch(error => {
            this.error = error;
            this.isOfferExist = false;
        });
    }

    updateAddOffersTable() {
        const selectedIds = new Set(this.tableData.map(row => row.Id));
        this.addOfferstableData = this.allOffersData.filter(offer => !selectedIds.has(offer.Id));
        const uniqueMap = new Map();
                this.addOfferstableData.forEach(item => {
                    uniqueMap.set(item.Id, item);
                });
                this.addOfferstableData = [...uniqueMap.values()];
        if(this.addOfferstableData.length > 0){
            this.isOfferDetailsExist = false;
        }else{
            this.isOfferDetailsExist = true;
        }
    }
   /* addMoreOffers(offerIdval){
        addofferdetails({offerId: offerIdval})
        .then(data => {
            this.addOfferstableData = data;
            if( this.addOfferstableData.length > 0){
                this.isOfferDetailsExist = false;
            }else{
                this.isOfferDetailsExist = true;
            }
        })
        .catch(error => {
            this.isOfferDetailsExist = true;
             this.error = error;
        });
    } */
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const rowId = event.detail.row.Id;
        if (actionName === 'Delete') {
           
           // Debugging: Check if rowId is captured correctly

           // Filter out the deleted row
           const newData = this.tableData.filter(row => row.Id !== rowId);
           
           // Debugging: Check if newData is updated correctly

           // Force reactivity by reassigning the array
           this.tableData = [...newData];
            
        }

        this.updateAddOffersTable();
    }
    handleRowActionAddOffers(event){
        const selectedRows = event.detail.selectedRows; // Get selected rows
        this.selectedRowIds = selectedRows.map(row => row.Id); // Extract only the IDs
       
        if (this.selectedRowIds.length > 0) {
            this.applyOffer = false;
            this.selectedOffersData = selectedRows;
        }else{
            this.applyOffer = true;
        }
     }
     handleSelectedOffers(event) {
        const selectedOffersRows = event.detail.selectedRows;
        const offerOnMap = new Map();
        let hasDuplicate = false;
        const cleanedRows = [];
        this.selectedSaveOffersData = [];
        this.selectedOffersRowsIds = [];
        this.offertableData = [];
        for (let i = 0; i < selectedOffersRows.length; i++) {
            const row = selectedOffersRows[i];
            const offerOn = row.OfferOn__c;
    
            if (offerOnMap.has(offerOn)) {
                // Duplicate detected
                hasDuplicate = true;
                this.showToast('Error', `Offer on "${offerOn}" is already selected.`, 'error');
                // Skip this row so it gets removed from selection
                continue;
            } else {
                offerOnMap.set(offerOn, true);
                cleanedRows.push(row); // Only push valid unique rows
            }
        }
    
        // Update the selected row IDs (only valid ones)
        this.selectedOffersRowsIds = cleanedRows.map(row => row.Id);
        this.selectedSaveOffersData = cleanedRows;
        this.offertableData.push({
            unitId: this.unitId,
            offerLinesList:  this.selectedSaveOffersData
           });
        this.applyOffer = this.selectedOffersRowsIds.length === 0;
    }
    
    
     handleChange(event){
      //  alert('event:'+event.detail.value);
      if(event.detail.value !== 'Choose Offers'){
        this.getdefaultOffers(event.detail.value);
      }else{
         this.isOfferDetailsExist = true;
         this.tableData = [];
      }
       
       // this.addMoreOffers(event.detail.value);
     }
    saveAddOffers(event){
        
        const keyField = 'Id'; // Replace with your unique field
            // Create a Map with existing data
            const dataMap = new Map(this.tableData.map(item => [item[keyField], item]));
            // Add new data, ensuring no duplicates
            this.selectedOffersData.forEach(item => {
                dataMap.set(item[keyField], item);
            });
            // Convert Map back to array
            this.tableData = Array.from(dataMap.values());
            //this.tableData = [...this.tableData];
            this.offertableData.push({
                unitId: this.unitId,
                offerLinesList:  this.tableData
               });
               this.updateAddOffersTable();
    }
    handleOffers(){
        this.isShowModal = true;
    }
    hideModalBox() {  
        this.saveAddOffers();
        this.isShowModal = false;
    }
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
   
}