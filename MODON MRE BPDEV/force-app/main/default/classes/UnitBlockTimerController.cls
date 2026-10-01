/**
* Description: Controller for unitBlockTimer LWC
* Author: Yazan Saeed
* Name: UnitBlockTimerController
* Created Date: 06th February 2024
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 06th Feb 2024     Yazan Saeed         V1.0                Initial Version
**************************************************************************************************
*/

public without sharing class UnitBlockTimerController{

   @AuraEnabled
   public static RespondWrap getUnitDetails(String requestWrapParam)  {

        //declaration and deseriliaze of wrapper
        RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap =  new RespondWrap();

        List<SalesOrder__c> soList = new List<SalesOrder__c>();

        for( SalesOrder__c soObj : [SELECT Id, CreatedDate  FROM SalesOrder__c WHERE Id = :reqWrap.recordId LIMIT 1]){
            soList.add(soObj);
        }

        if(!soList.isEmpty()){
            for(SalesOrder__c soObj : soList){

                if(soObj.CreatedDate != NULL){
                    respWrap.createdDate = soObj.CreatedDate;
                }
            }
        }

        return respWrap;
   }
    

   // ------------ Wrapper List ----------- //
    
   public class RequestWrap{

       @AuraEnabled public String recordId;
   }
    
   public class RespondWrap{

       @AuraEnabled public DateTime createdDate;
   }

}