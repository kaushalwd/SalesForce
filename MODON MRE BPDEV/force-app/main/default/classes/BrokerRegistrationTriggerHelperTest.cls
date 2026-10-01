@isTest
private class BrokerRegistrationTriggerHelperTest {

    @isTest
    static void testBrokerRegistrationFromSamaaro() {
        Broker_Registration__c broker = new Broker_Registration__c(
            Supplier_Name__c = 'Test Supplier23',
            Email__c = 'test2323broker@example.com',
            First_Name__c = 'John122',
            Last_Name__c = 'Doe12',
            Middle_Name__c = 'M',
            Unified_Number__c = '12123456789',
            Supplier_Number__c = 1231,
            Mailing_Address_Line__c = '123 Main St',
            Mailing_City__c = 'Dubai',
            Mailing_State__c = 'Dubai',
            Mailing_Postal_Code__c = '00000',
            Mailing_Country__c = 'UAE',
            Mobile__c = '05012234567'
        );
        insert broker;

        Test.startTest();
        BrokerRegistrationTriggerHelper.brokerRegistrationFromSamaaro(new List<sObject>{ broker });
        BrokerRegistrationTriggerHelper.incrementDifferenceExample();
        Test.stopTest();
    }
}