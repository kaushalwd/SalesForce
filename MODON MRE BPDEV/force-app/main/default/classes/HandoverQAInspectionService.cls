public class HandoverQAInspectionService {
    public static HandoverQAInspectionDtos.ApiResponseWrapper saveSnaggingSection(String requestBody) {
        HandoverQAInspectionDtos.ApiResponseWrapper response = new HandoverQAInspectionDtos.ApiResponseWrapper();

        try {
            HandoverQAInspectionDtos.SaveSnaggingSectionRequest reqObj =
                (HandoverQAInspectionDtos.SaveSnaggingSectionRequest) JSON.deserialize(
                    requestBody,
                    HandoverQAInspectionDtos.SaveSnaggingSectionRequest.class
                );

            HandoverQAInspectionValidators.validateSaveSnaggingSectionRequest(reqObj);

            Business_Process__c bp = [
                SELECT Id,
                       Sales_Order__c,
                       Unit__c,
                       Total_QA_Snags__c,
                       QA_snag_date__c,
                       QA_Snag_Executive__c,
                       Contractor_Name__c,
                       Fixed_QA_Snags__c/*,
                       QA_Snag_Status__c*/
                FROM Business_Process__c
                WHERE Id = :reqObj.businessProcessId
                LIMIT 1
            ];

           // bp.Sales_Order__c = reqObj.salesOrderId;
            //bp.Unit__c = reqObj.unitId;
            bp.Total_QA_Snags__c = reqObj.totalQASnags;
            bp.QA_snag_date__c = reqObj.qaSnagDate;
            bp.QA_Snag_Executive__c = reqObj.qaSnagExecutiveId;
            bp.Contractor_Name__c = reqObj.contractorName;
            bp.Fixed_QA_Snags__c = reqObj.fixedQASnags;
         //   bp.QA_Snag_Status__c = reqObj.qaSnagStatus;

            update bp;

            response.status = 'Success';
            response.message = 'QA Snagging section saved successfully';
            response.businessProcessId = bp.Id;
            response.recordId = bp.Id;
            RestContext.response.statusCode = 200;
            return response;

        } catch (Exception e) {
            return buildErrorResponse('Failed to save QA Snagging section', e);
        }
    }

    public static HandoverQAInspectionDtos.ApiResponseWrapper saveDeSnaggingSection(String requestBody) {
        HandoverQAInspectionDtos.ApiResponseWrapper response = new HandoverQAInspectionDtos.ApiResponseWrapper();

        try {
            HandoverQAInspectionDtos.SaveDeSnaggingSectionRequest reqObj =
                (HandoverQAInspectionDtos.SaveDeSnaggingSectionRequest) JSON.deserialize(
                    requestBody,
                    HandoverQAInspectionDtos.SaveDeSnaggingSectionRequest.class
                );

            HandoverQAInspectionValidators.validateSaveDeSnaggingSectionRequest(reqObj);

            Business_Process__c bp = [
                SELECT Id,
                       Sales_Order__c,
                       Unit__c,
                       QA_de_sang_date__c,
                       QA_Desnagging_Status__c,
                       QA_Desnagging_Date__c,
                       Fixed_QA_Snags__c,
                       Pending_QA_Snags__c
                FROM Business_Process__c
                WHERE Id = :reqObj.businessProcessId
                LIMIT 1
            ];

           // bp.Sales_Order__c = reqObj.salesOrderId;
           // bp.Unit__c = reqObj.unitId;
            bp.QA_de_sang_date__c = reqObj.qaDeSnagDate;
            bp.QA_Desnagging_Status__c = reqObj.qaDesnaggingStatus;
            bp.QA_Desnagging_Date__c = reqObj.qaDesnaggingCompletedDate;
            bp.Fixed_QA_Snags__c = reqObj.fixedQASnags;
            bp.Pending_QA_Snags__c = reqObj.pendingQASnags;

            update bp;

            response.status = 'Success';
            response.message = 'QA De-Snagging section saved successfully';
            response.businessProcessId = bp.Id;
            response.recordId = bp.Id;
            RestContext.response.statusCode = 200;
            return response;

        } catch (Exception e) {
            return buildErrorResponse('Failed to save QA De-Snagging section', e);
        }
    }

    public static HandoverQAInspectionDtos.ApiResponseWrapper createSnag(String requestBody) {
        HandoverQAInspectionDtos.ApiResponseWrapper response = new HandoverQAInspectionDtos.ApiResponseWrapper();

        try {
            HandoverQAInspectionDtos.CreateSnagRequest reqObj =
                (HandoverQAInspectionDtos.CreateSnagRequest) JSON.deserialize(
                    requestBody,
                    HandoverQAInspectionDtos.CreateSnagRequest.class
                );

            HandoverQAInspectionValidators.validateCreateSnagRequest(reqObj);

            Snagging__c snag = new Snagging__c();
            snag.Sales_Order__c = reqObj.salesOrderId;
            snag.Unit__c = reqObj.unitId;
            snag.Business_Process__c = reqObj.businessProcessId;
            snag.Snag_Name__c = reqObj.snagName;
            snag.Snag_Comment__c = reqObj.snagComment;
            snag.De_Snag_Comment__c = reqObj.deSnagComment;
            snag.Snag_Link__c = reqObj.snagLink;
            snag.Priority__c = reqObj.priority;
          //  To be added snag.status =
           //  To be added snag.onsiteSnagID
           
           // snag.Integration_Type__c = reqObj.integrationType;

            /*
            if (reqObj.recordTypeId != null) {
                snag.RecordTypeId = reqObj.recordTypeId;
            }

            if (fieldExists('Snagging__c', 'Snag_Type__c')) {
                snag.put('Snag_Type__c', reqObj.snagType);
            }
            */

            insert snag;

            response.status = 'Success';
            response.message = 'Snagging record created successfully';
            response.snaggingId = snag.Id;
            response.recordId = snag.Id;
            RestContext.response.statusCode = 201;
            return response;

        } catch (Exception e) {
            return buildErrorResponse('Failed to create Snagging record', e);
        }
    }

    public static HandoverQAInspectionDtos.ApiResponseWrapper updateSnag(String requestBody) {
        HandoverQAInspectionDtos.ApiResponseWrapper response = new HandoverQAInspectionDtos.ApiResponseWrapper();

        try {
            HandoverQAInspectionDtos.UpdateSnagRequest reqObj =
                (HandoverQAInspectionDtos.UpdateSnagRequest) JSON.deserialize(
                    requestBody,
                    HandoverQAInspectionDtos.UpdateSnagRequest.class
                );

            HandoverQAInspectionValidators.validateUpdateSnagRequest(reqObj);

            Snagging__c snag = [
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
                       RecordTypeId
                FROM Snagging__c
                WHERE Id = :reqObj.snaggingId
                LIMIT 1
            ];

            if (reqObj.salesOrderId != null) {
                snag.Sales_Order__c = reqObj.salesOrderId;
            }
            if (reqObj.unitId != null) {
                snag.Unit__c = reqObj.unitId;
            }
            if (reqObj.businessProcessId != null) {
                snag.Business_Process__c = reqObj.businessProcessId;
            }
            if (reqObj.snagName != null) {
                snag.Snag_Name__c = reqObj.snagName;
            }
            if (reqObj.snagComment != null) {
                snag.Snag_Comment__c = reqObj.snagComment;
            }
            if (reqObj.deSnagComment != null) {
                snag.De_Snag_Comment__c = reqObj.deSnagComment;
            }
            if (reqObj.snagLink != null) {
                snag.Snag_Link__c = reqObj.snagLink;
            }
            if (reqObj.priority != null) {
                HandoverQAInspectionValidators.validatePriority(reqObj.priority);
                snag.Priority__c = reqObj.priority;
            }
            if (reqObj.integrationType != null) {
                HandoverQAInspectionValidators.validateIntegrationType(reqObj.integrationType);
                snag.Integration_Type__c = reqObj.integrationType;
            }
            if (reqObj.recordTypeId != null) {
                snag.RecordTypeId = reqObj.recordTypeId;
            }

            if (reqObj.snagType != null && fieldExists('Snagging__c', 'Snag_Type__c')) {
                snag.put('Snag_Type__c', reqObj.snagType);
            }

            if (reqObj.status != null && fieldExists('Snagging__c', 'Status__c')) {
                snag.put('Status__c', reqObj.status);
            }

            update snag;

            response.status = 'Success';
            response.message = 'Snagging record updated successfully';
            response.snaggingId = snag.Id;
            response.recordId = snag.Id;
            RestContext.response.statusCode = 200;
            return response;

        } catch (Exception e) {
            return buildErrorResponse('Failed to update Snagging record', e);
        }
    }

    private static HandoverQAInspectionDtos.ApiResponseWrapper buildErrorResponse(String message, Exception e) {
        HandoverQAInspectionDtos.ApiResponseWrapper response = new HandoverQAInspectionDtos.ApiResponseWrapper();
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
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApiName)) {
            return false;
        }

        Schema.DescribeSObjectResult objDescribe = gd.get(objectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        return fieldMap.containsKey(fieldApiName);
    }
}