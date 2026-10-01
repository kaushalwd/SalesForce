public with sharing class CloneOpportunityController {
    
    @AuraEnabled(Cacheable=true)
    public static List<Opportunity> getRelatedOpportunities(Id accountId) {
        return [SELECT Id, Name,(Select Id From Sales_Orders__r) FROM Opportunity WHERE AccountId = :accountId];
    }
    
    @AuraEnabled
    public static Id cloneOpportunity(Id accountId) {
        
        //Id userId = UserInfo.getUserId();
        List<Opportunity> allOpportunities = [SELECT Id, Name FROM Opportunity WHERE AccountId = :accountId];
        
        if(allOpportunities.size() < 1){
            throw new AuraHandledException('You have no opportunity to clone');
        }
        
        Set<Id> opportunityIdsWithValidSalesOrders = new Set<Id>();
        for (SalesOrder__c salesOrder : [SELECT Opportunity__c FROM SalesOrder__c WHERE Opportunity__r.AccountId = :accountId 
                                         AND Status__c NOT IN ('Cancelled', 'System Cancelled', 'In Progress')]) {
                                             opportunityIdsWithValidSalesOrders.add(salesOrder.Opportunity__c);
                                         }
        
        Boolean allOpportunitiesHaveValidSalesOrders = true;
        for (Opportunity opp : allOpportunities) {
            if (!opportunityIdsWithValidSalesOrders.contains(opp.Id)) {
                allOpportunitiesHaveValidSalesOrders = false;
                break;
            }
        }
        
        if (!allOpportunitiesHaveValidSalesOrders) {
            return null;
        }
        
        Opportunity originalOpp = [SELECT Id, Name, StageName, Account.Name, OwnerId FROM Opportunity WHERE Id IN :opportunityIdsWithValidSalesOrders 
                                   ORDER BY CreatedDate ASC LIMIT 1];
        List<SObject> passtoDocument = new List<SObject>();
        Opportunity clonedOpp;
        try{
            clonedOpp = originalOpp.clone(false, true);
            clonedOpp.Name = originalOpp.Account.Name;
            clonedOpp.StageName = 'Unit Selection in Progress';
            clonedOpp.CloseDate = Date.today().addDays(2);
            insert clonedOpp;
        }catch(DMLException e){
            System.debug('Error While Inserting Clone Record:'+ e.getMessage());
        }
        try{
            AccountShare accountShare = new AccountShare();
            accountShare.AccountId = originalOpp.AccountId;
            accountShare.UserOrGroupId = originalOpp.OwnerId;
            accountShare.AccountAccessLevel = 'Edit'; 
            accountShare.OpportunityAccessLevel = 'Edit';
            accountShare.RowCause = Schema.AccountShare.RowCause.Manual;
            insert accountShare;
            System.debug('accountShare: '+accountShare);
        }catch(DMLException e){
            System.debug('Error While Creating account sharing: '+ e.getMessage());
        }
        passtoDocument.add(clonedOpp);
        createDocumentRecords(passtoDocument);
        return clonedOpp.Id;
    }
    public static void createDocumentRecords(List<SObject> newList) { 
        List<Documents__c> lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Lead');
        
        if (!lstDocumentsCurrent.isEmpty()) {
            List<Documents__c> lstDocumentsToInsert = new List<Documents__c>();
            for (Opportunity soObj : (List<Opportunity>)newList) {
                for (Documents__c doc : lstDocumentsCurrent) {
                    Documents__c tempD = doc.clone();
                    tempD.Opportunity__c = soObj.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if (!lstDocumentsToInsert.isEmpty()) {
                try{
                    insert lstDocumentsToInsert;
                }
                catch(DMLException e){
                    System.debug('Documents Insertion Failed: '+ e.getMessage());
                }
            }
        }
    }
}