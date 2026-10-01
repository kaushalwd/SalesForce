/**********************************************************************************************************************
* Name               : ContentDocumentLink                                                        
* Description        : This class is used to handle all the Service Request SPA Transfer
* Created By         : Active Minds                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Chaitanya         				13 Nov 2025     	Initial Draft       
******************************************************************************************************************/
trigger CDL_SROffPlanLinker on ContentDocumentLink (after insert) {
    // Filter only those links whose parent is a ServiceRequest__c
    String srPrefix = ServiceRequest__c.SObjectType.getDescribe().getKeyPrefix();

    List<ContentDocumentLink> srLinks = new List<ContentDocumentLink>();
    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId != null &&
            String.valueOf(cdl.LinkedEntityId).startsWith(srPrefix)) {
            srLinks.add(cdl);
        }
    }

    if (!srLinks.isEmpty()) {
        CDL_SignedSPAFileLinker.runForCDL(srLinks);
    }
}