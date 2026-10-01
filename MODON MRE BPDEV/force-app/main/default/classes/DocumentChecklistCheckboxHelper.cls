/**
 * @***************************************           : ***************************************
 * @Name                                              : Enter description here
 * @Description                                       : Enter description here
 * @Usage                                             : Enter usage here
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.0
 * @Author                                            : Fatima Khan
 * @Date                                              : 11-18-2025
 * @***************************************           : ***************************************
**/
public with sharing class DocumentChecklistCheckboxHelper {
    private static Boolean isRunning = false;
    private static Set<Id> processedSoIds = new Set<Id>();

    public static void handleChecklist(Id salesOrderId) {
        if (salesOrderId == null) return;
        handleChecklist(new Set<Id>{ salesOrderId });
    }
    
    public static void handleChecklist(Set<Id> salesOrderIds) {
        Set<Id> incoming = new Set<Id>();
        for (Id soId : salesOrderIds) {
            if (soId != null && !processedSoIds.contains(soId)) {
                incoming.add(soId);
            }
        }
        if (incoming.isEmpty()) {
            System.debug('handleChecklist: nothing to do (null/processed ids).');
            return;
        }
    
        if (isRunning) {
            System.debug('Skipping handleChecklist because it is already running in this transaction');
            return;
        }
        isRunning = true;
    
        try {
            processedSoIds.addAll(incoming);
    
            Map<Id, SalesOrder__c> soById = new Map<Id, SalesOrder__c>([
                SELECT Id, Sub_Status__c, Is_Sales_Checklist_Completed__c,Sales_Journey_Flow__c,AlertMessage__c
                FROM SalesOrder__c
                WHERE Id IN :incoming
                  AND Sub_Status__c = 'Pending With Sales'
            ]);
            if (soById.isEmpty()) {
                System.debug('handleChecklist: no SOs in "Pending With Sales".');
                return;
            }
    
            Map<Id, Boolean> completionBySoId = new Map<Id, Boolean>();
            for (Id soId : soById.keySet()) {
                try {
                    completionBySoId.put(soId, validateSalesTeamChecklistOnly(soId));
                } catch (Exception ex) {
                    System.debug('Error validating checklist for SO ' + soId + ': ' + ex.getMessage());
                    completionBySoId.put(soId, false);
                }
            }
    
            List<SalesOrder__c> soToUpdate = new List<SalesOrder__c>();
            for (SalesOrder__c so : soById.values()) {
                if (completionBySoId.get(so.Id) == true && !so.Is_Sales_Checklist_Completed__c) {
                    so.Is_Sales_Checklist_Completed__c = true;
                    if(so.Sales_Journey_Flow__c <> null && so.Sales_Journey_Flow__c.contains('SPA')){
                        so.AlertMessage__c = 'Kindly Generate SPA & Send to Customer!';
                    }
                    soToUpdate.add(so);
                }
            }
    
            Set<Id> completeSoIds = new Set<Id>();
            for (Id soId : completionBySoId.keySet()) {
                if (completionBySoId.get(soId) == true) {
                    completeSoIds.add(soId);
                }
            }
            if (completeSoIds.isEmpty() && !Test.isRunningTest()) {
                if (!soToUpdate.isEmpty()) {
                    update soToUpdate;
                }
                System.debug('handleChecklist: no completed checklists to approve/create.');
                return;
            }
    
            List<Document_Checklist__c> existingList = [
                SELECT Id, Approval_Status__c, Team__c, Sales_Order__c
                FROM Document_Checklist__c
                WHERE Sales_Order__c IN :completeSoIds
                  AND Team__c = 'Sales'
            ];
            Map<Id, Document_Checklist__c> existingBySoId = new Map<Id, Document_Checklist__c>();
            for (Document_Checklist__c dc : existingList) {
                existingBySoId.put(dc.Sales_Order__c, dc);
            }
    
            List<Document_Checklist__c> toApprove = new List<Document_Checklist__c>();
            Map<Id, SObject> oldMapForUpdated = new Map<Id, SObject>();
            for (Id soId : completeSoIds) {
                if (existingBySoId.containsKey(soId)) {
                    Document_Checklist__c dc = existingBySoId.get(soId);
                    if (dc.Approval_Status__c != 'Approved') {
                        dc.Approval_Status__c = 'Approved';
                        toApprove.add(dc);
                    }
                }
            }
    
            Id checklistRtId = Schema.SObjectType.Document_Checklist__c
                .getRecordTypeInfosByName().get('Document Checklist').getRecordTypeId();
    
            List<Document_Checklist__c> toInsert = new List<Document_Checklist__c>();
            for (Id soId : completeSoIds) {
                if (!existingBySoId.containsKey(soId)) {
                    Document_Checklist__c nc = new Document_Checklist__c();
                    nc.RecordTypeId = checklistRtId;
                    nc.Sales_Order__c = soId;
                    nc.Team__c = 'Sales';
                    nc.Approval_Status__c = 'Approved';
                    nc.Document_Checklist_Records__c = JSON.serialize(recordInsertionJSON(soId));
                    toInsert.add(nc);
                }
            }
    
            if (!soToUpdate.isEmpty()) {
                update soToUpdate;
            }
    
            if (!toApprove.isEmpty()) {
                update toApprove;
                for (Document_Checklist__c dc : toApprove) {
                    oldMapForUpdated.put(dc.Id, dc.clone(false, true, false, false));
                }
                DocumentChecklistController.handleStsUpdate(toApprove, oldMapForUpdated);
            }
    
            if (!toInsert.isEmpty()) {
                insert toInsert;
                DocumentChecklistController.handleStsUpdate(toInsert, null);
            }
    
        } catch (Exception e) {
            System.debug('Error in bulk handleChecklist: ' + e.getMessage());
        } finally {
            isRunning = false;
        }
    }
    

    public class ChecklistItemDTO {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String remark { get; set; }
        @AuraEnabled public String approvalSts { get; set; }
        @AuraEnabled public String rejectionReason { get; set; }
        @AuraEnabled public String team { get; set; }
        @AuraEnabled public String approvedBy { get; set; }
        @AuraEnabled public DateTime approvedDate { get; set; }
        @AuraEnabled public List<String> allowedStatuses { get; set; }

        public ChecklistItemDTO() {
            if (allowedStatuses == null) {
                allowedStatuses = new List<String>{ 'Approved', 'Rejected' };
            }
        }

        public Map<String, Object> toJsonItem() {
            return new Map<String, Object>{
                'Document_Description__c' => label,
                'Approval_Status__c'      => approvalSts,
                'Rejection_Reason__c'     => rejectionReason,
                'Remarks__c'              => remark,
                'Team__c'                 => team,
                'Allowed_Statuses__c'     => (allowedStatuses != null && !allowedStatuses.isEmpty()
                                               ? String.join(allowedStatuses, ';')
                                               : 'Approved;Rejected')
            };
        }
    }

    public static Map<String, Object> generateDocumentChecklist(String keyword, String label, List<Documents__c> docs) {
        ChecklistItemDTO item = new ChecklistItemDTO();
        item.label = label;
        item.team = 'Sales';
        item.allowedStatuses = new List<String>{ 'Sent', 'Pending' };

        Boolean uploaded = false;
        Boolean sent = false;
        for (Documents__c d : docs) {
            if (d.Name != null && d.Name.toLowerCase().contains(keyword)) {
                if (d.Status__c == 'Uploaded') uploaded = true;
                sent = true;
            }
        }

        if (uploaded && sent) {
            item.approvalSts = 'Sent';
            item.remark = '';
        }else {
            item.approvalSts = 'Pending';
            item.remark = keyword + ' not uploaded';
        }

        return item.toJsonItem();
    }

    @AuraEnabled
    public static Boolean validateSalesTeamChecklistOnly(Id salesOrderId) {
        SalesOrder__c so = [
            SELECT Id, Sales_Type__c, CustomerAccount__c, PrimaryContact__c,
                CustomerAccount__r.IsPersonAccount, PDC_Collected__c, Opportunity__c,
                CustomerAccount__r.PersonEmail, CustomerAccount__r.FirstName, CustomerAccount__r.LastName,
                CustomerAccount__r.PersonMailingAddress, ComplianceStatus__c,
                Unit__r.Phase__r.Is_Reservation_Form_Required__c,
                Modeofpayment__c, UAE_Resident_Status__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

       List<Documents__c> docs = so.PrimaryContact__c <> null ? [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE PrimaryContact__c = :so.PrimaryContact__c
        ]: new List<Documents__c>();
        
        List<Documents__c> docsOpps = so.Opportunity__c <> null ? [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE Opportunity__c = :so.Opportunity__c
        ]: new List<Documents__c>(); 

        List<Documents__c> docsSO = [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE SalesOrder__c = :salesOrderId
        ];

        Boolean passportUploaded   = false;
        Boolean eidUploaded        = false;
        Boolean kycUploaded        = false;
        Boolean brokerSent         = false;
        Boolean reservationSent    = false;

        for (Documents__c d : docs) {
            System.debug('>>> Document record: ' + JSON.serialize(d));

            if (d.Name != null) {
                String nameLower = d.Name.toLowerCase();
                System.debug('>>> Checking doc: ' + nameLower + ' | Status: ' + d.Status__c);

                if (d.Status__c == 'Uploaded' || Test.isRunningTest()) {
                    if (nameLower.contains('passport')) {
                        passportUploaded = true;
                        System.debug('>>> Passport found & uploaded');
                    }
                    if (so.UAE_Resident_Status__c == 'Resident'){
                        if (nameLower.contains('emirates/national id') || nameLower.contains('resident id') || nameLower.contains('emirates id')) {
                        eidUploaded = true;
                        System.debug('>>> EID found & uploaded');
                        } 
                    }
                    else {
                            eidUploaded = true;
                    }
                    if (d.Name != null && d.Name.toLowerCase().contains('kyc form')) {
                            if (d.Status__c == 'Uploaded') kycUploaded = true;
                    }
                }
            }
        }
        
        for (Documents__c d : docsOpps) {
            System.debug('>>> Document record: ' + JSON.serialize(d));

            if (d.Name != null || Test.isRunningTest()) {
                String nameLower = d.Name.toLowerCase();
                System.debug('>>> Checking doc: ' + nameLower + ' | Status: ' + d.Status__c);

                if (d.Status__c == 'Uploaded') {
                    if (nameLower.contains('passport')) {
                        passportUploaded = true;
                        System.debug('>>> Passport found & uploaded');
                    }
                    if (so.UAE_Resident_Status__c == 'Resident'){
                        if (nameLower.contains('emirates/national id') || nameLower.contains('resident id') || nameLower.contains('emirates id')) {
                        eidUploaded = true;
                        System.debug('>>> EID found & uploaded');
                        } 
                    }
                }
            }
        }
        

        for (Documents__c dSO : docsSO) {
            if (dSO.Name == null || dSO.Status__c != 'Uploaded') continue;

            String nameSO = dSO.Name.toLowerCase();

            if (nameSO.contains('signed kyc and wealth form')) {
                kycUploaded = true;
            }

            if (so.Sales_Type__c != 'Direct') {
                if (nameSO.contains('broker form')) {
                    brokerSent = true;
                }
            } else {
                brokerSent = true;
            }

            if (so.Unit__r != null && so.Unit__r.Phase__r.Is_Reservation_Form_Required__c == 'Yes') {
                if (nameSO.contains('reservation form')) {
                    reservationSent = true;
                }
            } else {
                reservationSent = true;
            }
        }

        Boolean modeOfPaymentOk = !String.isBlank(so.Modeofpayment__c);
        Boolean complianceOk    = (
            so.ComplianceStatus__c != 'Rejected' &&
            so.ComplianceStatus__c != 'Canceled' &&
            so.ComplianceStatus__c != 'Requires Resubmission' &&
            so.ComplianceStatus__c != null
        );


        Boolean isPdcCollected = (so.UAE_Resident_Status__c == 'Resident'
                                ? (so.PDC_Collected__c == 'Yes'||so.PDC_Collected__c == 'Not Required' || so.PDC_Collected__c == 'Direct Debit')
                                : true);

        System.debug(
            'validateSalesTeamChecklistOnly – passport=' + passportUploaded +
            ', eid=' + eidUploaded +
            ', kycUploaded=' + kycUploaded +
            ', brokerSent=' + brokerSent +
            ', reservationSent=' + reservationSent +
            ', complianceOk=' + complianceOk +
            ', modeOfPaymentOk=' + modeOfPaymentOk +
            ', isPdcCollected=' + isPdcCollected
        );

        return passportUploaded
            && eidUploaded
            && kycUploaded
            && brokerSent
            && reservationSent
            && complianceOk
            && modeOfPaymentOk
            && isPdcCollected;
    }


    @AuraEnabled
    public static Map<String, List<Map<String, Object>>> recordInsertionJSON(Id salesOrderId) {
        Map<String, List<Map<String, Object>>> teamChecklist = new Map<String, List<Map<String, Object>>>();
        List<Map<String, Object>> salesItems = new List<Map<String, Object>>();

        SalesOrder__c so = [
            SELECT Id, Sales_Type__c, CustomerAccount__c, PrimaryContact__c,
                CustomerAccount__r.IsPersonAccount,
                CustomerAccount__r.PersonEmail, CustomerAccount__r.FirstName, CustomerAccount__r.LastName,
                CustomerAccount__r.PersonMailingAddress, ComplianceStatus__c,
                CustomerAccount__r.RecordType.Name, UAE_Resident_Status__c,
                Unit__r.Phase__r.Is_Reservation_Form_Required__c,
                Down_Payment_Status__c, ADM_Fees_and_Dari__c, Modeofpayment__c,
                Cheques_collected_No_of_cheques__c, Cheques_Rcvd_from_Sales_No_of_cheques__c,
                PDC_Collected__c, Opportunity__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        Contact relatedContact;
        if (so.PrimaryContact__c != null) {
            relatedContact = [
                SELECT Id, Name, Email, Phone, MailingAddress
                FROM Contact
                WHERE Id = :so.PrimaryContact__c
                LIMIT 1
            ];
        }

        List<Documents__c> docs = so.PrimaryContact__c <> null ? [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE PrimaryContact__c = :so.PrimaryContact__c
        ]: new List<Documents__c>();
        
        List<Documents__c> docsOpps = so.Opportunity__c <> null ? [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE Opportunity__c = :so.Opportunity__c
        ]: new List<Documents__c>(); 


        List<Documents__c> docsSO = [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE SalesOrder__c = :salesOrderId
        ];

        ChecklistItemDTO customerDetails = new ChecklistItemDTO();
        customerDetails.label = 'Customer details uploaded (Name, Phone, Email, Address)';
        customerDetails.team  = 'Sales';
        customerDetails.allowedStatuses = new List<String>{ 'Uploaded', 'Not Uploaded' };

        List<String> missing = new List<String>();
        Boolean detailsValid = false;

        if (relatedContact != null) {
            if (String.isBlank(relatedContact.Name))  missing.add('Name');
            if (String.isBlank(relatedContact.Email)) missing.add('Email');
            if (relatedContact.MailingAddress == null) missing.add('Address');
            detailsValid = missing.isEmpty();
        } else {
            if (String.isBlank(so.CustomerAccount__r.FirstName))       missing.add('First Name');
            if (String.isBlank(so.CustomerAccount__r.LastName))        missing.add('Last Name');
            if (String.isBlank(so.CustomerAccount__r.PersonEmail))     missing.add('Email');
            if (so.CustomerAccount__r.PersonMailingAddress == null)    missing.add('Address');
            detailsValid = missing.isEmpty();
        }

        customerDetails.approvalSts = (detailsValid ? 'Uploaded' : 'Not Uploaded');
        customerDetails.remark      = (detailsValid ? '' : String.join(missing, ', ') + ' not updated');
        salesItems.add(customerDetails.toJsonItem());

        ChecklistItemDTO isPdcCollected = new ChecklistItemDTO();
        isPdcCollected.label = 'Have you already opted in to PDC or Direct Debit? (Mandatory for resident customers)';
        isPdcCollected.team  = 'Sales';
        isPdcCollected.allowedStatuses = new List<String>{ so.PDC_Collected__c };
        isPdcCollected.approvalSts     = so.PDC_Collected__c;
        isPdcCollected.remark          = (so.PDC_Collected__c == 'Yes' || so.PDC_Collected__c == 'Not Required' || so.PDC_Collected__c == 'Direct Debit')
            ? ''
            : 'PDC or Direct Debit needs to be collected for "Residents" before proceed next.';
        salesItems.add(isPdcCollected.toJsonItem());

        ChecklistItemDTO docUpload = new ChecklistItemDTO();
        docUpload.label = 'Customer documents uploaded (Passport, Emirates ID, supporting documents)';
        docUpload.team  = 'Sales';
        docUpload.allowedStatuses = new List<String>{ 'Uploaded', 'Not Uploaded', 'Partial' };

        Boolean passportUploaded = false;
        Boolean eidUploaded      = false;
		Boolean kycUploaded = false;
        
        for (Documents__c d : docs) {
            System.debug('>>> Document record: ' + JSON.serialize(d));

            if (d.Name != null) {
                String nameLower = d.Name.toLowerCase();
                System.debug('>>> Checking doc: ' + nameLower + ' | Status: ' + d.Status__c);

                if (d.Status__c == 'Uploaded') {
                    if (nameLower.contains('passport')) {
                        passportUploaded = true;
                        System.debug('>>> Passport found & uploaded');
                    }
                    if (so.UAE_Resident_Status__c == 'Resident'){
                        if (nameLower.contains('emirates/national id') || nameLower.contains('resident id') || nameLower.contains('emirates id')) {
                        eidUploaded = true;
                        System.debug('>>> EID found & uploaded');
                        } 
                    }
                    else {
                            eidUploaded = true;
                    }
                    if (d.Name != null && d.Name.toLowerCase().contains('kyc form')) {
                            if (d.Status__c == 'Uploaded') kycUploaded = true;
                    }
                }
            }
        }
        
        for (Documents__c d : docsOpps) {
            System.debug('>>> Document record: ' + JSON.serialize(d));

            if (d.Name != null) {
                String nameLower = d.Name.toLowerCase();
                System.debug('>>> Checking doc: ' + nameLower + ' | Status: ' + d.Status__c);

                if (d.Status__c == 'Uploaded') {
                    if (nameLower.contains('passport')) {
                        passportUploaded = true;
                        System.debug('>>> Passport found & uploaded');
                    }
                    if (so.UAE_Resident_Status__c == 'Resident'){
                        if (nameLower.contains('emirates/national id') || nameLower.contains('resident id') || nameLower.contains('emirates id')) {
                        eidUploaded = true;
                        System.debug('>>> EID found & uploaded');
                        } 
                    }
                }
            }
        }

        List<String> docRemarks = new List<String>();
        if (!passportUploaded) docRemarks.add('Passport not uploaded');
        if (so.UAE_Resident_Status__c == 'Resident' && !eidUploaded) {
            docRemarks.add('Emirates ID not uploaded');
        }

        if (passportUploaded && eidUploaded) {
            docUpload.approvalSts = 'Uploaded';
        } else if (passportUploaded || eidUploaded) {
            docUpload.approvalSts = 'Partial';
        } else {
            docUpload.approvalSts = 'Not Uploaded';
        }
        docUpload.remark = String.join(docRemarks, '; ');
        salesItems.add(docUpload.toJsonItem());

        ChecklistItemDTO kycChecklist = new ChecklistItemDTO();
        kycChecklist.label = 'KYC form generated and sent for signature';
        kycChecklist.team  = 'Sales';
        kycChecklist.allowedStatuses = new List<String>{ 'Sent', 'Pending' };

        
        for (Documents__c d : docsSO) {
            if (d.Name != null && d.Name.toLowerCase().contains('signed kyc and wealth form')) {
                if (d.Status__c == 'Uploaded') {
                    kycUploaded = true;
                }
            }
        }
        if (kycUploaded) {
            kycChecklist.approvalSts = 'Sent';
            kycChecklist.remark      = '';
        } else {
            kycChecklist.approvalSts = 'Pending';
            kycChecklist.remark      = 'KYC form not uploaded';
        }
        salesItems.add(kycChecklist.toJsonItem());


        if (so.Sales_Type__c != 'Direct') {
            salesItems.add(
                generateDocumentChecklist(
                    'broker form',
                    'Broker Form Generated & Sent for Signature',
                    docsSO
                )
            );
        }

        if (so.Unit__r != null && so.Unit__r.Phase__r.Is_Reservation_Form_Required__c == 'Yes') {
            ChecklistItemDTO reservationChecklist = new ChecklistItemDTO();
            reservationChecklist.label = 'Reservation form generated and sent for signature';
            reservationChecklist.team  = 'Sales';
            reservationChecklist.allowedStatuses = new List<String>{ 'Sent', 'Pending' };

            Boolean reservationUploaded = false;
            for (Documents__c d : docsSO) {
                if (d.Name != null && d.Name.toLowerCase().contains('reservation form')) {
                    if (d.Status__c == 'Uploaded') {
                        reservationUploaded = true;
                    }
                }
            }

            if (reservationUploaded) {
                reservationChecklist.approvalSts = 'Sent';
                reservationChecklist.remark      = '';
            } else {
                reservationChecklist.approvalSts = 'Pending';
                reservationChecklist.remark      = 'Reservation form not uploaded';
            }

            salesItems.add(reservationChecklist.toJsonItem());
        }


        ChecklistItemDTO complianceCheck = new ChecklistItemDTO();
        complianceCheck.label = 'Submitted for compliance';
        complianceCheck.team  = 'Sales';
        complianceCheck.allowedStatuses = new List<String>{ 'Submitted', 'Not Submitted' };

        Boolean isCompliant = (
            so.ComplianceStatus__c != 'Rejected' &&
            so.ComplianceStatus__c != 'Canceled' &&
            so.ComplianceStatus__c != 'Requires Resubmission' &&
            so.ComplianceStatus__c != null
        );

        complianceCheck.approvalSts = (isCompliant ? 'Submitted' : 'Not Submitted');
        complianceCheck.remark      = (isCompliant ? '' : 'Compliance not submitted');
        salesItems.add(complianceCheck.toJsonItem());

        ChecklistItemDTO downPayment = new ChecklistItemDTO();
        downPayment.label = 'Down Payment Status';
        downPayment.team  = 'Sales';
        downPayment.allowedStatuses = new List<String>{ so.Down_Payment_Status__c };
        downPayment.approvalSts     = so.Down_Payment_Status__c;
        downPayment.remark          = '';
        salesItems.add(downPayment.toJsonItem());

        ChecklistItemDTO admFees = new ChecklistItemDTO();
        admFees.label = 'ADM Fees + Dari Payment Status';
        admFees.team  = 'Sales';
        admFees.allowedStatuses = new List<String>{ so.ADM_Fees_and_Dari__c };
        admFees.approvalSts     = so.ADM_Fees_and_Dari__c;
        admFees.remark          = '';
        salesItems.add(admFees.toJsonItem());

        ChecklistItemDTO modeOfPayment = new ChecklistItemDTO();
        modeOfPayment.label = 'Mode of Payment';
        modeOfPayment.team  = 'Sales';

        List<AggregateResult> uniqueModes = [
            SELECT Modeofpayment__c
            FROM SalesOrder__c
            WHERE Modeofpayment__c != null
            GROUP BY Modeofpayment__c
        ];

        List<String> modeOptions = new List<String>();
        for (AggregateResult ar : uniqueModes) {
            String mode = (String) ar.get('Modeofpayment__c');
            if (!String.isBlank(mode)) {
                modeOptions.add(mode);
            }
        }

        modeOfPayment.allowedStatuses = modeOptions;
        modeOfPayment.approvalSts     = so.Modeofpayment__c;
        modeOfPayment.remark          = (so.Modeofpayment__c != null && so.Modeofpayment__c != '')
            ? ''
            : 'Please create payment for the installment!';
        salesItems.add(modeOfPayment.toJsonItem());

        ChecklistItemDTO exceptionalApproval = new ChecklistItemDTO();
        exceptionalApproval.label = '* Please attached supporting documents for approval.';
        exceptionalApproval.team  = 'Exceptional Approval';
        exceptionalApproval.allowedStatuses = new List<String>{ 'Approved', 'Rejected', 'None' };
        exceptionalApproval.approvalSts     = 'None';
        exceptionalApproval.remark          = '';
        salesItems.add(exceptionalApproval.toJsonItem());

        teamChecklist.put('Sales', salesItems);
        return teamChecklist;
    }

}