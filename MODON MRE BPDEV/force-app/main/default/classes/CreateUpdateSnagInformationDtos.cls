global class CreateUpdateSnagInformationDtos {

    global class ApiResponseWrapper {
        public String status;
        public String message;
        public String recordId;
        public String businessProcessId;
        public Integer createdCount;
        public Integer updatedCount;
        public List<String> snaggingIds;
        public List<String> errors;

        public ApiResponseWrapper() {
            errors = new List<String>();
            snaggingIds = new List<String>();
            createdCount = 0;
            updatedCount = 0;
        }
    }

    global class CreateSnagInformationRequest {
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
        public String integrationType;

        public List<SnagInformationWrapper> snagList;
    }

    global class CreateDeSnagInformationRequest {
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
        public String integrationType;

        public List<SnagInformationWrapper> snagList;
    }

    global class SnagInformationWrapper {
        public Id snaggingId;
        public String OnsiteSnagID;

        public Id salesOrderId;
        public Id businessProcessId;
        public Id unitId;

        public String snagName;
        public String snagComment;
        public String deSnagComment;
        public String snagLink;
        public String priority;
        public Id recordTypeId;
        public String snagType;
        public String status;
    }
}