/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public class BusinessProcessManadatoryDocuments { //nsv
    
    public static void validateMandatoryDocuments(List<SObject> newList, Map<Id, SObject> oldMap){
        System.debug('validateMandatoryDocuments method called');
        
        Set<String> stepNames = new Set<String>();
        Map<Id, Id> businessProcessdByStepId = new Map<Id, Id>();
        
        for(Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            Business_Process_Step__c oldStep = (Business_Process_Step__c) oldMap.get(newStep.Id);
            if (oldStep.Status__c != newStep.Status__c && newStep.Status__c == 'Completed') {
                if (newStep.Business_Process__c != null) {
                    stepNames.add(newStep.Name);
                    businessProcessdByStepId.put(newStep.Id, newStep.Business_Process__c);
                }
            }
        }
        system.debug('businessProcessdByStepId = '+businessProcessdByStepId);
        if ( businessProcessdByStepId.isEmpty() ) return;
        
        
        Set<Id> processFlowIds = new Set<Id>();
        for (Business_Process__c bp : [SELECT Id, Process_Flow__c FROM Business_Process__c WHERE Id IN :businessProcessdByStepId.values() AND Process_Flow__c != null]) {
            processFlowIds.add(bp.Process_Flow__c);
        }  
        System.debug('processFlowIds = '+processFlowIds);
        if (processFlowIds.isEmpty()) return;
        
                
        // Get all mandatory documents for these process flow steps
        Map<String, List<Mandatory_Document__c>> stepNameToMandatoryDocsMap = getMandatoryDocumentsByStepName(stepNames, processFlowIds);
        System.debug('stepNameToMandatoryDocsMap = '+stepNameToMandatoryDocsMap);
        if(stepNameToMandatoryDocsMap.isEmpty()) return;
        
        
        // Get existing documents for these business process steps
        Map<Id, Set<String>> businessProcessIdToExistingDocNamesMap = getExistingDocumentsForSteps(businessProcessdByStepId.keySet(), businessProcessdByStepId.values());
        
        // Validate mandatory documents
        validateDocuments(newList, stepNameToMandatoryDocsMap, businessProcessIdToExistingDocNamesMap, businessProcessdByStepId);
        
    }
    
    private static Map<String, List<Mandatory_Document__c>> getMandatoryDocumentsByStepName(Set<String> stepNames, Set<Id> processFlowIds) {
        System.debug('getMandatoryDocumentsByStepName method called stepNames = '+stepNames + ' processFlowIds = '+processFlowIds);
        Map<String, List<Mandatory_Document__c>> stepNameToDocsMap = new Map<String, List<Mandatory_Document__c>>();
        
        for(Mandatory_Document__c doc :  [
            SELECT Id, Name, Process_Flow_Step__r.Step_Name__c, Process_Flow_Document__r.Name, Process_Flow_Document__r.Process_Flow__c
            FROM Mandatory_Document__c 
            WHERE Process_Flow_Step__r.Step_Name__c IN :stepNames AND Process_Flow_Document__r.Process_Flow__c IN :processFlowIds
        ]) {
            String stepName = doc.Process_Flow_Step__r.Step_Name__c;
            if(!stepNameToDocsMap.containsKey(stepName)) {
                stepNameToDocsMap.put(stepName, new List<Mandatory_Document__c>());
            }
            stepNameToDocsMap.get(stepName).add(doc);
        }
        return stepNameToDocsMap;
    }
    
    private static Map<Id, Set<String>> getExistingDocumentsForSteps(Set<Id> stepIds, List<Id> businessProcessIds) {
        System.debug('getExistingDocumentsForSteps method called');
        Map<Id, Set<String>> businessProcessIdToDocNamesMap = new Map<Id, Set<String>>();        
        for(Business_Process_Documents__c doc : [
            SELECT Id, Name, Business_Process_Step__c, Business_Process__c,(SELECT Id FROM ContentDocumentLinks ORDER BY ContentDocument.CreatedDate DESC Limit 1)
            FROM Business_Process_Documents__c 
            WHERE Business_Process_Step__c IN :stepIds OR Business_Process__c IN: businessProcessIds
        ]) {
            if(doc.ContentDocumentLinks.size() > 0){
                if(!businessProcessIdToDocNamesMap.containsKey(doc.Business_Process__c)) {
                    businessProcessIdToDocNamesMap.put(doc.Business_Process__c, new Set<String>());
                }
                businessProcessIdToDocNamesMap.get(doc.Business_Process__c).add(doc.Name);
            }
        }
        System.debug('businessProcessIdToDocNamesMap = '+businessProcessIdToDocNamesMap);
        return businessProcessIdToDocNamesMap;
    }
     
    private static void validateDocuments(List<Business_Process_Step__c> newSteps, Map<String, List<Mandatory_Document__c>> stepNameToMandatoryDocsMap, Map<Id, Set<String>> businessProcessIdToExistingDocNamesMap, Map<Id, Id> businessProcessdByStepId) {
                                            
        System.debug('validateDocuments method called');
        for(Business_Process_Step__c newStep : newSteps) {            
            
            String stepName = newStep.Name;
            Id stepId = newStep.Id;
            Id bpId = businessProcessdByStepId.get(stepId);
            
            // Check if there are mandatory documents for this step
            if(stepNameToMandatoryDocsMap.containsKey(stepName)) {
                List<Mandatory_Document__c> mandatoryDocs = stepNameToMandatoryDocsMap.get(stepName);
                
                Set<String> existingDocNames = businessProcessIdToExistingDocNamesMap.get(bpId);
                
                if(existingDocNames == null) {
                    existingDocNames = new Set<String>();
                }
                System.debug('existingDocNames = '+existingDocNames);
                
                // Check each mandatory document
                for(Mandatory_Document__c mandatoryDoc : mandatoryDocs) {
                    String requiredDocName = mandatoryDoc.Process_Flow_Document__r.Name;
                    System.debug('requiredDocName = '+requiredDocName);
                    if(!existingDocNames.contains(requiredDocName)) {
                        newStep.addError('Cannot approve step. Missing mandatory document: ' + requiredDocName);
                        break; 
                    }
                }
            }
        }
    }

}