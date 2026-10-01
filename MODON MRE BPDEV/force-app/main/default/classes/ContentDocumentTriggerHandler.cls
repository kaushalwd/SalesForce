/**********************************************************************************************************************
* Name               : ContentDocumentTriggerHandler                                                        
* Description        : Handler class for ContentDocumentTrigger
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 19 Aug 2026     Initial Draft     
* 2.0           Tiyyab Ahmed                22 Sep 2026     Added logic to gaurd deletion on Receipt__c object
******************************************************************************************************************/
public without sharing class ContentDocumentTriggerHandler extends TriggerHandler { 
    
    //*** Before Delete Action ***//
    public override void beforeDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap) {
        String meetingPrefix = Sales_Executive_Meeting__c.SObjectType.getDescribe().getKeyPrefix();
        
        List<ContentDocumentLink> meetingCdls = new List<ContentDocumentLink>();
        Set<Id> blockedDocIds = new Set<Id>();
        Boolean userCanDelete = ProofOfPaymentDeleteGuard.canDelete();
        
        Set<Id> docIds = new Set<Id>();
        for (ContentDocument cd : (List<ContentDocument>) oldList) {
            docIds.add(cd.Id);
        }
        
        //2.0
        // Single query serves both the meeting file count and the guard.
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docIds
        ]) {
            if (cdl.LinkedEntityId == null) {
                continue;
            }
            
            if (!userCanDelete && ProofOfPaymentDeleteGuard.isProtected(cdl.LinkedEntityId)) {
                blockedDocIds.add(cdl.ContentDocumentId);
            }
            
            if (String.valueOf(cdl.LinkedEntityId).startsWith(meetingPrefix)) {
                meetingCdls.add(cdl);
            }
        }
        
        //2.0
        // A blocked document is not actually going to be deleted, so its meeting
        // file count must not be decremented. Without this, a partial-success
        // delete (allOrNone = false) leaves the count wrong.
        if (!blockedDocIds.isEmpty() && !meetingCdls.isEmpty()) {
            List<ContentDocumentLink> survivingCdls = new List<ContentDocumentLink>();
            for (ContentDocumentLink cdl : meetingCdls) {
                if (!blockedDocIds.contains(cdl.ContentDocumentId)) {
                    survivingCdls.add(cdl);
                }
            }
            meetingCdls = survivingCdls;
        }
        
        if (!meetingCdls.isEmpty()) {
            ContentDocumentLinkTriggerHelper.updateSalesExecutiveMeetingFileCount(meetingCdls);
        }
        
        if (!blockedDocIds.isEmpty()) {
            for (ContentDocument cd : (List<ContentDocument>) oldList) {
                if (blockedDocIds.contains(cd.Id)) {
                    cd.addError(ProofOfPaymentDeleteGuard.ERROR_MESSAGE);
                }
            }
        }
    }
}