/**
* Name               : ProofOfPaymentDeleteGuard                                                        
* Description        : See below
* Created By         : Tiyyab Ahmed
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Tiyyab Ahmed                15 Sep 2026     Initial Draft      

 *
 * Blocks deletion and unlinking of files attached to receipt / payment records.
 * Uploading NEW files is unaffected - only destructive actions are blocked.
 *
 * Bypass is granted through the custom permission below, not through profiles,
 * so the permitted user list lives in a permission set and stays auditable in
 * the access matrix.
 *
 * Called from ContentDocumentTriggerHandler.beforeDeleteMethod and
 * ContentDocumentLinkTriggerHandler.beforeDeleteMethod.
 *
 * NOTE: addError() blocks every user including System Administrators and users
 * with Modify All Data. That is intentional.
 * 
 * 
 */
public without sharing class ProofOfPaymentDeleteGuard {

    /** Custom permission that grants the bypass. */
    @TestVisible
    private static final String DELETE_PERMISSION = 'Delete_Proof_of_Payment';

    public static final String ERROR_MESSAGE =
        'Documents cannot be deleted or removed from this record. ' +
        'Upload an additional document instead. If deletion is genuinely required, ' +
        'raise a request for ED approval.';

    /**
     * API names of the objects whose attached files are protected.
     */
    @TestVisible
    private static Set<String> protectedObjects = new Set<String>{
        'Receipt__c'
    };

    /** Key prefixes for the objects above, matching your existing prefix style. */
    private static Set<String> protectedPrefixes {
        get {
            if (protectedPrefixes == null) {
                protectedPrefixes = new Set<String>();
                Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
                for (String objName : protectedObjects) {
                    Schema.SObjectType sot = globalDescribe.get(objName);
                    if (sot != null) {
                        String prefix = sot.getDescribe().getKeyPrefix();
                        if (String.isNotBlank(prefix)) {
                            protectedPrefixes.add(prefix);
                        }
                    }
                }
            }
            return protectedPrefixes;
        }
        set;
    }

    /** Test hook - lets the test class simulate a permitted user. */
    @TestVisible
    private static Boolean overrideCanDelete = null;

    public static Boolean canDelete() {
        if (Test.isRunningTest() && overrideCanDelete != null) {
            return overrideCanDelete;
        }
        return FeatureManagement.checkPermission(DELETE_PERMISSION);
    }

    /** True if files linked to this record are protected from deletion. */
    public static Boolean isProtected(Id recordId) {
        if (recordId == null) {
            return false;
        }
        return protectedPrefixes.contains(String.valueOf(recordId).substring(0, 3));
    }

    /**
     * Blocks the "Remove" action, which deletes the link rather than the file.
     * To an end user this is indistinguishable from deleting the document, so it
     * has to be blocked separately.
     */
    public static void blockLinkDeletes(List<ContentDocumentLink> links) {
        if (links == null || links.isEmpty() || canDelete()) {
            return;
        }
        for (ContentDocumentLink link : links) {
            if (isProtected(link.LinkedEntityId)) {
                link.addError(ERROR_MESSAGE);
            }
        }
    }

}