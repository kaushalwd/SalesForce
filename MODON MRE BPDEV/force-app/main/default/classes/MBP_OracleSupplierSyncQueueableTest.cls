@IsTest
public class MBP_OracleSupplierSyncQueueableTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Queueable Supplier',
            Agency_Status__c = 'Active',
            BillingStreet = 'Street Q',
            BillingCity = 'Dubai',
            BillingCountry = 'United Arab Emirates'
        );
        insert acc;
    }

    @IsTest
    static void testQueueableSuccess() {

        List<Account> accList = [
            SELECT Id, Name, Agency_Status__c,
                   BillingStreet, BillingCity, BillingCountry
            FROM Account
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MBP_OracleCalloutMockTest());

        Test.startTest();
        System.enqueueJob(
            new MBP_OracleSupplierSyncQueueable(accList,0)
        );
        Test.stopTest();

        Account updatedAcc = [
            SELECT OIC_Supplier_Sync_Status__c,
                   OIC_Supplier_Vendor_ID__c,
                   OIC_Supplier_Party_ID__c,
                   OIC_SUPPLIER_NUMBER__c,
                   OIC_Supplier_Address_ID__c,
                   OIC_Supplier_Site_ID__c,
                   OIC_Supplier_Response__c
            FROM Account
            WHERE Id = :accList[0].Id
        ];

    }
}