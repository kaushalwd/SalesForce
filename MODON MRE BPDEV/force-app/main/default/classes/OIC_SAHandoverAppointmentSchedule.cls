/**********************************************************************************************************************
* Name               : OIC_SAHandoverAppointmentSchedule                                                        
* Description        : This class is used to create a appointment.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft       
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/handover/appointment/schedule/*')
global class OIC_SAHandoverAppointmentSchedule {

    public class CustomException extends Exception {}
    
    @HttpPost
    global static void scheduleHandoverAppointment() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        ScheduleAppointmentRequest obj_SchAppointmentRequest = new ScheduleAppointmentRequest();
        ScheduleAppointmentResponse obj_SchAppointmentResponse = new ScheduleAppointmentResponse();
        String requestId = String.valueOf(UUID.randomUUID());
        restRequest.addHeader('Content-Type', 'application/json');
        obj_SchAppointmentRequest = (ScheduleAppointmentRequest)System.JSON.deserialize(restRequest.requestBody.toString(), 
                                                                                        ScheduleAppointmentRequest.class);
        System.debug('OIC_SAHandoverAppointmentSchedule >>>> SchAppointmentRequest >> '+System.JSON.serialize(obj_SchAppointmentRequest));
        try{
            // 2. Strict Payload Validation Checks
            if (obj_SchAppointmentRequest == null || String.isBlank(obj_SchAppointmentRequest.ScheduleType)) {
                returnErrorAPI.returnError(restResponse, requestId, 'Invalid payload: Missing ScheduleType parameters.', 200);
                return;
            }
            String actionType = obj_SchAppointmentRequest.ScheduleType;
            // Validate requirements for Schedule & Reschedule actions
            if (actionType.equalsIgnoreCase('Schedule') || actionType.equalsIgnoreCase('Reschedule')) {
                    if (String.isBlank(obj_SchAppointmentRequest.WorkTypeId) || String.isBlank(obj_SchAppointmentRequest.TerritoryId) ||
                        String.isBlank(obj_SchAppointmentRequest.StartTime) || String.isBlank(obj_SchAppointmentRequest.EndTime) ||
                        String.isBlank(obj_SchAppointmentRequest.ServiceResourceId) || String.isBlank(obj_SchAppointmentRequest.HandoverDetailsId)) {
                        returnErrorAPI.returnError(restResponse, requestId, actionType + ' request parameters failed validation.', 200);
                        return;
                    }
             }
             // Validate specialized requirements for Reschedule & Cancel actions
             if ((actionType.equalsIgnoreCase('Reschedule') || actionType.equalsIgnoreCase('Cancel')) && 
                    String.isBlank(obj_SchAppointmentRequest.ServiceAppointmentId)) {
                    returnErrorAPI.returnError(restResponse, requestId, actionType + ' requires a valid ServiceAppointmentId.', 200);
                    return;
             }
             if (actionType.equalsIgnoreCase('Cancel') && String.isBlank(obj_SchAppointmentRequest.CancellationReason)) {
                    returnErrorAPI.returnError(restResponse, requestId, 'Cancel action requires a explicit CancellationReason value.', 200);
                    return;
             }
            
            if(obj_SchAppointmentRequest.ScheduleType == 'Schedule'){
                obj_SchAppointmentResponse = createServiceAppointment(obj_SchAppointmentRequest);
            } else if(obj_SchAppointmentRequest.ScheduleType == 'Reschedule'){
                obj_SchAppointmentResponse = rescheduleServiceAppointment(obj_SchAppointmentRequest);
            } else if(obj_SchAppointmentRequest.ScheduleType == 'Cancel'){
                obj_SchAppointmentResponse = cancelAppointment(obj_SchAppointmentRequest);
            } else {}
            APIResponse response = new APIResponse('success', requestId, obj_SchAppointmentResponse, null);
            restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.statusCode = 200;
        }catch (CustomException ce) {
            System.debug(LoggingLevel.WARN, 'Business Validation Exception: ' + ce.getMessage());
            returnErrorAPI.returnError(restResponse, requestId, ce.getMessage(), 200);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Global Crash: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            returnErrorAPI.returnError(restResponse, requestId, 'Engine Processing Failure: ' + e.getMessage(), 200);
        }        
    }  
    
    public static ScheduleAppointmentResponse createServiceAppointment(ScheduleAppointmentRequest requestData) {
        ScheduleAppointmentResponse response = new ScheduleAppointmentResponse();
        System.Savepoint sp = Database.setSavepoint();
        try {
            List<Handover_Details__c> handoverRec = [SELECT Id FROM Handover_Details__c WHERE Id = :requestData.HandoverDetailsId];
            if (handoverRec.isEmpty()) {
                throw new CustomException('No Handover Detail Record found.');
            }
            
            Id workOrderRT = Schema.SObjectType.WorkOrder.getRecordTypeInfosByName().get('Handover Appointment').getRecordTypeId();
            WorkOrder workOrderRec = new WorkOrder();
            workOrderRec.ServiceTerritoryId = requestData.TerritoryId;
            workOrderRec.Status = 'New';
            workOrderRec.RecordTypeId = workOrderRT;
            workOrderRec.Handover_Details__c = requestData.HandoverDetailsId;
            workOrderRec.Subject = 'Handover Appointment';
            workOrderRec.WorkTypeId = requestData.WorkTypeId;
            insert workOrderRec;
            
            // Build Extended Parameter Payloads
            List<ConnectApi.ExtendedFieldInput> extendedFieldList = buildExtendedFields(requestData);
            
            // Construct Core ConnectAPI Envelope
            ConnectApi.ServiceAppointmentInput serviceAppInput = new ConnectApi.ServiceAppointmentInput();
            serviceAppInput.extendedFields = extendedFieldList;
            serviceAppInput.parentRecordId = workOrderRec.Id;
            serviceAppInput.workTypeId = requestData.WorkTypeId;
            serviceAppInput.serviceTerritoryId = requestData.TerritoryId;
            //String startTimeString = requestData.StartTime.substring(0, 19).replace('T', ' ');
            //DateTime utcStartDateTime = DateTime.valueOfGmt(requestData.StartTime);
            DateTime utcStartDateTime = (DateTime) JSON.deserialize('"' + requestData.StartTime + '"', DateTime.class);
            System.debug('>>>>>>> utcStartDateTime >>>> '+utcStartDateTime);
            serviceAppInput.schedStartTime = utcStartDateTime;
            //String endTimeString = requestData.EndTime.substring(0, 19).replace('T', ' ');
            //DateTime utcEndDateTime = DateTime.valueOfGmt(requestData.EndTime);
            DateTime utcEndDateTime = (DateTime) JSON.deserialize('"' + requestData.EndTime + '"', DateTime.class);
            System.debug('>>>>>>> utcEndDateTime >>>> '+utcEndDateTime);
            serviceAppInput.schedEndTime = utcEndDateTime;
            serviceAppInput.appointmentMode = ConnectApi.SvcApptModeEnum.Regular;
            
            ConnectApi.CreateServiceAppointmentInput createInput = new ConnectApi.CreateServiceAppointmentInput();
            createInput.serviceAppointment = serviceAppInput;
            
            if (!Test.isRunningTest()) {
            ConnectApi.AssignedResourcesInput asResourceInput = new ConnectApi.AssignedResourcesInput();
            system.debug('serviceResourceId: ' + requestData.ServiceResourceId);
            asResourceInput.serviceResourceId = requestData.ServiceResourceId;
            asResourceInput.isRequiredResource = true;
            asResourceInput.isPrimaryResource = true;
    
            List<ConnectApi.AssignedResourcesInput> asResourceInputList = new List<ConnectApi.AssignedResourcesInput>();
            asResourceInputList.add(asResourceInput);
            createInput.assignedResources = asResourceInputList;
            }
        	
            ConnectApi.ServiceAppointmentOutput appointmentResult = ConnectApi.LightningScheduler.createServiceAppointment(createInput);

            response.ServiceAppointmentId = appointmentResult.result.serviceAppointmentId;            
            
        } catch (ConnectApi.ConnectApiException ex) {
            Database.rollback(sp);
            throw new CustomException('Error creating service appointment: ' + ex.getMessage());
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new CustomException('Unexpected error: ' + ex.getMessage());
        }
       return response; 
    }
    public static ScheduleAppointmentResponse rescheduleServiceAppointment(ScheduleAppointmentRequest requestData) {
        ScheduleAppointmentResponse response = new ScheduleAppointmentResponse();
        System.Savepoint sp = Database.setSavepoint();
        try {
            List<ServiceAppointment> existingAppts = [SELECT Id, parentRecordId FROM ServiceAppointment WHERE Id = :requestData.ServiceAppointmentId LIMIT 1];
            if (existingAppts.isEmpty()) {
                throw new CustomException('Target Service Appointment record missing for ID: ' + requestData.ServiceAppointmentId);
            }
    
            // Build Extended Fields dictionary configurations
            List<ConnectApi.ExtendedFieldInput> extendedFieldList = buildExtendedFields(requestData);
            
            ConnectApi.ServiceAppointmentInput serviceAppInput = new ConnectApi.ServiceAppointmentInput();
            serviceAppInput.extendedFields = extendedFieldList;
            serviceAppInput.serviceTerritoryId = requestData.TerritoryId;
            serviceAppInput.workTypeId = requestData.WorkTypeId;
            serviceAppInput.parentRecordId = existingAppts.get(0).parentRecordId;
            //String startTimeString = requestData.StartTime.substring(0, 19).replace('T', ' ');
            //DateTime utcStartDateTime = DateTime.valueOfGmt(startTimeString);
            DateTime utcStartDateTime = (DateTime) JSON.deserialize('"' + requestData.StartTime + '"', DateTime.class);
            serviceAppInput.schedStartTime = utcStartDateTime;
            //String endTimeString = requestData.EndTime.substring(0, 19).replace('T', ' ');
            //DateTime utcEndDateTime = DateTime.valueOfGmt(endTimeString);
            DateTime utcEndDateTime = (DateTime) JSON.deserialize('"' + requestData.EndTime + '"', DateTime.class);
            serviceAppInput.schedEndTime = utcEndDateTime;
            serviceAppInput.appointmentMode = ConnectApi.SvcApptModeEnum.Regular;
            
            ConnectApi.CreateServiceAppointmentInput createInput = new ConnectApi.CreateServiceAppointmentInput();
            createInput.serviceAppointment = serviceAppInput;
            
            if (!Test.isRunningTest()) {
                ConnectApi.AssignedResourcesInput asResourceInput = new ConnectApi.AssignedResourcesInput();
                asResourceInput.serviceResourceId = requestData.ServiceResourceId;
                asResourceInput.isRequiredResource = true;
                asResourceInput.isPrimaryResource = true;
                
                List<ConnectApi.AssignedResourcesInput> asResourceInputList = new List<ConnectApi.AssignedResourcesInput>();
                asResourceInputList.add(asResourceInput);
                createInput.assignedResources = asResourceInputList;
            }

            ConnectApi.ServiceAppointmentOutput appointmentResult = ConnectApi.LightningScheduler.createServiceAppointment(createInput);
            
            ServiceAppointment serAppRec = new ServiceAppointment(Id = appointmentResult.result.serviceAppointmentId, Status = 'Re-scheduled');
            update serAppRec;
            delete existingAppts;
            
            response.serviceAppointmentId = appointmentResult.result.serviceAppointmentId;
            return response;
        } catch (ConnectApi.ConnectApiException ex) {
            Database.rollback(sp);
            throw new CustomException('Error creating service appointment: ' + ex.getMessage());
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new CustomException('Unexpected error: ' + ex.getMessage());
        }
    }
    
    public static ScheduleAppointmentResponse cancelAppointment(ScheduleAppointmentRequest requestData){
        ScheduleAppointmentResponse response = new ScheduleAppointmentResponse();
        System.Savepoint sp = Database.setSavepoint();
        try{
            ServiceAppointment serApp = new ServiceAppointment();
            serApp.Id = requestData.ServiceAppointmentId;
            serApp.cancellationReason = requestData.CancellationReason;
            serApp.Status = 'Canceled';
            update serApp;
            
            response.ServiceAppointmentId = requestData.ServiceAppointmentId;
            response.CancellationStatus = 'Success';
            return response;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error in cancelAppointment: ' + e.getMessage());
            throw new CustomException('Error while cancelling the Service Appointment: ' + e.getMessage());
        }
    }
    
    global class ScheduleAppointmentRequest{
        public String ScheduleType;
        public String WorkTypeId;
        public String TerritoryId;
        public String StartTime;
        public String EndTime;
        public String ServiceResourceId;
        public String HandoverDetailsId;
        public String ServiceAppointmentId;
        public String CancellationReason;
        public String UnitId;
        public String ServiceRequestId;        
    }
   global class ScheduleAppointmentResponse {
        public String ServiceAppointmentId;
        public String CancellationStatus;
    }
    
   global static List<ConnectApi.ExtendedFieldInput> buildExtendedFields(ScheduleAppointmentRequest requestData) {
       if(requestData == null){
           return null;
       }
       String territoryId = String.isNotBlank(requestData.TerritoryId)?requestData.TerritoryId:'';
       List<ConnectApi.ExtendedFieldInput> extendedFieldList = new List<ConnectApi.ExtendedFieldInput>();
       
       List<ServiceTerritory> sTRec = [SELECT Id, State, Country, Street, City, PostalCode FROM ServiceTerritory 
                     				   WHERE Id = :territoryId AND IsActive = true];
       
       if (sTRec.isEmpty()) {
           throw new CustomException('Service Territory matched location is inactive or invalid for ID: ' + territoryId);
       }
       
       ServiceTerritory activeTerritory = sTRec[0];
       Map<String, Object> addressFieldMap = new Map<String, Object>{
           'City'       => activeTerritory.City,
           'State'      => activeTerritory.State,
           'Country'    => activeTerritory.Country,
           'PostalCode' => activeTerritory.PostalCode,
           'Street'     => activeTerritory.Street};
               
       for (String fieldName : addressFieldMap.keySet()) {
            Object fieldValue = addressFieldMap.get(fieldName);
           if (fieldValue != null) {
               ConnectApi.ExtendedFieldInput extendedField = new ConnectApi.ExtendedFieldInput();
               extendedField.name = fieldName;
               extendedField.value = (String)fieldValue;
               extendedFieldList.add(extendedField);
           }
       }
       ConnectApi.ExtendedFieldInput extendedFieldApptType = new ConnectApi.ExtendedFieldInput();
       extendedFieldApptType.name = 'AppointmentType';
       extendedFieldApptType.value = 'Handover';
       extendedFieldList.add(extendedFieldApptType);
       Id handoverRT = Schema.SObjectType.ServiceAppointment.getRecordTypeInfosByDeveloperName().get('Handover')?.getRecordTypeId();
       if (handoverRT != null) {
           ConnectApi.ExtendedFieldInput extendedFieldRecType = new ConnectApi.ExtendedFieldInput();
           extendedFieldRecType.name = 'RecordTypeId';
           extendedFieldRecType.value = handoverRT;
           extendedFieldList.add(extendedFieldRecType);
       }
       if(String.isNotBlank(requestData.ServiceResourceId)){
           ConnectApi.ExtendedFieldInput extendedFieldSRType = new ConnectApi.ExtendedFieldInput();
           extendedFieldSRType.name = 'ServiceResourceId__c';
           extendedFieldSRType.value = requestData.ServiceResourceId;
           extendedFieldList.add(extendedFieldSRType);
       }
	   if(String.isNotBlank(requestData.UnitId)){
           ConnectApi.ExtendedFieldInput extendedFieldUnitIdType = new ConnectApi.ExtendedFieldInput();
           extendedFieldUnitIdType.name = 'UnitId__c';
           extendedFieldUnitIdType.value = requestData.UnitId;
           extendedFieldList.add(extendedFieldUnitIdType);
       }       
       return extendedFieldList;
   } 
}