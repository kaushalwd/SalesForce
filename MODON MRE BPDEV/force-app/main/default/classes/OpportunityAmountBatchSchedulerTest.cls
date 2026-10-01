/**********************************************************************************************************************
 * Name               : OpportunityAmountBatchSchedulerTest
 * Description        : Test coverage for OpportunityAmountBatchScheduler and OpportunityAmountBatchScheduler.
 * Created By         : Harsh Mathur
 * --------------------------------------------------------------------------------------------------------------------
 * Version  Author           Date            Comment
 * 1.0      Harsh Mathur     16 Sep 2026     Coverage for amount rollup batch and Dubai scheduler
 **********************************************************************************************************************/
@IsTest
private class OpportunityAmountBatchSchedulerTest {

    private static final String EID_MULTI_SO = '784-1000-0000001-1';
    private static final String EID_SECOND_OPEN = '784-1000-0000002-2';
    private static final String EID_CLOSED_WON = '784-1000-0000003-3';
    private static final String EID_CLOSED_LOST = '784-1000-0000004-4';
    private static final String EID_NO_VALID_SO = '784-1000-0000005-5';
    private static final String EID_NO_SO = '784-1000-0000006-6';
    private static final Decimal SENTINEL_AMOUNT = 1;
    private static final String VALID_STATUS = 'In Progress';

    private static void bypassTriggers() {
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassAccountTrigger = true;
        TriggerControl.bypassReceiptTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
    }

    @TestSetup
    static void setupData() {
        bypassTriggers();

        Schema.RecordTypeInfo personAccountRt = Schema.getGlobalDescribe().get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount');

        Account acc = new Account(
            RecordTypeId = personAccountRt.getRecordTypeId(),
            PersonEmail = 'opp-amount-batch@example.com',
            FirstName = 'OppAmount',
            LastName = 'Batch'
        );
        insert acc;

        Contact con = new Contact(LastName = 'Opp Amount Contact', Email = 'opp-amount-contact@example.com');
        insert con;

        Opportunity multiSoOpp = newOpportunity('Multi SO Open', acc.Id, con.Id, EID_MULTI_SO, SENTINEL_AMOUNT);
        Opportunity secondOpenOpp = newOpportunity('Second Open', acc.Id, con.Id, EID_SECOND_OPEN, SENTINEL_AMOUNT);
        Opportunity closedWonOpp = newOpportunity('Closed Won', acc.Id, con.Id, EID_CLOSED_WON, 10);
        Opportunity closedLostOpp = newOpportunity('Closed Lost', acc.Id, con.Id, EID_CLOSED_LOST, 20);
        Opportunity noValidSoOpp = newOpportunity('No Valid SO', acc.Id, con.Id, EID_NO_VALID_SO, 30);
        Opportunity noSoOpp = newOpportunity('No SO Open', acc.Id, con.Id, EID_NO_SO, 40);
        insert new List<Opportunity>{
            multiSoOpp, secondOpenOpp, closedWonOpp, closedLostOpp, noValidSoOpp, noSoOpp
        };

        update new Opportunity(Id = closedWonOpp.Id, StageName = 'Closed Won');
        update new Opportunity(
            Id = closedLostOpp.Id,
            StageName = 'Closed Lost',
            Loss_Reason__c = 'Lost-Cross Sell',
            ProjectInterest__c = 'Reem Hills'
        );

        List<SalesOrder__c> orders = new List<SalesOrder__c>{
            newOrder(multiSoOpp.Id, VALID_STATUS, 100),
            newOrder(multiSoOpp.Id, VALID_STATUS, 50),
            newOrder(secondOpenOpp.Id, VALID_STATUS, 200),
            newOrder(closedWonOpp.Id, VALID_STATUS, 999),
            newOrder(closedLostOpp.Id, VALID_STATUS, 888),
            newOrder(null, VALID_STATUS, 777),
            newOrder(noValidSoOpp.Id, 'Cancelled', 500)
        };

        for (String excludedStatus : OpportunityAmountBatchScheduler.EXCLUDED_STATUSES) {
            orders.add(newOrder(multiSoOpp.Id, excludedStatus, 1000));
        }

        insert orders;

        TriggerControl.bypassTransferTrigger = false;
        TriggerControl.BypassAccountTrigger = false;
        TriggerControl.bypassReceiptTrigger = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @IsTest
    static void testBatch_sumsValidOrdersAndAppliesBusinessRules() {
        Map<String, Opportunity> beforeByEid = opportunitiesByEid();

        Test.startTest();
        Database.executeBatch(new OpportunityAmountBatchScheduler(), OpportunityAmountBatchScheduler.DEFAULT_BATCH_SIZE);
        Test.stopTest();

        Map<String, Opportunity> afterByEid = opportunitiesByEid();

        System.assertEquals(
            150,
            afterByEid.get(EID_MULTI_SO).Amount,
            'Multiple valid Sales Orders on one Opportunity must be summed and cancelled/voided statuses excluded'
        );
        System.assertEquals(
            200,
            afterByEid.get(EID_SECOND_OPEN).Amount,
            'Each open Opportunity must receive its own valid Sales Order total'
        );
        System.assertEquals(
            999,
            afterByEid.get(EID_CLOSED_WON).Amount,
            'Closed Won Opportunities must not be updated'
        );
        System.assertEquals(
            888,
            afterByEid.get(EID_CLOSED_LOST).Amount,
            'Closed Lost Opportunities must not be updated'
        );
        System.assertEquals(
            30,
            afterByEid.get(EID_NO_VALID_SO).Amount,
            'Open Opportunity with only excluded Sales Orders must be left unchanged'
        );
        System.assertEquals(
            40,
            afterByEid.get(EID_NO_SO).Amount,
            'Open Opportunity with no Sales Orders must be left unchanged'
        );
        System.assertEquals(
            SENTINEL_AMOUNT,
            beforeByEid.get(EID_MULTI_SO).Amount,
            'Precondition: open Opportunity Amount starts as sentinel before the batch'
        );
    }

    @IsTest
    static void testBatch_nullOpportunitySalesOrdersAreIgnored() {
        Integer unlinkedCount = [
            SELECT COUNT()
            FROM SalesOrder__c
            WHERE Opportunity__c = null
            AND TotalAmount__c = 777
        ];
        System.assertEquals(1, unlinkedCount, 'Precondition: a Sales Order with null Opportunity__c exists');

        Test.startTest();
        Database.executeBatch(new OpportunityAmountBatchScheduler(), 50);
        Test.stopTest();

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM SalesOrder__c
                WHERE Opportunity__c = null
                AND TotalAmount__c = 777
            ],
            'Sales Orders with null Opportunity__c must be ignored without being changed or causing errors'
        );
        System.assertEquals(
            150,
            opportunitiesByEid().get(EID_MULTI_SO).Amount,
            'Null-Opportunity Sales Orders must not be included in any Opportunity total'
        );
    }

    @IsTest
    static void testScheduler_invokesBatch() {
        Test.startTest();
        new OpportunityAmountBatchScheduler().execute(null);
        Test.stopTest();

        Integer batchJobs = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'OpportunityAmountBatchScheduler'
        ];
        System.assert(
            batchJobs > 0,
            'Scheduler execute must invoke OpportunityAmountBatchScheduler. Jobs found: ' + batchJobs
        );
        System.assertEquals(
            150,
            opportunitiesByEid().get(EID_MULTI_SO).Amount,
            'Batch started by the Scheduler must populate open Opportunity Amount values'
        );
    }

    @IsTest
    static void testScheduler_dailyDubaiCron() {
        Test.startTest();
        String jobId = System.schedule(
            'Test ' + OpportunityAmountBatchScheduler.JOB_NAME,
            OpportunityAmountBatchScheduler.CRON_DAILY_11PM_DUBAI,
            new OpportunityAmountBatchScheduler()
        );
        Test.stopTest();

        CronTrigger scheduledJob = [
            SELECT CronExpression, TimesTriggered
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assert(
            scheduledJob.CronExpression.startsWith('0 0 23'),
            'CRON must be 11:00 PM daily in the scheduling user time zone (Asia/Dubai). Actual: ' +
            scheduledJob.CronExpression
        );
    }

    private static Opportunity newOpportunity(
        String name,
        Id accountId,
        Id contactId,
        String eidNumber,
        Decimal amount
    ) {
        return new Opportunity(
            Name = name,
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            PrimaryContact__c = contactId,
            Nationality__c = 'Egypt',
            AccountId = accountId,
            UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = eidNumber,
            En_Nationality__c = 'India',
            En_PassportNumber__c = 'P' + eidNumber.replace('-', ''),
            En_EIDNumber__c = eidNumber,
            ProjectInterest__c = 'Reem Hills',
            Amount = amount
        );
    }

    private static SalesOrder__c newOrder(Id opportunityId, String status, Decimal totalAmount) {
        return new SalesOrder__c(
            Opportunity__c = opportunityId,
            Status__c = status,
            TotalAmount__c = totalAmount
        );
    }

    private static Map<String, Opportunity> opportunitiesByEid() {
        Map<String, Opportunity> byEid = new Map<String, Opportunity>();
        for (Opportunity opp : [
            SELECT Id, Name, Amount, IsClosed, StageName, EIDNumber__c
            FROM Opportunity
            WHERE EIDNumber__c IN (
                :EID_MULTI_SO, :EID_SECOND_OPEN, :EID_CLOSED_WON,
                :EID_CLOSED_LOST, :EID_NO_VALID_SO, :EID_NO_SO
            )
        ]) {
            byEid.put(opp.EIDNumber__c, opp);
        }
        return byEid;
    }
}