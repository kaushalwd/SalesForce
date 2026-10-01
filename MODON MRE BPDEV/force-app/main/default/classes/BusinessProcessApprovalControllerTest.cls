/**
 * Tests for BusinessProcessApprovalController / BusinessProcessApprovalService.
 *
 * Deliberately does not create SalesOrder__c, Unit__c, Project__c or Account test data:
 * those are large, heavily customized objects in this org (363/175/82 fields respectively)
 * whose validation rules and required fields were not fully inventoried during analysis.
 * Coverage instead confirms the related-record mapping code takes its "absent" branch
 * cleanly (no null pointer exceptions) when those lookups are empty, which is itself a
 * realistic scenario for several process types. The mapping code for the "present" branch
 * is a direct field copy with no branching logic, reviewed by hand.
 */
@isTest
private class BusinessProcessApprovalControllerTest {

    private static final String PERM_SET_NAME = 'businessProcessSAPermissionSet';

    @testSetup
    static void setup() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User userA = new User(
            FirstName = 'Approval',
            LastName = 'TestUserA',
            Alias = 'atusra',
            Email = 'approval.testusera@example.com.invalid',
            Username = 'approval.testusera' + DateTime.now().getTime() + '@example.com.invalid',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        User userB = new User(
            FirstName = 'Approval',
            LastName = 'TestUserB',
            Alias = 'atusrb',
            Email = 'approval.testuserb@example.com.invalid',
            Username = 'approval.testuserb' + DateTime.now().getTime() + '@example.com.invalid',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert new List<User>{ userA, userB };

        List<PermissionSet> permSets = [SELECT Id FROM PermissionSet WHERE Name = :PERM_SET_NAME LIMIT 1];
        if (!permSets.isEmpty()) {
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = userA.Id, PermissionSetId = permSets[0].Id),
                new PermissionSetAssignment(AssigneeId = userB.Id, PermissionSetId = permSets[0].Id)
            };
        }
    }

    private static User getUserA() {
        return [SELECT Id FROM User WHERE Username LIKE 'approval.testusera%' LIMIT 1];
    }

    private static User getUserB() {
        return [SELECT Id FROM User WHERE Username LIKE 'approval.testuserb%' LIMIT 1];
    }

    private static Business_Process__c createBusinessProcess() {
        // Type__c and Process_Flow__c are deliberately left off a real configured value so this
        // test never triggers a real StepValidator / StepActivator / BusinessProcessAutomation
        // implementation from Business_Process_Validator__mdt / Eligibility__mdt /
        // Business_Process_Approval_Automations__mdt — only DefaultActivator (Test.isRunningTest()
        // forces this fallback inside LwcApproveRejectBpstepController.approveStep regardless).
        Business_Process__c bp = new Business_Process__c(
            Type__c = 'UnitTestProcessType',
            Status__c = 'In Progress'
        );
        insert bp;
        return bp;
    }

    private static Business_Process_Step__c buildStep(
        Id bpId, Id assignedToId, String stepNumber, String name,
        Decimal sectionNum, Decimal sequence, String status
    ) {
        return new Business_Process_Step__c(
            Business_Process__c = bpId,
            Name = name,
            Business_Process_Steps_Name_Custom__c = name,
            Section_Number__c = sectionNum,
            section_Name__c = 'Test Section',
            Sequence__c = sequence,
            Step__c = stepNumber,
            Status__c = status,
            Assigned_To__c = assignedToId,
            OwnerId = assignedToId,
            Is_Approve_Required__c = true,
            Is_Reject_Button_Required__c = true,
            Is_Required_More_Button_Required__c = true,
            Is_Review_Comments_Req__c = false
        );
    }

    // ---------------------------------------------------------------------------------------
    // Positive scenarios
    // ---------------------------------------------------------------------------------------

    @isTest
    static void testUserWithOneAssignedStep() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        insert buildStep(bp.Id, userA.Id, '1', 'Test Approval Step', 1, 1, 'Open');

        List<BusinessProcessApprovalWrapper.ApprovalStepCard> cards;
        System.runAs(userA) {
            Test.startTest();
            cards = BusinessProcessApprovalController.getMyApprovalSteps(null, null);
            Test.stopTest();
        }

        Assert.areEqual(1, cards.size(), 'Expected exactly one pending card for userA.');
        Assert.areEqual('Test Approval Step', cards[0].stepName);
        Assert.areEqual('Open', cards[0].status);
        Assert.areEqual(bp.Id, cards[0].businessProcessId);
    }

    @isTest
    static void testUserWithMultipleAssignedSteps() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        insert new List<Business_Process_Step__c>{
            buildStep(bp.Id, userA.Id, '1', 'First Pending Step', 1, 1, 'Open'),
            buildStep(bp.Id, userA.Id, '2', 'Second Pending Step', 2, 2, 'Accepted')
        };

        List<BusinessProcessApprovalWrapper.ApprovalStepCard> cards;
        System.runAs(userA) {
            cards = BusinessProcessApprovalController.getMyApprovalSteps(null, null);
        }

        Assert.areEqual(2, cards.size(), 'Expected both pending steps to be returned.');
    }

    @isTest
    static void testUserWithNoAssignedApprovals() {
        User userA = getUserA();
        // No steps created at all for userA.
        List<BusinessProcessApprovalWrapper.ApprovalStepCard> cards;
        System.runAs(userA) {
            cards = BusinessProcessApprovalController.getMyApprovalSteps(null, null);
        }
        Assert.isTrue(cards.isEmpty(), 'Expected an empty list when nothing is assigned.');
    }

    @isTest
    static void testSelectStepReturnsDetail() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Detail Step', 1, 1, 'Open');
        insert step;

        BusinessProcessApprovalWrapper.ApprovalStepDetail detail;
        System.runAs(userA) {
            detail = BusinessProcessApprovalController.getApprovalDetail(step.Id);
        }

        Assert.isNotNull(detail, 'Detail should be returned for an owned step.');
        Assert.areEqual(step.Id, detail.card.stepId);
        Assert.areEqual('In Progress', detail.businessProcessStatus);
        Assert.isNull(detail.salesOrderId, 'No Sales Order was linked, so this should stay null.');
        Assert.isTrue(detail.documents.isEmpty(), 'No documents were created for this process.');
    }

    @isTest
    static void testApproveStepActivatesNextStep() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c current = buildStep(bp.Id, userA.Id, '1', 'Current Step', 1, 1, 'Open');
        Business_Process_Step__c next = buildStep(bp.Id, userA.Id, '2', 'Next Step', 2, 2, 'Not Actioned');
        insert new List<Business_Process_Step__c>{ current, next };

        BusinessProcessApprovalWrapper.ActionResult result;
        System.runAs(userA) {
            Test.startTest();
            result = BusinessProcessApprovalController.submitApprovalAction(
                current.Id, 'Approve', 'Looks good, approved.', null, null
            );
            Test.stopTest();
        }

        Assert.isTrue(result.success);
        Assert.areEqual(bp.Id, result.businessProcessId);

        Business_Process_Step__c reloadedCurrent = [SELECT Status__c, Remarks_Comments__c FROM Business_Process_Step__c WHERE Id = :current.Id];
        Assert.areEqual('Completed', reloadedCurrent.Status__c);
        Assert.areEqual('Looks good, approved.', reloadedCurrent.Remarks_Comments__c);

        Business_Process_Step__c reloadedNext = [SELECT Status__c FROM Business_Process_Step__c WHERE Id = :next.Id];
        Assert.areNotEqual('Not Actioned', reloadedNext.Status__c, 'DefaultActivator should have opened the next step.');
    }

    @isTest
    static void testRejectStep() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Reject Me', 1, 1, 'Open');
        insert step;

        BusinessProcessApprovalWrapper.ActionResult result;
        System.runAs(userA) {
            result = BusinessProcessApprovalController.submitApprovalAction(
                step.Id, 'Reject', 'Does not meet requirements.', null, null
            );
        }

        Assert.isTrue(result.success);
        Business_Process_Step__c reloaded = [SELECT Status__c, Remarks_Comments__c FROM Business_Process_Step__c WHERE Id = :step.Id];
        Assert.areEqual('Cancelled', reloaded.Status__c);
        Assert.areEqual('Does not meet requirements.', reloaded.Remarks_Comments__c);
    }

    @isTest
    static void testRequireMoreInformation() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c earlier = buildStep(bp.Id, userA.Id, '1', 'Customer Submission', 1, 1, 'Completed');
        Business_Process_Step__c middle = buildStep(bp.Id, userA.Id, '2', 'Middle Step', 2, 2, 'Completed');
        Business_Process_Step__c current = buildStep(bp.Id, userA.Id, '3', 'Reviewer Step', 3, 3, 'Open');
        insert new List<Business_Process_Step__c>{ earlier, middle, current };

        BusinessProcessApprovalWrapper.ActionResult result;
        System.runAs(userA) {
            result = BusinessProcessApprovalController.submitApprovalAction(
                current.Id, 'RequireMoreInfo', 'Please attach the missing form.', earlier.Id, null
            );
        }

        Assert.isTrue(result.success);
        Business_Process_Step__c reloadedCurrent = [SELECT Status__c FROM Business_Process_Step__c WHERE Id = :current.Id];
        Assert.areEqual('Required Info', reloadedCurrent.Status__c);

        Business_Process_Step__c reloadedEarlier = [SELECT Status__c, Remarks_Comments__c FROM Business_Process_Step__c WHERE Id = :earlier.Id];
        Assert.areEqual('Re Open', reloadedEarlier.Status__c);
    }

    @isTest
    static void testDocumentsExistWithLinkedFile() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Doc Step', 1, 1, 'Open');
        insert step;

        Business_Process_Documents__c doc = new Business_Process_Documents__c(
            Business_Process__c = bp.Id,
            Name = 'Contract.pdf'
        );
        insert doc;

        ContentVersion cv = new ContentVersion(
            Title = 'Contract',
            PathOnClient = 'Contract.pdf',
            VersionData = Blob.valueOf('test file contents'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = doc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        BusinessProcessApprovalWrapper.ApprovalStepDetail detail;
        System.runAs(userA) {
            detail = BusinessProcessApprovalController.getApprovalDetail(step.Id);
        }

        Assert.areEqual(1, detail.documents.size());
        Assert.isTrue(detail.documents[0].hasFile);
        Assert.areEqual(contentDocumentId, detail.documents[0].contentDocumentId);
    }

    @isTest
    static void testNoDocuments() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'No Doc Step', 1, 1, 'Open');
        insert step;

        BusinessProcessApprovalWrapper.ApprovalStepDetail detail;
        System.runAs(userA) {
            detail = BusinessProcessApprovalController.getApprovalDetail(step.Id);
        }

        Assert.isTrue(detail.documents.isEmpty());
    }

    // ---------------------------------------------------------------------------------------
    // Security scenarios
    // ---------------------------------------------------------------------------------------

    @isTest
    static void testCannotActOnAnotherUsersStep() {
        User userA = getUserA();
        User userB = getUserB();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Owned By A', 1, 1, 'Open');
        insert step;

        Boolean blocked = false;
        String errorMessage;
        System.runAs(userB) {
            try {
                BusinessProcessApprovalController.submitApprovalAction(step.Id, 'Approve', 'Sneaky approval.', null, null);
            } catch (AuraHandledException e) {
                blocked = true;
                errorMessage = e.getMessage();
            }
        }

        Assert.isTrue(blocked, 'userB must not be able to act on a step assigned to userA.');

        Business_Process_Step__c reloaded = [SELECT Status__c FROM Business_Process_Step__c WHERE Id = :step.Id];
        Assert.areEqual('Open', reloaded.Status__c, 'Step must be unchanged after a blocked attempt.');
    }

    @isTest
    static void testCannotReadAnotherUsersStepDetail() {
        User userA = getUserA();
        User userB = getUserB();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Owned By A', 1, 1, 'Open');
        insert step;

        Boolean blocked = false;
        System.runAs(userB) {
            try {
                BusinessProcessApprovalController.getApprovalDetail(step.Id);
            } catch (AuraHandledException e) {
                blocked = true;
            }
        }

        Assert.isTrue(blocked, 'userB must not be able to read detail for a step assigned to userA.');
    }

    @isTest
    static void testInvalidStepIdThrows() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c throwaway = buildStep(bp.Id, userA.Id, '1', 'Throwaway', 1, 1, 'Open');
        insert throwaway;
        Id fakeButValidId = throwaway.Id;
        delete throwaway;

        Boolean threw = false;
        System.runAs(userA) {
            try {
                BusinessProcessApprovalController.getApprovalDetail(fakeButValidId);
            } catch (AuraHandledException e) {
                threw = true;
                Assert.areEqual('Approval step not found.', e.getMessage());
            }
        }
        Assert.isTrue(threw, 'A deleted/non-existent step Id must raise a friendly error.');
    }

    // ---------------------------------------------------------------------------------------
    // Error scenarios
    // ---------------------------------------------------------------------------------------

    @isTest
    static void testRejectWithoutCommentsThrows() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Needs Comment', 1, 1, 'Open');
        insert step;

        Boolean threw = false;
        System.runAs(userA) {
            try {
                BusinessProcessApprovalController.submitApprovalAction(step.Id, 'Reject', '', null, null);
            } catch (AuraHandledException e) {
                threw = true;
                Assert.areEqual('Comments are required for this action.', e.getMessage());
            }
        }
        Assert.isTrue(threw, 'Rejecting without comments must be blocked.');
    }

    @isTest
    static void testRequireMoreInfoWithoutTargetStepThrows() {
        User userA = getUserA();
        Business_Process__c bp = createBusinessProcess();
        Business_Process_Step__c step = buildStep(bp.Id, userA.Id, '1', 'Needs Target', 1, 1, 'Open');
        insert step;

        Boolean threw = false;
        System.runAs(userA) {
            try {
                BusinessProcessApprovalController.submitApprovalAction(step.Id, 'RequireMoreInfo', 'Please clarify.', null, null);
            } catch (AuraHandledException e) {
                threw = true;
                Assert.areEqual('Select which earlier step should provide the missing information.', e.getMessage());
            }
        }
        Assert.isTrue(threw, 'Requiring more info without a target step must be blocked.');
    }

    @isTest
    static void testMissingStepOrActionThrows() {
        User userA = getUserA();
        Boolean threw = false;
        System.runAs(userA) {
            try {
                BusinessProcessApprovalController.submitApprovalAction(null, null, null, null, null);
            } catch (AuraHandledException e) {
                threw = true;
                Assert.areEqual('A step and an action are required.', e.getMessage());
            }
        }
        Assert.isTrue(threw, 'A null step/action must raise a friendly error, not an unhandled exception.');
    }
}