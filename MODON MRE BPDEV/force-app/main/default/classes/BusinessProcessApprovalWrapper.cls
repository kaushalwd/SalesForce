/**
 * Data transfer objects for the Business Process Approval dashboard (businessProcessApprovalDashboard LWC).
 * Read-only shapes only — all mutations go through the existing LwcApproveRejectBpstepController.
 */
public with sharing class BusinessProcessApprovalWrapper {

    public class ApprovalStepCard {
        @AuraEnabled public Id stepId;
        @AuraEnabled public String stepName;
        @AuraEnabled public String status;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public DateTime assignedDate;
        @AuraEnabled public Boolean isApproveAllowed;
        @AuraEnabled public Boolean isRejectAllowed;
        @AuraEnabled public Boolean isRequireMoreInfoAllowed;
        @AuraEnabled public Boolean isReviewCommentsRequired;
        @AuraEnabled public Boolean isChooseNextOwner;
        @AuraEnabled public Id businessProcessId;
        @AuraEnabled public String businessProcessName;
        @AuraEnabled public String processTypeName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public String currentStepStatus;
    }

    public class ApprovalStepDetail {
        @AuraEnabled public ApprovalStepCard card;
        @AuraEnabled public String remarksComments;
        @AuraEnabled public Decimal sequence;
        @AuraEnabled public String sectionName;
        @AuraEnabled public String department;

        @AuraEnabled public String businessProcessStatus;
        @AuraEnabled public String latestComment;

        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String accountPhone;

        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public String salesOrderStatus;
        @AuraEnabled public String salesOrderSubStatus;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal totalPaidAmount;
        @AuraEnabled public Decimal totalOutstanding;
        @AuraEnabled public Date bookingDate;

        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String unitStatus;
        @AuraEnabled public Decimal unitBasePrice;
        @AuraEnabled public Decimal unitTotalPrice;
        @AuraEnabled public String numberOfBedrooms;

        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;

        @AuraEnabled public Id installmentId;
        @AuraEnabled public String installmentName;
        @AuraEnabled public Decimal installmentAmount;
        @AuraEnabled public Date installmentMilestoneDate;
        @AuraEnabled public String installmentPaymentStatus;

        @AuraEnabled public List<ApprovalDocument> documents;
    }

    public class ApprovalDocument {
        @AuraEnabled public Id documentId;
        @AuraEnabled public String documentName;
        @AuraEnabled public String reviewStatus;
        @AuraEnabled public String reviewComment;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id latestContentVersionId;
        @AuraEnabled public Boolean hasFile;
    }

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id businessProcessId;
    }
}