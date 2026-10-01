/**********************************************************************************************************************
* Name               : JointOwnerTriggerHandler                                                        
* Description        : This class is used to handle all the joint owner trigger instances
* Usage              : Called from JointOwner
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft
* 2.0           rushi.patel@horizontal.com       22 September 2026  Added checkJointOwnerKYC to before
*                                                                insert / before update.
******************************************************************************************************************/
public without sharing class JointOwnerTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        JointOwnerTriggerHelper.checkOwnershipPercentage(newList);
        //JointOwnerTriggerHelper.checkJointOwnerKYC(newList, null);
    }

    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        JointOwnerTriggerHelper.checkOwnershipPercentage(newList);
 //JointOwnerTriggerHelper.checkJointOwnerKYC(newList, oldMap);
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        JointOwnerTriggerHelper.updateJO(oldList);
    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        JointOwnerTriggerHelper.updateJO(newList);
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        JointOwnerTriggerHelper.updateJO(newList);
    }
}