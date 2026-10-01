@IsTest
public class SRPaymentReadinessControllerTest {

    @testSetup
    static void setupData() {

  
        Account acc = new Account();
        // acc.Id = acc2.Id;
        String personRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        acc.RecordTypeId = personRecTypeId;
       // acc.Name = 'Test Account';
        acc.FirstName = 'Test acc 222';
        acc.LastName = '222';  
        acc.PersonEmail = 'personal@email.com';
        acc.PersonMobilePhone = '+9711234422';
        acc.EIDNumber__pc = '784-1232-1326457-9';
        acc.PassportNumber__pc = '12344321';
        insert acc;

  
        
        Opportunity testOpportunity = new Opportunity(
        Name = 'Test Opportunity',
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        UAE_Resident_Status__c = 'Resident',
        Nationality__c = 'United Arab Emirates',
        EmiratesIDExpiryDate__c = Date.today().addDays(365),
        EIDNumber__c = '784-1234-1234567-1'
    );
        insert testOpportunity;
        
        Unit__c unit = new Unit__c(Name = 'Test Unit', PlotNo__c='1', Number_of_Bedrooms__c='1', UnitClassification__c='Apartment',
                                  Opportunity__c=testOpportunity.Id, Status__c='Sold'
                                  );
        insert unit;
        

          Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;
        Milestone__c ms = new Milestone__c(Name = 'M1',
                                          Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today()
                                          );
        insert ms;

        PaymentPlan__c pp = new PaymentPlan__c(Name = 'PP', Project__c = project.Id, Phase__c = phase.Id, Type__c = 'Standard');
        insert pp;

        PaymentInstallements__c pi = new PaymentInstallements__c(
            PaymentInstallment__c = pp.Id,
            MilestoneInstallment__c = ms.Id,
            MilestoneNumber__c = 1,
            MilestoneDate__c = Date.today()
        );
        insert pi;

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Installment Payment Verification',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Installment Payment Verification',
            Type__c = 'Cost Approval'
        );
        insert pf;

        // Business Process (Service Request)
        Business_Process__c sr = new Business_Process__c(
            Milestone__c = ms.Id
        );
        insert sr;

        // Sales Order
        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'Completed',
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            TotalAmount__c=100000,
            Opportunity__c = testOpportunity.Id
        );
        insert so;

        // Installment
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            MilestoneNumber__c=1,
            SalesOrder__c = so.Id,
            Milestone_Installment__c = ms.Id,
            PaymentInstallments__c = pi.Id,
            InstallmentAmount__c = 100,
            MilestoneDate__c = Date.today(),
            PaymentStatus__c = 'Not Paid',
            Payment_Readiness__c = 'No'
        );
        insert soi;

        // Receipt
        Receipt__c rec = new Receipt__c(
            SalesOrderInstallment__c = soi.Id,
            Modeofpayment__c = 'POS',
            Account__c=acc.Id,
            TotalAmount__c=1000
            
        );
        insert rec;
    }

    @IsTest
    static void testGetServiceRequestMilestone() {

        Business_Process__c sr = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        SRPaymentReadinessController.getServiceRequestMilestone(sr.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetInstallmentsByMilestone() {

        Milestone__c ms = [SELECT Id FROM Milestone__c LIMIT 1];
        Business_Process__c sr = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        // Business Process has no Phase -> no phase filter
        List<SRPaymentReadinessController.SoiRow> rows =
            SRPaymentReadinessController.getInstallmentsByMilestone(ms.Id, sr.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Installment should be returned when the BP has no Phase');
    }

    @IsTest
    static void testGetInstallmentsByMilestoneFiltersByPhase() {

        Milestone__c ms = [SELECT Id, Phase__r.Project__c FROM Milestone__c LIMIT 1];

        // The test unit is not in this phase, so the phase filter must exclude it.
        Phase__c otherPhase = new Phase__c(Project__c = ms.Phase__r.Project__c);
        insert otherPhase;

        Business_Process__c bp = new Business_Process__c(
            Milestone__c = ms.Id,
            Phase__c = otherPhase.Id
        );
        insert bp;

        Test.startTest();
        List<SRPaymentReadinessController.SoiRow> rows =
            SRPaymentReadinessController.getInstallmentsByMilestone(ms.Id, bp.Id);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Installments outside the Business Process Phase must be excluded');
    }

    @IsTest
    static void testSaveReadiness_UpdateAndCaseCreation() {

        Business_Process__c sr = [SELECT Id FROM Business_Process__c LIMIT 1];
        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];

        SRPaymentReadinessController.SoiRow row = new SRPaymentReadinessController.SoiRow();
        row.soiId = soi.Id;
        row.readiness = 'No';
        row.comment = 'Test Comment';

        List<SRPaymentReadinessController.SoiRow> updates = new List<SRPaymentReadinessController.SoiRow>{ row };

        Test.startTest();
        SRPaymentReadinessController.saveReadiness(sr.Id, updates);
        Test.stopTest();
    }

    @IsTest
    static void testSaveReadiness_YesRule() {

        Business_Process__c sr = [SELECT Id FROM Business_Process__c LIMIT 1];
        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];

        // Force existing = Yes
        soi.Payment_Readiness__c = 'Yes';
        update soi;

        SRPaymentReadinessController.SoiRow row = new SRPaymentReadinessController.SoiRow();
        row.soiId = soi.Id;
        row.readiness = 'No';
        row.comment = 'Try invalid change';

        List<SRPaymentReadinessController.SoiRow> updates = new List<SRPaymentReadinessController.SoiRow>{ row };

        Test.startTest();
        try {
            SRPaymentReadinessController.saveReadiness(sr.Id, updates);
        } catch (Exception e) {
            // expected validation path
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetUnpaidInstallments() {

        Milestone__c ms = [SELECT Id FROM Milestone__c LIMIT 1];

        Test.startTest();
        SRPaymentReadinessController.getUnpaidInstallments(ms.Id);
        Test.stopTest();
    }

    @IsTest
    static void testSaveDefaultSR() {

        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];
        Business_Process__c sr = [SELECT Id FROM Business_Process__c LIMIT 1];

        SRPaymentReadinessController.DefaultSRUpdateWrapper w = 
            new SRPaymentReadinessController.DefaultSRUpdateWrapper();

        w.soiId = soi.Id;
        w.defaultSR = true;
        w.defaultComments = 'Exclude test';

        List<SRPaymentReadinessController.DefaultSRUpdateWrapper> updates =
            new List<SRPaymentReadinessController.DefaultSRUpdateWrapper>{ w };

        Test.startTest();
        SRPaymentReadinessController.saveDefaultSR(sr.Id, updates);
        Test.stopTest();
    }

    @IsTest
    static void testInitiatePaymentVerification() {
        Business_Process__c sr = [SELECT Id, Type__c FROM Business_Process__c LIMIT 1];
        sr.Type__c = 'Project Milestone Confirmation';
        update sr;

        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];

        SRPaymentReadinessController.InitiateRow row = new SRPaymentReadinessController.InitiateRow();
        row.soiId = soi.Id;
        row.comment = 'Test Initiate';

        Test.startTest();
        Integer count = SRPaymentReadinessController.initiateInstallmentPaymentConfirmation(
            new List<SRPaymentReadinessController.InitiateRow>{ row },
            sr.Id
        );
        Test.stopTest();

        System.assertEquals(1, count);
    }

    @IsTest
    static void testInstallmentBusinessProcessBatch() {
        Business_Process__c sr = [SELECT Id FROM Business_Process__c LIMIT 1];
        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];

        Map<Id, String> comments = new Map<Id, String>{ soi.Id => 'Batch Comment' };
        InstallmentBusinessProcessBatch b = new InstallmentBusinessProcessBatch(comments, sr.Id);

        Test.startTest();
        Database.executeBatch(b, 1);
        Test.stopTest();
    }
}