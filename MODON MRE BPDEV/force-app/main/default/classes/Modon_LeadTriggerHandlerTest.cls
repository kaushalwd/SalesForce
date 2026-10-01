@isTest
public class Modon_LeadTriggerHandlerTest {
 
    @testSetup
    static void setupTestData() {
        //Get the Profile by name
        Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Modon Egypt - Sales Management' LIMIT 1];
    
        //Get UserRoles by DeveloperName or Name
        UserRole salesManagerRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Modon_Egypt_Sales_Manager_1' LIMIT 1];
        UserRole salesAssociateRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Modon_Egypt_Sales_Associate_Dir1_Manager1' LIMIT 1];
        UserRole salesDirectorRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Modon_Egypt_Sales_Director_1' LIMIT 1];

		User directorUser = new User(FirstName = 'Director',
            LastName = 'Modon',
            Alias = 'dmod',
            Email = 'director.modon@example.com',
            Username = 'director.modon@example.com.test',
            ProfileId = salesProfile.Id,
            UserRoleId = salesDirectorRole.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        
        insert directorUser;
    
        //Create first user - Sales Manager
        List<User> managerUsers = new List<User>();
        for(Integer i = 1; i<=2; i++){
            managerUsers.add(new User(FirstName = 'Manager' + i,
            LastName = 'Modon',
            Alias = 'mmod' + i,
            Email = 'manager' + i + '.modon@example.com',
            Username = 'manager' + i + '.modon@example.com.test',
            ProfileId = salesProfile.Id,
            UserRoleId = salesManagerRole.Id,
			ManagerId = (i==1 ? directorUser.Id : null),
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        	));
        }
            
    
        insert managerUsers;
        
        

        //Create two associate users, assigning the first user as their manager
        List<User> associateUsers = new List<User>();
    
        for (Integer i = 1; i <= 4; i++) {
            associateUsers.add(new User(
                FirstName = 'Associate' + i,
                LastName = 'Modon',
                Alias = 'amod' + i,
                Email = 'associate' + i + '.modon@example.com',
                Username = 'associate' + i + '.modon@example.com.test',
                ProfileId = salesProfile.Id,
                UserRoleId = salesAssociateRole.Id,
                ManagerId = (math.mod(i,2) == 1 ? managerUsers[0].Id : managerUsers[1].Id),
                TimeZoneSidKey = 'Asia/Dubai',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            ));
        }
    
        insert associateUsers;
    }

    @isTest
    static void testLeadAssignment() {
		
        Test.startTest();
        List<User> associateUsers = [SELECT Id, ManagerId, Name, UserName FROM User WHERE UserName = 'associate1.modon@example.com.test' OR UserName = 'associate2.modon@example.com.test' OR UserName = 'associate3.modon@example.com.test' OR UserName = 'associate4.modon@example.com.test' LIMIT 4];
        //Create Round Robin User Manager Records
        List<Egypt_Round_Robin_Assignment_Matrix__c> roundRobinUsersCre = new List<Egypt_Round_Robin_Assignment_Matrix__c>();
        Integer userNumber = 1;

        for (User u : associateUsers) {
            Egypt_Round_Robin_Assignment_Matrix__c rrUser = new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = u.Id,
                User_Number__c = userNumber
            );
            roundRobinUsersCre.add(rrUser);
            userNumber++;
        }

        insert roundRobinUsersCre;

        //Create 3 Leads
        List<Lead> testLeads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Source_Entity__c = 'Modon - Egypt', Egyptian_ID__c = '21354687921354', MobilePhone='8795462131', Email='testmail1@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem'),
            new Lead(FirstName = 'Jane', LastName = 'Smith', Source_Entity__c = 'Modon - Egypt', Egyptian_ID__c = '21354687921355', MobilePhone='8795462132', Email='testmail2@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem'),
            new Lead(FirstName = 'Alice', LastName = 'Brown', Source_Entity__c = 'Modon - Egypt', Egyptian_ID__c = '21354687921356', MobilePhone='8795462132', Email='testmail3@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem')
        };
        insert testLeads;
        Test.stopTest();

        System.debug('Leads After Insertion: ' + testLeads);

        //Verify that Leads have Sequential Lead Numbers Assigned
        List<Lead> insertedLeads = [SELECT Id, Lead_Number__c, OwnerId FROM Lead WHERE Source_Entity__c = 'Modon - Egypt' ORDER BY Lead_Number__c ASC];

        System.debug('Retrieved Leads After Insert: ' + insertedLeads);
        System.assertEquals(3, insertedLeads.size(), 'Exactly 3 leads should have been inserted.');
        System.assertNotEquals(null, insertedLeads[0].Lead_Number__c, 'Lead number should be assigned.');
        System.assertNotEquals(null, insertedLeads[1].Lead_Number__c, 'Lead number should be assigned.');
        System.assertNotEquals(null, insertedLeads[2].Lead_Number__c, 'Lead number should be assigned.');

        //Verify that Leads were Assigned to Users in Round Robin
        List<Egypt_Round_Robin_Assignment_Matrix__c> roundRobinUsers = [SELECT User__c FROM Egypt_Round_Robin_Assignment_Matrix__c ORDER BY User_Number__c ASC];
        System.assertEquals(4, roundRobinUsers.size(), 'There should be 4 Round Robin Users.');

        // Assert that each lead is assigned to the correct user in a Round Robin manner
        //System.assertEquals(roundRobinUsers[0].User__c, insertedLeads[0].OwnerId, 'First lead should be assigned to first user.');
        //System.assertEquals(roundRobinUsers[1].User__c, insertedLeads[1].OwnerId, 'Second lead should be assigned to second user.');
        //System.assertEquals(roundRobinUsers[0].User__c, insertedLeads[2].OwnerId, 'Third lead should be assigned to first user.');
    } 
    
    @isTest
    static void testLeadStatusChange() {
        
        //Lead oldLead = new Lead(Id = '00Q000000000001', Status = 'New', Source_Entity__c = 'Modon - Egypt');
        Lead oldLead = new Lead(FirstName = 'John', LastName = 'Doe', Egyptian_ID__c = '21354687921354', MobilePhone='8795462131', Email='testmail1@mail.com', Status = 'New', Source_Entity__c = 'Modon - Egypt', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem');
        insert oldLead;
        //Lead newLead = new Lead(Id = '00Q000000000001',Status = 'In Progress',First_Escalation_Time__c = System.now(),Source_Entity__c = 'Modon - Egypt');
        Lead newLead = new Lead(Id =oldLead.Id, FirstName = 'John', LastName = 'Doe', Egyptian_ID__c = '21354687921354', MobilePhone='8795462131', Email='testmail1@mail.com', Status = 'In Progress',First_Escalation_Time__c = System.now(),Source_Entity__c = 'Modon - Egypt');
        
        List<SObject> newList = new List<SObject>{ newLead };
        List<SObject> oldList = new List<SObject>{ oldLead };
        Map<Id, SObject> sObjNewMap = new Map<Id, SObject>{ newLead.Id => newLead };
        Map<Id, SObject> sObjOldMap = new Map<Id, SObject>{ oldLead.Id => oldLead };
                        
                       
        Map<Id, Lead> typedNewMap = new Map<Id, Lead>{ newLead.Id => newLead };
        Map<Id, Lead> typedOldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
                                
                               
        Modon_LeadTriggerhandler handler = new Modon_LeadTriggerhandler();
        handler.onBeforeUpdate(typedNewMap, typedOldMap);

        
        System.assertEquals(null, typedNewMap.get(newLead.Id).First_Escalation_Time__c, 'Escalation time should be null after status change');
        
        Map<String, Object> result = Modon_Egypt_LeadFilterHelper.filterBeforeUpdate(newList, sObjNewMap, oldList, sObjOldMap);
        Map<String, Object> result1 = Modon_Egypt_LeadFilterHelper.filterAfterUpdate(newList, sObjNewMap, oldList, sObjOldMap);
        System.assert(result1 != null && result1.containsKey('ModonEgyptNewLeads'), 'Expected filtered results');
        System.assert(result != null && result.containsKey('ModonEgyptNewLeads'), 'Expected filtered results');
    }


    @isTest
    static void nonModonEgyptLead() {


        // Step 3: Create an Expression of Interest (EOI)
        Lead oldRec = new Lead();
        oldRec.FirstName  = 'John';
        oldRec.LastName = 'Doe';
        //oldRec.Company = 'ABC Inc';
        oldRec.TradeName__c ='Test';
        oldRec.UnifiedNumber__c ='Test';
        oldRec.MobilePhone='+971 50 123 4567';
        oldRec.Email='testtestmail1@mail.com';
        oldRec.ProjectInterest__c = 'Wadeem';
        INSERT oldRec;
        
        Lead newRec = new Lead(Id = oldRec.ID, LastName = 'Doey');
        
        List<SObject> newList = new List<SObject>{ newRec };
        List<SObject> oldList = new List<SObject>{ oldRec };
        Map<Id, SObject> sObjNewMap = new Map<Id, SObject>{ newRec.Id => newRec };
        Map<Id, SObject> sObjOldMap = new Map<Id, SObject>{ oldRec.Id => oldRec };
        
        LeadTriggerHandler trig = new LeadTriggerHandler();
            
        trig.beforeUpdateMethod(newList, sObjNewMap, oldList, sObjOldMap);
        trig.afterUpdateMethod(newList, sObjNewMap, oldList, sObjOldMap);
        Map<String, Object> result = Modon_Egypt_LeadFilterHelper.filterAfterUpdate(newList, sObjNewMap, oldList, sObjOldMap);
        System.assert(result != null && result.containsKey('OtherNewLeads'), 'Expected filtered results');
    }

    @isTest
    static void testAssignLeads_minimal_safe() {
        // Create necessary profile and role
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Modon Egypt - Sales Management' LIMIT 1];
        UserRole role = [SELECT Id FROM UserRole WHERE DeveloperName = 'Modon_Egypt_Sales_Associate_Dir1' LIMIT 1];
    
        // Create the user
        User u = new User(
            FirstName = 'RoundRobin',
            LastName = 'User',
            Alias = 'rrusr',
            Email = 'rruser@example.com',
            Username = 'rruser@example.com.test',
            ProfileId = profile.Id,
            UserRoleId = role.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    
        System.runAs(u) {
            // Create Round Robin Matrix entry
            Egypt_Round_Robin_Assignment_Matrix__c matrixUser = new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = u.Id,
                User_Number__c = 1
            );
            insert matrixUser;
    
            // Create a lead with Lead_Number__c (trigger condition)
            Lead testLead = new Lead(
                FirstName = 'Assign',
                LastName = 'Test',
                Egyptian_ID__c = '99999999999999',
                MobilePhone = '971501234567',
                Email = 'leadassign@mail.com',
                Lead_Number__c = 123,
                Source_Entity__c = 'Modon - Egypt',
                ProjectInterest__c = 'Wadeem'
            );
            insert testLead;
    
            Test.startTest();
            Modon_LeadTriggerHandler.assignLeads(new List<Lead>{ testLead });
            Test.stopTest();
    
            Lead updated = [SELECT OwnerId, First_Escalation_Time__c FROM Lead WHERE Id = :testLead.Id];
            System.assertNotEquals(null, updated.OwnerId, 'Lead should be assigned to a user.');
        }
    }

    @isTest
    static void testLeadInsertWithManager() {
        List<User> associateUsers = [SELECT Id, ManagerId, Name, UserName FROM User WHERE UserName = 'associate1.modon@example.com.test' OR UserName = 'associate2.modon@example.com.test' OR UserName = 'associate3.modon@example.com.test' OR UserName = 'associate4.modon@example.com.test' ORDER BY UserName ASC LIMIT 4];
        System.debug('associate Users: ' + associateUsers);
        User managerUser = [SELECT Id, UserName FROM User WHERE UserName = 'manager1.modon@example.com.test' LIMIT 1];
        //Create Round Robin User Manager Records
        List<Egypt_Round_Robin_Assignment_Matrix__c> roundRobinUsersCre = new List<Egypt_Round_Robin_Assignment_Matrix__c>();
        Integer userNumber = 1;

        for (User u : associateUsers) {
            Egypt_Round_Robin_Assignment_Matrix__c rrUser = new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = u.Id,
                User_Number__c = userNumber
            );
            roundRobinUsersCre.add(rrUser);
            userNumber++;
        }

        insert roundRobinUsersCre;
        
        List<Lead> testLeads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Source_Entity__c = 'Modon - Egypt', MobilePhone='8795462131', Email='testmail1@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem'),
            new Lead(FirstName = 'Jane', LastName = 'Smith', Source_Entity__c = 'Modon - Egypt', MobilePhone='8795462132', Email='testmail2@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem'),
            new Lead(FirstName = 'Alice', LastName = 'Brown', Source_Entity__c = 'Modon - Egypt', MobilePhone='8795462133', Email='testmail3@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem')
        };

        Test.startTest();
             System.runAs(managerUser){
                insert testLeads;
            } 
        Test.stopTest();
        List<Lead> insertedLeads = [SELECT Id, Source_Entity__c, Lead_Number__c, OwnerId FROM Lead];
        
        List<String> leadOwnersIds = new List<String>();
        List<User> leadOwners = new List<User>();
        for(Lead l: insertedLeads){
            leadOwnersIds.add((Id)l.OwnerId);
        }
        leadOwners = [SELECT Id, ManagerId FROM User WHERE Id IN :leadOwnersIds];
        Integer i = 1;
        for(User u: leadOwners){
            System.assertEquals(u.ManagerId, managerUser.ID, 'Lead Should be assign to their team members');
        }
    }

    @isTest
    static void testLeadInsertWithDirector() {
        List<User> associateUsers = [SELECT Id, ManagerId, Name, UserName FROM User WHERE UserName = 'associate1.modon@example.com.test' OR UserName = 'associate2.modon@example.com.test' OR UserName = 'associate3.modon@example.com.test' OR UserName = 'associate4.modon@example.com.test' ORDER BY UserName ASC LIMIT 4];
        System.debug('associate Users: ' + associateUsers);
        User directorUser = [SELECT Id, UserName FROM User WHERE UserName = 'director.modon@example.com.test' LIMIT 1];
                
        //Create Round Robin User Manager Records
        List<Egypt_Round_Robin_Assignment_Matrix__c> roundRobinUsersCre = new List<Egypt_Round_Robin_Assignment_Matrix__c>();
        Integer userNumber = 1;

        for (User u : associateUsers) {
            Egypt_Round_Robin_Assignment_Matrix__c rrUser = new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = u.Id,
                User_Number__c = userNumber
            );
            roundRobinUsersCre.add(rrUser);
            userNumber++;
        }

        insert roundRobinUsersCre;
        
        List<Lead> testLeads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Source_Entity__c = 'Modon - Egypt', MobilePhone='8795462131', Email='testmail1@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem'),
            new Lead(FirstName = 'Jane', LastName = 'Smith', Source_Entity__c = 'Modon - Egypt', MobilePhone='8795462132', Email='testmail2@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem'),
            new Lead(FirstName = 'Alice', LastName = 'Brown', Source_Entity__c = 'Modon - Egypt', MobilePhone='8795462133', Email='testmail3@mail.com', LeadSource = 'Call Center', ProjectInterest__c = 'Wadeem')
        };

        Test.startTest();
             System.runAs(directorUser){
                insert testLeads;
            } 
        Test.stopTest();
        List<Lead> insertedLeads = [SELECT Id, Source_Entity__c, Lead_Number__c, OwnerId FROM Lead];
        
        List<String> leadOwnersIds = new List<String>();
        List<User> leadOwners = new List<User>();
        for(Lead l: insertedLeads){
            leadOwnersIds.add((Id)l.OwnerId);
        }
        leadOwners = [SELECT Id, Manager.ManagerId FROM User WHERE Id IN :leadOwnersIds];
        Integer i = 1;
        for(User u: leadOwners){
            System.assertEquals(u.Manager.ManagerId, directorUser.ID, 'Lead Should be assign to their team members');
        }
    }
}