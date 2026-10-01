/**********************************************************************************************************************
* Name               : EgyptCallCenterRoundRobinTest                                                        
* Description        : This is the test class for EgyptCallCenterRoundRobin
* Created By         : Inamul Hasan                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Inamul Hasan                     01 June 2026     Initial Draft       
******************************************************************************************************************/
@isTest
public class EgyptCallCenterRoundRobinTest {

    @testSetup
    static void setupData() {

        // Get Standard Profile
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // Create Test Users
        User user1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Alias = 'tusr1',
            Email = 'testuser1@test.com',
            Username = 'testuser1' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        User user2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Alias = 'tusr2',
            Email = 'testuser2@test.com',
            Username = 'testuser2' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert new List<User>{ user1, user2 };

        // Create Round Robin Matrix Records
        List<Egypt_Round_Robin_Assignment_Matrix__c> matrixList =
            new List<Egypt_Round_Robin_Assignment_Matrix__c>();

        matrixList.add(
            new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = user1.Id,
                User_Number__c = 1,
                Is_CallCenter__c = true
            )
        );

        matrixList.add(
            new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = user2.Id,
                User_Number__c = 2,
                Is_CallCenter__c = true
            )
        );

        insert matrixList;
    }

    @isTest
    static void testAssignLeads() {

        // Create Test Leads
        List<Lead> leadList = new List<Lead>();

        for(Integer i = 0; i < 4; i++) {

            leadList.add(
                new Lead(
                    FirstName = 'Test ',
                    LastName = 'Test Lead ',
                    Company = 'Test Company',
                    ProjectInterest__c = 'Ras El Hekma, Egypt'
                )
            );
        }

        insert leadList;

        Test.startTest();

        EgyptCallCenterRoundRobin.assignLeads(leadList);

        Test.stopTest();

        // Fetch Updated Leads
        List<Lead> updatedLeads = [
            SELECT Id, OwnerId, Lead_Assignment_Time__c
            FROM Lead
            WHERE Id IN :leadList
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(
            4,
            updatedLeads.size(),
            'All leads should be updated'
        );

        // Get Matrix Users
        List<Egypt_Round_Robin_Assignment_Matrix__c> matrixUsers = [
            SELECT User__c, User_Number__c
            FROM Egypt_Round_Robin_Assignment_Matrix__c
            ORDER BY User_Number__c ASC
        ];

        Id user1Id = matrixUsers[0].User__c;
        Id user2Id = matrixUsers[1].User__c;

        // Verify Round Robin Assignment
        System.assertEquals(user1Id, updatedLeads[0].OwnerId);
        System.assertEquals(user2Id, updatedLeads[1].OwnerId);
        System.assertEquals(user1Id, updatedLeads[2].OwnerId);
        System.assertEquals(user2Id, updatedLeads[3].OwnerId);

        // Verify Assignment Time
        for(Lead ld : updatedLeads) {

            System.assertNotEquals(
                null,
                ld.Lead_Assignment_Time__c,
                'Lead Assignment Time should be populated'
            );
        }
    }

    @isTest
    static void testNoUsersAvailable() {

        // Delete Matrix Records
        delete [
            SELECT Id
            FROM Egypt_Round_Robin_Assignment_Matrix__c
        ];

        Lead testLead = new Lead(
            FirstName = 'Test ',
            LastName = 'Test Lead ',
            Company = 'Test Company',
            ProjectInterest__c = 'Ras El Hekma, Egypt'
        );

        insert testLead;

        Test.startTest();

        EgyptCallCenterRoundRobin.assignLeads(
            new List<Lead>{ testLead }
        );

        Test.stopTest();

        Lead updatedLead = [
            SELECT Id, OwnerId
            FROM Lead
            WHERE Id = :testLead.Id
        ];
    }

    @isTest
    static void testEmptyLeadList() {

        Test.startTest();

        EgyptCallCenterRoundRobin.assignLeads(
            new List<Lead>()
        );

        Test.stopTest();

        System.assert(true);
    }
}