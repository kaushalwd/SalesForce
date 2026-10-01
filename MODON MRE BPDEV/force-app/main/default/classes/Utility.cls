/*
* @Author: Maanoj 
* @CreatedDate: 24th Nov 2024
* @Description: Utility
*/
/*****************************************************************************************************
* Version       Author      Date             Comment                                                                       
* 1.0           Manoj   24NOV2024      	 Initial draft 
*****************************************************************************************************/
public class Utility {
    
    public static String getRandomString(Integer len) {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            randStr += chars.substring(idx, idx+1);
        }
        return randStr; 
    }
    
    public static String getAllFields(String sobjectName) {
        Set<String> fieldNames = Schema.getGlobalDescribe().get(sobjectName).getDescribe().fields.getMap().keySet();
        return String.join(new List<String>(fieldNames), ',');
    } 
    public static Id getRecordTypeIdByDevName(Schema.SObjectType sObjType, string recTypeDevName){
        Id recTypeId;
        if(sObjType != NULL && String.isNotBlank(recTypeDevName)){
            recTypeId = sObjType.getDescribe().getRecordTypeInfosByDeveloperName().get(recTypeDevName).getRecordTypeId();
        }  
        return recTypeId;  
    }
    
    public static Id getRecordTypeIdByName(Schema.SObjectType sObjType, string recTypeName){
        Id recTypeId;
        if(sObjType != NULL && String.isNotBlank(recTypeName)){
            recTypeId = sObjType.getDescribe().getRecordTypeInfosByName().get(recTypeName).getRecordTypeId();
        }  
        return recTypeId;  
    }
    
    public static Map<String, String> getPicklistValues(Schema.SObjectType sObjType, String fieldAPIName){
        Map<String, String> options = new Map<String, String>();
        Schema.DescribeFieldResult fieldResult = sObjType.getDescribe().fields.getMap().get(fieldAPIName).getDescribe();
        List<Schema.PicklistEntry> pList = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry p: pList) {
            options.put(p.getValue(), p.getLabel());
        }
        return options;
    }
    
    public static Boolean checkAnyFieldChange(Sobject newObj, Sobject oldObj) {
        for (String field : newObj.getSObjectType().getDescribe().fields.getMap().keySet()) {
            if (newObj.get(field) != oldObj.get(field)) {
                return true;
            }
        }
        return false;
    }
    
    public static List<String> getUserEmailsFromPublicGroupId(Id groupId) {
        List<User> groupUsers = new List<User>();
        List<String> userEmails = New List<String>();
        if(String.isNotBlank(groupId)){
            Set<Id> userIds = new Set<Id>();
            for (GroupMember member : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :groupId]) {
                userIds.add(member.UserOrGroupId);
            }
            
            UserService objUserService = UserService.getInstance();
            for(User u:objUserService.getUsersByIds(userIds)){
                userEmails.add(u.Email);
            }
        }
        return userEmails;
    }
    
    public static List<String> getUserEmailsFromPublicGroupIds(Set<Id> groupIds) {
        List<User> groupUsers = new List<User>();
        List<String> userEmails = New List<String>();
        if(groupIds != NULL && !groupIds.isEmpty()){
            Set<Id> userIds = new Set<Id>();
            for (GroupMember member : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :groupIds]) {
                userIds.add(member.UserOrGroupId);
            }
            
            UserService objUserService = UserService.getInstance();
            for(User u:objUserService.getUsersByIds(userIds)){
                userEmails.add(u.Email);
            }
        }
        return userEmails;
    }
    
    public static string formatEmiratesId(String emiratesId){
        if(String.isNotBlank(emiratesId)){
            emiratesId = emiratesId.remove('-');
            Integer eidCharLength = emiratesId.length();
            if(eidCharLength > 3){
                emiratesId = emiratesId.substring(0, 3) + '-' + emiratesId.substring(3, emiratesId.length());
            }
            if(eidCharLength > 7){
                emiratesId = emiratesId.substring(0, 8) + '-' + emiratesId.substring(8, emiratesId.length());
            }
            if(eidCharLength > 14){
                emiratesId = emiratesId.substring(0, 16) + '-' + emiratesId.substring(16, emiratesId.length());
            }
        }
        return emiratesId;
    }
    
    public static string formatPhoneNumber(String countryCode, String phoneNumber){
        if(String.isNotBlank(countryCode) && String.isNotBlank(phoneNumber)){
            phoneNumber = countryCode + phoneNumber;
        }
        return phoneNumber;
    }

    public static String getObjectNameFromId(String recordId) {
        String objName;
        String prefix = recordId.substring(0, 3);

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for (Schema.SObjectType objType : gd.values()) {
            Schema.DescribeSObjectResult describeResult = objType.getDescribe();
            if (describeResult.getKeyPrefix() == prefix) {
                objName = describeResult.getName();
                break;
            }
        }

        return objName;
    }
}