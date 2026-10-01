@isTest
public class UnitConsolidationControllerTest {
  @isTest
    static void testCreateAccounts4(){
        Project__c project = new Project__c();
        insert project;
         
                Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Unit Consolidation').getRecordTypeId();

        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '6';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        
        //insert so;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
         oppObj.UAE_Resident_Status__c = 'Resident';
		oppObj.Nationality__c = 'United Arab Emirates';
		oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
		oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.CustomerAccount__c = acc.Id;
        so.Status__c = 'Completed';
        so.TotalAmount__c = 20000;
        insert so;
        
         JointOwner__c joObj = new JointOwner__c();
        joObj.SalesOrder__c = so.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
         SalesOrderInstallments__c sotest = new SalesOrderInstallments__c(
        SalesOrder__c = so.Id,
         PaymentInstallments__c = installment.id,
            InstallmentAmount__c = 150
        );
       insert sotest;
   Invoice__c inv = new Invoice__c();
        inv.Account__c = acc.Id;
        inv.Sales_Order__c=so.Id;
        insert inv;
        
        Receipt__c rec = new Receipt__c();
        rec.Account__c = acc.Id;
        rec.Status__c = 'In Progress';
        insert rec;
        
        
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
    
        
        //List<Account> createdAccounts = PropertyTransferProcessController.createAccounts(newt);
        List<Allocation__c> newtalloc= new List<Allocation__c>();
        newtalloc.add(alloc);
        List<Invoice__c> newtinv= new List<Invoice__c>();
        newtinv.add(inv);
           Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c = testServiceRequest.Id,
            Sales_Order__c = so.Id,
            //IsConsolidated__c = true,
           // Fund_Transfer__c = true,
            Transfer_Amount__c = 150
        );
        insert uc;

        Test.startTest();
        try{
                    String result = UnitConsolidationController.processConsolidationFinancials(testServiceRequest.Id);
        }catch(exception ex){
            
        }
        Test.stopTest();  
    }
    @isTest
    static void testProcessConsolidationFinancialsWithMultipleSalesOrders() {
        // Setup
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'Test Escrow');
        insert escrow;

        Phase__c phase = new Phase__c(Project__c = project.Id, EscrowAccount__c = escrow.Id);
        insert phase;

        Account acc = new Account(Name = 'Test Buyer');
        insert acc;

        VirtualAccount__c va = new VirtualAccount__c(
            Name = 'VA1',
            Status__c = 'Available',
            EscrowAccount__c = escrow.Id,
            VirtualAccountNumber__c = 'V12345',
            VirtualIBANNumber__c = 'AE123456789'
        );
        insert va;

        // Create 3 units
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 1; i <= 3; i++) {
            units.add(new Unit__c(
                Phase__c = phase.Id,
                PlotAreasqm__c = 1.0,
                PlotNo__c = String.valueOf(i),
                Status__c = 'Available',
                UnitClassification__c = 'Villa',
        		Number_of_Bedrooms__c = '6'
            ));
        }
        insert units;

        List<PaymentPlan__c> paymentPlans = new List<PaymentPlan__c>();
        for (Unit__c u : units) {
            paymentPlans.add(new PaymentPlan__c(
                Unit__c = u.Id,
                Type__c = 'Standard',
                Status__c = 'Active',
                StartDate__c = System.today().addDays(-5),
                ExpiryDate__c = System.today().addDays(10)
            ));
        }
        insert paymentPlans;

        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(Name = 'Opp1', StageName = 'Proposal', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c = '784-1234-1234567-1'),
            new Opportunity(Name = 'Opp2', StageName = 'Proposal', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c = '784-1234-1234567-1'),
            new Opportunity(Name = 'Opp3', StageName = 'Proposal', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c = '784-1234-1234567-1')
        };
        insert opportunities;

        // Create 3 Sales Orders
        List<SalesOrder__c> soList = new List<SalesOrder__c>();
        for (Integer i = 0; i < 3; i++) {
            soList.add(new SalesOrder__c(
                Unit__c = units[i].Id,
                PaymentPlan__c = paymentPlans[i].Id,
                Opportunity__c = opportunities[i].Id,
                CustomerAccount__c = acc.Id,
                VirtualAccount__c = va.Id,
                Status__c = 'Completed',
                TotalAmount__c = 10000
            ));
        }
        insert soList;

        // Add Installments and Invoices
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
        List<Invoice__c> invoices = new List<Invoice__c>();

        for (Integer i = 0; i < soList.size(); i++) {
            SalesOrder__c so = soList[i];
            for (Integer j = 1; j <= 2; j++) {
                SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
                    SalesOrder__c = so.Id,
                    MilestoneNumber__c = j,
                    InstallmentAmount__c = 5000
                );
                installments.add(soi);
            }
        }
        insert installments;

        for (SalesOrderInstallments__c soi : installments) {
            invoices.add(new Invoice__c(
                SalesOrderInstallment__c = soi.Id,
                Account__c = acc.Id,
                InvoiceAmount__c = soi.InstallmentAmount__c,
                InvoiceDate__c = Date.today(),
                RecordTypeId = UnitConsolidationController.getRecordTypeId('Invoice__c', 'Tax_Invoice'),
                IsCancelled__c = false,
                OICIntegrationStatus__c = 'S'
            ));
        }
        insert invoices;
        
        
        // Receipt + Allocation for 1st SalesOrder first installment
        Receipt__c rec = new Receipt__c(Account__c = acc.Id, Status__c = 'Cleared', TotalAmount__c = 5000, SalesOrderInstallment__c = installments[0].Id, EBS_Clearing_Date__c = Date.today()+ 15);
        insert rec;

        Allocation__c alloc = new Allocation__c(
            Invoice__c = invoices[0].Id, // Linked to 1st SO, 1st Installment
            Receipt__c = rec.Id,
            AllocationAmount__c = 5000
        );
        insert alloc;
        List<SalesOrder__c> updatedso= new List<SalesOrder__c>();
        Set<Id> updatedIds= new Set<Id>();
        for(SalesOrder__c so: soList){
            so.Status__c='Completed';
            updatedso.add(so);
            updatedIds.add(so.Id);
        }
        update updatedso;
        // ServiceRequest
        Id srRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Unit Consolidation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = srRecordTypeId,
            SalesOrder__c = soList[0].Id,
            Description__c = 'Consolidation Request'
        );
        insert sr;

        // Unit Consolidation: One consolidated (paid), two as fund transfer (unpaid)
        List<Unit_Consolidation__c> ucs = new List<Unit_Consolidation__c>{
            new Unit_Consolidation__c(Service_Request__c = sr.Id, Sales_Order__c = soList[0].Id, IsConsolidated__c = true,Secondary_Market_Value__c = 10000 ),
            new Unit_Consolidation__c(Service_Request__c = sr.Id, Sales_Order__c = soList[1].Id, Fund_Transfer__c = true, Transfer_Amount__c = 2500),
            new Unit_Consolidation__c(Service_Request__c = sr.Id, Sales_Order__c = soList[2].Id, Fund_Transfer__c = true, Transfer_Amount__c = 2500)
        };
        insert ucs;
         Invoice__c debit =new Invoice__c(
                    RecordTypeId = UnitConsolidationController.getRecordTypeId('Invoice__c', 'Debit_Memo'),
                    Sales_Order__c = soList[0].Id,
                    Account__c = acc.Id,
                    InvoiceAmount__c = 5000,
                    InvoiceDate__c = Date.today(),
                    OICIntegrationStatus__c = 'S'
                );
        insert debit;
        CreditNote__c crn= new CreditNote__c(
                    Invoice__c = debit.Id,
                    Amount__c = 5000,
                    Source__c = 'Property Sales Invoice',
                    Sales_Order__c = soList[0].Id,
                    Approval_Status__c = 'Approved',
                    ApprovalDate__c = Date.today(),
                    IntegrationStatus__c = 'Success'
                );
        insert crn;
        // Execute
        Test.startTest();
         try{
                    String result = UnitConsolidationController.processConsolidationFinancials(sr.Id);
        }catch(exception ex){
            
        }
        UnitConsolidationController.cancelOldSalesOrderHierarchy(updatedIds); 
        Test.stopTest();
    }
    
    @isTest
    static void testProcessConsolidationFinancials() {
    // Setup
    Project__c project = new Project__c(Name = 'Test Project');
    insert project;

    EscrowAccount__c escrow = new EscrowAccount__c(Name = 'Test Escrow');
    insert escrow;

    Phase__c phase = new Phase__c(Project__c = project.Id, EscrowAccount__c = escrow.Id);
    insert phase;

    Account acc = new Account(Name = 'Test Buyer');
    insert acc;

    VirtualAccount__c va = new VirtualAccount__c(
        Name = 'VA1',
        Status__c = 'Available',
        EscrowAccount__c = escrow.Id,
        VirtualAccountNumber__c = 'V12345',
        VirtualIBANNumber__c = 'AE123456789'
    );
    insert va;

    // Create 3 units
    List<Unit__c> units = new List<Unit__c>();
    for (Integer i = 1; i <= 3; i++) {
        units.add(new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = String.valueOf(i),
            Status__c = 'Available',
            UnitClassification__c = 'Villa',
        	Number_of_Bedrooms__c = '6'
        ));
    }
    insert units;

    // Payment Plans
    List<PaymentPlan__c> paymentPlans = new List<PaymentPlan__c>();
    for (Unit__c u : units) {
        paymentPlans.add(new PaymentPlan__c(
            Unit__c = u.Id,
            Type__c = 'Standard',
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-5),
            ExpiryDate__c = System.today().addDays(10)
        ));
    }
    insert paymentPlans;

    // Opportunities
    List<Opportunity> opportunities = new List<Opportunity>{
        new Opportunity(Name = 'Opp1', StageName = 'Proposal', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c = '784-1234-1234567-1'),
        new Opportunity(Name = 'Opp2', StageName = 'Proposal', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c = '784-1234-1234567-1'),
        new Opportunity(Name = 'Opp3', StageName = 'Proposal', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c = '784-1234-1234567-1')
    };
    insert opportunities;

    // Sales Orders
    List<SalesOrder__c> soList = new List<SalesOrder__c>();
    for (Integer i = 0; i < 3; i++) {
        soList.add(new SalesOrder__c(
            Unit__c = units[i].Id,
            PaymentPlan__c = paymentPlans[i].Id,
            Opportunity__c = opportunities[i].Id,
            CustomerAccount__c = acc.Id,
            VirtualAccount__c = va.Id,
            Status__c = 'Completed',
            TotalAmount__c = 10000
        ));
    }
    insert soList;

    // Installments and Invoices
    List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
    List<Invoice__c> invoices = new List<Invoice__c>();

    for (Integer i = 0; i < soList.size(); i++) {
        for (Integer j = 1; j <= 2; j++) {
            SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
                SalesOrder__c = soList[i].Id,
                MilestoneNumber__c = j,
                InstallmentAmount__c = 5000,
                PaymentStatus__c = (i == 0 && j == 1) ? 'Paid' : 'Not Paid'
            );
            installments.add(soi);
        }
    }
    insert installments;

    for (SalesOrderInstallments__c soi : installments) {
        invoices.add(new Invoice__c(
            SalesOrderInstallment__c = soi.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = soi.InstallmentAmount__c,
            InvoiceDate__c = Date.today(),
            RecordTypeId = UnitConsolidationController.getRecordTypeId('Invoice__c', 'Tax_Invoice'),
            IsCancelled__c = false,
            OICIntegrationStatus__c = 'S'
        ));
    }
    insert invoices;

    // Receipt + Allocation for SO1 first installment
    Receipt__c rec = new Receipt__c(
        Account__c = acc.Id,
        Status__c = 'Cleared',
        TotalAmount__c = 5000,
        SalesOrderInstallment__c = installments[0].Id,
        SalesOrder__c = soList[0].Id,
         EBS_Clearing_Date__c = Date.today()+ 15
    );
    insert rec;

    Allocation__c alloc = new Allocation__c(
        Invoice__c = invoices[0].Id,
        Receipt__c = rec.Id,
        AllocationAmount__c = 5000
    );
    insert alloc;
 List<SalesOrder__c> updatedso= new List<SalesOrder__c>();
        Set<Id> updatedIds= new Set<Id>();
        for(SalesOrder__c so: soList){
            so.Status__c='Completed';
            updatedso.add(so);
            updatedIds.add(so.Id);
        }
        update updatedso;
    // Service Request
    Id srRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Unit Consolidation').getRecordTypeId();
    ServiceRequest__c sr = new ServiceRequest__c(
        RecordTypeId = srRecordTypeId,
        SalesOrder__c = soList[0].Id,
        Description__c = 'Consolidation Request'
    );
    insert sr;

    // Unit Consolidation Records
    List<Unit_Consolidation__c> ucs = new List<Unit_Consolidation__c>{
        new Unit_Consolidation__c(Service_Request__c = sr.Id, Sales_Order__c = soList[0].Id, IsConsolidated__c = true, Secondary_Market_Value__c = 10000),
        new Unit_Consolidation__c(Service_Request__c = sr.Id, Sales_Order__c = soList[1].Id, Fund_Transfer__c = true, Transfer_Amount__c = 2500),
        new Unit_Consolidation__c(Service_Request__c = sr.Id, Sales_Order__c = soList[2].Id, Fund_Transfer__c = true, Transfer_Amount__c = 2500)
    };
    insert ucs;

    // Debit Memos for ALL SOs to fund allocations
    List<Invoice__c> debitMemos = new List<Invoice__c>();
    for (SalesOrder__c so : soList) {
        debitMemos.add(new Invoice__c(
            RecordTypeId = UnitConsolidationController.getRecordTypeId('Invoice__c', 'Debit_Memo'),
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 10000,
            InvoiceDate__c = Date.today(),
            OICIntegrationStatus__c = 'S',
            IsCancelled__c = false
        ));
    }
    insert debitMemos;

    // Run Test
    Test.startTest();
    String result;
    try {
        result = UnitConsolidationController.processConsolidationFinancials(sr.Id);
    } catch (Exception e) {
        System.debug('Unexpected error: ' + e.getMessage());
    }
    Test.stopTest();
}


}