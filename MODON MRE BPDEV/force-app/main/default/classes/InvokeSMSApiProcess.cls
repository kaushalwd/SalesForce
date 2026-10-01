/**********************************************************************************************************************
* Name               : InvokeSMSApiProcess                                                        
* Description        : This class is helper for Creating JSON Body
* Usage              : Called from case trigger
* Created By         : Active Minds Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                Date            Comment                                                                       
* 1.0           Manojkumar         19 Feb 2023     Initial Draft       
******************************************************************************************************************/
public class InvokeSMSApiProcess {
    
    @future(callout = true)
    public static void getSMS_Future(set<string> recIds,string objectName){
        system.debug('debug: in InvokeSMSApiProcess.getSMS_Future method');
        sendSMRequest(recIds,objectName);
    }
    @InvocableMethod(label='Send SMS on Case Closure' description='Send SMS on Case Closure to end user')
    
    public static void sendSMRequest_Case(List<string> recIds){
        
        system.debug('debug: in InvokeSMSApiProcess.sendSMRequest_Case method');
        
        set<string> setRecIds = new set<string>();
        
        for(String rec: recIds)
            
        {
            setRecIds.add(rec); 
        }   
        sendSMRequest(setRecIds,'Case');
    }
    
    public static void sendSMRequest(set<String> reqestId ,string objectName) {
        system.debug('debug: in InvokeSMSApiProcess.sendSMRequest method');
        List<Case> casesClosedList = new List<case>();
        
        try{
            Map<String,String> CaseRecordMap =new Map<String,String>();
            Map<string,string> recpentMap =new Map<string,string>();
            if(objectName == 'Case'){
                for(case casesClosedRec : [SELECT Id, Customer_Name__c,Subject, Description, Status,ContactPhone,Customer_Phone__c,Account.Name FROM Case WHERE Id IN :reqestId ]){
                    string KeyName =objectName+'-'+casesClosedRec.Status; 
                    if(casesClosedRec.Customer_Phone__c != null){
                        string CaseCustomer_Phone = processPhoneNumber(casesClosedRec.Customer_Phone__c);
                        CaseRecordMap.put(KeyName,CaseCustomer_Phone);                       
                        recpentMap.put(KeyName,casesClosedRec.Account.Name);
                    }                    
                }
            }else if(objectName == 'ServiceRequest__c'){
                List<ServiceRequest__c> srList = [
                    SELECT Id, AccountId__c, AccountId__r.Name, AccountId__r.PersonMobilePhone, 
                    AccountId__r.Phone, AccountId__r.IsPersonAccount, Status__c 
                    FROM ServiceRequest__c
                    WHERE Id IN :reqestId
                ];
                
                Set<Id> brokerOrgAccountIds = new Set<Id>();
                
                for (ServiceRequest__c sr : srList) {
                    String keySRName = objectName + '-' + sr.Status__c; 
                    String phoneNumber = null;
                    
                    // Check if AccountId is not null
                    if (sr.AccountId__r != null) {
                        if (sr.AccountId__r.IsPersonAccount && sr.AccountId__r.PersonMobilePhone != null) {
                            phoneNumber = processPhoneNumber(sr.AccountId__r.PersonMobilePhone);
                        } 
                        else if (sr.AccountId__r.IsPersonAccount == false ||(sr.AccountId__r.RecordType.Name == 'Broker Agency' || sr.AccountId__r.RecordType.Name == 'Organization Account')) {
                                     brokerOrgAccountIds.add(sr.AccountId__c);
                                 } 
                        CaseRecordMap.put(keySRName, phoneNumber);
                        recpentMap.put(keySRName, sr.AccountId__r.Name);
                    }
                }
                System.debug('CaseRecordMap--->+83'+CaseRecordMap);
                if (!brokerOrgAccountIds.isEmpty()) {
                    Map<Id, String> brokerOrgPhoneMap = new Map<Id, String>();
                    
                    for (Contact con : [
                        SELECT AccountId, Phone 
                        FROM Contact 
                        WHERE AccountId IN :brokerOrgAccountIds AND Is_Active__c = true 
                        ORDER BY Name ASC 
                        LIMIT 1
                    ]) {
                        if (con.Phone != null) {
                            brokerOrgPhoneMap.put(con.AccountId, processPhoneNumber(con.Phone));
                        }
                    }
                    
                    for (ServiceRequest__c sr : srList) {
                        String keySRName = objectName + '-' + sr.Status__c;
                        System.debug('orgAcc');
                        if (brokerOrgPhoneMap.containsKey(sr.AccountId__c)) {
                            CaseRecordMap.put(keySRName, brokerOrgPhoneMap.get(sr.AccountId__c));
                            recpentMap.put(keySRName, sr.AccountId__r.Name);
                        }
                    }
                    System.debug('CaseRecordMap--->+83'+CaseRecordMap);
                }
            }else if (objectName == 'Opportunity'){
                for(Opportunity oppClosedRec : [SELECT Id, Account.name,stageName,account.phone,account.PersonMobilePhone FROM Opportunity WHERE Id IN :reqestId]){
                    string KeyOppName =objectName+'-'+oppClosedRec.Status__c; 
                    if(oppClosedRec.Account.PersonMobilePhone != null){string oppPersonMobilePhone = processPhoneNumber(oppClosedRec.Account.Phone);CaseRecordMap.put(KeyOppName,oppPersonMobilePhone); recpentMap.put(KeyOppName,oppClosedRec.Name);
                                                                      }else if(oppClosedRec.Account.Phone != null){string oppPhone = processPhoneNumber(oppClosedRec.Account.Phone);CaseRecordMap.put(KeyOppName,oppPhone);recpentMap.put(KeyOppName,oppClosedRec.Account.Name);}                    
                }
            }else if(objectName == 'Lead'){
                for(Lead leadClosedRec : [SELECT id, Name, Phone, MobilePhone,Status  FROM Lead WHERE Id IN :reqestId]){
                    string KeyLeadName =objectName+'-'+leadClosedRec.Status; 
                    if(leadClosedRec.Phone != null){
                        string Lead_Phone = processPhoneNumber(leadClosedRec.Phone);
                        CaseRecordMap.put(KeyLeadName,Lead_Phone);
                        recpentMap.put(KeyLeadName,leadClosedRec.Name);
                    }else if(leadClosedRec.MobilePhone != null){string Lead_MobilePhone = processPhoneNumber(leadClosedRec.MobilePhone); CaseRecordMap.put(KeyLeadName,Lead_MobilePhone); recpentMap.put(KeyLeadName,leadClosedRec.Name);}                    
                }
            }
            
            String jsonMessage = null;                
            
            for(SMS_Message__mdt smsRec : [select id,DeveloperName, Label, IsActive__c,FromName__c, Message__c, ObjectName__c, ServiceName__c from SMS_Message__mdt where IsActive__c =true and Type_Of_Service__c = 'SMS' AND ObjectName__c = :objectName ]){
                
                string KeyName =smsRec.ObjectName__c+'-'+smsRec.ServiceName__c;  
                System.debug('debug: KeyName ' + KeyName);
                if(CaseRecordMap.containskey(KeyName)){                    
                    String senderName = recpentMap.get(KeyName); // This should be dynamically retrieved from Salesforce data.
                    String message = smsRec.Message__c;
                    system.debug('message53--'+message);
                    message = message.replace('{Sender}', senderName);
                    system.debug('message54--'+message);
                    jsonMessage =  generateMessage(smsRec.FromName__c, CaseRecordMap.get(KeyName), message);
                    if(jsonMessage != null){
                        //invokesmsAPI(jsonMessage); // can be uncommented post prod deployment
                    }else{
                        LoggerService.save(LoggerService.createAPILog('Survey API','InvokeSMSApiProcess','SendRequest', JSON.serialize(casesClosedList), '', 'Message null or message format is not valid', 'Update Log'));
                    }
                }                
            }                     
        }catch (Exception e) {System.debug('Error in sending request to Xibo for case:' + e.getMessage());LoggerService.save(LoggerService.createAPILog('Survey API','InvokeSMSApiProcess','SendRequest', JSON.serialize(casesClosedList), '', e.getMessage(), 'Update Log'));}       
    }
    
    public static String generateMessage(String fromValue, String toValue, String textValue) {
        system.debug('debug: in InvokeSMSApiProcess.generateMessage method');
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('from', fromValue);
        jsonMap.put('to', toValue);
        jsonMap.put('text', textValue);
        
        // Serialize the map to JSON
        return JSON.serialize(jsonMap);
        // return jsonMap;
    }
    public static void invokesmsAPI(string jsonMessage) {
        system.debug('debug: in InvokeSMSApiProcess.invokesmsAPI method');
        Organization this_org = [Select Id, Name, IsSandbox from Organization];
        
        Payment_Gateway__mdt pg_metadata = new Payment_Gateway__mdt();
        
        if(this_org.IsSandbox){
            pg_metadata = Payment_Gateway__mdt.getInstance('SMS_Sandbox');
        }
        else{
            pg_metadata = Payment_Gateway__mdt.getInstance('SMS');
        }
        System.debug('debug: pg_metadata ' + pg_metadata);
        if(pg_metadata <> null){ 
            System.debug('jsonMessage--'+jsonMessage);
            string endpoint=pg_metadata.End_Point_URL__c;
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('X-Reson8-ID', pg_metadata.Transaction_Type__c); // Use Named Credential for security
            request.setHeader('X-Reson8-Token', pg_metadata.Secret_Key__c); 
            request.setHeader('api-key', pg_metadata.API_Key__c); 
            
            String jsonBody = jsonMessage;
            System.debug('jsonBody---->'+jsonBody);
            request.setBody(jsonBody);
            System.debug('request: ' + request);
            HttpResponse res = http.send(request);
            System.debug('Response: ' + res.getBody());
            // Check if the request was successful
            if (res.getStatusCode() == 200) {
                
            }else {System.debug('Error sending request to Xibo: ' + res.getStatusCode() + ' - ' + res.getBody());
                string error = res.getStatusCode() + ' - ' + res.getBody(); LoggerService.save(LoggerService.createAPILog('SMS reson8 API','InvokeSMSApiProcess','invokesmsAPI', JSON.serialize(jsonMessage), '', error, 'Update Log'));
                
            }
        }else {
            LoggerService.save(LoggerService.createAPILog('SMS reson8 API','InvokeSMSApiProcess','invokesmsAPI', 'There is no service API found', '',  'There is no service API found', 'Update Log'));
            
        }
    }
    
    public static String processPhoneNumber(String phoneNumber) {
        system.debug('debug: in InvokeSMSApiProcess.processPhoneNumber method');
        // Remove any spaces, dashes, or non-numeric characters (except + for international numbers)
        phoneNumber = phoneNumber.replaceAll('[^0-9+]', '');
        
        // Check if the phone number starts with a plus sign, and handle country code 971
        if (phoneNumber.startsWith('+971')) {
            // Remove the '+' sign
            phoneNumber = phoneNumber.substring(1);
        } 
        // Handle the case when the number starts with '000'
        else if (phoneNumber.startsWith('000971')) {
            // Replace '000' with nothing and ensure the country code is '971'
            phoneNumber = phoneNumber.substring(3);
        }
        // Handle the case when the number starts with '000'
        else if (phoneNumber.startsWith('0971')) {
            // Replace '000' with nothing and ensure the country code is '971'
            phoneNumber = phoneNumber.substring(1);
        }
        // Handle the case when the number starts with '000'
        else if (phoneNumber.startsWith('0')) {
            // Replace '0' with nothing and ensure the country code is '971'
            phoneNumber = '971' + phoneNumber.substring(1);
        }
        // Ensure the phone number starts with country code '971' (for UAE)
        else if (!phoneNumber.startsWith('971')) {
            // Optionally, you can return an error message here if phone number doesn't start with '971'
            phoneNumber = '971'+ phoneNumber;
        }
        
        system.debug('debug: cleaned-up phoneNumber ' + phoneNumber);
        // Return the cleaned-up phone number
        return phoneNumber;
    }
    
}