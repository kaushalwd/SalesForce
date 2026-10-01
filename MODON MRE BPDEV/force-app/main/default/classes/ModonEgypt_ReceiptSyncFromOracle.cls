/**********************************************************************************************************************
* Name               : ModonEgypt_ReceiptSyncFromOracle
* Description        : REST API to sync receipts from Oracle to Salesforce for Modon Egypt
* Usage              : Called as REST API endpoint from Oracle integration
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        01 Dec 2025     Initial Version
* 1.1           Shahil Sinha (Horizontal)        12 Dec 2025     Updated the code to fetch the Mode of Payment, Swift Code and Bank Name based on receipt Method and Remittance Bank Account Number
* 1.2           Narendra Agrawal(Horizontal)     24 Dec 2025     Update request body and response body
* 1.3           Shahil Sinha (Horizontal)        26 Dec 2025     Updated response format to wrap in responses object
* 1.4           Shahil Sinha (Horizontal)        05 Jan 2026     Added Receipt Type based on Oracle Invoice ID match
* 1.5           Shahil Sinha (Horizontal)        06 Jan 2026     Updated to use ConversionRateWrapper for currency conversion & Added Oracle sync job call after receipt creation and fixed date field assignments
**********************************************************************************************************************/

@RestResource(urlMapping='/CreateReceipt/*')
global with sharing class ModonEgypt_ReceiptSyncFromOracle {
    
    //v1.2 (line 20 - 50)
    global class ReceiptRequest {
        global String CustomerAccountNumber;
        global String StandardInvoiceId;
        global String StandardReceiptId;
        global String ReceiptMethod;
        global String ReceiptNumber;
        global String RemittanceBankAccountNumber;
        global String TransactionDate;
        global String ReceiptCurrency;
        global Decimal AppliedAmount;
        global Decimal ReceiptAmount;
        global String ReceiptStatus;
        global String CardLast4Digit;
        global String CustomerBankName;
    }
    global class ReceiptResponse {
        public String status;
        public List<String> errorMessages;
        public String sfReceiptNumber;
        public String standardReceiptId;
        public String standardInvoiceId;
        public String receiptNumber;

        global ReceiptResponse(List<String> errorMessages, String sfReceiptNumber, ReceiptRequest request) {
            this.status = errorMessages != null && !errorMessages.isEmpty() ? 'FAILED' : 'SUCCESS';
            this.errorMessages = errorMessages;
            this.sfReceiptNumber = sfReceiptNumber;
            this.standardInvoiceId = request?.StandardInvoiceId;
            this.standardReceiptId = request?.StandardReceiptId;
            this.receiptNumber = request?.ReceiptNumber;
        }
    }

    //v1.3 (line 53 - 59)
    global class ReceiptResponseWrapper {
        public List<ReceiptResponse> responses;
        
        global ReceiptResponseWrapper(List<ReceiptResponse> responses) {
            this.responses = responses;
        }
    }

    @HttpPost
    global static ReceiptResponseWrapper createReceiptsFromOracle(List<ReceiptRequest> requests) {
        List<ReceiptResponse> responses = new List<ReceiptResponse>();
        
        if (requests == null || requests.isEmpty()) {
            responses.add(new ReceiptResponse(new List<String>{'Request payload should not be empty.'}, null, null));
            return new ReceiptResponseWrapper(responses);
        }

        try {
            // ============ STEP 1: Collect unique values for bulk queries ============
            Set<String> customerNumbers = new Set<String>();
            Set<String> standardInvoiceIds = new Set<String>();
            Set<String> standardReceiptIds = new Set<String>();
            Set<String> bankAccountNumbers = new Set<String>();
            Set<String> receiptMethods = new Set<String>();
            
            for (ReceiptRequest req : requests) {
                if (String.isNotBlank(req.CustomerAccountNumber)) customerNumbers.add(req.CustomerAccountNumber);
                if (String.isNotBlank(req.StandardInvoiceId)) standardInvoiceIds.add(req.StandardInvoiceId);
                if (String.isNotBlank(req.StandardReceiptId)) standardReceiptIds.add(req.StandardReceiptId);
                if (String.isNotBlank(req.RemittanceBankAccountNumber)) bankAccountNumbers.add(req.RemittanceBankAccountNumber);
                if (String.isNotBlank(req.ReceiptMethod)) receiptMethods.add(req.ReceiptMethod);
            }

            // ============ STEP 2: Bulk queries ============
            
            // Query Mappings
            //v1.1 (line 90 - 97) fetch the Mode of Payment, Swift Code and Bank Name based on receipt Method and Remittance Bank Account Number
            Map<String, Modon_Receipt_Mapping__mdt> mappingsMap = new Map<String, Modon_Receipt_Mapping__mdt>();
            for (Modon_Receipt_Mapping__mdt m : [
                SELECT Bank_Name__c, Mode_of_Payment__c, Remittance_Bank_Account_No__c, Receipt_Method__c, IBAN__c
                FROM Modon_Receipt_Mapping__mdt
                WHERE Remittance_Bank_Account_No__c IN :bankAccountNumbers AND Receipt_Method__c IN :receiptMethods
            ]) {
                mappingsMap.put(m.Remittance_Bank_Account_No__c + '|' + m.Receipt_Method__c, m);
            }

            // Query Accounts
            Map<String, Account> accountsMap = new Map<String, Account>();
           // for (Account accoutRecord : [SELECT Id, Customer_Number__c FROM Account WHERE Customer_Number__c IN :customerNumbers]) {
           //     accountsMap.put(accoutRecord.Customer_Number__c, accoutRecord);
           // }

            // Query Invoices
            Map<String, Invoice__c> invoicesMap = new Map<String, Invoice__c>();
            for (Invoice__c inv : [
                SELECT Id, Name, SalesOrderInstallment__c, SalesOrderInstallment__r.SalesOrder__c,
                       CurrencyIsoCode, InvoiceBalance__c, InvoiceAmount__c,
                       Oracle_Installment_Invoice_Id__c, Oracle_Maintenance_Invoice_Id__c
                FROM Invoice__c 
                WHERE Oracle_Installment_Invoice_Id__c IN :standardInvoiceIds OR Oracle_Maintenance_Invoice_Id__c IN :standardInvoiceIds
            ]) {
                if (String.isNotBlank(inv.Oracle_Installment_Invoice_Id__c)) invoicesMap.put(inv.Oracle_Installment_Invoice_Id__c, inv);
                if (String.isNotBlank(inv.Oracle_Maintenance_Invoice_Id__c)) invoicesMap.put(inv.Oracle_Maintenance_Invoice_Id__c, inv);
            }

            // Query existing receipts for duplicate check
            Map<String, Receipt__c> receiptMap = new Map<String, Receipt__c>();
            for (Receipt__c receipt : [
                SELECT Id, Name, Oracle_Receipt_Id__c
                FROM Receipt__c
                WHERE Oracle_Receipt_Id__c IN :standardReceiptIds
            ]) {
                if (String.isNotBlank(receipt.Oracle_Receipt_Id__c)) receiptMap.put(receipt.Oracle_Receipt_Id__c, receipt);
            }

            // ============ STEP 3: Process each request ============
            List<Receipt__c> receiptsToInsert = new List<Receipt__c>();
            List<ReceiptRequest> validRequests = new List<ReceiptRequest>();
            
            for (ReceiptRequest request : requests) {
                
                // Check mapping exists
                String mappingKey = request.RemittanceBankAccountNumber + '|' + request.ReceiptMethod;
                Modon_Receipt_Mapping__mdt mapping = mappingsMap.get(mappingKey);
                
                if (mapping == null) {
                    responses.add(new ReceiptResponse(new List<String>{'Either RemittanceBankAccountNumber or ReceiptMethod is not correct or not configured into Salesforce.'}, null, request));
                    continue;
                }

                String modeOfPayment = mapping.Mode_of_Payment__c;
                String mire_BankName = mapping.Bank_Name__c;
                String swiftCode = mapping.IBAN__c.right(4);

                // Validate request
                List<String> errors = validateRequest(request, modeOfPayment, swiftCode);
                if (!errors.isEmpty()) {
                    ReceiptResponse res = new ReceiptResponse(errors, null, request);
                    responses.add(res);
                    continue;
                }

                // Check account exists
                Account accountRecord = accountsMap.get(request.CustomerAccountNumber);
               if (accountRecord == null) {
                    accountRecord = new Account(Name = 'test');
                   // responses.add(new ReceiptResponse(new List<String>{'Customer number is not valid: ' + request.CustomerAccountNumber}, null, request));
                   // continue;
                }

                // Check invoice exists
                Invoice__c invoice = invoicesMap.get(request.StandardInvoiceId);
                if (invoice == null) {
                    responses.add(new ReceiptResponse(new List<String>{'Standard Invoice Id is not valid: ' + request.StandardInvoiceId}, null, request));
                    continue;
                }

                // Determine Receipt Type based on which Oracle Invoice ID field matched
                String receiptType;
                if (request.StandardInvoiceId == invoice.Oracle_Installment_Invoice_Id__c) {
                    receiptType = 'Installment Receipt';
                } else if (request.StandardInvoiceId == invoice.Oracle_Maintenance_Invoice_Id__c) {
                    receiptType = 'Maintenance Receipt';
                }

                // Check receipt exists
                Receipt__c exitingReceipt = receiptMap.get(request.StandardReceiptId);
                if (exitingReceipt != null) {
                    responses.add(new ReceiptResponse(new List<String>{'Receipt already exists in Salesforce with this Standard Receipt Id: ' + request.StandardReceiptId}, null, request));
                    continue;
                }

                //v1.5 (line 185)
                ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(request.ReceiptCurrency, invoice.CurrencyIsoCode);
                if (rateWrapper == null) { 
                    responses.add(new ReceiptResponse(new List<String>{'Conversion rate not found from ' + request.ReceiptCurrency + 
                            ' currency to ' + invoice.CurrencyIsoCode + ' currency in todays date. Please inform finance team.'}, null, request));
                    continue;
                }

                // Check amount vs balance
               /* Decimal receiptAmountConverted = (request.ReceiptAmount * conversionRate).setScale(2, RoundingMode.HALF_UP);
                Decimal balance = (invoice.InvoiceBalance__c != null && invoice.InvoiceBalance__c > 0) 
                    ? invoice.InvoiceBalance__c : invoice.InvoiceAmount__c;
                
                if (receiptAmountConverted > balance) {
                    responses.add(new ReceiptResponse('FAILED', 
                        'Receipt amount (' + receiptAmountConverted + ' ' + invoice.CurrencyIsoCode + 
                        ') exceeds invoice balance (' + balance + ' ' + invoice.CurrencyIsoCode + ').', request.ReceiptNumber));
                    continue;
                }*/

                // All validations passed - create receipt record
                Receipt__c receipt = new Receipt__c(
                    Account__c = accountRecord.Id,
                    SalesOrderInstallment__c = invoice.SalesOrderInstallment__c,
                    SalesOrder__c = invoice.SalesOrderInstallment__r.SalesOrder__c,
                    CurrencyIsoCode = request.ReceiptCurrency,
                    //v1.4 (line 211)
                    Receipt_Type__c = receiptType,
                    TotalAmount__c = request.ReceiptAmount.setScale(2, RoundingMode.HALF_UP),
                    Modeofpayment__c = modeOfPayment,
                    Status__c = (request.ReceiptStatus.equalsIgnoreCase('Remitted') || request.ReceiptStatus.equalsIgnoreCase('Confirmed')) ? 'In Progress' : request.ReceiptStatus,
                    Bank__c = String.isEmpty(request.CustomerBankName) ? null : request.CustomerBankName,
                    MIRE_Bank__c = mire_BankName,
                    Oracle_Receipt_Id__c = request.StandardReceiptId,
                    //Mode of Payment = Bank Transfer or POS
                    TransactionNumber__c = (modeOfPayment == 'Bank Transfer' || modeOfPayment == 'POS') ? request.ReceiptNumber : null,
                    TransactionDate__c = (modeOfPayment == 'Bank Transfer' || modeOfPayment == 'POS') && String.isNotBlank(request.TransactionDate) 
                        ? DateTime.newInstanceGmt(Date.valueOf(request.TransactionDate), Time.newInstance(0, 0, 0, 0)) : null,
                    IBAN_Swift_Code_last_4_digit__c = (modeOfPayment == 'Bank Transfer') ? swiftCode : null,
                    Last4DigitString__c = (modeOfPayment == 'POS') ? request.CardLast4Digit : null,
                    //Mode of Payment = Cheque
                    Cheque_Number__c  = (modeofpayment == 'Cheque') ? request.ReceiptNumber : null,
                    ChequeDate__c  = (modeOfPayment == 'Cheque' && String.isNotBlank(request.TransactionDate)) 
                        ? Date.valueOf(request.TransactionDate) : null
                );
                
                receiptsToInsert.add(receipt);
                validRequests.add(request);
            
            }

            // ============ STEP 4: Bulk insert receipts ============
            if (!receiptsToInsert.isEmpty()) {
                Database.SaveResult[] saveResults = Database.insert(receiptsToInsert, false);
                
                // Get inserted receipt names
                Set<Id> insertedIds = new Set<Id>();
                for (Database.SaveResult sr : saveResults) {
                    if (sr.isSuccess()) {
                        insertedIds.add(sr.getId());
                    }
                }
                
               // Query inserted receipts with all fields needed for Oracle sync
                Map<Id, Receipt__c> insertedReceipts = new Map<Id, Receipt__c>([
                    SELECT Id, Name, Oracle_Receipt_Id__c, Status__c, Modeofpayment__c,
                           TransactionNumber__c, Cheque_Number__c, UnitNumber__c,
                           AppliedAmount__c, RemainingAmount__c,
                           SalesOrder__c, SalesOrder__r.Name, 
                           SalesOrder__r.Unit__r.UnitClassification__c
                    FROM Receipt__c 
                    WHERE Id IN :insertedIds
                ]);

                // Build responses for inserted records
                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.SaveResult sr = saveResults[i];
                    ReceiptRequest req = validRequests[i];
                    
                    if (sr.isSuccess()) {
                        String sfReceiptNumber = insertedReceipts.get(sr.getId())?.Name;
                        responses.add(new ReceiptResponse(null, sfReceiptNumber, req));
                    } else {
                        List<String> errors = new List<String>();
                        for (Database.Error err : sr.getErrors()) {
                            errors.add(err.getMessage());
                        }
                        responses.add(new ReceiptResponse(errors, null, req));
                    }
                }
                 // ============ STEP 5: Enqueue job to sync receipt details back to Oracle ============
                if (!insertedReceipts.isEmpty()) {
                    //System.enqueueJob(new ModonEgypt_ReceiptOracleSyncQueueable(insertedReceipts.values()));
                }
            }

            return new ReceiptResponseWrapper(responses);

        } catch (Exception e) {
            responses.add(new ReceiptResponse(new List<String>{'Unexpected Error Occurred:' + e.getMessage()}, null, null));
            return new ReceiptResponseWrapper(responses);
        }
    }

    private static List<String> validateRequest(ReceiptRequest request, String modeOfPayment, String swiftCode) {
        List<String> errors = new List<String>();
        
        if (String.isBlank(request.ReceiptCurrency)) errors.add('Receipt Currency is required.');
        if (request.ReceiptAmount == null || request.ReceiptAmount <= 0) errors.add('Receipt Amount must be greater than zero.');
        if (request.AppliedAmount == null || request.AppliedAmount <= 0) errors.add('Applied Amount must be greater than zero.');
        if (String.isBlank(request.ReceiptMethod)) errors.add('Receipt Method is required.');
        if (String.isBlank(request.ReceiptStatus)) errors.add('Receipt Status is required.');
      //  if (String.isBlank(request.CustomerAccountNumber)) errors.add('Customer Number is required.');
        if (String.isBlank(request.StandardInvoiceId)) errors.add('Standard Invoice Id is required.');
        if (String.isBlank(request.StandardReceiptId)) errors.add('Standard Receipt Id is required.');
        if (String.isBlank(request.RemittanceBankAccountNumber)) errors.add('Remittance Bank Account Number is required.');
        if (String.isBlank(request.ReceiptNumber)) errors.add('Recceipt Number is required.');
        if (String.isBlank(request.TransactionDate)) errors.add('Transaction Date is required.');

        return errors;
    }
}