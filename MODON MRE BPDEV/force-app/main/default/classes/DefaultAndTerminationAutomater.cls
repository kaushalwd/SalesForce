/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class DefaultAndTerminationAutomater implements BusinessProcessAutomation {

    public void executeAutomation(BusinessProcessAutomationInput input) {

        Set<Id> defaultNoticeids = new Set<Id>();
        List<SObject> defaultNotice1Steps = new List<SObject>();
        List<SObject> defaultNotice2Steps = new List<SObject>();
        Map<Id, String> defaultNoticeMap = new Map<Id, String>();
        String taskSubject;

        // Process each BP step and route it based on its name
        for (Business_Process_Step__c step : input.steps) {

            switch on step.Name {

                when 'Finance Verification' {
                    if (step.Status__c == 'Completed') {
                    defaultNotice1Steps.add(step);
                }
                }
                when 'Collections Customer Engagement'{
                    if(step.Status__c == 'Completed'){
                        if(step.Business_Process__r.Collections_Discussion_OutCome__c!=null && 
                       step.Business_Process__r.Collections_Discussion_OutCome__c=='Close the Process' ){
                        Business_Process_Step__c stepy=new Business_Process_Step__c(Id=step.Id, Is_Process_End__c=true);
                        update stepy;
                       }
                    }

                }

                when 'Default 1  Notice Approval' {
                    // Act only when the approval step is completed
                    if (step.Status__c == 'Completed') {
                        //defaultNotice1Steps.add(step);
						System.debug('step.Business_Process__r.CRM_Manager_decision__c---->'+step.Business_Process__r.CRM_Manager_decision__c);
                        // Queue first default notice only if manager decided to proceed
                        if (step.Business_Process__r.CRM_Manager_decision__c != null &&
                            step.Business_Process__r.CRM_Manager_decision__c == 'Proceed with notification') {
                             if(!Test.isRunningTest())   
                           // BusinessProcessNintexDocumentGeneration.generateDocumentAsync(step.Id,step.Business_Process__c, 'First_Default_Notice' );    
                            defaultNoticeids.add(step.Business_Process__c);
                            defaultNoticeMap.put(
                                step.Id,
                                System.Label.First_Default_NoticeTemplate
                            );
                        }
                       // defaultNotice2Steps.add(step);

                    }
                }

                when 'Send Default 1 Notice'{

                     if (step.Status__c == 'Completed') {
                         defaultNotice2Steps.add(step);
                     }

                }

                when 'Collections Customer Negotiations' {
                    // Queue second default notice when this step becomes active
                    if (step.Status__c == 'Completed') {
                        //defaultNotice2Steps.add(step);
                       defaultNoticeMap.put(
                            step.Business_Process__c,
                            System.Label.Second_Default_Notice
                        );
                    }
                } 
                when 'Customer Solutions Status Update'{
                    if(step.Status__c=='Completed'){
                    /*
                    if(!Test.isRunningTest())     
                      BusinessProcessNintexDocumentGeneration.generateDocumentAsync(step.Id,step.Business_Process__c, 'Default_Termination_Notice' );        
                    */                    
}
                }
                when 'Default 2 Notice Approval' {
                    // Queue second default notice when this step becomes active
                    if (step.Status__c == 'Completed') {
                        defaultNoticeids.add(step.Business_Process__c);
                        if(!Test.isRunningTest())  
                        BusinessProcessNintexDocumentGeneration.generateDocumentAsync(step.Id,step.Business_Process__c, 'Second_Default_Email_Notification' );    
                            defaultNoticeMap.put(
                                step.Business_Process__c,
                                System.Label.Termination_Notice
                            );
                    }
                }

                when else {
                    // Other step names are not handled by this automator
                }
            }
        }

        // Create call tasks for each notice group with the appropriate subject
        if (!defaultNotice1Steps.isEmpty()) {
            DefaultSRActionController.createCallTask(defaultNotice1Steps, 'Default Notice1');
        }
        if (!defaultNotice2Steps.isEmpty()) {
            DefaultSRActionController.createCallTask(defaultNotice2Steps, 'Default Notice2');
        }

        // Send default notice emails in bulk for all qualifying BPs
        if (!defaultNoticeids.isEmpty()) {
            //BusinessProcessNintexDocumentGeneration.generateDocumentAsync()
            //SendDefaultNoticesFromBp.sendDefaultedEmail(defaultNoticeids, defaultNoticeMap);
        }
    }
}