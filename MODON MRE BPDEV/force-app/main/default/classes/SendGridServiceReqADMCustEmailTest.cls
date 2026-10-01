@isTest
public class SendGridServiceReqADMCustEmailTest {
    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message":"accepted"}');
            return res;
        }
    }
    
    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User assignUser = new User(
            Username = 'assignuser' + DateTime.now().getTime() + '@test.com',
            LastName = 'Assign',
            Email = 'assignuser@test.com',
            Alias = 'assign',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        User testUser = new User(
            Username = 'testuser' + DateTime.now().getTime() + '@test.com',
            LastName = 'Test',
            Email = 'testuser@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert new List<User>{assignUser, testUser};
            
            Folder emailFolder = [SELECT Id FROM Folder WHERE Type = 'Email' LIMIT 1];
        List<EmailTemplate> templates = new List<EmailTemplate>{
            createEmailTemplate(ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED, 'ADM_REG_COMPLETED', emailFolder.Id),
                createEmailTemplate(ServiceConstants.CEMAIL_SR_CREATED, 'SR_CREATED', emailFolder.Id),
                createEmailTemplate(ServiceConstants.CEMAIL_SR_JO_ACKNOWLEDGE, 'SR_JO_ACKNOWLEDGE', emailFolder.Id),
                createEmailTemplate(ServiceConstants.CEMAIL_SR_JO_COMPLETED, 'SR_JO_COMPLETED', emailFolder.Id),
                createEmailTemplate(ServiceConstants.CEMAIL_SR_JO_REJECTED, 'SR_JO_REJECTED', emailFolder.Id),
                createEmailTemplate(ServiceConstants.CEMAIL_SR_COMPLETED, 'SR_COMPLETED', emailFolder.Id),
                createEmailTemplate(ServiceConstants.CEMAIL_SR_SR_REJECTED, 'SR_SR_REJECTED', emailFolder.Id)
                };
                    insert templates;
        
        // 2. Non-setup objects in runAs block
        System.runAs(testUser) {
            BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
            AssignmentRule__c asr = new AssignmentRule__c(
                //Name = 'Test ADM Sales Rule',
                IsActive__c = true,
                RecordType__c = 'Service Request', // Set the controlling field
                ProcessName__c = 'ADM',            // Set the dependent value
                ProcessType__c = 'Sales'
            );
            insert asr;
            
            AssignmentUser__c au = new AssignmentUser__c(
                User__c = assignUser.Id,
                AssignmentRule__c = asr.Id,
                IsActive__c = true,
                BusinessHours__c = bh.Id,
                MondayStartTime__c = Time.newInstance(0,0,0,0),
                MondayEndTime__c = Time.newInstance(23,59,59,999),
                TuesdayStartTime__c = Time.newInstance(0,0,0,0),
                TuesdayEndTime__c = Time.newInstance(23,59,59,999),
                WednesdayStartTime__c = Time.newInstance(0,0,0,0),
                WednesdayEndTime__c = Time.newInstance(23,59,59,999),
                ThursdayStartTime__c = Time.newInstance(0,0,0,0),
                ThursdayEndTime__c = Time.newInstance(23,59,59,999),
                FridayStartTime__c = Time.newInstance(0,0,0,0),
                FridayEndTime__c = Time.newInstance(23,59,59,999),
                SaturdayStartTime__c = Time.newInstance(0,0,0,0),
                SaturdayEndTime__c = Time.newInstance(23,59,59,999),
                SundayStartTime__c = Time.newInstance(0,0,0,0),
                SundayEndTime__c = Time.newInstance(23,59,59,999)
            );
            insert au;
            
            Account personAcc = new Account(
                FirstName = 'Testing',
                LastName = 'Test Person',
                PersonEmail = 'person@test.com',
                RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
            );
            insert personAcc;
            
            SalesOrder__c so = new SalesOrder__c(
                CustomerAccount__c = personAcc.Id,
                status__c = 'sold'
            );
            insert so;
            
            ServiceRequest__c sr = new ServiceRequest__c(
                SurveyLink__c = 'http://survey.link',
                SalesOrder__c = so.Id
            );
            insert sr;
            
            Documents__c doc = new Documents__c(
                Name = 'ADM Registration Document',
                Service_Request__c = sr.Id
            );
            insert doc;
            
            ContentVersion cv = new ContentVersion(
                Title = 'TestDoc',
                PathOnClient = 'TestDoc.pdf',
                VersionData = Blob.valueOf('Test Data'),
                IsMajorVersion = true
            );
            insert cv;
            
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                LinkedEntityId = doc.Id,
                ContentDocumentId = contentDocumentId,
                ShareType = 'V'
            );
            insert cdl;
        }
    }
    
    private static EmailTemplate createEmailTemplate(String name, String devName, Id folderId) {
        return new EmailTemplate(
            Name = name,
            DeveloperName = devName,
            TemplateType = 'custom',
            Subject = 'Test Subject',
            HtmlValue = 'Hello {SurveyLink__c}',
            IsActive = true,
            FolderId = folderId,
            UiType = 'Aloha'
        );
    }
    
    @isTest
    static void testSendEmailToCustomer() {
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        set<Id> srIdSet = new set<Id>();
        srIdSet.add(sr.Id);
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Test.startTest();
        SendGridServiceRequestADMCustomerEmail.sendEmailToCustomer(
            srIdSet, 
            ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED
        );
        Test.stopTest();
    }
    
    @isTest
    static void testExecuteEmailSending() {
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        List<Id> srIdList = new List<Id>();
        srIdList.add(sr.Id);
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Test.startTest();
        SendGridServiceRequestADMCustomerEmail.executeEmailSending(
            srIdList, 
            ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED,
            'http://test.survey.link'
        );
        Test.stopTest();
    }
    
    @isTest
    static void testSendToSendGrid() {
        SendGrid_Configuration__mdt config = [
            SELECT Id, Label, DeveloperName, Banner_Name__c, 
            Content_Ids__c, SendGrid_API_KEY__c, SendGrid_API_URL__c 
            FROM SendGrid_Configuration__mdt 
            WHERE DeveloperName = 'Service_Request_Management' 
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Test.startTest();
        SendGridServiceRequestADMCustomerEmail.sendToSendGrid(
            '[{"to":[{"email":"test@example.com"}]}]',
            config,
            'Test Subject',
            'Test Body',
            EncodingUtil.base64Encode(Blob.valueOf('Test Content'))
        );
        Test.stopTest();
    }
}