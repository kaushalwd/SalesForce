public without sharing class UserTriggerHelper {

    @future(callout=true)
    public static void assignBrokerToBucket(set<Id> userIds) {
        User[] brokerUsers = [SELECT Id, Name, AccountId, Account.BillingCity FROM User WHERE Id IN :userIds];

        List<User> abuDhabiBrokers = new List<User>();
        List<User> dubaiBrokers = new List<User>();
        for (User usr: brokerUsers) {
            if (usr.AccountId == null || usr?.Account?.BillingCity == null) {
                continue;
            }
			String billingCity = usr.Account.BillingCity.toLowerCase();
            if (usr?.Account?.BillingCity == Constants.ABU_DHABI_CITY.toLowerCase()) {
                abuDhabiBrokers.add(usr);
            } else if (usr.Account.BillingCity == Constants.DUBAI_CITY.toLowerCase()) {
                dubaiBrokers.add(usr);
            }
        }

        if (!abuDhabiBrokers.isEmpty()) {
            assignAbuDhabiBrokerToBucket(abuDhabiBrokers);
        }

        if (!dubaiBrokers.isEmpty()) {
            assignDubaiBrokerToBucket(dubaiBrokers);
        }
    }

    @future(callout=true)
    public static void removeDeactiveUserFromBucket(set<Id> userIds) {
        //delete [SELECT Id FROM Bucket_Assignment__c WHERE User__c IN :userIds];
        delete [SELECT Id FROM GroupMember WHERE UserOrGroupId IN :userIds];
    }

    private static void assignDubaiBrokerToBucket(List<User> dubaiBrokers) {
        Bucket__c[] dubaiBuckets = [SELECT Id, Name, Bucket_Group_Id__c FROM Bucket__c WHERE Name = :Constants.DUBAI_BUCKET LIMIT 1];

        if (dubaiBuckets.isEmpty()) {
            return;
        }

        List<GroupMember> newMembers = new List<GroupMember>();
        for (User usr: dubaiBrokers) {
            newMembers.add(new GroupMember(
                GroupId = dubaiBuckets[0].Bucket_Group_Id__c,
                UserOrGroupId = usr.Id
            ));
        }

        if (!newMembers.isEmpty()) {
            insert newMembers;
        }

        // Bucket_Assignment__c[] brokerAssignments = new List<Bucket_Assignment__c>();
        // for (User usr: dubaiBrokers) {
        //     brokerAssignments.add(new Bucket_Assignment__c(Name = usr.Name, Bucket__c = dubaiBuckets[0].Id, Broker_Agency__c = usr.AccountId, User__c = usr.Id));
        // }

        // if (!brokerAssignments.isEmpty()) {
        //     insert brokerAssignments;
        // }
    }

    private static void assignAbuDhabiBrokerToBucket(List<User> abuDhabiBrokers) {
        Bucket__c[] abuDhabiBuckets = [SELECT Id, Name, Bucket_Group_Id__c FROM Bucket__c WHERE Name = :Constants.ABU_DHABI_BUCKET LIMIT 1];

        if (abuDhabiBuckets.isEmpty()) {
            return;
        }
        
        List<GroupMember> newMembers = new List<GroupMember>();
        for (User usr: abuDhabiBrokers) {
            newMembers.add(new GroupMember(
                GroupId = abuDhabiBuckets[0].Bucket_Group_Id__c,
                UserOrGroupId = usr.Id
            ));
        }

        if (!newMembers.isEmpty()) {
            insert newMembers;
        }

        // Bucket_Assignment__c[] brokerAssignments = new List<Bucket_Assignment__c>();
        // for (User usr: abuDhabiBrokers) {
        //     brokerAssignments.add(new Bucket_Assignment__c(Name = usr.Name, Bucket__c = abuDhabiBuckets[0].Id, Broker_Agency__c = usr.AccountId, User__c = usr.Id));
        // }

        // if (!brokerAssignments.isEmpty()) {
        //     insert brokerAssignments;
        // }
    }
}