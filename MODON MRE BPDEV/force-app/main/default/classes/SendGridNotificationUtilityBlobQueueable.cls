/**********************************************************************************************************************
* Name               : SendGridNotificationUtilityQueueable                                                        
* Description        : This class is used for communication matrix
* Usage              : Called from all the components without futur method
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22-08-2025      Initial Draft   
* 1.1			Suresh						23-09-2025		Added Async method
******************************************************************************************************************/
public class SendGridNotificationUtilityBlobQueueable implements Queueable {
    public Id leadId;
    public Id contactOrUserId;
    public String templateName;
    public String recipientEmail;
    public String senderEmail;
    public String senderName;
    public String category;
    public String subCategory;
    public String communicationName;
    public String department;
    public String frequency;
    public Blob attachmentData;
    public String attachmentFileName;
    public String attachmentFileType;
    public Id relatedRecordId;
    public SendGridNotificationUtilityBlobQueueable(
        Id leadId,
        Id contactOrUserId, // Can be Contact or User
        String templateName,
        String recipientEmail,
        String senderEmail,
        String senderName,
        String category,
        String subCategory,
        String communicationName,
        String department,
        String frequency,
        Blob attachmentData,
        String attachmentFileName,
        String attachmentFileType,
        Id relatedRecordId){
            this.leadId = leadId;
            this.contactOrUserId = contactOrUserId;
            this.templateName = templateName;
            this.recipientEmail = recipientEmail;
            this.senderEmail = senderEmail;
            this.senderName = senderName;
            this.category = category;
            this.subCategory = subCategory;
            this.communicationName = communicationName;
            this.department = department;
            this.frequency = frequency;
            this.attachmentData = attachmentData;
            this.attachmentFileName = attachmentFileName;
            this.attachmentFileType = attachmentFileType;
            this.relatedRecordId = relatedRecordId;
        }
    public SendGridNotificationUtilityBlobQueueable(){}
    public void execute(QueueableContext context) {
        SendGridNotificationUtility.sendEmailBlob(leadId, contactOrUserId, templateName, recipientEmail, senderEmail, senderName,
                                                  category, subCategory, communicationName, department, frequency, 
                                                  attachmentData, attachmentFileName, attachmentFileType, relatedRecordId);
    }    
}