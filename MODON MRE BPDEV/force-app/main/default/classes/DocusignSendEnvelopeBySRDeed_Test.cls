@IsTest(SeeAllData=true)
private class DocusignSendEnvelopeBySRDeed_Test {

    private static String pickFirstPicklistValue(Schema.SObjectField f) {
        List<Schema.PicklistEntry> vals = f.getDescribe().getPicklistValues();
        if (vals != null && !vals.isEmpty()) return vals[0].getValue();
        return null;
    }

    private static Id getAnyRecordTypeId(Schema.SObjectType sobType, String preferredName) {
        Map<String, Schema.RecordTypeInfo> byName = sobType.getDescribe().getRecordTypeInfosByName();
        if (byName != null && byName.containsKey(preferredName)) return byName.get(preferredName).getRecordTypeId();
        for (Schema.RecordTypeInfo rti : sobType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable()) return rti.getRecordTypeId();
        }
        return null;
    }

    private static Id getAnyRecordTypeIdByDevName(Schema.SObjectType sobType, String preferredDevName) {
        Map<String, Schema.RecordTypeInfo> byDev = sobType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (byDev != null && byDev.containsKey(preferredDevName)) return byDev.get(preferredDevName).getRecordTypeId();
        for (Schema.RecordTypeInfo rti : sobType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable()) return rti.getRecordTypeId();
        }
        return null;
    }

    private static User getDocuSignUserIfAny() {
        List<User> u = [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND Id IN (
                  SELECT AssigneeId
                  FROM PermissionSetAssignment
                  WHERE PermissionSet.Name LIKE '%DocuSign%'
                     OR PermissionSet.Label LIKE '%DocuSign%'
              )
            LIMIT 1
        ];
        if (!u.isEmpty()) return u[0];
        return [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    }

    private static ServiceRequest__c buildCommonData(Boolean personAccountPath, Boolean primaryContactPath) {

        Account acc;
        if (personAccountPath) {
            acc = new Account(
                RecordTypeId = getAnyRecordTypeId(Account.SObjectType, 'PersonAccount'),
                Name = 'Person Acc'
            );
        } else {
            acc = new Account(Name = 'Biz Account');
        }
        insert acc;

        Contact con;
        if (primaryContactPath) {
            con = new Contact(
                LastName = 'Primary Contact',
                AccountId = acc.Id,
                Email = 'primary@test.com'
            );
            insert con;
        }

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = pickFirstPicklistValue(Opportunity.StageName),
            CloseDate = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id,
            CustomerAccount__c = acc.Id,
            Status__c = pickFirstPicklistValue(SalesOrder__c.Status__c),
            PrimaryContact__c = primaryContactPath ? con.Id : null
        );
        insert so;

        Id srRt = getAnyRecordTypeId(ServiceRequest__c.SObjectType, 'Property Transfer OffPlan');

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = srRt,
            Type__c = 'Next of Kin',
            Seller_Validator_Email__c = 'seller@test.com',
            Seller_Validation_Name__c = 'Seller User',
            Buyer_Validator_Email__c = 'buyer@test.com',
            Buyer_Validator_Name__c = 'Buyer User'
        );
        insert sr;

        Id paRt = getAnyRecordTypeIdByDevName(Prospect_Account__c.SObjectType, 'Account');
        Prospect_Account__c prospect = new Prospect_Account__c(
            RecordTypeId = paRt,
            Account__c = acc.Id,
            Account_Name__c = 'Test Prospect',
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            OwnershipPercentage__c = 100,
            Is_Primary__c = true,
            Service_Request__c = sr.Id,
            Email__c = 'prospect@test.com'
        );
        insert prospect;

        Documents__c doc = new Documents__c(
            Name = 'Deed of Adherence Document',
            Service_Request__c = sr.Id
        );
        insert doc;

        ContentVersion cv = new ContentVersion(
            Title = 'Deed of Adherence',
            PathOnClient = 'Deed.pdf',
            VersionData = Blob.valueOf('Test File Body'),
            IsMajorVersion = true
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = doc.Id,
            ShareType = 'V'
        );

        return sr;
    }

    @IsTest
    static void testPersonAccountBranch_andCoverHelpers() {

        User runAsUser = getDocuSignUserIfAny();

        System.runAs(runAsUser) {

            ServiceRequest__c sr = buildCommonData(true, false);

            DocusignSendEnvelopeBySRDeed.createRecipientFromSobj(
                'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJK',
                'a@test.com',
                '  John   Doe  ',
                1,
                String.valueOf(sr.Id),
                'Signer'
            );

            DocusignSendEnvelopeBySRDeed.createEnvTab('<S-John Doe>');
            DocusignSendEnvelopeBySRDeed.createEnvTab('<D-John Doe>');
            DocusignSendEnvelopeBySRDeed.createEnvTab('<In-John Doe>');
            DocusignSendEnvelopeBySRDeed.createEnvTab('<ST-John Doe>');
            DocusignSendEnvelopeBySRDeed.createEnvTab('anything');

            Test.startTest();
            DocusignSendEnvelopeBySRDeed.sendFromServiceRequest(sr.Id);
            Test.stopTest();
        }
    }

    @IsTest
    static void testPrimaryContactBranch() {

        User runAsUser = getDocuSignUserIfAny();

        System.runAs(runAsUser) {

            ServiceRequest__c sr = buildCommonData(false, true);

            Test.startTest();
            DocusignSendEnvelopeBySRDeed.sendFromServiceRequest(sr.Id);
            Test.stopTest();
        }
    }
}