@isTest
public class CommissionLineReviewControllerTest {

    @testSetup
    static void setupData() {
        Account personAccount = new Account(LastName = 'Smith');
        Account brokerAccount = new Account(Name = 'Broker Corp');
        insert new List<Account>{ personAccount, brokerAccount };

        Opportunity oppWithBroker = new Opportunity(
            Name = 'Opportunity With Broker',
            StageName = 'Closed Won',
            CloseDate = System.today(),
            AccountId = brokerAccount.Id,
            BrokerAgency__c = brokerAccount.Id,
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
            Name = 'Unit-101',
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
            Username = 'reviewuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'rusr',
            Email = 'reviewuser@test.com',
            LastName = 'Reviewer',
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
            Number_Of_Bedrooms__c = '3'
        );
        insert rule;

        Commission_Payout_Line__c payoutIndirect = new Commission_Payout_Line__c(
            Commission_Type__c = 'Indirect',
            Sub_Type__c = 'Indirect Commission',
            Payout_Based_On__c = 'Down Payment Cleared',
            Equity_Commission_Payout__c = 50.0,
            Commission_Rules__c = rule.Id
        );
        insert payoutIndirect;

        List<Commission_Line__c> lines = new List<Commission_Line__c>{
            new Commission_Line__c(
                Sales_Order__c = so.Id,
                Status__c = 'Internal Review In-Progress',
                Commission_Line_Type__c = 'External',
                //Unit__c = 'Unit-101',
                Commission_Amount__c = 1000,
                Comments__c = 'Initial'
            ),
            new Commission_Line__c(
                Sales_Order__c = so.Id,
                Status__c = 'Rejected',
                Commission_Line_Type__c = 'External',
                //Unit__c = 'Unit-102',
                Commission_Amount__c = 1200,
                Comments__c = 'Rejected before'
            ),
            new Commission_Line__c(
                Sales_Order__c = so.Id,
                Status__c = 'Ready To Process',
                Commission_Line_Type__c = 'External',
                //Unit__c = 'Unit-103',
                Commission_Amount__c = 1300
            ),
            new Commission_Line__c(
                Sales_Order__c = so.Id,
                Status__c = 'Internal Review In-Progress',
                Commission_Line_Type__c = 'Internal',
                //Unit__c = 'Unit-104',
                Commission_Amount__c = 1400
            )
        };
        insert lines;
    }

    @isTest
    static void testFetchPage_DefaultStatuses() {
        Test.startTest();
        CommissionLineReviewController.PageResult resultObj =
            CommissionLineReviewController.fetchPage(10, 1, null, null);
        Test.stopTest();
    }

    @isTest
    static void testFetchPage_WithFilters() {
        Test.startTest();
        CommissionLineReviewController.PageResult resultObj =
            CommissionLineReviewController.fetchPage(10, 1, 'Rejected', 'Unit-102');
        Test.stopTest();
    }

    @isTest
    static void testApprove() {
        List<Commission_Line__c> targetLines = [
            SELECT Id, Status__c, Comments__c
            FROM Commission_Line__c
            WHERE Status__c IN ('Internal Review In-Progress', 'Rejected')
            AND Commission_Line_Type__c = 'External'
            ORDER BY CreatedDate ASC
        ];

        Id inProgressId = null;
        Id rejectedId = null;
        for (Commission_Line__c cl : targetLines) {
            if (cl.Status__c == 'Internal Review In-Progress' && inProgressId == null) {
                inProgressId = cl.Id;
            } else if (cl.Status__c == 'Rejected' && rejectedId == null) {
                rejectedId = cl.Id;
            }
        }

        Test.startTest();
        CommissionLineReviewController.approve(new List<Id>{ inProgressId, rejectedId });
        Test.stopTest();

        Map<Id, Commission_Line__c> updatedMap = new Map<Id, Commission_Line__c>([
            SELECT Id, Status__c, Comments__c
            FROM Commission_Line__c
            WHERE Id IN :new List<Id>{ inProgressId, rejectedId }
        ]);
    }

    @isTest
    static void testApprove_NullAndEmpty() {
        Test.startTest();
        CommissionLineReviewController.approve(null);
        CommissionLineReviewController.approve(new List<Id>());
        Test.stopTest();
    }

    @isTest
    static void testReject() {
        Commission_Line__c target = [
            SELECT Id, Status__c
            FROM Commission_Line__c
            WHERE Status__c = 'Internal Review In-Progress'
            AND Commission_Line_Type__c = 'External'
            LIMIT 1
        ];

        Test.startTest();
        CommissionLineReviewController.reject(target.Id, 'Invalid calculation');
        Test.stopTest();

        Commission_Line__c updatedRec = [
            SELECT Id, Status__c, Comments__c
            FROM Commission_Line__c
            WHERE Id = :target.Id
        ];
    }

    @isTest
    static void testReject_NullAndNonEligible() {
        Commission_Line__c alreadyRejected = [
            SELECT Id, Status__c, Comments__c
            FROM Commission_Line__c
            WHERE Status__c = 'Rejected'
            LIMIT 1
        ];
        String oldComment = alreadyRejected.Comments__c;

        Test.startTest();
        CommissionLineReviewController.reject(null, 'Nothing');
        CommissionLineReviewController.reject(alreadyRejected.Id, 'Should not update');
        Test.stopTest();

        Commission_Line__c updatedRec = [
            SELECT Id, Status__c, Comments__c
            FROM Commission_Line__c
            WHERE Id = :alreadyRejected.Id
        ];
    }

    @isTest
    static void testCreateCommissionAudit() {
        Commission_Line__c lineRec = [SELECT Id FROM Commission_Line__c LIMIT 1];

        Commission_Audit__c auditRec = CommissionLineReviewController.createCommissionAudit(
            lineRec.Id,
            'Approved',
            UserInfo.getUserId(),
            'Looks good',
            'Internal Review In-Progress'
        );
    }

    @isTest
    static void testHandleCommissionStsChange() {
        Commission_Line__c lineRec = [
            SELECT Id, Status__c, Comments__c
            FROM Commission_Line__c
            WHERE Status__c = 'Internal Review In-Progress'
            LIMIT 1
        ];

        Commission_Line__c newRec = lineRec.clone(false, true, false, false);
        newRec.Id = lineRec.Id;
        newRec.Status__c = 'Ready To Process';
        newRec.Comments__c = 'Approved now';

        Map<Id, Commission_Line__c> oldMap = new Map<Id, Commission_Line__c>{
            lineRec.Id => lineRec
        };

        Test.startTest();
        CommissionLineReviewController.handleCommissionStsChange(
            new List<Commission_Line__c>{ newRec },
            oldMap
        );
        Test.stopTest();

        List<Commission_Audit__c> audits = [
            SELECT Id, Commission_Line__c, Status__c, Previous_Status__c, Comments__c
            FROM Commission_Audit__c
            WHERE Commission_Line__c = :lineRec.Id
        ];
    }

    @isTest
    static void testCreateExternalCommissions() {
        Commission_Line__c extLine = [
            SELECT Id, Sales_Order__c, Comments__c
            FROM Commission_Line__c
            WHERE Commission_Line_Type__c = 'External'
            LIMIT 1
        ];

        Test.startTest();
        CommissionLineReviewController.createExternalCommissions(extLine.Id, 3, 'Recalculate external');
        Test.stopTest();

        Commission_Line__c refreshed = [
            SELECT Id, Comments__c
            FROM Commission_Line__c
            WHERE Id = :extLine.Id
        ];
    }

    @isTest
    static void testUpdateSPADocId() {
        SalesOrder__c soRec = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Commission_Line__c extLine = new Commission_Line__c(
            Sales_Order__c = soRec.Id,
            Status__c = 'Internal Review In-Progress',
            Commission_Line_Type__c = 'External'
            //Unit__c = 'Unit-201'
        );
        insert extLine;

        Documents__c docRec = new Documents__c(
            Name = 'Signed SPA (Modon)',
            SalesOrder__c = soRec.Id,
            Status__c = 'Pending Upload'
        );
        insert docRec;

        ContentVersion cv = new ContentVersion(
            Title = 'Signed SPA File',
            PathOnClient = 'SignedSPA.pdf',
            VersionData = Blob.valueOf('Test File Body'),
            FirstPublishLocationId = docRec.Id
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        Documents__c newDoc = new Documents__c(
            Id = docRec.Id,
            Name = 'Signed SPA (Modon)',
            SalesOrder__c = soRec.Id,
            Status__c = 'Uploaded'
        );

        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            docRec.Id => new Documents__c(
                Id = docRec.Id,
                Name = 'Signed SPA (Modon)',
                SalesOrder__c = soRec.Id,
                Status__c = 'Draft'
            )
        };

        Test.startTest();
        CommissionLineReviewController.updateSPADocId(
            new List<sObject>{ newDoc },
            oldMap
        );
        Test.stopTest();

        Commission_Line__c updatedLine = [
            SELECT Id, SPADocumentId__c
            FROM Commission_Line__c
            WHERE Id = :extLine.Id
        ];
    }
}