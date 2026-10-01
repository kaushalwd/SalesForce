@isTest
private class ModonEgyptAddJointOwnerControllerTest {

    /**
     * Test Data Factory
     * Creates Account, Opportunity, Sales Order, and Joint Owners
     */
    private static Map<String, Object> createTestData(Boolean withOpportunity) {
        Map<String, Object> dataMap = new Map<String, Object>();

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity (optional)
        Opportunity opp;
        if (withOpportunity) {
            opp = new Opportunity(
                Name = 'Test Opportunity',
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = acc.Id
            );
            insert opp;
        }

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = withOpportunity ? opp.Id : null
        );
        insert so;

        // Create Joint Owners (Opportunity level)
        List<JointOwner__c> oppOwners = new List<JointOwner__c>();
        if (withOpportunity) {
            for (Integer i = 0; i < 3; i++) {
                oppOwners.add(new JointOwner__c(
                    JointOwnerAccount__c = acc.Id,
                    Opportunity__c = opp.Id,
                    OwnershipPercentage__c = 10,
					RelationshipSubType__c = 'Sibling',
					RelationshipType__c = 'Joint Owner P-P'
                ));
            }
            insert oppOwners;
        }

        // Create existing Sales Order Joint Owner
        List<JointOwner__c> soOwners = new List<JointOwner__c>();
        if (withOpportunity) {
            soOwners.add(new JointOwner__c(
                JointOwnerAccount__c = acc.Id,
                SalesOrder__c = so.Id,
                OwnershipPercentage__c = 20,
				RelationshipSubType__c = 'Sibling',
				RelationshipType__c = 'Joint Owner P-P'
            ));
            insert soOwners;
        }

        dataMap.put('account', acc);
        dataMap.put('opportunity', opp);
        dataMap.put('salesOrder', so);
        dataMap.put('oppOwners', oppOwners);
        dataMap.put('soOwners', soOwners);

        return dataMap;
    }

    /**
     * Test: getJointOwners - Happy Path
     */
    @isTest
    static void testGetJointOwners() {
        Map<String, Object> data = createTestData(true);
        SalesOrder__c so = (SalesOrder__c) data.get('salesOrder');

        Test.startTest();
        ModonEgyptAddJointOwnerController.JointOwnerWrapper result =
            ModonEgyptAddJointOwnerController.getJointOwners(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(3, result.oppJointOwners.size(), 'Should return Opportunity Joint Owners');
        System.assertEquals(1, result.existingJointOwners.size(), 'Should return existing SO Joint Owners');
    }

    /**
     * Test: getJointOwners - No Opportunity case
     */
    @isTest
    static void testGetJointOwners_NoOpportunity() {
        Map<String, Object> data = createTestData(false);
        SalesOrder__c so = (SalesOrder__c) data.get('salesOrder');

        Test.startTest();
        ModonEgyptAddJointOwnerController.JointOwnerWrapper result =
            ModonEgyptAddJointOwnerController.getJointOwners(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertEquals(null, result.oppJointOwners, 'No Opportunity → no opp owners');
        System.assertEquals(null, result.existingJointOwners, 'No Opportunity → no existing owners');
    }

    /**
     * Test: createSalesOrderJointOwners - Happy Path
     */
    @isTest
    static void testCreateSalesOrderJointOwners() {
        Map<String, Object> data = createTestData(true);
        SalesOrder__c so = (SalesOrder__c) data.get('salesOrder');
        List<JointOwner__c> oppOwners = (List<JointOwner__c>) data.get('oppOwners');

        // Prepare map (Id → Ownership)
        Map<Id, Decimal> selectedMap = new Map<Id, Decimal>();
        for (JointOwner__c jo : oppOwners) {
            selectedMap.put(jo.Id, 15);
        }

        Test.startTest();
        ModonEgyptAddJointOwnerController.createSalesOrderJointOwners(selectedMap, so.Id);
        Test.stopTest();

        // Verify new records created
        List<JointOwner__c> insertedRecords = [
            SELECT Id, SalesOrder__c, OwnershipPercentage__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :so.Id
        ];

        // 1 existing + 3 new = 4
        System.assertEquals(4, insertedRecords.size(), 'Should have total 4 SO joint owners');

        // Verify ownership updated
        Integer updatedCount = 0;
        for (JointOwner__c jo : insertedRecords) {
            if (jo.OwnershipPercentage__c == 15) {
                updatedCount++;
            }
        }
        System.assertEquals(3, updatedCount, '3 records should have updated ownership');
    }

    /**
     * Test: createSalesOrderJointOwners - Empty Map
     */
    @isTest
    static void testCreateSalesOrderJointOwners_EmptyMap() {
        Map<String, Object> data = createTestData(true);
        SalesOrder__c so = (SalesOrder__c) data.get('salesOrder');

        Test.startTest();
        ModonEgyptAddJointOwnerController.createSalesOrderJointOwners(new Map<Id, Decimal>(), so.Id);
        Test.stopTest();

        // Verify no extra records created (only existing one)
        List<JointOwner__c> records = [
            SELECT Id FROM JointOwner__c WHERE SalesOrder__c = :so.Id
        ];

        System.assertEquals(1, records.size(), 'No new records should be created');
    }

    /**
     * Test: createSalesOrderJointOwners - Invalid Ids (Exception safe)
     */
    @isTest
    static void testCreateSalesOrderJointOwners_InvalidIds() {
        Map<String, Object> data = createTestData(true);
        SalesOrder__c so = (SalesOrder__c) data.get('salesOrder');

        Map<Id, Decimal> fakeMap = new Map<Id, Decimal>{
            '001000000000000AAA' => 10 // fake Id
        };

        Test.startTest();
        ModonEgyptAddJointOwnerController.createSalesOrderJointOwners(fakeMap, so.Id);
        Test.stopTest();

        // Should not fail, just no insert
        List<JointOwner__c> records = [
            SELECT Id FROM JointOwner__c WHERE SalesOrder__c = :so.Id
        ];

        System.assertEquals(1, records.size(), 'No new records should be created for invalid Ids');
    }
}