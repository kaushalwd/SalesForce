@isTest
public class BPFileUploaderControllerTest {

@testSetup
static void setupData() {

    // USER (setup)
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        Username = 'testuser' + System.currentTimeMillis() + '@test.com',
        Alias = 'tusr',
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    Group g = new Group(
        Name = 'Accounts Commision',
        Type = 'Queue'
    );
    insert g;

    GroupMember gm = new GroupMember(
        GroupId = g.Id,
        UserOrGroupId = u.Id
    );
    insert gm;
}
    @isTest
static void createBusinessData() {

    User u = [SELECT Id FROM User LIMIT 1];

    Process_Flow__c testProcessFlow = new Process_Flow__c(
        Name = 'BR Amendment',
        Active__c = true,
        Process_Flow_Unique_Name__c = 'test',
        Type__c = 'Cost Approval'
    );
    insert testProcessFlow;

    System.assertNotEquals(null, testProcessFlow.Id);
}

  @isTest static void testGetBusinessProcessDetails() 
  {
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

      
      Test.startTest();
      List<Business_Process_Step__c> result = BPFileUploaderController.getBusinessProcessDetails(bp.Id); 
      Test.stopTest();
  }
    @isTest
    static void testGetCommissionQueueMemberIds() {
        Test.startTest();
        List<Id> ids = BPFileUploaderController.getCommissionQueueMemberIds();
        Test.stopTest();
    }

    @isTest
    static void testRenameUploadedFile() {
       
          Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'Clash Approval',
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        insert steps;
        
        bp.Current_Business_Process_Step__c = steps[0].Id;
        update bp;
        
        // Create file
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Data')
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        Test.startTest();
        BPFileUploaderController.renameUploadedFile(
            bp.Id,
            cv.ContentDocumentId
        );
        Test.stopTest();

        ContentVersion updatedCv = [
            SELECT Title FROM ContentVersion WHERE Id = :cv.Id
        ];
    }

    @isTest
    static void testGetUserRoleName() {

        User u = [SELECT Id FROM User LIMIT 1];

        Test.startTest();
        String roleName =
            BPFileUploaderController.getUserRoleName(u.Id);
        Test.stopTest();

    }
}