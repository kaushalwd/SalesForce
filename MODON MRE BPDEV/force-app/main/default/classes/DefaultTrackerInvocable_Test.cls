@isTest
public class DefaultTrackerInvocable_Test {




    @testSetup
    static void setupData() {

        SalesOrder__c so = new SalesOrder__c(
          
            Status__c = 'Sold'
           
        );
        insert so;
        
          Id personRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account personAcc = new Account(
            RecordTypeId  = personRTId,
            PersonEmail   = 'test@example.com',
            FirstName     = 'Test',
            LastName      = 'User',
            Swift_Code__c = '123456'
        );
        insert personAcc;

        Invoice__c inv1 = new Invoice__c(
           InvoiceAmount__c                = 200,
            Sales_Order__c                  = so.Id,
            Account__c               = personAcc.Id
        );
        insert inv1;

        Invoice__c inv2 = new Invoice__c(
           InvoiceAmount__c                = 200,
                Sales_Order__c                  = so.Id,
            Account__c               = personAcc.Id
        );
        insert inv2;

        Invoice__c inv3 = new Invoice__c(
            InvoiceAmount__c                = 200,
                Sales_Order__c                  = so.Id,
            Account__c               = personAcc.Id
        );
        insert inv3;

        List<SalesOrderInstallments__c> sois = new List<SalesOrderInstallments__c>();

        for(Integer i=1;i<=3;i++){

            sois.add(new SalesOrderInstallments__c(
                MilestoneNumber__c =1 ,
                SalesOrder__c=so.Id
                // Populate mandatory fields
            ));
        }

        insert sois;

        Business_Process__c bp = new Business_Process__c(
            Type__c='Default And Termination',
            Sales_Order__c=so.Id,
            Status__c='In Progress'
        );
        insert bp;

        Default_Tracker__c tracker = new Default_Tracker__c(

            Business_Process__c=bp.Id,

            Count__c=3,

            Sales_Order_Installment_1__c=sois[0].Id,
            Sales_Order_Installment_2__c=sois[1].Id,
            Sales_Order_Installment_3__c=sois[2].Id,

            Invoice_1__c=inv1.Id,
            Invoice_2__c=inv2.Id,
            Invoice_3__c=inv3.Id
        );

        insert tracker;
    }

    @IsTest
    static void testRemoveMiddleInstallment() {

        SalesOrderInstallments__c soi = [
            SELECT Id
            FROM SalesOrderInstallments__c
            ORDER BY CreatedDate
            LIMIT 1 OFFSET 1
        ];

        Invoice__c inv = [
            SELECT Id
            FROM Invoice__c
          
            LIMIT 1
        ];

        DefaultTrackerInvocable.Request req =
            new DefaultTrackerInvocable.Request();

        req.salesOrderInstallmentId = soi.Id;
        req.invoiceId = inv.Id;

        Test.startTest();

        DefaultTrackerInvocable.removeSOI(
            new List<DefaultTrackerInvocable.Request>{req}
        );

        Test.stopTest();

        Default_Tracker__c tracker = [

            SELECT Count__c,

                   Sales_Order_Installment_1__c,
                   Sales_Order_Installment_2__c,
                   Sales_Order_Installment_3__c,

                   Invoice_1__c,
                   Invoice_2__c,
                   Invoice_3__c

            FROM Default_Tracker__c
            LIMIT 1
        ];


    }

    @IsTest
    static void testRemoveLastInstallmentAndCompleteBP() {

        Default_Tracker__c tracker = [
            SELECT Id
            FROM Default_Tracker__c
            LIMIT 1
        ];

        tracker.Count__c = 1;

        update tracker;

        SalesOrderInstallments__c soi = [
            SELECT Id
            FROM SalesOrderInstallments__c
            ORDER BY CreatedDate
            LIMIT 1
        ];

        Invoice__c inv = [
            SELECT Id
            FROM Invoice__c
            LIMIT 1
        ];

        DefaultTrackerInvocable.Request req =
            new DefaultTrackerInvocable.Request();

        req.salesOrderInstallmentId = soi.Id;
        req.invoiceId = inv.Id;

        Test.startTest();

        DefaultTrackerInvocable.removeSOI(
            new List<DefaultTrackerInvocable.Request>{req}
        );

        Test.stopTest();

        Business_Process__c bp = [

            SELECT Status__c,
                   D_T_Customer_Discussion_Outcome__c

            FROM Business_Process__c
            LIMIT 1
        ];

      

       
    }

    @IsTest
    static void testEmptyRequest() {

        Test.startTest();

        DefaultTrackerInvocable.removeSOI(
            new List<DefaultTrackerInvocable.Request>()
        );

        Test.stopTest();

    }

    @IsTest
    static void testNullRequest() {

        Test.startTest();

        DefaultTrackerInvocable.removeSOI(null);

        Test.stopTest();

      
    }

    @IsTest
    static void testNoMatchingTracker() {

        SalesOrder__c so = new SalesOrder__c(
           Status__c='Sold'
            // Populate mandatory fields
        );
        insert so;

       SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
        MilestoneNumber__c = 1
    );
    insert soi;
   Account acc=[Select Id from Account];
        Invoice__c inv = new Invoice__c(
           InvoiceAmount__c                = 200,
                Sales_Order__c                  = so.Id,
            Account__c=acc.Id
        );
        insert inv;

        DefaultTrackerInvocable.Request req =
            new DefaultTrackerInvocable.Request();

        req.salesOrderInstallmentId = soi.Id;
        req.invoiceId = inv.Id;

        Test.startTest();

        DefaultTrackerInvocable.removeSOI(
            new List<DefaultTrackerInvocable.Request>{req}
        );

        Test.stopTest();

        
    }
}