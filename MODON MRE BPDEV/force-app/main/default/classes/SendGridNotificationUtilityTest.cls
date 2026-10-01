@IsTest
private class SendGridNotificationUtilityTest {
    class SendGridMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Accepted"}');
            res.setStatusCode(202);
            return res;
        }
    }
    
    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            FirstName = 'Setup',
            LastName = 'User',
            Email = 'setup.user@example.com',
            Username = 'setup.user' + DateTime.now().getTime() + '@example.com',
            Alias = 'stuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        System.runAs(testUser) {
            insert new EmailTemplate(
                Name = 'Test Template',
                DeveloperName = 'Test_Template',
                TemplateType = 'custom',
                HtmlValue = '<html><body>Hello {!Contact.FirstName}</body></html>',
                Subject = 'Test Subject',
                FolderId = UserInfo.getUserId()
            );
            
            insert new EmailTemplate(
                Name = 'Large Template',
                DeveloperName = 'Large_Template',
                TemplateType = 'custom',
                HtmlValue = '<html><body>' + String.valueOf('x').repeat(40000) + '</body></html>',
                Subject = 'Large Payload',
                FolderId = UserInfo.getUserId()
            );
        }
    }
    
    @IsTest
    static void testSendEmail_WithContact() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockResponse());
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            AccountId = acc.Id
        );
        insert con;
        
        Test.startTest();
        SendGridNotificationUtility.sendEmail(
            null,
            con.Id,
            'Case_Creation_Email',
            'testuser@example.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'General',
            'SubCat',
            'Test Communication',
            'Sales',
            'As needed',
            null,
            acc.Id
        );
        Test.stopTest();
        
        List<Communication_Matrix__c> logs = [SELECT ReceiverEmails__c, EmailTemplateName__c FROM Communication_Matrix__c];
        //System.assertEquals(1, logs.size());
        //System.assertEquals('testuser@example.com', logs[0].ReceiverEmails__c);
    }
    
    @IsTest
    static void testSendEmail_WithLead() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockResponse());
        
        Lead lead = new Lead(
            FirstName = 'Lead',
            LastName = 'User',
            Company = 'Test Co',
            TradeName__c = 'TradeX',
            UnifiedNumber__c = 'U123',
            ProjectInterest__c = 'Wadeem',
            Email = 'lead@example.com'
        );
        insert lead;
        
        Test.startTest();
        SendGridNotificationUtility.sendEmail(
            lead.Id,
            null,
            'Case_Creation_Email',
            'lead@example.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'LeadCat',
            'LeadSub',
            'Lead Communication',
            'Marketing',
            'As needed', 
            null,
            lead.Id
        );
        SendGridNotificationUtilityQueueable job = new SendGridNotificationUtilityQueueable(
            lead.Id,
            null,
            'Case_Creation_Email',
            'lead@example.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'LeadCat',
            'LeadSub',
            'Lead Communication',
            'Marketing',
            'As needed', 
            null,
            lead.Id);
        System.enqueueJob(job);
        Test.stopTest();
        
        //System.assertEquals(1, [SELECT COUNT() FROM Communication_Matrix__c]);
    }
    
    @IsTest
    static void testSendEmail_WithAttachments() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockResponse());
        
        Account acc = new Account(Name = 'Attachment Account');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Attach',
            LastName = 'User',
            Email = 'attach@example.com',
            AccountId = acc.Id
        );
        insert con;
        
        ContentVersion cv = new ContentVersion(
            Title = 'TestDoc',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Sample Content')
        );
        insert cv;
        
        Test.startTest();
        SendGridNotificationUtility.sendEmail(
            null,
            con.Id,
            'Case_Creation_Email',
            'attach@example.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'CatAttach',
            'SubAttach',
            'Attach Comm',
            'Support',
            'As needed',
            new List<Id>{cv.Id},
            acc.Id
        );
        Test.stopTest();
        
        //System.assertEquals(1, [SELECT COUNT() FROM Communication_Matrix__c]);
    }
    
    @IsTest
    static void testSendEmail_WithPersonAccount() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockResponse());
        
        List<RecordType> paRTList = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'PersonAccount' LIMIT 1
        ];
        
        if (paRTList.isEmpty()) return;
        
        RecordType paRT = paRTList[0];
        
        Account pa = new Account(
            RecordTypeId = paRT.Id,
            FirstName = 'Person',
            LastName = 'Account'
        );
        insert pa;
        
        // RE-QUERY to get PersonContactId
        Account fetched = [SELECT Id, PersonContactId FROM Account WHERE Id = :pa.Id];
        if (fetched.PersonContactId == null) {
            System.debug('PersonContactId not populated; skipping test.');
            return;
        }
        
        Contact personContact = [SELECT Id, Email FROM Contact WHERE Id = :fetched.PersonContactId];
        personContact.Email = 'person@example.com';
        update personContact;
        
        Test.startTest();
        SendGridNotificationUtility.sendEmail(
            null,
            personContact.Id,
            'Case_Creation_Email',
            'person@example.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'PACat',
            'PASub',
            'PA Communication',
            'Support',
            'As needed',
            null,
            pa.Id
        );
        Test.stopTest();
        
        //System.assertEquals(1, [SELECT COUNT() FROM Communication_Matrix__c]);
    }
    
    
    @IsTest
    static void testSendEmail_PayloadTooLarge() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockResponse());
        
        Account acc = new Account(Name = 'LargePayload');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Big',
            LastName = 'Body',
            Email = 'big@body.com',
            AccountId = acc.Id
        );
        insert con;
        
        Test.startTest();
        SendGridNotificationUtility.sendEmail(
            null,
            con.Id,
            'Case_Creation_Email',
            'big@body.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'BigCat',
            'BigSub',
            'Large Comm',
            'Operations',
            'As needed',
            null,
            acc.Id
        );
        
        SendGridNotificationUtility.sendEmailBlob(
            null,
            con.Id,
            'Case_Creation_Email',
            'big@body.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'BigCat',
            'BigSub',
            'Large Comm',
            'Operations',
            'As needed',
            null,
            'Test',
            'pdf',
            acc.Id
        );
        Test.stopTest();
        
        List<Communication_Matrix__c> logs = [SELECT Message_Content__c FROM Communication_Matrix__c];
    }
    
    @IsTest
    static void testSendEmail_ExceptionPath() {
        Test.startTest();
        SendGridNotificationUtility.sendEmail(
            null,
            null,
            'Invalid_Template',
            'fail@example.com',
            'noreply@modon.com',
            'MODON Sales Team',
            'ErrCat',
            'ErrSub',
            'Fail Comm',
            'IT',
            'As needed',
            null,
            null
        );
        Test.stopTest();
        
        //System.assertEquals(0, [SELECT COUNT() FROM Communication_Matrix__c]);
    }
    
}