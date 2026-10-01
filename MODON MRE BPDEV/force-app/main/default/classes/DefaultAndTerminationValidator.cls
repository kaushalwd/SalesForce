/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class DefaultAndTerminationValidator implements StepValidator {
    
     public void ValidateSteps(Business_Process_Step__c bpStep){
        
    AuraHandledException e = new AuraHandledException('exception');
        switch on bpStep.Name {
            when 'Collections Customer Engagement' {
             List<Task> taskList=[Select Id, CreatedBy.Name, Subject, Owner.Name,Status from task where
                                  WhatId =:bpStep.Business_Process__c and Subject like 'Call Task - Finance Verification - Default Notice%'  
                                 and Status='Open'];
                if(taskList.size()>0){
                   throw new AuraHandledException('Collections Customer Engagement task is still open. Please complete it before proceeding.');  
                }
            //if(bpStep.Business_Process__r.D_T_Customer_Discussion_Outcome__c==null)
               // throw new AuraHandledException('please update the D&T Customer Discussion Outcome field update before approving the step');
            }

            when 'Collections Customer Negotiations' {
             List<Task> taskList=[Select Id, CreatedBy.Name, Subject, Owner.Name,Status from task where
                                  WhatId =:bpStep.Business_Process__c and Subject like 'Call Task - Default 1  Notice Approval - Default Notice%'  
                                 and Status='Open'];
                if(taskList.size()>0){
                   throw new AuraHandledException('Collections Customer Negotiations task is still open. Please complete it before proceeding.');  
                }
            if(bpStep.Business_Process__r.D_T_Customer_Discussion_Outcome__c==null)
                throw new AuraHandledException('please update the D&T Customer Discussion Outcome field update before approving the step');
            
            if(bpStep.Business_Process__r.D_T_Customer_Discussion_Outcome__c !=null && 
               bpStep.Business_Process__r.D_T_Customer_Discussion_Outcome__c =='Customer Agreed To Pay' && 
               bpStep.Business_Process__r.Customer_Agreed_Payment_Date__c ==null
               ){
                 throw new AuraHandledException('Please update Customer Agreed Payment Date');
               }
            
            }

            
            when 'Legal Discussions' {
                  Business_Process__c bproc=[Select Id,Legal_Status__c from Business_Process__c where Id=:bpStep.Business_Process__c];
                  if(bproc!=null && bproc.Legal_Status__c==null){
                  throw new AuraHandledException('Legal Status should be updated before completing the step');  
                  }

            }
             when else {
                //throw new AuraHandledException('Input cannot be blank.');
            }  
                
        }
            
            
      }

}