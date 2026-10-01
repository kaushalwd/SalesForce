public with sharing class UnitSearchLwcControllerFromSR {

    @AuraEnabled
    public static Boolean checkExistingSalesOrder(String srId){
        serviceRequest__c srObj = [SELECT Id, Name, Status__c, SalesOrder__c, RecordType.DeveloperName FROM ServiceRequest__c WHERE Id = :srId 
                                    AND RecordType.DeveloperName IN ('Service_Request_Management_Unit_Upgrade', 'Service_Request_Management_Unit_Transfer') 
                                    AND Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided') WITH SECURITY_ENFORCED]; 
            if(srObj.SalesOrder__c != null){
                return true;
            }            
        return false;
    }


    @AuraEnabled
    public static String updateServiceRequest(String unitId, String paymentPlanId, string srId){
        ServiceRequest__c srObj = new ServiceRequest__c();
        srObj.Id = srId;
        if(String.isNotBlank(unitId)){
            srObj.Selected_Unit__c = unitId;
        }
        if(String.isNotBlank(paymentPlanId)){
            srObj.Selected_Payment_Plan__c = paymentPlanId;
        }
        try{
            update srObj;
        }catch(Exception ex){
            system.debug(ex.getMessage());
            return ex.getMessage();
        }
        return 'Success';
    }

    //method to get unit details
    @AuraEnabled
    public static list<map<String,string>> populateProjectsforSR(Id projectId){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        for(Project__c tempProject: [SELECT Id,Name FROM Project__c  WHERE Id != :projectId WITH SECURITY_ENFORCED ORDER BY Name] ){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',tempProject.Name);
            tempMap.put('value',tempProject.id);
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    } 
    
    // Unitsupgrade method to get sales order from service request
     @AuraEnabled (cacheable=true)
    public static ServiceRequest__c getSalesOrderfromServiceReqeust(String srId){
        ServiceRequest__c thisRequest;
        if(srId <> null || String.isNotBlank(srId)) {
            thisRequest = [SELECT Id, Name, Status__c, RecordType.DeveloperName, SalesOrder__c, SalesOrder__r.Unit__r.Phase__c,  SalesOrder__r.Unit__r.Phase__r.Project__c, SalesOrder__r.ProjectName__c,
                            SalesOrder__r.Phase_Name__c, SalesOrder__r.TotalAmount__c, SalesOrder__r.Totalpaidamount__c  FROM ServiceRequest__c WHERE Id = :srId 
                                    AND RecordType.DeveloperName IN ('Service_Request_Management_Unit_Upgrade', 'SRM_Unit_Swap') 
                                    AND Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided') WITH SECURITY_ENFORCED]; 
            
        }
        system.debug(thisRequest.SalesOrder__r.TotalAmount__c);
        return thisRequest;
    }
    
    //method to get projects
    @AuraEnabled
    public static list<map<String,string>> getAllProjects(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        for(Project__c tempProject: [SELECT Id,Name from Project__c WITH SECURITY_ENFORCED ORDER BY Name ] ){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',tempProject.Name);
            tempMap.put('value',tempProject.id);
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    }


    //method to send sales offer to customer
    @AuraEnabled
    public static void sendSalesOfferPDF(String unitId, String unitName, String opportunityId, String customerName, String selectedPymnt, String unitOption){
        system.debug('unitId==>' + unitId);
        system.debug('unitName==>' + unitName);
        system.debug('customerName==>' + customerName);
        system.debug('selectedPymnt==>' + selectedPymnt);
        
        PageReference pdf = Page.OfferDetailsPDF;
        pdf.getParameters().put('id',opportunityId);
        pdf.getParameters().put('currentUnit',unitId);
        pdf.getParameters().put('selectedPayment',selectedPymnt);
        pdf.getParameters().put('unitOption',unitOption);
        pdf.getParameters().put('customerName',(customerName!=null?customerName:''));

        pdf.setRedirect(true);
        
        List<Messaging.EmailFileAttachment> fileAttachments = new List<Messaging.EmailFileAttachment>();
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Offer-'+unitName+'-'+customerName+'-'+System.today().format()+'.pdf');
        efa.setBody(Test.isRunningTest()? blob.valueOf('Methods defined as TestMethod do not support getContent call') :pdf.getContent());
        fileAttachments.add(efa);
        string emailTemplateId = '';
        string emailTemplateLeadId = '';
        String accountEmail = '';
        string OrgWideEmailAddressID = '';
        string whatId = '';
        string targetObjectId = '';

        List<string> toRecipients = new List<String>();
        for(OrgWideEmailAddress tempRec: [select id,Address from OrgWideEmailAddress limit 1]){
            OrgWideEmailAddressID=tempRec.Id;
        }

        for(Emailtemplate tempRec:  [select id, DeveloperName from emailtemplate where DeveloperName = 'SalesOffer' limit 1]){
            emailTemplateId=tempRec.Id;
        }

        if(opportunityId!=null ){
            
            List<opportunity> opportunityRecords=[select id,AccountId,Account.PersonContactId, PrimaryContact__c, StageName from opportunity where id =:opportunityId limit 1];
            if(!opportunityRecords.isEmpty()){
                //accountEmail = opportunityRecords[0].Account.PersonEmail;
                //toRecipients.add(accountEmail);
                targetObjectId = (String.isNotBlank(opportunityRecords[0].Account.PersonContactId) ? opportunityRecords[0].Account.PersonContactId : ((String.isNotBlank(opportunityRecords[0].PrimaryContact__c) ? opportunityRecords[0].PrimaryContact__c : null)));
                whatId = opportunityRecords[0].Id;
            }
        }
        // toRecipients.add('prateekbansal32@gmail.com');
        // toRecipients.add('prateek.b.bansal@pwc.com');
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();             
        mail.setSaveAsActivity(true);
        mail.setBccSender(false);
        mail.setUseSignature(false);
        if(targetObjectId != null && targetObjectId != ''){
            mail.setTargetObjectId(targetObjectId);
        }
        if(whatId!=null && whatId!=''){
            mail.setWhatId(whatId);
        }
        if(emailTemplateId!=null && emailTemplateId!=''){
            mail.setTemplateID(emailTemplateId);
        }
        if(toRecipients!=null && !toRecipients.isEmpty() ){
            mail.setToAddresses(toRecipients);
        }
        if(OrgWideEmailAddressID != null && OrgWideEmailAddressID!=''){
            mail.setOrgWideEmailAddressId(OrgWideEmailAddressID);
        }
        // Specify FileAttachments
        if(fileAttachments != null && !fileAttachments.isEmpty()) {
            mail.setFileAttachments(fileAttachments);
        }
        system.debug('mail==>'+ mail);
        if(!Test.isRunningTest())
        Messaging.sendEmail(new list<Messaging.SingleEmailMessage>{mail});
    }
    
    //method to generate sales offer
    @AuraEnabled
    public static UnitDetailsWrapper generateSalesOffer(String selectedUnitId){

        UnitDetailsWrapper udObj = new UnitDetailsWrapper();
        List<PaymentDetails> paymentLst = new List<PaymentDetails>();
        List<UnitOptionDetails> uoLst = new List<UnitOptionDetails>();
        if(selectedUnitId != null && String.isNotBlank(selectedUnitId)){
            String phaseId = '';
            String projectId = '';
            String phaseOptions = '';
            for(Unit__c unitObj : [SELECT Id, Phase__c, Phase__r.Project__c, Phase__r.PhaseOptions__c FROM Unit__c WHERE Id = : selectedUnitId]){
                if(String.isNotBlank(unitObj.Phase__c)){
                    phaseId = unitObj.Phase__c;
                    if(String.isNotBlank(unitObj.Phase__r.Project__c)){
                        projectId = unitObj.Phase__r.Project__c;
                    }
                    if(String.isNotBlank(unitObj.Phase__r.PhaseOptions__c)){
                        List<UnitPicklistOptions> picklistOptionWrapperLst = (List<UnitPicklistOptions>) JSON.deserialize(unitObj.Phase__r.PhaseOptions__c, List<UnitPicklistOptions>.class);
                        List<UnitOptionWrapper> unitOptionWrapperList = new List<UnitOptionWrapper>();
                        system.debug('picklistOptionWrapperLst==>' + picklistOptionWrapperLst);
                        for(UnitPicklistOptions picklistOptionObj : picklistOptionWrapperLst){
                            UnitOptionWrapper wrapperObj = new UnitOptionWrapper();
                            List<Map<String,String>> unitPicklistOptions = new List<Map<String,String>>();
                            unitPicklistOptions.add(new map<string,string>{'label' => '--None--' , 'value' => ''});
                            wrapperObj.fieldLabel = picklistOptionObj.picklistLable;
                            wrapperObj.fieldApiName = picklistOptionObj.picklistApiName;
                            wrapperObj.selectedValue = '';
                            for(String optionValue : picklistOptionObj.picklistOptions){
                                unitPicklistOptions.add(new map<string,string>{'label' => optionValue , 'value' => optionValue});
                            }
                            wrapperObj.unitOptions = unitPicklistOptions;
                            unitOptionWrapperList.add(wrapperObj);
                        }
                        udObj.unitOptionsList = unitOptionWrapperList;
                        system.debug('unitOptionWrapperList==>' + unitOptionWrapperList);
                    }
                }
                
            }
            
            String paymentQuery = 'SELECT Id, Name, IsActive__c, ' +
            '(SELECT Id, Name, BrokerPayout__c, IsHandoverPayment__c, Milestone__c, ' +
            'MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, ' +
            'SalesAgentPayout__c, MilestoneInstallment__c, ' +
            'MilestoneInstallment__r.Milestone_Due_Date__c, Milestone_Due__c ' +
            'FROM Payment_Installments__r ORDER BY MilestoneNumber__c) ' +
            'FROM PaymentPlan__c WHERE Unit__c = :selectedUnitId';

            if (String.isNotBlank(phaseId)) {
                paymentQuery += ' OR Phase__c = :phaseId';
            }

            if (String.isNotBlank(projectId)) {
                paymentQuery += ' OR Project__c = :projectId';
            }

            String unitOptionQuery =
                'SELECT Id, Name, Phase__c, Unit__c, TotalPrice__c ' +
                'FROM Unit_Option__c WHERE Unit__c = :selectedUnitId';

            if (String.isNotBlank(phaseId)) {
                unitOptionQuery += ' OR Phase__c = :phaseId';
            }

            Map<String, Object> bindVariables = new Map<String, Object>{
                'selectedUnitId' => selectedUnitId,
                'phaseId'        => phaseId,
                'projectId'     => projectId
            };

            List<PaymentPlan__c> tempPaymentPlanLst =
                (List<PaymentPlan__c>)Database.queryWithBinds(
                    paymentQuery,
                    bindVariables,
                    AccessLevel.SYSTEM_MODE
                );

            List<PaymentPlan__c> paymentPlanLst = new List<PaymentPlan__c>();

            for (PaymentPlan__c paymentPlanObj : tempPaymentPlanLst) {
                if (paymentPlanObj.IsActive__c) {
                    paymentPlanLst.add(paymentPlanObj);
                }
            }

            System.debug('paymentPlanLst====>>' + paymentPlanLst);

            List<Unit_Option__c> unitOptionLst =
                (List<Unit_Option__c>)Database.queryWithBinds(
                    unitOptionQuery,
                    bindVariables,
                    AccessLevel.SYSTEM_MODE
                );

            //unit options
            List<Map<String,String>> availableUnitOptions = new List<Map<String,String>>();
            Map<String, Unit_Option__c> unitOptionMap = new Map<String, Unit_Option__c>();
            for(Unit_Option__c uoObj : unitOptionLst){
                if(String.isNotBlank(uoObj.Phase__c)){
                    unitOptionMap.put(uoObj.Name, uoObj);
                }
            }
            for(Unit_Option__c uoObj : unitOptionLst){
                if(String.isNotBlank(uoObj.Unit__c)){
                    unitOptionMap.put(uoObj.Name, uoObj);
                }
            }
            availableUnitOptions.add(new map<string,string>{'label' => '--None--' , 'value' => ''});
            for(Unit_Option__c uoObj : unitOptionLst){
                UnitOptionDetails uoDetail = new UnitOptionDetails();
                uoDetail.unitOptionObj = unitOptionMap.get(uoObj.Name);
                uoLst.add(uoDetail);
                availableUnitOptions.add(new map<string,string>{'label' => unitOptionMap.get(uoObj.Name).Name , 'value' => unitOptionMap.get(uoObj.Name).Id});
            }
            UnitsUnitOptionDetails unitOptionDetailWrapper = new UnitsUnitOptionDetails();
            if(!uoLst.isEmpty()){
                unitOptionDetailWrapper.unitOptionLst = uoLst;
                unitOptionDetailWrapper.availableUnitOptions = availableUnitOptions;
                unitOptionDetailWrapper.selectedUnitOption = '';
            }
            system.debug('availableUnitOptions==>' + availableUnitOptions);
            system.debug('uoLst==>' + uoLst);
            system.debug('unitOptionDetailWrapper==>' + unitOptionDetailWrapper);
            udObj.unitOptiontDetailObj = unitOptionDetailWrapper;

            //payment plan
            List<Map<String,String>> availablePaymentPlan = new List<Map<String,String>>();
            for(PaymentPlan__c paymentPlanObj : paymentPlanLst){
                PaymentDetails paymentObj = new PaymentDetails();
                paymentObj.paymentObj = paymentPlanObj;
                paymentObj.paymentInstallment = paymentPlanObj.Payment_Installments__r;
                paymentLst.add(paymentObj);
                availablePaymentPlan.add(new map<string,string>{'label' => paymentPlanObj.Name , 'value' => paymentPlanObj.Id});
            }
            UnitPaymentDetails paymentDetailsWrapper = new UnitPaymentDetails();
            if(!paymentLst.isEmpty()){
                paymentLst[0].isSelected = true;
                paymentDetailsWrapper.paymentLst = paymentLst;
                paymentDetailsWrapper.availablePaymentPlans = availablePaymentPlan;
                paymentDetailsWrapper.selectedPayment = availablePaymentPlan[0].get('value');
                system.debug('paymentLst==>'+ paymentLst);
                system.debug('paymentDetailsWrapper==>'+ paymentDetailsWrapper);
            }
            udObj.unitPaymentDetailObj = paymentDetailsWrapper;
        }
        return udObj;
    }

    //method to get building details
    @AuraEnabled
    public static list<map<String,string>> getAllBuildings(string projectId){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        for(Phase__c  tempBuilding: [Select Id,Name from Phase__c where Project__c   =: projectId WITH SECURITY_ENFORCED order by Name] ){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',tempBuilding.Name);
            tempMap.put('value',tempBuilding.id);
            filtersToReturn.add(tempMap);
        }
        system.debug('filtersToReturn::'+filtersToReturn);
        return filtersToReturn;
    }

    @AuraEnabled
    public static string saveBlockedUnits(List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours){
        List<Block_Request__c> blockRequestLst = new List<Block_Request__c>();

        List<Block_Request__c> exstingblockRequestLst = [SELECT Id, Name FROM Block_Request__c WHERE Unit__c IN : selectedUnits AND Status__c = 'In Progress'];
        
        if(!exstingblockRequestLst.isEmpty()){
            return 'Block request : ' + exstingblockRequestLst[0].Name + ' is already in progress.';
        }

        
        List<Unit__c> unitLst = [SELECT Id, Name FROM Unit__c WHERE Id IN : selectedUnits AND Status__c = 'Reserved'];
        if(!unitLst.isEmpty()){
            return 'Unit : ' + unitLst[0].Name + ' is already blocked.';
        }

        for(String unitId : selectedUnits){
            Block_Request__c brObj = new Block_Request__c();
            brObj.Unit__c = unitId;
            brObj.Comment__c = commentValue;
            brObj.Opportunity__c = opportunityId;
            brObj.Hourstoblock__c = blockingHours;
            blockRequestLst.add(brObj);
        }
        try{
            INSERT blockRequestLst;
        }catch(Exception ex){
            system.debug(ex.getMessage());
            return ex.getMessage();
        }
        return 'Success';
    }

    @AuraEnabled
    public static list<map<String,string>> getBlockingHours(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries('Block_Request__c','Hourstoblock__c');

        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',ple.getLabel());
            tempMap.put('value',ple.getValue());
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    } 

    static List<Schema.PickListEntry> getPickListEntries(String objectName, String fieldName){
        //String objectName = 'Contact';
        //String fieldName ='LeadSource';
        
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        return ple;
    }

    @AuraEnabled
    public static Integer getEOIDetails(String oppId){
        List<ExpressionofInterest__c> eoiLst = new List<ExpressionofInterest__c>();
        eoiLst = [SELECT Id FROM ExpressionofInterest__c WHERE Opportunity__c = :oppId];

        return eoiLst.size();
    }

    //method to create sales order
    @AuraEnabled
    public static String saveSalesOrder(List<SalesOrder__c> salesOrderList, String oppId,String offerLinesListStr){
        String successMessage = 'Success';
        //todo==>
        //sales order should not be available
        //check if blocked with same opportunity and blocked for same user
        //unit is available change the status to block or if block
        //create sales order
		system.debug('opportunit'+ oppId);
        List<SalesOrder__c> soLst = [SELECT Id FROM SalesOrder__c WHERE Opportunity__c = :oppId AND Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided')];
        
        if(!soLst.isEmpty()){
            return 'Sales order already in progress for this opportunity.';
        }

        set<String> unitIds = new set<String>();
        for(SalesOrder__c soObj : salesOrderList){
            unitIds.add(soObj.Unit__c);
        }
        system.debug('unitIds==>' + salesOrderList);
        system.debug('unitIds==>' + unitIds);
        Map<String, String> escrowPhaseMap = new Map<String, String>();
        List<Unit__c> unitList = [SELECT Id, Name, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c/*, Phase__r.EscrowAccount__r.AvailableVirtualAccounts__c*/ FROM Unit__c WHERE Id IN : unitIds];
        
        Map<String, String> unitEscrowMap = new Map<String, String>();
        Map<String, String> escrowVirtualMap = new Map<String, String>();
        Map<String, String> unitVirtualAccountMap = new Map<String, String>();
        Map<String, set<String>> escrowVirtualAccountMap = new Map<String, set<String>>();
        Map<String, Unit__c> unitMap = new Map<String, Unit__c>();
        set<Id> virtualIdsWithoutUnit = new set<Id>();

        for(Unit__c unitObj : unitList){
            if(String.isBlank(unitObj.Phase__r.EscrowAccount__c)){
                return 'No escrow account is available for phase: ' + unitObj.Phase__r.Name;
            }
            unitMap.put(unitObj.Id, unitObj);
            escrowPhaseMap.put(unitObj.Phase__r.EscrowAccount__c, unitObj.Phase__c);
        }
        system.debug('unitIds==>' + unitIds);
        //system.debug('==>' + [SELECT Id, Unit__c, Unit__r.Phase__c, Unit__r.Phase__r.EscrowAccount__c FROM VirtualAccount__c WHERE Status__c = 'Available' AND EscrowAccount__c IN : escrowPhaseMap.keySet() AND (Unit__c IN :unitIds OR Unit__c = null) ORDER BY Unit__c NULLS LAST]);
        for(VirtualAccount__c vaObj : [SELECT Id, EscrowAccount__c, Unit__c, Unit__r.Phase__c, Unit__r.Phase__r.EscrowAccount__c FROM VirtualAccount__c WHERE Status__c = 'Available' AND EscrowAccount__c IN : escrowPhaseMap.keySet() AND (Unit__c IN :unitIds OR Unit__c = null) FOR UPDATE]){
           
            system.debug('cal==>' + escrowPhaseMap.containsKey(vaObj.EscrowAccount__c) + '=>' + vaObj.EscrowAccount__c);
            if(String.isNotBlank(vaObj.Unit__c)){
                unitVirtualAccountMap.put(vaObj.Unit__c, vaObj.Id);
            }else if(escrowPhaseMap.containsKey(vaObj.EscrowAccount__c)){
                set<String> tempSet = escrowVirtualAccountMap.get(vaObj.EscrowAccount__c);
                if(tempSet == null){
                    tempSet = new set<String>();
                }
                tempSet.add(vaObj.Id);
                escrowVirtualAccountMap.put(vaObj.EscrowAccount__c, tempSet);
            }
        }
        List<Unit__c> updateUnitLst = new List<Unit__c>();
        system.debug('unitVirtualAccountMap==>' + unitVirtualAccountMap);
        system.debug('escrowVirtualAccountMap==>' + escrowVirtualAccountMap);
        if(!unitList.isEmpty()){
            for(Unit__c unitObj : unitList){
                if(unitObj.Sub_Status__c == 'Assigned' && unitObj.BlockedFor__c != null && (unitObj.BlockedFor__c != UserInfo.getUserId() || (unitObj.Opportunity__c != oppId && unitObj.Opportunity__c != null))){
                    return 'Unit is not available for booking.';
                }
                //todo: virtual account must be available for all units.
                if(!unitVirtualAccountMap.containsKey(unitObj.Id) && !escrowVirtualAccountMap.containsKey(unitObj.Phase__r.EscrowAccount__c)){
                    return 'Virtual account is not available for unit : ' + unitObj.Name;
                } // Add Update the Change as par of new status 
                if((unitObj.Status__c == 'Available' && (unitObj.Sub_Status__c == 'Un-Assigned' || unitObj.Sub_Status__c == 'Assigned')) || (unitObj.Sub_Status__c == 'Assigned'  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                    unitObj.Status__c = 'Reserved';
                    unitObj.Sub_Status__c = '';
                    unitObj.ApprovalStatus__c='Released';
                    unitObj.BlockedFor__c = UserInfo.getUserId();
                    unitObj.Opportunity__c = oppId;
                    unitObj.BlockUntil__c = null;
                    unitObj.Status_Change_Time__c = DATETIME.NOW();
                    unitObj.Blocked_Time__c = DATETIME.NOW();//null;
                    if(String.isBlank(unitObj.BlockedBy__c)){
                        unitObj.BlockedBy__c = UserInfo.getUserId();
                    }
                    updateUnitLst.add(unitObj);
                }
            }   
        }else{
            return 'Unit is not available for booking.';
        }

        String roleName = [SELECT Id, Name, Profile.Name, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].UserRole.Name;

        
        List<Opportunity> oppLst = [SELECT Id, Name, PrimaryContact__c, CustomerType__c, UAE_Resident_Status__c,AccountId, Account.PersonContactId FROM Opportunity WHERE Id = :oppId];
        List<VirtualAccount__c> vaLst = new List<VirtualAccount__c>();
        if(!salesOrderList.isEmpty()){
            for(SalesOrder__c salesOrderObj : salesOrderList){
                if(String.isNotBlank(oppLst[0].PrimaryContact__c)){
                    salesOrderObj.PrimaryContact__c = oppLst[0].PrimaryContact__c;
                }

                if(unitVirtualAccountMap.containsKey(salesOrderObj.Unit__c) || 
                    (escrowVirtualAccountMap.containsKey(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c) && !(escrowVirtualAccountMap.get(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c)).isEmpty())){

                    if(unitVirtualAccountMap.containsKey(salesOrderObj.Unit__c)){
                        salesOrderObj.VirtualAccount__c = unitVirtualAccountMap.get(salesOrderObj.Unit__c);
                    }else{
                        List<String> vaIds = new List<String>(escrowVirtualAccountMap.get(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c));
                        salesOrderObj.VirtualAccount__c = vaIds[0];
                        set<String> vaSet = new Set<String>(vaIds);
                        vaSet.remove(salesOrderObj.VirtualAccount__c);
                        escrowVirtualAccountMap.put(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c, vaSet);
                    }
                }else{
                    return 'Virtual account is not available for unit : ' + unitMap.get(salesOrderObj.Unit__c).Name;
                }
                vaLst.add(new VirtualAccount__c(Id = salesOrderObj.VirtualAccount__c, Status__c = 'Consumed', Unit__c = salesOrderObj.Unit__c));
                salesOrderObj.CustomerAccount__c = oppLst[0].AccountId;
                salesOrderObj.Opportunity__c = oppId;
                salesOrderObj.CustomerType__c = oppLst[0].CustomerType__c;
                salesOrderObj.UAE_Resident_Status__c =oppLst[0].UAE_Resident_Status__c;
                if(roleName != null && roleName.contains('Sales Associate')){
                    system.debug('roleName >>>>>>  '+roleName+'  >>>>>>>   ');
                    salesOrderObj.SalesAssociate__c = UserInfo.getUserId(); 
                }
            }
            Savepoint sp = Database.setSavepoint();
            try{
                
                if(!updateUnitLst.isEmpty()){
                    UPDATE updateUnitLst;
                }    
                //insert new sales order
                INSERT salesOrderList;
                UPDATE vaLst;
                createPaymentInstallments(salesOrderList);
                createOfferLineCollection(salesOrderList,oppId,offerLinesListStr);
                // oppLst[0].StageName = 'Closed Won';
                // UPDATE oppLst[0];
                
            }catch(Exception ex){
                system.debug(ex.getMessage());
                Database.rollback(sp);
                return ex.getMessage();
            }
        }
        return successMessage;
    }


    //method to create sales order installments
   public static void createPaymentInstallments(List<SalesOrder__c> salesOrderList){
        List<SalesOrderInstallments__c> salesOrderInstallmentLst = new List<SalesOrderInstallments__c>(); 
                
        Map<String, List<PaymentInstallements__c>> paymentPlanInstallmentMap = new Map<String, List<PaymentInstallements__c>>();
        Map<String, String> salesOrderPaymentPlanMap = new Map<String, String>();
        set<Id> paymentSet = new set<Id>();
        for(SalesOrder__c soObj : salesOrderList){
            salesOrderPaymentPlanMap.put(soObj.Id, soObj.PaymentPlan__c);
            paymentSet.add(soObj.PaymentPlan__c);
        }

        for(PaymentInstallements__c piObj : [SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c, Milestone__c,  
                                                MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, SalesAgentPayout__c,Milestone_Due__c,MilestoneInstallment__c 
                                                    FROM PaymentInstallements__c 
                                                    WHERE PaymentInstallment__c IN : paymentSet]){
            List<PaymentInstallements__c> tempInstallment = paymentPlanInstallmentMap.get(piObj.PaymentInstallment__c);
            if(tempInstallment == null){
                tempInstallment = new List<PaymentInstallements__c>();
            }
            tempInstallment.add(piObj);
            paymentPlanInstallmentMap.put(piObj.PaymentInstallment__c, tempInstallment);
        }

        for(SalesOrder__c soObj : salesOrderList){
            for(PaymentInstallements__c piObj : paymentPlanInstallmentMap.get(salesOrderPaymentPlanMap.get(soObj.Id))){
                SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();
                soiObj.SalesOrder__c = soObj.Id;
                soiObj.PaymentInstallments__c = piObj.Id;
                soiObj.BrokerPayout__c = piObj.BrokerPayout__c;
                soiObj.IsHandoverPayment__c = piObj.IsHandoverPayment__c ;
                soiObj.Milestone__c = piObj.Milestone__c;
                //soiObj.MilestoneDate__c = piObj.MilestoneDate__c;
                soiObj.MilestoneDate__c = piObj.Milestone_Due__c;
                if(piObj.MilestoneInstallment__c != null)soiObj.Milestone_Installment__c = piObj.MilestoneInstallment__c;
                soiObj.MilestoneDescription__c = piObj.MilestoneDescription__c;
                soiObj.MilestoneNumber__c = piObj.MilestoneNumber__c;
                soiObj.SalesAgentPayout__c = piObj.SalesAgentPayout__c;
                soiObj.InstallmentAmount__c = (soObj.TotalAmount__c) * (piObj.Milestone__c/100);
                salesOrderInstallmentLst.add(soiObj);
            }
        }
        INSERT salesOrderInstallmentLst;
    }

    @AuraEnabled
    public static String updateUnitsAsBlocked(List<String> selectedUnits, String oppId){
        system.debug('selectedUnits==>' + selectedUnits+ '....OppId.....'+ oppId);

        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Id, Name, Status__c,Blocked_Time__c, BlockedFor__c, BlockedBy__c, Opportunity__c,Sub_Status__c FROM Unit__c WHERE Id IN : selectedUnits]);
        
        List<Unit__c> unitLst = new List<Unit__c>();
        for(String unitId : selectedUnits){ //Add Update the Change as par of new status
            if((unitMap.get(unitId).Status__c == 'Available' && unitMap.get(unitId).Sub_Status__c == 'Assigned') || 
                (unitMap.get(unitId).Sub_Status__c == 'Assigned' && unitMap.get(unitId).BlockedFor__c == UserInfo.getUserId())){
                    
                    if(unitMap.get(UnitId).Status__c == 'Available' && unitMap.get(UnitId).Sub_Status__c == 'Un-Assigned'){
                        Unit__c unitObj = new Unit__c(id = unitId, 
                                                        Opportunity__c = oppId, 
                                                        BlockedFor__c = UserInfo.getUserId(), 
                                                        BlockedBy__c = UserInfo.getUserId(),
                                                        Status__c = 'Available',Sub_Status__c = 'Assigned',ApprovalStatus__c='Released',
                                                        BlockUntil__c = null, Blocked_Time__c = DATETIME.NOW());
                        unitLst.add(unitObj);
                    }
            }else if(unitMap.get(unitId).Status__c == 'Available' && unitMap.get(unitId).Sub_Status__c == 'Assigned' && unitMap.get(unitId).BlockedFor__c != UserInfo.getUserId()){
                return 'Unit ' + unitMap.get(unitId).Name + ' is already Reserved by other user.';
            }
            
            //unitLst.add(unitMap.get(unitId));
        }
        system.debug('unitLst==>' + unitLst);
        UPDATE unitLst;
        return 'Success';
    }

    @AuraEnabled
    public static String checkUnitStatus(List<String> selectedUnits){
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Id, Name, Status__c, BlockedFor__c, BlockedBy__c, 
                                                            Opportunity__c ,Sub_Status__c
                                                            FROM Unit__c 
                                                            WHERE Id IN : selectedUnits]);
        
        List<Unit__c> unitLst = new List<Unit__c>();
        for(String unitId : selectedUnits){ //Add Update the Change as par of new status
            if(unitMap.get(unitId).Status__c == 'Available' && unitMap.get(unitId).Sub_Status__c == 'Assigned' && unitMap.get(unitId).BlockedFor__c != UserInfo.getUserId()){
                return 'Unit ' + unitMap.get(unitId).Name + ' is already Reserved by other user.';
            }
        }
        return 'Success';
    }

    

    @AuraEnabled
    public static void unblockSelectedUnits(List<String> selectedUnits){
        List<Unit__c> unitLst = [SELECT Id, Status__c, BlockedFor__c, BlockedBy__c FROM Unit__c WHERE Id IN : selectedUnits];
        List<Unit__c> updateUnitLst = new List<Unit__c>();
        for(Unit__c unitObj : unitLst){
            if(unitObj.BlockedBy__c == UserInfo.getUserId() && unitObj.BlockedFor__c == UserInfo.getUserId()){ //Add Update the Change as par of new status
                unitObj.Status__c = 'Available';
                unitObj.Sub_Status__c='Un-Assigned';
                unitObj.ApprovalStatus__c='Released';
                unitObj.BlockedFor__c = null;
                unitObj.BlockedBy__c = null;
                unitObj.Opportunity__c = null;
                unitObj.BlockUntil__c = null;
                unitObj.Blocked_Time__c = null;
                updateUnitLst.add(unitObj);
            }
        }
        if(!updateUnitLst.isEmpty()){
            UPDATE updateUnitLst;    
        }
    }

    @AuraEnabled
    public static List<Unit__c> getUnitDetailsforPhase(Id buildingsId, Decimal totalAmount) { 
        List<Unit__c> unitLst = new List<Unit__c>();
        Set<String> excludeStatuses = new Set<String>{'Cancelled', 'System cancelled', 'Voided'};
        if(totalAmount != null && totalAmount > 0){
            Decimal amount = totalAmount + 100000.00;
            unitLst = [
                SELECT id, Name, Phase__c, PlotAreasqm__c, Phase__r.Name, Number_of_Bedrooms__c, Phase__r.Project__c, Phase__r.Project__r.Name, TotalPrice__c,
                       (SELECT Id, Totalpaidamount__c, TotalAmount__c FROM Sales_Orders__r WHERE Status__c NOT IN :excludeStatuses)
                FROM Unit__c 
                WHERE Phase__c = :buildingsId AND Status__c = 'Available' AND TotalPrice__c >= :amount WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
        } else {
            unitLst = [
                SELECT id, Name, Phase__c, PlotAreasqm__c, Phase__r.Name, Number_of_Bedrooms__c, Phase__r.Project__c, Phase__r.Project__r.Name, TotalPrice__c,
                       (SELECT Id, Totalpaidamount__c, TotalAmount__c FROM Sales_Orders__r WHERE Status__c NOT IN :excludeStatuses)
                FROM Unit__c 
                WHERE Phase__c = :buildingsId AND Status__c = 'Available' WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
        }
        List<Unit__c> validUnitLst = new List<Unit__c>();
        if(!unitLst.isEmpty() && unitLst.size() > 0){
            for(Unit__c unitObj : unitLst){
                if(unitObj.Sales_Orders__r.isEmpty()){
                    validUnitLst.add(unitObj);
                }
            }
        }
        return validUnitLst;
    }

    @AuraEnabled
    public static List<Unit__c> getUnitDetails(Id buildingsId, String oppId){ 
        List<Unit__c> unitLst = new List<Unit__c>(); //Add Update the Change as par of new status
        unitLst = [select id,Name,Phase__c,PlotAreasqm__c,Phase__r.Name, Number_of_Bedrooms__c,Phase__r.Project__c, Phase__r.Project__r.Name, TotalPrice__c, (SELECT Id FROM Sales_Orders__r WHERE Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided')) 
                        FROM Unit__c 
                        WHERE Phase__c = :buildingsId 
                            AND (   (Status__c = 'Available' AND Sub_Status__c  ='Un-Assigned') OR 
                                    (Sub_Status__c = 'Assigned' AND BlockedFor__c = :UserInfo.getUserId()) 
                                )
                            AND (
                                    Opportunity__c = null OR
                                    Opportunity__c = :oppId
                            )
                            order by Name];

        List<Unit__c> validUnitLst = new List<Unit__c>();

        if(!unitLst.isEmpty() && unitLst.size() > 0){
            for(Unit__c unitObj : unitLst){
                if(unitObj.Sales_Orders__r.isEmpty()){
                    validUnitLst.add(unitObj);
                }
            }
        }
        return validUnitLst;
    }
    @AuraEnabled
    public static void createOfferLineCollection(List<SalesOrder__c> SalesOrderList,Id oppId,String offersLineStr){
        system.debug('OffLineString:'+offersLineStr);
        if(offersLineStr <> null && offersLineStr !=''){
        List<unitOffersWrapper> offerLinesList = (List<unitOffersWrapper>) JSON.deserialize(offersLineStr, List<unitOffersWrapper>.class);
        System.debug('offerLinesList::'+offerLinesList);
     if(offerLinesList.size() > 0){
       List<Offers_Collections__c> offerCollectionsList = new List<Offers_Collections__c>();
       List<SalesOrder__c> salesOrderUpdateList = new List<SalesOrder__c>();
       Map<Id,OfferLines__c> offerLinesMap = new Map<Id,OfferLines__c>();
       Map<Id,List<OfferLines__c>> unitOfferWrapper = new Map<Id,List<OfferLines__c>>();
       Set<Id> offerLinesId = new Set<Id>();
       for(unitOffersWrapper uWrap: offerLinesList){
        if(uWrap.offerLinesLst <> null && uWrap.offerLinesLst.size()>0){
            unitOfferWrapper.put(uWrap.unitId,uWrap.offerLinesLst);
        }
       }
       for(String keySet: unitOfferWrapper.keySet()){
           for(OfferLines__c offerLines: unitOfferWrapper.get(keySet)){
           	 offerLinesId.add(offerLines.Id);
           }
        }
        for(OfferLines__c offerLines: [SELECT Id,OfferValue__c,OfferOn__c FROM OfferLines__c WHERE Id IN: offerLinesId ]){
            offerLinesMap.put(offerLines.Id,offerLines);
        }
        for(SalesOrder__c so: SalesOrderList){
            if(unitOfferWrapper.containsKey(so.unit__c)){
            for(OfferLines__c offersLine: unitOfferWrapper.get(so.unit__c)){
            Offers_Collections__c offersCollections = new Offers_Collections__c();
            offersCollections.Opportunity__c = oppId;
            offersCollections.Sales_Order__c = so.Id;
            offersCollections.Offer_Lines__c = offersLine.Id;
            offersCollections.Unit__c = so.Unit__c;
            offerCollectionsList.add(offersCollections);
			if(offerLinesMap.containsKey(offersLine.Id) && offerLinesMap.get(offersLine.Id).OfferOn__c == 'ADM Fees' &&  offerLinesMap.get(offersLine.Id).OfferValue__c <> null){
               SalesOrder__c soObj = new SalesOrder__c();
               soObj.Id = so.Id;
               soObj.Discount_on_ADM_Fees__c = offerLinesMap.get(offersLine.Id).OfferValue__c;
               salesOrderUpdateList.add(soObj);
            }
        }
        } 
        }
       if(!offerCollectionsList.isEmpty()){
           insert offerCollectionsList; 
        }
        if(!salesOrderUpdateList.isEmpty()){
          update salesOrderUpdateList;
        }
    }
    }
    }
    
    
    public class UnitDetailsWrapper{
        @AuraEnabled public UnitsUnitOptionDetails unitOptiontDetailObj;
        @AuraEnabled public UnitPaymentDetails unitPaymentDetailObj;
        @AuraEnabled public List<UnitOptionWrapper> unitOptionsList;
    }

    public class UnitOptionWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String selectedValue;
        @AuraEnabled public List<Map<String, String>> unitOptions;
    }

    public class UnitsUnitOptionDetails{
        @AuraEnabled public String selectedUnitOption;
        @AuraEnabled public List<Map<String, String>> availableUnitOptions;
        @AuraEnabled public List<UnitOptionDetails> unitOptionLst;
    }

    public class UnitOptionDetails{
        @AuraEnabled public Unit_Option__c unitOptionObj;
        @AuraEnabled public Boolean isSelected;

        public UnitOptionDetails(){
            isSelected = false;
        }
    }


    public class UnitPaymentDetails{
        @AuraEnabled public String selectedPayment;
        @AuraEnabled public List<Map<String, String>> availablePaymentPlans;
        @AuraEnabled public List<PaymentDetails> paymentLst;
    }

    public class PaymentDetails{
        @AuraEnabled public PaymentPlan__c paymentObj;
        @AuraEnabled public List<PaymentInstallements__c> paymentInstallment;
        @AuraEnabled public Boolean isSelected;

        public PaymentDetails(){
            isSelected = false;
        }
    }

    public class UnitPicklistOptions{
        @AuraEnabled public string picklistLable;
        @AuraEnabled public string picklistApiName;
        @AuraEnabled public List<String> picklistOptions;
    }
    public class unitOffersWrapper{
        @AuraEnabled public string unitId;
        @AuraEnabled public List<OfferLines__c> offerLinesLst = new List<OfferLines__c>();
    }
}