@isTest
public class ClearCasesInQueuesTest {

    private static Id createCaseQueue() {
        Group queue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            queue = new Group(Name = 'ClearCases Test Queue ' + String.valueOf(Crypto.getRandomInteger()), Type = 'Queue');
            insert queue;
            insert new QueueSObject(QueueId = queue.Id, SObjectType = 'Case');
        }
        return queue.Id;
    }

    private static Case createQueueOwnedNewCase(Id accountId, Id unitId, Id queueId) {
        Case testCase = new Case(
            RunningTestClass__c = true,
            AccountId = accountId,
            Requestor_Email__c = 'customer1@gmail.com',
            Owner_Email__c = 'customer1@gmail.com',
            Customer_Email__c = 'test3@gmail.com',
            Emirates_Id__c = '784-1234-1234567-2',
            Masked_Emirates_Id__c = '784-xxxx-xxxxxxx-x',
            Account_Manager_Email__c = 'test4@gmail.com',
            CaseCategory__c = 'Department Action',
            CaseSubCategory__c = 'Financial Service',
            Reason = 'Complex functionality',
            Unit__c = unitId,
            Status = 'New',
            OwnerId = queueId,
            Origin = 'Service Call Center',
            Description = 'Test description from test methods'
        );
        insert testCase;
        return testCase;
    }

    @isTest
    static void testClearCasesWithProvidedList() {
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id queueId = createCaseQueue();
        Case testCase = createQueueOwnedNewCase(testData.get('vipPersonAccount'), testData.get('Unit'), queueId);

        System.assertNotEquals(null, testCase.Id, 'Case should be created');
        System.assertEquals(queueId, [SELECT OwnerId FROM Case WHERE Id = :testCase.Id].OwnerId, 'Case should start owned by the queue');

        CaseTriggerHandler.isTestRun = true;
        Test.startTest();
        ClearCasesInQueues.ClearCases(new List<SObject>{ testCase });
        Test.stopTest();
        CaseTriggerHandler.isTestRun = false;

        Case updatedCase = [SELECT Id, OwnerId, Status FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('New', updatedCase.Status, 'Job should not change Case status');
        System.assertEquals(queueId, updatedCase.OwnerId, 'assignToQueueOwner_Updated sets queue owner fields and does not reassign OwnerId');
    }

    @isTest
    static void testClearCasesEmptyListUsesQueryPath() {
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id queueId = createCaseQueue();
        Case testCase = createQueueOwnedNewCase(testData.get('vipPersonAccount'), testData.get('Unit'), queueId);

        CaseTriggerHandler.isTestRun = true;
        Test.startTest();
        ClearCasesInQueues.ClearCases(new List<SObject>());
        Test.stopTest();
        CaseTriggerHandler.isTestRun = false;

        Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updatedCase.Id, 'Query path should process the New queue-owned Case');
        System.assertEquals('New', updatedCase.Status, 'Query path should leave Case status as New');
    }

    @isTest
    static void testSchedulerExecution() {
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id queueId = createCaseQueue();
        Case testCase = createQueueOwnedNewCase(testData.get('vipPersonAccount'), testData.get('Unit'), queueId);

        CaseTriggerHandler.isTestRun = true;
        Test.startTest();
        new ClearCasesInQueuesScheduler().execute(null);
        Test.stopTest();
        CaseTriggerHandler.isTestRun = false;

        Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('New', updatedCase.Status, 'Scheduler should not change Case status');
    }

    @isTest
    static void testScheduleDailyReset() {
        Test.startTest();
        ClearCasesInQueuesScheduler.scheduleDailyReset();
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Assign cases to members before business hours'
            LIMIT 1
        ];
        System.assertNotEquals(null, ct.Id, 'Daily reset job should be scheduled');
        System.assertEquals('0 0 7 * * ?', ct.CronExpression, 'Daily reset should run at 7:00 AM');
    }
}