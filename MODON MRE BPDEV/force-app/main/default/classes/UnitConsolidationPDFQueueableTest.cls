@isTest
public class UnitConsolidationPDFQueueableTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id,status__c = 'sold');
        insert so;
    }

    @isTest
    static void testDisabledTriggerPath() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Test.startTest();
        ServiceRequestTriggerHandler.isTriggerDisabled = true;
        UnitConsolidationPDFService.generateAndAttachPDF(sr.Id);
       // sr.Status__c = 'Closed';
       // update sr;
        //System.enqueueJob(new UnitConsolidationPDFQueueable(sr.Id));
        Test.stopTest();
        //System.assertEquals(true, ServiceRequestTriggerHandler.isTriggerDisabled);
    }
}