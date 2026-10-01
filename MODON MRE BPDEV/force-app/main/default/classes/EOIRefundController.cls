/**********************************************************************************************************************
 * Name               : EOIRefundController
 * Description        : Apex controller for the EOI Refund Process Lightning Web Component (eoiRefund).
 *                      Handles fetching eligible Projects, EOIs with nested Eligible/UnEligible Receipts,
 *                      and submits refund requests by creating 1 Business Process (EOI Refund Approval)
 *                      tagged with all selected EOIs. Once approved (CCO Approval), EOIRefundAutomater
 *                      triggers Case creation (1 Case per EOI).
 * Usage              : Used by Lightning Web Component (eoiRefund)
 * Created By         : pprajapati@horizontal.com
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           pprajapati@horizontal.com           02 Sept 2026    Initial Draft for EOI Refund LWC
 * 2.0           pprajapati@horizontal.com           03 Sept 2026    Partition receipts into Eligible (Status = Cleared) and UnEligible,
 *                                                                   support multi-EOI submission creating 1 Case per EOI
 * 2.1           pprajapati@horizontal.com           04 Sept 2026    Require Management MEMO document upload and link to batch
 * 3.0           pprajapati@horizontal.com           08 Sept 2026    Transition flow to create 1 Business Process (EOI Refund Approval)
 *                                                                   for all selected EOIs, tag EOIs, and link Management MEMO.
 *                                                                   Cases will be generated upon CCO Approval via EOIRefundAutomater.
 * 3.1           pprajapati@horizontal.com           08 Sept 2026    Make Management MEMO document upload optional
 **********************************************************************************************************************/
public without sharing class EOIRefundController {

    private static final String UNIDENTIFIED_ACCOUNT_NAME = 'Unidentified Account (MRE Finance)';
    private static final Set<String> VOID_CANCEL_STATUSES = new Set<String>{'Voided', 'Cancelled'};

    /**
     * @description Fetches all Projects that have EOIs with eligible Receipts.
     * Eligible criteria:
     * - EOI exists on Project, Case__c is null, and Business_Process__c is null/inactive
     * - Receipt Case__c is null
     * - Receipt Status__c = 'Cleared'
     * - Receipt Account is 'Unidentified Account (MRE Finance)' OR (Receipt Sales Order is not null and Status is Voided or Cancelled)
     * @return List<OptionWrapper> List of Project options (label = Name, value = Id)
     */
    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getEligibleProjects() {
        try {
            Set<Id> activeBpIds = new Map<Id, Business_Process__c>([
                SELECT Id FROM Business_Process__c 
                WHERE Status__c NOT IN ('Rejected', 'Cancelled')
                LIMIT 50000
            ]).keySet();

            Set<Id> activeBpEoiIds = new Set<Id>();
            if (!activeBpIds.isEmpty()) {
                for (Expressionofinterest__c e : [
                    SELECT Id FROM Expressionofinterest__c
                    WHERE Business_Process__c != null
                    AND Business_Process__c IN :activeBpIds
                    LIMIT 50000
                ]) {
                    activeBpEoiIds.add(e.Id);
                }
            }

            Set<Id> eoiIdsWithEligibleReceipts = new Set<Id>();
            for (Receipt__c rec : [
                SELECT ExpressionOfInterest__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c != null
                AND Case__c = null
                AND Status__c = 'Cleared'
                AND (
                    Account__r.Name = :UNIDENTIFIED_ACCOUNT_NAME
                    OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN :VOID_CANCEL_STATUSES)
                )
                LIMIT 5000
            ]) {
                if (!activeBpEoiIds.contains(rec.ExpressionOfInterest__c)) {
                    eoiIdsWithEligibleReceipts.add(rec.ExpressionOfInterest__c);
                }
            }

            Set<Id> projectIds = new Set<Id>();
            if (!eoiIdsWithEligibleReceipts.isEmpty()) {
                for (Expressionofinterest__c eoi : [
                    SELECT Id, Project__c
                    FROM Expressionofinterest__c
                    WHERE Id IN :eoiIdsWithEligibleReceipts
                    AND Project__c != null
                    AND Case__c = null
                    LIMIT 5000
                ]) {
                    projectIds.add(eoi.Project__c);
                }
            }

            List<OptionWrapper> options = new List<OptionWrapper>();
            if (!projectIds.isEmpty()) {
                for (Project__c p : [
                    SELECT Id, Name
                    FROM Project__c
                    WHERE Id IN :projectIds
                    ORDER BY Name ASC
                ]) {
                    options.add(new OptionWrapper(p.Name, p.Id));
                }
            }
            return options;
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException('Error fetching eligible projects: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            ahe.setMessage('Error fetching eligible projects: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            throw ahe;
        }
    }

    /**
     * @description Fetches all eligible EOIs under a selected Project with all their receipts partitioned
     *              into Eligible and UnEligible.
     * @param projectId - The Id of the selected Project__c
     * @return List<EOIWrapper> List of EOI wrappers with nested receipts
     */
    @AuraEnabled(cacheable=true)
    public static List<EOIWrapper> getEligibleEOIs(Id projectId) {
        if (projectId == null) {
            return new List<EOIWrapper>();
        }

        try {
            Set<Id> activeBpIds = new Map<Id, Business_Process__c>([
                SELECT Id FROM Business_Process__c 
                WHERE Status__c NOT IN ('Rejected', 'Cancelled')
                LIMIT 50000
            ]).keySet();

            Set<Id> activeBpEoiIds = new Set<Id>();
            if (!activeBpIds.isEmpty()) {
                for (Expressionofinterest__c e : [
                    SELECT Id FROM Expressionofinterest__c
                    WHERE Business_Process__c != null
                    AND Business_Process__c IN :activeBpIds
                    LIMIT 50000
                ]) {
                    activeBpEoiIds.add(e.Id);
                }
            }

            // 1. Fetch EOIs directly under this project
            Map<Id, Expressionofinterest__c> projectEoiMap = new Map<Id, Expressionofinterest__c>([
                SELECT Id,
                       Name,
                       Opportunity__c,
                       Opportunity__r.Name,
                       Case__c,
                       Account__c,
                       Account__r.Name,
                       Project__c,
                       Project__r.Name,
                       Status__c
                FROM Expressionofinterest__c
                WHERE Project__c = :projectId
                AND Case__c = null
                LIMIT 5000
            ]);

            if (projectEoiMap.isEmpty()) {
                return new List<EOIWrapper>();
            }

            // Filter out EOIs already in active Business Process
            for (Id activeEoiId : activeBpEoiIds) {
                projectEoiMap.remove(activeEoiId);
            }

            if (projectEoiMap.isEmpty()) {
                return new List<EOIWrapper>();
            }

            // 2. Identify which of these EOIs have at least one qualifying eligible receipt
            Set<Id> eoiIdsWithEligibleReceipts = new Set<Id>();
            for (Receipt__c rec : [
                SELECT ExpressionOfInterest__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c IN :projectEoiMap.keySet()
                AND Case__c = null
                AND Status__c = 'Cleared'
                AND (
                    Account__r.Name = :UNIDENTIFIED_ACCOUNT_NAME
                    OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN :VOID_CANCEL_STATUSES)
                )
                LIMIT 5000
            ]) {
                eoiIdsWithEligibleReceipts.add(rec.ExpressionOfInterest__c);
            }

            if (eoiIdsWithEligibleReceipts.isEmpty()) {
                return new List<EOIWrapper>();
            }

            // Filter projectEoiMap to only those with eligible receipts
            List<Expressionofinterest__c> eoiRecords = new List<Expressionofinterest__c>();
            for (Id eoiId : projectEoiMap.keySet()) {
                if (eoiIdsWithEligibleReceipts.contains(eoiId)) {
                    eoiRecords.add(projectEoiMap.get(eoiId));
                }
            }

            // Retrieve all receipts under these eligible EOIs
            Map<Id, List<Receipt__c>> eoiToAllReceipts = new Map<Id, List<Receipt__c>>();
            for (Receipt__c rec : [
                SELECT Id,
                       Name,
                       TotalAmount__c,
                       Status__c,
                       SalesOrder__c,
                       SalesOrder__r.Name,
                       SalesOrder__r.Status__c,
                       Account__c,
                       Account__r.Name,
                       CurrencyIsoCode,
                       ExpressionOfInterest__c,
                       Case__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c IN :eoiIdsWithEligibleReceipts
                ORDER BY Name ASC
            ]) {
                if (!eoiToAllReceipts.containsKey(rec.ExpressionOfInterest__c)) {
                    eoiToAllReceipts.put(rec.ExpressionOfInterest__c, new List<Receipt__c>());
                }
                eoiToAllReceipts.get(rec.ExpressionOfInterest__c).add(rec);
            }

            List<EOIWrapper> result = new List<EOIWrapper>();
            for (Expressionofinterest__c eoi : [
                SELECT Id,
                       Name,
                       Opportunity__c,
                       Opportunity__r.Name,
                       Account__c,
                       Account__r.Name,
                       Project__c,
                       Project__r.Name,
                       Status__c
                FROM Expressionofinterest__c
                WHERE Id IN :eoiIdsWithEligibleReceipts
                ORDER BY Name ASC
            ]) {
                EOIWrapper wrapper = new EOIWrapper(eoi);
                List<Receipt__c> receipts = eoiToAllReceipts.get(eoi.Id);
                if (receipts != null) {
                    for (Receipt__c rec : receipts) {
                        // Version 2.0 [pprajapati@horizontal.com - 03 Sept 2026]: Partition into Eligible vs UnEligible
                        Boolean isCleared = (rec.Status__c == 'Cleared');
                        Boolean isNoCase = (rec.Case__c == null);
                        Boolean isMatchingCondition = (
                            (rec.Account__r != null && rec.Account__r.Name == UNIDENTIFIED_ACCOUNT_NAME)
                            || (rec.SalesOrder__c != null && VOID_CANCEL_STATUSES.contains(rec.SalesOrder__r.Status__c))
                        );

                        ReceiptWrapper rw = new ReceiptWrapper(rec);
                        if (isCleared && isNoCase && isMatchingCondition) {
                            rw.isEligible = true;
                            wrapper.eligibleReceipts.add(rw);
                            wrapper.totalEligibleAmount += rw.totalAmount;
                        } else {
                            rw.isEligible = false;
                            if (rec.Case__c != null) {
                                rw.ineligibilityReason = 'Already Refunded (Case Linked)';
                            } else if (!isCleared) {
                                rw.ineligibilityReason = 'Status is ' + (rec.Status__c != null ? rec.Status__c : 'Blank') + ' (Must be Cleared)';
                            } else {
                                rw.ineligibilityReason = 'Sales Order Active / Account Mismatch';
                            }
                            wrapper.uneligibleReceipts.add(rw);
                        }
                    }
                }
                wrapper.eligibleCount = wrapper.eligibleReceipts.size();
                wrapper.uneligibleCount = wrapper.uneligibleReceipts.size();
                result.add(wrapper);
            }
            return result;
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException('Error fetching eligible EOIs: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            ahe.setMessage('Error fetching eligible EOIs: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            throw ahe;
        }
    }

    /**
     * @description Fetches all eligible Receipts for a selected EOI.
     * @param eoiId - The Id of the selected Expressionofinterest__c
     * @return List<ReceiptWrapper> List of eligible Receipt records
     */
    @AuraEnabled(cacheable=true)
    public static List<ReceiptWrapper> getEligibleReceipts(Id eoiId) {
        if (eoiId == null) {
            return new List<ReceiptWrapper>();
        }

        try {
            List<ReceiptWrapper> result = new List<ReceiptWrapper>();
            for (Receipt__c rec : [
                SELECT Id,
                       Name,
                       TotalAmount__c,
                       Status__c,
                       SalesOrder__c,
                       SalesOrder__r.Name,
                       SalesOrder__r.Status__c,
                       Account__c,
                       Account__r.Name,
                       CurrencyIsoCode
                FROM Receipt__c
                WHERE ExpressionOfInterest__c = :eoiId
                AND Case__c = null
                AND Status__c = 'Cleared'
                AND (
                    Account__r.Name = :UNIDENTIFIED_ACCOUNT_NAME
                    OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN :VOID_CANCEL_STATUSES)
                )
                ORDER BY Name ASC
            ]) {
                ReceiptWrapper rw = new ReceiptWrapper(rec);
                rw.isEligible = true;
                result.add(rw);
            }
            return result;
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException('Error fetching receipts: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            ahe.setMessage('Error fetching receipts: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            throw ahe;
        }
    }

    /**
     * @description Submits a refund request for multiple EOIs by creating a single Business Process
     *              (Type: EOI Refund Approval) with all selected EOIs tagged to it.
     *              Links the uploaded Management MEMO document to the Business Process.
     *              Cases will be generated upon final Business Process approval via EOIRefundAutomater.
     * @param eoiIds - List of selected Expressionofinterest__c Ids
     * @param selectedReceiptIds - List of selected Receipt__c record Ids (legacy/compatibility)
     * @param contentDocumentId - (Optional) Id of the uploaded Management MEMO document
     * @return RefundResult Response message and status
     */
    @AuraEnabled
    public static RefundResult submitRefundRequest(List<Id> eoiIds, List<Id> selectedReceiptIds, Id contentDocumentId) {
        // Version 3.0 [pprajapati@horizontal.com - 08 Sept 2026]: Create 1 Business Process for all selected EOIs instead of directly creating Cases
        if (eoiIds == null || eoiIds.isEmpty()) {
            throw new AuraHandledException('At least one EOI must be selected.');
        }

        try {
            // Version 3.1 [pprajapati@horizontal.com - 08 Sept 2026]: Management MEMO is optional; verify only if provided
            if (contentDocumentId != null) {
                List<ContentDocument> docs = [
                    SELECT Id, Title
                    FROM ContentDocument
                    WHERE Id = :contentDocumentId
                    LIMIT 1
                ];
                if (docs.isEmpty()) {
                    throw new AuraHandledException('Uploaded Management MEMO document could not be found.');
                }
            }

            // Verify selected EOIs are not already linked to a Case or an active Business Process
            List<Expressionofinterest__c> checkEois = [
                SELECT Id, Name, Case__c, Business_Process__c
                FROM Expressionofinterest__c
                WHERE Id IN :eoiIds
            ];
            Set<Id> existingBpIds = new Set<Id>();
            for (Expressionofinterest__c e : checkEois) {
                if (e.Case__c != null) {
                    throw new AuraHandledException('One or more selected EOIs are already linked to an active Business Process or Case.');
                }
                if (e.Business_Process__c != null) {
                    existingBpIds.add(e.Business_Process__c);
                }
            }
            if (!existingBpIds.isEmpty()) {
                List<Business_Process__c> activeBps = [
                    SELECT Id, Name
                    FROM Business_Process__c
                    WHERE Id IN :existingBpIds
                    AND Status__c NOT IN ('Rejected', 'Cancelled')
                ];
                if (!activeBps.isEmpty()) {
                    throw new AuraHandledException('One or more selected EOIs are already linked to an active Business Process or Case.');
                }
            }

            // Find Process Flow configuration for EOI Refund Approval
            List<Process_Flow__c> processFlows = [
                SELECT Id, Name
                FROM Process_Flow__c
                WHERE Name = 'EOI Refund Approval'
                LIMIT 1
            ];
            if (processFlows.isEmpty()) {
                throw new AuraHandledException('Configuration error: Process Flow "EOI Refund Approval" was not found.');
            }

            // Query Project Id from first EOI
            Expressionofinterest__c firstEoi = [
                SELECT Id, Project__c
                FROM Expressionofinterest__c
                WHERE Id = :eoiIds[0]
                LIMIT 1
            ];
            Id projectId = firstEoi.Project__c;

            // Create Business Process & Steps via standard framework method
            String bpIdStr = CreateBusinessProcess.createPreRegistration(String.valueOf(eoiIds[0]), processFlows[0].Id);
            if (String.isBlank(bpIdStr) || bpIdStr.startsWith('Invalid')) {
                throw new AuraHandledException('Failed to initiate Business Process: ' + bpIdStr);
            }
            Id bpId = (Id) bpIdStr;

            // Set Project on Business Process if available
            if (projectId != null) {
                Database.update(new Business_Process__c(Id = bpId, Project__c = projectId), AccessLevel.SYSTEM_MODE);
            }

            // Tag all selected EOIs to this single Business Process
            List<Expressionofinterest__c> eoisToUpdate = new List<Expressionofinterest__c>();
            for (Id eoiId : eoiIds) {
                eoisToUpdate.add(new Expressionofinterest__c(
                    Id = eoiId,
                    Business_Process__c = bpId
                ));
            }
            Database.update(eoisToUpdate, AccessLevel.SYSTEM_MODE);

            // Version 3.1 [pprajapati@horizontal.com - 08 Sept 2026]: Link Management MEMO to the Business Process if provided
            if (contentDocumentId != null) {
                Database.insert(new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = bpId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ), AccessLevel.SYSTEM_MODE);
            }

            Business_Process__c bpRecord = [SELECT Id, Name FROM Business_Process__c WHERE Id = :bpId LIMIT 1];

            RefundResult response = new RefundResult();
            response.isSuccess = true;
            response.message = 'Business Process ' + bpRecord.Name + ' initiated successfully for ' + eoiIds.size() + ' EOI(s). Refund cases will be created upon approval.';
            response.casesCount = eoiIds.size();
            response.businessProcessId = bpRecord.Id;
            response.businessProcessName = bpRecord.Name;
            return response;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException('Failed to initiate Business Process: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            ahe.setMessage('Failed to initiate Business Process: ' + ex.getMessage() + ' [Line ' + ex.getLineNumber() + ']');
            throw ahe;
        }
    }

    /* -----------------------------------------------------------------------------------------
     * DTO / Wrapper Classes
     * ----------------------------------------------------------------------------------------- */

    public class OptionWrapper {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public OptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class EOIWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String eoiNumber { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer eligibleCount { get; set; }
        @AuraEnabled public Integer uneligibleCount { get; set; }
        @AuraEnabled public Decimal totalEligibleAmount { get; set; }
        @AuraEnabled public List<ReceiptWrapper> eligibleReceipts { get; set; }
        @AuraEnabled public List<ReceiptWrapper> uneligibleReceipts { get; set; }

        public EOIWrapper(Expressionofinterest__c eoi) {
            this.id = eoi.Id;
            this.eoiNumber = eoi.Name;
            this.opportunityName = eoi.Opportunity__r != null ? eoi.Opportunity__r.Name : '-';
            this.accountName = eoi.Account__r != null ? eoi.Account__r.Name : '-';
            this.projectName = eoi.Project__r != null ? eoi.Project__r.Name : '-';
            this.status = eoi.Status__c;
            this.eligibleCount = 0;
            this.uneligibleCount = 0;
            this.totalEligibleAmount = 0;
            this.eligibleReceipts = new List<ReceiptWrapper>();
            this.uneligibleReceipts = new List<ReceiptWrapper>();
        }
    }

    public class ReceiptWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String receiptNumber { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String salesOrderNumber { get; set; }
        @AuraEnabled public String salesOrderStatus { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String currencyIsoCode { get; set; }
        @AuraEnabled public Boolean isEligible { get; set; }
        @AuraEnabled public String ineligibilityReason { get; set; }

        public ReceiptWrapper(Receipt__c rec) {
            this.id = rec.Id;
            this.receiptNumber = rec.Name;
            this.totalAmount = rec.TotalAmount__c != null ? rec.TotalAmount__c : 0;
            this.status = rec.Status__c;
            this.salesOrderNumber = rec.SalesOrder__r != null ? rec.SalesOrder__r.Name : '-';
            this.salesOrderStatus = rec.SalesOrder__r != null ? rec.SalesOrder__r.Status__c : '-';
            this.accountName = rec.Account__r != null ? rec.Account__r.Name : '-';
            this.currencyIsoCode = rec.CurrencyIsoCode;
            this.isEligible = false;
            this.ineligibilityReason = '';
        }
    }

    public class RefundResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String batchJobId { get; set; }
        @AuraEnabled public Integer casesCount { get; set; }
        @AuraEnabled public Id businessProcessId { get; set; }
        @AuraEnabled public String businessProcessName { get; set; }
    }
}