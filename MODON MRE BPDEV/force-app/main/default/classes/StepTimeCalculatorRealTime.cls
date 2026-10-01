/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10      Initial Draft     
**********************************************************************************************************************/

public class StepTimeCalculatorRealTime {
    
    public class StepTimeCalculationInput {
        public List<Business_Process_Step_Time_Log__c> timeLogs;
        public Id businessHoursId;
        public Decimal milestoneHours;
        public Integer reopenCount;
    }

    public class StepTimeCalculationOutput {
        @AuraEnabled public String mileStoneTime;
        @AuraEnabled public String totalTime;
        @AuraEnabled public String escalatedTime;
        @AuraEnabled public Boolean isEscalated;
        @AuraEnabled public Integer reOpenCount;
        @AuraEnabled public Map<String, String> statusTimeLabels;

        public StepTimeCalculationOutput() {
            statusTimeLabels = new Map<String, String>();
        }
    }

    @AuraEnabled
    public static StepTimeCalculationOutput getTimelineMetadata(Id stepId) {
        Business_Process_Step__c step = [
            SELECT Id, Milestone_To_Complete_In_Hours__c, Re_Open_Count__c
            FROM Business_Process_Step__c
            WHERE Id = :stepId
            LIMIT 1
        ];

        List<Business_Process_Step_Time_Log__c> timeLogs = [
            SELECT Start_time__c, End_Time__c, New_Status__c
            FROM Business_Process_Step_Time_Log__c
            WHERE Business_Process_Step__c = :stepId
        ];

        Decimal milestoneHours = 0;
        if (String.isNotBlank(step.Milestone_To_Complete_In_Hours__c)) {
            try {
                milestoneHours = Decimal.valueOf(step.Milestone_To_Complete_In_Hours__c);
            } catch (Exception e) {
                milestoneHours = 0;
            }
        }

        StepTimeCalculationInput input = new StepTimeCalculationInput();
        input.timeLogs = timeLogs;
        input.milestoneHours = milestoneHours;
        input.reopenCount = step.Re_Open_Count__c != null ? step.Re_Open_Count__c.intValue() : 0;

        try {
            //un comment
              BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
              input.businessHoursId = bh.Id;
        } catch (Exception e) {
            input.businessHoursId = null; // fallback
        }

        return calculateTimeline(input);
    }

    public static StepTimeCalculationOutput calculateTimeline(StepTimeCalculationInput input) {
        StepTimeCalculationOutput output = new StepTimeCalculationOutput();
        if (input.timeLogs == null || input.timeLogs.isEmpty()) return output;

        Id bhId = input.businessHoursId;
        if (bhId == null) {
            try {
                 //un comment
                  BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
                  bhId = bh.Id;
            } catch (Exception e) {
                return output; // no business hours fallback
            }
        }

        Map<String, Integer> statusTimeMap = new Map<String, Integer>();
        Integer totalTimeMinutes = 0;

        for (Business_Process_Step_Time_Log__c log : input.timeLogs) {
            if (log.Start_time__c != null && String.isNotBlank(log.New_Status__c)) {
                Datetime endTime = log.End_Time__c != null ? log.End_Time__c : System.now();
                     Long diffMillis = BusinessHours.diff(bhId, log.Start_time__c, endTime);
                 //  Long diffMillis =60;
                if (diffMillis == null || diffMillis <= 0) continue;

                Integer minutes = Integer.valueOf(Math.round((Decimal.valueOf(diffMillis) / 1000 / 60)));
                String status = log.New_Status__c.trim();

                Integer existing = statusTimeMap.containsKey(status) ? statusTimeMap.get(status) : 0;
                statusTimeMap.put(status, existing + minutes);

                if (!status.equalsIgnoreCase('Not Actioned')) {
                    totalTimeMinutes += minutes;
                }
            }
        }

        // Status time display labels
        output.statusTimeLabels.put('openTime', formatMinutes(statusTimeMap.get('Open')));
        output.statusTimeLabels.put('reOpenTime', formatMinutes(statusTimeMap.get('Re Open')));
        output.statusTimeLabels.put('acceptedTime', formatMinutes(statusTimeMap.get('Accepted')));
        output.statusTimeLabels.put('requiredInfoTime', formatMinutes(statusTimeMap.get('Required Info')));
        output.statusTimeLabels.put('providedInfoTime', formatMinutes(statusTimeMap.get('Provided Info')));

        // Overall Times
        output.totalTime = formatMinutes(totalTimeMinutes);
        output.mileStoneTime = input.milestoneHours != null ? formatMinutes((Integer)(input.milestoneHours * 60)) : 'N/A';
        output.reOpenCount = input.reopenCount;

        Integer milestoneMinutes = input.milestoneHours != null ? (Integer)(input.milestoneHours * 60) : 0;
        Integer escalatedMinutes = totalTimeMinutes - milestoneMinutes;
        output.escalatedTime = escalatedMinutes > 0 ? formatMinutes(escalatedMinutes) : '0 min';
        output.isEscalated = escalatedMinutes > 0;

        return output;
    }

    private static String formatMinutes(Integer minutes) {
        if (minutes == null || minutes == 0) return '0 min';
        Integer hrs = minutes / 60;
        Integer min = Math.mod(minutes, 60);
        return (hrs > 0 ? hrs + ' hour' + (hrs > 1 ? 's' : '') : '') +
               (hrs > 0 && min > 0 ? ' ' : '') +
               (min > 0 ? min + ' min' : '');
    }
}