@IsTest
public class SOCSLAControllerTest {

    @TestSetup
    static void setupData() {
        // Create a Phase (if required by your org's validations)
        Phase__c phase = new Phase__c(Name = 'Test Phase', Is_Reservation_Form_Required__c = 'No');
        insert phase;

        // Create a Unit to satisfy relationships if necessary
 Unit__c unit = new Unit__c(
            Name = 'Unit 202',
            PlotNo__c = 'P-202',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '3'
        );        insert unit;

        // Create a basic Sales Order
        SalesOrder__c so = new SalesOrder__c(
            Status__c='New',
            Sub_Status__c = 'Pending with Sales',
            SLA_Start_Date_Time__c = System.now(),
            SLA_Hours__c = 1.5,       // 1 hour 30 minutes → should calculate SLA_End_Date_Time__c
            Unit__c = unit.Id
        );
        insert so;

        // Create one more SalesOrder with SLA_Hours__c = null (to test that branch)
        SalesOrder__c soNullSLA = new SalesOrder__c(
            Status__c='New',
            Sub_Status__c = 'Pending with Sales',
            SLA_Hours__c = null,
            SLA_Start_Date_Time__c = System.now(),
            Unit__c = unit.Id
        );
        insert soNullSLA;
    }

    @IsTest
    static void test_updateAndFetchSLA_withHours() {
        // Get SalesOrder with valid SLA_Hours__c
        SalesOrder__c so = [SELECT Id, SLA_Start_Date_Time__c, SLA_Hours__c FROM SalesOrder__c WHERE SLA_Hours__c != null LIMIT 1];

        Test.startTest();
        SalesOrder__c result = SOCSLAController.updateAndFetchSLA(so.Id);
        Test.stopTest();

        // Minimal check: method executed and returned a record
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_updateAndFetchSLA_withNullHours() {
        // Get SalesOrder with null SLA_Hours__c
        SalesOrder__c soNull = [SELECT Id FROM SalesOrder__c WHERE SLA_Hours__c = null LIMIT 1];

        Test.startTest();
        SalesOrder__c result = SOCSLAController.updateAndFetchSLA(soNull.Id);
        Test.stopTest();

        // Only one simple check — ensures branch executes cleanly
        System.assertEquals(null, result.SLA_Start_Date_Time__c);
    }

    @IsTest
    static void test_getSLAFields() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        SalesOrder__c fetched = SOCSLAController.getSLAFields(so.Id);
        SOCSLAController.upsertTaskRecord(so.Id,UserInfo.getuserId(),'Subject',system.today()+2,'Completed',null);
        Test.stopTest();

        System.assertNotEquals(null, fetched);
    }
}