/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class SendDefaultNoticesFromBp {
    
    /**
* Sends defaulted/terminated notice emails for the given Business Process records.
* Each BP is mapped to a specific email template developer name.
*
* @param salesOrderIds      Set of Business_Process__c Ids to process
* @param bpIdToTemplateName Map of BP Id → EmailTemplate DeveloperName
* @throws AuraHandledException if salesOrderIds is null or empty
*/
    public static void sendDefaultedEmail(Set<Id> salesOrderIds, Map<Id, String> bpIdToTemplateName) {
        
        // Guard clause: salesOrderIds must be provided
        if (salesOrderIds == null || salesOrderIds.isEmpty()) {
            throw new AuraHandledException('Sales Order Ids are required');
        }
        
        // Accumulates email messages to be sent in bulk at the end
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        String docName;
        if(bpIdToTemplateName.size()>0) 
            docName=bpIdToTemplateName.values()[0] =='First_Default_Notice' ? 'Default Notice Document 1' :
        bpIdToTemplateName.values()[0] =='Second_Default_Email_Notification' ?
            'Default Notice Document 2' : bpIdToTemplateName.values()[0] =='Default_Termination_Notice'
                ? 'Termination Document' :null ;    
        
        // Query Business Process records with related Sales Order, Unit, and Account fields
        List<Business_Process__c> bpList = [
            SELECT Id, Name,
            Sales_order__r.Unit__r.Name,
            Sales_order__r.ProjectName__c,
            Sales_order__r.CustomerAccount__c,
            Sales_order__r.CustomerAccount__r.IsPersonAccount,
            Sales_order__r.CustomerAccount__r.PersonEmail,
            Sales_order__r.CustomerAccount__r.PersonContactId,
            (Select Id from Business_Process_Documents__r  where Name=:docName)
            FROM Business_Process__c
            WHERE Id IN :salesOrderIds
        ];
        
        // Collect Account Ids for Organisation (non-Person) Accounts only
        // Person Accounts have email directly on the account; orgs need a Contact lookup
        Set<Id> orgAccountIds = new Set<Id>();
        Map<Id, Id> bpToDocMap =new Map<Id,Id>();
        for (Business_Process__c bp : bpList) {
            if(bp.Business_Process_Documents__r.size()>0)
                bpToDocMap .put(bp.Id, bp.Business_Process_Documents__r[0].Id );
            if (!bp.Sales_Order__r.CustomerAccount__r.IsPersonAccount) {
                orgAccountIds.add(bp.Sales_Order__r.CustomerAccount__c);
            }
        }
        
        Map<Id, Id> docToContentDocMap = new Map<Id, Id>();
        
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :bpToDocMap.values()
        ]) {
            
            if (!docToContentDocMap.containsKey(cdl.LinkedEntityId)) {
                docToContentDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }
        
        Map<Id, ContentVersion> contentMap = new Map<Id, ContentVersion>();
        
        for (ContentVersion cv : [
            SELECT Id, Title, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docToContentDocMap.values()
            AND IsLatest = true
        ]) {
            contentMap.put(cv.ContentDocumentId, cv);
        }
        // Map to hold one active Contact per Organisation Account (used as email recipient)
        Map<Id, Contact> accountToContactMap = new Map<Id, Contact>();
        
        if (!orgAccountIds.isEmpty()) {
            // Fetch active contacts with emails for each org account
            for (Contact con : [
                SELECT Id, Email, AccountId
                FROM Contact
                WHERE AccountId IN :orgAccountIds
                AND Email != null
                AND Is_Active__c = true
            ]) {
                // Only keep the first active contact found per account
                if (!accountToContactMap.containsKey(con.AccountId)) {
                    accountToContactMap.put(con.AccountId, con);
                }
            }
        }
        
        // Extract unique template developer names from the BP-to-template map
        Set<String> templateNames = new Set<String>();
        for (String templateName : bpIdToTemplateName.values()) {
            if (!String.isBlank(templateName)) {
                templateNames.add(templateName);
            }
        }
        
        // Query EmailTemplate records and index them by DeveloperName for fast lookup
        Map<String, EmailTemplate> templateMap = new Map<String, EmailTemplate>();
        if (!templateNames.isEmpty()) {
            for (EmailTemplate et : [
                SELECT Id, DeveloperName, Name
                FROM EmailTemplate
                WHERE DeveloperName IN :templateNames
            ]) {
                templateMap.put(et.DeveloperName, et);
            }
        }
        
        // Loop through each Business Process record to build the email messages
        for (Business_Process__c so : bpList) {
            
            String toEmail;
            Id targetObjectId;
            
            // Resolve the template for this BP; skip if none is configured or found in Salesforce
            String templateName = bpIdToTemplateName.get(so.Id);
            if (String.isBlank(templateName) || !templateMap.containsKey(templateName)) {
                continue; // No valid template → skip this BP
            }
            
            EmailTemplate templateRec = templateMap.get(templateName);
            
            // Determine recipient based on account type:
            // Person Account → use PersonEmail and PersonContactId directly from the account
            if (so.Sales_Order__r.CustomerAccount__r.IsPersonAccount) {
                toEmail = so.Sales_Order__r.CustomerAccount__r.PersonEmail;
                targetObjectId = so.Sales_Order__r.CustomerAccount__r.PersonContactId;
            }
            // Organisation Account → use the first active contact found earlier
            else if (accountToContactMap.containsKey(so.Sales_Order__r.CustomerAccount__c)) {
                Contact con = accountToContactMap.get(so.Sales_Order__r.CustomerAccount__c);
                toEmail = con.Email;
                targetObjectId = con.Id;
            }
            
            // Skip if no valid recipient could be resolved
            if (targetObjectId == null || String.isBlank(toEmail)) {
                continue;
            }
            
            // Build the email message using the resolved template and recipient
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(targetObjectId); // Required for template merge fields
            mail.setWhatId(so.Id);                  // Associates the email with the BP record
            mail.setTemplateId(templateRec.Id);     // Uses the resolved email template
            mail.setSaveAsActivity(true); // Logs email as an activity on the record
            if (bpToDocMap.size()>0 && bpToDocMap.containsKey(so.Id) 
                && docToContentDocMap.size()>0 &&  docToContentDocMap.containsKey(bpToDocMap.get(so.Id))
                && 	contentMap.size()>0 && contentMap.containsKey(docToContentDocMap.get(bpToDocMap.get(so.Id)))
               ) {
                   ContentVersion cv = contentMap.get(docToContentDocMap.get(bpToDocMap.get(so.Id)));
                   Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
                   att.setFileName(cv.Title);
                   att.setBody(cv.VersionData);
                   mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{att});
               }
            
            
            emailList.add(mail);
        }
        
        // Send all emails in a single bulk call to stay within governor limits
        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList);
        }
        
        /*
* LEGACY: Old hardcoded email body (now replaced by template-based approach above).
* Kept here for reference. Remove once confirmed no longer needed.
*/
    }
    
    public class Request {
        @InvocableVariable(required=true)
        public Id businessProcessId;
        
        @InvocableVariable
        public String templateDeveloperName;
        
    }
    @InvocableMethod(label='Send D&T Customer Negotiation 30 Day Email')
    public static void invokeFromFlow(List<Request> requestList) {
        
        if (requestList == null || requestList.isEmpty()) {
            return;
        }
        
        Set<Id> businessProcessIds = new Set<Id>();
        Map<Id, String> bpIdToTemplateName = new Map<Id, String>();
        
        for (Request req : requestList) {
            if (req == null || req.businessProcessId == null) {
                continue;
            }
            
            businessProcessIds.add(req.businessProcessId);
            
            bpIdToTemplateName.put(
                req.businessProcessId,
                String.isBlank(req.templateDeveloperName)
                ? Label.Second_Default_Notice
                : req.templateDeveloperName.trim()
            );
        }
        
        if (!businessProcessIds.isEmpty()) {
            sendDefaultedEmail(businessProcessIds, bpIdToTemplateName);
        }
    }
}