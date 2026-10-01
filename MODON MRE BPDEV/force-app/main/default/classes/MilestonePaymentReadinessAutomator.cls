/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class MilestonePaymentReadinessAutomator implements BusinessProcessAutomation {
    
     public void executeAutomation( BusinessProcessAutomationInput input){
        
       for(Business_Process_Step__c step:input.steps){
            switch on step.Name {
                when 'DLD Completion with Payment' {
                    if(step.Status__c=='Completed'){
                        
                }
                }
                when else {
                    //throw new AuraHandledException('Input cannot be blank.');
                }
            }
        }
        
           
       }


}