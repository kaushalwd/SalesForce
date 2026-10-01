public class HandoverStepActivator implements StepActivator {
    
    public  List<Business_Process_Step__c> activateNextSteps(
        Id stepId, List<Business_Process_Step__c> bpsList, Business_Process_Step__c previousStep,
        String nextStepOwnerID) {
            
            System.debug('-*******************************************SPAExecutionStepActivator method called******************************************');
            List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();
            
            Id bpsReqInfo=previousStep.Required_Info_Step__c;
            if(previousStep.Required_Info_Step__c!=null){
                Business_Process_Step__c stepUpdated = new Business_Process_Step__c();
                stepUpdated.Id = bpsReqInfo;
                stepUpdated.Status__c='Provided Info';
                stepsToActivateList.add(stepUpdated);
            } else if(previousStep.Multi_Select_Step_Required_Info_Step__c !=null) {  
                String multiRequiredInfoStep = '';
                Integer reOpenStepCount= 0;
                for (Business_Process_Step__c step : [
                    SELECT Id,Section_Number__c,Is_Process_End__c,Is_Single_Level_Required_Info__c,Business_Process__c,Sequence__c,Step__c,
                    Name,Status__c,Re_Open_Count__c,Assigned_To__c,Business_Process_Name__c,Multi_Select_Step_Required_Info_Step__c  
                    FROM Business_Process_Step__c WHERE Business_Process__c = :previousStep.Business_Process__c AND Multi_Select_Step_Required_Info_Step__c != null]  ) {
                        multiRequiredInfoStep = step.Multi_Select_Step_Required_Info_Step__c;
                        ++reOpenStepCount;
                    }
                System.debug('-----------------------------------reOpenStepCount = '+reOpenStepCount);
                System.debug('-----------------------------------multiRequiredInfoStep = '+multiRequiredInfoStep);
                if(multiRequiredInfoStep != ''){
                    for (Business_Process_Step__c step : bpsList) {
                        System.debug('-----------------------------------step.Status__c = '+step.Status__c);
                        System.debug('-----------------------------------step.Multi_Select_Step_Required_Info_Step__c = '+step.Multi_Select_Step_Required_Info_Step__c+'-------Id = '+step.Id);
                        if(previousStep.Id== step.Id){
                            step.Multi_Select_Step_Required_Info_Step__c = null;
                            step.Status__c='Provided Info';
                            stepsToActivateList.add(step);
                            System.debug('-----------------------------------step = '+step);
                        } else if (reOpenStepCount==1 && step.Status__c == 'Required Info' && step.Id == multiRequiredInfoStep) {
                            System.debug('Setting step to Provided Info: ' + step.Name + ' - ' + step.Id);
                            Business_Process_Step__c stepUpdated = new Business_Process_Step__c();
                            stepUpdated.Id = step.Id;
                            stepUpdated.Status__c = 'Completed';
                            stepsToActivateList.add(stepUpdated);
                            System.debug('-----------------------------------stepUpdated = '+stepUpdated);
                        } 
                        
                    }
                    
                }
            } else {
                
                List<Business_Process_Step__c> section3CompletedBPSList = new  List<Business_Process_Step__c>();
                List<Business_Process_Step__c> section4CompletedBPSList = new  List<Business_Process_Step__c>();
                if(previousStep.Section_Number__c == 3 ) {
                    section3CompletedBPSList = [Select id,Sequence__c,Name,Status__c,Section_Number__c from Business_Process_Step__c where Business_Process__c = :previousStep.Business_Process__c AND Section_Number__c = 3 AND Sequence__c <= 9 AND Step__c != null AND (Status__c = 'Completed' OR Status__c = 'Provided Info')];                     
                }
                
                if(previousStep.Section_Number__c == 4 ) {
                    section4CompletedBPSList = [Select id,Sequence__c,Name,Status__c,Section_Number__c from Business_Process_Step__c where Business_Process__c = :previousStep.Business_Process__c AND Section_Number__c = 4 AND Sequence__c <= 15 AND Step__c != null AND (Status__c = 'Completed' OR Status__c = 'Provided Info')]; 
                }
                
                
                for (Business_Process_Step__c step : bpsList) {
                    if(previousStep.Sequence__c == 1){
                        if(step.Sequence__c == 2 || step.Sequence__c == 3  || step.Sequence__c == 4 || step.Name == 'Development - Update Oqood area and price' || step.Name == 'Development - Uploading Masterplan,District Plan,Property layout,Material specification' || step.Name == 'Legal - Prepare Draft SPA') {
                            Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                            stepsToActivateList.add(stepToOpen);
                        } else {
                            continue;
                        }
                        
                    } else if(previousStep.Sequence__c == 2 || previousStep.Name == 'Development - Update Oqood area and price' ){
                        if(step.Sequence__c == 6 || step.Sequence__c == 9 || step.Name == 'Sales - Update Oqood area and price' || step.Name == 'Marketing SPA Preparation') {
                            Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                            stepsToActivateList.add(stepToOpen);
                        } else {
                            continue;
                        }
                        
                    } else if(previousStep.Sequence__c == 3 || previousStep.Name == 'Development - Uploading Masterplan,District Plan,Property layout,Material specification'){
                        if(step.Sequence__c == 7 || step.Name == 'CRM - Uploading Masterplan,District Plan,Property layout,Material specification') {
                            Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                            stepsToActivateList.add(stepToOpen);
                        } else {
                            continue;
                        }
                    } else if(previousStep.Sequence__c == 4 || previousStep.Name == 'Legal - Prepare Draft SPA'){
                        if(step.Sequence__c == 5 || step.Name == 'Development - SPA Draft Review' ) {
                            Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                            stepsToActivateList.add(stepToOpen);
                        } else {
                            continue;
                        }
                    }  else if(previousStep.Sequence__c == 10 || previousStep.Name == 'CRM - SPA Finalization'){
                        if(step.Sequence__c == 11 || step.Name == 'Salesforce Package creation' ) {
                            Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                            stepsToActivateList.add(stepToOpen);
                        } else {
                            continue;
                        }
                    } else if(previousStep.Sequence__c == 11 || previousStep.Name == 'Salesforce Package creation'){
                        if( step.Sequence__c == 12 || step.Sequence__c == 13 || step.Sequence__c == 14 || step.Sequence__c == 15 || step.Name == 'SPA CRM Review' || step.Name == 'Development - SPA Review' || step.Name == 'Legal - SPA Review' || step.Name == 'DLD Reg - SPA Review' ) {
                            Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                            stepsToActivateList.add(stepToOpen);
                        } else {
                            continue;
                        }
                    }
                    
                    if(previousStep.Section_Number__c == 3 ) {
                        
                        System.debug('section3CompletedBPSList.size() = '+section3CompletedBPSList.size());
                        if(section3CompletedBPSList.size()  == 6) {
                            if( step.Name == 'CRM - SPA Finalization' && step.Status__c == 'Not Actioned' ) {
                                Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                                stepsToActivateList.add(stepToOpen);
                            }
                        }
                    }
                    
                    if(previousStep.Section_Number__c == 4 ) {
                        System.debug('section4CompletedBPSList.size() = '+section4CompletedBPSList.size());
                        if(section4CompletedBPSList.size()  == 6) {
                            if(step.Name == 'CRM - SPA Customer Release' && step.Status__c == 'Not Actioned' ) {
                                Business_Process_Step__c stepToOpen = createStepToOpen(step, nextStepOwnerID);
                                stepsToActivateList.add(stepToOpen);
                            }
                        }
                    }

                }
            }
            
            if (!stepsToActivateList.isEmpty()) {
                update stepsToActivateList;
            }
            return stepsToActivateList;
        }
            
    private Business_Process_Step__c createStepToOpen(Business_Process_Step__c step, String nextStepOwnerID) {
        Business_Process_Step__c stepToOpen = new Business_Process_Step__c();
        stepToOpen.Id = step.Id;       
        
        if (stepToOpen.Status__c == null) {
            if(step.Status__c=='Required Info'){
                stepToOpen.Status__c = 'Provided Info';
            }else if(step.Re_Open_Count__c>0){
                stepToOpen.Status__c = 'Re Open';
            }else if(step.Assigned_To__c != null){
                stepToOpen.Status__c = 'Accepted';
            } else {
                stepToOpen.Status__c = 'Open';
            }
        }
        
        System.debug('stepToOpen.Status__c = '+stepToOpen.Status__c);
        
        if(nextStepOwnerID!=null){
            stepToOpen.Assigned_To__c=nextStepOwnerID;
            stepToOpen.Status__c = 'Accepted';
        }
        
        return stepToOpen;
    }
    

}