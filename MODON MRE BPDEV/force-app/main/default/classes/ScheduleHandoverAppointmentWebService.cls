@RestResource(urlMapping = '/modon/ScheduleHandoveAppointment')
global without sharing class ScheduleHandoverAppointmentWebService {
 
 @HttpPost
global static HandoverMilestoneResponse doPost() {

    try {
        RestRequest req = RestContext.request;

        // Step 1: Deserialize outer wrapper
        Map<String, Object> outerMap = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        // Step 2: Extract requestString
        String requestString = (String) outerMap.get('requestString');

        if (String.isBlank(requestString)) {
            throw new CustomException('Invalid request: requestString is empty');
        }

        // Step 3: Deserialize inner JSON
        BookAppointmentRequestWrapper requestData =
            (BookAppointmentRequestWrapper) JSON.deserialize(
                requestString,
                BookAppointmentRequestWrapper.class
            );

        // Validation
        if (requestData == null ||
            String.isBlank(requestData.workTypeId) ||
            String.isBlank(requestData.territoryId) ||
            String.isBlank(requestData.startTime) ||
            String.isBlank(requestData.endTime) ||
            String.isBlank(requestData.serviceResourceId) ||
            String.isBlank(requestData.handoverDetailsId)) {
            throw new CustomException('Invalid input');
        }

        // Business logic
        BookAppointmentResponseWrapper responseWrapper =
            createServiceAppointment(requestData);

        // Wrap response
        HandoverMilestoneResponse response = new HandoverMilestoneResponse();
        response.responseString = JSON.serialize(responseWrapper);

        return response;

    } catch (Exception ex) {

        HandoverMilestoneResponse response = new HandoverMilestoneResponse();
        response.responseString = null; // or error JSON if needed
        return response;
    }
}
    
    public class BookAppointmentRequestWrapper {
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String handoverDetailsId { get; set; }
    }
    
    
    public class BookAppointmentResponseWrapper {
        public String serviceAppointmentId { get; set; }
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String handoverDetailsId { get; set; }
    }
    
    public static BookAppointmentResponseWrapper createServiceAppointment(BookAppointmentRequestWrapper requestData) {
        BookAppointmentResponseWrapper response = new BookAppointmentResponseWrapper();
        try {
            List<Handover_Details__c> handoverRec = [SELECT Id FROM Handover_Details__c WHERE Id = :requestData.handoverDetailsId];
            if (handoverRec.isEmpty()) {
                throw new CustomException('No Handover Detail Record found.');
            }
            
            Id workOrderRT = Schema.SObjectType.WorkOrder.getRecordTypeInfosByName().get('Handover Appointment').getRecordTypeId();
            WorkOrder workOrderRec = new WorkOrder();
            workOrderRec.ServiceTerritoryId = requestData.territoryId;
            workOrderRec.Status = 'New';
            workOrderRec.RecordTypeId = workOrderRT;
            workOrderRec.Handover_Details__c = requestData.handoverDetailsId;
            workOrderRec.Subject = 'Handover Appointment';
            workOrderRec.WorkTypeId = requestData.workTypeId;
            insert workOrderRec;
            
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
            serviceAppInput.parentRecordId = workOrderRec.Id;
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
            system.debug('serviceResourceId: ' + requestData.serviceResourceId);
            asResourceInput.serviceResourceId = requestData.serviceResourceId;
            asResourceInput.isRequiredResource = true;
            asResourceInput.isPrimaryResource = true;
    
            List<ConnectApi.AssignedResourcesInput> asResourceInputList = new List<ConnectApi.AssignedResourcesInput>();
            asResourceInputList.add(asResourceInput);
            createInput.assignedResources = asResourceInputList;
            }
        
            ConnectApi.ServiceAppointmentOutput appointmentResult = ConnectApi.LightningScheduler.createServiceAppointment(createInput);

            BookAppointmentResponseWrapper responseWrapper = new BookAppointmentResponseWrapper();
            responseWrapper.serviceAppointmentId = appointmentResult.result.serviceAppointmentId;
          
            responseWrapper.workTypeId = requestData.workTypeId;
            responseWrapper.territoryId = requestData.territoryId;
            responseWrapper.startTime = requestData.startTime;
            responseWrapper.endTime = requestData.endTime;
            responseWrapper.serviceResourceId = requestData.serviceResourceId;
            responseWrapper.handoverDetailsId = requestData.handoverDetailsId;

            return responseWrapper;
        } catch (ConnectApi.ConnectApiException ex) {
            throw new CustomException('Error creating service appointment: ' + ex.getMessage());
        } catch (Exception ex) {
            throw new CustomException('Unexpected error: ' + ex.getMessage());
        }
    }
    
      Global class HandoverMilestoneResponse {
        @AuraEnabled public String responseString;
      
    }
    
}