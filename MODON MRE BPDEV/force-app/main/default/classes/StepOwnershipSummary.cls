/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public class StepOwnershipSummary {

    public static void updateOwnershipSummary(Set<Id> stepIds,Map<ID,Business_Process_Step__c> processFlowMap) {
        List<Business_Process_Step_Time_Log__c> allLogs = [
            SELECT Id,
                   Start_time__c,
                   End_Time__c,
                   Step_Assigned_User__c,
                   Step_Assigned_User__r.Name,
                   Business_Process_Step__c
            FROM Business_Process_Step_Time_Log__c
            WHERE Business_Process_Step__c IN :stepIds
            ORDER BY Start_time__c
        ];

        // Map<StepId, Map<UserId, Minutes>>
        Map<Id, Map<Id, Long>> stepUserTimeMap = new Map<Id, Map<Id, Long>>();
        Map<Id, String> userNames = new Map<Id, String>();

        for (Business_Process_Step_Time_Log__c log : allLogs) {

            if (log.Start_time__c == null || log.Step_Assigned_User__c == null) {
                continue;
            }

            Datetime startDt = log.Start_time__c;
            Datetime endDt = log.End_Time__c != null ? log.End_Time__c : System.now();

            Long diffMs = BusinessHours.diff(processFlowMap.get(log.Business_Process_Step__c).Process_Flow_Step__r.Process_Flow__r.Business_Hours_ID__c, startDt, endDt);
            Long diffMinutes = diffMs != null ? diffMs / (1000 * 60) : 0;

            if (!stepUserTimeMap.containsKey(log.Business_Process_Step__c)) {
                stepUserTimeMap.put(log.Business_Process_Step__c, new Map<Id, Long>());
            }

            Map<Id, Long> userTimeMap = stepUserTimeMap.get(log.Business_Process_Step__c);

            if (!userTimeMap.containsKey(log.Step_Assigned_User__c)) {
                userTimeMap.put(log.Step_Assigned_User__c, 0);
            }

            userTimeMap.put(
                log.Step_Assigned_User__c,
                userTimeMap.get(log.Step_Assigned_User__c) + diffMinutes
            );

            userNames.put(log.Step_Assigned_User__c, log.Step_Assigned_User__r.Name);
        }

        // Prepare updates
        List<Business_Process_Step__c> stepsToUpdate = new List<Business_Process_Step__c>();

        for (Id stepId : stepUserTimeMap.keySet()) {

            Map<Id, Long> userTimeMap = stepUserTimeMap.get(stepId);
            List<String> summaryList = new List<String>();

            for (Id userId : userTimeMap.keySet()) {
                String name = userNames.get(userId);
                Long mins = userTimeMap.get(userId);

                summaryList.add(name + ' - ' + mins + ' mins');
            }

            String summary = String.join(summaryList, '\n');

            stepsToUpdate.add(new Business_Process_Step__c(
                Id = stepId,
                Step_Ownership_Summary__c = summary
            ));
        }

        if (!stepsToUpdate.isEmpty()) {
            update stepsToUpdate;
        }
    }
}