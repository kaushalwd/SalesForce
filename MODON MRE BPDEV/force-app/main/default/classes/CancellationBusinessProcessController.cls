/**********************************************************************************************************************
* Name               : CancellationBusinessProcessController
* Description        : Save controller for the CancellationBusinessProcess LWC — the Business_Process__c
*                       counterpart of the ServiceRequest__c "Pre/Post Unit Cancellation" screen.
* Usage              : Called by initiateBusinessProcess.js after c-cancellation-business-process
*                       dispatches its "processsubmit" event.
* Created By         : Active Minds
**********************************************************************************************************************/
public without sharing class CancellationBusinessProcessController {

    // Accepts the payload as a JSON string, deserialized here with plain JSON.deserialize,
    // rather than taking CancellationRequestWrapper directly as an @AuraEnabled parameter.
    // The LWC payload (cancellationBusinessProcess._buildPayload()) carries several fields
    // (unitId, salesOrders, modalHeader, etc.) that this wrapper does not declare — the Aura
    // remoting layer's complex-parameter binding fails the whole call when the incoming JSON
    // has properties unknown to the target Apex type, which is what was causing reqPayload to
    // arrive as null. JSON.deserialize (unlike that binding) simply ignores unknown properties.
    @AuraEnabled
    public static Id processCancellationRequest(String reqPayloadJson) {

        if (String.isBlank(reqPayloadJson)) {
            throw new AuraHandledException('Sales Order is required.');
        }

        CancellationRequestWrapper reqPayload = (CancellationRequestWrapper) JSON.deserialize(
            reqPayloadJson,
            CancellationRequestWrapper.class
        );

        if (reqPayload == null || reqPayload.salesOrderId == null) {
            throw new AuraHandledException('Sales Order is required.');
        }

        if (String.isBlank(reqPayload.cancellationType)) {
            throw new AuraHandledException('Cancellation Type is required.');
        }

        if (String.isBlank(reqPayload.cancellationReason)) {
            throw new AuraHandledException('Reason for Cancellation is required.');
        }

        if (String.isBlank(reqPayload.managementJustification)) {
            throw new AuraHandledException('Management Justification is required.');
        }

        if (String.isBlank(reqPayload.processType)) {
            throw new AuraHandledException('Process Type is required.');
        }

        List<Process_Flow__c> flows = [
            SELECT Id
            FROM Process_Flow__c
            WHERE Name = :reqPayload.processType
            LIMIT 1
        ];

        if (flows.isEmpty()) {
            throw new AuraHandledException(
                'No Process Flow configuration found for "' + reqPayload.processType + '".'
            );
        }

        // Block a second request for the same Sales Order while one of this
        // process type is already In Progress, rather than letting duplicate
        // Business Process records run side by side.
        List<Business_Process__c> existingInProgress = [
            SELECT Id
            FROM Business_Process__c
            WHERE Sales_Order__c = :reqPayload.salesOrderId
            AND Process_Flow__c = :flows[0].Id
            AND Status__c = 'In Progress'
            LIMIT 1
        ];

        if (!existingInProgress.isEmpty()) {
            throw new AuraHandledException(
                'A "' + reqPayload.processType + '" is already in progress for this Sales Order. ' +
                'Please complete or close the existing request before starting a new one.'
            );
        }

        String newBpId = CreateBusinessProcess.createPreRegistration(
            String.valueOf(reqPayload.salesOrderId),
            flows[0].Id
        );

        if (String.isBlank(newBpId)) {
            throw new AuraHandledException('Unable to create the Cancellation Business Process.');
        }

        update new Business_Process__c(
            Id = newBpId,
            Cancellation_Type__c = reqPayload.cancellationType,
            Cancellation_Reason__c = reqPayload.cancellationReason,
            // Approval_Justification__c already exists on Business_Process__c and is used the
            // same way (captured at request-creation time) by the Payment Extension flow —
            // reused here for "Management Justification" rather than adding a new field.
            Approval_Justification__c = reqPayload.managementJustification,
            ADM_Refund_Type__c = reqPayload.admRefundValue,
            ADM_Paid_Amount__c = reqPayload.admPaidAmount,
            Down_Payment_Amount__c = reqPayload.downPaymentAmount,
            Refund_Amount__c = reqPayload.totalRefundAmount
        );

        if (reqPayload.consolidationRecords != null && !reqPayload.consolidationRecords.isEmpty()) {
            insertConsolidationRecords(newBpId, reqPayload.consolidationRecords);
        }

        if (reqPayload.uploadedFiles != null && !reqPayload.uploadedFiles.isEmpty()) {
            linkUploadedFilesToSupportDocuments(newBpId, reqPayload.uploadedFiles);
        }

        // Bank details / Customer Bank Details Upload step only apply to the
        // "with refund" path.
        if (reqPayload.cancellationType == 'Cancellation with Refund') {

            if (reqPayload.bankDetailsAvailable == true) {
                saveBankDetailsToAccount(reqPayload.accountId, reqPayload);

                if (reqPayload.ibanDocument != null && String.isNotBlank(reqPayload.ibanDocument.documentId)) {
                    linkFileToBankDetailsPlaceholder(newBpId, reqPayload.ibanDocument);
                }
            }

            closeOrOpenBankDetailsUploadStep(newBpId, reqPayload.bankDetailsAvailable == true);
        }

        return newBpId;
    }

    // Saves the 7 bank fields directly on the Account (all 7 already exist on Account —
    // used the same way by OIC_ManageBankData for the SR-side refund flow).
    private static void saveBankDetailsToAccount(Id accountId, CancellationRequestWrapper reqPayload) {

        if (accountId == null) {
            return;
        }

        update new Account(
            Id = accountId,
            Bank_Name__c = reqPayload.bankName,
            Beneficiary_Name__c = reqPayload.beneficiaryName,
            Bank_Account_Number__c = reqPayload.bankAccountNumber,
            IBAN_Number__c = reqPayload.ibanNumber,
            Bank_Branch_Name__c = reqPayload.bankBranchName,
            Swift_Code__c = reqPayload.swiftCode,
            Bank_Country__c = reqPayload.bankCountry
        );
    }

    // Links the uploaded IBAN document to the "Bank Details" Business_Process_Documents__c
    // placeholder (auto-created by createPreRegistration via Process_Flow_Document__c config),
    // the same way linkUploadedFilesToSupportDocuments links to "Support Documents".
    private static void linkFileToBankDetailsPlaceholder(Id businessProcessId, UploadedFileWrapper ibanDocument) {

        List<Business_Process_Documents__c> bankDetailDocs = [
            SELECT Id
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId
            AND Name = 'Bank Details'
            LIMIT 1
        ];

        if (bankDetailDocs.isEmpty()) {
            return;
        }

        insert new ContentDocumentLink(
            ContentDocumentId = ibanDocument.documentId,
            LinkedEntityId = bankDetailDocs[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    // "Customer Bank Details Upload" is a required step whenever Cancellation_Type__c =
    // 'Cancellation with Refund'. If the requester already supplied bank details on this
    // screen, the step auto-closes (assigned to them for the audit trail). Otherwise the
    // step opens immediately (in parallel with the approval chain, rather than waiting
    // for its normal turn in sequence), assigned to the requester to complete later.
    private static void closeOrOpenBankDetailsUploadStep(Id businessProcessId, Boolean bankDetailsAvailable) {

        List<Business_Process_Step__c> steps = [
            SELECT Id
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :businessProcessId
            AND Business_Process_Steps_Name_Custom__c = 'Customer Bank Details Upload'
            LIMIT 1
        ];

        if (steps.isEmpty()) {
            return;
        }

        Id currentUserId = UserInfo.getUserId();

        update new Business_Process_Step__c(
            Id = steps[0].Id,
            Status__c = bankDetailsAvailable ? 'Completed' : 'Accepted',
            Assigned_To__c = currentUserId,
            Assigned_Time__c = System.now()
        );
    }

    // Reuses the existing Unit_Consolidation__c object (already has a Business_Process__c
    // lookup alongside its Service_Request__c one) — no schema change needed here.
    private static void insertConsolidationRecords(Id businessProcessId, List<ConsolidationRowWrapper> rows) {

        List<Unit_Consolidation__c> consolidationsToInsert = new List<Unit_Consolidation__c>();

        for (ConsolidationRowWrapper row : rows) {

            if (row.salesOrderId == null) {
                continue;
            }

            consolidationsToInsert.add(new Unit_Consolidation__c(
                Business_Process__c = businessProcessId,
                Sales_Order__c = row.salesOrderId,
                IsConsolidated__c = row.isConsolidated,
                Fund_Transfer__c = row.fundTransfer,
                Transfer_Amount__c = row.transferAmount
            ));
        }

        if (!consolidationsToInsert.isEmpty()) {
            insert consolidationsToInsert;
        }
    }

    // CreateBusinessProcess.createPreRegistration() already auto-creates the
    // Business_Process_Documents__c placeholders configured via Process_Flow_Document__c
    // for this flow (e.g. "Support Documents", "Bank Details", ...). The file(s) the user
    // uploaded on the intake screen (already linked to the Sales Order via
    // lightning-file-upload) are additionally linked here to the "Support Documents"
    // placeholder so they are also visible at the process level.
    private static void linkUploadedFilesToSupportDocuments(Id businessProcessId, List<UploadedFileWrapper> uploadedFiles) {

        List<Business_Process_Documents__c> supportDocs = [
            SELECT Id
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId
            AND Name = 'Support Documents'
            LIMIT 1
        ];

        if (supportDocs.isEmpty()) {
            return;
        }

        Id supportDocId = supportDocs[0].Id;

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

        for (UploadedFileWrapper file : uploadedFiles) {

            if (String.isBlank(file.documentId)) {
                continue;
            }

            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = file.documentId,
                LinkedEntityId = supportDocId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }

    public class CancellationRequestWrapper {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String processType;
        @AuraEnabled public String cancellationType;
        @AuraEnabled public String cancellationReason;
        @AuraEnabled public String managementJustification;
        @AuraEnabled public String admRefundValue;
        @AuraEnabled public Decimal admPaidAmount;
        @AuraEnabled public Decimal downPaymentAmount;
        @AuraEnabled public Decimal totalRefundAmount;
        @AuraEnabled public List<ConsolidationRowWrapper> consolidationRecords;
        @AuraEnabled public List<UploadedFileWrapper> uploadedFiles;

        @AuraEnabled public Boolean bankDetailsAvailable;
        @AuraEnabled public String bankName;
        @AuraEnabled public String beneficiaryName;
        @AuraEnabled public String bankAccountNumber;
        @AuraEnabled public String ibanNumber;
        @AuraEnabled public String bankBranchName;
        @AuraEnabled public String swiftCode;
        @AuraEnabled public String bankCountry;
        @AuraEnabled public UploadedFileWrapper ibanDocument;
    }

    // Field names here are camelCase (not the Unit_Consolidation__c __c-suffixed names)
    // both because Apex disallows a __c-suffixed plain identifier and because __c-suffixed
    // Object-typed values previously broke JSON.deserialize entirely ("Apex Type unsupported
    // in JSON: Object") — every property here is a concretely-typed, supported field.
    public class ConsolidationRowWrapper {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public Boolean isConsolidated;
        @AuraEnabled public Boolean fundTransfer;
        @AuraEnabled public Decimal transferAmount;
    }

    public class UploadedFileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String documentId;
        @AuraEnabled public String contentVersionId;
    }
}