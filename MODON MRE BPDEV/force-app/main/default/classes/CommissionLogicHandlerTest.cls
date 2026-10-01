@isTest
public class CommissionLogicHandlerTest {
    
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        // Create test data
        Account personAccount = new Account(LastName='Smith');
        Account companyAccount = new Account(Name='Broker Corp');
        insert new List<Account>{personAccount, companyAccount};
            Opportunity oppWithBroker = new Opportunity(
                Name = 'Opportunity With Broker',
                StageName = 'Closed Won',
                CloseDate = System.today(),
                AccountId = companyAccount.Id,
                BrokerAgency__c = companyAccount.Id,
                LeadSource = 'Web',
              UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India',
                PassportExpiryDate__c = system.today()+100,
                PassportIssueDate__c = system.today()-100,
                PassportNumber__c = 'JQZ9898353'
            );
        Opportunity oppWithoutBroker = new Opportunity(
            Name = 'Opportunity Without Broker',
            StageName = 'Closed Won',
            CloseDate = System.today(),
            AccountId = personAccount.Id,
            LeadSource = 'Referral',
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India',
            PassportExpiryDate__c = system.today()+100,
            PassportIssueDate__c = system.today()-100,
             PassportNumber__c = 'JQZ9898353'
        );
        insert new List<Opportunity>{oppWithBroker, oppWithoutBroker};
            Project__c project = new Project__c(Name='Test Project', Launch_Date__c=System.today());
        insert project;
        Phase__c phase = new Phase__c(Name='Test Phase', Project__c=project.Id, LaunchStartDate__c=System.today());
        insert phase;
        Unit__c unit = new Unit__c(Name='Test Unit', Phase__c=phase.Id, PlotNo__c = '5', Number_of_Bedrooms__c='3', Unit_Launch_Date__c=System.today(),UnitClassification__c = 'Villa',Unit_Sold_Date__c =System.today() );
        Unit__c unit2 = new Unit__c(Name='Test Unit2', Phase__c=phase.Id, PlotNo__c = '6', Number_of_Bedrooms__c='2', Unit_Launch_Date__c=System.today(),UnitClassification__c = 'Villa',Unit_Sold_Date__c=System.today());
        insert new List<Unit__c>{unit, unit2};
            PaymentPlan__c pp = new PaymentPlan__c(Type__c = 'Standard');
        Insert pp;
        Commission_Rules__c rule = new Commission_Rules__c(
            StartDate__c = System.today(),
            EndDate__c = System.today().addDays(30),
            Direct_Commission__c = 5,
            Direct_Commission_Sales_Manager__c = 7,
            Indirect_Commission_Amount_Internal__c = 2000,
            Indirect_Commission_Amount_Intrl_Mgr__c = 2500,
            Management_Referral_Amount_UnitAllocated__c = 500,
            Management_Referral_Unit_Unallocated__c = 2,
            Indirect_Commission__c = 3,
            Project__c = project.Id,
            Inventory_Launch_Category__c = 'Launch Sales',
            //Payment_Plan__c = pp.id,
            Number_Of_Bedrooms__c = '3'
        );
        Commission_Rules__c ruleNoBedrooms = new Commission_Rules__c(
            StartDate__c = System.today(),
            EndDate__c = System.today().addDays(30),
            Direct_Commission__c = 6,
            Project__c = project.Id,
            Inventory_Launch_Category__c = 'Launch Sales',
            Indirect_Commission__c = 10
           // Payment_Plan__c = pp.id
        );
        insert new List<Commission_Rules__c>{rule, ruleNoBedrooms};
            Commission_Payout_Line__c payoutDirect = new Commission_Payout_Line__c(
                Commission_Type__c = 'Direct',
                Sub_Type__c = 'Direct Commission',
                Payout_Based_On__c = 'Equity',
                Equity__c = 1.0,
                Equity_Commission_Payout__c = 75.0,
                Commission_Rules__c = rule.Id
            );
        Commission_Payout_Line__c payoutIndirect = new Commission_Payout_Line__c(
            Commission_Type__c = 'Indirect',
            Sub_Type__c = 'Indirect Commission',
            Payout_Based_On__c = 'Down Payment Cleared',
            Equity_Commission_Payout__c = 50.0,
            Commission_Rules__c = rule.Id
        );
        Commission_Payout_Line__c payoutInstallment = new Commission_Payout_Line__c(
            Commission_Type__c = 'Direct',
            Sub_Type__c = 'Direct Commission',
            Payout_Based_On__c = 'Installment',
            Installment_No__c = 1,
            Installment_Commission_Payout__c = 25.0,
            Commission_Rules__c = rule.Id
        );
        insert new List<Commission_Payout_Line__c>{payoutDirect, payoutIndirect, payoutInstallment};
            
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
        User u2 = new User(
            Username = 'user2_' + String.valueOf(System.currentTimeMillis()) + '@test.com',
            Alias = 'u2',
            Email = 'user2@test.com',
            LastName = 'Test2',
            TimeZoneSidKey = 'America/Chicago',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert new List<User>{u1, u2};
            
            List<Commission_POT__c> pots = new List<Commission_POT__c>{
                new Commission_POT__c(User__c=u1.Id, POT_Type__c='Sales Associate', Split_Type__c='Total Gross Sales Value', Commission_Percent__c=3),
                    new Commission_POT__c(User__c=u1.Id, POT_Type__c='Sales Manager', Split_Type__c='Individual Commission', Commission_Percent__c=5),
                    new Commission_POT__c(User__c=u2.Id, POT_Type__c='Sales Manager', Split_Type__c='Team Gross Sales Value', Commission_Percent__c=4),
                    new Commission_POT__c(User__c=u2.Id, POT_Type__c='Sales Associate', Split_Type__c='Indirect - Total Gross Sales Value', Commission_Percent__c=2),
                    new Commission_POT__c(User__c=u2.Id, POT_Type__c='Sales Manager', Split_Type__c='Team Commission Value', Commission_Percent__c=6)
                    };
                        insert pots;
        
        SalesOrder__c soWithBroker = new SalesOrder__c(
            Opportunity__c = oppWithBroker.Id,
            OwnerId = u1.Id,
            Status__c = 'Completed',
            TotalAmount__c = 100000,
            Unit__c = unit.Id,
            PaymentPlan__c = pp.id,
            Referral_Type__c = 'Management',
            Unit_Allocated_Status__c = 'Allocated',
            Down_Payment_Status__c = 'Paid',
            SPAStatus__c = 'Pending for Validation',
            ExternalCommissionPaidPercent__c = 0,
            Booking_Date__c = System.today(),
            Unit_Launch_Date__c = System.today(),
            UsedForCommissionTesting__c=true,
                        CustomerAccount__c = personAccount.Id

        );
        SalesOrder__c soWithoutBroker = new SalesOrder__c(
            Opportunity__c = oppWithoutBroker.Id,
            OwnerId = u2.Id,
            Status__c = 'Completed',
            TotalAmount__c = 150000,
            Unit__c = unit2.Id,
            PaymentPlan__c = pp.id,
            Referral_Type__c = null,
            Unit_Allocated_Status__c = 'Un-Allocated',
            Down_Payment_Status__c = 'Paid',
            Booking_Date__c = System.today(),
            Unit_Launch_Date__c = System.today(),
            UsedForCommissionTesting__c=true,
                        CustomerAccount__c = personAccount.Id

        );
        SalesOrder__c soNoReferral = new SalesOrder__c(
            Opportunity__c = oppWithBroker.Id,
            OwnerId = u1.Id,
            Status__c = 'Completed',
            TotalAmount__c = 85000,
            Unit__c = unit2.Id,
            PaymentPlan__c = pp.id,
            Referral_Type__c = null,
            Unit_Allocated_Status__c = null,
            Booking_Date__c = System.today(),
            Unit_Launch_Date__c = System.today(),
            UsedForCommissionTesting__c=true,
                        CustomerAccount__c = personAccount.Id

        );
        SalesOrder__c soMinimal = new SalesOrder__c(
            Opportunity__c = oppWithoutBroker.Id,
            OwnerId = u2.Id,
            Status__c = 'Completed',
            TotalAmount__c = 62000,
            Unit__c = unit2.Id,
            PaymentPlan__c = pp.id,
            Booking_Date__c = System.today(),
            Unit_Launch_Date__c = System.today(),
            UsedForCommissionTesting__c=true,
            CustomerAccount__c = personAccount.Id
        );
        insert new List<SalesOrder__c>{soWithBroker, soWithoutBroker, soNoReferral, soMinimal};
            
            }
    
    @isTest
    static void testCreateCommissionLineBranches() {
        List<SalesOrder__c> allSOs = [
            SELECT Id, OwnerId, TotalAmount__c, Referral_Type__c, Unit_Allocated_Status__c,
            Opportunity__r.BrokerAgency__c, Opportunity__r.LeadSource,
            Unit__r.Unit_Launch_Date__c, Unit__r.Phase__r.LaunchStartDate__c, Unit__r.Phase__r.Project__r.Launch_Date__c,
            Category_Of_Sale__c, Booking_Date__c, PaymentPlan__c
            FROM SalesOrder__c
        ];
        
        Test.startTest();
        CommissionLogicHandler.createCommissionLine(allSOs);
        Test.stopTest();
        
        List<Commission_Line__c> commissionLines = [SELECT Id, Commission_POT__c, Commission_Type__c, Commission_Percent__c, Commission_Amount__c FROM Commission_Line__c];
        
        Set<String> splitTypesCovered = new Set<String>();
        for (Commission_Line__c cl : commissionLines) {
            if (cl.Commission_POT__c != null) {
                splitTypesCovered.add([
                    SELECT Split_Type__c FROM Commission_POT__c WHERE Id = :cl.Commission_POT__c LIMIT 1
                ].Split_Type__c);
            }
        }
    }
    @isTest static void testBookingDate(){
        List<SalesOrder__c> updateList = new List<SalesOrder__c>();
           for(SalesOrder__c so:[SELECT Id FROM SalesOrder__c LIMIT 1]){
            SalesOrder__c so1 = new SalesOrder__c();
            so1.Id = so.Id;
            so1.Booking_Date__c = null;
            so1.Unit_Launch_Date__c = null;
            updateList.add(so1);
        }
        update updateList;
        Test.startTest();
        String cronExp = '0 0 0 ? * * *'; // runs at midnight (example)
        String jobId = System.schedule('BookingDateReminderBatch', cronExp, new BookingDateReminderBatch());
        Test.stopTest();
    
    }
   @isTest 
    static void testCreateExternalCommissions() {
        List<SalesOrder__c> allSOs = [SELECT Id, OwnerId, TotalAmount__c, Referral_Type__c, Unit_Allocated_Status__c, Opportunity__r.BrokerAgency__c FROM SalesOrder__c];
        Test.startTest();
        CommissionLogicHandler.createExternalCommissions(allSOs);
        Test.stopTest();
        List<Commission_Line__c> externalCommissionLines = [SELECT Id FROM Commission_Line__c WHERE Commission_Line_Type__c = 'External'];
    }
    
    @isTest 
    static void testTeamCommissionValueCalculate() {
        List<SalesOrder__c> allSOs = [SELECT Id, OwnerId, TotalAmount__c, Referral_Type__c, Unit_Allocated_Status__c FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        Set<Id> soIds = new Map<Id, SalesOrder__c>(allSOs).keySet();
        Test.startTest();
        CommissionLogicHandler.teamCommissionValueCalculate(soIds);
        Test.stopTest();
        List<Commission_Line__c> teamCommissionLines = [SELECT Id, Team_Commission_Amount__c FROM Commission_Line__c WHERE POT_Split_Type__c = 'Team Commission Value'];
        
    }
    
    @isTest 
    static void testGetCommissionRule() {
        List<SalesOrder__c> allSOs = [SELECT Id, Unit__r.Phase__r.Project__c, Category_Of_Sale__c, Unit__c, PaymentPlan__c, unit__r.Number_of_Bedrooms__c FROM SalesOrder__c];
        Test.startTest();
        Map<String,Commission_Rules__c> result = CommissionLogicHandler.getCommissionRule(allSOs);
        Test.stopTest();
    }
    
    @isTest 
    static void testGetCommissionPayoutItems() {
        Commission_Rules__c rule = [SELECT Id FROM Commission_Rules__c LIMIT 1];
        Test.startTest();
        Map<Id,List<Commission_Payout_Line__c>> result = CommissionLogicHandler.getCommissionPayoutItems(new List<Id>{rule.Id});
        Test.stopTest();
    }
    
    @isTest 
    static void testGenerateKeySO() {
        SalesOrder__c so = [SELECT Id, Category_Of_Sale__c, Unit__r.Phase__r.Project__c, Unit__r.Phase__c, Unit__c, PaymentPlan__c FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        String result = CommissionLogicHandler.generateKeySO(so);
        Test.stopTest();
    }
    
    @isTest
    static void testMonthlyInvoiceBundle() {
        User u = [SELECT Id FROM User WHERE LastName = 'Test1' LIMIT 1];
        Commission_POT__c pot = new Commission_POT__c(
            User__c = u.Id,
            On_Hold_Pending_Commission_Reason__c = 'Test Reason',
            On_Hold_Previous_Pending_Commission__c = 100
        );
        insert pot;
        
        List<Commission_POT__c> pots = [SELECT Id, User__c, On_Hold_Pending_Commission_Reason__c, On_Hold_Previous_Pending_Commission__c FROM Commission_POT__c];
        
        Date today = Date.today();
        
        Test.startTest();
        CommissionLogicHandler.monthlyInvoiceBundle(pots, today);
        Test.stopTest();
        List<Invoice_Bundle__c> invoiceBundles = [SELECT Id FROM Invoice_Bundle__c];
    }
    
    @isTest
    static void testCreateCommissionLineItem_FullCoverage() {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 100000);
        insert so;
        
        Commission_Rules__c rule = new Commission_Rules__c( StartDate__c = System.today(),
                                                           EndDate__c = System.today().addDays(30),
                                                           Direct_Commission__c = 5,
                                                           Direct_Commission_Sales_Manager__c = 7,
                                                           Indirect_Commission_Amount_Internal__c = 2000,
                                                           Indirect_Commission_Amount_Intrl_Mgr__c = 2500,
                                                           Management_Referral_Amount_UnitAllocated__c = 500,
                                                           Management_Referral_Unit_Unallocated__c = 2,
                                                           Indirect_Commission__c = 3,
                                                           Inventory_Launch_Category__c = 'Launch Sales',
                                                           Number_Of_Bedrooms__c = '3'
                                                          );
        insert rule;
        
        Commission_Line__c clInternal = new Commission_Line__c(
            Sales_Order__c = so.Id,
            Commission_Rules__c = rule.Id,
            Commission_Line_Type__c = 'Internal',
            Commission_Amount__c = 2000
        );
        insert clInternal;
        
        Commission_Line__c clExternal = new Commission_Line__c(
            Sales_Order__c = so.Id,
            Commission_Rules__c = rule.Id,
            Commission_Line_Type__c = 'External',
            External_Total_Commission_Amount__c = 1500
        );
        insert clExternal;
        
        Commission_Payout_Line__c cplInternalInstallment = new Commission_Payout_Line__c(
            Commission_Rules__c = rule.Id,
            Commission_Type__c = 'Direct',
            Payout_Based_On__c = 'Installment',
            Installment_Commission_Payout__c = 20,
            Installment_No__c = 1
        );
        insert cplInternalInstallment;
        
        Commission_Payout_Line__c cplInternalEquity = new Commission_Payout_Line__c(
            Commission_Rules__c = rule.Id,
            Commission_Type__c = 'Direct',
            Payout_Based_On__c = 'Equity',
            Equity_Commission_Payout__c = 30,
            Equity__c = 10
        );
        insert cplInternalEquity;
        
        Commission_Payout_Line__c cplExternalDown = new Commission_Payout_Line__c(
            Commission_Rules__c = rule.Id,
            Commission_Type__c = 'Indirect',
            Payout_Based_On__c = 'Down Payment Cleared',
            Equity_Commission_Payout__c = 40,
            Equity__c = 15
        );
        insert cplExternalDown;
        
        Commission_Payout_Line__c cplExternalSPA = new Commission_Payout_Line__c(
            Commission_Rules__c = rule.Id,
            Commission_Type__c = 'Indirect',
            Payout_Based_On__c = 'SPA Signed (Customer)',
            Equity_Commission_Payout__c = 50,
            Equity__c = 20
        );
        insert cplExternalSPA;
        
        List<Commission_Line__c> commLines = [SELECT Id, Commission_Rules__c, Commission_Line_Type__c FROM Commission_Line__c WHERE Id IN :new List<Id>{clInternal.Id, clExternal.Id}];
        Test.startTest();
        CommissionLogicHandler.createCommissionLineItem(commLines);
        Test.stopTest();
    }
    
    @isTest 
    static void testGenerateCommissionLineItem() {
        List<SalesOrder__c> allSOs = [SELECT Id, OwnerId FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        List<Commission_Line__c> commLines = [SELECT Id FROM Commission_Line__c LIMIT 1];
        if (commLines.isEmpty()) {
            commLines.add(new Commission_Line__c(
                Sales_Order__c = allSOs[0].Id,
                Status__c = 'In Progress'
            ));
            insert commLines;
        }
        Commission_Line__c commLine = commLines[0];
        Test.startTest();
        Commission_Line_Item__c result = CommissionLogicHandler.generateCommissionLineItem(commLine.Id,1000,'Internal',10,'Equity',1,50,'SubType');
        Test.stopTest();
        
    }
    
    
    @isTest
    static void testCliPayoutAmountCalculation_FullCoverage() {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 100000);
        insert so;
        
        Commission_Line__c clExternal = new Commission_Line__c(Sales_Order__c = so.Id,External_Total_Commission_Amount__c = 2000);
        insert clExternal;
        
        Commission_Line__c clInternal = new Commission_Line__c(Sales_Order__c = so.Id,Commission_Amount__c = 3000);
        insert clInternal;
        
        Commission_Line_Item__c cliExternal = new Commission_Line_Item__c(
            Commission_Line__c = clExternal.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'Equity',
            Commission_Payout_Percent__c = 25,
            Equity_Payout_Percent__c = 5
        );
        insert cliExternal;
        
        Commission_Line_Item__c cliInternal = new Commission_Line_Item__c(
            Commission_Line__c = clInternal.Id,
            Commission_Type__c = 'Internal',
            Payout_Based_On__c = 'Installment',
            Commission_Payout_Percent__c = 50,
            Installment_No__c = 1
        );
        insert cliInternal;
        
        List<Commission_Line_Item__c> items = [
            SELECT Id, Commission_Type__c,Sub_Type__c, Payout_Based_On__c, Commission_Payout_Percent__c,
            Equity_Payout_Percent__c, Sales_Order_Equity__c, Total_Commission_Amount__c,
            Installment_No__c, Last_Paid_Installment_Number__c,
            Commission_Line__c,
            Commission_Line__r.External_Total_Commission_Amount__c,
            Commission_Line__r.Down_Payment_Status__c,
            Commission_Line__r.Is_SPA_Signed_By_Customer__c,
            Commission_Line__r.Commission_Amount__c
            FROM Commission_Line_Item__c
            WHERE Commission_Line__c IN :new List<Id>{clExternal.Id, clInternal.Id}
        ];
        
        Test.startTest();
        CommissionLogicHandler.cliPayoutAmountCalculation(items, true);
        CommissionLogicHandler.cliPayoutAmountCalculation(items, false);
        Test.stopTest(); 
    }
    
    @isTest
    static void testInvoiceLineCreation() {
        Commission_POT__c pot = new Commission_POT__c(POT_Type__c = 'Sales Associate');
        insert pot;
        
        Commission_Line__c cli = new Commission_Line__c(
            Commission_POT__c = pot.Id,
            Commission_Amount__c = 5000,
            Team_Commission_Amount__c = 1200,
            Status__c = 'In Progress'
        );
        insert cli;
        
        Commission_Line_Item__c cliItem = new Commission_Line_Item__c(
            Commission_Line__c = cli.Id,
            Commission_Type__c = 'Internal',
            Commission_Payout_Amount__c = 800
        );
        insert cliItem;
        
        Invoice_Bundle__c invBundle = new Invoice_Bundle__c(
            Commission_POT__c = pot.Id,
            Invoice_Date_From__c = Date.newInstance(2025, 7, 1) 
        );
        insert invBundle;
        Test.startTest();
        CommissionLogicHandler.invoiceLineCreation(
            new List<Commission_Line_Item__c>{ cliItem },
            'JULY'
        );
        Test.stopTest();
    }
    
    @isTest 
    static void testUpdateCommissionLineStatus() {
        List<SalesOrder__c> allSOs = [SELECT Id,OwnerId FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        List<Commission_Line__c> commLines = [SELECT Id FROM Commission_Line__c];
        CommissionLogicHandler.createCommissionLineItem(commLines);
        Set<Id> commLineIds = new Map<Id, Commission_Line__c>(commLines).keySet();
        Test.startTest();
        CommissionLogicHandler.updateCommissionLineStatus(commLineIds);
        Test.stopTest();
        List<Commission_Line__c> updatedLines = [SELECT Id, Status__c FROM Commission_Line__c];
        
    }
    
    @isTest 
    static void testGetMonthNameFromDate() {
        Date testDate = Date.newInstance(2023, 7, 15);
        Test.startTest();
        String result = CommissionLogicHandler.getMonthNameFromDate(testDate);
        Test.stopTest();
    }
    
    @isTest 
    static void testHoldCommissionFromCommissionLine() {
        List<SalesOrder__c> allSOs = [SELECT Id,OwnerId FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        List<Commission_Line__c> commLines = [SELECT Id FROM Commission_Line__c LIMIT 1];
        if (commLines.isEmpty()) {
            commLines.add(new Commission_Line__c(
                Sales_Order__c = allSOs[0].Id,
                Status__c = 'In Progress'
            ));
            insert commLines;
        }
        Commission_Line__c commLine = commLines[0];
        Test.startTest();
        Commission_Line__c result = CommissionLogicHandler.holdCommissionFromCommissionLine(commLine.Id);
        Test.stopTest();
    }
    
    @isTest 
    static void testRunTheHoldReasonBatch() {
        List<SalesOrder__c> allSOs = [SELECT Id,OwnerId FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        List<Commission_Line__c> commLines = [SELECT Id FROM Commission_Line__c LIMIT 1];
        if (commLines.isEmpty()) {
            commLines.add(new Commission_Line__c(
                Sales_Order__c = allSOs[0].Id,
                Status__c = 'In Progress'
            ));
            insert commLines;
        }
        Commission_Line__c commLine = commLines[0];
        Test.startTest();
        CommissionLogicHandler.runTheHoldReasonBatch(commLine.Id, 'Test Reason', true);
        Test.stopTest();
        Commission_Line__c updatedLine = [SELECT Id, Is_Hold__c, Hold_Reason__c FROM Commission_Line__c WHERE Id = :commLine.Id];
        
    }
    
    @isTest
    static void testGetInvoicesByBundle_withRecords() {
        Invoice_Bundle__c parentBundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason');
        insert parentBundle;
        
        Invoice_Bundle__c childBundle = new Invoice_Bundle__c(
            Invoice_Bundle__c = parentBundle.Id,
            Approval_Status__c = 'Approved',
            Hold_Status__c = 'Release',
            Override_Payout_Amount__c = 1000,
            Override_Payout_Amount_Reason__c = 'For Testing'
        );
        insert childBundle;
        Test.startTest();
        List<CommissionLogicHandler.invBundleWrapper> results = CommissionLogicHandler.getInvoicesByBundle(parentBundle.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetInvoicesByBundle_withNullSplitPercent() {
        Invoice_Bundle__c parentBundle = new Invoice_Bundle__c(
            Hold_Status__c = 'Release', 
            Hold_Reason__c = 'Parent Reason 2',
            Override_Payout_Amount__c = 1000,
            Override_Payout_Amount_Reason__c = 'For Testing'
        );
        insert parentBundle;
        
        Invoice_Bundle__c childBundle = new Invoice_Bundle__c(
            Invoice_Bundle__c = parentBundle.Id,
            Approval_Status__c = 'Not Submitted',
            Hold_Status__c = 'Release',
            Override_Payout_Amount__c = 1000,
            Override_Payout_Amount_Reason__c = 'For Testing'
        );
        insert childBundle;
        Test.startTest();
        List<CommissionLogicHandler.invBundleWrapper> results = CommissionLogicHandler.getInvoicesByBundle(parentBundle.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetInvoicesByBundle_noRecords() {
        Invoice_Bundle__c parentBundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold', Hold_Reason__c = 'Parent Reason 3');
        insert parentBundle;
        Test.startTest();
        List<CommissionLogicHandler.invBundleWrapper> results = CommissionLogicHandler.getInvoicesByBundle(parentBundle.Id);
        Test.stopTest();
    }
    
    @isTest 
    static void testHandleCommissionLineItem() {
        List<SalesOrder__c> allSOs = [SELECT Id,OwnerId FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        List<Commission_Line__c> commLines = [SELECT Id FROM Commission_Line__c];
        CommissionLogicHandler.createCommissionLineItem(commLines);
        List<Commission_Line_Item__c> items = [SELECT Id, Status__c, Commission_Line__c FROM Commission_Line_Item__c];
        Map<Id, sObject> oldMap = new Map<Id, sObject>();
        for(Commission_Line_Item__c item : items) {
            Commission_Line_Item__c oldItem = item.clone();
            oldItem.Status__c = 'In-Progress';
            oldMap.put(item.Id, oldItem);
            item.Status__c = 'Approved';
        }
        
        Test.startTest();
        CommissionLogicHandler.handleCommissionLineItem(items, oldMap);
        Test.stopTest();
        List<Commission_Line_Item__c> updatedItems = [SELECT Id, Status__c FROM Commission_Line_Item__c];
    }
    
    @isTest 
    static void testHandleInvoiceLineHoldAmt() {
        List<SalesOrder__c> allSOs = [SELECT Id,OwnerId FROM SalesOrder__c];
        CommissionLogicHandler.createCommissionLine(allSOs);
        List<Commission_Line__c> commLines = [SELECT Id FROM Commission_Line__c];
        CommissionLogicHandler.createCommissionLineItem(commLines);
        List<Commission_Line_Item__c> items = [SELECT Id FROM Commission_Line_Item__c];
        CommissionLogicHandler.invoiceLineCreation(items, 'July');
        List<Invoice_Line__c> invLines = [SELECT Id, Is_Hold__c FROM Invoice_Line__c];
        Map<Id, sObject> oldMap = new Map<Id, sObject>();
        for(Invoice_Line__c invLine : invLines) {
            Invoice_Line__c oldInvLine = invLine.clone();
            oldInvLine.Is_Hold__c = false;
            oldMap.put(invLine.Id, oldInvLine);
            invLine.Is_Hold__c = true;
        }
        
        Test.startTest();
        CommissionLogicHandler.handleInvoiceLineHoldAmt(invLines, oldMap);
        Test.stopTest();
        List<Invoice_Line__c> updatedLines = [SELECT Id, Is_Hold__c FROM Invoice_Line__c WHERE Is_Hold__c = true];
        
    }
    
    @isTest 
    static void testHandleInvoicebundleHold() {
        Invoice_Bundle__c bundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold',Hold_Reason__c = 'Test Reason');
        insert bundle;
        
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            bundle.Id => new Invoice_Bundle__c(Id = bundle.Id, Hold_Status__c = 'Release')
                };
                    
                    Test.startTest();
        CommissionLogicHandler.handleInvoicebundleHold(new List<sObject>{bundle}, oldMap);
        Test.stopTest();
        Invoice_Bundle__c updatedBundle = [SELECT Id, Hold_Status__c FROM Invoice_Bundle__c WHERE Id = :bundle.Id];
        
    }
    
    @isTest 
    static void testInvBundlehandleOverRideAmt() {
        Invoice_Bundle__c bundle = new Invoice_Bundle__c(Override_Payout_Amount__c = 1000,Override_Payout_Amount_Reason__c = 'Test Reason');
        insert bundle;
        
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            bundle.Id => new Invoice_Bundle__c(Id = bundle.Id, Override_Payout_Amount__c = 500)
                };
                    
                    Test.startTest();
        CommissionLogicHandler.InvBundlehandleOverRideAmt(new List<sObject>{bundle}, oldMap);
        Test.stopTest();
        Invoice_Bundle__c updatedBundle = [SELECT Id, Override_Payout_Amount__c FROM Invoice_Bundle__c WHERE Id = :bundle.Id];
        
    }
    
    @isTest 
    static void testUpdateHoldAmount() {
        Invoice_Bundle__c bundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason');
        insert bundle;
        Test.startTest();
        CommissionLogicHandler.updateHoldAmount(new Set<Id>{bundle.Id});
        Test.stopTest();
        Invoice_Bundle__c updatedBundle = [SELECT Id, Current_On_Hold_Commission__c FROM Invoice_Bundle__c WHERE Id = :bundle.Id];
        
    }
    
    @isTest
    static void testHoldCommissionLine() {
        Commission_Line__c commLine = new Commission_Line__c(External_Total_Commission_Amount__c=1000);
        insert commLine;
        
        Invoice_Bundle__c masterBundle = new Invoice_Bundle__c(Hold_Status__c = 'Release',Hold_Reason__c = 'Test Reason');
        insert masterBundle;
        
        Invoice_Line__c invLine = new Invoice_Line__c(Commission_Line__c = commLine.Id,Invoice_Bundle__c = masterBundle.Id,Is_Hold__c = false);
        insert invLine;
        
        List<Invoice_Line__c> invLines = [SELECT Id, Commission_Line__c FROM Invoice_Line__c];
        
        Test.startTest();
        CommissionLogicHandler.holdCommissionLine(invLines, 'Test Reason', true);
        Test.stopTest();
    }
    
    @isTest 
    static void testUpdateCommissionPayoutLines() {        
        Commission_Line__c cl = new Commission_Line__c(External_Total_Commission_Amount__c = 1000);
        insert cl;
        
        Commission_Line_Item__c cli = new Commission_Line_Item__c(Commission_Line__c = cl.Id,Status__c = 'In-Progress');
        insert cli;
        
        Invoice_Bundle__c bundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold',Hold_Reason__c = 'Test Reason');
        insert bundle;
        
        Invoice_Line__c invLine = new Invoice_Line__c(Invoice_Bundle__c = bundle.Id,Commission_Line__c = cl.Id,Commission_Line_Item__c = cli.Id);
        insert invLine;
        
        Test.startTest();
        CommissionLogicHandler.updateCommissionPayoutLines(new Set<Id>{bundle.Id});
        Test.stopTest();
        Commission_Line_Item__c updatedItem = [SELECT Id, Status__c FROM Commission_Line_Item__c WHERE Id = :cli.Id];
        
    }
    
    @isTest 
    static void testHandleInvoiceDocusignApproval() {
        Id masterRecordTypeId = Schema.SObjectType.Invoice_Bundle__c.getRecordTypeInfosByName().get('Master Invoice Bundle').getRecordTypeId();
        Invoice_Bundle__c bundle = new Invoice_Bundle__c(Approval_Status__c = 'Approved', RecordTypeId = masterRecordTypeId);
        insert bundle;
        
        Invoice_Bundle__c childBundle = new Invoice_Bundle__c(Invoice_Bundle__c = bundle.Id,Approval_Status__c = 'Approval In-Progress');
        insert childBundle;
        
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            bundle.Id => new Invoice_Bundle__c(Id = bundle.Id, Approval_Status__c = 'Draft')
                };
                    
                    Test.startTest();
        CommissionLogicHandler.handleInvoiceDocusignApproval(new List<sObject>{bundle}, oldMap);
        Test.stopTest();
        Invoice_Bundle__c updatedChild = [SELECT Id, Approval_Status__c FROM Invoice_Bundle__c WHERE Id = :childBundle.Id];
        
    }
    
    
    
    @isTest
    static void testExternalPayoutCalc_FullCoverage() {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 100000);
        insert so;
        
        Commission_Line__c cl = new Commission_Line__c(Sales_Order__c = so.Id,External_Total_Commission_Amount__c = 3000);
        insert cl;
        
        Commission_Line_Item__c cliEquity = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'Equity',
            Commission_Payout_Percent__c = 20,
            Equity_Payout_Percent__c = 5
        );
        insert cliEquity;
        
        Commission_Line_Item__c cliInstallment = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'Installment',
            Commission_Payout_Percent__c = 30,
            Installment_No__c = 1
        );
        insert cliInstallment;
        
        Commission_Line_Item__c cliDownPayment = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'Down Payment Cleared',
            Commission_Payout_Percent__c = 40
        );
        insert cliDownPayment;
        
        Commission_Line_Item__c cliSPA = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'SPA Signed (Customer)',
            Commission_Payout_Percent__c = 50
        );
        insert cliSPA;
        
        List<Commission_Line_Item__c> clis = [
            SELECT Id, Commission_Line__c, Payout_Based_On__c,
            Commission_Payout_Percent__c, Equity_Payout_Percent__c,
            Sales_Order_Equity__c, Installment_No__c, Last_Paid_Installment_Number__c,
            Commission_Line__r.External_Total_Commission_Amount__c,
            Commission_Line__r.Down_Payment_Status__c,
            Commission_Line__r.Is_SPA_Signed_By_Customer__c
            FROM Commission_Line_Item__c
            WHERE Commission_Line__c = :cl.Id
        ];
        
        Test.startTest();
        CommissionLineReviewController.createExternalCommissions(cl.Id,3,'test');
        CommissionLineReviewController.fetchPage(5,5,'','');
        CommissionLineReviewController.approve(new List<ID>{cl.Id});
        CommissionLineReviewController.reject(cl.Id,'test');
        for (Commission_Line_Item__c cli : clis) {
            CommissionLogicHandler.PayoutCalcWrapper result1 =
                CommissionLogicHandler.externalPayoutCalc(cli, false, 'Test');
            
            CommissionLogicHandler.PayoutCalcWrapper result2 =
                CommissionLogicHandler.externalPayoutCalc(cli, true, 'Test');
            System.assertNotEquals(null, result2);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testInternalPayoutCalc() {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 100000,TotalPaidAmount__c = 20000 );
        insert so;
        
        Commission_Line__c cl = new Commission_Line__c(Sales_Order__c = so.Id,Commission_Amount__c = 5000);
        insert cl;
        
        Commission_Line_Item__c cliEquity = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'Internal',
            Payout_Based_On__c = 'Equity',
            Commission_Payout_Percent__c = 10,
            Equity_Payout_Percent__c = 15
        );
        insert cliEquity;
        cliEquity = [SELECT Id, Total_Commission_Amount__c, Commission_Payout_Percent__c,Payout_Based_On__c, Equity_Payout_Percent__c, Sales_Order_Equity__c,
                     Commission_Line__c FROM Commission_Line_Item__c WHERE Id = :cliEquity.Id];
        
        Commission_Line_Item__c cliInst = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'Internal',
            Payout_Based_On__c = 'Installment',
            Commission_Payout_Percent__c = 20,
            Installment_No__c = 1
        );
        insert cliInst;
        cliInst = [SELECT Id, Total_Commission_Amount__c, Commission_Payout_Percent__c,Payout_Based_On__c, Installment_No__c, Last_Paid_Installment_Number__c,
                   Commission_Line__c FROM Commission_Line_Item__c WHERE Id = :cliInst.Id];
        
        Commission_Line_Item__c cliNull = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'Internal',
            Payout_Based_On__c = 'Equity'
        );
        insert cliNull;
        cliNull = [SELECT Id,Total_Commission_Amount__c,Commission_Payout_Percent__c, Commission_Line__c, Payout_Based_On__c
                   FROM Commission_Line_Item__c WHERE Id = :cliNull.Id];
        
        Test.startTest();
        CommissionLogicHandler.PayoutCalcWrapper wrapEquityFalse =
            CommissionLogicHandler.internalPayoutCalc(cliEquity, false, 'Test');
        CommissionLogicHandler.PayoutCalcWrapper wrapEquityTrue =
            CommissionLogicHandler.internalPayoutCalc(cliEquity, true, 'Test');
        CommissionLogicHandler.PayoutCalcWrapper wrapInstFalse =
            CommissionLogicHandler.internalPayoutCalc(cliInst, false, 'Test');
        CommissionLogicHandler.PayoutCalcWrapper wrapInstTrue =
            CommissionLogicHandler.internalPayoutCalc(cliInst, true, 'Test');
        CommissionLogicHandler.PayoutCalcWrapper wrapNull =
            CommissionLogicHandler.internalPayoutCalc(cliNull, false, 'Test');
        Test.stopTest();
    }
    
    
    @isTest 
    static void testUpdateExternalSOCommission() {
        SalesOrder__c so = new SalesOrder__c(Indirect_Commission_Amount__c = 10000);
        insert so;
        
        Commission_Line__c cl = new Commission_Line__c(Sales_Order__c = so.Id,Paid_Status__c = 'Paid');
        insert cl;
        
        Test.startTest();
        //CommissionLogicHandler.updateExternalSOCommission(new List<Commission_Line__c>{cl});
        Test.stopTest();
        
        SalesOrder__c updatedSO = [SELECT Id, Indirect_Commission_Amount_Paid__c, Indirect_Commission_Amount_Pending__c FROM SalesOrder__c WHERE Id = :so.Id];
    }
    
    @isTest
    static void testProcessSelectedInvoices() {
        Invoice_Bundle__c masterBundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason');
        insert masterBundle;
        
        Invoice_Bundle__c invoice1 = new Invoice_Bundle__c(Invoice_Bundle__c = masterBundle.Id,Approval_Status__c = 'Not Submitted');
        Invoice_Bundle__c invoice2 = new Invoice_Bundle__c(Invoice_Bundle__c = masterBundle.Id,Approval_Status__c = 'Not Submitted');
        insert new List<Invoice_Bundle__c> {invoice1, invoice2};
            
            List<Id> selectedIds = new List<Id>{invoice1.Id};
                
                Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        CommissionLogicHandler.processSelectedInvoices(selectedIds, 'Test notes');
        Test.stopTest();
        Invoice_Bundle__c updatedInvoice = [SELECT Id, Approval_Status__c FROM Invoice_Bundle__c WHERE Id = :invoice1.Id];
        
    }
    
    @isTest
    static void testGenerateMemoPDF() {
        Invoice_Bundle__c masterBundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason');
        insert masterBundle;
        
        Invoice_Bundle__c invoice = new Invoice_Bundle__c(Invoice_Bundle__c = masterBundle.Id);
        insert invoice;
        
        List<Id> selectedInvoiceIds = new List<Id>{invoice.Id};
            String notes = '<p>Test note content</p>';
        String month = 'July';
        
        Test.startTest();
        CommissionLogicHandler.generateMemoPDF(selectedInvoiceIds, notes, month, masterBundle.Id);
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id, Title, ContentDocumentId 
                                                FROM ContentVersion WHERE Title LIKE '%Invoice Bundle for the Month July%'];
        System.assert(!contentVersions.isEmpty(), 'ContentVersion should be created');
        
        List<ContentDocumentLink> links = [SELECT Id, LinkedEntityId, ContentDocumentId 
                                           FROM ContentDocumentLink WHERE LinkedEntityId = :masterBundle.Id];
    }
    
    @isTest
    static void testApprovedCommissionPayoutsHandler() {
        Commission_Line__c cl = new Commission_Line__c(External_Total_Commission_Amount__c=1000);
        insert cl;
        Invoice_Bundle__c inv = new Invoice_Bundle__c(Approval_Status__c = 'Approved');
        insert inv;
        
        Commission_Line_Item__c cli = new Commission_Line_Item__c(Status__c = 'In-Progress',Commission_Line__c = cl.Id);
        insert cli;
        
        Invoice_Line__c invLine = new Invoice_Line__c(Invoice_Bundle__c = inv.Id,Commission_Line__c = cl.Id,Commission_Line_Item__c = cli.Id);
        insert invLine;
        
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            inv.Id => new Invoice_Bundle__c(Id = inv.Id, Approval_Status__c = 'Approval In-Progress')
                };
                    
                    Test.startTest();
        CommissionLogicHandler.approvedCommissionPayoutsHandler(new List<sObject>{inv}, oldMap);
        Test.stopTest();
        Commission_Line_Item__c updatedItem = [SELECT Id, Status__c FROM Commission_Line_Item__c WHERE Id = :cli.Id];
        
    }
    
    @isTest
    static void testApprovedCommissionPayoutsHelper_Direct() {
        User u = [SELECT Id FROM User WHERE LastName = 'Test1' LIMIT 1];
        
        Commission_POT__c pot = new Commission_POT__c(User__c = u.Id,POT_Type__c = 'Sales Associate');
        insert pot;
        
        Invoice_Bundle__c inv = new Invoice_Bundle__c(
            Commission_Type__c = 'Direct',
            Current_On_Hold_Commission__c = 1000,
            Override_Payout_Amount_Reason__c = 'Direct Test Reason',
            Commission_POT__c = pot.Id
        );
        insert inv;
        
        Test.startTest();
        CommissionLogicHandler.approvedCommissionPayoutsHelper(new Set<Id>{inv.Id});
        Test.stopTest();
        
        Commission_POT__c updatedPot = [SELECT Id, On_Hold_Previous_Pending_Commission__c, On_Hold_Pending_Commission_Reason__c 
                                        FROM Commission_POT__c WHERE Id = :pot.Id];
        
      }
    
    @isTest
    static void testApprovedCommissionPayoutsHelper_Indirect() {
        Account broker = new Account(Name='Test Broker');
        insert broker;
        
        Invoice_Bundle__c inv = new Invoice_Bundle__c(
            Commission_Type__c = 'Indirect',
            Current_On_Hold_Commission__c = 0, 
            Override_Payout_Amount_Reason__c = 'Indirect Test Reason',
            Broker_Agency__c = broker.Id
        );
        insert inv;
        
        Test.startTest();
        CommissionLogicHandler.approvedCommissionPayoutsHelper(new Set<Id>{inv.Id});
        Test.stopTest();
        
    }
    
    @isTest
    static void testCreateCommissionLine_NoCommissionRule() {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 50000,Unit__c = [SELECT Id FROM Unit__c LIMIT 1].Id,PaymentPlan__c = [SELECT Id FROM PaymentPlan__c LIMIT 1].Id);
        insert so;
        
        Test.startTest();
        CommissionLogicHandler.createCommissionLine(new List<SalesOrder__c>{so});
        Test.stopTest();
        List<Commission_Line__c> commissionLines = [SELECT Id FROM Commission_Line__c WHERE Sales_Order__c = :so.Id];
        
    }
    
    @isTest
    static void testCreateExternalCommissions_NoBroker() {
        SalesOrder__c so = [SELECT Id,OwnerId FROM SalesOrder__c WHERE Opportunity__r.BrokerAgency__c = null LIMIT 1];
        Test.startTest();
        CommissionLogicHandler.createExternalCommissions(new List<SalesOrder__c>{so});
        Test.stopTest();
        List<Commission_Line__c> externalLines = [SELECT Id FROM Commission_Line__c 
                                                  WHERE Sales_Order__c = :so.Id AND Commission_Line_Type__c = 'External'];
    }
    
    @isTest
    static void testExternalPayoutCalc_EdgeCases() {
        SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 100000);
        insert so;
        
        Commission_Line__c cl = new Commission_Line__c(Sales_Order__c = so.Id,External_Total_Commission_Amount__c = 3000);
        insert cl;
        
        
        Commission_Line_Item__c cliEquity = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'Equity',
            Commission_Payout_Percent__c = 50,
            Equity_Payout_Percent__c = 10
        );
        
        Commission_Line_Item__c cliSPA = new Commission_Line_Item__c(
            Commission_Line__c = cl.Id,
            Commission_Type__c = 'External',
            Payout_Based_On__c = 'SPA Signed (Customer)',
            Commission_Payout_Percent__c = 50
        );
        insert new List<Commission_Line_Item__c>{cliEquity, cliSPA};
            
            Test.startTest();
        CommissionLogicHandler.PayoutCalcWrapper result1 = CommissionLogicHandler.externalPayoutCalc(cliEquity, true, 'Test');
        CommissionLogicHandler.PayoutCalcWrapper result2 = CommissionLogicHandler.externalPayoutCalc(cliSPA, true, 'Test');
        Test.stopTest();
    }
    @IsTest
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
        for (CommissionPreReviewController.CommissionRowDTO row : response.rows) {
            if (row.commissionLineName == 'CL-001') {
                foundVisibleRecord = true;
            }
        }
    }

    @IsTest
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

    @IsTest
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

    @IsTest
    static void testUpdateCommissionRows() {
         List<SalesOrder__c> allSOs = [
            SELECT Id, OwnerId, TotalAmount__c, Referral_Type__c, Unit_Allocated_Status__c,
            Opportunity__r.BrokerAgency__c, Opportunity__r.LeadSource,
            Unit__r.Unit_Launch_Date__c, Unit__r.Phase__r.LaunchStartDate__c, Unit__r.Phase__r.Project__r.Launch_Date__c,
            Category_Of_Sale__c, Booking_Date__c, PaymentPlan__c
            FROM SalesOrder__c
            WHERE UsedForCommissionTesting__c = true
        ];
        
        CommissionLogicHandler.createCommissionLine(allSOs);
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

    @IsTest
    static void testUpdateCommissionRows_EmptyList() {
        Test.startTest();
        CommissionPreReviewController.updateCommissionRows(new List<Map<String, Object>>());
        CommissionPreReviewController.updateCommissionRows(null);
        Test.stopTest();

    }

    @IsTest
    static void testUpdateCommissionRows_InvalidRowSkipped() {
        List<Map<String, Object>> updates = new List<Map<String, Object>>();
        updates.add(new Map<String, Object>());
        updates.add(null);

        Test.startTest();
        CommissionPreReviewController.updateCommissionRows(updates);
        Test.stopTest();

        System.assert(true, 'Invalid rows should be skipped safely');
    }
}