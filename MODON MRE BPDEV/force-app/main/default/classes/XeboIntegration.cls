/**********************************************************************************************************************
* Name               : XeboIntegration                                                        
* Description        : Calling to XEBO for sending the customer information for server
* Usage              : Called from SalesOrderTriggerHelper
* Created By         : Mirza Baig                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                Date               Comment                                                                       
* 1.0           Mirza Baig            20 April 2026        Initial Draft
******************************************************************************************************************/
public with sharing class XeboIntegration implements Queueable, Database.AllowsCallouts {
    
    Set<Id> salesOrderIds;
    
    public XeboIntegration(Set<Id> salesOrderIds){
        this.salesOrderIds = salesOrderIds;
    }
    
    public void execute(QueueableContext qc){
        
        if(salesOrderIds == null || salesOrderIds.isEmpty()){
            return;
        }
        
        List<SalesOrder__c> salesOrders = [
            SELECT Id,
            Unit__r.Zone__c,
            CustomerAccount__r.Id,
            CustomerAccount__r.IsPersonAccount,
            CustomerAccount__r.PersonEmail,
            CustomerAccount__r.PersonMobilePhone,
            CustomerAccount__r.Name,
            CustomerAccount__r.CustomerType__c,
            CustomerAccount__r.Nationality__pc,
            CustomerAccount__r.NationalityArabic__pc,
            CustomerAccount__r.PersonBirthdate,
            CustomerAccount__r.PersonGenderIdentity,
            CustomerAccount__r.PersonTitle,
            CustomerAccount__r.Account_Category__c,
            CustomerAccount__r.CountryOfResidence__pc,
            CustomerAccount__r.Customer_Nationality__c,
            CustomerAccount__r.AccountSource,
            CustomerAccount__r.AccountnameArabic__c,
            CustomerAccount__r.UAE_Resident_Status__pc,
            CustomerAccount__r.UAEResident__c
            FROM SalesOrder__c
            WHERE Id IN :salesOrderIds
            AND CustomerAccount__c != null AND CustomerAccount__r.PersonMobilePhone != null 
        ];
        
        if(salesOrders.isEmpty()) return;
        
        Xebo_Configuration__mdt cfg =
            Xebo_Configuration__mdt.getInstance(ModonEgyptConstants.XEBO_CONFIG_DEFAULT);
        
        XeboRequestWrapper requestWrapper = new XeboRequestWrapper();
        //requestWrapper.medium = Integer.valueOf(cfg.Medium__c);
        requestWrapper.contacts = new List<XeboContactWrapper>();
        
        Map<Id, Account> uniqueAccounts = new Map<Id, Account>();
        Map<Id, String> accountZoneMap = new Map<Id, String>();
        
        for(SalesOrder__c so : salesOrders){
            
            Account acc = so.CustomerAccount__r;
            
            if(acc == null) continue;
            if(!acc.IsPersonAccount) continue;
            if(String.isBlank(acc.PersonEmail)) continue;
            
            uniqueAccounts.put(acc.Id, acc);
            accountZoneMap.put(acc.Id, 
                               so.Unit__r != null ? so.Unit__r.Zone__c : null);
        }
        
        if(uniqueAccounts.isEmpty()) return;
        
        List<Account> sentAccounts = new List<Account>();
        
        for(Account acc : uniqueAccounts.values()){
            
            XeboContactWrapper contactWrapper = new XeboContactWrapper();
            
            contactWrapper.email = acc.PersonEmail; // Yes
            contactWrapper.mobile = acc.PersonMobilePhone; // Yes
            contactWrapper.customer_type = acc.CustomerType__c; // Yes
            contactWrapper.account_name = acc.Name; // Yes
            contactWrapper.nationality = acc.Nationality__pc; // Yes
          //  contactWrapper.Nationality_Arabic = acc.NationalityArabic__pc; // Yes skip it
            contactWrapper.birthdate = acc.PersonBirthdate != null ? acc.PersonBirthdate.format() : ''; // Yes
            contactWrapper.gender_identity = acc.PersonGenderIdentity; // Yes
            contactWrapper.title_en = acc.PersonTitle; // Yes
            contactWrapper.uae_resident_status = acc.UAE_Resident_Status__pc; // Yes
            contactWrapper.account_category = acc.Account_Category__c; // Yes
            contactWrapper.country_of_residence = acc.CountryOfResidence__pc;  // Yes
            contactWrapper.customer_nationality = acc.Customer_Nationality__c; // Yes
            contactWrapper.lead_source = acc.AccountSource; // Yes
            contactWrapper.name_arabic = acc.AccountnameArabic__c; // Yes
            contactWrapper.uae_resident = acc.UAEResident__c; // Yes
            contactWrapper.zone_english = accountZoneMap.get(acc.Id); // Yes
            
            requestWrapper.contacts.add(contactWrapper);
            sentAccounts.add(acc);
        }
        
        if(requestWrapper.contacts.isEmpty()) return;
        
        sendCallout(requestWrapper, sentAccounts, cfg);
    }
    
    private void sendCallout(XeboRequestWrapper requestWrapper, List<Account> sentAccounts,Xebo_Configuration__mdt cfg){
        
        String body = JSON.serialize(requestWrapper);
        String endpoint = cfg.Endpoint__c;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', cfg.API_Key__c);
        req.setBody(body);
        
        Http http = new Http();
        List<Account> updatesAccounts = new List<Account>();
        
        try{
            HttpResponse res = http.send(req);
            
            Integer statusCode = res.getStatusCode();
            String respBody = res.getBody();
            
            Boolean isSuccess = (statusCode == 200 || statusCode == 201);
            
            ResponseWrapper resp;
            if(isSuccess){
                try{
                    resp = (ResponseWrapper) JSON.deserialize(respBody, ResponseWrapper.class);
                }catch(Exception e){}
            }
            
            for(Account acc : sentAccounts){
                updatesAccounts.add(new Account(
                    Id = acc.Id,
                    Xebo_Request__c = body,
                    Xebo_Response__c = respBody,
                    Xebo_Status__c = isSuccess 
                    ? ModonEgyptConstants.STATUS_SUCCESS 
                    : ModonEgyptConstants.STATUS_FAILED_PREFIX + statusCode,
                    Xebo_Id__c = (resp != null ? resp.msgId : null),
                    Xebo_Last_Date__c = isSuccess ? Date.today() : null
                ));
            }
            
        }catch(Exception ex){
            System.debug('Callout Exception: ' + ex.getMessage());
        }
        
        if(!updatesAccounts.isEmpty()){
            update updatesAccounts;
        }
    }
    
    public class XeboRequestWrapper {
        public Integer medium;
        public List<XeboContactWrapper> contacts;
    }
    
    public class XeboContactWrapper {
        public String email;
        public String mobile;
        public String customer_type;
        public String account_name;
        public String nationality;
        public String nationality_arabic;
        public String birthdate;
        public String gender_identity;
        public String title_en;
        public String uae_resident_status;
        public String account_category;
        public String country_of_residence;
        public String customer_nationality;
        public String lead_source;
        public String name_arabic;
        public String uae_resident;
        public String zone_english;
    }
    
    public class ResponseWrapper{
        public String msg;
        public Integer status;
        public String msgId;
    }
}