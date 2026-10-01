/**********************************************************************************************************************
* Name               : ManageBucketLwcController                                                        
* Description        : This class is used as controller for LWC (Manage Bucket)
* Usage              : manageBucket LWC                                                          
* Created By         : MODON IT                                                 
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                         Date             Comment                                                                       
* 1.1           Modon IT                       20 Sept          Managed users with group member
******************************************************************************************************************/

public with sharing class ManageBucketLwcController {
    @AuraEnabled
    public static List<BucketWrapper> getBuckets() {
        List<BucketWrapper> bucketWrapperList = new List<BucketWrapper>();
        List<Bucket__c> bucketLst = [SELECT Id, Bucket_Group_Id__c, Name, Description__c, Active__c, Number_of_units__c,Number_of_Users__c,(SELECT Id, User__c, User__r.Name, User__r.Profile.Name, User__r.Account.Name, Broker_Agency__c, Broker_Agency__r.Name FROM Bucket_Assignments__r) FROM Bucket__c];

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
    
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers(String userCategory, String searchKey, Integer limitSize, List<Id> assignedUsers) {
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 2000) ? 100 : limitSize;
        system.debug('An userCategory'+userCategory +' searchKey--->>'+searchKey+ ''+'assignedUsers'+assignedUsers+'limitSize'+limitSize);
        
        String type = String.isBlank(userCategory) ? 'Internal' : userCategory.trim();
        String userTypeFilter = (type.equalsIgnoreCase('Broker') || type.equalsIgnoreCase('Partner')) ? 'PowerPartner' : 'Standard';
        
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
                AND (Not Profile.Name like '%Egypt%')
                ORDER BY Name, Id
                LIMIT :lim
            ];
        } else if (likeContains == null && !excludeIds.isEmpty()) {
            return [
                SELECT Id, Name, Profile.Name, Username, Email, Account.Name
                FROM User
                WHERE IsActive = true AND UserType = :userTypeFilter
                AND Id NOT IN :excludeIds
                AND (Not Profile.Name like '%Egypt%')
                AND (Not Profile.Name like '%Egypt%')
                ORDER BY Name, Id
                LIMIT :lim
            ];
        } else if (likeContains != null && excludeIds.isEmpty()) {
            return [
                SELECT Id, Name, Profile.Name, Username, Email, Account.Name
                FROM User
                WHERE IsActive = true AND UserType = :userTypeFilter
                AND (Name LIKE :likeContains OR Username LIKE :likeContains OR Email LIKE :likeContains)
                AND (Not Profile.Name like '%Egypt%')
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
                AND (Not Profile.Name like '%Egypt%')
                ORDER BY Name, Id
                LIMIT :lim
            ];
        }
    }
    
    
    @AuraEnabled
    public static User[] getBucketUsers(String userType) {
        try {
            String licenseFilter = 'Salesforce\', \'Partner Community Login\', \'Partner Community';
            
            if (userType == 'Internal') {
                licenseFilter = 'Salesforce';
            } else if (userType == 'Broker') {
                licenseFilter = 'Partner Community Login\', \'Partner Community';
            }
            
            String query = 'SELECT Id, Name, Profile.Name, Username, Email, UserType, Account.Name, Profile.UserLicense.Name ' +
                'FROM User ' +
                'WHERE IsActive = true  ' +
                'AND (NOT Profile.Name LIKE \'%Egypt%\')';
            
            if (licenseFilter != '') {
                query += 'AND Profile.UserLicense.Name IN (\'' + licenseFilter + '\')';
            }
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
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
    
    @AuraEnabled
    public static void createNewBucket(Bucket__c newBucket, List<Id> userIds) {
        try {
            Group pg = new Group(
                Name = newBucket.Name,
                DeveloperName = groupDeveloperNumber(newBucket.Name),
                Type = 'Regular'
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

    @future
    public static void bucketFutureMethod(String name, String desciption, Boolean isActive, String bucketGroupId, Id bucketId) {
        Bucket__c newBucket = new Bucket__c(
            Name = name,
            Bucket_Group_Id__c = bucketGroupId,
            Description__c = desciption,
            Active__c = isActive
        );

        if (String.isNotBlank(bucketId)) {
            newBucket.Id = bucketId;
        }

        upsert newBucket;
    }

    public static String groupDeveloperNumber(String bucketName) {
        if (String.isBlank(bucketName)) {
            return null;
        }

        String cleaned = bucketName.replaceAll('\\s+', '');
        String uniqueNumber = String.valueOf(DateTime.now().getTime());

        return cleaned + '_' + uniqueNumber;
    }

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
    
    @AuraEnabled
    public static List<Bucket_Assignment__c> addUsersToBucket(Id bucketId, List<Id> userIds) {
        if (bucketId == null || userIds == null || userIds.isEmpty()) {
            throw new AuraHandledException('Bucket and at least one User are required.');
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
    
    @AuraEnabled
    public static List<Bucket_Assignment__c> removeUsersFromBucket(Id bucketId, List<Id> userIds)
    {
        if (bucketId == null || userIds == null || userIds.isEmpty()) {
            throw new AuraHandledException('Bucket and at least one User are required.');
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
    @AuraEnabled
    public static List<User> getInternalUsers(String userCategory, integer limitSize, list<Id> assignedUsers){
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 2000) ? 200 : limitSize;
        String type = String.isBlank(userCategory) ? 'Internal' : userCategory.trim();
        String userTypeFilter = (type.equalsIgnoreCase('Broker') || type.equalsIgnoreCase('Partner'))
            ? 'Partner'
            : 'Standard';
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