/* Version       Author                          Date            Comment                                                                      
* 1.0           sanath.manohar@activemindsit.com    19 Dec 2023      Initial Draft   
  1.1           raghu.chilukuri@activemindsit.com    24-03-2026       Ignored user fetch Logic For broker Management Team and Created a Wrapper To add 
                                                                     Email and Phone From the custom Label and Used them as Email and Phone Into portal for Broker Management team.
**********************************************************************************************
*/
public without sharing class MBP_UserTeamController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<UserInfoWrapper>> getTeamUsers() {
        Map<String, List<UserInfoWrapper>> result = new Map<String, List<UserInfoWrapper>>();
        
        List<UserInfoWrapper> brokerTeam = new List<UserInfoWrapper>();
        List<UserInfoWrapper> salesTeam = new List<UserInfoWrapper>();
        List<UserInfoWrapper> brokerAdminTeam = new List<UserInfoWrapper>();

        /*update Version 1.1
        @description : created a New Wrapper to addthe custom labels from Salesforce To use Email and Phone
        * of Broker management team as a Constant Value.
        */
        UserInfoWrapper brokerWrapper = new UserInfoWrapper();
        brokerWrapper.email = System.Label.MBP_BrokermanagementEmail;
        brokerWrapper.phone = System.Label.MBP_BrokermanagementPhone;
        brokerTeam.add(brokerWrapper);
        //Update version 1.1 ends here
        
        // Set to track assigned user IDs to avoid duplicates
        Set<Id> assignedUserIds = new Set<Id>();

        for (User u : [
            SELECT Id, Name, FirstName, LastName, FullPhotoUrl, Profile.Name, UserRole.Name, Email, Phone, Twitter__c, LinkedIn__c, UserName
            FROM User WHERE IsActive = true AND ((UserRole.Name IN ('Broker Manager')) 
                                                 OR Profile.Name in ('Broker Management', 'Sales Management', 'Sales Operation'))] ) {
            /**if (assignedUserIds.contains(u.Id)) {
                continue; // Skip already assigned users
            }*/
            UserInfoWrapper userWrapper = new UserInfoWrapper();
            //userWrapper.name = u.Name;
            userWrapper.name = u.FirstName + ' ' + u.LastName;
            userWrapper.profileName = u.Profile.Name;
            userWrapper.photoUrl = u.FullPhotoUrl;
            userWrapper.email = u.Email;
            userWrapper.phone = u.Phone;
            userWrapper.twitterUrl = u.Twitter__c;
            userWrapper.linkedInUrl = u.LinkedIn__c;

            /*Update version 1.1
            @description: removed the Hardcoded Broker Management Team Names and Thier Values
            */

            if (u.UserRole != null && u.Profile.Name == 'Sales Management') {
                salesTeam.add(userWrapper);
                //assignedUserIds.add(u.Id);
            }

            //Update ends Here
        }

        result.put('BrokerManagementTeam', brokerTeam);
        result.put('SalesTeam', salesTeam);
        //result.put('BrokerAdminTeam', brokerAdminTeam);
        System.debug('result:::'+result);
        return result;
    }

    public class UserInfoWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String profileName;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String roleName;
        @AuraEnabled public String twitterUrl;
        @AuraEnabled public String linkedInUrl;
    }

}