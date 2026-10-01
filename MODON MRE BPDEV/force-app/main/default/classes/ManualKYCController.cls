/**********************************************************************************************************************
* Name               : ManualKYCController
* Description        : Handles the backend logic for Manual KYC submission, file renaming, and approval requests.
*                      Object-agnostic: works for any SObject registered in APPROVAL_PROCESS_BY_SOBJECT,
*                      provided that object carries KYC_Manual_Reason__c, Manual_KYC_Comment__c and
*                      Manual_KYC_Approval__c with the same API names.
* Usage              : Called from LWC (submitManualKyc) and Record-Triggered Flows
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date                  Comment
* 1.0           Rushi Patel                 27 Aug 2026           Initial draft
* 1.1           Rushi Patel                 21 September 2026     Generalised from Account-only to Account + Contact
******************************************************************************************************************/
public with sharing class ManualKYCController {

    /**
     * Maps each supported SObject to the approval process submitted for it.
     * To light this feature up on a new object, add an entry here plus the three custom fields,
     * the field updates, the approval process, the renamer flow and the quick action.
     */
    private static final Map<SObjectType, String> APPROVAL_PROCESS_BY_SOBJECT = new Map<SObjectType, String>{
        Account.SObjectType => 'Submit_for_Manual_KYC',
        Contact.SObjectType => 'Submit_for_Manual_KYC_Contact'
    };

    /**
     * Retrieves all available Manual KYC files for this record.
     * This excludes files that have already been submitted, approved, or rejected.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableKYCFiles(Id recordId) {
        // Find ANY file that starts with our Manual KYC naming convention, regardless of the date
        String searchPattern = '%Manual KYC - %';

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.Title LIKE :searchPattern
        ];

        List<Map<String, String>> result = new List<Map<String, String>>();
        for (ContentDocumentLink link : links) {
            String title = link.ContentDocument.Title;

            // Only show abandoned/unsubmitted files. Skip anything already submitted, approved, or rejected.
            if (!title.contains('For Approval') && !title.contains('- Approved') && !title.contains('- Rejected')) {
                Map<String, String> fileData = new Map<String, String>();

                // Append the extension for better UI clarity
                String ext = link.ContentDocument.FileExtension;
                String displayTitle = title + (String.isNotBlank(ext) ? '.' + ext : '');

                fileData.put('label', displayTitle);
                fileData.put('value', String.valueOf(link.ContentDocumentId));
                result.add(fileData);
            }
        }
        return result;
    }

    /**
     * Renames a newly uploaded file to include the Manual KYC convention.
     */
    @AuraEnabled
    public static Map<String, String> renameUploadedFile(Id documentId) {
        ContentDocument doc = [SELECT Id, Title, FileExtension FROM ContentDocument WHERE Id = :documentId LIMIT 1];

        // Include hours, minutes, and seconds to guarantee uniqueness
        String dateAndTime = DateTime.now().format('dd-MM-yyyy HH:mm:ss');

        String targetTitle = 'Manual KYC - ' + dateAndTime;

        // Discard original name and replace completely
        if (doc.Title != targetTitle) {
            doc.Title = targetTitle;
            update doc;
        }

        Map<String, String> fileData = new Map<String, String>();

        // Return title with extension for the UI
        String ext = doc.FileExtension;
        String displayTitle = doc.Title + (String.isNotBlank(ext) ? '.' + ext : '');

        fileData.put('label', displayTitle);
        fileData.put('value', String.valueOf(doc.Id));
        return fileData;
    }

    /**
     * Final submission: Updates the record, renames the specific file used for approval, and submits the process.
     * Resolves the object type from the record Id, so the same method serves Account and Contact.
     */
    @AuraEnabled
    public static void submitForApproval(Id recordId, String kycReason, String kycComment, Id documentId) {
        try {
            SObjectType targetType = recordId.getSObjectType();
            String processName = APPROVAL_PROCESS_BY_SOBJECT.get(targetType);

            if (String.isBlank(processName)) {
                throw new AuraHandledException('Manual KYC is not configured for ' + targetType);
            }

            // 1. Update the record with the reason and comment
            SObject recToUpdate = targetType.newSObject(recordId);
            recToUpdate.put('KYC_Manual_Reason__c', kycReason);
            recToUpdate.put('Manual_KYC_Comment__c', kycComment);
            update recToUpdate;

            // 2. Append "- For Approval" to the selected file so the approver knows which one to look at
            if (documentId != null) {
                ContentDocument doc = [SELECT Id, Title FROM ContentDocument WHERE Id = :documentId LIMIT 1];
                if (!doc.Title.contains('For Approval')) {
                    doc.Title = doc.Title + ' - For Approval';
                    update doc;
                }
            }

            // 3. Create an approval request against the process registered for this object
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments('Submitting for Manual KYC');
            req.setObjectId(recordId);
            req.setProcessDefinitionNameOrId(processName);
            req.setSkipEntryCriteria(false);

            // Submit the approval request
            if (!Test.isRunningTest()) {
                Approval.ProcessResult result = Approval.process(req);

                if (!result.isSuccess()) {
                    throw new AuraHandledException('Failed to submit for approval: ' + result.getErrors()[0].getMessage());
                }
            }
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Called from a Record-Triggered Flow when the Approval Process completes.
     * Renames the attached file from "- For Approval" to "- Approved" or "- Rejected".
     * The ContentDocumentLink query keys on LinkedEntityId, so one invocable serves every
     * object this feature is enabled on.
     */
    @InvocableMethod(label='Update KYC Document Name' description='Replaces "For Approval" with Approved or Rejected on the attached KYC file.')
    public static void updateDocumentNameOnApproval(List<KYCApprovalRequest> requests) {
        Map<Id, String> recordToStatus = new Map<Id, String>();
        for (KYCApprovalRequest req : requests) {
            if (req.recordId != null && req.status != null) {
                recordToStatus.put(req.recordId, req.status);
            }
        }

        if (recordToStatus.isEmpty()) return;

        // Find files linked to these records containing "For Approval"
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordToStatus.keySet()
            AND ContentDocument.Title LIKE '%For Approval%'
        ];

        Map<Id, ContentDocument> docsToUpdate = new Map<Id, ContentDocument>();

        for (ContentDocumentLink link : links) {
            String status = recordToStatus.get(link.LinkedEntityId);
            String title = link.ContentDocument.Title;

            if (title.contains('For Approval')) {
                title = title.replace('For Approval', status);
                docsToUpdate.put(link.ContentDocumentId, new ContentDocument(
                    Id = link.ContentDocumentId,
                    Title = title
                ));
            }
        }

        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate.values();
        }
    }

    public class KYCApprovalRequest {
        @InvocableVariable(required=true label='Record ID')
        public Id recordId;

        @InvocableVariable(required=true label='New Status (e.g. Approved, Rejected)')
        public String status;
    }
}