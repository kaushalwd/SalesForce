/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class MilestoneConfirmationActivator implements StepActivator {

    // Steps that execute the milestone update (same names as ProjectMileStoneConfirmationAutomator).
    private static final Set<String> MILESTONE_UPDATE_STEPS = new Set<String>{
        'CM Execute Milestone Update',
        'Execute Milestone Update'
    };

       public  List<Business_Process_Step__c> activateNextSteps(
        Id stepId, List<Business_Process_Step__c> bpsList, Business_Process_Step__c previousStep,
        String nextStepOwnerID) {

            List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();

            // Same as DefaultActivator: a process-end step does not open a next step.
            if (getField(previousStep, 'Is_Process_End__c') == true) {
                return stepsToActivateList;
            }

            // Milestone Extension Date present: the milestone update step is the last step.
            if (completeProcessOnMilestoneExtension(previousStep)) {
                return stepsToActivateList;
            }

            // Find steps with sequence just after the previousStep
            Id bpsReqInfo=previousStep.Required_Info_Step__c;
            if(previousStep.Required_Info_Step__c!=null){
                Business_Process_Step__c stepUpdated = new Business_Process_Step__c();
                stepUpdated.Id=bpsReqInfo;
                stepUpdated.Status__c='Provided Info';
                stepsToActivateList.add(stepUpdated);
            } else {
                for (Business_Process_Step__c step : bpsList) {
                    if (step.Sequence__c == previousStep.Sequence__c + 1 && previousStep.Status__c == 'Completed') {
                        Business_Process_Step__c stepToOpen = new Business_Process_Step__c();
                        stepToOpen.Id = step.Id;
                       
                       
                        
                        if(step.Status__c=='Required Info'){
                            stepToOpen.Status__c = 'Provided Info';
                        } else if(step.Re_Open_Count__c>0){
                            stepToOpen.Status__c = 'Re Open';
                        }
                        else if(step.Assigned_To__c != null){
                            stepToOpen.Status__c = 'Accepted';
                        } else {
                            stepToOpen.Status__c = 'Open';
                        }

                        stepsToActivateList.add(stepToOpen);
                        system.debug('stepToOpen --> '+stepToOpen);
                    }
                    
                }    
            }
            
            
            
            if (!stepsToActivateList.isEmpty()) {
                update stepsToActivateList;
            }
            return stepsToActivateList;
        }

    /*
     * When the Business Process has a Milestone Extension Date and the completed step is
     * "CM Execute Milestone Update", the process ends here: the step is flagged as the process
     * end and the Business Process is completed, and no next step is opened.
     *
     * The Business Process is completed here directly because BusinessProcessStepTriggerHandler
     * cannot do it in this transaction: TriggerHandler already processed this step when it was
     * saved as Completed, so a second save of the same step is skipped (processedIds).
     */
    private static Boolean completeProcessOnMilestoneExtension(Business_Process_Step__c previousStep) {

        if (previousStep == null
            || getField(previousStep, 'Status__c') != 'Completed'
            || !MILESTONE_UPDATE_STEPS.contains((String) getField(previousStep, 'Name'))
            || getField(previousStep, 'Business_Process__c') == null) {
            return false;
        }

        List<Business_Process__c> bps = [
            SELECT Id, MileStone_Extension_Date__c
            FROM Business_Process__c
            WHERE Id = :previousStep.Business_Process__c
            LIMIT 1
        ];

        if (bps.isEmpty() || bps[0].MileStone_Extension_Date__c == null) {
            return false;
        }

        update new Business_Process_Step__c(Id = previousStep.Id, Is_Process_End__c = true);

        // Same values BusinessProcessStepTriggerHandler sets for a process-end step.
        Business_Process__c bp = new Business_Process__c(
            Id = bps[0].Id,
            Status__c = 'Completed',
            End_Date__c = System.now(),
            Previous_Business_Process_Step__c = previousStep.Id
        );

        List<AggregateResult> stepTimes = [
            SELECT SUM(Completed__c) totalTime, SUM(Completed_in_Hours__c) totalHours, SUM(Completed_in_Days__c) totalDays
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp.Id
        ];
        if (!stepTimes.isEmpty()) {
            bp.Total_Time__c = (Decimal) stepTimes[0].get('totalTime');
            bp.Total_Time_In_Hours__c = (Decimal) stepTimes[0].get('totalHours');
            bp.Total_Time_in_Days__c = (Decimal) stepTimes[0].get('totalDays');
        }

        update bp;
        return true;
    }

    // Field value if it was queried on the step, otherwise null (callers build previousStep
    // with different SOQL field lists).
    private static Object getField(Business_Process_Step__c step, String fieldName) {
        Map<String, Object> populated = step.getPopulatedFieldsAsMap();
        return populated.containsKey(fieldName) ? populated.get(fieldName) : null;
    }


}