/**********************************************************************************************************************
* Name               : MBP_BrokerUserProfilecontroller
* Description        : This class is used as the Apex controller for Broker Portal Profile Management.
* Usage              : LWC components for Broker Agent profile updates
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com         20 Nov 2025      Initial Draft – Handles profile picture upload, 
*                                                              profile data update (Mobile, UAE Resident, Nationality),
*                                                              password reset, and nationality picklist fetch.
*
* 1.1        upendra.asam@activemindsit.com         09 Dec 2025      Updated methods getNationalityPicklistValues() and updateContactDetails().
*                                                              Added improved error handling, phone mandatory in SOQL,
*                                                              enhanced UI error messaging and field-level validation support.
**********************************************************************************************************************/



public without sharing class MBP_BrokerUserProfilecontroller {
    @AuraEnabled(cacheable=false)
    public static Map<String, String> uploadUserPicture(String baseData) {
        Map<String, String> returnResponse = new Map<String, String>();
        returnResponse.put('success', 'false');
        
        try {
            if (String.isBlank(baseData)) {
                returnResponse.put('msg', 'No image data received.');
                return returnResponse;
            }
            
            Blob picData = EncodingUtil.base64Decode(baseData);
            ConnectApi.BinaryInput fileUpload = new ConnectApi.BinaryInput(picData, 'image/jpeg', 'ProfileImage');
            
            ConnectApi.Photo photoProfile = ConnectApi.UserProfiles.setPhoto(
                ConnectApi.Communities.getCommunities().communities[0].id,
                UserInfo.getUserId(), 
                fileUpload
            );
            
            returnResponse.put('success', 'true');
            returnResponse.put('data', photoProfile.mediumPhotoUrl);
            returnResponse.put('msg', 'Image updated successfully. It may take time to reflect.');
        } catch (Exception e) {
            returnResponse.put('msg', e.getMessage());
        }
        
        return returnResponse;
    }
    

/* Version 1.1  starts*/
    @AuraEnabled(cacheable=false)
public static Map<String, Object> getNationalityPicklistValues() {
    Map<String, Object> result = new Map<String, Object>();
    try {
        Schema.DescribeFieldResult fieldResult = Contact.Nationality__c.getDescribe();
        List<Schema.PicklistEntry> pickListValues = fieldResult.getPicklistValues();
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : pickListValues) {
            values.add(entry.getLabel());
        }
        result.put('success', true);
        result.put('values', values);
    } catch (Exception e) {
        result.put('success', false);
        result.put('error', e.getMessage());
    }
    return result;
}
        /* Version 1.1  ends*/
    
/* Version 1.1  starts*/

@AuraEnabled
public static String updateContactDetails(String contactId, String phone, String uaeStatus, String nationality) {
    try {
        Contact con = [SELECT Id FROM Contact WHERE Id = :contactId LIMIT 1];
        con.Phone = phone;
        con.UAE_Resident_Status__c = uaeStatus;
        con.Nationality__c = nationality;
        update con;
        return 'Profile updated successfully!';
    } catch (Exception e) {
        throw new AuraHandledException('Error updating profile: ' + e.getMessage());
    }
}
    /* Version 1.1  ends*/
    
    @AuraEnabled
    public static void resetPassword(String newPassword, String verifyNewPassword, String oldPassword) {
        Site.changePassword(newPassword, verifyNewPassword, oldPassword);
    }
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getUserProfileDetails() {
        User userRecord = [
            SELECT Contact.Id, Contact.FirstName, Contact.LastName, 
            Contact.Phone, Contact.Broker_Type__c,
            Contact.Email, Username, FullPhotoUrl,
            Contact.Account.BillingCountry,contact.Nationality__c,contact.UAE_Resident_Status__c
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        return new Map<String, Object>{
            'Contact' => userRecord.Contact,
                'FullPhotoUrl' => userRecord.FullPhotoUrl,
                'Username' => userRecord.Username,
                'Country' => userRecord.Contact.Account.BillingCountry
                };
                    }
    

}