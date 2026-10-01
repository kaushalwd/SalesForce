/**********************************************************************************************************************
* Name               : DocuSignEnvelopeStatusTriggerHandler                                                        
* Description        : This class is used as a handler for DocuSign Status trigger
* Usage              : Called from DocuSignStatusTriggerHandler
* Created By         : Aphidas Solutions                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version          Author                          Date            Comment                                                                       
* 1.0          arbaz@aphidas.com                30 Oct 2024     Initial Draft       
* 2.0          (assistant)                      04 Sep 2026     Uncommented the updateSRDocuSignStatus() call — that
*                                                                method now exists in the helper. Nothing else changed.
******************************************************************************************************************/
public class DocuSignEnvelopeStatusTriggerHandler extends TriggerHandler
{
    //*** Before Insert Action ***//
    //public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    //}
    //*** Before Update Action ***//
    //public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    //}
    //*** After Delete Action ***//
    //public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
    //}
    //*** After Insert Action ***//
    /*public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        DocuSignEnvelopeStatusTriggerHelper.nullifyDocumentEnvelopeId(newList,null);
    }*/
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        DocuSignEnvelopeStatusTriggerHelper.nullifyDocumentEnvelopeId(newList,oldMap);
        DocuSignEnvelopeStatusTriggerHelper.updateOfferRecordApproved(newList,oldMap);
        DocuSignEnvelopeStatusTriggerHelper.markLatestUnifiedFileSignedForSR(newList, oldMap); // NEW
        DocuSignEnvelopeStatusTriggerHelper.updateSOSPAStatus(newList,oldMap);
        
         MBP_DocusignController.updateAccountDocuSignStatus(newList, oldMap);
        MBP_DocusignController.updateSRDocuSignStatus(newList, oldMap);
    }
    
}