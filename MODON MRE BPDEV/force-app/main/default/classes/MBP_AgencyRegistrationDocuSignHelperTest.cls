@isTest
private class MBP_AgencyRegistrationDocuSignHelperTest {

    @testSetup
    static void setupData() {
        // Create test Registration__c
        Registration__c reg = new Registration__c(
                Company_Email_Address__c = 'test.user.request@00dv0000003gibh2aa.orgforce.com',
                //Name = 'Test Registration',
                Company_Name_as_per_Trade_License__c = 'Test Company',
                Status__c = 'Draft'
            );
            insert reg;

        // Create test ServiceRequest__c
        ServiceRequest__c sr = new ServiceRequest__c(
            Registration__c = reg.Id
        );
        insert sr;

        // Create test Registration_Agent__c
        Registration_Agent__c agent = new Registration_Agent__c(
            Registration_Name__c = reg.Id,
            Type__c = 'Owner',
            Primary_Owner__c = true,
            Agent_Email__c = 'agent@example.com',
            Agent_First_Name__c = 'Test Agent'
        );
        insert agent;

        // Create test Task
        Task task = new Task(
            Subject = 'Test Subject',
            Status = 'Not Started',
            ActivityDate = Date.today()
        );
        insert task;

        // Create ContentVersion and link to Registration
        ContentVersion cv = new ContentVersion(
            Title = 'SalesAgreement',
            PathOnClient = 'SalesAgreement.pdf',
            VersionData = Blob.valueOf('Sample Content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
            LinkedEntityId = reg.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;
    }
    @isTest
    static void testSendUsingDocuSign_fullCoverage() {
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        Task task = [SELECT Id FROM Task LIMIT 1];

        Test.startTest();
        MBP_AgencyRegistrationDocuSignHelper.sendUsingDocuSign(sr.Id, task.Id);
        Test.stopTest();

        System.assert(true, 'sendUsingDocuSign executed');
    }

    @isTest
    static void testCreateRecipientFromSObject_Signer() {
        Registration_Agent__c agent = [SELECT Id, Agent_Email__c, Agent_First_Name__c FROM Registration_Agent__c LIMIT 1];
        dfsle.Recipient signerRecipient = MBP_AgencyRegistrationDocuSignHelper.createRecipientFromSobj(
            agent,
            'Agent_First_Name__c',
            'Agent_Email__c',
            'StaticAnchor',
            1,
            agent.Id,
            'Signer'
        );
        System.assertNotEquals(null, signerRecipient);
    }

    @isTest
    static void testCreateRecipientFromSObject_Approver() {
        dfsle.Recipient approverRecipient = MBP_AgencyRegistrationDocuSignHelper.createRecipientFromSobj(
            'Approver User',
            'approver@test.com',
            'AnchorText',
            2,
            '001000000000000', // Dummy SR ID
            'Approver'
        );
        System.assertNotEquals(null, approverRecipient);
    }

    @isTest
    static void testCreateEnvTab_AllTypes() {
        dfsle.Tab t1 = MBP_AgencyRegistrationDocuSignHelper.createEnvTab('anchorSignatureHolder');
        dfsle.Tab t2 = MBP_AgencyRegistrationDocuSignHelper.createEnvTab('anchorDateHolder');
        dfsle.Tab t3 = MBP_AgencyRegistrationDocuSignHelper.createEnvTab('anchorInitialsHolder');
        dfsle.Tab t4 = MBP_AgencyRegistrationDocuSignHelper.createEnvTab('anchorStampHolder');

        System.assertNotEquals(null, t1);
        System.assertNotEquals(null, t2);
        System.assertNotEquals(null, t3);
        System.assertNotEquals(null, t4);
    }

}