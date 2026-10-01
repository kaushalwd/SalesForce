@isTest
public class LwcApproveRejectBpstepControllerTest {

   @testSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;
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
            OwnerId = u.Id,
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
            OwnerId = u.Id,
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        insert steps;
    }

    @isTest
    static void testIsUserInQueue() {
        Group g = new Group(Name='Test Queue', Type='Queue');
        insert g;

        Id currentUserId = UserInfo.getUserId();

        GroupMember gm = new GroupMember(
            GroupId = g.Id,
            UserOrGroupId = currentUserId
        );
        insert gm;

        Test.startTest();
        Boolean result = LwcApproveRejectBpstepController.isUserInQueue(g.Id, currentUserId);
        Test.stopTest();

        System.assertEquals(true, result);
    }
    @isTest
    static void testApproveStepAssignedTo() {
        List<Business_Process_Step__c> steps =
            [SELECT Id FROM Business_Process_Step__c ORDER BY Sequence__c ASC LIMIT 2];

        Test.startTest();
        String res = LwcApproveRejectBpstepController.approveStepAssignedTo(
            steps[0].Id,
            steps[1].Id,
            'Approved'
        );
        Test.stopTest();
    }
    @isTest
    static void testReassignUser() {
        User u = [SELECT Id FROM User LIMIT 1];
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        String result = LwcApproveRejectBpstepController.reAssignUser(
            step.Id,
            u.Id,
            'Reassigned'
        );
        Test.stopTest();
    }

    @isTest
    static void testCheckSysAdmin() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User adminUser = new User(
            Alias = 'admin',
            Email = 'admin@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'admin' + System.currentTimeMillis() + '@test.com'
        );
        insert adminUser;

        Test.startTest();
        Boolean isAdmin = LwcApproveRejectBpstepController.checkSysAdmin(adminUser.Id);
        Test.stopTest();
    }

    @isTest
    static void testRejectStep() {
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        LwcApproveRejectBpstepController.RejectStepWrapper wrap =
            new LwcApproveRejectBpstepController.RejectStepWrapper();
        wrap.bpsId = step.Id;
        wrap.comment = 'Rejected';

        Test.startTest();
        String res = LwcApproveRejectBpstepController.rejectStep(JSON.serialize(wrap));
        Test.stopTest();
    }
      @isTest
    static void testCheckLoggedInUser1() {
        Business_Process_Step__c step = [SELECT Id, OwnerId, Business_Process__c FROM Business_Process_Step__c LIMIT 1];

        step.OwnerId = UserInfo.getUserId();
        update step;
       
        Test.startTest();
        String result = LwcApproveRejectBpstepController.checkLoggedInUser(step.Id);
        Test.stopTest();
       
        System.assertEquals('Success', result, 'Expected Success for authorized user');
       
        step.OwnerId = UserInfo.getUserId();
        update step;
       
        result = LwcApproveRejectBpstepController.checkLoggedInUser(step.Id);
        LwcApproveRejectBpstepController.reAssignUser(step.Id,UserInfo.getUserId(),'Hi');
        LwcApproveRejectBpstepController.checkSysAdmin(UserInfo.getUserId());
 
        LwcApproveRejectBpstepController.getPaymentProofDocuments(step.Id);
      
        Business_Process_Documents__c treasuryDoc = new Business_Process_Documents__c(
        Name = 'Treasury Reference Document',
        Business_Process__c = step.Business_Process__c,
        Business_Process_Step__c = step.Id
    );

    Business_Process_Documents__c supportDoc = new Business_Process_Documents__c(
        Name = 'Support Documents',
        Business_Process__c = step.Business_Process__c,
        Business_Process_Step__c = step.Id
    );

    insert new List<Business_Process_Documents__c>{ treasuryDoc, supportDoc };
       
        ContentVersion version = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test File Content')
        );
        insert version;
       
        ContentDocument cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :version.Id LIMIT 1];
       
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = treasuryDoc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
      
        LwcApproveRejectBpstepController.getPaymentProofDocuments(step.Id);
        List<Id> bpsIds =new  List<Id>(); bpsIds.add(step.Id);
        List<Id> fileids=new List<Id>();
        List<Id> supportDocumentFileIds=new List<Id>(); supportDocumentFileIds.add(cd.Id);   
    }
  
    @isTest
static void testCheckLoggedInUser_SystemAdmin() {

    Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    User adminUser = new User(
        Alias = 'sysadm',
        Email = 'sysadmin@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'Admin',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = adminProfile.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        UserName = 'sysadmin' + System.currentTimeMillis() + '@test.com'
    );
    insert adminUser;
   
Process_Flow__c testProcessFlow5 = new Process_Flow__c(
            Name = 'Broker Commission Slab Approvals',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test5',
            Type__c='Cost Approval'
        );
        insert testProcessFlow5;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow5.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow5.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow5.Id
        );
        insert bp;

     List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId =  UserInfo.getUserId(),
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

    System.runAs(adminUser){
        Test.startTest();
        String result = LwcApproveRejectBpstepController.checkLoggedInUser(steps[0].Id);
        Test.stopTest();
    }
}
@isTest
static void testApproveFileIds() {

  Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment1',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test1',
            Type__c='Office Branding'
        );
        insert testProcessFlow1;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c();
        insert bp;
       
  List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId =  UserInfo.getUserId(),
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

    Business_Process_Documents__c treasuryDoc = new Business_Process_Documents__c(
        Name = 'Treasury Reference Document',
        Business_Process__c = bp.Id,
        Business_Process_Step__c = steps[0].Id
    );

    Business_Process_Documents__c supportDoc = new Business_Process_Documents__c(
        Name = 'Support Documents',
        Business_Process__c = bp.Id,
        Business_Process_Step__c = steps[0].Id
    );

    insert new List<Business_Process_Documents__c>{ treasuryDoc, supportDoc };

    ContentVersion version = new ContentVersion(
        Title = 'Test File',
        PathOnClient = 'Test.pdf',
        VersionData = Blob.valueOf('Dummy content')
    );
    insert version;

    ContentDocument cd = [
        SELECT Id 
        FROM ContentDocument 
        WHERE LatestPublishedVersionId = :version.Id 
        LIMIT 1
    ];
    List<Id> bpsIds = new List<Id>{ steps[0].Id };
    List<Id> fileIds = new List<Id>{ cd.Id };              
    List<Id> supportFileIds = new List<Id>{ cd.Id };      

    Test.startTest();
    LwcApproveRejectBpstepController.approveFileIds(
        bpsIds,
        fileIds,
        supportFileIds
    );
    Test.stopTest();

}  
           @isTest
    static void approveStepAssignedTo() {
     
        User user = [SELECT Id FROM User WHERE Id=: UserInfo.getUserId()];//Profile.Name = 'Standard User' LIMIT 1];
        Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment1',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test1',
            Type__c='Office Branding'
        );
        insert testProcessFlow1;
        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c();
        insert bp;
       
  List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId = user.Id,
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
            OwnerId = user.Id,
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));

        insert steps;
           
        Test.startTest();
        Id stepId = steps[0].Id;
        LwcApproveRejectBpstepController.getAssinedSteps(stepId);
        
        String Result = LwcApproveRejectBpstepController.approveStepAssignedTo(
            steps[0].Id, 
            steps[1].Id, 
            'TEST'
        );
        Test.stopTest(); 
    }
        @isTest
    static void testGetSteps() {
        Test.startTest();
           
        Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'BR Amendment2',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test2',
            Type__c='Cost Approval'
        );
        insert testProcessFlow;
     
        Business_Process__c bp = new Business_Process__c();
        bp.Type__c='SPA Checklist Maker and Checker';
        bp.Process_Flow__c = testProcessFlow.Id;
        insert bp;
        Business_Process_Step__c bps = new Business_Process_Step__c(
            Business_Process__c = bp.Id
           
        );
        bps.name = 'test';
        bps.Business_Process_Steps_Name_Custom__c = 'test';
        bps.Sequence__c = 1;
        bps.Assigned_Time__c = system.now();
        bps.Completed_Time__c = system.now();
        bps.Original_Queue_Id__c = UserInfo.getUserId();
        bps.Section_Number__c = 1;
        bps.section_Name__c = 'Section 1';
        bps.OwnerId = UserInfo.getUserId();
        bps.Is_check_List__c = true;
       
       
        Process_Checklist__c objPc=new Process_Checklist__c();
        objPc.Business_Process__c = bp.Id;
        insert objPc;
        
         Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment3',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test3',
            Type__c='Office Branding'
        );
        insert testProcessFlow1;

         Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;
       
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
        Id stepId1 = steps[0].Id;
        Id stepId2 = steps[1].Id;
        
        LwcApproveRejectBpstepController.RejectStepWrapper rejWrap = new LwcApproveRejectBpstepController.RejectStepWrapper();
        rejWrap.bpsId = stepId1;
        rejWrap.comment = 'Test Comment';
        rejWrap.documentType = '';
        rejWrap.reasonForRejection = '';

        LwcApproveRejectBpstepController.RequestMoreInfoWrapper rfmiWrap = new LwcApproveRejectBpstepController.RequestMoreInfoWrapper();
        rfmiWrap.bpsId = stepId1;
        rfmiWrap.comment = 'Test Comment';
        rfmiWrap.rejectingToBpsId = stepId2;
        rfmiWrap.documentType = '';
        rfmiWrap.reasonForMoreInfo = '';
       
        List<Business_Process_Step__c> lstBps = LwcApproveRejectBpstepController.getSteps(stepId1);
        
        LwcApproveRejectBpstepController.FormWrapper wrapper = 
            new LwcApproveRejectBpstepController.FormWrapper();
        String wrapperJSON = JSON.serialize(wrapper);
        
        String result1 = LwcApproveRejectBpstepController.approveStep(
            wrapperJSON,
            stepId1, 
            'Test Comment',
            UserInfo.getUserId(), 
            0, 
            0, 
            '' 
        );

        String result2 = LwcApproveRejectBpstepController.onHoldStep(steps[0].Business_Process__c, stepId1, 'Test BR Number');
        LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(rfmiWrap));
        LwcApproveRejectBpstepController.getqueueMembers(steps[0].Id);
        Test.stopTest();
    }
    
    @isTest
static void testRequestForMoreInfo_AllScenarios() {
    Process_Flow__c pf = new Process_Flow__c(
        Name = 'Test Flow',
        Active__c = true,
        Process_Flow_Unique_Name__c = 'rfmiTest',
        Type__c = 'Cost Approval'
    );
    insert pf;

    Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
        Section_Number__c = 1,
        section_Name__c = 'S1',
        Process_Flow__c = pf.Id
    );
    insert pfs1;

    Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
        Section_Number__c = 2,
        section_Name__c = 'S2',
        Process_Flow__c = pf.Id
    );
    insert pfs2;

    Business_Process__c bp = new Business_Process__c(
        Process_Flow__c = pf.Id
    );
    insert bp;

    Process_Checklist__c pc = new Process_Checklist__c(
        Business_Process__c = bp.Id
    );
    insert pc;

    List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>{
        new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id,
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Is_check_List__c = true,
            Business_Process_Steps_Name_Custom__c='test1',
            Section_Number__c=1,
            section_Name__c='test1'
        ),
        new Business_Process_Step__c(
            Name = 'Step 2',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id,
            Sequence__c = 2,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test1',
            Section_Number__c=1,
            section_Name__c='test1'
        )
    };
    insert steps;

    Id stepId1 = steps[0].Id;
    Id stepId2 = steps[1].Id;

    LwcApproveRejectBpstepController.RequestMoreInfoWrapper baseWrap =
        new LwcApproveRejectBpstepController.RequestMoreInfoWrapper();
    baseWrap.bpsId = stepId1;
    baseWrap.rejectingToBpsId = stepId2;
    baseWrap.comment = 'Test Comment';

    Test.startTest();

    LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(baseWrap));

    steps[0].Is_Single_Level_Required_Info__c = true;
    update steps[0];

    LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(baseWrap));

    LwcApproveRejectBpstepController.RequestMoreInfoWrapper multiWrap =
        new LwcApproveRejectBpstepController.RequestMoreInfoWrapper();
    multiWrap.bpsId = stepId1;
    multiWrap.rejectingToBpsId = stepId2;
    multiWrap.comment = 'Multi Step';

    LwcApproveRejectBpstepController.MultiStepInfo msi =
        new LwcApproveRejectBpstepController.MultiStepInfo();
    msi.Id = stepId2;
    msi.reason = 'Reason 1';

    multiWrap.multiSteps =
        new List<LwcApproveRejectBpstepController.MultiStepInfo>{ msi };

    LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(multiWrap));

    LwcApproveRejectBpstepController.RequestMoreInfoWrapper multiIdWrap =
        new LwcApproveRejectBpstepController.RequestMoreInfoWrapper();
    multiIdWrap.bpsId = stepId1;
    multiIdWrap.rejectingToBpsId = stepId2;
    multiIdWrap.comment = 'Multi Id';
    multiIdWrap.multiStepIds = new List<Id>{ stepId2 };

    LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(multiIdWrap));

    steps[1].Name = 'Customer Documents';
    update steps;

    LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(baseWrap));

    steps[1].Name = 'Sales Audit';
    update steps;

    LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(baseWrap));

    Test.stopTest();
}
         
    @isTest
    static void test_approveMultipleSteps() {
        User user = [SELECT Id FROM User WHERE Id=: UserInfo.getUserId()];//Profile.Name = 'Standard User' LIMIT 1];
        Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'BR Amendment2',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test2',
            Type__c='Cost Approval'
        );
        insert testProcessFlow;
        
        Business_Process__c bp = new Business_Process__c();
        bp.Type__c='SPA Checklist Maker and Checker';
        bp.Process_Flow__c = testProcessFlow.Id;
        insert bp;
        Business_Process_Step__c bps = new Business_Process_Step__c(
            Business_Process__c = bp.Id
           
        );
        bps.name = 'test';
        bps.Business_Process_Steps_Name_Custom__c = 'test';
        bps.Sequence__c = 1;
        bps.Assigned_Time__c = system.now();
        bps.Completed_Time__c = system.now();
        bps.Original_Queue_Id__c = UserInfo.getUserId();
        bps.Section_Number__c = 1;
        bps.section_Name__c = 'Section 1';
        bps.OwnerId = UserInfo.getUserId();
        bps.Is_check_List__c = true;
       
       
        Process_Checklist__c objPc=new Process_Checklist__c();
        objPc.Business_Process__c = bp.Id;
        insert objPc;
        
         Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment3',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test3',
            Type__c='Office Branding'
        );
        insert testProcessFlow1;
         Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;
       
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
            section_Name__c='test2',
             Step__c = 'Next Step'
        ));

        insert steps;
        Id stepId1 = steps[0].Id;
        Id stepId2 = steps[1].Id;
           
            
        Test.startTest();
        LwcApproveRejectBpstepController.approveMultipleSteps(new List<String>{ stepId1 },'Approved from test', '{}');
        Test.stopTest();

        Business_Process_Step__c updatedStep1 = [
            SELECT Status__c, Remarks_Comments__c
            FROM Business_Process_Step__c
            WHERE Id = :stepId1
        ];
      
        System.assertEquals('Completed', updatedStep1.Status__c, 'Step 1 should be marked as Completed');
        System.assertEquals('Approved from test', updatedStep1.Remarks_Comments__c);

        Business_Process_Step__c updatedStep2 = [
            SELECT Status__c
            FROM Business_Process_Step__c
            WHERE Id = :stepId1
        ];
        System.assertNotEquals(null, updatedStep2.Status__c, 'Step 2 status should not be null');
        System.debug('Step 2 updated status: ' + updatedStep2.Status__c);
    }  
    static testMethod void test_getnextqueueMembers() {
        Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment3',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test3',
            Type__c='Office Branding'
        );
        insert testProcessFlow1;

         Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;
        Business_Process__c bp = new Business_Process__c(/* add necessary fields */);
        bp.Type__c='SPA Checklist Maker and Checker';
        bp.Process_Flow__c = testProcessFlow1.Id;
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
        Id stepId = steps[0].Id;
 
        Test.startTest();
        List<BusinessProcessStepController.OptionWrapper> options =
            LwcApproveRejectBpstepController.getnextqueueMembers(stepId);
        Test.stopTest();
    }
    
     @isTest
    static void test_approveMultipleSteps1() {
                Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment3',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test3',
            Type__c='Office Branding'
        );
        insert testProcessFlow1;

         Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;
        Business_Process__c bp = new Business_Process__c(/* add necessary fields */);
        bp.Type__c='SPA Checklist Maker and Checker';
        bp.Process_Flow__c = testProcessFlow1.Id;
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
            section_Name__c='test2', 
            Step__c = 'Next Step'
        ));

        insert steps;
        Id stepId1 = steps[0].Id;
     String additionalJson = '{"BPN_Number__c":"12345"}';
        
        Test.startTest();
        LwcApproveRejectBpstepController.approveMultipleSteps(
            new List<String>{ stepId1 },
            'Approved from test',
            additionalJson
        );
        Test.stopTest();
    }
    @isTest
static void testRequestForMoreInfoMultipleSteps_MultiLevel() {
    Process_Flow__c pf = new Process_Flow__c(
        Name = 'Test PF',
        Active__c = true,
        Process_Flow_Unique_Name__c = 'testML',
        Type__c='Cost Approval'
    );
    insert pf;

    Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
        Section_Number__c=1,
        section_Name__c='TES1',
        Process_Flow__c = pf.Id
    );
    insert pfs1;

    Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
        Section_Number__c=2,
        section_Name__c='TES2',
        Process_Flow__c = pf.Id
    );
    insert pfs2;

    Business_Process__c bp = new Business_Process__c(
        Process_Flow__c = pf.Id
    );
    insert bp;

    List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

    steps.add(new Business_Process_Step__c(
        Name = 'Step 1',
        Business_Process__c = bp.Id,
        Process_Flow_Step__c = pfs1.Id,
        Sequence__c = 1,
        Is_Single_Level_Required_Info__c = false,
        Status__c = 'Not Actioned',
        OwnerId = UserInfo.getUserId(),
        Section_Number__c=1,
        section_Name__c='test1',
        Business_Process_Steps_Name_Custom__c='test1'
    ));

    steps.add(new Business_Process_Step__c(
        Name = 'Step 2',
        Business_Process__c = bp.Id,
        Process_Flow_Step__c = pfs2.Id,
        Sequence__c = 2,
        Is_Single_Level_Required_Info__c = false,
        Status__c = 'Not Actioned',
        OwnerId = UserInfo.getUserId(),
        Section_Number__c=2,
        section_Name__c='test2',
        Business_Process_Steps_Name_Custom__c='test1'
    ));
    
    steps.add(new Business_Process_Step__c(
    Name = 'Step 3',
    Business_Process__c = bp.Id,
    Process_Flow_Step__c = pfs2.Id,
    Sequence__c = 3,
    Is_Single_Level_Required_Info__c = false,
    Status__c = 'Not Actioned',
    OwnerId = UserInfo.getUserId(),
    Section_Number__c=3,
    section_Name__c='test3',
    Business_Process_Steps_Name_Custom__c='test1'
));

    insert steps;

    List<Id> stepIds = new List<Id>{ steps[2].Id };

    Test.startTest();
    LwcApproveRejectBpstepController.requestForMoreInfoMultipleSteps(
        stepIds,
        steps[0].Id,
        'Test Comment'
    );
    Test.stopTest();   
}
    @isTest
    static void testRejectMultipleSteps() {
        List<Business_Process_Step__c> steps =
            [SELECT Id FROM Business_Process_Step__c LIMIT 2];

        List<String> ids = new List<String>();
        for (Business_Process_Step__c s : steps) {
            ids.add(s.Id);
        }
        Test.startTest();
        LwcApproveRejectBpstepController.rejectMultipleSteps(ids, 'Rejected');
        Test.stopTest();

        System.assert(true);
    }
   
    @isTest
static void testRequestForMoreInfoMultipleSteps() {
         Process_Flow__c testProcessFlow3 = new Process_Flow__c(
            Name = 'BR Amendment3',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test3',
            Type__c='Cost Approval'
        );
        insert testProcessFlow3;
 
        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow3.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow3.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow3.Id
        );
        insert bp;

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Is_Single_Level_Required_Info__c = true,
            Status__c = 'Not Actioned',
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test1',
            Section_Number__c=1,
            section_Name__c='test1'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 2',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id, 
            Sequence__c = 2, 
            Is_Single_Level_Required_Info__c = true,
            Status__c = 'Not Actioned',
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));

        insert steps;
  
  List<Id> stepIds = new List<Id>{ steps[0].Id };

Test.startTest();
LwcApproveRejectBpstepController.requestForMoreInfoMultipleSteps(
    stepIds,
    steps[0].Id, 
    'Test Comment'
);
Test.stopTest();
   
}
}