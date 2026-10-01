@IsTest
public class BusinessProcessManadatoryFieldsTest {

    @testSetup
    static void setupTestData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Clash Approval',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test',
            Type__c = 'Cost Approval'
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Step_Name__c = 'Customer Payment Completion',
            Section_Number__c = 1,
            section_Name__c = 'TES1',
            Process_Flow__c = pf.Id
        );
        insert pfs;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id
            
        );
        insert bp;

        // Step
        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Customer Payment Completion',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'test1',
            Section_Number__c = 1,
            section_Name__c = 'test1'
        );
        insert step;

        // Mandatory fields that FORCE execution of logic
        insert new List<Mandatory_Field__c>{
            new Mandatory_Field__c(
                Process_Flow_Step__c = pfs.Id,
                Object_Api_Name__c = 'Business_Process__c',
                Field_API_Name__c = 'Name',
                Field_Value__c = 'WRONG_VALUE'
            ),
            new Mandatory_Field__c(
                Process_Flow_Step__c = pfs.Id,
                Object_Api_Name__c = 'Business_Process_Step__c',
                Field_API_Name__c = 'Status__c',
                Field_Value__c = 'Completed'
            )
        };
    }

    @IsTest
    static void testValidation_MismatchPath() {

        Business_Process_Step__c step = [
            SELECT Id, Name, Status__c, Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        step.Status__c = 'Completed';

        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            step.Id => new Business_Process_Step__c(
                Id = step.Id,
                Status__c = 'Open'
            )
        };

        Test.startTest();
        BusinessProcessManadatoryFields.validateMandatoryFields(
            new List<SObject>{ step },
            oldMap
        );
        Test.stopTest();
    }

    @IsTest
    static void testValidation_NoChange() {

        Business_Process_Step__c step = [
            SELECT Id, Status__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            step.Id => new Business_Process_Step__c(
                Id = step.Id,
                Status__c = step.Status__c
            )
        };

        Test.startTest();
        BusinessProcessManadatoryFields.validateMandatoryFields(
            new List<SObject>{ step },
            oldMap
        );
        Test.stopTest();
    }

    @IsTest
    static void testValidation_EmptyExpectedValue() {

        Mandatory_Field__c mf = [
            SELECT Id
            FROM Mandatory_Field__c
            LIMIT 1
        ];

        mf.Field_Value__c = null;
        update mf;

        Business_Process_Step__c step = [
            SELECT Id, Name, Status__c, Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        step.Status__c = 'Completed';

        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            step.Id => new Business_Process_Step__c(
                Id = step.Id,
                Status__c = 'Open'
            )
        };

        Test.startTest();
        BusinessProcessManadatoryFields.validateMandatoryFields(
            new List<SObject>{ step },
            oldMap
        );
        Test.stopTest();
    }
}