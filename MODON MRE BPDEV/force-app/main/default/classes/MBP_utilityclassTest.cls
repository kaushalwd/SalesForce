@isTest
private class MBP_utilityclassTest {

    // Utility method to create a test user with contact & account
    static User createUserWithContact(String brokerType, String uniqueKey) {
        Account acc = new Account(Name = 'Test Acc ' + uniqueKey);
        insert acc;

        Contact con = new Contact(
            FirstName = 'F' + uniqueKey,
            LastName = 'L' + uniqueKey,
            Email = uniqueKey + '@test.com',
            Phone = '1234567890',
            AccountId = acc.Id,
            Broker_Type__c = brokerType
        );
        insert con;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

        User u = new User(
            Username = 'useruniqueKey46@test.com',
            LastName = 'Last' + uniqueKey,
            Email = uniqueKey + '@test.com',
            Alias = 'a' + uniqueKey,
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert u;
        return u;
    }

    @isTest
    static void testGetCurrentUser() {
        User testUser = createUserWithContact('Agent', '001');
        System.runAs(testUser) {
            User cu = MBP_utilityclass.getCurrentUser();
            System.assertEquals(testUser.Id, cu.Id, 'Current user Id should match');
        }
    }

    @isTest
    static void testGetDynamicPicklistValues() {
        // Picklist for Case.Status always exists, so using that for testing
        List<Map<String, String>> picklistVals = MBP_utilityclass.getDynamicPicklistValues('Case', 'Status');
        System.assert(picklistVals.size() > 0, 'Should return picklist values');
        for (Map<String, String> val : picklistVals) {
            System.assert(val.containsKey('label'));
            System.assert(val.containsKey('value'));
        }
    }

    @isTest
    static void testGetDependentPicklistValues() {
        // For testing, using Case.Priorirty (controlling) and Case.Status (dependent) - not truly dependent but just structure
        Map<String, List<Map<String, String>>> dependentMap = MBP_utilityclass.getDependentPicklistValues('Case', 'Priority', 'Status');
        System.assertNotEquals(null, dependentMap, 'Dependent picklist map should not be null');
        System.assert(dependentMap.size() > 0, 'Dependent picklist map should have controlling values');

        for (String key : dependentMap.keySet()) {
            List<Map<String, String>> dependentValues = dependentMap.get(key);
            System.assert(dependentValues != null, 'Dependent values list should not be null');
        }
    }

    @isTest
    static void testGetQueueIdByDeveloperName() {
        // Create test queue
        Group g = new Group(Name = 'Test Queue', DeveloperName = 'Test_Queue', Type = 'Queue');
        insert g;

        Id queueId = MBP_utilityclass.getQueueIdByDeveloperName('Test_Queue');
        System.assertEquals(g.Id, queueId, 'Queue Id should match');

        // Negative test - invalid queue
        try {
            MBP_utilityclass.getQueueIdByDeveloperName('Invalid_Queue');
            System.assert(false, 'Expected exception for invalid queue');
        } catch (Exception e) {
           //System.assert(e.getMessage().contains('Queue not found'), 'Exception message should contain Queue not found');
        }
    }

    @isTest
    static void testGetCurrentUserInfo() {
        User testUser = createUserWithContact('Agency Admin', '002');
        System.runAs(testUser) {
            Map<String, Object> userInfo = MBP_utilityclass.getCurrentUserInfo();
            System.assertEquals(testUser.Id, userInfo.get('userId'));
 
        }
    }

    @isTest
    static void testHasBrokerType() {
        User testUser = createUserWithContact('Agent', '003');
        System.runAs(testUser) {
            Boolean result = MBP_utilityclass.hasBrokerType('Agent');
            System.assertEquals(true, result, 'User should have broker type Agent');

            Boolean falseResult = MBP_utilityclass.hasBrokerType('Owner');
            System.assertEquals(false, falseResult, 'User should not have broker type Owner');
        }
    }

    @isTest
    static void testGetBrokerTypes() {
        List<Map<String, String>> brokerTypes = MBP_utilityclass.getBrokerTypes();
        System.assertNotEquals(null, brokerTypes);
        System.assert(brokerTypes.size() > 0, 'Should return some broker types');
    }
}