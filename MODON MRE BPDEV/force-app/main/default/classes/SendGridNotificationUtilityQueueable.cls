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
public class SendGridNotificationUtilityQueueable implements Queueable {
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
    public List<Id> attachmentIds;
    public Id relatedRecordId;
    public SendGridNotificationUtilityQueueable(
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
        List<Id> attachmentIds,
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
            this.attachmentIds = attachmentIds;
            this.relatedRecordId = relatedRecordId;
        }
    public SendGridNotificationUtilityQueueable(){}
    public void execute(QueueableContext context) {
        SendGridNotificationUtility.sendEmail(leadId, contactOrUserId, templateName, recipientEmail, senderEmail, senderName,
                                             category, subCategory, communicationName, department, frequency, attachmentIds, relatedRecordId);
    }    
}