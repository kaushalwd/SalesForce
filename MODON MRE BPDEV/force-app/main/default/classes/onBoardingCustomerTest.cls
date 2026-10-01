/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 09-Nov-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dce 2025   		Initial Draft 
**/
@isTest
public class onBoardingCustomerTest {
    
    @testSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(
            Name = 'ModonTest CustomerModon AccountModon'
            //IsCustomerPortal__c = false // Adjust if your org uses this field
        );
        insert acc;
        
        // Create Account
        Account acc2 = new Account(
            Name = 'Test ModonCustomer AccountModon'
            //IsCustomerPortal = true // Adjust if your org uses this field
        );
        insert acc2;
        // Create Contact linked to Account
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuserModon@example.com',
            MobilePhone = '1234567890',
            AccountId = acc.Id,
            EIDNumber__c = 'EID12345'
        );
        insert con;
        // Create Contact linked to Account
        Contact con1 = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuserModon@example.com',
            MobilePhone = '1234567890',
            AccountId = acc2.Id,
            EIDNumber__c = 'EID12345'
        );
        insert con1;
        // Create Project hierarchy to support Unit__c on SalesOrder__c
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;
        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id//,
            //Is_Reservation_Form_Required__c = 'No'
        );
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;
        Unit__c unit2 = new Unit__c(
            Name = 'Test Unit2',
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '2',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unit2;
        // Create SalesOrder__c record
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed',
            Unit__c = unit.Id, JO1__c=con1.id
        );
        insert so;
        // Create SalesOrder__c record
        SalesOrder__c so2 = new SalesOrder__c(
            CustomerAccount__c = acc2.Id,
            Status__c = 'Completed',
            Unit__c = unit2.Id
        );
        insert so2;
    }
    @isTest
    static void testBatchAndAccessProcessCoverage() {
        // Retrieve profile for user creation (adjust profile name accordingly)
       Test.startTest();
        // Run batch job which should create users and User records
        onBoardingCustomer batchJob = new onBoardingCustomer();
        Database.executeBatch(batchJob, 1);
        Test.stopTest();
        
    }
    
    
}