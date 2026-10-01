/**********************************************************************************************************************
* Name               : BlockRequestTriggerHelper                                                        
* Description        : This class is helper for Block Request trigger
* Usage              : Called from BlockRequestTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         24 Jan 2024     Initial Draft     
* 1.1           Manoj.vallapuneni@modon.com      24 Dec 2024     Update the Change as par of new status 
******************************************************************************************************************/
public without sharing class BlockRequestTriggerHelper {
    public static void checkBlockApproval(Map<Id, SObject> oldMap, Map<Id, SObject> newMap){
        Map<Id, Block_Request__c> blockRequestToApproveMap = new Map<Id, Block_Request__c>();
        Map<String, String> unitBlockRequestMap = new Map<String, String>();
        for(String key : oldMap.keySet()){
            Block_Request__c newBlock = (Block_Request__c)newMap.get(key);
            Block_Request__c oldBlock = (Block_Request__c)oldMap.get(key);
            if(oldBlock.Status__c == 'In Progress' && newBlock.Status__c == 'Approved'){
                blockRequestToApproveMap.put(key, newBlock);
                unitBlockRequestMap.put(newBlock.Unit__c, key);
            }
        }
        
        if(!blockRequestToApproveMap.isEmpty()){
            List<Unit__c> unitList = new List<Unit__c>();
            for(Block_Request__c brObj : [SELECT Id, Hourstoblock__c, Unit__c, Unit__r.BlockedFor__c, Unit__r.BlockedBy__c, Unit__r.Status__c,Unit__r.Sub_Status__c, CreatedById, Opportunity__c FROM Block_Request__c WHERE Id IN : blockRequestToApproveMap.keySet()]){
               // if(brObj.Unit__r.Status__c != 'Blocked' && brObj.Unit__r.BlockedBy__c == null){ //Update the Change as par of new status
                  if(brObj.Unit__r.Sub_Status__c != 'Assigned' && brObj.Unit__r.BlockedBy__c == null){ //Update the Change as par of new status
                    Unit__c unitObj = new Unit__c();
                    unitObj.Id = brObj.Unit__c;
                    unitObj.Status__c = 'Available';
                    unitObj.Sub_Status__c='Assigned';
                    unitObj.BlockedFor__c = brObj.CreatedById;
                    unitObj.BlockedBy__c = UserInfo.getUserId();
                   	unitObj.Opportunity__c = brObj.Opportunity__c;
                    List<String> tempLst = brObj.Hourstoblock__c.split(' ');
                    if(tempLst.size()>1){
                        unitObj.BlockUntil__c = System.now().addMinutes(Integer.valueOf(tempLst[0]));
                    }else{
                        unitObj.BlockUntil__c = System.now().addHours(Integer.valueOf(brObj.Hourstoblock__c));
                    }
                    //unitObj.BlockUntil__c = System.now().addHours(Integer.valueOf(brObj.Hourstoblock__c));
                    unitList.add(unitObj);
                }else{
                    (newMap.get(brObj.Id)).addError('Unit is already blocked by some other user.');
                }
            }
            if(!unitList.isEmpty()){
                UPDATE unitList;
            }
        }
    }
}