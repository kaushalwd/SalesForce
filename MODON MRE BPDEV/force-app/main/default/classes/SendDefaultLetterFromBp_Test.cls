@IsTest
public class SendDefaultLetterFromBp_Test {

    @testSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Primary',
            Email = 'primary@test.com',
            AccountId = acc.Id
        );
        insert con;

        Project__c proj = new Project__c(
            Name = 'Test Project'
        );
        insert proj;

        Phase__c phase = new Phase__c(
            Project__c = proj.Id
        );
        insert phase;

        Unit__c unitRec = new Unit__c(
            Name = 'A-101',
            Phase__c = phase.Id,
            PlotNo__c = '1234',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert unitRec;

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'Completed',
            Unit__c = unitRec.Id,
            CustomerAccount__c = acc.Id,
            PrimaryContact__c = con.Id
        );
        insert so;

        Account joAcc = new Account(
            Name = 'Joint Owner'
        );
        insert joAcc;

        Business_Process__c bp = new Business_Process__c(
            Sales_Order__c = so.Id
        );
        insert bp;

         List<Business_Process_Documents__c> docs = new List<Business_Process_Documents__c>{
            new Business_Process_Documents__c(Name = 'Default Notice Document 1',Business_Process__c=bp.ID),
            new Business_Process_Documents__c(Name = 'Default Notice Document 2',Business_Process__c=bp.ID),
            new Business_Process_Documents__c(Name = 'Termination Document',Business_Process__c=bp.ID)
        };

        insert docs;

        List<ContentVersion> versions = new List<ContentVersion>();

        for (Business_Process_Documents__c d : docs) {
            versions.add(new ContentVersion(
                Title = d.Name,
                PathOnClient = d.Name + '.pdf',
                VersionData = Blob.valueOf('Test PDF Data'),
                IsMajorVersion = true
            ));
        }

        insert versions;

        List<ContentVersion> insertedVersions = [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id IN :versions
        ];

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        for (Integer i = 0; i < insertedVersions.size(); i++) {
            links.add(new ContentDocumentLink(
                LinkedEntityId = docs[i].Id,
                ContentDocumentId = insertedVersions[i].ContentDocumentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        insert links;
    }

    @IsTest
    static void testDefaultNotice1() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        Test.startTest();

        SendDefaultLetterFromBp.processLetters(
            bp.Id,
            'Default Notice 1'
        );

        Test.stopTest();
    }

    @IsTest
    static void testDefaultNotice2() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        Test.startTest();

        SendDefaultLetterFromBp.processLetters(
            bp.Id,
            'Default Notice 2'
        );

        Test.stopTest();
    }

    @IsTest
    static void testTerminationLetter() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        Test.startTest();

        SendDefaultLetterFromBp.processLetters(
            bp.Id,
            'Termination Letter'
        );

        Test.stopTest();
    }

    @IsTest
    static void testNullId() {

        Test.startTest();

        SendDefaultLetterFromBp.processLetters(
            null,
            'Default Notice 1'
        );

        Test.stopTest();
    }

    @IsTest
    static void testInvalidType() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        Test.startTest();

        SendDefaultLetterFromBp.processLetters(
            bp.Id,
            'Invalid Type'
        );

        Test.stopTest();
    }
}