@isTest
public class ReviewerCommentControllerTest {

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
        
        // Create Document placeholder
        Business_Process_Documents__c doc = new Business_Process_Documents__c(
            Name = 'PNCA Approval Review documents',
            Business_Process__c = bp.Id
        );
        insert doc;

        // Create NOC Document
        Business_Process_Documents__c nocDoc = new Business_Process_Documents__c(
            Name = 'Include In NOC',
            Business_Process__c = bp.Id
        );
        insert nocDoc;

        // Create ContentVersion (File)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test Data')
        );
        insert cv;
    }

@isTest
static void testCreateAndFetchComments() {
    Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];
    ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

    ReviewerCommentController.CommentWrapper cw = new ReviewerCommentController.CommentWrapper();
    cw.notes = 'Test Note';
    cw.actionedTo = 'Included in NOC';
    cw.stepId = step.Id;
    cw.fileIds = new List<String>{ cv.ContentDocumentId };
    cw.remarks = 'Test Remarks';
    cw.reviewStatus = 'Open';

    Test.startTest();

    ReviewerCommentController.createReviewerComments(
        new List<ReviewerCommentController.CommentWrapper>{ cw }
    );

    List<ReviewerCommentController.ReviewerCommentWrapper> result =
        ReviewerCommentController.getCommentsByStep(step.Id);

    Test.stopTest();

    System.assert(!result.isEmpty(), 'Comments should be fetched');
}

    @isTest
    static void testUpdateReviewerComment() {
    Business_Process_Step__c step = [SELECT Id, Business_Process__c FROM Business_Process_Step__c LIMIT 1];

    // Create comment
    Reviewer_Comment__c rc = new Reviewer_Comment__c(
        Notes_Comments__c = 'Test',
        Actioned_To__c = 'CCC team',
        Business_Process_Step__c = step.Id,
        Business_Process__c = step.Business_Process__c
    );
    insert rc;
        
        Map<String, Object> payload = new Map<String, Object>{
            'commentId' => rc.Id,
                'notes' => 'Updated Note',
                'actionedTo' => 'CCC team', 
                'remarks' => 'Updated Remarks',
                'reviewStatus' => 'Open',   
                'newFileIds' => new List<String>(),
                'filesToRemove' => new List<String>()
                };
        String jsonString = JSON.serialize(payload);

        Test.startTest();
        ReviewerCommentController.updateReviewerComment(jsonString);
        Test.stopTest();

        Reviewer_Comment__c updated = [
            SELECT Notes_Comments__c, Review_Status__c
            FROM Reviewer_Comment__c
            WHERE Id = :rc.Id
        ];

    }

   @isTest
static void testDeleteCommentWithFiles() {

    // Get required parent data
    Business_Process_Step__c step = [SELECT Id, Business_Process__c FROM Business_Process_Step__c LIMIT 1];

    // Create comment
    Reviewer_Comment__c rc = new Reviewer_Comment__c(
        Notes_Comments__c = 'Test',
        Actioned_To__c = 'CCC team',
        Business_Process_Step__c = step.Id,
        Business_Process__c = step.Business_Process__c
    );
    insert rc;

    ContentVersion cv = new ContentVersion(
        Title = 'Delete Test File',
        PathOnClient = 'delete.txt',
        VersionData = Blob.valueOf('Test Data')
    );
    insert cv;

    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

    ContentDocumentLink cdl = new ContentDocumentLink(
        ContentDocumentId = cv.ContentDocumentId,
        LinkedEntityId = rc.Id,
        ShareType = 'V',
        Visibility = 'AllUsers'
    );
    insert cdl;

    Test.startTest();
    ReviewerCommentController.deleteCommentWithFiles(rc.Id);
    Test.stopTest();
}

    @isTest
static void testGetDesignDocumentPlaceholder() {

    Business_Process_Step__c step = [
        SELECT Id, Business_Process__c, Business_Process_Steps_Name_Custom__c
        FROM Business_Process_Step__c
        LIMIT 1
    ];

    step.Business_Process_Steps_Name_Custom__c = 'PNCA Approval';
    update step;

    Business_Process_Documents__c doc = new Business_Process_Documents__c(
        Name = 'PNCA Approval Review documents',
        Business_Process__c = step.Business_Process__c
    );
    insert doc;

    Test.startTest();
    Id docId = ReviewerCommentController.getDesignDocumentPlaceholder(step.Id);
    Test.stopTest();
}

 @isTest
static void testMetadataMethods() {
    Business_Process_Step__c step = [
        SELECT Id 
        FROM Business_Process_Step__c 
        LIMIT 1
    ];

    Test.startTest();
    List<String> actions = ReviewerCommentController.getActionedToOptions();
    List<String> remarks = ReviewerCommentController.getRemarkOptions(step.Id);
    Test.stopTest();

}
}