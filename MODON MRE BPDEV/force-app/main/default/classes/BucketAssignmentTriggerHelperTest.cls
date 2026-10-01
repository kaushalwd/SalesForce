@isTest
private class BucketAssignmentTriggerHelperTest {

    @testSetup
    static void setupTestData() {
        // Create a test bucket
        Bucket__c testBucket = new Bucket__c(Name = 'Test Bucket');
        insert testBucket;

        // Create test units linked to the bucket with required fields
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 2; i++) {
            units.add(new Unit__c(
                Name = 'Unit ' + i,
                Bucket__c = testBucket.Id,
                PlotNo__c = 'Plot-' + i,
                UnitClassification__c = 'Apartment', // Adjust to valid picklist value if needed
                Number_of_Bedrooms__c = '2'
            ));
        }
        insert units;
    }

    @isTest
    static void testAfterInsertTrigger() {
        Bucket__c bucket = [SELECT Id FROM Bucket__c LIMIT 1];

        Bucket_Assignment__c ba = new Bucket_Assignment__c(
            Bucket__c = bucket.Id,
            Name = 'Test Assignment'
        );

        Test.startTest();
        insert ba;
        Test.stopTest();

        System.assertNotEquals(null, ba.Id, 'Bucket Assignment should have been inserted');
    }

    @isTest
    static void testAfterUpdateTrigger() {
        Bucket__c bucket = [SELECT Id FROM Bucket__c LIMIT 1];

        Bucket_Assignment__c ba = new Bucket_Assignment__c(
            Bucket__c = bucket.Id,
            Name = 'Initial Assignment'
        );
        insert ba;

        ba.Name = 'Updated Assignment';

        Test.startTest();
        update ba;
        Test.stopTest();

        System.assertEquals('Updated Assignment', [SELECT Name FROM Bucket_Assignment__c WHERE Id = :ba.Id].Name);
    }

    @isTest
    static void testAfterDeleteTrigger() {
        Bucket__c bucket = [SELECT Id FROM Bucket__c LIMIT 1];

        Bucket_Assignment__c ba = new Bucket_Assignment__c(
            Bucket__c = bucket.Id,
            Name = 'To be deleted'
        );
        insert ba;

        Test.startTest();
        delete ba;
        Test.stopTest();

        List<Bucket_Assignment__c> records = [SELECT Id FROM Bucket_Assignment__c WHERE Id = :ba.Id];
        System.assertEquals(0, records.size(), 'Record should be deleted');
    }

    @isTest
    static void testAfterUndeleteTrigger() {
        Bucket__c bucket = [SELECT Id FROM Bucket__c LIMIT 1];

        Bucket_Assignment__c ba = new Bucket_Assignment__c(
            Bucket__c = bucket.Id,
            Name = 'To be undeleted'
        );
        insert ba;
        delete ba;

        Test.startTest();
        undelete ba;
        Test.stopTest();

        Bucket_Assignment__c undeleted = [SELECT Id, Name FROM Bucket_Assignment__c WHERE Id = :ba.Id];
        System.assertEquals('To be undeleted', undeleted.Name);
    }
}