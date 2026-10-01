@isTest
public class PaymentExtensionValidator_Test {



    @testSetup
    static void setupData() {


        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        Milestone__c milestoneRec = new Milestone__c(
            Name = 'Payment Extension Milestone',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert milestoneRec;

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Payment Extension Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Payment_Ext_Validator',
            Type__c = 'Cost Approval'
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Validation',
            Process_Flow__c = pf.Id
        );
        insert pfs;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id
        );
        insert bp;

        /* -----------------------------
           Step
        ------------------------------*/
        Business_Process_Step__c step =
            new Business_Process_Step__c(
                Name = 'Verify Request',
                Status__c = 'Completed',
                Business_Process__c = bp.Id,
                Sequence__c = 1,
                Section_Number__c = 1,
                section_Name__c = 'Section',
                Process_Flow_Step__c = pfs.Id,
                Business_Process_Steps_Name_Custom__c = 'Verify'
            );

        insert step;
    }

    /* =========================================================
       TEST SUCCESS CASE
    ==========================================================*/
    @isTest
    static void testValidateSteps_Success() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.Payment_Extension_Category__c = 'Upto 30 days';
        bp.Payment_Extension_Date__c = Date.today().addDays(30);
        bp.Payment_Extension_Reason__c = 'Customer request';

        update bp;

     
        Business_Process_Documents__c doc =
            new Business_Process_Documents__c(
                Name = 'Proof of Request',
                Business_Process__c = bp.Id
            );

        insert doc;


        ContentVersion cv = new ContentVersion(
            Title = 'Proof',
            PathOnClient = 'Proof.pdf',
            VersionData = Blob.valueOf('Test Data'),
            IsMajorVersion = true
        );

        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        ContentDocumentLink cdl =
            new ContentDocumentLink(
                LinkedEntityId = doc.Id,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V'
            );

        insert cdl;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        PaymentMilestoneExtentionValidator validator =
            new PaymentMilestoneExtentionValidator();

        validator.ValidateSteps(step);

        Test.stopTest();

    }


    @isTest
    static void testValidateSteps_AllErrors() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            PaymentMilestoneExtentionValidator validator =
                new PaymentMilestoneExtentionValidator();

            validator.ValidateSteps(step);

          
        } catch (AuraHandledException e) {

           
        }

        Test.stopTest();
    }

   
    @isTest
    static void testValidateSteps_MissingDocument() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.Payment_Extension_Category__c = 'Upto 60 days';
        bp.Payment_Extension_Date__c = Date.today().addDays(60);
        bp.Payment_Extension_Reason__c = 'Business approval';

        update bp;

        Business_Process_Documents__c doc =
            new Business_Process_Documents__c(
                Name = 'Proof of Request',
                Business_Process__c = bp.Id
            );

        insert doc;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            PaymentMilestoneExtentionValidator validator =
                new PaymentMilestoneExtentionValidator();

            validator.ValidateSteps(step);

           
        } catch (AuraHandledException e) {

        }

        Test.stopTest();
    }


    @isTest
    static void testValidateSteps_WhenElse() {

        Business_Process_Step__c step =
            new Business_Process_Step__c(
                Name = 'Other Step'
            );

        Test.startTest();

        PaymentMilestoneExtentionValidator validator =
            new PaymentMilestoneExtentionValidator();

        validator.ValidateSteps(step);

        Test.stopTest();

    
    }
}