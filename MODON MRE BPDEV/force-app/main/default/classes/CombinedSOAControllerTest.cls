@isTest
public class CombinedSOAControllerTest {

    @isTest
    static void testGetAllSOA() {
        // Step 1: Create required data
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        EscrowAccount__c escAccount = new EscrowAccount__c(Name = 'Phase 1 Escrow Account');
        insert escAccount;

        VirtualAccount__c vaObj = new VirtualAccount__c(
            Name = 'Test account',
            Status__c = 'Available',
            EscrowAccount__c = escAccount.Id,
            VirtualAccountNumber__c = '124567642',
            VirtualIBANNumber__c = 'AE3456789456789'
        );
        insert vaObj;

        String options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';

        Phase__c phase = new Phase__c(
            Project__c = project.Id,
            EscrowAccount__c = escAccount.Id,
            PhaseOptions__c = options
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Status__c = 'Available',
            BlockedFor__c = UserInfo.getUserId(),
            BlockedBy__c = UserInfo.getUserId(),
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '9'
        );
        insert unit;

        Unit_Option__c unitOp = new Unit_Option__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Unit__c = unit.Id
        );
        insert unitOp;

        Account acc = new Account(Name = 'test account');
        insert acc;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id,
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(5)
        );
        insert paymentPlan;

        PaymentInstallements__c installment = new PaymentInstallements__c(
            PaymentInstallment__c = paymentPlan.Id,
            BrokerPayout__c = 10,
            Milestone__c = 10,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'test'
        );
        insert installment;

        Opportunity oppObj = new Opportunity(
            Name = 'Test opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.Today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert oppObj;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = oppObj.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c = vaObj.Id,
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed',
            TotalAmount__c = 20000
        );
        insert so;

        JointOwner__c joObj = new JointOwner__c(
            SalesOrder__c = so.Id,
            JointOwnerAccount__c = acc.Id,
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
        insert joObj;

        SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.Id,
            InstallmentAmount__c = 150,
            MilestoneDate__c = Date.today().addDays(-10)
        );
        insert sotest;
        
        SalesOrderInstallments__c sotest1 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentInstallments__c = installment.Id,
            InstallmentAmount__c = 150,
            MilestoneDate__c = Date.today().addDays(10)
        );
        insert sotest1;

        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = sotest.Id,
            InvoiceAmount__c = 1500,
           // AppliedAmount__c = 500,
            //InvoiceBalance__c = 1000,
            InvoiceDate__c = Date.today().addDays(-5)
           // InvoiceStatus__c = 'Open'
        );
        insert inv;
	
        Invoice__c inv1 = new Invoice__c(
            Account__c = acc.Id,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = sotest1.Id,
            InvoiceAmount__c = 1500,
           // AppliedAmount__c = 500,
            //InvoiceBalance__c = 1000,
            InvoiceDate__c = Date.today().addDays(5)
           // InvoiceStatus__c = 'Open'
        );
        insert inv1;
        Test.startTest();
        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id,
            Status__c = 'Cleared',
            TransactionNumber__c = 'TRX123',
            EBS_Clearing_Date__c = Date.today()
        );
        insert rec;

        Allocation__c alloc = new Allocation__c(
            Invoice__c = inv.Id,
            Receipt__c = rec.Id,
            //SalesOrderInstallment__c = sotest.Id,
            AllocationAmount__c = 500,
            Status__c = 'Applied'
        );
        insert alloc;
        
         Allocation__c alloc12 = new Allocation__c(
            Invoice__c = inv1.Id,
            Receipt__c = rec.Id,
            //SalesOrderInstallment__c = sotest.Id,
            AllocationAmount__c = 500,
            Status__c = 'Applied'
        );
        insert alloc12;

        Charge__c charge = new Charge__c(Name = 'ADM Fee', Type__c = 'ADM & Dari Fee');
        insert charge;

        Invoice__c otherInv = new Invoice__c(
            Charge__c = charge.Id,
            Sales_Order__c = so.Id,
            InvoiceAmount__c = 2000,
            Account__c =acc.id,
            //AppliedAmount__c = 1000,
            //InvoiceBalance__c = 1000,
            InvoiceDate__c = Date.today().addDays(-3)
            //InvoiceStatus__c = 'Open'
        );
        insert otherInv;

        Allocation__c otherAlloc = new Allocation__c(
            Invoice__c = otherInv.Id,
            Receipt__c = rec.Id,
            AllocationAmount__c = 1000,
            Status__c = 'Applied'
        );
        insert otherAlloc;
        Test.stopTest();
        
        Test.setCurrentPage(Page.StatementOfAccountV1);
        ApexPages.currentPage().getParameters().put('id', so.Id);
        CombinedSOAController ctrl = new CombinedSOAController();
        ctrl.downloadPDF();
        ctrl.getAllSOA();
        

    }
}