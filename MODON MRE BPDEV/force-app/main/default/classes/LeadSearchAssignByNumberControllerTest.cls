@IsTest
public class LeadSearchAssignByNumberControllerTest {

    @testSetup
    static void setupData() {
        Lead_Assign_Filter__mdt cfg;
        List<Lead_Assign_Filter__mdt> cfgList = [
            SELECT LeadSource__c, SubSource__c, IsActive__c
            FROM Lead_Assign_Filter__mdt
            WHERE IsActive__c = true
            LIMIT 1
        ];
        if (!cfgList.isEmpty()) {
            cfg = cfgList[0];
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User ownerUser = new User(
            FirstName = 'Lead',
            LastName  = 'Owner',
            Email     = 'lead.owner.' + System.currentTimeMillis() + '@test.com',
            Username  = 'lead.owner.' + System.currentTimeMillis() + '@test.com',
            Alias     = 'lown',
            TimeZoneSidKey     = 'Asia/Dubai',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );

        User salesUser = new User(
            FirstName = 'Sales',
            LastName  = 'User',
            Email     = 'sales.user.' + System.currentTimeMillis() + '@test.com',
            Username  = 'sales.user.' + System.currentTimeMillis() + '@test.com',
            Alias     = 'susr',
            TimeZoneSidKey     = 'Asia/Dubai',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ownerUser, salesUser};

            List<CustomPermission> cpList = [
                SELECT Id, DeveloperName
                FROM CustomPermission
                WHERE DeveloperName = 'Lead_Search_Assign'
                LIMIT 1
            ];

            if (!cpList.isEmpty()) {
                List<SetupEntityAccess> seaList = [
                    SELECT ParentId
                    FROM SetupEntityAccess
                    WHERE SetupEntityId = :cpList[0].Id
                    LIMIT 1
                ];

                if (!seaList.isEmpty()) {
                    insert new PermissionSetAssignment(
                        AssigneeId = salesUser.Id,
                        PermissionSetId = seaList[0].ParentId
                    );
                }
            }
        }

        List<Lead> leads = new List<Lead>{
            new Lead(
                FirstName = 'John',
                LeadSource = (cfg != null ? cfg.LeadSource__c : 'Walk-In'),
                SubSource__c = (cfg != null ? cfg.SubSource__c : null),
                LastName = 'Doe',
                Company = 'ABC Inc.',
                Email = 'test@test.com',
                EIDNumber__c = '784-3434-3434343-4',
                MobilePhone = '+971343434343',
                TradeName__c = 'Test',
                UnifiedNumber__c = 'Test',
                ProjectInterest__c = 'Wadeem',
                Status = 'Open - Not Contacted',
                OwnerId = ownerUser.Id
            )
        };
        insert leads;
    }

    @IsTest
    static void test_SearchByLeadNumber_Positive() {
        User salesUser = [SELECT Id FROM User WHERE Alias = 'susr' LIMIT 1];
        Lead l = [SELECT Id, LeadNumber__c FROM Lead LIMIT 1];

        System.runAs(salesUser) {
            Test.startTest();
            List<LeadSearchAssignByNumberController.LeadRow> rows =
                LeadSearchAssignByNumberController.searchByLeadNumber(l.LeadNumber__c, 1);
            Test.stopTest();
        }
    }
}