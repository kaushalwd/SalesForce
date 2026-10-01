/**********************************************************************************************************************
* Name               : SORelationshipTriggerHelper                                                        
* Description        : This class is helper for SORelationshipTrigger
* Usage              : Called from SORelationshipTriggerHandler
* Created By         : Modon IT                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Modon IT          					7 Aug 2026     Initial Draft   
*****************************************************************************************************/
public without sharing class SORelationshipTriggerHelper {
    
    public static void createDocumentRecords(List<SObject> newList){
        
        List<Documents__c> lstDocumentsCurrent = new List<Documents__c>();
        List<Documents__c> lstDocumentsToInsert = new List<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('SalesOrderRelationship__c');
        if(!lstDocumentsCurrent.isEmpty()){            
            for(SalesOrderRelationship__c sor : (List<SalesOrderRelationship__c>) newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Sales_Order_Relationship__c = sor.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }

    public static void validateDuplicateRelationship(List<SObject> newList){
        Set<Id> salesOrderIds = new Set<Id>();
        Set<Id> thirdPartyCustomerIds = new Set<Id>();
        for(SalesOrderRelationship__c sor : (List<SalesOrderRelationship__c>) newList){
            if(sor.SalesOrder__c != null && sor.ThridPartyCustomer__c != null){
                salesOrderIds.add(sor.SalesOrder__c);
                thirdPartyCustomerIds.add(sor.ThridPartyCustomer__c);
            }
        }

        if(salesOrderIds.isEmpty()){
            return;
        }

        Set<String> existingKeys = new Set<String>();
        for(SalesOrderRelationship__c existingSor : [
            SELECT SalesOrder__c, ThridPartyCustomer__c
            FROM SalesOrderRelationship__c
            WHERE SalesOrder__c IN :salesOrderIds
            AND ThridPartyCustomer__c IN :thirdPartyCustomerIds
        ]){
            existingKeys.add(existingSor.SalesOrder__c + '_' + existingSor.ThridPartyCustomer__c);
        }

        Set<String> keysInBatch = new Set<String>();
        for(SalesOrderRelationship__c sor : (List<SalesOrderRelationship__c>) newList){
            if(sor.SalesOrder__c == null || sor.ThridPartyCustomer__c == null){
                continue;
            }
            String relationshipKey = sor.SalesOrder__c + '_' + sor.ThridPartyCustomer__c;
            if(existingKeys.contains(relationshipKey) || !keysInBatch.add(relationshipKey)){
                sor.addError('Already Relationship established for Selected Customer and Unit');
            }
        }
    }

    public static void validateNOCLetterDocument(List<SObject> newList, Map<Id, SObject> oldMap){
        List<SalesOrderRelationship__c> sorsBeingSigned = new List<SalesOrderRelationship__c>();
        Set<Id> sorIds = new Set<Id>();
        for(SalesOrderRelationship__c sor : (List<SalesOrderRelationship__c>) newList){
            SalesOrderRelationship__c oldSor = (oldMap == null) ? null : (SalesOrderRelationship__c) oldMap.get(sor.Id);
            Boolean isNewlySigned = sor.NOCStatus__c == 'Signed'
                && (oldSor == null || oldSor.NOCStatus__c != 'Signed');
            if(isNewlySigned){
                sorsBeingSigned.add(sor);
                sorIds.add(sor.Id);
            }
        }

        if(sorsBeingSigned.isEmpty()){
            return;
        }

        Map<Id, Documents__c> nocDocBySORId = new Map<Id, Documents__c>();
        for(Documents__c doc : [SELECT Id, Status__c, Sales_Order_Relationship__c
                                 FROM Documents__c
                                 WHERE Sales_Order_Relationship__c IN :sorIds
                                 AND Name = 'NOC Letter']){
            nocDocBySORId.put(doc.Sales_Order_Relationship__c, doc);
        }

        for(SalesOrderRelationship__c sor : sorsBeingSigned){
            Documents__c nocDoc = nocDocBySORId.get(sor.Id);
            if(nocDoc == null || nocDoc.Status__c != 'Uploaded'){
                sor.addError('NOC Letter document with an attachment is required before updating to Signed.');
            }
        }
    }

    public static void createCustomerRelationshipCallout(List<SObject> newList, Map<Id, SObject> oldMap){
        Set<Id> candidateSorIds = new Set<Id>();
        for(SalesOrderRelationship__c sor : (List<SalesOrderRelationship__c>) newList){
            SalesOrderRelationship__c oldSor = (oldMap == null) ? null : (SalesOrderRelationship__c) oldMap.get(sor.Id);
            Boolean isNewlySigned = sor.NOCStatus__c == 'Signed'
                && (oldSor == null || oldSor.NOCStatus__c != 'Signed');
            if(isNewlySigned){
                candidateSorIds.add(sor.Id);
            }
        }

        if(candidateSorIds.isEmpty()){
            return;
        }

        Map<Id, SalesOrderRelationship__c> candidateSors = new Map<Id, SalesOrderRelationship__c>([
            SELECT Id, ThridPartyCustomer__c, SalesOrder__r.CustomerAccount__c
            FROM SalesOrderRelationship__c
            WHERE Id IN :candidateSorIds
        ]);

        Set<Id> thirdPartyCustomerIds = new Set<Id>();
        Set<Id> customerAccountIds = new Set<Id>();
        for(SalesOrderRelationship__c sor : candidateSors.values()){
            if(sor.ThridPartyCustomer__c != null){
                thirdPartyCustomerIds.add(sor.ThridPartyCustomer__c);
            }
            if(sor.SalesOrder__r.CustomerAccount__c != null){
                customerAccountIds.add(sor.SalesOrder__r.CustomerAccount__c);
            }
        }

        Map<String, SalesOrderRelationship__c> syncedRelationshipByKey = new Map<String, SalesOrderRelationship__c>();
        for(SalesOrderRelationship__c existingSor : [
            SELECT Id, ThridPartyCustomer__c, SalesOrder__r.CustomerAccount__c,
                   RelationshipSyncStatus__c, RelationshipOracleId__c
            FROM SalesOrderRelationship__c
            WHERE RelationshipSyncStatus__c = 'S'
            AND RelationshipOracleId__c != null
            AND ThridPartyCustomer__c IN :thirdPartyCustomerIds
            AND SalesOrder__r.CustomerAccount__c IN :customerAccountIds
            AND Id NOT IN :candidateSorIds
        ]){
            String relationshipKey = existingSor.ThridPartyCustomer__c + '_' + existingSor.SalesOrder__r.CustomerAccount__c;
            if(!syncedRelationshipByKey.containsKey(relationshipKey)){
                syncedRelationshipByKey.put(relationshipKey, existingSor);
            }
        }

        Set<Id> sorIdsToSync = new Set<Id>();
        List<SalesOrderRelationship__c> sorsToMarkSynced = new List<SalesOrderRelationship__c>();
        for(Id sorId : candidateSorIds){
            SalesOrderRelationship__c sor = candidateSors.get(sorId);
            String relationshipKey = sor.ThridPartyCustomer__c + '_' + sor.SalesOrder__r.CustomerAccount__c;
            SalesOrderRelationship__c syncedSor = syncedRelationshipByKey.get(relationshipKey);
            if(syncedSor == null){
                sorIdsToSync.add(sorId);
            } else {
                // Relationship already synced with Oracle for this ThridPartyCustomer/CustomerAccount pair.
                // Copy the existing sync details onto the current record so it is excluded from the callout.
                sorsToMarkSynced.add(new SalesOrderRelationship__c(
                    Id = sorId,
                    RelationshipSyncStatus__c = syncedSor.RelationshipSyncStatus__c,
                    RelationshipOracleId__c = syncedSor.RelationshipOracleId__c
                ));
            }
        }

        if(!sorsToMarkSynced.isEmpty()){
            update sorsToMarkSynced;
        }

        if(!sorIdsToSync.isEmpty()){
            System.enqueueJob(new SORelationshipCallout_Queable(sorIdsToSync));
        }
    }
}