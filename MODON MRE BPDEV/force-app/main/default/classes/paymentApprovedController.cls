/**
* @description       :
* @author            : Kumaravel Mathivanan
* @group             :
* @Created modified on  : 10-20-2025
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Kumaravel Mathivanan        02-10-2025     Initial Draft
* 2.0           Manoj                       16-12-2025     Updated SOQL to add advanced search filters
*                                              (Project, Phase, Receipt Date, Transaction Date, Receipt Name)
* 3.0           Manoj                       16-12-2025     Updated SOQL to add advanced search filters
*                                              (Project, Phase, Receipt Date, Transaction Date, Receipt Name, Unit Name)
* 4.0           Manoj                       17-01-2026     Updating payment Errormessage and status methods
* 5.0           KC                          19-01-2026     Reuse bulk validations for approve+batch + batch job progress
**/
public class paymentApprovedController {

    public paymentApprovedController() { }

    // ------------------------------------------------------------------------------------
    // PICKLIST HELPERS
    // ------------------------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getProjects() {
        return [SELECT Id, Name FROM Project__c ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<Phase__c> getPhasesByProject(Id projectId) {
        return [
            SELECT Id, Name
            FROM Phase__c
            WHERE Project__c = :projectId
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Phase__c> getAllPhases() {
        return [SELECT Id, Name FROM Phase__c ORDER BY Name];
    }

    // ------------------------------------------------------------------------------------
    // GET RECEIPTS (UNCHANGED)
    // ------------------------------------------------------------------------------------
    @AuraEnabled(cacheable=false)
    public static List<ReceiptWrapper> getReceipts(
        String projectId,
        String phaseId,
        Date startDate,
        Date endDate,
        Date startDateTrans,
        Date endDateTrans,
        String receiptName,
        String unitName
    ) {
        System.debug('params : ' + projectId + ' ' + phaseId + ' ' + startDate + ' ' + endDate + ' ' + startDateTrans + ' ' + endDateTrans + ' ' + receiptName + ' ' + unitName);

        String SOstatusExcludeLst = System.Label.SO_Status_List;
        String ReceiptStatusExcludeLst = System.Label.Receipt_Status;
        String MIREExcludelst = System.Label.MIRE_Exclude_List;
        String ModeofpaymentValues = System.Label.ModeofpaymentValues;

        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('Oracle_Integration_Enabled_Date');
        Date oracleIntergrationEnableDate = Date.valueOf(oicParams.Value__c);

        List<String> SOList = new List<String>();
        for (String c : SOstatusExcludeLst.split(',')) SOList.add(c.trim());

        List<String> RcptList = new List<String>();
        for (String c1 : ReceiptStatusExcludeLst.split(',')) RcptList.add(c1.trim());

        List<String> MIREList = new List<String>();
        for (String c2 : MIREExcludelst.split(',')) {
            if (c2 != null && c2.contains('^')) {
                MIREList.add(c2.replace('^', ',').trim());
            } else {
                MIREList.add(c2.trim());
            }
        }

        List<String> ModOfPay = new List<String>();
        for (String Mod : ModeofpaymentValues.split(',')) ModOfPay.add(Mod.trim());

        System.debug('MIREList :' + MIREList);
        System.debug('RcptList : ' + RcptList);
        System.debug('SOList : ' + SOList);

        String baseQuery =
            'SELECT Id, Name, ReceiptDate__c, TransactionNumber__c, TransactionDate__c, Cheque_Number__c, ChequeDate__c,' +
            ' Milestone__c, TotalAmount__c, SalesOrder__r.Unit__r.Name, Account__r.Name,' +
            ' SalesOrderInstallment__r.MilestoneDate__c, SalesOrder__r.Unit__r.Phase__r.Project__c,' +
            ' SalesOrder__r.Unit__r.Phase__c, AppliedAmount__c, Receipt_Amount__c' +
            ' FROM Receipt__c' +
            ' WHERE Status__c IN :RcptList' +
            ' AND SalesOrder__r.Status__c NOT IN :SOList' +
            ' AND Receipt_Approved_Checker__c = false' +
            ' AND Modeofpayment__c NOT IN :ModOfPay';

        if (unitName != null) {
            baseQuery += ' AND SalesOrder__r.Unit__r.Name = :unitName';
        } else {
            if (projectId != 'ALL') {
                baseQuery += ' AND SalesOrder__r.Unit__r.Phase__r.Project__c = :projectId';
            } else {
                baseQuery += ' AND SalesOrder__r.Unit__r.Project_Name__c NOT IN :MIREList';
            }

            if (phaseId != 'ALL') {
                baseQuery += ' AND SalesOrder__r.Unit__r.Phase__c = :phaseId';
            }

            if (startDate != null) {
                if (oracleIntergrationEnableDate < startDate) {
                    baseQuery += ' AND CreatedDate >= :startDate';
                } else {
                    baseQuery += ' AND CreatedDate >= :oracleIntergrationEnableDate';
                }
            }

            if (startDate == null && receiptName == null) {
                baseQuery += ' AND CreatedDate >= :oracleIntergrationEnableDate';
            }

            if (endDate != null) {
                baseQuery += ' AND CreatedDate <= :endDate';
            }

            if (startDateTrans != null) {
                baseQuery += ' AND TransactionDate__c >= :startDateTrans';
            }

            if (endDateTrans != null) {
                baseQuery += ' AND TransactionDate__c <= :endDateTrans';
            }

            if (receiptName != null) {
                baseQuery += ' AND Name = :receiptName';
            }
        }

        baseQuery += ' ORDER BY CreatedDate DESC LIMIT 200';

        System.debug('baseQuery :' + baseQuery);

        List<Receipt__c> records = Database.query(baseQuery);
        List<ReceiptWrapper> wrappedList = new List<ReceiptWrapper>();

        Set<Id> receiptIds = new Set<Id>();
        for (Receipt__c r1 : records) receiptIds.add(r1.Id);

        Map<Id, ContentDocumentLink> fileMap = new Map<Id, ContentDocumentLink>();
        if (!receiptIds.isEmpty()) {
            List<ContentDocumentLink> links = [
                SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :receiptIds
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            for (ContentDocumentLink link : links) {
                if (!fileMap.containsKey(link.LinkedEntityId)) fileMap.put(link.LinkedEntityId, link);
            }
        }

        for (Receipt__c r : records) {
            ContentDocumentLink link = fileMap.get(r.Id);
            wrappedList.add(new ReceiptWrapper(r, link));
        }

        return wrappedList;
    }

    /**
     * [v4.0 CHANGE]
     * Purpose: Inline-edit update validation and user-friendly error surfacing for OIC/EBS integration issues.
     *  - Builds an Integration_Error_Messages__mdt map (System_Error_Msg__c -> User_Error_Msg__c) for 'EBS'.
     *  - For NON-exempt payment modes (not Credit Note / Equity Transfer / Payment Adjustment),
     *    checks integration messages in this order:
     *      1) CustomerAccount__r.OICIntegrationMessage__c
     *      2) SalesOrder__r.OICIntegrationMessage__c
     *      3) Receipt__c.OICIntegrationMessage__c
     *  - If any of the above matches a mapped system error, throws AuraHandledException with the mapped user message.
     *  - If no mapped issue, performs update on the passed receiptList.
     *
     * Notes:
     *  - This method intentionally queries only receiptList[0].Id (single-record inline edit pattern).
     *  - "isError" flag exists but the thrown exception already exits execution.
     */
    @AuraEnabled
    public static void updateReceipts(List<Receipt__c> receiptList) {
        try {
            Boolean isError = false;

            if (receiptList != null && !receiptList.isEmpty()) {
                if (receiptList[0].Id != null) {

                    Map<String, String> errorMsgMap = new Map<String, String>();
                    for (Integration_Error_Messages__mdt m : [
                        SELECT System_Error_Msg__c, User_Error_Msg__c
                        FROM Integration_Error_Messages__mdt
                        WHERE IsActive__c = true AND Application_Type__c = 'EBS'
                    ]) {
                        errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
                    }

                    for (Receipt__c receUpdateRec : [
                        SELECT Id, Status__c, Modeofpayment__c, Receipt_Amount__c, AppliedAmount__c, Name,
                               OICIntegrationMessage__c, OICIntegrationStatus__c, Oracle_Id_Temporary__c, OraclePartyId__c, SalesOrder__c,
                               SalesOrder__r.OICIntegrationMessage__c, SalesOrder__r.OracleCustAcctSiteID__c,
                               SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c,
                               SalesOrder__r.OraclePartySiteID__c, SalesOrder__r.OracleSiteUseID__c, SalesOrder__r.OraclePartyId__c,
                               SalesOrder__r.CustAcctId__c, SalesOrder__r.ProjectName__c, SalesOrder__r.Phase_Name__c
                        FROM Receipt__c
                        WHERE Id = :receiptList[0].Id
                    ]) {
                        if (receUpdateRec.Modeofpayment__c != 'Credit Note' &&
                            receUpdateRec.Modeofpayment__c != 'Equity Transfer' &&
                            receUpdateRec.Modeofpayment__c != 'Payment Adjustment') {

                            String systemError;
                            if (errorMsgMap.containsKey(receUpdateRec.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c)) {
                                systemError = receUpdateRec.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c;
                            } else if (errorMsgMap.containsKey(receUpdateRec.SalesOrder__r.OICIntegrationMessage__c)) {
                                systemError = receUpdateRec.SalesOrder__r.OICIntegrationMessage__c;
                            } else if (errorMsgMap.containsKey(receUpdateRec.OICIntegrationMessage__c)) {
                                systemError = receUpdateRec.OICIntegrationMessage__c;
                            }

                            if (systemError != null) {
                                isError = true;
                                throw new AuraHandledException(errorMsgMap.get(systemError));
                            }
                        }
                    }

                    if (!isError) update receiptList;
                }
            }
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception ex) {
            throw new AuraHandledException('An unexpected error occurred while processing the receipt. Please contact support.');
        }
    }

   
    /**
     * [v5.0 CHANGE]
     * Purpose: Single shared validation gate for receipt approval flows.
     *
     *  note:
     *  - This method is "fail-fast" by design: first invalid receipt throws and stops the operation.
     */
    private static void validateReceiptsForApproval(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return;

        Map<String, String> errorMsgMap = new Map<String, String>();
        for (Integration_Error_Messages__mdt m : [
            SELECT System_Error_Msg__c, User_Error_Msg__c
            FROM Integration_Error_Messages__mdt
            WHERE IsActive__c = true AND Application_Type__c = 'EBS'
        ]) {
            errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
        }

        Boolean isError = false;
        System.debug('errorMsgMap :' + errorMsgMap);
        for (Receipt__c r : [
            SELECT Id, Status__c, Modeofpayment__c, Receipt_Amount__c, AppliedAmount__c, Name,
                   OICIntegrationMessage__c, OICIntegrationStatus__c, Oracle_Id_Temporary__c, OraclePartyId__c, SalesOrder__c,
                   SalesOrder__r.OICIntegrationMessage__c, SalesOrder__r.OracleCustAcctSiteID__c,
                   SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c,SalesOrder__r.CustomerAccount__r.OraclePartyId__c,
                   SalesOrder__r.OraclePartySiteID__c, SalesOrder__r.OracleSiteUseID__c, SalesOrder__r.OraclePartyId__c,
                   SalesOrder__r.CustAcctId__c, SalesOrder__r.ProjectName__c, SalesOrder__r.Phase_Name__c,Is_Un_Identified_Receipts__c
            FROM Receipt__c
            WHERE Id IN :ids
        ]) {
            System.debug('r.OICIntegrationStatus__c : ' + r);
            if(r.SalesOrder__c != null){
                System.debug('Inside SalesOrder__c not null');
                // Your bulk rule: validate when status != 'S'
                if (r.OICIntegrationStatus__c != 'S') {
                    System.debug('r.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c : ' + r.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c);
                    String userErrorMsg;
                    if(r.SalesOrder__r.CustomerAccount__r.OraclePartyId__c == null && r.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c == null){
                        userErrorMsg = 'Account synchronization is incomplete. Please retry the sync process.';
                    }else if(r.SalesOrder__r.OraclePartySiteID__c == null && r.SalesOrder__r.OICIntegrationMessage__c == null){
                        userErrorMsg = 'Sales order synchronization is incomplete. Please retry the sync process.';
                    }
                    if (userErrorMsg == null) {
                        userErrorMsg = UserErrorMessage.getUserErrorMessage(
                            r.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c,
                            errorMsgMap
                        );
                    }

                    if (userErrorMsg == null) {
                        userErrorMsg = UserErrorMessage.getUserErrorMessage(
                            r.SalesOrder__r.OICIntegrationMessage__c,
                            errorMsgMap
                        );
                    }

                    if (userErrorMsg == null) {
                        userErrorMsg = UserErrorMessage.getUserErrorMessage(
                            r.OICIntegrationMessage__c,
                            errorMsgMap
                        );
                    }

                    if (userErrorMsg == null && (r.OICIntegrationMessage__c != null || r.SalesOrder__r.OICIntegrationMessage__c != null || r.SalesOrder__r.CustomerAccount__r.OICIntegrationMessage__c != null)) {
                        userErrorMsg = 'Receipt ' + r.Name +'- Required information is not updated in Salesforce. Please refresh or contact support.';
                    }
                    System.debug('userErrorMsg : ' + userErrorMsg);

                    if (userErrorMsg != null) {
                        isError = true;
                        throw new AuraHandledException(userErrorMsg);
                    }
                }
            } else if(r.Is_Un_Identified_Receipts__c == false){
                String userErrorMsg = 'Receipt ' + r.Name + ' is not linked to any Sales Order. Approval cannot proceed.';
                if (userErrorMsg != null) {
                    isError = true;
                    throw new AuraHandledException(userErrorMsg);
                }
            } else { }
        }

        if (isError) return;
    }

    /**
     * [v5.0 CHANGE]
     * Purpose: Bulk update now reuses the SAME approval validations as Approve+Batch.
     *
     * What 5.0 changed here:
     *  - Extracted prior bulk-only validations into validateReceiptsForApproval(ids).
     *  - This method now:
     *      1) Collects Ids
     *      2) Runs validateReceiptsForApproval(ids)
     *      3) Updates receiptList if validation passes
     *
     * Result:
     *  - Consistent error behavior between "Save" (bulk edit) and "Approve".
     */
    @AuraEnabled
    public static void updateReceiptsBulk(List<Receipt__c> receiptList) {
        try {
            if (receiptList == null || receiptList.isEmpty()) return;

            Set<Id> ids = new Set<Id>();
            for (Receipt__c r : receiptList) if (r.Id != null) ids.add(r.Id);
            if (ids.isEmpty()) return;

            validateReceiptsForApproval(ids);

            update receiptList;

        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception ex) {
            throw new AuraHandledException('Error updating receipts: ' + ex.getMessage());
        }
    }

    /**
     * [v5.0 CHANGE]
     * Purpose: Approve selected receipts and immediately start the OIC batch for ONLY those receipts.
     *
     * What 5.0 changed/added:
     *  - Reuses validateReceiptsForApproval(ids) to prevent approvals on invalid integration state.
     *  - Sets Receipt_Approved_Checker__c, Receipt_Approved_Date__c, Receipt_Approved_By__c for selected receipts.
     *  - Kicks off OIC_ManageReceiptBatchForApproval with batch size = 1 (per-receipt processing).
     *  - Returns AsyncApexJob Id (jobId) so UI can poll progress.
     */
    public class BatchStartResponse {
        @AuraEnabled public String jobId;
    }

    @AuraEnabled
    public static BatchStartResponse approveAndStartBatch(List<Id> receiptIds) {
        if (receiptIds == null || receiptIds.isEmpty()) {
            throw new AuraHandledException('No receipts selected.');
        }

        Set<Id> ids = new Set<Id>(receiptIds);

        // run same validations as bulk update before doing anything
        validateReceiptsForApproval(ids);

        // Approve the selected receipts
        List<Receipt__c> toUpd = new List<Receipt__c>();
        for (Id rid : ids) {
            toUpd.add(new Receipt__c(
                Id = rid,
                Receipt_Approved_Checker__c = true,
                Receipt_Approved_Date__c = System.now(),
                Receipt_Approved_By__c = UserInfo.getUserId()
            ));
        }
        update toUpd;

        // Start batch for ONLY these receipts, batch size = 1
        Id jobId = Database.executeBatch(
            new OIC_ManageReceiptBatchForApproval(ids),
            1
        );

        BatchStartResponse res = new BatchStartResponse();
        res.jobId = String.valueOf(jobId);
        return res;
    }

   
    /**
     * [v5.0 CHANGE]
     * Purpose: UI polling support to display AsyncApexJob progress for the started batch.
     *
     * What 5.0 added:
     *  - getBatchProgress(jobId): returns Status, processed, total, percent, and ExtendedStatus.
     *  - Supports LWC progress UI (spinner/progress bar + final messaging).
     */
    public class BatchProgress {
        @AuraEnabled public String status;
        @AuraEnabled public Integer processed;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer percent;
        @AuraEnabled public String extendedStatus;
    }

    @AuraEnabled(cacheable=false)
    public static BatchProgress getBatchProgress(String jobId) {
        AsyncApexJob j = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        BatchProgress p = new BatchProgress();
        p.status = j.Status;
        p.processed = (Integer)j.JobItemsProcessed;
        p.total = (Integer)j.TotalJobItems;
        p.percent = (p.total != null && p.total > 0)
            ? (Integer)Math.floor((Decimal)p.processed * 100 / p.total)
            : 0;
        p.extendedStatus = j.ExtendedStatus;
        return p;
    }

       /**
     * [v5.0 CHANGE]
     * Purpose: Post-batch failure summary for the UI (so user knows which receipts failed in OIC).
     *
     * What 5.0 added:
     *  - getOicFailures(receiptIds): returns list of ReceiptFailure for receipts with:
     *        OICIntegrationStatus__c == 'E'
     *  - Provides receipt name + message to show in UI toast/table after batch completion.
     */
    public class ReceiptFailure {
        @AuraEnabled public Id receiptId;
        @AuraEnabled public String receiptName;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=false)
    public static List<ReceiptFailure> getOicFailures(List<Id> receiptIds) {
        if (receiptIds == null || receiptIds.isEmpty()) return new List<ReceiptFailure>();

        List<Receipt__c> recs = [
            SELECT Id, Name, OICIntegrationStatus__c, OICIntegrationMessage__c
            FROM Receipt__c
            WHERE Id IN :receiptIds
        ];

        List<ReceiptFailure> out = new List<ReceiptFailure>();
        for (Receipt__c r : recs) {
            if (r.OICIntegrationStatus__c == 'E' ) {
                ReceiptFailure f = new ReceiptFailure();
                f.receiptId = r.Id;
                f.receiptName = r.Name;
                f.message = String.isBlank(r.OICIntegrationMessage__c) ? 'Unknown integration error' : r.OICIntegrationMessage__c;
                out.add(f);
            }
        }
        return out;
    }

    // ------------------------------------------------------------------------------------
    // WRAPPER
    // ------------------------------------------------------------------------------------
    public class ReceiptWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String RecptNo;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public Decimal RecptAmount;
        @AuraEnabled public Decimal AppliedAmount;
        @AuraEnabled public Date MilestoneDate;

        @AuraEnabled public Date ReceiptDate;
        @AuraEnabled public Date TransactionDate;
        @AuraEnabled public String ChequeNo;
        @AuraEnabled public Date ChequeDate;

        @AuraEnabled public String Unit;
        @AuraEnabled public String CustName;
        @AuraEnabled public Decimal MilestoneNo;
        @AuraEnabled public Id FileId;

        public ReceiptWrapper(Receipt__c r, ContentDocumentLink link) {
            this.Id = r.Id;
            this.RecptNo = r.Name;
            this.Amount = r.TotalAmount__c;
            this.RecptAmount = r.Receipt_Amount__c;
            this.AppliedAmount = r.AppliedAmount__c;
            this.MilestoneDate = (r.SalesOrderInstallment__r != null) ? r.SalesOrderInstallment__r.MilestoneDate__c : null;
            this.Unit = (r.SalesOrder__r != null) ? r.SalesOrder__r.Unit__r.Name : null;
            this.CustName = (r.Account__r != null) ? r.Account__r.Name : null;
            this.MilestoneNo = r.Milestone__c;

            this.ReceiptDate = r.ReceiptDate__c;
            this.TransactionDate = (r.TransactionDate__c != null) ? r.TransactionDate__c.date() : r.ChequeDate__c;
            this.ChequeNo = (r.TransactionNumber__c != null) ? r.TransactionNumber__c : null;
            this.ChequeDate = r.ChequeDate__c;

            if (link != null && link.ContentDocumentId != null) {
                this.FileId = link.ContentDocumentId;
            }
        }
    }
}