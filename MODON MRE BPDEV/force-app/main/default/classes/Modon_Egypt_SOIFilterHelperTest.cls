/**********************************************************************************************************************
* Name               : Modon_Egypt_SOIFilterHelperTest
* Description        : Test class for Modon_Egypt_SOIFilterHelper
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        03 Feb 2026     Initial Version
**********************************************************************************************************************/
@isTest
public class Modon_Egypt_SOIFilterHelperTest {

    @TestSetup
    static void setupTestData() {
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;
        
        insert new List<SalesOrder__c>{
            new SalesOrder__c(Status__c = 'New', Unit__c = unit.Id, Source_Entity__c = 'Modon - Egypt'),
            new SalesOrder__c(Status__c = 'New', Unit__c = unit.Id, Source_Entity__c = 'Modon - UAE')
        };
        
        List<SalesOrder__c> salesOrders = [SELECT Id, Source_Entity__c FROM SalesOrder__c];
        List<SalesOrderInstallments__c> soiList = new List<SalesOrderInstallments__c>();
        for (SalesOrder__c so : salesOrders) {
            soiList.add(new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                InstallmentAmount__c = 10000,
                MilestoneDate__c = Date.today().addDays(30)
            ));
        }
        insert soiList;
    }

    @isTest
    static void testFilterMethods() {
        List<SalesOrderInstallments__c> soiList = [SELECT Id, Source_Entity__c FROM SalesOrderInstallments__c];
        Map<Id, SObject> soiMap = new Map<Id, SObject>(soiList);

        Test.startTest();
        Map<String, Object> beforeInsertResults = Modon_Egypt_SOIFilterHelper.filterBeforeInsert(soiList, soiMap);
        Map<String, Object> afterInsertResults = Modon_Egypt_SOIFilterHelper.filterAfterInsert(soiList, soiMap);
        Map<String, Object> beforeUpdateResults = Modon_Egypt_SOIFilterHelper.filterBeforeUpdate(soiList, soiMap, soiList, soiMap);
        Map<String, Object> afterUpdateResults = Modon_Egypt_SOIFilterHelper.filterAfterUpdate(soiList, soiMap, soiList, soiMap);
        Test.stopTest();

        // Assert all methods return correct results
        assertResults(beforeInsertResults);
        assertResults(afterInsertResults);
        assertResults(beforeUpdateResults);
        assertResults(afterUpdateResults);
    }

    @isTest
    static void testEmptyList() {
        Test.startTest();
        Map<String, Object> results = Modon_Egypt_SOIFilterHelper.filterAfterInsert(new List<SObject>(), new Map<Id, SObject>());
        Test.stopTest();

        System.assertEquals(0, ((List<SalesOrderInstallments__c>) results.get('ModonEgyptSalesOrderInstallments')).size());
        System.assertEquals(0, ((List<SalesOrderInstallments__c>) results.get('OtherSalesOrderInstallments')).size());
    }

    private static void assertResults(Map<String, Object> results) {
        List<SalesOrderInstallments__c> egyptSOIs = (List<SalesOrderInstallments__c>) results.get('ModonEgyptSalesOrderInstallments');
        List<SalesOrderInstallments__c> otherSOIs = (List<SalesOrderInstallments__c>) results.get('OtherSalesOrderInstallments');

        System.assertEquals(1, egyptSOIs.size(), 'Should have 1 Egypt SOI');
        System.assertEquals(1, otherSOIs.size(), 'Should have 1 other SOI');
    }
}