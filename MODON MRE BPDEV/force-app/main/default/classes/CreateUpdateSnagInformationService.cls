public with sharing class CreateUpdateSnagInformationService {

    public class ApiValidationException extends Exception {}

    public static CreateUpdateSnagInformationDtos.ApiResponseWrapper createSnagInformation(String requestBody) {
        CreateUpdateSnagInformationDtos.ApiResponseWrapper response =
            new CreateUpdateSnagInformationDtos.ApiResponseWrapper();

        try {
            CreateUpdateSnagInformationDtos.CreateSnagInformationRequest reqObj =
                (CreateUpdateSnagInformationDtos.CreateSnagInformationRequest) JSON.deserialize(
                    requestBody,
                    CreateUpdateSnagInformationDtos.CreateSnagInformationRequest.class
                );

            validateCommonRequest(reqObj.businessProcessId, reqObj.snagList);

            updateBusinessProcessDeSnagDetails(
                reqObj.businessProcessId,
                reqObj.qaDeSnagDate,
                reqObj.qaDesnaggingStatus,
                reqObj.qaDesnaggingCompletedDate,
                reqObj.fixedQASnags,
                reqObj.pendingQASnags
            );

            List<Snagging__c> snagsToInsert = new List<Snagging__c>();

            for (CreateUpdateSnagInformationDtos.SnagInformationWrapper snagReq : reqObj.snagList) {
                Snagging__c snag = buildSnagRecord(
                    new Snagging__c(),
                    snagReq,
                    reqObj.salesOrderId,
                    reqObj.businessProcessId,
                    reqObj.unitId,
                    reqObj.integrationType
                );

                snagsToInsert.add(snag);
            }

            if (!snagsToInsert.isEmpty()) {
                insert snagsToInsert;
            }

            for (Snagging__c snag : snagsToInsert) {
                response.snaggingIds.add(String.valueOf(snag.Id));
            }

            response.status = 'Success';
            response.message = 'Snag information created successfully';
            response.businessProcessId = String.valueOf(reqObj.businessProcessId);
            response.recordId = String.valueOf(reqObj.businessProcessId);
            response.createdCount = snagsToInsert.size();
            response.updatedCount = 0;

            RestContext.response.statusCode = 201;
            return response;

        } catch (Exception e) {
            return buildErrorResponse('Failed to create snag information', e);
        }
    }

    public static CreateUpdateSnagInformationDtos.ApiResponseWrapper createDeSnagInformation(String requestBody) {
        CreateUpdateSnagInformationDtos.ApiResponseWrapper response =
            new CreateUpdateSnagInformationDtos.ApiResponseWrapper();

        try {
            CreateUpdateSnagInformationDtos.CreateDeSnagInformationRequest reqObj =
                (CreateUpdateSnagInformationDtos.CreateDeSnagInformationRequest) JSON.deserialize(
                    requestBody,
                    CreateUpdateSnagInformationDtos.CreateDeSnagInformationRequest.class
                );

            validateCommonRequest(reqObj.businessProcessId, reqObj.snagList);

            updateBusinessProcessDeSnagDetails(
                reqObj.businessProcessId,
                reqObj.qaDeSnagDate,
                reqObj.qaDesnaggingStatus,
                reqObj.qaDesnaggingCompletedDate,
                reqObj.fixedQASnags,
                reqObj.pendingQASnags
            );

            Set<Id> snaggingIds = new Set<Id>();
            Set<String> onsiteSnagIds = new Set<String>();

            for (CreateUpdateSnagInformationDtos.SnagInformationWrapper snagReq : reqObj.snagList) {
                if (snagReq.snaggingId != null) {
                    snaggingIds.add(snagReq.snaggingId);
                }

                if (String.isNotBlank(snagReq.OnsiteSnagID)) {
                    onsiteSnagIds.add(snagReq.OnsiteSnagID);
                }
            }

            Map<Id, Snagging__c> existingById = new Map<Id, Snagging__c>();

            if (!snaggingIds.isEmpty()) {
                existingById = new Map<Id, Snagging__c>([
                    SELECT Id,
                           Sales_Order__c,
                           Unit__c,
                           Business_Process__c,
                           Snag_Name__c,
                           Snag_Comment__c,
                           De_Snag_Comment__c,
                           Snag_Link__c,
                           Priority__c,
                           Integration_Type__c,
                           RecordTypeId,
                           Onsite_Snag_ID__c
                    FROM Snagging__c
                    WHERE Id IN :snaggingIds
                ]);
            }

            Map<String, Snagging__c> existingByOnsiteId = new Map<String, Snagging__c>();

            if (!onsiteSnagIds.isEmpty()) {
                for (Snagging__c snag : [
                    SELECT Id,
                           Sales_Order__c,
                           Unit__c,
                           Business_Process__c,
                           Snag_Name__c,
                           Snag_Comment__c,
                           De_Snag_Comment__c,
                           Snag_Link__c,
                           Priority__c,
                           Integration_Type__c,
                           RecordTypeId,
                           Onsite_Snag_ID__c
                    FROM Snagging__c
                    WHERE Onsite_Snag_ID__c IN :onsiteSnagIds
                ]) {
                    existingByOnsiteId.put(String.valueOf(snag.Onsite_Snag_ID__c), snag);
                }
            }

            List<Snagging__c> snagsToInsert = new List<Snagging__c>();
            List<Snagging__c> snagsToUpdate = new List<Snagging__c>();

            for (CreateUpdateSnagInformationDtos.SnagInformationWrapper snagReq : reqObj.snagList) {
                Snagging__c snag;

                if (snagReq.snaggingId != null && existingById.containsKey(snagReq.snaggingId)) {
                    snag = existingById.get(snagReq.snaggingId);
                } else if (
                    String.isNotBlank(snagReq.OnsiteSnagID) &&
                    existingByOnsiteId.containsKey(snagReq.OnsiteSnagID)
                ) {
                    snag = existingByOnsiteId.get(snagReq.OnsiteSnagID);
                } else {
                    snag = new Snagging__c();
                }

                snag = buildSnagRecord(
                    snag,
                    snagReq,
                    reqObj.salesOrderId,
                    reqObj.businessProcessId,
                    reqObj.unitId,
                    reqObj.integrationType
                );

                if (snag.Id == null) {
                    snagsToInsert.add(snag);
                } else {
                    snagsToUpdate.add(snag);
                }
            }

            if (!snagsToInsert.isEmpty()) {
                insert snagsToInsert;
            }

            if (!snagsToUpdate.isEmpty()) {
                update snagsToUpdate;
            }

            for (Snagging__c snag : snagsToInsert) {
                response.snaggingIds.add(String.valueOf(snag.Id));
            }

            for (Snagging__c snag : snagsToUpdate) {
                response.snaggingIds.add(String.valueOf(snag.Id));
            }

            response.status = 'Success';
            response.message = 'De-snag information processed successfully';
            response.businessProcessId = String.valueOf(reqObj.businessProcessId);
            response.recordId = String.valueOf(reqObj.businessProcessId);
            response.createdCount = snagsToInsert.size();
            response.updatedCount = snagsToUpdate.size();

            RestContext.response.statusCode = 200;
            return response;

        } catch (Exception e) {
            return buildErrorResponse('Failed to process de-snag information', e);
        }
    }

    private static Snagging__c buildSnagRecord(
        Snagging__c snag,
        CreateUpdateSnagInformationDtos.SnagInformationWrapper snagReq,
        Id headerSalesOrderId,
        Id headerBusinessProcessId,
        Id headerUnitId,
        String headerIntegrationType
    ) {
        snag.Sales_Order__c = snagReq.salesOrderId != null ? snagReq.salesOrderId : headerSalesOrderId;
        snag.Business_Process__c = snagReq.businessProcessId != null ? snagReq.businessProcessId : headerBusinessProcessId;
        snag.Unit__c = snagReq.unitId != null ? snagReq.unitId : headerUnitId;

        snag.Snag_Name__c = snagReq.snagName;
        snag.Snag_Comment__c = snagReq.snagComment;
        snag.De_Snag_Comment__c = snagReq.deSnagComment;
        snag.Snag_Link__c = snagReq.snagLink;
        snag.Priority__c = snagReq.priority;
        snag.Integration_Type__c = headerIntegrationType;

        if (snagReq.recordTypeId != null) {
            snag.RecordTypeId = snagReq.recordTypeId;
        }

        if (String.isNotBlank(snagReq.OnsiteSnagID)) {
            snag.Onsite_Snag_ID__c = snagReq.OnsiteSnagID;
        }

        if (fieldExists('Snagging__c', 'Snag_Type__c')) {
            snag.put('Snag_Type__c', snagReq.snagType);
        }

        if (String.isNotBlank(snagReq.status) && fieldExists('Snagging__c', 'Status__c')) {
            snag.put('Status__c', snagReq.status);
        }

        return snag;
    }

    private static void updateBusinessProcessDeSnagDetails(
        Id businessProcessId,
        Date qaDeSnagDate,
        String qaDesnaggingStatus,
        Date qaDesnaggingCompletedDate,
        Integer fixedQASnags,
        Integer pendingQASnags
    ) {
        Business_Process__c bp = [
            SELECT Id,
                   QA_de_sang_date__c,
                   QA_Desnagging_Status__c,
                   QA_Desnagging_Date__c,
                   Fixed_QA_Snags__c,
                   Pending_QA_Snags__c
            FROM Business_Process__c
            WHERE Id = :businessProcessId
            LIMIT 1
        ];

        bp.QA_de_sang_date__c = qaDeSnagDate;
        bp.QA_Desnagging_Status__c = qaDesnaggingStatus;
        bp.QA_Desnagging_Date__c = qaDesnaggingCompletedDate;
        bp.Fixed_QA_Snags__c = fixedQASnags;
        bp.Pending_QA_Snags__c = pendingQASnags;

        update bp;
    }

    private static void validateCommonRequest(
        Id businessProcessId,
        List<CreateUpdateSnagInformationDtos.SnagInformationWrapper> snagList
    ) {
        if (businessProcessId == null) {
            throw new ApiValidationException('businessProcessId is required.');
        }

        if (snagList == null || snagList.isEmpty()) {
            throw new ApiValidationException('snagList is required.');
        }
    }

    private static CreateUpdateSnagInformationDtos.ApiResponseWrapper buildErrorResponse(
        String message,
        Exception e
    ) {
        CreateUpdateSnagInformationDtos.ApiResponseWrapper response =
            new CreateUpdateSnagInformationDtos.ApiResponseWrapper();

        response.status = 'Error';
        response.message = message;
        response.errors.add(e.getMessage());

        if (e.getLineNumber() > 0) {
            response.errors.add('Line: ' + String.valueOf(e.getLineNumber()));
        }

        RestContext.response.statusCode = 500;
        return response;
    }

    private static Boolean fieldExists(String objectApiName, String fieldApiName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        if (!globalDescribe.containsKey(objectApiName)) {
            return false;
        }

        Map<String, Schema.SObjectField> fieldMap =
            globalDescribe.get(objectApiName).getDescribe().fields.getMap();

        return fieldMap.containsKey(fieldApiName);
    }
}