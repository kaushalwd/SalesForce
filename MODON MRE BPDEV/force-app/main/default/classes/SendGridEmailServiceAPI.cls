public class SendGridEmailServiceAPI {

    private static final SendGrid_Configuration__mdt CONFIG = SendGrid_Configuration__mdt.getInstance('Credentials');
    private static final String SENDGRID_API_URL = CONFIG?.SendGrid_API_URL__c;
    private static final String SENDGRID_API_KEY = CONFIG?.SendGrid_API_KEY__c;
    
    @InvocableMethod(label='Lead Acknowledgement Using Send' description='This method processes data and returns the result')
    public static void sendEmailUsingVFTemplateforLead(List<Lead> lead) {
        sendEmailUsingSendGrid(lead[0].Id);
    }
    
    @future (callout=true)
    public static void sendEmailUsingSendGrid(Id leadId){
        Lead leadObj =[SELECT Id, FirstName, LastName, Email, OwnerId from Lead  where id =: leadId];
        Id templateId; 
        String recipientEmail = leadObj.Email;
        System.debug('sendEmailUsingSendGrid >> '+recipientEmail);
        List<EmailTemplate> lst_EmailTemplate = [SELECT Id FROM EmailTemplate WHERE 
                                                 DeveloperName = 'Lead_Acknowledgement_Email' LIMIT 1];
        Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(lst_EmailTemplate[0].Id,
                                                                                 leadObj.OwnerId, leadObj.Id);
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
            '"from": {"email": "noreply@modon.com"},' +
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
        }
    }
    
    public static void sendEmailUsingSendGridBatch(Id leadId){
        Lead leadObj =[SELECT Id, FirstName, LastName, Email, OwnerId from Lead  where id =: leadId];
        Id templateId; 
        String recipientEmail = leadObj.Email;
        System.debug('sendEmailUsingSendGrid >> '+recipientEmail);
        List<EmailTemplate> lst_EmailTemplate = [SELECT Id FROM EmailTemplate WHERE 
                                                 DeveloperName = :System.Label.EmailTemplate LIMIT 1];
        Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(lst_EmailTemplate[0].Id,
                                                                                 leadObj.OwnerId, leadObj.Id);
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
            '"from": {"email": "noreply@modon.com"},' +
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
        }
    }
}