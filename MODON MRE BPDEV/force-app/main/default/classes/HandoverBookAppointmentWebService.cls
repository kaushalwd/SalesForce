@RestResource(urlMapping = '/Modon/CreateServiceAppointment')
global without sharing class HandoverBookAppointmentWebService {
   
    /*
    //--- App Related Constants
  public static final Integer STATUS_CODE_SUCCESS = 200;
  public static final Integer STATUS_CODE_UNAUTHORIZED = 403;
  public static final Integer STATUS_CODE_SYSTEM_ERROR = 500;  
  public static final Integer STATUS_CODE_NOT_FOUND = 400;
  public static final Integer STATUS_CODE_OLD_VERSION = 101; 
  public static final String MESSAGE_GENERIC_ERROR = 'An error has occured. Please contact your system administrator.';
  public static final String SUCCESS_MESSAGE = 'Success';
  public static Integer SUCCESS_CODE_200 = 200;
    
    
    @HttpPost
    global static void doPost() {
        RestContextHandler handler = new RestContextHandler(true);
        try {
            RestRequest req = RestContext.request;
            BookAppointmentRequestWrapper requestData = (BookAppointmentRequestWrapper) JSON.deserialize(req.requestBody.toString(), BookAppointmentRequestWrapper.class);           
            if (requestData == null || String.isBlank(requestData.workTypeId) || String.isBlank(requestData.territoryId) || String.isBlank(requestData.startTime) || String.isBlank(requestData.endTime) || (!Test.isRunningTest() && String.isBlank(requestData.serviceResourceId)) || String.isBlank(requestData.unitId) || String.isBlank(requestData.serviceRequestId)) {
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
            handler.response.statusCode = STATUS_CODE_SYSTEM_ERROR;
            handler.response.message = MESSAGE_GENERIC_ERROR;
            handler.finalize(ex);
        }
    }
    
    @HttpGet
    global static void doGet() {
        RestContextHandler handler = new RestContextHandler(true);
        String serviceAppointmentId = RestContext.request.params.get('serviceAppointmentId');
        Savepoint sp;
        try {
            sp = Database.setSavepoint();
            RestRequest req = RestContext.request;
            handler.response.data = getHomeOrientationPreferences(serviceAppointmentId);
            handler.response.message = SUCCESS_MESSAGE;
            handler.response.statusCode = SUCCESS_CODE_200;
            handler.response.success = true;
            handler.finalize();
            
        } catch (Exception ex) {
            Database.rollback(sp);
            handler.response.success = false;
            handler.response.statusCode = STATUS_CODE_SYSTEM_ERROR;
            RestContext.response.statusCode = STATUS_CODE_SYSTEM_ERROR;
            handler.response.message = ex.getMessage();
            handler.finalize(ex);
        }
    }
    
    public class BookAppointmentRequestWrapper {
        public String workTypeId { get; set; }
        public String territoryId { get; set; }
        public String startTime { get; set; }
        public String endTime { get; set; }
        public String serviceResourceId { get; set; }
        public String unitId { get; set; }
        public String serviceRequestId { get; set; }
        public HomeOrientationPreferences homeOrientationtPreferences {get;set;}
    }
    
    
    public class BookAppointmentResponseWrapper {
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
    
    public static BookAppointmentResponseWrapper createServiceAppointment(BookAppointmentRequestWrapper requestData) {
        BookAppointmentResponseWrapper response = new BookAppointmentResponseWrapper();
      
        
        try {
            List<HexaBPM__Service_Request__c> sRRec = [SELECT Id, HandoverDetail__c, SalesOrder__r.Account__c, SalesOrder__r.Contact__c FROM HexaBPM__Service_Request__c WHERE Id = :requestData.serviceRequestId];
            if (sRRec.isEmpty()) {
                throw new CustomException('No Service Request found.');
            }
            
            Id workOrderRT = Schema.SObjectType.WorkOrder.getRecordTypeInfosByName().get('Handover').getRecordTypeId();
            WorkOrder workOrderRec = new WorkOrder();
            workOrderRec.AccountId = sRRec[0].SalesOrder__r.Account__c;
            workOrderRec.ContactId = sRRec[0].SalesOrder__r.Contact__c;
            workOrderRec.ServiceTerritoryId = requestData.territoryId;
            workOrderRec.Status = 'New';
            workOrderRec.RecordTypeId = workOrderRT;
            workOrderRec.Handover_Detail__c = sRRec[0].HandoverDetail__c;
            workOrderRec.Subject = 'Handover Appointments';
            workOrderRec.WorkTypeId = requestData.workTypeId;
            workOrderRec.Type__c = 'Handover Details';
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
            
            //Added by Tajinkumar
            if(requestData.homeOrientationtPreferences != null) {
                Map<String,Object> requestBody = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(requestData.homeOrientationtPreferences));
                Map<String,Home_Orientation_Field_Configuration__mdt> homeOrtFieldConfig = Home_Orientation_Field_Configuration__mdt.getAll();
               
                for(Home_Orientation_Field_Configuration__mdt config : homeOrtFieldConfig.values()) {
                    if(!config.Active__c) continue;
                    ConnectApi.ExtendedFieldInput extFldInput = new ConnectApi.ExtendedFieldInput();
                    Object jsonValues = requestBody.get(config.Json_Key_Name__c);
                    if(jsonValues == null) continue; 
                    extFldInput.name  = config.Field_API_Name__c;
                    if(config.Is_Text_Field__c || config.Is_Picklist_Field__c) {
                        extFldInput.value = String.valueOf(jsonValues);
                    } else {
                        List<String> values = new List<String>();
                        for(Object val : (List<Object>) jsonValues) {
                            values.add(String.valueOf(val));
                        }
                        extFldInput.value = String.join(values, ';');
                    }
                    extendedFieldList.add(extFldInput);
                }
            }
            
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
            //DateTime scheduledStartTime = utcStartDateTime.addHours(4);
            //System.debug('scheduledStartTime: ' + scheduledStartTime);
            serviceAppInput.schedStartTime = utcStartDateTime;
            String endTimeString = requestData.endTime.substring(0, 19).replace('T', ' ');
            DateTime utcEndDateTime = DateTime.valueOfGmt(endTimeString);
            //DateTime scheduledEndtTime = utcEndDateTime.addHours(4);
            //System.debug('scheduledEndtTime: ' + utcEndDateTime);
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

            BookAppointmentResponseWrapper responseWrapper = new BookAppointmentResponseWrapper();
            responseWrapper.serviceAppointmentId = !Test.isRunningTest() ? appointmentResult.result.serviceAppointmentId : null;
            
            responseWrapper.workTypeId = requestData.workTypeId;
            responseWrapper.territoryId = requestData.territoryId;
            responseWrapper.startTime = requestData.startTime;
            responseWrapper.endTime = requestData.endTime;
            responseWrapper.serviceResourceId = requestData.serviceResourceId;
            responseWrapper.unitId = requestData.unitId; 
            responseWrapper.serviceRequestId = requestData.serviceRequestId;
            
            List<sObject> updateObjList = new List<sObject>();
            HandoverDetails__c hRec = new HandoverDetails__c();
            HexaBPM__Service_Request__c sr = new HexaBPM__Service_Request__c();
            hRec.Id = sRRec[0].HandoverDetail__c;
            sr.id = requestData.serviceRequestId;
            List<WorkType> wrkType = [SELECT Id, Name from WorkType WHERE Id =: requestData.workTypeId];
            if (wrkType.isEmpty()) {
                throw new CustomException('No active Work Type found.'); 
            }
            
            List<ServiceResource> hoAgentList = [SELECT id, RelatedRecordId from ServiceResource where id =: requestData.serviceResourceId AND RelatedRecordId != null AND RelatedRecord.IsActive = true];
             if (hoAgentList.isEmpty()) {
                throw new CustomException('No resource found'); 
            }
            String wrokType = wrkType[0].Name;
            if(wrokType.startsWith( System.Label.HANDOVER_WORKTYPE_HOME_ORIENTATION)){
                hRec.Home_Orientation_Appointment__c = appointmentResult.result.serviceAppointmentId;
                hRec.Home_Orientation_Appointment_Resource__c = requestData.serviceResourceId;
                hRec.HandoverAgent__c = hoAgentList[0].RelatedRecordId;
                sr.HOAgent__c = hoAgentList[0].RelatedRecordId;
                String HOAType = wrokType.split('-').size() > 1 ?  wrokType.split('-')[1].trim(): null;
                String OrientatinType = HOAType.equalsIgnoreCase('Virtual') ? 'Virtual' :  HOAType.equalsIgnoreCase('Third party') ? 'Third party' : 'In-person';
                hRec.Home_Orientation_Type__c = OrientatinType;
                responseWrapper.appointmentType = OrientatinType;
                responseWrapper.virtualURL = 'Not yet generated';
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

            return responseWrapper;
        } catch (ConnectApi.ConnectApiException ex) {
            throw new CustomException('Error creating service appointment: ' + ex.getMessage());
        } catch (Exception ex) {
            throw new CustomException('Unexpected error: ' + ex.getMessage());
        }
    }
    
    //Added by Tajinkumar
    public static Map<String,Object> getHomeOrientationPreferences(String serviceAppointmentId) {
        
        Map<String,Object> response = new Map<String,Object>();
        ServiceAppointment appt;
        
        if(!Test.isRunningTest()) {
            if(!String.isBlank(serviceAppointmentId)) {
                List<ServiceAppointment> serviceAppointmentsList = [SELECT Id,Home_Orientation_Appointment_Other__c,Special_Accommodations_Other__c,Minor_Adjustments_Other__c,Any_Minor_Adjustments_Planned__c,Install_Smart_System_Appliances__c,
                                                                    Personalized_Move_In_Offers__c,Mortgage_Resale_Advisor_Services__c,Post_Handover_Contact_Preferences__c,Key_Handover_Collection_Preferences__c,Anyone_require_special_accommodation__c,
                                                                    Who_will_attend_HO_appointment__c FROM ServiceAppointment WHERE Id =: serviceAppointmentId LIMIT 1];
                if(serviceAppointmentsList.isEmpty()) {
                    throw new CustomException ('Service Appointment not found with provided serviceAppointmentId.');
                } else {
                    appt = serviceAppointmentsList[0];
                }
            }
        }
        Map<String,Schema.SObjectField> fieldMap = ServiceAppointment.SObjectType.getDescribe().fields.getMap();
        List<HomeOrientPrefFieldDetails> fieldsList = new List<HomeOrientPrefFieldDetails>();
        
        List<Home_Orientation_Preferences__mdt> homeOrtPrefList = ([SELECT Id, PlaceHolder__c, Other_Field__c, LabelKey__c, 
                                                                    LabelName__c, OtherFieldKeyName__c, PlaceHolderKey__c, Field_API_Name__c, 
                                                                    Other_Field_Active__c, Active__c, Sequence__c FROM Home_Orientation_Preferences__mdt 
                                                                    WHERE Active__c = true Order By Sequence__c ASC]);
        
        for(Home_Orientation_Preferences__mdt ortPref : homeOrtPrefList) {
            String apiName = ortPref.Field_API_Name__c;
            Schema.SObjectField sfField = fieldMap.get(apiName);
            if(sfField == null) continue;
            
            Schema.DescribeFieldResult fieldResult = sfField.getDescribe();
            HomeOrientPrefFieldDetails fields = new HomeOrientPrefFieldDetails();
            fields.label = ortPref.LabelName__c;
            fields.labelKey = ortPref.LabelKey__c;
            fields.placeHolder = ortPref.PlaceHolder__c;
            fields.placeHolderKey = ortPref.PlaceHolderKey__c;
            fields.required = !fieldResult.isNillable();
            fields.type = String.valueOf(fieldResult.getType());
            fields.value = (appt == null) ? null : appt.get(apiName);
            
            if(fieldResult.getType() == Schema.DisplayType.Picklist || fieldResult.getType() == Schema.DisplayType.MultiPicklist) {
                fields.options = new List<PicklistOptionDetails>();
                for(Schema.PicklistEntry pe : fieldResult.getPicklistValues()) {
                    PicklistOptionDetails opt = new PicklistOptionDetails();
                    opt.value = pe.getValue();
                    opt.label = pe.getLabel();
                    fields.options.add(opt);
                }
            }
            if(ortPref.Other_Field__c != null && ortPref.Other_Field_Active__c) {
                fields.other = new OtherFieldDetails();
                fields.other.label = 'Other';
                fields.other.labelKey = 'Other';
                fields.other.keyName = ortPref.OtherFieldKeyName__c;
                fields.other.value = (appt == null) ? null : (String) appt.get(ortPref.Other_Field__c);
            }
            fieldsList.add(fields);
        }
        response.put('fields',fieldsList);
        return response;
    }
    
    public class HomeOrientPrefFieldDetails {
        public String label;
        public String labelKey;
        public String type;
        public Boolean required;
        public Object value;
        public List<PicklistOptionDetails> options;
        public String placeHolder;
        public String placeHolderKey;
        public OtherFieldDetails other;
    }
    public class PicklistOptionDetails {
        public String value;
        public String label;
    }
    
    public class OtherFieldDetails {
        public String keyName;
        public String label;
        public String labelKey;
        public String value;
    }
*/
}