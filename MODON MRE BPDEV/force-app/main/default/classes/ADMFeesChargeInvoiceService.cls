/**********************************************************************************************************************
* Name               : ADMFeesChargeInvoiceService                                                        
* Description        : This class is used to automate the Charge Creation for the Sales Order
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version      Author                               Date            Comment                                                                       
* 1.0          Krishna                             11 Nov 2025     Initial Draft
* 2.0          DSelvam                             15 Apr 2026     Added this condition to exclude PostSales charges for new Sales
* 2.1          DSelvam                             15 Apr 2026     Mapping the DARI charges in the SO Level
**********************************************************************************************************************/

public with sharing class ADMFeesChargeInvoiceService {

    public static void processOnUpsert(Map<Id, SalesOrder__c> oldMap, List<SalesOrder__c> newList, Boolean isInsert) {
        Set<Id> salesOrderIds = new Set<Id>();
        Set<Id> phaseIds = new Set<Id>();
        Map<Id, SalesOrder__c> validSalesOrders = new Map<Id, SalesOrder__c>();

        for (SalesOrder__c so : newList) {
            SalesOrder__c oldSo = isInsert ? null : oldMap.get(so.Id);
            Boolean isADMChanged = isInsert || so.ADM_Fees_Dari_charges__c != oldSo.ADM_Fees_Dari_charges__c ||so.ADM_Fees__c != oldSo.ADM_Fees__c ||
                so.Discount_on_ADM_Fees__c != oldSo.Discount_on_ADM_Fees__c;

            if (so.Source_Entity__c != 'Modon - Egypt' && isADMChanged && so.CustomerAccount__c != null && so.Opportunity__c != null &&
                (isInsert == false || (isInsert && so.Resale__c == false))
            ) {
                salesOrderIds.add(so.Id);
            }
        }

        if (salesOrderIds.isEmpty()) return;

        // Query Sales Orders with Unit.Phase
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>(
            [SELECT Id, Name, CustomerAccount__c, Unit__r.Phase__c, TotalAmount__c
             FROM SalesOrder__c
             WHERE Id IN :salesOrderIds]
        );

        for (SalesOrder__c so : soMap.values()) {
            if (so.Unit__r != null && so.Unit__r.Phase__c != null) {
                phaseIds.add(so.Unit__r.Phase__c);
                validSalesOrders.put(so.Id, so);
            }
        }

        if (phaseIds.isEmpty()) return;

        // Get Financial Setup for ADM Fee
        List<Financial_Setup__c> setupList = [
            SELECT Id, Type__c, Value__c, Phase__c, Fee_Type__c, VAT_Percnetage__c, SR_RecordType__c,Default_Amount__c
            FROM Financial_Setup__c
            WHERE Phase__c IN :phaseIds AND Type__c = 'ADM & Dari Fee' AND SR_RecordType__c = null AND Sub_Type__c INCLUDES ('New Sale') /**2.0 Added this condition to exclude PostSales charges for new Sales **/
        ];

        // Build a map: PhaseId + RecordTypeName → Financial_Setup__c
        Map<String, Financial_Setup__c> fsMap = new Map<String, Financial_Setup__c>();
        Set<String> rtNames = new Set<String>();

        for (Financial_Setup__c fs : setupList) {
            if (fs.Phase__c != null) {
                fsMap.put(fs.Phase__c + '-ADM & Dari Fee', fs);
                rtNames.add(fs.Type__c); // 'ADM Fee'
            }
        }

        // Get RecordTypeId for 'Charge__c' using fs.Type__c
        
        List<Charge__c> chargesToInsert = new List<Charge__c>();
        Map<Id, String> soToAccountMap = new Map<Id, String>();
		List<SalesOrder__c> soListUpdate = new List<SalesOrder__c>();
        for (SalesOrder__c so : validSalesOrders.values()) {
            Id phaseId = so.Unit__r.Phase__c;
            String fsKey = phaseId + '-ADM & Dari Fee';
            if (!fsMap.containsKey(fsKey)) continue;

            Financial_Setup__c fs = fsMap.get(fsKey);
            Decimal amount = fs.Fee_Type__c == '% Based Calculation'
                ? (so.TotalAmount__c != null ? ((so.TotalAmount__c * fs.Value__c) / 100)+fs.Default_Amount__c : 0)
                : fs.Value__c;

            if (amount == null || amount <= 0) continue;

            List<Charge__c> existingCharges = [
                SELECT Id FROM Charge__c 
                WHERE Sales_Order__c = :so.Id 
                AND Type__c = 'ADM & Dari Fee' 
                AND PaymentStatus__c = 'Unpaid'
                LIMIT 1
            ];
            if (!existingCharges.isEmpty()) continue;

            Decimal vatAmount = (fs.VAT_Percnetage__c != null && fs.VAT_Percnetage__c > 0)
                ? (amount * fs.VAT_Percnetage__c) / 100
                : 0;
Id recordTypeId = Schema.SObjectType.Charge__c.getRecordTypeInfosByDeveloperName().get('ADM_Fee').getRecordTypeId();

            Charge__c ch = new Charge__c(
                Name = 'ADM & Dari Fee',
                Amount__c = amount,
                VAT_Amount__c = vatAmount,
                Type__c = 'ADM & Dari Fee',
                PaymentStatus__c = 'Not Paid',
                Sales_Order__c = so.Id,
                Account__c = so.CustomerAccount__c,
                RecordTypeId = recordTypeId
            );

            chargesToInsert.add(ch);
            soToAccountMap.put(so.Id, so.CustomerAccount__c);
            
            /** 2.1 - Mapping the DARI charges in the SO Level **/
            SalesOrder__c soUpd = new SalesOrder__c();
            soUpd.Id = so.Id;
            soUpd.Daricharges__c = fs.Default_Amount__c <> null ? fs.Default_Amount__c : 0;
            soListUpdate.add(soUpd);
        }

        if (!chargesToInsert.isEmpty()) {
            insert chargesToInsert;

            List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
            for (Charge__c ch : chargesToInsert) {
                String accId = soToAccountMap.get(ch.Sales_Order__c);
                if (accId != null) {
                    Decimal vat = ch.VAT_Amount__c != null ? ch.VAT_Amount__c : 0;
                    //InvoiceDate__c = System.today().addDays(2), // commented by kumaravel
                    //Ebs_Invoice_Date__c=System.today().addDays(2), // commented by kumaravel
                    invoicesToInsert.add(new Invoice__c(
                        InvoiceAmount__c = ch.Amount__c + vat,
                        InvoiceDate__c = System.today(),
                        Sales_Order__c = ch.Sales_Order__c,
                        Account__c = accId,
                        Charge__c = ch.Id,
                        //Date firstDayOfMonth = System.today().toStartOfMonth();
						//Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month()) - 1);
                        Ebs_Invoice_Date__c=System.today(),
                        Is_ADM_Fees_and_Dari_charges__c = ch.name == 'ADM & Dari Fee' ? true :false
                    ));
                }
            }
            insert invoicesToInsert;
        }
         /** 2.1 - Mapping the DARI charges in the SO Level **/
        if(!soListUpdate.isEmpty()){
            try{
                update soListUpdate;
            }catch(Exception ex){}
        }
    }
}