public class SendGridEmailServiceUserAccessAPI {

    private static final SendGrid_Configuration__mdt CONFIG = SendGrid_Configuration__mdt.getInstance('Credentials');
    private static final String SENDGRID_API_URL = CONFIG?.SendGrid_API_URL__c;
    private static final String SENDGRID_API_KEY = CONFIG?.SendGrid_API_KEY__c;
    
    @InvocableMethod(label='RestPassword' description='Initiate callout to send Reset Password' category='User')
    public static void initiateCallout(List<Id> UserIds) {
        String userId = UserIds[0];
        sendEmailUsingSendGrid(userId,System.Label.Email_CustomerPortalEmail);
    }
   
    @future (callout=true)
    public static void sendEmailUsingSendGrid(Id userId,string emailTemplete){
       List<EmailTemplate> lst_EmailTemplate = [SELECT Id FROM EmailTemplate WHERE DeveloperName =: emailTemplete  LIMIT 1];
        
        for(User uaObj : [SELECT Id,Firstname,Lastname, email,UserName,EmailBase64String__c FROM User Where id =: userId and isActive =true ]){
           
         Id templateId; 
        String recipientEmail = uaObj.email;
        Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(lst_EmailTemplate[0].Id,uaObj.id,uaObj.id);
        String subject = email.getSubject();
        String body= email.getHtmlBody().replace('\n', '');        
        body = body.replace('"', '\\"');  
        
        System.debug('body===>>'+body); 
        System.debug('subject---'+subject);
        // Send the email via SendGrid
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SENDGRID_API_URL);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + SENDGRID_API_KEY);
        req.setHeader('Content-Type', 'application/json');
        
         // Initialize base payload
            String personalizations = '[{"bcc": [{ "email": "'+system.label.ReminderBCC+'" }] ,"to": [{"email": "' + recipientEmail + '"}';
            personalizations += ']}]';
            
            String payload = '{"personalizations": ' + personalizations + ',' +
                '"from": {"email": "'+system.label.customercareEmail+'"},' +
                '"subject": "' + subject + '",' +
                '"content": [{"type": "text/html", "value": "' + body + '"}]}';       
       
        
        system.debug('payload==>>'+payload);
        req.setBody(payload);
        Http http = new Http();
        HttpResponse res  = http.send(req);
        if (res.getStatusCode() == 202) {
            System.debug('Email sent successfully via SendGrid.');
        } else {
            System.debug('Failed to send email: ' + res.getBody());
            System.debug('Failed to send email: ' + res);
             LoggerService.save(LoggerService.createAPILog('Send Eamil Customer portal','SendGridEmailServiceUserAccessAPI','sendEmailUsingSendGrid', res.getBody(), res.getBody(), 'Error Message: ' + res.getBody() , 'Callout Log'));
            
        }
        }
    }
}