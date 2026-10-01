public class AppointmentCandidateService {
    public String workTypeId;
    public List<CandidateDetails> candidates; 

    public class CandidateDetails {
        public String startTime;
        public String endTime;
        public List<String> resources;
        public String territoryId;
    }

    public static AppointmentCandidateService getAppointmentCandidates(String workTypeId, String workTypeGroupId, String territoryId, String schedulingPolicyId, String startDateTime, String endDateTime){
        AppointmentCandidateService appointmentService = new AppointmentCandidateService();
        appointmentService.workTypeId = workTypeId;
        appointmentService.candidates = new List<CandidateDetails>();

        try {
            lxscheduler.GetAppointmentCandidatesInput input = new lxscheduler.GetAppointmentCandidatesInputBuilder()
                .setWorkTypeGroupId(workTypeGroupId)
                .setTerritoryIds(new List<String>{territoryId})
                .setStartTime(startDateTime)
                .setEndTime(endDateTime)
                .setSchedulingPolicyId(schedulingPolicyId)
                .build();
                
            String response = lxscheduler.SchedulerResources.getAppointmentCandidates(input);
            System.debug('API Response: ' + response);

            List<CandidateDetails> parsedCandidates = parse(response);
            appointmentService.candidates.addAll(parsedCandidates);
        } catch (Exception e) {
            System.debug('Error in getAppointmentCandidates: ' + e.getMessage());
            throw new CustomException('Error while fetching Appointment Candidates: ' + e.getMessage());
        }
        return appointmentService;
    }
    
    public static List<CandidateDetails> parse(String json) {
        return (List<CandidateDetails>) System.JSON.deserialize(json, List<CandidateDetails>.class);
    }
}