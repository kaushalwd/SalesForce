/**********************************************************************************************************************
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/passfort/update/*')
global with sharing class PassforStatusUpdate {
    //TODO CHnage the JSON parsing if the request will come from passfort
   @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        map<string,object> responseMap = new map<string,object>();
        
        try{
            system.debug(req.requestBody.toString());
            Map<String, Object> jsonBody = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            system.debug('----');
            system.debug(req.requestBody.toString());
            string eventValue  = jsonBody.get('event').toString();
            
            Map<String, Object> datavalues = (Map<String, Object>) jsonBody.get('data');
             
            string profile_id  = datavalues.get('profile_id').toString();
            
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
            list<Contact> relatedContacts = [
                SELECT Id FROM Contact WHERE ProfileId__c = :profile_id WITH USER_MODE
            ];
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
            list<Account> relatedAccount = [
                SELECT Id FROM Account WHERE ProfileId__c = :profile_id WITH USER_MODE
            ];
            
            if(!relatedContacts.isEmpty()){ 
                if(eventValue == 'RISK_LEVEL_CHANGED'){ relatedContacts[0].PassfortRiskStatus__c = datavalues.get('new_category').toString(); }else if(eventValue == 'PRODUCT_STATUS_CHANGED'){ relatedContacts[0].PassfortApprovalStatus__c  = datavalues.get('new_status').toString(); }
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact update
                Database.update(relatedContacts, AccessLevel.USER_MODE);
                responseMap.put('data',relatedContacts);
            }
            
            if(!relatedAccount.isEmpty()){ 
                if(eventValue == 'RISK_LEVEL_CHANGED'){ relatedAccount[0].PassfortRiskStatus__c = datavalues.get('new_category').toString(); }else if(eventValue == 'PRODUCT_STATUS_CHANGED'){ relatedAccount[0].PassfortApprovalStatus__c  = datavalues.get('new_status').toString(); }
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account update
                Database.update(relatedAccount, AccessLevel.USER_MODE);
                responseMap.put('data',relatedAccount);
            }
            responseMap.put('result','succcess');
            res.statusCode = 200;
            
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Passfort Status Update',
                'PassforStatusUpdate',
                'doPost'
            ));
            responseMap.put('result','error');
            responseMap.put('Message',e.getMessage());
            res.statusCode = 200;
        }
        res.responseBody = Blob.valueOf(JSON.serialize(responseMap));
        
    }
}