/**********************************************************************************************************************
* Name               : ServiceclassTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      29 Jan 2025     Initial Draft          
******************************************************************************************************************/


@isTest
public class ServiceclassTest {

     @isTest
    static void testHandleBeforeInsert() {
        // Create test cases for SObject (e.g., Case)
        List<Case> testCases = new List<Case> {
            new Case(
                Requestor_Email__c = 'test.email@example.com',
                Customer_Email__c = 'old.email@example.com',
                Requestor_Name__c = 'test.email@example.com',
                Requestor_Phone__c = '1234567890',
                Masked_Emirates_Id__c = '784-2022-1234567-1'
            )
        };

        
        Map<String, String> fieldMappings = new Map<String, String> {
            'Requestor_Email__c' => 'Customer_Email__c',
            'Requestor_Phone__c' => 'Customer_Phone__c',
            'Masked_Emirates_Id__c' => 'Emirates_Id__c'
        };

        // Call the handleBeforeInsert method
        Test.startTest();
        Serviceclass.handleBeforeInsert(testCases, fieldMappings);
        Test.stopTest();

        // Validate the results
        System.assertEquals('t********l@example.com', testCases[0].Requestor_Email__c, 'Email should be masked');
        System.assertEquals('test.email@example.com', testCases[0].Customer_Email__c, 'Standard email field should be populated');

        System.assertEquals('12******90', testCases[0].Requestor_Phone__c, 'Phone should be masked');
        System.assertEquals('1234567890', testCases[0].Customer_Phone__c, 'Standard phone field should be populated');

        System.assertEquals('78**************-1', testCases[0].Masked_Emirates_Id__c, 'Emirates ID should be masked');
        System.assertEquals('784-2022-1234567-1', testCases[0].Emirates_Id__c, 'Standard Emirates ID field should be populated');
    }
    @isTest
    static void testHandleBeforeUpdate() {
        //Create old and new test cases
        /*Case oldCase = new Case(
            Id = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Support').getRecordTypeId(),
            Requestor_Email__c = 'old.email@example.com',
            Requestor_Phone__c = '0987654321',
            Masked_Emirates_Id__c = '784-2020-8765432-1'
        );

        Case newCase = new Case(
            Id = oldCase.Id,
            Requestor_Email__c = 'new.email@example.com',
            Requestor_Phone__c = '1234567890',
            Masked_Emirates_Id__c = '784-2022-1234567-1'
        );*/
        Case oldCase = new Case(
        Requestor_Email__c = 'old.email@example.com',
            Requestor_Name__c = 'old.email@example.com',
        Customer_Email__c = 'old.email@example.com',
            Customer_Name__c = 'old.email@example.com',
        Requestor_Phone__c = '0987654321',
        Masked_Emirates_Id__c = '784-2020-8765432-1',
            // CaseCategory__c = 'General Enquiry',
            CaseCategory__c = 'General Enquiry',
            //CaseSubCategory__c = 'Joint Owner Addition/Deletion Off Plan',
            Description = 'test description'
    );
    
    insert oldCase; // This will assign a valid Id to the oldCase record

    // Create a new case record with updated values, using the oldCase's Id
    Case newCase = new Case(
        Id = oldCase.Id, // Use the same Id for the new case
        Requestor_Email__c = 'new.email@example.com',
        Customer_Email__c = 'old.email@example.com',
        Requestor_Phone__c = '1234567890',
        Masked_Emirates_Id__c = '784-2022-1234567-1',
       // CaseCategory__c = 'General Enquiry',
        CaseCategory__c = 'Contact Center / Front Liners',
            CaseSubCategory__c = 'Contact Details Update',
        Description = 'test description'
    );


        Map<Id, Case> oldMap = new Map<Id, Case>{ oldCase.Id => oldCase };
        Map<Id, Case> newMap = new Map<Id, Case>{ newCase.Id => newCase };

        Map<String, String> fieldMappings = new Map<String, String> {
            'Requestor_Email__c' => 'Customer_Email__c',
            'Requestor_Phone__c' => 'Customer_Phone__c',
            'Masked_Emirates_Id__c' => 'Emirates_Id__c'
        };

        // Call the handleBeforeUpdate method
        Test.startTest();
        Serviceclass.handleBeforeUpdate(newMap, oldMap, fieldMappings);
        Test.stopTest();

        // Validate the results
        System.assertEquals('n*******l@example.com', newMap.get(newCase.Id).Requestor_Email__c, 'Email should be masked');
        System.assertEquals('new.email@example.com', newMap.get(newCase.Id).Customer_Email__c, 'Standard email field should be populated');

        System.assertEquals('12******90', newMap.get(newCase.Id).Requestor_Phone__c, 'Phone should be masked');
        System.assertEquals('1234567890', newMap.get(newCase.Id).Customer_Phone__c, 'Standard phone field should be populated');

        System.assertEquals('78**************-1', newMap.get(newCase.Id).Masked_Emirates_Id__c, 'Emirates ID should be masked');
        System.assertEquals('784-2022-1234567-1', newMap.get(newCase.Id).Emirates_Id__c, 'Standard Emirates ID field should be populated');
    }

     @isTest
    static void testMaskingMethods() {
        // Test email masking
        System.assertEquals('t********l@example.com', Serviceclass.maskEmail('test.email@example.com'), 'Email masking failed');

        // Test phone masking
        System.assertEquals('12******90', Serviceclass.maskPhone('1234567890'), 'Phone masking failed');

        // Test Emirates ID masking
        System.assertEquals('78**************-1', Serviceclass.maskEmiratesId('784-2022-1234567-1'), 'Emirates ID masking failed');

        // Test Passport number masking
        System.assertEquals('12**56', Serviceclass.maskPassportNumber('123456'), 'Passport number masking failed');
    }
}