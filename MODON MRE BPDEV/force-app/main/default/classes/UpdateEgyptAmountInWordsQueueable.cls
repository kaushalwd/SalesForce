/**********************************************************************************************************************
* Name               : UpdateEgyptAmountInWordsQueueable                                                        
* Description        : Queueable class to update Sales Order Egypt amount in words fields (English & Arabic) 
*                      after roll-up summaries are calculated
* Usage              : Called from SalesOrderInstallmentTriggerHelper.updateEgyptAmountInWords
* Created By         : Shahil Sinha (Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha (Horizontal)        03 Feb 2026     Initial Draft
* 1.1           Shahil Sinha (Horizontal)        03 Feb 2026     Added Arabic amount in words using ArabicTranslaitonUtils
* 2.0           Milin Kapatel (Horizontal)       05 Mar 2026     Refactored to use ModonEgyptUtilities for amount in words conversion
* 3.0           Milin Kapatel (Horizontal)       22 Apr 2026     Queueable batching to avoid governor limit error + updated methods to use convertAmountInWordsTextEnglish, convertAmountInWordsTextArabic instead of amountInWords, Amount_in_ArabicWords
* 3.1           Milin Kapatel (Horizontal)       05 May 2026     Updated methods to pass Decimal values instead of String values
* 3.2           Milin Kapatel (Horizontal)       05 June 2026    Added unit selling price amount in words for English and Arabic translation logic
**********************************************************************************************************************/
public class UpdateEgyptAmountInWordsQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<Id> salesOrderIds;
    private static final Integer BATCH_SIZE = 25;
    
    public UpdateEgyptAmountInWordsQueueable(Set<Id> salesOrderIds) {
        this.salesOrderIds = new List<Id>(salesOrderIds);
    }
    
    public UpdateEgyptAmountInWordsQueueable(List<Id> salesOrderIds) {
        this.salesOrderIds = salesOrderIds;
    }
    
    public void execute(QueueableContext context) {
        try {
            if (salesOrderIds == null || salesOrderIds.isEmpty()) {
                return;
            }
            
            /************************************************************************************************************
             * Why batching of 50 records?
             * ----------------------------------------------------------------------------------------------------------
             * This Queueable performs API callouts via ModonEgyptUtilities methods.
             * 
             * Salesforce Governor Limit:
             * - Maximum 100 callouts allowed per Apex transaction.
             * 
             * In our logic:
             * - Each SalesOrder can trigger up to 2 callouts (English + Arabic conversion).
             * 
             * So:
             * - 50 records × 2 callouts = 100 callouts (safe limit)
             * 
             * To avoid hitting "Too many callouts: 101" error:
             * - We process only 50 records per execution
             * - Remaining records are chained into another Queueable job
             ************************************************************************************************************/

            // Split current batch (50) and remaining
            //v3.0
            List<Id> currentBatch = new List<Id>();
            List<Id> remainingIds = new List<Id>();

            for (Integer i = 0; i < salesOrderIds.size(); i++) {
                if (i < BATCH_SIZE) {
                    currentBatch.add(salesOrderIds[i]);
                } else {
                    remainingIds.add(salesOrderIds[i]);
                }
            }

            // Query only current batch
            List<SalesOrder__c> salesOrders = [
                SELECT Id, CurrencyIsoCode,
                    EgyptTotalAmount__c, 
                    EgyptTotalInstallmentAmount__c, 
                    EgyptTotalMaintenanceAmount__c,
                    Unit_Selling_Price__c
                FROM SalesOrder__c 
                WHERE Id IN :currentBatch
            ];
            
            // Process records
            for (SalesOrder__c so : salesOrders) {
                
                if (so.EgyptTotalAmount__c != null && so.EgyptTotalAmount__c != 0) { 
                    //v2.0 - refactored to use ModonEgyptUtilities for amount in words conversion
                    //v3.0
                    so.EgyptTotalAmountInWords__c = ModonEgyptUtilities.convertAmountInWordsTextEnglish(so.EgyptTotalAmount__c, so.CurrencyIsoCode); 
                    so.TotalamountinwordsArabic__c = ModonEgyptUtilities.convertAmountInWordsTextArabic(so.EgyptTotalAmount__c, so.CurrencyIsoCode);
                }
                
                // Installment Amount - English & Arabic
                if (so.EgyptTotalInstallmentAmount__c != null && so.EgyptTotalInstallmentAmount__c != 0) { 
                    //v2.0 - refactored to use ModonEgyptUtilities for amount in words conversion
                    //v3.0
                    so.EgyptTotalInstallmentAmountInWords__c = ModonEgyptUtilities.convertAmountInWordsTextEnglish(so.EgyptTotalInstallmentAmount__c, so.CurrencyIsoCode);
                    //v3.0
                    so.EgyptTotalInstallmentAmountInWordsArabic__c = ModonEgyptUtilities.convertAmountInWordsTextArabic(so.EgyptTotalInstallmentAmount__c, so.CurrencyIsoCode);
                }
                
                // Maintenance Amount - English & Arabic
                if (so.EgyptTotalMaintenanceAmount__c != null && so.EgyptTotalMaintenanceAmount__c != 0) { 
                    //v2.0 - refactored to use ModonEgyptUtilities for amount in words conversion
                    //v3.0
                    so.EgyptTotalMaintenanceAmountInWords__c = ModonEgyptUtilities.convertAmountInWordsTextEnglish(so.EgyptTotalMaintenanceAmount__c, so.CurrencyIsoCode);
                    //v3.0
                    so.EgyptTotalMaintenanceAmountInWordsArabic__c = ModonEgyptUtilities.convertAmountInWordsTextArabic(so.EgyptTotalMaintenanceAmount__c, so.CurrencyIsoCode);
                }

                // Unit Selling Price - English & Arabic
                if (so.Unit_Selling_Price__c != null && so.Unit_Selling_Price__c != 0) { 
                    so.EgyptUnitSellingPriceInWords__c = ModonEgyptUtilities.convertAmountInWordsTextEnglish(so.Unit_Selling_Price__c, so.CurrencyIsoCode);
                    so.EgyptUnitSellingPriceInWordsArabic__c = ModonEgyptUtilities.convertAmountInWordsTextArabic(so.Unit_Selling_Price__c, so.CurrencyIsoCode);
                }
            }
            
            // Update Sales Orders
            if (!salesOrders.isEmpty()) {
                update salesOrders;
            }

            //v3.0 Chain next job if remaining IDs exist
            if (!remainingIds.isEmpty()) {
                System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(remainingIds));
            }

        } catch (Exception ex) {
            System.debug('UpdateEgyptAmountInWordsQueueable Error - ' + ex.getMessage());
        }
    }
    
    //v2.0 - removed local getCurrencyUnits method and replaced with call to ModonEgyptUtilities.amountInWords
    //removed local getCurrencyUnits method
}