/**
 * @description       : Test class for OIC_EPBCSPaymantPlanBatch
 * @author            : Karunakar Pulkam
 * @Created           : 19-08-2026
 */
@IsTest
private class OIC_EPBCSPaymantPlanBatchTest {

    private class Generic200HttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"success":true}');
            return res;
        }
    }

    @testSetup
    static void makeData() {
        Account acc = new Account(FirstName = 'Test', LastName = 'Payer');
        insert acc;

        Project__c project = new Project__c(Name = 'Test EPBCS Project');
        insert project;

        Phase__c phase = new Phase__c(Name = 'Test EPBCS Phase', Project__c = project.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Name                     = 'Test EPBCS Unit',
            Phase__c                 = phase.Id,
            PlotNo__c                = '105',
            UnitClassification__c    = 'Villa',
            Number_of_Bedrooms__c    = '5',
            Status__c                = 'Sold'
        );
        insert unit;

        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, Status__c = 'In Progress', Source_Entity__c = 'Modon - UAE');
        insert so;

        List<SalesOrderInstallments__c> soiList = new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(
                SalesOrder__c        = so.Id,
                MilestoneNumber__c   = 1,
                InstallmentAmount__c = 1000,
                MilestoneDate__c     = Date.today(),
                PaymentStatus__c     = 'Not Paid'
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c        = so.Id,
                MilestoneNumber__c   = 2,
                InstallmentAmount__c = 2000,
                MilestoneDate__c     = Date.today(),
                PaymentStatus__c     = 'Paid',
                ExtensionDate__c     = Date.today().addDays(5)
            )
        };
        insert soiList;

        Invoice__c inv = new Invoice__c(
            Account__c              = acc.Id,
            SalesOrderInstallment__c = soiList[1].Id,
            InvoiceAmount__c        = 2000
        );
        insert inv;

        Receipt__c rec = new Receipt__c(
            Account__c               = acc.Id,
            SalesOrderInstallment__c = soiList[1].Id,
            Status__c                = 'Cleared',
            EBS_Clearing_Date__c     = Date.today(),
            TotalAmount__c           = 2000
        );
        //insert rec;

        Allocation__c alloc = new Allocation__c(
            Invoice__c          = inv.Id,
            Receipt__c           = rec.Id,
            AllocationAmount__c = 2000
        );
        //insert alloc;
    }

    @IsTest
    static void test_start_viaExecuteBatch_bothConstructors() {
        Test.setMock(HttpCalloutMock.class, new Generic200HttpMock());

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        Database.executeBatch(new OIC_EPBCSPaymantPlanBatch(), 200);
        Database.executeBatch(new OIC_EPBCSPaymantPlanBatch(Date.today().addDays(-30), new Set<Id>{ so.Id }), 200);
        Test.stopTest();
    }

    @IsTest
    static void test_execute_emptyScope() {
        OIC_EPBCSPaymantPlanBatch batch = new OIC_EPBCSPaymantPlanBatch();

        Test.startTest();
        batch.execute(null, new List<SObject>());
        Test.stopTest();
    }

    @IsTest
    static void test_execute_scopeWithoutInvoices_sendsPayload() {
        Test.setMock(HttpCalloutMock.class, new Generic200HttpMock());

        List<SalesOrderInstallments__c> scope = [
            SELECT Id, MilestoneNumber__c, InstallmentAmount__c, MilestoneDate__c,
                   PaymentStatus__c, ExtensionDate__c, SalesOrder__c,
                   SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__r.Building_Name__c,
                   SalesOrder__r.Unit__r.Phase__r.Name, SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                   SalesOrder__r.Unit__r.Phase__r.Project__r.Name,
                   (SELECT Id, Name, AppliedAmount__c FROM Invoices__r)
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Not Paid'
        ];

        OIC_EPBCSPaymantPlanBatch batch = new OIC_EPBCSPaymantPlanBatch();

        Test.startTest();
        batch.execute(null, (List<SObject>) scope);
        Test.stopTest();
    }

    @IsTest
    static void test_execute_scopeWithInvoices_buildsInvoiceIds() {
        Test.setMock(HttpCalloutMock.class, new Generic200HttpMock());

        List<SalesOrderInstallments__c> scope = [
            SELECT Id, MilestoneNumber__c, InstallmentAmount__c, MilestoneDate__c,
                   PaymentStatus__c, ExtensionDate__c, SalesOrder__c,
                   SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__r.Building_Name__c,
                   SalesOrder__r.Unit__r.Phase__r.Name, SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                   SalesOrder__r.Unit__r.Phase__r.Project__r.Name,
                   (SELECT Id, Name, AppliedAmount__c FROM Invoices__r)
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Paid'
        ];

        OIC_EPBCSPaymantPlanBatch batch = new OIC_EPBCSPaymantPlanBatch();

        Test.startTest();
        batch.execute(null, (List<SObject>) scope);
        Test.stopTest();
    }

    @IsTest
    static void test_schedulableExecute() {
        Test.setMock(HttpCalloutMock.class, new Generic200HttpMock());

        Test.startTest();
        try {
            new OIC_EPBCSPaymantPlanBatch().execute((SchedulableContext) null);
        } catch (Exception e) {
            System.debug('Schedulable execute threw (custom metadata dependent): ' + e.getMessage());
        }
        Test.stopTest();
    }
}