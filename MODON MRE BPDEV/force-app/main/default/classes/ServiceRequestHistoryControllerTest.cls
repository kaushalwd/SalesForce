@IsTest
public class ServiceRequestHistoryControllerTest {

    private static final String TEST_EMAIL = 'sr.history.test@test.com';

    @TestSetup
    static void setupData() {
        Id personAccountRtId = getAccountRecordTypeId('PersonAccount');

        Account acc = new Account(
            RecordTypeId = personAccountRtId,
            FirstName = 'SR',
            LastName = 'Customer',
            PersonEmail = TEST_EMAIL
        );

        insert acc;


        ServiceRequest__c srNew1 = createServiceRequest(acc.Id, 'New');
        ServiceRequest__c srNew2 = createServiceRequest(acc.Id, 'New');
        ServiceRequest__c srInProgress1 = createServiceRequest(acc.Id, 'In-progress');
        ServiceRequest__c srInProgress2 = createServiceRequest(acc.Id, 'In-progress');

        insert new List<ServiceRequest__c>{
            srNew1,
            srNew2,
            srInProgress1,
            srInProgress2
        };

        CaseSLA__c breachedSla = new CaseSLA__c(
            Service_Request__c = srNew1.Id,
            Status__c = 'Breached'
        );

        insert breachedSla;
    }

    private static Id getAccountRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        System.assert(
            rtMap.containsKey(developerName),
            'Missing Account Record Type: ' + developerName
        );

        return rtMap.get(developerName).getRecordTypeId();
    }

    private static Account getTestAccount() {
        return [
            SELECT Id, PersonEmail, RecordType.DeveloperName
            FROM Account
            WHERE PersonEmail = :TEST_EMAIL
            LIMIT 1
        ];
    }

    private static ServiceRequest__c createServiceRequest(Id accountId, String statusValue) {
        ServiceRequest__c sr = new ServiceRequest__c(
            AccountId__c = accountId,
            Status__c = statusValue
        );


        return sr;
    }

    @IsTest
    static void testGetServiceRequestDataWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, String> result =
            ServiceRequestHistoryController.getServiceRequestData(
                acc.Id,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            '4',
            result.get('Total SR'),
            'Total SR count should be 4.'
        );

        System.assertEquals(
            '4',
            result.get('Open SR'),
            'Open SR count should be 4.'
        );

        System.assertEquals(
            '0',
            result.get('Closed SR'),
            'Closed SR count should be 0 because closed/cancelled SRs are avoided in test setup.'
        );

        System.assertEquals(
            '1',
            result.get('SR Breached Cases'),
            'Breached SR count should be 1.'
        );

        System.assert(
            result.containsKey('Total SRs Tooltip'),
            'Tooltip data should be present when SRs exist.'
        );
    }

    @IsTest
    static void testGetServiceRequestDataWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, String> result =
            ServiceRequestHistoryController.getServiceRequestData(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            '4',
            result.get('Total SR'),
            'Total SR count should match date range.'
        );

        System.assertEquals(
            '4',
            result.get('Open SR'),
            'Open SR count should match date range.'
        );

        System.assertEquals(
            '0',
            result.get('Closed SR'),
            'Closed SR count should be 0.'
        );

        System.assertEquals(
            '1',
            result.get('SR Breached Cases'),
            'Breached SR count should match date range.'
        );
    }

    @IsTest
    static void testGetServiceRequestDataWithFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, String> result =
            ServiceRequestHistoryController.getServiceRequestData(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            '0',
            result.get('Total SR'),
            'Future date range should return zero total SRs.'
        );

        System.assertEquals(
            '0',
            result.get('Open SR'),
            'Future date range should return zero open SRs.'
        );

        System.assertEquals(
            '0',
            result.get('Closed SR'),
            'Future date range should return zero closed SRs.'
        );

        System.assertEquals(
            '0',
            result.get('SR Breached Cases'),
            'Future date range should return zero breached SRs.'
        );

        System.assertEquals(
            false,
            result.containsKey('Total SRs Tooltip'),
            'Tooltip should not be present when there are no SRs.'
        );
    }

    @IsTest
    static void testGetServiceRequestListAll() {
        Account acc = getTestAccount();

        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                acc.Id,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            4,
            result.size(),
            'All SR list should return 4 records.'
        );
    }

    @IsTest
    static void testGetServiceRequestListOpen() {
        Account acc = getTestAccount();

        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                acc.Id,
                null,
                null,
                'open'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            4,
            result.size(),
            'Open filter should return New and In-progress SRs.'
        );

        for (ServiceRequest__c sr : result) {
            System.assert(
                sr.Status__c == 'New' || sr.Status__c == 'In-progress',
                'Only open statuses should be returned.'
            );
        }
    }

    @IsTest
    static void testGetServiceRequestListClosed() {
        Account acc = getTestAccount();

        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                acc.Id,
                null,
                null,
                'closed'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            0,
            result.size(),
            'Closed filter should return no records because test data avoids closed/cancelled status trigger side effects.'
        );
    }

    @IsTest
    static void testGetServiceRequestListBreached() {
        Account acc = getTestAccount();

        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                acc.Id,
                null,
                null,
                'breached'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            1,
            result.size(),
            'Breached filter should return SRs linked to breached CaseSLA__c.'
        );
    }

    @IsTest
    static void testGetServiceRequestListWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                'open'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            4,
            result.size(),
            'Open SRs should be returned within date range.'
        );
    }

    @IsTest
    static void testGetServiceRequestListFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20),
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            0,
            result.size(),
            'Future date range should return no SR records.'
        );
    }

    @IsTest
    static void testGetServiceRequestListWithNullRecordId() {
        Test.startTest();
        List<ServiceRequest__c> result =
            ServiceRequestHistoryController.getServiceRequestList(
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            0,
            result.size(),
            'Null recordId should return empty list.'
        );
    }
}