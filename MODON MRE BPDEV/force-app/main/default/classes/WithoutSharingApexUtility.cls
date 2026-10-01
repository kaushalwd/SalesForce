/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10      Initial Draft     
**********************************************************************************************************************/
public without sharing class WithoutSharingApexUtility {
    
    Public static void updateRecord(List<Business_Process_Step__c> objBPS){
        if(objBPS!=null && objBPS.size()>0 ){
            update objBPS;
        }
    }
}