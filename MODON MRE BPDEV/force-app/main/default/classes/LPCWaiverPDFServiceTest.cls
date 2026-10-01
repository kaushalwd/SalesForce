@IsTest
public class LPCWaiverPDFServiceTest {

    // Reuse helpers from LPCWaiverExecutionTest -------------------

    private static Project__c makeProject() {
        Project__c p = new Project__c(Name = 'Test Project');
        insert p;
        return p;
    }

    private static EscrowAccount__c makeEscrow() {
        EscrowAccount__c e = new EscrowAccount__c(Name = 'Phase 1 Escrow Account');
        insert e;
        return e;
    }
private static SalesOrderInstallments__c makeSOI(Id soId) {
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = soId,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 5000,
            LPCActive__c = true,
            Exclude_LPC__c = false
        );
        insert soi;
        return soi;
    }
    private static Phase__c makePhase(Id projectId, Id escrowId) {
        Phase__c ph = new Phase__c(Project__c = projectId, EscrowAccount__c = escrowId);
        insert ph;
        return ph;
    }

    private static Unit__c makeUnit(Id phaseId) {
        Unit__c u = new Unit__c(
            Phase__c = phaseId,
            PlotAreasqm__c = 1.0,
            PlotNo__c = 'U-1',
            Status__c = 'Available',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '6'
        );
        insert u;
        return u;
    }

    private static PaymentPlan__c makePaymentPlan(Id unitId) {
        PaymentPlan__c pp = new PaymentPlan__c(
            Unit__c = unitId,
            Type__c = 'Standard',
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(10)
        );
        insert pp;
        return pp;
    }

    private static Opportunity makeOpp() {
        Opportunity o = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Proposal',
            CloseDate = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1234-1234567-1'
        );
        insert o;
        return o;
    }

    private static Account makeAccount() {
        Account a = new Account(Name = 'Test Buyer');
        insert a;
        return a;
    }

    private static SalesOrder__c makeSalesOrder(Id unitId, Id ppId, Id oppId, Id accountId) {
        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unitId,
            PaymentPlan__c = ppId,
            Opportunity__c = oppId,
            CustomerAccount__c = accountId,
            Status__c = 'Completed',
            TotalAmount__c = 10000
        );
        insert so;
        return so;
    }

    private static ServiceRequest__c makeServiceRequest(Id soId, Id chargeId,Id soi, Decimal lpcAmt, Decimal lpcWaived) {
                 Id srRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('LPC_Waiver').getRecordTypeId();

         ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = soId,
            Sales_Order_Installment__c =soi,
            Charge__c = chargeId,
            LPC_Amount__c = lpcAmt,
            RecordTypeId = srRecordTypeId,
            Waiver_Percentage__c = lpcWaived,
            Type__c = 'Normal'
        );
        insert sr;
        return sr;
    }

    // ---------------- TESTS ----------------

    @IsTest
    static void testGenerateAndAttachPDF_InsertsAttachment() {
        // Setup SR
        Project__c proj = makeProject();
         Decimal lpcAmount = 123.45;
        Decimal lpcWaived = 67.89;
        EscrowAccount__c esc = makeEscrow();
        Phase__c phase = makePhase(proj.Id, esc.Id);
        Unit__c unit = makeUnit(phase.Id);
        PaymentPlan__c pp = makePaymentPlan(unit.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();
        SalesOrder__c so = makeSalesOrder(unit.Id, pp.Id, opp.Id, acc.Id);
                SalesOrderInstallments__c soi = makeSOI(so.Id);

        Charge__c ch = makeCharge(soi.Id, acc.Id);
        so.Status__c = 'Completed';
        update so;
        ServiceRequest__c sr = makeServiceRequest(so.Id, ch.Id,soi.id, lpcAmount, lpcWaived);

        Test.startTest();
        LPCWaiverPDFService.generateAndAttachPDF(sr.Id);
        Test.stopTest();

        // Verify attachment created
        List<Attachment> atts = [
            SELECT Id, Name, ParentId, Body
            FROM Attachment
            WHERE ParentId = :sr.Id
        ];
        System.assertEquals(1, atts.size(), 'One attachment should be created');
        System.assertEquals('LPC_Waiver_Memo.pdf', atts[0].Name);
        System.assertNotEquals(null, atts[0].Body, 'PDF body should not be null');
    }
   private static Charge__c makeCharge(Id soiId, Id accountId) {
        Charge__c ch = new Charge__c(
            Name = 'LPC Fee',
            SalesOrderInstallment__c = soiId,
            Account__c = accountId,
            Amount__c = 0,
            Actual_Amount__c = 0
        );
        insert ch;
        return ch;
    }

    @IsTest
    static void testLPCPDFQueueable_EnqueuesAndCreatesAttachment() {
        Project__c proj = makeProject();
         Decimal lpcAmount = 123.45;
        Decimal lpcWaived = 67.89;
        EscrowAccount__c esc = makeEscrow();
        Phase__c phase = makePhase(proj.Id, esc.Id);
        Unit__c unit = makeUnit(phase.Id);
        PaymentPlan__c pp = makePaymentPlan(unit.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();
        SalesOrder__c so = makeSalesOrder(unit.Id, pp.Id, opp.Id, acc.Id);
                SalesOrderInstallments__c soi = makeSOI(so.Id);

                Charge__c ch = makeCharge(soi.Id, acc.Id);
so.Status__c = 'Completed';
        update so;
                ServiceRequest__c sr = makeServiceRequest(so.Id, ch.Id,soi.id, lpcAmount, lpcWaived);

         Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
            submitReq.setObjectId(sr.Id);
            submitReq.setSkipEntryCriteria(true);
            submitReq.setNextApproverIds(new Id[] { UserInfo.getUserId() });
            submitReq.setComments('Submit from test');
            Approval.ProcessResult submitResult = Approval.process(submitReq);
Id workItemId = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :sr.Id
                LIMIT 1
            ].Id;

            Approval.ProcessWorkitemRequest approveReq = new Approval.ProcessWorkitemRequest();
            approveReq.setWorkitemId(workItemId);
            approveReq.setAction('Approve');
            approveReq.setComments('Approved from test');
            Approval.ProcessResult approveResult = Approval.process(approveReq);

		ApexPages.StandardController sc = new ApexPages.StandardController(sr);
            LPCWaiverPDFController controller = new LPCWaiverPDFController(sc);

        Test.startTest();
        System.enqueueJob(new LPCPDFQueueable(sr.Id));
        Test.stopTest();

        // Verify attachment created via Queueable
        List<Attachment> atts = [
            SELECT Id, Name
            FROM Attachment
            WHERE ParentId = :sr.Id
        ];
        System.assertEquals(1, atts.size(), 'Queueable should create one attachment');
        System.assertEquals('LPC_Waiver_Memo.pdf', atts[0].Name);
    }
}