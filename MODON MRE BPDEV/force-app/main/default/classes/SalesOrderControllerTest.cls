@IsTest
private class SalesOrderControllerTest {

    private static final String TEST_ACCOUNT_NAME = 'Test Sales Order Account';
    private static final String TEST_BROKER_NAME = 'Test Broker Agency';
    private static final String TEST_PROJECT_NAME = 'Test Project';
    private static final String TEST_UNIT_NAME = 'Test Unit';

    @TestSetup
    static void setupTestData() {
        Account customerAcc = new Account(
            Name = TEST_ACCOUNT_NAME
        );
        insert customerAcc;

        Account brokerAgency = new Account(
            Name = TEST_BROKER_NAME
        );
        insert brokerAgency;

        Contact primaryContact = new Contact(
            FirstName = 'Primary',
            LastName = 'Contact',
            AccountId = customerAcc.Id
        );
        insert primaryContact;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = customerAcc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            LanguagePreference__c = 'English'
        );

        /*
         * If BrokerAgency__c is required/available in your org,
         * this field is needed for getSalesOrderCount().
         */
        opp.BrokerAgency__c = brokerAgency.Id;

        insert opp;

        Project__c projectRec = new Project__c(
            Name = TEST_PROJECT_NAME
        );
        insert projectRec;

        Phase__c phaseRec = new Phase__c(
            Name = 'Test Phase',
            Project__c = projectRec.Id
        );
        insert phaseRec;

        Unit__c unitRec = new Unit__c(
            Name = TEST_UNIT_NAME,
            Phase__c = phaseRec.Id,
            PlotNo__c = '10',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );

        String unitStatus = getPicklistValue(
            Unit__c.Status__c,
            new List<String>{ 'Sold', 'Available' },
            new Set<String>()
        );

        if (unitStatus != null) {
            unitRec.Status__c = unitStatus;
        }

        insert unitRec;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Name = 'Standard Plan'
        );

        String ppType = getPicklistValue(
            PaymentPlan__c.Type__c,
            new List<String>{ 'Standard' },
            new Set<String>()
        );

        if (ppType != null) {
            paymentPlan.Type__c = ppType;
        }

        insert paymentPlan;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = customerAcc.Id,
            Opportunity__c = opp.Id,
            Unit__c = unitRec.Id,
            PrimaryContact__c = primaryContact.Id,
            PaymentPlan__c = paymentPlan.Id,
            TotalAmount__c = 100000,
            Totalpaidamount__c = 50000,
            Number_of_JointOwners__c = 1
        );

        String soStatus = getPicklistValue(
            SalesOrder__c.Status__c,
            new List<String>{ 'Completed', 'New', 'In Progress', 'Sold' },
            getCancelledStatuses()
        );

        if (soStatus != null) {
            so.Status__c = soStatus;
        }

        insert so;

        JointOwner__c jointOwner = new JointOwner__c(
            SalesOrder__c = so.Id,
            OwnershipPercentage__c = 50,
            JointOwnerAccount__c = customerAcc.Id,
            Opportunity__c = opp.Id
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

        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();

        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 1000,
            MilestoneDate__c = System.today().addDays(-10)
        ));

        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 2000,
            MilestoneDate__c = System.today().addDays(30)
        ));

        insert installments;

        /*
         * Optional exterior document image setup.
         * This covers the image URL block in getSalesOrders().
         */
        Documents__c exteriorDoc = new Documents__c(
            Name = 'Exterior',
            Unit__c = unitRec.Id
        );
        insert exteriorDoc;

        ContentVersion cv = new ContentVersion(
            Title = 'Exterior Image',
            PathOnClient = 'ExteriorImage.jpg',
            VersionData = Blob.valueOf('Test image body')
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = exteriorDoc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    private static Account getCustomerAccount() {
        return [
            SELECT Id, Name
            FROM Account
            WHERE Name = :TEST_ACCOUNT_NAME
            LIMIT 1
        ];
    }

    private static Account getBrokerAgency() {
        return [
            SELECT Id, Name
            FROM Account
            WHERE Name = :TEST_BROKER_NAME
            LIMIT 1
        ];
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

    private static Set<String> getCancelledStatuses() {
        return new Set<String>{
            'Cancelled',
            'System cancelled',
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

    @IsTest
    static void testGetSalesOrdersWithDefaultDates() {
        Account acc = getCustomerAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrders(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(2, result.size(), 'Direct and joint-owner query can both return same SO.');

        Map<String, Object> firstRow = result[0];

        System.assert(firstRow.containsKey('Id'), 'Row should contain Id.');
        System.assert(firstRow.containsKey('Name'), 'Row should contain Name.');
        System.assert(firstRow.containsKey('ProjectName__c'), 'Row should contain ProjectName__c.');
        System.assert(firstRow.containsKey('Unit_Name__c'), 'Row should contain Unit_Name__c.');
        System.assert(firstRow.containsKey('PendingAmount__c'), 'Row should contain PendingAmount__c.');
        System.assert(firstRow.containsKey('PaidAmount__c'), 'Row should contain PaidAmount__c.');
        System.assert(firstRow.containsKey('OutstandingAmount__c'), 'Row should contain OutstandingAmount__c.');
        System.assert(firstRow.containsKey('FutureAmount__c'), 'Row should contain FutureAmount__c.');
        System.assert(firstRow.containsKey('HasJointOwners'), 'Row should contain HasJointOwners.');
        System.assert(firstRow.containsKey('JointOwners'), 'Row should contain JointOwners.');
    }

    @IsTest
    static void testGetSalesOrdersWithDateRange() {
        Account acc = getCustomerAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrders(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.size() > 0, 'Sales Orders should be returned for matching date range.');
    }

    @IsTest
    static void testGetSalesOrdersWithProjectAndUnitFilters() {
        Account acc = getCustomerAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrders(
                acc.Id,
                null,
                null,
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.size() > 0, 'Sales Orders should be returned for matching project and unit filters.');
    }

    @IsTest
    static void testGetSalesOrdersWithWrongFilters() {
        Account acc = getCustomerAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrders(
                acc.Id,
                null,
                null,
                'Wrong Project',
                'Wrong Unit'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Wrong filters should return no Sales Orders.');
    }

    @IsTest
    static void testGetSalesOrdersWithFutureDateRange() {
        Account acc = getCustomerAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrders(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Future created-date range should return no Sales Orders.');
    }

    @IsTest
    static void testGetSalesOrdersWithNullAccount() {
        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrders(
                null,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Null accountId should return empty list.');
    }

    @IsTest
    static void testGetSalesOrderCount() {
        Account brokerAgency = getBrokerAgency();

        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrderCount(brokerAgency.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Count result should not be null.');
        System.assert(result.size() > 0, 'Broker agency should have Sales Order count.');

        Map<String, Object> firstRow = result[0];
        System.assert(firstRow.containsKey('status'), 'Count row should contain status.');
        System.assert(firstRow.containsKey('count'), 'Count row should contain count.');
    }

    @IsTest
    static void testGetSalesOrderCountWithNullBrokerAgency() {
        Test.startTest();
        List<Map<String, Object>> result =
            SalesOrderController.getSalesOrderCount(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Count result should not be null.');
        System.assertEquals(0, result.size(), 'Null brokerAgencyId should return empty list.');
    }
}