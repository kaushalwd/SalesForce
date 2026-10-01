/**-------------------------------------------------------------------
 * Description : A class to handle sending system emails
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Abdallah Hdaib   14-02-2024         Code Creation
 * -------------------------------------------------------------------
 * Notes: Purpose of this class is to send emails with attachments.
*/
public with sharing class SystemEmailsHandler {

    // Email to be sent when Receipt is Approved
    @invocableMethod
    public static void sendReceiptApprovalEmail(List<String> receiptId){

        if(receiptId != null){
            Receipt__c receipt = [SELECT Id, Name, Account__c, Account__r.PersonEmail, Account__r.IsPersonAccount, Account__r.PersonContactId FROM Receipt__c WHERE Id =: receiptId];
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            String emailTemplateId = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName = 'Payment_Acknowledgment_Email'].Id;
            OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName='Modon Default'];
            List<ContentDocumentLink> attachments = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Receipt__c WHERE Id=:receiptId)];
            
            // Set email attributes
            email.setToAddresses(new String[]{receipt.Account__r.PersonEmail});
            email.setWhatId(receiptId[0]);
            email.setTargetObjectId(receipt.Account__r.PersonContactId);
            email.setTemplateId(emailTemplateId);
            email.setOrgWideEmailAddressId(owea.Id);
            
            // Attach files to the email
            List<Messaging.EmailFileAttachment> fileAttachments = new List<Messaging.EmailFileAttachment>();
            for(ContentDocumentLink attachment : attachments) {
                Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
                ContentVersion contentVersion = [SELECT Id, Title, VersionData FROM ContentVersion WHERE ContentDocumentId =: attachment.ContentDocumentId ORDER BY CreatedDate DESC LIMIT 1];
                fileAttachment.setFileName(contentVersion.Title);
                fileAttachment.setBody(contentVersion.VersionData);
                fileAttachment.setcontenttype('application/pdf');
                fileAttachments.add(fileAttachment);
            }
            email.setFileAttachments(fileAttachments);
            
            // Send the email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        }
    }
}