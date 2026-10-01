@isTest
public class DocuSignRecipientStatusTriggerHelperTest {

    @testSetup
    static void setupData() {
        // Create test SalesOrder__c record
        SalesOrder__c salesOrder = new SalesOrder__c();
        insert salesOrder;

        // Create test EnvelopeStatus__c record
        dfsle__EnvelopeStatus__c envelopeStatus = new dfsle__EnvelopeStatus__c(
           
            dfsle__SourceId__c = salesOrder.Id,
            dfsle__Status__c = 'Sent'
        );
        insert envelopeStatus;

        // Create test RecipientStatus__c record
        dfsle__RecipientStatus__c recipientStatus = new dfsle__RecipientStatus__c(
            dfsle__EnvelopeStatus__c = envelopeStatus.Id,
            dfsle__RoutingOrder__c = 9,
            dfsle__Status__c = 'Completed'
        );
        insert recipientStatus;
    }
    @isTest
    static void testUpdateDocuSignRecipientStatus_PendingWithModon() {
        // Create additional test data with different status 'Sent'
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        dfsle__EnvelopeStatus__c envelopeStatus = [SELECT Id FROM dfsle__EnvelopeStatus__c LIMIT 1];

        // Create RecipientStatus__c record with 'Sent' status
        dfsle__RecipientStatus__c recipientStatus = new dfsle__RecipientStatus__c(
            dfsle__EnvelopeStatus__c = envelopeStatus.Id,
            dfsle__RoutingOrder__c = 1,
            dfsle__Status__c = 'Sent'
        );
        insert recipientStatus;
        
      // Prepare RecipientStatusMap for the method
        Map<Id, SObject> recipientStatusMap = new Map<Id, SObject>{
            recipientStatus.Id => recipientStatus
        };
            
        // Call the method being tested
        Test.startTest();
        DocuSignRecipientStatusTriggerHelper.updateDocuSginRecipientStatus(new list<sobject>{recipientStatus}, new map<Id, sobject>{recipientStatus.Id => recipientStatus});
        Test.stopTest();
        
        
    }
    
     @isTest
    static void testUpdateDocuSignRecipientStatus_PendingWithCustomer() {
        // Create additional test data with different status 'Sent'
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        dfsle__EnvelopeStatus__c envelopeStatus = [SELECT Id FROM dfsle__EnvelopeStatus__c LIMIT 1];

        // Create RecipientStatus__c record with 'Sent' status
        dfsle__RecipientStatus__c recipientStatus = new dfsle__RecipientStatus__c(
            dfsle__EnvelopeStatus__c = envelopeStatus.Id,
            dfsle__RoutingOrder__c = 1,
            dfsle__Status__c = 'Sent'
        );
        
        dfsle__RecipientStatus__c recipientStatus2 = new dfsle__RecipientStatus__c(
            dfsle__EnvelopeStatus__c = envelopeStatus.Id,
            dfsle__RoutingOrder__c = 2,
            dfsle__Status__c = 'Created'
        );
        List<dfsle__RecipientStatus__c> recipientStatusList = new List<dfsle__RecipientStatus__c>();
        //insert recipientStatus;
        recipientStatusList.add(recipientStatus2);
        recipientStatusList.add(recipientStatus);
        insert recipientStatusList;
        // Prepare RecipientStatusMap for the method
        Map<Id, SObject> recipientStatusMap = new Map<Id, SObject>{
            recipientStatusList[0].Id => recipientStatusList[0],
                recipientStatusList[1].Id =>recipientStatusList[1]
        };

        // Call the method being tested
        Test.startTest();
        DocuSignRecipientStatusTriggerHelper.updateDocuSginRecipientStatus(new list<sobject>{recipientStatus2,recipientStatus},  new map<Id, sobject>{recipientStatus.Id => recipientStatus,recipientStatus2.Id => recipientStatus2 });
        Test.stopTest();
        
        
    }
    
}