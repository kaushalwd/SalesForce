/* Version       Author                          Date            Comment                                                                      
  1.0           raghu.chilukuri@activemindsit.com   16/04/26     Updated the loop to skip future calls
**********************************************************************************************
*/

public with sharing class UserTriggerHandler extends TriggerHandler {

    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap) {
        User[] users = [SELECT Id, Profile.Name FROM User WHERE Id IN :newMap.keySet()];

        Set<Id> brokerUser = new Set<Id>();
        for (User usr: users) {
            if (usr?.Profile?.Name?.contains(Constants.PARTNER_COMMUNITY_PROFILE)) {
                brokerUser.add(usr.Id);
            }
        }

        if (brokerUser.size() > 0 && !System.isFuture() && !System.isBatch()) {
            UserTriggerHelper.assignBrokerToBucket(brokerUser);
        }
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
		User[] users = [SELECT Id, Profile.Name, isActive FROM User WHERE Id IN :newMap.keySet()];

        Set<Id> deactiveUsers = new Set<Id>();
        Set<Id> activeUsers = new Set<Id>();
        for (User newUser: users) {
            User oldUser = (User) oldMap.get(newUser.Id);

            if (oldUser.IsActive == newUser.IsActive) {
                continue;
            }
            
            if (!newUser.isActive) {
                deactiveUsers.add(newUser.Id);
            } else if (newUser.isActive && newUser?.Profile?.Name?.contains(Constants.PARTNER_COMMUNITY_PROFILE)) {
                activeUsers.add(newUser.Id);
            }
        }
        
        /*Update Version 1.0 
        @description : Updated the Loop to skip future calls
        */
      /*  if (!deactiveUsers.isEmpty()) {
	        UserTriggerHelper.removeDeactiveUserFromBucket(deactiveUsers);            
}*/ //previous lines
        
          if (!deactiveUsers.isEmpty() && !System.isFuture() && !System.isBatch()) {
            UserTriggerHelper.removeDeactiveUserFromBucket(deactiveUsers);            
          }
        
        /*Update Version 1.0 Ends Here*/
        
        if (!activeUsers.isEmpty() && !System.isFuture() && !System.isBatch()) {
	        UserTriggerHelper.assignBrokerToBucket(activeUsers);            
        }
    }
}