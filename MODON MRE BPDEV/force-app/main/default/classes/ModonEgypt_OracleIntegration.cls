/**
 * @description       : Apex integration service responsible for synchronizing
 *                      Modon Egypt Salesforce data with Oracle ERP.
 *                      Handles Account, Receipt, and Invoice data sync using
 *                      REST-based callouts, metadata-driven configuration,
 *                      and structured wrapper payloads.
 *
 *                      Supports:
 *                      - Account creation and update in Oracle
 *                      - Receipt creation in Oracle
 *                      - Installment and Maintenance invoice generation
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 23-01-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra      Initial Version
 * 2.0	 17-02-2026	  Gautam Mishra		 Updated Invoice Oracle sync data pointers
 * 3.0	 27-02-2026	  Gautam Mishra		 Updated Invoice API data pointers (dates ones) for historical data migration
 * 4.0	 03-03-2026	  Gautam Mishra		 Updated Date data pointers in Reciept Creation API
 * 5.0	 09-03-2026	  Gautam Mishra		 Updated Accounting Date param in Receipt Creation API
 * 6.0	 09-03-2026	  Gautam Mishra		 Updated Flex values with Custom label
 * 7.0	 11-03-2026	  Gautam Mishra		 Updated Receipt Creation Method for Cleared Receipts
 * 8.0	 23-03-2026	  Mirza Baig		 Using database.update instead of update while updating receipts
 * 9.0	 26-03-2026	  Gautam Mishra		 Changed date data pointers of Date of Esatblishment and Milestone date for Account and Invoice
 * 10.0	 30-03-2026	  Gautam Mishra		 Changed date data pointers of Date of Esatblishment, Milestone date, Reciept date for Account, Invoice and Receipt
 * 11.0  02-04-2026	  Gautam Mishra		 Updated queries and code for preventing duplicity of Account, Receipt and Invoice records
 * 12.0  23-04-2026	  Gautam Mishra		 Applied setScale(2) to totalInstallmentAmount and totalMaintenanceAmount in sendInvoiceToOracle method to standardize 2-decimal precision before formatting output
 */
public with sharing class ModonEgypt_OracleIntegration {
    private static Map<Id, String> installmentInvUpdates = new Map<Id, String>();
    private static Map<Id, String> maintenanceInvUpdates = new Map<Id, String>();
    private static Map<Id, String> receiptUpdates = new Map<Id, String>();

    /**
     * @description       : Syncs newly created Modon Egypt Accounts from Salesforce
     *                      to Oracle Customer Master.
     *                      Builds person or business account payloads and performs
     *                      Oracle account creation via REST callout.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra      Initial Version
     * 2.0	 26-03-2026	  Gautam Mishra		 Changed date data pointers of Date of Esatblishment date for Account
     */
    public static void syncAccountToOracle(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        
        List<Account> accounts = [
            SELECT Id, Name, CreatedDate, BillingStreet, BillingCity, BillingCountry, Customer_Number__c,
                   BillingState, BillingPostalCode, PassportExpiryDate__pc,
                   PassportNumber__pc, TradeName__c, UAE_Resident_Status__pc,
                   FirstName, LastName, MiddleName, PersonEmail, Phone, 
                   PersonContactId, PersonContact.Name, IsPersonAccount,
                   PersonMailingCity, PersonMailingCountry, PersonMailingState,
                   PersonMailingStreet, PersonMailingPostalCode, PersonMobilePhone, Egypt_Date_of_Establishment__c,	//v9.0(line 62)
                   UAEVATRegisterNumber__c, Egyptian_ID__pc, UnifiedNumber__c, Organization_ID__c, TradeLicenseExpiryDate__c, Country_Modon_Egypt__c,
           		   (SELECT Id, Email, Phone, MobilePhone, FirstName, MiddleName, LastName, Name, PassportExpiryDate__c, PassportNumber__c, Egyptian_ID__c, UAE_Resident_Status__c
                    FROM Contacts Order By CreatedDate ASC LIMIT 1)
            FROM Account
            WHERE Id IN :accountIds AND Oracle_Customer_Account_Id__c = null	//v11.0 (line 69)
        ];

        List<PersonAccountWrapper> payload = new List<PersonAccountWrapper>();
        List<Account> accToUpdate = new List<Account>();

        for (Account acc : accounts) {
            PersonAccountWrapper pw = new PersonAccountWrapper();
            pw.RecordId = acc.Customer_Number__c;
            pw.CustomerNumber = acc.Customer_Number__c;
            pw.CustomerName = acc.Name; 
            pw.DateOfEstablishment = acc.Egypt_Date_of_Establishment__c != null ? String.valueOf(acc.Egypt_Date_of_Establishment__c) : String.valueOf(acc.CreatedDate.date());	//v9.0 (line 78)

            SiteWrapper site = new SiteWrapper();
            if (acc.IsPersonAccount) {
                site.Emirate = acc.PersonMailingCity;
                site.City = acc.PersonMailingCity;
                site.PersonMailingCity = acc.PersonMailingCity;
                site.PersonMailingCountry = acc.Country_Modon_Egypt__c;
                site.PersonMailingState = acc.PersonMailingState;
                site.PersonMailingStreet = acc.PersonMailingStreet;
                site.PersonMailingPostalCode = acc.PersonMailingPostalCode;
                site.PersonMobilePhone = acc.PersonMobilePhone;
                site.FirstName = acc.FirstName;
                site.LastName = acc.LastName;
            	site.MiddleName = acc.MiddleName;
                site.Mail = acc.PersonEmail;
                site.PassportExpiryDate = acc.PassportExpiryDate__pc != null ? String.valueOf(acc.PassportExpiryDate__pc) : null;
                site.PassportNumber = acc.PassportNumber__pc;
                site.NationalityID = acc.Egyptian_ID__pc;
                site.ResidentialStatus = acc.UAE_Resident_Status__pc;
                site.PhoneNumber = acc.Phone != null ? acc.Phone : acc.PersonMobilePhone;
                site.TradeName = acc.TradeName__c;
                site.TaxRegistrationNumber = acc.UnifiedNumber__c; //'100234567800003';
                site.CommercialRegistrationNumber = acc.Organization_ID__c;
                site.TradeLicenseExpiryDate = acc.TradeLicenseExpiryDate__c != null ? String.valueOf(acc.TradeLicenseExpiryDate__c) : null;
                site.AccountAddressSet = '300000002800197';
                site.IsPersonAccount = acc.IsPersonAccount;
            } else {
                site.AddressLine1 = acc.BillingStreet;
                site.Emirate = acc.BillingCity;
                site.City = acc.BillingCity;
                site.Country = acc.Country_Modon_Egypt__c;
                site.State = acc.BillingState;
                site.PostalCode = acc.BillingPostalCode;
                if(acc.Contacts != null && !acc.Contacts.isEmpty()){
                    site.FirstName = acc.Contacts[0].FirstName;
                    site.MiddleName = acc.Contacts[0].MiddleName;
                    site.LastName = acc.Contacts[0].LastName;
                    site.Mail = acc.Contacts[0].Email;
                    site.PhoneNumber = acc.Contacts[0].MobilePhone;
                }
                site.PassportExpiryDate = null;
                site.PassportNumber = null;
                site.NationalityID = null;
                site.ResidentialStatus = null;
                site.TradeName = acc.TradeName__c;
                site.TaxRegistrationNumber = acc.UnifiedNumber__c; //'100234567800003';
                site.CommercialRegistrationNumber = acc.Organization_ID__c;
                site.TradeLicenseExpiryDate = acc.TradeLicenseExpiryDate__c != null ? String.valueOf(acc.TradeLicenseExpiryDate__c) : null;
                site.AccountAddressSet = '300000002800197';
                site.IsPersonAccount = acc.IsPersonAccount;
            }

            pw.Sites = new List<SiteWrapper>{ site };
            // Callout and collect transaction ID
            ResponseWrapper response = performCallout('Account', pw, 'Insert', acc.Id, null);
            if (response != null) {
                Account recToUpdate = new Account(Id = acc.Id);
                recToUpdate.Oracle_Customer_Account_Id__c = response.CustomerAccountId;
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = response.Status;
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = response.Message;
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = response.StatusCode;
                recToUpdate.Oracle_Account_Contact_Status__c = response.ContactStatus;
                recToUpdate.Oracle_Account_Tax_Status__c = response.TaxStatus;
                accToUpdate.add(recToUpdate);
            }
        }
        
        // Perform DML operations after all callouts are complete
        if (!accToUpdate.isEmpty()) {
            AccountTriggerHandler.createApiExecuted_ModonEgypt = true;
            update accToUpdate;
        }

    }

    /**
     * @description       : Updates existing Oracle Customer Master records whenever
     *                      relevant Account fields are modified in Salesforce.
     *                      Supports both Person Accounts and Business Accounts.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public static void updateAccountInOracle(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Account> accounts = [
            SELECT Id, Name, CreatedDate, BillingStreet, BillingCity, BillingCountry, Customer_Number__c,
                   BillingState, BillingPostalCode, PassportExpiryDate__pc,
                   PassportNumber__pc, TradeName__c, UAE_Resident_Status__pc,
                   FirstName, LastName, MiddleName, PersonEmail, Phone, Country_Modon_Egypt__c,
                   PersonContactId, PersonContact.Name, IsPersonAccount,
                   PersonMailingCity, PersonMailingCountry, PersonMailingState,
                   PersonMailingStreet, PersonMailingPostalCode, PersonMobilePhone, Oracle_Account_Contact_Status__c, Oracle_Account_Tax_Status__c,
                   UAEVATRegisterNumber__c, Egyptian_ID__pc, UnifiedNumber__c, Organization_ID__c, TradeLicenseExpiryDate__c,
           		   (SELECT Id, Email, Phone, MobilePhone, MiddleName, FirstName, LastName, Name, PassportExpiryDate__c, PassportNumber__c, Egyptian_ID__c, UAE_Resident_Status__c, CreatedDate
                    FROM Contacts ORDER BY CreatedDate ASC LIMIT 1)
            FROM Account
            WHERE Id IN :accountIds
        ];

        List<AccountUpdateWrapper> payload = new List<AccountUpdateWrapper>();
        List<Account> accToUpdate = new List<Account>();

        for (Account acc : accounts) {
            AccountUpdateWrapper wrapper = new AccountUpdateWrapper();
            wrapper.CustomerNumber = acc.Customer_Number__c;
            if (acc.IsPersonAccount) {
                wrapper.AddressLine1 = acc.PersonMailingStreet;
                wrapper.Emirate = acc.PersonMailingCity;
                wrapper.City = acc.PersonMailingCity;
                wrapper.PersonMailingCity = acc.PersonMailingCity;
                wrapper.PersonMailingCountry = acc.Country_Modon_Egypt__c;
                wrapper.Country = acc.Country_Modon_Egypt__c;
                wrapper.PersonMailingState = acc.PersonMailingState;
                wrapper.PersonMailingStreet = acc.PersonMailingStreet;
                wrapper.PersonMailingPostalCode = acc.PersonMailingPostalCode;
                wrapper.PersonMobilePhone = acc.PersonMobilePhone;
                wrapper.FirstName = acc.FirstName;
                wrapper.LastName = acc.LastName;
                wrapper.MiddleName = acc.MiddleName;
                wrapper.IsPersonAccount = 'TRUE';
                wrapper.Mail = acc.PersonEmail;
                wrapper.PassportExpiryDate = acc.PassportExpiryDate__pc != null ? String.valueOf(acc.PassportExpiryDate__pc) : null;
                wrapper.PassportNumber = acc.PassportNumber__pc;
                wrapper.NationalityID = acc.Egyptian_ID__pc;
                wrapper.ResidentialStatus = acc.UAE_Resident_Status__pc;
                wrapper.PhoneNumber = acc.Phone != null ? acc.Phone : acc.PersonMobilePhone;
                wrapper.TradeName = acc.TradeName__c;
                wrapper.TradeLicenseExpiryDate = acc.TradeLicenseExpiryDate__c != null ? String.valueOf(acc.TradeLicenseExpiryDate__c) : null;
                wrapper.CommercialRegistrationNumber = acc.Organization_ID__c;
                wrapper.TaxRegistrationNumber = acc.UnifiedNumber__c;
            } else {
                wrapper.AddressLine1 = acc.BillingStreet;
                wrapper.Emirate = acc.BillingCity;
                wrapper.City = acc.BillingCity;
                wrapper.Country = acc.Country_Modon_Egypt__c;
                wrapper.State = acc.BillingState;
                wrapper.PostalCode = acc.BillingPostalCode;
                if(acc.Contacts != null && !acc.Contacts.isEmpty()){
                    wrapper.FirstName = acc.Contacts[0].FirstName;
                    wrapper.MiddleName = acc.Contacts[0].MiddleName;
                    wrapper.LastName = acc.Contacts[0].LastName;
                	wrapper.Mail = acc.Contacts[0].Email;
                	wrapper.PhoneNumber = acc.Contacts[0].MobilePhone;
                }
                wrapper.IsPersonAccount = 'FALSE';
                wrapper.PassportExpiryDate = null;
                wrapper.PassportNumber = null;
                wrapper.NationalityID = null;
                wrapper.ResidentialStatus = null;
                wrapper.TaxRegistrationNumber = acc.UnifiedNumber__c;
            }
            
            //payload.add(wrapper);
            
            ResponseWrapper response = performCallout('Account', wrapper, 'Update', acc.Id, null);
            if (response != null) {
                Account recToUpdate = new Account(Id = acc.Id);
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = response.Status;
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = response.Message;
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = response.StatusCode;
                recToUpdate.Oracle_Account_Contact_Status__c = String.isBlank(response.ContactStatus) == false ? response.ContactStatus : acc.Oracle_Account_Contact_Status__c;
                recToUpdate.Oracle_Account_Tax_Status__c = String.isBlank(response.TaxStatus) == false ? response.TaxStatus : acc.Oracle_Account_Tax_Status__c;
                accToUpdate.add(recToUpdate);
            }
        }
        
        if (!accToUpdate.isEmpty()) {
            update accToUpdate;
        }
    }
    
    /**
     * @description       : Builds a unique composite key used to map
     *                      receipt configuration metadata based on
     *                      payment mode, bank, currency, and source object.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    private static String buildKey(String modeOfPayment, String bankName, String currencyCode, String parentObj) {
        return modeOfPayment + '|' + bankName + '|' + currencyCode + '|' + parentObj;
    }
    
    //v7.0 (lines 274-276)
    private static String buildClearedKey(String bankName, String currencyCode) {
        return bankName + '|' + currencyCode;
    }

    /**
     * @description       : Syncs Salesforce Receipts to Oracle Receivables.
     *                      Dynamically derives receipt method and remittance
     *                      bank account using custom metadata mappings.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     * 2.0	 30-03-2026	  Gautam Mishra		 Changed date data pointers of Receipt date for Receipt
     */
    public static void syncReceiptToOracle(Set<Id> receiptIds) {
    
        // Query Receipts
        List<Receipt__c> receipts = [
            SELECT Id, Name, Modeofpayment__c, Bank__c, CurrencyISOCode, TotalAmount__c, ReceiptDate__c, Account__c, Account__r.Id, Account__r.Name,
                   SalesOrder__c, ExpressionOfInterest__c, ExpressionOfInterest__r.Name, ExpressionOfInterest__r.UnitType__c,
                   UnitNumber__c, Cheque_Number__c, ChequeDate__c, TransactionNumber__c, Receipt_Amount__c, AppliedAmount__c,
            	   SalesOrderInstallment__c, SalesOrderInstallment__r.MilestoneDescription__c,
            	   RemainingAmount__c, Status__c, Account__r.Customer_Number__c, SalesOrder__r.Name, Account__r.Egypt_Date_of_Establishment__c, //v10.0 (line 304)
            	   SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__r.UnitClassification__c, CreatedDate,MIRE_Bank__c
            FROM Receipt__c
            WHERE Id IN :receiptIds AND Oracle_Receipt_Id__c = null		//v11.0 (line 308)
        ];
    
        Map<String, Modon_Receipt_Mapping__mdt> metdataMap = new Map<String, Modon_Receipt_Mapping__mdt>();
        
        for (Modon_Receipt_Mapping__mdt metadataRecord : [
            SELECT Mode_of_Payment__c, Bank_Name__c, Currency__c,
                   Receipt_Method__c, Remittance_Bank_Account_No__c, Associated_Object__c
            FROM Modon_Receipt_Mapping__mdt
        ]) {
            //v7.0 (lines 313-321)
            if(String.isBlank(metadataRecord.Mode_of_Payment__c)){
                // Cleared mapping
                String key = buildClearedKey(metadataRecord.Bank_Name__c, metadataRecord.Currency__c);
                metdataMap.put(key, metadataRecord);
            }
            else{
                // Existing mapping
                String key = buildKey(metadataRecord.Mode_of_Payment__c, metadataRecord.Bank_Name__c, metadataRecord.Currency__c, metadataRecord.Associated_Object__c);
                metdataMap.put(key, metadataRecord);
            }
        }
    
        // Process receipts and collect transaction IDs for post-callout DML
        List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
        
        for (Receipt__c rec : receipts) {  
            
            //Derive Receipt Method and RemittanceBankAccountNumber
            String objName;
            String receiptMethod = null;
            String remittanceBankAccountNumber = null;
            if(rec.SalesOrder__c != null){
                String key;
                if(rec.SalesOrderInstallment__c != null && rec.SalesOrderInstallment__r.MilestoneDescription__c != null && rec.SalesOrderInstallment__r.MilestoneDescription__c.contains('Installment')){
                    objName = 'Sales Order - Installment';
                }
                else if(rec.SalesOrderInstallment__c != null && rec.SalesOrderInstallment__r.MilestoneDescription__c != null && rec.SalesOrderInstallment__r.MilestoneDescription__c.contains('Downpayment')){
                    objName = 'Sales Order - Downpayment';
                }
                
                //v7.0 (lines 344-349)
                if('Cleared'.equalsIgnoreCase(rec.Status__c)){
                    key = buildClearedKey(rec.MIRE_Bank__c, rec.CurrencyISOCode);
                }
                else{
                    key = buildKey(rec.Modeofpayment__c, rec.MIRE_Bank__c, rec.CurrencyISOCode, objName);
                }
                
                if(metdataMap.containsKey(key)){
                    Modon_Receipt_Mapping__mdt mapping = metdataMap.get(key);
                    receiptMethod = mapping.Receipt_Method__c;
                    remittanceBankAccountNumber = mapping.Remittance_Bank_Account_No__c;
                }
            }
            else if(rec.ExpressionOfInterest__c != null){
                String key;
                objName = 'Expression of Interest';
                
                //v7.0 (lines 362-367)
                if('Cleared'.equalsIgnoreCase(rec.Status__c)){
                    key = buildClearedKey(rec.MIRE_Bank__c, rec.CurrencyISOCode);
                }
                else{
                    key = buildKey(rec.Modeofpayment__c, rec.MIRE_Bank__c, rec.CurrencyISOCode, objName);
                }
                
                if(metdataMap.containsKey(key)){
                    Modon_Receipt_Mapping__mdt mapping = metdataMap.get(key);
                    receiptMethod = mapping.Receipt_Method__c;
                    remittanceBankAccountNumber = mapping.Remittance_Bank_Account_No__c;
                }
            }
    
            ReceiptWrapper rw = new ReceiptWrapper();
            rw.ReceiptNumber = rec.Modeofpayment__c == 'Cheque' ? rec.Cheque_Number__c :  rec.TransactionNumber__c;
            rw.MaturityDate = rec.Modeofpayment__c == 'Cheque' ? rec.ChequeDate__c : null;
            rw.BusinessUnit = 'RAS EL HEKMA-EGYPT-BU';
            rw.ReceiptMethod = receiptMethod;
            rw.CurrencyCode = rec.CurrencyISOCode;
            rw.Amount = rec.TotalAmount__c;
            //v4.0 (line 354)
            //v10.0 (lines 390-392)
            Date base = (rw.MaturityDate != null && rw.MaturityDate < rec.CreatedDate.date()) ? rw.MaturityDate : rec.CreatedDate.date();
            rw.ReceiptDate = (rec.Account__r.Egypt_Date_of_Establishment__c != null && rec.Account__r.Egypt_Date_of_Establishment__c > base)
                				? rec.Account__r.Egypt_Date_of_Establishment__c : base;
            //v5.0 (line 357)
            //v10.0 (line 395)
            rw.AccountingDate = rw.ReceiptDate;
            rw.CustomerAccountNumber = rec.Account__c != null ? rec.Account__r.Customer_Number__c : null;
            rw.CustomerName = rec.Account__c != null ? rec.Account__r.Name : null;
            rw.RemittanceBankAccountNumber = remittanceBankAccountNumber;
            rw.ConversionRateType = 'Corporate';
            //v4.0 (line 360)
            rw.ConversionDate = String.valueof(rw.ReceiptDate);
    
            // Flex fields
            ReceiptFlexWrapper flex = new ReceiptFlexWrapper();
            flex.FLEX_Context = System.Label.ModonEgypt_Receipt_FLEX_Value;//v6.0
            flex.FLEX_Context_DisplayValue = System.Label.ModonEgypt_Receipt_FLEX_Value;//v6.0
            flex.sfReceiptNo = rec.Name;
            flex.eoiNumber = rec.ExpressionOfInterest__c != null ? rec.ExpressionOfInterest__r.Name : null;
            flex.modeOfPayment = rec.Modeofpayment__c;
            flex.salesOrderNumber = rec.SalesOrder__c != null ? rec.SalesOrder__r.Name : null;
            flex.unittype = rec.SalesOrder__c != null ? rec.SalesOrder__r.Unit__r.UnitClassification__c  : null;
            flex.unitNumber = rec.SalesOrder__c != null ? rec.SalesOrder__r.Unit__r.Name : null;
            flex.appliedAmount = rec.AppliedAmount__c;
            flex.remainingAmount = rec.RemainingAmount__c;
            flex.receiptStatus = rec.Status__c;
            flex.customerBankName = rec.Bank__c;
    
            rw.standardReceiptDFF = new List<ReceiptFlexWrapper>{ flex };
    
            // Callout and collect transaction ID
            ResponseWrapper response = performCallout('Receipt__c', rw, 'Insert', rec.Id, null);
            if (response != null) {
                Receipt__c recToUpdate = new Receipt__c(Id = rec.Id);
                recToUpdate.Oracle_Receipt_Id__c = response.StandardReceiptId;
                recToUpdate.Oracle_Integration_Status_Modon_Egypt__c = response.Status;
                recToUpdate.Oracle_Integration_Message_Modon_Egypt__c = response.Message;
                recToUpdate.Oracle_Status_Code_Modon_Egypt__c = response.StatusCode;
                //v5.0 (lines 391 - 393)
                if(!String.isBlank(response.AccountingDate)){
                    recToUpdate.AccountingDate_Egypt__c = Date.valueOf(response.AccountingDate);
                }
                receiptsToUpdate.add(recToUpdate);
            }
        }
        
        // Perform DML operations after all callouts are complete
        if (!receiptsToUpdate.isEmpty()) {
            //update receiptsToUpdate;
            //v8.0
            Database.SaveResult[] results = Database.update(receiptsToUpdate, false);

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    System.debug('Record updated successfully: ' + receiptsToUpdate[i].Id);
                } else {
                    for (Database.Error err : results[i].getErrors()) {
                        System.debug('Error for record ' + receiptsToUpdate[i].Id + ': ' + err.getMessage());
                    }
                }
            }
            //end
        }
    }
    
    
     /**
     * @description       : Syncs Salesforce Invoices to Oracle Receivables.
     *                      Sends installment invoices and conditionally sends
     *                      maintenance invoices when applicable.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     * 2.0	 17-02-2026	  Gautam Mishra		 Updated Invoice Oracle sync data pointers
     * 3.0 	 26-03-2026	  Gautam Mishra		 Added Egypt_Date_of_Establishment__c in query of Invoice
     */
    public static void syncInvoicesToOracle(Set<Id> invoiceIds) {

        // Fetch all invoices
        Map<Id, Invoice__c> invMap = new Map<Id, Invoice__c>(
            [
                SELECT Id, Name, InvoiceAmount__c,
                       CurrencyIsoCode,
                       Account__r.Name, Account__r.Customer_Number__c,
                       Account__r.PersonMailingCity, Account__r.BillingCity, Account__r.Egypt_Date_of_Establishment__c, //v9.0 (line 473)
                       SalesOrderInstallment__c, Oracle_Installment_Invoice_Id__c, Oracle_Maintenance_Invoice_Id__c,
                	   Oracle_Integration_Message_Modon_Egypt__c, Oracle_Status_Code_Modon_Egypt__c
                FROM Invoice__c
                WHERE Id IN :invoiceIds
            ]
        );

        // Collect SOI Ids
        Set<Id> soiIds = new Set<Id>();
        for (Invoice__c inv : invMap.values()) {
            if (inv.SalesOrderInstallment__c != null)
                soiIds.add(inv.SalesOrderInstallment__c);
        }

        // Fetch all SOIs
        Map<Id, SalesOrderInstallments__c> soiMap =
            new Map<Id, SalesOrderInstallments__c>(
                [
                    SELECT Id, InstallmentAmount__c, Maintenance_Fee__c,
                    	Instalment_Number__c, SalesOrder__c, MilestoneDate__c, MilestoneDescription__c,
                    	
                    	/* Sales Order fields used */
                   		SalesOrder__r.Name,
                   		SalesOrder__r.PaymentPlan__r.Name,
                   		SalesOrder__r.ProjectName__c,
                   		SalesOrder__r.Status__c,
                    	//v2.0(lines 444-446)
                    	SalesOrder__r.EgyptTotalInstallmentAmount__c,
                    	SalesOrder__r.EgyptTotalMaintenanceAmount__c,
                    	SalesOrder__r.Unit_Selling_Price__c,
                    
                    	//V3.0(line 450)
                    	SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c,
                    	
                   		
                    	/* Unit fields used */
                    	SalesOrder__r.Unit__r.Name,
                        SalesOrder__r.Unit__r.GrossFloorAreaGFA__c,
                        SalesOrder__r.Unit__r.PlotAreasqm__c,
                        SalesOrder__r.Unit__r.UnitClassification__c,
                    	SalesOrder__r.Unit__r.Phase__r.Project__r.ProjectNumber__c,
                    	
						/* Phase fields */
                        SalesOrder__r.Unit__r.Phase__r.Name
                    FROM SalesOrderInstallments__c
                    WHERE Id IN :soiIds
                ]
            );

        // Process each invoice and collect transaction IDs for post-callout DML
        Map<Id, Invoice__c> invoicesToUpdate = new Map<Id, Invoice__c>();
        
        //v11.0 (line 533-566)
        for (Invoice__c inv : invMap.values()) {

            SalesOrderInstallments__c soi = soiMap.get(inv.SalesOrderInstallment__c);
            if (soi == null) continue;
        
            Invoice__c invToUpdate = invoicesToUpdate.get(inv.Id);
            if (invToUpdate == null) {
                invToUpdate = new Invoice__c(Id = inv.Id);
                invoicesToUpdate.put(inv.Id, invToUpdate);
            }
        
            // Sync Installment ONLY if not already synced
            if (inv.Oracle_Installment_Invoice_Id__c == null) {
                ResponseWrapper response = sendInvoiceToOracle(inv, soi, false);
                if (response != null) {
                    invToUpdate.Oracle_Installment_Invoice_Id__c = response.CustomerTransactionId;
                    invToUpdate.Oracle_Integration_Status_Modon_Egypt__c = response.Status;
                    invToUpdate.Oracle_Integration_Message_Modon_Egypt__c = response.Message;
                    invToUpdate.Oracle_Status_Code_Modon_Egypt__c = response.StatusCode;
                }
            }
        
            // Sync Maintenance ONLY if applicable AND not already synced
            if (soi.Maintenance_Fee__c > 0 && inv.Oracle_Maintenance_Invoice_Id__c == null) {
                ResponseWrapper response = sendInvoiceToOracle(inv, soi, true);
                if (response != null) {
                    invToUpdate.Oracle_Maintenance_Invoice_Id__c = response.CustomerTransactionId;
                    invToUpdate.Oracle_Integration_Status_Modon_Egypt__c = response.Status;
                    invToUpdate.Oracle_Integration_Message_Modon_Egypt__c = response.Message;
                    invToUpdate.Oracle_Status_Code_Modon_Egypt__c = response.StatusCode;
                }
            }
        }
        
        // Perform DML operations after all callouts are complete
        if (!invoicesToUpdate.isEmpty()) {
            System.debug(invoicesToUpdate.values());
            update invoicesToUpdate.values();
        }
    }

    /**
     * @description       : Constructs Oracle invoice payload and performs
     *                      REST callout for installment or maintenance invoices.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     * 2.0	 17-02-2026	  Gautam Mishra		 Updated Invoice Oracle sync data pointers
     * 3.0 	 27-02-2026	  Gautam Mishra		 Updated Invoice API data pointers (dates ones) for historical data migration
     * 4.0	 26-03-2026	  Gautam Mishra		 Changed date data pointers of Milestone date for Invoice
     * 5.0	 30-03-2026	  Gautam Mishra		 Changed date data pointers of Milestone date for Invoice
     */
    private static ResponseWrapper sendInvoiceToOracle(Invoice__c inv, SalesOrderInstallments__c soi, Boolean isMaintenance) {
        
        //v3.0(lines 529-549)
        // ===== Derive Transaction Date =====
        Date milestoneDate = inv.Account__r.Egypt_Date_of_Establishment__c == null ? soi.MilestoneDate__c : (inv.Account__r.Egypt_Date_of_Establishment__c < soi.MilestoneDate__c ? soi.MilestoneDate__c : inv.Account__r.Egypt_Date_of_Establishment__c);	//v9.0(line 588) //v10.0
        
        // Convert SPA DateTime to Date (null safe)
        Date spaSignedDate = 
            soi.SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c != null
            ? soi.SalesOrder__r.SPA_Signed_Date_Time_Modon_Egypt__c.date()
            : Date.today();
        
        Date transactionDate = null;
        
        // Null handling logic
        if (milestoneDate != null && spaSignedDate != null) {
            transactionDate = milestoneDate < spaSignedDate ? milestoneDate : spaSignedDate;
        }
        else if (milestoneDate != null) {
            transactionDate = milestoneDate;
        }
        else if (spaSignedDate != null) {
            transactionDate = spaSignedDate;
        }

        InvoiceRequest req = new InvoiceRequest();

        req.BusinessUnit = 'RAS EL HEKMA-EGYPT-BU';

        // If maintenance invoice → change transaction number
        req.TransactionNumber = inv.Name;
        //v3.0(lines 559-560)
        req.DueDate = String.valueof(milestoneDate);
        req.TransactionDate = transactionDate;
        req.TransactionType = isMaintenance ? 'MDN_SF_MAINTENANCE' : 'MDN_SF_INVOICE';
        req.TransactionSource = 'MDN_SF_SOURCE';
        req.InvoiceCurrencyCode = inv.CurrencyIsoCode;
        //v3.0(lines 565-566)
        req.AccountingDate = transactionDate;
        req.ConversionDate = inv.CurrencyIsoCode == 'EGP' ? null : transactionDate;
        req.ConversionRate = null;
        req.ConversionRateType = inv.CurrencyIsoCode == 'EGP' ? null : 'Corporate';

        req.BillToCustomerName = inv.Account__r.Name;
        req.BillToCustomerNumber = inv.Account__r.Customer_Number__c;
        req.BillToSite = inv.Account__r.Customer_Number__c;
        req.Comments = null;
        req.PaymentTerms = 'IMMEDIATE';
        req.RemitToAddress = null;
        req.LegalEntityIdentifier = 'MHIRE RFD';

        /*
         * ============= INVOICE LINES =============
         */
        ReceivablesInvoiceLine line = new ReceivablesInvoiceLine();
        line.LineNumber = 1;
        line.Description = isMaintenance ? 'Maintenance Line' : soi.MilestoneDescription__c;
        line.Quantity = 1;
        line.UnitSellingPrice = isMaintenance
            ? soi.Maintenance_Fee__c
            : soi.InstallmentAmount__c;

        line.TaxClassificationCode = 'EG_EXEMPT';

        req.receivablesInvoiceLines = new List<ReceivablesInvoiceLine>{ line };

        /*
         * ============= DFF =============
         */
        ReceivablesInvoiceDFF dff = new ReceivablesInvoiceDFF();
        dff.unitNumber = soi.SalesOrder__r.Unit__r.Name;
        dff.gfa = String.valueOf(soi.SalesOrder__r.Unit__r.GrossFloorAreaGFA__c);
        dff.plotArea = String.valueOf(soi.SalesOrder__r.Unit__r.PlotAreasqm__c);
        //v2.0(line 571)
        dff.unitSellingPrice = String.valueOf(soi.SalesOrder__r.Unit_Selling_Price__c);
        dff.paymentPlanName = soi.SalesOrder__r.PaymentPlan__r.Name;
        dff.reasonForUpdate = null;
        dff.FLEX_Context = null;
        dff.FLEX_Context_DisplayValue = null;

        req.receivablesInvoiceDFF = new List<ReceivablesInvoiceDFF>{ dff };

        /*
         * ============= TX DFF (static or from SOI if needed) =============
         */
        ReceivablesInvoiceTransactionDFF tx = new ReceivablesInvoiceTransactionDFF();
        tx.FLEX_Context = 'SF Invoice Details';
        tx.FLEX_Context_DisplayValue = 'SF Invoice Details';
        tx.salesorderNo = soi.SalesOrder__r.Name;
        tx.installmentNo = soi.Instalment_Number__c ;
        tx.unitNumber = null;
        tx.projectNumber = soi.SalesOrder__r.Unit__r.Phase__r.Project__r.ProjectNumber__c;
        tx.unitType = soi.SalesOrder__r.Unit__r.UnitClassification__c;
        tx.unitStatus = soi.SalesOrder__r.Status__c;
        
        String unitName = soi.SalesOrder__r.Unit__r.Name;
        tx.unitName = unitName != null ? (unitName.length() > 30 ? unitName.substring(0, 30) : unitName) : null;
        
        String phaseName = soi.SalesOrder__r.Unit__r.Phase__r.Name;
        tx.phaseName = phaseName != null ? (phaseName.length() > 30 ? phaseName.substring(0, 30) : phaseName) : null;
        
        //v2.0(lines 599-600)
        tx.totalInstallmentAmount = (soi.SalesOrder__r.EgyptTotalInstallmentAmount__c).setScale(2).format();	//v12.0
        tx.totalMaintenanceAmount = (soi.SalesOrder__r.EgyptTotalMaintenanceAmount__c).setScale(2).format();	//v12.0
        tx.landArea = String.valueOf(soi.SalesOrder__r.Unit__r.PlotAreasqm__c);
        tx.builtUpArea = String.valueOf(soi.SalesOrder__r.Unit__r.GrossFloorAreaGFA__c);
        
        String projectName = soi.SalesOrder__r.ProjectName__c;
        tx.projectName = projectName != null ? (projectName.length() > 30 ? projectName.substring(0, 30) : projectName) : null;

        req.receivablesInvoiceTransactionDFF =
            new List<ReceivablesInvoiceTransactionDFF>{ tx };
                
        System.debug('Payload>>> '+req);
                
        
        return performCallout('Invoice__c', req, 'Insert', inv.Id, isMaintenance);
    }

    /**
     * @description       : Performs REST callout to Oracle using metadata-driven
     *                      endpoint configuration.
     *                      Handles Account, Receipt, and Invoice response parsing
     *                      and standardizes Oracle integration responses.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    private static ResponseWrapper performCallout(String objectName, Object payload, String operationType, Id recordId, Boolean isMaintenance) {
        ResponseWrapper response = new ResponseWrapper();
        
        String transactionId = null;
        try {
            Boolean isSandboxOrg = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            
            // Fetch metadata config for this object
            List<Oracle_Integration_Config__mdt> configs = [
                SELECT Endpoint__c, Username__c, Password__c
                FROM Oracle_Integration_Config__mdt
                WHERE Object_API_Name__c = :objectName AND Operation_Type__c =: operationType AND Is_Sandbox__c =: isSandboxOrg
                LIMIT 1
            ];
    
            Oracle_Integration_Config__mdt config;
            
            if (!configs.isEmpty()) {
                config = configs[0];
            } 
            else {
                response.Status = 'Failed';
                response.StatusCode = '500';
                if(objectName == 'Account' && operationType == 'Insert'){
                    response.Message = 'Creation Failed : Invalid Credentials or Credentials are not available in metadata records';
                }
                else if(objectName == 'Account' && operationType == 'Update'){
                    response.Message = 'Update Failed : Invalid Credentials or Credentials are not available in metadata records';
                }
                else{
                    response.Message = 'Syncing Failed : Invalid Credentials or Credentials are not available in metadata records';
                }
                return response;
            }
    
            // Build Basic Auth header
            String authHeader = 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(config.Username__c + ':' + config.Password__c)
            );
            
            String payloadString = JSON.serialize(payload);
            
            if (objectName == 'Receipt__c') {
                payloadString = payloadString.replace('"CurrencyCode"', '"Currency"');
                payloadString = payloadString.replaceAll('"FLEX_Context"(?=\\s*:)', '"__FLEX_Context"');
                payloadString = payloadString.replaceAll('"FLEX_Context_DisplayValue"(?=\\s*:)', '"__FLEX_Context_DisplayValue"');
            }
            
            if (objectName == 'Invoice__c') {
                payloadString = payloadString.replace('"CurrencyCode"', '"Currency"');
                payloadString = payloadString.replaceAll('"FLEX_Context"(?=\\s*:)', '"__FLEX_Context"');
                payloadString = payloadString.replaceAll('"FLEX_Context_DisplayValue"(?=\\s*:)', '"__FLEX_Context_DisplayValue"');
            }

            // Prepare HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(config.Endpoint__c); // full URL from metadata
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', authHeader);
            req.setBody(payloadString);
            req.setTimeout(120000);
    
            Http http = new Http();
            HttpResponse res = http.send(req);
    
            System.debug('Oracle Sync Sent -> ' + objectName +
                         ' | Status: ' + res.getStatusCode() +
                         ' | Body: ' + res.getBody());
            
            if (objectName == 'Account' && recordId != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
            
                try {
                    if(operationType == 'Insert'){
                        List<Object> responseList = (List<Object>) JSON.deserializeUntyped(res.getBody());
            
                        if (!responseList.isEmpty()) {
                            Map<String, Object> resMap = (Map<String, Object>) responseList[0];
                
                            String status     = (String) resMap.get('Status');
                            String message    = (String) resMap.get('Message');
                            String statusCode = (String) resMap.get('StatusCode');
                
                            if ('Failure'.equalsIgnoreCase(status)) {
                                response.Status = 'Failed';
                                response.StatusCode = statusCode;
                                response.Message = 'Creation Failed : ' + message;
                                response.CustomerAccountId = String.valueOf(resMap.get('CustomerAccountId'));
                            }
                            else if('Success'.equalsIgnoreCase(status)){
                                response.Status = 'Success';
                                response.StatusCode = statusCode;
                                response.Message = 'Created Successfully: '+ message;
                                response.CustomerAccountId = String.valueOf(resMap.get('CustomerAccountId'));
                                
                                // ===== NEW: Parse Sites =====
                                if (resMap.containsKey('Sites')) {
                                    List<Object> sites = (List<Object>) resMap.get('Sites');
                                    if (!sites.isEmpty()) {
                                        Map<String, Object> site = (Map<String, Object>) sites[0];
                                        
                                        response.ContactStatus  = (String) site.get('ContactStatus');
                                        response.TaxStatus      = (String) site.get('TaxStatus');
                                    }
                                }
                            }
                        }
                    }
                    
                    else if(operationType == 'Update'){
                        List<Object> responseList = (List<Object>) JSON.deserializeUntyped(res.getBody());
            
                        if (!responseList.isEmpty()) {
                            Map<String, Object> resMap = (Map<String, Object>) responseList[0];
                
                            String status     = (String) resMap.get('Status');
                            String message    = (String) resMap.get('Message');
                
                            if ('Failed'.equalsIgnoreCase(status) || 'Failure'.equalsIgnoreCase(status)) {
                                response.Status = 'Failed';
                                response.StatusCode = '400';
                                response.Message = 'Update Failed : ' + message;
                            }
                            else if('Success'.equalsIgnoreCase(status)){
                                if(message.containsIgnoreCase('Tax')){
                                    response.Status = 'Success';
                                    response.StatusCode = '400';
                                    response.Message = 'Updated Partially: '+ message;
                                    response.TaxStatus = 'Failed';
                                }
                                else if(message.containsIgnoreCase('Contact')){
                                    response.Status = 'Success';
                                    response.StatusCode = '400';
                                    response.Message = 'Updated Partially: '+ message;
                                    response.ContactStatus = 'Failed';
                                }
                                else{
                                    response.Status = 'Success';
                                    response.StatusCode = '200';
                                    response.Message = 'Updated Successfully: '+ message;
                                    response.TaxStatus = 'Success';
                                    response.ContactStatus = 'Success';
                                }
                            }
                        }
                    }
                    
                } catch (Exception ex) {
                    response.Status = 'Failed';
                    response.StatusCode = '500';
                    response.Message = 'Callout Exception - Response parsing error: ' + ex.getMessage();
                }
            }

        
            if (objectName == 'Invoice__c' && recordId != null) {
                try {
                    if((res.getStatusCode() == 200 || res.getStatusCode() == 201)){
                        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        
                        response.Status = 'Success';
                        response.StatusCode = String.valueof(res.getStatusCode());
                        response.Message = 'Created Successfully: Invoice synced successfully in Oracle';
                        response.CustomerTransactionId = String.valueOf(resMap.get('CustomerTransactionId'));
                    }
                    
                    else if((res.getStatusCode() == 400 || res.getStatusCode() == 401 || res.getStatusCode() == 500)){
                        response.Status = 'Failed';
                        response.StatusCode = String.valueof(res.getStatusCode());
                        response.Message = 'Creation Failed : ' + res.getBody();
                        response.CustomerTransactionId = null;
                    }
                    
                } catch (Exception jsonEx) {
                    System.debug('Error parsing invoice response: ' + jsonEx.getMessage());
                    response.Status = 'Failed';
                    response.StatusCode = '500';
                    response.Message = 'Callout Exception - Response parsing error: ' + jsonEx.getMessage();
                    response.CustomerTransactionId = null;
                }
            }
            
            if (objectName == 'Receipt__c' && recordId != null) {
                try {
                    if((res.getStatusCode() == 200 || res.getStatusCode() == 201)){
                        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        
                        response.Status = 'Success';
                        response.StatusCode = String.valueof(res.getStatusCode());
                        response.Message = 'Created Successfully: Receipt synced successfully in Oracle';
                        response.StandardReceiptId = String.valueOf(resMap.get('StandardReceiptId'));
                        //v5.0 (line 862)
                        response.AccountingDate = String.valueOf(resMap.get('AccountingDate'));
                        
                        System.debug('transactionId>>> '+transactionId);
                    }
                    
                    else if((res.getStatusCode() == 400 || res.getStatusCode() == 401 || res.getStatusCode() == 500)){
                        response.Status = 'Failed';
                        response.StatusCode = String.valueof(res.getStatusCode());
                        response.Message = 'Creation Failed : ' + res.getBody();
                        response.StandardReceiptId = null;
                        //v5.0 (line 873)
                        response.AccountingDate = null;
                    }
    
                } catch (Exception jsonEx) {
                    System.debug('Error parsing receipt response: ' + jsonEx.getMessage());
                    response.Status = 'Failed';
                    response.StatusCode = '500';
                    response.Message = 'Callout Exception - Response parsing error: ' + jsonEx.getMessage();
                    response.StandardReceiptId = null;
                    //v5.0 (line 883)
                    response.AccountingDate = null;
                }
            }
    
        } catch (Exception e) {
            System.debug('Oracle callout failed for ' + objectName + ': ' + e.getMessage());
            response.Status = 'Failed';
            response.StatusCode = '500';
            response.Message = 'Callout Exception - Oracle callout failed for ' + objectName + ': ' + e.getMessage();
        }
        return response;
    }
    
    // --------------------- INVOICE WRAPPERS ---------------------
    public class ReceivablesInvoiceLine {
        public Integer LineNumber;
        public String Description;
        public Decimal Quantity;
        public Decimal UnitSellingPrice;
        public String TaxClassificationCode;
    }

    public class ReceivablesInvoiceDFF {
        public String unitNumber;
        public String gfa;
        public String plotArea;
        public String unitSellingPrice;
        public String paymentPlanName;
        public String reasonForUpdate;
        public String FLEX_Context;
        public String FLEX_Context_DisplayValue;
    }

    public class ReceivablesInvoiceTransactionDFF {
        public String FLEX_Context;
        public String FLEX_Context_DisplayValue;
        public String salesorderNo;
        public String installmentNo;
        public String unitNumber;
        public String projectNumber;
        public String unitType;
        public String unitStatus;
        public String unitName;
        public String phaseName;
        public String totalInstallmentAmount;
        public String totalMaintenanceAmount;
        public String landArea;
        public String builtUpArea;
        public String projectName;
    }

    public class InvoiceRequest {
        public String BusinessUnit;
        public String TransactionNumber;
        public Date TransactionDate;
        public String TransactionType;
        public String TransactionSource;
        public String InvoiceCurrencyCode;
        public String DueDate;
        public Date AccountingDate;
        public Date ConversionDate;
        public Object ConversionRate;
        public String ConversionRateType;
        public String BillToCustomerName;
        public String BillToCustomerNumber;
        public String BillToSite;
        public String Comments;
        public String PaymentTerms;
        public String RemitToAddress;
        public String LegalEntityIdentifier;

        public List<ReceivablesInvoiceLine> receivablesInvoiceLines;
        public List<ReceivablesInvoiceDFF> receivablesInvoiceDFF;
        public List<ReceivablesInvoiceTransactionDFF> receivablesInvoiceTransactionDFF;
    }

    // --------------------- PERSON ACCOUNT WRAPPERS ---------------------
    public class SiteWrapper {
        public String AddressLine1;
        public String Emirate;
        public String Country;
        public String City;
        public String State;
        public String PostalCode;
        public String PassportExpiryDate;
        public String PassportNumber;
        public String NationalityID;
        public String TradeName;
        public String ResidentialStatus;
        public String FirstName;
        public String LastName;
        public String MiddleName;
        public String Contact;
        public String Mail;
        public String PhoneNumber;
        public String TaxRegistrationNumber;
        public String CommercialRegistrationNumber;
        public String TradeLicenseExpiryDate;
        public String AccountAddressSet;
        public Boolean IsPersonAccount;
        public String PersonMailingCity;
        public String PersonMailingCountry;
        public String PersonMailingState;
        public String PersonMailingStreet;
        public String PersonMailingPostalCode;
        public String PersonMobilePhone;
    }

    public class PersonAccountWrapper {
        public String RecordId;
        public String CustomerNumber;
        public String CustomerName;
        public String DateOfEstablishment;
        public List<SiteWrapper> Sites;
    }
    
    public class AccountUpdateWrapper {
        public String CustomerNumber;
        public String AddressLine1;
        public String Emirate;
        public String City;
        public String Country;
        public String State;
        public String PostalCode;
        public String PassportExpiryDate;
        public String PassportNumber;
        public String NationalityID;
        public String TradeName;
        public String ResidentialStatus;
        public String TradeLicenseExpiryDate;
        public String CommercialRegistrationNumber;
        public String FirstName;
        public String LastName;
        public String MiddleName;
        public String Mail;
        public String PhoneNumber;
        public String IsPersonAccount;
        public String PersonMailingCity;
        public String PersonMailingCountry;
        public String PersonMailingState;
        public String PersonMailingStreet;
        public String PersonMailingPostalCode;
        public String PersonMobilePhone;
        public String TaxRegistrationNumber;
    }

    // --------------------- RECEIPT WRAPPERS ---------------------
    public class ReceiptFlexWrapper {
        public String FLEX_Context;
        public String FLEX_Context_DisplayValue;
        public String eoiNumber;
        public String salesOrderNumber;
        public String modeOfPayment;
        public String sfReceiptNo;
        public String unittype;
        public String unitNumber;
        public Decimal appliedAmount;
        public Decimal remainingAmount;
        public String receiptStatus;
        public String customerBankName;
    }

    public class ReceiptWrapper {
        public String ReceiptNumber;
        public Date MaturityDate;
        public String BusinessUnit;
        public String ReceiptMethod;
        public String CurrencyCode;
        public Decimal Amount;
        public Date ReceiptDate;
        public Date AccountingDate;
        public String CustomerName;
        public String CustomerAccountNumber;
        public String RemittanceBankAccountNumber;
        public String ConversionRateType;
        public String ConversionDate;
        public List<ReceiptFlexWrapper> standardReceiptDFF;
    }
    
    public class ResponseWrapper{
        public String CustomerAccountId;
        public String ContactStatus;
    	public String TaxStatus;
        public String CustomerTransactionId; //This represents Oracle Invoice Id
        public String StandardReceiptId;
        public String Message;
        public String StatusCode;
        public String Status;
        public String AccountingDate;
    }
}