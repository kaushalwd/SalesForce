/**********************************************************************************************************************
 * Name               : Modon_Egypt_ManageInventoryTest
 * Description        : Test class for Modon_Egypt_ManageInventoryController apex class
 * Created By         : Horizontal
 * --------------------------------------------------------------------------------------------------------------------
 * Version    Author         Date         Comments
 * --------------------------------------------------------------------------------------------------------------------
 * 1.0        Milin Kapatel  05-02-2025   Initial version
 **********************************************************************************************************************/
@IsTest
public class Modon_Egypt_ManageInventoryTest {

    /* ------------------------------
       Test Setup
    --------------------------------*/
    @TestSetup
    static void setupData() {

        // Create a test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon Egypt - Sales Operations' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@modon.com',
            Username = 'testuser' + System.currentTimeMillis() + '@modon.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        // Create Units
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new Unit__c(
                Name = 'Unit ' + i,
                ApprovalStatus__c = 'Draft',
                Status__c = 'Available',
                Sub_Status__c = 'Un-Assigned',
                Number_of_Bedrooms__c = '1',
                UnitClassification__c = 'Apartment',
                Zone__c = 'Beach Plaza',
                PlotNo__c = '100',
                Source_Entity__c = 'Modon - Egypt'
            ));
        }
        insert units;
        
        Bucket__c bucket = new Bucket__c(Name = 'Modon Egypt - Operation Team', Active__c = true);
        insert bucket;
    }

    /* ------------------------------
       loadFilters()
    --------------------------------*/
    @IsTest
    static void testLoadFilters() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result =
            Modon_Egypt_ManageInventoryController.loadFilters();
        Test.stopTest();

        System.assertNotEquals(null, result);
        // CurrencyIsoCode should exist in most orgs
        System.assert(result.containsKey('CurrencyIsoCode'));
    }

    /* ------------------------------
       getFieldsFromLayout()
    --------------------------------*/
    @IsTest
    static void testGetFieldsFromLayout() {

        Test.startTest();
        List<String> fields =
            Modon_Egypt_ManageInventoryController.getFieldsFromLayout(
                'Unit__c',
                'Unit Layout'
            );
        Test.stopTest();

        System.assertNotEquals(null, fields);
    }

    /* ------------------------------
       updateInventory()
    --------------------------------*/
    @IsTest
    static void testUpdateInventory_AllActions() {

        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        List<Unit__c> units = [SELECT Id FROM Unit__c LIMIT 2];
        Bucket__c bucket = [SELECT Id FROM Bucket__c LIMIT 1];
        
		Id bucketId = bucket.Id;
        Set<Id> unitIds = new Set<Id>();
        for (Unit__c u1 : units) {
            unitIds.add(u1.Id);
        }

        List<String> actions = new List<String>{
            'Draft', 'UnRelease', 'Release',
            'Assign', 'Un-Assign', 'Bucket'
        };
		
		Test.startTest();
        for (String action : actions) {

            Modon_Egypt_ManageInventoryController.InventoryUpdateWrapper w =
                new Modon_Egypt_ManageInventoryController.InventoryUpdateWrapper();
            w.unitIds = unitIds;
            w.action = action;
            w.userId = u.Id;
            w.bucketId = bucketId;
            w.hoursToBlock = '120';
            w.blockComments = 'Block for testing';

            String jsonString = JSON.serialize(w);

            String result =
                Modon_Egypt_ManageInventoryController.updateInventory(jsonString);
            System.assertEquals('SUCCESS', result);
        }
        Test.stopTest();
    }

    /* ------------------------------
       getFieldsFromLayout()
    --------------------------------*/
    @IsTest
    static void getZoneValues() {

        Test.startTest();
        List<String> zoneValues = Modon_Egypt_ManageInventoryController.getZoneValues();
        Test.stopTest();

        System.assertNotEquals(null, zoneValues);
    }
}