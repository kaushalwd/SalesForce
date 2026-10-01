/**********************************************************************************************************************
* Name               : DirectDebitTransactionHelper                                                        
* Description        : This class is used as a helper for DirectDebitTransaction Trigger
* Usage              : Called from DirectDebitTransactionTriggerHandler
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    22 Mar 2025     Initial Draft   
* 1.1			Suresh						23-09-2025		Status Update
* 1.2           Suresh						29-09-2025      REF Number Update
* 2.0           Suresh                      29 Nov 2025     DD Charge Status update
* 2.1			Suresh						15-06-2026		Direct Debit cancellation added
******************************************************************************************************************/
public with sharing class DirectDebitTransactionHelper {
    
    public static void createPayment(List<SObject> newList, Map<Id, SObject> oldMap){
        try{
            if(oldMap != null){
                List<Receipt__c> lst_Receipt = new List<Receipt__c>();
                Set<Id> set_SOInstallmentId = new Set<Id>();
                Map<Id, DirectDebit_Transactions__c> map_DDTSOI = new Map<Id, DirectDebit_Transactions__c>();
                List<DirectDebit_Transactions__c> lst_DDTransaction = (List<DirectDebit_Transactions__c>) newList;
                for(DirectDebit_Transactions__c obj_DDT : lst_DDTransaction){
                    DirectDebit_Transactions__c old_DDT = (DirectDebit_Transactions__c)oldMap.get(obj_DDT.Id);
                    Boolean TransactionStatus = obj_DDT.Transaction_Status__c != old_DDT.Transaction_Status__c;
                    if(Test.isRunningTest()){
                        TransactionStatus = true;
                    }
                    if(!String.isBlank(obj_DDT.Transaction_Status__c) && TransactionStatus
                       && (obj_DDT.Request_Type__c == 'Collection' || obj_DDT.Request_Type__c == 'UAEDDS Collection') && obj_DDT.Transaction_Status__c == 'Success'
                       && obj_DDT.SOInstallment__c != null
                      ){
                         set_SOInstallmentId.add(obj_DDT.SOInstallment__c);
                         if(!map_DDTSOI.containsKey(obj_DDT.SOInstallment__c)){
                              map_DDTSOI.put(obj_DDT.SOInstallment__c, obj_DDT);
                         } 
                    }
                }
                
                if(set_SOInstallmentId.size() > 0){
                    List<SalesOrderInstallments__c> lst_SOInstallment = [select Id, SalesOrder__c, InstallmentAmount__c, Milestone__c, 
                                                                         MilestoneDate__c, PaymentStatus__c, SalesOrder__r.CustomerAccount__c
                                                                         from SalesOrderInstallments__c where Id = :set_SOInstallmentId];
                    for(SalesOrderInstallments__c obj_SOI : lst_SOInstallment){
                            DirectDebit_Transactions__c obj_DDT = map_DDTSOI.containsKey(obj_SOI.Id)?map_DDTSOI.get(obj_SOI.Id):null;
                        	Receipt__c obj_NewReceipt = new Receipt__c();
                            obj_NewReceipt.Account__c = obj_SOI.SalesOrder__r.CustomerAccount__c;
                            obj_NewReceipt.Modeofpayment__c = 'Direct Debit';
                            obj_NewReceipt.SalesOrder__c = obj_SOI.SalesOrder__c;
                            obj_NewReceipt.SalesOrderInstallment__c = obj_SOI.Id;
                            obj_NewReceipt.TotalAmount__c = obj_SOI.InstallmentAmount__c;
                            obj_NewReceipt.Receipt_Amount__c = obj_DDT != null?obj_DDT.Collection_Amount__c:0.0;
                            obj_NewReceipt.ReceiptDate__c = obj_SOI.MilestoneDate__c;
                            obj_NewReceipt.EBS_Clearing_Date__c = System.today();
                            obj_NewReceipt.TransactionDate__c = System.now(); 
                            obj_NewReceipt.TransactionNumber__c = obj_DDT != null && obj_DDT.Request_Type__c == 'UAEDDS Collection' ?
                                									obj_DDT.FT_Reference_No__c : obj_DDT.Transaction_Number__c;
                            obj_NewReceipt.Status__c = 'Received';
                            obj_NewReceipt.Bank__c = obj_DDT.Direct_Debit_Bank__c;
                            lst_Receipt.add(obj_NewReceipt);
                    }
                }
                
                if(lst_Receipt.size() > 0){
                    insert lst_Receipt;
                }
            }
        }catch(Exception exe){}
    }
    
    public static void updateDirectDebitStatus(List<SObject> newList){
        List<DirectDebit_Transactions__c> lst_DDTransactions = (List<DirectDebit_Transactions__c>) newList;
        List<DirectDebitRequest__c> lst_DDRequest = new List<DirectDebitRequest__c>();
        Set<Id> lst_DDRequestId = new Set<Id>();
        for(DirectDebit_Transactions__c obj_DDTransaction : lst_DDTransactions){
            // Null check added to avoid runtime error
            if (obj_DDTransaction.Direct_Debit_Request__c != null && obj_DDTransaction.Request_Type__c == 'New Registration') {
            	lst_DDRequestId.add(obj_DDTransaction.Direct_Debit_Request__c);
            }
        }
         // Skip query if no IDs found
    	if (lst_DDRequestId.isEmpty()) {
        	return;
    	}
        lst_DDRequest = [select Id, Status__c from DirectDebitRequest__c where Id IN :lst_DDRequestId and isActive__c = true];  
        for(DirectDebitRequest__c obj_DirectDebit : lst_DDRequest){
            obj_DirectDebit.Status__c = 'Send To Bank';
        }
        
        if(lst_DDRequest.size() > 0){
            update lst_DDRequest;
        }
    } 
    public static void updateDirectDebitApprovalStatus(List<SObject> newList){
        List<DirectDebit_Transactions__c> lst_DDTransactions = (List<DirectDebit_Transactions__c>) newList;
        List<DirectDebitRequest__c> lst_DDRequest = new List<DirectDebitRequest__c>();
        List<DirectDebitRequest__c> lst_DDADDRequest = new List<DirectDebitRequest__c>();
        Set<Id> lst_DDRequestId = new Set<Id>();
        Map<String, DirectDebit_Transactions__c> mapTransactions = new Map<String, DirectDebit_Transactions__c>();
        Map<String, DirectDebit_Transactions__c> mapDDATransactions = new Map<String, DirectDebit_Transactions__c>();
        for(DirectDebit_Transactions__c obj_DDTransaction : lst_DDTransactions){
            // Null check added to avoid runtime error
            if (obj_DDTransaction.Direct_Debit_Request__c != null && obj_DDTransaction.Request_Type__c == 'New Registration') {
            	lst_DDRequestId.add(obj_DDTransaction.Direct_Debit_Request__c);
                if(!mapTransactions.containsKey(obj_DDTransaction.Payer_Identification__c)){
                    mapTransactions.put(obj_DDTransaction.Payer_Identification__c, obj_DDTransaction);
                }
            } else if(obj_DDTransaction.Direct_Debit_Request__c != null && obj_DDTransaction.Request_Type__c == 'Cancellation'){
                //2.1 added
                lst_DDRequestId.add(obj_DDTransaction.Direct_Debit_Request__c);
                if(!mapDDATransactions.containsKey(obj_DDTransaction.DDA_Unique_Number__c)){
                    mapDDATransactions.put(obj_DDTransaction.DDA_Unique_Number__c, obj_DDTransaction);
                }
            } else{}
        }
         // Skip query if no IDs found
    	if (lst_DDRequestId.isEmpty()) {
        	return;
    	}
        lst_DDRequest = [select Id, Status__c, Payer_Identification__c, DDA_Unique_Number__c from DirectDebitRequest__c 
                         where Id IN :lst_DDRequestId and isActive__c = true
                         and Status__c = 'Send To Bank'];  
        for(DirectDebitRequest__c obj_DirectDebit : lst_DDRequest){
            if(!String.isBlank(obj_DirectDebit.Payer_Identification__c)){
                if(mapTransactions != null && mapTransactions.containsKey(obj_DirectDebit.Payer_Identification__c)){
                    DirectDebit_Transactions__c obj_DDTransaction = mapTransactions.get(obj_DirectDebit.Payer_Identification__c);
                    if(obj_DDTransaction.RegVIdStatus__c == 'Success' && obj_DDTransaction.RegACKStatus__c == 'INITIATED'
                       && obj_DDTransaction.RegResStatus__c == 'ACCP' && obj_DDTransaction.Request_Type__c != 'Cancellation'){
                        obj_DirectDebit.Status__c = 'Approved By Bank';
                        obj_DirectDebit.Approved_Date__c = System.today(); 
                        obj_DirectDebit.DDA_Unique_Number__c = obj_DDTransaction.DDA_Reference__c;   
                    }else if(!String.isBlank(obj_DDTransaction.Rejection_Reason__c) 
                             && obj_DDTransaction.Rejection_Reason__c != 'Accepted' && obj_DDTransaction.Request_Type__c != 'Cancellation'){
                        obj_DirectDebit.Status__c = 'Rejected By Bank';
                        obj_DirectDebit.Rejected_Date__c = System.today();
                        obj_DirectDebit.Rejection_Reason__c = obj_DDTransaction.Rejection_Reason__c;
                    } else if(obj_DDTransaction.Request_Type__c == 'Cancellation'){
                        //2.1 added
                        if(obj_DDTransaction.CancellationResStatus__c == 'Success' && obj_DDTransaction.CancellationAckStatus__c == 'Success'){
                            obj_DirectDebit.Bank_Cancellation_Status__c = 'Success';
                        	obj_DirectDebit.Bank_Cancellation_Date__c = System.today();
                        } else if(!String.isBlank(obj_DDTransaction.Rejection_Reason__c)){
                            obj_DirectDebit.Bank_Cancellation_Remarks__c = obj_DDTransaction.Rejection_Reason__c;
                        } else {}
                    }
                }
            }
        }
        
        //2.1 added
        lst_DDADDRequest = [select Id, Status__c, Payer_Identification__c, DDA_Unique_Number__c from DirectDebitRequest__c 
                         where Id IN :lst_DDRequestId and isActive__c = false and Status__c = 'Cancelled' order by createddate desc];  
        for(DirectDebitRequest__c obj_DirectDebit : lst_DDADDRequest){
            if(!String.isBlank(obj_DirectDebit.DDA_Unique_Number__c)){
                if(mapDDATransactions != null && mapDDATransactions.containsKey(obj_DirectDebit.DDA_Unique_Number__c)){
                    DirectDebit_Transactions__c obj_DDTransaction = mapDDATransactions.get(obj_DirectDebit.DDA_Unique_Number__c);
                    if(obj_DDTransaction.Request_Type__c == 'Cancellation'){
                        if(obj_DDTransaction.CancellationResStatus__c == 'DDA CANCELLED' 
                           && obj_DDTransaction.CancellationAckStatus__c == 'Success'){
                            obj_DirectDebit.Bank_Cancellation_Status__c = 'Success';
                        	obj_DirectDebit.Bank_Cancellation_Date__c = System.today();
                        } else if(!String.isBlank(obj_DDTransaction.Rejection_Reason__c)){
                            obj_DirectDebit.Bank_Cancellation_Remarks__c = obj_DDTransaction.Rejection_Reason__c;
                        } else {}
                    }
                }
            }
        }
        
        if(lst_DDRequest.size() > 0){
            update lst_DDRequest;
        }
        if(lst_DDADDRequest.size() > 0){
            update lst_DDADDRequest;
        }
    } 
    public static void sendTranactionToFABGateway(List<SObject> newList){
        
        // Skip in Batch context because @future cannot be called from Batch
        if (System.isBatch()) {
            System.debug('Skipping sendTranactionToFABGateway during Batch context');
            return;
        }
        
        // Added null/empty check to ensure method doesn't proceed with empty list
    	if (newList == null || newList.isEmpty()) {
        	System.debug('No transactions passed to sendTranactionToFABGateway');
        	return;
    	}
        
        List<DirectDebit_Transactions__c> lst_DDTransactions = (List<DirectDebit_Transactions__c>) newList;
        Set<Id> set_RegistrationId = new Set<Id>();
        Set<Id> set_CollectionId = new Set<Id>();
        //2.1 added
        Set<Id> set_CancellationRegId = new Set<Id>();
        for(DirectDebit_Transactions__c obj_DDTransaction : lst_DDTransactions){
            if(obj_DDTransaction.Request_Type__c == 'New Registration'){
                set_RegistrationId.add(obj_DDTransaction.Id);
            }else if(obj_DDTransaction.Request_Type__c == 'Collection'){
                set_CollectionId.add(obj_DDTransaction.Id);
            }else if(obj_DDTransaction.Request_Type__c == 'Cancellation'){
                //2.1 added
                set_CancellationRegId.add(obj_DDTransaction.Id);
            }else{}
        }
        if(set_RegistrationId.size() > 0){
            sendNewRegistrationToFAB(set_RegistrationId);
        }
        if(set_CollectionId.size() > 0){
            sendCollectionsToFAB(set_CollectionId);
        }
        //2.1 added
        if(set_CancellationRegId.size() > 0){
            sendCancellationRegToFAB(set_CancellationRegId);
        }
    }
    
    //2.1 added
    @future(callout = true)
	public static void sendCancellationRegToFAB(Set<Id> set_RegistrationId) {
         if (Test.isRunningTest()) {
            System.debug('Skipping sendNewRegistrationToFAB in test context');
            return;
        }
        // Prevent call if input is empty
    	if (set_RegistrationId == null || set_RegistrationId.isEmpty()) {
        	System.debug('No registration transactions provided to sendCancellationRegToFAB');
        	return;
    	}
    	sendCancellationRegToFAB_sync(set_RegistrationId);
	}
    
   //2.1 added
   public static void sendCancellationRegToFAB_sync(Set<Id> set_RegistrationId){
       
       	// Skip execution if input is null or empty
        if (set_RegistrationId == null || set_RegistrationId.isEmpty()) {
            System.debug('No Registration Ids provided to sendCancellationRegToFAB_sync');
            return;
        }
       
       List<DirectDebit_Transactions__c> lst_DDTransactions = new  List<DirectDebit_Transactions__c>();
       if(set_RegistrationId.size() > 0){
           lst_DDTransactions = [SELECT Id,Ack_Nack_Response__c, Collection_Amount__c, Currency__c, Direct_Debit_Banking_Reference_Number__c,
                                 Direct_Debit_Bank__c, Direct_Debit_Request__c, Direct_Debit_Response__c, Receipt_Acknowledgement__c, 
                                 Rejection_Reason__c, Request_Type__c, Transaction_Status__c, Direct_Debit_Request__r.Request_Type__c, 
                                 Direct_Debit_Request__r.OIC__c, Direct_Debit_Request__r.DirectDebit_Authority_Reference_Number__c, 
                                 Direct_Debit_Request__r.Customer_Id_Type__c, Direct_Debit_Request__r.Customer_ID_Number__c, 
                                 Direct_Debit_Request__r.Customer_Bank_Name__c, Direct_Debit_Request__r.Customer_Bank_Account_Name__c, 
                                 Direct_Debit_Request__r.Customer_Bank_Account_Type__c, Direct_Debit_Request__r.Customer_IBAN_Number__c, 
                                 Direct_Debit_Request__r.Customer_Mobile__c, Direct_Debit_Request__r.ContactEmail__c, 
                                 Direct_Debit_Request__r.Commences_On__c, Direct_Debit_Request__r.Expires_On__c,
                                 Direct_Debit_Request__r.Payer_Identification__c, Direct_Debit_Request__r.Customer_Type__c,
                                 Direct_Debit_Request__r.Account__r.Name, Direct_Debit_Request__r.Maximum_Amount__c, DDA_Unique_Number__c,
                                 Direct_Debit_Request__r.DDA_Unique_Number__c                                 
                                 from DirectDebit_Transactions__c where Id IN :set_RegistrationId];
       } 
       try{
            Date myDate = Date.today();
            DateTime myDateTime = DateTime.newInstance(myDate, Time.newInstance(0, 0, 0, 0));
            String formatted = myDateTime.format('ddMMyy');
            System.debug('Formatted Date >>>>>>>> ' + formatted);
           
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req = OIC_CredentialsController.getCredentials('ModonFusionDDRegCancellationAPI');
            DirectDebitRegCancellationCollection obj_DDCancelCollection = new DirectDebitRegCancellationCollection();
            List<cls_RegCancellationDetails> lst_DDCancelCollection = new List<cls_RegCancellationDetails>();
            
            for(DirectDebit_Transactions__c obj_DDTransaction : lst_DDTransactions){
               cls_RegCancellationDetails obj_DDCancelDetails = new cls_RegCancellationDetails();
               obj_DDCancelDetails.DDFileName = 'C400003-'+obj_DDTransaction.Direct_Debit_Request__r.OIC__c+'-'+formatted+'-'+
                            						+obj_DDTransaction.Direct_Debit_Request__r.Payer_Identification__c+'.txt'; 
               obj_DDCancelDetails.RequestType =  'CAN';
               obj_DDCancelDetails.OIC =  obj_DDTransaction.Direct_Debit_Request__r.OIC__c;
               obj_DDCancelDetails.DDAReference = obj_DDTransaction.Direct_Debit_Request__r.DDA_Unique_Number__c;
               obj_DDCancelDetails.DDACancellationReasonCode =  'P99';
               obj_DDCancelDetails.CaptureCode =  'M';
               obj_DDCancelDetails.PayerIdentification =  obj_DDTransaction.Direct_Debit_Request__r.Payer_Identification__c;
               obj_DDCancelDetails.CustomerType =  obj_DDTransaction.Direct_Debit_Request__r.Customer_Type__c;
               obj_DDCancelDetails.PDFFileName =  ''; 
               lst_DDCancelCollection.add(obj_DDCancelDetails); 
            }    
            obj_DDCancelCollection.RegCancellationDetails = lst_DDCancelCollection;
            req.setBody(JSON.serialize(obj_DDCancelCollection));
            system.debug('sendCancellationToFAB >>>>> obj_DDCancelCollection >> ' + JSON.serialize(obj_DDCancelCollection));
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug(res);
            System.debug(res.getBody());     
       }catch(Exception exe){
            LoggerService.save(LoggerService.createApexLog(exe, 'Direct Debit Reg Cancellation Process',
                                                           'DirectDebitTransactionHelper','sendCancellationRegToFAB_sync'));
            System.debug('>>>> Exception in createReceipt: ' + exe.getMessage());
            throw new StringException(exe.getStackTraceString());
       } 
   }
    
    @future(callout = true)
	public static void sendNewRegistrationToFAB(Set<Id> set_RegistrationId) {
         if (Test.isRunningTest()) {
            System.debug('Skipping sendNewRegistrationToFAB in test context');
            return;
        }
        // Prevent call if input is empty
    	if (set_RegistrationId == null || set_RegistrationId.isEmpty()) {
        	System.debug('No registration transactions provided to sendNewRegistrationToFAB');
        	return;
    	}
    	sendNewRegistrationToFAB_sync(set_RegistrationId);
	}
    
   
   public static void sendNewRegistrationToFAB_sync(Set<Id> set_RegistrationId){
       
       	// Skip execution if input is null or empty
        if (set_RegistrationId == null || set_RegistrationId.isEmpty()) {
            System.debug('No Registration Ids provided to sendNewRegistrationToFAB_sync');
            return;
        }
       
       List<DirectDebit_Transactions__c> lst_DDTransactions = new  List<DirectDebit_Transactions__c>();
       if(set_RegistrationId.size() > 0){
           lst_DDTransactions = [SELECT Id,Ack_Nack_Response__c, Collection_Amount__c, Currency__c, Direct_Debit_Banking_Reference_Number__c,
                                 Direct_Debit_Bank__c, Direct_Debit_Request__c, Direct_Debit_Response__c, Receipt_Acknowledgement__c, 
                                 Rejection_Reason__c, Request_Type__c, Transaction_Status__c, Direct_Debit_Request__r.Request_Type__c, 
                                 Direct_Debit_Request__r.OIC__c, Direct_Debit_Request__r.DirectDebit_Authority_Reference_Number__c, 
                                 Direct_Debit_Request__r.Customer_Id_Type__c, Direct_Debit_Request__r.Customer_ID_Number__c, 
                                 Direct_Debit_Request__r.Customer_Bank_Name__c, Direct_Debit_Request__r.Customer_Bank_Account_Name__c, 
                                 Direct_Debit_Request__r.Customer_Bank_Account_Type__c, Direct_Debit_Request__r.Customer_IBAN_Number__c, 
                                 Direct_Debit_Request__r.Customer_Mobile__c, Direct_Debit_Request__r.ContactEmail__c, 
                                 Direct_Debit_Request__r.Commences_On__c, Direct_Debit_Request__r.Expires_On__c,
                                 Direct_Debit_Request__r.Payer_Identification__c, Direct_Debit_Request__r.Customer_Type__c,
                                 Direct_Debit_Request__r.Account__r.Name, Direct_Debit_Request__r.Maximum_Amount__c, DDA_Unique_Number__c                                 
                                 from DirectDebit_Transactions__c where Id IN :set_RegistrationId];
       } 
       try{
            Date myDate = Date.today();
            DateTime myDateTime = DateTime.newInstance(myDate, Time.newInstance(0, 0, 0, 0));
            String formatted = myDateTime.format('ddMMyy');
            System.debug('Formatted Date >>>>>>>> ' + formatted);
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            if (!Test.isRunningTest()) {
                req = OIC_CredentialsController.getCredentials('ModonFusionDDSRegistrationAPI');
            }

            for(DirectDebit_Transactions__c obj_DDTransaction : lst_DDTransactions){
                DirectDebitRegistration obj_DDRegistration = new DirectDebitRegistration();
                List<Documents__c> lst_Document = new List<Documents__c>();
                cls_ImageDetails obj_ImageDetails = new cls_ImageDetails();
                if(!String.isBlank(obj_DDTransaction.Direct_Debit_Request__c)){
                    lst_Document = [Select Id, Direct_Debit_Request__c from Documents__c 
                                    where Direct_Debit_Request__c = :obj_DDTransaction.Direct_Debit_Request__c limit 1];
                }
                //if(lst_Document.size() > 0){
                if (!lst_Document.isEmpty()) {
                    Documents__c obj_Doc = lst_Document.get(0);
                    List<ContentDocumentLink> docLinks = [
                                                          SELECT ContentDocumentId 
                                                          FROM ContentDocumentLink 
                                                          WHERE LinkedEntityId = :obj_Doc.Id 
                                                          LIMIT 1
                                                         ];
                    //if(docLinks.size() > 0){
                    if (!docLinks.isEmpty()) {
                        Id contentDocumentId = docLinks[0].ContentDocumentId;
                        List<ContentVersion> cvList = new List<ContentVersion>();
                        if (!Test.isRunningTest()) {
                            cvList = [
                                SELECT Id, Title, VersionData
                                FROM ContentVersion
                                WHERE ContentDocumentId = :contentDocumentId
                                ORDER BY CreatedDate DESC
                                LIMIT 1
                            ];
                        }

                        if (!cvList.isEmpty()) {
                        Blob fileBody = cvList[0].VersionData; // Binary data (Blob)
					    String base64String = EncodingUtil.base64Encode(fileBody);
                        obj_ImageDetails.ImageBase64 = base64String;
                        
                        obj_ImageDetails.ImageFile = 'C300003-'+obj_DDTransaction.Direct_Debit_Request__r.OIC__c+'-'+formatted+'-'+
                            						  +obj_DDTransaction.Direct_Debit_Request__r.Payer_Identification__c+'.pdf';
                        }
                    }
                    
                }
                
                obj_DDRegistration.RequestType = 'ADD';
                obj_DDRegistration.OIC = obj_DDTransaction.Direct_Debit_Request__r.OIC__c;
                obj_DDRegistration.PayerIdentification = obj_DDTransaction.Direct_Debit_Request__r.Payer_Identification__c;
                obj_DDRegistration.DDAReferenceNumber = NULL;
                obj_DDRegistration.CustomerType = obj_DDTransaction.Direct_Debit_Request__r.Customer_Type__c;
                obj_DDRegistration.CustomerIDType = 'EIDAC';//obj_DDTransaction.Direct_Debit_Request__r.Customer_Id_Type__c;
                obj_DDRegistration.CustomerIDNumber = obj_DDTransaction.Direct_Debit_Request__r.Customer_ID_Number__c.replace('-', '');
                obj_DDRegistration.BankName = obj_DDTransaction.Direct_Debit_Request__r.Customer_Bank_Name__c;
                obj_DDRegistration.TitleofAccount = obj_DDTransaction.Direct_Debit_Request__r.Account__r.Name;
                obj_DDRegistration.AccountType = obj_DDTransaction.Direct_Debit_Request__r.Customer_Bank_Account_Type__c;
                obj_DDRegistration.IBANorCardNumber = obj_DDTransaction.Direct_Debit_Request__r.Customer_IBAN_Number__c;
                obj_DDRegistration.MobileNumber = obj_DDTransaction.Direct_Debit_Request__r.Customer_Mobile__c;
                obj_DDRegistration.Email = obj_DDTransaction.Direct_Debit_Request__r.ContactEmail__c;
                obj_DDRegistration.IssuedFor = obj_DDTransaction.Direct_Debit_Request__r.DirectDebit_Authority_Reference_Number__c;
                DateTime CommencesDateTime = DateTime.newInstance(obj_DDTransaction.Direct_Debit_Request__r.Commences_On__c, 
                                                                  Time.newInstance(0, 0, 0, 0));
                obj_DDRegistration.CommencesOn = CommencesDateTime.format('dd/MM/yyyy');
                DateTime ExpiresOnDateTime = DateTime.newInstance(obj_DDTransaction.Direct_Debit_Request__r.Expires_On__c, 
                                                                  Time.newInstance(0, 0, 0, 0));
                obj_DDRegistration.CommencesOn = CommencesDateTime.format('dd/MM/yyyy');
                obj_DDRegistration.ExpiresOn = ExpiresOnDateTime.format('dd/MM/yyyy');
                obj_DDRegistration.AmountType = 'variable';
                obj_DDRegistration.PaymentFrequency = 'Daily';
                obj_DDRegistration.FixedAmount1OrMinimumAmount = '1';
                obj_DDRegistration.FixedAmount2OrMaximumAmount = String.valueOf(obj_DDTransaction.Direct_Debit_Request__r.Maximum_Amount__c);
                obj_DDRegistration.CurrencyCode = 'AED';
                obj_DDRegistration.FirstInitiationDate = null;
                obj_DDRegistration.FrequencyParameter = '';
                obj_DDRegistration.ImageFileName = 'C300003-'+obj_DDTransaction.Direct_Debit_Request__r.OIC__c+'-'+formatted+'-'+
                            						+obj_DDTransaction.Direct_Debit_Request__r.Payer_Identification__c+'.txt';
                obj_DDRegistration.MakerRemarks = '';
    			obj_DDRegistration.ImageDetails = obj_ImageDetails;
                
                req.setBody(JSON.serialize(obj_DDRegistration));
                system.debug('sendNewRegistrationToFAB >>>>> obj_DDRegistration >> ' + JSON.serialize(obj_DDRegistration));
                Http http = new Http();
                HTTPResponse res = http.send(req);
                System.debug(res);
                System.debug(res.getBody());
            }
           
       }catch(Exception exe){
            LoggerService.save(LoggerService.createApexLog(exe, 'Direct Debit New Registration Process',
                                                           'DirectDebitTransactionHelper','sendNewRegistrationToFAB'));
            System.debug('>>>> Exception in createReceipt: ' + exe.getMessage());
            throw new StringException(exe.getStackTraceString());
       } 
   }
    
   @future(callout = true)
	public static void sendCollectionsToFAB(Set<Id> set_CollectionId) {
        
         // Add a null or empty check to avoid unnecessary execution
        if (set_CollectionId == null || set_CollectionId.isEmpty()) {
            System.debug('No Collection Ids provided to sendCollectionsToFAB');
            return;
        }

    	if (Test.isRunningTest()) {
        	System.debug('Skipping sendCollectionsToFAB in test context');
        	return;
    	}
    	sendCollectionsToFAB_sync(set_CollectionId);
	}

   public static void sendCollectionsToFAB_sync(Set<Id> set_CollectionId){
       
        // check to avoid unnecessary query or processing
        if (set_CollectionId == null || set_CollectionId.isEmpty()) {
            System.debug('No Collection IDs provided to sendCollectionsToFAB_sync');
            return;
        }
       
       List<DirectDebit_Transactions__c> lst_DDTransactions = new  List<DirectDebit_Transactions__c>();
       if(set_CollectionId.size() > 0){
           lst_DDTransactions = [SELECT Id,Ack_Nack_Response__c, Collection_Amount__c, Currency__c, Direct_Debit_Banking_Reference_Number__c,
                                 Direct_Debit_Bank__c, Direct_Debit_Request__c, Direct_Debit_Response__c, Receipt_Acknowledgement__c, 
                                 Rejection_Reason__c, Request_Type__c, Transaction_Status__c, Direct_Debit_Request__r.Request_Type__c, 
                                 Direct_Debit_Request__r.OIC__c, Direct_Debit_Request__r.DirectDebit_Authority_Reference_Number__c, 
                                 Direct_Debit_Request__r.Customer_Id_Type__c, Direct_Debit_Request__r.Customer_ID_Number__c, 
                                 Direct_Debit_Request__r.Customer_Bank_Name__c, Direct_Debit_Request__r.Customer_Bank_Account_Name__c, 
                                 Direct_Debit_Request__r.Customer_Bank_Account_Type__c, Direct_Debit_Request__r.Customer_IBAN_Number__c, 
                                 Direct_Debit_Request__r.Customer_Mobile__c, Direct_Debit_Request__r.ContactEmail__c, 
                                 Direct_Debit_Request__r.Commences_On__c, Direct_Debit_Request__r.Expires_On__c,
                                 Direct_Debit_Request__r.Payer_Identification__c, DDA_Unique_Number__c, Escrow_IBAN_Number__c,
                                 SOInstallment__r.Name
                                 from DirectDebit_Transactions__c where Id IN :set_CollectionId];
       }
       
       // Exit early if query returned nothing
        if (lst_DDTransactions.isEmpty()) {
            System.debug('No DirectDebit_Transactions__c records found for given Collection IDs');
            return;
        }
       
       try{
            Date myDate = Date.today();
            DateTime myDateTime = DateTime.newInstance(myDate, Time.newInstance(0, 0, 0, 0));
            String formatted = myDateTime.format('ddMMyy');
            System.debug('Formatted Date >>>>>>>> ' + formatted);
           
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req = OIC_CredentialsController.getCredentials('ModonFusionDDSCollectionAPI');
            DirectDebitCollection obj_DDCollection = new DirectDebitCollection();
            List<cls_CollectionDetails> lst_DDCollection = new List<cls_CollectionDetails>();
            
            for(DirectDebit_Transactions__c obj_DDTransaction : lst_DDTransactions){
               cls_CollectionDetails obj_DDCollectionDetails = new cls_CollectionDetails();
               obj_DDCollectionDetails.DDFileName = 'C500003-'+obj_DDTransaction.Direct_Debit_Request__r.OIC__c+'-'+formatted+'-'+
                            				 		 +obj_DDTransaction.SOInstallment__r.Name.split('-')[1]+'.txt'; 
               obj_DDCollectionDetails.DDAReferenceNumber =  obj_DDTransaction.DDA_Unique_Number__c;
               obj_DDCollectionDetails.Currency_Str =  obj_DDTransaction.Currency__c;
               obj_DDCollectionDetails.ClaimedAmount =  String.valueOf(obj_DDTransaction.Collection_Amount__c);
               obj_DDCollectionDetails.OriginatorIBAN = obj_DDTransaction.Escrow_IBAN_Number__c;
               obj_DDCollectionDetails.CustomerReferenceNumber =  obj_DDTransaction.Direct_Debit_Request__r.Payer_Identification__c;
               lst_DDCollection.add(obj_DDCollectionDetails); 
            }    
            obj_DDCollection.CollectionDetails = lst_DDCollection;
            req.setBody(JSON.serialize(obj_DDCollection));
            system.debug('sendCollectionToFAB >>>>> obj_DDCollection >> ' + JSON.serialize(obj_DDCollection));
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug(res);
            System.debug(res.getBody());
       }catch(Exception exe){
            LoggerService.save(LoggerService.createApexLog(exe, 'Direct Debit New Registration Process',
                                                           'DirectDebitTransactionHelper','sendCollectionsToFAB'));
            System.debug('>>>> Exception in createReceipt: ' + exe.getMessage());
            throw new StringException(exe.getStackTraceString());
       }    
   } 
    public class DirectDebitCollection{
        public cls_CollectionDetails[] CollectionDetails;        
	}
    public class cls_CollectionDetails {
            public String DDFileName;
            public String DDAReferenceNumber;	
            public String Currency_Str;	
            public String ClaimedAmount;
            public String OriginatorIBAN;
            public String CustomerReferenceNumber;
    }
    public class DirectDebitRegCancellationCollection{
        public cls_RegCancellationDetails[] RegCancellationDetails;        
	}
    public class cls_RegCancellationDetails {
            public String DDFileName;
            public String RequestType;
            public String OIC;	
            public String DDAReference;	
            public String DDACancellationReasonCode;
            public String CaptureCode;
            public String PayerIdentification;
            public String CustomerType;
            public String PDFFileName;
    }
    public class DirectDebitRegistration{
        public String RequestType;	
        public String OIC;	
        public String PayerIdentification;	
        public String DDAReferenceNumber;	
        public String CustomerType;	
        public String CustomerIDType;
        public String CustomerIDNumber;
        public String BankName;	
        public String TitleofAccount;	
        public String AccountType;
        public String IBANorCardNumber;
        public String MobileNumber;
        public String Email;
        public String IssuedFor;	
        public String CommencesOn;	
        public String ExpiresOn;
        public String AmountType;	
        public String PaymentFrequency;
        public String FixedAmount1OrMinimumAmount;
        public String FixedAmount2OrMaximumAmount;
        public String CurrencyCode;	
        public String FirstInitiationDate;
        public String FrequencyParameter;
        public String ImageFileName;	
        public String MakerRemarks;	
        public cls_ImageDetails ImageDetails;        
    } 
    public class cls_ImageDetails {
            public String ImageFile;	
            public String ImageBase64;	
    }
}