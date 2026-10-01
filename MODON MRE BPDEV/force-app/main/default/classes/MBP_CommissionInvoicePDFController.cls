public without sharing class MBP_CommissionInvoicePDFController {
    public Commission_Line__c commissionLine { get; private set; }
    public Account userAccount { get; private set; }
    public Boolean isRejectAttempt { get; set; }
    public String comments { get; set; }

    public String descriptionText { get; private set; }
    public String UnitNumberText { get; private set; }
    public String CustomerNameText { get; private set; }
    public Integer vatRatePercent { get; private set; } 
    public Decimal grossAmount { get; private set; }  
    public String vatDisplayText { get; private set; }
    public Decimal netAmount { get; private set; }     
    public Decimal vatAmount { get; private set; }
    public String projectOwningEntity { get; private set; }
    public String salesOrderName { get; private set; }
    public string brokerAgreementNo { get; private set; }
    public String taxInvoiceNumberFormatted { get; private set; }
    public Decimal unitPrice { get; private set; }
    public Decimal commissionRate { get; private set; }
    public Decimal commissionBase { get; private set; }
    public String projectName { get; private set; }
    public String phaseName { get; private set; }
    public String status { get; set; }
    public String cliNumber { get; private set; } //New line

    // SPA Developer details (from the unit's Phase). These drive the
    // header block on the invoice PDF - developer/entity name, TRN and
    // registered address - instead of the previous hardcoded values.
    public String developerTRN { get; private set; }
    public String developerAddress { get; private set; }

    // Message shown to the broker whenever their OIC (Fusion) Supplier / Bank
    // sync has not completed successfully yet.
    private static final String OIC_NOT_SYNCED_MESSAGE =
        'Your supplier details are not synced with the Fusion team. Please reach out to the Broker Management Team.';


    public String getCommissionLineJson() {
        return (commissionLine != null) ? JSON.serializePretty(commissionLine) : '';
    }
    public String getUserAccountJson() {
        return (userAccount != null) ? JSON.serializePretty(userAccount) : '';
    }
    
    public MBP_CommissionInvoicePDFController() {
        Id commissionId = ApexPages.currentPage().getParameters().get('commissionId');
        status = ApexPages.currentPage().getParameters().get('status');
        isRejectAttempt = false;
        
        if (commissionId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No commissionId parameter provided.'));
            return;
        }
        
        try {
            User currentUser = [
                SELECT Id, ContactId, AccountId,contact.Accountid
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            Id contactId = currentUser.ContactId;
            Id accountId = currentUser.contact.Accountid;
            List<Account> accounts = [
                SELECT Id, Name, AccountNumber,
                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                TRN__c, Bank_Name__c, Bank_Account_Number__c, IBAN_Country_Bank_Code__c,
                SWIFT_Code__c, Bank_Country__c, UAEVATRegisterNumber__c,
                Agency_Region__c, VAT_Certificate_Type__c,BrokerAgreementNo__c,Trade_License_Number__c,EBS_VENDOR_ID__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            if (!accounts.isEmpty()) userAccount = accounts[0];
            Boolean hasVAT = (
                userAccount != null &&
                userAccount.Agency_Region__c == 'Domestic' &&
                userAccount.VAT_Certificate_Type__c == 'VAT Registration Certificate' &&
                String.isNotBlank(userAccount.UAEVATRegisterNumber__c)
            );
       
            List<Commission_Line__c> lines = [
                SELECT Id, Name, Project__c, Total_Unit_Price__c, Commission_Percent__c,
                Total_Commission_Amount_Paid__c, Commission_Amount__c,
                Commission_Payout_Amount_Now__c, Status__c, Current_Commission_Payout_Now__c,
                Equity__c, Payout_Equity__c, External_Total_Commission_Amount__c,Sales_Order__r.Name,
                
                Sales_Order__r.Unit__r.Project_Name__c,
                Sales_Order__r.Unit__r.Phase__r.Name,
                Sales_Order__r.Unit__r.Phase__r.EntityName__c,
                Sales_Order__r.Unit__r.Phase__r.Project__r.SPA_Developer_Name__c,
                Sales_Order__r.Unit__r.Phase__r.Project__r.SPA_Developer_TRN_Number__c,
                Sales_Order__r.Unit__r.Phase__r.Project__r.SPA_Developer_Address__c,
                Broker_Agency__r.BrokerAgreementNo__c,
                Broker_Agency__r.EBS_VENDOR_ID__c,
                Broker_Agency__r.Trade_License_Number__c
                ,
                Sales_Order__c, Sales_Order__r.Id, Sales_Order__r.Unit__c, Sales_Order__r.Unit__r.Name,Sales_Order__r.Unit__r.TotalPrice__c,
                Unit__c, Broker_Agent__c, Broker_Agency__r.Name, Tax_Invoice_Number__c,
                Sales_Order__r.Opportunity__r.Account.Name, Invoice_Status__c,Sales_Order__r.CustomerAccount__r.Name,Invoice_Date__c
                FROM Commission_Line__c
                WHERE Id = :commissionId
                AND Broker_Agency__c = :accountId
                LIMIT 1
            ];
            
            
            commissionLine = lines[0];
            
            
            
            
            grossAmount = (commissionLine.Commission_Amount__c == null) ? 0 : commissionLine.Commission_Amount__c;
            
            
            vatRatePercent = hasVAT ? 5 : 0;
            vatDisplayText = hasVAT ? String.valueOf(vatRatePercent) : 'Out of scope';
            
            
            if (hasVAT) {
                vatAmount = (grossAmount * 0.05);
                netAmount = grossAmount;              
                grossAmount = netAmount + vatAmount;  
            } else {
                vatAmount = 0;
                netAmount = grossAmount;              
            }
            
            
            netAmount   = netAmount.setScale(2);
            vatAmount   = vatAmount.setScale(2);
            grossAmount = grossAmount.setScale(2);

            // Header block (company name / TRN / address) is now driven by
            // the SPA Developer details captured on the unit's Phase,
            // rather than the generic phase EntityName__c / a hardcoded
            // TRN and address.
            projectOwningEntity = commissionLine.Sales_Order__r.Unit__r.Phase__r.Project__r.SPA_Developer_Name__c;
            developerTRN = commissionLine.Sales_Order__r.Unit__r.Phase__r.Project__r.SPA_Developer_TRN_Number__c;
            developerAddress = commissionLine.Sales_Order__r.Unit__r.Phase__r.Project__r.SPA_Developer_Address__c;
            
            salesOrderName = commissionLine.Sales_Order__r.Name;
            
            brokerAgreementNo = commissionLine.Broker_Agency__r.EBS_VENDOR_ID__c;
            
            projectName = commissionLine.Sales_Order__r.Unit__r.Project_Name__c;
            phaseName = commissionLine.Sales_Order__r.Unit__r.Phase__r.Name;
            
            unitPrice = commissionLine.Sales_Order__r.Unit__r.TotalPrice__c;
            commissionRate = commissionLine.Commission_Percent__c;
            commissionBase = commissionLine.Total_Unit_Price__c;
            String unitName = commissionLine.Sales_Order__r.Unit__r.Name;
            
            String cleanedName = commissionLine.Name;
            
            if (cleanedName != null && cleanedName.startsWith('CLI-')) {
                cleanedName = cleanedName.replace('CLI-', '');
            }
            String commissionPercentText = '';

if (commissionRate != null) {
    commissionPercentText = String.valueOf(commissionRate.setScale(0));
}

taxInvoiceNumberFormatted =
    salesOrderName + ' - ' +
    commissionPercentText + '% Commission Fee';
            
            
            
            
            UnitNumberText = commissionLine.Sales_Order__r.Unit__r.Name;
            CustomerNameText = commissionLine.Sales_Order__r.CustomerAccount__r.Name;
            
            String unitName1 = (commissionLine.Sales_Order__r.Unit__r.Name != null) ? commissionLine.Sales_Order__r.Unit__r.Name :
            (String) commissionLine.get('Unit__c');
            if (unitName == null) unitName = '';
            descriptionText = 'This is your invoice for Unit ' + unitName;
            
            cliNumber = commissionLine.Name;
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error loading data: ' + e.getMessage()));
        }
    }
    
    public void attemptReject() {
        isRejectAttempt = true;
    }
    
    @AuraEnabled
    public static String rejectCommissionWithComments(Id commissionLineId, String comments) {
        try {
            if (String.isBlank(comments)) {
                return 'ERROR: Comments are required for rejection';
            }
            
            Commission_Line__c commissionLine = [
                SELECT Id, Comments__c, Invoice_Status__c, Status__c
                FROM Commission_Line__c 
                WHERE Id = :commissionLineId
                LIMIT 1
            ];
            
            commissionLine.Status__c = 'Rejected';
            commissionLine.Comments__c = comments;
            update commissionLine;
            
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException('Error rejecting commission: ' + e.getMessage());
        }
    }
    
 
    @AuraEnabled
    public static void savePDFtoCommissionLine(
        Id commissionLineId,
        String comments,
        String invoiceNumber,
        Date invoiceDate,
        String invoiceFileName,
        String invoiceFileData,
        Boolean isVatUndertakingFlow
    ){
        
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        Id brokerAgencyId = u.Contact.AccountId;

        // Hard gate: an agency whose OIC (Fusion) Bank / Supplier sync has not
        // completed successfully must never be allowed to submit/accept an
        // invoice, even if the client attempts to bypass the UI checks.
        if (!isOICSyncSuccessful(brokerAgencyId)) {
            throw new AuraHandledException(OIC_NOT_SYNCED_MESSAGE);
        }
        
       
        Boolean vatFlow = (isVatUndertakingFlow == true);

        Commission_Line__c cl = [
            SELECT Id, Name
            FROM Commission_Line__c
            WHERE Id = :commissionLineId
            LIMIT 1
        ];
        
        cl.Comments__c = comments;
        cl.Invoice_Status__c = 'Submitted';
        cl.Status__c = 'Pending Invoice Verification';
        
        if (String.isNotBlank(invoiceNumber)) {
            cl.Tax_Invoice_Number__c = invoiceNumber;
        }
        
        if (vatFlow) {
            if (invoiceDate != null) {
                cl.Invoice_Date__c = invoiceDate;
            }
        } else {
            cl.Invoice_Date__c = Date.today();
        }
        
        update cl;
        
      
        if (!vatFlow) {
            
            Blob pdfBlob = generatePDF(commissionLineId, cl.Name);
            
            ContentVersion pdfVersion = new ContentVersion();
            pdfVersion.Title = 'Modon Broker Commission Invoice';
            pdfVersion.PathOnClient = 'CommissionInvoice.pdf';
            pdfVersion.VersionData = pdfBlob;
            pdfVersion.IsMajorVersion = true;
            insert pdfVersion;
            
            Id generatedDocId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :pdfVersion.Id
            ].ContentDocumentId;
            
            insert new ContentDocumentLink(
                ContentDocumentId = generatedDocId,
                LinkedEntityId = commissionLineId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        }

        if (String.isNotBlank(invoiceFileData)) {
            createFile(invoiceFileName, invoiceFileData, commissionLineId);
        }
    
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(cl.Id);
        
        Approval.ProcessResult result = Approval.process(req);
        
        if (!result.isSuccess()) {
            
            Database.Error err =
                result.getErrors().isEmpty() ? null : result.getErrors()[0];
            
            if (err != null) {
                throw new AuraHandledException(
                    'Approval failed: ' + err.getMessage()
                );
            } else {
                throw new AuraHandledException(
                    'Approval failed for unknown reason.'
                );
            }
        }
    }
    private static void createFile(
        String fileName,
        String base64Data,
        Id parentId
    ){
        Blob body = EncodingUtil.base64Decode(base64Data);
        
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = body;
        insert cv;
        
        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;
        
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = parentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }
    
    
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getCommissionSummary(
        Id accountId, 
        Id contactId, 
        String filterType, 
        Date startDate, 
        Date endDate
    ) {
        Map<String, Decimal> summary = new Map<String, Decimal>{
            'Paid' => 0,
                'Pending' => 0,
                'Total' => 0
                };
                    
                    if (accountId == null || contactId == null) {
                        return summary;
                    }
        
        if (String.isNotBlank(filterType)) {
            Integer currentYear = Date.today().year();
            
            if (filterType == 'Current FY') {
                startDate = Date.newInstance(currentYear, 1, 1);
                endDate = Date.newInstance(currentYear, 12, 31);
            } else if (filterType == 'Previous FY') {
                startDate = Date.newInstance(currentYear - 1, 1, 1);
                endDate = Date.newInstance(currentYear - 1, 12, 31);
            }
        }
        
        String soql = 'SELECT Total_Commission_Amount_Paid__c, Commission_Amount__c, Total_Commission_Amount_Pending__c ' +
            'FROM Commission_Line__c ' +
            'WHERE Sales_Order__r.Unit__c != null ' +
            'AND Commission_Line_Type__c = \'External\' ' +
            'AND Broker_Agent__c = :contactId ' +
            'AND Broker_Agency__c = :accountId';
        
        if (startDate != null && endDate != null) {
            soql += ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate';
        }
        
        List<Commission_Line__c> comms = Database.query(soql);
        
        for (Commission_Line__c c : comms) {
            summary.put('Paid', summary.get('Paid') + (c.Total_Commission_Amount_Paid__c == null ? 0 : c.Total_Commission_Amount_Paid__c));
            summary.put('Pending', summary.get('Pending') + (c.Total_Commission_Amount_Pending__c == null ? 0 : c.Total_Commission_Amount_Pending__c));
            summary.put('Total', summary.get('Total') + (c.Commission_Amount__c == null ? 0 : c.Commission_Amount__c));
        }
        
        return summary;
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isTradeLicenseMandatory() {
        
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        Id brokerAgencyId = u.Contact.AccountId;
        
        AggregateResult ar = [
            SELECT SUM(Sales_Order__r.TotalAmount__c) totalAmt
            FROM Commission_Line__c
            WHERE Broker_Agency__c = :brokerAgencyId
            AND Sales_Order__r.Status__c = 'Completed'
            AND Sales_Order__r.Status__c NOT IN ('Cancelled','System Cancelled','CancelledSR','Voided')
            AND Sales_Order__r.Unit__r.Status__c IN ('Sold','Reserved')
        ];
        
        Decimal totalAmount =
            (Decimal) ar.get('totalAmt');
        
        if(totalAmount == null) totalAmount = 0;
        
        return totalAmount >= 375000;
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean hasBrokerVAT() {
        
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        Account acc = [
            SELECT UAEVATRegisterNumber__c,
            VAT_Certificate_Type__c,
            Agency_Region__c
            FROM Account
            WHERE Id = :u.Contact.AccountId
            LIMIT 1
        ];
        
        return (
            
            acc.VAT_Certificate_Type__c == 'VAT Registration Certificate' &&
            String.isNotBlank(acc.UAEVATRegisterNumber__c)
        );
    }

    // ------------------------------------------------------------------
    // OIC (Fusion) Bank / Supplier sync validation
    //
    // Two JSON "log" fields are populated on the broker Agency Account
    // whenever the middleware (OIC) pushes the agency's bank and supplier
    // records to Fusion/EBS:
    //   - OIC_Bank_Response__c     -> array, status key "OracleEBSSyncStatus"
    //   - OIC_Supplier_Response__c -> array, status key "Status"
    // Both must report "Success" before a broker is allowed to accept /
    // submit a commission invoice or manage bank details. Otherwise the
    // broker must be told to reach out to the Broker Management Team.
    // ------------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static Boolean isSupplierAndBankSynced() {
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        return isOICSyncSuccessful(u.Contact.AccountId);
    }

    private static Boolean isOICSyncSuccessful(Id brokerAgencyId) {
        if (brokerAgencyId == null) {
            return false;
        }

        Account acc = [
            SELECT OIC_Bank_Response__c, OIC_Supplier_Response__c
            FROM Account
            WHERE Id = :brokerAgencyId
            LIMIT 1
        ];

        Boolean bankSynced = isResponseStatusSuccess(acc.OIC_Bank_Response__c, 'OracleEBSSyncStatus');
        Boolean supplierSynced = isResponseStatusSuccess(acc.OIC_Supplier_Response__c, 'Status');

        return bankSynced && supplierSynced;
    }

    private static Boolean isResponseStatusSuccess(String responseJson, String statusFieldName) {
        if (String.isBlank(responseJson)) {
            return false;
        }

        try {
            Object parsed = JSON.deserializeUntyped(responseJson);
            List<Object> records = new List<Object>();

            if (parsed instanceof List<Object>) {
                records = (List<Object>) parsed;
            } else if (parsed instanceof Map<String, Object>) {
                records.add(parsed);
            }

            if (records.isEmpty()) {
                return false;
            }

            for (Object recordObj : records) {
                if (!(recordObj instanceof Map<String, Object>)) {
                    return false;
                }

                Map<String, Object> record = (Map<String, Object>) recordObj;
                Object statusValue = record.get(statusFieldName);

                if (statusValue == null || String.valueOf(statusValue).trim().equalsIgnoreCase('Success') == false) {
                    return false;
                }
            }

            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getCommissionPDFBase64(Id commissionLineId) {
        PageReference pdfPage = Page.CommissionInvoicePDF;
        pdfPage.getParameters().put('commissionId', commissionLineId);
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Fake PDF Content for Test');
        } else {
            pdfBlob = pdfPage.getContentAsPDF();
        }
        
        return EncodingUtil.base64Encode(pdfBlob);
    }
    

    public static Blob generatePDF(Id commissionLineId, String cliNumber){
        PageReference pdfPage = Page.CommissionInvoicePDF;
        pdfPage.getParameters().put('commissionId', commissionLineId);
        pdfPage.getParameters().put('renderAs', 'pdf');
       
        
        if (String.isNotBlank(cliNumber)) {
            pdfPage.getParameters().put('cliNumber', cliNumber);
        }
        if (Test.isRunningTest()) {
            return Blob.valueOf('Mock PDF Content');
        } else {
            return pdfPage.getContentAsPDF();
        }
    }
}