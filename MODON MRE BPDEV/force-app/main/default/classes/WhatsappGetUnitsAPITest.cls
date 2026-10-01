@IsTest
public class WhatsappGetUnitsAPITest {

    // Find a Person Account Record Type safely
    private static Id getPersonAccountRtId() {
        for (Schema.RecordTypeInfo rti : Schema.SObjectType.Account.getRecordTypeInfos()) {
            if (rti.isAvailable() && rti.getName().toLowerCase().contains('person')) {
                return rti.getRecordTypeId();
            }
        }
        return null;
    }

    @TestSetup
    static void testData() {
        Id paRtId = getPersonAccountRtId();
        System.assertNotEquals(null, paRtId,
            'Person Accounts must be enabled and a Person Account record type must exist.');

        // Account with + in number
        Account acc1 = new Account(
            RecordTypeId      = paRtId,
            LastName          = 'WA Test Customer Plus',
            PersonMobilePhone = '+97156756789'
        );
        insert acc1;

        // Account without + in number
        Account acc2 = new Account(
            RecordTypeId      = paRtId,
            LastName          = 'WA Test Customer NoPlus',
            PersonMobilePhone = '97156756780'
        );
        insert acc2;

        // Minimal Phase & Unit
        Phase__c phase = new Phase__c(Name = 'Test Phase');
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit 101',
            Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2',
            Numberofbathroom__c = 2,
            NumberofCarParks__c = 1,
            TotalArea__c = 1200,
            PlotNo__c = '101',
            UnitClassification__c = 'villa',
            Type__c = 'Apartment'
        );
        insert unit;

        // Sales Orders for both accounts
        insert new List<SalesOrder__c>{
            new SalesOrder__c(
                CustomerAccount__c = acc1.Id,
                Unit__c = unit.Id,
                TotalAmount__c = 1000000,
                Status__c = 'Completed',
                SPAPublicUrl__c = 'https://example.com/spa'
            ),
            new SalesOrder__c(
                CustomerAccount__c = acc2.Id,
                Unit__c = unit.Id,
                TotalAmount__c = 2000000,
                Status__c = 'Completed',
                SPAPublicUrl__c = 'https://example.com/spa2'
            )
        };
    }

    @IsTest
    static void test_findUnits_withPlus() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/whatsappGetUnitsAPI/';
        req.httpMethod = 'GET';
        req.addParameter('phone', '97156756789'); // Matches stored '+97156756789'

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsappGetUnitsAPI.findUnits();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assertNotEquals(null, res.responseBody);
    }

    @IsTest
    static void test_findUnits_withoutPlus() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/whatsappGetUnitsAPI/';
        req.httpMethod = 'GET';
        req.addParameter('phone', '97156756780'); // Matches stored '97156756780'

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsappGetUnitsAPI.findUnits();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assertNotEquals(null, res.responseBody);
    }
}