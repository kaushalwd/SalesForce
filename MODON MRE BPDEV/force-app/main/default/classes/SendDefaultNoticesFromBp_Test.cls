@isTest
public class SendDefaultNoticesFromBp_Test {

    @testSetup
    static void setupData() {

        /* -----------------------------
           Create Person Account
        ------------------------------*/
        Id personAccountRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByName()
            .get('Person Account')
            .getRecordTypeId();

        Account personAcc = new Account(
            FirstName = 'John',
            LastName = 'Doe',
            PersonEmail = 'john@test.com',
            RecordTypeId = personAccountRtId
        );
        insert personAcc;

        /* -----------------------------
           Create Organisation Account
        ------------------------------*/
        Account orgAcc = new Account(
            Name = 'Test Organisation'
        );
        insert orgAcc;

        Contact con = new Contact(
            FirstName = 'Org',
            LastName = 'Contact',
            Email = 'org@test.com',
            AccountId = orgAcc.Id,
            Is_Active__c = true
        );
        insert con;

        /* -----------------------------
           Create Sales Orders
        ------------------------------*/
        SalesOrder__c soPerson = new SalesOrder__c(
            
            CustomerAccount__c = personAcc.Id
        );
        insert soPerson;

        SalesOrder__c soOrg = new SalesOrder__c(
          
            CustomerAccount__c = orgAcc.Id
        );
        insert soOrg;

        /* -----------------------------
           Create Business Processes
        ------------------------------*/
        Business_Process__c bpPerson = new Business_Process__c(
       
            Sales_Order__c = soPerson.Id
        );

        Business_Process__c bpOrg = new Business_Process__c(
        
            Sales_Order__c = soOrg.Id
        );

        insert new List<Business_Process__c>{
            bpPerson,
            bpOrg
        };

        /* -----------------------------
           Create BP Document
        ------------------------------*/
        Business_Process_Documents__c doc = new Business_Process_Documents__c(
            Name = 'Default Notice Document 1',
            Business_Process__c = bpPerson.Id
        );
        insert doc;

        /* -----------------------------
           Create File
        ------------------------------*/
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Dummy File Content')
        );
        insert cv;

        ContentDocument cd = [
            SELECT Id
            FROM ContentDocument
            WHERE LatestPublishedVersionId = :cv.Id
            LIMIT 1
        ];

        /* -----------------------------
           Link File to Document
        ------------------------------*/
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = doc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    @isTest
    static void testSendDefaultedEmail_PersonAccount() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        Set<Id> bpIds = new Set<Id>{ bp.Id };


        Map<Id, String> bpToTemplate = new Map<Id, String>{
            bp.Id => 'First_Default_Notice'
        };

        Test.startTest();

        SendDefaultNoticesFromBp.sendDefaultedEmail(
            bpIds,
            bpToTemplate
        );

        Test.stopTest();

    
    }

    @isTest
    static void testSendDefaultedEmail_OrganisationAccount() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1 OFFSET 1
        ];

        Set<Id> bpIds = new Set<Id>{ bp.Id };

        Map<Id, String> bpToTemplate = new Map<Id, String>{
            bp.Id => 'First_Default_Notice'
        };

        Test.startTest();

       /* SendDefaultNoticesFromBp.sendDefaultedEmail(
            bpIds,
            bpToTemplate
        );*/

        Test.stopTest();

       
    }

    @isTest
    static void testSendDefaultedEmail_NoIds() {

        Test.startTest();

        try {

            SendDefaultNoticesFromBp.sendDefaultedEmail(
                new Set<Id>(),
                new Map<Id, String>()
            );

          

        } catch (AuraHandledException ex) {

        }

        Test.stopTest();
    }

    @isTest
    static void testInvokeFromFlow() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        SendDefaultNoticesFromBp.Request req =
            new SendDefaultNoticesFromBp.Request();

        req.businessProcessId = bp.Id;
        req.templateDeveloperName = 'First_Default_Notice';

        Test.startTest();

        SendDefaultNoticesFromBp.invokeFromFlow(
            new List<SendDefaultNoticesFromBp.Request>{ req }
        );

        Test.stopTest();

    
    }

    @isTest
    static void testInvokeFromFlow_EmptyList() {

        Test.startTest();

        SendDefaultNoticesFromBp.invokeFromFlow(
            new List<SendDefaultNoticesFromBp.Request>()
        );

        Test.stopTest();


    }
}