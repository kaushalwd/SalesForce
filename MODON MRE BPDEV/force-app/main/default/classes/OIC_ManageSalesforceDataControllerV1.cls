/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceDataControllerV1                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            29 Sep 2025     Initial Draft       
* 2.0           Kumar 				    18 Oct 2025		Update where logic
* 3.0			Manoj					20 Feb 2026		Update the PropertyTransfer logic
* 4.0			Manoj					17 May 2026		Add fusion logic
***********************************************************************************************************************/

public class OIC_ManageSalesforceDataControllerV1 {
    
    public static void updateUnitStatus(set<String> unitIds){
        List<Unit__c> unitLst = [SELECT Id, Status__c FROM Unit__c WHERE Id IN :unitIds];
        HttpRequest req = new HttpRequest();
        req.setTimeout(120000);
        req.setHeader('Accept', 'application/json');
        req = OIC_CredentialsController.getCredentials('ModonFusion3DSUpdateUnitUAT');
        for(Unit__c unitObj : unitLst){
            OIC_RequestWrapperController.UnitUpdateWrapper unitUpdatObj = new OIC_RequestWrapperController.UnitUpdateWrapper();
            unitUpdatObj.Id = unitObj.Id;
            unitUpdatObj.Status = unitObj.Status__c;

            req.setBody(JSON.serialize(unitUpdatObj));
            system.debug('JSON.serialize(unitUpdatObj)==>' + JSON.serialize(unitUpdatObj));
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug(res);
            System.debug(res.getBody());
        }
    }
	
    //ANIL- createSalesOrderAndSOInstallments
    public static string createSalesOrderAndSOInstallments(set<String> salesOrderIDs){
			string salesorderReturn =null;
        try{
			// 4.0
            List<SalesOrder__c> soList = [SELECT Id, Name, CustomerAccount__c, CustomerAccount__r.OraclePartyId__c,Old_Account__c,
                                          Unit__r.Name, UnitOption__r.Name, PaymentPlan__r.Name, Unit__r.Phase__r.Name,
                                          Unit__r.Project_Name__c, Unit__r.Phase__r.EntityName__c, TotalAmount__c,
                                          VirtualAccount__r.VirtualAccountNumber__c, VirtualAccount__r.VirtualIBANNumber__c,
                                          SalesAssociate__r.Name, Status__c, ProjectName__c,
                                          CustAcctId__c, OraclePartySiteID__c, OracleCustAcctSiteID__c, OracleSiteUseID__c,
                                          (SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, InstallmentAmount__c,
                                                  MilestoneDate__c, Milestone__c, PaymentStatus__c, Balance_Amount__c
                                           FROM   Sales_Order_Installments__r)
                                          FROM SalesOrder__c 
                                                    WHERE Id IN: salesOrderIDs and CustomerAccount__r.OraclePartyId__c != null]; 

            OIC_RequestWrapperController.SalesOrderWrapperLst soWrapListFinal = new OIC_RequestWrapperController.SalesOrderWrapperLst();

            List<OIC_RequestWrapperController.SalesOrderWrapper> soWrapList = new List<OIC_RequestWrapperController.SalesOrderWrapper>();
            
            for(SalesOrder__c so : soList){
                OIC_RequestWrapperController.SalesOrderWrapper soWrap = new OIC_RequestWrapperController.SalesOrderWrapper();
                soWrap.Sfid = so.Id; 
                soWrap.SfReference = so.Name; 
                soWrap.CustomerSfid = so.CustomerAccount__c;
                soWrap.CustomerPartyId = so.CustomerAccount__r.OraclePartyId__c; 
                soWrap.CustomerAcct = '';
                soWrap.UnitName = so.Unit__r.Name; 
                soWrap.UnitOption = so.UnitOption__r.Name; 
                soWrap.PaymentPlan = so.PaymentPlan__r.Name;
                soWrap.Phase = so.Unit__r.Phase__r.Name; 
                soWrap.Project = so.Unit__r.Project_Name__c;
                soWrap.TotalAmount = so.TotalAmount__c != null ? string.valueOf(so.TotalAmount__c) : null;
                soWrap.AdmAmount = '0'; 
                soWrap.DiscountAmount = '0';
                soWrap.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
                soWrap.VirtualIbanNumber = so.VirtualAccount__r.VirtualIBANNumber__c;
                soWrap.SalesAssociateName = so.SalesAssociate__r.Name; 
                soWrap.Status = so.Status__c;
                soWrap.OrgIdentifier = UserInfo.getOrganizationId(); 
                soWrap.ProjectName = so.ProjectName__c;
                soWrap.Unit = so.Unit__r.Name; 
                soWrap.ProjectPhase = so.Unit__r.Phase__r.Name;
                soWrap.EntityName = so.Unit__r.Phase__r.EntityName__c; 
                soWrap.CustAcctId = so.CustAcctId__c;
                soWrap.OraclePartySiteID = so.OraclePartySiteID__c; 
                soWrap.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c;
                soWrap.OracleSiteUseID = so.OracleSiteUseID__c;
                //start 4.0 PropertyTransfer 
                if(so.Old_Account__c != null ){
                    soWrap.PropertyTransfer ='Y';
                    soWrap.OldCustomerId =so.CustAcctId__c;
                }else{
                	soWrap.PropertyTransfer ='N';
                } // End 4.0
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
        
            String soWrapperFinalString = JSON.serialize(soWrapListFinal);
            system.debug('soWrapperFinalString::::  ' + soWrapperFinalString);
            Blob binaryData = Blob.valueOf(soWrapperFinalString);
            String base64String = EncodingUtil.base64Encode(binaryData);

            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;

            HttpRequest req = new HttpRequest();
            req = OIC_CredentialsController.getCredentials('ModonFusionSalesOrderAPI2');
            req.setTimeout(120000);

            req.setBody(JSON.serialize(wrapper));
            req.setHeader('Accept', 'application/json');
            system.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('SALES ORDER RESPONSE:::: ' + res);
            System.debug('SALES ORDER RESPONSE BODY:::: ' + res.getBody());

            string soResponseBody = res.getBody();

            // PARSING THE RESPONSE //
            if(soResponseBody <> null && soResponseBody <> ''){

                OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(soResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                
                blob soResponseBlobActual = null;
                string soResponseStringActual = null;

                if(base64RespWrap.Base64Response <> null && base64RespWrap.Base64Response <> '')
                soResponseBlobActual = EncodingUtil.base64Decode(base64RespWrap.Base64Response); 
                if(soResponseBlobActual <> null)
                soResponseStringActual = soResponseBlobActual.toString();
                System.debug('soResponseStringActual:::: ' + soResponseStringActual);

                if(soResponseStringActual <> null){
                    OIC_RequestWrapperController.OICSOResponseWrapperList soResponseObjectActual = (OIC_RequestWrapperController.OICSOResponseWrapperList)JSON.deserialize(soResponseStringActual, OIC_RequestWrapperController.OICSOResponseWrapperList.class);
                
                    if(soResponseObjectActual <> null){
                        list<SalesOrder__c> lstSOToUpdate = new list<SalesOrder__c>();

                        set<string> recordIds = new set<string>();
                        map<string, integer> mp_recId_NoOfReTries = new map<string, integer>();

                        for(OIC_RequestWrapperController.OICSOResponseWrapper resp : soResponseObjectActual.ResponseArray){
                            recordIds.add(resp.Sfid);
                        }

                        if(!recordIds.isEmpty()){
                            list<SalesOrder__c> recs = [select Id, OICNoOfRetries__c from SalesOrder__c where Id in: recordIds and OICNoOfRetries__c != null];
                            for(SalesOrder__c rec: recs){
                                mp_recId_NoOfReTries.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
                            }
                        }

                        for(OIC_RequestWrapperController.OICSOResponseWrapper soResp : soResponseObjectActual.ResponseArray){
                            SalesOrder__c soToupdate = new SalesOrder__c();
                            soToupdate.Id = soResp.Sfid;
                            soToupdate.OraclePartyId__c = soResp.OracleId;
                            soToupdate.OICIntegrationMessage__c = soResp.ErrorMsg;
                            soToupdate.OICIntegrationStatus__c = soResp.Status;
                            soToupdate.CustAcctId__c= soResp.CustAcctId;
                            soToupdate.OraclePartySiteID__c= soResp.OraclePartySiteID;
                            soToupdate.OracleCustAcctSiteID__c= soResp.OracleCustAcctSiteID;
                            soToupdate.OracleSiteUseID__c= soResp.OracleSiteUseID;                            
                            if(soResp.Status == 'S'){
                            soToupdate.OICNoOfRetries__c = null;
                            salesorderReturn = 'S';
                            }else if(soResp.Status == 'E'){
                                if(mp_recId_NoOfReTries <> null && !mp_recId_NoOfReTries.isEmpty() && mp_recId_NoOfReTries.containsKey(soResp.Sfid) && mp_recId_NoOfReTries.get(soResp.Sfid) <> null)
                                soToupdate.OICNoOfRetries__c = mp_recId_NoOfReTries.get(soResp.Sfid) + 1; // increment the count
                                else 
                                soToupdate.OICNoOfRetries__c = 1;
                                salesorderReturn = 'E';
                            }

                            lstSOToUpdate.add(soToupdate);
                        }

                        if(!lstSOToUpdate.isEmpty()){
                            update lstSOToUpdate;
                        }
                    }
                
                }
            
                // Create API Callout Log (for both Success and Error)
                //PARAMS: string processName, string className, string methodName, string intReqBody, string intRespBody, string intStatusCode
                LoggerService.save(LoggerService.createAPILog('Sales Order API','OIC_ManageSalesforceDataController','createSalesOrderAndSOInstallments', soWrapperFinalString, soResponseStringActual, 'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));
            	return salesorderReturn;
            }
        
        }
        catch(Exception ex){
            salesorderReturn ='E';
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(ex, 'Sales Order API','OIC_ManageSalesforceDataController','createSalesOrderAndSOInstallments'));
        }
        
		return salesorderReturn;
    }

    public static string createAccount(set<String> accountIds){
        List<String> excludeStatuses = new List<String>{'Modon - Egypt'};
        string accountReturn =null;
        try{
            
            List<Account> accLst = [SELECT Id, Name, PersonTitle, FirstName, MiddleName, LastName, EIDNumber__pc, EmiratesIDExpiryDate__pc,
                                    (SELECT Id, Name, Email, EIDNumber__c, Birthdate, MobilePhone, Nationality__c FROM Contacts LIMIT 1),
                                    IsPersonAccount, TradeName__c, UnifiedNumber__c, PersonEmail, Phone, BillingCountry, PassportNumber__pc,
                                    PersonGenderIdentity, MaritalStatus__pc, PersonBirthdate, UAE_Resident_Status__pc, PassportExpiryDate__pc, Nationality__pc,
                                    BillingCity, BillingState, BillingAddress, BillingStreet, UAEVATRegisterNumber__c, PersonMobilePhone,
                                    PersonMailingCity, PersonMailingStreet, PersonMailingState, PersonMailingCountry, PersonMailingPostalCode
                                    FROM Account WHERE Id IN : accountIds and Source_Entity__c NOT IN: excludeStatuses];

            List<OIC_RequestWrapperController.CustomerWrapper> customerWrapLst = new List<OIC_RequestWrapperController.CustomerWrapper>();
            
            for(Account accObj : accLst){
                OIC_RequestWrapperController.CustomerWrapper customWrapObj = new OIC_RequestWrapperController.CustomerWrapper();
                customWrapObj.SFID = accObj.Id;
                if(accObj.IsPersonAccount){
                    customWrapObj = OIC_ManageSalesforceDataController.createPersonWrapper(accObj);
                }else{
                    customWrapObj = OIC_ManageSalesforceDataController.createOrganizationWrapper(accObj);
                }
                customerWrapLst.add(customWrapObj);
            }

            HttpRequest req = new HttpRequest();
            req = OIC_CredentialsController.getCredentials('ModonFusionCustomerAPI2');
            req.setTimeout(120000);

            OIC_RequestWrapperController.CustomerWrapperLst customerWrapList = new OIC_RequestWrapperController.CustomerWrapperLst();
            customerWrapList.RequestArray = customerWrapLst;
            String customerWrappString = JSON.serialize(customerWrapList);
            system.debug('JSON.serialize(customerWrapList)==>' + JSON.serialize(customerWrapList));
            Blob binaryData = Blob.valueOf(customerWrappString);
            String base64String = EncodingUtil.base64Encode(binaryData);

            OIC_RequestWrapperController.Base64Wrapper wrapper = new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;

            req.setBody(JSON.serialize(wrapper));
            system.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('Create Account Res::::' + res);
            System.debug('Create Account Res Body::::' + res.getBody());

            string custResponseBody = res.getBody();
            // PARSING THE RESPONSE //
            if(custResponseBody <> null && custResponseBody <> ''){
                OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(custResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                
                blob custResponseBlobActual = null;
                string custResponseStringActual = null;

                if(base64RespWrap.Base64Response <> null && base64RespWrap.Base64Response <> '')
                custResponseBlobActual = EncodingUtil.base64Decode(base64RespWrap.Base64Response); 
                if(custResponseBlobActual <> null)
                custResponseStringActual = custResponseBlobActual.toString();
                
                System.debug('custResponseStringActual:::: ' + custResponseStringActual);

                if(custResponseStringActual <> null){
                    OIC_RequestWrapperController.OICResponseWrapperList custResponseObjectActual = (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(custResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                
                    if(custResponseObjectActual <> null){
                        list<Account> lstRecordToUpdate = new list<Account>();

                        set<string> recordIds = new set<string>();
                        map<string, integer> mp_recId_NoOfReTries = new map<string, integer>();

                        for(OIC_RequestWrapperController.OICResponseWrapper resp : custResponseObjectActual.ResponseArray){
                            recordIds.add(resp.Sfid);
                        }

                        if(!recordIds.isEmpty()){
                            list<Account> recs = [select Id, OICNoOfRetries__c from Account where Id in: recordIds and OICNoOfRetries__c != null];
                            for(Account rec: recs){
                                mp_recId_NoOfReTries.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
                            }
                        }

                        for(OIC_RequestWrapperController.OICResponseWrapper resp : custResponseObjectActual.ResponseArray){
                            Account recordToupdate = new Account();
                            recordToupdate.Id = resp.Sfid;
                            recordToupdate.OraclePartyId__c = resp.OracleId;
                            recordToupdate.OICIntegrationMessage__c = resp.ErrorMsg;
                            recordToupdate.OICIntegrationStatus__c = resp.Status;

                            if(resp.Status == 'S'){
                            recordToupdate.OICNoOfRetries__c = null;
                                accountReturn ='S';
                            }else if(resp.Status == 'E'){
                                if(mp_recId_NoOfReTries <> null && !mp_recId_NoOfReTries.isEmpty() && mp_recId_NoOfReTries.containsKey(resp.Sfid) && mp_recId_NoOfReTries.get(resp.Sfid) <> null)
                                recordToupdate.OICNoOfRetries__c = mp_recId_NoOfReTries.get(resp.Sfid) + 1; // increment the count
                                else 
                                recordToupdate.OICNoOfRetries__c = 1;
                                accountReturn ='E';
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
                LoggerService.save(LoggerService.createAPILog('Customer API','OIC_ManageSalesforceDataController','createAccount', customerWrappString, custResponseStringActual, 'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));
            	return accountReturn;

            }
           
        }
        catch(Exception ex){
            accountReturn ='E';
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(ex, 'Customer API','OIC_ManageSalesforceDataController','createAccount'));
        }
       return accountReturn;
    }  

    
}