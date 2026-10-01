/**********************************************************************************************************************
* Name               : CreditCardTokenValidityBatch                                                        
* Description        : This class is used to check the card validity and process updates seamlessly in batches.
* Usage              : Batch class execution pipeline
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    12 06 2026      Initial Draft       
******************************************************************************************************************/
global without sharing class CreditCardTokenValidityBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Date twoDaysAfter = System.today().addDays(2);
        return Database.getQueryLocator([SELECT Id, TokenId__c, Reference__c, Processed_On__c, Status__c, Approved__c, ExpiresOn__c, Amount__c 
                                         FROM CreditCardToken__c 
                                         WHERE Status__c = 'Authorized' AND Approved__c = true AND Reference__c != null 
                                         AND TokenId__c != null AND ExpiresOn__c <= :twoDaysAfter]);
    }    
   		
    global void execute(Database.BatchableContext BC, List<CreditCardToken__c> scope) {
        List<CreditCardToken__c> batchUpdateList = new List<CreditCardToken__c>();
        try {
            Http httpenv = new Http();
            HttpRequest requestenv = new HttpRequest();
            requestenv.setMethod('POST'); 
            requestenv.setHeader('Content-Type', 'application/json');
            requestenv.setTimeout(120000);
            
            if (!Test.isRunningTest()) {
                 requestenv = OIC_CredentialsController.getCredentials('CreditCardTokenValidity');
            } else {
                requestenv.setEndpoint('https://mock-gateway.com');
            }
            
            for (CreditCardToken__c obj_CC : scope) {
                CCTokenValidityRequest obj_Request = new CCTokenValidityRequest();
                obj_Request.Reference = obj_CC.Reference__c;
                obj_Request.Amount = obj_CC.Amount__c;
                obj_Request.CheckoutId = obj_CC.TokenId__c;
                
                requestenv.setBody(JSON.serialize(obj_Request));
                System.debug('CreditCardTokenValidityBatch >>>>> Request >> ' + JSON.serialize(obj_Request));
                
                HTTPResponse res = new HTTPResponse();
                if (!Test.isRunningTest()) {
                    res = httpenv.send(requestenv);
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"Status":"Success","SourceSystem":"TEST_GATEWAY","Expires_On":"2029-12-31T00:00:00.000Z"}');
                }
                if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                    CCTokenValidityResponse obj_Response = (CCTokenValidityResponse)System.JSON.deserialize(
                        res.getBody(), 
                        CCTokenValidityResponse.class
                    );
                    
                    if (obj_Response != null && obj_Response.Status == 'Success') {
                        obj_CC.UpdatedBy__c = obj_Response.SourceSystem;
                        obj_CC.ExpiresOn__c = obj_Response.Expires_On != null ? obj_Response.Expires_On : obj_CC.ExpiresOn__c;
                        batchUpdateList.add(obj_CC);
                    }                        
                }                                            
            }
            
            if (!batchUpdateList.isEmpty()) {
                Database.update(batchUpdateList, true);
            }
            
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, 'CreditCardTokenValidityBatch', 'execute', 'Batch Processing Frame Failure'));
        }        
    }
    
    global void finish(Database.BatchableContext BC) {
        System.debug('CreditCardTokenValidityBatch verification pipeline execution finalized successfully.');
    }
    
    global class CCTokenValidityRequest {
        public String Reference;
        public Decimal Amount;
        public String CheckoutId;
    }
    
    global class CCTokenValidityResponse {
        public Datetime Expires_On;
        public String Status;
        public String SourceSystem;
    }
}