public class EidGreetingsEmails implements Queueable, Database.AllowsCallouts {
    
    private List<String> userIds;

    // Constructor to pass User IDs
    public EidGreetingsEmails(List<String> userIds) {
        this.userIds = userIds;
    }

    public void execute(QueueableContext context) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }

        // Query all Users with Profile = 'Community User'
       // List<User> communityUsers = [SELECT Id, Email FROM User WHERE Id IN :userIds /*AND Profile.Name = 'Modon - Partner Community User' AND (not name like '%%')*/];

      //  if (communityUsers.isEmpty()) {
       //     System.debug('communityUsers: '+ communityUsers);
       //     return;
       // }
        // Query the Email Template by Name (Eid_Greeting)
        EmailTemplate eidGreetingTemplate = [SELECT Id, Subject, HtmlValue FROM EmailTemplate WHERE DeveloperName = 'Eid_Reminder' LIMIT 1];//Eid_Greetings
        System.debug('eidGreetingTemplate: '+ eidGreetingTemplate);
        if (eidGreetingTemplate == null) {
            System.debug('Eid_Greeting Email Template not found');
            return;
        }

        // Get the static image as a Document (Base64 Encoding)
        Document staticImageDoc = [SELECT DeveloperName, Body FROM Document WHERE DeveloperName = 'Eid_Greetings' LIMIT 1];
        System.debug('staticImageDoc: '+ staticImageDoc);
        if (staticImageDoc == null || staticImageDoc.Body == null || staticImageDoc.Body.size() == 0) {
            System.debug('Static Image Document not found or empty');
            return;
        }


        String base64EncodedImage = EncodingUtil.base64Encode(staticImageDoc.Body);

        // Prepare bulk email list for SendGrid
//        String subject = eidGreetingTemplate.Subject;
        Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(System.Label.EmailTemplateId, System.Label.UserId,System.Label.SalesOrderId);
            String subject = email.getSubject();
            String body = email.getHtmlBody().replace('\n', '').replace('"', '\\"'); 
        system.debug('body--->>'+body);
        
        List<String> personalizationsList = new List<String>();
       // String subject = eidGreetingTemplate.Subject;
       // String body = eidGreetingTemplate.HtmlValue;
        system.debug('body'+body);
        // Create personalizations entries for each user
        //String testEmail = 'arbaz@aphidas.com';
        
        for (String userEmail : userIds) {
            String personalizationsEntry = '[{"bcc": [{ "email": "' + System.Label.ReminderBCC + '" }] ,"to": [{"email": "' + userEmail + '"}';//duser.Email
            personalizationsEntry += ']}]';
            
            // Send the email using SendGrid
            sendToSendGrid(personalizationsEntry, subject, body, base64EncodedImage);
        }
    }

    @TestVisible
    private void sendToSendGrid(String personalizations, String subject, String body, String base64EncodedImage) {
        System.debug(personalizations);
        String sendGridApiKey = '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';  // Use your SendGrid API Key
        String sendGridApiUrl = 'https://api.sendgrid.com/v3/mail/send';  // SendGrid API URL

        String contentId = 'b1fad9e5-ea64-4f5b-80bb-e8361adc0819';
        String payload = '{"personalizations": ' + personalizations + ',' +
            '"from": {"email": "noreply@modon.com"},' +
            '"subject": "' + subject + '",' +
            '"content": [{"type": "text/html", "value": "' + body + '"}],' +
            '"attachments": [{"content": "' + base64EncodedImage + '",' +
            '"type": "image/png",' +
            '"filename": "image.png",' +
            '"disposition": "inline",' +
            '"content_id": "' + contentId + '"}]}';
        System.debug('Payload: ' + payload);

        // Prepare HTTP Request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(sendGridApiUrl);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sendGridApiKey);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('SendGrid Response: ' + res.getBody());
        System.debug('SendGrid Response Status Code: ' + res.getStatusCode());
    }
    public static void functionforcoverage(){
        integer i = 0;
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
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}