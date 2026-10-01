@IsTest
public class AccountSOAControllerTest {

    private static final String TEST_ACCOUNT_NAME = 'Test SOA Account';

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Test SOA Project'
        );
        insert project;

        EscrowAccount__c escrowAccount = new EscrowAccount__c(
            Name = 'Test Escrow Account'
        );
        insert escrowAccount;

        VirtualAccount__c virtualAccount = new VirtualAccount__c(
            Name = 'Test Virtual Account',
            Status__c = 'Available',
            EscrowAccount__c = escrowAccount.Id,
            VirtualAccountNumber__c = '124567642',
            VirtualIBANNumber__c = 'AE3456789456789'
        );
        insert virtualAccount;

        Phase__c phase = new Phase__c(
            Name = 'Test SOA Phase',
            Project__c = project.Id,
            EscrowAccount__c = escrowAccount.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Test SOA Unit',
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = 'SOA-001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );

        String unitStatus = getPicklistValue(
            Unit__c.Status__c,
            new List<String>{ 'Available', 'Sold' },
            new Set<String>()
        );

        if (unitStatus != null) {
            unit.Status__c = unitStatus;
        }

        insert unit;

        Account acc = new Account(
            Name = TEST_ACCOUNT_NAME
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test SOA Opportunity',
            AccountId = acc.Id,
            StageName = 'Discussion In Progress',
            CloseDate = System.today()
        );

        setFieldSafely(opp, 'UAE_Resident_Status__c', null, null, 'Resident', null);
        setFieldSafely(opp, 'Nationality__c', null, null, 'United Arab Emirates', null);
        setFieldSafely(opp, 'EmiratesIDExpiryDate__c', null, null, null, Date.today().addDays(365));
        setFieldSafely(opp, 'EIDNumber__c', null, null, '784-1232-1234567-4', null);

        insert opp;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(5)
        );

        String paymentPlanType = getPicklistValue(
            PaymentPlan__c.Type__c,
            new List<String>{ 'Standard' },
            new Set<String>()
        );

        if (paymentPlanType != null) {
            paymentPlan.Type__c = paymentPlanType;
        }

        setFieldSafely(paymentPlan, 'Unit__c', unit.Id, 1, 'Test Unit', null);

        insert paymentPlan;

        SalesOrder__c salesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c = virtualAccount.Id,
            CustomerAccount__c = acc.Id,
            TotalAmount__c = 20000
        );

        String soStatus = getPicklistValue(
            SalesOrder__c.Status__c,
            new List<String>{ 'Completed', 'Sold', 'New', 'In Progress' },
            getExcludedStatuses()
        );

        if (soStatus != null) {
            salesOrder.Status__c = soStatus;
        }

        insert salesOrder;

        JointOwner__c jointOwner = new JointOwner__c(
            SalesOrder__c = salesOrder.Id,
            JointOwnerAccount__c = acc.Id,
            OwnershipPercentage__c = 20
        );

        String relationshipType = getPicklistValue(
            JointOwner__c.RelationshipType__c,
            new List<String>{ 'Partner', 'Sibling' },
            new Set<String>()
        );

        if (relationshipType != null) {
            jointOwner.RelationshipType__c = relationshipType;
        }

        String relationshipSubType = getPicklistValue(
            JointOwner__c.RelationshipSubType__c,
            new List<String>{ 'Sibling', 'Partner' },
            new Set<String>()
        );

        if (relationshipSubType != null) {
            jointOwner.RelationshipSubType__c = relationshipSubType;
        }

        insert jointOwner;

        PaymentInstallements__c paymentInstallment = new PaymentInstallements__c();

        setFieldSafely(
            paymentInstallment,
            'PaymentInstallment__c',
            paymentPlan.Id,
            1,
            'Test Payment Installment',
            null
        );

        setFieldSafely(paymentInstallment, 'BrokerPayout__c', null, 10, null, null);
        setFieldSafely(paymentInstallment, 'Milestone__c', null, 10, 'Test Milestone', null);
        setFieldSafely(paymentInstallment, 'MilestoneNumber__c', null, 1, null, null);
        setFieldSafely(paymentInstallment, 'MilestoneDescription__c', null, null, 'Test Milestone', null);

        insert paymentInstallment;

        SalesOrderInstallments__c soInstallment = new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            InstallmentAmount__c = 1500,
            MilestoneDate__c = Date.today().addDays(-10)
        );

        setFieldSafely(soInstallment, 'PaymentInstallments__c', paymentInstallment.Id, 1, null, null);
        setFieldSafely(soInstallment, 'MilestoneNumber__c', null, 1, null, null);
        setFieldSafely(soInstallment, 'Milestone__c', null, 10, 'Test Milestone', null);

        insert soInstallment;

        Invoice__c installmentInvoice = new Invoice__c(
            Account__c = acc.Id,
            Sales_Order__c = null,
            SalesOrderInstallment__c = soInstallment.Id,
            InvoiceAmount__c = 1500,
            InvoiceDate__c = Date.today().addDays(-5)
        );
        insert installmentInvoice;

        Charge__c charge = new Charge__c(
            Name = 'ADM Fee'
        );

        String chargeType = getPicklistValue(
            Charge__c.Type__c,
            new List<String>{ 'ADM Fee' },
            new Set<String>()
        );

        if (chargeType != null) {
            charge.Type__c = chargeType;
        }

        insert charge;

        Invoice__c otherInvoice = new Invoice__c(
            Charge__c = charge.Id,
            Sales_Order__c = salesOrder.Id,
            Account__c = acc.Id,
            InvoiceAmount__c = 2000,
            InvoiceDate__c = Date.today().addDays(-3)
        );

        setFieldSafely(otherInvoice, 'AppliedAmount__c', null, 700, null, null);
        setFieldSafely(otherInvoice, 'InvoiceBalance__c', null, 1300, null, null);

        insert otherInvoice;
    }

    @IsTest
    static void testConstructorWithAccountId() {
        Account acc = getTestAccount();

        Test.startTest();
        Test.setCurrentPage(new PageReference('/apex/AccountSOA'));
        ApexPages.currentPage().getParameters().put('id', acc.Id);

        AccountSOAController controller = new AccountSOAController();
        Test.stopTest();

        System.assertEquals(true, controller.isAccountMode, 'Controller should be in Account mode.');
        System.assertNotEquals(null, controller.allSOARecords, 'SOA records should not be null.');
        System.assertEquals(1, controller.allSOARecords.size(), 'One SOA wrapper should be loaded.');

        AccountSOAController.SOWrapper wrapper = controller.allSOARecords[0];

        System.assertNotEquals(null, wrapper.salesOrder, 'Sales Order should be populated.');
        System.assertEquals(1, wrapper.PayemntSalesList.size(), 'Installment invoice should be loaded.');
        System.assertEquals(1, wrapper.OtherPayemntSalesList.size(), 'Other invoice should be loaded.');
        System.assertEquals(TEST_ACCOUNT_NAME, wrapper.jointOwnerNames, 'Joint owner name should be populated.');

        System.assertEquals(1500, wrapper.totalAmount, 'Installment invoice total should match.');
        System.assertEquals(0, wrapper.totalAmountCollected, 'No Allocation records are inserted, so collected should be zero.');
        System.assertEquals(1500, wrapper.totalAmountOutstanding, 'Outstanding should equal installment invoice amount.');

        System.assertEquals(2000, wrapper.totalOtherAmount, 'Other invoice total should match.');
        System.assert(wrapper.totalOtherAmountCollected >= 0, 'Other collected amount should be valid.');
        System.assert(wrapper.totalOtherAmountOutstanding >= 0, 'Other outstanding amount should be valid.');
        System.assert(wrapper.grandTotalOutstanding >= 1500, 'Grand outstanding should include installment outstanding.');
    }

    @IsTest
    static void testConstructorWithSalesOrderId() {
        SalesOrder__c salesOrder = getTestSalesOrder();

        Test.startTest();
        Test.setCurrentPage(new PageReference('/apex/AccountSOA'));
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);

        AccountSOAController controller = new AccountSOAController();
        Test.stopTest();

        System.assertEquals(false, controller.isAccountMode, 'Controller should be in Sales Order mode.');
        System.assertNotEquals(null, controller.allSOARecords, 'SOA records should not be null.');
        System.assertEquals(1, controller.allSOARecords.size(), 'One SOA wrapper should be loaded.');
    }

    @IsTest
    static void testConstructorWithoutId() {
        Test.startTest();
        Test.setCurrentPage(new PageReference('/apex/AccountSOA'));

        AccountSOAController controller = new AccountSOAController();
        Test.stopTest();

        System.assertEquals(null, controller.inputId, 'Input Id should be null.');
        System.assertNotEquals(null, controller.allSOARecords, 'SOA records should be initialized.');
        System.assertEquals(0, controller.allSOARecords.size(), 'No records should be loaded without Id.');
    }

    @IsTest
    static void testConstructorWithAccountHavingNoSalesOrders() {
        Account emptyAccount = new Account(
            Name = 'Empty SOA Account'
        );
        insert emptyAccount;

        Test.startTest();
        Test.setCurrentPage(new PageReference('/apex/AccountSOA'));
        ApexPages.currentPage().getParameters().put('id', emptyAccount.Id);

        AccountSOAController controller = new AccountSOAController();
        Test.stopTest();

        System.assertEquals(true, controller.isAccountMode, 'Controller should be in Account mode.');
        System.assertNotEquals(null, controller.allSOARecords, 'SOA records should not be null.');
        System.assertEquals(0, controller.allSOARecords.size(), 'No SOA records should be loaded.');
    }

    private static Account getTestAccount() {
        return [
            SELECT Id, Name
            FROM Account
            WHERE Name = :TEST_ACCOUNT_NAME
            LIMIT 1
        ];
    }

    private static SalesOrder__c getTestSalesOrder() {
        return [
            SELECT Id, CustomerAccount__c
            FROM SalesOrder__c
            WHERE CustomerAccount__r.Name = :TEST_ACCOUNT_NAME
            LIMIT 1
        ];
    }

    private static void setFieldSafely(
        SObject recordObj,
        String fieldApi,
        Id lookupId,
        Decimal numberValue,
        String textValue,
        Date dateValue
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            recordObj.getSObjectType().getDescribe().fields.getMap();

        if (!fieldMap.containsKey(fieldApi)) {
            return;
        }

        Schema.DescribeFieldResult dfr = fieldMap.get(fieldApi).getDescribe();

        if (!dfr.isCreateable()) {
            return;
        }

        Schema.DisplayType fieldType = dfr.getType();

        if (fieldType == Schema.DisplayType.Reference && lookupId != null) {
            recordObj.put(fieldApi, lookupId);
        } else if (fieldType == Schema.DisplayType.Integer && numberValue != null) {
            recordObj.put(fieldApi, Integer.valueOf(numberValue));
        } else if (
            (
                fieldType == Schema.DisplayType.Currency ||
                fieldType == Schema.DisplayType.Double ||
                fieldType == Schema.DisplayType.Percent
            ) &&
            numberValue != null
        ) {
            recordObj.put(fieldApi, numberValue);
        } else if (fieldType == Schema.DisplayType.Picklist && textValue != null) {
            recordObj.put(fieldApi, getValidPicklistValue(dfr, textValue));
        } else if (
            (
                fieldType == Schema.DisplayType.String ||
                fieldType == Schema.DisplayType.TextArea
            ) &&
            textValue != null
        ) {
            recordObj.put(fieldApi, textValue);
        } else if (fieldType == Schema.DisplayType.Date && dateValue != null) {
            recordObj.put(fieldApi, dateValue);
        }
    }

    private static String getValidPicklistValue(Schema.DescribeFieldResult dfr, String preferredValue) {
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive() && pe.getValue() == preferredValue) {
                return pe.getValue();
            }
        }

        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return preferredValue;
    }

    private static String getPicklistValue(
        Schema.SObjectField fieldToken,
        List<String> preferredValues,
        Set<String> excludedValues
    ) {
        List<Schema.PicklistEntry> values =
            fieldToken.getDescribe().getPicklistValues();

        for (String preferred : preferredValues) {
            for (Schema.PicklistEntry pe : values) {
                if (pe.isActive() && pe.getValue() == preferred) {
                    return pe.getValue();
                }
            }
        }

        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive() && !excludedValues.contains(pe.getValue())) {
                return pe.getValue();
            }
        }

        return null;
    }

    private static Set<String> getExcludedStatuses() {
        return new Set<String>{
            'Cancelled',
            'Cancelled SR',
            'Voided',
            'Property Transfer Cancelled - SR',
            'Unit Swap Cancelled - SR',
            'Unit Upgrade Cancelled - SR',
            'Unit Cancellation Cancelled - SR',
            'Unit Consolidation Cancelled - SR',
            'Property Transfer Title Deed Cancelled - SR'
        };
    }
}