@RestResource(urlMapping='/qaSnaggingAPI/*')
global without sharing class QASnaggingAPI {
        
    static Map<String, String> methodToStepMap = new Map<String, String>{
        'ready to inspect' => 'QA Snagging',
        'qa snagging completed' => 'QA Snagging',
        'contractor rectification completed' => 'Contractor Snag Rectification',
        'contractor re open' => 'QA Desnagging',
        'de snagging completed' => 'QA Desnagging'};
    
    public class SnaggingRequest {
        public String method;
        public String unitNo;
        public HandoverInfo handoverInfo;
        public List<SnagItem> snags;
    }
    
    public class HandoverInfo {
        // QA Snagging fields
        public String unitReleasedDate;
        public String qaSnagDate;
        public String qaSnagExecutiveId;
        public String contractorName;
        
        // NEW FIELDS
        public String qaSnagExecutiveName;
        public String qaSnagExecutiveEmail;
        public String qaDeSnagExecutiveName;
        public String qaDeSnagExecutiveEmail;
           
        // Desnagging fields
        public String qaDeSnagDate;
        public String qaDesnaggingStatus;
        public String qaDesnaggingCompletedDate;
        public String totalQASnags;
        public String pendingQASnags;
        public String fixedQASnags;
        
         // Approval / Unit Release fields
        public String consultantApprovedName;
        public String consultantApprovalTimestamp;
        public String projectTeamApprovedBy;
        public String projectTeamApprovalTimestamp;
        public String unitReleasedTimestamp;
    }
    
    public class SnagItem {
        public String snagId;
        public String snagName;
        public String snagStatus;
        public String snagComment;
        public String deSnagComment;
        public String snagRectificationComment;
        public String snagLink;
        public String deSangLink;
        public String snagType;
        public String priority;

        // NEW FIELDS
        public String snagOpenedBy;
        public String snagReOpenedBy;
        public String snagReOpenCount;
        public String snagRectifiedBy;
        public String snagOpenedDate;
        public String snagReopenedDate;
        public String snagClosedDate;
        public String snagLocation;
        public String snagRectificationLink;
    }
    
    public class SnaggingResponse {
        public String status;
        public String message;
        public String businessProcessId;
    }
    
    @HttpPost
    global static void doPost() {
        
        RestRequest req = RestContext.request;
        RestResponse resp = RestContext.response;
        SnaggingResponse response = new SnaggingResponse();
        String reqStr = req.requestBody.toString();
        
        try {
            System.debug('*** Request ****' + reqStr);
            SnaggingRequest reqObj = (SnaggingRequest) JSON.deserialize(reqStr, SnaggingRequest.class);
            
            String validationError = validateRequestBody(reqObj);
            
            if (validationError != null) {
                response.status = 'error';
                response.message = validationError;
                response.businessProcessId = null;
                buildValidationResponse(resp, 200, response);
                return;
            }
            
            // Make sure this way of processing is correct getting unitId.
            SalesOrder__c sr = [SELECT Id, Unit__c FROM SalesOrder__c WHERE Unit__r.Name = :reqObj.unitNo AND Status__c = 'Completed' LIMIT 1] ?? null;
            
            if (sr == null) {
                response.status = 'error';
                response.message = 'No sales order found for the provided unitNo.';
                response.businessProcessId = null;
                buildValidationResponse(resp, 200, response);
                return;
            }
            
            if (reqObj.method.toLowerCase() == 'ready to inspect') {         
                Business_Process__c bp = [ SELECT Id,Name,Current_Business_Process_Step__c,Current_Business_Process_Step__r.Name,Current_Business_Process_Step__r.Sequence__c,Current_Business_Process_Step__r.Status__c,
                           Current_Business_process_StepName__c,Sales_Order__c,Unit__c,Handover_Details__c FROM Business_Process__c
                    WHERE Type__c = 'Handover Units'
                    AND Unit__c = :sr.Unit__c
                    AND Sales_Order__c = :sr.Id limit 1
                ];
                
                if (bp == null) {
                    response.status = 'error';
                    response.message = 'No Handover Units Business process available for the provided unitNo.';
                    response.businessProcessId = null;
                    
                    buildValidationResponse(resp, 400, response);
                    return;
                }
            
                if (bp.Handover_Details__c == null) {
                    response.status = 'error';
                    response.message = 'Handover detail record not found in Business process.';
                    response.businessProcessId = bp.Id;
                    
                    buildValidationResponse(resp, 400, response);
                    return;
                }
                
                Handover_Details__c hd = new Handover_Details__c();
                
                if (reqObj.handoverInfo != null) {
                    HandoverInfo info = reqObj.handoverInfo;
                    hd.Id = bp.Handover_Details__c;
                    hd.Unit_QA_Released_Date__c = Date.valueOf(info.unitReleasedDate);
                     // Consultant Approval Details
                    if (String.isNotBlank(info.consultantApprovedName)) {
                        hd.Consultant_Approved_Name__c =info.consultantApprovedName.trim();
                    }
                    
                    if (String.isNotBlank(info.consultantApprovalTimestamp)) {
                        hd.Consultant_Approval_Timestamp__c = parseDateTime(info.consultantApprovalTimestamp);
                    }
                    
                    // Project Team Approval Details
                    if (String.isNotBlank(info.projectTeamApprovedBy)) {
                        hd.Project_Team_Approved_By__c = info.projectTeamApprovedBy.trim();
                    }
                    
                    if (String.isNotBlank(info.projectTeamApprovalTimestamp)) {
                        hd.Project_Team_Approval_Timestamp__c =parseDateTime(info.projectTeamApprovalTimestamp);
                    }
                    
                    // Unit Released Timestamp
                    if (String.isNotBlank(info.unitReleasedTimestamp)) {
                        hd.Unit_Released_Timestamp__c = parseDateTime(info.unitReleasedTimestamp);
                    }
           
                    update hd;
                }

                if (!isQASnaggingStepAlreadyOpen(bp.Id)) {
                    updateBpStepRecord(
                        bp.Id,
                        bp.Current_Business_Process_Step__c,
                        bp.Current_Business_Process_Step__r.Sequence__c,
                        reqObj.method.toLowerCase()
                    );
                }


                response.status = 'success';
                response.message = 'Data Updated';
                response.businessProcessId = bp.Id;
                
                buildValidationResponse(resp, 200, response);
                return;
            }
            
            Business_Process__c bp = [
                SELECT Id,
                       Name,
                       Current_Business_Process_Step__c,
                       Current_Business_Process_Step__r.Name,
                       Current_Business_Process_Step__r.Sequence__c,
                       Current_Business_Process_Step__r.Status__c,
                       Current_Business_process_StepName__c,
                       Sales_Order__c,
                       Unit__c,
                       Handover_Details__c
                FROM Business_Process__c
                WHERE Type__c = 'Handover Units'
                AND Unit__c = :sr.Unit__c
                AND Sales_Order__c = :sr.Id
                AND Current_Business_process_StepName__c =
                    :methodToStepMap.get(reqObj.method.toLowerCase())
                ORDER BY CreatedDate DESC
                LIMIT 1
            ] ?? null;
            
            if (bp == null) {
                response.status = 'error';
                response.message = 'No Handover Units Business process available for the provided unitNo.';
                response.businessProcessId = null;
                
                buildValidationResponse(resp, 400, response);
                return;
            }
            
            if (bp.Handover_Details__c == null) {
                response.status = 'error';
                response.message = 'Handover detail record not found in Business process.';
                response.businessProcessId = bp.Id;
                
                buildValidationResponse(resp, 400, response);
                return;
            }
            
            response = processSnaggingData(bp, reqObj);
            
            resp.statusCode = response.status == 'success' ? 200 : 500;
            resp.addHeader('Content-Type', 'application/json');
            resp.responseBody = Blob.valueOf(JSON.serialize(response));
            
        } catch (Exception e) {
            response.status = 'error';
            response.message = e.getMessage();
            response.businessProcessId = null;
            
            resp.statusCode = 500;
            resp.addHeader('Content-Type', 'application/json');
            resp.responseBody = Blob.valueOf(JSON.serialize(response));
            
        } finally {
            logApiCall(
                reqStr,
                JSON.serialize(response),
                String.valueOf(resp.statusCode)
            );
        }
    }
    
    private static String validateRequestBody(SnaggingRequest reqObj) {
        
        if (String.isBlank(reqObj.unitNo)) {
            return 'unitNo is required.';
        }
        
        if (String.isBlank(reqObj.method)) {
            return 'method is required.';
        }
        
        if (!methodToStepMap.containsKey(reqObj.method.toLowerCase())) {
            return 'Please provide a valid method.';
        }
        
        if(reqObj.method.toLowerCase()=='ready to inspect'){
            return null;
        }
        if (reqObj.snags == null || reqObj.snags.isEmpty()) {
            return 'At least one snag item is required.';
        }
        
        for (SnagItem si : reqObj.snags) {
            if (String.isBlank(si.snagId) || String.isBlank(si.snagName)) {
                return 'snagId and snagName are required for every snag item.';
            }
        }
        
        return null;
    }
    
    private static SnaggingResponse processSnaggingData(
        Business_Process__c bp,
        SnaggingRequest req
    ) {
        
        Set<String> externalIds = new Set<String>();
        
        for (SnagItem item : req.snags) {
            externalIds.add(item.snagId);
        }
        
        Map<String, Id> existingSnagMap = new Map<String, Id>();
        
        if (!externalIds.isEmpty()) {
            for (Snagging__c s : [
                SELECT Id, External_Snag_Id__c
                FROM Snagging__c
                WHERE External_Snag_Id__c IN :externalIds
            ]) {
                existingSnagMap.put(s.External_Snag_Id__c, s.Id);
            }
        }
        
        List<Snagging__c> snagToUpsert = new List<Snagging__c>();
        
        for (SnagItem item : req.snags) {
            Snagging__c s = new Snagging__c();
            s.External_Snag_Id__c = item.snagId;
            
            if (existingSnagMap.containsKey(item.snagId)) {
                s.Id = existingSnagMap.get(item.snagId);
            }
            
            if (String.isNotBlank(item.snagName)) {
                s.Snag_Name__c = item.snagName;
            }
            
            if (String.isNotBlank(item.snagStatus)) {
                s.Status__c = item.snagStatus;
            }
            
            if (String.isNotBlank(item.snagComment)) {
                s.Snag_Comment__c = item.snagComment;
            }
            
            if (String.isNotBlank(item.deSnagComment)) {
                s.De_Snag_Comment__c = item.deSnagComment;
            }
            
            if (String.isNotBlank(item.snagRectificationComment)) {
                s.Snag_Rectification_Comment__c =
                    item.snagRectificationComment;
            }
            
            if (String.isNotBlank(item.snagLink)) {
                s.SnagLink__c = item.snagLink;
            }
            
            if (String.isNotBlank(item.deSangLink)) {
                s.De_Snag_Link__c = item.deSangLink;
            }
            
            if (String.isNotBlank(item.snagType)) {
                s.Snag_Type__c = item.snagType;
            }
            
            if (String.isNotBlank(item.priority)) {
                s.Priority__c = item.priority;
            }

            if (String.isNotBlank(item.snagOpenedBy)) {
                s.Snag_Opened_By__c = item.snagOpenedBy;
            }

            if (String.isNotBlank(item.snagReOpenedBy)) {
                s.Snag_Re_Opened_By__c = item.snagReOpenedBy;
            }

            if (String.isNotBlank(item.snagReOpenCount)) {
                s.Snag_Re_Open_Count__c = Integer.valueOf(item.snagReOpenCount);
            }

            if (String.isNotBlank(item.snagRectifiedBy)) {
                s.Snag_Rectified_By__c = item.snagRectifiedBy;
            }

            if (String.isNotBlank(item.snagOpenedDate)) {
                s.Snag_Opened_Date__c = parseDateTime(item.snagOpenedDate);
            }

            if (String.isNotBlank(item.snagReopenedDate)) {
                s.Snag_Reopened_Date__c = parseDateTime(item.snagReopenedDate);
            }

            if (String.isNotBlank(item.snagClosedDate)) {
                s.Snag_Closed_Date__c = parseDateTime(item.snagClosedDate);
            }

            if (String.isNotBlank(item.snagLocation)) {
                s.Snag_Location__c = item.snagLocation;
            }

            if (String.isNotBlank(item.snagRectificationLink)) {
                s.Snag_Rectification_Link__c = item.snagRectificationLink;
            }

            if (!existingSnagMap.containsKey(item.snagId)) {
                s.RecordTypeId =
                    Schema.SObjectType.Snagging__c
                        .getRecordTypeInfosByDeveloperName()
                        .get('QA_Snagging')
                        .getRecordTypeId();
                
                s.Business_Process__c = bp.Id;
                s.Unit__c = bp.Unit__c;
                s.Sales_Order__c = bp.Sales_Order__c;
            }
            
            snagToUpsert.add(s);
        }
        
        Handover_Details__c hd = new Handover_Details__c();
        
        if (req.handoverInfo != null) {
            HandoverInfo info = req.handoverInfo;
            hd.Id = bp.Handover_Details__c;
            
            
            // QA Snagging fields
            if (info.totalQASnags != null && info.totalQASnags != '') {
                hd.Total_QA_Snags__c = Integer.valueOf(info.totalQASnags);
            }
            
            System.debug('**** info.qaSnagDate ***' + info.qaSnagDate);
            
            if (info.qaSnagDate != null && info.qaSnagDate != '') {
                hd.QA_snag_date__c =Date.valueOf(info.qaSnagDate.trim());
            }
            
            if (String.isNotBlank(info.qaSnagExecutiveId)) {
                hd.QA_Snag_Executive__c = info.qaSnagExecutiveId;
            }
            
            if (String.isNotBlank(info.contractorName)) {
                hd.Contractor_Name__c = info.contractorName;
            }
            
            if (info.fixedQASnags != null && info.fixedQASnags != '') {
                hd.Fixed_QA_Snags__c =Integer.valueOf(info.fixedQASnags);
            }
            
            // Desnagging fields
            if (info.qaDeSnagDate != null && info.qaDeSnagDate != '') {
                hd.QA_de_sang_date__c =
                    Date.valueOf(info.qaDeSnagDate);
            }
            
            if (String.isNotBlank(info.qaDesnaggingStatus)) {
                hd.QA_Desnagging_Status__c =
                    info.qaDesnaggingStatus;
            }
            
            if (
                info.qaDesnaggingCompletedDate != null &&
                info.qaDesnaggingCompletedDate != ''
            ) {
                hd.QA_Desnagging_Date__c =
                    Date.valueOf(info.qaDesnaggingCompletedDate);
            }
            
            if (info.pendingQASnags != null && info.pendingQASnags != '') {
                hd.Pending_QA_Snags__c =
                    Integer.valueOf(info.pendingQASnags);
            }
            
            // QA Snag Executive Details
            if (String.isNotBlank(info.qaSnagExecutiveName)) {
                hd.QA_Snag_Executive_Name__c =
                    info.qaSnagExecutiveName;
            }
            
            if (String.isNotBlank(info.qaSnagExecutiveEmail)) {
                hd.QA_Snag_Executive_Email__c =
                    info.qaSnagExecutiveEmail;
            }
            
            // QA De-Snag Executive Details
            if (String.isNotBlank(info.qaDeSnagExecutiveName)) {
                hd.QA_De_Snag_Executive_Name__c =
                    info.qaDeSnagExecutiveName;
            }
            
            if (String.isNotBlank(info.qaDeSnagExecutiveEmail)) {
                hd.QA_De_Snag_Executive_Email__c =
                    info.qaDeSnagExecutiveEmail;
            }
        }
        
        SnaggingResponse response = new SnaggingResponse();
        Savepoint sp = Database.setSavepoint();
        
        try {
            if (!hd.getPopulatedFieldsAsMap().isEmpty()) {
                update hd;
            }
            
            if (!snagToUpsert.isEmpty()) {
                upsert snagToUpsert;
            }
            
            updateBpStepRecord(
                bp.Id,
                bp.Current_Business_Process_Step__c,
                bp.Current_Business_Process_Step__r.Sequence__c,
                req.method.toLowerCase()
            );
            
            response.status = 'success';
            response.message =
                bp.Current_Business_process_StepName__c +
                ' processed successfully.';
            
        } catch (Exception ex) {
            Database.rollback(sp);
            
            response.status = 'error';
            response.message =
                bp.Current_Business_process_StepName__c +
                ' Process failed.';
        }
        
        response.businessProcessId = bp.Id;
        return response;
    }
    
    // Returns true when the QA Snagging step for this Business Process is already Open,
    // so a repeated/duplicate "ready to inspect" call does not advance the process past
    // QA Snagging before the actual inspection has taken place.
    private static Boolean isQASnaggingStepAlreadyOpen(Id bpId) {

        List<Business_Process_Step__c> qaSnaggingSteps = [
            SELECT Id, Status__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :bpId
            AND Name = 'QA Snagging'
            LIMIT 1
        ];

        return !qaSnaggingSteps.isEmpty() && qaSnaggingSteps[0].Status__c == 'Open';
    }

    private static void updateBpStepRecord(
        Id bpId,
        Id currentStepId,
        Decimal currentSequence,
        String method
    ) {
        
        Boolean isReOpen =
            method.equalsIgnoreCase('contractor re open');
        
        Decimal sequence =
            isReOpen
            ? currentSequence - 1
            : currentSequence + 1;
        
        List<Business_Process_Step__c> bpSteps = [
            SELECT Id, Status__c, Sequence__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :bpId
            AND (
                Id = :currentStepId
                OR Sequence__c = :sequence
            )
            ORDER BY Sequence__c ASC
        ];
        
        List<Business_Process_Step__c> bpsToUpdate =
            new List<Business_Process_Step__c>();
        
        for (Business_Process_Step__c bps : bpSteps) {
            
            if (bps.Id == currentStepId) {
                bps.Status__c =
                    isReOpen ? 'Required Info' : 'Completed';
                
                bpsToUpdate.add(bps);
                
            } else if (bps.Sequence__c == sequence) {
                
                if (isReOpen) {
                    bps.Status__c = 'Re Open';
                    
                } else if (bps.Status__c == 'Required Info') {
                    bps.Status__c = 'Provided Info';
                    
                } else {
                    bps.Status__c = 'Open';
                }
                
                bpsToUpdate.add(bps);
            }
            
            if (bpsToUpdate.size() == 2) {
                break;
            }
        }
        
        if (!bpsToUpdate.isEmpty()) {
            update bpsToUpdate;
        }
    }
    
    private static RestResponse buildValidationResponse(
        RestResponse resp,
        Integer httpCode,
        SnaggingResponse response
    ) {
        resp.statusCode = httpCode;
        resp.addHeader('Content-Type', 'application/json');
        resp.responseBody = Blob.valueOf(JSON.serialize(response));
        return resp;
    }
    
    @future
    private static void logApiCall(
        String reqBody,
        String resBody,
        String code
    ) {
        LoggerService.createAPILog(
            'qaSnaggingAPI',
            'QASnaggingAPI',
            'doPost',
            reqBody,
            reqBody,
            reqBody,
            'Callout Log'
        );
    }
    
private static Datetime parseDateTime(String value) {
    if (String.isBlank(value)) {
        return null;
    }

    String dtValue = value.trim();

    try {
        // Handle ISO format:
        // 2026-08-12T10:30:00Z
        // 2026-08-12T10:30:00.000Z
        if (dtValue.contains('T')) {
            dtValue = dtValue.replace('T', ' ');

            if (dtValue.endsWith('Z')) {
                dtValue = dtValue.substring(0, dtValue.length() - 1);
            }

            // Remove milliseconds if provided
            if (dtValue.contains('.')) {
                dtValue = dtValue.substring(0, dtValue.indexOf('.'));
            }

            return Datetime.valueOfGmt(dtValue);
        }

        // Handle Salesforce format:
        // 2026-08-12 10:30:00
        return Datetime.valueOf(dtValue);

    } catch (Exception e) {
        throw new IllegalArgumentException(
            'Invalid datetime value: ' + value
        );
    }
}
    
    
}