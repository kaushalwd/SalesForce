/**
* @File Name : MBP_utilityclass.cls
* @Description :Reusable Utility Class for dynamic picklists & user context
* @Author :raghu.chilukuri@activemindsit.com.srdev
* @Last Modified By :raghu.chilukuri@activemindsit.com.srdev
* @Last Modified On : September 9, 2025
* @group            : Broker Portal Utilities
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 9, 2025 |   | Initial Version
**/

public with sharing class MBP_utilityclass {
    
    private static User currentUser {
        get {
            if(currentUser == null) {
                currentUser = [SELECT Id,Name,AccountId, Account.Name,Account.Broker_Classification__c,Account.Bank_Account_Number__c,Account.Rank__c, ContactId, Contact.Name, 
                              Contact.Email, Contact.Phone, Contact.Broker_Type__c, 
                              CreatedBy.Name, Profile.Name, UserRole.Name
                              FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            }
            return currentUser;
        }
        set;
    }

    // Public method to get current user for other classes
    public static User getCurrentUser() {
        return currentUser;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDynamicPicklistValues(String objectName, String fieldName) {
        List<Map<String, String>> picklistValues = new List<Map<String, String>>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        Schema.SObjectField field = fieldMap.get(fieldName);
        
        Schema.DescribeFieldResult fieldResult = field.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        
        for(Schema.PicklistEntry entry : picklistEntries) {
            if(entry.isActive()) {
                picklistValues.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        
        return picklistValues;
    }

	
     @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDependentPicklistValues(
        String objectName, String controllingField, String dependentField) {
            
        Map<String, List<Map<String, String>>> dependentMap = new Map<String, List<Map<String, String>>>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        
        Schema.SObjectField controllingFieldObj = fieldMap.get(controllingField);
        Schema.SObjectField dependentFieldObj = fieldMap.get(dependentField);
        
        List<Schema.PicklistEntry> controllingValues = controllingFieldObj.getDescribe().getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldObj.getDescribe().getPicklistValues();
        
        for(Schema.PicklistEntry controllingEntry : controllingValues) {
            if(controllingEntry.isActive()) {
                dependentMap.put(controllingEntry.getValue(), new List<Map<String, String>>());
            }
        }
        
        for(Schema.PicklistEntry dependentEntry : dependentValues) {
            if(dependentEntry.isActive()) {
                Map<String, String> valueMap = new Map<String, String>{
                    'label' => dependentEntry.getLabel(),
                    'value' => dependentEntry.getValue()
                };
                
                for(String controllingValue : dependentMap.keySet()) {
                    dependentMap.get(controllingValue).add(valueMap);
                }
            }
        }
        
        return dependentMap;
    }


    @AuraEnabled(cacheable=true)
        public static Id getQueueIdByDeveloperName(String queueDevName) {
          try {
	               return [SELECT Id FROM Group WHERE DeveloperName = :queueDevName AND Type = 'Queue' LIMIT 1].Id;
               } catch (Exception e) {
	                             throw new AuraHandledException('Queue not found: ' + queueDevName);
              }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCurrentUserInfo() {
        Map<String, Object> userInfo = new Map<String, Object>();
        
        userInfo.put('userId', currentUser.Id);
        userInfo.put('userName', currentUser.Name);
        userInfo.put('profileName', currentUser.Profile.Name);
        userInfo.put('userRole', currentUser.UserRole?.Name);
        userInfo.put('contactId', currentUser.ContactId);
        userInfo.put('contactName', currentUser.Contact?.Name);
        userInfo.put('contactEmail', currentUser.Contact?.Email);
        userInfo.put('contactPhone', currentUser.Contact?.Phone);
        userInfo.put('brokerType', currentUser.Contact?.Broker_Type__c);
        userInfo.put('accountId', currentUser.AccountId);
        userInfo.put('accountName', currentUser.Account?.Name);
        
        return userInfo;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean hasBrokerType(String brokerType) {
        return currentUser.Contact?.Broker_Type__c == brokerType;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBrokerTypes() {
        return getDynamicPicklistValues('Contact', 'Broker_Type__c');
    }
}