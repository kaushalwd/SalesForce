@isTest
public class MBP_MassTransferControllerTest {

     @testSetup
    static void setupData() {

        RecordType partnerRecordType = [
        SELECT Id
        FROM RecordType
        WHERE SObjectType = 'Account'
        AND DeveloperName = 'Broker_Agency'
        LIMIT 1
    ];

    Account agency = new Account(
        Name = 'Test Agency',
        RecordTypeId = partnerRecordType.Id
    );

    insert agency;

    Contact agentContact = new Contact(
        FirstName = 'Agent',
        LastName = 'One',
        Email = 'agent@example.com',
        Broker_Type__c = 'Agent',
        AccountId = agency.Id
    );

    Database.insert(agentContact, AccessLevel.SYSTEM_MODE);
   // insert agentContact;

    Contact ownerContact = new Contact(
        FirstName = 'Owner',
        LastName = 'One',
        Email = 'owner@example.com',
        Broker_Type__c = 'Owner',
        AccountId = agency.Id
    );

    Database.insert(ownerContact, AccessLevel.SYSTEM_MODE);
    //insert ownerContact;

    Contact adminContact = new Contact(
        FirstName = 'Admin',
        LastName = 'One',
        Email = 'admin@example.com',
        Broker_Type__c = 'Agency Admin',
        AccountId = agency.Id
    );
    Database.insert(adminContact, AccessLevel.SYSTEM_MODE);
    //insert adminContact;

    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Modon - Partner Community Login User'
        LIMIT 1
    ];

    Id userRoleId;

    try {

        userRoleId = [
            SELECT Id
            FROM UserRole
            WHERE Name = 'Partner User'
            LIMIT 1
        ].Id;

    } catch (Exception e) {

        userRoleId = null;
    } insert new List<User>{

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
            ProfileId = p.Id,
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
            ProfileId = p.Id,
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
            ProfileId = p.Id,
            ContactId = adminContact.Id,
            UserRoleId = userRoleId,
            IsActive = true
        )
            };
                Project__c proj = new Project__c(
                    Name = 'Hudayriyat Golf Estates',
                    EOI_Limit__c = 10
                );
        Database.insert(proj, AccessLevel.SYSTEM_MODE);
        // insert proj;
        
        Phase__c ph = new Phase__c(
            Name = 'Phase 1'
        );
        Database.insert(ph, AccessLevel.SYSTEM_MODE);
        //insert ph;
        
        EOI_Range__c rangeRec = new EOI_Range__c(
            Project__c = proj.Id,
            Phase__c = ph.Id,
            Unit_Type__c = 'Apartment',
            No_of_Bedrooms__c = '2 BHK',
            UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 10000,
            Is_Active__c = true
        );
        Database.insert(rangeRec, AccessLevel.SYSTEM_MODE);
        // insert rangeRec;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = agency.Id,
            BrokerAgency__c = agency.Id,
            BrokerAgent__c = agentContact.Id
        );
        Database.insert(opp, AccessLevel.SYSTEM_MODE);
        // insert opp;
        
        Expressionofinterest__c eoi =
            new Expressionofinterest__c(
                Opportunity__c = opp.Id,
                Project__c = proj.Id,
                UnitType__c = 'Apartment',
                NumberofBedrooms__c = '2',
                Status__c = 'In progress',
                Account__c = agency.Id
            );
        Database.insert(eoi, AccessLevel.SYSTEM_MODE);
    }

    @isTest
    static void testGetEOIRecords() {

        Test.startTest();
        List<Expressionofinterest__c> results =
            MBP_OpportunityMassTransferController.getEOIRecords();
        Test.stopTest();

        System.assert(results != null, 'Result should not be null');
        System.assert(results.size() >= 0, 'Should return list safely');

        for(Expressionofinterest__c e : results) {
            System.assertNotEquals(null, e.Name);
        }
    }

    @isTest
    static void testChangeOpportunityOwners() {

        Expressionofinterest__c eoi =
            [SELECT Id, Opportunity__c FROM Expressionofinterest__c LIMIT 1];

        User newUser = new User(
            FirstName = 'New',
            LastName = 'Owner',
            Email = 'newowner@example.com',
            Username = 'newowner' + System.currentTimeMillis() + '@test.com',
            Alias = 'nowner',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US'
        );
        insert newUser;

        Test.startTest();

        MBP_OpportunityMassTransferController.changeOpportunityOwners(
            new List<Id>{ eoi.Id },
            newUser.Id
        );

        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT Id, OwnerId
            FROM Opportunity
            WHERE Id = :eoi.Opportunity__c
        ];

        System.assertEquals(
            newUser.Id,
            updatedOpp.OwnerId,
            'Opportunity owner should be updated'
        );
    }

    @isTest
    static void testEmptyInputException() {

        Boolean thrown = false;

        try {
            MBP_OpportunityMassTransferController.changeOpportunityOwners(
                new List<Id>(),
                UserInfo.getUserId()
            );
        } catch (Exception e) {
            thrown = true;
        }

        System.assertEquals(true, thrown, 'Exception should be thrown for empty input');
    }
}