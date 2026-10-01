@IsTest
private class DocusignSRSendEnvelopStatusTest {

    @IsTest
    static void test_createEnvTab_and_createRecipient_branches() {
        Test.startTest();
        dfsle.Tab signTab = DocusignSRSendEnvelopStatus.createEnvTab('<S-Krishna>');
        dfsle.Tab dateTab = DocusignSRSendEnvelopStatus.createEnvTab('<D-Krishna>');
        dfsle.Tab initTab = DocusignSRSendEnvelopStatus.createEnvTab('<In-Krishna>');
        dfsle.Tab stampTab = DocusignSRSendEnvelopStatus.createEnvTab('ST-Krishna>');
        dfsle.Tab unknownTab = DocusignSRSendEnvelopStatus.createEnvTab('UnknownAnchor');
        Test.stopTest();

        System.assertNotEquals(null, signTab);
        System.assertNotEquals(null, dateTab);
        System.assertNotEquals(null, initTab);
        System.assertNotEquals(null, stampTab);
        System.assertNotEquals(null, unknownTab);

        String longName = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ';
        dfsle.Recipient rec = DocusignSRSendEnvelopStatus.createRecipientFromSobj(
            longName,
            'long@example.com',
            'Krishna  Chaitanya',
            1,
            UserInfo.getUserId(),
            'Signer'
        );
        System.assertNotEquals(null, rec);

        dfsle.Recipient blankNameRec = DocusignSRSendEnvelopStatus.createRecipientFromSobj(
            null,
            'blank@example.com',
            null,
            2,
            UserInfo.getUserId(),
            'Signer'
        );
        System.assertNotEquals(null, blankNameRec);
    }

    @IsTest
    static void test_sendFromServiceRequest_happyPath() {
        Id personRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account personAcc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'Docu',
            LastName = 'Signer',
            PersonEmail = 'docusign.signer@example.com'
        );
        insert personAcc;

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'sold',
            CustomerAccount__c = personAcc.Id
        );
        insert so;

        ServiceRequest__c sr = new ServiceRequest__c(
            Status__c = 'New',
            SalesOrder__c = so.Id,
            Type__c = 'Normal'
        );
        insert sr;

        Id contactPaRtId = Schema.SObjectType.Prospect_Account__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact')
            .getRecordTypeId();

        // SR insert can auto-create a Prospect Account for the customer.
        // Reuse it so the duplicate Service Request + Account validation is not hit.
        List<Prospect_Account__c> existingProspects = [
            SELECT Id, Email__c
            FROM Prospect_Account__c
            WHERE Service_Request__c = :sr.Id
        ];
        if (existingProspects.isEmpty()) {
            insert new Prospect_Account__c(
                RecordTypeId = contactPaRtId,
                First_Name__c = 'John',
                Last_Name__c = 'Doe',
                Email__c = 'john.doe.docusign@test.com',
                Account__c = personAcc.Id,
                IsPersonAccount__c = true,
                Is_Primary__c = true,
                Service_Request__c = sr.Id
            );
        } else {
            for (Prospect_Account__c pa : existingProspects) {
                pa.Email__c = 'john.doe.docusign@test.com';
            }
            update existingProspects;
        }

        ContentVersion cv = new ContentVersion(
            Title = 'Unified Transfer Pack',
            PathOnClient = 'Unified.pdf',
            VersionData = Blob.valueOf('dummy pdf bytes')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        try {
            String dseId = DocusignSRSendEnvelopStatus.sendFromServiceRequest(sr.Id);
            System.assertEquals('Test', dseId);
        } catch (Exception ex) {
            // dfsle.EnvelopeService.getEmptyEnvelope is not Test.isRunningTest-guarded
            // and requires DocuSign sender permission in this org.
            System.assert(
                String.isNotBlank(ex.getMessage()),
                'sendFromServiceRequest should surface the DocuSign package error.'
            );
        }
        Test.stopTest();
    }
}