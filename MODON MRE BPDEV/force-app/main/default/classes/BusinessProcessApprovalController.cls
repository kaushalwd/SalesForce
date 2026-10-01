/**
 * @AuraEnabled entry points for the businessProcessApprovalDashboard LWC and its children.
 * Pure passthrough by design — all query/mutation logic and error handling lives in
 * BusinessProcessApprovalService.
 */
public with sharing class BusinessProcessApprovalController {

    @AuraEnabled(cacheable=true)
    public static List<BusinessProcessApprovalWrapper.ApprovalStepCard> getMyApprovalSteps(Integer limitCount, Integer offsetCount) {
        return BusinessProcessApprovalService.getMyApprovalSteps(limitCount, offsetCount);
    }

    @AuraEnabled(cacheable=true)
    public static BusinessProcessApprovalWrapper.ApprovalStepDetail getApprovalDetail(Id stepId) {
        return BusinessProcessApprovalService.getApprovalDetail(stepId);
    }

    @AuraEnabled
    public static BusinessProcessApprovalWrapper.ActionResult submitApprovalAction(
        Id stepId, String actionName, String comments, Id reopenStepId, Id nextStepOwnerId
    ) {
        return BusinessProcessApprovalService.submitApprovalAction(stepId, actionName, comments, reopenStepId, nextStepOwnerId);
    }
}