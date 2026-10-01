/* Version       Author                          Date            Comment                                                                      
* 1.0           sanath.manohar@activemindsit.com    19 Dec 2023      Initial Draft(Communication Record Creation,Approvalprocess,emailsending)      
  1.1           raghu.chilukuri@activemindsit.com    08/03/26         Template Change
  1.2           Upendra.assam@activemindsit.com    11/03/36         template Verify and code refinement
  1.3           raghu.chilukuri@activeminds.com    10/04/26         Changed The Logic Of personalizations to add cc emails
  1.4           raghu.chilukuri@activemindsit.com  21/04/26         Added Bcc and NO_DATA Logic for The cc and Bcc emails 
**********************************************************************************************
*/

global class MBP_EmiratesIDExpiryBatch
    implements Database.Batchable<SObject>,
               Database.Stateful,
               Schedulable,
               Database.AllowsCallouts {


    List<Id> userIdsToDeactivate = new List<Id>();
    Map<Id, Boolean> limitedAccessUsers = new Map<Id, Boolean>();
                   
/**
 * @description Starts the batch job by querying Contacts whose Emirates ID
 *              expiry date falls in 30 days, 15 days, 1 day, or today.
 */

    global Database.QueryLocator start(Database.BatchableContext bc) {

        Date today = Date.today();
        Date d30 = today.addDays(30);
        Date d15 = today.addDays(15);
        Date d1  = today.addDays(1);

        return Database.getQueryLocator([
            SELECT Id, Name, Email, Broker_Type__c, EID_Expiry_Date__c,
                   (SELECT Id FROM Users)
            FROM Contact
            WHERE EID_Expiry_Date__c IN :new List<Date>{ d30, d15, d1, today } 
            AND Agent_Status__c = 'Active'AND id='003VH00000cYGVvYAO'
        ]);
    }
                   
/**
 * @description Processes Contacts in the current batch scope, sends reminder
 *              emails based on Emirates ID expiry timelines, and collects
 *              related User records for deactivation or limited access update
 *              when the Emirates ID expires today.
 */

    global void execute(Database.BatchableContext bc, List<Contact> scope) {

        Date today = Date.today();

        for (Contact c : scope) {

            if (c.EID_Expiry_Date__c == null) continue;

            Integer daysLeft = today.daysBetween(c.EID_Expiry_Date__c);
            system.debug('daysLeft:::'+daysLeft);
            if ((daysLeft == 30 || daysLeft == 15 || daysLeft == 1)
                && String.isNotBlank(c.Email)) {

            String subject;
            String htmlBody;
                    
                    /*Update 1.1 starts*/
                    
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
            
            if(daysLeft == 30){
            
                subject = 'Important: Emirates ID Expiry Reminder';
            
                htmlBody =
                    wrapperStart +
                    '<p style="margin:0;">Dear ' + c.Name + ',</p><br/>' +
                    '<p style="margin:0;">We would like to remind you that your Emirates ID is set to expire in 30 days.</p><br/>' +
                    '<p style="margin:0;">To avoid any interruptions to your business operations, please ensure that your information is updated before the expiry date.</p><br/>' +
                    '<p style="margin:0;">If you have already initiated the update process, please disregard this message.</p><br/>' +
                    '<p style="margin:0;">Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email ' +
                    '<a href="mailto:broker@modon.com">broker@modon.com</a>.</p>' +
                    wrapperEnd;
            
            }
            
            else if(daysLeft == 15){
            
                subject = 'Reminder: Emirates ID Expiry in 15 Days';
            
                htmlBody =
                    wrapperStart +
                    '<p style="margin:0;">Dear ' + c.Name + ',</p><br/>' +
                    '<p style="margin:0;">We would like to remind you that your Emirates ID is set to expire in 15 days.</p><br/>' +
                    '<p style="margin:0;">To avoid any interruptions to your business operations, please ensure that your information is updated before the expiry date.</p><br/>' +
                    '<p style="margin:0;">If you have already initiated the update process, please disregard this message.</p><br/>' +
                    '<p style="margin:0;">Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email ' +
                    '<a href="mailto:broker@modon.com">broker@modon.com</a>.</p>' +
                    wrapperEnd;
            
            }
            
            else if(daysLeft == 1){
            
                subject = 'Final Reminder – Emirates ID Expiry Tomorrow';
            
                htmlBody =
                    wrapperStart +
                    '<p style="margin:0;">Dear ' + c.Name + ',</p><br/>' +
                    '<p style="margin:0;">This is a final reminder that your Emirates ID is set to expire tomorrow.</p><br/>' +
                    '<p style="margin:0;">To avoid any disruption in service, please ensure your information is updated before the expiry date.</p><br/>' +
                    '<p style="margin:0;">If the required details are not updated by then, your access to the broker portal will be limited to updating your information only.</p><br/>' +
                    '<p style="margin:0;">We strongly encourage you to complete the update at your earliest convenience to maintain full access to all portal features.</p>' +
                    wrapperEnd;
            
            }
                    
                    /*Update 1.1 Ends here*/
            
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

            String personalization ='[{' + '"to":[{"email":"' + c.Email + '"}],' + ccJson + bccJson + '"subject":"' + subject + '"' + '}]';

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

            if (daysLeft == 0 && c.Users != null && !c.Users.isEmpty()) {

                for (User u : c.Users) {

                    if (c.Broker_Type__c == BRConstants.AGENT_TYPE_AGENCYADMIN || c.Broker_Type__c == BRConstants.AGENT_TYPE_OWNER ) {
                        limitedAccessUsers.put(u.Id, true);
                    }

                    else if (c.Broker_Type__c == BRConstants.AGENT_TYPE_AGENT) {
                        userIdsToDeactivate.add(u.Id);
                    }
                }
            }
        }
    }
                   
/**
 * @description Finalizes the batch job by enqueueing a queueable job to update
 *              related User records for deactivation or limited portal access.
 */

    global void finish(Database.BatchableContext bc) {

        if (!userIdsToDeactivate.isEmpty() || !limitedAccessUsers.isEmpty()) {
            System.enqueueJob(
                new MBP_UserUpdateQueueable(
                    userIdsToDeactivate,
                    limitedAccessUsers
                )
            );
        }
    }
                   
/**
 * @description Executes the batch job emirates id Expiry Batch when triggered from the Salesforce scheduler.
 */

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MBP_EmiratesIDExpiryBatch(), 100);
    }
}