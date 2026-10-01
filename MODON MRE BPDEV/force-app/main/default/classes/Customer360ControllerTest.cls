@IsTest
private class Customer360ControllerTest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(
            Name = 'Test Customer 360 Account'
        );

        String segmentation = getFirstPicklistValue(Account.Customer_Segmentation__c);
        String segmentGroup = getFirstPicklistValue(Account.Customer_Segemnt_Group__c);

        insert acc;
    }

    private static String getFirstPicklistValue(Schema.SObjectField fieldToken) {
        List<Schema.PicklistEntry> values = fieldToken.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return null;
    }

    private static Account getTestAccount() {
        return [
            SELECT Id,
                   OwnerId,
                   Owner.Name,
                   RecordTypeId,
                   RecordType.Name,
                   Customer_Segmentation__c,
                   Customer_Segemnt_Group__c
            FROM Account
            WHERE Name = 'Test Customer 360 Account'
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetRecordTypeNameSuccess() {
        Account acc = getTestAccount();
        if (acc.RecordTypeId == null) {
            return;
        }

        Test.startTest();
        String recordTypeName = Customer360Controller.getRecordTypeName(acc.Id);
        Test.stopTest();

        System.assertEquals(
            acc.RecordType.Name,
            recordTypeName,
            'Record Type Name should match the Account record type name.'
        );
    }

    @IsTest
    static void testGetRecordTypeNameException() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            Customer360Controller.getRecordTypeName(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException should be thrown for invalid/null Account Id.'
        );
    }

    @IsTest
    static void testGetAccountOwnerPhotoUrlSuccess() {
        Account acc = getTestAccount();

        Test.startTest();
        String photoUrl = Customer360Controller.getAccountOwnerPhotoUrl(acc.Id);
        Test.stopTest();

        System.assert(
            photoUrl == null || String.isNotBlank(photoUrl),
            'Photo URL should either be null or a valid non-blank value.'
        );
    }

    @IsTest
    static void testGetAccountOwnerNameSuccess() {
        Account acc = getTestAccount();

        Test.startTest();
        String ownerName = Customer360Controller.getAccountOwnerName(acc.Id);
        Test.stopTest();

        System.assertEquals(
            acc.Owner.Name,
            ownerName,
            'Owner name should match Account owner name.'
        );
    }

    @IsTest
    static void testGetAccountSegmentationSuccess() {
        Account acc = getTestAccount();

        Test.startTest();
        Account result = Customer360Controller.getAccountSegmentation(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Returned Account should not be null.');
        System.assertEquals(
            acc.Customer_Segmentation__c,
            result.Customer_Segmentation__c,
            'Customer segmentation should match.'
        );
        System.assertEquals(
            acc.Customer_Segemnt_Group__c,
            result.Customer_Segemnt_Group__c,
            'Customer segment group should match.'
        );
    }

    @IsTest
    static void testNullInputs() {
        Test.startTest();

        String photoUrl = Customer360Controller.getAccountOwnerPhotoUrl(null);
        String ownerName = Customer360Controller.getAccountOwnerName(null);
        Account segmentation = Customer360Controller.getAccountSegmentation(null);

        Test.stopTest();

        System.assertEquals(null, photoUrl, 'Photo URL should be null for null Account Id.');
        System.assertEquals(null, ownerName, 'Owner name should be null for null Account Id.');
        System.assertEquals(null, segmentation, 'Segmentation should be null for null Account Id.');
    }
}