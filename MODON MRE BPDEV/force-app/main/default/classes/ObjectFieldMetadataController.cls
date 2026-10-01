/**********************************************************************************************************************
* Name               : ObjectFieldMetadataController                                                        
* Description        : This class is used to return Metadata 
* Usage              : Called from LWC
* Created By         : Sireesha Komma                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sireesha                   04/03/2025       Initial Draft
* 1.1           Chandu                     30/04/2026        Added method to check the existing record type reocrds
* 1.2           Chandu                     19/05/2026        Added method for uploading file, copying salesorder data
******************************************************************************************************************/

public with sharing class ObjectFieldMetadataController {
    
    @AuraEnabled
    public static boolean getisActive(String objName){
        Boolean isActive=false;
        List<ObjectField__mdt> objectFieldlst= new List<ObjectField__mdt>();
        
        objectFieldlst = [SELECT Id,isActive__c FROM ObjectField__mdt WHERE isActive__c =:true AND Object_Name__c= :objName];
        
        if(objectFieldlst.size()>0){
            isActive = true;
        }else{
            isActive = false;
        }
        return isActive;
    }
    
    @AuraEnabled(cacheable=true) //1.1 start
    public static Map<String, String> getStatusToRecordTypeMap(String objName){
        
        Map<String, String> statusMap = new Map<String, String>();
        
        List<ObjectField__mdt> records = [
            SELECT Status__c, RecordType_Name__c
            FROM ObjectField__mdt
            WHERE Object_Name__c = :objName
            AND isActive__c = true
        ];
        
        for(ObjectField__mdt rec : records){
            if(rec.Status__c != null && rec.RecordType_Name__c != null){
                statusMap.put(rec.Status__c, rec.RecordType_Name__c);
            }
        }
        
        return statusMap;
    } //1.1 end
    
    
    @AuraEnabled
    public static FieldInfoWrapper getObjInfo(String sObjectName ,String sObjectRecordType, String sOjectRecId){
        String sObjName;
        
        if(sOjectRecId <> null || sOjectRecId !=''){
            Id recID =sOjectRecId;
            sObjName = recID.getSObjectType().getDescribe().getName();
        }
        
        System.debug('sObjName----->'+sObjName);        
        FieldInfoWrapper fieldInfoWrapper = new FieldInfoWrapper();
        try{
            fieldInfoWrapper.columns = getFields(sObjectName,sObjectRecordType,sObjName);
            
        }catch (Exception e){
            LoggerService.save(LoggerService.createApexLog(e,'ObjectFieldMetadataController','ObjectFieldMetadataController.getisActive',''));
            system.debug('Error:::: ' + e.getMessage() + ' Trace::: ' + e.getStackTraceString());
        }
        System.debug('fieldInfoWrapper--->'+fieldInfoWrapper);
        
        return fieldInfoWrapper;
    }
    Public class FieldInfoWrapper{
        @AuraEnabled public List<FieldWrapper> columns {get;set;}
    }
    @testVisible
    private static  List<FieldWrapper> getFields(String sObjectName, String sObjectRecordType, String sObjName){
        List<FieldWrapper> fieldWrappers = new List<FieldWrapper>();
        List<String> fieldReqAPINames = new List<String> ();
        List<String> fieldOptAPINames = new List<String> ();
        List<String> fieldRedonlyAPINames = new List<String> ();
        
        List<ObjectField__mdt> objectFieldlst= new List<ObjectField__mdt>();
        System.debug('Object Name--->'+sObjectName+'recordType'+sObjectRecordType);
        if (String.isNotBlank(sObjectName) && String.isBlank(sObjectRecordType)) {
            objectFieldlst = [
                SELECT Id, Required_Fields__c, Read_Only_Fields__c, Related_Field_API_Names__c
                FROM ObjectField__mdt
                WHERE isActive__c = true
                AND Object_Name__c = :sObjectName
            ];
        } else if (String.isNotBlank(sObjectRecordType)) {
            objectFieldlst = [
                SELECT Id, Required_Fields__c, Read_Only_Fields__c, Related_Field_API_Names__c
                FROM ObjectField__mdt
                WHERE isActive__c = true
                AND Object_Name__c = :sObjectName
                AND RecordType_Name__c = :sObjectRecordType
            ];
        } else if (String.isNotBlank(sObjName)) {
            objectFieldlst = [
                SELECT Id, Required_Fields__c, Read_Only_Fields__c, Related_Field_API_Names__c
                FROM ObjectField__mdt
                WHERE isActive__c = true
                AND Object_Type__c = :sObjName
            ];
        }
        System.debug('objectFieldlst'+objectFieldlst);
        if(objectFieldlst.size() == 0 || objectFieldlst.isEmpty()){
            throw new AuraHandledException('No Data Found');
        }
        for(ObjectField__mdt obj:objectFieldlst){
            if(obj.Related_Field_API_Names__c <> NULL){
                if(obj.Related_Field_API_Names__c.contains(',')){
                    obj.Related_Field_API_Names__c = obj.Related_Field_API_Names__c.replaceAll(' ','');
                    fieldOptAPINames = obj.Related_Field_API_Names__c.toLowerCase().split(',');
                    
                    System.debug('fieldAPINames---->65'+fieldOptAPINames);
                }
            }
            System.debug('obj.Required_Fields__c--->'+obj.Required_Fields__c);
            if(obj.Required_Fields__c != '' || obj.Required_Fields__c <> NULL){
                if(obj.Required_Fields__c.contains(',')){
                    obj.Required_Fields__c = obj.Required_Fields__c.replaceAll(' ','');
                    fieldReqAPINames = obj.Required_Fields__c.toLowerCase().split(',');
                    
                    System.debug('fieldRequiredAPINames---->65'+fieldReqAPINames);
                }else{
                    fieldReqAPINames.add(obj.Required_Fields__c.toLowerCase());
                }
            }
            if(obj.Read_Only_Fields__c != '' || obj.Read_Only_Fields__c <> NULL){
                if(obj.Read_Only_Fields__c.contains(',')){
                    obj.Read_Only_Fields__c = obj.Read_Only_Fields__c.replaceAll(' ','');
                    fieldRedonlyAPINames = obj.Read_Only_Fields__c.toLowerCase().split(',');
                    
                    System.debug('fieldRedonlyAPINames---->65'+fieldRedonlyAPINames);
                }else{
                    fieldRedonlyAPINames.add(obj.Read_Only_Fields__c.toLowerCase());
                }
            }
        }
        if(objectFieldlst.size() >0 && (fieldReqAPINames.size() >0 || fieldOptAPINames.size()>0 || fieldRedonlyAPINames.size()>0)){
            Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
            Schema.SObjectType objectType = schemaMap.get(sObjectName);
            Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
            
            for (String fieldName: fieldMap.keySet()) {
                if(fieldReqAPINames.contains(fieldName.toLowerCase())){
                    FieldWrapper wrapper = new FieldWrapper();
                    wrapper.label = fieldMap.get(fieldName).getDescribe().getLabel();
                    wrapper.type = String.valueOf(fieldMap.get(fieldName).getDescribe().getType());
                    wrapper.fieldName = String.valueOf(fieldMap.get(fieldName));
                    wrapper.fieldType = String.valueOf('RequiredFields');
                    fieldWrappers.add(wrapper);
                    System.debug('fieldWrappers---->Required'+fieldWrappers);
                }
                if(fieldOptAPINames.contains(fieldName.toLowerCase())){
                    FieldWrapper wrapper = new FieldWrapper();
                    wrapper.label = fieldMap.get(fieldName).getDescribe().getLabel();
                    wrapper.type = String.valueOf(fieldMap.get(fieldName).getDescribe().getType());
                    wrapper.fieldName = String.valueOf(fieldMap.get(fieldName));
                    wrapper.fieldType = String.valueOf('OptionalFields');
                    fieldWrappers.add(wrapper);
                }
                if(fieldRedonlyAPINames.contains(fieldName.toLowerCase())){
                    FieldWrapper wrapper = new FieldWrapper();
                    wrapper.label = fieldMap.get(fieldName).getDescribe().getLabel();
                    wrapper.type = String.valueOf(fieldMap.get(fieldName).getDescribe().getType());
                    wrapper.fieldName = String.valueOf(fieldMap.get(fieldName));
                    wrapper.fieldType = String.valueOf('ReadOnlyFields');
                    fieldWrappers.add(wrapper);
                }
            }
        }
        System.debug('fieldWrappers--->'+fieldWrappers);
        
        return fieldWrappers;
    }
    Public class FieldWrapper{
        @AuraEnabled public String label {get;set;}
        @AuraEnabled public String type {get;set;}
        @AuraEnabled public String fieldName {get;set;}
        @AuraEnabled public String fieldType {get;set;}
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRecordTypeData() {
        Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get('ServiceRequest__c').getDescribe();
        List<Schema.RecordTypeInfo> recordTypeList = objDescribe.getRecordTypeInfos();
        
        Map<String, String> filteredRecordTypes = new Map<String, String>();
        
        for (Schema.RecordTypeInfo rt : recordTypeList) {
            filteredRecordTypes.put(rt.getRecordTypeId(), rt.getName()); // Key = RecordTypeId, Value = Name
            
        }
        
        return filteredRecordTypes;
    }
    
    @AuraEnabled //V1.1
    public static String checkExistingSR(Id salesOrderId, Id recordTypeId) {
        List<ServiceRequest__c> srList = [
            SELECT Id, RecordType.Name
            FROM ServiceRequest__c
            WHERE SalesOrder__c = :salesOrderId
            AND RecordTypeId = :recordTypeId
            LIMIT 1
        ];
        
        if (!srList.isEmpty()) {
            return srList[0].RecordType.Name;
        }
        
        return null;
    } //End 1.1
     //1.2 Start
    @AuraEnabled(cacheable=true)
    public static List<SalesOrder__c> getRelatedSalesOrders(Id salesOrderId) {
        String SOstatusExcludeLst = System.Label.SO_Status_List;
        String MIREExcludelst = System.Label.MIRE_Exclude_List;
        String ModeofpaymentValues = System.Label.ModeofpaymentValues;
        list<String> SOList = new List<String>();
        for (String c : SOstatusExcludeLst.split(',')) SOList.add(c.trim());
        
        
        List<String> MIREList = new List<String>();
        for (String c2 : MIREExcludelst.split(',')) {
            if (c2 != null && c2.contains('^')) {
                MIREList.add(c2.replace('^', ',').trim());
            } else {
                MIREList.add(c2.trim());
            }
        }
        
        Id accId = [
            SELECT CustomerAccount__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
        ].CustomerAccount__c;
        
        return [
            SELECT Id, Name, Unit_Name__c
            FROM SalesOrder__c
            WHERE CustomerAccount__c = :accId
            AND Id != :salesOrderId and Status__c NOT IN :SOList AND ProjectName__c NOT IN :MIREList 
        ];
    }
    
    @AuraEnabled
    public static void saveConsolidationRecords(List<Unit_Consolidation__c> records) {
        
        if (records == null || records.isEmpty()) return;
        
        Database.SaveResult[] results = Database.insert(records, false);
        
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    throw new AuraHandledException(err.getMessage());
                }
            }
        }
    }
    
    @AuraEnabled
    public static void copyFilesToServiceRequest(
        Id salesOrderId,
        Id serviceRequestId
    ) {
        
        // Fetch Placeholder Document Record
        Documents__c approvalDoc = [
            
            SELECT Id
            FROM Documents__c
            WHERE Service_Request__c = :serviceRequestId
            AND Name = 'Pre Unit Cancellation Approval Attachment'
            LIMIT 1
        ];
        
        // Fetch Existing Sales Order Files
        List<ContentDocumentLink> existingLinks = [
            
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :salesOrderId
        ];
        
        List<ContentDocumentLink> newLinks =
            new List<ContentDocumentLink>();
        
        for (ContentDocumentLink cdl : existingLinks) {
            
            newLinks.add(
                
                new ContentDocumentLink(
                    
                    // Link To Placeholder Document Record
                    LinkedEntityId = approvalDoc.Id,
                    
                    ContentDocumentId = cdl.ContentDocumentId,
                    
                    ShareType = 'V',
                    
                    Visibility = 'AllUsers'
                )
            );
        }
        
        if (!newLinks.isEmpty()) {
            
            insert newLinks;
        }
    }
    
    
    @AuraEnabled
    public static void deleteUploadedFile(Id contentDocumentId) {
        delete [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :contentDocumentId
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getReceiptAmounts(Id salesOrderId) {

        Decimal admAmount = 0;
        Decimal downPaymentAmount = 0;

        List<Receipt__c> receipts = [

            SELECT Id,
            AppliedAmount__c,
            Receipt_Amount__c,
            Is_ADM_Fees_and_Dari_charges__c,
            Milestone__c,Status__c
            FROM Receipt__c
            WHERE SalesOrder__c = :salesOrderId
            AND (
                Is_ADM_Fees_and_Dari_charges__c = true
                OR Milestone__c = 1
            )
        ];

        for(Receipt__c rec : receipts) {

            // ADM Receipt
            if(rec.Is_ADM_Fees_and_Dari_charges__c == true && rec.Status__c == 'Cleared') {

                admAmount +=
                    rec.AppliedAmount__c != null
                    ? rec.AppliedAmount__c
                    : 0;
            }

            // Down Payment Receipt
            if(
                rec.Is_ADM_Fees_and_Dari_charges__c == false &&
                rec.Milestone__c == 1 && rec.Status__c == 'Cleared'
            ) {

                downPaymentAmount +=
                    rec.Receipt_Amount__c != null
                    ? rec.Receipt_Amount__c
                    : 0;
            }
        }

        return new Map<String, Decimal>{

            'admAmount' => admAmount,

                'downPaymentAmount' => downPaymentAmount
                };
     } //end 1.2
    
}