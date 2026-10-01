public without sharing class ADMSRService {
    
    private static final String SERVICE_REQUEST_RT_DEV_NAME_ADM = 'Service_Request_Management_ADM';
    
    public static void createADMServiceRequests(List<SalesOrder__c> salesOrders) {
        try {
            if (salesOrders == null || salesOrders.isEmpty()) {
                return;
            }
            Boolean TriggerOICService = String.isNotBlank(Label.TriggerOICService) && Label.TriggerOICService.toLowerCase() == 'true' ? True :False;             
            if(TriggerOICService){
                
            
            Set<Id> salesOrderIds = new Set<Id>();
            for (SalesOrder__c so : salesOrders) {
                salesOrderIds.add(so.Id);
            }
            Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(
                ServiceRequest__c.SObjectType,
                SERVICE_REQUEST_RT_DEV_NAME_ADM
            );
            
            Map<Id, ServiceRequest__c> existingSOWithSR = new Map<Id, ServiceRequest__c>();
            for (ServiceRequest__c sr : [
                SELECT SalesOrder__c, Transferred_Sales_Order__c,RecordTypeId
                FROM ServiceRequest__c
                WHERE (SalesOrder__c IN :salesOrderIds OR Transferred_Sales_Order__c ='')
                AND SalesOrder__r.Status__c = 'Completed'
            ]) {
                if (sr.SalesOrder__c != null && sr.RecordTypeId  == admrRecordTypeId) {
                    existingSOWithSR.put(sr.SalesOrder__c, sr);
                }
               /* if (sr.Transferred_Sales_Order__c != null) {
                    existingSOWithSR.put(sr.Transferred_Sales_Order__c, sr);
                }*/
            }
            
            
            List<ServiceRequest__c> newSRs = new List<ServiceRequest__c>();
            
            for (SalesOrder__c so : salesOrders) {
                if (!existingSOWithSR.containsKey(so.Id)) {
                    ServiceRequest__c sr = new ServiceRequest__c();
                    sr.Name__c = 'ADM Registration SR - ' + so.Unit_Name__c + ' - New Sale';
                    sr.SalesOrder__c = so.Id;
                    sr.AccountId__c = so.CustomerAccount__c;
                    sr.Type__c = 'New Sale';
                    sr.Status__c = 'New';
                    sr.UnitId__c = so.Unit__c;
                    sr.RecordTypeId = admrRecordTypeId;
                    sr.OpportunityId__c = so.Opportunity__c;
                    sr.Source_Of_SR__c = 'Sales Order';
                    newSRs.add(sr);
                }
            }
            
            if (!newSRs.isEmpty()) {
                System.debug('newSRs--->'+newSRs);
                Database.SaveResult[] results = Database.insert(newSRs, false);
                
                System.debug('results--->'+results);
            }
            }
        } catch (Exception ex) {
            LoggerService.save(
                LoggerService.createApexLog(
                    ex,
                    'SR ADM Creation',
                    'ADMSRService',
                    'createADMServiceRequests - Exception: ' + ex.getMessage()
                )
            );
        }
    }
}