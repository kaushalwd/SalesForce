/**********************************************************************************************************************
* Name               : ModonEgypt_SakneenReadAPITest
* Description        : Test class for ModonEgypt_SakneenReadAPI. Covers request validation, field selection,
*                      source-entity filters, date filters, sorting/limits, and cursor pagination.
**********************************************************************************************************************/
@IsTest
public class ModonEgypt_SakneenReadAPITest {

    @TestSetup
    static void setupTestData() {
        Project__c project = new Project__c(
            Name = 'Sakneen Test Project',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit A-101',
            PlotNo__c = 'P001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 500000,
            Status__c = 'Available',
            GrossFloorAreaGFA__c = 250
        );
        insert egyptUnit;

        Unit__c egyptUnit2 = new Unit__c(
            Name = 'Egypt Unit A-102',
            PlotNo__c = 'P002',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 350000
        );
        insert egyptUnit2;

        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit B-101',
            PlotNo__c = 'P003',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4',
            Source_Entity__c = 'Modon - UAE'
        );
        insert uaeUnit;

        Account egyptAccount = new Account(
            Name = 'Sakneen Egypt Account',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert egyptAccount;

        insert new PaymentPlan__c(
            Name = 'Sakneen Plan 1',
            Phase__c = phase.Id,
            StartDate__c = Date.today(),
            ExpiryDate__c = Date.today().addMonths(6),
            Status__c = 'Active',
            Type__c = 'Standard'
        );
        insert new PaymentPlan__c(
            Name = 'Sakneen Plan 2',
            Phase__c = phase.Id,
            StartDate__c = Date.today().addDays(1),
            ExpiryDate__c = Date.today().addMonths(6),
            Status__c = 'Active',
            Type__c = 'Standard'
        );
    }

    private static Map<String, Object> executeAPI(String body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/SakneenReadAPI';
        req.httpMethod = 'POST';
        req.requestBody = body == null ? null : Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = res;
        ModonEgypt_SakneenReadAPI.getRecords();
        System.assertNotEquals(null, RestContext.response.responseBody, 'Expected a response body');
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    private static String unitPayload(Map<String, Object> extra) {
        Map<String, Object> payload = new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' }
        };
        if (extra != null) {
            payload.putAll(extra);
        }
        return JSON.serialize(payload);
    }

    private static String responseMsg(Map<String, Object> response) {
        return 'API response: ' + JSON.serialize(response);
    }

    @IsTest
    static void testFetchUnitWithCustomFields() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{
                'Id', 'Name', 'UnitClassification__c', 'Phase__c'
            }
        }));
        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(2, response.get('count'));
    }

    @IsTest
    static void testSourceEntityRestrictionForUnit() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Name', 'Source_Entity__c' }
        }));
        Test.stopTest();

        List<Object> records = (List<Object>) response.get('records');
        System.assertEquals(2, records.size());
        for (Object record : records) {
            Map<String, Object> data = (Map<String, Object>) record;
            System.assertEquals('Modon - Egypt', data.get('Source_Entity__c'));
        }
    }

    @IsTest
    static void testFetchUnitByIds() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'Egypt Unit A-101' LIMIT 1];

        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>{ '', unit.Id },
            'fields' => new List<String>{ 'Id', 'Name' }
        }));
        Test.stopTest();

        System.assertEquals(1, response.get('count'));
    }

    @IsTest
    static void testLookupRelationshipFields() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Phase__c' },
            'extraFields' => new List<String>{ 'Owner.Email' }
        }));
        Test.stopTest();

        System.assertEquals(true, response.get('success'), responseMsg(response));
        List<Object> records = (List<Object>) response.get('records');
        System.assertNotEquals(null, records);
        System.assert(!records.isEmpty());
        Map<String, Object> first = (Map<String, Object>) records[0];
        System.assertNotEquals(null, first.get('Phase__c'));
    }

    @IsTest
    static void testLimitAndSorting() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'sortField' => 'Name',
            'sortDirection' => 'ASC',
            'limitSize' => 1
        }));
        Test.stopTest();

        System.assertEquals(1, response.get('count'));
        System.assertEquals(true, response.get('hasMore'));
        System.assertNotEquals(null, response.get('nextCursor'));
    }

    @IsTest
    static void testInvalidObjectName() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'InvalidObject__c'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testMissingObjectName() {
        Test.startTest();
        Map<String, Object> response = executeAPI('{}');
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testNullJsonBody() {
        Test.startTest();
        Map<String, Object> response = executeAPI('null');
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
        System.assertEquals(500, RestContext.response.statusCode);
    }

    @IsTest
    static void testMalformedJson() {
        Test.startTest();
        Map<String, Object> response = executeAPI('{ invalid json');
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
        System.assertEquals(500, RestContext.response.statusCode);
    }

    @IsTest
    static void testEmptyAndNullRequestBody() {
        Test.startTest();
        Map<String, Object> emptyBody = executeAPI('');
        Map<String, Object> nullBody = executeAPI(null);
        Test.stopTest();

        System.assertEquals(false, emptyBody.get('success'));
        System.assertEquals(false, nullBody.get('success'));
    }

    @IsTest
    static void testInvalidLastNDays_failure() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'lastNDays' => -10,
            'dateFilterFieldForLastNDays' => 'LastModifiedDate'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testLastNDaysWithoutDateField_failure() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id' },
            'dateFilterFieldForLastNDays' => 'LastModifiedDate'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testInvalidDateFilterFieldForLastNDays_failure() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'lastNDays' => 10,
            'dateFilterFieldForLastNDays' => 'InvalidField__c'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testDateFilterFieldForLastNDays_OtherThanDateTime_failure() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'lastNDays' => 10,
            'dateFilterFieldForLastNDays' => 'Source_Entity__c'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testInvalidSortDirection() {
        Test.startTest();
        Map<String, Object> response = executeAPI(unitPayload(new Map<String, Object>{
            'sortDirection' => 'SIDEWAYS'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testInvalidLastNDays_success() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>{ 'Id', 'Name' },
            'extraFields' => new List<String>{ 'Owner.Email' },
            'lastNDays' => 10,
            'dateFilterFieldForLastNDays' => 'LastModifiedDate',
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));
        Test.stopTest();

        System.assertEquals(true, response.get('success'), responseMsg(response));
        System.assertEquals('Unit__c', response.get('objectName'));
        System.assertEquals(1, response.get('count'));
    }

    @IsTest
    static void testLastNDaysWithoutFilterFieldStillSucceeds() {
        Test.startTest();
        Map<String, Object> response = executeAPI(unitPayload(new Map<String, Object>{
            'lastNDays' => 5,
            'limitSize' => 1
        }));
        Test.stopTest();
        System.assertEquals(true, response.get('success'));
    }

    @IsTest
    static void testCreatedFrom_CreatedTo_success() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'extraFields' => new List<String>{ 'Owner.Email' },
            'createdDateFrom' => System.now().addDays(-1),
            'createdDateTo' => System.now().addDays(1),
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));
        Test.stopTest();

        System.assertEquals(true, response.get('success'), responseMsg(response));
        System.assertEquals(1, response.get('count'));
    }

    @IsTest
    static void testLastModifiedFrom_LastModifiedTo_success() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'extraFields' => new List<String>{ 'Owner.Email' },
            'lastModifiedFrom' => System.now().addDays(-1),
            'lastModifiedTo' => System.now().addDays(1),
            'sortField' => 'CreatedDate',
            'sortDirection' => 'desc',
            'limitSize' => 1
        }));
        Test.stopTest();

        System.assertEquals(true, response.get('success'), responseMsg(response));
        System.assertEquals(1, response.get('count'));
    }

    @IsTest
    static void testFieldSetAndDefaultLimit() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'UnitPaymentPlanMapping__c'
        }));
        Test.stopTest();

        System.assertEquals(true, response.get('success'), responseMsg(response));
        System.assertEquals('UnitPaymentPlanMapping__c', response.get('objectName'));
    }

    @IsTest
    static void testFieldSetNotConfigured() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'Contact'
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testInvalidSortFieldFallsBack() {
        Test.startTest();
        Map<String, Object> response = executeAPI(unitPayload(new Map<String, Object>{
            'sortField' => 'DoesNotExist__c',
            'limitSize' => 0
        }));
        Test.stopTest();
        System.assertEquals(true, response.get('success'));
    }

    @IsTest
    static void testCursorPaginationAndInvalidCursor() {
        Test.startTest();
        Map<String, Object> firstPage = executeAPI(unitPayload(new Map<String, Object>{
            'sortField' => 'Name',
            'sortDirection' => 'ASC',
            'limitSize' => 1
        }));
        System.assertEquals(true, firstPage.get('hasMore'));
        String cursor = (String) firstPage.get('nextCursor');
        System.assertNotEquals(null, cursor);

        Map<String, Object> secondPage = executeAPI(unitPayload(new Map<String, Object>{
            'sortField' => 'Name',
            'sortDirection' => 'ASC',
            'limitSize' => 1,
            'cursor' => cursor
        }));
        System.assertEquals(true, secondPage.get('success'));

        Map<String, Object> descPage = executeAPI(unitPayload(new Map<String, Object>{
            'sortField' => 'Name',
            'sortDirection' => 'DESC',
            'limitSize' => 1,
            'cursor' => cursor
        }));
        System.assertEquals(true, descPage.get('success'));

        Map<String, Object> invalidCursor = executeAPI(unitPayload(new Map<String, Object>{
            'cursor' => 'not-a-valid-cursor'
        }));
        Test.stopTest();

        System.assertEquals(false, invalidCursor.get('success'));
    }

    @IsTest
    static void testBlankCursorPayloadIsIgnored() {
        String blankCursor = EncodingUtil.base64Encode(Blob.valueOf('{"lit":"","id":""}'));
        Test.startTest();
        Map<String, Object> response = executeAPI(unitPayload(new Map<String, Object>{
            'cursor' => blankCursor,
            'limitSize' => 1
        }));
        Test.stopTest();
        System.assertEquals(true, response.get('success'));
    }

    @IsTest
    static void testNumericAndDateSortCursors() {
        Test.startTest();
        Map<String, Object> pricePage = executeAPI(unitPayload(new Map<String, Object>{
            'sortField' => 'BasePrice__c',
            'sortDirection' => 'ASC',
            'limitSize' => 1
        }));
        System.assertEquals(true, pricePage.get('success'));

        Map<String, Object> datePage = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'PaymentPlan__c',
            'fields' => new List<String>{ 'Id', 'Name', 'StartDate__c' },
            'sortField' => 'StartDate__c',
            'sortDirection' => 'ASC',
            'limitSize' => 1
        }));
        Test.stopTest();

        System.assertEquals(true, datePage.get('success'), responseMsg(datePage));
        System.assertEquals(true, datePage.get('hasMore'), responseMsg(datePage));
    }

    @IsTest
    static void testPaymentPlanAndMappingSourceEntityFilters() {
        Test.startTest();
        Map<String, Object> plans = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'PaymentPlan__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'limitSize' => 10
        }));
        Map<String, Object> mappings = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'UnitPaymentPlanMapping__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'limitSize' => 10
        }));
        Map<String, Object> installments = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'PaymentInstallements__c',
            'fields' => new List<String>{ 'Id' },
            'limitSize' => 10
        }));
        Test.stopTest();

        System.assertEquals(true, plans.get('success'), responseMsg(plans));
        System.assertEquals(true, mappings.get('success'), responseMsg(mappings));
        System.assertEquals(true, installments.get('success'), responseMsg(installments));
    }

    @IsTest
    static void testMissingSourceEntityFilterThrows() {
        Test.startTest();
        Map<String, Object> response = executeAPI(JSON.serialize(new Map<String, Object>{
            'objectName' => 'User',
            'fields' => new List<String>{ 'Id', 'Name' },
            'limitSize' => 1
        }));
        Test.stopTest();
        System.assertEquals(false, response.get('success'));
    }

    @IsTest
    static void testLargeLimitIsCapped() {
        Test.startTest();
        Map<String, Object> response = executeAPI(unitPayload(new Map<String, Object>{
            'limitSize' => 999999
        }));
        Test.stopTest();
        System.assertEquals(true, response.get('success'));
        System.assertEquals(2, response.get('count'));
    }
}