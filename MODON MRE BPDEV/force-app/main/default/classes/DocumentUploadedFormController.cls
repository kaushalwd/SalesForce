/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public without sharing class DocumentUploadedFormController {
    
    public class DocumentWrapper {
        @AuraEnabled public Business_Process_Documents__c documentRecord { get; set; }
        @AuraEnabled public Boolean hasFile { get; set; }
        @AuraEnabled public Integer fileCount { get; set; }
    }
        
    public class PersonWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String DisplayName { get; set; }
        @AuraEnabled public String Type { get; set; }
        @AuraEnabled public String SaveButtonLabel { get; set; }
        @AuraEnabled public String SubtypeOfApplicant { get; set; }
        @AuraEnabled public String TypeOfApplicant { get; set; }
        @AuraEnabled public List<DocumentRequirement> requiredDocuments { get; set; }
    }
    
    public class DocumentRequirement {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String screen { get; set; }
        @AuraEnabled public Boolean required { get; set; }
    }
           
    public class FileWrapper {
        @AuraEnabled public String base64Data { get; set; }
        @AuraEnabled public String documentLabel { get; set; }
        @AuraEnabled public String fileName { get; set; } 
    }

    @AuraEnabled(cacheable=true)
    public static List<Business_Process_Documents__c> getBusinessProcessDocuments(Id bussinessProcessId) {
        try {
            System.debug('=== Fetching Business Process Documents for BP: ' + bussinessProcessId + ' ===');
            
            if (bussinessProcessId == null) {
                throw new AuraHandledException('Business Process ID cannot be null');
            }
            
            List<Business_Process_Documents__c> bpDocs = [
                SELECT Id, Name, Business_Process__c, Available_to_Customer__c
                FROM Business_Process_Documents__c
                WHERE Business_Process__c = :bussinessProcessId
                ORDER BY CreatedDate DESC
            ];
            
            System.debug('=== Returning ' + bpDocs.size() + ' BP Documents ===');
            return bpDocs;
            
        } catch (Exception e) {
            System.debug('Error fetching BP Documents: ' + e.getMessage());
            throw new AuraHandledException('Error fetching BP Documents: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Business_Process_Documents__c createBussinessProcessDocument(Id bussinessProcessId, String docName) {
        Business_Process_Documents__c doc = new Business_Process_Documents__c(
            Name = docName,
            Business_Process__c = bussinessProcessId,
            Available_to_Customer__c = true
        );
        insert doc;
        return doc;
    }

    @AuraEnabled
    public static void updateBussinessProcessDocumentss(List<Id> docIds, Id bussinessProcessId,Boolean skipOutstanding) {
        if (docIds == null || docIds.isEmpty()) {
            throw new AuraHandledException('No documents selected');
        }
        
        if (bussinessProcessId == null) {
            throw new AuraHandledException('Business Process ID is required');
        }
        
        try {
            System.debug('=== START updateBussinessProcessDocumentss ===');
            System.debug('Document IDs received: ' + docIds);
            System.debug('Business Process ID: ' + bussinessProcessId);
            
            List<Business_Process_Documents__c> docs = [
                SELECT Id, Name, Available_to_Customer__c
                FROM Business_Process_Documents__c 
                WHERE Id IN :docIds
            ];
            
            System.debug('Documents found: ' + docs.size());
            
            if (docs.isEmpty()) {
                throw new AuraHandledException('No valid documents found');
            }
            
            for (Business_Process_Documents__c d : docs) {
                d.Available_to_Customer__c = true;
                System.debug('Marking document as available: ' + d.Name);
            }
            update docs;
            
            System.debug('Successfully updated ' + docs.size() + ' documents');
            
            sendBusinessProcessNotificationToUploadDocuments(bussinessProcessId, docIds,skipOutstanding);
            
            System.debug('=== END updateBussinessProcessDocumentss ===');
            
        } catch (Exception e) {
            System.debug('ERROR in updateBussinessProcessDocumentss: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to update documents: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteBusinessProcessDocument(Id docId) {
        try {
            delete [SELECT Id FROM Business_Process_Documents__c WHERE Id = :docId];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to delete document: ' + e.getMessage());
        }
    }
   
    @AuraEnabled(cacheable=true)
    public static Business_Process__c getBusinessProcessHeader(Id bussinessProcessId) {
        if (bussinessProcessId == null) {
            throw new AuraHandledException('Business Process ID is required');
        }
    
        return [
            SELECT Id
                  /* Outstanding_Skipped__c,
                   Booking__r.Outstanding_Amount__c*/
            FROM Business_Process__c
            WHERE Id = :bussinessProcessId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static void sendBusinessProcessNotificationToUploadDocuments(Id businessProcessId, List<Id> selectedDocIds,Boolean skipOutstanding) {
      /*
        try {
            System.debug('=== START sendBusinessProcessNotificationToUploadDocuments ===');
            System.debug('Business Process ID: ' + businessProcessId);
            System.debug('Selected document IDs: ' + selectedDocIds);
            
            
            List<Business_Process_Documents__c> selectedDocuments = [
                SELECT Id, Name
                FROM Business_Process_Documents__c
                WHERE Id IN :selectedDocIds
                ORDER BY Name
            ];
            
            System.debug('Selected documents count: ' + selectedDocuments.size());

            
            Business_Process__c bpUpdate = new Business_Process__c(
                Id = businessProcessId,
                Document_Upload_Status__c = 'Email Initiated'
            );
            update bpUpdate;
            System.debug('Updated BP status to: Email Initiated');
            
            Business_Process__c bp = [
                SELECT Id, Name, Booking__c,
                Booking__r.Name,
                Booking__r.Primary_Applicant_Email__c,
                Booking__r.Unit__r.Name,
                Booking__r.Outstanding_Amount__c,
                Outstanding_Skipped__c
                FROM Business_Process__c
                WHERE Id = :businessProcessId
                LIMIT 1
            ];

            bp.Document_Upload_Status__c = 'Email Initiated';

if (skipOutstanding == true &&
    bp.Booking__r.Outstanding_Amount__c != null &&
    bp.Booking__r.Outstanding_Amount__c > 0) {

    bp.Outstanding_Skipped__c = true;
}

update bp;

            
            
            String applicantEmail = bp.Booking__r.Primary_Applicant_Email__c;
            System.debug('Primary Applicant Email: ' + applicantEmail);
            
            if (String.isBlank(applicantEmail)) {
                throw new AuraHandledException('Primary Applicant Email is missing in the Booking record.');
            }
            
            List<String> ccEmails = new List<String>();
            if (bp.Booking__c != null) {
                List<Applicant_Details__c> applicants = [
                    SELECT Email_Address__c
                    FROM Applicant_Details__c
                    WHERE Booking__c = :bp.Booking__c
                    AND Email_Address__c != null
                    AND Email_Address__c != :applicantEmail  
                ];
                
                for (Applicant_Details__c app : applicants) {
                    ccEmails.add(app.Email_Address__c);
                }
            }
            
            System.debug('CC Emails: ' + ccEmails);
            
            List<OrgWideEmailAddress> oweaList = [
                SELECT Id, Address, DisplayName 
                FROM OrgWideEmailAddress 
                WHERE DisplayName = 'Sobha Realty Helpdesk' 
                LIMIT 1
            ];
            
            if (oweaList.isEmpty()) {
                System.debug('WARNING: Org-Wide Email Address "Sobha Realty Helpdesk" not found');
            } else {
                System.debug('Found Org-Wide Email: ' + oweaList[0].Address);
            }
            
            Id orgWideEmailId = oweaList.isEmpty() ? null : oweaList[0].Id;
            
            
            String docIdsParam = String.join(selectedDocIds, ',');
            
            
            String communityUrl = 'https://orgfarm-043118be66-dev-ed.develop.my.site.com/BpDocumentUpload?recordId=' 
                + businessProcessId + '&docIds=' + EncodingUtil.urlEncode(docIdsParam, 'UTF-8');
            
            System.debug('Community URL: ' + communityUrl);
            
            
            String emailBody = getHtmlBodyWithSelectedDocuments(communityUrl, selectedDocuments, bp);
            System.debug('Email body prepared');
            
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { applicantEmail });
            
            
            if (!ccEmails.isEmpty()) {
                mail.setCcAddresses(ccEmails);
            }
            
            mail.setSubject('Business Process ' + bp.Name + ' – Document Submission Required');
            mail.setHtmlBody(emailBody);
            
            if (orgWideEmailId != null) {
                mail.setOrgWideEmailAddressId(orgWideEmailId);
            }
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            
            
            if (results[0].isSuccess()) {
                System.debug('SUCCESS: Email sent to: ' + applicantEmail + ' with CC: ' + ccEmails);
            } else {
                String errorMsg = 'Email send failed: ';
                for (Messaging.SendEmailError error : results[0].getErrors()) {
                    errorMsg += error.getMessage() + '; ';
                    System.debug('Email Error Code: ' + error.getStatusCode());
                    System.debug('Email Error Fields: ' + error.getFields());
                }
                System.debug('EMAIL FAILURE: ' + errorMsg);
                throw new AuraHandledException(errorMsg);
            }
            
            System.debug('=== END sendBusinessProcessNotificationToUploadDocuments ===');
            
        } catch (Exception e) {
            System.debug('EXCEPTION in sendBusinessProcessNotificationToUploadDocuments');
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
        */
    }

    public static String getHtmlBodyWithSelectedDocuments(
        
        String link,
        List<Business_Process_Documents__c> selectedDocuments,
        Business_Process__c bp
    ) {
        /*
String outstandingNotice = '';
if (bp.Booking__r != null &&
    bp.Booking__r.Outstanding_Amount__c != null &&
    bp.Booking__r.Outstanding_Amount__c > 0) {
        
    String outstandingAmount =
    String.valueOf(bp.Booking__r.Outstanding_Amount__c.setScale(2));

   outstandingNotice =
    '<p style="margin-top:15px; color:#c23934; font-weight:600;">' +
    'Please note that there is an outstanding amount of <strong>' +
    outstandingAmount +
    ' AED</strong>. You are requested to clear the same prior to issuance of NOC.' +
    '</p>';
}


        String documentList = '';
        
        if (selectedDocuments != null && !selectedDocuments.isEmpty()) {
            documentList = '<p><strong>Required Documents:</strong></p>'
                + '<ul style="margin-left: 20px; margin-top: 10px;">';
            for (Business_Process_Documents__c doc : selectedDocuments) {
                documentList += '<li style="margin-bottom: 5px;">' + doc.Name + '</li>';
            }
            documentList += '</ul>';
        }
        
        
        String unitName = (bp.Booking__r != null && bp.Booking__r.Unit__r != null)
            ? bp.Booking__r.Unit__r.Name
            : 'your assigned unit';
        
        return
            '<html><body style="font-family: Tahoma, Arial, sans-serif; font-size: 14px; line-height: 1.6;">' +
            '<p>Dear Customer,</p>' +
            '<p>With reference to your unit <strong>' + unitName + '</strong>, we kindly request you to upload the required documents using the link provided below:</p>' +
            outstandingNotice + 
            documentList +
            '<p style="margin-top: 15px;">' +
            '<a href="' + link + '" style="color: #bfa14a; text-decoration: none; font-weight: bold;">Click here to upload your documents</a>' +
            '</p>' +
            '<p style="margin-top: 20px;">Thank you for your cooperation.<br/>' +
            'Regards,<br/>' +
            '<span style="color:#bfa14a; font-weight:600;">Sobha Community Team</span></p>' +
            '</body></html>';
            */
            return '';
    }
 



}