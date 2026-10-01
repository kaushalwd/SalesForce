@IsTest
public class MileStoneBusinessProcessBatch_Test {



    @testSetup
    static void setupData() {

        // Project
        Project__c proj = new Project__c(
            Name = 'Test Project'
        );
        insert proj;

        // Phase
        Phase__c ph = new Phase__c(
            Name = 'Test Phase',
            Project__c = proj.Id
        );
        insert ph;

        // Milestone
        Milestone__c ms = new Milestone__c(
            Name = 'Test Milestone',
            Phase__c = ph.Id,
            Milestone_Due_Date__c = System.today().addDays(45)
        );
        insert ms;

        // Process Flow
        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Project Mile Stone Confirmation',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Project_Mile_Stone_Confirmation'
            
        );
        insert pf;
    }

    @IsTest
    static void testBatchExecute() {

        Test.startTest();

        MileStoneBusinessProcessBatch batchObj =
            new MileStoneBusinessProcessBatch();

        Database.executeBatch(batchObj, 1);

        Test.stopTest();
    }

    @IsTest
    static void testBatchExecute_WithConstructorSet() {

        Set<Id> milestoneIds = new Set<Id>();

        for(Milestone__c ms : [SELECT Id FROM Milestone__c]) {
            milestoneIds.add(ms.Id);
        }

        Test.startTest();

        MileStoneBusinessProcessBatch batchObj =
            new MileStoneBusinessProcessBatch(milestoneIds);

        Database.executeBatch(batchObj, 1);

        Test.stopTest();
    }

    @IsTest
    static void testSchedulableExecute() {

        Test.startTest();

        String cronExp = '0 0 0 15 5 ? 2027';

        System.schedule(
            'Test MileStone Batch',
            cronExp,
            new MileStoneBusinessProcessBatch()
        );

        Test.stopTest();
    }

    @IsTest
    static void testStartMethodCoverage() {

        Test.startTest();

        MileStoneBusinessProcessBatch batchObj =
            new MileStoneBusinessProcessBatch();

        Database.QueryLocator ql =
            batchObj.start(null);

        Test.stopTest();
    }

    @IsTest
    static void testFinishMethodCoverage() {

        Test.startTest();

        MileStoneBusinessProcessBatch batchObj =
            new MileStoneBusinessProcessBatch();

        batchObj.finish(null);

        Test.stopTest();
    }
}