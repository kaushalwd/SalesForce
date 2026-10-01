@isTest
public class TestAttachEOIFilesBatchForEOIFiles {

    @testSetup
    static void setupData() {
        // Create Account and Contact
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact conObj = new Contact(LastName = 'Test Contact', Email = 'test@test.com');
        insert conObj;

        // Create Opportunity with ID and Passport fields
        Opportunity oppObj = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            PrimaryContact__c = conObj.Id,
            Egyptian_ID__c = '1234567890',
            PassportNumber__c = 'P1234567'
        );
        insert oppObj;

        // Create EOIs
        Expressionofinterest__c eoi1 = new Expressionofinterest__c(
            EOI_Code_Legacy__c = 'EOI-123',
            Opportunity__c = oppObj.Id
        );
        insert eoi1;

        Expressionofinterest__c eoi2 = new Expressionofinterest__c(
            EOI_Code_Legacy__c = 'EOI-456',
            Opportunity__c = oppObj.Id
        );
        insert eoi2;

        // Create Receipts
        Receipt__c receipt1 = new Receipt__c(
            Expressionofinterest__c = eoi1.Id,
            Account__c = acc.Id
        );
        insert receipt1;

        Receipt__c receipt2 = new Receipt__c(
            Expressionofinterest__c = eoi2.Id,
            Account__c = acc.Id
        );
        insert receipt2;

        // Create Documents__c for Receipt
        Documents__c docReceipt = new Documents__c(
            Receipt__c = receipt1.Id,
            Expressionofinterest__c = eoi1.Id
        );
        insert docReceipt;

        // Create Documents__c for ID files
        Documents__c docID1 = new Documents__c(
            Expressionofinterest__c = eoi2.Id,
            Opportunity__c = oppObj.Id,
            Name = 'National Id'
        );
        insert docID1;

        Documents__c docID2 = new Documents__c(
            Expressionofinterest__c = eoi2.Id,
            Opportunity__c = oppObj.Id,
            Name = 'Passport'
        );
        insert docID2;

        // Create Documents__c for EOI files
        Documents__c docEOI = new Documents__c(
            Expressionofinterest__c = eoi1.Id
        );
        insert docEOI;

        // Create Documents__c for Residency files
        Documents__c docResidency = new Documents__c(
            Expressionofinterest__c = eoi1.Id
        );
        insert docResidency;

        // Create ContentVersion for Receipt, ID, Payment, EOI, Residency
        insert new List<ContentVersion>{
            new ContentVersion(
                Title = 'EOI-123_RECEIPT_File',
                PathOnClient = 'EOI-123_RECEIPT_File.pdf',
                VersionData = Blob.valueOf('Receipt file content')
            ),
            new ContentVersion(
                Title = 'EOI-456_ID_File',
                PathOnClient = 'EOI-456_ID_File.pdf',
                VersionData = Blob.valueOf('ID file content')
            ),
            new ContentVersion(
                Title = 'EOI-123_PAYM_File',
                PathOnClient = 'EOI-123_PAYM_File.pdf',
                VersionData = Blob.valueOf('Payment file content')
            ),
            new ContentVersion(
                Title = 'EOI-123_EOI_File',
                PathOnClient = 'EOI-123_EOI_File.pdf',
                VersionData = Blob.valueOf('EOI file content')
            ),
            new ContentVersion(
                Title = 'EOI-123_RECE_RESIDENCY_File',
                PathOnClient = 'EOI-123_RECE_RESIDENCY_File.pdf',
                VersionData = Blob.valueOf('Residency file content')
            )
        };
    }

    @isTest
    static void testReceiptBatchExecution() {
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Receipt__c != NULL LIMIT 1];
        String query = 'SELECT Id, Receipt__r.Expressionofinterest__r.EOI_Code_Legacy__c FROM Documents__c WHERE Id = \'' + doc.Id + '\'';
        AttachEOIFilesBatchForReceiptFiles batch = new AttachEOIFilesBatchForReceiptFiles(query);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testIDBatchExecution() {
        List<Documents__c> docs = [SELECT Id FROM Documents__c WHERE Expressionofinterest__c != NULL AND Opportunity__c != NULL AND Name IN ('National Id', 'Passport')];
        String query = 'SELECT Id, Expressionofinterest__r.EOI_Code_Legacy__c, Opportunity__r.Egyptian_ID__c, Opportunity__r.PassportNumber__c, Name FROM Documents__c WHERE Id IN (\'' + docs[0].Id + '\', \'' + docs[1].Id + '\')';
        AttachEOIFilesBatchForIDFiles batch = new AttachEOIFilesBatchForIDFiles(query);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testPaymentBatchExecution() {
		Receipt__c rec = [SELECT Id FROM Receipt__c WHERE Expressionofinterest__r.EOI_Code_Legacy__c != NULL LIMIT 1];
		String query = 'SELECT Id, Name, Expressionofinterest__r.EOI_Code_Legacy__c FROM Receipt__c WHERE Id =\'' + rec.Id + '\'';
        AttachEOIFilesBatchForPaymentFiles batch = new AttachEOIFilesBatchForPaymentFiles(query);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testEOIBatchExecution() {
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Expressionofinterest__c != NULL AND Receipt__c = NULL LIMIT 1];
        String query = 'SELECT Id, Expressionofinterest__r.EOI_Code_Legacy__c FROM Documents__c WHERE Id = \'' + doc.Id + '\'';
        AttachEOIFilesBatchForEOIFiles batch = new AttachEOIFilesBatchForEOIFiles(query);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    @isTest
    static void testResidencyBatchExecution() {
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Expressionofinterest__c != NULL LIMIT 1];
        String query = 'SELECT Id, Expressionofinterest__r.EOI_Code_Legacy__c FROM Documents__c WHERE Id = \'' + doc.Id + '\'';
        AttachEOIFilesBatchForResidencyFiles batch = new AttachEOIFilesBatchForResidencyFiles(query);

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
}