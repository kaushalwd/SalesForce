/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceDataController                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : PWC Digital Middle East                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                      
* 1.0           Anil Valluri				29 Feb 2024     Initial Draft
* 2.0			Manoj						13 sep 2025		Update for Multi Entity
* 3.0           Manoj						29 Sep 2025		Update the Bug Fix EBS
* 4.0           Kumar                       10 Oct 2025		Update Logic for new change
* 5.0           Kumar						18 Oct 2025		Update The DL data and bulkBypass
* 5.1           Kumar						21 Oct 2025		Update The Bugfix on invoices
* 5.2           Kumar						21 Oct 2025		Update The Bugfix on invoices/Receipt
* 5.3           Kumar						11 Oct 2025		Update The Bugfix on for Date and amount invoices/Receipt
* 6.0			Manoj						28 Nov 2025		Update on the bypass the Not To Be Shown On RD projects to Ebs and source entity checked
* 6.1           Manoj						28 Nov 2025		Update missing else
* 7.0			Manoj						24 Dec 2025		Update logic realted to CreditNoteService
* 8.0           kumaravel                   02 Jan 2026     Update trans type hard code changes
* 9.0			Manoj						20 Jan 2026		Update Errormessage responce, Reverse Receipt logic and allocation GL data
* 10.0			Manoj						20 Feb 2026		Update Errormessage remove once it Success and update GL date
* 11.0			Manoj						02 May 2026		Added code for unit cancellation
* 12.0          Manoj                       05-May 2026     Added code logic for Fusion process
* 13.0			Manoj						13 May 2026		Remove bypass on account
* 14.0			Manoj						14 May 2026		Add Logic to error
* 15.0          Manoj						17 May 2026		Add ADM Waiver type
* 16.0		    Suresh						03 June 2026 	Hudayriyat Golf Estates project change
* 17.0			Arvind                      09 June 2026    Fix TrxnType for ADM receipts - added Is_ADM_Fees_And_Dari_charges__c
*                                                           to SOQL and added fallback conditions before INSTALLMENT default
* 18.0			Manoj						17 June 2026	Fix Receipt TrxnType
* 19.0			Manoj						18 June 2026    Fix Tax bug 
* 20.0			Modon IT 					27 Jul 2026		Refactor Receipt and Invoice queries, Added customer bank details in Invoice callout(createInstallment)
* 21.0 			Karunakar					Aug 20, 2026	OracleId for Receipt fix
* 22.0			MODON IT					Aug 26, 2026	Refactor createInstallment - wrapper building moved to
*                                                           OIC_SFDataWrapperGenerator, callout moved to
*                                                           OIC_InvoiceExternalService, IBAN URL lookup limited to
*                                                           Customer Refund invoices
* 23.0			Karunakar					Aug 26, 2026	createInstallment now cancels an already-synced Advance Tax
*                                                           Invoice in Oracle first; installments whose cancellation
*                                                           fails are held back for the next run
* 24.0			Priyanka					27 Aug 2026		MCR-48: collect OIC error logs; one Logger DML after loop
* 25.0			Priyanka					31 Aug 2026		ResponseArray NPE guard; callout-limit stop in updateUnitStatus;
*                                                           credit-receipt null-safe related records; allocation amount
*                                                           still uses receipt total when present (null total unchanged)
***********************************************************************************************************************/

public class OIC_ManageSalesforceDataController {
    
    // ── SHARED HELPERS ────────────────────────────────────────────────────────
    // start 12.0
    /** Load Integration_Error_Messages__mdt ONCE per method; pass map into loop. */
    /**
     * Description : Loads active EBS error message metadata  
     *               into a map for user-friendly resolution.  
     */
    @TestVisible
    private static Map<String,String> loadErrorMsgMap() {
        Map<String,String> m = new Map<String,String>();
        for (Integration_Error_Messages__mdt r : [
                SELECT System_Error_Msg__c, User_Error_Msg__c
                FROM   Integration_Error_Messages__mdt
                WHERE  IsActive__c = true AND Application_Type__c = 'EBS'])
            m.put(r.System_Error_Msg__c, r.User_Error_Msg__c);
        return m;
    }
	/**
     * Description : Resolves a system OIC error message to   
     *               a user-friendly display message.         
     */
    @TestVisible
    private static String resolveErrMsg(String sysMsg, Map<String,String> errMap) {
        String u = UserErrorMessage.getUserErrorMessage(sysMsg, errMap);
        if (u == null)                                                     return 'Required information is not updated in Salesforce. Please contact support, ' + sysMsg;
        if (sysMsg != null && sysMsg.contains('Unknown integration error')) return 'Required information is not updated in Salesforce. Please contact support';
        return u;
    }

    /**
     * Description : Bulk-loads OIC retry counts for given    
     *               object IDs into a map before response.   
     */
    @TestVisible
    private static Map<String,Integer> loadRetryMap(String objName, Set<String> ids) {
        Map<String,Integer> m = new Map<String,Integer>();
        if (ids == null || ids.isEmpty()) return m;
        for (SObject r : Database.query('SELECT Id, OICNoOfRetries__c FROM ' + objName + ' WHERE Id IN : ids AND OICNoOfRetries__c != null'))
            m.put((String)r.get('Id'), Integer.valueOf((Decimal)r.get('OICNoOfRetries__c')));
        return m;
    }
	/**
     * Description : Returns the next retry count for a       
     *               given SFID from the retry count map.     
     */
    @TestVisible
    private static Integer nextRetry(Map<String,Integer> m, String sfid) {
        return (m != null && m.containsKey(sfid) && m.get(sfid) != null) ? m.get(sfid) + 1 : 1;
    }

    /**
     * Central OIC-error logger — builds one Logger__c per E-status record (same fields as before).
     * Caller collects these and saves once after the response loop (MCR-48: no DML in the loop).
     */
    @TestVisible
    private static Logger__c logOICError(String process, String cls, String method,
                                    String reqBody, String respBody,
                                    String sfid, String oicMsg,
                                    Integer httpCode, String httpStatus) {
        String detail = 'OIC Error | SFID: ' + sfid
                      + ' | OIC Msg: '       + oicMsg
                      + ' | HTTP: '          + httpCode + ' ' + httpStatus;
        return LoggerService.createAPILog(process, cls, method, reqBody, respBody, detail, 'OIC Error Log');
    }

    /** MCR-48: one Logger upsert for the collected OIC error rows. */
    @TestVisible
    private static void saveOICErrorLogs(List<Logger__c> logs) {
        if (logs != null && !logs.isEmpty()) LoggerService.save(logs);
    } //End 12.0

    /**
     * Description : Sends unit status update for given IDs   
     *               to Oracle via Fusion callout.        
     */
    public static void updateUnitStatus(set<String> unitIds) {
        List<Unit__c> unitLst = [SELECT Id, Status__c FROM Unit__c WHERE Id IN :unitIds];
        // MCR-48: Fusion still one callout per unit (same payload); Logger DML after the loop.
        List<Logger__c> unitLogs = new List<Logger__c>();
        for (Unit__c unitObj : unitLst) {
            // Same per-unit Fusion payload; stop before callout 101 so the transaction does not abort.
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                unitLogs.add(LoggerService.createAPILog(
                    'Unit Status API','OIC_ManageSalesforceFusionDataController','updateUnitStatus',
                    JSON.serialize(unitIds), null,
                    'Callout limit reached; remaining units not sent this transaction. First unsent: ' + unitObj.Id,
                    'Callout Error Log'));
                break;
            }

            OIC_RequestWrapperController.UnitUpdateWrapper w = new OIC_RequestWrapperController.UnitUpdateWrapper();
            w.Id = unitObj.Id; w.Status = unitObj.Status__c;
            String reqBody = JSON.serialize(w);
            String resBody = null;
            try {
                HttpRequest req = new HttpRequest();
                req.setTimeout(120000);
                req.setHeader('Accept', 'application/json');
                req = OIC_CredentialsController.getCredentials('ModonFusion3DSUpdateUnitUAT');
                req.setBody(reqBody);
                System.debug('JSON.serialize(unitUpdatObj)==>' + reqBody);
                Http http = new Http();
                HTTPResponse res = http.send(req);
                resBody = res.getBody();
                System.debug(res); System.debug(resBody);
            } catch (Exception ex) {
                unitLogs.add(LoggerService.createAPILog(
                    'Unit Status API','OIC_ManageSalesforceFusionDataController','updateUnitStatus',
                    reqBody, resBody,
                    'Exception: '+ '500 Error', 'Callout Error Log'));
                unitLogs.add(LoggerService.createApexLog(ex,'Unit Status API','OIC_ManageSalesforceFusionDataController','updateUnitStatus'));
            }
        }
        saveOICErrorLogs(unitLogs);
    }
    // start 12.0
    // ── createReceipt ─────────────────────────────────────────────────────────
    /**
     * Description : Builds receipt payload and sends it to   
     *               Oracle via Fusion receipt API callout.   
     */
    public static void createReceipt(Set<String> receiptIds) {
        String receiptWrappString = null, receiptResponseStringActual = null;
        HTTPResponse res = null;
        try {
         	//16.0 - Hudayriyat Golf Estates project changes
            //V20.0 - Start
            List<Receipt__c> receipts = ReceiptSelector.getReceiptsById(receiptIds);
            Map<id,boolean> receiptMap = new Map<id,boolean>(); 
            
            //Initilizing ReceiptWrapper of OIC_RequestWrapperController to wrap Receipt Data            
            List<OIC_RequestWrapperController.ReceiptWrapper> receiptWrapLst =
                OIC_SFDataWrapperGenerator.generateReceiptWrappers(receipts, receiptMap);
            
			//Initilizing ReceiptWrapperList and Call Receipt API
            OIC_RequestWrapperController.ReceiptWrapperLst receiptWrapperList = new OIC_RequestWrapperController.ReceiptWrapperLst();
            receiptWrapperList.RequestArray = receiptWrapLst;
            receiptWrappString = JSON.serialize(receiptWrapperList);
            System.debug('JSON.serialize(receiptWrappString)==>' + receiptWrappString);
            
            //Call Receipt API
            res = OIC_ReceiptExternalService.sendReceipt(receiptWrappString);
			//V20.0 - End

            String receiptResponseBody = res.getBody();
            
            System.debug('receiptResponseBody::: ' + receiptResponseBody);
            if (receiptResponseBody != null && receiptResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(receiptResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                
                Blob  receiptResponseBlob= null;
                if (b64.Base64Response != null && b64.Base64Response != '') {
                    receiptResponseBlob = EncodingUtil.base64Decode(b64.Base64Response);
                }
                if (receiptResponseBlob != null) {
                    receiptResponseStringActual = receiptResponseBlob.toString();
                }
                System.debug('receiptResponseStringActual:::: ' + receiptResponseStringActual);
                if (receiptResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(receiptResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) {
                            ids.add(r.Sfid);
                        }
                        
                        Map<String,Integer> retryMap = loadRetryMap('Receipt__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        list<Receipt__c> lstToUpdate = new list<Receipt__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        
                        for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                            Receipt__c rec = new Receipt__c(Id = resp.Sfid);                            
                            if (resp.Status == 'S') {
                                rec.OICNoOfRetries__c = null; 
                                rec.OICIntegrationMessage__c = null; //start 14.0
                                rec.Oracle_Id_Temporary__c = resp.OracleId;//21.0
                                /*if (receiptMap.containskey(rec.Id)) {
                                    rec.Oracle_Id_Temporary__c = resp.OracleId;
                                }else { 
                                    rec.OraclePartyId__c = resp.OracleId;
                                }*/
                                rec.OICIntegrationStatus__c = resp.Status; // End 14.0
                            } else if (resp.Status == 'E') {
                                if (resp.ErrorMsg != null) rec.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                                rec.Receipt_Approved_Checker__c = false; 
                                rec.Receipt_Approved_Date__c = null; 
                                rec.Receipt_Approved_By__c = null;
                                rec.OICIntegrationStatus__c = resp.Status; // End 14.0
                                rec.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                                oicErrorLogs.add(logOICError('Receipt API','OIC_ManageSalesforceFusionDataController','createReceipt',
                                            receiptWrappString, receiptResponseStringActual,
                                            resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus()));
                            }
                            lstToUpdate.add(rec);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()) update lstToUpdate;
                    }

                }
                LoggerService.save(LoggerService.createAPILog('Receipt API','OIC_ManageSalesforceFusionDataController','createReceipt',
                    receiptWrappString, receiptResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Receipt API','OIC_ManageSalesforceFusionDataController','createReceipt',
                receiptWrappString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Receipt API','OIC_ManageSalesforceFusionDataController','createReceipt'));
            System.debug('>>>> Exception in createReceipt: ' + ex.getMessage());
            throw ex;
        }
    }

    // ── createSalesOrderAndSOInstallments ─────────────────────────────────────
    /**
     * Description : Builds sales order and installment data  
     *               and sends it to Oracle via OIC callout.  
     */
    public static void createSalesOrderAndSOInstallments(set<String> salesOrderIDs) {
        String soWrapperFinalString = null, soResponseStringActual = null;
        HTTPResponse res = null;
        try {//15.0 Add SOQL
            List<SalesOrder__c> soList = [SELECT Id, Name, CustomerAccount__c, CustomerAccount__r.OraclePartyId__c,
                                          Unit__r.Name, UnitOption__r.Name, PaymentPlan__r.Name, Unit__r.Phase__r.Name,
                                          Unit__r.Project_Name__c, Unit__r.Phase__r.EntityName__c, TotalAmount__c,
                                          VirtualAccount__r.VirtualAccountNumber__c, VirtualAccount__r.VirtualIBANNumber__c,
                                          SalesAssociate__r.Name, Status__c, ProjectName__c,ADM_Fees_Dari_charges__c,Discount_Amount__c,
                                          CustAcctId__c, OraclePartySiteID__c, OracleCustAcctSiteID__c, OracleSiteUseID__c,
                                          (SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, InstallmentAmount__c,
                                                  MilestoneDate__c, Milestone__c, PaymentStatus__c, Balance_Amount__c
                                           FROM   Sales_Order_Installments__r)
                                          FROM SalesOrder__c
                                          WHERE Id IN :salesOrderIDs AND NotToBeShownOnRD__c = false
                                          AND Source_Entity__c != 'Modon - Egypt' AND CustomerAccount__r.OraclePartyId__c != null];

            OIC_RequestWrapperController.SalesOrderWrapperLst soWrapListFinal = new OIC_RequestWrapperController.SalesOrderWrapperLst();

            List<OIC_RequestWrapperController.SalesOrderWrapper> soWrapList = new List<OIC_RequestWrapperController.SalesOrderWrapper>();
            for (SalesOrder__c so : soList) {
                OIC_RequestWrapperController.SalesOrderWrapper soWrap = new OIC_RequestWrapperController.SalesOrderWrapper();
                soWrap.Sfid = so.Id; 
                soWrap.SfReference = so.Name; 
                soWrap.CustomerSfid = so.CustomerAccount__c;
                soWrap.CustomerPartyId = so.CustomerAccount__r.OraclePartyId__c; soWrap.CustomerAcct = '';
                soWrap.UnitName = so.Unit__r.Name; 
                soWrap.UnitOption = so.UnitOption__r.Name; 
                soWrap.PaymentPlan = so.PaymentPlan__r.Name;
                soWrap.Phase = so.Unit__r.Phase__r.Name; 
                soWrap.Project = so.Unit__r.Project_Name__c;
                soWrap.TotalAmount = so.TotalAmount__c != null ? string.valueOf(so.TotalAmount__c) : null;
                soWrap.AdmAmount            = so.ADM_Fees_Dari_charges__c != null ?string.valueOf(so.ADM_Fees_Dari_charges__c) : '0'; // 15.0
            	soWrap.DiscountAmount       = so.Discount_Amount__c != null ? string.valueOf(so.Discount_Amount__c) : '0'; //15.0
            	soWrap.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
                soWrap.VirtualIbanNumber = so.VirtualAccount__r.VirtualIBANNumber__c;
                soWrap.SalesAssociateName = so.SalesAssociate__r.Name; soWrap.Status = so.Status__c;
                soWrap.OrgIdentifier = UserInfo.getOrganizationId(); soWrap.ProjectName = so.ProjectName__c;
                soWrap.Unit = so.Unit__r.Name; 
                soWrap.ProjectPhase = so.Unit__r.Phase__r.Name;
                soWrap.EntityName = so.Unit__r.Phase__r.EntityName__c; 
                soWrap.CustAcctId = so.CustAcctId__c;
                soWrap.OraclePartySiteID = so.OraclePartySiteID__c; 
                soWrap.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c;
                soWrap.OracleSiteUseID = so.OracleSiteUseID__c;
                list<OIC_RequestWrapperController.SalesOrderInstallmentWrapper> soiWrapList = new list<OIC_RequestWrapperController.SalesOrderInstallmentWrapper>();
                for (SalesOrderInstallments__c soi : so.Sales_Order_Installments__r) {
                    OIC_RequestWrapperController.SalesOrderInstallmentWrapper sw = new OIC_RequestWrapperController.SalesOrderInstallmentWrapper();
                    sw.InstallmentSfid = soi.Id; 
                    sw.InstallmentfReference = soi.Name;
                    sw.InstallmentNumber = soi.MilestoneNumber__c != null ? string.valueOf(soi.MilestoneNumber__c) : null;
                    sw.InstallementDescription = soi.MilestoneDescription__c; 
                    sw.InstallmentDate = soi.MilestoneDate__c;
                    sw.InstallementAmount = soi.InstallmentAmount__c != null ? string.valueOf(soi.InstallmentAmount__c) : null;
                    sw.InstallementStatus = soi.PaymentStatus__c; 
                    sw.ExtraInfo1 = string.valueOf(soi.MilestoneDate__c);
                    sw.ExtraInfo2 = string.valueOf(soi.Milestone__c);
                    sw.ExtraInfo3 = soi.PaymentStatus__c;
                    sw.ExtraInfo4 = string.valueOf(soi.Balance_Amount__c);
                    soiWrapList.add(sw);
                }
                soWrap.SalesOrderLines = soiWrapList;
                soWrapList.add(soWrap);
            }
            soWrapListFinal.RequestArray = soWrapList;
            soWrapperFinalString = JSON.serialize(soWrapListFinal);
            System.debug('soWrapperFinalString::::  ' + soWrapperFinalString);
            Blob binaryData = Blob.valueOf(soWrapperFinalString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionSalesOrderAPI2');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(wrapper)); req.setHeader('Accept', 'application/json');
            System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            res = http.send(req);
            System.debug('SALES ORDER RESPONSE:::: ' + res); System.debug('SALES ORDER RESPONSE BODY:::: ' + res.getBody());
            String soResponseBody = res.getBody();
            if (soResponseBody != null && soResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(soResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob soResponseBodyBlob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') soResponseBodyBlob = EncodingUtil.base64Decode(b64.Base64Response);
                if (soResponseBodyBlob != null) soResponseStringActual = soResponseBodyBlob.toString();
                System.debug('soResponseStringActual:::: ' + soResponseStringActual);
                if (soResponseStringActual != null) {
                    OIC_RequestWrapperController.OICSOResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICSOResponseWrapperList)JSON.deserialize(soResponseStringActual, OIC_RequestWrapperController.OICSOResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICSOResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('SalesOrder__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        list<SalesOrder__c> lstSOToUpdate = new list<SalesOrder__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICSOResponseWrapper soResp : respObj.ResponseArray) {
                            SalesOrder__c sou = new SalesOrder__c(Id = soResp.Sfid);                            
                            if (soResp.Status == 'S') { 
                                sou.OICNoOfRetries__c = null; 
                                sou.OICIntegrationMessage__c = null;//start 14.0
                                sou.OraclePartyId__c = soResp.OracleId;                                 
                                sou.OICIntegrationStatus__c = soResp.Status;
                                sou.CustAcctId__c = soResp.CustAcctId; 
                                sou.OraclePartySiteID__c = soResp.OraclePartySiteID;
                                sou.OracleCustAcctSiteID__c = soResp.OracleCustAcctSiteID; 
                                sou.OracleSiteUseID__c = soResp.OracleSiteUseID; // End 14.0
                            }
                            else if (soResp.Status == 'E') {
                                sou.OICIntegrationStatus__c = soResp.Status; //14.0
                                if (soResp.ErrorMsg != null){
                                    sou.OICIntegrationMessage__c = resolveErrMsg(soResp.ErrorMsg, errMap);
                                }
                                sou.OICNoOfRetries__c = nextRetry(retryMap, soResp.Sfid);
                                oicErrorLogs.add(logOICError('Sales Order API','OIC_ManageSalesforceFusionDataController','createSalesOrderAndSOInstallments',
                                            soWrapperFinalString, soResponseStringActual,
                                            soResp.Sfid, soResp.ErrorMsg, res.getStatusCode(), res.getStatus()));
                            }
                            lstSOToUpdate.add(sou);

                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstSOToUpdate.isEmpty()) 
                        update lstSOToUpdate;
                    }
                }
                LoggerService.save(LoggerService.createAPILog('Sales Order API','OIC_ManageSalesforceFusionDataController','createSalesOrderAndSOInstallments',
                    soWrapperFinalString, soResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));

            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Sales Order API','OIC_ManageSalesforceFusionDataController','createSalesOrderAndSOInstallments',
                soWrapperFinalString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Sales Order API','OIC_ManageSalesforceFusionDataController','createSalesOrderAndSOInstallments'));
        }

    }

    // ── createAccount ────────────────────────────────────────────────────────
    /**
     * Description : Builds customer account payload and      
     *               sends it to Oracle via Fusion API.       
     */
    public static void createAccount(set<String> accountIds) {
        String customerWrappString = null, custResponseStringActual = null;
        HTTPResponse res = null;
        List<String> excludeStatuses = new List<String>{'Modon - Egypt'};
        try {
            List<Account> accLst = [SELECT Id, Name, PersonTitle, FirstName, MiddleName, LastName, EIDNumber__pc, EmiratesIDExpiryDate__pc,
                                    (SELECT Id, Name, Email, EIDNumber__c, Birthdate, MobilePhone, Nationality__c FROM Contacts LIMIT 1),
                                    IsPersonAccount, TradeName__c, UnifiedNumber__c, PersonEmail, Phone, BillingCountry, PassportNumber__pc,
                                    PersonGenderIdentity, MaritalStatus__pc, PersonBirthdate, UAE_Resident_Status__pc, PassportExpiryDate__pc, Nationality__pc,
                                    BillingCity, BillingState, BillingAddress, BillingStreet, UAEVATRegisterNumber__c, PersonMobilePhone,
                                    PersonMailingCity, PersonMailingStreet, PersonMailingState, PersonMailingCountry, PersonMailingPostalCode
                                    FROM Account WHERE Id IN :accountIds AND Source_Entity__c NOT IN :excludeStatuses];
            List<OIC_RequestWrapperController.CustomerWrapper> customerWrapLst = new List<OIC_RequestWrapperController.CustomerWrapper>();
            for (Account accObj : accLst)
                customerWrapLst.add(accObj.IsPersonAccount ? createPersonWrapper(accObj) : createOrganizationWrapper(accObj));
            OIC_RequestWrapperController.CustomerWrapperLst customerWrapList = new OIC_RequestWrapperController.CustomerWrapperLst();
            customerWrapList.RequestArray = customerWrapLst;
            customerWrappString = JSON.serialize(customerWrapList);
            System.debug('JSON.serialize(customerWrapList)==>' + customerWrappString);
            Blob binaryData = Blob.valueOf(customerWrappString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionCustomerAPI2');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(wrapper));
            System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            res = http.send(req);
            System.debug('Create Account Res::::' + res); System.debug('Create Account Res Body::::' + res.getBody());
            String custResponseBody = res.getBody();
            if (custResponseBody != null && custResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(custResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob custResponseBlob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') custResponseBlob = EncodingUtil.base64Decode(b64.Base64Response);
                if (custResponseBlob != null) custResponseStringActual = custResponseBlob.toString();
                System.debug('custResponseStringActual:::: ' + custResponseStringActual);
                if (custResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(custResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('Account', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        list<Account> lstToUpdate = new list<Account>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                            Account acc = new Account(Id = resp.Sfid);                            
                            if (resp.Status == 'S') { 
                                acc.OICNoOfRetries__c = null; 
                                acc.OICIntegrationMessage__c = null;
                                acc.OraclePartyId__c = resp.OracleId; //14.0
                            	acc.OICIntegrationStatus__c = resp.Status; //14.0
                            }
                            else if (resp.Status == 'E') {
                                acc.OICIntegrationStatus__c = resp.Status; //14.0
                                if (resp.ErrorMsg != null) acc.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                                acc.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                                oicErrorLogs.add(logOICError('Customer API','OIC_ManageSalesforceFusionDataController','createAccount',
                                            customerWrappString, custResponseStringActual,
                                            resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus()));
                            }
                            lstToUpdate.add(acc);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()){
                            TriggerControl.BypassAccountTrigger =true;
                            update lstToUpdate;
                             //TriggerControl.BypassAccountTrigger =false; // 13.0

                        } 
                    }
                }
                LoggerService.save(LoggerService.createAPILog('Customer API','OIC_ManageSalesforceFusionDataController','createAccount',
                    customerWrappString, custResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Customer API','OIC_ManageSalesforceFusionDataController','createAccount',
                customerWrappString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Customer API','OIC_ManageSalesforceFusionDataController','createAccount'));
        }

    }

    // ── createCreditReceipt ───────────────────────────────────────────────────
    /**
     * Description : Builds credit receipt payload and sends  
     *               it to Oracle as a credit memo callout.   
     */
    public static void createCreditReceipt(Set<String> receiptIds) {
        String installmentWrapString = null, receiptResponseStringActual = null;
        HTTPResponse res = null;
        try { //14.0 add fields to SOQL
        // 16.0 - Hudayriyat Golf Estates project changes
            List<Receipt__c> recLst = [SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, PaymentReferenceNumber__c,
                                       Account__c, SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c,
                                       SalesOrder__r.ProjectName__c, SalesOrderInstallment__r.SalesOrder__r.ProjectName__c,
                                       PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, TransactionDate__c,
                                       PaymentEscrowAccount__r.IBANNo__c, PaymentEscrowAccount__r.Name, TransactionNumber__c, ExpressionOfInterest__c,
                                       Modeofpayment__c, ReceiptDate__c, ChequeDate__c, TotalAmount__c, Bank__c, Status__c,
                                       SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c,
                                       SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                                       SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c,
                                       SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                                       SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                       SalesOrder__r.Unit__r.Phase__r.EntityName__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c,
                                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,
                                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                                       SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c, SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c,
                                       SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c, SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c,
                                       SalesOrderInstallment__r.SalesOrder__r.Name, SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,
                                       SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c, SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                                       SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c, SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                                       SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c, SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c,
                                       SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c, SalesOrder__r.Unit__r.PlotNo__c,
                                       EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c,SalesOrder__r.VirtualAccount__r.Name,
                                       SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, SalesOrder__r.OracleCustAcctSiteID__c,SalesOrder__r.Unit__r.UnitClassification__c,
                                       SalesOrder__r.OracleSiteUseID__c, SalesOrder__r.NotToBeShownOnRD__c, SalesOrder__r.Name, SalesOrder__r.Id
                                       FROM Receipt__c WHERE Id IN :receiptIds AND Oracle_Id_Temporary__c = null
                                       AND Account__r.OraclePartyId__c != null AND SalesOrder__r.OraclePartySiteID__c != null
                                       AND SalesOrder__r.NotToBeShownOnRD__c = false AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'];

            List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst = new List<OIC_RequestWrapperController.InstallmentWrapper>();
            for (Receipt__c recObj : recLst) {
                Boolean hasSOI = (recObj.SalesOrderInstallment__c != null);
                SalesOrder__c so = hasSOI ? recObj.SalesOrderInstallment__r.SalesOrder__r : recObj.SalesOrder__r;
                if (so == null) { System.debug('Skipping receipt (no SalesOrder resolved): ' + recObj.Id); continue; }
                Unit__c unit = so.Unit__r; 
                Phase__c phase = unit != null ? unit.Phase__r : null;
                VirtualAccount__c va = so.VirtualAccount__r; 
                EscrowAccount__c escrow = va != null ? va.EscrowAccount__r : null;
                OIC_RequestWrapperController.InstallmentWrapper w = new OIC_RequestWrapperController.InstallmentWrapper();
                w.Sfid = recObj.Id; 
                w.CustomerSfid = recObj.Account__c;
                w.CustomerPartyId = recObj.Account__r != null ? recObj.Account__r.OraclePartyId__c : null;
                w.SoIsfid = recObj.SalesOrderInstallment__c; 
                w.SoIsfReference = recObj.SalesOrderInstallment__c;
                w.SoSfid = so.Id; 
                w.SoReference = so.Name;
                //start 14.0 — same field mapping; skip NPE when related escrow/unit/VA is missing
                w.EscrowAccountNumber = escrow?.AccountNumber__c; 
                w.EscrowIbanNumber = escrow?.IBANNo__c;
                w.EscrowStoreId = escrow?.StoreId__c; 
                w.EscrowSwiftCode = escrow?.SwiftCode__c;
                w.EscrowTradeId = escrow?.TradeID__c; 
                w.EscrowBankName = escrow?.BankName__c; 
                w.EscrowBenificaryName = escrow?.BeneficiaryName__c;
                w.Unit = unit?.PlotNo__c; 
                w.ExtraInfo1 = unit?.PlotNo__c; 
                w.UnitName = unit?.Name; 
                w.UnitSfId = so.Unit__c;
                w.VirtualAccountNumber = va?.VirtualAccountNumber__c; 
                w.VirtualIbanNumber = va?.VirtualIBANNumber__c;
                w.ProjectName = unit?.Project_Name__c; //End 14.0
                w.ProjectPhase = phase != null ? phase.Name : ''; 
                w.EntityName = phase != null ? phase.EntityName__c : '';
                if (unit != null && phase != null){
                // 16.0 - Hudayriyat Golf Estates project changes
                    if(unit.Project_Name__c == 'Hudayriyat Golf Estates'){
                        w.ExtraInfo2 = unit.Project_Name__c+'-'+unit.UnitClassification__c; 
                    }else{
                        w.ExtraInfo2 = unit.Project_Name__c =='Commercial Plots' ? unit.Name : unit.Project_Name__c+'-'+phase.Name; //12.0
                    }
                }
                w.TrxnType = 'ADM Waiver'; // 15.0
                w.CustAcctId = so.CustAcctId__c; 
                w.OraclePartySiteID = so.OraclePartySiteID__c;
                w.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c; 
                w.OracleSiteUseID = so.OracleSiteUseID__c;
                w.Description = (hasSOI && recObj.SalesOrderInstallment__r != null) ? recObj.SalesOrderInstallment__r.Milestone_Name__c
                    : (!String.isBlank(recObj.Milestone_Description__c) ? recObj.Milestone_Description__c : 'Credit Memo Receipt');
                if (recObj.AppliedAmount__c != null){
                     w.Amount = String.valueOf(recObj.AppliedAmount__c);
                }
                w.InvoiceDate = recObj.TransactionDate__c != null ? Date.valueOf(recObj.TransactionDate__c)
                    : (recObj.EBS_Clearing_Date__c != null ? Date.valueOf(recObj.EBS_Clearing_Date__c) : System.today());
                w.GlDate = recObj.EBS_Clearing_Date__c != null ? recObj.EBS_Clearing_Date__c : System.today();
                w.Status = 'Generated'; 
                w.OrgIdentifier = UserInfo.getOrganizationId();
                w.InstallmentNumber = recObj.PaymentReferenceNumber__c;
                w.VirtualAccountName = va?.Name; //14.0
                installmentWrapLst.add(w);
            }
            // null-guard before debug
            if (!installmentWrapLst.isEmpty()) system.debug('installmentWrapLst[0] : ' + installmentWrapLst[0]);
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionInstallmentAPI2');
            req.setTimeout(120000);
            OIC_RequestWrapperController.InstallmentWrapperLst installmentWrapperList = new OIC_RequestWrapperController.InstallmentWrapperLst();
            installmentWrapperList.RequestArray = installmentWrapLst;
            installmentWrapString = JSON.serialize(installmentWrapperList);
            System.debug('JSON.serialize(installmentWrapString)==>' + installmentWrapString);
            Blob binaryData = Blob.valueOf(installmentWrapString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            System.debug('base64String JSON request :' + base64String);
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            req.setBody(JSON.serialize(wrapper)); req.setHeader('Accept', 'application/json');
            System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            res = http.send(req);
            System.debug(res); System.debug(res.getBody());
            String installmentResponseBody = res.getBody();
            System.debug('installmentResponseBody::: ' + installmentResponseBody);
            if (installmentResponseBody != null && installmentResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(installmentResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob installmentResponseBlob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') installmentResponseBlob = EncodingUtil.base64Decode(b64.Base64Response);
                if (installmentResponseBlob != null) receiptResponseStringActual = installmentResponseBlob.toString();
                System.debug('receiptResponseStringActual:::: ' + receiptResponseStringActual);
                if (receiptResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(receiptResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('Receipt__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        List<Receipt__c> lstToUpdate = new List<Receipt__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                            Receipt__c rec = new Receipt__c(Id = resp.Sfid);
                            if (resp.Status == 'S') { 
                                rec.OICNoOfRetries__c = null; 
                                rec.OICIntegrationMessage__c = null;
                                rec.OraclePartyId__c = resp.OracleId; //14.0
                            	rec.OICIntegrationStatus__c = resp.Status; //14.0 
                            }
                            else if (resp.Status == 'E') {
                                rec.OICIntegrationStatus__c = resp.Status; //14.0                            
                                if (resp.ErrorMsg != null) rec.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                                rec.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                                oicErrorLogs.add(logOICError('Credit Receipt API','OIC_ManageSalesforceFusionDataController','createCreditReceipt',
                                            installmentWrapString, receiptResponseStringActual,
                                            resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus()));

                            }
                            lstToUpdate.add(rec);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()) update lstToUpdate;
                    }
                }
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Credit Receipt API','OIC_ManageSalesforceFusionDataController','createCreditReceipt',
                installmentWrapString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Receipt API','OIC_ManageSalesforceFusionDataController','createCreditReceipt'));
            System.debug('>>>> Exception in createCreditReceipt: ' + ex.getMessage());
            if (!Test.isRunningTest()) throw new StringException(ex.getStackTraceString());
        }
    }

    /**
     * Description : 20.0 - Resolves each Account's 'IBAN Letter' file public URL (ContentDistribution) keyed by
     *               Account Id, but only for the invoices whose Transaction_Type__c is 'Customer Refund'.
     *               Returns an empty map when there is no refund in the batch, so the ContentDistribution
     *               queries/inserts are skipped entirely for ordinary installments.
     */
    @TestVisible
    private static Map<Id, String> getCustomerRefundIbanUrls(List<Invoice__c> invoices) {
        Set<String> refundInvoiceIds = new Set<String>();
        for (Invoice__c inv : invoices) {
            if (inv.Transaction_Type__c == 'Customer Refund') refundInvoiceIds.add(inv.Id);
        }
        if (refundInvoiceIds.isEmpty()) return new Map<Id, String>();
        return ContentPublicURLHelper.getAccountIbanDistributionUrls(refundInvoiceIds);
    }

    // ── createInstallment  (invCrdMap drives Oracle_Credit_Memo_Id__c) ─
    /**
     * Description : Builds invoice installment payload and
     *               sends it to Oracle via Fusion API.
     */
    public static void createInstallment(Set<String> installmentIds) {
        String installmentWrapString = null, installmentResponseStringActual = null;
        HTTPResponse res = null;
        OIC_AdvanceTaxCancellationService.CancellationResult advTaxResult = null;
        try { //14.0 Add Fields to SOQL
         // 16.0 - Hudayriyat Golf Estates project changes
         //V20.0 - Start
         // 1) Query List of Invoice__c
            List<Invoice__c> installmentLst = InvoiceSelector.getInvoicesByIds(installmentIds);

         // 1a) 23.0 - Cancel any Advance Tax Invoice already synced to Oracle for these installments.
            //   Installments whose cancellation did not succeed are held back for the next run; the rest
            //   carry on. No Advance Tax Invoice means no callout here and the normal flow is untouched.
            //   The cancellation DML is staged, not committed - Apex rejects a callout that follows
            //   uncommitted DML and the installment callout below still has to run.
            advTaxResult = OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(installmentIds);
            if (!advTaxResult.blockedInstallmentIds.isEmpty()) {
                installmentLst = excludeBlockedInstallments(installmentLst, advTaxResult.blockedInstallmentIds);
            }

         // 2) Resolve the Account 'IBAN Letter' public URLs only for Customer Refund invoices
            Map<Id, String> accountIbanUrlMap = getCustomerRefundIbanUrls(installmentLst);

         // 3) Build the installment payload (SOI driven or Sales Order driven) in the wrapper generator
            // invCrdMap collects the invoices sent as CREDIT_MEMO so the response can stamp the right Oracle Id field
            Map<Id,Boolean> invCrdMap = new Map<Id,Boolean>();
            List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst =
                OIC_SFDataWrapperGenerator.generateInstallmentWrappers(installmentLst, accountIbanUrlMap, invCrdMap);

         // 4) Serialize the payload and send it through the Invoice external service
            // 23.0 - Nothing left to send (no eligible invoice, or every one held back by a failed
            // Advance Tax cancellation) - skip the callout rather than posting an empty RequestArray
            if (installmentWrapLst.isEmpty()) return;

            OIC_RequestWrapperController.InstallmentWrapperLst installmentWrapperList = new OIC_RequestWrapperController.InstallmentWrapperLst();
            installmentWrapperList.RequestArray = installmentWrapLst;
            installmentWrapString = JSON.serialize(installmentWrapperList);
            System.debug('JSON.serialize(installmentWrapString)==>' + installmentWrapString);

            //Call Installment API
            res = OIC_InvoiceExternalService.sendInstallment(installmentWrapString);
            //V20.0 - End

         // 5) Update each Invoice with the status returned by Oracle
            String installmentResponseBody = res.getBody();
            System.debug('installmentResponseBody::: ' + installmentResponseBody);
            if (installmentResponseBody != null && installmentResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(installmentResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob installmentResponseblob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') installmentResponseblob = EncodingUtil.base64Decode(b64.Base64Response);
                if (installmentResponseblob != null) installmentResponseStringActual = installmentResponseblob.toString();
                System.debug('installmentResponseStringActual:::: ' + installmentResponseStringActual);
                if (installmentResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(installmentResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('Invoice__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        list<Invoice__c> lstToUpdate = new list<Invoice__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                            Invoice__c inv = new Invoice__c(Id = resp.Sfid);
                            if (resp.Status == 'S') { //Start 14.0
                                // FIX: use invCrdMap (correctly populated) not invoiceMap (was always empty)
                                if (invCrdMap.containskey(inv.Id)) inv.Oracle_Credit_Memo_Id__c = resp.OracleId;
                                else inv.OraclePartyId__c = resp.OracleId;
                                inv.OICIntegrationStatus__c = resp.Status;
                            	//End 14.0
                                inv.OICNoOfRetries__c = null; 
                                inv.OICIntegrationMessage__c = null; 
                            }
                            else if (resp.Status == 'E') {
                                inv.OICIntegrationStatus__c = resp.Status; //14.0
                                if (resp.ErrorMsg != null) inv.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                                inv.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                                oicErrorLogs.add(logOICError('Invoice API','OIC_ManageSalesforceFusionDataController','createInstallment',
                                            installmentWrapString, installmentResponseStringActual,
                                            resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus()));

                            }
                            lstToUpdate.add(inv);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()) update lstToUpdate;
                    }
                }
                LoggerService.save(LoggerService.createAPILog('Invoice API','OIC_ManageSalesforceFusionDataController','createInstallment',
                    installmentWrapString, installmentResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Invoice API','OIC_ManageSalesforceFusionDataController','createInstallment',
                installmentWrapString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Invoice API','OIC_ManageSalesforceFusionDataController','createInstallment'));
        } finally {
            // 23.0 - Every callout in this transaction is done, so the Advance Tax cancellation DML and its
            // logs can now be committed. Runs on the early return and on the exception path too.
            if (advTaxResult != null) advTaxResult.commitStagedWork();
        }
    }

    /**
     * Description : 23.0 - Removes the installments whose Advance Tax cancellation failed, so they are not
     *               sent to Oracle in this run. They keep their OIC error message and are picked up again
     *               on the next retry.
     */
    @TestVisible
    private static List<Invoice__c> excludeBlockedInstallments(List<Invoice__c> installmentLst, Set<Id> blockedIds) {
        List<Invoice__c> allowed = new List<Invoice__c>();
        for (Invoice__c inv : installmentLst) {
            if (!blockedIds.contains(inv.Id)) allowed.add(inv);
        }
        return allowed;
    }

    // ── createAllocation ──────────────────────────────────────────────────────
    /**
     * Description : Builds allocation payload and sends it   
     *               to Oracle via Fusion allocation API.     
     */
    public static void createAllocation(set<String> allocationIds) {
        String allocationWrapString = null, allocationResponseStringActual = null;
        HTTPResponse res = null;
        try {
            List<Allocation__c> allocationLst = [SELECT Id, Name, Receipt__c, Invoice__c,
                                                 Receipt__r.TotalAmount__c, Receipt__r.OraclePartyId__c, Invoice__r.Ebs_Invoice_Date__c,
                                                 Invoice__r.OraclePartyId__c, AllocationAmount__c, AllocationDate__c, Status__c,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                                                 Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name, Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c
                                                 FROM Allocation__c WHERE Id IN :allocationIds AND OraclePartyId__c = null
                                                 AND Receipt__r.OraclePartyId__c != null AND Invoice__r.OraclePartyId__c != null
                                                 AND Receipt__r.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c = false
                                                 AND Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt'];
            List<OIC_RequestWrapperController.AllocationWrapper> allocationWrapLst = new List<OIC_RequestWrapperController.AllocationWrapper>();
            for (Allocation__c a : allocationLst) {
                OIC_RequestWrapperController.AllocationWrapper aw = new OIC_RequestWrapperController.AllocationWrapper();
                aw.Sfid = a.Id; 
                aw.SfReference = a.Id; 
                aw.ReceiptSfid = a.Receipt__c;
                aw.CashReceiptId = a.Receipt__r.OraclePartyId__c; 
                aw.InstallmentInvoiceSfid = a.Invoice__c;
                aw.CustomerTrxId = a.Invoice__r.OraclePartyId__c;
                aw.AllocationDate = a.AllocationDate__c != null ? Date.valueOf(a.AllocationDate__c) : null;
                aw.AllocationGlDate = system.today();
                if (a.AllocationAmount__c != null) {
                    // Keep original rule: min(receipt total, allocation) when total is populated;
                    // null receipt total still uses AllocationAmount__c (do not treat null as 0).
                    Decimal recTotal = a.Receipt__r.TotalAmount__c;
                    Decimal amt = (recTotal != null && recTotal < a.AllocationAmount__c) ? recTotal : a.AllocationAmount__c;
                    aw.AllocationAmount = String.valueOf(amt);
                }
                aw.Status = a.Status__c;
                aw.ProjectPhase = a.Receipt__r.SalesOrderInstallment__c != null
                    ? a.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name : a.Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name;
                aw.EntityName = a.Receipt__r.SalesOrderInstallment__c != null
                    ? a.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c : a.Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                allocationWrapLst.add(aw);
            }
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionAllocationAPI2');
            req.setTimeout(120000);
            OIC_RequestWrapperController.AllocationWrapperLst allocationWrapperList = new OIC_RequestWrapperController.AllocationWrapperLst();
            allocationWrapperList.RequestArray = allocationWrapLst;
            allocationWrapString = JSON.serialize(allocationWrapperList);
            System.debug('JSON.serialize(allocationWrapString)==>' + allocationWrapString);
            Blob binaryData = Blob.valueOf(allocationWrapString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            req.setBody(JSON.serialize(wrapper)); req.setHeader('Accept', 'application/json');
            System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            res = http.send(req);
            System.debug(res); System.debug(res.getBody());
            String allocationResponseBody = res.getBody();
            if (allocationResponseBody != null && allocationResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(allocationResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob allocationResponseBlob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') allocationResponseBlob = EncodingUtil.base64Decode(b64.Base64Response);
                if (allocationResponseBlob != null) allocationResponseStringActual = allocationResponseBlob.toString();
                System.debug('allocationResponseStringActual:::: ' + allocationResponseStringActual);
                if (allocationResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(allocationResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('Allocation__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        list<Allocation__c> lstToUpdate = new list<Allocation__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                            Allocation__c al = new Allocation__c(Id = resp.Sfid);
                            if (resp.Status == 'S') { 
                                al.OICNoOfRetries__c = null; 
                                al.OICIntegrationMessage__c = null; 
                                al.OraclePartyId__c = resp.OracleId;  //14.0
                            	al.OICIntegrationStatus__c = resp.Status; //14.0                           
                            }
                            else if (resp.Status == 'E') {
                                al.OICIntegrationStatus__c = resp.Status; //14.0                           
                                if (resp.ErrorMsg != null) al.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                                al.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                                oicErrorLogs.add(logOICError('Allocation API','OIC_ManageSalesforceFusionDataController','createAllocation',
                                            allocationWrapString, allocationResponseStringActual,
                                            resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus()));
                            }
                            lstToUpdate.add(al);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()) update lstToUpdate;
                    }
                }
                LoggerService.save(LoggerService.createAPILog('Allocation API','OIC_ManageSalesforceFusionDataController','createAllocation',
                    allocationWrapString, allocationResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Allocation API','OIC_ManageSalesforceFusionDataController','createAllocation',
                allocationWrapString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Allocation API','OIC_ManageSalesforceFusionDataController','createAllocation'));
        }
    }

    // ── createUnAppliedAllocation ─────────────────────────────────────────────
    /**
     * Description : Sends unapplied allocation payload to    
     *               Oracle to reverse existing allocations.  
     */
    public static void createUnAppliedAllocation(set<String> allocationIds) {
        String allocationWrapString = null, allocationResponseStringActual = null;
        HTTPResponse res = null;
        try {
            List<Allocation__c> allocationLst = [SELECT Id, Name, Receipt__c, Invoice__c,
                                                 Receipt__r.TotalAmount__c, Receipt__r.OraclePartyId__c, Invoice__r.Ebs_Invoice_Date__c,
                                                 Invoice__r.OraclePartyId__c, AllocationAmount__c, AllocationDate__c, Status__c,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                                 Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                                                 Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name, Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c
                                                 FROM Allocation__c WHERE Id IN :allocationIds AND OraclePartyId__c != null
                                                 AND Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt'];
            List<OIC_RequestWrapperController.AllocationWrapper> allocationWrapLst = new List<OIC_RequestWrapperController.AllocationWrapper>();
            for (Allocation__c a : allocationLst) {
                OIC_RequestWrapperController.AllocationWrapper aw = new OIC_RequestWrapperController.AllocationWrapper();
                aw.Sfid = a.Id; 
                aw.SfReference = a.Id; 
                aw.ReceiptSfid = a.Receipt__c;
                aw.CashReceiptId = a.Receipt__r.OraclePartyId__c; 
                aw.InstallmentInvoiceSfid = a.Invoice__c;
                aw.CustomerTrxId = a.Invoice__r.OraclePartyId__c; 
                aw.ResyncUnApply = 'Y';
                aw.AllocationDate = a.AllocationDate__c != null ? Date.valueOf(a.AllocationDate__c) : null;
                aw.AllocationGlDate = system.today();
                if (a.AllocationAmount__c != null) {
                    // Keep original rule: min(receipt total, allocation) when total is populated;
                    // null receipt total still uses AllocationAmount__c (do not treat null as 0).
                    Decimal recTotal = a.Receipt__r.TotalAmount__c;
                    Decimal amt = (recTotal != null && recTotal < a.AllocationAmount__c) ? recTotal : a.AllocationAmount__c;
                    aw.AllocationAmount = String.valueOf(amt);
                }
                aw.Status = a.Status__c;
                aw.ProjectPhase = a.Receipt__r.SalesOrderInstallment__c != null
                    ? a.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name : a.Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name;
                aw.EntityName = a.Receipt__r.SalesOrderInstallment__c != null
                    ? a.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c : a.Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                allocationWrapLst.add(aw);
            }
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionAllocationAPI2');
            req.setTimeout(120000);
            OIC_RequestWrapperController.AllocationWrapperLst allocationWrapperList = new OIC_RequestWrapperController.AllocationWrapperLst();
            allocationWrapperList.RequestArray = allocationWrapLst;
            allocationWrapString = JSON.serialize(allocationWrapperList);
            System.debug('JSON.serialize(allocationWrapString)==>' + allocationWrapString);
            Blob binaryData = Blob.valueOf(allocationWrapString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            req.setBody(JSON.serialize(wrapper)); req.setHeader('Accept', 'application/json');
            System.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            res = http.send(req);
            System.debug(res); System.debug(res.getBody());
            String allocationResponseBody = res.getBody();
            if (allocationResponseBody != null && allocationResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(allocationResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob unAllocationResponseBlob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') unAllocationResponseBlob = EncodingUtil.base64Decode(b64.Base64Response);
                if (unAllocationResponseBlob != null) allocationResponseStringActual = unAllocationResponseBlob.toString();
                System.debug('allocationResponseStringActual:::: ' + allocationResponseStringActual);
                if (allocationResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(allocationResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('Allocation__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        list<Allocation__c> lstToUpdate = new list<Allocation__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                            Allocation__c al = new Allocation__c(Id = resp.Sfid);
                            if (resp.Status == 'S') { 
                                al.OICNoOfRetries__c = null; //Start 14.0
                                al.OraclePartyId__c = resp.OracleId; 
                            	al.OICIntegrationStatus__c = resp.Status; 
                                al.OICIntegrationMessage__c = null; //End 14.0
                            }
                            else if (resp.Status == 'E') {
                                al.OICIntegrationStatus__c = resp.Status; //14.0
                                if (resp.ErrorMsg != null) al.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                                al.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                                oicErrorLogs.add(logOICError('Allocation API','OIC_ManageSalesforceFusionDataController','createUnAppliedAllocation',
                                            allocationWrapString, allocationResponseStringActual,
                                            resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus()));
                            }
                            lstToUpdate.add(al);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()) update lstToUpdate;
                    }
                }
                LoggerService.save(LoggerService.createAPILog('Allocation API','OIC_ManageSalesforceFusionDataController','createUnAppliedAllocation',
                    allocationWrapString, allocationResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Allocation API','OIC_ManageSalesforceFusionDataController','createUnAppliedAllocation',
                allocationWrapString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Allocation API','OIC_ManageSalesforceFusionDataController','createUnAppliedAllocation'));
        }
    }

    // ── createProject ─────────────────────────────────────────────────────────
    /**
     * Description : Builds project master payload and sends  
     *               it to Oracle via Fusion project API.     
     */
    public static void createProject(Set<Id> ProjectIds) {
        String ProjectWrapString = null, projectResponseStringActual = null;
        HTTPResponse res = null;
        try {
            List<Project__c> ProjectList = [SELECT Id, Name, ProjectNumber__c FROM Project__c
                                            WHERE Id IN :ProjectIds AND Source_Entity__c != 'Modon - Egypt'];
            List<OIC_RequestWrapperController.ProjectMaster> ProjectMasterWrapLst = new List<OIC_RequestWrapperController.ProjectMaster>();
            for (Project__c p : ProjectList) {
                OIC_RequestWrapperController.ProjectMaster pm = new OIC_RequestWrapperController.ProjectMaster();
                pm.Sfid = p.Id; 
                pm.Description = p.Name;
                ProjectMasterWrapLst.add(pm);
            }
            OIC_RequestWrapperController.ProjectMasterList ProjectMasterListObj = new OIC_RequestWrapperController.ProjectMasterList();
            ProjectMasterListObj.RequestArray = ProjectMasterWrapLst;
            ProjectWrapString = JSON.serialize(ProjectMasterListObj);
            System.debug('ProjectWrapString ==> ' + ProjectWrapString);
            Blob binaryData = Blob.valueOf(ProjectWrapString);
            String base64String = EncodingUtil.base64Encode(binaryData);
            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionProjectAPI');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(wrapper)); req.setHeader('Accept', 'application/json');
            System.debug('Request wrapper ==> ' + JSON.serialize(wrapper));
            Http http = new Http();
            res = http.send(req);
            System.debug(res); System.debug(res.getBody());
            String projectResponseBody = res.getBody();
            if (projectResponseBody != null && projectResponseBody != '') {
                OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(projectResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                Blob projectResponseBlob = null;
                if (b64.Base64Response != null && b64.Base64Response != '') projectResponseBlob = EncodingUtil.base64Decode(b64.Base64Response);
                if (projectResponseBlob != null) projectResponseStringActual = projectResponseBlob.toString();
                System.debug('projectResponseStringActual:::: ' + projectResponseStringActual);
                if (projectResponseStringActual != null) {
                    OIC_RequestWrapperController.OICResponseWrapperList respObj =
                        (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(projectResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                    if (respObj != null && respObj.ResponseArray != null) {
                        Set<String> ids = new Set<String>();
                        for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) ids.add(r.Sfid);
                        Map<String,Integer> retryMap = loadRetryMap('Project__c', ids);
                        Map<String,String>  errMap   = loadErrorMsgMap();
                        List<Project__c> lstToUpdate = new List<Project__c>();
                        List<Logger__c> oicErrorLogs = new List<Logger__c>();
                        for (OIC_RequestWrapperController.OICResponseWrapper pr : respObj.ResponseArray) {
                            Project__c p = new Project__c(Id = pr.Sfid);
                            if (pr.Status == 'S') { 
                                p.OICNoOfRetries__c = null; 
                                p.OraclePartyId__c = pr.OracleId; 
                                p.OICIntegrationMessage__c = null;
                                p.OICIntegrationStatus__c = pr.Status; //14.0
                            
                            }
                            else if (pr.Status == 'E') {
                                p.OICIntegrationStatus__c = pr.Status;//14.0                            
                                if (pr.ErrorMsg != null){
                                    p.OICIntegrationMessage__c = resolveErrMsg(pr.ErrorMsg, errMap);
                                }else{
                                    p.OICIntegrationMessage__c ='Required information is not updated in Salesforce. Please contact support';
                                }
                                p.OICNoOfRetries__c = nextRetry(retryMap, pr.Sfid);
                                oicErrorLogs.add(logOICError('Project API','OIC_ManageSalesforceFusionDataController','createProject',
                                            ProjectWrapString, projectResponseStringActual,
                                            pr.Sfid, pr.ErrorMsg, res.getStatusCode(), res.getStatus()));
                            }
                            lstToUpdate.add(p);
                        }
                        saveOICErrorLogs(oicErrorLogs);
                        if (!lstToUpdate.isEmpty()) update lstToUpdate;
                    }

                }
                LoggerService.save(LoggerService.createAPILog('Project API','OIC_ManageSalesforceFusionDataController','createProject',
                    ProjectWrapString, projectResponseStringActual, 'Status Code: '+res.getStatusCode()+'; Status: '+res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Project API','OIC_ManageSalesforceFusionDataController','createProject',
                ProjectWrapString, (res != null ? res.getBody() : null),
                'Exception: '+ '500 Error' , 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex,'Project API','OIC_ManageSalesforceFusionDataController','createProject'));
        }
    }

    // ── Customer wrapper builders (unchanged) ─────────────────────────────────
    /**
     * Description : Builds and returns a person account      
     *               customer wrapper from Account fields.    
     */
    public static OIC_RequestWrapperController.CustomerWrapper createPersonWrapper(Account accObj) {
        OIC_RequestWrapperController.CustomerWrapper w = new OIC_RequestWrapperController.CustomerWrapper();
        w.Sfid = accObj.Id; w.CustomerType = 'PERSON'; 
        w.Title = accObj.PersonTitle;
        w.FirstName = accObj.FirstName; 
        w.MiddleName = accObj.MiddleName; 
        w.LastName = accObj.LastName;
        w.Gender = accObj.PersonGenderIdentity; 
        w.MaritalStatus = accObj.MaritalStatus__pc;
        w.DateOfBirth = accObj.PersonBirthdate; 
        w.PassportNumber = accObj.PassportNumber__pc;
        w.PassportExpiryDate = accObj.PassportExpiryDate__pc; 
        w.Nationality = accObj.Nationality__pc;
        w.EmiratesIdExpDate = accObj.EmiratesIDExpiryDate__pc; 
        w.EmiratesId = accObj.EIDNumber__pc;
        w.EmailAddress = accObj.PersonEmail; 
        w.PhoneNumber = '+971000000000';
        w.Country  = accObj.PersonMailingCountry ;
        w.City     = accObj.PersonMailingCity;
        w.State    = accObj.PersonMailingState ;
        w.Address1 = accObj.PersonMailingStreet;
        w.IsUaeCustomer = (accObj.UAE_Resident_Status__pc == 'Resident') ? 'Y' : 'N';
        return w;
    }
	/**
     * Description : Builds and returns an organization       
     *               customer wrapper from Account fields.    
     */
    public static OIC_RequestWrapperController.CustomerWrapper createOrganizationWrapper(Account accObj) {
        OIC_RequestWrapperController.CustomerWrapper w = new OIC_RequestWrapperController.CustomerWrapper();
        w.SFID = accObj.Id; 
        w.CustomerType = 'ORGANIZATION';
        w.FirstName = accObj.FirstName;         
        w.MiddleName = accObj.MiddleName; 
        w.LastName = accObj.LastName;
        w.OrganizationName = accObj.Name; 
        w.TradeName = accObj.TradeName__c; 
        w.UnifiedNumber = accObj.UnifiedNumber__c;
        if (accObj.Contacts != null && !accObj.Contacts.isEmpty()) {
            w.EmailAddress = accObj.Contacts[0].Email; 
            w.PhoneNumber = '+971000000000';
        }
        w.Country  = accObj.BillingCountry;
        w.City     = accObj.BillingCity;
        w.State    = accObj.BillingState;
        w.Address1 = accObj.BillingStreet;
        w.VatRegistrationNumber = accObj.UAEVATRegisterNumber__c;
        return w;
    } //End 12.0
}