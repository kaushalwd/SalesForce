/* Version       Author                          Date            Comment                                                                      
* 1.0           sanath.manohar@activemindsit.com    19 Dec 2023      Initial Draft(Communication Record Creation,Approvalprocess,emailsending)      
1.1           raghu.chilukuri@activemindsit.com    08/03/26         Template Change
1.2           Upendra.assam@activemindsit.com    11/03/36         template Verify and code refinement
1.3           raghu.chilukuri@activeminds.com    10/04/26         Changed The Logic Of personalizations to add cc emails
1.4           raghu.chilukuri@activemindsit.com  21/04/26         Added Bcc and NO_DATA Logic for The cc and Bcc emails 
1.5           upendra.asam@modon.com             16/06/26         I have done multiple changes in  this batch apex to handle the broker activation and de activation
**********************************************************************************************
*/

global class MBP_TradeLicenseExpiryBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable, Database.AllowsCallouts {
    global Set<Id> accountIdsForPermissionQueue = new Set<Id>();
    
    

    






    global Database.QueryLocator start(Database.BatchableContext bc) {
        
        Date today = Date.today();
        Date d30 = today.addDays(30);
        Date d15 = today.addDays(15);
        Date d1 = today.addDays(1);
        List<Date> expiryDates = new List<Date>{ d30, d15, d1, today };
        Id recordTypeId = BRConstants.BROKER_AGENCY_RT;
        String agencyStatus = 'Active';
        
        System.debug('##### BATCH START ####');
        System.debug('Today: ' + today + ' | D+30: ' + d30 + ' | D+15: ' + d15 + ' | D+1: ' + d1);
        
        return Database.getQueryLocator([
            SELECT Id,
            Name,
            TradeLicenseExpiryDate__c,
            Agency_Status__c,
            Agency_Status_Reason__c,
            Trade_License_Status__c,
            Bank_Status__c,
            (SELECT Id,
             Name,
             Email,
             Broker_Type__c,
             Agent_Status__c,
             Agent_Status_Reason__c,
             Primary_Owner__c
             FROM Contacts)
            FROM Account
            WHERE RecordTypeId = :recordTypeId
            AND TradeLicenseExpiryDate__c IN :expiryDates
            AND Agency_Status__c = :agencyStatus


        ]);
    }
    
 





    global void execute(Database.BatchableContext bc, List<Account> scope) {
        
        System.debug('##### EXECUTE CALLED - SCOPE SIZE: ' + scope.size());
        
        Date today = Date.today();
        List<Contact> contactsToUpdate = new List<Contact>();
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Account acc : scope) {
            
            System.debug('Processing Account: ' + acc.Name + ' | Expiry: ' + acc.TradeLicenseExpiryDate__c);
            
            Date expiry = acc.TradeLicenseExpiryDate__c;
            Integer daysLeft = today.daysBetween(expiry);
            
            System.debug('Days Left: ' + daysLeft);
            
            Contact agencyAdmin;
            Contact primaryOwner;
            
            for (Contact c : acc.Contacts) {
                
                if (c.Broker_Type__c == BRConstants.AGENT_TYPE_AGENCYADMIN) {
                    agencyAdmin = c;
                }
                
                if (c.Broker_Type__c == BRConstants.AGENT_TYPE_OWNER &&
                    c.Primary_Owner__c == true) {
                        
                        primaryOwner = c;
                    }
            }
            
            System.debug('Agency Admin: ' + (agencyAdmin != null ? agencyAdmin.Name : 'NONE'));
            System.debug('Primary Owner: ' + (primaryOwner != null ? primaryOwner.Name : 'NONE'));
            Boolean skipReminder =
                acc.Trade_License_Status__c == 'Submitted' ||
                acc.Bank_Status__c == 'Submitted';
            // ===== Sending Reminder Emails =====
            if (
                !skipReminder &&
                (daysLeft == 30 || daysLeft == 15 || daysLeft == 1)
            ) {
                
                // Wrapper to align body with Fixed "Best Regards, Modon" spacing from utility
                String wrapperStart =
                    '<tr>' +
                    '  <td style="padding:20px 30px 10px 30px;' +
                    '             font-family:Arial, sans-serif;' +
                    '             font-size:16px;' +
                    '             line-height:20px;' +
                    '             color:#000000;">';
                
                String wrapperEnd =
                    '  </td>' +
                    '</tr>';
                
                for (Contact c : new List<Contact>{ agencyAdmin, primaryOwner }) {
                    
                    if (c != null && String.isNotBlank(c.Email)) {
                        
                        String subject;
                        String htmlBody;
                        
                        if (daysLeft == 30) {
                            
                            subject = 'Important: Trade Licence Expiry Notification';
                            /* Update 1.1 Starts here*/
                            htmlBody =
                                wrapperStart +
                                '<p style="margin:0;">Dear ' + c.Name + ',</p><br/>' +
                                '<p style="margin:0;">We would like to remind you that your agency’s trade licence will expire in 30 days.</p><br/>' +
                                '<p style="margin:0;">Please ensure that your trade licence is renewed promptly to avoid any interruptions to your business operations.</p><br/>' +
                                '<p style="margin:0;">If you have already initiated the renewal process, please disregard this message.</p><br/>' +
                                '<p style="margin:0;">Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email ' +
                                '<a href="mailto:broker@modon.com">broker@modon.com</a>.</p>' +
                                wrapperEnd;
                            
                        } else if (daysLeft == 15) {
                            
                            subject = 'Reminder: Trade Licence Expiry in 15 Days';
                            
                            htmlBody =
                                wrapperStart +
                                '<p style="margin:0;">Dear ' + c.Name + ',</p><br/>' +
                                '<p style="margin:0;">This is a reminder that your agency’s trade licence will expire in 15 days.</p><br/>' +
                                '<p style="margin:0;">Please arrange for the renewal as soon as possible to ensure your operations continue without disruption.</p><br/>' +
                                '<p style="margin:0;">If you have already renewed your trade licence, kindly disregard this message.</p><br/>' +
                                '<p style="margin:0;">Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email ' +
                                '<a href="mailto:broker@modon.com">broker@modon.com</a>.</p>' +
                                wrapperEnd;
                            
                        } else { // daysLeft == 1
                            
                            subject = 'Final Reminder: Trade Licence Expiry Tomorrow';
                            
                            htmlBody =
                                wrapperStart +
                                '<p style="margin:0;">Dear ' + c.Name + ',</p><br/>' +
                                '<p style="margin:0;">This is a final reminder that your agency’s trade licence will expire tomorrow.</p><br/>' +
                                '<p style="margin:0;">To avoid any disruption to your account, please ensure that the renewed trade licence details are updated before the expiry date.</p><br/>' +
                                
                                '<p style="margin:0;">If the trade licence is not updated by the expiry date:</p>' +
                                '<ul style="margin:8px 0 0 18px; padding:0;">' +
                                '  <li>Agency access will become inactive.</li>' +
                                '  <li>Owner and Admin users will have limited access to update the required details only.</li>' +
                                '  <li>Agent access will be inactive.</li>' +
                                '</ul><br/>' +
                                
                                '<p style="margin:0;">We strongly recommend completing the update as soon as possible to maintain uninterrupted access to all portal services.</p>' +
                                wrapperEnd;
                        }
                        
                        /*update 1.1 Ends Here*/
                        
                        String emailBody = MBP_ModonEmailUtilityClass.getFullEmailHtml(htmlBody);
                        /*Update version 1.4
@description : Added cc and bcc NO_DATA logic
*/
                        String ccJson = '';
                        String ccLabel = Label.MBP_BatchEmailsCc;
                        
                        if (ccLabel != null && !ccLabel.contains('NO_DATA') && !String.isBlank(ccLabel)) {
                            ccJson = '"cc":[{"email":"' + ccLabel.replace(',', '"},{"email":"') + '"}],';
                        }
                        
                        String bccJson = '';
                        String bccLabel = Label.MBP_BatchEmailsBCc;
                        
                        if (bccLabel != null && !bccLabel.contains('NO_DATA') && !String.isBlank(bccLabel)) {
                            bccJson = '"bcc":[{"email":"' + bccLabel.replace(',', '"},{"email":"') + '"}],';
                        }
                        
                        
                        String personalization ='[{' + '"to":[{"email":"' + c.Email + '"}],' + ccJson + bccJson + '"subject":"' + subject + '"' +'}]';
                        
                        
                        /*Update version 1.3
@description : added cc emails using a Custom label To the Personalizations
*/                        
                        BP_SendGridUtilityClass.sendEmail(
                            personalization,
                            'Al Naseem',
                            subject,
                            emailBody,
                            false
                        );
                        //Update version 1.4 Ends Here                       
                    }
                }
            }
            
            // ===== Expiry Day - Deactivate Users =====
            if (daysLeft == 0) {
                accountIdsForPermissionQueue.add(acc.Id);
                System.debug('Trade License Expired — Updating Status and Users');
                
                // Account Status Update
                acc.Agency_Status__c =
                    BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION;
                
                acc.Agency_Status_Reason__c =
                    'Trade License Expired';
                acc.Is_Broker_Agency_Blocked__c=true;
                accountsToUpdate.add(acc);
                

                for (Contact c : acc.Contacts) {
                    
                    if (
                        c.Agent_Status__c == 'Active' ||
                        c.Agent_Status__c == 'Pending Verification'
                    ) {
                        
                        c.Agent_Status_Reason__c = 'Trade License Expired';
                        
                        contactsToUpdate.add(c);
                        
                        System.debug('Contact Updated: ' + c.Name);
                    }
                }
                
                
            }
            if (!contactsToUpdate.isEmpty()) {
                System.debug('Updating Contacts Count: ' + contactsToUpdate.size());
                update contactsToUpdate;
            }
            
            if (!accountsToUpdate.isEmpty()) {
                System.debug('Updating Accounts Count: ' + accountsToUpdate.size());
                   /*1.5 starts */
                MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue = true;
                 /*1.5  ends*/
                update accountsToUpdate;
                /*1.5 starts */
                MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue = false;
                 /*1.5  ends*/






            }
            
            System.debug('#### EXECUTE END ####');
        }












    }
    
 
    




    global void finish(Database.BatchableContext bc) {
        
        if(!accountIdsForPermissionQueue.isEmpty()){
            







            System.enqueueJob(
                new MBP_BrokerPermissionQueue(
                    accountIdsForPermissionQueue

                )
            );


        }
    }
    
    /**
* @description Executes the trade license expiry batch job when triggered
*              from the Salesforce scheduler.
*/
    
    global void execute(SchedulableContext sc) {
        System.debug('##### SCHEDULABLE TRIGGERED - EXECUTING BATCH #####');
        Database.executeBatch(new MBP_TradeLicenseExpiryBatch(), 100);
    }
}