import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import getAllProjects from '@salesforce/apex/UnitSearchLwcControllerFromSR.getAllProjects';
import getAllBuildings from '@salesforce/apex/UnitSearchLwcControllerFromSR.getAllBuildings';
import getUnitDetails from '@salesforce/apex/UnitSearchLwcControllerFromSR.getUnitDetails'; 
import getUnitDetailsforPhase from '@salesforce/apex/UnitSearchLwcControllerFromSR.getUnitDetailsforPhase';
import generateSalesOffer from '@salesforce/apex/UnitSearchLwcControllerFromSR.generateSalesOffer';
import sendSalesOfferPDF from '@salesforce/apex/UnitSearchLwcControllerFromSR.sendSalesOfferPDF';
import saveSalesOrder from '@salesforce/apex/UnitSearchLwcControllerFromSR.saveSalesOrder';
import getEOIDetails from '@salesforce/apex/UnitSearchLwcControllerFromSR.getEOIDetails';
import checkExistingSalesOrder from '@salesforce/apex/UnitSearchLwcControllerFromSR.checkExistingSalesOrder';
import updateUnitsAsBlocked from '@salesforce/apex/UnitSearchLwcControllerFromSR.updateUnitsAsBlocked';
import unblockSelectedUnits from '@salesforce/apex/UnitSearchLwcControllerFromSR.unblockSelectedUnits';
import checkUnitStatus from '@salesforce/apex/UnitSearchLwcControllerFromSR.checkUnitStatus';
import getBlockingHours from '@salesforce/apex/UnitSearchLwcControllerFromSR.getBlockingHours';
import saveBlockedUnits from '@salesforce/apex/UnitSearchLwcControllerFromSR.saveBlockedUnits';
import getSalesOrderfromServiceReqeust from '@salesforce/apex/UnitSearchLwcControllerFromSR.getSalesOrderfromServiceReqeust';
import getAllProjectsforSR from '@salesforce/apex/UnitSearchLwcControllerFromSR.populateProjectsforSR';
import updateServiceRequest from '@salesforce/apex/UnitSearchLwcControllerFromSR.updateServiceRequest';

export default class UnitSearchLwcForSR extends LightningElement {
    
    selectedProject = '';
    selectedBuilding = '';
    searchText = '';
    selectedAction = '';
    showOfferDetails = false;
    showBtnGroup = true;
    showOfferDetails = false;
    isSwapOrUpgrade = false;
    projectList = [];
    unitInventoryDetails = [];
    unitLst = [];
    isActiveTab = false;
    blockingHourOptions = [];
    totalAmount;
    paidAmount;
    unitDetails = {};
    offerLabel = 'Generate Offer';

    pageNumber = 1;
    isLoading = false;
    
    confirmation = false;

    paymentTypeName = '';
    paymentInstallments = [];
    paymentPlanId;

    selectedBlockingHours = '';

    unitOptionPrice = 0;

    fullUrl='';

    showBlockRequestModal = false;

    salesOrderExist = false;

    availableEOI = 0;

    customerName = '';

    lastPageName = '';

    @track
    selectedUnits={};

    @api recordId;
    @track offerDetailsLst = [];
    unitRollbackConfirmation = false;

    get showOriginalPrice(){
        return (this.selectedUnits[this.currentUnit].unitOptionPrice == 0 || this.selectedUnits[this.currentUnit].unitOptionPrice === undefined)
    }

    get alNaseemSelected(){
        for(let i = 0;i < this.projectList.length; i++){
            if(this.projectList[i].value == this.selectedProject && this.projectList[i].label == 'Al Naseem'){
                return true;
            }
        }
        return true;
    }

    connectedCallback(){
        this.getSalesOrderinfofromServiceReqeust();        
      //  this.checkExistingSalesOrder();
        
        
    }
    renderedCallback() {
        this.handleGetOffersData(this.currentUnit);
    }
    
    handleGetOffersData(currentTab) {
        if(this.isActiveTab){


        // Select the child component from the active tab
        const offerDetailsComp = this.template.querySelector(
            'c-offers-line-details-l-w-c[data-unitid="' + currentTab + '"]'
        );
    



        if (offerDetailsComp) {
            const data = offerDetailsComp.invokeOfferDetails(this.selectedProject,this.recordId,this.currentUnit,this.selectedUnitIds); // Call method from child
           
        } else {
            console.error('Offer Details component not found for active tab');
        }
        this.isActiveTab = false;
        }
    }
    // updradation units
    getSalesOrderinfofromServiceReqeust() {
        this.isLoading = true;
        getSalesOrderfromServiceReqeust({srId : this.recordId})
        .then(data => {
            this.salesOrderExist = data.SalesOrder__c ? true : false;
            this.isLoading=false;
            if(this.salesOrderExist){
                this.paidAmount = data.SalesOrder__r.Totalpaidamount__c; 
                if(data.RecordType.DeveloperName == 'SRM_Unit_Swap' || data.RecordType.DeveloperName == 'Service_Request_Management_Unit_Upgrade'){  
                    this.isSwapOrUpgrade = true;
                    this.offerLabel = 'Proceed';
                    this.totalAmount = data.SalesOrder__r.TotalAmount__c;
                }
                if(data.RecordType.DeveloperName == 'Service_Request_Management_Unit_Upgrade') {
                    this.selectedProject = data.SalesOrder__r.Unit__r.Phase__r.Project__c;
                    this.selectedBuilding = data.SalesOrder__r.Unit__r.Phase__c; 
                    this.projectList = [{value: data.SalesOrder__r.Unit__r.Phase__r.Project__c, label: data.SalesOrder__r.ProjectName__c}];
                    this.buildingList = [{value: data.SalesOrder__r.Unit__r.Phase__c, label: data.SalesOrder__r.Phase_Name__c}];
                    if(this.selectedBuilding){  
                        this.populateUnitDataForSR();
                    }
                } else if(data.RecordType.DeveloperName == 'SRM_Unit_Swap') {                    
                    this.populateProjectsforSR(data.SalesOrder__r.Unit__r.Phase__r.Project__c);
                } else {
                    this.populateProjects();
                }                
                this.getOpportunityEOIs();
            }
        })
        .catch(error => {
            this.isLoading=false;
        });
    }

    checkExistingSalesOrder(){
        this.isLoading = true;
        checkExistingSalesOrder({srId : this.recordId})
        .then(data => {
            this.salesOrderExist = data;
            this.isLoading=false;
            if(!data){
                this.populateProjects();
                this.getOpportunityEOIs();
            }
        })
        .catch(error => {
            this.isLoading=false;
        });
        
    }

    getOpportunityEOIs(){
        this.isLoading = true;

        getEOIDetails({oppId : this.recordId})
        .then(data => {
            this.availableEOI = data;
            this.isLoading=false;
        })
        .catch(error => {
            this.isLoading=false;
        });
    }

    get isOfferSelected(){
        if(this.selectedAction == 'OFFER') return true;

        return false;
    }

    get isBookingSelected(){
        if(this.selectedAction == 'BOOKING') return true;

        return false;
    }

    get isBookingSection(){

    }

    get disableProceed(){
        return (this.pageNumber==3);
    }

    get disablePath(){
        return (this.pageNumber==1 || this.steps==[]);
    }

    get showPage1(){
        return this.pageNumber==1;
    }
    get showPage2(){
        return this.pageNumber==2
    }
    get showPage3(){
        return this.pageNumber==3
    }

    get totalSelectedUnits(){
        debugger;
        var selectedCountToReturn=0;
        if(this.selectedUnits){
            for(var key in this.selectedUnits){
                if(this.selectedUnits[key].selectionStatus){
                    selectedCountToReturn++;
                }
            }
        }
        return selectedCountToReturn;
    }

    get disableOffer(){
        return (this.totalSelectedUnits < 1);
    }

    get selectedUnitList(){
        let unitsToReturn = [];
        for(var key in this.selectedUnits){
            if(this.selectedUnits[key].selectionStatus){
                unitsToReturn.push(this.selectedUnits[key]);
            }
        }
        return unitsToReturn;
    }

    get selectedUnitIds(){
        let selectedIds = [];
        for(var key in this.selectedUnits){
            if(this.selectedUnits[key].selectionStatus){
                selectedIds.push(key);
            }
        }
        return selectedIds;
    }

    populateProjectsforSR(projId){
        this.isLoading = true;
        getAllProjectsforSR({projectId : projId})
        .then(data => {
            this.projectList = data;
            this.selectedProject = data[0].value;
            if(this.selectedProject){
                this.populateBuildings();
            }else{
                this.isLoading=false;
            }
        })
        .catch(error => {
            this.projectList = undefined;
            this.isLoading=false;
        });
    }

    populateProjects(){
        this.isLoading = true;
        getAllProjects()
        .then(data => {
            this.projectList = data;
            this.selectedProject = data[0].value;
            if(this.selectedProject){
                this.populateBuildings();
            }else{
                this.isLoading=false;
            }
        })
        .catch(error => {
            this.projectList = undefined;
            this.isLoading=false;
        });
    }

    get showBlockingHours(){
        if(this.selectedBlockingHours !== undefined && this.selectedBlockingHours.length > 0){
            return true;
        }
        return false;
    }

    manageBlockingHours(event){
        this.selectedBlockingHours = event.target.value;
    }

    updateCommentValue(event){
        this.commentValue = event.target.value;
    }

    get blockingHoursOptions(){
        getBlockingHours()
        .then(data => {
            this.blockingHourOptions = data;
            this.selectedBlockingHours = (data && data[0] && data[0].value)?data[0].value:'';
            return data;
        })
        .catch(error => {
            // this.isLoading=false;
            return null;
        });
    }

    populateBuildings(){
        getAllBuildings({projectId :this.selectedProject })
        .then(data => {
            this.buildingList = data;
            this.selectedBuilding = (data && data[0] && data[0].value)?data[0].value:'';
            if(this.isSwapOrUpgrade){
                this.populateUnitDataForSR();
            } else {
                this.populateUnitData();
            }
            this.isLoading=false;
        })
        .catch(error => {
            this.buildingList = undefined;
            this.isLoading=false;
        });
    }

    populateUnitData(){
        getUnitDetails({buildingsId :this.selectedBuilding, oppId : this.recordId })
        .then(data => {
            this.unitInventoryDetails=data;

            if (this.unitInventoryDetails.length == 0) {
                const evt = new ShowToastEvent({
                    title: 'Units',
                    message: 'No unit available for selected filter criteria ',
                    variant: 'error',
                });
                this.dispatchEvent(evt);
                this.unitLst = undefined;
                //this.selectedUnits={};
            }else{
                this.unitLst = (this.unitInventoryDetails || []).map(unit => {
                    return {
                      ...unit,
                      isSelected : (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false)
                    }
                });
            }

            for(let i = 0; i < this.unitLst.length; i++){
                this.unitDetails[this.unitLst[i].Id] = this.unitLst[i];
            }
            this.isLoading=false;
        })
        .catch(error => {
            this.isLoading=false;
            
        });
    }

    populateUnitDataForSR(){
        getUnitDetailsforPhase({buildingsId :this.selectedBuilding, totalAmount :this.totalAmount})
        .then(data => {
            this.unitInventoryDetails=data;

            if (this.unitInventoryDetails.length == 0) {
                const evt = new ShowToastEvent({
                    title: 'Units',
                    message: 'No unit available for selected filter criteria ',
                    variant: 'error',
                });
                this.dispatchEvent(evt);
                this.unitLst = undefined;
                //this.selectedUnits={};
            }else{
                this.unitLst = (this.unitInventoryDetails || []).map(unit => {
                    return {
                      ...unit,
                      isSelected : (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false)
                    }
                });
            }

            for(let i = 0; i < this.unitLst.length; i++){
                this.unitDetails[this.unitLst[i].Id] = this.unitLst[i];
            }
            this.isLoading=false;
        })
        .catch(error => {
            this.isLoading=false;
            
        });
    }

    handleRowSelect(event){
        this.isLoading=true;
        
        if(event.target.checked){
            this.selectedUnits[event.target.dataset.id] = {
                'selectionStatus':event.target.checked,
                'unitId': event.target.dataset.id, 
                'unitName':event.target.dataset.unitName,
                'projectId':this.unitDetails[event.target.dataset.id].Phase__r.Project__c,
                'projectName':this.unitDetails[event.target.dataset.id].Phase__r.Project__r.Name,
                'price':this.unitDetails[event.target.dataset.id].TotalPrice__c,
                'buildingName':this.unitDetails[event.target.dataset.id].Phase__r.Name,
                'buildingId':this.unitDetails[event.target.dataset.id].Phase__c
            };

        }else{
            this.selectedUnits[event.target.dataset.id].selectionStatus=false;
            this.selectedUnits[event.target.dataset.id].paymentDetails=undefined;
        }
        if(this.isSwapOrUpgrade){            
            if(this.totalSelectedUnits > 1)  { 
                const evt = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Please select only one unit for swap/upgrade.',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                let tempUnitList = JSON.parse(JSON.stringify(this.unitLst));
                this.template.querySelector(`[data-id="${event.target.dataset.id}"]`).checked = false;
                this.selectedUnits[event.target.dataset.id].selectionStatus = false;
            } 
        }else{
            this.showBtnGroup = true;
            this.showBtnGroup = true;
        }
        this.isLoading=false;
    }

    handleBookingUnitActive(event){
        this.isLoading=true;
        this.currentUnit = event.target.value;
        this.isActiveTab = true;
        let paymentData = this.selectedUnits[this.currentUnit].paymentDetails;
        for(let i = 0 ; i < paymentData.paymentLst.length ; i ++){
            if(paymentData.paymentLst[i].paymentObj.Id == paymentData.selectedPayment){
                this.paymentInstallments = paymentData.paymentLst[i].paymentObj.Payment_Installments__r;
                this.calculatePaymentAmount();
                this.paymentTypeName = paymentData.paymentLst[i].paymentObj.Name;
                break;
            }
        }
        this.isLoading = false;

    }

    validateBlockForm(){
        let isInvalid = false;
        let inputFields = this.template.querySelectorAll('.blockDetails');
        inputFields.forEach(inputField => {

        if(!inputField.checkValidity()){
            inputField.reportValidity();
            isInvalid = true;
        }
        });
        if(isInvalid){
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: 'Please review all the errors', variant: 'error', mode: 'dismissable'}));
            return true;
        }
        return isInvalid;
    }

    saveBlockUnits(){
        this.isLoading = true;
        
        if(this.validateBlockForm()){
            this.isLoading = false;
            return;
        }

        saveBlockedUnits({selectedUnits : this.selectedUnitIds, opportunityId : this.recordId, commentValue : this.commentValue, blockingHours : this.selectedBlockingHours})
        .then(data =>{
            let message = '';
            let type = 'Success';
            
            if(data == 'Success'){
                this.showBlockRequestModal = false;
                message = 'Block on the selected units are submitted for approval.';
            }else{
                message = data;
                type = 'error';
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success', 
                    message: message, 
                    variant: type, 
                    mode: 'dismissable'
                })
            );
            this.isLoading = false;
        })
        .catch(error =>{
            this.isLoading = false;
        })
    }

    validateForm(){
        
        let isInvalid = false;
        let inputFields = this.template.querySelectorAll('.confirmationCheckbox');
        inputFields.forEach(inputField => {

            if(!inputField.checkValidity()){
                inputField.reportValidity();
                isInvalid = true;
            }
        });

        
        if(isInvalid){
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: 'Please review all the errors', variant: 'error', mode: 'dismissable'}));
            return true;
        }
        return isInvalid;
    }
    generateSalesOrder(){
       
        this.isLoading = true;
        if(this.validateForm()){
            this.isLoading = false;
            return;
        }
        

        checkUnitStatus({selectedUnits : this.selectedUnitIds})
        .then(data => {
            if(data == 'Success'){
                //this.pageNumber = this.pageNumber+1;
                //this.isLoading=false;
            }else{
                const evt = new ShowToastEvent({
                    title: 'Error!',
                    message: data,
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                this.isLoading = false;
                return;
            }
        })
        .catch(error => {
            this.isLoading=false;
        });

        let salesOrderLst = [];
        for(let i = 0; i < this.selectedUnitList.length; i++){

            let priceValue = 0;
            if(this.selectedUnitList[i].unitOptionPrice == 0 || this.selectedUnitList[i].unitOptionPrice === undefined){
                priceValue = this.selectedUnitList[i].price;
            }else{
                priceValue = this.selectedUnitList[i].unitOptionPrice;
            }
            let salesOrderObj = new salesOrder(this.selectedUnitList[i].paymentDetails.selectedPayment,null,this.selectedUnitList[i].unitId,null, priceValue);

            if(this.selectedUnitList[i].unitOptionDetails !== undefined && this.selectedUnitList[i].unitOptionDetails.selectedUnitOption != null && this.selectedUnitList[i].unitOptionDetails.selectedUnitOption != ''){
                salesOrderObj.UnitOption__c = this.selectedUnitList[i].unitOptionDetails.selectedUnitOption;    
            }
            if(this.selectedUnitList[i].allUnitOptions !== undefined && this.selectedUnitList[i].allUnitOptions.length > 0){
                for(let j = 0; j < this.selectedUnitList[i].allUnitOptions.length; j++){
                    salesOrderObj[this.selectedUnitList[i].allUnitOptions[j].fieldApiName] = this.selectedUnitList[i].allUnitOptions[j].selectedValue;
                }
            }
            salesOrderLst.push(salesOrderObj);
        }
        debugger;

        /***** Offer Lines Info **/
        this.offerDetailsLst = [];
        const offerDetails = this.template.querySelectorAll('c-offers-line-details-l-w-c');
       // alert(':offerDetails:'+offerDetails.length);
        if (offerDetails.length > 0) {
            offerDetails.forEach(child => {
                var offerLinesData = child.getTableData(); 
                //alert('offerLinesData:'+JSON.stringify(offerLinesData));
                for(var i =0;i < offerLinesData.length;i++){
                this.offerDetailsLst.push({
                    unitId: offerLinesData[i].unitId,
                    offerLinesLst: offerLinesData[i].offerLinesList
                });
            }   
             });
           //alert( this.offerDetailsLst.length);
          //alert(JSON.stringify(this.offerDetailsLst));
        }
        /****************** Offer Lines */
        
        saveSalesOrder({salesOrderList : salesOrderLst, oppId : this.recordId,offerLinesListStr:JSON.stringify(this.offerDetailsLst) })
        .then(data => {
            if(data == 'Success'){
                debugger;
               // this.saveOffersLine();
                this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Sales order created successfully.', variant: 'success', mode: 'dismissable'}));
                window.location.reload();
            }else{
                this.dispatchEvent(new ShowToastEvent({title: 'Error', message: data, variant: 'Error', mode: 'dismissable'}));
            }
            
            this.isLoading=false;
        })
        .catch(error => {
            this.isLoading=false;
        });
        
    }

    updateConfirmation(event){
        this.confirmation = event.target.checked;
        this.isLoading = false;
    }

    handlePaymentUnitSelect(event){

        this.isLoading=true;

        this.currentUnit = event.target.value;
        
        if(!this.selectedUnits[this.currentUnit].paymentDetails ){

            this.paymentInstallments = [];
            this.paymentTypeName = '';
            this.generateOffer();
            this.isLoading = false;
        }else{
            
            let paymentData = this.selectedUnits[this.currentUnit].paymentDetails;
            for(let i = 0 ; i < paymentData.paymentLst.length ; i ++){
                if(paymentData.paymentLst[i].paymentObj.Id == paymentData.selectedPayment){
                    this.paymentInstallments = paymentData.paymentLst[i].paymentObj.Payment_Installments__r;
                    this.calculatePaymentAmount();
                    this.paymentTypeName = paymentData.paymentLst[i].paymentObj.Name;
                    break;
                }
            }
            this.isLoading = false;
        }
    }

    handleUnitOptionSelection(event){
        let index = event.target.dataset.index;
        this.selectedUnits[this.currentUnit].allUnitOptions[index].selectedValue = event.target.value;
    }

    generateOffer(){
        generateSalesOffer({selectedUnitId : this.currentUnit})
        .then(data => {
            if(data != null){
                if(data.unitPaymentDetailObj.paymentLst !== undefined){
                    let paymentDetailWrapper = data.unitPaymentDetailObj;
                    this.selectedUnits[this.currentUnit].paymentDetails=paymentDetailWrapper; 
            

                    for(let i = 0 ; i < paymentDetailWrapper.paymentLst.length ; i ++){
                        if(paymentDetailWrapper.paymentLst[i].paymentObj.Id == paymentDetailWrapper.selectedPayment){
                            this.paymentPlanId = paymentDetailWrapper.paymentLst[i].paymentObj.Id;
                            this.paymentInstallments = paymentDetailWrapper.paymentLst[i].paymentObj.Payment_Installments__r;
                            this.calculatePaymentAmount();
                            this.paymentTypeName = paymentDetailWrapper.paymentLst[i].paymentObj.Name;
                            break;
                        }
                    }
                }

                if(data.unitOptiontDetailObj.unitOptionLst !== undefined){
                    let unitOptionWrapper = data.unitOptiontDetailObj;
                    this.selectedUnits[this.currentUnit].unitOptionDetails = unitOptionWrapper;
                }

                if(data.unitOptionsList.length > 0){
                    this.selectedUnits[this.currentUnit].allUnitOptions = data.unitOptionsList;
                }
            }
            
            this.isLoading=false;
        })
        .catch(error => {
            this.isLoading=false;
        });
    }

    calculatePaymentAmount(){
        let paidAmount = this.paidAmount
        if(this.selectedUnits[this.currentUnit].unitOptionPrice == 0 || this.selectedUnits[this.currentUnit].unitOptionPrice === undefined){
            
            this.paymentInstallments = this.paymentInstallments.map(row => ({
                ...row,
                amount: (row.Milestone__c/100)* this.selectedUnits[this.currentUnit].price
                }));
        }else{
            this.paymentInstallments = this.paymentInstallments.map(row => ({
            ...row,
            amount: (row.Milestone__c/100)* this.selectedUnits[this.currentUnit].unitOptionPrice
            }));
        }
        if(this.isOfferSelected) {
            this.paymentInstallments.forEach(row => {
                if(row.amount && row.amount > paidAmount){
                    row.amount = row.amount - paidAmount;
                    paidAmount = 0;
                } else if(row.amount < paidAmount) {
                    row.amount = 0;
                    paidAmount = paidAmount - row.amount;
                }
            });
        }
        
    }

    calculateInstallmentAmount(mileStone, unitPrice){
        let amount = (mileStone/100)* unitPrice;
        if(amount  && amount > this.paidAmount){
            amount = amount - this.paidAmount;
        } else if(amount < this.paidAmount) {
            amount = 0;
            this.paidAmount = this.paidAmount - amount;
        }
        return amount;
    }

    selectUnitOption(event){
        this.isLoading = true;
        let pd = JSON.parse(JSON.stringify(this.selectedUnits[this.currentUnit]));
        debugger;
        if(event.detail.value != ''){
            this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption = event.detail.value;


            for(let i = 0; i < this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst.length; i++){
                if(this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.Id == event.detail.value){
                    this.unitOptionPrice = this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.TotalPrice__c;
                    this.selectedUnits[this.currentUnit].unitOptionPrice = this.unitOptionPrice;
                    this.selectedUnits[this.currentUnit].selectedUnitOptionName = this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.Name;
                    this.selectedUnits[this.currentUnit].selectedUnitOptionId = this.selectedUnits[this.currentUnit].unitOptionDetails.unitOptionLst[i].unitOptionObj.Id;
                }   
            }    
        }else{
            this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption = '';
            this.unitOptionPrice = 0;
            this.selectedUnits[this.currentUnit].unitOptionPrice = 0;
        }
        this.calculatePaymentAmount();

        this.isLoading = false;
    }

    selectPaymentPlan(event){
        this.isLoading = true;
        let pd = JSON.parse(JSON.stringify(this.selectedUnits[this.currentUnit]));
        debugger;
        for(let i = 0 ; i < pd.paymentDetails.paymentLst.length ; i ++){
            if(pd.paymentDetails.paymentLst[i].paymentObj.Id == event.detail.value){
                this.paymentPlanId = event.detail.value;
                this.paymentInstallments = pd.paymentDetails.paymentLst[i].paymentObj.Payment_Installments__r;
                this.calculatePaymentAmount();
                this.paymentTypeName = pd.paymentDetails.paymentLst[i].paymentObj.Name;
                break;
            }
        }
        
        this.selectedUnits[this.currentUnit].paymentDetails.selectedPayment = event.detail.value;
        this.isLoading = false;
    }

    handleBuildingChange(event){
        this.unitLst=undefined;
        this.isLoading=true;
        this.selectedBuilding=event.detail.value;
        if(this.isSwapOrUpgrade){
            this.populateUnitDataForSR();
        } else {
            this.populateUnitData();
        }
    }

    handleProjectChange(event){
        this.unitLst=undefined;
        this.isLoading=true;
        this.selectedProject=event.detail.value;
        this.populateBuildings();
    }

    handleUnitChange(event){
    }

    async handleMenuAction(event){
        this.showOfferDetails = false;
        if(event.target.name=='OFFER'){
           // if(this.availableEOI < this.totalSelectedUnits && this.availableEOI != 0){
           //     const evt = new ShowToastEvent({
           //         title: 'Error!',
           //         message: 'Number of units selected are more than EOI available for this opportunity.',
           //         variant: 'error',
           //     });
          //      this.dispatchEvent(evt);
          //      return;
          //  }
            this.selectedAction=event.target.name;
            this.steps=[]
            this.steps.push({ label: 'Unit Selection', value: 1 });
            this.steps.push({ label: 'Payment Selection', value: 2 });
           // this.steps.push({ label: 'Offer generation', value: 3 });
            this.pageNumber = this.pageNumber+1; 
        }else if(event.target.name=='BACK'){
            // if(this.lastPageName == 'Booking selected'){
                // this.unitRollbackConfirmation = true;
                
                // return;
                // unblockSelectedUnits({selectedUnits : this.selectedUnitIds})
                // .then(data => {
                //     this.isLoading=false;
                //     this.lastPageName = 'Booking';
                // })
                // .catch(error => {
                //     this.isLoading=false;
                // });
                // this.isLoading = false;
            // }
            //this.lastPageName = 'Booking';
            this.pageNumber = this.pageNumber-1;
            this.unitLst = (this.unitInventoryDetails || []).map(unit => {
                return {
                  ...unit,
                  isSelected : (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false)
                }
            });
        }else if(event.target.name == 'FORWARD'){
            //this.selectedAction = 'Booking';
            this.isLoading=true;
            for(var key in this.selectedUnits){
                if(this.selectedUnits[key].paymentDetails === undefined && this.selectedUnits[key].selectionStatus) {
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: 'Payment plan is not selected for ' + this.selectedUnits[key].unitName + ' unit.',
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                    this.isLoading=false;
                    return;
                }

                if(this.selectedUnits[key].unitOptionDetails !== undefined && this.selectedUnits[key].unitOptionDetails.selectedUnitOption == '' && this.selectedUnits[key].selectionStatus) {
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: 'Unit option is not selected for ' + this.selectedUnits[key].unitName + ' unit.',
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                    this.isLoading=false;
                    return;
                }
            }
            let isInvalid = false;
            let inputFields = this.template.querySelectorAll('.picklistUnitOption');
            inputFields.forEach(inputField => {

                if(!inputField.checkValidity()){
                    inputField.reportValidity();
                    isInvalid = true;
                }
            });

            
            if(isInvalid){
                this.dispatchEvent(new ShowToastEvent({title: 'Error', message: 'Please review all the errors', variant: 'error', mode: 'dismissable'}));
                this.isLoading=false;
                return;
            }

            if(this.isBookingSelected){
                checkUnitStatus({selectedUnits : this.selectedUnitIds})
                .then(data => {
                    if(data == 'Success'){
                        this.pageNumber = this.pageNumber+1;
                        this.isLoading=false;
                        this.showOfferDetails = true;
                        
                    }else{
                        const evt = new ShowToastEvent({
                            title: 'Error!',
                            message: data,
                            variant: 'error',
                            mode: 'dismissable'
                        });
                        this.dispatchEvent(evt);
                        this.isLoading = false;
                        return;
                    }
                })
                .catch(error => {
                    this.isLoading=false;
                });
            }else if(this.isOfferSelected){
                this.pageNumber = this.pageNumber+1;
                this.isLoading=false;
            }

            

            // if(this.lastPageName == 'Booking'){
            //     updateUnitsAsBlocked({selectedUnits : this.selectedUnitIds, oppId : this.recordId})
            //         .then(data => {
            //             if(data == 'Success'){
            //             this.isLoading=false;
            //             this.lastPageName = 'Booking selected';
            //         }else{
            //             const evt = new ShowToastEvent({
            //                 title: 'Error!',
            //                 message: data,
            //                 variant: 'error',
            //                 mode: 'dismissable'
            //             });
            //             this.dispatchEvent(evt);
            //         }
                    
            //     })
            //     .catch(error => {
            //         this.isLoading=false;
            //     });
            // }
            
            
        }else if(event.target.name =='BOOKING'){
            if(this.availableEOI < this.totalSelectedUnits && this.availableEOI != 0){
                const evt = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Number of units selected are more than EOI available for this opportunity.',
                    variant: 'error',
                });
                this.dispatchEvent(evt);
                return;
            }else{
               
            }

            checkUnitStatus({selectedUnits : this.selectedUnitIds})
            .then(data => {
                if(data == 'Success'){
                   
                }else{
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: data,
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(evt);
                    this.isLoading = false;
                    return;
                }
            })
            .catch(error => {
                this.isLoading=false;
            });
            
            this.lastPageName = 'Booking';
            this.selectedAction=event.target.name;
            this.steps=[];
            this.steps.push({ label: 'Unit Selection', value: 1 });
            this.steps.push({ label: 'Payment Selection', value: 2 });
            this.steps.push({ label: 'Book Unit(s)', value: 3 });
            this.pageNumber = this.pageNumber+1;
            
            this.isLoading = false;
            debugger;
        }else if(event.target.name == 'BLOCKREQUEST'){
            this.showBlockRequestModal = true;
        } else if(event.target.name == 'SAVEUNITS'){ 
            this.isLoading = true;
            updateServiceRequest({unitId : this.selectedUnitIds[0], paymentPlanId : this.paymentPlanId, srId: this.recordId})
            .then(data => {
                if(data == 'Success'){
                    this.isLoading=false;                  
                    this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Units are blocked successfully.', variant: 'success', mode: 'dismissable'}));
                    this.showBlockRequestModal = false;
                }else{
                    const evt = new ShowToastEvent({
                        title: 'Error!',
                        message: data,
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(evt);
                    this.isLoading = false;
                    return;
                }
            })
            .catch(error => {
                this.isLoading=false;
            });                             
          window.location.reload();
        }

    }

    rollbackSelectedUnits(){
        this.isLoading = true;
        unblockSelectedUnits({selectedUnits : this.selectedUnitIds})
        .then(data => {
            this.unitRollbackConfirmation = false;
            this.isLoading=false;
            this.lastPageName = 'Booking';
        })
        .catch(error => {
            this.isLoading=false;
        });
        this.pageNumber = this.pageNumber-1;
        this.unitLst = (this.unitInventoryDetails || []).map(unit => {
            return {
                ...unit,
                isSelected : (this.selectedUnits[unit.Id] != undefined ? this.selectedUnits[unit.Id].selectionStatus : false)
            }
        });
        //this.isLoading = false;
    }

    closeConfirmationModal(){
        this.unitRollbackConfirmation = false;
    }

    hideModalBox(){
        this.showBlockRequestModal = false;
    }

    async handlePDFActive(event){
        var currentUnit='';
        currentUnit = event.target.dataset.unitId;
        var selectedPayment = this.selectedUnits[currentUnit].paymentDetails.selectedPayment;
        var selectedUnitOption = '';
        if(this.selectedUnits[this.currentUnit].unitOptionDetails !== undefined){
            selectedUnitOption = this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption;
        }
        if(event.target.dataset.targetType == 'input'){
            this.customerName = event.target.value;
        }
        debugger;
        var mainUrl = 'https://modonproperties--uat--c.sandbox.vf.force.com';
        this.fullUrl = mainUrl + '/apex/OfferDetailsPDF?id=' + this.recordId + '&currentUnit='+currentUnit+'&selectedPayment='+selectedPayment+'&customerName='+this.customerName+'&unitOption='+selectedUnitOption;
    }

    sendSalesOfferEmail(event){
        debugger;
        this.isLoading=true;
        var unitId = event.target.dataset.unitId;
        var selectedPayment = this.selectedUnits[unitId].paymentDetails.selectedPayment;
        var selectedUnitOption = '';
        if(this.selectedUnits[this.currentUnit].unitOptionDetails !== undefined){
            selectedUnitOption = this.selectedUnits[this.currentUnit].unitOptionDetails.selectedUnitOption;
        }
        var custName = this.customerName;

        sendSalesOfferPDF({
            unitId : unitId, 
            unitName : this.selectedUnits[unitId].unitName, 
            opportunityId : this.recordId, 
            customerName : custName, 
            selectedPymnt : selectedPayment, 
            unitOption: selectedUnitOption
        })
        .then(data => {

            this.isLoading=false;
            const evt = new ShowToastEvent({
                title: 'Email Confirmation',
                message: 'Email have been sent successfully.',
                variant: 'success',
            });
            this.dispatchEvent(evt);
        })
        .catch(error => {
            console.error(error);
            this.isLoading=false;
            const evt = new ShowToastEvent({
                title: 'Email Confirmation',
                message: 'Sending email failed.',
                variant: 'error',
            });
            this.dispatchEvent(evt);
            
        });
    }
    saveOffersLine(){
        
   }
};

class salesOrder {
    constructor(paymentPlan, primaryContact, unitId, customerAccount, price) {
        this.sobjectType = 'SalesOrder__c';
        this.PaymentPlan__c = paymentPlan;
        this.PrimaryContact__c = primaryContact;
        this.Unit__c = unitId;
        this.TotalAmount__c = price;
        this.CustomerAccount__c = customerAccount;
    }
}