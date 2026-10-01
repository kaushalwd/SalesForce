/**********************************************************************************************************************
 * Name               : AdjustEoiPaymentController
 * Description        : Apex controller for Adjust EOI Payment LWC component. This controller provides:
 *                      1. Fetching Receipt__c records related to EOIs (ExpressionOfInterest__c) of a Sales Order's Opportunity.
 *                      2. Applying selected receipts by linking them to Milestone 1 SalesOrderInstallment__c
 *                         and creating Allocation__c records with Invoice__c, Receipt__c, and amount details.
 * Usage              : Used by Lightning Web Component (AdjustEoiPaymentLwc)
 * Created By         : Harshit
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Harshit                             16-06-2025      Initial Draft
 * 2.0           Shahil Sinha (Horizontal)           14-11-2025      Added logic to adjust EOI against multiple installments with currency conversion
 * 2.1           Shahil Sinha (Horizontal)           02-01-2026      Updated to use Installment_Balance__c for EOI receipts allocation
 * 2.2           Shahil Sinha (Horizontal)           06-01-2026      Updated to use ConversionRateWrapper for currency conversion
 * 2.3           Shahil Sinha (Horizontal)           07-01-2026      Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
 * 2.4           Narendra Agrawal (Horizontal)       30-04-2026      Updating Unit and Salesforce when Sales order blocking feed pending and adjusted through EOI receipt. 
 **********************************************************************************************************************/

public with sharing class AdjustEoiPaymentLwcController {

    /**
     * @description
     *    Retrieves all Receipt__c records linked to the EOIs associated with the Sales Order’s Opportunity.
     *
     * @param salesOrderId - The Id of the SalesOrder__c record
     * @return List of Receipt__c records
     */
    @AuraEnabled
    public static List<ReceiptWrapper> getReceipts(Id salesOrderId) {
        // Step 1: Get the Opportunity Id from the Sales Order
        SalesOrder__c so = [
            SELECT Opportunity__c , CurrencyIsoCode 
            FROM SalesOrder__c 
            WHERE Id = :salesOrderId 
            LIMIT 1
        ];
        
        if (so.Opportunity__c == null) {
            return new List<ReceiptWrapper>();
        }

        // Step 2: Get EOIs related to the Opportunity
        List<ExpressionOfInterest__c> eois = [
            SELECT Id 
            FROM ExpressionOfInterest__c 
            WHERE Opportunity__c = :so.Opportunity__c
        ];

        if (eois.isEmpty()) {
            return new List<ReceiptWrapper>();
        }

        // Step 3: Get Receipt__c records related to these EOIs

        List<Id> eoiIds = new List<Id>();
        for (ExpressionOfInterest__c eoi : eois) {
            eoiIds.add(eoi.Id);
        }

        String targetCurrency = so.CurrencyIsoCode;
        List<Receipt__c> receipts = [
            SELECT Id, Name, TotalAmount__c, RemainingAmount__c, Conversion_Rate__c, AppliedAmount__c, Status__c, ExpressionOfInterest__r.Name, CurrencyIsoCode, ExpressionOfInterest__c
            FROM Receipt__c
            WHERE ExpressionOfInterest__c IN :eoiIds And RemainingAmount__c > 0 And Status__c = 'Cleared' AND Receipt_Type__c = 'EOI Receipt'
        ];

        List<ReceiptWrapper> receiptWrappers = new List<ReceiptWrapper>();

        for(Receipt__c rec: receipts){
            ReceiptWrapper rw = new ReceiptWrapper();
            rw.receipt = rec;
            rw.sourceCurrencyIsoCode = rec.CurrencyIsoCode;
            receiptWrappers.add(rw);
        }
        return receiptWrappers;
    }

    /**
     * @description
     *    Links selected receipts to Milestone 1 SalesOrderInstallment__c and
     *    creates Allocation__c records with invoice, allocation amount and date.
     *
     * @param receiptIds   - List of selected Receipt__c record Ids
     * @param salesOrderId - Id of the current SalesOrder__c record
     */
    @AuraEnabled
    public static void applyReceipts(List<AmountByReceipt> amountList, Id salesOrderId, Boolean isMultiInstallment) {
        
        // Step 0: Input validations
        if (amountList == null || amountList.isEmpty()) {
            throw new AuraHandledException('No receipts selected.');
        }

        if (salesOrderId == null) {
            throw new AuraHandledException('Sales Order ID is required.');
        }

        // Step 1: Collect All receipt Ids
        Set<Id> receiptIds = new Set<Id>();
        Decimal totalAmountToApply = 0;
        for (AmountByReceipt amountByReceipt : amountList) {
            receiptIds.add(amountByReceipt.receiptId);
            totalAmountToApply += amountByReceipt.amount;
        }

        // Step 2: Fetch Receipt Records
        Map<Id, Receipt__c> receiptsMap = new Map<Id, Receipt__c>([
            SELECT Id, Name, TotalAmount__c, RemainingAmount__c, Conversion_Rate__c, CurrencyIsoCode
            FROM Receipt__c
            WHERE Id IN :receiptIds
        ]);

        if (receiptsMap.isEmpty()) {
            throw new AuraHandledException('No valid receipts found.');
        }

        List<Allocation__c> allocationsToInsert = new List<Allocation__c>();

        //Step 3: Check for installment logic
        // ============= SINGLE INSTALLMENT LOGIC =============
        if (isMultiInstallment == false) {
            // Step 3.1: Fetch SalesOrderInstallment with MilestoneNumber__c == 1
            
            SalesOrderInstallments__c soi = [
                SELECT Id, InstallmentAmount__c, PaymentStatus__c, SalesOrder__r.CurrencyIsoCode, SalesOrder__r.Status__c,
                 (SELECT Id, CurrencyIsoCode, InvoiceBalance__c, Installment_Amount__c, Applied_InstallmentAmount__c FROM Invoices__r Where isCancelled__c = false LIMIT 1)
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c = :salesOrderId
                AND MilestoneNumber__c = 1
                LIMIT 1
            ];

            if (soi == null) {
                throw new AuraHandledException('Milestone 1 installment not found for this Sales Order.');
            }

            if (soi.PaymentStatus__c == 'Paid') {
                throw new AuraHandledException('Milestone 1 installment is already cleared.');
            }

            if (soi.Invoices__r.isEmpty()) {
                throw new AuraHandledException('No Invoice found for Milestone 1 installment.');
            }

            Id invoiceId = soi.Invoices__r[0].Id;
            String invoiceCurrency = soi.Invoices__r[0].CurrencyISOCode;

            //v2.1 (line 150 - 152) use installment balance for EOI receipts (Installment Receipt Type)
            // Subtract already applied amount to get effective available balance
            Decimal installmentBalance = soi.Invoices__r[0].Installment_Amount__c;
            Decimal appliedAmount = soi.Invoices__r[0].Applied_InstallmentAmount__c;
            Decimal invoiceBalanceInInvoiceCurrency = installmentBalance - appliedAmount;

            // Check if there's any balance available
            if (invoiceBalanceInInvoiceCurrency <= 0) {
                throw new AuraHandledException('No outstanding installment balance available. The balance may already be allocated to pending receipts.');
            }
            
            Decimal totalAppliedAmountinInvoiceCurrency = 0;
            
            for(AmountByReceipt abr : amountList){
                Receipt__c receipt = receiptsMap.get(abr.receiptId);
                String receiptCurrency = receipt.currencyIsoCode;
                Decimal receiptAmount = abr.amount;

                //v2.2 (line 167) Updated to use ConversionRateWrapper for currency conversion
                ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(receiptCurrency, invoiceCurrency);
                if(rateWrapper == null) { 
                    throw new AuraHandledException('Currency conversion rate not found for ' + receiptCurrency + 
                                                ' to ' + invoiceCurrency + ' for today. Please contact system administrator.');
                }
                Decimal conversionRate = rateWrapper.conversionRate;

                Decimal receiptAmountInInvoiceCurrency = receiptAmount * conversionRate;

                totalAppliedAmountinInvoiceCurrency += receiptAmountInInvoiceCurrency;
                
            }

            if(totalAppliedAmountinInvoiceCurrency > invoiceBalanceInInvoiceCurrency){
                throw new AuraHandledException('The total applied amount of '+ invoiceCurrency +' '+totalAppliedAmountinInvoiceCurrency.setScale(2).format() + ' exceeds Milestone 1 invoice balance of ' + invoiceCurrency + ' ' + invoiceBalanceInInvoiceCurrency.setScale(2).format() + '. Please adjust the amounts.');
            }

            Decimal remainingInvoiceBalance = invoiceBalanceInInvoiceCurrency;

            
            for (AmountByReceipt amountByReceipt : amountList) {

                if (remainingInvoiceBalance <= 0) break;

                //get receipt details from receiptsMap
                Receipt__c receipt = receiptsMap.get(amountByReceipt.receiptId);
                String receiptCurrency = receipt.CurrencyISOCode;
                Decimal receiptAmountInReceiptCurrency = amountByReceipt.amount;

                //v2.2 (line 197) Updated to use ConversionRateWrapper for currency conversion
                ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(invoiceCurrency, receiptCurrency);
                if(rateWrapper == null) { 
                    throw new AuraHandledException('Currency conversion rate not found for ' + invoiceCurrency + 
                                                ' to ' + receiptCurrency + ' for today. Please contact system administrator.');
                }
                
                Decimal conversionRate = rateWrapper.conversionRate;

                Decimal invoiceBalanceInReceiptCurrency = (remainingInvoiceBalance * conversionRate);

                Decimal finalAmountToApplyInReceiptCurrency = Math.min(receiptAmountInReceiptCurrency, invoiceBalanceInReceiptCurrency);

                allocationsToInsert.add(new Allocation__c(
                    AllocationDate__c    = System.today(),
                    Invoice__c           = invoiceId,
                    Receipt__c           = amountByReceipt.receiptId,
                    AllocationAmount__c  = finalAmountToApplyInReceiptCurrency,  //Setting amount in receipt currency, conversion in invoice currency will be done in allocation trigger
                    CurrencyIsoCode      = invoiceCurrency,
                    isMaintenance__c     = false  // EOI receipts are Installment Receipts
                ));
                //update remaining invoce balance
                remainingInvoiceBalance -= (finalAmountToApplyInReceiptCurrency / conversionRate);
            }
        } 
        // ============= MULTIPLE INSTALLMENT LOGIC =============
        else {
            // Fetch all installments for this Sales Order
            List<SalesOrderInstallments__c> allInstallments = [
                SELECT Id, MilestoneNumber__c, InstallmentAmount__c, SalesOrder__r.CurrencyIsoCode,SalesOrder__r.Status__c,
                    (SELECT Id, InvoiceBalance__c, CurrencyIsoCode, Installment_Amount__c, Applied_InstallmentAmount__c
                        FROM Invoices__r Where isCancelled__c = false limit 1)
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c = :salesOrderId
                ORDER BY MilestoneNumber__c ASC
            ];

            if(!allInstallments.isEmpty()) {
                String currencyIsoCode = allInstallments[0].SalesOrder__r.CurrencyIsoCode;
                
                // Build a map of invoice ID to balance and maintain order
                Map<Id, Decimal> invoiceBalanceMap = new Map<Id, Decimal>();
                Map<Id, String> invoiceCurrencyMap = new Map<Id, String>();
                for (SalesOrderInstallments__c inst : allInstallments) {
                    if (inst.Invoices__r != null && !inst.Invoices__r.isEmpty()) {
                        for (Invoice__c inv : inst.Invoices__r) {
                            // Subtract already applied amount to get effective available balance
                            Decimal installmentBalance = inv.Installment_Amount__c;
                            Decimal appliedAmount = inv.Applied_InstallmentAmount__c;
                            Decimal effectiveBalance = installmentBalance - appliedAmount;
                            invoiceBalanceMap.put(inv.Id, effectiveBalance);
                            invoiceCurrencyMap.put(inv.Id, inv.CurrencyIsoCode);
                        }
                    }
                }

                // Check if ALL balances are zero or less (nothing to pay)
                Boolean allCleared = true;
                for (Decimal balance : invoiceBalanceMap.values()) {
                    if (balance > 0) {
                        allCleared = false;
                        break;
                    }
                }
                if (allCleared) {
                    throw new AuraHandledException('All installments are already cleared or allocated to pending receipts. No outstanding installment balance to apply payments.');
                }
                
                // Process each receipt
                for (AmountByReceipt amountByReceipt : amountList) {
                    if (totalAmountToApply <= 0) break;
                    
                    Receipt__c receipt = receiptsMap.get(amountByReceipt.receiptId);
                    Decimal receiptAmountInReceiptCurrency = amountByReceipt.amount;

                    // Iterate through invoices in order
                    for (Id invoiceId : invoiceBalanceMap.keySet()) {
                        if (receiptAmountInReceiptCurrency <= 0 || totalAmountToApply <= 0) break;
                        
                        String invoiceCurrency = invoiceCurrencyMap.get(invoiceId);
                        String receiptCurrency = receipt.CurrencyISOCode;

                        Decimal invoiceBalanceInInvoiceCurrency = invoiceBalanceMap.get(invoiceId);

                        if (invoiceBalanceInInvoiceCurrency <= 0) continue;

                        //v2.2 (line 282) Updated to use ConversionRateWrapper for currency conversion
                        ModonEgypt_CurrencyConversion.ConversionRateWrapper rateWrapper = ModonEgypt_CurrencyConversion.getConversionRate(invoiceCurrency, receiptCurrency);
                        if(rateWrapper == null) { 
                            throw new AuraHandledException('Currency conversion rate not found for ' + invoiceCurrency + 
                                                    ' to ' + receiptCurrency + ' for today. Please contact system administrator.');
                        }
                        Decimal conversionRate = rateWrapper.conversionRate;

                        Decimal invoiceBalanceInReceiptCurrency = (invoiceBalanceInInvoiceCurrency * conversionRate);
                        
                        //Find min amount and apply that on allocation.
                        Decimal finalAmountToApplyInReceiptCurrency;
                        //v2.3 (line 294) Updated to use CONVERSION_THRESHOLD from ModonEgypt_CurrencyConversion
                        if (Math.abs(receiptAmountInReceiptCurrency - invoiceBalanceInReceiptCurrency) <= ModonEgypt_CurrencyConversion.CONVERSION_THRESHOLD) {
                            finalAmountToApplyInReceiptCurrency = invoiceBalanceInReceiptCurrency;
                        } else {
                            finalAmountToApplyInReceiptCurrency = Math.min(receiptAmountInReceiptCurrency, invoiceBalanceInReceiptCurrency);
                        }
                        
                        Allocation__c allocation = new Allocation__c(
                            AllocationDate__c    = System.today(),
                            Receipt__c = receipt.Id,
                            Invoice__c = invoiceId,
                            AllocationAmount__c = finalAmountToApplyInReceiptCurrency,   //Setting amount in receipt currency, conversion in invoice currency will be done in allocation trigger
                            CurrencyIsoCode = invoiceCurrency,
                            isMaintenance__c = false  // EOI receipts are Installment Receipts
                        );
                        allocationsToInsert.add(allocation);
                        
                        totalAmountToApply -= finalAmountToApplyInReceiptCurrency;
                        receiptAmountInReceiptCurrency -= finalAmountToApplyInReceiptCurrency;
                        invoiceBalanceMap.put(invoiceId, invoiceBalanceInInvoiceCurrency - (finalAmountToApplyInReceiptCurrency * 1/conversionRate));
                    }
                }
            } else {
                throw new AuraHandledException('No Sales order installment found on this sales order.');
            }
        }

        try {
            // Step 4: DML Operations
            if (!allocationsToInsert.isEmpty()) {
                insert allocationsToInsert;
            }
            
            updateSalesOrderAndUnit(salesOrderId);
        } catch (Exception err) {
            throw new AuraHandledException('Error: ' + err.getMessage());
        }
    }

    private static void updateSalesOrderAndUnit(Id salesOrderId) {
    
        // Query Sales Order
        SalesOrder__c soObj = [
            SELECT Id, Opportunity__c, Status__c, Unit__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
        
        // Proceed only if status is Pending Blocking Fees
        if (soObj.Status__c == ModonEgyptConstants.SALES_ORDER_STATUS_PENDING_BLOCKING_FEES) {
            
            // Query Approved Block Request
            Block_Request__c blockRequestObj = [
                SELECT Id,
                    Hourstoblock__c,
                    Unit__c,
                    Unit__r.BlockedFor__c,
                    Unit__r.BlockedBy__c,
                    Unit__r.Status__c,
                    Unit__r.Sub_Status__c,
                    CreatedById,
                    Opportunity__c
                FROM Block_Request__c
                WHERE Opportunity__c = :soObj.Opportunity__c
                AND Status__c = 'Approved'
                AND Unit__c = :soObj.Unit__c
                LIMIT 1
            ];
            
            // Calculate block until datetime (NOW + hoursToBlock / 24)
            Datetime blockUntil = System.now().addHours((
                Integer.valueOf(String.valueOf(blockRequestObj.Hourstoblock__c)))
            );

            List<Unit__c> unitsToUpdate = [
                SELECT Id, Status__c, Sub_Status__c, BlockUntil__c
                FROM Unit__c
                WHERE Id = :soObj.Unit__c
                LIMIT 1
            ];

            if (!unitsToUpdate.isEmpty()) {
                Unit__c unit = unitsToUpdate[0];
                unit.Status__c = ModonEgyptConstants.STATUS_RESERVED;
                unit.Sub_Status__c = '';
                unit.BlockUntil__c = blockUntil;

                update unit;
            }
            
            // Update Sales Order
            SalesOrder__c soToUpdate = new SalesOrder__c(
                Id = soObj.Id,
                Status__c = ModonEgyptConstants.SALES_ORDER_STATUS_BLOCKING_FEES_COLLECTED,
                AutoEndDate__c = blockUntil
            );
            
            update soToUpdate;
        }
    }

    public class AmountByReceipt {
        @AuraEnabled
        public String receiptId { get; set; }
        @AuraEnabled
        public Decimal amount { get; set; }
        @AuraEnabled
        public Decimal conversionRate { get; set; }
    }

    public class ReceiptWrapper {
        @AuraEnabled
        public Receipt__c receipt { get; set; }
        @AuraEnabled
        public Decimal conversionRate { get; set; }
        @AuraEnabled
        public String sourceCurrencyIsoCode {get; set;}
        @AuraEnabled
        public String targetCurrencyIsoCode  {get; set;}
    }
}