@IsTest
public class SalesOrderInteractionController_Test {



    @testSetup
    static void setupData() {



        Account acc = new Account(
            LastName = 'Test Customer',
            PersonEmail = 'test@test.com'
        );
        insert acc;


        Project__c proj = new Project__c(
            Name = 'Test Project'
        );
        insert proj;



        Phase__c ph = new Phase__c(
            Name = 'Phase 1',
            Project__c = proj.Id
        );
        insert ph;



        Unit__c unitObj = new Unit__c(
            Name = 'Unit 101',
            Phase__c = ph.Id,
            PlotNo__c='1234',
            UnitClassification__c='Villa',
            Number_of_Bedrooms__c='1',
            Status__c='Sold'
            
        );
        insert unitObj;



        SalesOrder__c so = new SalesOrder__c(
             Status__c = 'Completed',
            Unit__c = unitObj.Id,
            CustomerAccount__c = acc.Id
        );

        insert so;


        SalesOrderInstallments__c soi =
            new SalesOrderInstallments__c(

                SalesOrder__c = so.Id,

                MilestoneNumber__c = 1,

                MilestoneDate__c = System.today(),

                PaymentStatus__c = 'Not Paid',

                InstallmentAmount__c = 1000
            );

        insert soi;
    }



    @IsTest
    static void testGetInstallments() {

        SalesOrder__c so = [

            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Test.startTest();

        List<SalesOrderInteractionController.SOIWrapper>
            result =
                SalesOrderInteractionController.getInstallments(so.Id);

        Test.stopTest();
        SalesOrderInteractionController.getInteractionData(so.Id);

      
    }



    @IsTest
    static void testCreateInteractionCase_Email() {

        SalesOrderInstallments__c soi = [

            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Test.startTest();

        SalesOrderInteractionController.createInteractionCase(
           

                soi.Id,
                'Installment',
    'Milestone Collection',
            'Email',
                'Test Comments',
            true
            );

        Test.stopTest();

        Case cs = [

            SELECT
                Id,
                Status,
                Origin,
                Sub_Status__c,
                Resolution_Comments__c,
                Sales_Order_Installment__c

            FROM Case

            LIMIT 1
        ];

        
    }



    @IsTest
    static void testCreateInteractionCase_Calls() {

        SalesOrderInstallments__c soi = [

            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Test.startTest();

        SalesOrderInteractionController.createInteractionCase(
           

                soi.Id,
                'Installment',
    'Milestone Collection',
                'Calls',
                'Call Interaction',
            true
            );

        Test.stopTest();

        Case cs = [

            SELECT
                Id,
                Origin

            FROM Case

            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


    }



    @IsTest
    static void testCreateInteractionCase_Message() {

        SalesOrderInstallments__c soi = [

            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Test.startTest();

        SalesOrderInteractionController.createInteractionCase(

          
                soi.Id,
            'Installment',
    'Milestone Collection',
                'Messages',
                'Message Interaction',
            true
            );

        Test.stopTest();

        Case cs = [

            SELECT
                Id,
                Origin

            FROM Case

            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

       
    }


    @IsTest
    static void testCreateInteractionCase_WalkIn() {

        SalesOrderInstallments__c soi = [

            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Test.startTest();

        SalesOrderInteractionController.createInteractionCase(
          

                soi.Id,
            'Installment',
    'Milestone Collection',
                'Walk-in',
                'Walkin Interaction',
            true
            );

        Test.stopTest();

        Case cs = [

            SELECT
                Id,
                Origin

            FROM Case

            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(
            'Walk In',
            cs.Origin
        );
    }

    // =====================================================
    // TEST SOI COMMENTS UPDATED
    // =====================================================

    @IsTest
    static void testSOIUpdated() {

        SalesOrderInstallments__c soi = [

            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Test.startTest();

        SalesOrderInteractionController.createInteractionCase(
           

                soi.Id,
            'Installment',
    'Milestone Collection',
                'Email',
                'Latest Interaction Comment',
            true
            );

        Test.stopTest();

        SalesOrderInstallments__c updatedSOI = [

            SELECT
                Latest_Interaction_Comments__c

            FROM SalesOrderInstallments__c

            WHERE Id = :soi.Id
        ];
        
        SalesOrderInteractionController.getCaseCategories();

       
    }
    
}