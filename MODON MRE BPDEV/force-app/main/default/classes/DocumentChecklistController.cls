/**********************************************************************************************************************
* Name               : DocumentChecklistController                                                        
* Description        : This class is used as a helper for manage the DocumentChecklist in Sales Order Level
* Created By         : ActiveMinds                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Fatima Khan                                 18 Nov 2025     Initial Draft 
* 2.0           Fatima Khan                                 10 Apr 2026     Bug fixed on the Sales Team Doc Checklist Saving Part
* 3.0           Aurelix IT                                  06 Aug 2026     Payment validation before the Finance hand-off
*                                                                          (Modon feedback #13). sendToNextTeam now refuses
*                                                                          an approval routed to Finance while the down
*                                                                          payment or ADM & Dari fee is still uncollected,
*                                                                          honouring the existing
*                                                                          IsADMCollectedWithWaiverRequest__c waiver.
******************************************************************************************************************/
public with sharing class DocumentChecklistController {

    @AuraEnabled(cacheable = true)
    public static SalesOrder__c getSalesOrderDetails(Id recordId) {
        List<SalesOrder__c> results = [
            SELECT Id, Name, CustomerAccount__r.Name, Owner.Name, ProjectName__c,
                   Unit__r.Name, Booking_Date__c, Sub_Status__c, UAE_Resident_Status__c,
                   Sales_Type__c, Unit__r.Phase__r.Is_Reservation_Form_Required__c,
                   Down_Payment_Status__c, ADM_Fees_and_Dari__c, 
                   Cheques_collected_No_of_cheques__c, Cheques_Rcvd_from_Sales_No_of_cheques__c
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        return (results.isEmpty() ? null : results[0]);
    }

    public class ChecklistWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public List<String> rejectionReasons;
        @AuraEnabled public Boolean forResidents;
        @AuraEnabled public Boolean forNonResidents;
        @AuraEnabled public List<String> allowedStatuses;

        public ChecklistWrapper(String id, String label, List<String> rejectionReasons, Boolean forResidents, Boolean forNonResidents) {
            this.id = id;
            this.label = label;
            this.rejectionReasons = rejectionReasons;
            this.forResidents = forResidents;
            this.forNonResidents = forNonResidents;
            this.allowedStatuses = new List<String>{ 'Approved', 'Rejected' };
        }

        public ChecklistWrapper(String id, String label, List<String> rejectionReasons, Boolean forResidents, Boolean forNonResidents, List<String> allowedStatuses) {
            this.id = id;
            this.label = label;
            this.rejectionReasons = rejectionReasons;
            this.forResidents = forResidents;
            this.forNonResidents = forNonResidents;
            this.allowedStatuses = (allowedStatuses != null ? allowedStatuses : new List<String>{ 'Approved', 'Rejected' });
        }
    }

    @AuraEnabled
    public static Map<String, List<ChecklistWrapper>> getDocumentChecklistMetadata(String residentStatus, Boolean isReservationRequired, String salesType) {
        List<Document_Checklists__mdt> records = [
            SELECT Sr_No__c, Document_Description__c, Department__c, Is_Active__c, Object__c,
                   Rejection_Reason__c, For_Residents__c, For_Non_Residents__c
            FROM Document_Checklists__mdt
            WHERE Is_Active__c = true AND Object__c = 'Sales Order'
            ORDER BY Sr_No__c ASC
        ];

        Map<String, List<ChecklistWrapper>> checklistByDepartment = new Map<String, List<ChecklistWrapper>>();

        for (Document_Checklists__mdt record : records) {
            if (residentStatus == 'Resident' && !record.For_Residents__c) continue;
            if (residentStatus == 'Non-Resident' && !record.For_Non_Residents__c) continue;
            if (!isReservationRequired && record.Document_Description__c == 'Reservation form generated and sent for signature') continue;
            if (salesType == 'Direct' && record.Document_Description__c == 'Broker Form Generated & Sent for Signature') continue;

            String dept = record.Department__c;
            if (!checklistByDepartment.containsKey(dept)) {
                checklistByDepartment.put(dept, new List<ChecklistWrapper>());
            }

            List<String> rejectionList = (record.Rejection_Reason__c != null
                                          ? record.Rejection_Reason__c.split('; ')
                                          : new List<String>());

            checklistByDepartment.get(dept).add(
                new ChecklistWrapper(
                    String.valueOf(record.Sr_No__c),
                    record.Document_Description__c,
                    rejectionList,
                    record.For_Residents__c,
                    record.For_Non_Residents__c,
                    new List<String>{ 'Approved', 'Rejected' }
                )
            );
            if (record.Department__c == 'Exceptional Approval') {
                ChecklistWrapper wrapper = checklistByDepartment.get(dept).get(
                    checklistByDepartment.get(dept).size() - 1
                );
                ChecklistItemDTO dto = new ChecklistItemDTO();
                dto.label = wrapper.label;
                dto.team = 'Exceptional Approval';
                dto.allowedStatuses = new List<String>{ 'Approved', 'Rejected', 'None' };
            }
        }
            
        if (!checklistByDepartment.containsKey('Exceptional Approval')) {
            checklistByDepartment.put('Exceptional Approval', new List<ChecklistWrapper>());
        }

        Boolean alreadyExists = false;
        for (ChecklistWrapper cw : checklistByDepartment.get('Exceptional Approval')) {
            if (cw.label == '* Please attached supporting documents for approval.') {
                alreadyExists = true;
                break;
            }
        }

        if (!alreadyExists) {
            checklistByDepartment.get('Exceptional Approval').add(
                new ChecklistWrapper(
                    'EXC-001',
                    '* Please attached supporting documents for approval.',
                    new List<String>(),
                    true,
                    true,
                    new List<String>{ 'Approved', 'Rejected', 'None' }
                )
            );
        }


        return checklistByDepartment;
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
                'Rejection_Reason__c'      => rejectionReason,
                'Remarks__c'               => remark,
                'Team__c'                  => team,
                'Allowed_Statuses__c' => (allowedStatuses != null && !allowedStatuses.isEmpty()
                ? String.join(allowedStatuses, ';')
                : null)
            };
        }
    }

    

   



    @AuraEnabled(cacheable = true)
    public static String getSalesOrderSubStatus(Id recordId) {
        SalesOrder__c so = [
            SELECT Status__c
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        return so.Status__c;
    }



    @AuraEnabled
    public static Map<String, Object> getLatestChecklistMap(Id salesOrderId) {
        Map<String, Map<String, ChecklistItemDTO>> teamChecklistMap = new Map<String, Map<String, ChecklistItemDTO>>();

        List<Document_Checklist__c> latestRecords = [
            SELECT Team__c, Document_Checklist_Records__c, Approve_Reject_By__r.Name, Approve_Rejected_Date_Time__c
            FROM Document_Checklist__c
            WHERE Sales_Order__c = :salesOrderId
            ORDER BY Approve_Rejected_Date_Time__c DESC
        ];

        Set<String> seen = new Set<String>();

        for (Document_Checklist__c record : latestRecords) {
            if (String.isBlank(record.Document_Checklist_Records__c)) continue;

            Object parsed = JSON.deserializeUntyped(record.Document_Checklist_Records__c);
            if (!(parsed instanceof Map<String, Object>)) continue;

            Map<String, Object> rawMap = (Map<String, Object>) parsed;

            for (String teamKey : rawMap.keySet()) {
                if (!teamChecklistMap.containsKey(teamKey)) {
                    teamChecklistMap.put(teamKey, new Map<String, ChecklistItemDTO>());
                }
                List<Object> items = (List<Object>) rawMap.get(teamKey);
                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    String docDesc = (String) item.get('Document_Description__c');
                    if (String.isBlank(docDesc)) continue;

                    String uniqueKey = teamKey + '|' + docDesc;
                    if (seen.contains(uniqueKey)) continue;
                    seen.add(uniqueKey);

                    ChecklistItemDTO dto = new ChecklistItemDTO();
                    dto.label = docDesc;
                    dto.approvalSts = (String) item.get('Approval_Status__c');
                    dto.rejectionReason = (String) item.get('Rejection_Reason__c');
                    dto.remark = (String) item.get('Remarks__c');
                    dto.team = teamKey;
                    dto.approvedBy = (record.Approve_Reject_By__r != null ? record.Approve_Reject_By__r.Name : null);
                    dto.approvedDate = record.Approve_Rejected_Date_Time__c;
                    dto.allowedStatuses = (String.isNotBlank((String)item.get('Allowed_Statuses__c'))
                                            ? ((String)item.get('Allowed_Statuses__c')).split(';')
                                            : new List<String>{ 'Approved', 'Rejected' });
                    teamChecklistMap.get(teamKey).put(docDesc, dto);
                }
            }
        }

        return new Map<String, Object>{ 'teamChecklistMap' => teamChecklistMap };
    }

   


    /*** 3.0  Start — Aurelix IT 06 Aug 2026, Modon feedback #13 *******************/
    /**
     * Returns a blocking message when a hand-off presumes money that has not arrived,
     * null when it may proceed. Only the stages that actually presume collected funds
     * are gated - Sales to Sales Operations document review is not a money event.
     *
     * Honours the existing IsADMCollectedWithWaiverRequest__c waiver, so an approved
     * waiver is not re-blocked here.
     */
    @TestVisible
    private static String paymentGateMessage(Id salesOrderId, String nextTeam) {
        if (salesOrderId == null) {
            return null;
        }
        // Finance verification is the point at which funds are assumed present.
        if (nextTeam != 'Finance') {
            return null;
        }

        List<SalesOrder__c> orders = [
            SELECT Id, Down_Payment_Status__c, ADM_Fees_and_Dari__c,
                   IsADMCollectedWithWaiverRequest__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return null;
        }
        SalesOrder__c so = orders[0];

        Set<String> settled = new Set<String>{ 'Collected', 'Paid' };
        List<String> missing = new List<String>();

        if (!settled.contains(so.Down_Payment_Status__c)) {
            missing.add('the down payment');
        }
        Boolean admWaived = so.IsADMCollectedWithWaiverRequest__c == true;
        if (!admWaived && !settled.contains(so.ADM_Fees_and_Dari__c)) {
            missing.add('the ADM registration fee');
        }

        if (missing.isEmpty()) {
            return null;
        }
        return 'This booking cannot move to Finance until ' +
            String.join(missing, ' and ') +
            ' has been received. Record the payment first, or raise a waiver request.';
    }
    /*** 3.0  End *******************/

    @AuraEnabled
    public static String sendToNextTeam(Id salesOrderId, List<ChecklistItemDTO> items, String popupRemark, Boolean isApproval) {
        if (salesOrderId == null) {
            throw new AuraHandledException('Missing Sales Order Id.');
        }

        String currentTeam = getTeamFromSalesOrder(salesOrderId);
        Id userId = UserInfo.getUserId();
        DateTime now = System.now();
        String nextTeam = getNextTeamFor(currentTeam);

        /*** 3.0  Start — Aurelix IT 06 Aug 2026 *******************/
        // Payment validation before the booking progresses (Modon feedback #13).
        // sendToNextTeam is the single choke point - internal UI, console, approval
        // trigger and batch jobs all pass through it, so a gate in any one caller
        // would be bypassed by the others.
        //
        // Not a validation rule: updateSOSubStatus bulk-updates, so a VR would surface
        // as opaque partial failures and could deadlock the Allocation__c chain.
        if (isApproval == true) {
            String moneyBlock = paymentGateMessage(salesOrderId, nextTeam);
            if (String.isNotBlank(moneyBlock)) {
                throw new AuraHandledException(moneyBlock);
            }
        }
        /*** 3.0  End *******************/

        System.debug('==[DEBUG] sendToNextTeam START==');
        System.debug('Current Team: ' + currentTeam + ', Next Team: ' + nextTeam + ', Popup Remark: ' + popupRemark + ', isApproval: ' + isApproval);

        Map<String, List<Map<String, Object>>> checklistMap = new Map<String, List<Map<String, Object>>>();
        Map<String, Set<String>> remarksByTeam = new Map<String, Set<String>>();

        SalesOrder__c soUpdate = new SalesOrder__c(Id = salesOrderId);
        Boolean chequeCollectedTouched = false;
        Boolean chequeReceivedTouched = false;

        if (items != null) {
            for (ChecklistItemDTO item : items) {
                if (item == null || String.isBlank(item.label)) continue;

                String teamKey = String.isBlank(item.team) ? currentTeam : item.team;
                if (teamKey != currentTeam && teamKey != 'Exceptional Approval') continue;

                if (!checklistMap.containsKey(teamKey)) {
                    checklistMap.put(teamKey, new List<Map<String, Object>>());
                }
                checklistMap.get(teamKey).add(item.toJsonItem());

                if (!remarksByTeam.containsKey(teamKey)) {
                    remarksByTeam.put(teamKey, new Set<String>());
                }
                if (!String.isBlank(item.remark)) {
                    remarksByTeam.get(teamKey).add(item.remark.trim());
                }

                if (item.label != null && item.label.contains('Cheques collected')) {
                    chequeCollectedTouched = true;
                    if (!String.isBlank(item.remark)) {
                        soUpdate.Cheques_collected_No_of_cheques__c = String.valueOf(item.remark);
                    } else if (item.approvalSts == 'Not Collected') {
                        soUpdate.Cheques_collected_No_of_cheques__c = null;
                    }
                }

                if (item.label != null && item.label.contains('Cheques received from Sales Team')) {
                    chequeReceivedTouched = true;
                    if (!String.isBlank(item.remark)) {
                        soUpdate.Cheques_Rcvd_from_Sales_No_of_cheques__c = String.valueOf(item.remark);
                    } else if (item.approvalSts == 'Not Received') {
                        soUpdate.Cheques_Rcvd_from_Sales_No_of_cheques__c = null;
                    }
                }
            }
        }

        if (currentTeam == 'Sales' && !String.isBlank(popupRemark)) {
            soUpdate.Sales_Remarks__c = popupRemark.trim();
        } else {
            for (String teamKey : remarksByTeam.keySet()) {
                String joined = String.join(new List<String>(remarksByTeam.get(teamKey)), ';');
                if (String.isBlank(joined)) continue;

                if (teamKey == 'Sales') {
                    soUpdate.Sales_Remarks__c = joined;
                } else if (teamKey == 'Sales Operation') {
                    soUpdate.Sales_Operation_Remarks__c = joined;
                } else if (teamKey == 'Finance') {
                    soUpdate.Finance_Remarks__c = joined;
                } else if (teamKey == 'Customer Management') {
                    soUpdate.Customer_Management_Remarks__c = joined;
                }
            }
        }
        Map<Id,SalesOrder__c> soMap = new Map<Id,SalesOrder__c>();
        if (currentTeam == 'Sales' && isApproval == true) {
            SalesOrder__c so = [SELECT Id, Status__c,Sub_Status__c, Is_Sales_Checklist_Completed__c,Sales_Journey_Flow__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
            if ((so.Sub_Status__c == 'Pending with Sales' && so.Is_Sales_Checklist_Completed__c == false ) || so.Sub_Status__c == 'Pending With Sales Team') { /**2.0 Bug fixed on the Sales Team Doc Checklist Saving Part**/
                soUpdate.Is_Sales_Checklist_Completed__c = true;
                if(so.Sales_Journey_Flow__c <> null && so.Sales_Journey_Flow__c.contains('SPA')){
                	soUpdate.AlertMessage__c = 'Kindly Generate SPA & Send to Customer!';
                }
                soMap.put(so.Id,so);
            }/*else if(so.Sub_Status__c == 'Pending with Sales' && so.Is_Sales_Checklist_Completed__c == true){
                 soMap.put(so.Id,so);
            }*/
        }
       

        if (!checklistMap.isEmpty()) {
            Id checklistRtId = Schema.SObjectType.Document_Checklist__c
                .getRecordTypeInfosByName().get('Document Checklist').getRecordTypeId();

            Document_Checklist__c checklistRec = new Document_Checklist__c();
            checklistRec.RecordTypeId = checklistRtId;
            checklistRec.Sales_Order__c = salesOrderId;
            checklistRec.Team__c = currentTeam;
            checklistRec.Approve_Reject_By__c = userId;
            checklistRec.Approve_Rejected_Date_Time__c = now;
            checklistRec.Document_Checklist_Records__c = JSON.serialize(checklistMap);

            checklistRec.Approval_Status__c = (isApproval == null
                                            ? 'In Progress'
                                            : (isApproval ? 'Approved' : 'Rejected'));
            if( currentTeam != 'Sales' || (currentTeam == 'Sales' && soMap.containsKey(salesOrderId))){ /**2.0 Bug fixed on the Sales Team Doc Checklist Saving Part**/
            	insert checklistRec;
            }
           
            if (checklistRec.Approval_Status__c == 'Approved' || checklistRec.Approval_Status__c == 'Rejected') {
                handleStsUpdate(new List<sObject>{ checklistRec }, null);
            }
        }
		if(soUpdate <> null){
            	update soUpdate;
        }
        System.debug('==[DEBUG] sendToNextTeam END==');
        return nextTeam;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canAccessSalesChecklist(Id salesOrderId) {
        if (salesOrderId == null) return false;

        String currentEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
        String allowedEmails = Label.SO_Journey_Extended_User;

        Set<String> allowedSet = new Set<String>();
        if (!String.isBlank(allowedEmails)) {
            for (String e : allowedEmails.split(';')) {
                allowedSet.add(e.trim().toLowerCase());
            }
        }

        SalesOrder__c so = [
            SELECT SalesAssociate__r.Email,
                Sales_Operations_Associate__r.Email,
                Finance_Associate__r.Email,
                Customer_Management_Associate__r.Email
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        List<String> soEmails = new List<String>();
        if (so.SalesAssociate__r.Email != null) soEmails.add(so.SalesAssociate__r.Email.toLowerCase());
        if (so.Sales_Operations_Associate__r.Email != null) soEmails.add(so.Sales_Operations_Associate__r.Email.toLowerCase());
        if (so.Finance_Associate__r.Email != null) soEmails.add(so.Finance_Associate__r.Email.toLowerCase());
        if (so.Customer_Management_Associate__r.Email != null) soEmails.add(so.Customer_Management_Associate__r.Email.toLowerCase());

        Boolean isAllowed = allowedSet.contains(currentEmail.toLowerCase()) || soEmails.contains(currentEmail.toLowerCase());
        System.debug('Checklist Access: ' + isAllowed + ' for user ' + currentEmail);
        return isAllowed;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getChecklistAccess(Id salesOrderId) {
        Map<String, Object> accessInfo = new Map<String, Object>();

        SalesOrder__c so = [
            SELECT Id, SalesAssociate__c, Sales_Operations_Associate__c,
                Finance_Associate__c, Customer_Management_Associate__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        User currentUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId()];
        String currentEmail = currentUser.Email.toLowerCase();

        String labelString = System.Label.SO_Journey_Extended_User;
        Set<String> overrideEmails = new Set<String>();
        for (String email : labelString.split(';')) {
            overrideEmails.add(email.trim().toLowerCase());
        }

        Boolean isOverride = overrideEmails.contains(currentEmail);

        accessInfo.put('isOverride', isOverride);
        accessInfo.put('userId', currentUser.Id);
        accessInfo.put('salesAssociate', so.SalesAssociate__c);
        accessInfo.put('soAssociate', so.Sales_Operations_Associate__c);
        accessInfo.put('financeAssociate', so.Finance_Associate__c);
        accessInfo.put('cmAssociate', so.Customer_Management_Associate__c);

        return accessInfo;
    }

    
    @TestVisible
        private static String getNextTeamFor(String currentTeam) {
            if (currentTeam == 'Sales') return 'Sales Operation';
            if (currentTeam == 'Sales Operation') return 'Finance';
            if (currentTeam == 'Finance') return 'Customer Management';
            if (currentTeam == 'Customer Management') return 'Exceptional Approval';
            return null;
        }
    @TestVisible
        private static String getTeamFromSalesOrder(Id salesOrderId) {
            SalesOrder__c so = [SELECT Sub_Status__c FROM SalesOrder__c WHERE Id = :salesOrderId];
            if (so.Sub_Status__c == 'Pending with Sales' || so.Sub_Status__c == 'Pending With Sales Team') return 'Sales';
            if (so.Sub_Status__c == 'Pending With Sales Operation') return 'Sales Operation';
            if (so.Sub_Status__c == 'Under Finance Verification') return 'Finance';
            if (so.Sub_Status__c == 'Pending with CM') return 'Customer Management';
            return so.Sub_Status__c;
        }

    

    @AuraEnabled
    public static Map<String, ChecklistItemDTO> validateSalesTeamChecklistFatima(Id salesOrderId) {
        Map<String, ChecklistItemDTO> checklistMap = new Map<String, ChecklistItemDTO>();

        SalesOrder__c so = [
            SELECT Id, Sales_Type__c, CustomerAccount__c, PrimaryContact__c,
                CustomerAccount__r.IsPersonAccount,PDC_Collected__c, Opportunity__c,
                CustomerAccount__r.PersonEmail, CustomerAccount__r.FirstName, CustomerAccount__r.LastName,
                CustomerAccount__r.PersonMailingAddress, CustomerAccount__r.ComplianceStatus__pc,
                CustomerAccount__r.RecordType.Name,
                Unit__r.Phase__r.Is_Reservation_Form_Required__c,
                Down_Payment_Status__c, ADM_Fees_and_Dari__c, UAE_Resident_Status__c,
                Cheques_collected_No_of_cheques__c, Cheques_Rcvd_from_Sales_No_of_cheques__c, Modeofpayment__c, ComplianceStatus__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

       Contact relatedContact;
        //try {
            if (so.PrimaryContact__c != null) {
                relatedContact = [
                    SELECT Id, Name, Email, Phone, MailingAddress
                    FROM Contact
                    WHERE Id = :so.PrimaryContact__c
                    LIMIT 1
                ];
           } 
        //else {
        //         throw new AuraHandledException('No Primary Contact linked to this Sales Order.');
        //     }
        // } catch (Exception e) {
        //     throw new AuraHandledException('No Primary Contact found for this Sales Order. Please link a primary contact before proceeding.');
        // }


       /* List<Documents__c> docs = !so.CustomerAccount__r.IsPersonAccount && so.CustomerAccount__c <> null ? [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE Account__c = :so.CustomerAccount__c
        ]: [
            SELECT Name, Status__c
            FROM Documents__c
            WHERE PrimaryContact__c = :so.PrimaryContact__c
        ]; */
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

        
        List<Documents__c> docsSO =  [
            SELECT Name, Status__c
            FROM Documents__c WHERE SalesOrder__c = :salesOrderId
        ] ;


        ChecklistItemDTO customerDetails = new ChecklistItemDTO();
        customerDetails.label = 'Customer details uploaded (Name, Phone, Email, Address)';
        customerDetails.team = 'Sales';
        customerDetails.allowedStatuses = new List<String>{ 'Uploaded', 'Not Uploaded' };

        List<String> missing = new List<String>();
        Boolean detailsValid = false;

        if (relatedContact != null) {
            if (String.isBlank(relatedContact.Name)) missing.add('Name');
            if (String.isBlank(relatedContact.Email)) missing.add('Email');
            if (relatedContact.MailingAddress == null) missing.add('Address');
            detailsValid = missing.isEmpty();
        } else {
            if (String.isBlank(so.CustomerAccount__r.FirstName)) missing.add('First Name');
            if (String.isBlank(so.CustomerAccount__r.LastName)) missing.add('Last Name');
            if (String.isBlank(so.CustomerAccount__r.PersonEmail)) missing.add('Email');
            if (so.CustomerAccount__r.PersonMailingAddress == null) missing.add('Address');
            detailsValid = missing.isEmpty();
        }

        customerDetails.approvalSts = (detailsValid ? 'Uploaded' : 'Not Uploaded');
        customerDetails.remark = (detailsValid ? '' : String.join(missing, ', ') + ' not updated');
        checklistMap.put(customerDetails.label, customerDetails);

        ChecklistItemDTO docUpload = new ChecklistItemDTO();
        docUpload.label = 'Customer documents uploaded (Passport, Emirates ID, supporting documents)';
        docUpload.team  = 'Sales';
        docUpload.allowedStatuses = new List<String>{ 'Uploaded', 'Not Uploaded', 'Partial' };

        Boolean passportUploaded = false;
        Boolean eidUploaded = false;
        
          // KYC DIFF CAUSE ALREADY SIGNED
        ChecklistItemDTO kycChecklist = new ChecklistItemDTO();
        kycChecklist.label = 'KYC form generated and sent for signature';
        kycChecklist.team = 'Sales';
        kycChecklist.allowedStatuses = new List<String>{ 'Sent', 'Pending' };

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
        
        System.debug('Final Flags: passportUploaded=' + passportUploaded + ', eidUploaded=' + eidUploaded);
     

        List<String> remarks = new List<String>();
        if (!passportUploaded) remarks.add('Passport not uploaded');
        if (so.UAE_Resident_Status__c == 'Resident'){if (!eidUploaded) remarks.add('Emirates ID not uploaded');}

        if (passportUploaded && eidUploaded) {
            docUpload.approvalSts = 'Uploaded';
        } else if (passportUploaded || eidUploaded) {
            docUpload.approvalSts = 'Partial';
        } else {
            docUpload.approvalSts = 'Not Uploaded';
        }
        docUpload.remark = String.join(remarks, '; ');
        checklistMap.put(docUpload.label, docUpload);

        if(kycUploaded == false){
            for (Documents__c d : docsSO) {
                if (d.Name != null && (d.Name.toLowerCase().contains('signed kyc and wealth form') || d.Name.toLowerCase().contains('kyc and wealth form'))) {//KYC and Wealth Form
                    if (d.Status__c == 'Uploaded') kycUploaded = true;
                }
            }
        }
 
        if (kycUploaded) {
            kycChecklist.approvalSts = 'Sent';
            kycChecklist.remark = '';
        } else {
            kycChecklist.approvalSts = 'Pending';
            kycChecklist.remark = 'KYC form not uploaded';
        }

        checklistMap.put(kycChecklist.label, kycChecklist);


        if (so.Sales_Type__c != 'Direct') {
            checklistMap.putAll(generateDocumentChecklist('broker form', 'Broker Form Generated & Sent for Signature', docsSO));
        }
        if (so.Unit__r != null && so.Unit__r.Phase__r.Is_Reservation_Form_Required__c == 'Yes') {
            ChecklistItemDTO reservationChecklist = new ChecklistItemDTO();
            reservationChecklist.label = 'Reservation form generated and sent for signature';
            reservationChecklist.team = 'Sales';
            reservationChecklist.allowedStatuses = new List<String>{ 'Sent', 'Pending' };

            Boolean reservationUploaded = false;

            for (Documents__c d : docsSO) {
                if (d.Name != null && d.Name.toLowerCase().contains('reservation form')) {
                    if (d.Status__c == 'Uploaded') reservationUploaded = true;
                }
            }

            if (reservationUploaded) {
                reservationChecklist.approvalSts = 'Sent';
                reservationChecklist.remark = '';
            } else {
                reservationChecklist.approvalSts = 'Pending';
                reservationChecklist.remark = 'Reservation form not uploaded';
            }

            checklistMap.put(reservationChecklist.label, reservationChecklist);

        }

        ChecklistItemDTO complianceCheck = new ChecklistItemDTO();
        complianceCheck.label = 'Submitted for compliance';
        complianceCheck.team = 'Sales';
        complianceCheck.allowedStatuses = new List<String>{ 'Submitted', 'Not Submitted' };

        Boolean isCompliant = (so.ComplianceStatus__c != 'Rejected' && so.ComplianceStatus__c != 'Canceled' && so.ComplianceStatus__c != 'Requires Resubmission'  && so.ComplianceStatus__c != null);
        complianceCheck.approvalSts = (isCompliant ? 'Submitted' : 'Not Submitted');
        complianceCheck.remark = (isCompliant ? '' : 'Compliance not submitted');
        checklistMap.put(complianceCheck.label, complianceCheck);

        ChecklistItemDTO downPayment = new ChecklistItemDTO();
        downPayment.label = 'Down Payment Status';
        downPayment.team = 'Sales';
        downPayment.allowedStatuses = new List<String>{ so.Down_Payment_Status__c };
        downPayment.approvalSts = so.Down_Payment_Status__c;
        downPayment.remark = '';
        checklistMap.put(downPayment.label, downPayment);

        ChecklistItemDTO admFees = new ChecklistItemDTO();
        admFees.label = 'ADM Fees + Dari Payment Status';
        admFees.team = 'Sales';
        admFees.allowedStatuses = new List<String>{ so.ADM_Fees_and_Dari__c };
        admFees.approvalSts = so.ADM_Fees_and_Dari__c;
        admFees.remark = '';
        checklistMap.put(admFees.label, admFees);

        ChecklistItemDTO downPaymentC = new ChecklistItemDTO();
        downPaymentC.label = 'Down payment cleared';
        downPaymentC.team = 'Finance';
        downPaymentC.allowedStatuses = new List<String>{ so.Down_Payment_Status__c };
        downPaymentC.approvalSts = so.Down_Payment_Status__c;
        downPaymentC.remark = (so.Down_Payment_Status__c == 'Paid')? '': 'Down Payment Fees not Cleared';
        checklistMap.put(downPaymentC.label, downPaymentC);

        ChecklistItemDTO admFeesC = new ChecklistItemDTO();
        admFeesC.label = 'ADM Cleared';
        admFeesC.team = 'Finance';
        admFeesC.allowedStatuses = new List<String>{ so.ADM_Fees_and_Dari__c };
        admFeesC.approvalSts = so.ADM_Fees_and_Dari__c;
        admFeesC.remark = (so.ADM_Fees_and_Dari__c == 'Paid')? '': 'ADM + Dari Fees not Cleared';
        checklistMap.put(admFeesC.label, admFeesC);

        ChecklistItemDTO modeOfPayment = new ChecklistItemDTO();
        modeOfPayment.label = 'Mode of Payment';
        modeOfPayment.team = 'Sales';

        List<AggregateResult> uniqueModes = [
            SELECT Modeofpayment__c
            FROM SalesOrder__c
            WHERE Modeofpayment__c != null
            GROUP BY Modeofpayment__c
        ];

        List<String> modeOptions = new List<String>();
        for (AggregateResult ar : uniqueModes) {
            String mode = (String)ar.get('Modeofpayment__c');
            if (!String.isBlank(mode)) {
                modeOptions.add(mode);
            }
        }

        modeOfPayment.allowedStatuses = modeOptions; 
        modeOfPayment.approvalSts = so.Modeofpayment__c;
        modeOfPayment.remark = (so.Modeofpayment__c !='')?'':'Please create payment for the installment!';
        checklistMap.put(modeOfPayment.label, modeOfPayment);


                        
        ChecklistItemDTO isPdcCollected = new ChecklistItemDTO();
        isPdcCollected.label = 'Have you already opted in to PDC or Direct Debit? (Mandatory for resident customers)';
        isPdcCollected.team = 'Sales';
        isPdcCollected.allowedStatuses = new List<String>{ so.PDC_Collected__c };
        isPdcCollected.approvalSts = so.PDC_Collected__c;
        isPdcCollected.remark = (so.PDC_Collected__c == 'Yes') || (so.PDC_Collected__c == 'Not Required') || (so.PDC_Collected__c == 'Direct Debit')?'':'PDC or Direct Debit needs to be collected for "Residents" before proceed next.';
        checklistMap.put(isPdcCollected.label, isPdcCollected);


        ChecklistItemDTO exceptionalApproval = new ChecklistItemDTO();
        exceptionalApproval.label = '* Please attached supporting documents for approval.';
        exceptionalApproval.team = 'Exceptional Approval';
        exceptionalApproval.allowedStatuses = new List<String>{ 'Approved', 'Rejected', 'None' };
        exceptionalApproval.approvalSts = 'None';
        exceptionalApproval.remark = '';
        checklistMap.put(exceptionalApproval.label, exceptionalApproval);

        
        ChecklistItemDTO chequeCollected = new ChecklistItemDTO();
        chequeCollected.label = 'Cheques collected (____) nos. of cheques';
        chequeCollected.team = 'Sales Operation';
        chequeCollected.allowedStatuses = new List<String>{ 'Collected', 'Not Collected' };
        chequeCollected.approvalSts = (so.Cheques_collected_No_of_cheques__c != null && so.Cheques_collected_No_of_cheques__c != '0')
            ? 'Collected'
            : 'Not Collected';
        chequeCollected.remark = String.valueOf(so.Cheques_collected_No_of_cheques__c);
        checklistMap.put(chequeCollected.label, chequeCollected);

        ChecklistItemDTO complianceCheckCM = new ChecklistItemDTO();
        complianceCheckCM.label = 'Compliance Approved';
        complianceCheckCM.team = 'Customer Management';
        complianceCheckCM.allowedStatuses = new List<String>{ 'Approved', 'Not Approved' };

        Boolean isCompliantSO = (so.ComplianceStatus__c == 'Approved' && so.ComplianceStatus__c != null);
        complianceCheckCM.approvalSts = (isCompliantSO ? 'Approved' : 'Not Approved');
        complianceCheckCM.remark = (isCompliantSO ? '' : 'Compliance not Approved');
        checklistMap.put(complianceCheckCM.label, complianceCheckCM);

        ChecklistItemDTO complianceCheckSO = new ChecklistItemDTO();
        complianceCheckSO.label = 'Compliance Approved';
        complianceCheckSO.team = 'Sales Operation';
        complianceCheckSO.allowedStatuses = new List<String>{ 'Approved', 'Not Approved' };

        isCompliantSO = (so.ComplianceStatus__c == 'Approved' && so.ComplianceStatus__c != null);
        complianceCheckSO.approvalSts = (isCompliantSO ? 'Approved' : 'Not Approved');
        complianceCheckSO.remark = (isCompliantSO ? '' : 'Compliance not Approved');
        checklistMap.put(complianceCheckSO.label, complianceCheckSO);

        ChecklistItemDTO chequeReceived = new ChecklistItemDTO();
        chequeReceived.label = 'Cheques received from Sales Team (____) nos. of cheques';
        chequeReceived.team = 'Sales Operation';
        chequeReceived.allowedStatuses = new List<String>{ 'Received', 'Not Received' };
        chequeReceived.approvalSts = (so.Cheques_Rcvd_from_Sales_No_of_cheques__c != null && so.Cheques_Rcvd_from_Sales_No_of_cheques__c != '0')
            ? 'Received'
            : 'Not Received';
        chequeReceived.remark = String.valueOf(so.Cheques_Rcvd_from_Sales_No_of_cheques__c);
        checklistMap.put(chequeReceived.label, chequeReceived);
        System.debug('Final Document Checkist Record Field Value' + checklistMap); 

        return checklistMap;
    }

    public static Map<String, ChecklistItemDTO> generateDocumentChecklist(String keyword, String label, List<Documents__c> docs) {
        Map<String, ChecklistItemDTO> result = new Map<String, ChecklistItemDTO>();
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
        } else {
            item.approvalSts = 'Pending';
            item.remark = keyword +  ' not uploaded';
        }

        result.put(label, item);
        return result;
    }


    public static Boolean hasStatusSafe(Document_Checklist__c d) {
        try {
            return d.Sales_Order__c != null
                && d.Sales_Order__r != null
                && d.Sales_Order__r.get('Status__c') != null
                && !String.isBlank((String) d.Sales_Order__r.get('Status__c'));
        } catch (Exception e) {
            return false;
        }
    }

            public static Map<String, String> docStatusValuesMap;
            static {
                docStatusValuesMap = new Map<String, String>();
                docStatusValuesMap.put('New-Sales-Approved-Reservation', 'Pending With Sales Operation');
                docStatusValuesMap.put('New-Sales-Approved-SPA', 'SPA In Progress');
                docStatusValuesMap.put('New-Sales-Rejected', 'Pending with Sales');
                docStatusValuesMap.put('In Progress-Sales-Approved', 'Pending With Sales Operation');
                docStatusValuesMap.put('In Progress-Sales-Rejected', 'Pending With Sales Team');
                docStatusValuesMap.put('In Progress-Sales Operation-Approved', 'Document Checklist Verified By - Sales Operation');
                docStatusValuesMap.put('In Progress-Sales Operation-Rejected', 'Pending With Sales Team');
                docStatusValuesMap.put('In Progress-Customer Management-Approved', 'Document Checklist Verified By - Customer Management');
                docStatusValuesMap.put('In Progress-Customer Management-Rejected', 'Pending With Sales Operation');
                docStatusValuesMap.put('In Progress-Finance-Approved', 'Pending with CM');
                docStatusValuesMap.put('In Progress-Finance-Rejected', 'Pending With Sales Operation');
            }




            public static void handleStsUpdate(List<sObject> docChecklistUpdateList, Map<Id, sObject> oldMap) {
            System.debug('func handleStsUpdate');
            System.debug('docChecklistUpdateList size: ' + docChecklistUpdateList.size());
            
            Set<Id> docIdset = new Set<Id>();
            Map<Id, String> salesOrderStsMap = new Map<Id, String>();

            for (Document_Checklist__c doc : (List<Document_Checklist__c>) docChecklistUpdateList) {
                Document_Checklist__c oldRecord = oldMap != null ? (Document_Checklist__c) oldMap.get(doc.Id) : null;

                System.debug('Processing doc ID: ' + doc.Id);
                System.debug('New Approval_Status__c: ' + doc.Approval_Status__c);
                if (oldRecord != null) {
                    System.debug('Old Approval_Status__c: ' + oldRecord.Approval_Status__c);
                }

                if (doc.Approval_Status__c != null &&
                    (oldRecord == null || doc.Approval_Status__c != oldRecord.Approval_Status__c) &&
                    (doc.Approval_Status__c == 'Approved' || doc.Approval_Status__c == 'Rejected')) {
                    docIdset.add(doc.Id);
                }
            }

            System.debug('docIdset (IDs to query): ' + docIdset);

            Map<String, String> soStatusApprovalMap = new Map<String, String>();
            Map<String, String> salesOrderPreviousStsMap = new Map<String, String>();
            Map<Id, Id> soCurrentStsMap = new Map<Id, Id>();

            for (Document_Checklist__c doc : [
                SELECT Id, Team__c, Approval_Status__c, Sales_Order__r.Status__c, Sales_Order__r.Sub_Status__c, Sales_Order__c,Sales_Order__r.Sales_Journey_Flow__c
                FROM Document_Checklist__c
                WHERE Id IN :docIdset
            ]) {
                String key = doc.Sales_Order__r.Status__c + '-' + doc.Team__c + '-' + doc.Approval_Status__c;
                System.debug('Generated key: ' + key);
                if(doc.Sales_Order__r.Status__c == 'New' && doc.Sales_Order__r.Sales_Journey_Flow__c.contains('SPA')){
                    key = key+'-SPA';
                }else if(doc.Sales_Order__r.Status__c == 'New' && doc.Sales_Order__r.Sales_Journey_Flow__c.contains('Reservation')){
                     key = key+'-Reservation';
                }

                String status = docStatusValuesMap.containsKey(key) ? docStatusValuesMap.get(key) : null;
                System.debug('Mapped status for key [' + key + ']: ' + status);

                if (status != null) {
                    salesOrderStsMap.put(doc.Sales_Order__c, status);
                    salesOrderPreviousStsMap.put(doc.Sales_Order__c, doc.Sales_Order__r.Sub_Status__c);
                    soStatusApprovalMap.put(doc.Sales_Order__c, doc.Approval_Status__c);
                }
            }

            System.debug('salesOrderStsMap: ' + salesOrderStsMap);
            System.debug('salesOrderPreviousStsMap: ' + salesOrderPreviousStsMap);
            System.debug('soStatusApprovalMap: ' + soStatusApprovalMap);

            Map<String, Sales_Order_Sub_Status_Meta_Data__mdt> statusMetaDataMap = new Map<String, Sales_Order_Sub_Status_Meta_Data__mdt>();
            for (Sales_Order_Sub_Status_Meta_Data__mdt soMdt : [
                SELECT Current_Sub_Status__c, Sales_Order_Status__c, Next_Sub_Status__c, Approval_Status__c, Alert_Message__c
                FROM Sales_Order_Sub_Status_Meta_Data__mdt
                WHERE Current_Sub_Status__c IN :salesOrderStsMap.values()
            ]) {
                statusMetaDataMap.put(soMdt.Current_Sub_Status__c, soMdt);
            }

            System.debug('statusMetaDataMap size: ' + statusMetaDataMap.size());

            for (Sales_Order_Status_Approvals__c soApp : [
                SELECT Id, Sales_Order__c
                FROM Sales_Order_Status_Approvals__c
                WHERE Current_Sub_Status__c IN :salesOrderPreviousStsMap.values()
                AND Sales_Order__c IN :salesOrderStsMap.keySet()
                ORDER BY CreatedDate DESC
            ]) {
                soCurrentStsMap.put(soApp.Sales_Order__c, soApp.Id);
            }

            System.debug('soCurrentStsMap: ' + soCurrentStsMap);
        /*
            List<Sales_Order_Status_Approvals__c> soAppNewList = new List<Sales_Order_Status_Approvals__c>();
            for (Id soId : salesOrderStsMap.keySet()) {
                Sales_Order_Sub_Status_Meta_Data__mdt mdtData = statusMetaDataMap.get(salesOrderStsMap.get(soId));
                if (mdtData == null) {
                    System.debug('MDT not found for sub-status: ' + salesOrderStsMap.get(soId));
                    continue;
                }

                Sales_Order_Status_Approvals__c soAppNew = new Sales_Order_Status_Approvals__c();
                soAppNew.Sales_Order__c = soId;
                soAppNew.Approval_Status__c = 'Pending';
                soAppNew.Alert_Message__c = mdtData.Alert_Message__c;
                soAppNew.Current_Sub_Status__c = mdtData.Current_Sub_Status__c;
                soAppNew.Next_Sub_Status__c = mdtData.Next_Sub_Status__c;
                soAppNew.Sales_Order_Status__c = mdtData.Sales_Order_Status__c;
                soAppNew.Submitted_Date__c = DateTime.now();

                System.debug('Prepared new Sales_Order_Status_Approvals__c: ' + soAppNew);

                soAppNewList.add(soAppNew);
            }

            if (!soAppNewList.isEmpty()) {
                System.debug('Inserting new SO Status Approvals: ' + soAppNewList.size());
                insert soAppNewList;

                Set<Id> soaIdset = new Set<Id>();
                for (Sales_Order_Status_Approvals__c soa : soAppNewList) {
                    if (soa.Current_Sub_Status__c == 'Document Checklist Verified By - Sales Operation' ||
                        soa.Current_Sub_Status__c == 'Document Checklist Verified By - Customer Management' ||
                        soa.Current_Sub_Status__c == 'Pending with CM' ||
                        soa.Current_Sub_Status__c == 'Completed') {
                        soaIdset.add(soa.Id);
                    }
                }

                System.debug('Calling skipPendingWithStatus for IDs: ' + soaIdset);
            //  SalesOrderStatusAutomationHelper.skipPendingWithStatus(soaIdset);
            } */

            List<Sales_Order_Status_Approvals__c> soStsApprovalList = new List<Sales_Order_Status_Approvals__c>();
            for (Id soId : soStatusApprovalMap.keySet()) {
                Id existingId = soCurrentStsMap.get(soId);
                if (existingId == null) {
                    System.debug('No existing SO Status Approval record for SO: ' + soId);
                    continue;
                }

                Sales_Order_Status_Approvals__c soApp = new Sales_Order_Status_Approvals__c();
                soApp.Id = existingId;
                soApp.Approval_Status__c = soStatusApprovalMap.get(soId);
                soApp.Completed_Date__c = DateTime.now();
                soStsApprovalList.add(soApp);
            }

            if (!soStsApprovalList.isEmpty()) {
                System.debug('Updating existing SO Status Approvals: ' + soStsApprovalList.size());
                update soStsApprovalList;
            }

            System.debug('=== EXITING handleStsUpdate ===');
        }
}