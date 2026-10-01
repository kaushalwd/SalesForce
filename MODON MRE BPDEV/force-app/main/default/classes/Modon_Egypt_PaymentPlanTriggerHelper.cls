/**********************************************************************************************************************
* Name               : PaymentPlanTriggerHelper
* Description        : Helper class for PaymentPlan__c trigger logic
* Usage              : Called from PaymentPlanInstallmentTriggerHandler
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.1           mdixit@horizontal.com               20 Aug 2025     Refactored with dynamic field mapping and logging
**********************************************************************************************************************/
public without sharing class Modon_Egypt_PaymentPlanTriggerHelper {
    private static final Map<String, String> UPDATE_FIELD_MAPPING = new Map<String, String>{
        'Expiry_Date__c' => 'ExpiryDate__c',
        'Status__c'      => 'Status__c',
        'Name__c'      => 'Name',
        'Currency_ISO_Code__c'      => 'CurrencyIsoCode'
    };
                
    private static final Map<String, String> EVENT_FIELD_MAPPING = new Map<String, String>{
        'Currency_ISO_Code__c' => 'CurrencyIsoCode',
        'Expiry_Date__c'       => 'ExpiryDate__c',
        'LastModifiedDate__c'  => 'LastModifiedDate',
        'Name__c'              => 'Name',
        'Phase__c'             => 'Phase__c',
        'RecordId__c'          => 'Id',
        'Start_Date__c'        => 'StartDate__c',
        'Status__c'            => 'Status__c',
        'Type__c'              => 'Type__c'
    };  
    
    public static void syncPaymentPlanToNawy(List<PaymentPlan__c> newList) {
        List<PaymentPlanEvent__e> paymentPlanEventList = new List<PaymentPlanEvent__e>();
        
        for (PaymentPlan__c rec : newList) {
            paymentPlanEventList.add(createEvent(rec, 'Create'));
        }
        
        publishEvents(paymentPlanEventList);
    }
    
    public static void syncPaymentPlanUpdatesToNawy(List<PaymentPlan__c> newList, Map<Id, PaymentPlan__c> oldMap) {
        List<PaymentPlanEvent__e> paymentPlanEventList = new List<PaymentPlanEvent__e>();
               
        for (PaymentPlan__c newRec : newList) {
            PaymentPlan__c oldRec = oldMap.get(newRec.Id);
            Map<String, Object> changedFields = getChangedFields(newRec, oldRec);
            
            if (!changedFields.isEmpty()) {
                PaymentPlanEvent__e eventPayload = new PaymentPlanEvent__e();
                eventPayload.put('RecordId__c', newRec.Id);
                eventPayload.put('Operation_Type__c', 'Update');
                eventPayload.put('Source_Entity__c', 'Modon - Egypt');
                
                for (String field : changedFields.keySet()) {
                    eventPayload.put(field, changedFields.get(field));
                }
                
                paymentPlanEventList.add(eventPayload);
            }
        }
        
        if (!paymentPlanEventList.isEmpty()) {
            publishEvents(paymentPlanEventList);
        }
    }
    
    private static Map<String, Object> getChangedFields(PaymentPlan__c newRec, PaymentPlan__c oldRec) {
        Map<String, Object> changedFields = new Map<String, Object>();
        
        for (String eventField : UPDATE_FIELD_MAPPING.keySet()) {
            String sourceField = UPDATE_FIELD_MAPPING.get(eventField);
            Object newValue = newRec.get(sourceField);
            Object oldValue = oldRec.get(sourceField);
            
            if (newValue != oldValue) {
                changedFields.put(eventField, newValue);
            }
        }
        
        return changedFields;
    }
    
    private static PaymentPlanEvent__e createEvent(PaymentPlan__c sourceRecord, String operationType) {
        PaymentPlanEvent__e eventPayload = new PaymentPlanEvent__e();
        
        eventPayload.put('RecordId__c', sourceRecord.Id);
        eventPayload.put('Operation_Type__c', operationType);
        eventPayload.put('Source_Entity__c', 'Modon - Egypt');
        
        for (String eventField : EVENT_FIELD_MAPPING.keySet()) {
            String sourceField = EVENT_FIELD_MAPPING.get(eventField);
            eventPayload.put(eventField, sourceRecord.get(sourceField));
        }
        
        return eventPayload;
    }
    
    public static Boolean TEST_THROW_EXCEPTION = false; 
    private static void publishEvents(List<PaymentPlanEvent__e> events) {   
        
        if (TEST_THROW_EXCEPTION) {
            throw new AuraHandledException('Forced exception for testing trigger catch block');
        }
        
        Database.SaveResult[] results = EventBus.publish(events);
        
        String processName = 'Nawy - PaymentPlanSync';
        String className = 'PaymentPlanTriggerHelper';
        String methodName = 'publishEvents';
        String requestBody = JSON.serialize(events);
        String responseBody = JSON.serialize(results);
        String statusCode = getStatusCode(results);
        String logType = 'Integration';
        
        Logger__c logEntry = LoggerService.createAPILog(
            processName,
            className,
            methodName,
            requestBody,
            responseBody,
            statusCode,
            logType
        );
        
        insert logEntry;
    }
    
    private static String getStatusCode(Database.SaveResult[] results) {
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                return 'FAILURE';
            }
        }
        return 'SUCCESS';
    }
}