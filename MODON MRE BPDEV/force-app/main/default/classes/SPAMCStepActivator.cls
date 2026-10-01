public without sharing class SPAMCStepActivator implements StepActivator {

    // Custom method to activate next steps based on name
    public List<Business_Process_Step__c> activateNextSteps(
        Id stepId,
        List<Business_Process_Step__c> bpsList,
        Business_Process_Step__c previousStep,
        String nextStepOwnerID
    ) {
        // List to hold steps that need to be activated
        List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();

        system.debug('*** StepActivator nextStepOwnerID '+nextStepOwnerID);

        for (Business_Process_Step__c step : bpsList) {
            switch on step.Name {
                when 'SPA Checklist Checker Verification' {
                    if (previousStep.Name == 'SPA Maker Verification' 
                        && previousStep.Status__c == 'Completed') {
                        Business_Process_Step__c stepUpdated = new Business_Process_Step__c();
                        stepUpdated.Id = step.Id;
                        if(step.Status__c == 'Required Info'){
                         stepUpdated.Status__c = 'Provided Info';
                        } else if(step.Assigned_To__c != null) {stepUpdated.Status__c = 'Accepted';}
                        else {stepUpdated.Status__c = 'Open';}
                        if(nextStepOwnerID!=null){
                           stepUpdated.Assigned_To__c=nextStepOwnerID;
                           stepUpdated.Status__c = 'Accepted';
                        }
                        stepsToActivateList.add(stepUpdated);
                       // mapCallValidator.
                    }
                }
                when else {
                    //throw new AuraHandledException('Input cannot be blank.');
                }
            }
        }

        System.debug('stepsToActivateList --> '+stepsToActivateList);
        // Update the activated steps
        if (!stepsToActivateList.isEmpty() && !test.isRunningTest()) {
            update stepsToActivateList;
        }
        return stepsToActivateList;
    }
}