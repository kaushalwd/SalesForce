@isTest
public class EscalationEmailsTest {
@testSetup
static void setupData() {

    Profile p = [SELECT Id FROM Profile LIMIT 1];

    // Create Users (Setup object)
    User manager = new User(
        Alias = 'mgr',
        Email = 'manager@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'Manager',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'Asia/Kolkata',
        ProfileId = p.Id,
        Username = 'manager' + System.currentTimeMillis() + '@test.com'
    );
    insert manager;

    User u = new User(
        Alias = 'usr',
        Email = 'user@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'User',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'Asia/Kolkata',
        ProfileId = p.Id,
        Username = 'user' + System.currentTimeMillis() + '@test.com',
        ManagerId = manager.Id
    );
    insert u;

    // Queue + GroupMember (Setup objects)
    Group g = new Group(Name = 'Test Queue', Type = 'Queue');
    insert g;

    insert new GroupMember(
        GroupId = g.Id,
        UserOrGroupId = u.Id
    );

    //  Separate transaction using runAs
    System.runAs(u) {

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
            Assigned_To__c = u.Id,
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

        Step_Escalation__c esc = new Step_Escalation__c(
            Process_Flow_Step__c = pfs1.Id,
            Trigger_To__c = 'Department Head;Assigned TO;Assigned TO Manager;CC Email;BCC Email',
            Department_Head__c = 'dept@test.com',
            CC_Email__c = 'cc@test.com',
            BCC_Email__c = 'bcc@test.com',
            Escalation_Trigger_Days__c = 1
        );
        insert esc;
    }
}

    @isTest
    static void testGetEmails_MainFlow() {

        // Fetch data
        Business_Process_Step__c step = [
            SELECT Id FROM Business_Process_Step__c LIMIT 1
        ];

        Group g = [SELECT Id FROM Group LIMIT 1];

        // Prepare input
        EscalationEmails.InputParams input = new EscalationEmails.InputParams();
        input.StepIds = step.Id;
        input.actionType = '0'; // index for escalation
        input.queueIds = g.Id;

        Test.startTest();
        List<EscalationEmails.ResultWrapper> result =
            EscalationEmails.getEmails(new List<EscalationEmails.InputParams>{ input });
        Test.stopTest();

       
    }

    @isTest
    static void testGetEmails_UserFallbackInsteadOfQueue() {

        Business_Process_Step__c step = [
            SELECT Id FROM Business_Process_Step__c LIMIT 1
        ];

        User u = [SELECT Id FROM User WHERE Email = 'user@test.com' LIMIT 1];

        EscalationEmails.InputParams input = new EscalationEmails.InputParams();
        input.StepIds = step.Id;
        input.actionType = '0';
        input.queueIds = u.Id; // passing user instead of queue

        Test.startTest();
        List<EscalationEmails.ResultWrapper> result =
            EscalationEmails.getEmails(new List<EscalationEmails.InputParams>{ input });
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assert(result[0].message.contains('user@test.com'), 'Fallback user email expected');
    }

    @isTest
    static void testGetEmails_NoEscalation() {
           Process_Flow__c testProcessFlow11 = new Process_Flow__c(
            Name = 'BR Amendment11',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'tes1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow11;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow11.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow11.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow11.Id
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

        EscalationEmails.InputParams input = new EscalationEmails.InputParams();
        input.StepIds = steps[0].Id;
        input.actionType = '0';
        input.queueIds = null;

        Test.startTest();
        List<EscalationEmails.ResultWrapper> result =
            EscalationEmails.getEmails(new List<EscalationEmails.InputParams>{ input });
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('', result[0].message);
        System.assertEquals('', result[0].CCmsg);
    }

    @isTest
    static void testEscalationEmailsSend_NullOrEmpty() {
        EscalationEmailsSend.getEmails(null);
        EscalationEmailsSend.getEmails(new List<EscalationEmailsSend.InputParams>());
    }

    @isTest
    static void testEscalationEmailsSend_WithStep() {
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];
        Group q = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'user@test.com' LIMIT 1];

        EscalationEmailsSend.InputParams input = new EscalationEmailsSend.InputParams();
        input.StepIds = step.Id;
        input.actionType = '0';
        input.queueIds = q.Id;

        EscalationEmailsSend.InputParams inputUser = new EscalationEmailsSend.InputParams();
        inputUser.StepIds = step.Id;
        inputUser.actionType = '0';
        inputUser.queueIds = u.Id;

        EscalationEmailsSend.InputParams inputInvalid = new EscalationEmailsSend.InputParams();
        inputInvalid.StepIds = 'invalid-id';
        inputInvalid.actionType = '0';

        Test.startTest();
        EscalationEmailsSend.getEmails(new List<EscalationEmailsSend.InputParams>{ input, inputUser, inputInvalid });
        Test.stopTest();
    }
}