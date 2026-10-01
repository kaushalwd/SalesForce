/**
 * Service class for processing PassFort webhook data.
 * Contains business logic separated from the REST endpoint handler.
 * 
 * Business Context:
 * This service is the core processing engine for PassFort webhooks. It implements
 * the business rules for each event type, translating PassFort risk assessments and
 * verification results into Salesforce record updates. This separation of concerns
 * allows the webhook handler to focus on API protocol while this class handles
 * business operations.
 * 
 * Integration Architecture:
 * - PassfortWebhookService: REST endpoint that receives webhooks
 * - PassfortIntegrationService (this class): Business logic processor 
 * - PassfortWebhookModel: Data structures for webhook payloads
 * 
 * Process Flow:
 * 1. Webhook received by PassfortWebhookService
 * 2. Payload parsed into PassfortWebhookModel objects
 * 3. This service processes based on event
 * 4. Salesforce records updated based on webhook data
 * 5. ProcessResult returned to webhook service for response formatting
 *
****************************************************************************************************/

/*
 Version            Author                                    Date             Comment
  1.0              raghu.chilukuri@activemindsit.com         14-01-26      :Added Broker registration related lines of code to the 
                                                                            processRiskLevelChange and processProductStatusChange methods.
  1.1              raghu.chilukuri@activemindsit.com         10-2-26       :Added methods to fetch response and Store them at backend 
                                                                            and Updating Service Request(updateBrokerTaskStatus,sendBrokerComplianceEmail)
*/
public without sharing class PassfortIntegrationService {
    
    /**
     * Process result class for returning webhook processing status.
     * 
     * Business Context:
     * This inner class encapsulates the result of webhook processing, including
     * success/failure status, appropriate HTTP status codes, and any data that
     * should be returned to PassFort in the response. This standardized result
     * format ensures consistent error handling across all event types.
     */
    public class ProcessResult {
        public Boolean success { get; set; }
        public String message { get; set; }
        public Integer statusCode { get; set; }
        public Map<String, Object> data { get; set; }
        
        public ProcessResult() {
            this.success = true;
            this.statusCode = 200;
            this.message = 'Success';
            this.data = new Map<String, Object>();
        }
    }
    
    /**
     * Process a webhook based on the event type.
     * 
     * @param webhook The parsed webhook payload containing event data
     * @param requestId A unique identifier for tracking this request in logs
     * @return ProcessResult containing the outcome and any response data
     * 
     * Business Context:
     * This is the primary entry point for webhook processing. It routes each event
     * to the appropriate handler method based on event. Currently supported events:
     * - RISK_LEVEL_CHANGED: Updates risk assessment data on Salesforce records
     * - CHECK_COMPLETED: Records when verification checks are completed
     * - PRODUCT_STATUS_CHANGED: Updates product status information
     * 
     * The method ensures comprehensive error handling and logging throughout the
     * processing pipeline. A requestId is used for correlation across log entries.
     */
    public static ProcessResult processWebhook(PassfortWebhookModel.Webhook webhook, String requestId) {
        ProcessResult result = new ProcessResult();
        System.debug('The Webhook is called'+webhook);
        try {
            if (webhook == null) {
                result.success = false;
                result.message = 'Invalid webhook data';
                result.statusCode = 400;
                return result;
                
            }

            system.debug('The resukt is called'+ result);
            
            IntegrationLogger.info('Processing ' + webhook.event + ' event. RequestId: ' + requestId);
            
            // Process based on event type
            switch on webhook.event {
                when 'RISK_LEVEL_CHANGED' {
                    processRiskLevelChange(webhook, result);
                }
                when 'PRODUCT_STATUS_CHANGED' {
                    processProductStatusChange(webhook, result);
                }
                when else {
                    result.success = false;
                    result.message = 'Unsupported event type: ' + webhook.event;
                    result.statusCode = 422;
                }
            }
            
        } catch (Exception e) {
            IntegrationLogger.error('Error processing webhook: ' + e.getMessage() + '. Stack: ' + e.getStackTraceString());
          //  result.success = false;
          //  result.message = 'Processing error: ' + e.getMessage();
          //  result.statusCode = 500;
        }
        
        return result;
    }
    
    /**
     * Process a risk level change event.
     * 
     * @param webhook The webhook payload containing risk level data
     * @param result The ProcessResult object to populate with the outcome
     * 
     * Business Context:
     * This handler processes risk level changes from PassFort. When an entity's risk
     * assessment is updated in PassFort (e.g., after sanctions screening or other checks),
     * this method updates the corresponding Salesforce record with the new risk level.
     * 
     * Implementation Details:
     * 1. Extracts the PassFort entity ID and new risk level from the webhook
     * 2. Queries Salesforce for a matching Account using External_ID__c
     * 3. Updates the Account's Risk_Level__c field
     * 4. Also updates Risk_Score__c if provided in the metadata
     * 
     * The mapping between PassFort entity IDs and Salesforce records is managed via
     * the External_ID__c field on Account objects.
     */
    private static void processRiskLevelChange(PassfortWebhookModel.Webhook webhook, ProcessResult result) {
        PassfortWebhookModel.Entity entity = webhook.data;
        String entityId = entity.profile_id;
        String riskLevel = entity.new_category;
        
        IntegrationLogger.debug('Processing risk level change for entity ' + entityId + ' to ' + riskLevel);

        try {
            // Find the corresponding record in Salesforce
            List<Contact> contacts = [SELECT Id, PassfortRiskStatus__c, PassfortApprovalStatus__c FROM Contact WHERE ProfileId__c = :entityId LIMIT 1];
            List<Account> accounts = [SELECT Id, PassfortRiskStatus__c, PassfortApprovalStatus__c FROM Account WHERE ProfileId__c = :entityId LIMIT 1];

            /* Update Version 1.0 starts Here
            * @description:
            * Fetches the Registration record based on ProfileId and updates its risk status.
            * Also updates the related Passfort Transaction with the API response details.
            * Ensures Registration handling is aligned with Account and Contact logic.
            */

            List<Registration__c> registrations = [SELECT Id, PassfortRiskStatus__c, PassfortApprovalStatus__c FROM Registration__c WHERE ProfileId__c = :entityId LIMIT 1];
            
            
            if (!registrations.isEmpty()) {
                Registration__c reg = registrations[0];
                reg.PassfortRiskStatus__c = riskLevel;
                update reg;
                
                result.data.put('registrationId', reg.Id);
                result.data.put('riskLevel', riskLevel);
                result.message = 'Risk level updated successfully for Registration';
                
                
                List<PassfortTransaction__c> transactions = [
                    SELECT Id 
                    FROM PassfortTransaction__c 
                    WHERE ProfileId__c = :entityId
                    LIMIT 1
                ];
                
               if (!transactions.isEmpty()) {
                    transactions[0].Final_Response__c = JSON.serializePretty(result);
                    update transactions[0];
                }
            }
            //Update Version 1.0 Ends Here 

            else if (!contacts.isEmpty()) {
                // Update the risk level
                Contact con = contacts[0];
                con.PassfortRiskStatus__c = riskLevel;
                update con;

                result.data.put('contactId', con.Id);
                result.data.put('riskLevel', riskLevel);
                result.message = 'Risk level updated successfully';
            } else if (!accounts.isEmpty()) {
                // Update the risk level
                Account acct = accounts[0];
                acct.PassfortRiskStatus__c = riskLevel;
                
                update acct;
                
                result.data.put('accountId', acct.Id);
                result.data.put('riskLevel', riskLevel);
                result.message = 'Risk level updated successfully';
            } else {
               // IntegrationLogger.warn('Account not found for profile ID: ' + entityId);result.success = false;result.message = 'Account not found for profile ID: ' + entityId;result.statusCode = 404;
            }
        } catch (Exception e) {
            IntegrationLogger.error('Error updating risk level: ' + e.getMessage());
            throw e; // Let the main method handle the exception
        }
    }
    
    /**
     * Process a product status change event.
     * 
     * @param webhook The webhook payload containing product status data
     * @param result The ProcessResult object to populate with the outcome
     * 
     * Business Context:
     * This handler processes notifications when a PassFort product's status changes.
     * PassFort products represent bundled compliance services like:
     * - KYC (Know Your Customer) verification
     * - KYB (Know Your Business) verification
     * - AML (Anti-Money Laundering) screening
     * 
     * Implementation Notes:
     * - Currently a placeholder implementation
     * - In a full implementation, this would typically:
     *   1. Extract product details and new status from the webhook
     *   2. Update corresponding product records or activities in Salesforce
     *   3. Potentially trigger approval processes or notifications
     */
    private static void processProductStatusChange(PassfortWebhookModel.Webhook webhook, ProcessResult result) {
        PassfortWebhookModel.Entity entity = webhook.data;
        String entityId = entity.profile_id;
        String productStatus = entity.new_status;
		
        if(String.isNotBlank(productStatus) && productStatus == 'IN_REVIEW'){ productStatus = 'In review'; }
        
        IntegrationLogger.debug('Processing risk level change for entity ' + entityId + ' to ' + productStatus);

        try {
            // Find the corresponding record in Salesforce
            List<Contact> contacts = [SELECT Id, PassfortRiskStatus__c, PassfortApprovalStatus__c FROM Contact WHERE ProfileId__c = :entityId LIMIT 1];
            List<Account> accounts = [SELECT Id, PassfortRiskStatus__c, PassfortApprovalStatus__c FROM Account WHERE ProfileId__c = :entityId LIMIT 1];

            /* Update Version 1.0
            @description :
            * Added logic to fetch Registration using ProfileId and update Product (Approval) status.
            * Updates related Passfort Transaction with response details.
            * Triggers broker task status update when status is Approved or Rejected.
            */
            List<Registration__c> registrations = [SELECT Id, PassfortRiskStatus__c, PassfortApprovalStatus__c FROM Registration__c WHERE ProfileId__c = :entityId LIMIT 1];
        
           if (!registrations.isEmpty()) {
               Registration__c reg = registrations[0];
               reg.PassfortApprovalStatus__c = productStatus; 
               update reg;
            
               result.data.put('registrationId', reg.Id);
               result.data.put('productStatus', productStatus);
               result.message = 'Product Status updated successfully for Registration';
            
               List<PassfortTransaction__c> transactions = [SELECT Id FROM PassfortTransaction__c WHERE ProfileId__c = :entityId LIMIT 1];
            
               if (!transactions.isEmpty()) {
                  transactions[0].Final_Response__c = JSON.serializePretty(result);
                   update transactions[0];
                }
            
                    String originalProductStatus = entity.new_status;

                if (originalProductStatus == constants.BROKER_PASSFORT_RESPONSE_APPROVED || originalProductStatus == constants.BROKER_PASSFORT_RESPONSE_REJECTED) {
                    updateBrokerTaskStatus(reg.Id, originalProductStatus);
                }



            }
            //update Version 1.0 Ends Here

            else if (!contacts.isEmpty()) {
                // Update the risk level
                Contact con = contacts[0];
                con.PassfortApprovalStatus__c = productStatus;

                update con;
                
                result.data.put('contactId', con.Id);
                result.data.put('productStatus', productStatus);
                result.message = 'Risk level updated successfully';
            } else if (!accounts.isEmpty()) {
                // Update the risk level
                Account acct = accounts[0];
                acct.PassfortApprovalStatus__c = productStatus;

                update acct;
                
                result.data.put('accountId', acct.Id);
                result.data.put('productStatus', productStatus);
                result.message = 'Product Status updated successfully';
            } else {
             //  IntegrationLogger.warn('Account not found for profile ID: ' + entityId);result.success = false;result.message = 'Account not found for profile ID: ' + entityId;result.statusCode = 404;
            }
        } catch (Exception e) {
            IntegrationLogger.error('Error updating risk level: ' + e.getMessage());
            throw e; // Let the main method handle the exception
        }
    }

  /** Update Version 1.1
    * @description Updates the Broker Registration validation task status based on
    *              Passfort approval or rejection response and triggers a compliance email.
    * @param registrationId   Id of the related Registration record
    * @param passfortStatus   Status received from Passfort (APPROVED/REJECTED)
    */
    @testvisible
    private static void updateBrokerTaskStatus(Id registrationId, String passfortStatus) {
        try {
            String taskStatus;
            
            if (passfortStatus == Constants.BROKER_PASSFORT_RESPONSE_APPROVED) {
                taskStatus = Constants.BROKER_COMPLIANCE_TASK_APPROVED;
            } else if (passfortStatus == Constants.BROKER_PASSFORT_RESPONSE_REJECTED) {
                taskStatus = Constants.BROKER_COMPLIANCE_TASK_REJECTED;
            } else {
                return; 
            }
            
            List<ServiceRequest__c> srs = [SELECT Id FROM ServiceRequest__c WHERE Registration__c = :registrationId
                               AND RecordType.DeveloperName = :Constants.BROKER_REGISTRATION_RECORDTYPE LIMIT 1];
            
            if (srs.isEmpty()) return;
            
            Id srId = srs[0].Id;
            
            List<Task> tasksToUpdate = [SELECT Id, WhatId, Subject, Broker_Registration_Status__c 
                                        FROM Task WHERE WhatId = :srId 
                                        AND Subject = :Constants.BROKER_COMPLIANCE_TASK_SUBJECT AND Broker_Registration_Status__c != :taskStatus];
            
            if (tasksToUpdate.isEmpty()) return;
            
            for (Task t : tasksToUpdate) {
                t.Broker_Registration_Status__c = taskStatus;
            }
            
            update tasksToUpdate;
            sendBrokerComplianceEmail(registrationId, taskStatus);
            
            IntegrationLogger.info(
                'Updated ' + tasksToUpdate.size() +
                ' Validation tasks to ' + taskStatus +
                ' based on Passfort response for Registration: ' + registrationId
            );
            
        } catch (Exception e) {
            IntegrationLogger.error('Error in updateBrokerTaskStatus: ' + e.getMessage());
        }
    }
    
  /** Update Version 1.1
    * @description Sends a compliance notification email when a Broker Registration
    *              Service Request is approved or rejected.
    * @param registrationId   Id of the related Registration record
    * @param status           Final status of the registration (Approved/Rejected)
    */
    public static void sendBrokerComplianceEmail(Id registrationId, String status) {
        
        try {
            if (registrationId == null) return;
            if (status != constants.BROKER_COMPLIANCE_TASK_APPROVED && status != constants.BROKER_COMPLIANCE_TASK_REJECTED) return;
            
            ServiceRequest__c sr = [SELECT Id, Name FROM ServiceRequest__c WHERE Registration__c = :registrationId
                                    AND RecordType.DeveloperName = :Constants.BROKER_REGISTRATION_RECORDTYPE LIMIT 1];
            
            Broker_Compliance__mdt cfg = Broker_Compliance__mdt.getInstance('Default');
            if (cfg == null) return;
            
            List<String> toEmails = new List<String>();
            if (String.isNotBlank(cfg.To_Email__c)) {
                for (String e : cfg.To_Email__c.split(',')) {
                    if (String.isNotBlank(e)) toEmails.add(e.trim());
                }
            }
            if (toEmails.isEmpty()) return;
            
            List<Map<String, Object>> ccList = new List<Map<String, Object>>();
            if (String.isNotBlank(cfg.CC_Email__c)) {
                for (String e : cfg.CC_Email__c.split(',')) {
                    if (String.isNotBlank(e)) {
                        ccList.add(new Map<String, Object>{ 'email' => e.trim() });
                    }
                }
            }
            
            String subject = 'Service Request ' + sr.Name + ' - ' + status;
            String bodyContent =
                '<div style="padding:20px 30px 10px 30px; font-family:Arial, sans-serif; font-size:15px; color:#000;">' +
                '<p style="margin:0 0 10px 0;">Hi Team,</p>' +
                '<p style="margin:0;">The Service Request <b>' + sr.Name + '</b> has been <b>' + status +
                '</b> by the Compliance Team.</p>' +
                '</div>';
            
            String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(bodyContent);
            
            List<Object> personalizationsList = new List<Object>();
            
            for (String toEmail : toEmails) {
                Map<String, Object> p = new Map<String, Object>{
                    'to' => new List<Object>{
                        new Map<String, Object>{ 'email' => toEmail }
                    }
                };
                    
                    if (!ccList.isEmpty()) p.put('cc', ccList);
                
                personalizationsList.add(p);
            }
            
            String personalizations = JSON.serialize(personalizationsList);
            
            String sendGridLabel = constants.BROKER_SEND_GRID_LABEL;
            
            BP_SendGridUtilityClass.sendEmail(personalizations,sendGridLabel,subject,emailHtml,true);
            
        } catch (Exception e) {
            IntegrationLogger.error('Email Error: ' + e.getMessage());
        }
    }

    //Update Version 1.1 Ends Here 
    
}