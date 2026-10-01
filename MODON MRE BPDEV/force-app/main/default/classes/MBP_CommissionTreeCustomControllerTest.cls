@isTest
public class MBP_CommissionTreeCustomControllerTest {
    
    @testSetup
    static void setup() {
        // Fetch Broker_Agency record type for Account
        RecordType partnerRecordType = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency'
            LIMIT 1
        ];

        // Create Broker Agency Account
        Account agency = new Account(
            Name = 'Test Agency',
            RecordTypeId = partnerRecordType.Id,
            Bank_Account_Number__c = '123456'
        );
        insert agency;

        // Create Contacts for Agency
        Contact agentContact = new Contact(
            FirstName = 'Agent',
            LastName = 'One',
            Email = 'agent@example.com',
            Broker_Type__c = 'Agent',
            AccountId = agency.Id
        );
        insert agentContact;

        Contact ownerContact = new Contact(
            FirstName = 'Owner',
            LastName = 'One',
            Email = 'owner@example.com',
            Broker_Type__c = 'Owner',
            AccountId = agency.Id
        );
        insert ownerContact;

        Contact adminContact = new Contact(
            FirstName = 'Admin',
            LastName = 'One',
            Email = 'admin@example.com',
            Broker_Type__c = 'Agency Admin',
            AccountId = agency.Id
        );
        insert adminContact;

        // Get Partner Community Login Profile
        Profile partnerProfile = [
            SELECT Id FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];

        // Try to fetch UserRole (if not exists, keep null)
        Id userRoleId;
        try {
            userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
        } catch (Exception e) {
            userRoleId = null;
        }

        // Insert Partner Users
        insert new List<User>{
            new User(
                FirstName = 'AgentUser',
                LastName = 'One',
                Email = 'agentuser@example.com',
                Username = 'agentuser' + DateTime.now().getTime() + '@test.com',
                Alias = 'agusr',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = partnerProfile.Id,
                ContactId = agentContact.Id,
                UserRoleId = userRoleId,
                IsActive = true
            ),
            new User(
                FirstName = 'OwnerUser',
                LastName = 'One',
                Email = 'owneruser@example.com',
                Username = 'owneruser' + DateTime.now().getTime() + '@test.com',
                Alias = 'ownusr',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = partnerProfile.Id,
                ContactId = ownerContact.Id,
                UserRoleId = userRoleId,
                IsActive = true
            ),
            new User(
                FirstName = 'AdminUser',
                LastName = 'One',
                Email = 'adminuser@example.com',
                Username = 'adminuser' + DateTime.now().getTime() + '@test.com',
                Alias = 'admusr',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = partnerProfile.Id,
                ContactId = adminContact.Id,
                UserRoleId = userRoleId,
                IsActive = true
            )
        };
 Unit__c unit1 = new Unit__c(Name = 'Test Egypt Unit', PlotAreasqm__c = 1234, PlotNo__c = '1234' , Source_Entity__c='Modon - Egypt' , Sub_Status__c = 'Un-Assigned' ,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1');
       
        insert unit1;
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
           Unit__c=unit1.id,
            Status__c = 'Sold',
            Down_Payment_Status__c = 'Paid',
            SPAStatus__c = 'SPA Not Generated'
        );
        insert testSalesOrder;

        // Create Commission Line linked to Agency
        Commission_Line__c testCommissionLine = new Commission_Line__c(
            Sales_Order__c = testSalesOrder.Id,
            Commission_Amount__c = 1000,
            Commission_Percent__c = 5,
            Status__c = 'Pending Invoice Verification',
            Commission_Line_Type__c = 'External',
            Broker_Agency__c = agency.Id,
            Tax_Invoice_Number__c = 'INV123'
        );
        insert testCommissionLine;
    }

    @isTest
    static void testGetCommissionData_withValidUser() {
        User agentUser = [SELECT Id FROM User WHERE Email = 'agentuser@example.com' LIMIT 1];
        System.runAs(agentUser) {
            Test.startTest();
            List<MBP_CommissionTreeCustomController.CommissionWrapper> results = 
                MBP_CommissionTreeCustomController.getCommissionData(
                    String.valueOf(Date.today()), 
                    String.valueOf(Date.today())
                );
            Test.stopTest();

        }
    }
    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        Map<String, List<Map<String, String>>> picklists = MBP_CommissionTreeCustomController.getPicklistValues();
        Test.stopTest();

        System.assert(picklists.containsKey('spaStatus'), 'SPA Status picklist should be present');
        System.assert(picklists.containsKey('downPaymentStatus'), 'Down Payment Status picklist should be present');
        System.assert(picklists.containsKey('status'), 'Status picklist should be present');
    }
}