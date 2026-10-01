/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10      Initial Draft     
**********************************************************************************************************************/

public class BusinessProcessAutomationInput {    
   public List<Business_Process_Step__c>  steps;    
   public Business_Process_Step__c  currentStep;
   public Boolean isRFMI = false;
}