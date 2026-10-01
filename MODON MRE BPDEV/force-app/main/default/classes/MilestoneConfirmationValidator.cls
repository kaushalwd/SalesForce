/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class MilestoneConfirmationValidator  implements StepValidator {
    
     public void ValidateSteps(Business_Process_Step__c bpStep){
        
    AuraHandledException e = new AuraHandledException('exception');
        switch on bpStep.Name {
            when 'DLD Registration Process Initiation' {
                
            }
             when else {
                //throw new AuraHandledException('Input cannot be blank.');
            }  
                
        }
            
            
      }

}