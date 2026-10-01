/**********************************************************************************************************************
* Name               : SendGridQueueable                                                        
* Description        : This class is used as a email sending for reminders
* Usage              : Called from InstallmentReminderCreation
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0			raghu.gajjela@activemindsit.com 			15 DEC 2025		Email Sending Logic
***********************************************************************************************************************/
public class SendGridQueueable implements Queueable, Database.AllowsCallouts {

    public class EmailRequest {

        public Id reminderId;
        public String templateName;
        public String toAddress;
        public String reminderType;
        public Id emailMessageId;

        public EmailRequest(){}

        public EmailRequest(
            Id reminderId,
            String templateName,
            String toAddress,
            String reminderType,
            Id emailMessageId
        ){

            this.reminderId = reminderId;
            this.templateName = templateName;
            this.toAddress = toAddress;
            this.reminderType = reminderType;
            this.emailMessageId = emailMessageId;
        }
    }

    private List<EmailRequest> requests;

    public SendGridQueueable( List<EmailRequest> requests){
        this.requests = requests;
    }

    public void execute(QueueableContext qc) {

        List<EmailMessage> emailUpdates = new List<EmailMessage>();

        for(EmailRequest req : requests){

            Boolean success = true;

            try {

                SendGridNotificationUtility.sendEmail(
                    null,
                    null,
                    req.templateName,
                    req.toAddress,
                    'noreply@modon.com',
                    'MODON Finance Team',
                    'Payment Reminder',
                    req.reminderType,
                    'Installment Reminder',
                    'Finance',
                    null,
                    null,
                    req.reminderId
                );

            } catch(Exception e){

                success = false;
            }

            emailUpdates.add(new EmailMessage(
                Id = req.emailMessageId,
                Status = success ? '3' : '5'));
        }

        if(!emailUpdates.isEmpty()){
            update emailUpdates;
        }
    }
}