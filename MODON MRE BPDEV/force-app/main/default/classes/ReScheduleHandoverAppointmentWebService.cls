@RestResource(urlMapping = '/modon/ReScheduleHandoveAppointment')
global without sharing class ReScheduleHandoverAppointmentWebService {
    
     Global class HandoverMilestoneResponse {
        @AuraEnabled public String responseString; 
    }
    
   @HttpPost
global static HandoverMilestoneResponse doPost() {

    try {
        RestRequest req = RestContext.request;

        // Step 1: Deserialize outer wrapper
        Map<String, Object> outerMap =
            (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        // Step 2: Extract requestString
        String requestString = (String) outerMap.get('requestString');

        if (String.isBlank(requestString)) {
            throw new CustomException('Invalid request: requestString is empty');
        }

        // Step 3: Deserialize inner JSON
        ReScheduleAppointmentRequestWrapper requestData =
            (ReScheduleAppointmentRequestWrapper) JSON.deserialize(
                requestString,
                ReScheduleAppointmentRequestWrapper.class
            );

        // Validation
        if (requestData == null ||
            String.isBlank(requestData.serviceAppointmentId) ||
            String.isBlank(requestData.workTypeId) ||
            String.isBlank(requestData.territoryId) ||
            String.isBlank(requestData.startTime) ||
            String.isBlank(requestData.endTime) ||
            String.isBlank(requestData.serviceResourceId) ||
            String.isBlank(requestData.handoverDetailsId)) {
            throw new CustomException('Invalid input');
        }

        // Business Logic
        ReScheduleAppointmentResponseWrapper responseWrapper =
            createServiceAppointment(requestData);

        // Wrap response
        HandoverMilestoneResponse response = new HandoverMilestoneResponse();
        response.responseString = JSON.serialize(responseWrapper);

        return response;

    } catch (Exception ex) {

        HandoverMilestoneResponse response = new HandoverMilestoneResponse();
        response.responseString = null; // or error JSON
        return response;
    }
}
    
    public class ReScheduleAppointmentRequestWrapper {
        public String serviceAppointmentId { get; set; }
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String handoverDetailsId { get; set; }
    }
    
    
    public class ReScheduleAppointmentResponseWrapper {
        public String serviceAppointmentId { get; set; }
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String handoverDetailsId { get; set; }
    }
    
    public static ReScheduleAppointmentResponseWrapper createServiceAppointment(ReScheduleAppointmentRequestWrapper requestData) {
        ReScheduleAppointmentResponseWrapper response = new ReScheduleAppointmentResponseWrapper();
        try {
            List<ServiceAppointment> sARec = [SELECT Id, ParentRecordId FROM ServiceAppointment WHERE Id = :requestData.serviceAppointmentId];
            if (sARec.isEmpty()) {
                throw new CustomException('No Service Appointment found.');
            }
            
            List<ServiceTerritory> sTRec = [SELECT Id, State, Country, Street, City, PostalCode FROM ServiceTerritory WHERE Id = :requestData.territoryId AND IsActive = true];
            if (sTRec.isEmpty()) {
                throw new CustomException('No Service Territory found.');
            }
            
            List<ConnectApi.ExtendedFieldInput> extendedFieldList = new List<ConnectApi.ExtendedFieldInput>();
            
            ConnectApi.ExtendedFieldInput extendedFieldCity = new ConnectApi.ExtendedFieldInput();
            extendedFieldCity.name = 'City';
            extendedFieldCity.value = sTRec[0].City;
            
            ConnectApi.ExtendedFieldInput extendedFieldState = new ConnectApi.ExtendedFieldInput();
            extendedFieldState.name = 'State';
            extendedFieldState.value = sTRec[0].State;
            
            ConnectApi.ExtendedFieldInput extendedFieldCountry = new ConnectApi.ExtendedFieldInput();
            extendedFieldCountry.name = 'Country';
            extendedFieldCountry.value = sTRec[0].Country;
            
            ConnectApi.ExtendedFieldInput extendedFieldPostalCode = new ConnectApi.ExtendedFieldInput();
            extendedFieldPostalCode.name = 'PostalCode';
            extendedFieldPostalCode.value = sTRec[0].PostalCode;
            
            ConnectApi.ExtendedFieldInput extendedFieldStreet = new ConnectApi.ExtendedFieldInput();
            extendedFieldStreet.name = 'Street';
            extendedFieldStreet.value = sTRec[0].Street;
            
            
            ConnectApi.ExtendedFieldInput extendedFieldApptType = new ConnectApi.ExtendedFieldInput();
            extendedFieldApptType.name = 'AppointmentType';
            extendedFieldApptType.value = 'Handover';
            
            Id handoverRT = Schema.SObjectType.ServiceAppointment.getRecordTypeInfosByName().get('Handover').getRecordTypeId();
            ConnectApi.ExtendedFieldInput extendedFieldRecType = new ConnectApi.ExtendedFieldInput();
            extendedFieldRecType.name = 'RecordTypeId';
            extendedFieldRecType.value = handoverRT;
            
            extendedFieldList.add(extendedFieldCity);
            extendedFieldList.add(extendedFieldState);
            extendedFieldList.add(extendedFieldCountry);
            extendedFieldList.add(extendedFieldPostalCode);
            extendedFieldList.add(extendedFieldStreet);
            extendedFieldList.add(extendedFieldApptType);
            extendedFieldList.add(extendedFieldRecType);
            ConnectApi.ServiceAppointmentInput serviceAppInput = new ConnectApi.ServiceAppointmentInput();
            serviceAppInput.extendedFields = extendedFieldList;
            serviceAppInput.serviceTerritoryId = requestData.territoryId;
            serviceAppInput.workTypeId = requestData.workTypeId;
            serviceAppInput.parentRecordId = sARec[0].parentRecordId;
            String startTimeString = requestData.startTime.substring(0, 19).replace('T', ' ');
            DateTime utcStartDateTime = DateTime.valueOfGmt(startTimeString);
            serviceAppInput.schedStartTime = utcStartDateTime;
            String endTimeString = requestData.endTime.substring(0, 19).replace('T', ' ');
            DateTime utcEndDateTime = DateTime.valueOfGmt(endTimeString);
            serviceAppInput.schedEndTime = utcEndDateTime;
            serviceAppInput.appointmentMode = ConnectApi.SvcApptModeEnum.Regular;
            
            ConnectApi.CreateServiceAppointmentInput createInput = new ConnectApi.CreateServiceAppointmentInput();
            createInput.serviceAppointment = serviceAppInput;
            
            if (!Test.isRunningTest()) {
                ConnectApi.AssignedResourcesInput asResourceInput = new ConnectApi.AssignedResourcesInput();
                asResourceInput.serviceResourceId = requestData.serviceResourceId;
                asResourceInput.isRequiredResource = true;
                asResourceInput.isPrimaryResource = true;
                
                List<ConnectApi.AssignedResourcesInput> asResourceInputList = new List<ConnectApi.AssignedResourcesInput>();
                asResourceInputList.add(asResourceInput);
                createInput.assignedResources = asResourceInputList;
            }

            ConnectApi.ServiceAppointmentOutput appointmentResult = ConnectApi.LightningScheduler.createServiceAppointment(createInput);
            
            ReScheduleAppointmentResponseWrapper responseWrapper = new ReScheduleAppointmentResponseWrapper();
            responseWrapper.serviceAppointmentId = appointmentResult.result.serviceAppointmentId;
          
            responseWrapper.workTypeId = requestData.workTypeId;
            responseWrapper.territoryId = requestData.territoryId;
            responseWrapper.startTime = requestData.startTime;
            responseWrapper.endTime = requestData.endTime;
            responseWrapper.serviceResourceId = requestData.serviceResourceId;
            responseWrapper.handoverDetailsId = requestData.handoverDetailsId;
            ServiceAppointment serAppRec = new ServiceAppointment(Id = appointmentResult.result.serviceAppointmentId, Status = 'Re-scheduled');
            update serAppRec;
            delete sARec;
            return responseWrapper;
        } catch (ConnectApi.ConnectApiException ex) {
            throw new CustomException('Error creating service appointment: ' + ex.getMessage());
        } catch (Exception ex) {
            throw new CustomException('Unexpected error: ' + ex.getMessage());
        }
    }
    
    
}