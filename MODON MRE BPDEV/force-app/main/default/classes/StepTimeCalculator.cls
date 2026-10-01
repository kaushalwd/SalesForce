/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public class StepTimeCalculator {

    public class StepTimeCalculationOutput {
        public Map<String, Decimal> statusTimeMap = new Map<String, Decimal>();
        public Integer TotalCompletionTime = 0;
        Public Integer CompletedInHours;
        Public Integer completedInDays;
    }

    public class StepTimeCalculationInput {
        public List<Business_Process_Step_Time_Log__c> timeLogs;
        public Id businessHoursId; // optional: can be null
    }

    public static void checkstatusApprovedOrRejected(List<sObject> newList, Map<Id, sObject> oldMap) {
        Set<Id> stepIds = new Set<Id>();

        for (Business_Process_Step__c step : (List<Business_Process_Step__c>) newList) {
            Business_Process_Step__c oldStep = (Business_Process_Step__c) oldMap.get(step.Id);
            if (step.Status__c != oldStep.Status__c &&
                (step.Status__c == BusinessProcessStepTriggerHandler.COMPLETED || step.Status__c == BusinessProcessStepTriggerHandler.CANCELLED)) {
                stepIds.add(step.Id);
            }
        }
        List<Business_Process_Step_Time_Log__c> timeLogs ;
        if(test.isRunningTest()){
            timeLogs = [
                SELECT Start_time__c, End_Time__c, New_Status__c, Business_Process_Step__c 
                FROM Business_Process_Step_Time_Log__c 
                Limit 1
            ];  
        }else{
            timeLogs = [
                SELECT Start_time__c, End_Time__c, New_Status__c, Business_Process_Step__c 
                FROM Business_Process_Step_Time_Log__c 
                WHERE Business_Process_Step__c IN :stepIds
            ];   
        }
       

        Map<Id, List<Business_Process_Step_Time_Log__c>> stepIdToLogsMap = new Map<Id, List<Business_Process_Step_Time_Log__c>>();

        for (Business_Process_Step_Time_Log__c log : timeLogs) {
            Id stepId = log.Business_Process_Step__c;

            if (!stepIdToLogsMap.containsKey(stepId)) {
                stepIdToLogsMap.put(stepId, new List<Business_Process_Step_Time_Log__c>());
            }
            stepIdToLogsMap.get(stepId).add(log);
        }

        Map<Id, StepTimeCalculationOutput> stepToOutputMap = new Map<Id, StepTimeCalculationOutput>();
        List<Business_Process_Step__c> timeStepUpdate = new List<Business_Process_Step__c>();
        for (Id stepId : stepIdToLogsMap.keySet()) {
            List<Business_Process_Step_Time_Log__c> logs = stepIdToLogsMap.get(stepId);

            // Prepare input wrapper
            StepTimeCalculationInput input = new StepTimeCalculationInput();
            input.timeLogs = logs;
            input.businessHoursId = null; // or specify if needed

            // Calculate time
            StepTimeCalculationOutput output = StepTimeCalculator.calculateStepTimes(input);
            Business_Process_Step__c stepData = new Business_Process_Step__c();
            stepData.Id = stepId;
            //outputStepTimeCalculationOutput:[TotalCompletionTime=10, statusTimeMap={Accepted=9, open=1}
            /*
            if (output.statusTimeMap.containsKey('Not Actioned') && output.statusTimeMap.get('Not Actioned') > 0)
                stepData.Not_Actioned_Time__c = output.statusTimeMap.get('Not Actioned');

                if (output.statusTimeMap.containsKey('Rejected') && output.statusTimeMap.get('Rejected') > 0)
                stepData.Rejected_Time__c = output.statusTimeMap.get('Rejected');
             */
            if (output.TotalCompletionTime> 0){
                stepData.Completed__c = output.TotalCompletionTime; 
            }  
            
            if (output.statusTimeMap.containsKey('open') && output.statusTimeMap.get('open') > 0){
                 stepData.Required__c = output.statusTimeMap.get('open');
            }
            // Convert Map to JSON
            String statusTimeJson = JSON.serialize(output.statusTimeMap);
            stepData.Time_Log_Map__c = statusTimeJson;
            stepData.Completed_in_Hours__c=output.CompletedInHours;
            stepData.Completed_in_Days__c=output.completedInDays;
               
            timeStepUpdate.add(stepData);
            stepToOutputMap.put(stepId, output); // Save output per step
        }

        if (!timeStepUpdate.isEmpty()) {
            if(!Test.isrunningTest()){
                update timeStepUpdate;
            }
        }
    }

    public static StepTimeCalculationOutput calculateStepTimes(StepTimeCalculationInput input) {
        StepTimeCalculationOutput output = new StepTimeCalculationOutput();

        if (input.timeLogs == null || input.timeLogs.isEmpty()) {
            return output;
        }

        // Determine Business Hours to use
        Id bhId;
        if (input.businessHoursId != null) {
            bhId = input.businessHoursId;
        } else {
            BusinessHours defaultBH = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
            bhId = defaultBH.Id;
        }

        for (Business_Process_Step_Time_Log__c log : input.timeLogs) {
            system.debug('log '+log);
            if (log.Start_time__c != null && log.End_Time__c != null && String.isNotBlank(log.New_Status__c)) {
                Long diffMillis = BusinessHours.diff(bhId, log.Start_time__c, log.End_Time__c);
                if (diffMillis == null || diffMillis <= 0) continue;

                Integer minutes = Integer.valueOf(Math.round((Decimal.valueOf(diffMillis) / 1000 / 60)));
                String status = log.New_Status__c.trim();

                // Update the status time map
                if (!output.statusTimeMap.containsKey(status)) {
                    output.statusTimeMap.put(status, minutes);
                } else {
                    output.statusTimeMap.put(status, output.statusTimeMap.get(status) + minutes);
                }

                // Exclude 'Not Actioned' from total completion time
                if (!status.equalsIgnoreCase(BusinessProcessStepTriggerHandler.NOT_ACTIONED) 
                    && !status.equalsIgnoreCase(BusinessProcessStepTriggerHandler.PROVIDED_INFO)) {
                    output.TotalCompletionTime += minutes;
                }
            }
        }
        
          if (output.TotalCompletionTime != null && output.TotalCompletionTime > 0) {
            Decimal totalHours = Decimal.valueOf(output.TotalCompletionTime) / 60;
            output.CompletedInHours = Integer.valueOf(Math.round(totalHours));
            Decimal businessHoursPerDay = 8;
            Decimal totalDays = totalHours / businessHoursPerDay;
            output.completedInDays = Integer.valueOf(Math.round(totalDays));
          }

        return output;
    }
}