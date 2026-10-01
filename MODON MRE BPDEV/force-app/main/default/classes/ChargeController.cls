public with sharing class ChargeController {
    @AuraEnabled(cacheable=true)
    public static List<Charge__c> getCharges(Id serviceRequestId) {
        List<ServiceRequest__c> srList = [SELECT Id, SalesOrder__c, SR_OriginID__c 
                                          FROM ServiceRequest__c 
                                          WHERE Id = :serviceRequestId];
        
        Set<Id> soId = new Set<Id>();
        Set<Id> parentSrIds = new Set<Id>();
        
        for (ServiceRequest__c sr : srList) {
            if (sr.SR_OriginID__c != null) {
                parentSrIds.add(sr.SR_OriginID__c);
            }
            if (sr.SalesOrder__c != null) {
                soId.add(sr.SalesOrder__c);
            }
        }
        
        // Use a Set to store unique Charge__c records
        Set<Id> chargeIds = new Set<Id>();
        List<Charge__c> chargeList = [SELECT Id, Name, Amount__c, PaymentStatus__c, VAT_Amount__c, Service_Request__c, Sales_Order__c 
                                      FROM Charge__c 
                                      WHERE (Service_Request__c = :serviceRequestId 
                                             OR Service_Request__c IN :parentSrIds 
                                             OR Sales_Order__c IN :soId)];
        
        // Use a Map to ensure unique Charge__c records by Id
        Map<Id, Charge__c> uniqueChargesMap = new Map<Id, Charge__c>();
        
        for (Charge__c charge : chargeList) {
            uniqueChargesMap.put(charge.Id, charge);
        }
        
        // Convert the Map values back to a List
        return new List<Charge__c>(uniqueChargesMap.values());
    }
    @AuraEnabled
    public static void deleteCharge(Id chargeId) {
        try {
            delete [SELECT Id FROM Charge__c WHERE Id = :chargeId];
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting charge: ' + e.getMessage());
        }
    }
}