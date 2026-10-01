/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public without sharing class ApprovalDynamicFieldController {

        public class DocumentWrapper {
        @AuraEnabled public Id docId;
        @AuraEnabled public String docName;
        @AuraEnabled public String fileName;
        @AuraEnabled public Id contentDocumentId;
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentWrapper> getStepDocuments(String stepId){

        List<Business_Process_Documents__c> docs = [
            SELECT Id, Name, Process_Flow_Document__r.isAutoGen__c
            FROM Business_Process_Documents__c
            WHERE Business_Process_Step__c = :stepId
            AND Process_Flow_Document__r.isAutoGen__c=false
            order by Process_Flow_Document__r.Sequence__c ASC
        ];
        set<Id> docIds=new Set<Id>();
        for(Business_Process_Documents__c doc:docs){
             docIds.add(doc.Id);
        }

        Map<Id, ContentDocumentLink> fileMap = new Map<Id, ContentDocumentLink>();

        for(ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId,
                   ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docIds
        ]){
            fileMap.put(cdl.LinkedEntityId, cdl);
        }

        List<DocumentWrapper> result = new List<DocumentWrapper>();

        for(Business_Process_Documents__c d : docs){

            DocumentWrapper w = new DocumentWrapper();
            w.docId = d.Id;
            w.docName = d.Name;

            if(fileMap.containsKey(d.Id)){
                w.fileName = fileMap.get(d.Id).ContentDocument.Title;
                w.contentDocumentId = fileMap.get(d.Id).ContentDocumentId;
            }

            result.add(w);
        }

        return result;
    }

    /* @AuraEnabled(cacheable=true)
    public static List<Business_Process_Documents__c> getStepDocuments(String stepId){

        return [
            SELECT Id, Name
            FROM Business_Process_Documents__c 
            WHERE Business_Process_Step__c =:stepId
            ORDER BY Name
        ];

    }*/


    // Get dynamic fields for a step
   /* @AuraEnabled(cacheable=true)
    public static  getFields(String stepName, Id recordId){
        return [
            SELECT Field_Label__c,
                   Field_API_Name__c,
                   Field_Type__c,
                   Required__c,
                   Picklist_Values__c,
                   Object_API_Name__c
            FROM Approval_Dynamic_Field__mdt
            WHERE Step_Name__c = :stepName
            ORDER BY Order__c
        ];
    }*/

    @AuraEnabled(cacheable=true)
public static Map<String, Object> getFields(String stepName, Id recordId) {

    // 1. Get metadata fields
    List<Approval_Dynamic_Field__mdt> metaFields = [
        SELECT Field_Label__c,
               Field_API_Name__c,
               Field_Type__c,
               Required__c,
               Picklist_Values__c,
               Object_API_Name__c
        FROM Approval_Dynamic_Field__mdt
        WHERE Step_Name__c = :stepName
        ORDER BY Order__c
    ];

    Map<String, Object> response = new Map<String, Object>();
    response.put('fields', metaFields);

    // 2. If no recordId → return only metadata
    if (recordId == null || metaFields.isEmpty()) {
        response.put('values', new Map<String, Object>());
        return response;
    }

    // 3. Get object name (assuming same for all fields)
    String objectName = metaFields[0].Object_API_Name__c;

    // 4. Collect only required field API names
    List<String> fieldApis = new List<String>();
    for (Approval_Dynamic_Field__mdt f : metaFields) {
        fieldApis.add(f.Field_API_Name__c);
    }

    // 5. Dynamic query ONLY required fields
    String query = 'SELECT ' + String.join(fieldApis, ',') +
                   ' FROM ' + objectName +
                   ' WHERE Id = :recordId LIMIT 1';

    SObject rec = Database.query(query);

    // 6. Return only populated values
    response.put('values', rec.getPopulatedFieldsAsMap());

    return response;
}

    // Submit approval and update fields dynamically
    public static void submitApproval(LwcApproveRejectBpstepController.FormWrapper wrapper){

        if(wrapper.fieldValues == null || wrapper.fieldValues.isEmpty()){
            return;
        }

        // Build field meta dynamically (internal only)
        Map<String, FieldWrapper> fieldMeta = getFieldMetaByStep(wrapper.stepName);

        // Query Business_Process__c and related Booking__c if exists
        Business_Process__c bp = [
            SELECT Id /*Booking__c*/
            FROM Business_Process__c
            WHERE Id = :wrapper.recordId
            LIMIT 1
        ];
        /*
        Booking__c bookingRecord;
        if(bp.Booking__c != null){
            bookingRecord = [SELECT Id FROM Booking__c WHERE Id = :bp.Booking__c LIMIT 1];
        }
        */

        Boolean bpChanged = false;
        Boolean bookingChanged = false;

        // Loop through fieldValues and update respective records
        for(String fieldApi : wrapper.fieldValues.keySet()){
            if(fieldMeta.containsKey(fieldApi)){
                FieldWrapper fw = fieldMeta.get(fieldApi);
                /*
                if(fw.objectName == 'Booking__c' && bookingRecord != null){
                    bookingRecord.put(fieldApi, wrapper.fieldValues.get(fieldApi));
                    bookingChanged = true;
                }
                */
                
                  Object value = wrapper.fieldValues.get(fieldApi);

     
        if(value != null){
            if(fw.fieldType == 'date'){
                value = Date.valueOf((String)value);
            } else if(fw.fieldType == 'number'){
                value = Decimal.valueOf((String)value);
            } else if(fw.fieldType == 'checkbox'){
                value = (Boolean)value;
            }
     
        }

                if(fw.objectName == 'Business_Process__c'){
                    bp.put(fieldApi, value);
                    bpChanged = true;
                }
            }
        }

       // if(bookingChanged) update bookingRecord;
        if(bpChanged) update bp;
    }

    // Internal helper to build field meta from Custom Metadata
    private static Map<String, FieldWrapper> getFieldMetaByStep(String stepName) {

        Map<String, FieldWrapper> metaMap = new Map<String, FieldWrapper>();

        List<Approval_Dynamic_Field__mdt> mappings = [
            SELECT Object_API_Name__c, Field_API_Name__c, Field_Type__c
            FROM Approval_Dynamic_Field__mdt
            WHERE Step_Name__c = :stepName
        ];

        for(Approval_Dynamic_Field__mdt m : mappings){
            metaMap.put(m.Field_API_Name__c, new FieldWrapper(m.Object_API_Name__c, m.Field_API_Name__c, m.Field_Type__c));
        }

        return metaMap;
    }

    // Wrapper to receive data from LWC
    public class FormWrapper{
        @AuraEnabled public Id recordId;
        @AuraEnabled public String stepName; 
        @AuraEnabled public Id stepId;
        @AuraEnabled public String action;
        @AuraEnabled public String comment;

        @AuraEnabled public Map<String,String> fieldValues;
    }

    // Internal wrapper, not AuraEnabled for Map usage
    public class FieldWrapper {
        public String objectName;
        public String fieldApi;
        public String fieldType;

        public FieldWrapper(String objName, String fldApi, String fieldType){
            this.objectName = objName;
            this.fieldApi = fldApi;
            this.fieldType=fieldType;
        }
    }
}