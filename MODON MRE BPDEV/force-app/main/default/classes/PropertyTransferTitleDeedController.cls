/**********************************************************************************************************************
* Name               : PropertyTransferTitleDeedController                                                       
* Description        : This is a helper class for PropertyTransferTitleDeedController
* Usage              : Controller for Commercial Plots Property Transfer – Title Deed process.
*                     Handles outstanding charge creation, invoice generation, document validation,
*                     and email dispatch for NOC/payment receipts and invoices
* Created By         : AMGS                                                     
* -------------------------------createNextStepBRTasks-------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sirisha Reddy               10 Jan 2025     Create Commercial Plots Property Transfer – Title Deed process
* 2.0           Sirisha Reddy               10 May 2026     Updated/added commercial charges
******************************************************************************************************************/

public class PropertyTransferTitleDeedController {
     /**
* Purpose      : Creates Outstanding Charge records and their linked Invoice records
*                when the Outstanding_Charge__c field changes on a ServiceRequest__c.
*                Called from a trigger context (after update).
* Business Rule: A new Charge__c (type = Outstanding Charge) and Invoice__c are created
*                only when Outstanding_Charge__c is populated and has changed from its
*                previous value — preventing duplicate charges on re-saves.
* @param : newList - List of updated ServiceRequest__c records (trigger.new)
* @param : oldMap  - Map of previous ServiceRequest__c values (trigger.oldMap)
* @return        void
*/
   public static void handleCommercialCharges(
    List<ServiceRequest__c> newList,
    Map<Id, ServiceRequest__c> oldMap
) {
    if (newList == null || newList.isEmpty()) {
        return;
    }

    Boolean isInsertContext = (oldMap == null || oldMap.isEmpty());

    Id commercialSrRtId = Utility.getRecordTypeIdByDevName(
        ServiceRequest__c.SObjectType,
        'Property_Transfer_Title_Deed_Commercial'
    );

    String srRtDevName = Schema.SObjectType.ServiceRequest__c
    .getRecordTypeInfosById()
    .get(commercialSrRtId)
    .getDeveloperName();
    
    Map<String, Schema.RecordTypeInfo> chargeRtByDevName =
        Schema.SObjectType.Charge__c.getRecordTypeInfosByDeveloperName();
    Map<String, Schema.RecordTypeInfo> chargeRtByName =
        Schema.SObjectType.Charge__c.getRecordTypeInfosByName();

    Id adminFeeNocRtId = chargeRtByDevName.containsKey('Admin_Fee_NOC')
        ? chargeRtByDevName.get('Admin_Fee_NOC').getRecordTypeId()
        : null;

    Id outstandingRtId = chargeRtByDevName.containsKey('Outstanding_Charge')
        ? chargeRtByDevName.get('Outstanding_Charge').getRecordTypeId()
        : null;

    List<ServiceRequest__c> eligibleSRs = new List<ServiceRequest__c>();
    Set<Id> srIds = new Set<Id>();

    for (ServiceRequest__c sr : newList) {
        if (sr.RecordTypeId == commercialSrRtId) {
            eligibleSRs.add(sr);
            if (sr.Id != null) {
                srIds.add(sr.Id);
            }
        }
    }

    if (eligibleSRs.isEmpty()) {
        return;
    }

    // Existing charges
    Map<String, Charge__c> existingChargeByKey = new Map<String, Charge__c>();
    if (!srIds.isEmpty()) {
        for (Charge__c ch : [
            SELECT Id, Name, Type__c, Amount__c, VAT_Amount__c,
                   Service_Request__c, Sales_Order__c, Account__c
            FROM Charge__c
            WHERE Service_Request__c IN :srIds
            AND Name IN ('NOC', 'Outstanding')
        ]) {
            existingChargeByKey.put(ch.Service_Request__c + '|' + ch.Name, ch);
        }
    }

    // NOC financial setup only needed on insert
    Financial_Setup__c nocSetup;
    if (isInsertContext) {
        List<Financial_Setup__c> setupList = [
            SELECT Id, Value__c, VATAmount__c, Fee_Type__c, SR_RecordType__c, Type__c
            FROM Financial_Setup__c
            WHERE SR_RecordType__c = :srRtDevName
            AND Type__c = 'NOC'
            LIMIT 1
        ];
        if (!setupList.isEmpty()) {
            nocSetup = setupList[0];
        }
    }

    List<Charge__c> chargesToInsert = new List<Charge__c>();
    List<Charge__c> chargesToUpdate = new List<Charge__c>();
    List<Charge__c> insertedChargesForInvoice = new List<Charge__c>();

    for (ServiceRequest__c sr : eligibleSRs) {
        // Insert scenario -> create NOC
        if (isInsertContext) {
            String nocKey = sr.Id + '|NOC';

            if (nocSetup != null &&
                adminFeeNocRtId != null &&
                !existingChargeByKey.containsKey(nocKey)) {

                chargesToInsert.add(new Charge__c(
                    Name = 'NOC',
                    Type__c = 'NOC',
                    Amount__c = nocSetup.Value__c != null ? nocSetup.Value__c : 0,
                    VAT_Amount__c = nocSetup.VATAmount__c != null ? nocSetup.VATAmount__c : 0,
                    PaymentStatus__c = 'Not Paid',
                    Service_Request__c = sr.Id,
                    RecordTypeId = adminFeeNocRtId,
                    Sales_Order__c = sr.SalesOrder__c,
                    Account__c = sr.AccountId__c
                ));
            }
        }

        System.debug('isInsertContext----->'+isInsertContext+'rec'+outstandingRtId);
        // Update scenario -> create/update Outstanding
        if (!isInsertContext) {
            ServiceRequest__c oldSr = oldMap.get(sr.Id);

            if (oldSr != null &&
                sr.Outstanding_Charge__c != null &&
                sr.Outstanding_Charge__c != oldSr.Outstanding_Charge__c) {

                String outstandingKey = sr.Id + '|Outstanding';

                if (existingChargeByKey.containsKey(outstandingKey)) {
                    Charge__c existingOutstanding = existingChargeByKey.get(outstandingKey);
                    existingOutstanding.Amount__c = sr.Outstanding_Charge__c;
                    chargesToUpdate.add(existingOutstanding);
                } else if (outstandingRtId != null) {
                    chargesToInsert.add(new Charge__c(
                        Name = 'Outstanding',
                        Amount__c = sr.Outstanding_Charge__c,
                        VAT_Amount__c = 0,
                         Type__c = 'Other',
                        PaymentStatus__c = 'Not Paid',
                        Service_Request__c = sr.Id,
                        RecordTypeId = outstandingRtId,
                        Sales_Order__c = sr.SalesOrder__c,
                        Account__c = sr.AccountId__c
                    ));
                }
            }
        }
    }

    if (!chargesToUpdate.isEmpty()) {
        update chargesToUpdate;
    }

    if (!chargesToInsert.isEmpty()) {
        List<Database.SaveResult> chargeResults = Database.insert(chargesToInsert, false);

        for (Integer i = 0; i < chargeResults.size(); i++) {
            if (chargeResults[i].isSuccess()) {
                insertedChargesForInvoice.add(chargesToInsert[i]);
            } else {
                for (Database.Error err : chargeResults[i].getErrors()) {
                    System.debug(
                        'Charge insert failed for SR [' +
                        chargesToInsert[i].Service_Request__c + ']: ' +
                        err.getMessage()
                    );
                }
            }
        }
    }

    if (insertedChargesForInvoice.isEmpty()) {
        return;
    }

    List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
    for (Charge__c ch : insertedChargesForInvoice) {
        Invoice__c inv = createChargeInvoice(ch, ch.Account__c);
        if (inv != null) {
            invoicesToInsert.add(inv);
        }
    }

    if (!invoicesToInsert.isEmpty()) {
        Database.insert(invoicesToInsert, false);
    }
}    /**
* Purpose      : Builds a single Invoice__c record from a given Charge__c and Account Id.
*                Calculates the total invoice amount as Charge Amount + VAT Amount.
*                Does NOT perform DML — caller is responsible for bulk insert.
* Business Rule: Invoice is always dated today. VAT defaults to 0 if null on the charge.
*                Invoice is linked to the Charge, Sales Order, and Account.
* @param : charge - The Charge__c record to invoice (must have Amount__c, VAT_Amount__c,
*                 Sales_Order__c, and Id populated)
* @param : accId  - The Account Id to link to the Invoice
* @return       Invoice__c — unsaved invoice record ready for bulk insert
*/
    public static Invoice__c createChargeInvoice(Charge__c charge, Id accId) {
        
        Invoice__c invObj = new Invoice__c();
        invObj.Sales_Order__c = charge.Sales_Order__c;
        
        Decimal vatAmount = (charge.VAT_Amount__c != null) ? charge.VAT_Amount__c : 0;
        invObj.InvoiceAmount__c = charge.Amount__c + vatAmount;
        
        invObj.InvoiceDate__c = System.today();
        invObj.Account__c = accId;
        invObj.Charge__c = charge.Id;
        
        return invObj;
    }
    /**
* Purpose      : Retrieves all unpaid Charge__c records linked to a set of Service Request IDs.
*                Filters to charges where Paid Amount does not equal Amount (partially or fully unpaid).
*                Returns a map keyed by Service_Request__c Id for O(1) lookup.
* Business Rule: Used to block step completion when outstanding or NOC charges are still unpaid.
*                Excludes charges with PaymentStatus__c = 'Paid' at SOQL level for efficiency.
* @param  : completedTaskServiceRequestIds - Set of ServiceRequest__c Ids to check charges for
* @return Map<Id, Charge__c> — keyed by Service_Request__c Id, one unpaid charge per SR
*/
    @TestVisible
    private static Map<Id, Charge__c> getChargeData (Set<Id> completedTaskServiceRequestIds)
    {
        Map<Id, Charge__c> chargeMap = new Map<Id, Charge__c> ();
        List<Charge__c> chargelst = [
            SELECT Id, Service_Request__c, Name, Paid_Amount__c, PaymentStatus__c,
            Remaining_Amount__c, Sales_Order__c, Type__c, VAT_Amount__c,
            Amount__c FROM Charge__c Where Service_Request__c IN : completedTaskServiceRequestIds AND (PaymentStatus__c <> 'Paid')];
        for (Charge__c c: chargelst)
        {
            if (c.Paid_Amount__c<> c.Amount__c)
            {
                chargeMap.put (c.Service_Request__c, c);
            }
        }
        return chargeMap;
    }
    /**
* Purpose      : Sends the NOC Payment Receipt and (if applicable) the Outstanding Payment
*                Receipt to the customer via email with file attachments.
*                Validates that the relevant documents are uploaded before sending.
*                Resolves the correct Contact recipient from the linked Account.
* Business Rule: NOC Payment Receipt is always required.
*                Outstanding Payment Receipt is only required when Outstanding_Charge__c > 0.
*                Uses the email template defined in Custom Label: TitleDeedReceiptEmailTemplate.
*                Returns a string status code — caller uses this to show user feedback.
*                Email is saved as an Activity (setSaveAsActivity = true).
* @param : serviceRequestId - Id of the ServiceRequest__c to send the receipt for
* @return String status code:
*         'EMAIL_SENT'                                   — success
*         'INVALID_SERVICE_REQUEST_ID'                   — null input
*         'PERSON_ACCOUNT_HAS_NO_CONTACT'               — person account missing contact
*         'NO_ACTIVE_CONTACT_FOUND'                     — no active contact on business account
*         'ERROR_NOC_PAYMENT_RECEIPT_NOT_UPLOADED'      — NOC receipt doc not uploaded
*         'ERROR_OUTSTANDING_PAYMENT_RECEIPT_NOT_UPLOADED' — outstanding receipt not uploaded
*         'NO_FILES_FOUND'                              — no ContentDocument links found
*         'NO_CONTENTVERSION_FOUND'                     — no file versions found
*         'EMAIL_TEMPLATE_NOT_FOUND'                    — email template missing
*         'EMAIL_FAILED'                                — Salesforce email send failure
*         'EMAIL_EXCEPTION'                             — unexpected exception caught
*/
    @AuraEnabled
    public static String sendPaymentReceiptToCustomer(Id serviceRequestId) {
        if (serviceRequestId == null) return 'INVALID_SERVICE_REQUEST_ID';
        
        try {
            
            /* -----------------------------
Step 1: Get Service Request
------------------------------*/
            ServiceRequest__c sr = [
                SELECT Id, AccountId__c, Outstanding_Charge__c
                FROM ServiceRequest__c
                WHERE Id = :serviceRequestId
                LIMIT 1
            ];
            
            Decimal outstanding = sr.Outstanding_Charge__c;
            Boolean isOutstandingRequired = (outstanding != null && outstanding > 0);
            
            Set<Id> srIds = new Set<Id>{ sr.Id };
                Map<Id, Charge__c> chargeMap = getChargeData(srIds);
            
            if (chargeMap.containsKey(sr.Id)) {
                return 'Please update the ' + chargeMap.get(sr.Id).Name + ' charge status to paid: ';
            }
            
            
            
            
            /* -----------------------------
Step 2: Get Account
------------------------------*/
            Account acc = [
                SELECT Id, IsPersonAccount, PersonContactId
                FROM Account
                WHERE Id = :sr.AccountId__c
                LIMIT 1
            ];
            
            /* -----------------------------
Step 3: Determine Recipient
------------------------------*/
            Id targetId;
            if (acc.IsPersonAccount) {
                if (acc.PersonContactId == null) return 'PERSON_ACCOUNT_HAS_NO_CONTACT';
                targetId = acc.PersonContactId;
            } else {
                List<Contact> contacts = [
                    SELECT Id
                    FROM Contact
                    WHERE AccountId = :acc.Id
                    AND Is_Active__c = true
                    LIMIT 1
                ];
                if (contacts.isEmpty()) return 'NO_ACTIVE_CONTACT_FOUND';
                targetId = contacts[0].Id;
            }
            
            /* -----------------------------
Step 4: Fetch Documents
------------------------------*/
            List<Documents__c> docList = [
                SELECT Id, Name, Status__c
                FROM Documents__c
                WHERE Service_Request__c = :sr.Id
                AND Name IN ('NOC Payment Receipt', 'Outstanding Payment Receipt')
            ];
            
            Map<String, Documents__c> docMap = new Map<String, Documents__c>();
            for (Documents__c d : docList) {
                docMap.put(d.Name, d);
            }
            
            /* -----------------------------
Step 5: Validations
------------------------------*/
            
            // NOC Payment Receipt must exist and be Uploaded
            if (!docMap.containsKey('NOC Payment Receipt') ||
                docMap.get('NOC Payment Receipt').Status__c != 'Uploaded') {
                    
                    return 'ERROR_NOC_PAYMENT_RECEIPT_NOT_UPLOADED';
                }
            
            // Outstanding Payment Receipt required only when Outstanding > 0
            if (isOutstandingRequired &&
                (!docMap.containsKey('Outstanding Payment Receipt') ||
                 docMap.get('Outstanding Payment Receipt').Status__c != 'Uploaded')) {
                     
                     return 'ERROR_OUTSTANDING_PAYMENT_RECEIPT_NOT_UPLOADED';
                 }
            
            /* -----------------------------
Step 6: Collect Valid Document Ids
------------------------------*/
            Set<Id> docIds = new Set<Id>();
            docIds.add(docMap.get('NOC Payment Receipt').Id);
            
            if (isOutstandingRequired) {
                docIds.add(docMap.get('Outstanding Payment Receipt').Id);
            }
            
            /* -----------------------------
Step 7: Get Files
------------------------------*/
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :docIds
            ];
            
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink l : links) {
                contentDocIds.add(l.ContentDocumentId);
            }
            
            if (contentDocIds.isEmpty()) return 'NO_FILES_FOUND';
            
            List<ContentVersion> versions = [
                SELECT Title, VersionData, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                AND IsLatest = true
            ];
            
            if (versions.isEmpty()) return 'NO_CONTENTVERSION_FOUND';
            
            /* -----------------------------
Step 8: Get Email Template
------------------------------*/
            EmailTemplate template = [
                SELECT Id
                FROM EmailTemplate
                WHERE Name = :Label.TitleDeedReceiptEmailTemplate
                LIMIT 1
            ];
            
            if (template == null) return 'EMAIL_TEMPLATE_NOT_FOUND';
            
            /* -----------------------------
Step 9: Prepare Email
------------------------------*/
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(targetId);
            email.setWhatId(sr.Id);
            email.setTemplateId(template.Id);
            email.setSaveAsActivity(true);
            
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            for (ContentVersion cv : versions) {
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setFileName(cv.Title + '.' + cv.FileExtension);
                efa.setBody(cv.VersionData);
                attachments.add(efa);
            }
            email.setFileAttachments(attachments);
            
            /* -----------------------------
Step 10: Send Email
------------------------------*/
            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
            
            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) return 'EMAIL_FAILED';
            }
            
            return 'EMAIL_SENT';
            
        } catch (Exception e) {
            System.debug('Send payment receipt error: ' + e.getMessage());
            return 'EMAIL_EXCEPTION';
        }
    }
    /**
* Purpose      : Validates that all required data fields are populated on the
*                ServiceRequest__c, its linked Unit__c, Account, and Prospect_Account__c
*                before Task step 4 (order '4' or '4.0') can be closed.
*                Adds a field-level error on the Task.Status if any required fields are missing.
* Business Rule: Step 4 is the document details validation gate in the Title Deed Commercial
*                workflow. All listed SR fields, unit dimensions, account details (for non-person
*                accounts), and prospect account details must be present before proceeding.
*                Missing fields are collected and reported in a single consolidated error message.
* @param : srRecordMap   - Map<Id, ServiceRequest__c> of SR records keyed by Id
* @param : srList        - List<ServiceRequest__c> of Title Deed Commercial SRs to validate
* @param : tskMap        - Map<String, Task> of tasks keyed by order number string (e.g. '4', '4.0')
* @return              void — errors are added directly to Task.Status via addError()
*/
    public static void validateDocumentFields(
        Map<Id, ServiceRequest__c> srRecordMap,
        List<ServiceRequest__c> srList,
        Map<String, Task> tskMap
    ) {
        
        Set<Id> srIds = new Set<Id>();
        Set<Id> unitIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        
        for (ServiceRequest__c sr : srList) {
            if (sr.Id != null) srIds.add(sr.Id);
            if (sr.UnitId__c != null) unitIds.add(sr.UnitId__c);
            if (sr.AccountId__c != null) accountIds.add(sr.AccountId__c);
        }
        
        /* ------------------ QUERY UNIT ------------------ */
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>();
        if (!unitIds.isEmpty()) {
            unitMap = new Map<Id, Unit__c>([
                SELECT Id,
                GrossFloorAreaGFA__c,
                ADM_Plot_Number__c,
                AED_SQM__c,
                Sector__c,
                Location__c
                FROM Unit__c
                WHERE Id IN :unitIds
            ]);
        }
        
        /* ------------------ QUERY ACCOUNT ------------------ */
        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountMap = new Map<Id, Account>([
                SELECT Id,IsPersonAccount,
                POARegistrationAuthority__c,
                Trade_License_Number__c,
                BillingAddress
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }
        
        /* ------------------ QUERY PROSPECT ACCOUNT ------------------ */
        Map<Id, Prospect_Account__c > prospectBySR = new Map<Id, Prospect_Account__c >();
        if (!srIds.isEmpty()) {
            for (Prospect_Account__c  pa : [
                SELECT Id,
                Service_Request__c,
                Account__c,
                POARegistrationAuthority__c,
                UnifiedNumber__c,
                BillingAddress__c
                FROM Prospect_Account__c 
                WHERE Service_Request__c IN :srIds  and IsOrgAccount__c=True
            ]) {
                prospectBySR.put(pa.Service_Request__c, pa);
            }
        }
        
        /* ------------------ VALIDATION ------------------ */
        for (String ordr : tskMap.keySet()) {
            
            if (ordr == '4' || ordr == '4.0') {
                
                System.debug('ordr------------' + ordr);
                Task t = tskMap.get(ordr);
                
                if (t.Status == Constants.TASK_STATUS_CLOSED) {
                    
                    ServiceRequest__c sr = srRecordMap.get(t.WhatId);
                    if (sr == null) continue;
                    
                    List<String> missingFields = new List<String>();
                    
                    /* -------- Existing SR Validations -------- */
                    if (sr.Master_Developer__c == null) missingFields.add('Master Developer');
                    if (sr.Reference_Number__c == null) missingFields.add('Reference Number');
                    if (sr.Initial_Purchase_Date__c == null) missingFields.add('Initial Purchase Date');
                    if (sr.Master_Developer_License_Number__c == null) missingFields.add('Master Developer License Number');
                    if (sr.Agreement_Effective_Date__c == null) missingFields.add('Agreement Effective Date');
                    if (sr.Seller_SPA_Effective_Date__c == null) missingFields.add('Seller SPA Effective Date');
                    if (sr.SR_Selling_Price__c == null) missingFields.add('SR Selling Price');
                    if (sr.Master_Community_Declaration_Date__c == null) missingFields.add('Master Community Declaration Date');
                    if (sr.Max_No_Of_Floors__c == null) missingFields.add('Max No Of Floors');
                    if (sr.Max_Allowable_Podium__c == null) missingFields.add('Max Allowable Podium');
                    if (sr.Submission_Period_in_Months__c == null) missingFields.add('Submission Period (Months)');
                    if (sr.Commencement_Date_in_Months__c == null) missingFields.add('Commencement Date (Months)');
                    if (sr.Completion_Date_in_Months__c == null) missingFields.add('Completion Date (Months)');
                    if (sr.Buyer_Validator_Email__c == null) missingFields.add('Buyer Validator Email');
                    if (sr.Buyer_Validator_Name__c == null) missingFields.add('Buyer Validator Name');
                    if (sr.Seller_Validator_Email__c == null) missingFields.add('Seller Validator Email');
                    if (sr.Seller_Validation_Name__c == null) missingFields.add('Seller Validator Name');
                    
                    /* -------- Unit Validation -------- */
                    if (sr.UnitId__c == null) {
                        missingFields.add('Unit');
                    } else {
                        Unit__c unitRec = unitMap.get(sr.UnitId__c);
                        if (unitRec == null) {
                            missingFields.add('Unit');
                        } else {
                            if (unitRec.GrossFloorAreaGFA__c == null) missingFields.add('Unit Gross Floor Area');
                            if (unitRec.ADM_Plot_Number__c == null) missingFields.add('Unit ADM Plot Number');
                            if (unitRec.AED_SQM__c == null) missingFields.add('Unit AED SQM');
                            if (unitRec.Sector__c == null) missingFields.add('Unit Sector');
                            if (unitRec.Location__c == null) missingFields.add('Unit Location');
                        }
                    }
                    
                    /* -------- Account Validation -------- */
                    if (sr.AccountId__c == null) {
                        missingFields.add('Account');
                    } else {
                        Account acc = accountMap.get(sr.AccountId__c);
                        if (acc == null) {
                            missingFields.add('Account');
                        } else {
                            if (!acc.IsPersonAccount) {
                                
                                if (acc.POARegistrationAuthority__c == null) missingFields.add('Account POA Registration Authority');
                                if (acc.Trade_License_Number__c == null) missingFields.add('Account Trade License Number');
                                if (acc.BillingAddress == null) missingFields.add('Account Billing Address');
                            }
                        }
                    }
                    
                    /* -------- Prospect Account Validation -------- */
                    Prospect_Account__c  pa = prospectBySR.get(sr.Id);
                    system.debug('pa--->'+pa);
                    if (pa == null) {
                        missingFields.add('Prospect Account');
                    } else {
                        if (pa.Account__c == null) missingFields.add('Prospect Account - Account');
                        if (pa.POARegistrationAuthority__c == null) missingFields.add('Prospect POA Registration Authority');
                        if (pa.UnifiedNumber__c == null) missingFields.add('Prospect Unified Number');
                        if (pa.BillingAddress__c == null) missingFields.add('Prospect Billing Address');
                    }
                    
                    /* -------- Error Message -------- */
                    if (!missingFields.isEmpty()) {
                        t.Status.addError(
                            'Document details are missing on Service Request. Please update: ' +
                            String.join(missingFields, ', ')
                        );
                    }
                }
            }
        }
    }
    
    /**
* Purpose      : Central document and charge validation method for the Property Transfer
*                Title Deed Commercial workflow. Validates each task step (1–10) when
*                its Status is set to Closed, enforcing step-specific document and
*                business rules before the step can be completed.
*
*                Step-by-step rules enforced:
*                  Step 1  — Third-party requests: Authorization Letter and Title Deed (Seller) required
*                  Step 2  — If Outstanding Charge > 0: Outstanding Invoice and NOC Fee Invoice required
*                  Step 3  — All docs in Label.Property_Transfer_Title_Deed_Docs must be uploaded
*                  Step 4  — Delegates to validateDocumentFields() for SR/Unit/Account/Prospect data
*                  Step 5  — NOC and Outstanding charges must be paid; payment receipts must be uploaded
*                  Step 6  — All DocuSign docs in Label.PropertyTransferDocusignDocs must be uploaded
*                            (skipped if SR.Is_Manual_Upload__c = true)
*                  Step 7  — SR.Signature_Status__c must be 'Fully Signed'
*                            (skipped if SR.Is_Manual_Upload__c = true)
*                  Step 8  — NOC document must be uploaded
*                  Step 10 — Title Deed (After Transfer) must be uploaded
*
* Business Rule: Only runs for ServiceRequest__c with Record Type =
*                SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL.
*                Errors are added directly to Task.Status — blocking step closure in UI and API.
*
* @param : serviceRequestRtName     - Set of SR record type developer names for the current context
* @param : docMap                   - Map<String, Documents__c> of SR documents keyed by document Name
* @param : tskMap                   - Map<String, Task> of tasks keyed by order number string
* @param : srRecordMap              - Map<Id, ServiceRequest__c> keyed by SR Id
* @param : titleDeedCommercialSRs   - List<ServiceRequest__c> of Title Deed Commercial SRs
* @param : chargeMap                - Map<Id, Charge__c> of unpaid charges keyed by SR Id
* @return                         void — errors added directly to Task.Status via addError()
*/
    public static void validatePropertyTransferSRDocuments(
        set<String> serviceRequestRtName, 
        Map<String, Documents__c> docMap, 
        Map<String, Task> tskMap,Map<Id, ServiceRequest__c> srRecordMap,List<ServiceRequest__c> titleDeedCommercialSRs,  Map<Id, charge__c> chargeMap
    ) {
        // Only run for Mortgage Registration SRs
        if (serviceRequestRtName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL)) {
            System.debug('salesOrderDocs----->' + docMap);
            
            for (String ordr : tskMap.keySet()) {
                System.debug('ordr---->' + ordr);
                
                Task task = tskMap.get(ordr);
                
                if (task.Status == Constants.TASK_STATUS_CLOSED){
                    if(!docMap.isEmpty()) {
                        if (ordr == '1' || ordr == '1.0') {
                            if (task.Requested_From__c == 'Third Party'  && (ordr == '1' || ordr == '1.0')) {
                                String[] requiredAuthDocs = Label.SR_Doc_Authorization_Letter_And_Title_Deed_Seller.split (',');
                                List<String> missingAuthAndTittleDeedDocs = new List<String> ();
                                
                                for (String doc: requiredAuthDocs)
                                {
                                    doc = doc.trim (); // Remove extra spaces
                                    System.debug('docMap--------------------->2239'+docMap);
                                    System.debug('doc--------------------->2239'+doc);
                                    if (!docMap.containsKey (doc) || docMap.get (doc).Status__c != 'Uploaded')
                                    {
                                        missingAuthAndTittleDeedDocs.add (doc);
                                    }
                                }
                                System.debug('missingTittleDeedDocs------------------->'+missingAuthAndTittleDeedDocs);
                                if (!missingAuthAndTittleDeedDocs.isEmpty ())
                                {
                                    String errorMessage = 'Please upload the ' + String.join (missingAuthAndTittleDeedDocs, ', ');
                                    tskMap.get (ordr).Status.addError (errorMessage);
                                }
                            }
                        }else  if (ordr == '2' || ordr == '2.0') {
                            
                            ServiceRequest__c srRec = srRecordMap.get(task.WhatId);
                            Decimal outstanding = srRec != null ? srRec.Outstanding_Charge__c : 0;
                            
                            if (outstanding != null && outstanding > 0) {
                                
                                List<String> missingDocs = new List<String>();
                                
                                if (!docMap.containsKey('Outstanding Invoice') ||
                                    docMap.get('Outstanding Invoice').Status__c != 'Uploaded') {
                                        missingDocs.add('Outstanding Invoice');
                                    }
                                
                                if (!docMap.containsKey('NOC Fee Invoice') ||
                                    docMap.get('NOC Fee Invoice').Status__c != 'Uploaded') {
                                        missingDocs.add('NOC Fee Invoice');
                                    }
                                
                                if (!missingDocs.isEmpty()) {
                                    String errorMessage = 'Please upload the ' + String.join(missingDocs, ', ');
                                    tskMap.get(ordr).Status.addError(errorMessage);
                                }
                            }
                        }
                        else if (ordr == '3' || ordr == '3.0')
                        {
                            
                            String[] requiredDocs = Label.Property_Transfer_Title_Deed_Docs.split (',');
                            List<String> missingTittleDeedDocs = new List<String> ();
                            
                            for (String doc: requiredDocs)
                            {
                                doc = doc.trim (); // Remove extra spaces
                                System.debug('docMap--------------------->2239'+docMap);
                                System.debug('doc--------------------->2239'+doc);
                                if (!docMap.containsKey (doc) || docMap.get (doc).Status__c != 'Uploaded')
                                {
                                    missingTittleDeedDocs.add (doc);
                                }
                            }
                            System.debug('missingTittleDeedDocs------------------->'+missingTittleDeedDocs);
                            if (!missingTittleDeedDocs.isEmpty ())
                            {
                                String errorMessage = 'Please upload the ' + String.join (missingTittleDeedDocs, ', ');
                                tskMap.get (ordr).Status.addError (errorMessage);
                            }
                        }
                        else if(ordr == '4' || ordr == '4.0'){
                            if (!titleDeedCommercialSRs.isEmpty()) {
                                System.debug('titleDeedCommercialSRs----->'+titleDeedCommercialSRs);
                                PropertyTransferTitleDeedController.validateDocumentFields(srRecordMap,titleDeedCommercialSRs, tskMap);
                            }
                            
                        }
                        else if (ordr == '5' || ordr == '5.0')
                        {
                            
                            
                            if (chargeMap.containsKey (tskMap.get (ordr).WhatId))
                            {
                                if (chargeMap.get (tskMap.get (ordr).WhatId).Name.Contains ('NOC'))
                                {
                                    tskMap.get (ordr).Status.addError ('Please update the ' + chargeMap.get (tskMap.get (ordr).WhatId).Name + ' charge status to paid: ');
                                }
                                if (chargeMap.get (tskMap.get (ordr).WhatId).Name.Contains ('Outstanding Charge'))
                                {
                                    tskMap.get (ordr).Status.addError ('Please update the ' + chargeMap.get (tskMap.get (ordr).WhatId).Name + ' charge status to paid: ');
                                }
                            }
                            /*if ((docMap.containsKey ('Payment Receipt')  && docMap.get ('Payment Receipt').Status__c!= 'Uploaded'))
{

tskMap.get (ordr).Status.addError ('Please Upload Payment Receipt');
}*/
                            List<String> missingReceipts = new List<String>();
                            
                            if (!docMap.containsKey('Outstanding Payment Receipt') ||
                                docMap.get('Outstanding Payment Receipt').Status__c != 'Uploaded')
                            {
                                missingReceipts.add('Outstanding Payment Receipt');
                            }
                            
                            if (!docMap.containsKey('NOC Payment Receipt') ||
                                docMap.get('NOC Payment Receipt').Status__c != 'Uploaded')
                            {
                                missingReceipts.add('NOC Payment Receipt');
                            }
                            
                            if (!missingReceipts.isEmpty())
                            {
                                String errorMessage = 'Please upload the ' + String.join(missingReceipts, ', ');
                                tskMap.get(ordr).Status.addError(errorMessage);
                            }
                        }
                        
                        ServiceRequest__c srRec = srRecordMap.get(task.WhatId);
                        Boolean skipValidation = (srRec != null && srRec.Is_Manual_Upload__c);
                        
                        if (!skipValidation) {
                            if (ordr == '6' || ordr == '6.0')
                            {
                                
                                String[] requiredDocusignDocs = Label.PropertyTransferDocusignDocs.split (',');
                                List<String> missingTittleDeedDocusignDocs = new List<String> ();
                                
                                for (String doc: requiredDocusignDocs)
                                {
                                    doc = doc.trim (); // Remove extra spaces
                                    System.debug('docMap--------------------->2239'+docMap);
                                    System.debug('doc--------------------->2239'+doc);
                                    if (!docMap.containsKey (doc) || docMap.get (doc).Status__c != 'Uploaded')
                                    {
                                        missingTittleDeedDocusignDocs.add (doc);
                                    }
                                }
                                System.debug('missingTittleDeedDocs------------------->'+missingTittleDeedDocusignDocs);
                                if (!missingTittleDeedDocusignDocs.isEmpty ())
                                {
                                    String errorMessage = 'Please Generate the ' + String.join (missingTittleDeedDocusignDocs, ', ');
                                    tskMap.get (ordr).Status.addError (errorMessage);
                                }
                            }
                            else if (ordr == '7' || ordr == '7.0') {
                                if (srRec == null || srRec.Signature_Status__c != 'Fully Signed') {
                                    tskMap.get(ordr).Status.addError(
                                        'Please sign the Deed of Adherence and Novation Agreement documents before proceeding.'
                                    );
                                }
                            }
                        }
                        else if (ordr == '8' || ordr == '8.0')
                        {
                            
                            
                            if (docMap.containsKey ('NOC') && docMap.get ('NOC').Status__c != 'Uploaded')
                            {
                                tskMap.get (ordr).Status.addError ('Please Generate the NOC Document on the SR');
                            }
                        }
                        else if (ordr == '10' || ordr == '10.0')
                        {
                            
                            
                            if (docMap.containsKey ('Title Deed (After Transfer)') && docMap.get ('Title Deed (After Transfer)').Status__c != 'Uploaded')
                            {
                                tskMap.get (ordr).Status.addError ('Please Upload the Title Deed Document on the SR');
                            }
                        }
                    }
                }
            }
        }
    }
    
    /**
* Purpose      : Sends the NOC Fee Invoice and (if applicable) the Outstanding Invoice
*                to the customer via email with PDF file attachments.
*                Validates document upload status before sending.
*                Resolves the correct Contact recipient from the linked Account.
* Business Rule: NOC Fee Invoice is always required and must be uploaded.
*                Outstanding Invoice is only required when Outstanding_Charge__c > 0.
*                Uses the email template defined in Custom Label: TitleDeedInvoiceEmailTemplate.
*                Returns a string status code — caller uses this to show user feedback.
*                Email is saved as an Activity (setSaveAsActivity = true).
* @param : serviceRequestId - Id of the ServiceRequest__c to send the invoice for
* @return String status code:
*         'EMAIL_SENT'                             — success
*         'INVALID_SERVICE_REQUEST_ID'             — null input
*         'PERSON_ACCOUNT_HAS_NO_CONTACT'         — person account missing PersonContactId
*         'NO_ACTIVE_CONTACT_FOUND'               — no active contact on business account
*         'ERROR_NOC_INVOICE_NOT_UPLOADED'        — NOC Fee Invoice doc not uploaded
*         'ERROR_OUTSTANDING_INVOICE_NOT_UPLOADED'— Outstanding Invoice not uploaded
*         'NO_FILES_FOUND'                        — no ContentDocument links found
*         'NO_CONTENTVERSION_FOUND'               — no file versions found
*         'EMAIL_TEMPLATE_NOT_FOUND'              — email template missing in org
*         'EMAIL_FAILED'                          — Salesforce email send failure
*         'EMAIL_EXCEPTION'                       — unexpected exception caught
*/
    @AuraEnabled
    public static String sendInvoiceToCustomer(Id serviceRequestId) {
        if (serviceRequestId == null) return 'INVALID_SERVICE_REQUEST_ID';
        
        try {
            
            /* -----------------------------
Step 1: Get Service Request
------------------------------*/
            ServiceRequest__c sr = [
                SELECT Id, AccountId__c, Outstanding_Charge__c
                FROM ServiceRequest__c
                WHERE Id = :serviceRequestId
                LIMIT 1
            ];
            
            Decimal outstanding = sr.Outstanding_Charge__c;
            Boolean isOutstandingRequired = (outstanding != null && outstanding > 0);
            
            /* -----------------------------
Step 2: Get Account
------------------------------*/
            Account acc = [
                SELECT Id, IsPersonAccount, PersonContactId
                FROM Account
                WHERE Id = :sr.AccountId__c
                LIMIT 1
            ];
            
            /* -----------------------------
Step 3: Determine Recipient
------------------------------*/
            Id targetId;
            if (acc.IsPersonAccount) {
                if (acc.PersonContactId == null) return 'PERSON_ACCOUNT_HAS_NO_CONTACT';
                targetId = acc.PersonContactId;
            } else {
                List<Contact> contacts = [
                    SELECT Id
                    FROM Contact
                    WHERE AccountId = :acc.Id
                    AND Is_Active__c = true
                    LIMIT 1
                ];
                if (contacts.isEmpty()) return 'NO_ACTIVE_CONTACT_FOUND';
                targetId = contacts[0].Id;
            }
            
            /* -----------------------------
Step 4: Fetch Documents
------------------------------*/
            List<Documents__c> docList = [
                SELECT Id, Name, Status__c
                FROM Documents__c
                WHERE Service_Request__c = :sr.Id
                AND Name IN ('NOC Fee Invoice', 'Outstanding Invoice')
            ];
            
            Map<String, Documents__c> docMap = new Map<String, Documents__c>();
            for (Documents__c d : docList) {
                docMap.put(d.Name, d);
            }
            
            /* -----------------------------
Step 5: Validations (LIKE YOUR PATTERN)
------------------------------*/
            
            // NOC Invoice must exist and must be Uploaded
            if (!docMap.containsKey('NOC Fee Invoice') ||
                (docMap.containsKey('NOC Fee Invoice') &&
                 docMap.get('NOC Fee Invoice').Status__c != 'Uploaded')) {
                     
                     return 'ERROR_NOC_INVOICE_NOT_UPLOADED';
                 }
            
            // Outstanding Invoice validation only when charge > 0
            if (isOutstandingRequired &&
                (!docMap.containsKey('Outstanding Invoice') ||
                 (docMap.containsKey('Outstanding Invoice') &&
                  docMap.get('Outstanding Invoice').Status__c != 'Uploaded'))) {
                      
                      return 'ERROR_OUTSTANDING_INVOICE_NOT_UPLOADED';
                  }
            
            /* -----------------------------
Step 6: Collect Valid Document Ids
------------------------------*/
            Set<Id> docIds = new Set<Id>();
            docIds.add(docMap.get('NOC Fee Invoice').Id);
            
            if (isOutstandingRequired) {
                docIds.add(docMap.get('Outstanding Invoice').Id);
            }
            
            /* -----------------------------
Step 7: Get Files
------------------------------*/
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :docIds
            ];
            
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink l : links) {
                contentDocIds.add(l.ContentDocumentId);
            }
            
            if (contentDocIds.isEmpty()) return 'NO_FILES_FOUND';
            
            List<ContentVersion> versions = [
                SELECT Title, VersionData, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                AND IsLatest = true
            ];
            
            if (versions.isEmpty()) return 'NO_CONTENTVERSION_FOUND';
            
            /* -----------------------------
Step 8: Get Email Template
------------------------------*/
            EmailTemplate template = [
                SELECT Id
                FROM EmailTemplate
                WHERE Name = :Label.TitleDeedInvoiceEmailTemplate
                LIMIT 1
            ];
            
            if (template == null) return 'EMAIL_TEMPLATE_NOT_FOUND';
            
            /* -----------------------------
Step 9: Prepare Email
------------------------------*/
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(targetId);
            email.setWhatId(sr.Id);
            email.setTemplateId(template.Id);
            email.setSaveAsActivity(true);
            
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            for (ContentVersion cv : versions) {
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setFileName(cv.Title + '.' + cv.FileExtension);
                efa.setBody(cv.VersionData);
                attachments.add(efa);
            }
            email.setFileAttachments(attachments);
            
            /* -----------------------------
Step 10: Send Email
------------------------------*/
            Messaging.SendEmailResult[] results =
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
            
            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) return 'EMAIL_FAILED';
            }
            
            return 'EMAIL_SENT';
            
        } catch (Exception e) {
            System.debug('Send invoice error: ' + e.getMessage());
            return 'EMAIL_EXCEPTION';
        }
    }    
}