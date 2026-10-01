@IsTest
public class MBP_OracleBankSyncQueueableTest {

    @IsTest
    static void testBankSync_Success_CoversAllLines() {

        Account acc = new Account(
            Name = 'Test Bank Account',
            OIC_Bank_Sync_Status__c = 'Failed' 
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class,
                     new MBP_OracleBankSyncMockTest());

        Test.startTest();

        System.enqueueJob(
            new MBP_OracleBankSyncQueueable(
                new List<Account>{ acc },0
            )
        );

        Test.stopTest();

        Account updatedAcc = [
            SELECT
                OIC_Bank_Sync_Status__c,
                OIC_Bank_Response__c,
                OIC_BANK_PARTY_ID__c,
                OIC_BANK_BRANCH_PARTY_ID__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('BP-12345',
            updatedAcc.OIC_BANK_PARTY_ID__c);

        System.assertEquals('BR-67890',
            updatedAcc.OIC_BANK_BRANCH_PARTY_ID__c);
    }
}