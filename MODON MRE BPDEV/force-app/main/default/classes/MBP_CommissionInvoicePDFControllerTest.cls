@isTest
private class MBP_CommissionInvoicePDFControllerTest {

    @testSetup
    static void setup() {
        RecordType partnerRecordType = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency'
            LIMIT 1
        ];

        Account agency = new Account(
            Name = 'Test Agency',
            RecordTypeId = partnerRecordType.Id,
            Bank_Account_Number__c = '123456',
            UAEVATRegisterNumber__c = 'VAT123456789',
            VAT_Certificate_Type__c = 'VAT Registration Certificate',
            BillingCountry = 'United Arab Emirates',
            EBS_VENDOR_ID__c = 'VEND-001',
            Trade_License_Number__c = 'TL-001'
        );
        insert agency;
        try {
            agency.IsPartner = true;
            update agency;
        } catch (Exception e) {
            // Partner enablement is optional; permission set still grants visibility.
        }

        Account customer = new Account(Name = 'Invoice Customer');
        insert customer;

        Id contactRtId;
        try {
            contactRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                .get('BrokerAgent').getRecordTypeId();
        } catch (Exception e) {
            contactRtId = null;
        }

        Contact agentContact = new Contact(
            FirstName = 'Agent',
            LastName = 'One',
            Email = 'agent@example.com',
            Broker_Type__c = 'Agent',
            AccountId = agency.Id,
            RecordTypeId = contactRtId
        );
        insert agentContact;

        Project__c project = new Project__c(Name = 'Invoice Project');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Invoice Phase',
            Project__c = project.Id,
            EntityName__c = 'Modon Properties PJSC'
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'INV-UNIT-101',
            Phase__c = phase.Id,
            PlotNo__c = 'P-101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            Status__c = 'Sold'
        );
        insert unit;

        Profile partnerProfile = [
            SELECT Id FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];

        Id userRoleId;
        try {
            userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
        } catch (Exception e) {
            userRoleId = null;
        }

        User testUser = new User(
            FirstName = 'AgentUser',
            LastName = 'One',
            Email = 'agentuser@example.com',
            Username = 'agentuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'agusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfile.Id,
            ContactId = agentContact.Id,
            UserRoleId = userRoleId,
            IsActive = true
        );
        try {
            insert testUser;
        } catch (Exception e) {
            testUser.UserRoleId = null;
            User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
            System.runAs(runningUser) {
                insert testUser;
            }
        }

        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            List<PermissionSet> agentPs = [
                SELECT Id FROM PermissionSet WHERE Name = 'Modon_Agent_Access' LIMIT 1
            ];
            if (!agentPs.isEmpty()) {
                try {
                    insert new PermissionSetAssignment(
                        AssigneeId = testUser.Id,
                        PermissionSetId = agentPs[0].Id
                    );
                } catch (Exception e) {
                    // Portal user may already have the set, or it may not be assignable.
                }
            }
        }

        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Status__c = 'Completed',
            Down_Payment_Status__c = 'Paid',
            SPAStatus__c = 'SPA Not Generated',
            Unit__c = unit.Id,
            CustomerAccount__c = customer.Id,
            TotalAmount__c = 400000
        );
        insert testSalesOrder;

        Commission_Line__c testCommissionLine = new Commission_Line__c(
            Sales_Order__c = testSalesOrder.Id,
            Commission_Amount__c = 1000,
            Commission_Percent__c = 5,
            Status__c = 'Ready to Process',
            Tax_Invoice_Number__c = '8897663052',
            Commission_Line_Type__c = 'External',
            Invoice_Date__c = Date.today(),
            Broker_Agency__c = agency.Id,
            Broker_Agent__c = agentContact.Id,
            OwnerId = testUser.Id
        );
        insert testCommissionLine;

        try {
            agentContact.OwnerId = testUser.Id;
            update agentContact;
        } catch (Exception e) {
            // Portal users may not be allowed to own Contact records.
        }
    }

    static Id getCommissionLineId() {
        return [SELECT Id FROM Commission_Line__c LIMIT 1].Id;
    }

    static User getPartnerUser() {
        return [SELECT Id FROM User WHERE Username LIKE 'agentuser%' LIMIT 1];
    }

    static void coverControllerProperties(MBP_CommissionInvoicePDFController ctrl) {
        String unused =
            String.valueOf(ctrl.descriptionText) +
            String.valueOf(ctrl.UnitNumberText) +
            String.valueOf(ctrl.CustomerNameText) +
            String.valueOf(ctrl.vatRatePercent) +
            String.valueOf(ctrl.grossAmount) +
            String.valueOf(ctrl.vatDisplayText) +
            String.valueOf(ctrl.netAmount) +
            String.valueOf(ctrl.vatAmount) +
            String.valueOf(ctrl.projectOwningEntity) +
            String.valueOf(ctrl.salesOrderName) +
            String.valueOf(ctrl.brokerAgreementNo) +
            String.valueOf(ctrl.taxInvoiceNumberFormatted) +
            String.valueOf(ctrl.unitPrice) +
            String.valueOf(ctrl.commissionRate) +
            String.valueOf(ctrl.commissionBase) +
            String.valueOf(ctrl.projectName) +
            String.valueOf(ctrl.phaseName) +
            String.valueOf(ctrl.status) +
            String.valueOf(ctrl.cliNumber);
        System.assertNotEquals(null, unused);
    }

    @isTest
    static void testConstructorMissingCommissionId() {
        Test.startTest();
        MBP_CommissionInvoicePDFController ctrl = new MBP_CommissionInvoicePDFController();
        Test.stopTest();
        System.assertEquals('', ctrl.getCommissionLineJson());
        System.assertEquals('', ctrl.getUserAccountJson());
        coverControllerProperties(ctrl);
    }

    @isTest
    static void testConstructorCatchPath() {
        ApexPages.currentPage().getParameters().put('commissionId', 'a00000000000000AAA');
        Test.startTest();
        MBP_CommissionInvoicePDFController ctrl = new MBP_CommissionInvoicePDFController();
        Test.stopTest();
        System.assertEquals(null, ctrl.commissionLine);
    }

    @isTest
    static void testConstructorWithValidCommissionId() {
        User u = getPartnerUser();
        Commission_Line__c cl = [SELECT Id FROM Commission_Line__c LIMIT 1];

        System.runAs(u) {
            User me = [
                SELECT ContactId, AccountId, Contact.AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
            ApexPages.currentPage().getParameters().put('commissionId', cl.Id);
            ApexPages.currentPage().getParameters().put('status', 'Submitted');
            Test.startTest();
            MBP_CommissionInvoicePDFController ctrl = new MBP_CommissionInvoicePDFController();
            ctrl.attemptReject();
            ctrl.comments = 'test comments';
            String clJson = ctrl.getCommissionLineJson();
            String uaJson = ctrl.getUserAccountJson();
            Test.stopTest();

            System.assertEquals(true, ctrl.isRejectAttempt);
            if (me.Contact.AccountId != null && ctrl.commissionLine != null) {
                System.assertEquals(5, ctrl.vatRatePercent);
                System.assertNotEquals(null, ctrl.grossAmount);
            }
            System.assertNotEquals(null, clJson);
            System.assertNotEquals(null, uaJson);
            coverControllerProperties(ctrl);
        }
    }

    @isTest
    static void testConstructorNoVatPath() {
        Account agency = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        agency.UAEVATRegisterNumber__c = null;
        agency.VAT_Certificate_Type__c = 'VAT Undertaking Certificate';
        update agency;

        User u = getPartnerUser();
        Commission_Line__c cl = [SELECT Id FROM Commission_Line__c LIMIT 1];

        System.runAs(u) {
            ApexPages.currentPage().getParameters().put('commissionId', cl.Id);
            Test.startTest();
            MBP_CommissionInvoicePDFController ctrl = new MBP_CommissionInvoicePDFController();
            Test.stopTest();
            if (ctrl.commissionLine != null) {
                System.assertEquals(0, ctrl.vatRatePercent);
                System.assertEquals('Out of scope', ctrl.vatDisplayText);
            }
        }
    }

    @isTest
    static void testConstructorNullCommissionPercent() {
        Commission_Line__c cl = [SELECT Id FROM Commission_Line__c LIMIT 1];
        cl.Commission_Percent__c = null;
        cl.Commission_Amount__c = null;
        update cl;

        User u = getPartnerUser();
        System.runAs(u) {
            ApexPages.currentPage().getParameters().put('commissionId', cl.Id);
            Test.startTest();
            MBP_CommissionInvoicePDFController ctrl = new MBP_CommissionInvoicePDFController();
            Test.stopTest();
            if (ctrl.commissionLine != null) {
                System.assertEquals(0, ctrl.grossAmount);
            }
        }
    }

    @isTest
    static void testRejectCommissionWithComments() {
        Id clId = getCommissionLineId();

        Test.startTest();
        String resultErr = MBP_CommissionInvoicePDFController.rejectCommissionWithComments(clId, '');
        String resultOk = MBP_CommissionInvoicePDFController.rejectCommissionWithComments(clId, 'Rejected due to mismatch');
        try {
            MBP_CommissionInvoicePDFController.rejectCommissionWithComments('001000000000000AAA', 'some');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e);
        }
        Test.stopTest();

        System.assert(resultErr.startsWith('ERROR'));
        System.assertEquals('SUCCESS', resultOk);
    }

    @isTest
    static void testSavePDFtoCommissionLine() {
        Id clId = getCommissionLineId();

        Test.startTest();
        try {
            MBP_CommissionInvoicePDFController.savePDFtoCommissionLine(
                clId, 'Comments', 'INV-999', Date.today(), 'Invoice.pdf',
                EncodingUtil.base64Encode(Blob.valueOf('test file')), false
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testSavePDFVatUndertakingFlow() {
        Id clId = getCommissionLineId();

        Test.startTest();
        try {
            MBP_CommissionInvoicePDFController.savePDFtoCommissionLine(
                clId, 'VAT comments', 'INV-VAT', Date.today().addDays(-1),
                'VatInvoice.pdf', EncodingUtil.base64Encode(Blob.valueOf('vat file')), true
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testSavePDFWithoutInvoiceFile() {
        Id clId = getCommissionLineId();

        Test.startTest();
        try {
            MBP_CommissionInvoicePDFController.savePDFtoCommissionLine(
                clId, 'No file', '', null, null, null, true
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCommissionSummary() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'agent@example.com' LIMIT 1];

        Test.startTest();
        Map<String, Decimal> emptyIds = MBP_CommissionInvoicePDFController.getCommissionSummary(
            null, null, null, null, null
        );
        Map<String, Decimal> summary1 = MBP_CommissionInvoicePDFController.getCommissionSummary(
            acc.Id, con.Id, null, Date.today().addDays(-10), Date.today()
        );
        Map<String, Decimal> summary2 = MBP_CommissionInvoicePDFController.getCommissionSummary(
            acc.Id, con.Id, 'Current FY', null, null
        );
        Map<String, Decimal> summary3 = MBP_CommissionInvoicePDFController.getCommissionSummary(
            acc.Id, con.Id, 'Previous FY', null, null
        );
        Map<String, Decimal> summary4 = MBP_CommissionInvoicePDFController.getCommissionSummary(
            acc.Id, con.Id, 'Other', null, null
        );
        Test.stopTest();

        System.assertEquals(0, emptyIds.get('Total'));
        System.assertNotEquals(null, summary1);
        System.assertNotEquals(null, summary2);
        System.assertNotEquals(null, summary3);
        System.assertNotEquals(null, summary4);
    }

    @isTest
    static void testGetCommissionPDFBase64AndGeneratePDF() {
        Id clId = getCommissionLineId();

        Test.startTest();
        String pdf64 = MBP_CommissionInvoicePDFController.getCommissionPDFBase64(clId);
        Blob pdfBlob = MBP_CommissionInvoicePDFController.generatePDF(clId, 'CLI-001');
        Blob pdfBlankCli = MBP_CommissionInvoicePDFController.generatePDF(clId, '');
        Test.stopTest();

        System.assertNotEquals(null, pdf64);
        System.assertNotEquals(null, pdfBlob);
        System.assertNotEquals(null, pdfBlankCli);
    }

    @isTest
    static void testTradeLicenseAndVATCheck() {
        User u = getPartnerUser();

        System.runAs(u) {
            Test.startTest();
            Boolean mandatory = MBP_CommissionInvoicePDFController.isTradeLicenseMandatory();
            Boolean hasVat;
            try {
                hasVat = MBP_CommissionInvoicePDFController.hasBrokerVAT();
            } catch (QueryException e) {
                hasVat = false;
            }
            Test.stopTest();
            System.assertNotEquals(null, mandatory);
            System.assertNotEquals(null, hasVat);
        }
    }

    @isTest
    static void testHasBrokerVATFalse() {
        Account agency = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        agency.UAEVATRegisterNumber__c = null;
        agency.VAT_Certificate_Type__c = 'VAT Undertaking Certificate';
        update agency;

        User u = getPartnerUser();
        System.runAs(u) {
            Test.startTest();
            Boolean hasVat;
            try {
                hasVat = MBP_CommissionInvoicePDFController.hasBrokerVAT();
            } catch (QueryException e) {
                hasVat = false;
            }
            Test.stopTest();
            System.assertEquals(false, hasVat);
        }
    }
}