/**********************************************************************************************************************
* Name               : DocumentTriggerHelper                                                        
* Description        : This class is helper for Document trigger handler
* Usage              : Called from DocumentTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         09 May 2024     Initial Draft       
* 2.0           Shahil Sinha                     25 Feb 2026     Added check to bypass Modon Egypt docs
* 3.0           Arvind Kesharwani                20 May 2026     Auto generate document and send DocuSign on insert
* 4.0           Rushi Patel                      01 Sep 2026     Added autoSendDocuSign method to publish Platform Event
******************************************************************************************************************/
public without sharing class DocumentTriggerHelper {

    public static void updateSalesOrder(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        Map<Id,Id> signedSPAMap = new Map<Id,Id>();
        Map<String, set<String>> salesOrderStringMap = new Map<String, set<String>>();
        set<String> salesOrderSet = new set<String>();
        Set<Id> salesOrderCheckReservationForm = new Set<Id>();
        Set<Id> salesOrderCheckBrokerForm = new Set<Id>();
        Set<Id> checkSPAStatusIdset = new Set<Id>();
        for(String key : newMap.keySet()){
            Documents__c docObjNew = (Documents__c)newMap.get(key);
            Documents__c docObjOld = (Documents__c)oldMap.get(key);

            //v2.0 - Bypassing the modon egypt documents
            if (ModonEgyptConstants.EGYPT_DOC_TO_BYPASS.contains(docObjNew.Name)) {
                continue;
            }

            if(docObjNew.Status__c != docObjOld.Status__c && (docObjNew.Status__c == 'Uploaded' || docObjNew.Status__c == 'Pending Upload') && docObjNew.Name.contains('SPA') && String.isNotBlank(docObjNew.SalesOrder__c)){
                checkSPAStatusIdset.add(docObjNew.SalesOrder__c);
            }
            if(docObjNew.Status__c != docObjOld.Status__c && (docObjNew.Status__c == 'Uploaded' || docObjNew.Status__c == 'Pending Upload') && docObjNew.Name.contains('Signed') && String.isNotBlank(docObjNew.SalesOrder__c)){
                salesOrderSet.add(docObjNew.SalesOrder__c);
            }
            if(docObjNew.Status__c != docObjOld.Status__c && (docObjNew.Status__c == 'Uploaded') && String.isNotBlank(docObjNew.SalesOrder__c) && docObjNew.Name.contains('Reservation')){
                salesOrderCheckReservationForm.add(docObjNew.SalesOrder__c);
            }
            if(docObjNew.Status__c != docObjOld.Status__c && (docObjNew.Status__c == 'Uploaded') && String.isNotBlank(docObjNew.SalesOrder__c) && docObjNew.Name.contains('Broker')){
                salesOrderCheckBrokerForm.add(docObjNew.SalesOrder__c);
            }
        }

        if(!salesOrderSet.isEmpty()){
            List<SalesOrder__c> soLst = [SELECT Id, (SELECT Id, Name FROM Documents__r WHERE (Name LIKE 'Signed %' OR Name =:System.label.PublicURLSPADocName) AND Status__c = 'Uploaded') FROM SalesOrder__c WHERE Id IN : salesOrderSet];
            if(!soLst.isEmpty()){
                List<SalesOrder__c> soUpdateLst = new List<SalesOrder__c>();
                for(SalesOrder__c soObj : soLst){
                    if(!soObj.Documents__r.isEmpty()){
                        set<string> docString = new set<String>();
                        for(Documents__c docObj : soObj.Documents__r){
                            docString.add(docObj.Name.remove('Signed '));
                            if(docObj.Name == System.label.PublicURLSPADocName){
                                signedSPAMap.put(docObj.Id,soObj.Id);
                            }
                        }
                        soUpdateLst.add(new SalesOrder__c(Id = soObj.Id, SignedDocuments__c = String.join(new List<String>(docString),';')));
                    }
                }
                system.debug('soUpdateLst==>' + soUpdateLst);
                try{
                    UPDATE soUpdateLst;
                }catch(Exception ex){
                    system.debug(ex.getMessage());
                }
            }
        }
        if(!signedSPAMap.keySet().isEmpty()){
            Map<Id,String> generatePublicLink = ContentPublicURLHelper.generatePublicLink(signedSPAMap.keySet());
            system.debug('generatePublicLink:'+generatePublicLink);
            List<SalesOrder__c> soList = new List<SalesOrder__c>();
            for(Id idVal: generatePublicLink.keySet()){
                SalesOrder__c so = new SalesOrder__c();
                so.Id = signedSPAMap.get(idVal);
                so.SPAPublicUrl__c = generatePublicLink.get(idVal);
                soList.add(so);
            }
            if(!soList.isEmpty()){
                update soList;
            }
        }
        if(!salesOrderCheckReservationForm.isEmpty()){
            SalesOrderStatusAutomationHelper.checkReservationForm(salesOrderCheckReservationForm);
        }
        if(!checkSPAStatusIdset.isEmpty()){
            SalesOrderStatusAutomationHelper.checkSPAStatus(checkSPAStatusIdset);
        }
        if(!salesOrderCheckBrokerForm.isEmpty()){
            SalesOrderStatusAutomationHelper.checkBrokerForm(salesOrderCheckBrokerForm);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // v3.0 — Auto generate document and send DocuSign on insert
    // ─────────────────────────────────────────────────────────────
      public static void autoGenerateAndSendDocument(List<SObject> newList) {

        Set<Id> eligibleDocIds = new Set<Id>();

        for (SObject sObj : newList) {
            Documents__c doc = (Documents__c) sObj;
            if (doc.Auto_Generate_Document__c == true
                && String.isNotBlank(doc.Name)) {
                eligibleDocIds.add(doc.Id);
            }
        }

        if (!eligibleDocIds.isEmpty()) {
            // No sessionId needed — DrawloopHelper handles auth internally
            // Same approach as BusinessProcessNintexDocumentGeneration
            DocumentAutoGenerateService.generateAndSend(eligibleDocIds);
        }
          }
    /**********************************************************************************************************************
    * @Description  : Method to publish a Platform Event for automated DocuSign sending when a document is Generated.
    *                 Decouples the API callout from the restricted triggering user context (Broker/Community).
    * @Author       : Rushi Patel
    * @Date         : 01 Sep 2026
    **********************************************************************************************************************/
    public static void autoSendDocuSign(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        Set<Id> docsToProcess = new Set<Id>();
        for (Id docId : newMap.keySet()) {
            Documents__c doc = (Documents__c) newMap.get(docId);
            Documents__c oldDoc = (Documents__c) oldMap.get(docId);
            // Fire when Document Status changes to Generated and Auto Send is checked
            if (doc.Auto_Send_DocuSign_Email__c == true
                && doc.Document_Status__c == 'Generated' 
                && oldDoc.Document_Status__c != 'Generated'
                && String.isBlank(doc.EnvelopID__c)) {
                docsToProcess.add(doc.Id);
            }
        }
        
        if (!docsToProcess.isEmpty()) {
            List<DocuSign_Send_Request__e> events = new List<DocuSign_Send_Request__e>();
            for (Id docId : docsToProcess) {
                events.add(new DocuSign_Send_Request__e(Document_Id__c = docId));
            }
            // Added by Rushi Patel: Publish Platform Event to decouple the DocuSign API callout context from the triggering user
            // This prevents INVALID_SESSION_ID errors when restricted Broker users trigger the process
            EventBus.publish(events);
        }
    }
}