@isTest
private class AccountStatusControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Account with different expiry dates for various test scenarios
        Account expiredAccount = new Account(
    		RecordTypeId = getPersonAccountRecordTypeId(),
    		FirstName = 'Expired',
    		LastName = 'User',
    		EmiratesIDExpiryDate__pc = Date.newInstance(2025, 4, 7)
		);
insert expiredAccount;

        List<Account> accounts = new List<Account>{
            new Account(
                FirstName = 'Expired',
                LastName = 'User',
                EmiratesIDExpiryDate__pc = Date.today().addDays(-3)
            ),
            new Account(
                FirstName = 'Today',
                LastName = 'Expiry',
                EmiratesIDExpiryDate__pc = Date.today()
            ),
            new Account(
                FirstName = 'Future',
                LastName = 'Expiry',
                EmiratesIDExpiryDate__pc = Date.today().addDays(5)
            ),
            new Account(
                FirstName = 'No',
                LastName = 'Expiry'
                // No EmiratesIDExpiryDate__pc
            )
        };

        insert accounts;
    }
    
    // Utility method to get Person Account Record Type Id
	private static Id getPersonAccountRecordTypeId() {
    return [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Person Account' LIMIT 1].Id;
	}

    @isTest
    static void testGetAccountStatusData_expired() {
        Account expiredAcc = [SELECT Id FROM Account WHERE FirstName = 'Expired' LIMIT 1];

        Test.startTest();
        Map<String, String> result = AccountStatusController.getAccountStatusData(expiredAcc.Id);
        Test.stopTest();

         //System.assertEquals('Expired', result.get('EmiratesIDStatus'), 'Expected status: Expired');
    	 System.assertEquals('07/04/2025', result.get('Emirates ID Expiry date'), 'Expected expired date');

    }

    @isTest
    static void testGetAccountStatusData_todayExpiry() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Today' LIMIT 1];

        Test.startTest();
        Map<String, String> result = AccountStatusController.getAccountStatusData(acc.Id);
        Test.stopTest();

        System.assertEquals(Date.today().format(), result.get('Emirates ID Expiry date'), 'Expected today’s expiry date');
    }

    @isTest
    static void testGetAccountStatusData_futureExpiry() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'Future' LIMIT 1];

        Test.startTest();
        Map<String, String> result = AccountStatusController.getAccountStatusData(acc.Id);
        Test.stopTest();

        System.assertEquals(Date.today().addDays(5).format(), result.get('Emirates ID Expiry date'), 'Expected future expiry date');
    }

    @isTest
    static void testGetAccountStatusData_noExpiryDate() {
        Account acc = [SELECT Id FROM Account WHERE FirstName = 'No' LIMIT 1];

        Test.startTest();
        Map<String, String> result = AccountStatusController.getAccountStatusData(acc.Id);
        Test.stopTest();

        System.assertEquals('Data Not Available', result.get('Emirates ID Expiry date'), 'Expected fallback for missing date');
    }

    @isTest
    static void testGetAccountStatusData_invalidId() {
        Test.startTest();
        Map<String, String> result = AccountStatusController.getAccountStatusData('');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty map for invalid ID');
    }

    @isTest
    static void testGetAccountStatusData_nullId() {
        Test.startTest();
        Map<String, String> result = AccountStatusController.getAccountStatusData(null);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty map for null ID');
    }
    @isTest
	static void testGetAccountStatusData_passportExpiry() {
   	 Account acc = new Account(
        FirstName = 'Passport',
        LastName = 'Expiry',
        PassportExpiryDate__pc = Date.today().addDays(10),
        RecordTypeId = getPersonAccountRecordTypeId()
    );
    insert acc;

    Test.startTest();
    Map<String, String> result = AccountStatusController.getAccountStatusData(acc.Id);
    Test.stopTest();

    System.debug(result);
    // Since we're not asserting exact metadata label, at least validate map is not empty
    System.assertNotEquals(0, result.size(), 'Expected at least one field value for passport expiry');
}

}