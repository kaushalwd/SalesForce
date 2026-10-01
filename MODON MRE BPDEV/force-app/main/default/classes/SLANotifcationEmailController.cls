public class SLANotifcationEmailController {
    public class Request {
        @InvocableVariable(required = true)
        public Id salesOrderId;
        
        @InvocableVariable(required = false)
        public String team; 
    }
    
    @InvocableMethod(
        label='Send SLA Email'
        description='Sends SLA Assigned email to the Customer Management Associate for the given SalesOrder'
    )
    public static void sendSlaEmails(List<Request> requests) {
        try{
        String emailTemplateName;
        // Bulk-safe: Flow can pass multiple records
        for (Request req : requests) {
            if (req.salesOrderId == null) continue;
            
            // If user not provided, you can derive from SalesOrder__c
            Id targetUserId=null;
            String targetUserEmail = null;
            SalesOrder__c so = [
                    SELECT Id, Customer_Management_Associate__c,Customer_Management_Associate__r.Email,SalesAssociate__c,Sales_Operations_Associate__c,Finance_Associate__c,Finance_Associate__r.Name,
                    Customer_Management_Associate__r.Name,ProjectName__c,CustomerAccount__r.Name,SalesAssociate__r.Email,SalesAssociate__r.Name,Sales_Operations_Associate__r.Email,Sales_Operations_Associate__r.Name,Finance_Associate__r.Email,
                    SLA_Hours__c,SLA_Start_Date_Time__c,SLA_End_Date_Time__c,Name,Unit__r.Name  FROM SalesOrder__c
                    WHERE Id = :req.salesOrderId
                    LIMIT 1
                ];
            
            if (targetUserId == null) {
                
                if(req.team == 'Customer Management'){
                	targetUserId = so.Customer_Management_Associate__c;
                    targetUserEmail = so.Customer_Management_Associate__r.Email;
                    emailTemplateName = 'SLA_Assigned_Customer_Management';
                }else if(req.team == 'Sales Associate'){
                	targetUserId = so.SalesAssociate__c;
                    targetUserEmail = so.SalesAssociate__r.Email;
                    emailTemplateName = 'SLA_Assigned_With_Round_Robin';
                }else if(req.team == 'Sales Operation Associate'){
                	targetUserId = so.Sales_Operations_Associate__c;
                    targetUserEmail = so.Sales_Operations_Associate__r.Email;
                    emailTemplateName = 'SLA_Assigned_Sales_Operations';
                }else if(req.team == 'Finance Associate'){
                	targetUserId = so.Finance_Associate__c;
                    targetUserEmail = so.Finance_Associate__r.Email;
                    emailTemplateName = 'SLA_Assigned_Finance';
                }
            }
            system.debug('targetUserEmail:'+targetUserEmail);
            if (targetUserEmail == null) {
                // No user, skip this record
                continue;
            }
            EmailTemplate et = [
                    SELECT Id, Name, DeveloperName, HtmlValue
                    FROM EmailTemplate
                    WHERE DeveloperName =: emailTemplateName
                    LIMIT 1
                ];
            OrgWideEmailAddress owea = [
                    SELECT Id, Address, DisplayName
                    FROM OrgWideEmailAddress
                    WHERE Address = 'noreply@modon.com'
                    LIMIT 1
                ];
            String baseUrl  = URL.getOrgDomainUrl().toExternalForm();
			String recordUrl = baseUrl + '/' + req.salesOrderId;
            String subject = '';
            if(et.Id <> null){
                String htmlValue = et.HtmlValue;
                subject= so.Name+'-Unit:'+so.Unit__r.Name+'-Assigned to you for ';
                if(so.Customer_Management_Associate__c <> null && req.team == 'Customer Management'){
                  subject +='CM Verification';
                   htmlValue = htmlValue.replace('{!SalesOrder__c.Customer_Management_Associate__c}',so.Customer_Management_Associate__r.Name);
                }
                if(so.SalesAssociate__c <> null && req.team == 'Sales Associate'){
                   subject +='Sales Verification';
                   htmlValue = htmlValue.replace('{!SalesOrder__c.SalesAssociate__c}',so.SalesAssociate__r.Name);  
                }
                if(so.Finance_Associate__c <> null && req.team == 'Finance Associate'){
                   subject +='Finance Verification';
                   htmlValue = htmlValue.replace('{!SalesOrder__c.Finance_Associate__c}',so.Finance_Associate__r.Name);
                }
                if(so.Sales_Operations_Associate__c <> null && req.team == 'Sales Operation Associate'){
                   subject +='Sales Operation Verification';
                   htmlValue = htmlValue.replace('{!SalesOrder__c.Sales_Operations_Associate__c}',so.Sales_Operations_Associate__r.Name);  
                }
                htmlValue = htmlValue.replace('{!SalesOrder__c.Name}',so.Name);
                htmlValue = htmlValue.replace('{!SalesOrder__c.ProjectName__c}',so.ProjectName__c);
                htmlValue = htmlValue.replace('{!SalesOrder__c.CustomerAccount__c}',so.CustomerAccount__r.Name);
                htmlValue = htmlValue.replace('{!SalesOrder__c.SLA_Hours__c}',so.SLA_Hours__c <> null ? String.valueOf(so.SLA_Hours__c) : '');
                htmlValue = htmlValue.replace('{!SalesOrder__c.SLA_Start_Date_Time__c}',so.SLA_Start_Date_Time__c <> null ? String.valueOf(so.SLA_Start_Date_Time__c.format()):'');
                htmlValue = htmlValue.replace('{!SalesOrder__c.SLA_End_Date_Time__c}',so.SLA_End_Date_Time__c <> null? String.valueOf(so.SLA_End_Date_Time__c.format()):'');
                htmlValue = htmlValue.replace('{!SalesOrder__c.Link}',recordUrl);
                htmlValue = htmlValue.replace('{!SalesOrder__c.Unit__c}',so.Unit__r.Name);
               
                sendWithTemplate(et.Id,targetUserEmail,req.salesOrderId,htmlValue,owea,subject);
            }
            // Call your existing email service (the one using Static Resource HTML)
            //SLAEmailService.sendSlaEmail(req.salesOrderId, targetUserId);
        }
        }catch(Exception ex){
            system.debug('Exception ex:'+ex.getMessage());
        }
    }
    public static void sendWithTemplate(Id templateRecordId, String email, Id relatedRecordId,String htmlValue,OrgWideEmailAddress owea,String subject) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        //mail.setTemplateId(templateRecordId);       // EmailTemplate.Id
        //mail.setTargetObjectId(recipientContactId); // Contact / Lead / User (depends on template Recipient Type)
        //mail.setWhatId(relatedRecordId);            // e.g. SalesOrder__c Id (only allowed if recipient is Contact/Lead)
		mail.setSaveAsActivity(false);
        mail.setToAddresses(new String[] { email });
        mail.setSubject(subject);
		mail.setHtmlBody(htmlValue); 
        mail.setOrgWideEmailAddressId(owea.Id);

        //mail.setTargetobjectId(relatedRecordId);
      //  Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }, false); // second param = allOrNone

        for (Messaging.SendEmailResult r : results) {
            System.debug('Email success? ' + r.isSuccess());
            if (!r.isSuccess()) {
                for (Messaging.SendEmailError e : r.getErrors()) {
                    System.debug('EMAIL ERROR: ' + e.getMessage() + ' | StatusCode: ' + e.getStatusCode());
                }
            }
        }
	}
}