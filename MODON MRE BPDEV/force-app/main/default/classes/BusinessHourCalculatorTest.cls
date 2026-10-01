@IsTest
public class BusinessHourCalculatorTest {

    @TestSetup
    static void setupTestData() {
         Process_Flow__c testProcessFlow11 = new Process_Flow__c(
            Name = 'BR Amendment11',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'tes1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow11;
        
        Process_Flow_Step__c pf=new Process_Flow_Step__c();
        pf.Section_Number__c=1;
        pf.section_Name__c='test';
        pf.Active__c=true;
        pf.Description__c='tes';
        pf.Setp_No__c=1;
        insert pf;    
         Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow11.Id
        );
        insert bp;
       Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'test',
            Business_Process__c = bp.Id,
            Status__c = 'Open',
            Sequence__c = 1,
            Process_Flow_Step__c=pf.Id,
            Business_Process_Steps_Name_Custom__c = 'test',
            section_Name__c = 'Collection Initiation',
            Section_Number__c = 1
        );
        insert step;
     

        // Create Step_Escalation__c records
        List<Step_Escalation__c> escalations = new List<Step_Escalation__c>{
            new Step_Escalation__c(
                Process_Flow_Step__c = pf.Id,
                Escalation_Trigger_Days__c = 1
            ),
            new Step_Escalation__c(
                Process_Flow_Step__c = pf.Id,
                Escalation_Trigger_Days__c = 2
            ),
            new Step_Escalation__c(
                Process_Flow_Step__c = pf.Id,
                Escalation_Trigger_Days__c = 3
            )
        };
        insert escalations;
    }

    @IsTest
    static void testCalculateReminder() {
        // Query a step created in @TestSetup
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        // Ensure default BusinessHours exists
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE LIMIT 1];
        System.assertNotEquals(null, bh, 'Default BusinessHours must exist for the test');

        // Call the invocable method
        Test.startTest();
        List<BusinessHourCalculator.Result> results = BusinessHourCalculator.calculateReminder(
            new List<Id>{step.Id}
        );
        Test.stopTest();

    }
}