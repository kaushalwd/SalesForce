/**********************************************************************************************************************
* Name               : ApprovalModalController
* Description        : Controller for the Business Process framework
* Usage              : BP Framework
* Created By         : Sivannarayana Peddireddi
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment
* 1.0           sivannaryana.p@modon.com        10-05-2026      Initial Draft
* 1.1           Sivannarayana Peddireddi        10-07-2026      Added exception handling
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes
* 3.0           sivannaryana.p@modon.com     22-07-2026     LPC Process Changes
**********************************************************************************************************************/
public without sharing class ApprovalModalController {

    /******************************************************************************************************************
* Method Name : getProcessData
* Description : Retrieves Business Process milestone dates.
******************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static Business_Process__c getProcessData(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException(
                    'Business Process record ID is required.'
                );
            }

            List<Business_Process__c> processes = [
                SELECT Id,MileStone_Confirmation_Date__c,Milestone__r.Milestone_Due_Date__c FROM Business_Process__c WHERE Id = :recordId LIMIT 1];


            if (processes.isEmpty()) {throw new AuraHandledException( 'Business Process record was not found.');}
              return processes[0];

        } catch (AuraHandledException ex) {throw ex;} catch (Exception ex) {throw buildHandledException('Unable to retrieve the Business Process details.', ex);}
    }

    /******************************************************************************************************************
* Method Name : getDocuments
* Description : Retrieves document records linked to a Business Process.
******************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Business_Process_Documents__c> getDocuments(
        Id processId
    ) {
        try {
            if (processId == null) {
                throw new AuraHandledException('Business Process ID is required to retrieve documents.');
            }

            return [SELECT Id,Name FROM Business_Process_Documents__c WHERE Business_Process__c = :processId ORDER BY CreatedDate DESC
            ];

        } catch (AuraHandledException ex) {throw ex;} catch (Exception ex) {throw buildHandledException('Unable to retrieve the Business Process documents.',ex );}
    }

    /******************************************************************************************************************
* Method Name : getFiles
* Description : Retrieves files linked to Business Process document records.
******************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFiles(
        List<Id> docIds
    ) {
        try {
            if (docIds == null || docIds.isEmpty()) {
                return new List<ContentDocumentLink>();
            }

            return [
                SELECT Id, ContentDocumentId,ContentDocument.Title,LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :docIds
            ];

        } catch (Exception ex) {throw buildHandledException('Unable to retrieve the uploaded files.',ex);
        }
    }

    /******************************************************************************************************************
* Method Name : deleteFile
* Description : Deletes a Salesforce file.
******************************************************************************************************************/
    @AuraEnabled
    public static void deleteFile(
        Id contentDocumentId
    ) {
        try {
            if (contentDocumentId == null) {throw new AuraHandledException('Content Document ID is required.' );}

            List<ContentDocument> documents = [
                SELECT Id
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];

            if (documents.isEmpty()) {throw new AuraHandledException('The selected file was not found or has already been deleted.' );}

            delete documents;

        } catch (AuraHandledException ex) {throw ex;}  catch (Exception ex) {throw buildHandledException('Unable to delete the selected file.',ex);}
    }

    /******************************************************************************************************************
* Method Name : updateBusinessProcess
* Description : Updates the milestone confirmation or extension date.
******************************************************************************************************************/
    @AuraEnabled
    public static void updateBusinessProcess(
        Id recordId,
        String selectedOption,
        Date confirmationDate,
        Date extensionDate
    ) {
        try {
            if (recordId == null) { throw new AuraHandledException('Business Process record ID is required.');
            }

            if (String.isBlank(selectedOption)) { throw new AuraHandledException('Please select Confirmation or Extension.');}

            String normalizedOption =selectedOption.trim().toUpperCase();

            if (normalizedOption != 'CONFIRMATION' && normalizedOption != 'EXTENSION') {
                throw new AuraHandledException( 'Invalid selection. Please select Confirmation or Extension.' );
            }

            if (normalizedOption == 'CONFIRMATION' && confirmationDate == null) {
                throw new AuraHandledException( 'Milestone confirmation date is required.');
            }

            if (normalizedOption == 'EXTENSION' && extensionDate == null) {
                throw new AuraHandledException('Milestone extension date is required.');
            }

            List<Business_Process__c> processes = [
                SELECT Id,
                MileStone_Confirmation_Date__c,
                MileStone_Extension_Date__c
                FROM Business_Process__c
                WHERE Id = :recordId
                LIMIT 1
                FOR UPDATE
            ];

            if (processes.isEmpty()) {
                throw new AuraHandledException('Business Process record was not found.');
            }

            Business_Process__c businessProcess = processes[0];

            if (normalizedOption == 'CONFIRMATION') {
                businessProcess.MileStone_Confirmation_Date__c =confirmationDate;

                businessProcess.MileStone_Extension_Date__c = null;
            } else {
                businessProcess.MileStone_Extension_Date__c = extensionDate;

                businessProcess.MileStone_Confirmation_Date__c = null;
            }

            update businessProcess;

        } catch (AuraHandledException ex) {throw ex; } catch (Exception ex) {throw buildHandledException('Unable to update the Business Process.', ex);}}

    /******************************************************************************************************************
* Method Name : getApprovalTypes
* Description : Retrieves Business Process types from Custom Metadata.
******************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Approval_Type_Config__mdt> getApprovalTypes() {
        try {
            return [
                SELECT MasterLabel,
                Category__c,
                Sub_Categories__c
                FROM Approval_Type_Config__mdt
                ORDER BY MasterLabel
            ];

        } catch (Exception ex) { throw buildHandledException( 'Unable to retrieve the approval types.',ex);}
    }

    /******************************************************************************************************************
* Method Name : getInstallments
* Description : Retrieves installments based on Sales Order or Case.
******************************************************************************************************************/
   @AuraEnabled(cacheable=true)
public static List<SalesOrderInstallments__c> getInstallments(
    Id recordId
) {
    try {
        if (recordId == null) {
            throw new AuraHandledException(
                'Record ID is required to retrieve installments.'
            );
        }

        String objectName =
            recordId.getSObjectType().getDescribe().getName();

        if (objectName == 'SalesOrder__c') {
            return [SELECT Id, Name, SalesOrder__c, SalesOrder__r.Name, Milestone__c, MilestoneNumber__c, MilestoneDate__c, ExtensionDate__c, PaymentStatus__c, InstallmentAmount__c,MilestoneDescription__c FROM SalesOrderInstallments__c
                WHERE SalesOrder__c = :recordId AND (PaymentStatus__c = NULL OR PaymentStatus__c != 'Paid') ORDER BY  MilestoneNumber__c ASC, MilestoneDate__c ASC ];
        }

        if (objectName == 'Case') {
            Case caseRecord = [SELECT Id, Latest_Sales_Order__c FROM Case
                WHERE Id = :recordId LIMIT 1];

            if (caseRecord.Latest_Sales_Order__c == null) {
                throw new AuraHandledException('No Sales Order is associated with this Case.');
            }

            return [SELECT Id, Name, SalesOrder__c, SalesOrder__r.Name, Milestone__c, MilestoneNumber__c, MilestoneDate__c, ExtensionDate__c, PaymentStatus__c, InstallmentAmount__c,MilestoneDescription__c FROM SalesOrderInstallments__c
                WHERE SalesOrder__c = :caseRecord.Latest_Sales_Order__c AND (PaymentStatus__c = NULL OR PaymentStatus__c != 'Paid') ORDER BY  MilestoneNumber__c ASC, MilestoneDate__c ASC ];
        }

        throw new AuraHandledException('Installments cannot be retrieved for the ' +objectName +' object.');
    } catch (AuraHandledException ex) {throw ex;
    } catch (Exception ex) { throw buildHandledException( 'Unable to retrieve the Sales Order installments.', ex);
    }
}

    /******************************************************************************************************************
* Method Name : createBusinessProcess
* Description : Creates a Business Process based on the selected process name.
******************************************************************************************************************/
    @AuraEnabled
    public static void createBusinessProcess(
        Id recId,
        String processName
    ) {
        try {
            System.debug( LoggingLevel.INFO,'createBusinessProcess inputs: ' +recId + ' - ' + processName);

            if (recId == null) {throw new AuraHandledException('Sales Order record ID is required.');
            }

            if (String.isBlank(processName)) {throw new AuraHandledException('Please select a Business Process.');
            }

            processName = processName.trim();

            String sourceObjectName =recId.getSObjectType().getDescribe().getName();

            Id salesOrderId;
            Id caseId;

            if (sourceObjectName == 'SalesOrder__c') {

                salesOrderId = recId;

            } else if (sourceObjectName == 'Case') {

                List<Case> caseRecords = [
                    SELECT Id,
                    CaseCategory__c,
                    Latest_Sales_Order__c
                    FROM Case
                    WHERE Id = :recId
                    LIMIT 1
                ];

                if (caseRecords.isEmpty()) {
                    throw new AuraHandledException('Case record was not found.');
                }

                Case caseRecord = caseRecords[0];

                if (caseRecord.Latest_Sales_Order__c == null) {
                    throw new AuraHandledException('No Sales Order is associated with this Case.');
                }

                if (String.isBlank(caseRecord.CaseCategory__c)) {
                    throw new AuraHandledException('This Case does not have a Category selected.');
                }

                List<Business_Process_Case_Management_Mapping__mdt> mappings = [
                    SELECT Id,
                    Business_Process_Name__c
                    FROM Business_Process_Case_Management_Mapping__mdt
                    WHERE Case_Category__c = :caseRecord.CaseCategory__c
                    LIMIT 1
                ];

                if (mappings.isEmpty()) {
                    throw new AuraHandledException('Business Process cannot be initiated for the "' + caseRecord.CaseCategory__c + '" case category.');
                }

                salesOrderId = caseRecord.Latest_Sales_Order__c;
                caseId = caseRecord.Id;

            } else {
                throw new AuraHandledException('The Business Process can only be initiated from a Sales Order or a Case.' );
            }

            List<Business_Process__c> existingProcesses = [
                SELECT Id,
                Name,
                Status__c,
                Type__c
                FROM Business_Process__c
                WHERE Sales_Order__c = :salesOrderId
                AND Type__c = :processName
                AND Status__c = 'In Progress'
                LIMIT 1
            ];

            if (!existingProcesses.isEmpty()) {
                throw new AuraHandledException( processName + ' process is already in progress for this Sales Order.' );
            }

            List<Process_Flow__c> processFlows = [
                SELECT Id,
                Name
                FROM Process_Flow__c
                WHERE Name = :processName
                LIMIT 1
            ];

            if (processFlows.isEmpty()) {throw new AuraHandledException('Process Flow configuration was not found for "' + processName + '".');
            }

            Id newBusinessProcessId = CreateBusinessProcess.createPreRegistration(String.valueOf(salesOrderId),processFlows[0].Id);

            /*
             * Link the Business Process back to the originating Case
             * (and vice versa) for tracking, when initiated from a Case.
             */
            if (caseId != null && newBusinessProcessId != null) {

                update new Business_Process__c(
                    Id = newBusinessProcessId,
                    Case__c = caseId
                );

                update new Case(
                    Id = caseId,
                    Business_Process__c = newBusinessProcessId
                );
            }

        } catch (AuraHandledException ex) {throw ex;} catch (Exception ex) { throw buildHandledException('Unable to initiate the ' +(String.isBlank(processName) ? '': processName + ' ') +'Business Process.', ex);}}

    /******************************************************************************************************************
* Method Name : processInstallments
* Description : Creates the Payment Extension Business Process.
******************************************************************************************************************/
    // Members must be {get; set;} properties: the LWC -> Apex parameter binding
    // does not populate plain public fields, which left documentId null.
    public class UploadedFileWrapper {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String documentId { get; set; }
        @AuraEnabled public String contentVersionId { get; set; }
    }

    @AuraEnabled
public static String processInstallments(
    Id installmentId,
    Date extensionDate,
    String typeOfRequest,
    String paymentExtensionReason,
    String approvalJustification,
    List<UploadedFileWrapper> uploadedFiles
) {
    try {
        if (installmentId == null) {throw new AuraHandledException('Installment ID is required to initiate Payment Extension.');}

        if (extensionDate == null) {throw new AuraHandledException( 'Extension Date is required.');}

        if (String.isBlank(typeOfRequest)) {throw new AuraHandledException('Type of Request is required.');}

        if (String.isBlank(paymentExtensionReason)) {throw new AuraHandledException('Payment Extension Reason is required.');}

        if (installmentId.getSObjectType() != SalesOrderInstallments__c.SObjectType) {throw new AuraHandledException('The selected record is not a Sales Order Installment.' );}

        SalesOrderInstallments__c selectedInstallment = [
            SELECT Id, Name,SalesOrder__c, SalesOrder__r.Unit__c,SalesOrder__r.Unit__r.Phase__c,SalesOrder__r.CustomerAccount__c,SalesOrder__r.Unit__r.Phase__r.Project__c,
                SalesOrder__r.PrimaryContact__c,MilestoneNumber__c, MilestoneDate__c, ExtensionDate__c,PaymentStatus__c
            FROM SalesOrderInstallments__c WHERE Id = :installmentId LIMIT 1 FOR UPDATE ];
        if (String.isNotBlank( selectedInstallment.PaymentStatus__c) && selectedInstallment.PaymentStatus__c.equalsIgnoreCase( 'Paid' )) {
            throw new AuraHandledException('Payment Extension cannot be initiated for a paid installment.');}

        if (selectedInstallment.MilestoneDate__c == null) {throw new AuraHandledException('Milestone Date is not available for the selected installment.');}

        if (extensionDate <=selectedInstallment.MilestoneDate__c) {
            throw new AuraHandledException('Extension Date must be later than the selected installment Milestone Date.');
        }

        List<SalesOrderInstallments__c> nextInstallments;

        if (
            selectedInstallment.MilestoneNumber__c != null
        ) {
            nextInstallments = [SELECT Id, Name,MilestoneNumber__c,MilestoneDate__c FROM SalesOrderInstallments__c WHERE SalesOrder__c =:selectedInstallment.SalesOrder__c AND Id != :selectedInstallment.Id AND MilestoneDate__c != NULL
                    AND MilestoneNumber__c > :selectedInstallment.MilestoneNumber__c ORDER BY MilestoneNumber__c ASC, MilestoneDate__c ASC LIMIT 1 ];
        } else {
            nextInstallments = [ SELECT Id, Name, MilestoneNumber__c, MilestoneDate__c FROM SalesOrderInstallments__c WHERE SalesOrder__c =:selectedInstallment.SalesOrder__c AND Id != :selectedInstallment.Id AND MilestoneDate__c > :selectedInstallment.MilestoneDate__c ORDER BY MilestoneDate__c ASC LIMIT 1
            ];
        }

        if (
            !nextInstallments.isEmpty() && extensionDate >= nextInstallments[0].MilestoneDate__c
        ) {
            throw new AuraHandledException('Extension Date must be earlier than the next installment date of ' +String.valueOf( nextInstallments[0].MilestoneDate__c ) + '.' );}

        List<Business_Process__c> existingProcesses = [
            SELECT Id,Status__c,Type__c FROM Business_Process__c WHERE Sales_Order__c =:selectedInstallment.SalesOrder__c AND Type__c = 'Payment Extension'  AND Status__c = 'In Progress'  LIMIT 1
        ];

        if (!existingProcesses.isEmpty()) {throw new AuraHandledException( 'Payment Extension process is already in progress for this Sales Order.' );
        }

        Process_Flow__c paymentExtensionFlow = [ SELECT Id,Name  FROM Process_Flow__c WHERE Name = 'Payment Extension' LIMIT 1];

        CreateBusinessProcess.createPreRegistration(
            String.valueOf(installmentId),
            paymentExtensionFlow.Id
        );

        /*
         * createPreRegistration is expected to create the
         * Business Process synchronously.
         */
        List<Business_Process__c> createdProcesses = [SELECT Id, MileStone_Extension_Date__c, Milestone__c FROM Business_Process__c WHERE Sales_Order__c = :selectedInstallment.SalesOrder__c AND Type__c = 'Payment Extension' AND Status__c = 'In Progress' ORDER BY CreatedDate DESC LIMIT 1 ];

        if (createdProcesses.isEmpty()) {throw new AuraHandledException( 'Payment Extension process could not be created.' ); }

        Business_Process__c createdProcess = createdProcesses[0];

       // createdProcess.Milestone__c =selectedInstallment.Id;

        createdProcess.Original_Milestone_Date__c = selectedInstallment.MilestoneDate__c;
        createdProcess.Payment_Extension_Date__c =extensionDate;
        createdProcess.Type_of_Request__c = typeOfRequest;
        createdProcess.Payment_Extension_Reason__c = paymentExtensionReason;
        createdProcess.Approval_Justification__c = approvalJustification;

        update createdProcess;

        return linkUploadedFilesToProofOfRequest(createdProcess.Id, uploadedFiles);

    } catch (AuraHandledException ex) {
        throw ex;
    } catch (QueryException ex) {
        throw buildHandledException('Required Payment Extension configuration or installment information was not found.',ex );
    } catch (DmlException ex) {
        String msg = getDmlErrorMessage('Unable to save the Payment Extension request.', ex);
        AuraHandledException aex = new AuraHandledException(msg);
        aex.setMessage(msg);
        throw aex;
    } catch (Exception ex) {
        throw buildHandledException(
            'Unable to initiate the Payment Extension process.',
            ex
        );
    }
}

    // Links the file(s) uploaded on the installment selector screen (already attached to the
    // Sales Order / Case via lightning-file-upload) to the "Proof of Request"
    // Business_Process_Documents__c placeholder auto-created by createPreRegistration via
    // Process_Flow_Document__c config, the same pattern
    // CancellationBusinessProcessController.linkUploadedFilesToSupportDocuments uses.
    // Returns a non-fatal warning message when the file(s) could not be attached, so the
    // caller can surface it instead of the attachment silently failing.
    @TestVisible
    private static String linkUploadedFilesToProofOfRequest(Id businessProcessId, List<UploadedFileWrapper> uploadedFiles) {

        if (uploadedFiles == null || uploadedFiles.isEmpty()) {
            return null;
        }

        List<Business_Process_Documents__c> proofOfRequestDocs = [
            SELECT Id
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId
            AND Name = 'Proof of Request'
            LIMIT 1
        ];

        if (proofOfRequestDocs.isEmpty()) {
            return 'The Payment Extension request was created, but no "Proof of Request" checklist item is configured for this process, so the uploaded file(s) could not be attached to it.';
        }

        Id proofOfRequestDocId = proofOfRequestDocs[0].Id;

        // The upload widget should always return a documentId, but fall back to
        // resolving it from the ContentVersion Id in case it doesn't come through.
        Set<String> contentVersionIdsToResolve = new Set<String>();
        for (UploadedFileWrapper file : uploadedFiles) {
            if (String.isBlank(file.documentId) && String.isNotBlank(file.contentVersionId)) {
                contentVersionIdsToResolve.add(file.contentVersionId);
            }
        }

        Map<String, String> contentVersionToDocumentId = new Map<String, String>();
        if (!contentVersionIdsToResolve.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :contentVersionIdsToResolve
            ]) {
                contentVersionToDocumentId.put(cv.Id, cv.ContentDocumentId);
            }
        }

        Set<String> documentIdsToLink = new Set<String>();

        for (UploadedFileWrapper file : uploadedFiles) {
            String contentDocumentId = String.isNotBlank(file.documentId)
                ? file.documentId
                : contentVersionToDocumentId.get(file.contentVersionId);

            if (String.isNotBlank(contentDocumentId)) {
                documentIdsToLink.add(contentDocumentId);
            }
        }

        if (documentIdsToLink.isEmpty()) {
            return 'The Payment Extension request was created, but the uploaded file(s) could not be identified and were not attached to the "Proof of Request" record. Please attach them manually.';
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (String contentDocumentId : documentIdsToLink) {
            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = proofOfRequestDocId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        insert linksToInsert;
        return null;
    }
    /******************************************************************************************************************
* Method Name : buildHandledException
* Description : Creates a user-friendly AuraHandledException.
******************************************************************************************************************/
    public static AuraHandledException buildHandledException(String userMessage,Exception ex ) {
        System.debug(LoggingLevel.ERROR,userMessage +' Exception Type: ' + ex.getTypeName() +
            ', Line: ' +ex.getLineNumber() +', Message: ' + ex.getMessage() +', Stack Trace: ' + ex.getStackTraceString()
        );

        String finalMessage = userMessage;

        if (!Test.isRunningTest() && String.isNotBlank(ex.getMessage())) {
            finalMessage += ' ' + ex.getMessage();
        }

        return new AuraHandledException(finalMessage);
    }

    /******************************************************************************************************************
* Method Name : getDmlErrorMessage
* Description : Extracts Salesforce DML error messages.
******************************************************************************************************************/
    public static String getDmlErrorMessage(String defaultMessage,DmlException ex) {
        System.debug(
            LoggingLevel.ERROR,
            defaultMessage +
            ' DML Exception: ' +
            ex.getMessage() +
            ', Stack Trace: ' +
            ex.getStackTraceString()
        );

        List<String> errorMessages = new List<String>();

        for ( Integer index = 0; index < ex.getNumDml(); index++) {
            String dmlMessage = ex.getDmlMessage(index);

            if (String.isNotBlank(dmlMessage)) {
                errorMessages.add(dmlMessage);
            }
        }

        if (errorMessages.isEmpty()) {return defaultMessage;}

        return defaultMessage +
            ' ' +
            String.join(errorMessages, ' ');
    }
}