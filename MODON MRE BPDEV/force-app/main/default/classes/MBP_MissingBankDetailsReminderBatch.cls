/* Version       Author                          Date            Comment                                                                      
* 1.0           sanath.manohar@activemindsit.com    19 Dec 2023      Initial Draft(Communication Record Creation,Approvalprocess,emailsending)      
1.1           raghu.chilukuri@activemindsit.com    08/03/26         Template Change
1.2           sanath.manohar@activemindsit.com    11/03/36         template change and code refinement
1.3           raghu.chilukuri@activeminds.com    10/04/26         Changed The Logic Of personalizations to add cc emails
1.4           raghu.chilukuri@activemindsit.com   16/04/26       Added Beneficiary name to the Missing bank Flow
1.5           raghu.chilukuri@activemindsit.com    21/04/26      Updated the email template for Bank details and Added Bcc and NO_DATA Logic for The cc and Bcc emails
1.6           raghu.chilukuri@activemindsit.com    06/05/26      Updated the Url of email as it is having test url so corrected it to prod url
1.7           raghu.chilukuri@activemindsit.com   07/05/26       updated the url of email using custom label      
1.8           upendra.asam@modon.com             16/06/26         I have done multiple changes in  this batch apex to handle the broker activation and de activation

**********************************************************************************************
*/

global class MBP_MissingBankDetailsReminderBatch
implements Database.Batchable<SObject>, Schedulable, Database.AllowsCallouts {
    /**
* @description Starts the batch job by querying broker agency Accounts that
*              have missing bank details such as bank country, bank name,
*              IBAN number, bank account number, or SWIFT code.
*/
    
    global Database.QueryLocator start(Database.BatchableContext bc) {    
        //update version 1.4 Added Beneficiary field to the Missing bank details Flow
        return Database.getQueryLocator([
            SELECT Id,
            Name,
            Bank_Country__c,
            Bank_Name__c,
            IBAN_Number__c,
            Bank_Account_Number__c,
            Swift_Code__c,
            Beneficiary_Name__c,
            Bank_Branch_Name__c,
            Trade_License_Status__c,
            Bank_Status__c
            FROM Account
            WHERE RecordTypeId = :BRConstants.BROKER_AGENCY_RT 
            AND (
                Bank_Country__c = null OR
                Bank_Name__c = null OR
                IBAN_Number__c = null OR
                Bank_Account_Number__c = null OR
                Swift_Code__c = null OR
                Bank_Branch_Name__c = null OR
                
                Beneficiary_Name__c = null
            )
            AND Agency_Status__c = 'Active'
        ]); 
    }
    
    /**
* @description Processes Accounts in the current batch scope, identifies
*              Agency Admin and Owner contacts associated with those accounts,
*              and sends reminder emails requesting completion of missing
*              bank details.
*/
    
    global void execute(Database.BatchableContext bc, List<Account> scope) {
        
        Set<Id> accountIds = new Set<Id>();
        for(Account a : scope){
            accountIds.add(a.Id);
        }
        Map<Id, List<Contact>> accountToRecipients = new Map<Id, List<Contact>>();
        
        for(Contact con : [
            SELECT Id, Name, Email, AccountId, Broker_Type__c
            FROM Contact
            WHERE AccountId IN :accountIds
            AND Broker_Type__c IN :new List<String>{
                BRConstants.AGENT_TYPE_AGENCYADMIN,
                    BRConstants.AGENT_TYPE_OWNER
                    }
        ]){
            if(String.isBlank(con.Email)) continue;
            
            if(!accountToRecipients.containsKey(con.AccountId)){
                accountToRecipients.put(con.AccountId,new List<Contact>());
            }
            
            accountToRecipients.get(con.AccountId).add(con);
        }
        
        for(Account acct : scope){
            /*1.8 starts */
            Boolean skipReminder =
                acct.Trade_License_Status__c == 'Submitted' ||
                acct.Bank_Status__c == 'Submitted';
            /*1.8  ends*/
            if(skipReminder){
                System.debug(
                    'Skipping Missing Bank Details Reminder for Account: ' +
                    acct.Name
                );
                continue;
            }
            
            
            List<Contact> recipients = accountToRecipients.get(acct.Id);
            
            if(recipients == null || recipients.isEmpty()) continue;
            
            for(Contact r : recipients){
                
                /*update 1.5 Starts Here
@description : slightly changed the template to include login url
*/
                
                //Update version 1.7--Updated the Url to prod with a custom label 
                
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
                
                String htmlBody =
                    wrapperStart +
                    '<p style="margin:0;">Dear ' + r.Name + ',</p><br/>' +
                    
                    '<p style="margin:0;">Our records indicate that your agency’s bank details are either incomplete or have not yet been provided. Please update the following details to avoid interruption to your business operation.</p><br/>' +
                    
                    '<p style="margin:0;"><b>Please note:</b> Bank details cannot be submitted via email. You must update them directly in the broker portal. Only the agency owner or the agency admin has the authority to update bank account details.</p><br/>' +
                    
                    '<p style="margin:0;"><b>Action Required:</b><br/>Please log into the portal and complete the update as follows:</p>' +
                    
                    '<ul style="margin:8px 0 0 18px; padding:0;">' +
                    '<li>Access: <a href="' + System.Label.Portal_url + '">Modon Broker Portal</a></li>' +
                    '<li>Go to My Agency</li>' +
                    '<li>Select Bank Details</li>' +
                    '<li>Click Update and enter the required information</li>' +
                    '</ul><br/>' +
                    
                    '<p style="margin:0;"><b>Required Details:</b></p>' +
                    '<ul style="margin:8px 0 0 18px; padding:0;">' +
                    '<li>Bank country</li>' +
                    '<li>Bank name</li>' +
                    '<li>IBAN number</li>' +
                    '<li>Bank account number</li>' +
                    '<li>SWIFT code</li>' +
                    '<li>Beneficiary Name</li>' +
                    '</ul><br/>' +
                    
                    '<p style="margin:0;">If you have already initiated the updating process, please disregard this message.</p><br/>' +
                    
                    '<p style="margin:0;">For assistance contact 800 MODON (800 66366) or email <a href="mailto:broker@modon.com">broker@modon.com</a>.</p><br/>' +
                    
                    
                    wrapperEnd;
                
                /*Update 1.5 Ends Here*/
                
                String finalEmailBody = MBP_ModonEmailUtilityClass.getFullEmailHtml(htmlBody);
                
                /*Update version 1.5
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
                
                String personalization ='[{' +'"to":[{"email":"' + r.Email + '"}],' + ccJson + bccJson + '"subject":"Missing Bank Details - Action Required"' + '}]';
                
                /*Update version 1.3
@description : added cc emails using a Custom label To the Personalizations
*/     
                BP_SendGridUtilityClass.sendEmail(
                    personalization,
                    'Al Naseem',
                    'Missing Bank Details - Action Required',
                    finalEmailBody,
                    false
                );
                /*Update 1.5 Ends Here*/
            }
        }
    }
    
    /**
* @description Executes after all batch chunks are processed. This method
*              can be used for post-processing or logging after batch completion.
*/
    
    global void finish(Database.BatchableContext bc){}
    
    /* @description Executes the Missing Bank Details reminder batch when triggered
*              from the Salesforce scheduler.
*/
    global void execute(SchedulableContext sc){
        Database.executeBatch(new MBP_MissingBankDetailsReminderBatch(),200);
    }
}