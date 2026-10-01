public without sharing class CommunityCustomerProfile {
    @AuraEnabled(Cacheable=true)
    public static UserWrapper getCurrentUserInfo(){
        UserWrapper uWrap = new UserWrapper();
        User userObj = [SELECT Id,Name,Email,MobilePhone,title,EmiratesIDNumber__c,CompanyName,Phone,FirstName,LastName, Street, City, State, PostalCode, Country,PhotoImageURL__c FROM User WHERE Id =: UserInfo.getUserId() LIMIT 1];
        uWrap.isUserUpdateInProgress = isUpdateRequestInProgress(userObj.Email,userObj.MobilePhone);
        uWrap.userObj = userObj;
        return uWrap;
    }
    @AuraEnabled
    public static String generateResetPassword(String password){
        try {
            System.setPassword(UserInfo.getUserId(), password);
            return'Password reset email sent successfully.';
        } catch (Exception e) {
            System.debug('Reset Password Error: '+e.getMessage());
            return 'Error !'+e.getMessage();
        }
    }
    @AuraEnabled
    public static String udpateUserData(String firstName,String lastName,String title,String companyName,String phone,string street,string state,string city,string postalCode,String country,String email){
        try{
            Case caseObj = new Case();
            caseObj.Status = 'New';
            caseObj.Origin = 'Web';
            caseObj.Subject = 'Contact Update Request';
            caseObj.Description = 'Customer requesting to update the following contact data: ';
            caseObj.Description += phone <> null ?'Mobile :'+phone+' , ':'';
            caseObj.Description += email <> null?'Email : '+email+', ':'';
            caseObj.Description += (City <> null || state <> null || postalCode <> null || country <> null || street <> null) ?' Address - ':'';
            if( caseObj.Description <> null &&  caseObj.Description.contains('Address')){
                caseObj.Description += street <> null ? 'street : '+City+', ' :'';
                caseObj.Description += City <> null ? 'City : '+City+', ' :'';
                caseObj.Description += state <> null ? 'State : '+state+', ' :'';
				caseObj.Description += country <> null ? 'Country : '+country+', ' :'';
                caseObj.Description += postalCode <> null ? 'Postal Code : '+postalCode+'' :'';
            }
            caseObj.SuppliedEmail = email;
            caseObj.SuppliedPhone = phone;
            //caseObj.Customer_Email__c = email;
            //caseObj.Customer_Phone__c = phone;
            caseObj.Requestor_Email__c = email;
            caseObj.Requestor_Phone__c = phone;
            caseObj.Requestor_Name__c = email;
            caseObj.CaseCategory__c = 'Contact Details Update';
            //caseObj.CaseSubCategory__c = 'Contact Details Update';
           
            insert caseObj;
            
            List<User> userList = new List<User>();
            for(User u:[SELECT Id FROM User WHERE Username =: email]){
                User uObj = new User();
                uObj.Id = u.Id;
                uObj.Street = street;
                uObj.City = City;
                uObj.State = State;
                uObj.Country = country;
                uObj.PostalCode = postalCode;
                userList.add(uObj);
            }
            if(!userList.isEmpty()){
               update userList;
            }
            String caseNumber = [SELECT Id,CaseNumber FROM Case WHERE Id =:caseObj.Id LIMIT 1 ].CaseNumber;
            return 'Your case created for contact details update! Here is your reference tracking number '+caseNumber+'.';
        }catch (DmlException e) {
            String rawMessage = e.getMessage();
            System.debug(' Error Message: ' + rawMessage);
            
            // Try to clean it
            String validErrorMsg = rawMessage;
            
            if (rawMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION,')) {
                // Extract after the custom validation
                Integer index = rawMessage.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
                validErrorMsg = rawMessage.substring(index + 'FIELD_CUSTOM_VALIDATION_EXCEPTION,'.length());
                
                // Remove anything after the colon :
                if (validErrorMsg.contains(':')) {
                    validErrorMsg = validErrorMsg.substring(0, validErrorMsg.indexOf(':')).trim();
                }
            }
            
            return 'Error! ' + validErrorMsg;
        }catch(Exception ex){
            System.debug('Error User update:'+ex.getMessage()); 
            return 'Error! Please reachout to System Admin!';
        }
    }
  
    @AuraEnabled
    public static String uploadUserAvatar(String base64Data, String fileName) {
        // 1. Decode base64 file
        Blob fileBody = EncodingUtil.base64Decode(base64Data);
        
        // 2. Create ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = '21User_Custom_Avatar.jpg';
        cv.PathOnClient = fileName+'221.jpg';
        cv.VersionData = fileBody;
        insert cv;
        
        // Get document ID
        ContentVersion inserted = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id 
            LIMIT 1
        ];
        
        List<ContentDocumentLink> contDocLinkList = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId =:inserted.ContentDocumentId ];    
        List<User> UserList = [SELECT Id,ContactId FROM User WHERE ContactId !=null AND Id=: UserInfo.getUserId()];
        if(!UserList.isEmpty() && contDocLinkList.isEmpty()){
            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = inserted.ContentDocumentId;
            link.LinkedEntityId = UserList[0].ContactId;
            link.ShareType = 'I'; 
            link.Visibility = 'AllUsers';
            insert link;
        }
        
        ContentVersion cvData = [SELECT VersionData FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        User user = new User();
        user.Id = UserInfo.getUserId();
        user.PhotoImageURL__c = cvData.Id;
        update user;
        return EncodingUtil.base64Encode(cvData.VersionData);
        
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserPhotoUrl() {
        User u = [SELECT FullPhotoUrl,PhotoImageURL__c FROM User WHERE Id = :UserInfo.getUserId()];
        Id versionId = u.PhotoImageURL__c <> null ? u.PhotoImageURL__c:System.Label.CP_defaultAvatar;
        List<ContentVersion> cv = [SELECT VersionData FROM ContentVersion WHERE Id = :versionId LIMIT 1];
        if(!cv.isEMpty()){
            return EncodingUtil.base64Encode(cv[0].VersionData);
        }
        return null;
    }
    public static boolean isUpdateRequestInProgress(String email, String Mobile){
        List<Case> caseList = [SELECT Id FROM Case WHERE (SuppliedEmail =:email OR SuppliedPhone =:Mobile) AND (NOT Status IN('Closed')) AND CaseCategory__c = 'Contact Details Update' AND CaseSubCategory__c = 'Contact Details Update'];
        if(!caseList.isEmpty()){
            return true;
        }
        return false;
    }
    public class UserWrapper{
        @AuraEnabled public User userObj;
        @AuraEnabled public boolean isUserUpdateInProgress;
    }
    
    public static UserWrapper getCurrentUserInfo(string userName){
        UserWrapper uWrap = new UserWrapper();
        User userObj = [SELECT Id,Name,Email,MobilePhone,title,EmiratesIDNumber__c,CompanyName,Phone,FirstName,LastName, Street, City, State, PostalCode, Country,PhotoImageURL__c FROM User WHERE username =: userName LIMIT 1];
        uWrap.isUserUpdateInProgress = isUpdateRequestInProgress(userObj.Email,userObj.MobilePhone);
        uWrap.userObj = userObj;
        return uWrap;
    }
}