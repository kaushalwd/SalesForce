public with sharing class HandOverSearchController {

    public class TableResponse {
        @AuraEnabled public List<Map<String,Object>> records;
        @AuraEnabled public List<ColumnWrapper> columns;
    }
    
    public class ColumnWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String type;
    }
    
    public class SendNotificationRes {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
    
    public class HandoverSearchRes {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
    }
    
    @AuraEnabled
    public static HandoverSearchRes updateHandoverPhasing(List<Id> businessProcessIds, Date handoverDate, Date expectedHandoverDate, String phase) {
        
        HandoverSearchRes response = new HandoverSearchRes();
        
        try {
            
            List<Business_Process__c> bpList = [SELECT Id, Name, Current_Business_Process_Step__c, Current_Business_Process_Step__r.Name, 
                                                Current_Business_Process_Step__r.Status__c, Current_Business_process_StepName__c, Handover_Details__c 
                                                FROM Business_Process__c 
                                                WHERE Id IN :businessProcessIds];
            
            List<String> invalidRecords = new List<String>();
            for(Business_Process__c bp : bpList) {
                if (bp.Handover_Details__c == null) {
                    invalidRecords.add(bp.Name);
                }
            }
            
            if (!invalidRecords.isEmpty()) {
                response.success = false;
                response.message = 'The following records are not associated with Handover Detail: ' + String.join(invalidRecords, ', ');
                return response;
            }
            
            for (Business_Process__c bp : bpList) {
                if (bp.Current_Business_process_StepName__c != 'Handover Phase Allocation') {
                    invalidRecords.add(bp.Name + ' (Stage: ' + bp.Current_Business_process_StepName__c + ')');
                } 
            }
            
            if (!invalidRecords.isEmpty()) {
                response.success = false;
                response.message = 'The following records are not in "Handover Phase Allocation" stage: ' + String.join(invalidRecords, ', ');
                return response;
            }
            
            List<Handover_Details__c> detailsToUpdate = new List<Handover_Details__c>();
            for (Business_Process__c bp : bpList) {
                Handover_Details__c hd = new Handover_Details__c();
                hd.Id = bp.Handover_Details__c;
                hd.Handover_Phase_Date__c = handoverDate;
                hd.Expected_Handover_Date__c = expectedHandoverDate;
                hd.Handover_Phase__c = phase;
                detailsToUpdate.add(hd);
            }
            update detailsToUpdate;
            
            response.success = true;
            response.message = detailsToUpdate.size() + ' Handover Detail record(s) updated successfully.';
            advanceBusinessProcessSteps(businessProcessIds);
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }
        
        return response;
    }
    
    @AuraEnabled
    public static HandoverSearchRes updateKARUser(List<Id> businessProcessIds, Id userId) {
        
        HandoverSearchRes response = new HandoverSearchRes();
        
        try {
            System.debug('businessProcessIds -- ' + businessProcessIds);
            List<Business_Process__c> bpList = [SELECT Id, Name, Current_Business_Process_Step__c, Current_Business_Process_Step__r.Name, 
                                                Current_Business_Process_Step__r.Status__c, Current_Business_process_StepName__c, Handover_Details__c 
                                                FROM Business_Process__c WHERE Id IN :businessProcessIds];
            system.debug('bpList -- ' + bpList);
            
            // Validate all have Handover Details
            List<String> invalidRecords = new List<String>();
            for (Business_Process__c bp : bpList) {
                if (bp.Handover_Details__c == null) {
                    invalidRecords.add(bp.Name);
                }
            }
            
            if (!invalidRecords.isEmpty()) {
                response.success = false;
                response.message = 'The following records are not associated with Handover Detail: '+ String.join(invalidRecords, ', ');
                return response;
            }
            
             for (Business_Process__c bp : bpList) {
                if (bp.Current_Business_process_StepName__c != 'KAR Assignment and Finance Billing') {
                    System.debug('Inside One');
                    invalidRecords.add(bp.Name + ' (Stage: ' + bp.Current_Business_process_StepName__c + ')');
                } 
            }
            
            if (!invalidRecords.isEmpty()) {
                System.debug('Inside Two');
                response.success = false;
                response.message = 'The following records are not in "KAR Assignment and Finance Billing" stage: ' + String.join(invalidRecords, ', ');
                return response;
            }
            
            // Update KAR__c on Handover Details
            List<Handover_Details__c> detailsToUpdate = new List<Handover_Details__c>();
            for (Business_Process__c bp : bpList) {
                Handover_Details__c hd = new Handover_Details__c();
                hd.Id = bp.Handover_Details__c;
                hd.KAR__c = userId;
                detailsToUpdate.add(hd);
            }
            
            update detailsToUpdate;
            
            response.success = true;
            response.message = detailsToUpdate.size() + ' Handover Detail record(s) updated successfully.';
            advanceBusinessProcessSteps(businessProcessIds);
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }
        
        return response;
    }
    
    @future
    public static void advanceBusinessProcessSteps(List<Id> businessProcessIds) {
        
        try {
            
            List<Business_Process__c> bpList = [SELECT Id, Current_Business_Process_Step__c, Current_Business_Process_Step__r.Sequence__c 
                                                FROM Business_Process__c
                                                WHERE Id IN :businessProcessIds];
            
            // Map BP Id -> current step Id and sequence
            Map<Id, Id> bpToCurrentStepId = new Map<Id, Id>();
            Map<Id, Decimal> bpToCurrentSequence = new Map<Id, Decimal>();
            
            for (Business_Process__c bp : bpList) {
                bpToCurrentStepId.put(bp.Id, bp.Current_Business_Process_Step__c);
                bpToCurrentSequence.put(bp.Id, bp.Current_Business_Process_Step__r.Sequence__c);
            }
            
            // Fetch all steps for these BPs ordered by sequence
            List<Business_Process_Step__c> allSteps = [SELECT Id, Status__c, Sequence__c, Business_Process__c 
                                                       FROM Business_Process_Step__c
                                                       WHERE Business_Process__c IN :businessProcessIds
                                                       ORDER BY Business_Process__c, Sequence__c ASC];
            
            // Group steps by BP Id
            Map<Id, List<Business_Process_Step__c>> bpToSteps = new Map<Id, List<Business_Process_Step__c>>();
            for (Business_Process_Step__c step : allSteps) {
                if (!bpToSteps.containsKey(step.Business_Process__c)) {
                    bpToSteps.put(step.Business_Process__c, new List<Business_Process_Step__c>());
                }
                bpToSteps.get(step.Business_Process__c).add(step);
            }
            
            List<Business_Process_Step__c> stepsToUpdate = new List<Business_Process_Step__c>();
            List<Business_Process__c> bpsToUpdate = new List<Business_Process__c>();
            
            for (Business_Process__c bp : bpList) {
                
                Decimal currentSeq = bpToCurrentSequence.get(bp.Id);
                List<Business_Process_Step__c> steps = bpToSteps.get(bp.Id);
                
                // Complete current step
                Business_Process_Step__c currentStep = new Business_Process_Step__c();
                currentStep.Id = bpToCurrentStepId.get(bp.Id);
                currentStep.Status__c = 'Completed';
                stepsToUpdate.add(currentStep);
                
                // Find and open next step
                Business_Process_Step__c nextStep = null;
                for (Business_Process_Step__c step : steps) {
                    if (step.Sequence__c > currentSeq) {
                        nextStep = step;
                        break;
                    }
                }
                
                if (nextStep != null) {
                    Business_Process_Step__c nextStepToUpdate = new Business_Process_Step__c();
                    nextStepToUpdate.Id = nextStep.Id;
                    nextStepToUpdate.Status__c = 'Open';
                    stepsToUpdate.add(nextStepToUpdate);
                    
                    // Point BP to next step
                    Business_Process__c bpToUpdate = new Business_Process__c();
                    bpToUpdate.Id = bp.Id;
                    bpToUpdate.Current_Business_Process_Step__c = nextStep.Id;
                    bpToUpdate.Previous_Business_Process_Step__c = currentStep.Id;
                    bpsToUpdate.add(bpToUpdate);
                }
            }
            
            if (!stepsToUpdate.isEmpty()) update stepsToUpdate;
            if (!bpsToUpdate.isEmpty()) update bpsToUpdate;
            
        } catch (Exception e) {
            System.debug('advanceBusinessProcessSteps Error: ' + e.getMessage());
        }
    }

    
    @AuraEnabled
    public static SendNotificationRes sendNotifications(List<Id> businessProcessIds, String notificationType) {
        SendNotificationRes response = new SendNotificationRes();
        
        try {
            Database.executeBatch(new SendHandOverNotificationBatch(businessProcessIds, notificationType), 50);
            response.success = true;
            response.message = notificationType + ' Notification process initiated successfully.';
        } catch(Exception ex) {
            response.success = false;
            response.message = ex.getMessage();
        }
        return response;
        
    }
    
    @AuraEnabled
    public static TableResponse getBusinessProcess(Id projectId, Id phaseId, Id salesOrderId, Id unitId, String handoverPhase){

        List<Business_Process_Table_Config__mdt> configs = [SELECT Field_API_Name__c, Field_Label__c, Order__c 
                                                            FROM Business_Process_Table_Config__mdt ORDER BY Order__c];

        List<String> fieldList = new List<String>();
        List<ColumnWrapper> columns = new List<ColumnWrapper>();
        // SOQL injection fix: only allow safe field API names from CMDT before building SELECT.
        Pattern safeField = Pattern.compile('^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)?$');

        for(Business_Process_Table_Config__mdt cfg : configs) {
            if (String.isBlank(cfg.Field_API_Name__c)
                || !safeField.matcher(cfg.Field_API_Name__c).matches()) {
                continue;
            }
            
            fieldList.add(cfg.Field_API_Name__c);
            
            ColumnWrapper col = new ColumnWrapper();
            col.label = cfg.Field_Label__c;
            col.fieldName = cfg.Field_API_Name__c.replace('.', '_');
            col.type = 'text';
            
            columns.add(col);
        }

        Map<String, Object> binds = new Map<String, Object>();
        String query = 'SELECT Id'
            + (fieldList.isEmpty() ? '' : ', ' + String.join(fieldList, ','))
            + ' FROM Business_Process__c WHERE Id != null';

        if(projectId != null){
            query += ' AND Project__c = :projectId';
            binds.put('projectId', projectId);
        }

        if(phaseId != null){
            query += ' AND Phase__c = :phaseId';
            binds.put('phaseId', phaseId);
        }

        if(salesOrderId != null){
            query += ' AND Sales_Order__c = :salesOrderId';
            binds.put('salesOrderId', salesOrderId);
        }
        
        if(unitId != null){
            query += ' AND Unit__c = :unitId';
            binds.put('unitId', unitId);
        }
        
        if (String.isNotBlank(handoverPhase)) {
            query += ' AND Handover_Details__r.Handover_Phase__c = :handoverPhase';
            binds.put('handoverPhase', handoverPhase);
        }
        
        System.debug('query -- ' + query);
        List<SObject> results = Database.queryWithBinds(query, binds, AccessLevel.SYSTEM_MODE);

        List<Map<String, Object>> data = new List<Map<String, Object>>();
        for(SObject rec : results) {
            
            Map<String,Object> row = new Map<String,Object>();
            row.put('Id', rec.Id);
            for(String field : fieldList) {
                
                String key = field.replace('.', '_');
                
                if(field.contains('.')){
                    
                    List<String> parts = field.split('\\.');
                    
                    SObject parent = rec.getSObject(parts[0]);
                    
                    row.put(key , parent != null ? parent.get(parts[1]) : null);
                    
                }
                else{
                    row.put(key , rec.get(field));
                }
            }
            
            data.add(row);
        }

        TableResponse resp = new TableResponse();
        resp.records = data;
        resp.columns = columns;

        return resp;
    }
    
    public static void progressToNextStep (Id bpId) {
        
        Business_Process__c bp = [SELECT Current_Business_Process_Step__c,
                                  Current_Business_Process_Step__r.Sequence__c
                                  FROM Business_Process__c
                                  WHERE Id = :bpId LIMIT 1] ?? null;
        
        if (bp == null) return;
        
        Decimal nextSequence = bp.Current_Business_Process_Step__r.Sequence__c + 1;
        
        List<Business_Process_Step__c> steps = [SELECT Id, Sequence__c
                                                FROM Business_Process_Step__c
                                                WHERE Business_Process__c = :bpId
                                                AND (Id = :bp.Current_Business_Process_Step__c OR Sequence__c = :nextSequence)
                                                ORDER BY Sequence__c ASC
                                                LIMIT 2];
        
        for (Business_Process_Step__c step : steps) {
            if(step.Id == bp.Current_Business_Process_Step__c) {
                step.Status__c = 'Completed';
              //  bp.Previous_Business_Process_Step__c = step.Id;
            } else {
                step.Status__c = 'Open';
               // bp.Current_Business_Process_Step__c = step.Id;
            }
        }
        
        if (!steps.isEmpty()) {
            update steps;
           // update bp;
        } 
    }


    public class CsvUnitResponse {

    @AuraEnabled
    public List<Map<String,Object>> records;

    @AuraEnabled
    public List<ColumnWrapper> columns;

    @AuraEnabled
    public List<String> missingUnitNames;

    @AuraEnabled
    public Integer foundUnitCount;

    @AuraEnabled
    public Integer totalUnitCount;
}

@AuraEnabled
public static CsvUnitResponse getBusinessProcessByUnitNames(
    List<String> unitNames
) {

    CsvUnitResponse response =
        new CsvUnitResponse();

    response.records =
        new List<Map<String,Object>>();

    response.columns =
        new List<ColumnWrapper>();

    response.missingUnitNames =
        new List<String>();

    response.foundUnitCount = 0;
    response.totalUnitCount = 0;

    if (
        unitNames == null ||
        unitNames.isEmpty()
    ) {
        return response;
    }

    /*
     * =====================================================
     * CLEAN UNIT NAMES
     * =====================================================
     */

    Set<String> cleanUnitNames =
        new Set<String>();

    Map<String,String> normalizedToOriginal =
        new Map<String,String>();

    for (String unitName : unitNames) {

        if (String.isBlank(unitName)) {
            continue;
        }

        String cleaned =
            unitName.trim();

        if (String.isBlank(cleaned)) {
            continue;
        }

        String normalized =
            cleaned.toLowerCase();

        cleanUnitNames.add(normalized);

        normalizedToOriginal.put(
            normalized,
            cleaned
        );
    }

    response.totalUnitCount =
        cleanUnitNames.size();

    if (cleanUnitNames.isEmpty()) {
        return response;
    }

    /*
     * =====================================================
     * GET TABLE CONFIGURATION
     * =====================================================
     */

    List<Business_Process_Table_Config__mdt> configs =
        [
            SELECT
                Field_API_Name__c,
                Field_Label__c,
                Order__c
            FROM Business_Process_Table_Config__mdt
            ORDER BY Order__c
        ];

    List<String> fieldList =
        new List<String>();

    List<ColumnWrapper> columns =
        new List<ColumnWrapper>();

    Pattern safeField =
        Pattern.compile(
            '^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)?$'
        );

    for (
        Business_Process_Table_Config__mdt cfg :
        configs
    ) {

        if (
            String.isBlank(
                cfg.Field_API_Name__c
            )
        ) {
            continue;
        }

        if (
            !safeField.matcher(
                cfg.Field_API_Name__c
            ).matches()
        ) {
            continue;
        }

        fieldList.add(
            cfg.Field_API_Name__c
        );

        ColumnWrapper col =
            new ColumnWrapper();

        col.label =
            cfg.Field_Label__c;

        col.fieldName =
            cfg.Field_API_Name__c
                .replace('.', '_');

        col.type = 'text';

        columns.add(col);
    }

    /*
     * =====================================================
     * IMPORTANT
     *
     * We need Unit__r.Name in the query.
     * =====================================================
     */

    if (!fieldList.contains('Unit__r.Name')) {

        fieldList.add(
            'Unit__r.Name'
        );

        ColumnWrapper unitColumn =
            new ColumnWrapper();

        unitColumn.label =
            'Unit Name';

        unitColumn.fieldName =
            'Unit__r_Name';

        unitColumn.type =
            'text';

        /*
         * Put Unit Name at the beginning.
         */
        columns.add(
            0,
            unitColumn
        );
    }

    /*
     * =====================================================
     * BUILD QUERY
     * =====================================================
     */

    String query =
        'SELECT Id';

    if (!fieldList.isEmpty()) {

        query +=
            ', ' +
            String.join(
                fieldList,
                ','
            );
    }

    query +=
        ' FROM Business_Process__c' +
        ' WHERE Unit__r.Name IN :unitNames';

    /*
     * Only return BPs associated with Handover Details.
     */

    query +=
        ' AND Handover_Details__c != null';

    /*
     * =====================================================
     * EXECUTE QUERY
     * =====================================================
     */

    Map<String,Object> binds =
        new Map<String,Object>();

    /*
     * Use original values for SOQL IN.
     * Salesforce text matching is normally case-insensitive,
     * so this will match the unit names.
     */

    Set<String> queryUnitNames =
        new Set<String>();

    for (String originalName : unitNames) {

        if (!String.isBlank(originalName)) {

            queryUnitNames.add(
                originalName.trim()
            );
        }
    }

    binds.put(
        'unitNames',
        queryUnitNames
    );

    List<SObject> results =
        Database.queryWithBinds(
            query,
            binds,
            AccessLevel.SYSTEM_MODE
        );

    /*
     * =====================================================
     * TRACK FOUND UNITS
     * =====================================================
     */

    Set<String> foundNormalizedNames =
        new Set<String>();

    /*
     * =====================================================
     * BUILD DATATABLE RECORDS
     * =====================================================
     */

    for (SObject rec : results) {

        Map<String,Object> row =
            new Map<String,Object>();

        row.put(
            'Id',
            rec.Id
        );

        for (String field : fieldList) {

            String key =
                field.replace('.', '_');

            if (field.contains('.')) {

                List<String> parts =
                    field.split('\\.');

                SObject parent =
                    rec.getSObject(
                        parts[0]
                    );

                Object value =
                    parent != null
                    ? parent.get(parts[1])
                    : null;

                row.put(
                    key,
                    value
                );

                /*
                 * Track Unit Name.
                 */
                if (
                    field == 'Unit__r.Name' &&
                    value != null
                ) {

                    foundNormalizedNames.add(
                        String.valueOf(value)
                            .trim()
                            .toLowerCase()
                    );
                }

            } else {

                row.put(
                    key,
                    rec.get(field)
                );
            }
        }

        response.records.add(
            row
        );
    }

    /*
     * =====================================================
     * FIND MISSING UNITS
     * =====================================================
     */

    for (String normalizedName :
        cleanUnitNames) {

        if (
            !foundNormalizedNames
                .contains(normalizedName)
        ) {

            response.missingUnitNames.add(
                normalizedToOriginal.get(
                    normalizedName
                )
            );
        }
    }

    response.foundUnitCount =
        foundNormalizedNames.size();

    response.columns =
        columns;

    return response;
}

@AuraEnabled
public static Map<String, Object> updateHandoverDetailZone(
    List<Id> businessProcessIds,
    String zoneName
) {

    Map<String, Object> response = new Map<String, Object>();

    try {

        if (businessProcessIds == null || businessProcessIds.isEmpty()) {

            response.put('success', false);
            response.put(
                'message',
                'No Business Process records were selected.'
            );

            return response;
        }

        if (String.isBlank(zoneName)) {

            response.put('success', false);
            response.put(
                'message',
                'Please select a Zone.'
            );

            return response;
        }

        List<Handover_Details__c> HandOverListUpdate=new List<Handover_Details__c>();
        List<Business_Process__c> businessProcesses = [
            SELECT Id,
                   Handover_Details__c
            FROM Business_Process__c
            WHERE Id IN :businessProcessIds
        ];

        for (Business_Process__c bp : businessProcesses) {
              if(bp.Handover_Details__c!=null)
			  HandOverListUpdate.add(new Handover_Details__c(Id=bp.Handover_Details__c, Zone__c=zoneName));
           
        }

        if (!HandOverListUpdate.isEmpty()) {

            update HandOverListUpdate;
        }

        response.put('success', true);

        response.put(
            'message',
            ' Unit(s) updated successfully to ' +
            zoneName + '.'
        );

        return response;

    } catch (Exception e) {

        response.put('success', false);

        response.put(
            'message',
            e.getMessage()
        );

        return response;
    }
}


public class BCCUploadResponse {

    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;

    public BCCUploadResponse(
        Boolean success,
        String message
    ) {
        this.success = success;
        this.message = message;
    }
}

@AuraEnabled
public static BCCUploadResponse uploadBCCLetter(
    List<Id> businessProcessIds,
    Id contentDocumentId
) {
    if (businessProcessIds == null || businessProcessIds.isEmpty()) {
        return new BCCUploadResponse(
            false,
            'Please select at least one Business Process.'
        );
    }

    if (contentDocumentId == null) {
        return new BCCUploadResponse(
            false,
            'Uploaded BCC Letter file was not found.'
        );
    }

    try {

        List<Business_Process_Documents__c> bccDocuments = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Documents__c
            WHERE Business_Process__c IN :businessProcessIds
            AND Name = 'BCC Letter'
        ];

        if (bccDocuments.isEmpty()) {
            return new BCCUploadResponse(
                false,
                'BCC Letter document was not found for the selected Business Process records.'
            );
        }

        List<ContentDocumentLink> linksToInsert =
            new List<ContentDocumentLink>();

        for (Business_Process_Documents__c bccDocument : bccDocuments) {

            linksToInsert.add(
                new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = bccDocument.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                )
            );
        }

        insert linksToInsert;

        return new BCCUploadResponse(
            true,
            'BCC Letter uploaded successfully.'
        );

    } catch (Exception e) {

        throw new AuraHandledException(
            'Unable to upload BCC Letter: ' + e.getMessage()
        );
    }
}

}