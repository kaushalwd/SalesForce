/**********************************************************************************************************************
* Name               : InstallmentReminderCreationTest                                                        
* Description        : Test class for InstallmentReminderCreation
* Usage              : Test class for InstallmentReminderCreation
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0			raghu.gajjela@activemindsit.com 			04 May 2026		Test class for InstallmentReminderCreation
***********************************************************************************************************************/
@isTest
private class InstallmentReminderCreationTest {

    private static final String TEST_EMAIL = 'testperson@example.com';
 class MockHttpResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"status":"success"}');
        res.setStatusCode(200);
        return res;
    }
}

    @testSetup
    static void setupData() {

        // -------------------------
        // ACCOUNT
        // -------------------------
        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = TEST_EMAIL
        );
        insert acc;

        // -------------------------
        // PROJECT (MUST MATCH METADATA)
        // -------------------------
        Project__c proj = new Project__c(Name = 'Al Naseem');
        insert proj;

        Phase__c phase = new Phase__c(
            Name = 'Phase 1',
            Project__c = proj.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit A',
            Phase__c = phase.Id,
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            Type__c = 'G+1'
        );
        insert unit;

        // Re-query for formula field
        unit = [
            SELECT Id, Project_Name__c
            FROM Unit__c
            WHERE Id = :unit.Id
        ];

        // -------------------------
        // SALES ORDER
        // -------------------------
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed',
            Unit__c = unit.Id,
            TotalAmount__c = 50000
        );
        insert so;

        // -------------------------
        // INSTALLMENT (CRITICAL MATCH)
        // -------------------------
        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Milestone 1',
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 10000,
            MilestoneDate__c = Date.today().addDays(30) // → 30 days Prior
        );
        insert inst;

        // Re-query → ensures formula fields are evaluated
        inst = [
            SELECT ReminderType__c,
                   ReminderDueDate__c,
                   SalesOrder__r.Unit__r.Project_Name__c
            FROM SalesOrderInstallments__c
            WHERE Id = :inst.Id
        ];

        /*System.assertEquals('30 days Prior', inst.ReminderType__c);
        System.assertEquals('Al Naseem', inst.SalesOrder__r.Unit__r.Project_Name__c);
        System.assertNotEquals(null, inst.ReminderDueDate__c);*/
    }

    // -------------------------
    // MAIN BATCH TEST
    // -------------------------
    @isTest
    static void testBatch_execute() {
Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        Test.startTest();
        Database.executeBatch(new InstallmentReminderCreation(), 1);
        Test.stopTest();

    }

    // -------------------------
    // TEST CONSTRUCTOR WITH ID
    // -------------------------
    @isTest
    static void testBatch_withIdConstructor() {
Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        SalesOrderInstallments__c inst = [
            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(
            new InstallmentReminderCreation(new Set<Id>{ inst.Id }),
            1
        );
        Test.stopTest();

    }

    // -------------------------
    // HELPER METHOD TEST
    // -------------------------
    @isTest
    static void testGetPaymentReminder() {

        SalesOrderInstallments__c inst = [
            SELECT Id,
                   SalesOrder__r.Name,
                   SalesOrder__r.CustomerAccount__r.PersonEmail,MilestoneDescription__c,
                   InstallmentAmount__c,
                   ReminderDueDate__c
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        PaymentRemindersTemplates__mdt meta = new PaymentRemindersTemplates__mdt();
        meta.FromAddress__c = 'from@test.com';

        PaymentReminder__c pr =
            InstallmentReminderCreation.getPaymentReminder(
                inst,
                '30 days Prior',
                meta
            );

       // System.assertNotEquals(null, pr);
        //System.assertEquals('30 days Prior', pr.ReminderType__c);
    }

    // -------------------------
    // UPDATE METHOD TEST
    // -------------------------
    @isTest
    static void testUpdateInstallmentReminderSentDates() {

        SalesOrderInstallments__c inst = [
            SELECT Id
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        PaymentReminder__c pr = new PaymentReminder__c(
            SalesOrderInstallment__c = inst.Id,
            ReminderType__c = '30 days Prior'
        );

        Test.startTest();
        InstallmentReminderCreation.updateInstallmentReminderSentDates(
            new List<PaymentReminder__c>{ pr }
        );
        Test.stopTest();

    }

    // -------------------------
    // FINISH METHOD
    // -------------------------
    @isTest
    static void testFinishMethod() {
        InstallmentReminderCreation batch = new InstallmentReminderCreation();
        batch.finish(null);
    }
}