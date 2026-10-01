/**********************************************************************************************************************
* Name               : SalesExecutiveKPIControllerTest
* Description        : Test class for SalesExecutiveKPIController
* Usage              : Test class
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Rushi Patel      24 Aug 2026     Initial Draft
******************************************************************************************************************/
@isTest
public class SalesExecutiveKPIControllerTest {
    
    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'SalesExec',
            Email = 'testsalesexec@modon.ae',
            Username = 'testsalesexec' + DateTime.now().getTime() + '@modon.ae',
            Alias = 'tse',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;
        
        Sales_Executive_Teams_KPI__c kpi = new Sales_Executive_Teams_KPI__c(
            Sales_Executive__c = testUser.Id,
            Presentable__c = 5,
            Punctuality__c = 5,
            Team_Work__c = 5,
            Target__c = 100000,
            Month__c = 'January',
            Year__c = '2026'
        );
        insert kpi;
    }
    
    @isTest
    static void testGetSalesExecutiveKPIs() {
        Test.startTest();
        List<SalesExecutiveKPIController.KPIWrapper> result = SalesExecutiveKPIController.getSalesExecutiveKPIs();
        Test.stopTest();
        
        System.assertNotEquals(0, result.size(), 'Should return at least one KPI wrapper');
        
        Boolean found = false;
        for(SalesExecutiveKPIController.KPIWrapper wrapper : result) {
            if(wrapper.lastName == 'SalesExec') {
                found = true;
                System.assertEquals(5, wrapper.presentable, 'Presentable should match');
                System.assertEquals('January', wrapper.month, 'Month should match');
            }
        }
        System.assert(found, 'Test user KPI should be found');
    }
    
    @isTest
    static void testSaveKPIs() {
        List<SalesExecutiveKPIController.KPIWrapper> result = SalesExecutiveKPIController.getSalesExecutiveKPIs();
        
        for(SalesExecutiveKPIController.KPIWrapper wrapper : result) {
            if(wrapper.lastName == 'SalesExec') {
                wrapper.target = 200000;
            }
        }
        
        Test.startTest();
        SalesExecutiveKPIController.saveKPIs(JSON.serialize(result));
        Test.stopTest();
        
        User u = [SELECT Id FROM User WHERE LastName = 'SalesExec' LIMIT 1];
        Sales_Executive_Teams_KPI__c kpi = [SELECT Target__c FROM Sales_Executive_Teams_KPI__c WHERE Sales_Executive__c = :u.Id LIMIT 1];
        System.assertEquals(200000, kpi.Target__c, 'Target should be updated');
    }
}