@IsTest
public class BP_SendGridUtilityClassTest {

    static Integer callCount = 0;
    static String lastPayload;
    static String lastAuthHeader;
    static String lastContentType;
    static String lastEndpoint;

    private static String getAnyConfigLabelOrFail() {
        List<SendGrid_Configuration__mdt> cfgs = [
            SELECT Label, SendGrid_API_KEY__c, SendGrid_API_URL__c
            FROM SendGrid_Configuration__mdt
            LIMIT 1
        ];
        System.assert(!cfgs.isEmpty(), 'No SendGrid_Configuration__mdt found. Create at least one configuration to run tests.');
        System.assert(String.isNotBlank(cfgs[0].Label), 'SendGrid config Label is blank');
        System.assert(String.isNotBlank(cfgs[0].SendGrid_API_KEY__c), 'SendGrid API Key is blank');
        System.assert(String.isNotBlank(cfgs[0].SendGrid_API_URL__c), 'SendGrid API URL is blank');
        return cfgs[0].Label;
    }

    private static List<ContentDocumentLink> createLinksForExtensions(Id parentId) {
        List<ContentVersion> versions = new List<ContentVersion>{
            new ContentVersion(Title='T_pdf',  PathOnClient='T.pdf',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_doc',  PathOnClient='T.doc',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_docx', PathOnClient='T.docx', VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_xls',  PathOnClient='T.xls',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_xlsx', PathOnClient='T.xlsx', VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_ppt',  PathOnClient='T.ppt',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_pptx', PathOnClient='T.pptx', VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_jpg',  PathOnClient='T.jpg',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_png',  PathOnClient='T.png',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_gif',  PathOnClient='T.gif',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_txt',  PathOnClient='T.txt',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_csv',  PathOnClient='T.csv',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_unk',  PathOnClient='T.abc',  VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId),
            new ContentVersion(Title='T_noext',PathOnClient='T',      VersionData=Blob.valueOf('x'), FirstPublishLocationId=parentId)
        };
        insert versions;

        List<ContentVersion> inserted = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versions
        ];

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : inserted) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = parentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        links.add(null);
        return links;
    }

    @IsTest
    static void test_100Percent_AllBranches_SuccessAndMimeTypes() {
        callCount = 0; lastPayload = null; lastAuthHeader = null; lastContentType = null; lastEndpoint = null;
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        String cfgLabel = getAnyConfigLabelOrFail();
        String personalizationsJson = '[{"to":[{"email":"test@test.com"}]}]';
        Id parentId = UserInfo.getUserId();

        List<ContentDocumentLink> links = createLinksForExtensions(parentId);

        Test.startTest();

        BP_SendGridUtilityClass.getSendGridMap();

        BP_SendGridUtilityClass.sendEmail(personalizationsJson, cfgLabel, 'Sub Sync', '<b>Body</b>', false);
        BP_SendGridUtilityClass.sendEmail(personalizationsJson, cfgLabel, 'Sub Async', '<b>Body</b>', true);

        BP_SendGridUtilityClass.sendToSendGridSync(personalizationsJson, cfgLabel, 'Direct Sync', 'Body');
        BP_SendGridUtilityClass.sendToSendGridAsync(personalizationsJson, cfgLabel, 'Direct Async', 'Body');

        BP_SendGridUtilityClass.sendEmail(personalizationsJson, '___NOT_FOUND___', 'Missing Config', 'Body', false);

        BP_SendGridUtilityClass.sendEmailWithAttachments(personalizationsJson, cfgLabel, 'noreply@modon.com', 'HTML + Attach', '<p>Hi</p>', true, links);
        BP_SendGridUtilityClass.sendEmailWithAttachments(personalizationsJson, cfgLabel, 'noreply@modon.com', 'Plain + Attach', 'Hi', false, links);
        BP_SendGridUtilityClass.sendEmailWithAttachments(personalizationsJson, '___NOT_FOUND___', 'noreply@modon.com', 'Missing Config Attach', 'Hi', true, links);
        BP_SendGridUtilityClass.sendEmailWithAttachments(personalizationsJson, cfgLabel, 'noreply@modon.com', 'No Attach', 'Hi', true, null);

        Test.stopTest();

        System.assert(callCount >= 6, 'Expected multiple callouts across sync/async + attachments');
        System.assertNotEquals(null, lastPayload);
        System.assert(lastPayload.contains('"personalizations"'), 'Payload should contain personalizations');
        System.assertNotEquals(null, lastAuthHeader);
        System.assertEquals(true, lastAuthHeader.startsWith('Bearer '));
        System.assertEquals('application/json', lastContentType);
        System.assertNotEquals(null, lastEndpoint);

        Map<String, Object> obj = (Map<String, Object>)JSON.deserializeUntyped(lastPayload);
        System.assert(obj.containsKey('from'));
        System.assert(obj.containsKey('content'));
        if (obj.containsKey('attachments')) {
            List<Object> atts = (List<Object>)obj.get('attachments');
            System.assert(atts.size() > 0);
        }
    }

    @IsTest
    static void test_CalloutException_IsCaught_InSendEmail_SyncAndAsync() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        String cfgLabel = getAnyConfigLabelOrFail();
        String personalizationsJson = '[{"to":[{"email":"boom@test.com"}]}]';

        Test.startTest();
        BP_SendGridUtilityClass.sendEmail(personalizationsJson, cfgLabel, 'Throw Sync', 'Body', false);
        BP_SendGridUtilityClass.sendEmail(personalizationsJson, cfgLabel, 'Throw Async', 'Body', true);
        BP_SendGridUtilityClass.sendToSendGridSync(personalizationsJson, cfgLabel, 'Throw Direct Sync', 'Body');
        BP_SendGridUtilityClass.sendToSendGridAsync(personalizationsJson, cfgLabel, 'Throw Direct Async', 'Body');
        Test.stopTest();

        System.assert(true, 'No exception should escape sendEmail/sendToSendGrid* because callSendGrid catches it');
    }

    @IsTest
    static void test_SendEmailWithAttachments_Rethrows_OnCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        String cfgLabel = getAnyConfigLabelOrFail();
        String personalizationsJson = '[{"to":[{"email":"throwattach@test.com"}]}]';
        Id parentId = UserInfo.getUserId();

        List<ContentDocumentLink> links = createLinksForExtensions(parentId);

        Boolean threw = false;

        Test.startTest();
        try {
            BP_SendGridUtilityClass.sendEmailWithAttachments(personalizationsJson, cfgLabel, 'noreply@modon.com', 'Throw Attach', 'Body', true, links);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'sendEmailWithAttachments should rethrow when callout fails');
    }

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            BP_SendGridUtilityClassTest.callCount++;
            BP_SendGridUtilityClassTest.lastPayload = req.getBody();
            BP_SendGridUtilityClassTest.lastAuthHeader = req.getHeader('Authorization');
            BP_SendGridUtilityClassTest.lastContentType = req.getHeader('Content-Type');
            BP_SendGridUtilityClassTest.lastEndpoint = req.getEndpoint();

            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"accepted"}');
            return res;
        }
    }

    private class ThrowingMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated SendGrid failure');
        }
    }
}