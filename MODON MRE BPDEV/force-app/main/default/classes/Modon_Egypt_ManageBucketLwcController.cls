/**********************************************************************************************************************
* Name               : Modon_Egypt_ManageBucketLwcController                                                        
* Description        : This class is used as controller for LWC (modonEgyptManageBucket) to manage buckets for MIRE Egypt team.
* Usage              : modoonEgyptManageBucket                                                          
* Created By         : Horizontal Digital                 
*
*
*================================================= NOTE ==============================================================
*
*               To give permission of Bucket management to the user, user will need permission of:
*                   - Manage Users (User Permission) 
*                     to be able to add/remove users from the bucket groups
*
*======================================================================================================================
*
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                         Date             Comment                                                                       
* 1.0           mkapatel@horizontal.com          05-02-2025       Initial Version
* 1.1          mkapatel@horizontal.com           03 Mar 2026      Used Constants common class for hardcoded values
* 1.2           mkapatel@horizontal.com          05 Mar 2026      Implemented Source Entity filter for Buckets to handle only buckets with 'Modon - Egypt' Source Entity
* 1.3           mkapatel@horizontal.com          25 Aug 2026      Added DoesIncludeBosses = false to the bucket group creation in createNewBucket method
******************************************************************************************************************/

public with sharing class Modon_Egypt_ManageBucketLwcController {

    /**************************************************************************************************************************************************************************************
     * Method		 :	getBuckets
     * Description	 :	This method is used to get all buckets and their associated group members
     * Parameters	 :  None
     * Returns		 :	List<BucketWrapper>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<BucketWrapper> getBuckets() {
        List<BucketWrapper> bucketWrapperList = new List<BucketWrapper>();
        //v1.2 - added Source Entity filter for Buckets to only pull buckets relevant to Modon - Egypt
        List<Bucket__c> bucketLst = [SELECT Id, Bucket_Group_Id__c, Name, Description__c, Active__c, Number_of_units__c,Number_of_Users__c,(SELECT Id, User__c, User__r.Name, User__r.Profile.Name, User__r.Account.Name, Broker_Agency__c, Broker_Agency__r.Name FROM Bucket_Assignments__r) FROM Bucket__c WHERE Source_Entity__c = :ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY];

        Set<Id> grpIds = new Set<Id>();
        for (Bucket__c bk: bucketLst) {
            grpIds.add(bk.Bucket_Group_Id__c);
        }

        Map<Id, List<GroupMember>> memberMap = new Map<Id, List<GroupMember>>();

        List<GroupMember> bucketMembers = [
            SELECT Id, GroupId, UserOrGroupId,
                   UserOrGroup.Name,
                   UserOrGroup.Profile.Name,
                   UserOrGroup.Account.Name
            FROM GroupMember
            WHERE GroupId IN :grpIds
        ];
        
        for (GroupMember member : bucketMembers) {
            if (!memberMap.containsKey(member.GroupId)) {
                memberMap.put(member.GroupId, new List<GroupMember>());
            }
            memberMap.get(member.GroupId).add(member);
        }
        

        if(!bucketLst.isEmpty()){
            for(Bucket__c bucketObj : bucketLst){
                BucketWrapper wrapperObj = new BucketWrapper();
                wrapperObj.bucketObj = bucketObj;
                wrapperObj.baLst = memberMap.get(bucketObj.Bucket_Group_Id__c);
                bucketWrapperList.add(wrapperObj);
            }
        }
        return bucketWrapperList;
    }
    
    /**************************************************************************************************************************************************************************************
     * Method         :   getUsers
     * Description    :   Retrieves active users filtered by category, optional search key, exclusion list, and limit.
     * Parameters     :   userCategory (String), searchKey (String), limitSize (Integer), assignedUsers (List<Id>)
     * Returns       :   List<User>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers(String userCategory, String searchKey, Integer limitSize, List<Id> assignedUsers) {
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 2000) ? 100 : limitSize;
        
        String type = String.isBlank(userCategory) ? ModonEgyptConstants.BUCKET_INTERNAL : userCategory.trim();
        String userTypeFilter = (type.equalsIgnoreCase(ModonEgyptConstants.BUCKET_BROKER) || type.equalsIgnoreCase(ModonEgyptConstants.BUCKET_PARTNER)) ? ModonEgyptConstants.BUCKET_USER_TYPE_POWER_PARTNER : ModonEgyptConstants.BUCKET_USER_TYPE_STANDARD;
        
        List<Id> excludeIds = (assignedUsers == null) ? new List<Id>() : assignedUsers;
        
        String sk = String.isBlank(searchKey) ? null : searchKey.trim();
        if (sk != null) {
            sk = sk.replace('\\','\\\\').replace('%','\\%').replace('_','\\_'); // escape LIKE wildcards
        }
        String likeContains = (sk == null) ? null : '%' + sk + '%';
        
        if (likeContains == null && excludeIds.isEmpty()) {
            return [
                SELECT Id, Name, Profile.Name, Username, Email, Account.Name
                FROM User
                WHERE IsActive = true AND UserType = :userTypeFilter
                AND Profile.Name like :ModonEgyptConstants.BUCKET_PROFILE_LIKE_EGYPT
                ORDER BY Name, Id
                LIMIT :lim
            ];
        } else if (likeContains == null && !excludeIds.isEmpty()) {
            return [
                SELECT Id, Name, Profile.Name, Username, Email, Account.Name
                FROM User
                WHERE IsActive = true AND UserType = :userTypeFilter
                AND Id NOT IN :excludeIds
                AND Profile.Name like :ModonEgyptConstants.BUCKET_PROFILE_LIKE_EGYPT
                ORDER BY Name, Id
                LIMIT :lim
            ];
        } else if (likeContains != null && excludeIds.isEmpty()) {
            return [
                SELECT Id, Name, Profile.Name, Username, Email, Account.Name
                FROM User
                WHERE IsActive = true AND UserType = :userTypeFilter
                AND (Name LIKE :likeContains OR Username LIKE :likeContains OR Email LIKE :likeContains)
                AND Profile.Name like :ModonEgyptConstants.BUCKET_PROFILE_LIKE_EGYPT
                ORDER BY Name, Id
                LIMIT :lim
            ];
        } else {
            return [
                SELECT Id, Name, Profile.Name, Username, Email, Account.Name
                FROM User
                WHERE IsActive = true AND UserType = :userTypeFilter
                AND (Name LIKE :likeContains OR Username LIKE :likeContains OR Email LIKE :likeContains)
                AND Id NOT IN :excludeIds
                AND Profile.Name like :ModonEgyptConstants.BUCKET_PROFILE_LIKE_EGYPT
                ORDER BY Name, Id
                LIMIT :lim
            ];
        }
    }
    
    
    /**************************************************************************************************************************************************************************************
     * Method         :   getBucketUsers
     * Description    :   Returns active users for buckets filtered by high-level userType and restricted to Egypt profiles.
     * Parameters     :   userType (String)
     * Returns       :   User[]
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static User[] getBucketUsers(String userType) {
        try {
            String licenseFilter = ModonEgyptConstants.BUCKET_LICENSES_PARTNER;
            
            if (userType == ModonEgyptConstants.BUCKET_INTERNAL) {
                licenseFilter = ModonEgyptConstants.BUCKET_LICENSE_SF;
            } else if (userType == ModonEgyptConstants.BUCKET_BROKER) {
                licenseFilter = ModonEgyptConstants.BUCKET_LICENSES_PARTNER;
            }
            
            String query = 'SELECT Id, Name, Profile.Name, Username, Email, UserType, Account.Name, Profile.UserLicense.Name ' +
                'FROM User ' +
                'WHERE IsActive = true  ' +
                'AND Profile.Name LIKE \'' + ModonEgyptConstants.BUCKET_PROFILE_LIKE_EGYPT + '\'';
            
            if (licenseFilter != '') {
                query += ' AND Profile.UserLicense.Name IN (\'' + licenseFilter + '\')';
            }
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**************************************************************************************************************************************************************************************
     * Method         :   updateBucket
     * Description    :   Updates an existing bucket's group membership and attributes.
     * Parameters     :   bucketObj (Bucket__c), newUserIds (List<Id>), removedUserIds (List<Id>)
     * Returns        :   void
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static void updateBucket(Bucket__c bucketObj,List<Id> newUserIds,List<Id> removedUserIds) {
        try {
            Bucket__c[] bucket = [SELECT Id, Bucket_Group_Id__c FROM Bucket__c WHERE Id = :bucketObj.Id];
            Group pg = [SELECT Id FROM Group WHERE Id = :bucket[0].Bucket_Group_Id__c];

            if (newUserIds.size() > 0) {
                List<Id> mergedUserIds = getMergedPartnerUserIds(newUserIds);
                // addUsersToBucket(bucketObj.Id, mergedUserIds);
                addBucketGroupMembers(mergedUserIds, pg.Id);
            }
            
            List<Id> removedMergedUserIds = getMergedPartnerUserIds(removedUserIds);
            delete [SELECT Id FROM GroupMember WHERE GroupId = :pg.Id AND UserOrGroupId IN :removedMergedUserIds];
            
            bucketFutureMethod(bucketObj.Name, bucketObj.Description__c, bucketObj.Active__c, pg.Id, bucketObj.Id);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**************************************************************************************************************************************************************************************
     * Method         :   createNewBucket
     * Description    :   Creates a new bucket along with a backing public group, assigns users, and persists the bucket.
     * Parameters     :   newBucket (Bucket__c), userIds (List<Id>)
     * Returns        :   void
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static void createNewBucket(Bucket__c newBucket, List<Id> userIds) {
        try {
            Group pg = new Group(
                Name = newBucket.Name,
                DeveloperName = groupDeveloperNumber(newBucket.Name),
                Type = ModonEgyptConstants.BUCKET_GROUP_TYPE_REGULAR,
                DoesIncludeBosses = false // v1.3
            );
            insert pg;

            List<Id> mergedUserIds = getMergedPartnerUserIds(userIds);
            // addUsersToBucket(newBucket.Id, mergedUserIds);
            addBucketGroupMembers(mergedUserIds, pg.Id);


            newBucket.Bucket_Group_Id__c = pg.Id;
            bucketFutureMethod(newBucket.Name, newBucket.Description__c, newBucket.Active__c, pg.Id, null);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**************************************************************************************************************************************************************************************
     * Method         :   bucketFutureMethod
     * Description    :   Asynchronously upserts a Bucket__c record using provided primitive parameters.
     * Parameters     :   name (String), desciption (String), isActive (Boolean), bucketGroupId (String), bucketId (Id)
     * Returns        :   void
    ***************************************************************************************************************************************************************************************/
    @future
    public static void bucketFutureMethod(String name, String desciption, Boolean isActive, String bucketGroupId, Id bucketId) {
        Bucket__c newBucket = new Bucket__c(
            Name = name,
            Bucket_Group_Id__c = bucketGroupId,
            Description__c = desciption,
            Active__c = isActive,
            //v1.2 creating all new buckets with 'Modon - Egypt'
            Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY
        );

        if (String.isNotBlank(bucketId)) {
            newBucket.Id = bucketId;
        }

        upsert newBucket;
    }

    /**************************************************************************************************************************************************************************************
     * Method         :   groupDeveloperNumber
     * Description    :   Builds a unique, developer-friendly name by removing spaces and appending a timestamp suffix.
     * Parameters     :   bucketName (String)
     * Returns        :   String
    ***************************************************************************************************************************************************************************************/
    public static String groupDeveloperNumber(String bucketName) {
        if (String.isBlank(bucketName)) {
            return null;
        }

        String cleaned = bucketName.replaceAll('\\s+', '');
        String uniqueNumber = String.valueOf(DateTime.now().getTime());

        return cleaned + '_' + uniqueNumber;
    }

    /**************************************************************************************************************************************************************************************
     * Method         :   getMergedPartnerUserIds
     * Description    :   Expands a list of user Ids to include all partner users on the same accounts as any partner users in the input.
     * Parameters     :   userIds (List<Id>)
     * Returns        :   List<Id>
    ***************************************************************************************************************************************************************************************/
    private static List<Id> getMergedPartnerUserIds(List<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new List<Id>();
        }

        // Step 1: Find which of the input users are partner users
        List<User> partnerUsers = [
            SELECT Id, AccountId, IsPartner
            FROM User
            WHERE Id IN :userIds
            AND IsPartner = true
            AND AccountId != null
        ];

        if (partnerUsers.isEmpty()) {
            // No partner users found — return just the input
            return new List<Id>(userIds);
        }

        // Step 2: Collect account ids from those partner users
        Set<Id> accountIds = new Set<Id>();
        for (User u : partnerUsers) {
            accountIds.add(u.AccountId);
        }

        // Step 3: Get all partner users from those accounts
        List<User> allPartnerUsers = [
            SELECT Id
            FROM User
            WHERE AccountId IN :accountIds
            AND IsPartner = true
        ];

        // Step 4: Merge input + related partner users (Set handles duplicates)
        Set<Id> mergedUserIds = new Set<Id>(userIds);
        for (User u : allPartnerUsers) {
            mergedUserIds.add(u.Id);
        }

        return new List<Id>(mergedUserIds);
    }

    /**************************************************************************************************************************************************************************************
     * Method         :   addBucketGroupMembers
     * Description    :   Adds users to a public group while avoiding duplicates.
     * Parameters     :   userIds (List<Id>), grpId (Id)
     * Returns        :   void
    ***************************************************************************************************************************************************************************************/
    private static void addBucketGroupMembers(List<Id> userIds, Id grpId) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }

        Set<Id> existingUserIds = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :grpId
            AND UserOrGroupId IN :userIds
        ]) {
            existingUserIds.add(gm.UserOrGroupId);
        }

        List<GroupMember> newMembers = new List<GroupMember>();
        for (Id uid : userIds) {
            if (!existingUserIds.contains(uid)) {
                newMembers.add(new GroupMember(
                    GroupId = grpId,
                    UserOrGroupId = uid
                ));
            }
        }

        if (!newMembers.isEmpty()) {
            insert newMembers;
        }
    }
    
    /**************************************************************************************************************************************************************************************
     * Method         :   addUsersToBucket
     * Description    :   Creates Bucket_Assignment__c records for the given users if not already assigned.
     * Parameters     :   bucketId (Id), userIds (List<Id>)
     * Returns        :   List<Bucket_Assignment__c>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<Bucket_Assignment__c> addUsersToBucket(Id bucketId, List<Id> userIds) {
        if (bucketId == null || userIds == null || userIds.isEmpty()) {
            throw new AuraHandledException(ModonEgyptConstants.BUCKET_ERR_BUCKET_USER_REQUIRED);
        }
        
        Set<Id> uSet = new Set<Id>(userIds);
        
        // Fetch existing assignments to avoid duplicates
        Map<Id, Bucket_Assignment__c> existingByUser = new Map<Id, Bucket_Assignment__c>([SELECT Id, User__c FROM Bucket_Assignment__c WHERE Bucket__c = :bucketId AND User__c IN :uSet]);
        
        // Fetch user names
        Map<Id, String> userIdToName = new Map<Id, String>();
        for (User u : [SELECT Id, Name FROM User WHERE Id IN :uSet]) {
            userIdToName.put(u.Id, u.Name);
        }
        
        // Create new assignments
        List<Bucket_Assignment__c> toInsert = new List<Bucket_Assignment__c>();
        for (Id uid : uSet) {
            if (!existingByUser.containsKey(uid)) {
                toInsert.add(new Bucket_Assignment__c(
                    Bucket__c = bucketId,
                    User__c = uid,
                    Name = userIdToName.get(uid) // Set name to the user's name
                ));
            }
        }
        
        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, false);
        }
        
        return [
            SELECT Id, Name, User__c, User__r.Name, User__r.Profile.Name, Broker_Agency__r.Name
            FROM Bucket_Assignment__c
            WHERE Bucket__c = :bucketId AND User__c IN :uSet
        ];
    }
    
    /**************************************************************************************************************************************************************************************
     * Method         :   removeUsersFromBucket
     * Description    :   Deletes Bucket_Assignment__c records for specified users from the provided bucket.
     * Parameters     :   bucketId (Id), userIds (List<Id>)
     * Returns        :   List<Bucket_Assignment__c>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<Bucket_Assignment__c> removeUsersFromBucket(Id bucketId, List<Id> userIds)
    {
        if (bucketId == null || userIds == null || userIds.isEmpty()) {
            throw new AuraHandledException(ModonEgyptConstants.BUCKET_ERR_BUCKET_USER_REQUIRED);
        }
        
        List<Bucket_Assignment__c> toDelete = [
            SELECT Id
            FROM Bucket_Assignment__c
            WHERE Bucket__c = :bucketId AND User__c IN :userIds
        ];
        
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete, false);
        }
        
        return [
            SELECT Id, User__c, User__r.Name, User__r.Profile.Name, Broker_Agency__r.Name
            FROM Bucket_Assignment__c
            WHERE Bucket__c = :bucketId
        ];
    }
    /**************************************************************************************************************************************************************************************
     * Method         :   getInternalUsers
     * Description    :   Retrieves active internal users (or partner if specified) excluding already assigned users.
     * Parameters     :   userCategory (String), limitSize (Integer), assignedUsers (List<Id>)
     * Returns        :   List<User>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<User> getInternalUsers(String userCategory, integer limitSize, list<Id> assignedUsers){
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 2000) ? 200 : limitSize;
        String type = String.isBlank(userCategory) ? ModonEgyptConstants.BUCKET_INTERNAL : userCategory.trim();
        String userTypeFilter = (type.equalsIgnoreCase(ModonEgyptConstants.BUCKET_BROKER) || type.equalsIgnoreCase(ModonEgyptConstants.BUCKET_PARTNER))
            ? ModonEgyptConstants.BUCKET_PARTNER
            : ModonEgyptConstants.BUCKET_USER_TYPE_STANDARD;
        system.debug('assignedUsers==>' + assignedUsers);
        return [
            SELECT Id, Name, Profile.Name 
            FROM User 
            WHERE IsActive = true 
            AND UserType = :userTypeFilter 
            AND Id NOT IN :assignedUsers
            ORDER BY Name 
            LIMIT 10
        ];
    }
    
    public class BucketWrapper {
        @AuraEnabled
        public Bucket__c bucketObj;
        @AuraEnabled
        public List<GroupMember> baLst;
    }
}