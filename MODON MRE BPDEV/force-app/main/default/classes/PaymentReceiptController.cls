/**
/**********************************************************************************************************************
* Name               : PaymentReceiptController
* Description        : This class is used to create the Payment using  LWC
* Created By         : Arvind
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0          Arvind                            18 May 2026     Create Payment from LWC
* 2.0          Arvind                            21 May 2026     Allow_Duplicate_Payment_for_EOI custom permission
*                                                                bypasses duplicate block; approval only fires once
* 2.1          Arvind                            22 May 2026     Signed EOI Form document check temporarily disabled
* 2.2          Arvind                            22 May 2026     Set Payment_Created_w_o_Signed_EOI_form__c = true
*                                                                on EOI when payment is created without a signed form
 */
public with sharing class PaymentReceiptController {

    // ─────────────────────────────────────────────────────────────────────
    // TESTABLE ACCOUNT OVERRIDE
    // In tests:  PaymentReceiptController.unidentifiedAccountId = myAccId;
    // ─────────────────────────────────────────────────────────────────────
    @TestVisible
    private static Id unidentifiedAccountId {
        get {
            if (unidentifiedAccountId == null) {
                unidentifiedAccountId = (Id) System.Label.Unidentified_Account1;
            }
            return unidentifiedAccountId;
        }
        set;
    }

    // ─────────────────────────────────────────────────────────────────────
    // 1.  GET EOI DETAILS
    // ─────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static EOIWrapper getEOIDetails(Id eoiId) {
        try {
            List<Expressionofinterest__c> eoiList = [
                SELECT Id,
                       Name,
                       EOIId__c,
                       Opportunity__r.Name,
                       EOI_Amount_AED__c,
                       Preferred_Payment__c,
                       Payment_Type__c
                FROM   Expressionofinterest__c
                WHERE  Id = :eoiId
                LIMIT  1
            ];

            if (eoiList.isEmpty()) {
                throw new AuraHandledException('Expression of Interest record not found.');
            }

            Expressionofinterest__c eoi = eoiList[0];
            EOIWrapper wrap      = new EOIWrapper();
            wrap.eoiName                    = String.isNotBlank(eoi.EOIId__c) ? eoi.EOIId__c : eoi.Name;
            wrap.opportunityName            = eoi.Opportunity__r != null ? eoi.Opportunity__r.Name : '';
            wrap.amount                     = eoi.EOI_Amount_AED__c;
            wrap.preferredPayment           = eoi.Payment_Type__c;
            wrap.hasAllowDuplicatePermission = FeatureManagement.checkPermission('Allow_Duplicate_Payment_for_EOI');
            return wrap;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading EOI details: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // 2.  VALIDATE BEFORE PAYMENT
    //     Bank__c picklist is now read by LWC @wire(getPicklistValues)
    //     directly from the Receipt__c schema — no Apex method needed.
    //     a) Signed EOI Form check — TEMPORARILY DISABLED (v2.1)
    //     b) No duplicate Receipt already exists for this EOI
    //        (v2.0) skipped for users with Allow_Duplicate_Payment_for_EOI
    // ─────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static ValidationResult validateBeforePayment(Id eoiId) {
        ValidationResult res = new ValidationResult();

        // --- a) Signed documents ---
        // v2.1 Arvind — temporarily disabled per business request.
        // Payment creation is allowed regardless of Signed EOI Form status.
        // Restore by uncommenting the block below when required.
        /*
        List<String> notUploaded = new List<String>();
        for (Documents__c doc : [
            SELECT Id, Name, Status__c
            FROM   Documents__c
            WHERE  Expressionofinterest__c = :eoiId
            AND    Name IN ('Signed EOI Form')
        ]) {
            if (doc.Status__c != 'Uploaded') {
                notUploaded.add(doc.Name);
            }
        }

        if (!notUploaded.isEmpty()) {
            res.isValid   = false;
            res.errorType = 'DOCS_MISSING';
            res.message   = 'Please upload the required signed documents before creating a payment: '
                          + String.join(notUploaded, ', ');
            return res;
        }
        */

        // --- b) Duplicate check ---
        // v2.0 Arvind — users with Allow_Duplicate_Payment_for_EOI custom permission
        // are allowed to create additional payments on the same EOI.
        Boolean allowDuplicate = FeatureManagement.checkPermission('Allow_Duplicate_Payment_for_EOI');

        if (!allowDuplicate) {
            List<Receipt__c> existing = [
                SELECT Id, Name
                FROM   Receipt__c
                WHERE  ExpressionOfInterest__c = :eoiId
                LIMIT  1
            ];

            if (!existing.isEmpty()) {
                res.isValid   = false;
                res.errorType = 'DUPLICATE';
                res.message   = 'A payment / receipt (' + existing[0].Name + ') already exists '
                              + 'for this Expression of Interest. Duplicate payments are not allowed.';
                return res;
            }
        }

        res.isValid = true;
        return res;
    }

    // ─────────────────────────────────────────────────────────────────────
    // 4.  CREATE PAYMENT  +  LINK DOCUMENTS  +  SUBMIT EOI APPROVAL
    // ─────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static SaveResult createPaymentAndSubmit(
            String   paymentJSON,
            List<Id> contentDocumentIds) {

        SaveResult  saveResult = new SaveResult();
        Savepoint   sp         = Database.setSavepoint();

        try {
            PaymentWrapper wrap = (PaymentWrapper)
                JSON.deserializeStrict(paymentJSON, PaymentWrapper.class);

            // v2.0 Arvind — check custom permission + detect first payment.
            // isFirstPayment captured BEFORE insert to drive two things:
            //   1. Block users without the bypass permission
            //   2. Send approval only on the very first payment (not again for splits)
            Boolean allowDuplicate = FeatureManagement.checkPermission('Allow_Duplicate_Payment_for_EOI');
            Boolean isFirstPayment = [
                SELECT Id FROM Receipt__c
                WHERE  ExpressionOfInterest__c = :wrap.eoiId
                LIMIT  1
            ].isEmpty();

            if (!allowDuplicate && !isFirstPayment) {
                saveResult.isSuccess = false;
                saveResult.errorType = 'DUPLICATE';
                saveResult.message   = 'A payment already exists for this EOI.';
                return saveResult;
            }

            // ── Query EOI for Phase / Project / EntityName ────────────
            // These 3 fields need to be copied to the Receipt.
            // Phase__r.EntityName__c uses the parent relationship so we
            // avoid a second SOQL query for the Phase record.
            Expressionofinterest__c eoiData = [
                SELECT Phase__c,
                       Phase__r.EntityName__c,
                       Project__c
                FROM   Expressionofinterest__c
                WHERE  Id = :wrap.eoiId
                LIMIT  1
            ];
            // ──────────────────────────────────────────────────────────

            // ── Build Receipt record ──────────────────────────────────
            Receipt__c r              = new Receipt__c();
            r.Account__c              = unidentifiedAccountId;        // Finance fixed account (Custom Label)
            r.ExpressionOfInterest__c = wrap.eoiId;
            r.Modeofpayment__c        = wrap.modeOfPayment;
            r.TotalAmount__c          = wrap.amount;
            r.Receipt_Amount__c       = wrap.amount;
            r.Status__c               = 'In Progress';
            r.ReceiptDate__c          = wrap.transactionDate != null
                                        ? wrap.transactionDate
                                        : Date.today();
            r.TransactionDate__c      = wrap.transactionDate;

            // EOI.Phase__c   → Receipt.Phase__c
            r.Phase__c                     = eoiData.Phase__c;
            // EOI.Project__c → Receipt.Project__c
            r.Project__c                   = eoiData.Project__c;
            // Always true for LWC payment
            r.Is_Un_Identified_Receipts__c = true;
            // EntityName__c from Phase record (3-level null check)
            if (eoiData.Phase__c != null
                    && eoiData.Phase__r != null
                    && eoiData.Phase__r.EntityName__c != null) {
                r.EntityName__c = eoiData.Phase__r.EntityName__c;
            }

            switch on wrap.modeOfPayment {
                when 'Cheque' {
                    r.ChequeDate__c        = wrap.chequeDate;
                    r.TransactionNumber__c = wrap.chequeNumber;
                    r.Bank__c              = wrap.bankValue;
                }
                when 'POS' {
                    r.TransactionNumber__c = wrap.transactionNumber;
                    r.Last4DigitString__c  = wrap.last4Digit;
                }
                when 'Bank Transfer' {
                    r.TransactionNumber__c = wrap.transactionNumber;
                    r.Last4DigitString__c  = wrap.last4Digit;
                }
                // 'Online' — no extra fields beyond date/time
            }

            insert r;

            // ── Link uploaded documents to the new Receipt ────────────
            if (contentDocumentIds != null && !contentDocumentIds.isEmpty()) {
                List<ContentDocumentLink> links = new List<ContentDocumentLink>();
                for (Id docId : contentDocumentIds) {
                    links.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId    = r.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                }
                insert links;
            }

            // ── v2.2 Arvind — Track payments created without Signed EOI Form ──
            // Query Documents__c for 'Signed EOI Form' where Status__c != 'Uploaded'.
            // If found, set Payment_Created_w_o_Signed_EOI_form__c = true on the EOI
            // so finance teams can report on how many payments bypassed the signed form.
            // This runs regardless of the signed-doc validation being enabled or not.
            List<Documents__c> unsignedDocs = [
                SELECT Id
                FROM   Documents__c
                WHERE  Expressionofinterest__c = :wrap.eoiId
                AND    Name IN ('Signed EOI Form')
                AND    Status__c != 'Uploaded'
                LIMIT  1
            ];

            if (!unsignedDocs.isEmpty()) {
                update new Expressionofinterest__c(
                    Id                                     = wrap.eoiId,
                    Payment_Created_w_o_Signed_EOI_form__c = true
                );
            }
            // ──────────────────────────────────────────────────────────

            // ── Submit EOI — exact same pattern as the working submitEoi() ──
            // v2.0 Arvind — approval only fires for the FIRST payment.
            // Users with Allow_Duplicate_Payment_for_EOI may create additional
            // payments (to split amounts) but must not re-trigger approval.
            if (isFirstPayment) {
                submitEoiInternal(wrap.eoiId, 'Payment received Receipt: ' + r.Id);
            }

            saveResult.isSuccess = true;
            saveResult.receiptId = r.Id;
            saveResult.message   = isFirstPayment
                ? 'Payment created successfully and submitted for approval.'
                : 'Additional payment created successfully.';

        } catch (Exception e) {
            Database.rollback(sp);
            saveResult.isSuccess = false;
            saveResult.message   = e.getMessage();
        }

        return saveResult;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getSLAConfig() {
        Map<String, Object> config = new Map<String, Object>();
        config.put('slaEnabled',       System.Label.EOI_SLA_Enabled);
        config.put('residentHours',    Integer.valueOf(System.Label.EOI_SLA_HOURS_Expired));
        config.put('nonResidentHours', Integer.valueOf(System.Label.EOI_SLA_Hours_Non_Resident_expired));
        config.put('residentValue',    System.Label.EOI_SLA_Resident_Value);
        return config;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean checkHasPayment(Id eoiId) {
        List<Receipt__c> receiptObj = [
            SELECT Id FROM Receipt__c
            WHERE Expressionofinterest__c = :eoiId
        ];
        return !receiptObj.isEmpty();
    }

    // ─────────────────────────────────────────────────────────────────────
    // PRIVATE — Submit EOI status + approval
    // Mirrors the existing submitEoi() logic so behaviour is identical.
    // ─────────────────────────────────────────────────────────────────────
    private static void submitEoiInternal(Id eoiId, String comments) {
        Expressionofinterest__c eoi = [
            SELECT Id, Status__c
            FROM   Expressionofinterest__c
            WHERE  Id = :eoiId
        ];

        if (eoi != null) {
            eoi.Status__c = 'Submitted';
            update eoi;

            Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
            request.setComments(comments);
            request.setObjectId(eoi.Id);
            request.setSubmitterId(UserInfo.getUserId());
            request.setProcessDefinitionNameOrId('EOI_Approval_Process');
            request.setSkipEntryCriteria(true);
            Approval.process(request);
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // INNER CLASSES
    // ─────────────────────────────────────────────────────────────────────

    public class EOIWrapper {
        @AuraEnabled public String  eoiName;
        @AuraEnabled public String  opportunityName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  preferredPayment;
        @AuraEnabled public Boolean hasAllowDuplicatePermission; // v2.0 — drives Amount editability in LWC
    }

    public class ValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String  errorType;   // DOCS_MISSING | DUPLICATE
        @AuraEnabled public String  message;
    }

    public class SaveResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String  errorType;
        @AuraEnabled public String  message;
        @AuraEnabled public Id      receiptId;
    }

    public class PaymentWrapper {
        @AuraEnabled public Id      eoiId;
        @AuraEnabled public String  modeOfPayment;
        @AuraEnabled public Decimal amount;
        // Cheque
        @AuraEnabled public Date    chequeDate;
        @AuraEnabled public String  chequeNumber;
        @AuraEnabled public String  bankValue;
        // POS / Bank Transfer / Online
        @AuraEnabled public String  transactionNumber;
        @AuraEnabled public Date    transactionDate;
        @AuraEnabled public String  last4Digit;
    }
}