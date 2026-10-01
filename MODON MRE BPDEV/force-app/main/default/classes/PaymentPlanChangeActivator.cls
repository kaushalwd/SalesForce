/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PaymentPlanChangeActivator
 * Author          : <YourName>
 * Created Date    : Aug 3, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Aug 3, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 3, 2026  │ <YourName>   │ Initial version
 *  AUG 6, 2026  │ Siva   │ Payment Plan Phase 2 Changes
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class PaymentPlanChangeActivator implements StepActivator{
	 
	  public  List<Business_Process_Step__c> activateNextSteps(
        Id stepId, List<Business_Process_Step__c> bpsList, Business_Process_Step__c previousStep,
        String nextStepOwnerID) {
            
            List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();
            
            // Find steps with sequence just after the previousStep
            Id bpsReqInfo=previousStep.Required_Info_Step__c;
            if(previousStep.Is_Process_End__c) return stepsToActivateList ;
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
    
}