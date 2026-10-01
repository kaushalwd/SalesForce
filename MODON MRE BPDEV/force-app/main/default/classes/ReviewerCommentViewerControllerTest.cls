@isTest
public class ReviewerCommentViewerControllerTest {

    @testSetup
    static void setupData() {

        Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test',
            Type__c='Cost Approval'
        );
        insert testProcessFlow;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow.Id
        );
        insert bp;

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test1',
            Section_Number__c=1,
            section_Name__c='test1'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 2',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id, 
            Sequence__c = 2,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        insert steps;
        // Create Comment
        Reviewer_Comment__c rc = new Reviewer_Comment__c(
            Notes_Comments__c = 'Test Note',
            Actioned_To__c = 'CCC team',
            Business_Process__c = bp.Id,
            Business_Process_Step__c = steps[0].Id,
            Remarks__c = 'Test Remarks',
            Review_Status__c = 'Open'
        );
        insert rc;

        // Create File
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test Data')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link file to comment
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = rc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    @isTest
    static void testGetCommentsByStep() {

        Business_Process_Step__c step = [
            SELECT Id FROM Business_Process_Step__c LIMIT 1
        ];

        Test.startTest();
        List<ReviewerCommentViewerController.ReviewerCommentWrapper> result =
            ReviewerCommentViewerController.getCommentsByStep(step.Id);
        Test.stopTest();
    }

    @isTest
    static void testDeleteCommentWithFiles() {

        Reviewer_Comment__c rc = [
            SELECT Id FROM Reviewer_Comment__c LIMIT 1
        ];

        Test.startTest();
        ReviewerCommentViewerController.deleteCommentWithFiles(rc.Id);
        Test.stopTest(); 
    }

    @isTest
    static void testDeleteCommentWithFiles_Exception() {

        Test.startTest();
        try {
            ReviewerCommentViewerController.deleteCommentWithFiles('invalidId');
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
           
        }
        Test.stopTest();
    }
}