@isTest
public class UnitConsolidationPDFServiceTest {
private static final String SERVICE_REQUEST_RT_UNIT_SWAP = 'SRM_Unit_Swap';
    private static final String SERVICE_REQUEST_RT_UNIT_UPGRADE = 'Service_Request_Management_Unit_Upgrade';

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'sold'
        );
        insert so;
        
    }

    @isTest
    static void testGenerateAndEmailPDF_UnitSwap() {
        Id rtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get(SERVICE_REQUEST_RT_UNIT_SWAP).getRecordTypeId();
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = rtId
        );
        insert sr;

        Test.startTest();
        ServiceRequestTriggerHandler.isTriggerDisabled = true;
        UnitUpgradeOrSwapPDFService.generateAndEmailPDF(sr.Id);
        Test.stopTest();

        List<Attachment> attachments = [SELECT Id, Name FROM Attachment WHERE ParentId = :sr.Id];
        System.assertEquals(1, attachments.size(), 'Expected one PDF attachment');
        System.assertEquals('Unit_Swap_Memo.pdf', attachments[0].Name);
    }

    @isTest
    static void testGenerateAndEmailPDF_UnitUpgrade() {
        Id rtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get(SERVICE_REQUEST_RT_UNIT_UPGRADE).getRecordTypeId();
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = rtId
        );
        insert sr;

        Test.startTest();
        ServiceRequestTriggerHandler.isTriggerDisabled = true;
        UnitUpgradeOrSwapPDFService.generateAndEmailPDF(sr.Id);
        Test.stopTest();

        List<Attachment> attachments = [SELECT Id, Name FROM Attachment WHERE ParentId = :sr.Id];
        System.assertEquals(1, attachments.size(), 'Expected one PDF attachment');
        System.assertEquals('Unit_Upgrade_Memo.pdf', attachments[0].Name);
    }

    @isTest
    static void testGenerateAndEmailPDF_UnsupportedRecordType() {
       
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id
        );
        insert sr;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            UnitUpgradeOrSwapPDFService.generateAndEmailPDF(sr.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Expected AuraHandledException for unsupported record type');
    }
   
}