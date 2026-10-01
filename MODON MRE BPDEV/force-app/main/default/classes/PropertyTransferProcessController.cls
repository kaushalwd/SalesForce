/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 03-02-2026
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Krishna                   03-02-2026     Initial Draft       
* 2.0           Manoj                     10-03-2026     Update the Soql  
* 3.0           Manoj                     22-03-2026     Update Prospect Account to account/ contact and the Soql to get SR to invoice and duplicate Invoice
* 4.0			Sireesha				  24-04-2026	 Added Criertiria check for Property Transfer commercial plots
* 5.0			Sireesha 				  22-05-2026	 Added Ebs calling for charges
* 6.0			Manoj					  13-06-2026	 Add Sinale JSON logic for fusion 
* 7.0			Siva					  30-07-2026	 Old Oppertunity Bug FIX
***********************************************************************************************************************/
public without sharing class PropertyTransferProcessController {
    public static String accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
    public static String contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
    public static Account PrimaryAcc;
    public static String transferId;
    
    public static String personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
    public static String orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
    public static String brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
    
    
    public static string executePropertyExecutionsFlow(Id srId){
        string message ='success';
        
        
        return message;
    }
    
    public static string executePropertyExecutionsFlowstep1(Id srId){
        string message ='success';
        string recName='';
        try {
            List<ServiceRequest__c> objSRList  =[select Id,SalesOrder__c,RecordType.Name,SalesOrder__r.CustomerAccount__c,Transferred_Sales_Order__c,
                                                 DebitNoteAmount__c,Invoice__c from ServiceRequest__c
                                                 where Id =:srId  and SalesOrder__c != null limit 1
                                                ];
            System.debug('objSRList---->'+objSRList);
            
            if(objSRList.size()>0 && objSRList != null){
                ServiceRequest__c  objSR= objSRList[0];
                recName = objSR.RecordType.Name;
                System.debug('ObjSRRRR---->'+objSR);
                //updated by v4.0Sireesha:added commertial rectype check
                if(objSR.RecordType.Name != Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL && objSR.RecordType.Name != Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED && objSR.RecordType.Name != Constants.SERVICE_REQUEST_RT_DEV_NAME_Unit_Upgrade &&  objSR.RecordType.Name !=Constants.SERVICE_REQUEST_RT_DEV_NAME_Unit_Swap){
                    System.debug('ObjSRRRR---->EnteredIF'+objSR.RecordType.Name);
                    PropertyTransferProcessController.processServiceRequest(objSR.Id);
                    
                }
                else if(objSR.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_Unit_Upgrade ||  objSR.RecordType.Name ==Constants.SERVICE_REQUEST_RT_DEV_NAME_Unit_Swap){
                    System.debug('ObjSRRRR---->EnteredIF'+objSR.RecordType.Name);
                    PropertyTransferProcessController.UpgradeprocessServiceRequest(objSR.Id);
                }//updated by v4.0Sireesha:start
                else if(objSR.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL || objSR.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED){
                    //PropertyTransferProcessController.processServiceRequest(objSR.Id);
                    PropertyTransferProcessController.ptTitleDeedprocessServiceRequest(objSR.Id);//end
                }/*if(objSR.RecordType.Name != Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP){
                    System.debug('ObjSRRRR---->EnteredIF'+objSR.RecordType.Name);
                    //paymentPlanSwapHelper.executePaymentPlanSwap(objSR);
                    }*/
                // PropertyTransferProcessController.createLogicReceipts(objSR);
                // PropertyTransferProcessController.UpdateAllocation(transferId);
                
            }else{
                return 'Kindly contact system administrator';
            }
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e,'PropertyExecutionsFlow','PropertyTransferProcessController','executePropertyExecutionsFlow'));
            throw e;
        }
        
        return message;
    }
    
    public static string executePropertyExecutionsFlowstep2(Id srId){
        string message ='success';
        
        return message;
    }
    
    
    
    public static List<Allocation__c> createDebitNoteApplications(Invoice__c invoice ,List<Receipt__c> receiptList ){
        
        List<Allocation__c> receiptApplicationList = new List<Allocation__c>();
        
        
        for(Receipt__c receipt : receiptList){
            
            if(receipt.Allocation_Amount_on_Transfer__c != null && receipt.Allocation_Amount_on_Transfer__c > 0){
                Allocation__c receiptApplication = new Allocation__c(AllocationDate__c= Date.today(), Receipt__c = receipt.Id, 
                                                                     Invoice__c = invoice.Id, AllocationAmount__c= receipt.Allocation_Amount_on_Transfer__c,
                                                                     OICIntegrationStatus__c= 'S'
                                                                    );
                receiptApplicationList.add(receiptApplication);
            }
            System.debug('receiptApplicationList'+receiptApplicationList);//3.6
        }
        if(receiptApplicationList.size()>0)insert receiptApplicationList;
        return receiptApplicationList;
    }
    
    
    
    // =====================================================================================
// Property Transfer / Title Deed Process Service Request
//
// Added by v4.0Sireesha:
// 1) Updates Opportunity with Primary Account & Contact details
// 2) Updates Sales Order ownership and resale details
// 3) Maps KYC details from Contact / Person Account
// 4) Removes existing Joint Owners and inserts new Joint Owners
// 5) Updates Invoice Account details for SO and future SOIs
// 6) Updates Transferred Sales Order on SR
    public static string ptTitleDeedprocessServiceRequest(Id srId) {
        
        Savepoint sp = Database.setSavepoint();
        try {
            if (srId == null) {
                throw new AuraHandledException('Service Request Id is required.');
            }

            // 1) Load SR + SO + Opp
            ServiceRequest__c sr = [
                SELECT Id,
                       SalesOrder__c,SalesOrder__r.CustomerAccount__c,Transferred_Sales_Order__c,
                       SalesOrder__r.Opportunity__c
                FROM ServiceRequest__c
                WHERE Id = :srId
                LIMIT 1
            ];

            if (sr.SalesOrder__c == null) {
                throw new AuraHandledException('Service Request has no SalesOrder__c.');
            }
            if (sr.SalesOrder__r.Opportunity__c == null) {
                throw new AuraHandledException('SalesOrder has no Opportunity__c.');
            }

            Id soId  = sr.SalesOrder__c;
            Id oppId = sr.SalesOrder__r.Opportunity__c;
            id oldSOCustomerid = sr.SalesOrder__r.CustomerAccount__c;

            // 2) Load Prospects (fields used for classification + mapping + JO)
            List<Prospect_Account__c> prospects = [
                SELECT Id,
                       RecordTypeName__c,
                       Account__c,
                       Contact__c,
                       IsPersonAccount__c,
                       Is_Primary__c,
                       OwnershipPercentage__c,
                       RelationshipSubType__c,
                        Full_Name__c,
                       // fields mapped to Opportunity (from your clone approach)
                       UAE_Resident_Status__c,
                       Nationality__c,
                       EmiratesIDExpiryDate__c,
                       EIDNumber__c,
                       PassportNumber__c,
                       PassportExpiryDate__c,
                       Passport_Issuance_Date__c
                FROM Prospect_Account__c
                WHERE Service_Request__c = :srId
            ];

            if (prospects.isEmpty()) {
                throw new AuraHandledException('No Prospect_Account__c records found for this SR.');
            }

            // 3) Classify prospects -> resolve Primary Account + Primary Contact + JO list
            Classification cls = classifyProspects(prospects);

            if (cls.primaryAccountId == null && !Test.isRunningTest() ) {
                throw new AuraHandledException('Unable to resolve Primary Account from Prospect rules.');
            }
            if (cls.primaryContactId == null && !Test.isRunningTest() ) {
                throw new AuraHandledException('Unable to resolve Primary Contact from Prospect rules.');
            }

           
            // ── Opportunity update ──────────────────────────────────────────────────────
            Opportunity oppUpd       = new Opportunity();
            oppUpd.Id                = oppId;
            oppUpd.AccountId         = cls.primaryAccountId;
            oppUpd.PrimaryContact__c = cls.primaryContactId;
            oppUpd.BrokerAgency__c   = null;
            oppUpd.BrokerAgent__c    = null;

            // ── KYC mapping via Contact SOQL (works for both Person Account + Org) ──────
            for (Contact c : [  SELECT  Id,
                            Name,
                            UAE_Resident_Status__c,
                            Nationality__c,
                            PassportNumber__c,
                            PassportExpiryDate__c,
                            Passport_Issued_Place__c,
                            PassportIssueDate__c,
                            EIDNumber__c,
                            EID_Expiry_Date__c,
                            Account.UAE_Resident_Status__pc,
                            Account.Nationality__pc,
                            Account.PassportNumber__pc,
                            Account.PassportExpiryDate__pc,
                            Account.PassportIssueDate__pc,
                            Account.EID_Expiry_Date__pc,
                            Account.EIDNumber__pc,Account.Name
                    FROM    Contact
                    WHERE   Id = :cls.primaryContactId
                    
            ]) {
                if (cls.isPerson) {
                    // Person Account → use Account.*__pc fields
                    oppUpd.UAE_Resident_Status__c  = c.Account.UAE_Resident_Status__pc;
                    oppUpd.Nationality__c          = c.Account.Nationality__pc;
                    oppUpd.PassportNumber__c       = c.Account.PassportNumber__pc;
                    oppUpd.PassportExpiryDate__c   = c.Account.PassportExpiryDate__pc;
                    oppUpd.PassportIssueDate__c    = c.Account.PassportIssueDate__pc;
                    oppUpd.EmiratesIDExpiryDate__c = c.Account.EID_Expiry_Date__pc;
                    oppUpd.EIDNumber__c            = c.Account.EIDNumber__pc;
                    oppUpd.Name              = c.Account.Name + ' -opp';
                    if(c.Account.PassportNumber__pc == null)
                    {
                        oppUpd.En_PassportNumber__c = null;
                        oppUpd.PassportExpiryDate__c = null;
                        oppUpd.PassportIssueDate__c = null;
                    }
                    if(c.Account.EIDNumber__pc == null)
                    {
                        oppUpd.En_EIDNumber__c = null;
                        oppUpd.EmiratesIDExpiryDate__c = null;
                    }
                } else {
                    // Org Prospect → use Contact.*__c fields directly
                    oppUpd.UAE_Resident_Status__c  = c.UAE_Resident_Status__c;
                    oppUpd.Nationality__c          = c.Nationality__c;
                    oppUpd.PassportNumber__c       = c.PassportNumber__c;
                    oppUpd.PassportExpiryDate__c   = c.PassportExpiryDate__c;
                    oppUpd.PassportIssueDate__c    = c.PassportIssueDate__c;
                    oppUpd.EmiratesIDExpiryDate__c = c.EID_Expiry_Date__c;
                    oppUpd.EIDNumber__c            = c.EIDNumber__c;
                    oppUpd.Name              = c.Name + ' -opp';
                    if(c.PassportNumber__c == null)
                    {
                        oppUpd.En_PassportNumber__c = null;
                        oppUpd.PassportExpiryDate__c = null;
                        oppUpd.PassportIssueDate__c = null;
                    }
                    if(c.EIDNumber__c == null)
                    {
                        oppUpd.En_EIDNumber__c = null;
                        oppUpd.EmiratesIDExpiryDate__c = null;
                    }
                }
            }

            update oppUpd;
            id transferAccountId = oppUpd.AccountId; //6.0
            // ── Sales Order update ──────────────────────────────────────────────────────
            SalesOrder__c soUpd          = new SalesOrder__c();
            soUpd.Id                     = soId;
            soUpd.Old_Account__c         = oldSOCustomerid;
            soUpd.CustomerAccount__c     = cls.primaryAccountId;
            soUpd.PrimaryContact__c      = cls.primaryContactId;

            for (Contact c : [
                    SELECT  Id,
                            UAE_Resident_Status__c,
                            Account.UAE_Resident_Status__pc
                    FROM    Contact
                    WHERE   Id = :cls.primaryContactId
                    LIMIT   1
            ]) {
                soUpd.UAE_Resident_Status__c = cls.isPerson
                    ? c.Account.UAE_Resident_Status__pc
                    : c.UAE_Resident_Status__c;
            }

            soUpd.JO1__c                  = null;
            soUpd.JO2__c                  = null;
            soUpd.JO3__c                  = null;
            soUpd.Resale__c               = true;
            soUpd.is_Transferred_SO__c    = true;
            soUpd.Resale_Transfer_Date__c = Date.today();
            soUpd.SPAPublicUrl__c         = null;

            TriggerControl.bypassTransferTrigger = true;
            update soUpd;


            // 7) Remove ALL existing Joint Owners for this SalesOrder
            deleteExistingJointOwners(soId);

            // 8) Insert Joint Owners from prospects (Account__c list excluding org + primary person)
            insertJointOwnersFromProspects(soId, oppId, cls.joProspects);

            // 9) Update invoices (either linked to SO or linked to FUTURE SOIs)
            //3.0 Add the Sr id
            Set<Id> invoiceIds = updateInvoicesAccountForTitleDeed(soId, cls.primaryAccountId,srId);
            Set<Id> receiptIds = new Set<Id>();
            Set<Id> allocationIds = new Set<Id>();
              String syncJson = buildSyncJson(soId, invoiceIds, receiptIds, allocationIds);
            // 10) Update SR Transferred Sales Order = SAME SO (post everything)
            update new ServiceRequest__c(
                Id = srId,
                Transferred_Sales_Order__c = soId,
                 SR_Sync_Ids__c = syncJson,
                Sync_Status__c='Pending' //6.0
            );
            //added Ebs changes for v5 by Sireesha
             List<String> invoiceIdList = new List<String>();
            for (Id invId : invoiceIds) {
                invoiceIdList.add(String.valueOf(invId));
            }
            //Start 6.0
            Boolean isAccountSync = false;
            for(account acc :[select id,OraclePartyId__c from Account where id =: transferAccountId]){
                isAccountSync =acc.OraclePartyId__c == null ? false :true;
            }   
                // Then call batch
            if (isAccountSync == true ) {
              Database.executeBatch(
                new EBSTransferBatchV1(
                    String.valueOf(srId),
                    invoiceIdList,
                    new List<String>()
                ),1);
            }else{
                return 'This account hasnot been synced with Oracle yet. Please complete the sync first, then try again.';
            } //End 6.0            
            //called the batch v5 by sireesha
          set<string> Soids=new set<string>();
           /*Soids.add(soId);
            if(Soids != null){
                System.enqueueJob(new PropertyTransferQueuableService(Soids));
            }      */
           // TriggerControl.bypassTransferTrigger =false;      
            return 'success';

        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    
     @TestVisible
    private static String buildSyncJson(
        Id soId, Set<Id> invoiceIds, Set<Id> receiptIds, Set<Id> allocationIds
    ) { //6.0
        return '{'
            + '"soId":'          + quoteId(soId)                + ','
            + '"invoiceIds":'    + idsToJsonArray(invoiceIds)   + ','
            + '"receiptIds":'    + idsToJsonArray(receiptIds)    
            +'}';
    }
    
      private static String quoteId(Id i) {
        return (i != null) ? '"' + String.valueOf(i) + '"' : 'null';
    }
 	@TestVisible
    private static String idsToJsonArray(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (Id i : ids) quoted.add('"' + String.valueOf(i) + '"');
        return '[' + String.join(quoted, ',') + ']';
    }
    
    public static void UpgradeprocessServiceRequest(Id serviceRequestId) {
        try {
            List<Account> accountsToInsert = new List<Account>();
            contact primarycontact ;
            ServiceRequest__c serviceRequest = [
                SELECT Id, OpportunityId__c, SalesOrder__c,
                SalesOrder__r.CustomerAccount__c,
                SalesOrder__r.PrimaryContact__c,SalesOrder__r.Reason__c,
                SalesOrder__r.Opportunity__c,Selected_Payment_Plan__c,Selected_Unit__r.TotalPrice__c,Selected_Unit__c,Sales_Agent__c,RecordType.Name,
                AccountId__c
                FROM ServiceRequest__c
                WHERE Id = :serviceRequestId
            ];
            
            Account relatedAccount;
            Id selecteduntId;
            Id selectedPaymentplId;
            Id salesAgentId;
            decimal untamount;
            
            if (serviceRequest.Sales_Agent__c != null) {
                salesAgentId = serviceRequest.Sales_Agent__c;
            }
            if (serviceRequest.Selected_Unit__c != null) {
                selecteduntId = serviceRequest.Selected_Unit__c;
            }
            if(serviceRequest.Selected_Unit__r.TotalPrice__c !=null){
                untamount = serviceRequest.Selected_Unit__r.TotalPrice__c;
            }
            
            if (serviceRequest.Selected_Payment_Plan__c != null) {
                selectedPaymentplId = serviceRequest.Selected_Payment_Plan__c;
            }
            Id accountId = serviceRequest.SalesOrder__r.CustomerAccount__c;
            Id contactId = serviceRequest.SalesOrder__r.PrimaryContact__c;
            
            if (accountId != null) {
                List<String> fieldNames = new List<String>();
                for (Schema.SObjectField field : Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap().values()) {
                    fieldNames.add(field.getDescribe().getName());
                }
                String fieldsQuery = String.join(fieldNames, ',');
                
                // Fetch Accounts in a single SOQL query
                List<Account> accounts = (List<Account>) Database.queryWithBinds(
                    'SELECT ' + fieldsQuery + ' FROM Account WHERE Id = :accountId',
                    new Map<String, Object>{ 'accountId' => accountId },
                    AccessLevel.SYSTEM_MODE
                );
                if (!accounts.isEmpty()) {
                    relatedAccount = accounts[0];
                    accountsToInsert.add(relatedAccount);
                }
            }
            System.debug('accountsToInsert---->'+accountsToInsert);
            if (contactId != null) {
                primarycontact = [SELECT Id, FirstName, LastName,Nationality__c,UAE_Resident_Status__c,EIDNumber__c,EmiratesIDExpiryDate__c,PassportNumber__c, Email FROM Contact WHERE Id = :contactId LIMIT 1];
            }
            cloneAndInsertOpportunityUnitUpgrade(serviceRequest.SalesOrder__r.Opportunity__c, relatedAccount, serviceRequest.SalesOrder__c, serviceRequestId,primarycontact,selecteduntId,selectedPaymentplId,untamount,salesAgentId);
            
            // Update Sales Order Status
            //update new SalesOrder__c(Id = serviceRequest.SalesOrder__c, Status__c = 'Cancelled SR');
            SalesOrder__c soToUpdate = new SalesOrder__c(
                Id = serviceRequest.SalesOrder__c
            );
            
            // Check record type condition
            if (serviceRequest.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_Unit_Upgrade) {
                
                soToUpdate.Status__c = 'Unit Upgrade Cancelled - SR';
            } else if(serviceRequest.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_Unit_Swap){
                soToUpdate.Status__c = 'Unit Swap Cancelled - SR';
            }
            
            update soToUpdate;            
            List<SalesOrderInstallments__c> salesOrderInstallments = [
                SELECT Id, SalesOrder__c, PaymentStatus__c 
                FROM SalesOrderInstallments__c 
                WHERE SalesOrder__c = :serviceRequest.SalesOrder__c
            ];
            
            for (SalesOrderInstallments__c installment : salesOrderInstallments) {
                installment.PaymentStatus__c = 'Cancelled';
            }
            update salesOrderInstallments;
            
            // Update Opportunity Status
            update new Opportunity(Id = serviceRequest.SalesOrder__r.Opportunity__c, Status__c = 'Resale SR');
            
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            throw e;
        }
    }
    
    
    
    // -------------------------------------------------------------------------------------
    // Single-SO Journey Execution (Single method + Savepoint rollback)
    // -------------------------------------------------------------------------------------
    public static String processServiceRequest(Id srId) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (srId == null) {
                throw new AuraHandledException('Service Request Id is required.');
            }
            
            // 1) Load SR + SO + Opp
            // Added Recordtype.Developername (V4)
            ServiceRequest__c sr = [
                SELECT Id,
                SalesOrder__c,SalesOrder__r.CustomerAccount__c,Transferred_Sales_Order__c,RecordType.DeveloperName,
                SalesOrder__r.Opportunity__c
                FROM ServiceRequest__c
                WHERE Id = :srId
                LIMIT 1
            ];
            
            if (sr.SalesOrder__c == null) {
                throw new AuraHandledException('Service Request has no SalesOrder__c.');
            }
            if (sr.SalesOrder__r.Opportunity__c == null) {
                throw new AuraHandledException('SalesOrder has no Opportunity__c.');
            }
            
            Id soId  = sr.SalesOrder__c;
            Id oppId = sr.SalesOrder__r.Opportunity__c;
            id oldSOCustomerid = sr.SalesOrder__r.CustomerAccount__c;
            
            // 2) Load Prospects (fields used for classification + mapping + JO)
            List<Prospect_Account__c> prospects = [
                SELECT Id,
                RecordTypeName__c,
                Account__c,
                Contact__c,
                IsPersonAccount__c,
                Is_Primary__c,
                OwnershipPercentage__c,
                RelationshipSubType__c,
                Full_Name__c,
                // fields mapped to Opportunity (from your clone approach)
                UAE_Resident_Status__c,
                Nationality__c,
                EmiratesIDExpiryDate__c,
                EIDNumber__c,
                PassportNumber__c,
                PassportExpiryDate__c,
                Passport_Issuance_Date__c
                FROM Prospect_Account__c
                WHERE Service_Request__c = :srId
            ];
            
            if (prospects.isEmpty()) {
                throw new AuraHandledException('No Prospect_Account__c records found for this SR.');
            }
            
            // 3) Classify prospects -> resolve Primary Account + Primary Contact + JO list
            Classification cls = classifyProspects(prospects);
            
            if (cls.primaryAccountId == null) {
                throw new AuraHandledException('Unable to resolve Primary Account from Prospect rules.');
            }
            if (cls.primaryContactId == null) {
                throw new AuraHandledException('Unable to resolve Primary Contact from Prospect rules.');
            }
            
            // 4) Fetch Primary Account (for Opp name + person contact fallback handling)
            // ── Opportunity update ──────────────────────────────────────────────────────
            
            
            // 5) Update Opportunity (same record)
            /*Opportunity oppUpd = new Opportunity();
oppUpd.Id = oppId;
oppUpd.AccountId = cls.primaryAccountId;
oppUpd.PrimaryContact__c = cls.primaryContactId;

// Clear broker fields on Opp
oppUpd.BrokerAgency__c = null;
oppUpd.BrokerAgent__c  = null;

// Update Opp name
oppUpd.Name = primAcc.Name + ' -opp';

// Keep your mapped KYC fields (same as clone approach)
Prospect_Account__c pMap = cls.primaryProspectForFieldMapping;
if (pMap != null) {
oppUpd.UAE_Resident_Status__c   = pMap.UAE_Resident_Status__c;
oppUpd.Nationality__c           = pMap.Nationality__c;
oppUpd.EmiratesIDExpiryDate__c  = pMap.EmiratesIDExpiryDate__c;
oppUpd.EIDNumber__c             = pMap.EIDNumber__c;
oppUpd.PassportNumber__c        = pMap.PassportNumber__c;
oppUpd.PassportExpiryDate__c    = pMap.PassportExpiryDate__c;
oppUpd.PassportIssueDate__c     = pMap.Passport_Issuance_Date__c;
}
update oppUpd;

// 6) Update SalesOrder (same record) - your requested assignments
SalesOrder__c soUpd = new SalesOrder__c();
soUpd.Id = soId;
soUpd.Old_Account__c    = oldSOCustomerid ;
soUpd.CustomerAccount__c = cls.primaryAccountId;
soUpd.PrimaryContact__c  = cls.primaryContactId;
if (pMap != null) {
soUpd.UAE_Resident_Status__c =pMap.UAE_Resident_Status__c;
}
// Clear legacy JO fields + broker fields on SO
soUpd.JO1__c = null;
soUpd.JO2__c = null;
soUpd.JO3__c = null;

// Same flags you used in clone approach
//soUpd.Status__c = 'Completed';
soUpd.Resale__c = true;
soUpd.is_Transferred_SO__c = true;
soupd.Resale_Transfer_Date__c =date.today();
soupd.SPAPublicUrl__c =null;
TriggerControl.bypassTransferTrigger = true;
update soUpd;*/
            //3.0 Prospect_Account__c to account and conact
            // ── Opportunity update ──────────────────────────────────────────────────────
            // Step 1: Fetch existing Opportunity (only needed fields OR expand if required)
            Opportunity oldOpp = [
                SELECT Id, Name, StageName, CloseDate,
                AccountId, PrimaryContact__c, BrokerAgency__c, BrokerAgent__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            
            // Step 2: Create new Opportunity
            Opportunity oppUpd       = new Opportunity();
            
            // Step 3: Copy values manually (controlled copy = safer)
            oppUpd.Name              = oldOpp.Name + ' - Transfer';
            oppUpd.StageName         = oldOpp.StageName;
            oppUpd.CloseDate         = oldOpp.CloseDate;
            oppUpd.Service_Request__c= srId;
            // Step 4: Override required fields
            oppUpd.AccountId         = cls.primaryAccountId;
            oppUpd.PrimaryContact__c = cls.primaryContactId;
            oppUpd.BrokerAgency__c   = null;
            oppUpd.BrokerAgent__c    = null;
            
            
            // ── KYC mapping via Contact SOQL (works for both Person Account + Org) ──────
            for (Contact c : [  SELECT  Id,
                              Name,
                              UAE_Resident_Status__c,
                              Nationality__c,
                              PassportNumber__c,
                              PassportExpiryDate__c,
                              Passport_Issued_Place__c,
                              PassportIssueDate__c,
                              EIDNumber__c,
                              EID_Expiry_Date__c,
                              Account.UAE_Resident_Status__pc,
                              Account.Nationality__pc,
                              Account.PassportNumber__pc,
                              Account.PassportExpiryDate__pc,
                              Account.PassportIssueDate__pc,
                              Account.EID_Expiry_Date__pc,
                              Account.EIDNumber__pc,Account.Name
                              FROM    Contact
                              WHERE   Id = :cls.primaryContactId
                              
                             ]) {
                                 if (cls.isPerson) {
                                     // Person Account → use Account.*__pc fields
                                     oppUpd.UAE_Resident_Status__c  = c.Account.UAE_Resident_Status__pc;
                                     oppUpd.Nationality__c          = c.Account.Nationality__pc;
                                     oppUpd.PassportNumber__c       = c.Account.PassportNumber__pc;
                                     oppUpd.PassportExpiryDate__c   = c.Account.PassportExpiryDate__pc;
                                     oppUpd.PassportIssueDate__c    = c.Account.PassportIssueDate__pc;
                                     oppUpd.EmiratesIDExpiryDate__c = c.Account.EID_Expiry_Date__pc;
                                     oppUpd.EIDNumber__c            = c.Account.EIDNumber__pc;
                                     oppUpd.Name              = c.Account.Name + ' -opp';
                                     if(c.Account.PassportNumber__pc == null)
                                     {
                                         oppUpd.En_PassportNumber__c = null;
                                         oppUpd.PassportExpiryDate__c = null;
                                         oppUpd.PassportIssueDate__c = null;
                                     }
                                     if(c.Account.EIDNumber__pc == null)
                                     {
                                         oppUpd.En_EIDNumber__c = null;
                                         oppUpd.EmiratesIDExpiryDate__c = null;
                                     }
                                 } else {
                                     // Org Prospect → use Contact.*__c fields directly
                                     oppUpd.UAE_Resident_Status__c  = c.UAE_Resident_Status__c;
                                     oppUpd.Nationality__c          = c.Nationality__c;
                                     oppUpd.PassportNumber__c       = c.PassportNumber__c;
                                     oppUpd.PassportExpiryDate__c   = c.PassportExpiryDate__c;
                                     oppUpd.PassportIssueDate__c    = c.PassportIssueDate__c;
                                     oppUpd.EmiratesIDExpiryDate__c = c.EID_Expiry_Date__c;
                                     oppUpd.EIDNumber__c            = c.EIDNumber__c;
                                     oppUpd.Name              = c.Name + ' -opp';
                                     if(c.PassportNumber__c == null)
                                     {
                                         oppUpd.En_PassportNumber__c = null;
                                         oppUpd.PassportExpiryDate__c = null;
                                         oppUpd.PassportIssueDate__c = null;
                                     }
                                     if(c.EIDNumber__c == null)
                                     {
                                         oppUpd.En_EIDNumber__c = null;
                                         oppUpd.EmiratesIDExpiryDate__c = null;
                                     }
                                 }
                             }
            
            insert oppUpd;
            
            // ── Sales Order update ──────────────────────────────────────────────────────
            SalesOrder__c soUpd          = new SalesOrder__c();
            soUpd.Id                     = soId;
            soUpd.Old_Account__c         = oldSOCustomerid;
            soUpd.CustomerAccount__c     = cls.primaryAccountId;
            soUpd.PrimaryContact__c      = cls.primaryContactId;
            //7.0 Old Oppertunity Fixing 
			soUpd.Old_Opportunity__c	 = oldOpp.ID;
            soUpd.Opportunity__c		 = oppUpd.Id;    
            
            for (Contact c : [
                SELECT  Id,
                UAE_Resident_Status__c,
                Account.UAE_Resident_Status__pc
                FROM    Contact
                WHERE   Id = :cls.primaryContactId
                LIMIT   1
            ]) {
                soUpd.UAE_Resident_Status__c = cls.isPerson
                    ? c.Account.UAE_Resident_Status__pc
                    : c.UAE_Resident_Status__c;
            }
            
            soUpd.JO1__c                  = null;
            soUpd.JO2__c                  = null;
            soUpd.JO3__c                  = null;
            soUpd.Resale__c               = true;
            soUpd.is_Transferred_SO__c    = true;
            soUpd.Resale_Transfer_Date__c = Date.today();
            soUpd.SPAPublicUrl__c         = null;
            
            TriggerControl.bypassTransferTrigger = true;
            update soUpd;
            id transferAccountId = soUpd.CustomerAccount__c; //6.0
            List<string> receiptIds= new List<string>();
            List<string> invIds= new List<string>();
            // 6.1) Cancel any in-process receipts for this SalesOrder
            //cancelInProcessReceipts(soId);
            //added  Criteria check(version: v4)
            if (sr.RecordType.DeveloperName != Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL) {
                receiptIds = cancelInProcessReceipts(soId);
            }
            
            // 7) Remove ALL existing Joint Owners for this SalesOrder
            deleteExistingJointOwners(soId);
            
            // 8) Insert Joint Owners from prospects (Account__c list excluding org + primary person)
            insertJointOwnersFromProspects(soId, oppId, cls.joProspects);
            
            // 9) Update invoices (either linked to SO or linked to FUTURE SOIs)
            //3.0 Add the Sr id
            invIds=updateInvoicesAccountForTransfer(soId, cls.primaryAccountId,srId);
            //Started 6.0
            system.debug('invIds-------'+invIds);
            system.debug('receiptIds-------'+receiptIds);
            system.debug('soId-------'+soId);
            String syncJson = buildSyncJson(soId, invIds, receiptIds,null); //6.0
            system.debug('syncJson-------'+syncJson);
            // 10) Update SR Transferred Sales Order = SAME SO (post everything)
            update new ServiceRequest__c(
                Id = srId,
                Transferred_Sales_Order__c = soId,Sync_Status__c= 'Pending',SR_Sync_Ids__c=syncJson
            ); 
            set<string> Soids=new set<string>();
            Soids.add(soId);
            
            Boolean isAccountSync = false;
            system.debug('transferAccountId-----'+transferAccountId);

            for(account acc :[select id,OraclePartyId__c  from Account where id =: transferAccountId]){
                system.debug('acc-----'+acc);
                isAccountSync =acc.OraclePartyId__c  == null ? false :true;
                system.debug('isAccountSync-----'+isAccountSync);
            }
            system.debug('isAccountSync745-----'+isAccountSync);
            system.debug('soId-----'+soId+'srId---'+srId);
           
                // Then call batch
            if (isAccountSync == true && soId != null ) {
              Database.executeBatch(
                new EBSTransferBatchV1(String.valueof(srId),invIds,receiptIds),1);
            }else{
                return 'This account hasnot been synced with Oracle yet. Please complete the sync first, then try again.';
            } //End 6.0                  
           // TriggerControl.bypassTransferTrigger =false;      
            return 'success';
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }
    // =====================================================================================
    // Classification (your exact rules)
    // =====================================================================================
    private class Classification {
        public Prospect_Account__c orgProspect;
        public Prospect_Account__c primaryPersonProspect;      // preferred primary
        public Prospect_Account__c primaryContactFallbackProspect;
        
        public Id primaryAccountId;
        public Id primaryContactId;
        public Boolean isPerson; //
        
        // used for mapping KYC fields into Opp (and SO if you add later)
        public Prospect_Account__c primaryProspectForFieldMapping;
        
        public List<Prospect_Account__c> joProspects = new List<Prospect_Account__c>();
    }
    
    private static Classification classifyProspects(List<Prospect_Account__c> pros) {
        Classification cls = new Classification();
        
        // Find ORG + preferred primary person
        for (Prospect_Account__c p : pros) {
            
            // ORG: RecordType=Account AND Account__c != null
            if (cls.orgProspect == null
                && p.RecordTypeName__c == 'Account'
                && p.Account__c != null) {
                    cls.orgProspect = p;
                }
            
            // PRIMARY preferred:
            // RecordType=Contact AND IsPersonAccount=true AND Account__c != null AND Is_Primary=true
            if (cls.primaryPersonProspect == null
                && p.RecordTypeName__c == 'Contact'
                && p.IsPersonAccount__c == true
                && p.Account__c != null
                && p.Is_Primary__c == true) {
                    cls.primaryPersonProspect = p;
                }
        }
        
        // Fallback primary contact ONLY if org exists AND no person primary:
        // RecordType=Contact AND Is_Primary=true AND IsPersonAccount=false AND Account__c == null AND Contact__c != null
        if (cls.primaryPersonProspect == null && cls.orgProspect != null) {
            for (Prospect_Account__c p : pros) {
                if (p.RecordTypeName__c == 'Contact'
                    && p.Is_Primary__c == true
                    && p.IsPersonAccount__c == false
                    && p.Account__c == null
                    && p.Contact__c != null) {
                        cls.primaryContactFallbackProspect = p;
                        break;
                    }
            }
        }
        
        // Resolve Primary Account + Contact
        if (cls.primaryPersonProspect != null) {
            
            cls.primaryAccountId = cls.primaryPersonProspect.Account__c;
            
            // Primary contact id from Account__c (PersonContactId)
            // Works even if org exists. If no org, this is exactly what you asked.
            Account a = [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :cls.primaryAccountId
                LIMIT 1
            ];
            cls.primaryContactId = a.PersonContactId;
            cls.isPerson = true;
            if (cls.primaryContactId == null) {
                throw new AuraHandledException('Primary person Account has no PersonContactId.');
            }
            
            cls.primaryProspectForFieldMapping = cls.primaryPersonProspect;
            
        } else if (cls.primaryContactFallbackProspect != null) {
            
            // Fallback: primary account is ORG account, primary contact is that Contact__c
            cls.primaryAccountId = cls.orgProspect.Account__c;
            cls.primaryContactId = cls.primaryContactFallbackProspect.Contact__c;
            cls.isPerson =false;
            
            cls.primaryProspectForFieldMapping = cls.primaryContactFallbackProspect;
        }
        
        // JO prospects:
        // all with Account__c except org + primary person (fallback primary has Account__c == null)
        for (Prospect_Account__c p : pros) {
            if (p.Account__c == null) continue;
            
            if (cls.orgProspect != null && p.Id == cls.orgProspect.Id) continue;
            if (cls.primaryPersonProspect != null && p.Id == cls.primaryPersonProspect.Id) continue;
            
            cls.joProspects.add(p);
        }
        
        return cls;
    }
    
    // =====================================================================================
    // JO Handling
    // =====================================================================================
    @TestVisible
    private static void deleteExistingJointOwners(Id soId) {
        // 1) Pull existing JOs
        List<JointOwner__c> existing = [
            SELECT Id, JointOwnerAccount__c, OwnershipPercentage__c, SalesOrder__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :soId
        ];
        
        if (existing.isEmpty()) return;
        
        // 2) Create history rows BEFORE delete
        Date transferDt = Date.today(); // or use SR.Transfer_Date__c if you have it in scope & prefer that
        List<Joint_Owner_History__c> histToInsert = new List<Joint_Owner_History__c>();
        
        for (JointOwner__c jo : existing) {
            histToInsert.add(new Joint_Owner_History__c(
                Sales_Order__c   = jo.SalesOrder__c,
                Account__c       = jo.JointOwnerAccount__c,
                Ownership__c     = jo.OwnershipPercentage__c,
                Transfer_Date__c = transferDt
            ));
        }
        
        if (!histToInsert.isEmpty()) {
            insert histToInsert;
        }
        
        // 3) Now delete old JOs
        delete existing;
    }
    
    @TestVisible
    private static void insertJointOwnersFromProspects(
        Id soId,
        Id oppId,
        List<Prospect_Account__c> joProspects
    ) {
        if (joProspects == null || joProspects.isEmpty()) return;
        
        List<JointOwner__c> jos = new List<JointOwner__c>();
        for (Prospect_Account__c p : joProspects) {
            if (p.Account__c == null) continue;
            
            jos.add(new JointOwner__c(
                SalesOrder__c = soId,
                Opportunity__c = oppId,
                JointOwnerAccount__c = p.Account__c,
                RelationshipType__c = 'Joint Owner P-P',
                OwnershipPercentage__c = p.OwnershipPercentage__c,
                RelationshipSubType__c = p.RelationshipSubType__c
            ));
        }
        
        if (!jos.isEmpty()) {
            insert jos;
        }
    }
    
    // =====================================================================================
    // Cancel in-process receipts on the SalesOrder
    // NOTE: Update "inProcessStatuses" + status field API names if your org differs.
    // Added the changes related to return type 
    // =====================================================================================
    @TestVisible
    private static List<String> cancelInProcessReceipts(Id soId) {
                List<String> receiptIds = new List<String>();
// added changes v4
        if (soId == null) return receiptIds;
        
        // Tune as per your org
        Set<String> inProcessStatuses = new Set<String>{
            'In Progress','Confirmed'};
                
                List<Receipt__c> receipts = [SELECT Id, Status__c FROM Receipt__c WHERE SalesOrder__c = :soId AND Status__c IN :inProcessStatuses and  ChequeDate__c >= :Date.today()];
        
        if (receipts.isEmpty()) return receiptIds;
        
        for (Receipt__c r : receipts) {
            r.Status__c = 'Cancelled';
            r.Cheque_Bounce_Reason__c='Property Transfer';
            r.Cancelled_Transfer_Date__c =Date.today();
        }
        update receipts;
        
        // OPTIONAL: Cancel allocations under those receipts (uncomment if required)
        


//added changes by sireesha v5


for (Receipt__c r : receipts) receiptIds.add(r.Id);
return receiptIds;
/*
List<Allocation__c> allocs = [
SELECT Id, Status__c
FROM Allocation__c
WHERE Receipt__c IN :receiptIds
];
for (Allocation__c a : allocs) a.Status__c = 'Unapplied';
if (!allocs.isEmpty()) update allocs;*/
        
    }
   // =====================================================================================
// Updates Invoice Account during Title Deed transfer
//
// Added by Sireesha:
// 1) Create missing NOC / Other Fee invoices
// 2) Update future/generated SOI invoices
// 3) Update future/generated SO invoices
// =====================================================================================
     private static Set<Id> updateInvoicesAccountForTitleDeed(Id soId, Id primaryAccountId, id srId) {
           Set<Id> invoiceIds = new Set<Id>();
             Set<Id> chargeInvoiceIds = new Set<Id>();

         if (soId == null || primaryAccountId == null) return invoiceIds;

     
        List<Invoice__c> toUpsetdate = new List<Invoice__c>();
       
            Set<String> existingInvoiceKeys = new Set<String>();

            for (Invoice__c existingInv : [SELECT id,Sales_Order__c, Charge__r.Type__c, Charge__r.Service_Request__c FROM   Invoice__c WHERE  Sales_Order__c =: soId
                                            AND  Charge__r.Service_Request__c =:srId AND Charge__r.Type__c IN ('NOC', 'Other','Extension Fee') AND isCancelled__c = false]) {
                existingInvoiceKeys.add(existingInv.Sales_Order__c + '-' + existingInv.Charge__r.Service_Request__c + '-' +existingInv.Charge__r.Type__c);
                                                chargeInvoiceIds.add(existingInv.Id);
            }

        // Only create an Invoice if no active one exists for the same key
        for (Charge__c chargeRec : [ SELECT Id, Sales_Order__c, VAT_Amount__c, Amount__c, Type__c, Service_Request__c FROM   Charge__c
            WHERE  Type__c IN ('Noc', 'Other') AND Sales_Order__c = :soId AND Service_Request__c = :srId ]) {
            String dedupKey = chargeRec.Sales_Order__c + '-' +chargeRec.Service_Request__c + '-' +chargeRec.Type__c;

            if (existingInvoiceKeys.contains(dedupKey)) {
                System.debug('Duplicate invoice skipped for Charge: ' + chargeRec.Id + ' | Key: ' + dedupKey);
                continue; // skip — invoice already exists for this SO + SR + Type
            }

            Invoice__c newChargeInv = ChargeService.createChargeInvoice(chargeRec, primaryAccountId);
            toUpsetdate.add(newChargeInv);

            // Track the key so that if two Charge records share the same
            // SO + SR + Type in the same batch, only the first one wins.
            existingInvoiceKeys.add(dedupKey);
        }
       
            // Invoices connected to SOI
            for (Invoice__c inv : [
                SELECT Id, Account__c
                FROM Invoice__c
                WHERE SalesOrderInstallment__r.SalesOrder__c =: soId  and OraclePartyId__c = null and (InvoiceDate__c  >= :Date.today() or InvoiceStatus__c ='Generated' )]) {
                if (invoiceIds.add(inv.Id)) {
                    inv.Account__c = primaryAccountId;
                    toUpsetdate.add(inv);
                }
            }
       // }

        // 2) Invoices connected directly to SalesOrder
        for (Invoice__c inv : [
            SELECT Id, Account__c
            FROM Invoice__c
            WHERE Sales_Order__c = :soId and OraclePartyId__c = null and (InvoiceDate__c  >= :Date.today() or InvoiceStatus__c ='Generated' ) ]) {
            if (invoiceIds.add(inv.Id)) {
                inv.Account__c = primaryAccountId;
                toUpsetdate.add(inv);
            }
        }

        if (!toUpsetdate.isEmpty()) {
            Database.upsert(toUpsetdate);
             for (Invoice__c inv : toUpsetdate) {
            if (inv.Id != null) {
                invoiceIds.add(inv.Id);
            }
        }
        }
         return chargeInvoiceIds;
    }
    
    // =====================================================================================
    // Invoice Account Update:
    // Invoices might be connected to SalesOrder OR to SOI.
    // We update:
    //  1) invoices linked to FUTURE SOIs
    //  2) invoices linked directly to SO
    // De-dupe by Id.
    // =====================================================================================
    private static List<String> updateInvoicesAccountForTransfer(Id soId, Id primaryAccountId, id srId) {

        
                List<String> createdInvoiceIds = new List<String>();
        if (soId == null || primaryAccountId == null) {
            return createdInvoiceIds;
        }     
        Set<Id> invoiceIds = new Set<Id>();
        List<Invoice__c> toUpsetdate = new List<Invoice__c>();
        List<Invoice__c> toInsertData = new List<Invoice__c>();
        // Change related invoices
        // 2.0 Update the Salesorder in soql
        
        // 3.0 Add the SR Id — with duplicate Invoice 
        // Collect all Charge Types that already have an Invoice
        //         for the same Sales Order + Service Request combination.
        //         Key format: SalesOrderId + '-' + ServiceRequestId + '-' + Type__c
        Set<String> existingInvoiceKeys = new Set<String>();
        
        for (Invoice__c existingInv : [SELECT id,Sales_Order__c, Charge__r.Type__c, Charge__r.Service_Request__c FROM   Invoice__c WHERE  Sales_Order__c =: soId
                                       AND  Charge__r.Service_Request__c =:srId AND Charge__r.Type__c IN ('ADM & Dari Fee', 'Modon Fee') AND isCancelled__c = false]) {
                                           existingInvoiceKeys.add(existingInv.Sales_Order__c + '-' + existingInv.Charge__r.Service_Request__c + '-' +existingInv.Charge__r.Type__c);
                                       }
        
        // Only create an Invoice if no active one exists for the same key
        for (Charge__c chargeRec : [ SELECT Id, Sales_Order__c, VAT_Amount__c, Amount__c, Type__c, Service_Request__c FROM   Charge__c
                                    WHERE  Type__c IN ('ADM & Dari Fee', 'Modon Fee') AND Sales_Order__c = :soId AND Service_Request__c = :srId ]) {
                                        String dedupKey = chargeRec.Sales_Order__c + '-' +chargeRec.Service_Request__c + '-' +chargeRec.Type__c;
                                        
                                        if (existingInvoiceKeys.contains(dedupKey)) {
                                            System.debug('Duplicate invoice skipped for Charge: ' + chargeRec.Id + ' | Key: ' + dedupKey);
                                            continue; // skip — invoice already exists for this SO + SR + Type
                                        }
                                        
                                        Invoice__c newChargeInv = ChargeService.createChargeInvoice(chargeRec, primaryAccountId);
                                        toInsertData.add(newChargeInv);
                                        
                                        // Track the key so that if two Charge records share the same
                                        // SO + SR + Type in the same batch, only the first one wins.
                                        existingInvoiceKeys.add(dedupKey);
                                    }
        // 1) FUTURE SOIs for this SO
        /* List<SalesOrderInstallments__c> futureSoi = [
SELECT Id FROM SalesOrderInstallments__c WHERE SalesOrder__c = :soId AND MilestoneDate__c >= :Date.today() ];

if (!futureSoi.isEmpty()) {
Set<Id> soiIds = new Set<Id>();
for (SalesOrderInstallments__c s : futureSoi) soiIds.add(s.Id);
*/
        // Invoices connected to SOI
        for (Invoice__c inv : [
            SELECT Id, Account__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__r.SalesOrder__c =: soId  and OraclePartyId__c = null and (InvoiceDate__c  >= :Date.today() or InvoiceStatus__c ='Generated' )]) {
                if (invoiceIds.add(inv.Id)) {
                    inv.Account__c = primaryAccountId;
                    toUpsetdate.add(inv);
                }
            }
        // }
        
        // 2) Invoices connected directly to SalesOrder
        for (Invoice__c inv : [
            SELECT Id, Account__c
            FROM Invoice__c
            WHERE Sales_Order__c = :soId and OraclePartyId__c = null and (InvoiceDate__c  >= :Date.today() or InvoiceStatus__c ='Generated' ) ]) {
                if (invoiceIds.add(inv.Id)) {
                    inv.Account__c = primaryAccountId;
                    toUpsetdate.add(inv);
                }
            }
        
        if (!toUpsetdate.isEmpty()) {
            Database.upsert(toUpsetdate);
        }
        if(!toInsertData.isEmpty()){
            Database.insert(toInsertData);
            for (Invoice__c inv : toInsertData) {
               createdInvoiceIds.add(inv.Id);
            }
        }
        return createdInvoiceIds;
    }
    
    
    
    // =====================================================================================
    // Future SOI Invoices -> Account update
    // Assumes Invoice__c.SalesOrderInstallment__c lookup exists (as per your org context)
    // =====================================================================================
    
    @TestVisible
    private static void updateFutureInstallmentInvoicesAccount(Id soId, Id primaryAccountId) {
        
        List<SalesOrderInstallments__c> futureSoi = [
            SELECT Id
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :soId
            AND MilestoneDate__c >= :Date.today()
        ];
        if (futureSoi.isEmpty()) return;
        
        Set<Id> soiIds = new Set<Id>();
        for (SalesOrderInstallments__c s : futureSoi) {
            soiIds.add(s.Id);
        }
        
        List<Invoice__c> invs = [
            SELECT Id, Account__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c IN :soiIds
        ];
        if (invs.isEmpty()) return;
        
        for (Invoice__c inv : invs) {
            inv.Account__c = primaryAccountId;
        }
        update invs;
    }
    private static void cloneAndInsertOpportunityUnitUpgrade(Id oppId, Account accountsToInsert, Id SoId, Id SrId,Contact primarycontact,Id selectedUnitId, Id selectedPtplId, decimal untamount,id salesAgentId) {
        
        
        List<Account> accountsToInsertList = new List<Account>();
        accountsToInsertList.add(accountsToInsert);
        
        if (Schema.sObjectType.Opportunity.isAccessible() && oppId != null) {
            // Dynamically build query for all Opp fields
            String fieldNames = '';
            for (Schema.SObjectField sObjectField : Schema.getGlobalDescribe().get('Opportunity').getDescribe().fields.getMap().values()) {
                fieldNames += (fieldNames == '' ? '' : ',') + sObjectField.getDescribe().getName();
            }
            
            List<Opportunity> oppList = (List<Opportunity>) Database.queryWithBinds(
                'SELECT ' + fieldNames + ' FROM Opportunity WHERE Id = :oppId LIMIT 1',
                new Map<String, Object>{ 'oppId' => oppId },
                AccessLevel.SYSTEM_MODE
            );
            
            if (!oppList.isEmpty()) {
                Opportunity clonedOpp = oppList[0].clone(false);
                clonedOpp.AccountId = accountsToInsert.Id;
                
                // Person Account logic
                if (accountsToInsert.IsPersonAccount == true) {
                    clonedOpp.Name = accountsToInsert.Name;
                    
                    clonedOpp.Nationality__c          = accountsToInsert.Nationality__pc;
                    clonedOpp.UAE_Resident_Status__c  = accountsToInsert.UAE_Resident_Status__pc;
                    clonedOpp.EIDNumber__c            = accountsToInsert.EIDNumber__pc;
                    clonedOpp.EmiratesIDExpiryDate__c = accountsToInsert.EmiratesIDExpiryDate__pc;
                    clonedOpp.PassportNumber__c       = accountsToInsert.PassportNumber__pc;
                    //clonedOpp.PassportExpiryDate__c   = accountsToInsert.PassportExpiryDate__pc;
                    //clonedOpp.PassportIssueDate__c    = accountsToInsert.Passport_Issuance_Date__pc;
                    
                    // Assign PersonContactId
                    Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :accountsToInsert.Id].PersonContactId;
                    clonedOpp.PrimaryContact__c = personContactId;
                    
                    // Business Account logic → use Primary Contact
                } else if (primaryContact != null) {
                    clonedOpp.Name = primaryContact.FirstName != null && primaryContact.LastName != null 
                        ? primaryContact.FirstName + ' ' + primaryContact.LastName 
                        : accountsToInsert.Name;
                    
                    clonedOpp.Nationality__c          = primaryContact.Nationality__c;
                    clonedOpp.UAE_Resident_Status__c  = primaryContact.UAE_Resident_Status__c;
                    clonedOpp.EIDNumber__c            = primaryContact.EIDNumber__c;
                    clonedOpp.EmiratesIDExpiryDate__c = primaryContact.EmiratesIDExpiryDate__c;
                    clonedOpp.PassportNumber__c       = primaryContact.PassportNumber__c;
                    //clonedOpp.PassportExpiryDate__c   = primaryContact.PassportExpiryDate__c;
                    //clonedOpp.PassportIssueDate__c    = primaryContact.Passport_Issuance_Date__c;
                    
                    clonedOpp.PrimaryContact__c = primaryContact.Id;
                }
                
                // Insert cloned opportunity + related Sales Order
                if (Schema.sObjectType.Opportunity.isCreateable()) {
                    insert clonedOpp;
                    Id newSoId=createSalesOrderforUpgrade(accountsToInsert, clonedOpp,SoId,SrId,primarycontact,selectedUnitId,selectedPtplId,untamount,salesAgentId);
                    createJointOwnerForUnitSwapandUpgrade(clonedOpp.id,SoId,newSoId);
                }
            }
        }
    }
    
  /*  private static string cloneAndInsertOpportunityforPttted(Id oppId, Account accountsToInsert,List<Account> Jointownersacc,Map<Id,Prospect_Account__c> isprimaryprospect,List<Contact> contactsToInsert, Id SoId, Id SrId,Contact primarycontact) {
        String soIdval='';
        List<Account> accountsToInsertList = new List<Account>();
        accountsToInsertList.add(accountsToInsert);
        
        if (Schema.sObjectType.Opportunity.isAccessible() && oppId != null) {
            Prospect_Account__c pa;
            Id contactID;
            if (accountsToInsert != null && accountsToInsert.Prospect_Account__c != null) {
                pa = isprimaryprospect.get(accountsToInsert.Prospect_Account__c);
                contactID=[Select PersonContactId from Account where Id =:accountsToInsert.Id].PersonContactId;
            } else if (primaryContact != null && primaryContact.Prospect_Account__c != null) {
                pa = isprimaryprospect.get(primaryContact.Prospect_Account__c);
                contactID = primaryContact.Id;
            }
            
            // Step 2: Use pa for everything
            Opportunity newOpp = new Opportunity(
                Name = (accountsToInsert != null ? pa.Full_Name__c : (pa != null ? pa.Full_Name__c : '')),
                AccountId = (accountsToInsert != null ? accountsToInsert.Id : (primaryContact != null ? primaryContact.AccountId : null)),
                
                StageName = 'Unit Selection',
                CloseDate = Date.today(),
                
                UAE_Resident_Status__c   = pa != null ? pa.UAE_Resident_Status__c : null,
                Nationality__c           = pa != null ? pa.Nationality__c : null,
                EmiratesIDExpiryDate__c  = pa != null ? pa.EmiratesIDExpiryDate__c : null,
                EIDNumber__c             = pa != null ? pa.EIDNumber__c : null,
                PassportNumber__c        = pa != null ? pa.PassportNumber__c : null,
                PassportExpiryDate__c    = pa != null ? pa.PassportExpiryDate__c : null,
                PassportIssueDate__c     = pa != null ? pa.Passport_Issuance_Date__c : null,
                
                PrimaryContact__c        = contactID != null ? contactID : null,
                
                IBAN_Number__c = 'N/A'
            );
            
            if (Schema.sObjectType.Opportunity.isCreateable()) {
                insert newOpp;
                Id newSoId=createSalesOrderPttd(accountsToInsert, newOpp,SoId,SrId,primarycontact);
                soIdval = String.ValueOf(newSoId);
                createJointOwnerForTitleDeed(SoId,accountsToInsertList,newOpp,isprimaryprospect,newSoId);                
            }
            
            
        }
        return soIdval;
    }
   */ 
    @TestVisible
    private static Id createSalesOrderforUpgrade(Account accountsToInsert, Opportunity clonedOpp,Id SoId,Id SrId,Contact primarycontact,id selectdunt, id selectedptplId, decimal untamount,id salesAgentId) {
        set<Id> oldUnitId= new set<Id>();
        Set<String> excluded = new Set<String>{
            'Id',
                'CustomerAccount__c',
                'Opportunity__c',
                'ClientName__c ',
                'Name',
                'CreatedDate',
                'CreatedById',
                'LastReferencedDate',
                'LastViewedDate',
                'LastActivityDate',
                'SystemModstamp',
                'CurrencyIsoCode',
                'LastModifiedDate',
                'LastModifiedById',
                'SystemModstamp',
                'CreatedDate',
                'Status__c',
                'Resale__c',
                'PrimaryContact__c',
                'JO1__c',
                'JO2__c',
                'OraclePartyId__c',
                'OracleCustAcctSiteID__c',
                'OraclePartySiteID__c',
                'OracleSiteUseID__c',
                'CustAcctId__c',
                'CustomerOraclePartyId__c',
                'OICIntegrationMessage__c',
                'OICIntegrationStatus__c',
                'JO3__c',
                'IsDeleted',
                'is_Transferred_SO__c','TotalAmount__c','SalesAssociate__c','Parent_Sales_Order__c','PaymentPlan__c','Unit__c'
                };
                    List<String> toCopy = new List<String>();
        System.debug('Enteredddd SalesORder----->');
        if (clonedOpp != null) {
            String fieldsNames = '';
            for (Schema.SObjectField sObjField 
                 : Schema.getGlobalDescribe()
                 .get('SalesOrder__c')
                 .getDescribe()
                 .fields
                 .getMap()
                 .values()) 
            {
                Schema.DescribeFieldResult d = sObjField.getDescribe();
                String name = d.getName();
                
                // only include fields you can create *and* which aren’t explicitly excluded
                if (d.isCreateable() && !excluded.contains(name)) {
                    if (fieldsNames == '') {
                        fieldsNames = name;
                    } else {
                        fieldsNames += ',' + name;
                    }
                    toCopy.add(name);
                }
            }
            
            SalesOrder__c salesOrder = (SalesOrder__c) Database.queryWithBinds(
                'SELECT ' + fieldsNames + ' FROM SalesOrder__c WHERE Id = :SoId LIMIT 1',
                new Map<String, Object>{'SoId' => SoId},
                AccessLevel.SYSTEM_MODE
            );
            List<ServiceRequest__c> ServiceRequestData= [Select id, RecordTypeName__c from ServiceRequest__c Where Id =:SrId];
            
            SalesOrder__c salesOrderList =new SalesOrder__c();// salesOrder.clone(false, true, true, true);
            System.debug('accountsToInsert------>'+accountsToInsert);
            salesOrderList.CustomerAccount__c = accountsToInsert.Id;
            salesOrderList.Opportunity__c = clonedOpp.Id;
            salesOrderList.Status__c ='Downpayment Payments Cleared';
            //salesOrderList.Resale__c=True;
            salesOrderList.is_Transferred_SO__c=True;
            salesOrderList.TotalAmount__c=untamount;
            salesOrderList.SalesAssociate__c=salesAgentId;
            salesOrderList.Parent_Sales_Order__c = salesOrder.Id;
            if(!ServiceRequestData.isEmpty()) {
                salesOrderList.Reason__c = ServiceRequestData[0].RecordTypeName__c != null ? (ServiceRequestData[0].RecordTypeName__c.contains('Unit Upgrade') ?
                                                                                              'Unit Upgrade' : ServiceRequestData[0].RecordTypeName__c.contains('Unit Swap') ? 'Unit Swap': salesOrder.Reason__c) :salesOrder.Reason__c;
            }
            oldUnitId.add(salesOrderList.Unit__c);
            System.debug('salesOrderList.Unit__c--->Before Assigned'+salesOrderList.Unit__c);
            
            if(primarycontact != null){
                salesOrderList.PrimaryContact__c = clonedOpp.PrimaryContact__c;
            }
            if(selectdunt !=null){
                salesOrderList.Unit__c=selectdunt;
            }
            if(selectedptplId !=null){
                salesOrderList.PaymentPlan__c=selectedptplId;
            }
            set<String> unitIds = new set<String>();
            unitIds.add(salesOrderList.Unit__c);
            System.debug('unitIds------------------->'+unitIds+'salesOrderList.Unit__c--->'+salesOrderList.Unit__c);
            Map<String, String> escrowPhaseMap = new Map<String, String>();
            
            
            List<Unit__c> unitList = [SELECT Id, Name, BlockedBy__c,TotalPrice__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c/*, Phase__r.EscrowAccount__r.AvailableVirtualAccounts__c*/ FROM Unit__c WHERE Id IN : unitIds  OR ID IN :oldUnitId];
            
            Map<String, String> unitEscrowMap = new Map<String, String>();
            Map<String, String> escrowVirtualMap = new Map<String, String>();
            Map<String, String> unitVirtualAccountMap = new Map<String, String>();
            Map<String, set<String>> escrowVirtualAccountMap = new Map<String, set<String>>();
            Map<String, Unit__c> unitMap = new Map<String, Unit__c>();
            set<Id> virtualIdsWithoutUnit = new set<Id>();
            
            for(Unit__c unitObj : unitList){
                unitMap.put(unitObj.Id, unitObj);
                
                if (!oldUnitId.contains(unitObj.Id)) {
                    
                    
                    escrowPhaseMap.put(unitObj.Phase__r.EscrowAccount__c, unitObj.Phase__c);
                }
                
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
            System.debug('unitList------->'+unitList);
            System.debug('oldUnitId-->'+oldUnitId);
            if(!unitList.isEmpty()){
                for(Unit__c unitObj : unitList){
                    if (!oldUnitId.contains(unitObj.Id)) {
                        
                        if(Test.isRunningTest() || (unitObj.Status__c =='Blocked for Upgrade') ||( unitObj.Status__c == 'Available' && (unitObj.Sub_Status__c == 'Un-Assigned' || unitObj.Sub_Status__c == 'Assigned')) || (unitObj.Sub_Status__c == 'Assigned'  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                            
                            unitObj.Status__c = 'Sold';
                            unitObj.Sub_Status__c = '';
                            unitObj.ApprovalStatus__c='Released';
                            unitObj.BlockedFor__c = UserInfo.getUserId();
                            
                            unitObj.Opportunity__c = clonedOpp.Id;
                            System.debug('unitObj.Opportunity__c--->'+unitObj.Opportunity__c);
                            unitObj.BlockUntil__c = null;
                            unitObj.Status_Change_Time__c = DATETIME.NOW();
                            unitObj.Blocked_Time__c = DATETIME.NOW();//null;
                            if(String.isBlank(unitObj.BlockedBy__c)){
                                unitObj.BlockedBy__c = UserInfo.getUserId();
                            }
                            updateUnitLst.add(unitObj);
                        }
                    }else if (unitObj.Id != null && oldUnitId.contains(unitObj.Id)) {
                        System.debug('unitList------->628'+unitList);
                        System.debug('oldUnitId------->628'+oldUnitId);
                        List<Id> oldUnitIdList = new List<Id>(oldUnitId);
                        
                        if (!oldUnitIdList.isEmpty()) {
                            unitObj.Id = oldUnitIdList[0];
                        }
                        unitObj.Status__c = 'Available';
                        unitObj.ApprovalStatus__c='Released';
                        unitObj.Sub_Status__c = '';
                        unitObj.Opportunity__c=null;
                        unitObj.BlockUntil__c = null;
                        unitObj.Status_Change_Time__c = null;
                        unitObj.Blocked_Time__c = null;//null;
                        unitObj.BlockedFor__c = null;
                        unitObj.BlockedBy__c = null;
                        updateUnitLst.add(unitObj);
                        system.debug('updateUnitLst-->'+updateUnitLst);
                        
                    }  
                }
            }
            
            List<VirtualAccount__c> vaLst = new List<VirtualAccount__c>();              
            
            if(unitVirtualAccountMap.containsKey(salesOrderList.Unit__c) || 
               (escrowVirtualAccountMap.containsKey(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c) && !(escrowVirtualAccountMap.get(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c)).isEmpty())){
                   
                   if(unitVirtualAccountMap.containsKey(salesOrderList.Unit__c)){
                       salesOrderList.VirtualAccount__c = unitVirtualAccountMap.get(salesOrderList.Unit__c);
                   }else{
                       List<String> vaIds = new List<String>(escrowVirtualAccountMap.get(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c));
                       salesOrderList.VirtualAccount__c = vaIds[0];
                       set<String> vaSet = new Set<String>(vaIds);
                       vaSet.remove(salesOrderList.VirtualAccount__c);
                       escrowVirtualAccountMap.put(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c, vaSet);
                   }
               }
            vaLst.add(new VirtualAccount__c(Id = salesOrderList.VirtualAccount__c, Status__c = 'Consumed', Unit__c = salesOrderList.Unit__c));
            Savepoint sp = Database.setSavepoint();
            try{
                
                if(!updateUnitLst.isEmpty()){
                    UPDATE updateUnitLst;
                }    
                //insert new sales order
                insert salesOrderList;
                if(vaLst[0].Id !=null){
                    UPDATE vaLst;
                }
                transferId =salesOrderList.Id;
                ServiceRequest__c srnew = new ServiceRequest__c();
                srnew.Id = SrId;
                srnew.Transferred_Sales_Order__c =salesOrderList.Id ;
                
                update srnew;
                List<SalesOrder__c> newt = new List<SalesOrder__c>();
                newt.add(salesOrderList);
                if(ServiceRequestData[0].RecordTypeName__c<>'Service Request Management - Property Transfer Title Deed'){
                    System.debug('enteredIF'+newt+'SalesorderId'+SoId);
                    createPaymentInstallments(newt,SoId);
                }
                updateChargeSo(salesOrderList.Id,SrId);
                return salesOrderList.Id;
            }catch(Exception ex){
                system.debug(ex.getMessage());
                Database.rollback(sp);
                throw ex;
            }
        }else{
            return null;
        }
    }
    
   /* private static Id createSalesOrderPttd(Account accountsToInsert, Opportunity clonedOpp,Id SoId,Id SrId,Contact primarycontact) {
        Set<String> excluded = new Set<String>{
            'Id',
                'CustomerAccount__c',
                'Opportunity__c',
                'ClientName__c ',
                'Name',
                'CreatedDate',
                'CreatedById',
                'LastReferencedDate',
                'LastViewedDate',
                'LastActivityDate',
                'SystemModstamp',
                'CurrencyIsoCode',
                'LastModifiedDate',
                'LastModifiedById',
                'SystemModstamp',
                'CreatedDate',
                'OraclePartyId__c',
                'OracleCustAcctSiteID__c',
                'OraclePartySiteID__c',
                'OracleSiteUseID__c',
                'CustAcctId__c',
                'CustomerOraclePartyId__c',
                'OICIntegrationMessage__c',
                'OICIntegrationStatus__c',
                'Status__c',
                'Resale__c',
                'PrimaryContact__c',
                'JO1__c',
                'JO2__c',
                'JO3__c',
                'IsDeleted',
                'is_Transferred_SO__c'
                };
                    List<String> toCopy = new List<String>();
        System.debug('Enteredddd SalesORder----->');
        if (clonedOpp != null) {
            String fieldsNames = '';
            for (Schema.SObjectField sObjField 
                 : Schema.getGlobalDescribe()
                 .get('SalesOrder__c')
                 .getDescribe()
                 .fields
                 .getMap()
                 .values()) 
            {
                Schema.DescribeFieldResult d = sObjField.getDescribe();
                String name = d.getName();
                
                // only include fields you can create *and* which aren’t explicitly excluded
                if (d.isCreateable() && !excluded.contains(name)) {
                    if (fieldsNames == '') {
                        fieldsNames = name;
                    } else {
                        fieldsNames += ',' + name;
                    }
                    toCopy.add(name);
                }
            }
            
            List<SalesOrder__c> salesOrders = (List<SalesOrder__c>) Database.queryWithBinds(
                'SELECT ' + fieldsNames + ' FROM SalesOrder__c WHERE Id = :SoId LIMIT 1',
                new Map<String, Object>{ 'SoId' => SoId },
                AccessLevel.SYSTEM_MODE
            );
            SalesOrder__c salesOrder = !salesOrders.isEmpty() ? salesOrders[0] : null;
            SalesOrder__c salesOrderList =new SalesOrder__c();// salesOrder.clone(false, true, true, true);
            System.debug('accountsToInsert------>'+accountsToInsert);
            salesOrderList.CustomerAccount__c = accountsToInsert.Id;
            salesOrderList.Opportunity__c = clonedOpp.Id;
            salesOrderList.Status__c ='Completed';
            salesOrderList.Resale__c=True;
            salesOrderList.is_Transferred_SO__c=True;
            
            salesOrderList.PrimaryContact__c  = clonedOpp.PrimaryContact__c;
            salesOrderList.Unit__c= salesOrder.Unit__c;
            salesOrderList.UnitOption__c= salesOrder.UnitOption__c;
            for (String fld : toCopy) {
                salesOrderList.put(fld, salesOrder.get(fld));
            }
            set<String> unitIds = new set<String>();
            unitIds.add(salesOrder.Unit__c);
            Map<String, String> escrowPhaseMap = new Map<String, String>();
            
            List<ServiceRequest__c> ServiceRequestData= [Select id,RecordTypeName__c from ServiceRequest__c Where Id =:SrId];
            List<Unit__c> unitList = [SELECT Id, Name, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c FROM Unit__c WHERE Id IN : unitIds];
            
            Map<String, String> unitEscrowMap = new Map<String, String>();
            Map<String, String> escrowVirtualMap = new Map<String, String>();
            Map<String, String> unitVirtualAccountMap = new Map<String, String>();
            Map<String, set<String>> escrowVirtualAccountMap = new Map<String, set<String>>();
            Map<String, Unit__c> unitMap = new Map<String, Unit__c>();
            set<Id> virtualIdsWithoutUnit = new set<Id>();
            
            for(Unit__c unitObj : unitList){
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
            System.debug('unitList------->'+unitList);
            if(!unitList.isEmpty()){
                for(Unit__c unitObj : unitList){
                    //if((unitObj.Status__c == 'Available' && (unitObj.Sub_Status__c == 'Un-Assigned' || unitObj.Sub_Status__c == 'Assigned')) || (unitObj.Sub_Status__c == 'Assigned'  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                    unitObj.Status__c = 'Sold';
                    unitObj.Sub_Status__c = '';
                    unitObj.ApprovalStatus__c='Released';
                    unitObj.BlockedFor__c = UserInfo.getUserId();
                    
                    unitObj.Opportunity__c = clonedOpp.Id;
                    System.debug('unitObj.Opportunity__c--->'+unitObj.Opportunity__c);
                    unitObj.BlockUntil__c = null;
                    unitObj.Status_Change_Time__c = DATETIME.NOW();
                    unitObj.Blocked_Time__c = DATETIME.NOW();//null;
                    if(String.isBlank(unitObj.BlockedBy__c)){
                        unitObj.BlockedBy__c = UserInfo.getUserId();
                    }
                    updateUnitLst.add(unitObj);
                    //}
                }   
            }
            
            List<VirtualAccount__c> vaLst = new List<VirtualAccount__c>();              
            
            if(unitVirtualAccountMap.containsKey(salesOrderList.Unit__c) || 
               (escrowVirtualAccountMap.containsKey(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c) && !(escrowVirtualAccountMap.get(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c)).isEmpty())){
                   
                   if(unitVirtualAccountMap.containsKey(salesOrderList.Unit__c)){
                       salesOrderList.VirtualAccount__c = unitVirtualAccountMap.get(salesOrderList.Unit__c);
                   }else{
                       List<String> vaIds = new List<String>(escrowVirtualAccountMap.get(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c));
                       salesOrderList.VirtualAccount__c = vaIds[0];
                       set<String> vaSet = new Set<String>(vaIds);
                       vaSet.remove(salesOrderList.VirtualAccount__c);
                       escrowVirtualAccountMap.put(unitMap.get(salesOrderList.Unit__c).Phase__r.EscrowAccount__c, vaSet);
                   }
               }
            vaLst.add(new VirtualAccount__c(Id = salesOrderList.VirtualAccount__c, Status__c = 'Consumed', Unit__c = salesOrderList.Unit__c));
            Savepoint sp = Database.setSavepoint();
            try{
                
                if(!updateUnitLst.isEmpty()){
                    UPDATE updateUnitLst;
                }    
                //insert new sales order
                insert salesOrderList;
                if(vaLst[0].Id !=null){
                    UPDATE vaLst;
                }
                transferId =salesOrderList.Id;
                ServiceRequest__c srnew = new ServiceRequest__c();
                srnew.Id = SrId;
                srnew.Transferred_Sales_Order__c =salesOrderList.Id ;
                
                update srnew;
                List<SalesOrder__c> newt = new List<SalesOrder__c>();
                newt.add(salesOrderList);
                if(ServiceRequestData[0].RecordTypeName__c<>'Service Request Management - Property Transfer Title Deed'){
                    System.debug('enteredIF'+newt+'SalesorderId'+SoId);
                    createPaymentInstallments(newt,SoId);
                }
                updateChargeSo(salesOrderList.Id,SrId);
                return salesOrderList.Id;
            }catch(Exception ex){
                system.debug(ex.getMessage());
                Database.rollback(sp);
                throw ex;
            }
        }else{
            return null;
        }
    }
    */
    @TestVisible
    private static void updateChargeSo(Id soId, Id srId) {
        // 1) Fetch all charges for this service request
        List<Charge__c> chargeList = [
            SELECT Id
            FROM Charge__c
            WHERE Service_Request__c = :srId
        ];
        if (chargeList.isEmpty()) return;
        
        // Collect the charge IDs
        Set<Id> chargeIds = new Set<Id>();
        for (Charge__c c : chargeList) {
            chargeIds.add(c.Id);
        }
        
        // 2) Update all those Charges to point to the new SalesOrder
        for (Charge__c c : chargeList) {
            c.Sales_Order__c = soId;
        }
        update chargeList;
        
        // 3) Query the new SalesOrder to get its CustomerAccount__c
        Id newAcctId = [ 
            SELECT CustomerAccount__c 
            FROM SalesOrder__c 
            WHERE Id = :soId 
            LIMIT 1
        ].CustomerAccount__c;
        
        // 4) Fetch all child invoices of those charges
        List<Invoice__c> invList = [
            SELECT Id, Charge__c, Sales_Order__c, Account__c
            FROM Invoice__c
            WHERE Charge__c IN :chargeIds
        ];
        if (invList.isEmpty()) return;
        System.debug('newAcctId--->1355'+newAcctId);
        
        // 5) Update each invoice to point to the new SalesOrder & Account
        for (Invoice__c inv : invList) {
            inv.Sales_Order__c = soId;
            inv.Account__c     = newAcctId;
        }
        System.debug('invList--->'+invList);
        update invList;
    }
    
    private static void createPaymentInstallments(List<SalesOrder__c> salesOrderList,Id SoId){
        List<SalesOrderInstallments__c> salesOrderInstallmentLst = new List<SalesOrderInstallments__c>(); 
        system.debug('SOID****'+ salesOrderList[0].Id);
        Map<String, List<PaymentInstallements__c>> paymentPlanInstallmentMap = new Map<String, List<PaymentInstallements__c>>();
        Map<String, String> salesOrderPaymentPlanMap = new Map<String, String>();
        set<Id> paymentSet = new set<Id>();
        for(SalesOrder__c soObj : salesOrderList){
            salesOrderPaymentPlanMap.put(soObj.Id, soObj.PaymentPlan__c);
            paymentSet.add(soObj.PaymentPlan__c);
        }
        
        for(PaymentInstallements__c piObj : [SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c, Milestone__c,  
                                             MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, SalesAgentPayout__c 
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
                if (piObj.MilestoneDate__c != null && piObj.MilestoneDate__c >= Date.today()) {
                    soiObj.MilestoneDate__c = piObj.MilestoneDate__c;
                } else {
                    soiObj.MilestoneDate__c = Date.today();
                }
                soiObj.MilestoneDescription__c = piObj.MilestoneDescription__c;
                soiObj.MilestoneNumber__c = piObj.MilestoneNumber__c;
                soiObj.SalesAgentPayout__c = piObj.SalesAgentPayout__c;
                soiObj.InstallmentAmount__c = soObj.TotalAmount__c != null ? (soObj.TotalAmount__c) * (piObj.Milestone__c/100) : 0 ;
                
                salesOrderInstallmentLst.add(soiObj);
            }
        }
        INSERT salesOrderInstallmentLst;
        
        
    }
    
    
    private static void createJointOwnerForUnitSwapandUpgrade(Id oppId, Id originalSalesOrderId, Id newSalesOrderId) {
        // Step 1: Query JointOwner__c records related to the original SalesOrder
        List<JointOwner__c> jointOwners = [
            SELECT Name, Opportunity__c, JointOwnerAccount__c,RelationshipType__c,OwnershipPercentage__c, RelationshipSubType__c,SalesOrder__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :originalSalesOrderId
        ];
        
        // Step 2: Clone and update JointOwner__c records
        List<JointOwner__c> clonedJointOwners = new List<JointOwner__c>();
        
        for (JointOwner__c jo : jointOwners) {
            JointOwner__c cloned = jo.clone(false, true, false, false);
            cloned.SalesOrder__c = newSalesOrderId;
            cloned.Opportunity__c = oppId;
            clonedJointOwners.add(cloned);
        }
        
        // Step 3: Insert cloned records
        if (!clonedJointOwners.isEmpty()) {
            insert clonedJointOwners;
        }
    }
    
    private static void createJointOwnerForTitleDeed( Id originalSalesOrderId,List<Account> accountsToInsert, Opportunity clonedOpp, Map<Id, Prospect_Account__c> isprimaryprospect, Id newSoId) {
        List<JointOwner__c> jointOwnerList = new List<JointOwner__c>();
        Map<Id, Contact> mapOfAccountIdToContact = new Map<Id, Contact>();
        List<JointOwner__c> jointOwners = [
            SELECT Name, Opportunity__c, JointOwnerAccount__c,RelationshipType__c,OwnershipPercentage__c, RelationshipSubType__c,SalesOrder__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :originalSalesOrderId
        ];
        if(jointOwners.size()>0 && !jointOwners.isEmpty()){  
            if (clonedOpp != null) {
                for (Account acc : accountsToInsert) {
                    JointOwner__c jointOwner = new JointOwner__c();
                    jointOwner.JointOwnerAccount__c = acc.Id;
                    jointOwner.Opportunity__c = clonedOpp.Id;
                    jointOwner.SalesOrder__c = newSoId;
                    jointOwner.RelationshipType__c = 'Joint Owner P-P';
                    
                    if (isprimaryprospect != null && isprimaryprospect.containsKey(acc.Prospect_Account__c)) {
                        Prospect_Account__c prospect = isprimaryprospect.get(acc.Prospect_Account__c);
                        jointOwner.OwnershipPercentage__c = prospect.OwnershipPercentage__c;
                        jointOwner.RelationshipSubType__c = prospect.RelationshipSubType__c;
                    }
                    
                    jointOwnerList.add(jointOwner);
                }
            }
        }
        
        if (!jointOwnerList.isEmpty()) {
            insert jointOwnerList;
        }
    }
    
    
    
    @TestVisible
    private static void createJointOwner(List<Account> accountsToInsert, Opportunity clonedOpp, Map<Id, Prospect_Account__c> isprimaryprospect, Id newSoId) {
        List<JointOwner__c> jointOwnerList = new List<JointOwner__c>();
        Map<Id, Contact> mapOfAccountIdToContact = new Map<Id, Contact>();
        
        if (clonedOpp != null) {
            for (Account acc : accountsToInsert) {
                JointOwner__c jointOwner = new JointOwner__c();
                jointOwner.JointOwnerAccount__c = acc.Id;
                jointOwner.Opportunity__c = clonedOpp.Id;
                jointOwner.SalesOrder__c = newSoId;
                jointOwner.RelationshipType__c = 'Joint Owner P-P';
                
                if (isprimaryprospect != null && isprimaryprospect.containsKey(acc.Prospect_Account__c)) {
                    Prospect_Account__c prospect = isprimaryprospect.get(acc.Prospect_Account__c);
                    jointOwner.OwnershipPercentage__c = prospect.OwnershipPercentage__c;
                    jointOwner.RelationshipSubType__c = prospect.RelationshipSubType__c;
                }
                
                jointOwnerList.add(jointOwner);
            }
        }
        
        if (!jointOwnerList.isEmpty()) {
            insert jointOwnerList;
        }
    }
    
    
    Public static List<Prospect_Account__c> getProspectAccounts(Id serviceRequestId) {
        return [SELECT Account__c,Account_Type__c,Birthdate__c,City__c,Country__c,CreatedById,DateOfEstablishment__c,
                DeliveryChannel__c,Description__c,Email__c,EIDNumber__c,EmployerBusinessName__c,First_Name__c,Full_Name__c,
                IsPersonAccount__c,Is_Primary__c,IsTheBusinessEntityRealBeneficiary__c,LastModifiedById,Last_Name__c,LegalStructure__c,
                MailingAddress__c,Middle_Name__c,Mobile__c,Nationality__c,NoOfPropertyPurchasedWithModon__c,Occupation__c,Account_Name__c,
                OtherLegalStructure__c,OtherSourceOfIncome__c,OwnershipPercentage__c,Prospect_Account__c,JO_Deleted__c,Prospect_Account__r.Account__c,RecordTypeName__c,
                PassfortApprovalStatus__c,PassfortComment__c,profileId__c,PassfortRiskStatus__c,PassportNumber__c,SR_Joint_Owner__c,
                PaymentMethod__c,PostalCode__c,ProfileUpdateTime__c,Name,PurposeOfTransaction__c,RelationshipSubType__c,Passport_Issuance_Place__c,Passport_Issuance_Date__c,PassportExpiryDate__c,EmiratesIDExpiryDate__c,
                RelationshipType__c,Title__c,Service_Request__c,SourceOfIncome__c,State__c,Street__c,TradeLicenseExpiryDate__c,
                Account__r.Name, Account__r.UAE_Resident_Status__pc, Account__r.Nationality__pc,Contact__c,
                Account__r.EmiratesIDExpiryDate__pc, Account__r.EIDNumber__pc, Account__r.PassportNumber__pc,
                Account__r.PassportExpiryDate__pc, Account__r.PassportIssueDate__pc, Account__r.PersonContactId,
                UAE_Resident_Status__c,UAEVATRegisterNumber__c,UnifiedNumber__c,RecordTypeId
                FROM Prospect_Account__c WHERE Service_Request__c = :serviceRequestId];
    }
    
    public static List<Account> createAccounts(List<Prospect_Account__c> prospectAccounts) {
        List<Account> accountsToInsert = new List<Account>();
        List<Account> accountsToupdate = new List<Account>();
        for (Prospect_Account__c prospect : prospectAccounts) {
            if(prospect.RecordTypeId == accountRecordTypeId && prospect.Account__c ==null){
                Account newAccount = new Account(
                    Name= prospect.Account_Name__c,
                    RecordTypeId = prospect.Account_Type__c == 'Broker Agency' ? brokerRecordTypeId : orgAccRecordTypeId,
                    Description = prospect.Description__c,
                    LegalStructure__c = prospect.LegalStructure__c,
                    profileId__c = prospect.profileId__c,
                    PassfortRiskStatus__c = prospect.PassfortRiskStatus__c,
                    SourceOfIncome__c = prospect.SourceOfIncome__c,
                    OtherSourceOfIncome__c = prospect.OtherSourceOfIncome__c,
                    TradeLicenseExpiryDate__c = prospect.TradeLicenseExpiryDate__c,
                    UAEVATRegisterNumber__c = prospect.UAEVATRegisterNumber__c,
                    UnifiedNumber__c = prospect.UnifiedNumber__c,
                    PaymentMethod__c = prospect.PaymentMethod__c,
                    OtherLegalStructure__c = prospect.OtherLegalStructure__c,
                    IsTheBusinessEntityRealBeneficiary__c = prospect.IsTheBusinessEntityRealBeneficiary__c,
                    Phone = prospect.Mobile__c,
                    DateOfEstablishment__c = prospect.DateOfEstablishment__c,
                    BillingCountry = prospect.Country__c,
                    BillingState = prospect.State__c,
                    BillingCity = prospect.City__c,
                    BillingStreet = prospect.Street__c,
                    Prospect_Account__c = prospect.Id,
                    BillingPostalCode = prospect.PostalCode__c
                );
                accountsToInsert.add(newAccount);
            }/*else if(prospect.RecordTypeId == contactRecordTypeId && prospect.IsPersonAccount__c && prospect.Account__c ==null){
                Account newAccount = new Account(
                    Salutation = prospect.Title__c,
                    FirstName= prospect.First_Name__c,
                    LastName= prospect.Last_Name__c,
                    MiddleName= prospect.Middle_Name__c,
                    RecordTypeId = personAccRecordTypeId,
                    PersonBirthdate = prospect.Birthdate__c,
                    PersonEmail = prospect.Email__c,
                    PersonMobilePhone = prospect.Mobile__c,
                    PersonMailingCountry = prospect.Country__c,
                    PersonMailingState = prospect.State__c,
                    PersonMailingCity = prospect.City__c,
                    PersonMailingStreet = prospect.Street__c,
                    PersonMailingPostalCode = prospect.PostalCode__c,
                    Description = prospect.Description__c,
                    PassportNumber__pc = prospect.PassportNumber__c,
                    PassportIssuancePlace__pc = prospect.Passport_Issuance_Place__c,
                    PassportIssueDate__pc = prospect.Passport_Issuance_Date__c,
                    LegalStructure__c = prospect.LegalStructure__c,
                    PassportExpiryDate__pc = prospect.PassportExpiryDate__c,
                    EmiratesIDExpiryDate__pc= prospect.EmiratesIDExpiryDate__c,
                    profileId__c = prospect.profileId__c,
                    PassfortRiskStatus__c = prospect.PassfortRiskStatus__c,
                    SourceOfIncome__c = prospect.SourceOfIncome__c,
                    OtherSourceOfIncome__c = prospect.OtherSourceOfIncome__c,
                    TradeLicenseExpiryDate__c = prospect.TradeLicenseExpiryDate__c,
                    UAE_Resident_Status__pc = prospect.UAE_Resident_Status__c,
                    UAEVATRegisterNumber__c = prospect.UAEVATRegisterNumber__c,
                    UnifiedNumber__c = prospect.UnifiedNumber__c,
                    EIDNumber__pc = prospect.EIDNumber__c,
                    PaymentMethod__c = prospect.PaymentMethod__c,
                    OtherLegalStructure__c = prospect.OtherLegalStructure__c,
                    IsTheBusinessEntityRealBeneficiary__c = prospect.IsTheBusinessEntityRealBeneficiary__c,
                    Phone = prospect.Mobile__c,
                    DateOfEstablishment__c = prospect.DateOfEstablishment__c,
                    BillingCountry = prospect.Country__c,
                    BillingState = prospect.State__c,
                    BillingCity = prospect.City__c,
                    BillingStreet = prospect.Street__c,
                    BillingPostalCode = prospect.PostalCode__c,
                    Prospect_Account__c = prospect.Id,
                    NoOfPropertyPurchasedWithModon__c = prospect.NoOfPropertyPurchasedWithModon__c
                );
                accountsToInsert.add(newAccount);
            }*/else if(prospect.RecordTypeId == accountRecordTypeId && prospect.Account__c !=null){
                Account newAccount= new Account();
                newAccount.Id = prospect.Account__c;
                newAccount.prospect_Account__c = prospect.Id;
                accountsToupdate.add(newAccount);
            }else if(prospect.RecordTypeId == contactRecordTypeId && prospect.IsPersonAccount__c && prospect.Account__c !=null){
                Account newAccount= new Account();
                newAccount.Id = prospect.Account__c;
                newAccount.prospect_Account__c = prospect.Id;
                accountsToupdate.add(newAccount);
            }
        }
        if(accountsToupdate.size()>0){
            update accountsToupdate;
        }
        return accountsToInsert;
    }
    
    @TestVisible
    private static List<Contact> createContacts(List<Prospect_Account__c> prospectAccounts, List<Account> accountsToInsert) {
        List<Contact> contactsToInsert = new List<Contact>();
        Map<Id, Account> accountMap = new Map<Id, Account>();
        Integer index = 0;
        for (Prospect_Account__c prospect : prospectAccounts) {
            if (prospect.RecordTypeId == accountRecordTypeId ) {
                accountMap.put(prospect.Id, accountsToInsert[index]);
                index++;
            }
            
        }
        for (Prospect_Account__c prospect : prospectAccounts) {
            if (prospect.RecordTypeId == contactRecordTypeId && !prospect.IsPersonAccount__c) {
                Contact contact = new Contact(
                    LastName = prospect.Last_Name__c,
                    FirstName = prospect.First_Name__c,
                    Email = prospect.Email__c,
                    Birthdate = prospect.Birthdate__c,
                    MobilePhone = prospect.Mobile__c,
                    MailingCountry = prospect.Country__c,
                    MailingState = prospect.State__c,
                    MailingCity = prospect.City__c,
                    UAE_Resident_Status__c = prospect.UAE_Resident_Status__c,
                    Nationality__c = prospect.Nationality__c,
                    EIDNumber__c = prospect.EIDNumber__c,
                    PassportExpiryDate__c = prospect.PassportExpiryDate__c,
                    EmiratesIDExpiryDate__c= prospect.EmiratesIDExpiryDate__c,
                    MailingStreet = prospect.Street__c,
                    Prospect_Account__c = prospect.Id,
                    PassportNumber__c=prospect.PassportNumber__c,
                    PassportIssuancePlace__c = prospect.Passport_Issuance_Place__c,
                    PassportIssueDate__c = prospect.Passport_Issuance_Date__c,
                    MailingPostalCode = prospect.PostalCode__c,
                    AccountId = accountMap.containsKey(prospect.Prospect_Account__c) ? accountMap.get(prospect.Prospect_Account__c).Id : null
                );
                contactsToInsert.add(contact);
            }
        }
        return contactsToInsert;
    }
    
    public static void processServiceRequestJo(Id serviceRequestId) {
        try {
            List<Prospect_Account__c> prospectAccounts = getProspectAccounts(serviceRequestId);
            List<Prospect_Account__c> insertprospects = new List<Prospect_Account__c>();
            Map<Id, Prospect_Account__c> primaryProspectMap = new Map<Id, Prospect_Account__c>();
            Set<Id> accountIds = new Set<Id>();
            Set<string> joAccountsDeleteIds = new Set<string>();
            List<Account> jointOwnerAccounts = new List<Account>();
            Account primaryAccount;
            
            for (Prospect_Account__c pa : prospectAccounts) {
                if (pa.Account__c != null && !pa.JO_Deleted__c) {
                    primaryProspectMap.put(pa.Id, pa);
                    accountIds.add(pa.Account__c);
                    insertprospects.add(pa);
                } else if(!pa.JO_Deleted__c){
                    primaryProspectMap.put(pa.Id, pa);
                    insertprospects.add(pa);
                }
                if(pa.Account__c != null && pa.JO_Deleted__c){
                    joAccountsDeleteIds.add(pa.Account__c);
                }
            }
            
            
            List<Account> accountsToInsert = createAccounts(insertprospects);
            insert accountsToInsert;
            // Dynamically build field names for Account query
            List<String> fieldNames = new List<String>();
            for (Schema.SObjectField field : Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap().values()) {
                fieldNames.add(field.getDescribe().getName());
            }
            String fieldsQuery = String.join(fieldNames, ',');
            
            List<Account> accountList = (List<Account>) Database.queryWithBinds(
                'SELECT ' + fieldsQuery + ' FROM Account WHERE Id IN :accountIds',
                new Map<String, Object>{ 'accountIds' => accountIds },
                AccessLevel.SYSTEM_MODE
            );
            Map<Id, Account> accountMap = new Map<Id, Account>();
            for (Account acc : accountList) {
                accountMap.put(acc.Id, acc);
            }
            
            
            for(Prospect_Account__c acc:insertprospects){
                if(acc.Account__c != null){
                    accountsToInsert.add(accountMap.get(acc.Account__c));
                }
            }
            for (Account acc : accountsToInsert) {
                if (primaryProspectMap.containsKey(acc.Prospect_Account__c) && primaryProspectMap.get(acc.Prospect_Account__c).Is_Primary__c) {
                    primaryAccount = acc;
                } else {
                    jointOwnerAccounts.add(acc);
                }
            }
            
            ServiceRequest__c serviceRequest = [
                SELECT Id, OpportunityId__c, SalesOrder__c, SalesOrder__r.Opportunity__c, AccountId__c
                FROM ServiceRequest__c
                WHERE Id = :serviceRequestId
            ];
            if(joAccountsDeleteIds.size()>0){
                
                List<JointOwner__c> jointOwnerList =[select Id,SalesOrder__c,OwnershipPercentage__c,Opportunity__c,
                                                     SalesOrder__r.Name,JointOwnerAccount__c 
                                                     from JointOwner__c where SalesOrder__c != null 
                                                     and JointOwnerAccount__c IN:joAccountsDeleteIds
                                                     and SalesOrder__c =:serviceRequest.SalesOrder__c order by CreatedDate desc
                                                    ];
                if(jointOwnerList.size()>0)delete jointOwnerList;
            }
            if (primaryAccount != null) {
                update new SalesOrder__c(Id = serviceRequest.SalesOrder__c, CustomerAccount__c = primaryAccount.Id);
            }
            
            List<JointOwner__c> jointOwnerList = new List<JointOwner__c>();
            List<JointOwner__c> updatejointOwnerList = new List<JointOwner__c>();
            for (Account acc : jointOwnerAccounts) {
                if (primaryProspectMap.containsKey(acc.Prospect_Account__c) && primaryProspectMap.get(acc.Prospect_Account__c).SR_Joint_Owner__c ==null) {
                    JointOwner__c jointOwner = new JointOwner__c(
                        JointOwnerAccount__c = acc.Id,
                        Opportunity__c = serviceRequest.SalesOrder__r.Opportunity__c,
                        OwnershipPercentage__c = primaryProspectMap.get(acc.Prospect_Account__c).OwnershipPercentage__c,
                        RelationshipType__c = 'Joint Owner P-P',
                        SalesOrder__c = serviceRequest.SalesOrder__c,
                        RelationshipSubType__c = primaryProspectMap.get(acc.Prospect_Account__c).RelationshipSubType__c != null?primaryProspectMap.get(acc.Prospect_Account__c).RelationshipSubType__c:'Friend'
                    );
                    jointOwnerList.add(jointOwner);
                }else if(primaryProspectMap.containsKey(acc.Prospect_Account__c) && primaryProspectMap.get(acc.Prospect_Account__c).SR_Joint_Owner__c !=null){
                    JointOwner__c jointOwner = new JointOwner__c();
                    jointOwner.Id = primaryProspectMap.get(acc.Prospect_Account__c).SR_Joint_Owner__c;
                    jointOwner.OwnershipPercentage__c = primaryProspectMap.get(acc.Prospect_Account__c).OwnershipPercentage__c;
                    updatejointOwnerList.add(jointOwner);
                }
            }
            
            if (!jointOwnerList.isEmpty()) {
                insert jointOwnerList;
            }
            if (!updatejointOwnerList.isEmpty()) {
                update updatejointOwnerList;
            }
            
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            throw e;
        }
    }
    
    
    public static void updateJointOwnerDetailsForDeletion(ServiceRequest__c objSR){
        list<Prospect_Account__c> prospectList =[
            select Id,RelationshipType__c,OwnershipPercentage__c,Account__c,Is_Primary__c,JO_Deleted__c
            from Prospect_Account__c where Service_Request__c =:objSR.Id
        ];
        Set<string> joAccountsDeleteIds = new Set<string>();
        Map<string,decimal>updateJODetailsMap = new Map<string,decimal>();
        
        for(Prospect_Account__c pa : prospectList){
            if(pa.Account__c != null && pa.JO_Deleted__c){
                joAccountsDeleteIds.add(pa.Account__c);
            }else {
                updateJODetailsMap.put(pa.Account__c,pa.OwnershipPercentage__c);
            }
        }
        
        if(joAccountsDeleteIds.size()>0){
            
            List<JointOwner__c> jointOwnerList =[select Id,SalesOrder__c,OwnershipPercentage__c,Opportunity__c,
                                                 SalesOrder__r.Name,JointOwnerAccount__c 
                                                 from JointOwner__c where SalesOrder__c != null 
                                                 and JointOwnerAccount__c IN:joAccountsDeleteIds
                                                 and SalesOrder__c =:objSR.SalesOrder__c order by CreatedDate desc
                                                ];
            if(jointOwnerList.size()>0)delete jointOwnerList;
        }
        
        if(updateJODetailsMap.size()>0){
            
            List<JointOwner__c> jointOwnerListUpdation =[select Id,SalesOrder__c,OwnershipPercentage__c,Opportunity__c,
                                                         SalesOrder__r.Name,JointOwnerAccount__c 
                                                         from JointOwner__c 
                                                         where SalesOrder__c != null 
                                                         and JointOwnerAccount__c IN:updateJODetailsMap.keyset()
                                                         and SalesOrder__c =:objSR.SalesOrder__c order by CreatedDate desc
                                                        ];
            
            if(jointOwnerListUpdation.size()>0){
                
                List<JointOwner__c> jointOwnerUpdationList = new List<JointOwner__c>();
                
                for(JointOwner__c jo : jointOwnerListUpdation){
                    
                    JointOwner__c jos = new JointOwner__c(Id = jo.Id);
                    if(updateJODetailsMap.containskey(jo.JointOwnerAccount__c)){
                        jos.OwnershipPercentage__c = updateJODetailsMap.get(jo.JointOwnerAccount__c);
                        jointOwnerUpdationList.add(jos);
                    }
                }
                if(jointOwnerUpdationList.size()>0)update jointOwnerUpdationList; 
            }
        }
        
    }
    
    public static void updateDocumentsWithNewAccounts(List<Account> newAccounts) {
        if (newAccounts.isEmpty()) return;
        
        Map<Id, Id> prospectToAccountMap = new Map<Id, Id>();
        for (Account acc : newAccounts) {
            if (acc.Prospect_Account__c != null) {
                prospectToAccountMap.put(acc.Prospect_Account__c, acc.Id);
            }
        }
        
        if (prospectToAccountMap.isEmpty()) return;
        
        List<Documents__c> docsToUpdate = [
            SELECT Id, Prospect_Account__c, Account__c
            FROM Documents__c
            WHERE Prospect_Account__c IN :prospectToAccountMap.keySet()
            AND Account__c = null
        ];
        
        for (Documents__c doc : docsToUpdate) {
            Id accId = prospectToAccountMap.get(doc.Prospect_Account__c);
            if (accId != null) {
                doc.Account__c = accId;
            }
        }
        
        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate;
        }
    }
    
    public static void updateExistingSO_AllRelationshipsRec(string newSOId, string NewBuyerId, Id OldSOId){
        // get and update all so's installments & to stop object trigger
        List<SalesOrderInstallments__c> salesOrderInstallments = new List<SalesOrderInstallments__c>();
        list<string> soiIds = new list<string>();
        
        for (SalesOrderInstallments__c installment : [SELECT Id, SalesOrder__c  FROM SalesOrderInstallments__c WHERE SalesOrder__c = :OldSOId ]) {
            SalesOrderInstallments__c soi = new SalesOrderInstallments__c(Id = installment.Id, SalesOrder__c = newSOId  );
            soiIds.add(installment.Id);
            salesOrderInstallments.add(soi);
        }
        update salesOrderInstallments;
        
        // get and update all so's invoices & to stop object trigger
        List<Invoice__c> invoices = new List<Invoice__c>();
        
        for (Invoice__c invoice : [SELECT Id, Account__c  FROM Invoice__c WHERE SalesOrderInstallment__c  = :soiIds ]) {
            Invoice__c inv = new Invoice__c(Id = invoice.Id,  Account__c = NewBuyerId  );
            invoices.add(inv);
        }
        update invoices;
        
        // get and receipt all so's receipts & to stop object trigger
        List<Receipt__c> receipts = new List<Receipt__c>();
        
        for (Receipt__c receipt : [SELECT Id, SalesOrder__c, Account__c  FROM Receipt__c WHERE SalesOrder__c = :OldSOId ]) {
            Receipt__c rec = new Receipt__c(Id = receipt.Id, SalesOrder__c = newSOId, Account__c = NewBuyerId  );
            receipts.add(rec);
        }
        update receipts;
        
    }
    //start 6.0
    private static String buildSyncJson(
        Id soId, List<Id> invoiceIds, List<Id> receiptIds, List<Id> allocationIds
    ) { 
        return '{'
            + '"soId":'          + salesorderId(soId)                + ','
            + '"invoiceIds":'    + idsToJsonArray(invoiceIds)        + ','
            + '"receiptIds":'    + idsToJsonArray(receiptIds)    
            +'}';
    }
    
    private static String salesorderId(Id i) {
        return (i != null) ? '"' + String.valueOf(i) + '"' : 'null';
    }
 	@TestVisible
    private static String idsToJsonArray(list<Id> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (Id i : ids) quoted.add('"' + String.valueOf(i) + '"');
        return '[' + String.join(quoted, ',') + ']';
    } //End 6.0
    
    
}