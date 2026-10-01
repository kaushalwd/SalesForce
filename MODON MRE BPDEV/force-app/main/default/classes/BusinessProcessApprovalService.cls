/**
 * 
 * Bypassing it would leave a process permanently stalled.
 */
public with sharing class BusinessProcessApprovalService {

    // Confirmed with the business: exact match to BusinessProcessStepController.fetchInitialSteps's
    // existing default "active" status set (no changes).
    private static final Set<String> PENDING_STATUSES = new Set<String>{
        'Accepted', 'Open', 'Re Open', 'Provided Info', 'Assigned', 'Not Actioned'
    };

    public static final String ACTION_APPROVE = 'Approve';
    public static final String ACTION_REJECT = 'Reject';
    public static final String ACTION_MORE_INFO = 'RequireMoreInfo';

    private static final Integer DEFAULT_PAGE_SIZE = 50;

    public static List<BusinessProcessApprovalWrapper.ApprovalStepCard> getMyApprovalSteps(Integer limitCount, Integer offsetCount) {
        try {
            Id currentUserId = UserInfo.getUserId();
            Integer pageSize = (limitCount == null || limitCount <= 0) ? DEFAULT_PAGE_SIZE : limitCount;
            Integer pageOffset = (offsetCount == null || offsetCount < 0) ? 0 : offsetCount;

            List<Business_Process_Step__c> steps = [
                SELECT Id, Name, Status__c, CreatedDate, Assigned_Time__c, CurrencyIsoCode,
                       Is_Approve_Required__c, Is_Reject_Button_Required__c,
                       Is_Required_More_Button_Required__c, Is_Review_Comments_Req__c,
                       Choose_Next_Owner__c,
                       Business_Process__c, Business_Process__r.Name,
                       Business_Process__r.Process_Flow__r.Name,
                       Business_Process__r.Current_Step_Status__c,
                       Business_Process__r.Account__r.Name,
                       Business_Process__r.Unit__r.Name,
                       Business_Process__r.Project__r.Name,
                       Business_Process__r.Sales_Order__r.Name
                FROM Business_Process_Step__c
                WHERE Assigned_To__c = :currentUserId
                  AND Status__c IN :PENDING_STATUSES
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :pageOffset
            ];

            List<BusinessProcessApprovalWrapper.ApprovalStepCard> cards = new List<BusinessProcessApprovalWrapper.ApprovalStepCard>();
            for (Business_Process_Step__c s : steps) {
                cards.add(toCard(s));
            }
            return cards;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw handled('Unable to load your approvals: ' + e.getMessage());
        }
    }

    public static BusinessProcessApprovalWrapper.ApprovalStepDetail getApprovalDetail(Id stepId) {
        try {
            return buildApprovalDetail(stepId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw handled('Unable to load approval details: ' + e.getMessage());
        }
    }

    private static BusinessProcessApprovalWrapper.ApprovalStepDetail buildApprovalDetail(Id stepId) {
        assertOwnedByCurrentUser(stepId);

        List<Business_Process_Step__c> steps = [
            SELECT Id, Name, Status__c, CreatedDate, Assigned_Time__c, Remarks_Comments__c, CurrencyIsoCode,
                   Sequence__c, section_Name__c, Department__c,
                   Is_Approve_Required__c, Is_Reject_Button_Required__c,
                   Is_Required_More_Button_Required__c, Is_Review_Comments_Req__c, Choose_Next_Owner__c,
                   Business_Process__c,
                   Business_Process__r.Name, Business_Process__r.Status__c, Business_Process__r.Latest_Comment__c,
                   Business_Process__r.Current_Step_Status__c, Business_Process__r.Process_Flow__r.Name,
                   Business_Process__r.Account__c, Business_Process__r.Account__r.Name,
                   Business_Process__r.Account__r.AccountNumber, Business_Process__r.Account__r.Phone,
                   Business_Process__r.Unit__c, Business_Process__r.Unit__r.Name, Business_Process__r.Unit__r.Status__c,
                   Business_Process__r.Unit__r.BasePrice__c, Business_Process__r.Unit__r.TotalPrice__c,
                   Business_Process__r.Unit__r.Number_of_Bedrooms__c,
                   Business_Process__r.Project__c, Business_Process__r.Project__r.Name,
                   Business_Process__r.Sales_Order__c, Business_Process__r.Sales_Order__r.Name,
                   Business_Process__r.Sales_Order__r.Status__c, Business_Process__r.Sales_Order__r.Sub_Status__c,
                   Business_Process__r.Sales_Order__r.TotalAmount__c, Business_Process__r.Sales_Order__r.Totalpaidamount__c,
                   Business_Process__r.Sales_Order__r.Total_Outstanding__c, Business_Process__r.Sales_Order__r.Booking_Date__c,
                   Business_Process__r.Sales_Order_Installment__c, Business_Process__r.Sales_Order_Installment__r.Name,
                   Business_Process__r.Sales_Order_Installment__r.InstallmentAmount__c,
                   Business_Process__r.Sales_Order_Installment__r.MilestoneDate__c,
                   Business_Process__r.Sales_Order_Installment__r.PaymentStatus__c
            FROM Business_Process_Step__c
            WHERE Id = :stepId
            LIMIT 1
        ];

        if (steps.isEmpty()) {
            throw handled('Approval step not found.');
        }
        Business_Process_Step__c step = steps[0];

        BusinessProcessApprovalWrapper.ApprovalStepDetail detail = new BusinessProcessApprovalWrapper.ApprovalStepDetail();
        detail.card = toCard(step);
        detail.remarksComments = step.Remarks_Comments__c;
        detail.sequence = step.Sequence__c;
        detail.sectionName = step.section_Name__c;
        detail.department = step.Department__c;

        Business_Process__c bp = step.Business_Process__r;
        if (bp != null) {
            detail.businessProcessStatus = bp.Status__c;
            detail.latestComment = bp.Latest_Comment__c;

            if (bp.Account__c != null) {
                detail.accountId = bp.Account__c;
                detail.accountNumber = bp.Account__r.AccountNumber;
                detail.accountPhone = bp.Account__r.Phone;
            }
            if (bp.Sales_Order__c != null) {
                detail.salesOrderId = bp.Sales_Order__c;
                detail.salesOrderName = bp.Sales_Order__r.Name;
                detail.salesOrderStatus = bp.Sales_Order__r.Status__c;
                detail.salesOrderSubStatus = bp.Sales_Order__r.Sub_Status__c;
                detail.totalAmount = bp.Sales_Order__r.TotalAmount__c;
                detail.totalPaidAmount = bp.Sales_Order__r.Totalpaidamount__c;
                detail.totalOutstanding = bp.Sales_Order__r.Total_Outstanding__c;
                detail.bookingDate = bp.Sales_Order__r.Booking_Date__c;
            }
            if (bp.Unit__c != null) {
                detail.unitId = bp.Unit__c;
                detail.unitName = bp.Unit__r.Name;
                detail.unitStatus = bp.Unit__r.Status__c;
                detail.unitBasePrice = bp.Unit__r.BasePrice__c;
                detail.unitTotalPrice = bp.Unit__r.TotalPrice__c;
                detail.numberOfBedrooms = bp.Unit__r.Number_of_Bedrooms__c;
            }
            if (bp.Project__c != null) {
                detail.projectId = bp.Project__c;
                detail.projectName = bp.Project__r.Name;
            }
            if (bp.Sales_Order_Installment__c != null) {
                detail.installmentId = bp.Sales_Order_Installment__c;
                detail.installmentName = bp.Sales_Order_Installment__r.Name;
                detail.installmentAmount = bp.Sales_Order_Installment__r.InstallmentAmount__c;
                detail.installmentMilestoneDate = bp.Sales_Order_Installment__r.MilestoneDate__c;
                detail.installmentPaymentStatus = bp.Sales_Order_Installment__r.PaymentStatus__c;
            }
        }

        detail.documents = getDocumentsForBusinessProcess(step.Business_Process__c);
        return detail;
    }

    public static BusinessProcessApprovalWrapper.ActionResult submitApprovalAction(
        Id stepId, String actionName, String comments, Id reopenStepId, Id nextStepOwnerId
    ) {
        if (stepId == null || String.isBlank(actionName)) {
            throw handled('A step and an action are required.');
        }
        if ((actionName == ACTION_REJECT || actionName == ACTION_MORE_INFO) && String.isBlank(comments)) {
            throw handled('Comments are required for this action.');
        }
        if (actionName == ACTION_MORE_INFO && reopenStepId == null) {
            throw handled('Select which earlier step should provide the missing information.');
        }

        Business_Process_Step__c step = assertOwnedByCurrentUser(stepId);

        // Belt-and-suspenders: the existing engine's own authorization gate also covers
        // queue-owned steps (OwnerId), which a plain Assigned_To__c comparison misses.
        String authResult = LwcApproveRejectBpstepController.checkLoggedInUser(stepId);
        if (authResult != 'Success') {
            throw handled('You are not authorized to act on this approval step.');
        }

        try {
            String businessProcessIdStr;

            if (actionName == ACTION_APPROVE) {
                LwcApproveRejectBpstepController.FormWrapper formWrapper = new LwcApproveRejectBpstepController.FormWrapper();
                formWrapper.stepId = stepId;
                formWrapper.comment = comments;
                businessProcessIdStr = LwcApproveRejectBpstepController.approveStep(
                    JSON.serialize(formWrapper), stepId, comments, nextStepOwnerId, null, null, null
                );
            } else if (actionName == ACTION_REJECT) {
                LwcApproveRejectBpstepController.RejectStepWrapper rejectWrapper = new LwcApproveRejectBpstepController.RejectStepWrapper();
                rejectWrapper.bpsId = stepId;
                rejectWrapper.comment = comments;
                businessProcessIdStr = LwcApproveRejectBpstepController.rejectStep(JSON.serialize(rejectWrapper));
            } else if (actionName == ACTION_MORE_INFO) {
                LwcApproveRejectBpstepController.RequestMoreInfoWrapper moreInfoWrapper = new LwcApproveRejectBpstepController.RequestMoreInfoWrapper();
                moreInfoWrapper.bpsId = stepId;
                moreInfoWrapper.rejectingToBpsId = reopenStepId;
                moreInfoWrapper.comment = comments;
                businessProcessIdStr = LwcApproveRejectBpstepController.requestForMoreInfo(JSON.serialize(moreInfoWrapper));
            } else {
                throw handled('Unknown action: ' + actionName);
            }

            BusinessProcessApprovalWrapper.ActionResult result = new BusinessProcessApprovalWrapper.ActionResult();
            result.success = true;
            result.businessProcessId = String.isNotBlank(businessProcessIdStr) ? Id.valueOf(businessProcessIdStr) : step.Business_Process__c;
            result.message = actionLabel(actionName) + ' submitted.';
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw handled(e.getDmlMessage(0));
        } catch (Exception e) {
            throw handled('Unable to submit this action: ' + e.getMessage());
        }
    }

    // ---------------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------------

    /**
     * AuraHandledException.getMessage() returns the generic "Script-thrown exception" unless
     * setMessage() is called explicitly — a well-known Apex gotcha. Centralized here so every
     * throw site (and every test asserting on the message) gets the real text back.
     */
    private static AuraHandledException handled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    /**
     * Server-side ownership guard. Never trust a client-passed user Id — this always compares
     * against UserInfo.getUserId(). Used before both reading step detail and acting on a step,
     * so a step Id guessed/edited in the browser can't be used to view or action someone else's work.
     */
    private static Business_Process_Step__c assertOwnedByCurrentUser(Id stepId) {
        List<Business_Process_Step__c> steps = [
            SELECT Id, Assigned_To__c, Business_Process__c
            FROM Business_Process_Step__c
            WHERE Id = :stepId
            LIMIT 1
        ];
        if (steps.isEmpty()) {
            throw handled('Approval step not found.');
        }
        Business_Process_Step__c step = steps[0];
        if (step.Assigned_To__c != UserInfo.getUserId()) {
            throw handled('You are not assigned to this approval step.');
        }
        return step;
    }

    private static BusinessProcessApprovalWrapper.ApprovalStepCard toCard(Business_Process_Step__c s) {
        BusinessProcessApprovalWrapper.ApprovalStepCard card = new BusinessProcessApprovalWrapper.ApprovalStepCard();
        card.stepId = s.Id;
        card.stepName = s.Name;
        card.status = s.Status__c;
        card.currencyCode = s.CurrencyIsoCode;
        card.createdDate = s.CreatedDate;
        card.assignedDate = s.Assigned_Time__c;
        card.isApproveAllowed = s.Is_Approve_Required__c;
        card.isRejectAllowed = s.Is_Reject_Button_Required__c;
        card.isRequireMoreInfoAllowed = s.Is_Required_More_Button_Required__c;
        card.isReviewCommentsRequired = s.Is_Review_Comments_Req__c;
        card.isChooseNextOwner = s.Choose_Next_Owner__c;
        card.businessProcessId = s.Business_Process__c;

        Business_Process__c bp = s.Business_Process__r;
        if (bp != null) {
            card.businessProcessName = bp.Name;
            card.currentStepStatus = bp.Current_Step_Status__c;
            card.processTypeName = bp.Process_Flow__r != null ? bp.Process_Flow__r.Name : null;
            card.accountName = bp.Account__r != null ? bp.Account__r.Name : null;
            card.unitName = bp.Unit__r != null ? bp.Unit__r.Name : null;
            card.projectName = bp.Project__r != null ? bp.Project__r.Name : null;
            card.salesOrderName = bp.Sales_Order__r != null ? bp.Sales_Order__r.Name : null;
        }
        return card;
    }

    private static List<BusinessProcessApprovalWrapper.ApprovalDocument> getDocumentsForBusinessProcess(Id businessProcessId) {
        List<BusinessProcessApprovalWrapper.ApprovalDocument> result = new List<BusinessProcessApprovalWrapper.ApprovalDocument>();
        if (businessProcessId == null) {
            return result;
        }

        List<Business_Process_Documents__c> docs = [
            SELECT Id, Name, Review_status__c, Review_Comment__c
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId
            ORDER BY CreatedDate DESC
        ];
        if (docs.isEmpty()) {
            return result;
        }

        Set<Id> docIds = new Map<Id, Business_Process_Documents__c>(docs).keySet();

        Map<Id, ContentDocumentLink> linkByRecordId = new Map<Id, ContentDocumentLink>();
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docIds
        ]) {
            if (!linkByRecordId.containsKey(link.LinkedEntityId)) {
                linkByRecordId.put(link.LinkedEntityId, link);
            }
        }

        for (Business_Process_Documents__c d : docs) {
            BusinessProcessApprovalWrapper.ApprovalDocument doc = new BusinessProcessApprovalWrapper.ApprovalDocument();
            doc.documentId = d.Id;
            doc.documentName = d.Name;
            doc.reviewStatus = d.Review_status__c;
            doc.reviewComment = d.Review_Comment__c;

            ContentDocumentLink link = linkByRecordId.get(d.Id);
            if (link != null) {
                doc.contentDocumentId = link.ContentDocumentId;
                doc.latestContentVersionId = link.ContentDocument.LatestPublishedVersionId;
                doc.hasFile = true;
            } else {
                doc.hasFile = false;
            }
            result.add(doc);
        }
        return result;
    }

    private static String actionLabel(String actionName) {
        if (actionName == ACTION_APPROVE) return 'Approval';
        if (actionName == ACTION_REJECT) return 'Rejection';
        if (actionName == ACTION_MORE_INFO) return 'Request for more information';
        return 'Action';
    }
}