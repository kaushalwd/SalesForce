@IsTest
public without sharing class LatePaymentChargesActivatorTest {

    @testSetup
    static void setupData() {

        Account customerAccount = new Account(
            Name = 'LPC Activator Test Customer'
        );
        insert customerAccount;

        Project__c project = new Project__c(
            Name = 'LPC Activator Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'LPC Activator Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unitRecord = new Unit__c(
            Name = 'LPC Activator Test Unit',
            Phase__c = phase.Id,
            PlotNo__c = 'LPC-101',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRecord;

        List<SalesOrder__c> salesOrders = new List<SalesOrder__c>();

        for (Integer counter = 1; counter <= 8; counter++) {
            salesOrders.add(
                new SalesOrder__c(
                    CustomerAccount__c = customerAccount.Id,
                    Unit__c = unitRecord.Id,
                    TotalAmount__c = 1000000
                )
            );
        }

        insert salesOrders;

        Process_Flow__c processFlow = new Process_Flow__c(
            Name = 'Late Payment Charge Approval Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'LPC_ACTIVATOR_TEST'
        );
        insert processFlow;

        List<Process_Flow_Step__c> processFlowSteps =
            new List<Process_Flow_Step__c>{
                createProcessFlowStep(
                    processFlow.Id,
                    'Verify Request',
                    1
                ),
                createProcessFlowStep(
                    processFlow.Id,
                    'Approval from CM Senior Manager',
                    2
                ),
                createProcessFlowStep(
                    processFlow.Id,
                    'Approval from CM Director',
                    3
                ),
                createProcessFlowStep(
                    processFlow.Id,
                    'Approval from CCO',
                    4
                ),
                createProcessFlowStep(
                    processFlow.Id,
                    'Approval from CEO',
                    5
                ),
                createProcessFlowStep(
                    processFlow.Id,
                    'Collections Execute Waiver',
                    6
                )
            };

        insert processFlowSteps;

        Map<String, Id> processFlowStepIds = new Map<String, Id>();

        for (Process_Flow_Step__c processStep : processFlowSteps) {
            processFlowStepIds.put(
                processStep.Step_Name__c,
                processStep.Id
            );
        }

        /*
         * Waiver amounts are calculated automatically using:
         *
         * LPC_Amount__c
         * Waiver_Percentage__c
         */
        List<Business_Process__c> businessProcesses =
            new List<Business_Process__c>{
                /*
                 * Waiver amount should be less than or equal to 100.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[0].Id,
                    LPC_Amount__c = 1000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Waiver amount greater than 100 but below 25,000.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[1].Id,
                    LPC_Amount__c = 100000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Waiver amount greater than 25,000.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[2].Id,
                    LPC_Amount__c = 500000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Waiver amount greater than 100,000.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[3].Id,
                    LPC_Amount__c = 1500000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Waiver amount greater than 200,000.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[4].Id,
                    LPC_Amount__c = 2500000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Used for Required Info branch.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[5].Id,
                    LPC_Amount__c = 100000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Used for prepareStepToOpen branches.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[6].Id,
                    LPC_Amount__c = 100000,
                    Waiver_Percentage__c = 10
                ),

                /*
                 * Used for non-completed branch.
                 */
                new Business_Process__c(
                    Process_Flow__c = processFlow.Id,
                    Sales_Order__c = salesOrders[7].Id,
                    LPC_Amount__c = 100000,
                    Waiver_Percentage__c = 10
                )
            };

        insert businessProcesses;

        Integer processCounter = 1;

        for (Business_Process__c businessProcess : businessProcesses) {

            List<Business_Process_Step__c> steps =
                new List<Business_Process_Step__c>{
                    createBusinessProcessStep(
                        businessProcess.Id,
                        processFlowStepIds.get('Verify Request'),
                        'Verify Request',
                        1,
                        'Completed',
                        'PROCESS_' + processCounter + '_VERIFY'
                    ),
                    createBusinessProcessStep(
                        businessProcess.Id,
                        processFlowStepIds.get(
                            'Approval from CM Senior Manager'
                        ),
                        'Approval from CM Senior Manager',
                        2,
                        'Open',
                        'PROCESS_' + processCounter + '_SM'
                    ),
                    createBusinessProcessStep(
                        businessProcess.Id,
                        processFlowStepIds.get(
                            'Approval from CM Director'
                        ),
                        'Approval from CM Director',
                        3,
                        'Open',
                        'PROCESS_' + processCounter + '_DIRECTOR'
                    ),
                    createBusinessProcessStep(
                        businessProcess.Id,
                        processFlowStepIds.get('Approval from CCO'),
                        'Approval from CCO',
                        4,
                        'Open',
                        'PROCESS_' + processCounter + '_CCO'
                    ),
                    createBusinessProcessStep(
                        businessProcess.Id,
                        processFlowStepIds.get('Approval from CEO'),
                        'Approval from CEO',
                        5,
                        'Open',
                        'PROCESS_' + processCounter + '_CEO'
                    ),
                    createBusinessProcessStep(
                        businessProcess.Id,
                        processFlowStepIds.get(
                            'Collections Execute Waiver'
                        ),
                        'Collections Execute Waiver',
                        6,
                        'Open',
                        'PROCESS_' + processCounter + '_EXECUTE'
                    )
                };

            insert steps;
            processCounter++;
        }
    }

    private static Process_Flow_Step__c createProcessFlowStep(
        Id processFlowId,
        String stepName,
        Decimal sequenceNumber
    ) {
        return new Process_Flow_Step__c(
            Step_Name__c = stepName,
            Section_Number__c = 1,
            section_Name__c = 'LPC Waiver',
            Process_Flow__c = processFlowId
        );
    }

    private static Business_Process_Step__c createBusinessProcessStep(
        Id businessProcessId,
        Id processFlowStepId,
        String stepName,
        Decimal sequenceNumber,
        String stepStatus,
        String customName
    ) {
        return new Business_Process_Step__c(
            Name = stepName,
            Business_Process__c = businessProcessId,
            Process_Flow_Step__c = processFlowStepId,
            Sequence__c = sequenceNumber,
            Status__c = stepStatus,
            section_Name__c = 'LPC Waiver',
            Section_Number__c = 1,
            Business_Process_Steps_Name_Custom__c = customName
        );
    }

    private static List<Business_Process_Step__c> getProcessSteps(
        String processIdentifier
    ) {
        return [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Business_Process__r.LPC_Amount__c,
                   Business_Process__r.Waiver_Percentage__c,
                   Business_Process__r.LPC_Waived_Amount__c,
                   Business_Process__r.LPCWaivedAmount__c,
                   Business_Process__r.Sales_Order__c
            FROM Business_Process_Step__c
            WHERE Business_Process_Steps_Name_Custom__c
                LIKE :processIdentifier + '%'
            ORDER BY Sequence__c
        ];
    }

    @IsTest
    static void testMinimumAmountDirectExecuteWaiver() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_1_');

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Minimum amount activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testSeniorManagerApproval() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_2_');

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Senior Manager activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testDirectorApproval() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_3_');

        /*
         * Simulate completion of the Senior Manager approval.
         */
        Business_Process_Step__c previousStep = steps[1];
        previousStep.Status__c = 'Completed';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Director activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testCCOApproval() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_4_');

        /*
         * Simulate completion of CM Director approval.
         */
        Business_Process_Step__c previousStep = steps[2];
        previousStep.Status__c = 'Completed';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'CCO activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testCEOApproval() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_5_');

        /*
         * Simulate completion of CCO approval.
         */
        Business_Process_Step__c previousStep = steps[3];
        previousStep.Status__c = 'Completed';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'CEO activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testExecuteWaiverAfterFinalApproval() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_5_');

        Business_Process_Step__c previousStep = steps[4];
        previousStep.Status__c = 'Completed';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Execute waiver activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testRequiredInfoStep() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_6_');

        Business_Process_Step__c previousStep = steps[0];

        /*
         * Point Required_Info_Step__c to the Senior Manager step.
         */
        previousStep.Required_Info_Step__c = steps[1].Id;

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Required info activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testRequiredInfoStatusBranch() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_7_');

        Business_Process_Step__c previousStep = steps[0];

        /*
         * Greater than 100 requires Senior Manager approval.
         */
        steps[1].Status__c = 'Required Info';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Required Info status activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testReOpenStatusBranch() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_7_');

        Business_Process_Step__c previousStep = steps[0];

        steps[1].Status__c = 'Open';
        steps[1].Re_Open_Count__c = 1;
        steps[1].Assigned_To__c = null;

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Reopen activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testAcceptedStatusBranch() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_7_');

        Business_Process_Step__c previousStep = steps[0];

        steps[1].Status__c = 'New';
        steps[1].Re_Open_Count__c = 0;
        steps[1].Assigned_To__c = UserInfo.getUserId();

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Accepted activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testOpenStatusBranch() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_7_');

        Business_Process_Step__c previousStep = steps[0];

        steps[1].Status__c = 'New';
        steps[1].Re_Open_Count__c = 0;
        steps[1].Assigned_To__c = null;

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Open activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testPreviousStepNotCompleted() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_8_');

        Business_Process_Step__c previousStep = steps[0];
        previousStep.Status__c = 'Open';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'Non-completed activated steps: ' +
            activatedSteps
        );
    }

    @IsTest
    static void testNoNextStepAvailable() {

        List<Business_Process_Step__c> steps =
            getProcessSteps('PROCESS_2_');

        Business_Process_Step__c previousStep = steps[5];
        previousStep.Status__c = 'Completed';

        Test.startTest();

        List<Business_Process_Step__c> activatedSteps =
            new LatePaymentChargesActivator().activateNextSteps(
                previousStep.Id,
                steps,
                previousStep,
                null
            );

        Test.stopTest();

        System.debug(
            'No next step result: ' +
            activatedSteps
        );
    }

    @IsTest
static void testSequenceComparator() {

    Business_Process_Step__c firstStep =
        new Business_Process_Step__c(
            Sequence__c = 1
        );

    Business_Process_Step__c secondStep =
        new Business_Process_Step__c(
            Sequence__c = 2
        );

    Business_Process_Step__c nullSequenceStep =
        new Business_Process_Step__c();

    LatePaymentChargesActivator.BusinessProcessStepSequenceComparator comparator =
        new LatePaymentChargesActivator.BusinessProcessStepSequenceComparator();

    Integer sameSequenceResult =
        comparator.compare(firstStep, firstStep);

    Integer lowerSequenceResult =
        comparator.compare(firstStep, secondStep);

    Integer higherSequenceResult =
        comparator.compare(secondStep, firstStep);

    Integer firstNullResult =
        comparator.compare(nullSequenceStep, firstStep);

    Integer secondNullResult =
        comparator.compare(firstStep, nullSequenceStep);

    System.debug('Same sequence result: ' + sameSequenceResult);
    System.debug('Lower sequence result: ' + lowerSequenceResult);
    System.debug('Higher sequence result: ' + higherSequenceResult);
    System.debug('First null sequence result: ' + firstNullResult);
    System.debug('Second null sequence result: ' + secondNullResult);
}
}