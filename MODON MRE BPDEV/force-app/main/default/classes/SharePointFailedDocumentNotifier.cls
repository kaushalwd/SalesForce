/**********************************************************************************************************************
* Name               : SharePointFailedDocumentNotifier                                                       
* Description        : Scheduled Apex class to send email notifications for failed SharePoint document sync records.
* Usage              : Runs on schedule and emails failed Documents__c records to System Administrators.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Chandu Battu               23 May 2026     Initial Draft    
******************************************************************************************************************/

public class SharePointFailedDocumentNotifier 
implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        
        sendFailedDocumentEmail();
    }
    
    public static void sendFailedDocumentEmail() {
        
        /* ================= GET FAILED RECORDS ================= */
        
        List<Documents__c> failedDocs = [
            SELECT Id,
            Name,
            SharePoint_Status__c,
            SharePoint_Error__c,
            SharePoint_Last_Sync__c
            FROM Documents__c
            WHERE SharePoint_Status__c = 'Failed'
            AND LastModifiedDate = TODAY
            ORDER BY LastModifiedDate DESC
        ];
        
        /* ================= SEND ONLY IF RECORDS EXIST ================= */
        
        if (failedDocs.isEmpty()) {
            System.debug(
                'No failed SharePoint records found.'
            );
            return;
        }
        
        /* ================= BUILD EMAIL BODY ================= */
        
        String body = '';
        
        body += 'Hello Team,<br/><br/>';
        
        body += 'Below are the failed SharePoint sync records.<br/><br/>';
        
        body += '<table border="1" cellpadding="5" cellspacing="0">';
        
        body += '<tr>';
        body += '<th>Document Id</th>';
        body += '<th>Document Name</th>';
        body += '<th>Status</th>';
        body += '<th>Error</th>';
        body += '<th>Last Sync</th>';
        body += '</tr>';
        
        for (Documents__c doc : failedDocs) {
            
            body += '<tr>';
            
            body += '<td>' + doc.Id + '</td>';
            
            body += '<td>' + doc.Name + '</td>';
            
            body += '<td>' + doc.SharePoint_Status__c + '</td>';
            
            body += '<td>' +
                (doc.SharePoint_Error__c != null
                 ? doc.SharePoint_Error__c
                 : '') +
                '</td>';
            
            body += '<td>' +
                (doc.SharePoint_Last_Sync__c != null
                 ? String.valueOf(doc.SharePoint_Last_Sync__c)
                 : '') +
                '</td>';
            
            body += '</tr>';
        }
        
        body += '</table><br/><br/>';
        
        body += 'Regards,<br/>';
        body += 'Salesforce System';
        
        /* ================= GET SYS ADMIN EMAILS ================= */
        
        List<String> adminEmails = new List<String>();
        
        for(User usr : [
            SELECT Email
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'System Administrator'
            AND Email != null
        ]) {
            adminEmails.add(usr.Email);
        }
        
        /* ================= SEND EMAIL ================= */
        
        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();
        
        mail.setToAddresses(adminEmails);
        
        mail.setSubject(
            'Failed SharePoint Sync Records'
        );
        
        mail.setHtmlBody(body);
        
        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { mail }
        );
        
        System.debug(
            'Failure email sent successfully.'
        );
    }
}