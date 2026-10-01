/**********************************************************************************************************************
* Name               : CustomerIdentificationAPI                                                        
* Description        : This class is used to identify the customer.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft   
* 1.1           Suresh   	                01 06 2026      contact id is added in the response message
* 1.2			Suresh						31 07 2026      UAE Pass auto linking with contacts - changed entire logic in apex
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/customeridentification/*')
global class CustomerIdentificationAPI {

    private class CustomerIdentificationException extends Exception {}

    @HttpGet
    global static void identifyCustomer() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        
        restResponse.addHeader('Content-Type', 'application/json');
        List<IdentificationResponse> lst_IdentificationResponse = new List<IdentificationResponse>();
        
        String email = restRequest.params.get('Email');
        String eid = restRequest.params.get('Eid');
        String phoneNumber = restRequest.params.get('PhoneNumber');
        String uuid = restRequest.params.get('UUID');
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            if (String.isBlank(email)) {
                throw new CustomerIdentificationException('Err-002|Email is empty');
            }
            
            List<Contact> lst_MatchContact = new List<Contact>();
            
            List<Contact> lst_Contact = [
                SELECT Id, FirstName, LastName, Email, MobilePhone, Phone, AccountId,
                       Account.EIDNumber__pc, Account.Trade_License_Number__c, Account.PassportNumber__pc, 
                       UAE_Resident_Status__c, Nationality__c, IsPersonAccount, RecordType.Name 
                FROM Contact 
                WHERE Email != NULL AND Email = :email.trim()
                WITH SYSTEM_MODE
            ];
            
            if (!lst_Contact.isEmpty()) {
                lst_MatchContact.add(lst_Contact.get(0));
            } 
            if (String.isNotBlank(eid)) {
                lst_MatchContact.clear();
                List<Contact> lst_EIDContact = [
                    SELECT Id, FirstName, LastName, Email, MobilePhone, Phone, AccountId,
                           Account.EIDNumber__pc, Account.Trade_License_Number__c, Account.PassportNumber__pc, 
                           UAE_Resident_Status__c, Nationality__c, EIDNumber__c, IsPersonAccount, RecordType.Name 
                    FROM Contact 
                    WHERE EIDNumber__c != NULL AND EIDNumber__c = :eid.trim()
                    WITH SYSTEM_MODE
                ];
                
                if (!lst_EIDContact.isEmpty() && lst_EIDContact.size() == 1) {
                    lst_MatchContact.addAll(lst_EIDContact);
                } else if(!lst_EIDContact.isEmpty()){
                    for (Contact obj_Contact : lst_EIDContact) {
                        if (obj_Contact.Email == email) {
                            lst_MatchContact.add(obj_Contact);
                        } else {
                            lst_MatchContact.clear();
                            handleAutoLinkProcessing(eid, email, phoneNumber, uuid, null, 'Login not successfull because of email mismatch in Salesforce');
                            break;
                        }
                    }                    
                } else {
                    handleAutoLinkProcessing(eid, email, phoneNumber, uuid, null, 'No Records matching with Emirates Id');
                }               
            }
            
            if (!lst_MatchContact.isEmpty()) {
                if(String.isNotBlank(eid)){
                    handleAutoLinkProcessing(eid, email, phoneNumber, uuid, lst_MatchContact.get(0).Id, 'Login Successfull');
                } 
                for (Contact obj_Contact : lst_MatchContact) {
                    IdentificationResponse resObj = new IdentificationResponse();
                    resObj.FirstName = obj_Contact.FirstName;
                    resObj.LastName = obj_Contact.LastName;
                    resObj.PersonEmail = obj_Contact.Email;
                    resObj.PersonMobilePhone = String.isNotBlank(obj_Contact.MobilePhone) ? obj_Contact.MobilePhone : obj_Contact.Phone;
                    resObj.EIDNumber = obj_Contact.Account.EIDNumber__pc;
                    resObj.TradeLicenseNumber = obj_Contact.Account.Trade_License_Number__c;
                    resObj.Passport = obj_Contact.Account.PassportNumber__pc;
                    resObj.AccountId = obj_Contact.AccountId;
                    resObj.ContactId = obj_Contact.Id;
                    resObj.UAE_Resident_Status = obj_Contact.UAE_Resident_Status__c;
                    resObj.Nationality = obj_Contact.Nationality__c;
                    resObj.Status = 'Success';
                    lst_IdentificationResponse.add(resObj);
                }
            } else {
                throw new CustomerIdentificationException('Err-003|No Records');
            }
            
            restResponse.statusCode = 200;
            restResponse.responseBody = Blob.valueOf(JSON.serialize(lst_IdentificationResponse));
            
        } catch (CustomerIdentificationException cex) {
            //Database.rollback(sp);
            List<String> errTokens = cex.getMessage().split('\\|');
            LoggerService.save(LoggerService.createApexLog(cex, 'CustomerIdentificationException', 'CustomerIdentificationException', 'getCustomerDetails'));
            configureErrorResponse(restResponse, lst_IdentificationResponse, 200, errTokens[0], errTokens[1]);
        } catch (Exception ex) {
            Database.rollback(sp);
            LoggerService.save(LoggerService.createApexLog(ex, 'CustomerIdentificationException', 'CustomerIdentificationException', 'getCustomerDetails'));
            System.debug(LoggingLevel.ERROR, 'Fatal System Identity Error: ' + ex.getStackTraceString());
            configureErrorResponse(restResponse, lst_IdentificationResponse, 200, 'Err-500', ex.getMessage());
        }
    }

   private static void handleAutoLinkProcessing(String eid, String email, String phone, String uuid, String contactId, String comments) {
        List<UAEPassAutoLinkRule__c> lst_UAEPass = [
            SELECT Id, EIDNumber__c, Email__c, MobilePhone__c, UUId__c, Contact__c 
            from UAEPassAutoLinkRule__c 
            WHERE EIDNumber__c = :eid
            WITH SYSTEM_MODE
        ];
        
        UAEPassAutoLinkRule__c ruleRecord;
        
        if (!lst_UAEPass.isEmpty()) {
            ruleRecord = lst_UAEPass.get(0);
                ruleRecord.Email__c = email;
                ruleRecord.MobilePhone__c = phone;
                ruleRecord.Contact__c = String.isNotBlank(contactId)?contactId:null;
                ruleRecord.Comments__c = comments;
                Database.update(ruleRecord, true);
        } else {
            ruleRecord = new UAEPassAutoLinkRule__c();
            ruleRecord.Email__c = email;
            ruleRecord.MobilePhone__c = phone;
            ruleRecord.EIDNumber__c = eid;
            ruleRecord.UUId__c = uuid;
            ruleRecord.Contact__c = String.isNotBlank(contactId)?contactId:null;
            ruleRecord.Comments__c = comments;
            Database.insert(ruleRecord, true);
        }
    }

    private static void configureErrorResponse(RestResponse res, List<IdentificationResponse> resList, Integer httpCode, String errCode, String errMsg) {
        IdentificationResponse errorObj = new IdentificationResponse();
        errorObj.Status = 'Failure';
        errorObj.AccountId = '';
        errorObj.ErrorCode = errCode;
        errorObj.ErrorMessage = errMsg;
        resList.add(errorObj);
        
        res.statusCode = httpCode;
        res.responseBody = Blob.valueOf(JSON.serialize(resList));
    }

    global class IdentificationResponse {
        public String Status;
        public String AccountId;
        public String ContactId;
        public String FirstName;
        public String LastName; 
        public String PersonEmail;
        public String PersonMobilePhone;
        public String EIDNumber;
        public String TradeLicenseNumber;
        public String Passport;
        public String UAE_Resident_Status;
        public String Nationality;
        public String ErrorCode;
        public String ErrorMessage;
    }
}