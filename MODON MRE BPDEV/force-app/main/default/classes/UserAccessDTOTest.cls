@isTest
public class UserAccessDTOTest {
    
    @isTest
    static void testUserAccessDTOConstructor() {
         RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1];
        Account acc = new Account(
            RecordTypeId = rt.Id,
            LastName = 'Test Person',
             FirstName = 'Sample', 
             EIDNumber__pc = '784-8767-3457743-0',
            PersonMobilePhone = '9876543210'
        );
        insert acc;

        // Create UserAccess__c record
        UserAccess__c ua = new UserAccess__c(
            Email__c = 'dto-test@example.com',
            First_Name__c = 'DTO',
            Last_Name__c = 'Test',
            IsActive__c = true,
            Account__c = acc.Id,
            GeneratedPassword__c = 'password123'/*,
            Country__c = 'India',
            City__c = 'Mumbai',
            Street__c = '123 Test Street',
            State__c = 'MH',
            PostalCode__c = '400001'*/
        );
        insert ua;
        ua = [SELECT Id, Email__c, First_Name__c, Last_Name__c, 
                      Account__c,Account__r.EIDNumber__pc, Account__r.PersonMobilePhone
               FROM UserAccess__c WHERE Id = :ua.Id];

        // Construct DTO
        UserAccessDTO dto = new UserAccessDTO(ua);

    }
}