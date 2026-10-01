/**********************************************************************************************************************
* Name               : FeedItemTriggerHelper                                                        
* Description        :  * Handles FeedItem-related validations, specifically controlling deletion permissions based on user profile whitelist.
* Usage              : Called from FeedItemTriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      24 Feb 2026     Initial Draft 
***********************************************************************************************************************/
public without sharing class FeedItemTriggerHelper 
{ 
    @TestVisible
    static String testLabelOverride;//adding this to handle blank value for the custom label from test methods
    
    /**
    * Method Name: checkUserPermissionForDeletion
    * Restricts FeedItem deletion based on profile whitelist.
    * @param oldList  Trigger.old FeedItem records.
    */
    public static void checkUserPermissionForDeletion(List<SObject> oldList)
    {system.debug('debug: in FeedItemTriggerHelper.checkUserPermissionForDeletion method');
     
     String labelValue = testLabelOverride != null ? testLabelOverride : System.Label.Case_FeedItem_Deletion_Profiles_Whitelist;
     
     if (String.isBlank(labelValue)) {return;}
     
     // Prepare allowed profile names
     Set<String> allowedProfiles = new Set<String>();
     for (String name : labelValue.split(',')) {
         system.debug('debug: name: ' + name);
         allowedProfiles.add(name.trim());
     }
     
     // Get current user's profile name
     String currentProfileName = [
         SELECT Profile.Name
         FROM User
         WHERE Id = :UserInfo.getUserId()
     ].Profile.Name;
     
     system.debug('debug: currentProfileName: ' + currentProfileName);
     
     List<FeedItem> odlRecs = (List<FeedItem>)oldList;
     
     if (!allowedProfiles.contains(currentProfileName)) {
         for (FeedItem fi : odlRecs) {
             fi.addError(System.Label.Case_FeedItem_Deletion_Message);
         }
     }
    }
}