/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10      Initial Draft     
**********************************************************************************************************************/

public interface  StepActivator {
    
    List<Business_Process_Step__c> activateNextSteps(Id stepId, List<Business_Process_Step__c> bpsList,Business_Process_Step__c previousStep,String nextStepOwnerID);
    //List<Business_Process_Step__c> activateNextStepss(Id stepId, List<Business_Process_Step__c> bpsList,Business_Process_Step__c previousStep,String nextStepOwnerID, Integer businessProcessPrevoiousStepSequenece);
   
}