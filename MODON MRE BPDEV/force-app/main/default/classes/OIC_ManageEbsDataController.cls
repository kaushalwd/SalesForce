/**********************************************************************************************************************
* Name               : OIC_ManageEbsDataController
* Description        : Controller for is used for Seding if any sync alloaction is unapplied.
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            20 Jan 2026          Initial Draft
* 1.1			Karunakar		 Aug 21 2026	      Bypass flag update

***********************************************************************************************************************/
public class OIC_ManageEbsDataController {
  /** 
 * Handles updates to Allocation records when the Unapplied Amount changes.
 * If an Allocation's status changes to 'Unapplied' and it has an Oracle Party Id,
 * the Allocation Id is collected and sent to Oracle asynchronously. *
 * @param set of Allocation records after update * 
 */
     public static void createUnAppliedAllocation(set<String> allocationIds){        
        try{
            List<Allocation__c> allocationLst = [SELECT Id, Name, Receipt__c, Invoice__c, Receipt__r.TotalAmount__c,
                                                 Receipt__r.OraclePartyId__c,Invoice__r.Ebs_Invoice_Date__c, 
                                                 Invoice__r.OraclePartyId__c, AllocationAmount__c, AllocationDate__c, 
                                                 Status__c,Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                                                 Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                                                 Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c 
                                                 FROM Allocation__c 
                                                 WHERE Id IN : allocationIds AND OraclePartyId__c != null AND Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt'];
            
            List<OIC_RequestWrapperController.AllocationWrapper> allocationWrapLst = new List<OIC_RequestWrapperController.AllocationWrapper>();
            
            for(Allocation__c allocationObj : allocationLst){
                
                OIC_RequestWrapperController.AllocationWrapper allocationWrapObj = new OIC_RequestWrapperController.AllocationWrapper();
                
                allocationWrapObj.Sfid = allocationObj.Id;
                allocationWrapObj.SfReference = allocationObj.Id;
                allocationWrapObj.ReceiptSfid = allocationObj.Receipt__c;
                
                allocationWrapObj.CashReceiptId = allocationObj.Receipt__r.OraclePartyId__c;
                allocationWrapObj.InstallmentInvoiceSfid = allocationObj.Invoice__c;
                allocationWrapObj.CustomerTrxId = allocationObj.Invoice__r.OraclePartyId__c;
                allocationWrapObj.ResyncUnApply = 'Y';
                if(allocationObj.AllocationDate__c <> null)
                    allocationWrapObj.AllocationDate = Date.valueOf(allocationObj.AllocationDate__c);
                else {
                    allocationWrapObj.AllocationDate = null;
                }                
                allocationWrapObj.AllocationGlDate = system.today();
                if(allocationObj.AllocationAmount__c <> null){
                    Decimal ebsSendAmount = allocationObj.Receipt__r.TotalAmount__c < allocationObj.AllocationAmount__c ? allocationObj.Receipt__r.TotalAmount__c : allocationObj.AllocationAmount__c;
                    allocationWrapObj.AllocationAmount = String.valueOf(ebsSendAmount);
                }
                allocationWrapObj.Status = allocationObj.Status__c;
                if(allocationObj.Receipt__r.SalesOrderInstallment__c != null){
                    allocationWrapObj.ProjectPhase =allocationObj.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                    allocationWrapObj.EntityName =allocationObj.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                    
                }else{
                    allocationWrapObj.ProjectPhase =allocationObj.Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name;
                    allocationWrapObj.EntityName =allocationObj.Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;                    
                }                
                allocationWrapLst.add(allocationWrapObj);
            }
            
            HttpRequest req = new HttpRequest();
            req = OIC_CredentialsController.getCredentials('ModonFusionAllocationAPI');
            req.setTimeout(120000);
            
            OIC_RequestWrapperController.AllocationWrapperLst allocationWrapperList = new OIC_RequestWrapperController.AllocationWrapperLst();
            allocationWrapperList.RequestArray = allocationWrapLst;
            
            String allocationWrapString = JSON.serialize(allocationWrapperList);
            
            system.debug('JSON.serialize(allocationWrapString)==>' + JSON.serialize(allocationWrapString));
            Blob binaryData = Blob.valueOf(allocationWrapString);
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
            
            String allocationResponseBody = res.getBody();
            
            // PARSING THE RESPONSE //
            if(allocationResponseBody <> null && allocationResponseBody <> ''){
                
                OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(allocationResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                
                blob allocationResponseBlobActual = null;
                string allocationResponseStringActual = null;
                
                if(base64RespWrap.Base64Response <> null && base64RespWrap.Base64Response <> '')
                    allocationResponseBlobActual = EncodingUtil.base64Decode(base64RespWrap.Base64Response); 
                if(allocationResponseBlobActual <> null)
                    allocationResponseStringActual = allocationResponseBlobActual.toString();
                
                System.debug('allocationResponseStringActual:::: ' + allocationResponseStringActual);
                
                if(allocationResponseStringActual <> null){
                    OIC_RequestWrapperController.OICResponseWrapperList allocationResponseObjectActual = (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(allocationResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    
                    if(allocationResponseObjectActual <> null){
                        list<Allocation__c> lstAllocationToUpdate = new list<Allocation__c>();
                        
                        set<string> recordIds = new set<string>();
                        map<string, integer> mp_recId_NoOfReTries = new map<string, integer>();
                        
                        for(OIC_RequestWrapperController.OICResponseWrapper resp : allocationResponseObjectActual.ResponseArray){
                            recordIds.add(resp.Sfid);
                        }
                        
                        if(!recordIds.isEmpty()){
                            list<Allocation__c> recs = [select Id, OICNoOfRetries__c from Allocation__c where Id in: recordIds and OICNoOfRetries__c != null];
                            for(Allocation__c rec: recs){
                                mp_recId_NoOfReTries.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
                            }
                        }
                        
                        for(OIC_RequestWrapperController.OICResponseWrapper allocationResp : allocationResponseObjectActual.ResponseArray){
                            Allocation__c allocationToupdate = new Allocation__c();
                            allocationToupdate.Id = allocationResp.Sfid;
                            allocationToupdate.OraclePartyId__c = allocationResp.OracleId;
                            //allocationToupdate.OICIntegrationMessage__c = allocationResp.ErrorMsg;
                            allocationToupdate.OICIntegrationStatus__c = allocationResp.Status;                            
                            if(allocationResp.Status == 'S')
                                allocationToupdate.OICNoOfRetries__c = null;
                            else if(allocationResp.Status == 'E'){
                                if(allocationResp.ErrorMsg != null){ //9.0 start Error message OICIntegrationMessage
                                    Map<String, String> errorMsgMap = new Map<String, String>();
                                    for (Integration_Error_Messages__mdt m : [
                                        SELECT System_Error_Msg__c, User_Error_Msg__c
                                        FROM Integration_Error_Messages__mdt
                                        WHERE IsActive__c = true AND Application_Type__c = 'EBS'
                                    ]) {
                                        errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
                                    }
                                    String userIntErrorMsg = null;
                                    userIntErrorMsg = UserErrorMessage.getUserErrorMessage(allocationResp.ErrorMsg,errorMsgMap); 
                                    if(userIntErrorMsg == null){
                                        allocationToupdate.OICIntegrationMessage__c = 'Required information is not updated in Salesforce. Please contact support, '+allocationResp.ErrorMsg;
                                    }else if(allocationResp.ErrorMsg.contains('Unknown integration error')){
                                        allocationToupdate.OICIntegrationMessage__c = 'Required information is not updated in Salesforce. Please contact support';
                                    } //9.0 end
                                    
                                }
                                if(mp_recId_NoOfReTries <> null && !mp_recId_NoOfReTries.isEmpty() && mp_recId_NoOfReTries.containsKey(allocationResp.Sfid) && mp_recId_NoOfReTries.get(allocationResp.Sfid) <> null)
                                    allocationToupdate.OICNoOfRetries__c = mp_recId_NoOfReTries.get(allocationResp.Sfid) + 1; // increment the count
                                else 
                                    allocationToupdate.OICNoOfRetries__c = 1;
                            }
                            
                            lstAllocationToUpdate.add(allocationToupdate);
                        }
                        
                        if(!lstAllocationToUpdate.isEmpty()){
                            update lstAllocationToUpdate;
                        }
                    }                    
                }                
                // Create API Callout Log (for both Success and Error)
                //PARAMS: string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode
                LoggerService.save(LoggerService.createAPILog('Allocation API','OIC_ManageSalesforceDataController','createAllocation', allocationWrapString, allocationResponseStringActual, 'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));
                
            }            
        }        
        catch(Exception ex){            
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(ex, 'Allocation API','OIC_ManageSalesforceDataController','createAllocation'));
        }
    }
    /**
 * Creates Unidentified Receipts in Oracle (EBS/Fusion) via OIC integration.
 *
 * This method:
 * Fetches Receipt records based on the provided Ids ,send the payload to Oracle using an HTTP callout
 * *
 * @param receiptIds Set of Receipt record Ids to be processed
 */
    public static void createUnidentifiedReceipt(set<String> receiptIds){
        try{
            
            List<Receipt__c> recLst = [SELECT Id, Name, Receipt_Amount__c,Receipt_Approved_Date__c,Account__c, SalesOrder__c, SalesOrderInstallment__c,  AppliedAmount__c,
                                       SalesOrder__r.ProjectName__c,SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                                       PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, TransactionDate__c,
                                       PaymentEscrowAccount__r.IBANNo__c, PaymentEscrowAccount__r.Name, TransactionNumber__c, ExpressionOfInterest__c,
                                       Modeofpayment__c, ReceiptDate__c,ChequeDate__c, TotalAmount__c, Bank__c, Status__c, SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c,
                                       SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                                       SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c,ReceiptRemarks__c,
                                       SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                                       SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                       SalesOrder__r.Unit__r.Phase__r.EntityName__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                       EBS_Clearing_Date__c ,Charge__r.Type__c, Cheque_Number__c, SalesOrder__r.CustAcctId__c, 
                                       SalesOrder__r.OraclePartySiteID__c,SalesOrder__r.OracleCustAcctSiteID__c,
                                       SalesOrder__r.OracleSiteUseID__c,SalesOrder__r.NotToBeShownOnRD__c, Cheque_Bounce_Reason__c, 
                                       Reason_Code__c, OraclePartyId__c,isReverseEBS__c,EntityName__c
                                       FROM Receipt__c WHERE Id IN : receiptIds 
                                       and Account__c != null and SalesOrder__r.Source_Entity__c != 'Modon - Egypt'];
            
            List<OIC_RequestWrapperController.ReceiptWrapper> receiptWrapLst = new List<OIC_RequestWrapperController.ReceiptWrapper>();
            map<id,boolean> receiptMap =new map<id,boolean>();
            
            for(Receipt__c recObj : recLst){
                OIC_RequestWrapperController.ReceiptWrapper receiptWrapObj = new OIC_RequestWrapperController.ReceiptWrapper();
                receiptWrapObj.Sfid = recObj.Id;
                receiptWrapObj.SfReference = recObj.Name;
                receiptWrapObj.CustomerSfid = recObj.Account__c;
                receiptWrapObj.CustomerPartyId = recObj.Account__r.OraclePartyId__c;
                receiptWrapObj.VirtualAccountNumber = recObj.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
                receiptWrapObj.VirtualIbanNumber = recObj.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
                receiptWrapObj.OrgIdentifier = UserInfo.getOrganizationId();
                
                receiptWrapObj.ProjectName = recObj.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                receiptWrapObj.ExtraInfo2 = recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                receiptWrapObj.EntityName=recObj.EntityName__c;				
                receiptWrapObj.ProjectPhase = recObj.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;		
                receiptWrapObj.TrxnType = 'INSTALLMENT';
                //receiptWrapObj.Description = recObj.Milestone_Description__c;
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
                receiptWrapObj.Description = recObj.ReceiptRemarks__c;
                receiptWrapObj.EoiFlag = recObj.ExpressionOfInterest__c != null ? 'Y' : 'N';
                
                if(recObj.Receipt_Approved_Date__c <> null){
                    //receiptWrapObj.Bypass = 'N';
                    receiptMap.put(recObj.id,true);
                }else{
                    //receiptWrapObj.Bypass = 'Y';
                }
                receiptWrapObj.Bypass = 'N';
                receiptWrapObj.Unidentified = 'Y';
                if(recObj.Account__c != System.Label.Unidentified_Account){
                    //receiptWrapObj.OraclePartyId =recObj.OraclePartyId__c;
                    receiptWrapObj.UNIDENTIFIED_CUST_ACCT_ID = recObj.SalesOrder__r.CustAcctId__c;
                	receiptWrapObj.UNIDENTIFIED_RECEIPT_ID = recObj.OraclePartyId__c;
                }else {
                    receiptMap.put(recObj.id,true);
                }
                
                
                receiptWrapLst.add(receiptWrapObj);
            }
            
            HttpRequest req = new HttpRequest();
            req = OIC_CredentialsController.getCredentials('ModonFusionReceiptAPI');
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
                                 /*if(receiptMap.containskey(recordToupdate.Id)){
                                	recordToupdate.Oracle_Id_Temporary__c = resp.OracleId;
                                }else{
                                    recordToupdate.OraclePartyId__c = resp.OracleId;
                                }*/
                            	//recordToupdate.Oracle_Id_Temporary__c = resp.OracleId;
                                //recordToupdate.OICIntegrationStatus__c = resp.Status;
                            
                            //if(resp.Status == 'S')
                                //recordToupdate.OICNoOfRetries__c = null;
                            if (String.isNotBlank(resp.Status) && resp.Status == 'S') { 
                                recordToupdate.OICNoOfRetries__c = null; 
                                recordToupdate.OICIntegrationMessage__c = null;
                                recordToupdate.Oracle_Id_Temporary__c = resp.OracleId;
                                recordToupdate.OICIntegrationStatus__c = resp.Status;                                
                            }else if(resp.Status == 'E'){
                                if(resp.ErrorMsg != null){ //9.0 Error message OICIntegrationMessage
                                    Map<String, String> errorMsgMap = new Map<String, String>();
                                    for (Integration_Error_Messages__mdt m : [
                                        SELECT System_Error_Msg__c, User_Error_Msg__c
                                        FROM Integration_Error_Messages__mdt
                                        WHERE IsActive__c = true AND Application_Type__c = 'EBS'
                                    ]) {
                                        errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
                                    }
                                    String userErrorMsg = null;
                                    userErrorMsg = UserErrorMessage.getUserErrorMessage(resp.ErrorMsg,errorMsgMap);
                                    if(userErrorMsg == null){
                                        recordToupdate.OICIntegrationMessage__c = 'Required information is not updated in Salesforce. Please contact support, '+resp.ErrorMsg;
                                    }else if(resp.ErrorMsg.contains('Unknown integration error')){
                                        recordToupdate.OICIntegrationMessage__c = 'Required information is not updated in Salesforce. Please contact support';
                                    }
                                    recordToupdate.Receipt_Approved_Checker__c =false;
                                    recordToupdate.Receipt_Approved_Date__c = null;
                                    recordToupdate.Receipt_Approved_By__c = null;                                                                      
                                }  //9.0 end
                                if(mp_recId_NoOfReTries <> null && !mp_recId_NoOfReTries.isEmpty() && mp_recId_NoOfReTries.containsKey(resp.Sfid) && mp_recId_NoOfReTries.get(resp.Sfid) <> null)
                                    recordToupdate.OICNoOfRetries__c = mp_recId_NoOfReTries.get(resp.Sfid) + 1; // increment the count
                                else 
                                    recordToupdate.OICNoOfRetries__c = 1;
                            }                            
                            
                            lstRecordToUpdate.add(recordToupdate);
                        }
                        
                        if(!lstRecordToUpdate.isEmpty()){
                            update lstRecordToUpdate;
                        }
                    }
                    
                }
                
                // Create API Callout Log (for both Success and Error)
                //PARAMS: string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode
                LoggerService.save(LoggerService.createAPILog('Receipt API','OIC_ManageSalesforceDataController','createReceipt', receiptWrappString, receiptResponseStringActual, 'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));
                
            }
            // }
        }
        catch(Exception ex){
            
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(ex, 'Receipt API','OIC_ManageSalesforceDataController','createReceipt'));
            System.debug('>>>> Exception in createReceipt: ' + ex.getMessage());
            //throw new StringException(ex.getStackTraceString());
            if (!Test.isRunningTest()) {
        throw new StringException(ex.getMessage());
    }
        }
        
    } 
    
}