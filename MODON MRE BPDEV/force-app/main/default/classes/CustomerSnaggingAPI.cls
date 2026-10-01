@RestResource(urlMapping='/customerSnaggingAPI/*')
global with sharing class CustomerSnaggingAPI {
    
    static final Map<String, String> METHOD_TO_DOC = new Map<String, String> {
        'customer snagging completed' => 'Customer Snagging Letter',
        'customer de snagging completed' => 'Customer De Snagging Letter (RFO)'};
    
    static final Set<String> ALLOWED_TYPES = new Set<String>{
        'application/pdf', 'image/jpeg', 'image/png'};
    
    static final Map<String, String> METHOD_TO_STEP = new Map<String, String>{
        'customer snagging completed' => 'Customer Snagging',
        'contractor rectification completed' => 'Contractor Customer Snag Rectification',
        'contractor re open' => 'Customer De-Snagging',
        'customer de snagging completed' => 'Customer De-Snagging'};
    
    public class SnaggingRequest {
        public String method;
        public String unitNo;
        public HandoverInfo handoverInfo;
        public List<SnagItem> snags;
        public FileAttachment file;
    }
    
    public class HandoverInfo {
        // Customer Snagging fields
        public Integer totalCustomerSnags;
        public Date customerSnagDate;
        public String customerSnagExecutiveId;
        public String contractorName;
        public Integer fixedCustomerSnags;
        
        // Desnagging fields
        public Date customerDeSnagDate;
        public String customerDesnaggingStatus;
        public Date customerDesnaggingCompletedDate;
        public Integer pendingCustomerSnags;
    }
    
    public class SnagItem {
        public String snagId;     
        public String snagName;
        Public String snagStatus;
        public String snagComment;
        public String deSnagComment;
        public String snagRectificationComment;
        public String snagLink;
        public String deSangLink;
        public String snagType;
        public String priority;      
    }
    
    public class FileAttachment {
        public String fileName;
        public String fileBase64;
        public String contentType;
    }
    
    public class SnaggingResponse {
        public String status;
        public String message;
        public String businessProcessId;
        public List<String> errors = new List<String>();
    }
    
    @HttpPost
    global static void doPost() {
        
        RestRequest req = RestContext.request;
        RestResponse resp = RestContext.response;
        SnaggingResponse response = new SnaggingResponse();
        String reqStr = req.requestBody.toString();
        
        try {
            
            SnaggingRequest reqObj = (SnaggingRequest) JSON.deserialize(reqStr, SnaggingRequest.class);
            
            String validationError = validateRequestBody(reqObj);
            if (validationError != null) {
                buildValidationResponse(resp, 400, 'error', validationError);
                return;
            }
            
            //Make sure this way of processing is correct getting unitId.
            SalesOrder__c sr = [SELECT Id, Unit__c FROM SalesOrder__c WHERE Unit__r.Name = :reqObj.unitNo AND Status__c = 'Completed' LIMIT 1] ?? null;
            if (sr == null) {
                buildValidationResponse(resp, 400, 'error', 'No sales order found for the provided unitNo.');
                return;
            }
            
            Business_Process__c bp = [SELECT Id, Name, Current_Business_Process_Step__c, Current_Business_Process_Step__r.Name, Current_Business_Process_Step__r.Sequence__c, 
                                      Current_Business_Process_Step__r.Status__c, Current_Business_process_StepName__c, Sales_Order__c, Unit__c, Handover_Details__c 
                                      FROM Business_Process__c 
                                      WHERE Type__c = 'Handover Units' 
                                      AND Unit__c = :sr.Unit__c AND Sales_Order__c = :sr.Id
                                      AND Current_Business_process_StepName__c = :METHOD_TO_STEP.get(reqObj.method.toLowerCase()) ORDER BY CreatedDate DESC LIMIT 1] ?? null;
            if (bp == null) {
                buildValidationResponse(resp, 400, 'error', 'No Handover Units Business process available for the provided unitNo.');
                return;
            }
            
            if (bp.Handover_Details__c == null) {
                buildValidationResponse(resp, 400, 'error', 'Handover detail record not found in Business process.');
                return;
            }
            
            response = processSnaggingData(bp, reqObj);
            resp.statusCode = response.status == 'success' ? 200 : 500;
            resp.responseBody = Blob.valueOf(JSON.serialize(response));
            
        } catch (Exception e) {
            response.status   = 'error';
            response.message  = e.getMessage();
            response.errors.add(e.getMessage());
            resp.statusCode   = 500;
            resp.responseBody = Blob.valueOf(JSON.serialize(response));
        } finally {
            logApiCall(reqStr, JSON.serialize(response), String.valueOf(resp.statusCode));
        }
        
    }
    
    private static String validateRequestBody(SnaggingRequest reqObj) {
        
        if (String.isBlank(reqObj.unitNo)) return 'unitNo is required.';
        if (String.isBlank(reqObj.method)) return 'method is required.';
        if (!METHOD_TO_STEP.containsKey(reqObj.method.toLowerCase())) return 'Please provide a valid method.';
        if(reqObj.method.toLowerCase()!='ready to inspect')
        if (reqObj.snags == null || reqObj.snags.isEmpty()) return 'At least one snag item is required.';
        if (reqObj.file != null && String.IsNotBlank(reqObj.file.fileBase64) && String.IsBlank(reqObj.file.fileName)) return 'fileName is required';
        
        for (SnagItem si : reqObj.snags) {
            if (String.isBlank(si.snagId) || String.isBlank(si.snagName)) return 'snagId and snagName are required for every snag item.';
        }
        return null;
        
    }
    
    private static SnaggingResponse processSnaggingData(Business_Process__c bp, SnaggingRequest req) {
        
        Set<String> externalIds = new Set<String>();
        for (SnagItem item : req.snags) externalIds.add(item.snagId);
        
        Map<String, Id> existingSnagMap = new Map<String, Id>();
        if (!externalIds.isEmpty()) {
            for (Snagging__c s : [SELECT Id, External_Snag_Id__c FROM Snagging__c WHERE External_Snag_Id__c IN :externalIds]) {
                existingSnagMap.put(s.External_Snag_Id__c, s.Id);
            }
        }
        
        List<Snagging__c> snagToUpsert = new List<Snagging__c>();
        for(SnagItem item : req.snags) {
            Snagging__c s = new Snagging__c();
            s.External_Snag_Id__c = item.snagId;
            if (existingSnagMap.containsKey(item.snagId)) s.Id = existingSnagMap.get(item.snagId);
            if (String.isNotBlank(item.snagName)) s.Snag_Name__c = item.snagName;
            if (String.isNotBlank(item.snagStatus)) s.Status__c = item.snagStatus;
            if (String.isNotBlank(item.snagComment)) s.Snag_Comment__c = item.snagComment;
            if (String.isNotBlank(item.deSnagComment)) s.De_Snag_Comment__c = item.deSnagComment;
            if (String.isNotBlank(item.snagRectificationComment)) s.Snag_Rectification_Comment__c = item.snagRectificationComment;
            if (String.isNotBlank(item.snagLink)) s.SnagLink__c = item.snagLink;
            if (String.isNotBlank(item.deSangLink)) s.De_Snag_Link__c = item.deSangLink;
            if (String.isNotBlank(item.snagType)) s.Snag_Type__c = item.snagType;
            if (String.isNotBlank(item.priority)) s.Priority__c = item.priority;
            if (!existingSnagMap.containsKey(item.snagId)) {
                s.RecordTypeId = Schema.SObjectType.Snagging__c.getRecordTypeInfosByDeveloperName().get('Customer_Snagging').getRecordTypeId();
                s.Business_Process__c = Bp.Id;
                s.Unit__c = Bp.Unit__c;
                s.Sales_Order__c = bp.Sales_Order__c;
            }
            snagToUpsert.add(s);
        }
        
        Handover_Details__c hd = new Handover_Details__c();
        if (req.handoverInfo != null) {
            HandoverInfo info = req.handoverInfo;
            hd.Id = bp.Handover_Details__c;
            
            // Customer Snagging fields
            if (info.totalCustomerSnags != null) hd.Total_Customer_Snags__c = info.totalCustomerSnags;
            if (info.customerSnagDate != null) hd.Customer_Snag_Date__c = info.customerSnagDate;       
            if (String.isNotBlank(info.customerSnagExecutiveId)) hd.Customer_Snag_Executive__c = info.customerSnagExecutiveId;
            if (String.isNotBlank(info.contractorName)) hd.Contractor_Name__c = info.contractorName;
            if (info.fixedCustomerSnags != null) hd.Fixed_Customer_Snags__c = info.fixedCustomerSnags;
            
            // Desnagging fields
            if (info.customerDeSnagDate != null) hd.Customer_De_Sang_Date__c = info.customerDeSnagDate;
            if (String.isNotBlank(info.customerDesnaggingStatus)) hd.Customer_Desnagging_Status__c = info.customerDesnaggingStatus;
            if (info.customerDesnaggingCompletedDate != null) hd.Customer_Desnagging_Date__c = info.customerDesnaggingCompletedDate;
            if (info.pendingCustomerSnags != null) hd.Pending_Customer_Snags__c = info.pendingCustomerSnags;
        }
        
        String methodName = req.method.toLowerCase();
        SnaggingResponse response = new SnaggingResponse();
        Savepoint sp = Database.setSavepoint();
        
        try {
            if(!hd.getPopulatedFieldsAsMap().isEmpty()) update hd;
            if(!snagToUpsert.isEmpty()) upsert snagToUpsert;
            updateBpStepRecord(bp.Id, bp.Current_Business_Process_Step__c, bp.Current_Business_Process_Step__r.Sequence__c, methodName);
            attachFile(bp.Id, methodName, req.file);
            response.status = 'success';
            response.message = bp.Current_Business_process_StepName__c + ' processed successfully.';
        } catch (Exception ex) {
            Database.rollback(sp);
            response.status = 'error';
            response.message = bp.Current_Business_process_StepName__c + ' Process failed.';
            response.errors.add(ex.getMessage());
        }
        response.businessProcessId = bp.Id;
        return response;
        
    }
    
    private static void updateBpStepRecord(Id bpId, Id currentStepId, Decimal currentSequence, String method) {
        
        Boolean isReOpen = method.equalsIgnoreCase('contractor re open');
        Decimal Sequence = isReOpen ? currentSequence - 1 : currentSequence + 1;
        
        List<Business_Process_Step__c> bpSteps = [SELECT Id, Status__c, Sequence__c 
                                                  FROM Business_Process_Step__c
                                                  WHERE Business_Process__c = :bpId
                                                  AND (Id = :currentStepId OR Sequence__c = :Sequence)
                                                  ORDER BY Sequence__c ASC];
        
        List<Business_Process_Step__c> bpsToUpdate = new List<Business_Process_Step__c>();
        
        for (Business_Process_Step__c bps : bpSteps) {
            
            if (bps.Id == currentStepId) {
                bps.Status__c = isReOpen ? 'Required Info' : 'Completed';
                bpsToUpdate.add(bps);
                
            } else if (bps.Sequence__c == Sequence) {
                if (isReOpen) {
                    bps.Status__c = 'Re Open';
                } else if (bps.Status__c == 'Required Info') {
                    bps.Status__c = 'Provided Info';
                } else {
                    bps.Status__c = 'Open';
                }
                bpsToUpdate.add(bps);
            }
            
            if (bpsToUpdate.size() == 2) break;
        }
        
        if (!bpsToUpdate.isEmpty()) update bpsToUpdate;
    }
    
    private static void attachFile(Id bpId, String methodName, FileAttachment file) {
        if (file == null || String.isBlank(file.fileBase64) || String.isBlank(file.fileName)) return;
        
        String docName = METHOD_TO_DOC.get(methodName);
        if (String.isBlank(docName)) return;
        
        Business_Process_Documents__c bpDoc = [SELECT Id 
                                               FROM Business_Process_Documents__c 
                                               WHERE Business_Process__c = :bpId 
                                               AND Name = :docName ORDER BY CreatedDate DESC LIMIT 1] ?? null;
        
        if (bpDoc == null) return;
        
        ContentVersion cv = new ContentVersion();
        cv.Title = file.fileName;
        cv.PathOnClient = file.fileName;
        cv.VersionData = EncodingUtil.base64Decode(file.fileBase64);
        cv.IsMajorVersion = true;
        insert cv;
        
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = bpDoc.Id;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }
    
    private static RestResponse buildValidationResponse(RestResponse resp, Integer httpCode, String status, String message) {
        SnaggingResponse response = new SnaggingResponse();
        response.status  = status;
        response.message = message;
        resp.statusCode = httpCode;
        resp.responseBody = Blob.valueOf(JSON.serialize(response));
        return resp;
    }
    
    @future
    private static void logApiCall(String reqBody, String resBody, String code){
        LoggerService.createAPILog('customerSnaggingAPI', 'CustomerSnaggingAPI', 'doPost', reqBody, reqBody, reqBody, 'Callout Log');
    }

}