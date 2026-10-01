/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
trigger BusinessProcessStepTrigger on Business_Process_Step__c (before update,after Insert,before Insert, after update) {
    
    new BusinessProcessStepTriggerHandler().run('BusinessProcessStep'); 
    
}