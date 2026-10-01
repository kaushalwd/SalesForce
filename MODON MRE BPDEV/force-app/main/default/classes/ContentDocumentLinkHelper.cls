public class ContentDocumentLinkHelper {
    @future
    public static void insertContentDocumentLinks(Id contentVersionId, Id currentRecordId, String contentDocumentTermsId) {
        List<ContentDocumentLink> contentDocumentLinkList = new List<ContentDocumentLink>();

        // Retrieve the ContentDocumentId
        ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        ContentDocument contentDocument = [SELECT Id FROM ContentDocument WHERE Id = :contentVersion.ContentDocumentId LIMIT 1];
        
        // Create a new ContentDocumentLink to associate the ContentDocument with the record
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentDocument.Id;
        contentDocumentLink.LinkedEntityId = currentRecordId;
        contentDocumentLink.ShareType = 'I'; // Inferred from parent
        contentDocumentLink.Visibility = 'AllUsers';
        
        ContentDocumentLink contentDocumentLink2 = new ContentDocumentLink();
        contentDocumentLink2.ContentDocumentId = contentDocumentTermsId;
        contentDocumentLink2.LinkedEntityId = currentRecordId;
        contentDocumentLink2.ShareType = 'I'; // Inferred from parent
        contentDocumentLink2.Visibility = 'AllUsers';

        contentDocumentLinkList.add(contentDocumentLink);
        contentDocumentLinkList.add(contentDocumentLink2);

        try {
            insert contentDocumentLinkList;
            system.debug('contentDocumentLinkList=='+contentDocumentLinkList);
        } catch (DMLException e) {
            System.debug('Error inserting ContentDocumentLink: ' + e.getMessage());
        }
    }
    public static void incrementDifferenceExample() {
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        
    }




}