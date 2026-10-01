/**********************************************************************************************************************
* Name               : Modon_Egypt_UnitFilterHelper_Test
* Description        : Test class for Modon_Egypt_UnitFilterHelper
* Created By         : Harshit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Harshit                             15 Sep 2025     Initial Version
* 2.0           Shahil Sinha (Horizontal)           31 Dec 2025     Simplified test class
**********************************************************************************************************************/
@isTest
public class Modon_Egypt_UnitFilterHelper_Test {

    @TestSetup
    static void setupTestData() {
        // Create Egypt Unit
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert egyptUnit;
        
        // Create UAE Unit
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit',
            Source_Entity__c = 'Modon - UAE',
            PlotNo__c = '102',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert uaeUnit;
    }

    @isTest
    static void testFilterAfterInsert() {
        List<Unit__c> units = [SELECT Id, Name, Source_Entity__c FROM Unit__c];
        
        List<SObject> newList = new List<SObject>();
        newList.addAll(units);
        Map<Id, SObject> newMap = new Map<Id, SObject>(units);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_UnitFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();

        List<Unit__c> egyptUnits = (List<Unit__c>) results.get('ModonEgyptUnits');
        List<Unit__c> otherUnits = (List<Unit__c>) results.get('OtherUnits');

        System.assertEquals(1, egyptUnits.size(), 'Should have 1 Egypt unit');
        System.assertEquals(1, otherUnits.size(), 'Should have 1 other unit');
    }

    @isTest
    static void testFilterAfterUpdate() {
        List<Unit__c> units = [SELECT Id, Name, Source_Entity__c FROM Unit__c];
        
        List<SObject> newList = new List<SObject>();
        newList.addAll(units);
        Map<Id, SObject> newMap = new Map<Id, SObject>(units);
        List<SObject> oldList = new List<SObject>();
        oldList.addAll(units);
        Map<Id, SObject> oldMap = new Map<Id, SObject>(units);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_UnitFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        Test.stopTest();

        List<Unit__c> egyptUnits = (List<Unit__c>) results.get('ModonEgyptUnits');
        List<Unit__c> otherUnits = (List<Unit__c>) results.get('OtherUnits');

        System.assertEquals(1, egyptUnits.size(), 'Should have 1 Egypt unit');
        System.assertEquals(1, otherUnits.size(), 'Should have 1 other unit');
    }

    @isTest
    static void testFilterAfterDelete() {
        List<Unit__c> units = [SELECT Id, Name, Source_Entity__c FROM Unit__c];
        
        List<SObject> oldList = new List<SObject>();
        oldList.addAll(units);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_UnitFilterHelper.filterAfterDelete(oldList);
        Test.stopTest();

        List<Unit__c> egyptUnits = (List<Unit__c>) results.get('ModonEgyptUnits');
        List<Unit__c> otherUnits = (List<Unit__c>) results.get('OtherUnits');

        System.assertEquals(1, egyptUnits.size(), 'Should have 1 Egypt unit');
        System.assertEquals(1, otherUnits.size(), 'Should have 1 other unit');
    }

    @isTest
    static void testFilterEmptyList() {
        Test.startTest();
        Map<String, Object> results = Modon_Egypt_UnitFilterHelper.filterAfterInsert(new List<SObject>(), new Map<Id, SObject>());
        Test.stopTest();

        List<Unit__c> egyptUnits = (List<Unit__c>) results.get('ModonEgyptUnits');
        System.assertEquals(0, egyptUnits.size(), 'Should have 0 units');
    }
}