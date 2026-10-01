/* **
 * 1.0          Sivannarayana                               27 June 2026    Initial Draft
 * 2.0          pprajapati@horizontal.com                   02 Sept 2026    Added support for user-selected receipts and Sales Order Voided/Cancelled criteria
 * 2.1          pprajapati@horizontal.com                   03 Sept 2026    Updated to create 1 Case per EOI when multiple EOIs are selected, ensure Receipt Status is Cleared, and link receipts per EOI
 * 2.2          pprajapati@horizontal.com                   04 Sept 2026    Added support for linking mandatory Management MEMO document to created Cases and Documents__c records
 * 2.3          pprajapati@horizontal.com                   08 Sept 2026    Execute DML in SYSTEM_MODE to bypass user permission and record-type restrictions
 ****/
public without sharing class CaseInsertEOIRefundTargetBatch implements Database.Batchable<SObject> {

    private List<Id> inputEOIIds;
    private List<Id> inputReceiptIds;
    private Id contentDocumentId;
    public static Boolean isTriggerDisabled = false;

    public CaseInsertEOIRefundTargetBatch() {
        this.inputEOIIds = new List<Id>();
        this.inputReceiptIds = new List<Id>();
    }

    public CaseInsertEOIRefundTargetBatch(List<Id> eoiIds) {
        this.inputEOIIds = eoiIds != null ? eoiIds : new List<Id>();
        this.inputReceiptIds = new List<Id>();
    }

    public CaseInsertEOIRefundTargetBatch(List<Id> eoiIds, List<Id> receiptIds) {
        this(eoiIds, receiptIds, null);
    }

    // Version 2.2 [pprajapati@horizontal.com - 04 Sept 2026]: Added constructor supporting Management MEMO file attachment
    public CaseInsertEOIRefundTargetBatch(List<Id> eoiIds, List<Id> receiptIds, Id contentDocumentId) {
        this.inputEOIIds = eoiIds != null ? eoiIds : new List<Id>();
        this.inputReceiptIds = receiptIds != null ? receiptIds : new List<Id>();
        this.contentDocumentId = contentDocumentId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {

        if (!inputEOIIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id
                FROM Expressionofinterest__c
                WHERE Id IN :inputEOIIds
                ORDER BY CreatedDate ASC
            ]);
        }

        // Version 2.1 [pprajapati@horizontal.com - 03 Sept 2026]: Added Status__c = 'Cleared' eligibility condition
        return Database.getQueryLocator([
            SELECT Id
            FROM Expressionofinterest__c
            WHERE Account__c != null
            AND Account__r.PersonMobilePhone != null
            AND Case__c = null
            AND Id IN (
                SELECT ExpressionOfInterest__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c != null
                AND Case__c = null
                AND Status__c = 'Cleared'
                AND (
                    Account__r.Name = 'Unidentified Account (MRE Finance)'
                    OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN ('Voided', 'Cancelled'))
                )
            )
            ORDER BY CreatedDate ASC
            LIMIT 1
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {

        if (scope == null || scope.isEmpty()) {
            return;
        }

        // Version 2.1 [pprajapati@horizontal.com - 03 Sept 2026]: Create 1 Case per EOI when user triggers refund
        if (!inputEOIIds.isEmpty()) {
            List<Id> scopeIds = new List<Id>();
            for (SObject sobj : scope) {
                scopeIds.add(sobj.Id);
            }

            Map<Id, Expressionofinterest__c> currentEOIMap = new Map<Id, Expressionofinterest__c>([
                SELECT Id,
                       Name,
                       Account__c,
                       Account__r.FirstName,
                       Account__r.LastName,
                       Account__r.Name,
                       Account__r.PersonEmail,
                       Account__r.PersonMobilePhone,
                       Case__c
                FROM Expressionofinterest__c
                WHERE Id IN :scopeIds
            ]);

            Id standardRecordTypeId = getRecordTypeIdByDeveloperName('Case', 'Standard');

            for (Id eoiId : scopeIds) {
                Expressionofinterest__c currentEOI = currentEOIMap.get(eoiId);
                if (currentEOI == null || currentEOI.Case__c != null) {
                    continue;
                }

                Case cs = new Case();
                cs.Subject = System.Label.EOI_Subject;
                cs.Status = 'New';
                cs.Description = System.Label.EOI_Subject;
                cs.Sub_Vertical__c = System.Label.EOI_Sub_Vertical;
                cs.CaseCategory__c = System.Label.EOI_Case_Category;
                cs.Expression_of_Interest__c = currentEOI.Id;
                cs.Send_Customer_Email__c = false;
                cs.AccountId = currentEOI.Account__c;
                cs.Customer_Type__c = 'Owner';
                cs.Customer_Email__c = currentEOI.Account__r.PersonEmail;
                cs.Source__c = 'Internal';
                cs.Channel__c = 'Social';
                cs.Refund_Status__c = 'Initiated';
                cs.Whats_App_Integration_Status__c = 'Initiated';

                if (standardRecordTypeId != null) {
                    cs.RecordTypeId = standardRecordTypeId;
                }

                // Version 2.3 [pprajapati@horizontal.com - 08 Sept 2026]: Execute DML in SYSTEM_MODE and disable CaseTrigger to avoid owner CaseShare insertion conflicts
                CaseTriggerHandler.isTriggerDisabled = true;
                try {
                    Database.insert(cs, AccessLevel.SYSTEM_MODE);
                } finally {
                    CaseTriggerHandler.isTriggerDisabled = false;
                }

                currentEOI.Case__c = cs.Id;
                Database.update(currentEOI, AccessLevel.SYSTEM_MODE);

                // Link only the selected receipts belonging to this specific EOI
                List<Receipt__c> receiptList;
                if (inputReceiptIds != null && !inputReceiptIds.isEmpty()) {
                    receiptList = [
                        SELECT Id, ExpressionOfInterest__c, Case__c
                        FROM Receipt__c
                        WHERE ExpressionOfInterest__c = :currentEOI.Id
                        AND Id IN :inputReceiptIds
                    ];
                } else {
                    receiptList = [
                        SELECT Id, ExpressionOfInterest__c, Case__c
                        FROM Receipt__c
                        WHERE ExpressionOfInterest__c = :currentEOI.Id
                        AND Case__c = null
                        AND Status__c = 'Cleared'
                        AND (
                            Account__r.Name = 'Unidentified Account (MRE Finance)'
                            OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN ('Voided', 'Cancelled'))
                        )
                    ];
                }

                List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
                for (Receipt__c rec : receiptList) {
                    rec.Case__c = cs.Id;
                    receiptsToUpdate.add(rec);
                }

                if (!receiptsToUpdate.isEmpty()) {
                    isTriggerDisabled = true;
                    Database.update(receiptsToUpdate, AccessLevel.SYSTEM_MODE);
                }

                // Version 2.2 [pprajapati@horizontal.com - 04 Sept 2026]: Link Management MEMO file to created Case and Documents__c record
                if (contentDocumentId != null) {
                    try {
                        ContentDocumentLink cdl = new ContentDocumentLink(
                            ContentDocumentId = contentDocumentId,
                            LinkedEntityId = cs.Id,
                            ShareType = 'V',
                            Visibility = 'AllUsers'
                        );
                        Database.insert(cdl, AccessLevel.SYSTEM_MODE);

                        Documents__c doc = new Documents__c(
                            Name = 'Management MEMO',
                            Case__c = cs.Id,
                            Expressionofinterest__c = currentEOI.Id,
                            Account__c = currentEOI.Account__c,
                            Status__c = 'Uploaded'
                        );
                        Database.insert(doc, AccessLevel.SYSTEM_MODE);
                    } catch (Exception docEx) {
                        System.debug('Error linking Management MEMO to Case: ' + docEx.getMessage());
                    }
                }

                String phoneNumber = currentEOI.Account__r.PersonMobilePhone != null ? currentEOI.Account__r.PersonMobilePhone.trim() : null;
                if (String.isNotBlank(phoneNumber) && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                    System.enqueueJob(new EOIRefundWhatsAppQueueable(cs.Id, phoneNumber, new List<Id>{ currentEOI.Id }, 'Initial Outreach', 'eoi_initial_outreach'));
                }
            }
            return;
        }

        // Default Scheduled Flow: Group EOIs by Customer Phone
        Expressionofinterest__c scopeEOI = (Expressionofinterest__c) scope[0];

        Expressionofinterest__c currentEOI = [
            SELECT Id,
                   Name,
                   Account__c,
                   Account__r.FirstName,
                   Account__r.LastName,
                   Account__r.Name,
                   Account__r.PersonEmail,
                   Account__r.PersonMobilePhone,
                   Case__c
            FROM Expressionofinterest__c
            WHERE Id = :scopeEOI.Id
            LIMIT 1
        ];

        if (currentEOI.Case__c != null || String.isBlank(currentEOI.Account__r.PersonMobilePhone)) {
            return;
        }

        String phoneNumber = currentEOI.Account__r.PersonMobilePhone != null ? currentEOI.Account__r.PersonMobilePhone.trim() : null;

        List<Expressionofinterest__c> matchedEOIs = [
            SELECT Id,
                   Name,
                   Account__c,
                   Account__r.FirstName,
                   Account__r.LastName,
                   Account__r.Name,
                   Account__r.PersonEmail,
                   Account__r.PersonMobilePhone,
                   Case__c
            FROM Expressionofinterest__c
            WHERE Account__c != null
            AND Account__r.PersonMobilePhone = :phoneNumber
            AND Case__c = null
            AND Eligible_for_Refund__c = true
            AND Id IN (
                SELECT ExpressionOfInterest__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c != null
                AND Case__c = null
                AND Status__c = 'Cleared'
                AND (
                    Account__r.Name = 'Unidentified Account (MRE Finance)'
                    OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN ('Voided', 'Cancelled'))
                )
            )
            ORDER BY CreatedDate ASC
        ];

        if (matchedEOIs.isEmpty()) {
            return;
        }

        Expressionofinterest__c primaryEOI = matchedEOIs[0];

        Case cs = new Case();
        cs.Subject = System.Label.EOI_Subject;
        cs.Status = 'New';
        cs.Description = System.Label.EOI_Subject;
        cs.Sub_Vertical__c = System.Label.EOI_Sub_Vertical;
        cs.CaseCategory__c = System.Label.EOI_Case_Category;
        cs.Expression_of_Interest__c = primaryEOI.Id;
        cs.Send_Customer_Email__c = false;
        cs.AccountId = primaryEOI.Account__c;
        cs.Customer_Type__c = 'Owner';
        cs.Customer_Email__c = primaryEOI.Account__r.PersonEmail;
        cs.Source__c = 'Internal';
        cs.Channel__c = 'Social';
        cs.Refund_Status__c = 'Initiated';
        cs.Whats_App_Integration_Status__c = 'Initiated';

        Id standardRecordTypeId = getRecordTypeIdByDeveloperName('Case', 'Standard');
        if (standardRecordTypeId != null) {
            cs.RecordTypeId = standardRecordTypeId;
        }

        // Version 2.3 [pprajapati@horizontal.com - 08 Sept 2026]: Execute DML in SYSTEM_MODE and disable CaseTrigger to avoid owner CaseShare insertion conflicts
        CaseTriggerHandler.isTriggerDisabled = true;
        try {
            Database.insert(cs, AccessLevel.SYSTEM_MODE);
        } finally {
            CaseTriggerHandler.isTriggerDisabled = false;
        }

        List<Expressionofinterest__c> eoiToUpdate = new List<Expressionofinterest__c>();
        List<Id> eoiIds = new List<Id>();
        for (Expressionofinterest__c eoi : matchedEOIs) {
            eoi.Case__c = cs.Id;
            eoiToUpdate.add(eoi);
            eoiIds.add(eoi.Id);
        }

        Database.update(eoiToUpdate, AccessLevel.SYSTEM_MODE);

        List<Receipt__c> receiptList = [
            SELECT Id, ExpressionOfInterest__c, Case__c
            FROM Receipt__c
            WHERE ExpressionOfInterest__c IN :eoiIds
            AND Case__c = null
            AND Status__c = 'Cleared'
            AND (
                Account__r.Name = 'Unidentified Account (MRE Finance)'
                OR (SalesOrder__c != null AND SalesOrder__r.Status__c IN ('Voided', 'Cancelled'))
            )
        ];

        List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
        for (Receipt__c rec : receiptList) {
            rec.Case__c = cs.Id;
            receiptsToUpdate.add(rec);
        }

        if (!receiptsToUpdate.isEmpty()) {
            isTriggerDisabled = true;
            Database.update(receiptsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        if (String.isNotBlank(phoneNumber) && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new EOIRefundWhatsAppQueueable(cs.Id, phoneNumber, eoiIds, 'Initial Outreach', 'eoi_initial_outreach'));
        }
    }

    public void finish(Database.BatchableContext bc) {
    }

    private static Id getRecordTypeIdByDeveloperName(String objectName, String developerName) {

        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);

        if (sObjectType == null) {
            return null;
        }

        Map<String, Schema.RecordTypeInfo> rtMap =
            sObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey(developerName)) {
            return rtMap.get(developerName).getRecordTypeId();
        }

        return null;
    }
}