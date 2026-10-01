@RestResource(urlMapping = '/modon/HandoverGetCandidates')
global without sharing class HandoverGetCandidatesWebService {
    
    @HttpPost
    global static HandoverMilestoneResponse doPost() {
        //RestResponse res = RestContext.response;
        
        try {
            String startDateTime;
            String endDateTime;
            DateTime actualStartDateTime;
            DateTime actualEndDateTime;

            RestRequest req = RestContext.request;
            
            
           // Step 1: Deserialize outer wrapper
Map<String, Object> outerMap = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

// Step 2: Extract responseString
String requestString = (String) outerMap.get('requestString');

System.debug('requestString: ' + requestString);

// Step 3: Deserialize inner JSON into wrapper
CandidatesRequestWrapper requestData = 
    (CandidatesRequestWrapper) JSON.deserialize(
        requestString, 
        CandidatesRequestWrapper.class
    );
           /*
            CandidatesRequestWrapper requestData = 
                (CandidatesRequestWrapper) JSON.deserialize(
                    req.requestBody.toString(), 
                    CandidatesRequestWrapper.class
                );
          */

            System.debug('requestData: ' + requestData);

            if (requestData == null || 
                String.isBlank(requestData.territoryId) || 
                String.isBlank(requestData.appointmentType) || String.isBlank(requestData.startDate) || 
                String.isBlank(requestData.endDate)) {
                throw new CustomException('Invalid input');
            }

            List<AppointmentSchedulingPolicy> schedulingPolicyRec = [
                SELECT Id, DeveloperName 
                FROM AppointmentSchedulingPolicy 
                WHERE DeveloperName = 'default_appointment_scheduling_policy' 
                LIMIT 1
            ];

            List<WorkTypeGroup> workTypegroupRec = [
                SELECT Id, Name 
                FROM WorkTypeGroup 
                WHERE Name = :requestData.appointmentType 
                AND IsActive = true 
                LIMIT 1
            ];

            String appType = requestData.appointmentType + ' Appointment';

            List<WorkType> workTypeRec = [
                SELECT Id, Name 
                FROM WorkType 
                WHERE Name = :appType 
                LIMIT 1
            ];

            // Start Date Handling
            if (!String.isBlank(requestData.startDate)) {
                Date startDateFormatted = Date.valueOf(requestData.startDate);
                actualStartDateTime = DateTime.newInstance(
                    startDateFormatted.year(),
                    startDateFormatted.month(),
                    startDateFormatted.day(),
                    0, 0, 0
                );
                startDateTime = actualStartDateTime.format(
                    'yyyy-MM-dd\'T\'HH:mm:ssZ',
                    'America/Los_Angeles'
                );
            } else {
                actualStartDateTime = System.now();
                startDateTime = actualStartDateTime.format(
                    'yyyy-MM-dd\'T\'HH:mm:ssZ',
                    'America/Los_Angeles'
                );
            }

            // End Date Handling
            if (!String.isBlank(requestData.endDate)) {
                Date endDateFormatted = Date.valueOf(requestData.endDate);
                actualEndDateTime = DateTime.newInstance(
                    endDateFormatted.year(),
                    endDateFormatted.month(),
                    endDateFormatted.day(),
                    23, 59, 0
                );
                endDateTime = actualEndDateTime.format(
                    'yyyy-MM-dd\'T\'HH:mm:ssZ',
                    'America/Los_Angeles'
                );
            } else {
                actualEndDateTime = actualStartDateTime.addDays(10);
                endDateTime = actualEndDateTime.format(
                    'yyyy-MM-dd\'T\'HH:mm:ssZ',
                    'America/Los_Angeles'
                );
            }

            AppointmentCandidateService appointmentCandidates =
                AppointmentCandidateService.getAppointmentCandidates(
                    workTypeRec[0].Id,
                    workTypegroupRec[0].Id,
                    requestData.territoryId,
                    schedulingPolicyRec[0].Id,
                    startDateTime,
                    endDateTime
                );

            // Success Response
          //  res.statusCode = 200;
         //   res.responseBody = Blob.valueOf(JSON.serialize(appointmentCandidates));
           //    res.responseBody = Blob.valueOf('{ "responseString": "' + JSON.serialize(appointmentCandidates) + '" }');
           
            
             HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
             handoverResponse.responseString=JSON.serialize(appointmentCandidates);
             return handoverResponse;

        } catch (CustomException ex) {
            //res.statusCode = 400;
           // res.responseBody = Blob.valueOf(
              /*  JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => ex.getMessage()
                })
            );
            */
            
             HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
             //handoverResponse.responseString=JSON.serialize(appointmentCandidates);
             handoverResponse.responseString=null;
             return handoverResponse;

        } catch (Exception ex) {
            /*
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'System error occurred'
                })
            ); */
            
             HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
             handoverResponse.responseString=null;
             return handoverResponse;
        }
    }

    global class SlotsResponse {
        public Boolean success;
        public String message;
        public String data;
    }
    
    Global class HandoverMilestoneResponse {
        @AuraEnabled public String responseString;
      
    }

     
    public class CandidatesRequestWrapper {
        public String territoryId { get; set; }
        public String appointmentType { get; set; }
        public String startDate { get; set; }
        public String endDate { get; set; }
    }
}