global class HandoverQAInspectionDtos {
    global class ApiResponseWrapper {
        public String status;
        public String message;
        public String recordId;
        public String businessProcessId;
        public String snaggingId;
        public List<String> errors;

        public ApiResponseWrapper() {
            errors = new List<String>();
        }
    }

    // Save QA Snagging Section under Business_Process__c
    global class SaveSnaggingSectionRequest {
        public Id salesOrderId;
        public Id businessProcessId;
        public Id unitId;
        public String unitName;
        public String salesOrderName;

        public Integer totalQASnags;
        public Date qaSnagDate;
        public Id qaSnagExecutiveId;
        public String qaSnagExecutiveName;
        public String contractorName;
        public Integer fixedQASnags;
        public String qaSnagStatus;
    }

    // Save QA De-Snagging Section under Business_Process__c
    global class SaveDeSnaggingSectionRequest {
        public Id salesOrderId;
        public Id businessProcessId;
        public Id unitId;
        public String unitName;
        public String salesOrderName;

        public Date qaDeSnagDate;
        public String qaDesnaggingStatus;
        public Date qaDesnaggingCompletedDate;
        public Integer fixedQASnags;
        public Integer pendingQASnags;
    }

    // Create Snagging__c
    global class CreateSnagRequest {
        public Id salesOrderId;
        public Id businessProcessId;
        public Id unitId;

        public String snagName;
        public String snagComment;
        public String deSnagComment;
        public String snagLink;
        public String priority;
        public String integrationType;
        public Id recordTypeId;
        public String snagType;
    }

    // Update Snagging__c
    global class UpdateSnagRequest {
        public Id snaggingId;
        public Id salesOrderId;
        public Id businessProcessId;
        public Id unitId;

        public String snagName;
        public String snagComment;
        public String deSnagComment;
        public String snagLink;
        public String priority;
        public String integrationType;
        public Id recordTypeId;
        public String snagType;
        public String status;
    }
}