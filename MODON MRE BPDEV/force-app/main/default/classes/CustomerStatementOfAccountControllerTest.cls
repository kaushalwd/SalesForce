@IsTest
private class CustomerStatementOfAccountControllerTest {

    @testSetup
    static void setupData() {

        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        EscrowAccount__c escrowAccount = new EscrowAccount__c(Name = 'Test Escrow Account');
        insert escrowAccount;

        VirtualAccount__c virtualAccount = new VirtualAccount__c(
            Name = 'Test Virtual Account',
            Status__c = 'Available',
            EscrowAccount__c = escrowAccount.Id,
            VirtualAccountNumber__c = '124567642',
            VirtualIBANNumber__c = 'AE3456789456789'
        );
        insert virtualAccount;

        String phaseOptions =
            '[{"picklistOptions":["Light","Dark"],' +
            '"picklistLable":"Fit out palette",' +
            '"picklistApiName":"FitoutPalete__c"}]';

        Phase__c phase = new Phase__c(
            Project__c = project.Id,
            EscrowAccount__c = escrowAccount.Id,
            PhaseOptions__c = phaseOptions
        );
        insert phase;

        Map<String, Schema.SObjectField> unitFieldMap =
            Schema.SObjectType.Unit__c.fields.getMap();

        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 1; i <= 2; i++) {
            Unit__c unit = new Unit__c(
                Phase__c = phase.Id,
                PlotAreasqm__c = 1,
                PlotNo__c = 'PLOT-00' + i,
                Status__c = 'Available',
                BlockedFor__c = UserInfo.getUserId(),
                BlockedBy__c = UserInfo.getUserId(),
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '9'
            );

            if (unitFieldMap.containsKey('Type__c') &&
                unitFieldMap.get('Type__c').getDescribe().isCreateable()) {
                unit.put('Type__c', 'Villa');
            }
            if (unitFieldMap.containsKey('District__c') &&
                unitFieldMap.get('District__c').getDescribe().isCreateable()) {
                unit.put('District__c', 'Test District');
            }
            units.add(unit);
        }
        insert units;

        Account customerAccount = new Account(Name = 'Primary Customer');
        insert customerAccount;

        Account emptyAccount = new Account(Name = 'Customer Without Orders');
        insert emptyAccount;

        Account jointOwnerAccount = new Account(Name = 'Joint Owner Customer');
        insert jointOwnerAccount;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = units[0].Id,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-30),
            ExpiryDate__c = Date.today().addDays(365)
        );
        insert paymentPlan;

        PaymentInstallements__c paymentInstallment1 = new PaymentInstallements__c(
            PaymentInstallment__c = paymentPlan.Id,
            BrokerPayout__c = 10,
            Milestone__c = 10,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Past Milestone'
        );
        PaymentInstallements__c paymentInstallment2 = new PaymentInstallements__c(
            PaymentInstallment__c = paymentPlan.Id,
            BrokerPayout__c = 10,
            Milestone__c = 20,
            MilestoneNumber__c = 2,
            MilestoneDescription__c = 'Future Milestone'
        );
        insert new List<PaymentInstallements__c>{ paymentInstallment1, paymentInstallment2 };

        Opportunity opportunity = new Opportunity(
            Name = 'SOA Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert opportunity;

        Map<String, Schema.SObjectField> salesOrderFieldMap =
            Schema.SObjectType.SalesOrder__c.fields.getMap();

        // Sales Order 1 - full payment plan / invoices / receipts
        SalesOrder__c salesOrder1 = new SalesOrder__c(
            Unit__c = units[0].Id,
            Opportunity__c = opportunity.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c = virtualAccount.Id,
            CustomerAccount__c = customerAccount.Id,
            Status__c = 'Completed',
            TotalAmount__c = 20000
        );

        // Sales Order 2 - same customer, different unit / project (exercises sort + aggregation)
        SalesOrder__c salesOrder2 = new SalesOrder__c(
            Unit__c = units[1].Id,
            Opportunity__c = opportunity.Id,
            VirtualAccount__c = virtualAccount.Id,
            CustomerAccount__c = customerAccount.Id,
            Status__c = 'Completed',
            TotalAmount__c = 15000
        );

        if (salesOrderFieldMap.containsKey('SOCreationDate__c') &&
            salesOrderFieldMap.get('SOCreationDate__c').getDescribe().isCreateable()) {
            salesOrder1.put('SOCreationDate__c', Date.today().addDays(-60));
            salesOrder2.put('SOCreationDate__c', Date.today().addDays(-40));
        }
        if (salesOrderFieldMap.containsKey('ProjectName__c') &&
            salesOrderFieldMap.get('ProjectName__c').getDescribe().isCreateable()) {
            salesOrder1.put('ProjectName__c', 'Test Project');
            salesOrder2.put('ProjectName__c', 'Test Project');
        }

        insert new List<SalesOrder__c>{ salesOrder1, salesOrder2 };

        JointOwner__c jointOwner = new JointOwner__c(
            SalesOrder__c = salesOrder1.Id,
            JointOwnerAccount__c = jointOwnerAccount.Id,
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
        insert jointOwner;

        SalesOrderInstallments__c pastInstallment = new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder1.Id,
            PaymentInstallments__c = paymentInstallment1.Id,
            InstallmentAmount__c = 1500,
            MilestoneDate__c = Date.today().addDays(-10)
        );
        SalesOrderInstallments__c futureInstallment = new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder1.Id,
            PaymentInstallments__c = paymentInstallment2.Id,
            InstallmentAmount__c = 1500,
            MilestoneDate__c = Date.today().addDays(10)
        );
        insert new List<SalesOrderInstallments__c>{ pastInstallment, futureInstallment };

        Invoice__c pastInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = salesOrder1.Id,
            SalesOrderInstallment__c = pastInstallment.Id,
            InvoiceAmount__c = 1500,
            InvoiceDate__c = Date.today().addDays(-5)
        );
        Invoice__c futureInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = salesOrder1.Id,
            SalesOrderInstallment__c = futureInstallment.Id,
            InvoiceAmount__c = 1500,
            InvoiceDate__c = Date.today().addDays(5)
        );
        insert new List<Invoice__c>{ pastInvoice, futureInvoice };

        Receipt__c clearedReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            Status__c = 'Cleared',
            TransactionNumber__c = 'TRX-CLEARED-001',
            EBS_Clearing_Date__c = Date.today()
        );
        insert clearedReceipt;

        insert new List<Allocation__c>{
            new Allocation__c(
                Invoice__c = pastInvoice.Id,
                Receipt__c = clearedReceipt.Id,
                AllocationAmount__c = 500,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            ),
            new Allocation__c(
                Invoice__c = futureInvoice.Id,
                Receipt__c = clearedReceipt.Id,
                AllocationAmount__c = 500,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            )
        };

        Charge__c admCharge = new Charge__c(Name = 'ADM Fee', Type__c = 'ADM & Dari Fee');
        insert admCharge;

        Invoice__c otherInvoice = new Invoice__c(
            Charge__c = admCharge.Id,
            Sales_Order__c = salesOrder1.Id,
            InvoiceAmount__c = 2000,
            Account__c = customerAccount.Id,
            InvoiceDate__c = Date.today().addDays(-3),
            Is_ADM_Fees_and_Dari_charges__c = true
        );
        insert otherInvoice;

        insert new Allocation__c(
            Invoice__c = otherInvoice.Id,
            Receipt__c = clearedReceipt.Id,
            AllocationAmount__c = 1000,
            AllocationDate__c = Date.today(),
            Status__c = 'Applied'
        );
    }

    private static Id customerAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Primary Customer' LIMIT 1].Id;
    }

    @IsTest
    static void testBuildFromAccountId() {
        Id accountId = customerAccountId();

        Test.setCurrentPage(Page.CustomerSOA);
        ApexPages.currentPage().getParameters().put('id', accountId);

        Test.startTest();
        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        Test.stopTest();

        System.assertEquals(accountId, controller.customerAccountId,
            'Account Id should be used directly as the customer account.');
        System.assertEquals('Primary Customer', controller.customerSOA.customerName,
            'Customer name should be populated.');
        System.assertEquals(2, controller.customerSOA.salesOrderSOAs.size(),
            'Both Sales Orders for the customer should be listed.');

        System.assertEquals(35000, controller.customerSOA.totalSalesValue,
            'Total sales value should aggregate both Sales Orders (20000 + 15000).');
        System.assertEquals(true,
            controller.customerSOA.salesOrderSOAs[1].isLast,
            'The last SOA in the list should be flagged as last.');
        System.assertEquals(false,
            controller.customerSOA.salesOrderSOAs[0].isLast,
            'Only the final SOA should be flagged as last.');

        CustomerStatementOfAccountController.SOAWrapper richSoa;
        for (CustomerStatementOfAccountController.SOAWrapper s : controller.customerSOA.salesOrderSOAs) {
            if (s.price == 20000) {
                richSoa = s;
            }
        }
        System.assertNotEquals(null, richSoa, 'The Sales Order with a payment plan should be present.');
        System.assert(richSoa.paymentRows.size() >= 2,
            'Installment payment rows should be built for the Sales Order with a payment plan.');

        Boolean admRowFound = false;
        for (CustomerStatementOfAccountController.PaymentRowWrapper row : richSoa.otherPaymentRows) {
            if (row.transactionType == 'ADM/Dari Fee') {
                admRowFound = true;
                System.assertEquals(2000, row.amount, 'ADM invoice amount should be populated.');
            }
        }
        System.assertEquals(true, admRowFound, 'ADM/Dari Fee row should be present in Other Payments.');

        // customer-level aggregation mirrors the per-SOA grand totals
        Decimal expectedGrand = 0;
        for (CustomerStatementOfAccountController.SOAWrapper s : controller.customerSOA.salesOrderSOAs) {
            expectedGrand += s.grandTotalOutstanding;
        }
        System.assertEquals(expectedGrand, controller.customerSOA.grandTotalOutstanding,
            'Customer grand total outstanding should be the sum of every Sales Order grand total.');
    }

    @IsTest
    static void testBuildFromSalesOrderId() {
        Id accountId = customerAccountId();
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c WHERE CustomerAccount__c = :accountId AND TotalAmount__c = 20000 LIMIT 1
        ];

        Test.setCurrentPage(Page.CustomerSOA);
        ApexPages.currentPage().getParameters().put('id', so.Id);

        Test.startTest();
        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        Test.stopTest();

        System.assertEquals(accountId, controller.customerAccountId,
            'A Sales Order Id should resolve to its CustomerAccount__c.');
        System.assertEquals(2, controller.customerSOA.salesOrderSOAs.size(),
            'All Sales Orders of the resolved customer should still be listed.');
    }

    @IsTest
    static void testAccountWithoutSalesOrders() {
        Id emptyAccId = [SELECT Id FROM Account WHERE Name = 'Customer Without Orders' LIMIT 1].Id;

        Test.setCurrentPage(Page.CustomerSOA);
        ApexPages.currentPage().getParameters().put('id', emptyAccId);

        Test.startTest();
        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        Test.stopTest();

        System.assertEquals(emptyAccId, controller.customerAccountId);
        System.assertEquals(0, controller.customerSOA.salesOrderSOAs.size(),
            'No Sales Order SOAs should be built for an account with no Sales Orders.');
        System.assertEquals('Customer Without Orders', controller.customerSOA.customerName);
    }

    @IsTest
    static void testNoParameter() {
        Test.setCurrentPage(Page.CustomerSOA);

        Test.startTest();
        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        Test.stopTest();

        System.assertEquals(null, controller.customerAccountId,
            'Customer account Id should be null when no page parameter is supplied.');
        System.assertNotEquals(null, controller.customerSOA,
            'Customer SOA wrapper should still be initialized.');
        System.assertEquals(0, controller.customerSOA.salesOrderSOAs.size());
    }

    @IsTest
    static void testUnsupportedIdType() {
        Test.setCurrentPage(Page.CustomerSOA);
        ApexPages.currentPage().getParameters().put('id', UserInfo.getUserId());

        Test.startTest();
        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        Test.stopTest();

        System.assertEquals(null, controller.customerAccountId,
            'An Id that is neither Account nor Sales Order should resolve to null.');
        System.assertEquals(0, controller.customerSOA.salesOrderSOAs.size());
    }

    @IsTest
    static void testDownloadPDF() {
        Test.setCurrentPage(Page.CustomerSOA);
        ApexPages.currentPage().getParameters().put('id', customerAccountId());

        Test.startTest();
        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        PageReference downloadPage = controller.downloadPDF();
        Test.stopTest();

        System.assertNotEquals(null, downloadPage, 'Download PageReference should be returned.');
        System.assertEquals(true, downloadPage.getRedirect(), 'Download PageReference should redirect.');

        List<ContentVersion> generatedFiles = [
            SELECT Id, Title, PathOnClient, ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Customer_Statement_of_Account'
        ];
        System.assertEquals(1, generatedFiles.size(), 'One PDF ContentVersion should be created.');
        System.assertEquals('CustomerStatementOfAccount.pdf', generatedFiles[0].PathOnClient);
        System.assertNotEquals(null, generatedFiles[0].ContentDocumentId);
    }

    @IsTest
    static void testReceiptRowsAndExcessHandling() {
        Id accountId = customerAccountId();
        SalesOrder__c salesOrder = [
            SELECT Id FROM SalesOrder__c WHERE CustomerAccount__c = :accountId AND TotalAmount__c = 20000 LIMIT 1
        ];
        Invoice__c admInvoice = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = true LIMIT 1
        ];

        Receipt__c unallocatedExcess = new Receipt__c(
            Account__c = accountId,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'Cleared',
            TransactionNumber__c = 'TRX-EXCESS-001',
            Receipt_Amount__c = 5000,
            EBS_Clearing_Date__c = Date.today()
        );
        Receipt__c inProgressReceipt = new Receipt__c(
            Account__c = accountId,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            TransactionNumber__c = 'TRX-INPROG-001',
            Receipt_Amount__c = 1500,
            ChequeDate__c = Date.today().addDays(7)
        );
        Receipt__c confirmedReceipt = new Receipt__c(
            Account__c = accountId,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'Confirmed',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX-CONF-001',
            Receipt_Amount__c = 2000,
            ChequeDate__c = Date.today().addDays(3)
        );

        Test.setCurrentPage(Page.CustomerSOA);
        ApexPages.currentPage().getParameters().put('id', accountId);

        Test.startTest();
        insert new List<Receipt__c>{ unallocatedExcess, inProgressReceipt, confirmedReceipt };
        insert new List<Allocation__c>{
            new Allocation__c(
                Invoice__c = admInvoice.Id, Receipt__c = inProgressReceipt.Id,
                AllocationAmount__c = 100, AllocationDate__c = Date.today(), Status__c = 'Applied'
            ),
            new Allocation__c(
                Invoice__c = admInvoice.Id, Receipt__c = confirmedReceipt.Id,
                AllocationAmount__c = 100, AllocationDate__c = Date.today(), Status__c = 'Applied'
            )
        };

        CustomerStatementOfAccountController controller =
            new CustomerStatementOfAccountController();
        Test.stopTest();

        CustomerStatementOfAccountController.SOAWrapper richSoa;
        for (CustomerStatementOfAccountController.SOAWrapper s : controller.customerSOA.salesOrderSOAs) {
            if (s.price == 20000) {
                richSoa = s;
            }
        }
        System.assertNotEquals(null, richSoa);

        Boolean excessRowFound = false;
        List<String> receiptStatusOrder = new List<String>();
        for (CustomerStatementOfAccountController.PaymentRowWrapper row : richSoa.otherPaymentRows) {
            if (row.amount == 5000 && row.outstandingAmount == -5000) {
                excessRowFound = true;
                System.assertEquals('', row.dueDateDisplay, 'Excess receipt row hides the due date.');
                System.assertEquals(1, row.allocationRows.size(),
                    'Unallocated excess receipt carries a synthesised allocation detail row.');
            }
            if (row.isReceiptRow) {
                receiptStatusOrder.add(row.invoiceStatus);
            }
        }
        System.assertEquals(true, excessRowFound,
            'The unallocated excess receipt should produce an Other Payments row.');
        System.assert(!receiptStatusOrder.isEmpty(), 'Receipt rows should be present.');

        System.assertEquals(3500, richSoa.unclearedReceiptsAmount,
            'Uncleared Receipts Amount should total the In Progress (1500) and Confirmed (2000) receipts.');
        System.assertEquals(3500, controller.customerSOA.totalUnclearedReceiptsAmount,
            'Customer-level uncleared receipts should aggregate the per-SOA amounts.');
    }
}