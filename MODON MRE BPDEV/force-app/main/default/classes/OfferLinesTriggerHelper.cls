public without sharing class OfferLinesTriggerHelper {
    public static void lockApprovalRecord(List<SObject> offerLinesList,Map<Id, SObject> oldMap){
        String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
        List<String> approverEmailList = System.label.ApprovalOfferLineModifyBy.contains(',') ? System.label.ApprovalOfferLineModifyBy.split(','): new List<String>{System.label.ApprovalOfferLineModifyBy};
        for (OfferLines__c newRec : (List<OfferLines__c>) offerLinesList) {
            OfferLines__c oldRec = (OfferLines__c) oldMap.get(newRec.Id);
            // Check if the record is in a locked state
            if (oldRec.Offer_Line_Approval_Status__c != 'Not Submitted' && !approverEmailList.contains(currentUserEmail)) {
                // Prevent any edits
                if (!newRec.equals(oldRec)) {
                    newRec.addError('This record cannot be edited once submitted.');
                }
            }
        }
    }
    public static void validateuniqueOffers(List<SObject> offerLinesList,Map<Id, SObject> oldMap){
        Set<String> uniqueKeys = new Set<String>();
        Map<String, OfferLines__c> keyToOfferMap = new Map<String, OfferLines__c>();
        Set<Id> projectId = new Set<Id>();
        Set<Id> offerLineIds = new Set<Id>();
        Map<Id,OfferLines__c> keyRecord = new Map<Id,OfferLines__c>();
        Map<Id,String> errorMap = new map<Id,String>();
        Map<Id,String> existingKeyMap = new Map<Id,String>(); 
        List<String> getFieldSetFields = getFieldSetFields('OfferLines__c','OfferLinesFieldSet');
        /*** Trigger Only the specific field Change*****/
        for(OfferLines__c ol : (List<OfferLines__c>)offerLinesList){
            for(String s: getFieldSetFields){
                offerLineIds.add(ol.Id);
                if(oldMap == null || (oldMap <> null && (oldMap.get(ol.Id).get(s) != ol.get(s)))){
                    keyRecord.put(ol.Id,ol);
                }
            }
        } 
        for (OfferLines__c ol : (List<OfferLines__c>)offerLinesList) {
            String key = generateKey(ol,getFieldSetFields);
            if(!keyToOfferMap.containsKey(key)){
                uniqueKeys.add(key);
                keyToOfferMap.put(key, ol);
                projectId.add(ol.ProjectID__c);
                errorMap.put(ol.Id,key);
            }
        }
        system.debug('uniqueKeys:'+uniqueKeys);
        // Step 2: Query existing records with matching field combinations
        List<OfferLines__c> existingOffers = [
            SELECT Id,project__c,OfferName__r.Project__c,ProjectID__c ,OfferName__c, Unit_Price_From__c,Customer_Specific__c,CustomerType__c,Nationality__c,ResidentStatus__c, Unit_Price_To__c, OfferOn__c, OfferType__c,
            OfferValue__c, Unit__c, Phase__c
            FROM OfferLines__c
            WHERE (OfferName__r.Project__c IN: projectId)
        ];
        system.debug('offerLineIds:'+offerLineIds);
        // Step 3: Generate keys for existing and compare
        Set<String> existingKeys = new Set<String>();
        for (OfferLines__c existing : existingOffers) {
            if(!offerLineIds.contains(existing.Id)){
                existingKeys.add(generateKey(existing,getFieldSetFields));
            }
        }
        system.debug('existingKeys:'+existingKeys);
        
        
        for(OfferLines__c offer:(List<OfferLines__c>)offerLinesList){
            // Step 4: Check for duplicates
            for (String key : existingKeys) {
                if (errorMap.containsKey(offer.Id) && errorMap.get(offer.Id) == key) {
                    system.debug('Existing Key=='+key+' == Current Key== '+errorMap.get(offer.Id));
                    offer.addError('Duplicate offer combination already exists.');
                }
            } 
        }
    }
    
    private static String generateKey(OfferLines__c ol,List<String> getFieldSetFields) {
        String uniqueKey = '';
        for(String s: getFieldSetFields){
            uniqueKey += string.valueOf(ol.get(s))+ ':';
        }
        return uniqueKey;
    }
    
    public static List<String> getFieldSetFields(String objectName, String fieldSetName) {
        List<String> fieldNames = new List<String>();
        
        // Use Schema to get the SObjectType
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        
        if (sObjectType != null) {
            Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
            Map<String, Schema.FieldSet> fieldSetMap = describeResult.fieldSets.getMap();
            
            if (fieldSetMap.containsKey(fieldSetName)) {
                Schema.FieldSet fieldSet = fieldSetMap.get(fieldSetName);
                List<Schema.FieldSetMember> fields = fieldSet.getFields();
                
                for (Schema.FieldSetMember f : fields) {
                    fieldNames.add(f.getFieldPath());
                }
            }
        }
        
        return fieldNames;
    }
    
}