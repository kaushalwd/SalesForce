public class UserImageUrl {
    public static String getUserImageUrl(Id userId) {
        List<User> UserList = [SELECT Id,ContactId,Contact.accountId FROM User WHERE ContactId !=null AND id =: userId];
        system.debug('UserList---'+UserList);
        List<ContentDocumentLink> docLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :UserList[0].Contact.accountId and ContentDocument.Title like '%ProfileImage%' ORDER BY ContentDocument.CreatedDate  DESC LIMIT 1 ];
        system.debug('docLinks---'+docLinks);    
        if (!docLinks.isEmpty()) {
            ContentVersion cv = [SELECT Id, ContentDocumentId, VersionData, Title FROM ContentVersion WHERE ContentDocumentId = :docLinks[0].ContentDocumentId 
                                 ORDER BY CreatedDate DESC LIMIT 1 ];
            system.debug('cv---'+cv);
            return 'data:image/jpeg;base64,' + EncodingUtil.base64Encode(cv.VersionData);
        }
        return null;
    }
    
    public Static UserAccess_DTO mapUserdto(user userRecord){
        
        // Get user's profile image URL (from ContentDocumentLink)
        String imageUrl = getUserImageUrl(userRecord.Id);
        
        // Use existing UserAccess_DTO constructor
        UserAccess_DTO dto = new UserAccess_DTO(
            userRecord.Id,
            userRecord.Email,
            userRecord.Username,
            userRecord.FirstName,
            userRecord.LastName,
            userRecord.Contact.AccountId, 
            userRecord.Street,
            userRecord.State,
            userRecord.City,
            userRecord.Country,
            userRecord.PostalCode,
            userRecord.EmiratesIDNumber__c,
            userRecord.Phone,
            imageUrl                
        );     
        return dto;
    }
    public static String uploadUserAvatar(String base64Data, String fileName,string email) {
        List<User> UserList = [SELECT Id,ContactId,LastName FROM User WHERE ContactId !=null AND UserName =: email];
        // 1. Decode base64 file
        Blob fileBody = EncodingUtil.base64Decode(base64Data);
        
        // 2. Create ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = UserList[0].LastName+'ProfileImage.jpg';
        cv.PathOnClient = UserList[0].LastName+'ProfileImage.jpg';
        cv.VersionData = fileBody;
        insert cv;
        
        // Get document ID
        ContentVersion inserted = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id 
            LIMIT 1
        ];
        system.debug('email--'+email);
        List<ContentDocumentLink> contDocLinkList = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId =:inserted.ContentDocumentId ];    
        
        if(!UserList.isEmpty() && !contDocLinkList.isEmpty()){
            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = inserted.ContentDocumentId;
            link.LinkedEntityId = UserList[0].ContactId;
            link.ShareType = 'V'; 
            link.Visibility = 'AllUsers';
            insert link;
            system.debug('link---'+link);
        }
        
        ContentVersion cvData = [SELECT VersionData FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        system.debug('base64Encode-------'+EncodingUtil.base64Encode(cvData.VersionData));
        return EncodingUtil.base64Encode(cvData.VersionData);
        
    }
}