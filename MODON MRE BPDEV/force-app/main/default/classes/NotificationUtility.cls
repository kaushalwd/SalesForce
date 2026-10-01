public class NotificationUtility {

    public static void sendNotification(
        String emailTemplateDeveloperName,
        List<Id> recipientIds,
        Boolean sendBellNotification,
        Id whatId,                   // Context record for email merge fields
        Id whoId,                    // Optional: person contact (used only in some templates)
        String bellTitle,           // Optional: title for bell notification
        String bellBody,            // Optional: body text for bell notification
        Id targetRecordId,          // Required if bellNotification is true
        String bellNotificationTypeDeveloperName // NEW: dynamic bell type
    )
        {
        //overloaded method with null attachment
        sendNotification(
            emailTemplateDeveloperName,
            recipientIds,
            sendBellNotification,
            whatId,
            whoId,
            bellTitle,
            bellBody,
            targetRecordId,
            bellNotificationTypeDeveloperName,
            null,
            null
        );
    }

    //New overloaded method with attachment support
    public static void sendNotification(
        String emailTemplateDeveloperName,
        List<Id> recipientIds,
        Boolean sendBellNotification,
        Id whatId,
        Id whoId,
        String bellTitle,
        String bellBody,
        Id targetRecordId,
        String bellNotificationTypeDeveloperName,
        Blob pdfAttachment,          // New parameter
        String fileName              // New parameter
    ) {
        try {
            System.debug('>>> NotificationUtility: Template Developer Name: ' + emailTemplateDeveloperName);
            System.debug('>>> NotificationUtility: Recipients: ' + recipientIds);
            System.debug('>>> sendBellNotification: ' + sendBellNotification);
            System.debug('>>> whatId: ' + whatId + ', whoId: ' + whoId);

            // ===== SEND EMAIL =====
            if (emailTemplateDeveloperName != null && !recipientIds.isEmpty()) {
                EmailTemplate template = [
                    SELECT Id FROM EmailTemplate WHERE DeveloperName = :emailTemplateDeveloperName LIMIT 1
                ];
                System.debug('>>> Using Email Template Id: ' + template.Id);

                List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

                for (Id recipientId : recipientIds) {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setTemplateId(template.Id);
                    email.setSaveAsActivity(false);

                    String prefix = String.valueOf(recipientId).substring(0, 3);
                    if (prefix == '005' || prefix == '00Q' || prefix == '003') {
                        email.setTargetObjectId(recipientId);
                    } else if (prefix == '001' && isPersonAccount(recipientId)) {
                        // Fetch the underlying Contact Id of the Person Account
                        Id contactId = getPersonContactId(recipientId);
                        if (contactId != null) {
                            email.setTargetObjectId(contactId);
                        } else {
                            System.debug('>>> Person Account found but no ContactId: ' + recipientId);
                            continue;
                        }
                    } else {
                        System.debug('>>> Unsupported recipient type: ' + recipientId);
                        continue;
                    }

                    if (whatId != null) {
                        email.setWhatId(whatId);
                    }
                    
                    // Add PDF attachment if present
                    if (pdfAttachment != null && String.isNotBlank(fileName)) {
                        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                        attachment.setFileName(fileName + '.pdf');
                        attachment.setBody(pdfAttachment);
                        attachment.setContentType('application/pdf');
                        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
                    }

                    // Set from address as 'Modon noreply <sales@modon.ae>'
                    email.setOrgWideEmailAddressId(getModonOrgWideEmailAddressId());
                    emailList.add(email);
                }

                Messaging.sendEmail(emailList);
                System.debug('>>> Email sent successfully to: ' + recipientIds);
            }

            // ===== SEND BELL NOTIFICATION =====
            if (sendBellNotification && !recipientIds.isEmpty() && targetRecordId != null && bellNotificationTypeDeveloperName != null) {
                try {
                    CustomNotificationType notifType = [
                        SELECT Id FROM CustomNotificationType WHERE DeveloperName = :bellNotificationTypeDeveloperName LIMIT 1
                    ];

                    Messaging.CustomNotification notif = new Messaging.CustomNotification();
                    notif.setNotificationTypeId(notifType.Id);
                    notif.setTitle(String.isBlank(bellTitle) ? 'Notification' : bellTitle);
                    notif.setBody(String.isBlank(bellBody) ? 'You have a new notification.' : bellBody);
                    notif.setTargetId(targetRecordId);

                    Set<String> recipientIdStrings = new Set<String>();
                    for (Id recId : recipientIds) {
                        recipientIdStrings.add((String)recId);
                    }

                    notif.send(recipientIdStrings);
                    System.debug('>>> Bell notification sent to: ' + recipientIdStrings);
                } catch (Exception ex) {
                    System.debug('>>> Bell Notification ERROR: ' + ex.getMessage());
                }
            }

        } catch (Exception ex) {
            System.debug('Error in NotificationUtility.sendNotification: ' + ex.getMessage());
        }
    }

    private static Id getModonOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> oweaList = [
            SELECT Id FROM OrgWideEmailAddress WHERE Address = 'sales@modon.ae' LIMIT 1
        ];
        return oweaList.isEmpty() ? null : oweaList[0].Id;
    }
    
    private static Boolean isPersonAccount(Id accountId) {
    Account acc = [SELECT Id, IsPersonAccount FROM Account WHERE Id = :accountId LIMIT 1];
    return acc.IsPersonAccount;
}
    private static Id getPersonContactId(Id accountId) {
    Account acc = [SELECT PersonContactId FROM Account WHERE Id = :accountId AND IsPersonAccount = true LIMIT 1];
    return acc.PersonContactId;
}


    
}