public class FetchServiceRequestContoller {

    @AuraEnabled(cacheable=true)
    public static List<Case> getCaseObjData(string recordId){
        return [SELECT Id,Unit__c,accountId FROM Case Where Id=:recordId];
    }
    
     @AuraEnabled
    public static void updateCaseWithServiceRequest(Id caseId, Id serviceRequestId) {
        try {
            ServiceRequest__c sr=[SELECT Id,Name from ServiceRequest__c Where Id=:serviceRequestId LIMIT 1];
            Case caseRecord = [SELECT Id, SR_Number__c FROM Case WHERE Id = :caseId LIMIT 1];
            caseRecord.SR_Number__c = sr.Name;
            update caseRecord;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update Case: ' + e.getMessage());
        }
    }
    
     @AuraEnabled(cacheable=true)
    public static List<SalesOrder__c> getSalesOrders(String unitId) {
        if (String.isEmpty(unitId)) {
            return new List<SalesOrder__c>();
        }

        return [SELECT Id, Name FROM SalesOrder__c WHERE Unit__c = :unitId];
    }
    
}