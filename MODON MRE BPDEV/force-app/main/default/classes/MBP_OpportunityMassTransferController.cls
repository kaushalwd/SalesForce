public class MBP_OpportunityMassTransferController {
    
    @AuraEnabled(cacheable=true)
    public static List<Expressionofinterest__c> getEOIRecords() {

        return [
            SELECT
            Id,
            Name,
            EOIId__c,
            CreatedDate,
            CreatedBy.Name,
            BrokerAgency__c,
            BrokerAgency__r.Name,
            BrokerAgent__c,
            BrokerAgent__r.Name,
            Number_of_Units__c,
            NumberofBedrooms__c,
            EOI_Amount_AED__c,
            Opportunity__c,
            Opportunity__r.OwnerId,
            Opportunity__r.Owner.Name
            FROM Expressionofinterest__c
            WHERE BrokerAgency__r.Name != null 
            AND Opportunity__r.OwnerId =:UserInfo.getUserId()
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void changeOpportunityOwners(
        List<Id> eoiIds,
        Id newOwnerId) {

        if(eoiIds == null || eoiIds.isEmpty()) {
            throw new AuraHandledException('No records selected.');
        }

        List<Expressionofinterest__c> eoiList = [
            SELECT Id, Opportunity__c
            FROM Expressionofinterest__c
            WHERE Id IN :eoiIds
            AND Opportunity__c != null
        ];

        Set<Id> oppIds = new Set<Id>();

        for(Expressionofinterest__c eoi : eoiList) {
            oppIds.add(eoi.Opportunity__c);
        }

        if(oppIds.isEmpty()) {
            throw new AuraHandledException(
                'No related Opportunities found.'
            );
        }

        List<Opportunity> oppsToUpdate = [
            SELECT Id, OwnerId
            FROM Opportunity
            WHERE Id IN :oppIds
        ];

        for(Opportunity opp : oppsToUpdate) {
            opp.OwnerId = newOwnerId;
        }

        update oppsToUpdate;
    }
}