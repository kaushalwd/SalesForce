/**********************************************************************************************************************
* Name               : ADMWaiverController
* Description        : This class is used to handle all the ADM Waiver Related functionality
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0          dinesh.selvam@modon.com             02 Mar 2026     Handle the Entire Credit Note Automation Changes
* 2.0          dinesh.selvam@modon.com             06 Mar 2026     Update Allocation Type & Transaction Number for Credit Note
* 3.0          Dselvam                             19 Apr 2026     Custom file upload via Apex and link files only to Offers_Collections__c
* 4.0          Arvind Kesharwani                   01/05/2026      Added the check for Charge Object
* 5.0          Arvind Kesharwani                   10/05/2026      Added support for "Only Dari Fee" waiver type — amount sourced from Daricharges__c, ADM validations bypassed
* 5.1          Arvind                              15/05/2026      Added the Dari Charge into Dari Amount Dari Amount Discount field
******************************************************************************************************************/
public class ADMWaiverController {

    /** 4.0 NEW: Check if related charges with Record Type ADM or Dari Fee exist **/
    @AuraEnabled
    public static Boolean checkRelatedCharges(Id salesOrderId) {
        try {
            Integer chargeCount = [
                SELECT COUNT() 
                FROM Charge__c 
                WHERE Sales_Order__c = :salesOrderId 
                AND RecordType.DeveloperName = 'ADM_Fee' 
                AND Type__c = 'ADM & Dari Fee'
            ];
            return chargeCount > 0;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking charges: ' + e.getMessage());
        }
    }

    @AuraEnabled /** 1.0 Validated the Current ADM Payment Status **/
    public static String getAdmPaymentStatus(Id salesOrderId) {
        SalesOrder__c so = [
            SELECT ADM_Fees_and_Dari__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
        return so.ADM_Fees_and_Dari__c;
    }

    @AuraEnabled /** 1.0 Validating the Waiver Status of Existing ADM **/
    public static String admWaiverUpdate(Id salesOrderId) {
        try {
            if (salesOrderId != null) {
                Invoice__c invoice = [
                    SELECT Id, AppliedAmount__c, InvoiceAmount__c
                    FROM Invoice__c
                    WHERE Sales_Order__c = :salesOrderId
                    AND Is_ADM_Fees_and_Dari_charges__c = true
                    LIMIT 1
                ];

                if (invoice != null && invoice.AppliedAmount__c < invoice.InvoiceAmount__c) {
                    return 'Waiver';
                }
                return 'No Waiver';
            }
            return 'No Waiver';
        } catch (Exception ex) {
            return 'Error';
        }
    }

    public class SaveWaiverRequest {
        @AuraEnabled public Id parentRecordId;
        @AuraEnabled public String waiverpercent;
        @AuraEnabled public String waiverMemo;
        @AuraEnabled public String filesDataJson;
    }

    public class SaveWaiverResponse {
        @AuraEnabled public Id waiverId;
        @AuraEnabled public String message;
    }
    /** 3.0 Custom file upload via Apex and link files only to Offers_Collections__c Start **/
    public class FileDataWrapper {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
        @AuraEnabled public String contentType;
    }

    public class ResponseWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id waiverId;
    }

    @AuraEnabled /** 1.0 Creating the ADM Waiver Request based on the user selection **/
    public static ResponseWrapper saveWaiver(
        Id parentRecordId,
        Decimal waiverpercent,
        String waiverMemo,
        String waiverMemoNumber,
        String applyDariWaiver,
        Decimal dariWaiverAmount,
        Decimal admDiscountAmount,
        Decimal totalWaiverAmount,
        String filesDataJson,
        Boolean onlyDariFee /** 5.0 Arvind Kesharwani 10/05/2026 - New param: true when waiver type is "Only Dari Fee" **/
    ) {
        List<String> errors = new List<String>();

        if (parentRecordId == null) {
            errors.add('Parent Record Id is required.');
        }

        /** 5.0 Arvind Kesharwani 10/05/2026 - Waiver % is required only for ADM type; skip for Only Dari Fee **/
        if (onlyDariFee != true && waiverpercent == null) {
            errors.add('Waiver Percent is required.');
        }

        if (String.isBlank(waiverMemo)) {
            errors.add('Waiver Memo is required.');
        }

        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, '\n'));
        }
        /** 3.0 Custom file upload via Apex and link files only to Offers_Collections__c **/
        List<FileDataWrapper> filesData = new List<FileDataWrapper>();
        if (!String.isBlank(filesDataJson)) {
            filesData = (List<FileDataWrapper>) JSON.deserialize(filesDataJson, List<FileDataWrapper>.class);
        }
        try {
            Invoice__c inv = [
                SELECT Id, AppliedAmount__c, InvoiceAmount__c
                FROM Invoice__c
                WHERE Sales_Order__c = :parentRecordId
                AND Is_ADM_Fees_and_Dari_charges__c = TRUE
                LIMIT 1
            ];

            if (inv == null) {
                throw new AuraHandledException('No ADM Invoice Present under this Sales Order.');
            }

            Map<Id, Id> soextDocMap = new Map<Id, Id>();
            for (Documents__c extDoc : [
                SELECT Id, SalesOrder__c
                FROM Documents__c
                WHERE Name = 'ADM - Waiver'
                AND SalesOrder__c = :parentRecordId
            ]) {
                soextDocMap.put(extDoc.SalesOrder__c, extDoc.Id);
            }

            Documents__c doc = new Documents__c(
                SalesOrder__c = parentRecordId,
                Name = 'ADM - Waiver'
            );

            if (soextDocMap.containsKey(parentRecordId)) {
                doc.Id = soextDocMap.get(parentRecordId);
            }
            upsert doc;

            SalesOrder__c soObj = [
                SELECT Id,
                       Opportunity__c,
                       Unit__c,
                       ADM_Fees_and_Dari__c,
                       TotalAmount__c,
                       CustomerAccount__c,
                       Daricharges__c,
                       Discount_on_ADM_Fees__c
                FROM SalesOrder__c
                WHERE Id = :parentRecordId
                LIMIT 1
            ];

            /** 5.0 Arvind Kesharwani 10/05/2026 - Skip ADM discount validation when waiver type is Only Dari Fee **/
            if (onlyDariFee != true) {
                if (soObj.Discount_on_ADM_Fees__c != null && soObj.Discount_on_ADM_Fees__c >= 2) {
                    throw new AuraHandledException(
                        'Cannot create a new Waiver. An existing Offer is already inprogress for this Sales Order OR ADM Already Collected.'
                    );
                }

                if (soObj.Discount_on_ADM_Fees__c != null && soObj.Discount_on_ADM_Fees__c + waiverpercent > 2) {
                    throw new AuraHandledException(
                        'Cannot create a new Waiver. ADM Waiver % greater than 2% please check is there any ADM waiver inprogress OR please correct the waiver %.'
                    );
                }
            }

            Integer approvedCount = [
                SELECT COUNT()
                FROM Offers_Collections__c
                WHERE Sales_Order__c = :parentRecordId
                AND Offer_On__c = 'ADM Fees'
                AND Offer_Type__c = 'Waiver'
                AND Approval_Status__c != 'Approved'
                AND Approval_Status__c != 'Rejected'
            ];

            if (approvedCount > 0) {
                throw new AuraHandledException(
                    'Cannot create a new Waiver. An existing Offer is already inprogress for this Sales Order OR ADM Already Collected.'
                );
            }

            /** 5.0 Arvind Kesharwani 10/05/2026 - Fetch OfferLines based on waiver type.**/ 
            Id offerLineId = null;
            if (onlyDariFee == true) {
                // Arvind Kesharwani 10/05/2026 - OfferType__c = 'Dari Charges'
                List<OfferLines__c> dariLines = [
                    SELECT Id
                    FROM OfferLines__c
                    WHERE OfferType__c = 'Dari Charges'
                    LIMIT 1
                ];
                if (!dariLines.isEmpty()) {
                    offerLineId = dariLines[0].Id;
                }
                if (offerLineId == null) {
                    throw new AuraHandledException(
                        'No Offer Line found with type "Dari Charges". Please ensure this record exists and is active.'
                    );
                }
            } else {
                List<OfferLines__c> admLines = [
                    SELECT Id
                    FROM OfferLines__c
                    WHERE OfferType__c = 'Waiver'
                    AND OfferValue__c = :waiverpercent
                    LIMIT 1
                ];
                if (!admLines.isEmpty()) {
                    offerLineId = admLines[0].Id;
                }
            }

            Offers_Collections__c newOffer = new Offers_Collections__c(
                Offer_Lines__c      = offerLineId,
                Opportunity__c      = soObj.Opportunity__c,
                Sales_Order__c      = parentRecordId,
                Unit__c             = soObj.Unit__c,
                Waiver_Memo_No__c   = waiverMemoNumber,
                Approval_Status__c  = 'Not Submitted',
                Invoice__c          = inv.Id,
                Customer__c         = soObj.CustomerAccount__c,
                /** 5.0 Arvind Kesharwani 10/05/2026 - Always waive DARI for Only Dari Fee type **/
                Is_DARI_Fee_Waived__c = (onlyDariFee == true) ? true : (applyDariWaiver == 'Yes')
            );
            insert newOffer;

            Decimal bufferAmount = Decimal.valueOf(System.Label.ADMBufferAmount);

            /** 5.0 Arvind Kesharwani 10/05/2026 - For Only Dari Fee, waiver amount = Daricharges__c only;
             *      no ADM percentage discount is applied **/
            Decimal waiverAmount;
            if (onlyDariFee == true) {
                waiverAmount = (soObj.Daricharges__c != null ? soObj.Daricharges__c : 0);
            } else {
                waiverAmount =
                    (soObj.TotalAmount__c * (waiverpercent / 100)) +
                    (applyDariWaiver == 'Yes'
                        ? (soObj.Daricharges__c != null ? soObj.Daricharges__c : 0)
                        : 0);
            }

            Decimal totalApplied = inv.AppliedAmount__c + waiverAmount + bufferAmount;

            /** 5.0 Arvind Kesharwani 10/05/2026 - Only update Discount_on_ADM_Fees__c for ADM type waiver **/
            SalesOrder__c so = new SalesOrder__c(
                Id = parentRecordId,
                ADM_Dari_Fee_Collected_Date__c = System.today()
            );
                            // 5.1 rvind Kesharwani 14/05/2026 - Flag Sales Order so formula includes Daricharges__c

              if (onlyDariFee == true)  {

                                so.Is_Only_Dari_Fee_Waived__c = true;}
                                else {

                so.Discount_on_ADM_Fees__c = soObj.Discount_on_ADM_Fees__c != null
                    ? soObj.Discount_on_ADM_Fees__c + waiverpercent
                    : waiverpercent;}
            
            update so;

            if (totalApplied >= inv.InvoiceAmount__c) {
                SalesOrderStatusAutomationHelper.closingTheStatus(
                    new Set<Id>{ parentRecordId },
                    new List<String>{'ADM + Dari Fee Collected'}
                );
            }
           /** 3.0 Custom file upload via Apex and link files only to Offers_Collections__c Start **/
            if (filesData != null && !filesData.isEmpty()) {
                List<ContentVersion> versionsToInsert = new List<ContentVersion>();

                for (FileDataWrapper fileItem : filesData) {
                    if (fileItem == null || String.isBlank(fileItem.fileName) || String.isBlank(fileItem.base64Data)) {
                        continue;
                    }

                    ContentVersion cv = new ContentVersion();
                    cv.Title = fileItem.fileName.contains('.')
                        ? fileItem.fileName.substringBeforeLast('.')
                        : fileItem.fileName;
                    cv.PathOnClient = '/' + fileItem.fileName;
                    cv.VersionData = EncodingUtil.base64Decode(fileItem.base64Data);
                    versionsToInsert.add(cv);
                }

                if (!versionsToInsert.isEmpty()) {
                    insert versionsToInsert;

                    List<ContentVersion> insertedVersions = [
                        SELECT Id, ContentDocumentId
                        FROM ContentVersion
                        WHERE Id IN :versionsToInsert
                    ];

                    List<ContentDocumentLink> links = new List<ContentDocumentLink>();
                    for (ContentVersion insertedCv : insertedVersions) {
                        links.add(new ContentDocumentLink(
                            ContentDocumentId = insertedCv.ContentDocumentId,
                            LinkedEntityId = newOffer.Id,
                            ShareType = 'V',
                            Visibility = 'AllUsers'
                        ));
                    }

                    if (!links.isEmpty()) {
                        insert links;
                    }
                }
            }
          /** 3.0 Custom file upload via Apex and link files only to Offers_Collections__c End **/
            for (Offers_Collections__c offers : [
                SELECT Id
                FROM Offers_Collections__c
                WHERE Id = :newOffer.Id
                AND DontAllowToCreateCreditNote__c = false
            ]) {
                // submitAdmWaiverForApproval(offers.Id, null);
            }

            ResponseWrapper res = new ResponseWrapper();
            res.success = true;
            res.waiverId = doc.Id;
            res.recordId = newOffer.Id;
            res.message = 'Waiver saved successfully.';
            return res;

        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            System.debug('Exception in saveWaiver: ' + ex.getMessage());
            throw new AuraHandledException('Error! ' + ex.getMessage());
        }
    }
    /** 2.0 - Update Allocation Type for Credit Note **/
    public static void handleWaiverAllocation(List<SObject> newList) {
        Set<Id> receiptIdset = new Set<Id>();
        for (Allocation__c alloc : (List<Allocation__c>) newList) {
            receiptIdset.add(alloc.Receipt__c);
        }

        if (!receiptIdset.isEmpty()) {
            Set<Id> creditNoteReceiptId = new Set<Id>();
            for (Receipt__c pay : [
                SELECT Id
                FROM Receipt__c
                WHERE Id IN :receiptIdset
                AND Modeofpayment__c = 'Credit Note'
            ]) {
                creditNoteReceiptId.add(pay.Id);
            }

            if (!creditNoteReceiptId.isEmpty()) {
                for (Allocation__c alloc : (List<Allocation__c>) newList) {
                    if (creditNoteReceiptId.contains(alloc.Receipt__c)) {
                        alloc.Allocation_Type__c = 'Credit Note';
                    }
                }
            }
        }
    }
    /** 2.0 - Update Transcation Number for Credit Note **/
    public static void updateCreditNoteTransactionNumber(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Receipt__c> updateReceiptLst = new List<Receipt__c>();

        for (Receipt__c rec : (List<Receipt__c>) newList) {
            Receipt__c oldData = oldMap != null ? (Receipt__c) oldMap.get(rec.Id) : null;

            if (rec.Modeofpayment__c == 'Credit Note' &&
                (oldData == null || (oldData != null && oldData.Modeofpayment__c != rec.Modeofpayment__c))) {
                Receipt__c recObj = new Receipt__c();
                recObj.Id = rec.Id;
                recObj.TransactionNumber__c = rec.Name.replace('R', 'CN');
                updateReceiptLst.add(recObj);
            }
        }

        if (!updateReceiptLst.isEmpty()) {
            update updateReceiptLst;
        }
    }
}