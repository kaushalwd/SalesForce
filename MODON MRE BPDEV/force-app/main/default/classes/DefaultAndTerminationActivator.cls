/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes 
**********************************************************************************************************************/
public class DefaultAndTerminationActivator implements StepActivator {

    public List<Business_Process_Step__c> activateNextSteps(
        Id stepId,
        List<Business_Process_Step__c> bpsList,
        Business_Process_Step__c previousStep,
        String nextStepOwnerID
    ) {
        List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();

        if (previousStep.Is_Process_End__c) {
            return stepsToActivateList;
        }

       List<Business_Process_Step__c> bpStepOwner = [
            SELECT Id, Assigned_To__c
            FROM Business_Process_Step__c
            WHERE Name = 'Collections Customer Engagement'
            AND Business_Process__c = :previousStep.Business_Process__c
            LIMIT 1
        ];

        if (previousStep.Required_Info_Step__c != null) {
            Business_Process_Step__c stepUpdated = new Business_Process_Step__c();
            stepUpdated.Id = previousStep.Required_Info_Step__c;
            stepUpdated.Status__c = 'Provided Info';
            stepsToActivateList.add(stepUpdated);
        } else {
            String nextStepName;
               if (
                    previousStep.Name == 'Manager Default Notice Approval' &&
                    previousStep.Business_Process__r.CRM_Manager_decision__c == 'Proceed without default notification'
                ) {
                    nextStepName = 'Collections Customer Negotiations';
                
                } else if (
                    (previousStep.Name == 'Manager Default Notice Approval' &&
                    previousStep.Business_Process__r.CRM_Manager_decision__c == 'Proceed with default notification')
                ) {
                    nextStepName = 'Senior Manager Default Notice Approval';
                
                } else if (
                    (previousStep.Name == 'Senior Manager Default Notice Approval' &&
                    previousStep.Business_Process__r.CRM_Manager_decision__c == 'Proceed without default notification')
                ) {
                    nextStepName = 'Collections Customer Negotiations';
                
                } else if (
                    (previousStep.Name == 'Senior Manager Default Notice Approval' &&
                    previousStep.Business_Process__r.CRM_Manager_decision__c == 'Proceed with default notification')
                ) {
                    nextStepName = 'Send Default1 Notice';
                }
            
            System.debug('*** nextStepName ***'+nextStepName);
            Integer num = previousStep.Name == 'Collections Customer Negotiations' &&
                previousStep.Business_Process__r.D_T_Customer_Discussion_Outcome__c == 'Escalate for further action'
                ? 2
                : 1;

            for (Business_Process_Step__c step : bpsList) {

                Boolean shouldOpenStep = false;

                if (String.isNotBlank(nextStepName)) {
                    shouldOpenStep = step.Name == nextStepName;
                } else {
                    num = step.Skip_Step_To_Reopen__c && step.Re_Open_Count__c > 0 ? num + 1 : num;
                    shouldOpenStep = step.Sequence__c == previousStep.Sequence__c + num;
                }

                if (shouldOpenStep && previousStep.Status__c == 'Completed') {
                    Business_Process_Step__c stepToOpen = new Business_Process_Step__c();
                    stepToOpen.Id = step.Id;

                    if (step.Status__c == 'Required Info') {
                        stepToOpen.Status__c = 'Provided Info';
                    } else if (step.Re_Open_Count__c > 0) {
                        stepToOpen.Status__c = 'Re Open';
                    } else if (step.Assigned_To__c != null) {
                        stepToOpen.Status__c = 'Accepted';
                    } else {
                        stepToOpen.Status__c = 'Open';

                        if (
                            (
                                step.Name == 'Default 1 Notice Approval' ||
                                step.Name == 'Collections Customer Negotiations' ||
                                step.Name == 'Customer Solutions Status Update' ||
                                step.Name == 'Send Default 2 Notice'
                            ) &&
                            !bpStepOwner.isEmpty() &&
                            bpStepOwner[0].Assigned_To__c != null
                        ) {
                            stepToOpen.Assigned_To__c = bpStepOwner[0].Assigned_To__c;
                        }
                    }

                    stepsToActivateList.add(stepToOpen);
                    System.debug('stepToOpen --> ' + stepToOpen);
                    break;
                }
            }
        }

        if (!stepsToActivateList.isEmpty()) {
            update stepsToActivateList;
        }

        return stepsToActivateList;
    }
}