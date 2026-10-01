/**********************************************************************************************************************
* Name               : OIC_SAHandoverAppointment                                                        
* Description        : This class is used to fetch available appointment slots based on project and appointment type.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft       
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/handover/appointment/*')
global with sharing class OIC_SAHandoverAppointment {

    @HttpGet
    global static void fetchAppointmentCandidates() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        restResponse.addHeader('Content-Type', 'application/json');
        String requestId = String.valueOf(UUID.randomUUID());
        
        try {
            DateTime actualStartDateTime;
            DateTime actualEndDateTime;
            String startDateTime;
            String endDateTime;
            
            String projectId = restRequest.params.get('ProjectId');
            String appointmentType = restRequest.params.get('AppointmentType');
            String rawStartDate = restRequest.params.get('StartDate');
            String rawEndDate = restRequest.params.get('EndDate');
            
            if (String.isBlank(projectId) || String.isBlank(appointmentType) || String.isBlank(rawStartDate) || String.isBlank(rawEndDate)) {
                returnErrorAPI.returnError(restResponse, requestId, 'Request message is not valid: Missing required parameters', 200);
                return;
            } 
            
            Date startDate = Date.valueOf(rawStartDate);
            Date endDate = Date.valueOf(rawEndDate);
            String appType = appointmentType + ' Appointment';
            
            List<AppointmentSchedulingPolicy> schedulingPolicyRec = [
                    SELECT Id, DeveloperName 
                    FROM AppointmentSchedulingPolicy 
                    WHERE DeveloperName = 'default_appointment_scheduling_policy'
                    LIMIT 1];
                    
            List<WorkTypeGroup> workTypegroupRec = [
                    SELECT Id, Name 
                    FROM WorkTypeGroup 
                    WHERE Name = :appointmentType 
                    AND IsActive = true
                    LIMIT 1];
                    
            List<WorkType> workTypeRec = [
                    SELECT Id, Name 
                    FROM WorkType 
                    WHERE Name = :appType
                    LIMIT 1];
            
            if (schedulingPolicyRec.isEmpty() || workTypegroupRec.isEmpty() || workTypeRec.isEmpty()) {
                returnErrorAPI.returnError(restResponse, requestId, 'Configuration Error: Matching scheduling policy, work type group, or work type not found.', 200);
                return;
            }
            
            actualStartDateTime = DateTime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            startDateTime = actualStartDateTime.format('yyyy-MM-dd\'T\'HH:mm:ssZ', 'Asia/Dubai');
            
            actualEndDateTime = DateTime.newInstance(endDate.year(), endDate.month(), endDate.day(), 23, 59, 0);
            endDateTime = actualEndDateTime.format('yyyy-MM-dd\'T\'HH:mm:ssZ', 'Asia/Dubai');
            
            System.debug('>>>>>>>>>>>>>>>>>> OIC_SAHandoverAppointment >>>>>>>>>>>>'+startDateTime+'    '+endDateTime);
            AppointmentCandidateService appointmentCandidates = 
                AppointmentCandidateService.getAppointmentCandidates(workTypeRec[0].Id, workTypegroupRec[0].Id, '0HhVG000000lcbJ0AQ',
                        schedulingPolicyRec[0].Id, startDateTime, endDateTime);
            for(AppointmentCandidateService.CandidateDetails obj_Can : appointmentCandidates.candidates){
                if(String.isNotBlank(obj_Can.startTime)){
                    Datetime tempDatetime = (Datetime)JSON.deserialize('"' + obj_Can.startTime + '"', Datetime.class);
                    obj_Can.startTime = tempDatetime.format('yyyy-MM-dd\'T\'HH:mm:ssXXX', 'Asia/Dubai');
                }
                if(String.isNotBlank(obj_Can.endTime)){
                    Datetime tempDatetime = (Datetime)JSON.deserialize('"' + obj_Can.endTime + '"', Datetime.class);
                    obj_Can.endTime = tempDatetime.format('yyyy-MM-dd\'T\'HH:mm:ssXXX', 'Asia/Dubai');
                }                
            }

            if (appointmentCandidates == null || appointmentCandidates.candidates == null || appointmentCandidates.candidates.isEmpty()) {
                APIResponse emptyResponse = new APIResponse('success', requestId, appointmentCandidates, 'No available appointment slots found for this date range.');
                restResponse.responseBody = Blob.valueOf(JSON.serialize(emptyResponse));
                restResponse.addHeader('Content-Type', 'application/json');
                restResponse.statusCode = 200;
                return;
            }
            
            Set<String> set_Resource = new Set<String>();
            for (AppointmentCandidateService.CandidateDetails obj_Cand : appointmentCandidates.candidates) {
                if (obj_Cand.resources != null && !obj_Cand.resources.isEmpty()) {
                    set_Resource.addAll(obj_Cand.resources);
                }            
            }
            
            if (!set_Resource.isEmpty()) {
                Map<Id, ServiceResource> resourceMap = new Map<Id, ServiceResource>([
                    SELECT Id, Name 
                    FROM ServiceResource 
                    WHERE Id IN :set_Resource
                ]);
                
                for (AppointmentCandidateService.CandidateDetails obj_Cand : appointmentCandidates.candidates) {
                    if (obj_Cand.resources == null) { continue; }
                    List<String> resourceNames = new List<String>();
                    for (String resourceId : obj_Cand.resources) {
                        if (resourceMap.containsKey(resourceId)) {
                            resourceNames.add(resourceMap.get(resourceId).Name + '-' + resourceId);
                        } else {
                            resourceNames.add(resourceId); 
                        }
                    }
                    obj_Cand.resources = resourceNames;
                }    
            }
            
            APIResponse response = new APIResponse('success', requestId, appointmentCandidates, null);
            restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.statusCode = 200;
            
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_SAHandoverAppointment', 'fetchAppointmentCandidates', 'Execution Crash Catch'));
            returnErrorAPI.returnError(restResponse, requestId, 'Internal Server Error: ' + ex.getMessage(), 200);
        }
    }
}