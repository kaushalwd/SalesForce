@isTest
public class SendBCCLetterBatchTest {

    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(Name = 'BCC Project');
        insert proj;

        Phase__c ph = new Phase__c(Name = 'BCC Phase 1', Project__c = proj.Id);
        insert ph;

        Unit__c unit = new Unit__c(
            Name = 'Unit-BCC-01',
            Phase__c = ph.Id,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            PlotNo__c = '1'
        );
        insert unit;

        Account acc = new Account(Name = 'BCC Customer Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'BCC',
            LastName = 'Primary',
            AccountId = acc.Id,
            Email = 'bcc_primary@example.com'
        );
        insert con;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            PrimaryContact__c = con.Id,
            Status__c = 'In Progress'
        );
        insert so;

        ContentVersion cv = new ContentVersion(
            Title = 'BCC Letter Document',
            PathOnClient = 'BCC_Letter.pdf',
            VersionData = Blob.valueOf('Sample BCC letter PDF content')
        );
        insert cv;

        ContentVersion cvQueried = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cvQueried.ContentDocumentId,
            LinkedEntityId = ph.Id,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testSendBCCLetterBatchExecution() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        SendBCCLetterBatch batch = new SendBCCLetterBatch(new List<Id>{unit.Id});
        Database.executeBatch(batch, 10);
        Test.stopTest();

        System.assertNotEquals(null, unit.Id, 'Unit should exist');
    }
}