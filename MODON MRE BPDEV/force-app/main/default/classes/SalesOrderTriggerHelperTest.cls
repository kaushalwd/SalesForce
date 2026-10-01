@isTest
public class SalesOrderTriggerHelperTest {
    private class SalesOrderHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            return res;
        }
    }

    @isTest
    static void myTestmethod(){
        Project__c project = new Project__c();
        insert project;
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        insert unit;
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
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
        oppObj.AccountId = acc.id;
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.TODAY();
        oppObj.EIDNumber__c = '784-1990-1234567-8';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        oppObj.En_EIDNumber__c = '784-1990-1234567-8';
        INSERT oppObj;
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 50;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c = acc.id;
        INSERT so;
        SalesOrder__c soOld = so;
        soOld.TotalAmount__c = 154687.60;
        soOld.Status__c = 'Cancelled';
        Test.startTest();
        SalesOrderTriggerHelper.updatUnitStatusBasedonSOStatus(new list<SObject>{soOld}, new Map<Id, sObject>{so.Id => soOld}, new list<SObject>{so}, new Map<Id, sObject>{so.Id => so});
        Utilities.amountInWords(soOld.TotalAmount__c, 'dirhams', 'fils');
        Test.stopTest();
        UPDATE so;
        DELETE so;
    }

    @isTest
    static void myTestmethod1(){
        Project__c project = new Project__c();
        insert project;
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Plot';
        unit.Number_of_Bedrooms__c = '2';
        insert unit;
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        Contact con = new Contact();
        con.FirstName = 'ConFirst';
        con.LastName = 'ConLast';
        con.Email = 'con@test.com';
        con.Phone = '23423424';
        con.MobilePhone = '234342343';
        con.AccountId = acc.Id;
        insert con;
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
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
        oppObj.AccountId = acc.id;
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.TODAY();
        oppObj.EIDNumber__c = '784-1990-1234567-8';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        oppObj.En_EIDNumber__c = '784-1990-1234567-8';
        INSERT oppObj;
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 50;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c = acc.id;
        INSERT so;
        test.starttest();
        SalesOrder__c oldSo = [SELECT Id, PaymentPlan__c,Status__c,Opportunity__c,TotalAmount__c,Unit__c,CustomerType__c,CreatedDate FROM SalesOrder__c WHERE Id =: so.Id];
        SalesOrder__c soOld = so;
        soOld.TotalAmount__c = 154687.60;
        soOld.Status__c = 'Cancelled';
        update soOld;
        SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c = so.Id;
        soInstallmentObj.Milestone__c = 1;
        soInstallmentObj.MilestoneNumber__c = 1;
        INSERT soInstallmentObj;
        Invoice__c invoiceObj = new Invoice__c();
        invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
        invoiceObj.InvoiceAmount__c = 10000;
        invoiceObj.Account__c = acc.Id;
        INSERT invoiceObj;
        Receipt__c receiptObj = new Receipt__c();
        receiptObj.TotalAmount__c = 1000;
        receiptObj.Account__c = acc.Id;
        receiptObj.SalesOrderInstallment__c = soInstallmentObj.Id;
        receiptObj.SalesOrder__c = so.Id;
        receiptObj.TransactionDate__c = system.now();
        INSERT receiptObj;
        Receipt__c receiptObj1 = new Receipt__c();
        receiptObj1.TotalAmount__c = 1000;
        receiptObj1.Account__c = acc.Id;
        receiptObj1.SalesOrder__c = so.Id;
        receiptObj1.TransactionDate__c = system.now();
        INSERT receiptObj1;
        Allocation__c allocationObj = new Allocation__c();
        allocationObj.Invoice__c = invoiceObj.Id;
        allocationObj.AllocationAmount__c = 300;
        allocationObj.Status__c = 'Applied';
        allocationObj.Receipt__c = receiptObj.Id;
        INSERT allocationObj;
        SalesOrder__c newSO = [SELECT Id, SPAStatus__c, PaymentPlan__c,Down_Payment_Status__c,Status__c,Opportunity__c,Unit__c,TotalAmount__c,CustomerType__c,CreatedDate FROM SalesOrder__c WHERE Id =: soOld.Id];
        SalesOrder__c solst = [SELECT Id, Unit__c, SPAStatus__c FROM SalesOrder__c WHERE Id = :so.Id];
        List<SObject> soList = new List<SObject>{solst};
        List<SObject> soList1 = new List<SObject>{so};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ soOld.Id => soOld };
        SalesOrderTriggerHelper.setOwner(new List<SalesOrder__c>{newSO}, new Map<Id, SObject>{oldSo.Id => oldSo});
        SalesOrderTriggerHelper.updatUnitStatusBasedonSOStatus(new List<SalesOrder__c>{newSO}, null, null, new Map<Id, SObject>{oldSo.Id => oldSo});
        SalesOrderTriggerHelper.fillBucketOnSalesOrder(soList);
        SalesOrderTriggerHelper.removeBucketOnSalesOrderUnit(soList);
        SalesOrderTriggerHelper.sendGrid(soList1, oldMap);
        test.stoptest();
    }

   /* @isTest
    static void testSalesOrderCustEmail() {
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;
        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'A101',
            UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3');
        insert unit;
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting',
            CloseDate = Date.today(), AccountId = acc.Id, UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates', EmiratesIDExpiryDate__c = Date.TODAY(),
            EIDNumber__c = '784-1990-1234567-8');
        insert opp;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, Opportunity__c = opp.Id,
            PaymentPlan__c = plan.Id, Status__c = 'In Progress',
            SPAStatus__c = 'Pending with Customer', CustomerAccount__c = acc.Id);
        insert so;
        SalesOrder__c oldSO = new SalesOrder__c(Id = so.Id, IsDownPaymentCollected__c = false);
        so.IsDownPaymentCollected__c = true;
        Test.setMock(HttpCalloutMock.class, new SalesOrderHttpMock());
        Test.startTest();
        SalesOrderTriggerHelper.salesOrderCustEmail(new List<SalesOrder__c>{so}, new List<SalesOrder__c>{oldSO});
        Test.stopTest();
    }*/

    @isTest
    static void testDirectBeforeHelperMethods() {
        Account normalAccount = new Account(Name = 'Normal Customer');
        Account defaultedAccount = new Account(Name = 'Defaulted Customer', Customer_Defaulted__c = true);
        insert new List<Account>{ normalAccount, defaultedAccount };
        Project__c project = new Project__c(Name = 'Direct Coverage Project');
        insert project;
        Phase__c phase = new Phase__c(Name = 'Direct Coverage Phase', Project__c = project.Id);
        insert phase;
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'DIR-1',
            UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3');
        insert unit;
        PaymentPlan__c paymentPlan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert paymentPlan;
        Opportunity opp = new Opportunity(Name = 'Direct Coverage Opportunity',
            StageName = 'Discussion In Progress', CloseDate = Date.today(),
            AccountId = normalAccount.Id, UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates', EmiratesIDExpiryDate__c = Date.today(),
            EIDNumber__c = '784-1990-1234567-8');
        insert opp;
        SalesOrder__c baseSo = new SalesOrder__c(Unit__c = unit.Id, Opportunity__c = opp.Id,
            PaymentPlan__c = paymentPlan.Id, CustomerAccount__c = normalAccount.Id,
            Status__c = 'In Progress');
        insert baseSo;
        SalesOrder__c oldCompletedSo = new SalesOrder__c(Id = baseSo.Id, Status__c = 'In Progress',
            Email_Reminder__c = null, CustomerType__c = 'Regular');
        SalesOrder__c completedSo = new SalesOrder__c(Id = oldCompletedSo.Id, Status__c = 'Completed',
            Email_Reminder__c = 'Reminder 1', CustomerType__c = 'Regular',
            CustomerAccount__c = normalAccount.Id);
        Test.startTest();
        SalesOrderTriggerHelper.populateCompletionDate(
            new List<SObject>{ completedSo },
            new Map<Id, SObject>{ oldCompletedSo.Id => oldCompletedSo }
        );
        SalesOrderTriggerHelper.updateCommaSeparatedField(new List<SObject>{ completedSo });
        SalesOrderTriggerHelper.populateAmountText(new List<SObject>{
            new SalesOrder__c(Source_Entity__c = 'Modon - Egypt', CurrencyISOCode = 'USD', TotalAmount__c = 10, Totalpaidamount__c = 5),
            new SalesOrder__c(Source_Entity__c = 'Modon - Egypt', CurrencyISOCode = 'EUR', TotalAmount__c = 20, Totalpaidamount__c = 10),
            new SalesOrder__c(Source_Entity__c = 'Modon - Egypt', CurrencyISOCode = 'SAR', TotalAmount__c = 30, Totalpaidamount__c = 15),
            new SalesOrder__c(Source_Entity__c = 'Modon - UAE', CurrencyISOCode = 'AED', TotalAmount__c = 40, Totalpaidamount__c = 20)
        });
        SalesOrderTriggerHelper.createNewServiceRequestBasedOnSoStatus(new List<SalesOrder__c>{
            new SalesOrder__c(Status__c = 'Completed', SPAStatus__c = 'SPA Signed (Modon)', is_Transferred_SO__c = true),
            new SalesOrder__c(Status__c = 'In Progress', SPAStatus__c = 'SPA Signed (Modon)', is_Transferred_SO__c = false)
        });
        SalesOrderTriggerHelper.processXeboSalesOrder(
            new List<SObject>{ new SalesOrder__c(Id = completedSo.Id,
                Status__c = ModonEgyptConstants.SALES_ORDER_STATUS_DOWNPAYMENT_COLLECTED,
                Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY,
                CustomerAccount__c = normalAccount.Id) },
            new Map<Id, SObject>{ completedSo.Id => new SalesOrder__c(Id = completedSo.Id, Status__c = 'In Progress') }
        );
        Test.stopTest();
        System.assertEquals(System.today(), completedSo.SOCompletion_Date__c, 'Completion date should be populated.');
        System.assertNotEquals(null, completedSo.SearchHelper__c, 'Search helper should be populated.');
        SalesOrder__c defaultedSo = new SalesOrder__c(CustomerAccount__c = defaultedAccount.Id);
        SalesOrderTriggerHelper.PreventSalesOrderForDefaulted(new List<SalesOrder__c>{ defaultedSo });
        System.assertEquals(1, defaultedSo.getErrors().size(), 'Defaulted account should throw error.');
    }

    @isTest
    static void testDocumentJointOwnerAndSharingBranches() {
        Project__c project = new Project__c(Name = 'Coverage Project');
        insert project;
        Phase__c phase = new Phase__c(Name = 'Coverage Phase', Project__c = project.Id);
        insert phase;
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'COV-1',
            UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3');
        insert unit;
        Account account = new Account(Name = 'Coverage Account');
        insert account;
        Opportunity opp = new Opportunity(Name = 'Coverage Opportunity',
            StageName = 'Discussion In Progress', CloseDate = Date.today(),
            AccountId = account.Id, UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates', EmiratesIDExpiryDate__c = Date.today(),
            EIDNumber__c = '784-1990-1234567-8', En_Nationality__c = 'India',
            En_PassportNumber__c = 'P1234567', En_EIDNumber__c = '784-1990-1234567-8');
        insert opp;
        JointOwner__c opportunityJointOwner = new JointOwner__c(Opportunity__c = opp.Id,
            JointOwnerAccount__c = account.Id, OwnershipPercentage__c = 50,
            RelationshipType__c = 'Partner', RelationshipSubType__c = 'Sibling');
        insert opportunityJointOwner;
        PaymentPlan__c paymentPlan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert paymentPlan;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, Opportunity__c = opp.Id,
            PaymentPlan__c = paymentPlan.Id, CustomerAccount__c = account.Id,
            Status__c = 'In Progress', Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY);
        insert so;
        Test.startTest();
        SalesOrderTriggerHelper.createDocumentRecords(new List<SObject>{ so });
        SalesOrderTriggerHelper.createModonEgyptDocumentRecords(new List<SObject>{ so });
        SalesOrderTriggerHelper.shareVIPSalesOrder(new Map<Id, SObject>{ so.Id => so });
        SalesOrderTriggerHelper.fillBucketOnSalesOrder(new List<SObject>{ so });
        SalesOrderTriggerHelper.removeBucketOnSalesOrderUnit(new List<SObject>{ so });
        Test.stopTest();
    }

    @isTest
    static void testAdditionalBranchCoverage() {
        Account account = new Account(Name = 'Additional Coverage Account');
        insert account;
        Project__c project = new Project__c(Name = 'Additional Coverage Project');
        insert project;
        Phase__c phase = new Phase__c(Name = 'Additional Coverage Phase', Project__c = project.Id);
        insert phase;
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'ADD-1',
            UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '2');
        insert unit;
        PaymentPlan__c paymentPlan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert paymentPlan;
        Opportunity opp = new Opportunity(Name = 'Additional Coverage Opportunity',
            StageName = 'Discussion In Progress', CloseDate = Date.today(),
            AccountId = account.Id, UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates', EmiratesIDExpiryDate__c = Date.today(),
            EIDNumber__c = '784-1990-1234567-8');
        insert opp;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, Opportunity__c = opp.Id,
            PaymentPlan__c = paymentPlan.Id, CustomerAccount__c = account.Id,
            Status__c = 'In Progress', Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY);
        insert so;
        SalesOrder__c oldCompleted = new SalesOrder__c(Id = so.Id, Status__c = 'Completed');
        SalesOrder__c reopened = new SalesOrder__c(Id = so.Id, Status__c = 'In Progress', SOCompletion_Date__c = Date.today());
        SalesOrder__c emailNoChangeOld = new SalesOrder__c(Id = so.Id, Email_Reminder__c = 'Same');
        SalesOrder__c emailNoChangeNew = new SalesOrder__c(Id = so.Id, Email_Reminder__c = 'Same');
        SalesOrder__c salesOrderWithoutUnit = new SalesOrder__c(Id = so.Id, Status__c = 'Cancelled', Unit__c = null);
        SalesOrder__c oldSalesOrderWithoutUnit = new SalesOrder__c(Id = so.Id, Status__c = 'In Progress', Unit__c = null);
        Test.startTest();
        SalesOrderTriggerHelper.populateCompletionDate(
            new List<SObject>{ reopened },
            new Map<Id, SObject>{ oldCompleted.Id => oldCompleted }
        );
        SalesOrderTriggerHelper.sendGrid(
            new List<SObject>{ emailNoChangeNew },
            new Map<Id, SObject>{ emailNoChangeOld.Id => emailNoChangeOld }
        );
        SalesOrderTriggerHelper.updatUnitStatusBasedonSOStatus(
            new List<SObject>{ salesOrderWithoutUnit },
            new Map<Id, SObject>{ salesOrderWithoutUnit.Id => salesOrderWithoutUnit },
            new List<SObject>{ oldSalesOrderWithoutUnit },
            new Map<Id, SObject>{ oldSalesOrderWithoutUnit.Id => oldSalesOrderWithoutUnit }
        );
       // SalesOrderTriggerHelper.salesOrderCustEmail(new List<SalesOrder__c>(), new List<SalesOrder__c>());
        SalesOrderTriggerHelper.PreventSalesOrderForDefaulted(new List<SalesOrder__c>{
            new SalesOrder__c(CustomerAccount__c = null)
        });
        SalesOrderTriggerHelper.processXeboSalesOrder(new List<SObject>(), null);
        SalesOrderTriggerHelper.processXeboSalesOrder(
            new List<SObject>{ new SalesOrder__c(Id = so.Id, Status__c = 'In Progress') }, null);
        SalesOrderTriggerHelper.sendSalesOrdersToOracle(
            new Map<Id, SObject>{ so.Id => new SalesOrder__c(Id = so.Id, Status__c = 'In Progress', TotalAmount__c = 100, Down_Payment_Status__c = 'Pending') },
            new Map<Id, SObject>{ so.Id => new SalesOrder__c(Id = so.Id, Status__c = 'In Progress', TotalAmount__c = 100, Down_Payment_Status__c = 'Pending') }
        );
        Test.stopTest();
        System.assertEquals(null, reopened.SOCompletion_Date__c, 'Completion date should clear.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW TESTS - Arvind - 06 Jun 2026 - Coverage increase to 90%+
    // testEgyptInvoiceReceiptSyncCoverage REMOVED — syncAllEgyptInvoicesAndReceipts
    // does not exist in prod SalesOrderTriggerHelper.
    // Added: testPdcSLA, testManageJointOwner to replace and boost coverage.
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testPdcSLA() {
        Project__c project = new Project__c(Name = 'PdcSLA Project');
        insert project;
        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotNo__c = 'PdcSLA-1',
            UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '2', PlotAreasqm__c = 100);
        insert unit;
        Account acc = new Account(Name = 'PdcSLA Acc');
        insert acc;
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;
        Opportunity opp = new Opportunity(Name = 'PdcSLA Opp',
            StageName = 'Discussion In Progress', CloseDate = Date.today(),
            AccountId = acc.Id, UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates', EmiratesIDExpiryDate__c = Date.today(),
            EIDNumber__c = '784-1990-1234567-8');
        insert opp;
        List<SalesOrder__c> soList = new List<SalesOrder__c>();
        for (String sub : new List<String>{
            'Pending with Sales', 'Pending With Sales Operation',
            'Under Finance Verification', 'Pending with CM', 'Down Payment Collected'
        }) {
            soList.add(new SalesOrder__c(
                Unit__c = unit.Id, Opportunity__c = opp.Id, PaymentPlan__c = plan.Id,
                CustomerAccount__c = acc.Id, Status__c = 'In Progress',
                Sub_Status__c = sub, Is_Sales_Checklist_Completed__c = false
            ));
        }
        insert soList;
        List<SObject> soObjList = new List<SObject>();
        soObjList.addAll([SELECT Id, Sub_Status__c, Status__c, Is_Sales_Checklist_Completed__c
             FROM SalesOrder__c WHERE Id IN :soList]);
        Test.startTest();
        SalesOrderTriggerHelper.pdcSLA(soObjList);
        Test.stopTest();
    }

    @isTest
    static void testManageJointOwner() {
        Project__c project = new Project__c(Name = 'JointOwner Project');
        insert project;
        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotNo__c = 'JO-1',
            UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '2', PlotAreasqm__c = 100);
        insert unit;
        Account acc = new Account(Name = 'JointOwner Acc');
        insert acc;
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;
        Opportunity opp = new Opportunity(Name = 'JointOwner Opp',
            StageName = 'Discussion In Progress', CloseDate = Date.today(),
            AccountId = acc.Id, UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates', EmiratesIDExpiryDate__c = Date.today(),
            EIDNumber__c = '784-1990-1234567-8', En_Nationality__c = 'India',
            En_PassportNumber__c = 'P1234567', En_EIDNumber__c = '784-1990-1234567-8');
        insert opp;
        JointOwner__c jo = new JointOwner__c(Opportunity__c = opp.Id,
            JointOwnerAccount__c = acc.Id, OwnershipPercentage__c = 10,
            RelationshipType__c = 'Partner', RelationshipSubType__c = 'Sibling');
        insert jo;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, Opportunity__c = opp.Id,
            PaymentPlan__c = plan.Id, CustomerAccount__c = acc.Id, Status__c = 'In Progress');
        insert so;
        Test.startTest();
        SalesOrderTriggerHelper.manageJointOwner(new List<SObject>{ so });
        Test.stopTest();
    }

    @isTest
    static void testSOEgyptCurrency(){
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account testAccount = new Account();
        testAccount.FirstName = 'Test';
        testAccount.LastName = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test2.com';
        insert testAccount;
        Contact conObj = new Contact();
        conObj.LastName = 'Test contact';
        conObj.Email = 'test@test.com';
        INSERT conObj;
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.PrimaryContact__c = conObj.Id;
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.EIDNumber__c = '784-1987-1234567-8';
        oppObj.EmiratesIDExpiryDate__c = system.today();
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        oppObj.En_EIDNumber__c = '784-1990-1234567-8';
        insert oppObj;
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        phase__c phase = new phase__c(name='Test Phase', EscrowAccount__c = escAccount.id);
        insert phase;
        Unit__c unit = new Unit__c(name = 'Test Unit', Phase__c = phase.id, PlotNo__c = '123',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment');
        insert unit;
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.id;
        so.TotalAmount__c = 100;
        so.CurrencyISOCode = 'EGP';
        insert so;
    }

    /**
     * FIX - Arvind Kesharwani - 09 Aug 2026
     * Original version inserted 4 SalesOrder__c records all pointing at the SAME
     * Unit__c. As of v13.0 (SalesOrderTriggerHelper.validateUnitAvailability),
     * a Unit can only have one active (non-Cancelled/Voided) Sales Order at a
     * time, so the 2nd+ insert in this test threw:
     *   FIELD_CUSTOM_VALIDATION_EXCEPTION, Unit is not available for booking.
     * Fix: give each Sales Order its own Unit so they don't collide. No other
     * logic in the test changed.
     */
    @isTest
    static void testPopulateAmountText() {
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;
        Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = project.Id);
        insert phase;

        // Arvind Kesharwani - 09 Aug 2026 : one Unit per Sales Order to satisfy
        // v13.0 validateUnitAvailability (no two active SOs on the same Unit).
        Unit__c unit1 = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'U-100',
            UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '2');
        Unit__c unit2 = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'U-101',
            UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '2');
        Unit__c unit3 = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100, PlotNo__c = 'U-102',
            UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '2');
        insert new List<Unit__c>{ unit1, unit2, unit3 };

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Opportunity opp = new Opportunity(Name = 'Test Opportunity',
            StageName = 'Discussion In Progress', CloseDate = System.today(), AccountId = acc.Id);
        insert opp;
        List<SalesOrder__c> soList = new List<SalesOrder__c>{
            new SalesOrder__c(Unit__c=unit1.Id, Opportunity__c=opp.Id, CustomerAccount__c=acc.Id,
                Source_Entity__c='Modon - Egypt', CurrencyISOCode='EGP', TotalAmount__c=100, Totalpaidamount__c=50),
            new SalesOrder__c(Unit__c=unit2.Id, Opportunity__c=opp.Id, CustomerAccount__c=acc.Id,
                Source_Entity__c='Modon - UAE', CurrencyISOCode='AED', TotalAmount__c=200),
            new SalesOrder__c(Unit__c=unit3.Id, Opportunity__c=opp.Id, CustomerAccount__c=acc.Id,
                Source_Entity__c='Modon - UAE', CurrencyISOCode='USD', TotalAmount__c=200)
        };
        insert soList;
        List<SObject> soSObjectList = new List<SObject>();
        soSObjectList.addAll(soList);
        Test.startTest();
        SalesOrderTriggerHelper.populateAmountText(soSObjectList);
        Test.stopTest();
    }

    @isTest
    static void testSendCounterSignedSPA() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Discussion In Progress',
            CloseDate = System.today(), AccountId = acc.Id);
        insert opp;
        Unit__c unit = new Unit__c(PlotNo__c = 'U-1', UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2');
        insert unit;
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;
        SalesOrder__c so = new SalesOrder__c(Unit__c=unit.Id, Opportunity__c=opp.Id,
            PaymentPlan__c=plan.Id, CustomerAccount__c=acc.Id, Status__c='In Progress');
        insert so;
        SalesOrder__c oldSo = [SELECT Id, Status__c FROM SalesOrder__c WHERE Id = :so.Id];
        so.Status__c = 'Completed';
        update so;
        SalesOrder__c newSo = [SELECT Id, Status__c FROM SalesOrder__c WHERE Id = :so.Id];
        List<SObject> newList = new List<SObject>{ newSo };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldSo.Id => oldSo };
        Test.startTest();
        SalesOrderTriggerHelper.sendCounterSignedSPA(newList, null, null, oldMap);
        Test.stopTest();
    }
}