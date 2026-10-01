/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public with sharing class BusinessProcessStepTimeCalculator {

    @InvocableMethod(
        label = 'Calculate Business Hours Time'
        description = 'Calculates and updates Calculate_Time_1__c to Calculate_Time_4__c based on LastModifiedDate using Default Business Hours.'
    )
    public static void calculateStepTimes(List<Id> stepIds) {
        if (stepIds == null || stepIds.isEmpty()) {
            System.debug('⚠️ No Step Ids provided.');
            return;
        }

        // 🔹 Query Business_Process_Step__c records
        List<Business_Process_Step__c> steps = [
            SELECT Id, LastModifiedDate, Status__c, Process_Flow_Step__c,
                   Calculate_Time_1__c, Calculate_Time_2__c,
                   Calculate_Time_3__c, Calculate_Time_4__c
            FROM Business_Process_Step__c
            WHERE Id IN :stepIds
            AND Status__c IN ('Open', 'Accepted')
        ];

        if (steps.isEmpty()) {
            System.debug('⚠️ No eligible Business_Process_Step__c records found.');
            return;
        }

        // 🔹 Collect Process_Flow_Step__c Ids
        Set<Id> processFlowStepIds = new Set<Id>();
        for (Business_Process_Step__c step : steps) {
            if (step.Process_Flow_Step__c != null) {
                processFlowStepIds.add(step.Process_Flow_Step__c);
            }
        }

        if (processFlowStepIds.isEmpty()) {
            System.debug('⚠️ No related Process_Flow_Step__c IDs found.');
            return;
        }

        // 🔹 Get Default Business Hours
        Id defaultBHId;
        List<BusinessHours> bhList = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        if (!bhList.isEmpty()) {
            defaultBHId = bhList[0].Id;
        } else {
            System.debug('⚠️ No default Business Hours found. Exiting.');
            return;
        }

        // 🔹 Query Step_Assignment__c related to Process_Flow_Step__c
        Map<Id, List<Step_Assignment__c>> stepToAssignmentsMap = new Map<Id, List<Step_Assignment__c>>();
        for (Step_Assignment__c sa : [
            SELECT Id, Process_Flow_Step__c, Sequence__c,
                   Assignment_Days__c, Assignment_Time__c, Assignment_Minutes__c
            FROM Step_Assignment__c
            WHERE Process_Flow_Step__c IN :processFlowStepIds
            ORDER BY Sequence__c ASC
        ]) {
            if (!stepToAssignmentsMap.containsKey(sa.Process_Flow_Step__c)) {
                stepToAssignmentsMap.put(sa.Process_Flow_Step__c, new List<Step_Assignment__c>());
            }
            stepToAssignmentsMap.get(sa.Process_Flow_Step__c).add(sa);
        }

        List<Business_Process_Step__c> stepsToUpdate = new List<Business_Process_Step__c>();

        // 🔹 Loop through each Step and calculate times
        for (Business_Process_Step__c step : steps) {
            if (!stepToAssignmentsMap.containsKey(step.Process_Flow_Step__c)) {
                continue; // No matching Step_Assignment__c
            }

            List<Step_Assignment__c> assignments = stepToAssignmentsMap.get(step.Process_Flow_Step__c);
            Datetime baseTime = step.LastModifiedDate;

            for (Step_Assignment__c sa : assignments) {
                if (sa.Sequence__c == null) continue;

                Long totalMinutes = 0;
                if (sa.Assignment_Days__c != null)
                    totalMinutes += (Long)(sa.Assignment_Days__c.longValue() * 24 * 60);
                if (sa.Assignment_Time__c != null)
                    totalMinutes += (Long)(sa.Assignment_Time__c.longValue() * 60);
                if (sa.Assignment_Minutes__c != null)
                    totalMinutes += (Long)sa.Assignment_Minutes__c.longValue();

                Long totalMillis = totalMinutes * 60 * 1000;
                Datetime calcTime = BusinessHours.add(defaultBHId, baseTime, totalMillis);

                // 🔹 Assign calculated time to correct field
                switch on Integer.valueOf(sa.Sequence__c) {
                    when 1 {
                        step.Calculate_Time_1__c = calcTime;
                        System.debug('🕒 Step ' + step.Id + ' → Calculate_Time_1__c = ' + calcTime);
                    }
                    when 2 {
                        step.Calculate_Time_2__c = calcTime;
                        System.debug('🕒 Step ' + step.Id + ' → Calculate_Time_2__c = ' + calcTime);
                    }
                    when 3 {
                        step.Calculate_Time_3__c = calcTime;
                        System.debug('🕒 Step ' + step.Id + ' → Calculate_Time_3__c = ' + calcTime);
                    }
                    when 4 {
                        step.Calculate_Time_4__c = calcTime;
                        System.debug('🕒 Step ' + step.Id + ' → Calculate_Time_4__c = ' + calcTime);
                    }
                    when else {
                        System.debug('ℹ️ Step ' + step.Id + ' → Sequence__c ' + sa.Sequence__c + ' ignored.');
                    }
                }
            }

            stepsToUpdate.add(step);
        }

        // 🔹 Update all steps
        if (!stepsToUpdate.isEmpty()) {
            update stepsToUpdate;
            System.debug('✅ Updated ' + stepsToUpdate.size() + 
                         ' Business_Process_Step__c records with calculated times.');
        } else {
            System.debug('ℹ️ No updates required.');
        }
    }
}