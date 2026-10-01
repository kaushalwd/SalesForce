/**********************************************************************************************************************
* Name               : OIC_ManageReceiptReversal
* Description        : Controller for is used for  Receipt Reversal from payemnt record
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            22 Jan 2026          Initial Draft
* 1.1           Arvind           06 Jul 2026          Fixed reversal not reflecting in Salesforce after successful
* 1.2 			Modon IT		 24 Jul 2026		  Adding user comments and updated Receipt level	
***********************************************************************************************************************/
public without sharing class OIC_ManageReceiptReversal {
   public class InputWrapper {
        @InvocableVariable(required=true)
        public Id value1;
        @InvocableVariable (required=true)
        public string value2; 
		@InvocableVariable
        public string comments;        
    }
    
    public class ReceiptData {
        public String reason;
        public String comments;

        public ReceiptData(String reason, String comments) {
            this.reason = reason;
            this.comments = comments;
        }
    }

    @InvocableMethod(label='Process Receipt Reversal' description='Details Receipt Reversal callout')
    public static void processValues(List<InputWrapper> inputs) {
		//Map<id,string> ReceiptMap =new map<id,string>();
        Map<Id, ReceiptData> receiptMap = new Map<Id, ReceiptData>();
        for (InputWrapper input : inputs) {
            receiptMap.put(
                input.value1,
                new ReceiptData(input.value2, input.comments)
            );
            //System.debug(input.value1);
            //System.debug(input.value2);            
            //ReceiptMap.put(input.value1,input.value2);
        }
        if(!receiptMap.isEmpty()){
            sendReceiptToOracle_Future(JSON.serialize(receiptMap));
        }
    }
/**
     * Future method to perform asynchronous callout
     * - Required because callouts are not allowed directly from Flow context
     * - Delegates processing to main service method
     */
	@future(callout = true)
    public static void sendReceiptToOracle_Future(String receiptMapJson){
        Map<Id, ReceiptData> receiptMap = (Map<Id, ReceiptData>) JSON.deserialize(receiptMapJson, Map<Id, ReceiptData>.class);
        receiptReversalEbsService(receiptMap);        
        //for(id ids: recMap.keyset()){
            //String reason  = recMap.get(Ids);
            //receiptReversalEbsServive(ids,reason);
        //}        
    }
    
    
    /**
     * Aura-enabled method to fetch receipt integration status
     * - Used by UI (LWC/Aura)
     * - Returns OIC status, Oracle ID, and error/message
     */
	@AuraEnabled(cacheable=false)
    public static StatusResponse getReceiptStatus(Id recordId) {
        Receipt__c receiptStatus =[select id,ReverseReasonstatus__c  from Receipt__c where id =:recordId LIMIT 1  ];
    
    StatusResponse res = new StatusResponse();
        res.status = receiptStatus.OICIntegrationStatus__c;
        res.oracleId = receiptStatus.Oracle_Id_Temporary__c;
        res.message = receiptStatus.OICIntegrationMessage__c;

        return res;
    }

    /**
     * Wrapper class for returning receipt status to UI
     */
    public class StatusResponse {
        @AuraEnabled public String status;
        @AuraEnabled public String oracleId;
        @AuraEnabled public String message;
    }
    
    /**
     * Core method to handle Receipt Reversal Integration with Oracle (OIC)
     *
     * Responsibilities:
     * - Prepare reversal payload from Receipt__c records
     * - Map reversal reason values to Oracle reason codes (Custom Metadata driven)
     * - Construct request wrapper and encode in Base64
     * - Perform HTTP callout to OIC endpoint
     * - Parse Base64 response and update Salesforce records
     * - Handle success and error scenarios
     * - Maintain retry count for failed records
     * - Log API request/response
     *
     * @param recMap → Map<ReceiptId, ReversalReason>
     */
    public static void receiptReversalEbsService(Map<Id, ReceiptData> receiptMap){
        
        Map<String, String> reasonValueToCodeMap = new Map<String, String>();
        Map<String, String> reasonToCodeMap = new Map<String, String>();
		//system.debug('recMap-----'+ReceiptIds);
        for (Ebs_Receipts_Status__mdt mdt : [SELECT Reason_code__c, Reason_Values__c FROM Ebs_Receipts_Status__mdt]) {
        
            if (String.isNotBlank(mdt.Reason_Values__c)) {
                for (String value : mdt.Reason_Values__c.split(',')) {
                    reasonValueToCodeMap.put(value, mdt.Reason_code__c);
                    reasonToCodeMap.put(mdt.Reason_code__c,value);
                }
            }
        }
        try{
        List<Receipt__c> recLst = [SELECT Id, Name, Receipt_Amount__c,Receipt_Approved_Date__c,Account__c, SalesOrder__c, SalesOrderInstallment__c,  AppliedAmount__c,
                                       SalesOrder__r.ProjectName__c,SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, EntityName__c,
                                       PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, TransactionDate__c,
                                       PaymentEscrowAccount__r.IBANNo__c, PaymentEscrowAccount__r.Name, TransactionNumber__c, ExpressionOfInterest__c,
                                       Modeofpayment__c, ReceiptDate__c,ChequeDate__c, TotalAmount__c, Bank__c, Status__c, SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c,
                                       SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                                       SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c,
                                       SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                                       SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                       SalesOrder__r.Unit__r.Phase__r.EntityName__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                       EBS_Clearing_Date__c ,Charge__r.Type__c, Cheque_Number__c, SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c,SalesOrder__r.OracleCustAcctSiteID__c,SalesOrder__r.OracleSiteUseID__c,SalesOrder__r.NotToBeShownOnRD__c, Cheque_Bounce_Reason__c, Reason_Code__c, OraclePartyId__c,isReverseEBS__c
                                       FROM Receipt__c WHERE Id IN:receiptMap.keySet() and ( OraclePartyId__c != null OR Oracle_Id_Temporary__c != null ) and SalesOrder__r.NotToBeShownOnRD__c = false and SalesOrder__r.Source_Entity__c != 'Modon - Egypt' ];
            
            List<OIC_RequestWrapperController.ReceiptWrapper> receiptWrapLst = new List<OIC_RequestWrapperController.ReceiptWrapper>();
            map<id,boolean> receiptMap2 =new map<id,boolean>();
            
            for(Receipt__c recObj : recLst){
                ReceiptData data = receiptMap.get(recObj.Id);
                OIC_RequestWrapperController.ReceiptWrapper receiptWrapObj = new OIC_RequestWrapperController.ReceiptWrapper();
                receiptWrapObj.Sfid = recObj.Id;
                receiptWrapObj.SfReference = recObj.Name;
                receiptWrapObj.CustomerSfid = recObj.Account__c;
                receiptWrapObj.CustomerPartyId = recObj.Account__r.OraclePartyId__c;
                receiptWrapObj.VirtualAccountNumber = recObj.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
                receiptWrapObj.VirtualIbanNumber = recObj.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
                receiptWrapObj.OrgIdentifier = UserInfo.getOrganizationId();
                
                if(recObj.SalesOrderInstallment__c != null ){
                    receiptWrapObj.ProjectName = recObj.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                    receiptWrapObj.ExtraInfo2 = recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                    receiptWrapObj.EntityName=recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;				
                    receiptWrapObj.ProjectPhase =recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;		
                    receiptWrapObj.TrxnType = 'INSTALLMENT';
                }else{
                    // added for charge api 
                    receiptWrapObj.ProjectName = recObj.SalesOrder__r.ProjectName__c;
                    receiptWrapObj.ExtraInfo2 = recObj.SalesOrder__r.Unit__r.Project_Name__c+'-'+recObj.SalesOrder__r.Unit__r.Phase__r.Name;
                    receiptWrapObj.EntityName = recObj.SalesOrder__r.Unit__r.Phase__r.EntityName__c != null ? recObj.SalesOrder__r.Unit__r.Phase__r.EntityName__c : recObj.EntityName__c;				
                    receiptWrapObj.ProjectPhase =recObj.SalesOrder__r.Unit__r.Phase__r.Name;
                    // trans type hard code changes
					Map<String, String> chargeToTrxnMap = new Map<String, String>();
					for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
						chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
					}					
					String chargeType = recObj.Charge__r.Type__c;

					if (chargeToTrxnMap.containsKey(chargeType)) {
						receiptWrapObj.TrxnType = chargeToTrxnMap.get(chargeType);
					}else{
						receiptWrapObj.TrxnType ='ADM_CHARGES';
					}                   
                }
                if(receiptWrapObj.TrxnType == null){
                    receiptWrapObj.TrxnType ='ADM_CHARGES';
                }
                receiptWrapObj.Description = recObj.Milestone_Description__c;
                receiptWrapObj.EscrowAccountName = recObj.PaymentEscrowAccount__r.Name;
                receiptWrapObj.EscrowAccountNo = recObj.PaymentEscrowAccount__r.AccountNumber__c;
                receiptWrapObj.EscrowIBANNo = recObj.PaymentEscrowAccount__r.IBANNo__c;
                receiptWrapObj.ReceiptNumber = recObj.Name;
                receiptWrapObj.ReceiptType = recObj.Modeofpayment__c;
                receiptWrapObj.CurrencyCode = 'AED';
                receiptWrapObj.ReceiptDate = recObj.ChequeDate__c <> null? Date.valueOf(recObj.ChequeDate__c) : Date.valueOf(recObj.ReceiptDate__c);
                receiptWrapObj.MaturityDate = receiptWrapObj.ReceiptDate;                
                if(recObj.EBS_Clearing_Date__c != null){
                    receiptWrapObj.GlDate =recObj.EBS_Clearing_Date__c;
                }else{
                    receiptWrapObj.GlDate =system.today();
                }
                if(recObj.Receipt_Amount__c != null){
                    receiptWrapObj.Amount = recObj.Receipt_Amount__c;
                }else{
                    receiptWrapObj.Amount = recObj.AppliedAmount__c;
                }                
                receiptWrapObj.BankName = recObj.Bank__c;
                receiptWrapObj.Status = recObj.Status__c;
                receiptWrapObj.ChequeNumber = recObj.TransactionNumber__c ; //Cheque_Number__c
                receiptWrapObj.CustAcctId= recObj.SalesOrder__r.CustAcctId__c;
                receiptWrapObj.OraclePartySiteID= recObj.SalesOrder__r.OraclePartySiteID__c;
                receiptWrapObj.OracleCustAcctSiteID= recObj.SalesOrder__r.OracleCustAcctSiteID__c;
                receiptWrapObj.OracleSiteUseID= recObj.SalesOrder__r.OracleSiteUseID__c;
                receiptWrapObj.Unit = recObj.SalesOrder__r.Unit__r.Name;
                receiptWrapObj.UnitName = recObj.SalesOrder__r.Unit__r.Name;
                receiptWrapObj.Description = recObj.Milestone_Description__c;
                if(recObj.ExpressionOfInterest__c <> null)
                    receiptWrapObj.EoiFlag = 'Y';
                else 
                    receiptWrapObj.EoiFlag = 'N';
                if(recObj.Receipt_Approved_Date__c <> null){
                    receiptWrapObj.Bypass = 'N';
                    receiptMap2.put(recObj.id,true);
                }else{
                    receiptWrapObj.Bypass = 'Y';
                }

                // receipt Retry Process type ebs
                    receiptWrapObj.ReverseReceipt = 'Y';
                    receiptWrapObj.ReverseOracleID = recObj.OraclePartyId__c;
                    receiptWrapObj.CategoryCode = 'REV';

                    //if (ReversalValues != null && reasonValueToCodeMap.containsKey(ReversalValues)) {
                        receiptWrapObj.ReasonCode = data.reason != null && reasonValueToCodeMap.containsKey(data.reason) ? reasonValueToCodeMap.get(data.reason) : null;                       
                    //}                                                              
                    receiptWrapObj.ReasonComments = data.reason;
                
                system.debug('receiptWrapObj.ReasonCode--'+receiptWrapObj.ReasonCode);
                system.debug('receiptWrapObj.ReasonComments--'+receiptWrapObj.ReasonComments);
                receiptWrapLst.add(receiptWrapObj);
            }
            
            HttpRequest req = new HttpRequest();
            req = OIC_CredentialsController.getCredentials('ModonFusionReceiptAPI2');
            req.setTimeout(120000);
            OIC_RequestWrapperController.ReceiptWrapperLst receiptWrapperList = new OIC_RequestWrapperController.ReceiptWrapperLst();
            receiptWrapperList.RequestArray = receiptWrapLst;
            
            String receiptWrappString = JSON.serialize(receiptWrapperList);
            
            system.debug('JSON.serialize(receiptWrappString)==>' + JSON.serialize(receiptWrappString));
            Blob binaryData = Blob.valueOf(receiptWrappString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            
            req.setBody(JSON.serialize(wrapper));
            req.setHeader('Accept', 'application/json');
            system.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug(res);
            System.debug(res.getBody());
            
            string receiptResponseBody = res.getBody();
            System.debug('receiptResponseBody::: ' + receiptResponseBody);
            
            // PARSING THE RESPONSE //
            if(receiptResponseBody <> null && receiptResponseBody <> ''){                
                OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(receiptResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                
                blob receiptResponseBlobActual = null;
                string receiptResponseStringActual = null;
                
                System.debug('base64RespWrap.Base64Response::: ' + base64RespWrap.Base64Response);
                
                if(base64RespWrap.Base64Response <> null && base64RespWrap.Base64Response <> '')
                    receiptResponseBlobActual = EncodingUtil.base64Decode(base64RespWrap.Base64Response); 
                if(receiptResponseBlobActual <> null)
                    receiptResponseStringActual = receiptResponseBlobActual.toString();
                System.debug('receiptResponseStringActual:::: ' + receiptResponseStringActual);
                
                if(receiptResponseStringActual <> null){
                    OIC_RequestWrapperController.OICResponseWrapperList receiptResponseObjectActual = (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(receiptResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    
                    if(receiptResponseObjectActual <> null){
                        list<Receipt__c> lstRecordToUpdate = new list<Receipt__c>();                        
                        set<string> recordIds = new set<string>();
                        map<string, integer> mp_recId_NoOfReTries = new map<string, integer>();                        
                        for(OIC_RequestWrapperController.OICResponseWrapper resp : receiptResponseObjectActual.ResponseArray){
                            recordIds.add(resp.Sfid);
                        }                        
                        if(!recordIds.isEmpty()){
                            list<Receipt__c> recs = [select Id, OICNoOfRetries__c from Receipt__c where Id in: recordIds and OICNoOfRetries__c != null];
                            for(Receipt__c rec: recs){
                                mp_recId_NoOfReTries.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
                            }
                        }
                        for(OIC_RequestWrapperController.OICResponseWrapper resp : receiptResponseObjectActual.ResponseArray){
                            Receipt__c recordToupdate = new Receipt__c();
                            recordToupdate.Id = resp.Sfid;
                            
                            ReceiptData data = receiptMap.get(resp.Sfid);
                            System.debug('Print comments '+ data.comments);
                            recordToupdate.Comments_Description__c = data.comments;

                            /* ---------------------------------------------------------------------------------------
                             * FIX (Arvind, 06 Jul 2026):
                             * --------------------------------------------------------------------------------- */
                            if(resp.Status == 'S'){
                                recordToupdate.OICNoOfRetries__c = null;
                                recordToupdate.ReverseReasonstatus__c = 'S';
                                recordToupdate.OICIntegrationMessage__c = null; // clear any stale error message

                                if (String.isNotBlank(data.reason) && reasonValueToCodeMap.containsKey(data.reason)) {
                                    if(data.reason == 'Cheque Replace' || data.reason == 'Cheque Returned'){
                                        recordToupdate.Status__c = 'Returned to customer';
                                    }else if(data.reason == 'Accounting Error' || data.reason == 'Cancelled'){
                                        recordToupdate.Status__c = 'Cancelled';
                                    }else{
                                        recordToupdate.Status__c = 'Bounced';
                                    }
                                    recordToupdate.isReverseEBS__c = true;
                                    recordToupdate.Cheque_Bounce_Reason__c = data.reason;
                                    //recordToupdate.Comments_Description__c = data.comments;
                                }
                            }else if(resp.Status == 'E'){
                                recordToupdate.ReverseReasonstatus__c = 'E';
                                if(resp.ErrorMsg != null){ //9.0 Error message OICIntegrationMessage
                                    Map<String, String> errorMsgMap = new Map<String, String>();
                                    for (Integration_Error_Messages__mdt m : [   SELECT System_Error_Msg__c, User_Error_Msg__c
                                            FROM Integration_Error_Messages__mdt
                                            WHERE IsActive__c = true AND Application_Type__c = 'EBS']) {
                                            errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
         }
                                    String userErrorMsg = null;
                                    userErrorMsg = UserErrorMessage.getUserErrorMessage(resp.ErrorMsg,errorMsgMap);
                                    if(userErrorMsg == null){
                                        recordToupdate.OICIntegrationMessage__c = 'Required information is not updated in Salesforce. Please contact support, '+resp.ErrorMsg;
                                    }else if(resp.ErrorMsg.contains('Unknown integration error')){
                                        recordToupdate.OICIntegrationMessage__c = 'Required information is not updated in Salesforce. Please contact support';
                                    }                                                                                                         
                                }  
                                if(mp_recId_NoOfReTries <> null && !mp_recId_NoOfReTries.isEmpty() && mp_recId_NoOfReTries.containsKey(resp.Sfid) && mp_recId_NoOfReTries.get(resp.Sfid) <> null)
                                    recordToupdate.OICNoOfRetries__c = mp_recId_NoOfReTries.get(resp.Sfid) + 1; // increment the count
                                else 
                                    recordToupdate.OICNoOfRetries__c = 1;
                            }      
                            lstRecordToUpdate.add(recordToupdate);
                        }                        
                        if(!lstRecordToUpdate.isEmpty()){
                            system.debug('lstRecordToUpdate---'+lstRecordToUpdate);
                            update lstRecordToUpdate;
                        }
                    }                    
                }                
                // Create API Callout Log (for both Success and Error)
                //PARAMS: string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode
                LoggerService.save(LoggerService.createAPILog('Receipt API','OIC_ManageSalesforceDataController','createReceipt', receiptWrappString, receiptResponseStringActual, 'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));
                
            }            
        }
        catch(Exception ex){            
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(ex, 'Receipt API','OIC_ManageSalesforceDataController','createReceipt'));
            System.debug('>>>> Exception in createReceipt: ' + ex.getMessage());
            throw new StringException(ex.getStackTraceString());
        }
    }

}