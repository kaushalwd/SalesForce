/**********************************************************************************************************************
* Name               : PaymentPlanInstallmentHelper
* Description        : Helper class for PaymentInstallements__c trigger logic
* Usage              : Called from PaymentPlanInstallmentTriggerHandler
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               19 Aug 2025     Initial Draft       
**********************************************************************************************************************/
public with sharing class Modon_Egypt_PaymentInstallmentHelper {    
    
    
    private static final Map<String, String> UPDATE_FIELD_MAPPING = new Map<String, String>{
        'Milestone__c'      => 'Milestone__c',
        'Milestone_Date__c' => 'MilestoneDate__c'
    };
        
    private static final Map<String, String> EVENT_FIELD_MAPPING = new Map<String, String>{
        'Currency_ISO_Code__c'       => 'CurrencyIsoCode',
        'Instalment_Number__c'       => 'InstalmentNumber__c',
        'Is_Handover_Payment__c'     => 'IsHandoverPayment__c',
        'LastModifiedDate__c'        => 'LastModifiedDate',
        'Milestone__c'               => 'Milestone__c',
        'Milestone_Date__c'          => 'MilestoneDate__c',
        'Milestone_Description__c'   => 'MilestoneDescription__c',
        'Milestone_Number__c'        => 'MilestoneNumber__c',
        'Name__c'                    => 'Name',
        'Payment_Installment__c'     => 'PaymentInstallment__c'
   	};
        
    public static void syncPaymentInstallmentToNawy(List<PaymentInstallements__c> newList) {
        List<PaymentInstallementEvent__e> paymentInstallmentsEventsList = new List<PaymentInstallementEvent__e>();
        List<PaymentInstallements__c> paymentInstallmentstoInsertList = new List<PaymentInstallements__c>();
        
        for (PaymentInstallements__c installment : newList) {
            paymentInstallmentsEventsList.add(createEvent(installment, 'Create'));
            paymentInstallmentstoInsertList.add(installment);
        }
        
        publishEvents(paymentInstallmentsEventsList, paymentInstallmentstoInsertList);
    }
    
    
    public static void syncUpdatedPaymentInstallmentToNawy(List<PaymentInstallements__c> newList, Map<Id, PaymentInstallements__c> oldMap) {
        List<PaymentInstallementEvent__e> eventsList = new List<PaymentInstallementEvent__e>();
        
        for (PaymentInstallements__c newRec : newList) {
            PaymentInstallements__c oldRec = oldMap.get(newRec.Id);
            Map<String, Object> changedFieldsMap = getChangedFields(newRec, oldRec);
            if (!changedFieldsMap.isEmpty()) {
                PaymentInstallementEvent__e eventPayload = new PaymentInstallementEvent__e();
                eventPayload.put('RecordId__c', newRec.Id);
                eventPayload.put('Operation_Type__c', 'Update');                
                for (String eventField : changedFieldsMap.keySet()) {
                    eventPayload.put(eventField, changedFieldsMap.get(eventField));
                }                
                eventsList.add(eventPayload);
            }
        }        
        if (!eventsList.isEmpty()) {
            EventBus.publish(eventsList);
        }
    }

    
    private static Map<String, Object> getChangedFields(PaymentInstallements__c newRec, PaymentInstallements__c oldRec) {
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
    
    private static PaymentInstallementEvent__e createEvent(PaymentInstallements__c sourceRecord, String operationType) {
        PaymentInstallementEvent__e eventPayload = new PaymentInstallementEvent__e();
        
        eventPayload.put('RecordId__c', sourceRecord.Id);
        eventPayload.put('Operation_Type__c', operationType);
        eventPayload.put('Source_Entity__c', 'Modon - Egypt'); // Assuming this is a constant
        
        // Dynamically assign mapped fields
        for (String eventField : EVENT_FIELD_MAPPING.keySet()) {
            String sourceField = EVENT_FIELD_MAPPING.get(eventField);
            eventPayload.put(eventField, sourceRecord.get(sourceField));
        }
        
        return eventPayload;
    }

    public static Boolean TEST_THROW_EXCEPTION = false; 
    private static void publishEvents(List<PaymentInstallementEvent__e> events, List<PaymentInstallements__c> records) {
        if (TEST_THROW_EXCEPTION) {
            throw new AuraHandledException('Forced exception for testing trigger catch block');
        }
        Database.SaveResult[] results = EventBus.publish(events);
        
        // Prepare log details
        String processName = 'Nawy - PaymentInstallmentSync';
        String className = 'PaymentInstallmentTriggerHelper';
        String methodName = 'publishEvents';
        String requestBody = JSON.serialize(events);
        String responseBody = JSON.serialize(results);
        String statusCode = getStatusCode(results);
        String logType = 'Integration';
        
        // Create and insert log
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