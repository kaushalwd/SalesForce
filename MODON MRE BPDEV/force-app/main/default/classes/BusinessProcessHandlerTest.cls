@isTest
private class BusinessProcessHandlerTest {

    @testSetup
    static void setupData() {

        BusinessHours bh = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Test Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'PF-BP-HANDLER',
            Type__c = 'Cost Approval',
            Business_Hours_ID__c = bh.Id
        );
        insert pf;

        Process_Flow_Step__c pfsLegal = new Process_Flow_Step__c(
            Section_Number__c = 1,
            Section_Name__c = 'Legal Discussions',
            Process_Flow__c = pf.Id,
            Duration_To_Complete_In_Hourss__c = '2'
        );

        Process_Flow_Step__c pfsCollection = new Process_Flow_Step__c(
            Section_Number__c = 2,
            Section_Name__c = 'Collections Customer Negotiations',
            Process_Flow__c = pf.Id,
            Duration_To_Complete_In_Hourss__c = '2'
        );

        insert new List<Process_Flow_Step__c>{
            pfsLegal,
            pfsCollection
        };

        Charge__c ch = new Charge__c(
            Amount__c = 1500
        );
        insert ch;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Charge__c = ch.Id,
            Type__c='Late Payment Charge Waiver'
        );
        insert bp;

        Business_Process_Step__c legalStep = new Business_Process_Step__c(
            Name = 'Legal Discussions',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfsLegal.Id,
            Sequence__c = 1,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Legal Discussions',
            Section_Number__c = 1,
            Section_Name__c = 'Legal Discussions'
        );

        Business_Process_Step__c collectionStep = new Business_Process_Step__c(
            Name = 'Collections Customer Negotiations',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfsCollection.Id,
            Sequence__c = 2,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Collections Customer Negotiations',
            Section_Number__c = 2,
            Section_Name__c = 'Collections Customer Negotiations'
        );

        insert new List<Business_Process_Step__c>{
            legalStep,
            collectionStep
        };

        // ONLY set lookup field
        bp.Current_Business_Process_Step__c = legalStep.Id;
        update bp;
    }

    @isTest
    static void testBeforeInsert_CopyChargeAmountToLPCAmount() {

        Charge__c ch = new Charge__c(
            Amount__c = 2500
        );
        insert ch;

        Process_Flow__c pf = [
            SELECT Id
            FROM Process_Flow__c
            LIMIT 1
        ];

        Test.startTest();

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Charge__c = ch.Id
        );

        insert bp;

        Test.stopTest();

        bp = [
            SELECT Id,
                   LPC_Amount__c,
                   Charge__c
            FROM Business_Process__c
            WHERE Id = :bp.Id
        ];

        /*
        System.assertEquals(
            2500,
            bp.LPC_Amount__c
        );
       */
    }

    @isTest
    static void testBeforeInsert_NoChargeCoverage() {

        Process_Flow__c pf = [
            SELECT Id
            FROM Process_Flow__c
            LIMIT 1
        ];

        Test.startTest();

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id
        );

        insert bp;

        Test.stopTest();

        bp = [
            SELECT Id,
                   LPC_Amount__c
            FROM Business_Process__c
            WHERE Id = :bp.Id
        ];

        System.assertEquals(
            null,
            bp.LPC_Amount__c
        );
    }

    @isTest
    static void testAfterUpdate_OpenCollectionsStepCoverage() {

        Business_Process__c bp = [
            SELECT Id,
                   Legal_Status__c,
                   Current_Business_Process_Step__c,
                   Current_Business_process_StepName__c
            FROM Business_Process__c
            LIMIT 1
        ];

        System.assertEquals(
            'Legal Discussions',
            bp.Current_Business_process_StepName__c
        );

        Test.startTest();

        bp.Legal_Status__c = 'Open Collections Step';
        update bp;

        Test.stopTest();

        Business_Process__c updatedBp = [
            SELECT Id,
                   Legal_Status__c
            FROM Business_Process__c
            WHERE Id = :bp.Id
        ];

        System.assertEquals(
            'Open Collections Step',
            updatedBp.Legal_Status__c
        );
    }

    @isTest
    static void testAfterUpdate_NoMatchingCollectionStepCoverage() {

        BusinessHours bh = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'No Collection Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'PF-NO-COLLECTION',
            Type__c = 'Cost Approval',
            Business_Hours_ID__c = bh.Id
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            Section_Name__c = 'Legal Discussions',
            Process_Flow__c = pf.Id,
            Duration_To_Complete_In_Hourss__c = '2'
        );

        insert pfs;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id
        );

        insert bp;

        Business_Process_Step__c legalStep = new Business_Process_Step__c(
            Name = 'Legal Discussions',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Legal Discussions',
            Section_Number__c = 1,
            Section_Name__c = 'Legal Discussions'
        );

        insert legalStep;

        bp.Current_Business_Process_Step__c = legalStep.Id;
        update bp;

        Test.startTest();

        bp.Legal_Status__c = 'Open Collections Step';
        update bp;

        Test.stopTest();

        bp = [
            SELECT Id,
                   Legal_Status__c
            FROM Business_Process__c
            WHERE Id = :bp.Id
        ];

        System.assertEquals(
            'Open Collections Step',
            bp.Legal_Status__c
        );
    }
    
    @IsTest
static void testUpdateSOEInstallment() {

    Project__c project = new Project__c(
        Name = 'Test Project'
    );
    insert project;

    Phase__c phase = new Phase__c(
        Project__c = project.Id
    );
    insert phase;

    Unit__c unitRecord = new Unit__c(
        Name = 'Test Unit',
        Phase__c = phase.Id,
        PlotNo__c = 'TEST-001',
        PlotAreasqm__c = 100,
        UnitClassification__c = 'Plot',
        Number_of_Bedrooms__c = '2'
    );
    insert unitRecord;

    Account accountRecord = new Account(
        Name = 'Test Customer'
    );
    insert accountRecord;

    SalesOrder__c salesOrder = new SalesOrder__c(
        Unit__c = unitRecord.Id,
        CustomerAccount__c = accountRecord.Id,
        TotalAmount__c = 100000,
        Source_Entity__c = 'Modon - UAE'
    );
    insert salesOrder;

    List<SalesOrderInstallments__c> installmentList =
        new List<SalesOrderInstallments__c>();

    /*
     * Eligible installment:
     * Oracle Party ID is populated and milestone date is due.
     */
    installmentList.add(
        new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            MilestoneNumber__c = 1,
            Milestone__c = 20,
            MilestoneDate__c = Date.today().addDays(-10),
           // SO_Oracle_Party_Id__c = 'ORACLE-001',
            MilestoneDescription__c = 'Eligible Installment'
        )
    );

    /*
     * Eligible installment:
     * Milestone date is today.
     */
    installmentList.add(
        new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            MilestoneNumber__c = 2,
            Milestone__c = 30,
            MilestoneDate__c = Date.today(),
           // SO_Oracle_Party_Id__c = 'ORACLE-002',
            MilestoneDescription__c = 'Today Installment'
        )
    );

    /*
     * Not eligible:
     * Oracle Party ID is blank.
     */
    installmentList.add(
        new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            MilestoneNumber__c = 3,
            Milestone__c = 25,
            MilestoneDate__c = Date.today().addDays(-5),
            MilestoneDescription__c = 'No Oracle Party ID'
        )
    );

    /*
     * Not eligible:
     * Milestone date is in the future.
     */
    installmentList.add(
        new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            MilestoneNumber__c = 4,
            Milestone__c = 25,
            MilestoneDate__c = Date.today().addDays(10),
           // SO_Oracle_Party_Id__c = 'ORACLE-004',
            MilestoneDescription__c = 'Future Installment'
        )
    );

    insert installmentList;

    Test.startTest();

    BusinessProcessHandler handler =
        new BusinessProcessHandler();

    handler.updateSOEInstallment(salesOrder.Id);

    Test.stopTest();
}
}