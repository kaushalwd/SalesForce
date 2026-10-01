/**********************************************************************************************************************
* Name               : EgyptCallCenterRoundRobinTest                                                        
* Description        : This is the test class for EgyptLeadEscalationService
* Created By         : Inamul Hasan                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Inamul Hasan                     02 June 2026     Initial Draft  
* 2.0           Inamul Hasan                     28 July 2026     Revamp the Main class.
******************************************************************************************************************/
@isTest
public class EgyptLeadEscalationServiceTest {
    
   private static User createUser(String firstName){

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];


        User u = new User(
            FirstName = firstName,
            LastName = 'Test',
            Alias = firstName.substring(0,3).toLowerCase(),
            Email = firstName + '@test.com',
            Username = firstName + System.currentTimeMillis() + '@test.com',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );

        insert u;

        return u;
    }



    @TestSetup
    static void setupData(){


        // Managers

        User managerA = createUser('ManagerA');
        User managerB = createUser('ManagerB');


        // Sales users

        User salesA1 = createUser('SalesA1');
        User salesA2 = createUser('SalesA2');

        User salesB1 = createUser('SalesB1');


        
        insert new List<Egypt_Round_Robin_Assignment_Matrix__c>{
            
            // Manager A team
            
            new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = salesA1.Id,
                User_Number__c = 1,
                Current_Position__c = 0,
                Is_CallCenter__c = false
            ),
                new Egypt_Round_Robin_Assignment_Matrix__c(
                    User__c = salesA2.Id,
                    User_Number__c = 2,
                    Is_CallCenter__c = false
                ),
                new Egypt_Round_Robin_Assignment_Matrix__c(
                    User__c = salesB1.Id,
                    User_Number__c = 3,
                    Current_Position__c = 0,
                    Is_CallCenter__c = false
                )
                };


        Lead ld = new Lead(
            FirstName = 'Testttttest',
            LastName = 'Round Robin ',
            MobilePhone = '32456456',
            Email = 'Test@robin.com',
            Source_Entity__c = 'Modon - Egypt',
            LeadSource = 'Social Media',
            ProjectInterest__c = 'Ras El Hekma, Egypt'
        );
        
        insert ld;

    }




    private static Lead getLead(){

        return [
            SELECT Id,FirstName,LastName,
            OwnerId,
            LastModifiedDate,
            Egypt_Assignment_Number__c,
            Egypt_Escalation_Stage__c,
            Egypt_Escalation_Last_Assigned_Time__c,
            Egypt_First_Escalation_Date_Time__c,
            Egypt_Second_Escalation_Date_Time__c,
            Egypt_Third_Escalation_Date_Time__c,
            Source_Entity__c,LeadSource,ProjectInterest__c,Email,MobilePhone
            FROM Lead
            LIMIT 1
        ];

    }

    /*
     Test Initial Assignment
    */

    @IsTest
    static void testInitialAssignment(){


        Lead ld = getLead();


        Test.startTest();

        EgyptLeadEscalationService.process(
            new List<Lead>{ld}
        );

        Test.stopTest();



        Lead result=[
            SELECT OwnerId,
                   Egypt_Assignment_Number__c,
                   Egypt_Escalation_Stage__c
            FROM Lead
            WHERE Id=:ld.Id
        ];

    }


    /*
      Test Second Escalation
    */

    @IsTest
    static void testSecondEscalation(){


        Lead ld=getLead();


        Id ownerId=[
            SELECT User__c
            FROM Egypt_Round_Robin_Assignment_Matrix__c
            WHERE User_Number__c=1
            LIMIT 1
        ].User__c;



        ld.OwnerId=ownerId;
        ld.Egypt_Escalation_Stage__c='First Escalation';
        ld.Egypt_Escalation_Last_Assigned_Time__c=
            System.now().addMinutes(-10);


        update ld;



        Test.startTest();

        EgyptLeadEscalationService.process(
            new List<Lead>{getLead()}
        );

        Test.stopTest();



        Lead result=[
            SELECT OwnerId,
                   Egypt_Escalation_Stage__c
            FROM Lead
            WHERE Id=:ld.Id
        ];

    }
    
    /*
      Test Third Escalation
    */

    @IsTest
    static void testThirdEscalation(){


        Lead ld=getLead();


        Id ownerId=[
            SELECT User__c
            FROM Egypt_Round_Robin_Assignment_Matrix__c
            WHERE User_Number__c=2
            LIMIT 1
        ].User__c;



        ld.OwnerId=ownerId;

        ld.Egypt_Escalation_Stage__c=
            'Second Escalation';

        ld.Egypt_Escalation_Last_Assigned_Time__c=
            System.now().addMinutes(-10);


        update ld;



        Test.startTest();


        EgyptLeadEscalationService.process(
            new List<Lead>{getLead()}
        );


        Test.stopTest();



        Lead result=[
            SELECT Egypt_Escalation_Stage__c
            FROM Lead
            WHERE Id=:ld.Id
        ];

    }

    /*
       Test Flag after Third Escalation
    */

    @IsTest
    static void testFlagged(){


        Lead ld=getLead();


        Id ownerId=[
            SELECT User__c
            FROM Egypt_Round_Robin_Assignment_Matrix__c
            LIMIT 1
        ].User__c;



        ld.OwnerId=ownerId;

        ld.Egypt_Escalation_Stage__c=
            'Third Escalation';


        ld.Egypt_Escalation_Last_Assigned_Time__c=
            System.now().addMinutes(-10);


        update ld;



        Test.startTest();

        EgyptLeadEscalationService.process(
            new List<Lead>{getLead()}
        );

        Test.stopTest();



        Lead result=[
            SELECT Egypt_Escalation_Stage__c
            FROM Lead
            WHERE Id=:ld.Id
        ];


    }
    
    /*
       Test user worked scenario
    */

    @IsTest
    static void testUserWorkedStopEscalation(){


        Lead ld=getLead();



        ld.Egypt_Escalation_Stage__c=
            'First Escalation';


        ld.Egypt_Escalation_Last_Assigned_Time__c=
            System.now().addMinutes(-10);



        update ld;



        // simulate sales user update

        ld.Description='Customer contacted';

        update ld;

        Test.startTest();

        EgyptLeadEscalationService.process(
            new List<Lead>{getLead()}
        );

        Test.stopTest();



        Lead result=[
            SELECT Egypt_Escalation_Stage__c
            FROM Lead
            WHERE Id=:ld.Id
        ];


    }

    /*
      Invalid Lead Source
    */

    @IsTest
    static void testInvalidSource(){


        Lead ld=new Lead(
            FirstName = 'Testtt',
            LastName = 'Round ',
            MobilePhone = '32456456',
            Email = 'Test@Testtt.com',
            Source_Entity__c = 'Modon - Egypt',
            LeadSource = 'Social Media',
            ProjectInterest__c = 'Ras El Hekma, Egypt'
        );
        insert ld;

        Test.startTest();


        EgyptLeadEscalationService.process(
            new List<Lead>{
                [
                    SELECT Id,
                           OwnerId,
                    Egypt_Escalation_Stage__c,
                           Source_Entity__c,
                           LeadSource
                    FROM Lead
                    WHERE Id=:ld.Id
                ]
            }
        );


        Test.stopTest();

        Lead result=[
            SELECT OwnerId
            FROM Lead
            WHERE Id=:ld.Id
        ];

    }
}