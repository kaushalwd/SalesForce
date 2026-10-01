public with sharing class AccountStatusController {

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAccountStatusData(String recordId) {
        Map<String, String> fieldToValueMap = new Map<String, String>();

        if (String.isNotBlank(recordId)) {
            Account acc = getAccountDetails(recordId);

            List<Customer360_Field_Config__mdt> metadataList = [
                SELECT DeveloperName, Component_Name__c, Field_Name_In_Object__c, Data_Type__c, Order__c, MasterLabel
                FROM Customer360_Field_Config__mdt
                WHERE Active__c = TRUE AND Component_Name__c = 'Account Status'
                ORDER BY Order__c
            ];

            for (Customer360_Field_Config__mdt meta : metadataList) {
                String fieldValue = getFieldValue(meta.Field_Name_In_Object__c, acc);
                fieldToValueMap.put(meta.MasterLabel, fieldValue);
            }
        }

        return fieldToValueMap;
    }

    private static String getFieldValue(String fieldName, Account acc) {
        if (String.isBlank(fieldName)) return 'Data Not Available';

        // Calculate EID_Expire_Days (virtual field)
        if (fieldName == 'EID_Expire_Days') {
            Date expiryDate = acc != null ? acc.EmiratesIDExpiryDate__pc : null;

            if (expiryDate == null) return 'Data Not Available';

            Date today = Date.today();
            Integer diffDays = today.daysBetween(expiryDate); // future: positive, past: negative

            if (diffDays == 0) {
                return 'Expires today';
            } else if (diffDays > 0) {
                return 'Expires in ' + diffDays + ' day' + (diffDays != 1 ? 's' : '');
            } else {
                diffDays = Math.abs(diffDays);
                return '<span style="color:red;">Expired ' + diffDays + ' day' + (diffDays != 1 ? 's' : '') + ' ago</span>';
            }
        }
        
        // Calculate Passport_Expire_Days (virtual field)
if (fieldName == 'PassportExpiresIn__c') {
    Date expiryDate = acc != null ? acc.PassportExpiryDate__pc : null;

    if (expiryDate == null) return 'Data Not Available';

    Date today = Date.today();
    Integer diffDays = today.daysBetween(expiryDate);

    if (diffDays == 0) {
        return 'Expires today';
    } else if (diffDays > 0) {
        return 'Expires in ' + diffDays + ' day' + (diffDays != 1 ? 's' : '');
    } else {
        diffDays = Math.abs(diffDays);
        return '<span style="color:red;">Expired ' + diffDays + ' day' + (diffDays != 1 ? 's' : '') + ' ago</span>';
    }
}


        // Handle normal fields
        if (acc != null && hasField(acc, fieldName)) {
            Object value = acc.get(fieldName);

            // Format the date properly
           if ((fieldName == 'EmiratesIDExpiryDate__pc' || fieldName == 'PassportExpiryDate__pc') && value instanceof Date) {
    			return ((Date)value).format(); // format as yyyy-MM-dd
			}


            return value != null ? String.valueOf(value) : 'Data Not Available';
        }

        return 'Data Not Available';
    }

    private static Boolean hasField(SObject record, String fieldName) {
        return record != null && record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName);
    }

    private static Account getAccountDetails(Id recordId) {
        try {
            return [SELECT EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc, PassportExpiryDate__pc
                    FROM Account WHERE Id = :recordId LIMIT 1];
        } catch (Exception e) {
            System.debug('Account Query Failed: ' + e.getMessage());
            return null;
        }
    }
}