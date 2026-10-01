@IsTest
public class MBP_OracleSupplierPayloadBuilderTest {

    @IsTest
    static void testBuildSupplierJson_Active() {

        Account acc = new Account(
            Name = 'Test Supplier',
            Agency_Status__c = 'Active',
            BillingStreet = 'Street 1',
            BillingCity = 'Dubai',
            BillingCountry = 'United Arab Emirates'
        );
        insert acc;

        Test.startTest();
        String jsonPayload =
            MBP_OracleSupplierPayloadBuilder.buildSupplierJson(acc);
        Test.stopTest();

        System.assert(jsonPayload.contains('"Supplier":"Test Supplier"'));
        System.assert(jsonPayload.contains('"Status":"Active"'));
        System.assert(jsonPayload.contains('"Sites"'));
    }


}