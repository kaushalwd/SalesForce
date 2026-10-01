/**********************************************************************************************************************
* Name               : ContentDocumentLinkTriggerHandler                                                        
* Description        : This class is used as a handler for content document link trigger
* Usage              : Called from ContentDocumentLinkTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         10 Jan 2024     Initial Draft       
* 1.1			arvind.kesharwani@modon.com		 13 May 2026		Commented line no 28
* 1.2           Sireesha						 24-May-2026     Added method related comertial plots documents
* 1.3           Rushi Patel                      18 Aug 2026     Added logic for Sales Executive Meeting File Count
* 2.0           Tiyyab Ahmed                     22 Sep 2026     Added logic to gaurd deletion on Receipt__c object
******************************************************************************************************************/
public without sharing class ContentDocumentLinkTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }

    //*** After Insert Action***//
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        ContentDocumentLinkTriggerHelper.updateDocumentStatus(newList);
        ContentDocumentLinkTriggerHelper.updateSignedDocuments(newList);
        ContentDocumentLinkTriggerHelper.reParentSODocs(newList);
        ContentDocumentLinkTriggerHelper.moveToSignedForms(newList);
        ContentDocumentLinkTriggerHelper.moveSignedSpaToDocuments(newList);
        ContentDocumentLinkTriggerHelper.updateSalesOrderStatusToSpaGenerated(newList);
      //  ContentDocumentLinkTriggerHelper.updateSalesOrderStatusToSpaGenerated2(newList);// Arvind Commnted Legacy code Functionality moved to SPA STatus

            ContentDocumentLinkTriggerHelper.handleSRSPADocuments(Trigger.new);
        //added by v1.2
        ContentDocumentLinkTriggerHelper.handleNOCAdherenceNovationDocuments(Trigger.new);
        
        ContentDocumentLinkTriggerHelper.captureKYCFileIdOnAccount(newList);
       ContentDocumentLinkTriggerHelper.moveManualKYCFormToSigned(newList);




        //ContentDocumentLinkTriggerHelper.uploadDocumentCheckName(newList);
        //ContentDocumentLinkTriggerHelper.serviceRequestUpdate(newList);
        // Added by Rushi Patel on 18 Aug 2026: Calculate file count for Sales_Executive_Meeting__c
        ContentDocumentLinkTriggerHelper.updateSalesExecutiveMeetingFileCount(newList);
    }
    
    //*** After Update Action***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }

    //*** Before Delete Action***//
    public override void beforeDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){ 
        //2.0
        //ProofOfPaymentDeleteGuard.blockLinkDeletes((List<ContentDocumentLink>) oldList);
    }
    
    //*** After Delete Action***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        // Added by Rushi Patel on 18 Aug 2026: Calculate file count for Sales_Executive_Meeting__c
        ContentDocumentLinkTriggerHelper.updateSalesExecutiveMeetingFileCount(oldList);
    }
    
}