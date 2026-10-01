@RestResource(urlMapping = '/Modon/ReScheduleServiceAppointment')
global without sharing class HandoverRescheduleAppointmentWebService {
    
    /*
    @HttpPost
    global static void doPost() {
        RestContextHandler handler = new RestContextHandler(true);
        try {
            RestRequest req = RestContext.request;
            ReScheduleAppointmentRequestWrapper requestData = (ReScheduleAppointmentRequestWrapper) JSON.deserialize(req.requestBody.toString(), ReScheduleAppointmentRequestWrapper.class);           
            if (requestData == null || String.isBlank(requestData.serviceAppointmentId) || String.isBlank(requestData.workTypeId) || String.isBlank(requestData.territoryId) || String.isBlank(requestData.startTime) || String.isBlank(requestData.endTime) || (!Test.isRunningTest() && String.isBlank(requestData.serviceResourceId)) || String.isBlank(requestData.unitId) || String.isBlank(requestData.serviceRequestId)) {
                throw new CustomException('Invalid input');
            }
            handler.response.data = createServiceAppointment(requestData);
            handler.response.success = true;
            handler.finalize();
            
        } catch (CustomException ex) {
            handler.response.success = false;
            handler.response.statusCode = 400;
            handler.response.message = ex.getMessage();
            handler.finalize(ex);
            
        } catch (Exception ex) {
            handler.response.success = false;
           // handler.response.statusCode = Constants.STATUS_CODE_SYSTEM_ERROR;
            //handler.response.message = CustomerAPIConstants.MESSAGE_GENERIC_ERROR;
            handler.finalize(ex);
        }
    }
    
    public class ReScheduleAppointmentRequestWrapper {
        public String serviceAppointmentId { get; set; }
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String unitId { get; set; }
        public String serviceRequestId { get; set; }
        public HomeOrientationPreferences homeOrientationtPreferences {get;set;}
    }
    
    
    public class ReScheduleAppointmentResponseWrapper {
        public String serviceAppointmentId { get; set; }
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String unitId { get; set; }
        public String serviceRequestId { get; set; }
        public String appointmentType;
        public String virtualURL;
    }
    
    //Added by Tajinkumar
    public class HomeOrientationPreferences {
        public List<String> homeOrientationAttendees {get;set;}
        public String hoAppointmentsOther {get;set;}
        public List<String> specialAccommodations {get;set;}
        public String specialAccommodationsOther {get;set;}
        public String keyCollectionPreference {get;set;}
        public List<String> postHandoverContactPreferences {get;set;}
        public String mortgageResaleAdvisorServices {get;set;}
        public List<String> personalizedMoveInOffers {get;set;}
        public String smartInstallationPreference {get;set;}
        public List<String> minorAdjustments {get;set;}
        public String minorAdjustmentsOther {get;set;}
    }
    
    public static ReScheduleAppointmentResponseWrapper createServiceAppointment(ReScheduleAppointmentRequestWrapper requestData) {
        ReScheduleAppointmentResponseWrapper response = new ReScheduleAppointmentResponseWrapper();
        try {
            List<ServiceAppointment> sARec = [SELECT Id, ParentRecordId FROM ServiceAppointment WHERE Id = :requestData.serviceAppointmentId];
            if (sARec.isEmpty()) {
                throw new CustomException('No Service Appointment found.');
            }

            List<HexaBPM__Service_Request__c> sRRec = [SELECT Id, HandoverDetail__c, SalesOrder__r.Account__c, SalesOrder__r.Contact__c FROM HexaBPM__Service_Request__c WHERE Id = :requestData.serviceRequestId];
            if (sRRec.isEmpty()) {
                throw new CustomException('No matching Service Request found.');
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
            //DateTime scheduledStartTime = utcStartDateTime.addHours(4);
            serviceAppInput.schedStartTime = utcStartDateTime;
            String endTimeString = requestData.endTime.substring(0, 19).replace('T', ' ');
            DateTime utcEndDateTime = DateTime.valueOfGmt(endTimeString);
            //DateTime scheduledEndtTime = utcEndDateTime.addHours(4);
            serviceAppInput.schedEndTime = utcEndDateTime;
            serviceAppInput.appointmentMode = ConnectApi.SvcApptModeEnum.Regular;
            
            ConnectApi.CreateServiceAppointmentInput createInput = new ConnectApi.CreateServiceAppointmentInput();
            createInput.serviceAppointment = serviceAppInput;
            ConnectApi.ServiceAppointmentOutput appointmentResult;
            
            if (!Test.isRunningTest()) {
                ConnectApi.AssignedResourcesInput asResourceInput = new ConnectApi.AssignedResourcesInput();
                system.debug('serviceResourceId: ' + requestData.serviceResourceId);
                asResourceInput.serviceResourceId = requestData.serviceResourceId;
                asResourceInput.isRequiredResource = true;
                asResourceInput.isPrimaryResource = true;
                
                List<ConnectApi.AssignedResourcesInput> asResourceInputList = new List<ConnectApi.AssignedResourcesInput>();
                asResourceInputList.add(asResourceInput);
                createInput.assignedResources = asResourceInputList;
                appointmentResult = ConnectApi.LightningScheduler.createServiceAppointment(createInput);
            }

            //ConnectApi.ServiceAppointmentOutput appointmentResult = ConnectApi.LightningScheduler.createServiceAppointment(createInput);
            
            ReScheduleAppointmentResponseWrapper responseWrapper = new ReScheduleAppointmentResponseWrapper();
            responseWrapper.serviceAppointmentId =  !Test.isRunningTest() ?  appointmentResult.result.serviceAppointmentId : null;
          
            responseWrapper.workTypeId = requestData.workTypeId;
            responseWrapper.territoryId = requestData.territoryId;
            responseWrapper.startTime = requestData.startTime;
            responseWrapper.endTime = requestData.endTime;
            responseWrapper.serviceResourceId = requestData.serviceResourceId;
            responseWrapper.unitId = requestData.unitId;
            responseWrapper.serviceRequestId = requestData.serviceRequestId;
            
            ServiceAppointment serAppRec = new ServiceAppointment(Status = 'Re-scheduled');
            // Added by Tajinkumar
            if(requestData.homeOrientationtPreferences != null) {
                Map<String,Object> requestBody = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(requestData.homeOrientationtPreferences));
                Map<String,Home_Orientation_Field_Configuration__mdt> homeOrtFieldConfig = Home_Orientation_Field_Configuration__mdt.getAll();
                
                for(Home_Orientation_Field_Configuration__mdt config : homeOrtFieldConfig.values()) {
                    if(!config.Active__c) continue;
                    Object jsonValues = requestBody.get(config.Json_Key_Name__c);
                    if(jsonValues == null) continue; 
                    if(config.Is_Text_Field__c || config.Is_Picklist_Field__c) {
                        serAppRec.put(config.Field_API_Name__c,String.valueOf(jsonValues));
                    } else {
                        List<String> values = new List<String>();
                        for(Object val : (List<Object>) jsonValues) {
                            values.add(String.valueOf(val));
                        }
                        serAppRec.put(config.Field_API_Name__c,String.join(values, ';'));
                    }
                }
            }
            if(!Test.isRunningTest() && appointmentResult?.result?.serviceAppointmentId != null) {
                serAppRec.Id = appointmentResult.result.serviceAppointmentId;
                update serAppRec;
            }
            List<sObject> updateObjList = new List<sObject>();
            HandoverDetails__c hRec = new HandoverDetails__c();
            HexaBPM__Service_Request__c sr = new HexaBPM__Service_Request__c();
            hRec.Id = sRRec[0].HandoverDetail__c;
            sr.id = requestData.serviceRequestId;            
            List<WorkType> wrkType = [SELECT Id, Name from WorkType WHERE Id =: requestData.workTypeId];
            if (wrkType.isEmpty()) {throw new CustomException('No active Work Type found.');}
            List<ServiceResource> hoAgentList ;
            if(!Test.isRunningTest() ){
                hoAgentList = [SELECT id, RelatedRecordId from ServiceResource where id =: requestData.serviceResourceId AND RelatedRecordId != null AND RelatedRecord.IsActive = true];
                    if (hoAgentList.isEmpty()) {throw new CustomException('No resource found'); }}


            String wrokType = wrkType[0].Name;
            if(wrokType.startsWith( System.Label.HANDOVER_WORKTYPE_HOME_ORIENTATION)){
                hRec.Home_Orientation_Appointment__c = appointmentResult.result.serviceAppointmentId;
                hRec.Home_Orientation_Appointment_Resource__c = requestData.serviceResourceId;hRec.HandoverAgent__c = !hoAgentList.isEmpty() ? hoAgentList[0].RelatedRecordId : null;
                sr.HOAgent__c = hoAgentList[0].RelatedRecordId; 
                String HOAType = wrokType.split('-').size() > 1 ?  wrokType.split('-')[1].trim(): null;
                String OrientatinType = HOAType.equalsIgnoreCase('Virtual') ? 'Virtual' :  HOAType.equalsIgnoreCase('Third party') ? 'Third party' : 'In-person';
                hRec.Home_Orientation_Type__c = OrientatinType;
                responseWrapper.appointmentType = OrientatinType;

            } else if(wrkType[0].Name == System.Label.HANDOVER_WORKTYPE_KEY_HANDOVER_INPERSON){
                hRec.Key_Handover_Appointment__c = appointmentResult.result.serviceAppointmentId;
                hRec.Key_Handover_Appointment_Resource__c = requestData.serviceResourceId;
            } else if(wrkType[0].Name == System.Label.HANDOVER_WORKTYPE_DESNAGGING_SCHEDULED){
                hRec.Desnagging_Appointment__c = appointmentResult.result.serviceAppointmentId;
                hRec.Desnagging_Appointment_Resource__c = requestData.serviceResourceId;
            }
            updateObjList.add(hRec);
            updateObjList.add(sr);
            update updateObjList;
            delete sARec;
            return responseWrapper;
        } catch (ConnectApi.ConnectApiException ex) {throw new CustomException('Error creating service appointment: ' + ex.getMessage());
        } catch (Exception ex) {
            throw new CustomException('Unexpected error: ' + ex.getMessage());
        }
    }
  */  
    
}