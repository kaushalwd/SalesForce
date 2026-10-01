@isTest
public class CommissionPreReviewControllerTest {

    @testSetup
    static void setupData() {
        Account personAccount = new Account(LastName = 'Smith');
        Account companyAccount = new Account(Name = 'Broker Corp');
        insert new List<Account>{ personAccount, companyAccount };

        Opportunity oppWithBroker = new Opportunity(
            Name = 'Opportunity With Broker',
            StageName = 'Closed Won',
            CloseDate = System.today(),
            AccountId = companyAccount.Id,
            BrokerAgency__c = companyAccount.Id,
            LeadSource = 'Web',
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India',
            PassportExpiryDate__c = System.today() + 100,
            PassportIssueDate__c = System.today() - 100,
            PassportNumber__c = 'JQZ9898353'
        );

        insert oppWithBroker;

        Project__c project = new Project__c(
            Name = 'Test Project',
            Launch_Date__c = System.today()
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id,
            LaunchStartDate__c = System.today()
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            PlotNo__c = '5',
            Number_of_Bedrooms__c = '3',
            Unit_Launch_Date__c = System.today(),
            UnitClassification__c = 'Villa',
            Unit_Sold_Date__c = System.today()
        );
        insert unit;

        PaymentPlan__c pp = new PaymentPlan__c(Type__c = 'Standard');
        insert pp;

        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = new User(
            Username = 'user1_' + String.valueOf(System.currentTimeMillis()) + '@test.com',
            Alias = 'u1',
            Email = 'user1@test.com',
            LastName = 'Test1',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u1;

        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = oppWithBroker.Id,
            OwnerId = u1.Id,
            Status__c = 'Completed',
            TotalAmount__c = 100000,
            Unit__c = unit.Id,
            PaymentPlan__c = pp.Id,
            Referral_Type__c = 'Management',
            Unit_Allocated_Status__c = 'Allocated',
            Down_Payment_Status__c = 'Paid',
            SPAStatus__c = 'Pending for Validation',
            ExternalCommissionPaidPercent__c = 0,
            Booking_Date__c = System.today(),
            Unit_Launch_Date__c = System.today(),
            UsedForCommissionTesting__c = true,
            CustomerAccount__c = personAccount.Id
        );
        insert so;

        Commission_Line__c cl1 = new Commission_Line__c(
            Sales_Order__c = so.Id,
            Booking_Date__c = System.today(),
            Unit_Launch_Date__c = System.today().addDays(-10),
            Lead_Source__c = 'Web',
            Category_Of_Sale__c = 'Launch Sales',
            Commission_Type__c = 'Direct',
            Commission_Percent__c = 2.5,
            Commission_Amount__c = 25000
        );

        Commission_Line__c cl2 = new Commission_Line__c(
            Sales_Order__c = so.Id,
            Booking_Date__c = System.today().addMonths(-1),
            Unit_Launch_Date__c = System.today().addMonths(-2),
            Lead_Source__c = 'Referral',
            Category_Of_Sale__c = 'Inventory Sales',
            Commission_Type__c = 'Indirect',
            Commission_Percent__c = 3,
            Commission_Amount__c = 60000
        );

        Commission_Line__c cl3 = new Commission_Line__c(
            Sales_Order__c = so.Id,
           Booking_Date__c = System.today()
        );

        insert new List<Commission_Line__c>{ cl1, cl2, cl3 };
    }

    @isTest
    static void testGetCommissionRows_MonthFilter() {
        Test.startTest();
        CommissionPreReviewController.ResponseDTO response =
            CommissionPreReviewController.getCommissionRows(
                10,
                1,
                'month',
                Date.today().month(),
                Date.today().year(),
                null,
                null,
                null,
                null
            );
        Test.stopTest();


        Boolean foundVisibleRecord = false;
     }

    @isTest
    static void testGetCommissionRows_CustomDateAndProjectFilter() {
        Date fromDate = Date.today().addDays(-5);
        Date toDate = Date.today().addDays(5);

        Test.startTest();
        CommissionPreReviewController.ResponseDTO response =
            CommissionPreReviewController.getCommissionRows(
                10,
                1,
                'custom',
                null,
                null,
                fromDate,
                toDate,
                'Project Alpha',
                'Unit-101'
            );
        Test.stopTest();

    }

    @isTest
    static void testGetCommissionRows_YearFilter() {
        Test.startTest();
        CommissionPreReviewController.ResponseDTO response =
            CommissionPreReviewController.getCommissionRows(
                20,
                1,
                'year',
                null,
                Date.today().year(),
                null,
                null,
                null,
                null
            );
        Test.stopTest();

    }

    @isTest
    static void testGetCommissionRows_DefaultPaging() {
        Test.startTest();
        CommissionPreReviewController.ResponseDTO response =
            CommissionPreReviewController.getCommissionRows(
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

    }

    @isTest
    static void testUpdateCommissionRows() {
        Commission_Line__c rec = [
            SELECT Id, Booking_Date__c, Unit_Launch_Date__c, Lead_Source__c,
                   Commission_Type__c, Category_Of_Sale__c,
                   Commission_Percent__c, Commission_Amount__c
            FROM Commission_Line__c
            LIMIT 1
        ];

        List<Map<String, Object>> updates = new List<Map<String, Object>>();
        Map<String, Object> row = new Map<String, Object>();
        row.put('recordId', rec.Id);
        row.put('unitSoldDate', String.valueOf(Date.today().addDays(-2)));
        row.put('launchDate', String.valueOf(Date.today().addDays(-20)));
        row.put('leadSource', 'Website');
        row.put('salesType', 'Indirect');
        row.put('saleCategory', 'Inventory Sales');
        row.put('commissionPercent', 4.25);
        row.put('commissionAmount', 42500);
        updates.add(row);

        Test.startTest();
        CommissionPreReviewController.updateCommissionRows(updates);
        Test.stopTest();

        Commission_Line__c updatedRec = [
            SELECT Id, Booking_Date__c, Unit_Launch_Date__c, Lead_Source__c,
                   Commission_Type__c, Category_Of_Sale__c,
                   Commission_Percent__c, Commission_Amount__c
            FROM Commission_Line__c
            WHERE Id = :rec.Id
            LIMIT 1
        ];


        List<Commission_Audit__c> audits = [
            SELECT Id, Commission_Line__c
            FROM Commission_Audit__c
            WHERE Commission_Line__c = :rec.Id
        ];
    }

    @isTest
    static void testUpdateCommissionRows_EmptyList() {
        Test.startTest();
        CommissionPreReviewController.updateCommissionRows(new List<Map<String, Object>>());
        CommissionPreReviewController.updateCommissionRows(null);
        Test.stopTest();

    }

    @isTest
    static void testUpdateCommissionRows_InvalidRowSkipped() {
        List<Map<String, Object>> updates = new List<Map<String, Object>>();
        updates.add(new Map<String, Object>());
        updates.add(null);

        Test.startTest();
        CommissionPreReviewController.updateCommissionRows(updates);
        Test.stopTest();

    }
}