/**********************************************************************************************************************
* Name               : EOITriggerHelper                                                        
* Description        : This class is helper for EOI trigger
* Usage              : Called from EOITriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
* 2.0           Gautam Sah(Horizontal)           31 Mar 2025     Modon Egypt Built      
* 2.1           Prateek Bansal                    08 May 2026     Clone EOI document templates per EOI to prevent duplicate sObject instances during bulk insert
* 2.2           Arvind                            13 May 2026     SLA Start Time logic — sets SLA_Start_Time__c on EOI after insert based on Opportunity Lead Source
* 2.3           Prateek Bansal                    13 Sep 2026     Carry the UAT Egypt sync here, commented, so one copy fits every org.

******************************************************************************************************************/
public without sharing class EOITriggerHelper {
    public static void updateEOIStatus(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        for(String key : newMap.keySet()){
            Expressionofinterest__c eoiObjNew = (Expressionofinterest__c)newMap.get(key);
            Expressionofinterest__c eoiObjOld = (Expressionofinterest__c)oldMap.get(key);

            if( (eoiObjNew.PaymentStatus__c != eoiObjOld.PaymentStatus__c || eoiObjNew.SecurityCheckCompleted__c != eoiObjOld.SecurityCheckCompleted__c) && eoiObjNew.PaymentStatus__c =='Paid' && eoiObjNew.SecurityCheckCompleted__c ){
                eoiObjNew.Status__c = 'Completed';
            }
            // --- START NEW VALIDATION LOGIC ---
        // If status is being set to Approved, check the payment status
        if (eoiObjNew.Status__c == 'Approved' || eoiObjNew.Status__c == 'Completed' && eoiObjOld.Status__c == 'Pending With Finance') {
            if (eoiObjNew.PaymentStatus__c != 'Paid' && eoiObjNew.EOI_Amount_AED__c > 0) {
                eoiObjNew.addError('CRITICAL ERROR: This EOI cannot be approved because the Payment Status is "Not Paid".');
                continue; // Skip further logic for this record if validation fails
            }
        }
        // --- END NEW VALIDATION LOGIC ---
        }
        
    }    

    public static void updateEOIId(List<SObject> newList){
        set<String> existingEOIIds = new set<String>();
        for(Expressionofinterest__c eoiObj : [SELECT Id, EOIId__c FROM Expressionofinterest__c]){
            existingEOIIds.add(eoiObj.EOIId__c);
        }

        for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
            String token = 'EOI-' + EOITriggerHelper.generateToken();
            if(!existingEOIIds.contains(token)){
                eoiObj.EOIId__c = token;
                existingEOIIds.add(token);
            }
        }
    }

   /* public static void createInvoice(List<sObject> newList){
        List<Invoice__c> invLst = new List<Invoice__c>();
        set<String> oppIds = new set<String>(); 
        for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
            oppIds.add(eoiObj.Opportunity__c);
        }

        Map<String, String> oppAccountMap = new Map<String, String>();
        for(Opportunity oppObj : [SELECT Id, AccountId FROM Opportunity WHERE Id IN : oppIds]){
            oppAccountMap.put(oppObj.Id, oppObj.AccountId);
        }

        for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
            if(eoiObj.Amount__c != '0'){
                Invoice__c invObj = new Invoice__c();
                invObj.Expressionofinterest__c = eoiObj.Id;
                
                if(eoiObj.Amount__c <> null) // Anil: Added null check.
                invObj.InvoiceAmount__c = Integer.valueOf(eoiObj.Amount__c);
            
                invObj.InvoiceDate__c = system.today();
                //invObj.Status__c = 'Generated';
                invObj.Account__c = oppAccountMap.get(eoiObj.Opportunity__c);
                invLst.add(invObj);
            }
        }
        try{
            INSERT invLst;
        }catch(Exception ex){
            system.debug('EOITriggerHelper.createInvoice==>' + ex.getMessage());
        }       
        
    }*/

    public static void manageInvoiceAmount(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        Map<Id, Expressionofinterest__c> updatedAmountMap = new Map<Id, Expressionofinterest__c>();
        for(String key : newMap.keySet()){
            Expressionofinterest__c eoiObjNew = (Expressionofinterest__c) newMap.get(key);
            Expressionofinterest__c eoiObjOld = (Expressionofinterest__c) oldMap.get(key);
            if(eoiObjNew.Amount__c != eoiObjOld.Amount__c){
                updatedAmountMap.put(eoiObjNew.Id, eoiObjNew);
            }
        }

        if(updatedAmountMap != null && updatedAmountMap.size() > 0){
            Map<String, Invoice__c> eoiInvoiceMap = new Map<String, Invoice__c>();
            for(Invoice__c invObj : [SELECT Id, Expressionofinterest__c, InvoiceStatus__c, Account__c FROM Invoice__c WHERE Expressionofinterest__c = :updatedAmountMap.keySet()]){
                eoiInvoiceMap.put(invObj.Expressionofinterest__c, invObj);
            }

            if(eoiInvoiceMap != null && eoiInvoiceMap.size() > 0){
                List<Invoice__c> invToUpdate = new List<Invoice__c>();
                List<Invoice__c> invToCreate = new List<Invoice__c>();
                for(String eoiId : eoiInvoiceMap.keySet()){
                    if(eoiInvoiceMap.get(eoiId).InvoiceStatus__c != 'Generated'){
                        newMap.get(eoiId).addError('You cannot change the amount, related invoice is already in process');
                        // Invoice__c invObj = eoiInvoiceMap.get(eoiId);
                        // invObj.Status__c = 'Cancelled';
                        // invToUpdate.add(invObj);

                        // Invoice__c newInvObj = new Invoice__c();
                        // newInvObj.Expressionofinterest__c = eoiId;
                        // newInvObj.InvoiceAmount__c = Integer.valueOf((updatedAmountMap.get(eoiId)).Amount__c);
                        // newInvObj.InvoiceDate__c = system.today();
                        // newInvObj.Status__c = 'Generated';
                        // newInvObj.Account__c = (eoiInvoiceMap.get(eoiId)).Account__c;
                        // invToCreate.add(newInvObj);
                    }else if(eoiInvoiceMap.get(eoiId).InvoiceStatus__c == 'Generated'){
                        Invoice__c invObj = eoiInvoiceMap.get(eoiId);
                        invObj.InvoiceAmount__c = Integer.valueOf(updatedAmountMap.get(eoiId).Amount__c);
                        invToUpdate.add(invObj);
                    }
                }
                if(!invToCreate.isEmpty() && invToCreate.size() > 0){
                    INSERT invToCreate;
                }
                if(!invToUpdate.isEmpty() && invToUpdate.size() > 0){
                    UPDATE invToUpdate;
                }
            }
        }
    }
    
    /*
    public static void updateAvailableEscrowAccount(List<SObject> newList){
        List<EscrowAccount__c> eaLst = [SELECT Id FROM EscrowAccount__c WHERE Status__c = 'Unassigned' LIMIT :newList.size()];
        
        if(!eaLst.isEmpty()){
            Integer availableEscrowAccount = eaLst.size();
            for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
                if(availableEscrowAccount > 0){
                    eoiObj.AssignedEscrowAccount__c = eaLst[availableEscrowAccount-1].Id;
                    eaLst[availableEscrowAccount-1].Status__c = 'Assigned';
                    availableEscrowAccount--;
                    continue;
                }
                eoiObj.addError('No escrow account is available for assignment');
            }  
            UPDATE eaLst;
        }else{
            for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
                eoiObj.addError('No escrow account is available for assignment');
            }  
        }
    }*/

    public static String generateToken(){
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        String a = '';
        while (a.length() < 6) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            a += chars.substring(idx, idx+1);
        }
        return a;
    }

   public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Expressionofinterest__c');
        
        if(!lstDocumentsCurrent.isEmpty()){
            
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            
            for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
                for(Documents__c templateDoc: lstDocumentsCurrent){
                    // v2.1: Clone the template for each EOI; reusing the same instance breaks bulk inserts.
                    Documents__c doc = templateDoc.clone(false, true, false, false);
                    doc.Expressionofinterest__c = eoiObj.Id;
                    doc.Opportunity__c = eoiObj.Opportunity__c;                    
                    lstDocumentsToInsert.add(doc);
                }
            }
            
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }


    public static void createModonEgyptDocumentRecords(List<SObject> newList){ // call this After Insert.
    
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getEgyptDocumentsForSObject('Expressionofinterest__c', 'Modon - Egypt');
        Documents__c doc;
        
        if(!lstDocumentsCurrent.isEmpty()){
            
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            
            for(Expressionofinterest__c eoiObj : (List<Expressionofinterest__c>)newList){
                for(Documents__c templateDoc: lstDocumentsCurrent){
                    doc = new Documents__c();
                    doc.Name = templateDoc.Name;
                    doc.Status__c = templateDoc.Status__c;
                    doc.GenerateDocument__c = templateDoc.GenerateDocument__c;
                    doc.SendForESignature__c = templateDoc.SendForESignature__c;
                    doc.Expressionofinterest__c = eoiObj.Id;
                    doc.Opportunity__c = eoiObj.Opportunity__c;
                    lstDocumentsToInsert.add(doc);
                }
            }
            
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    /*public static void sendEmailtoCustomers(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){
        Map<Id, Expressionofinterest__c> updatedExpressionofinteresMap = new Map<Id, Expressionofinterest__c>();
        
        for(String key : newMap.keySet()){
            Expressionofinterest__c eoiObjNew = (Expressionofinterest__c) newMap.get(key);
            Expressionofinterest__c eoiObjOld = (Expressionofinterest__c) oldMap.get(key);
            if(eoiObjNew.Status__c != eoiObjOld.Status__c && eoiObjNew.Status__c == 'In Progress' && eoiObjNew.BrokerAgency__c != null){
                updatedExpressionofinteresMap.put(eoiObjNew.Id, eoiObjNew);
            }
        }
        List<Id> allEOIValues = new List<Id>();
        List<Id> allCompletedEOIValues = new List<Id>();
        
        if(updatedExpressionofinteresMap.keySet().size()>0){
            allEOIValues.addAll(updatedExpressionofinteresMap.keySet());
            MBP_ExpressionOfInterestsController.sendEOISuccessEmail(allEOIValues);
        }
    }*/

    // ============================================================
    // v2.2 — Arvind — 13 May 2026
    // ============================================================
    public static void setSLAStartTime(List<SObject> newList) {

        if (System.Label.EOI_SLA_Enabled != 'true') return;
        
        Set<Id> oppIds = new Set<Id>();
        for (Expressionofinterest__c eoi : (List<Expressionofinterest__c>) newList) {
            if (!eoi.Skip_SLA__c && eoi.Opportunity__c != null) {
                oppIds.add(eoi.Opportunity__c);
            }
        }
        if (oppIds.isEmpty()) return;
        
        Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>();
        for (Opportunity opp : [SELECT Id, LeadSource, UAE_Resident_Status__c FROM Opportunity WHERE Id IN :oppIds]) {
            opportunityById.put(opp.Id, opp);
        }
        
        List<Expressionofinterest__c> toUpdate = new List<Expressionofinterest__c>();
        
        for (Expressionofinterest__c eoi : (List<Expressionofinterest__c>) newList) {
            if (eoi.Skip_SLA__c || eoi.Opportunity__c == null) continue;
            Opportunity opportunityRecord = opportunityById.get(eoi.Opportunity__c);
            toUpdate.add(new Expressionofinterest__c(
                Id                = eoi.Id,
                SLA_Start_Time__c = eoi.CreatedDate,
                SLA_Expiry_Time__c = EoiSlaService.calculateExpiry(
                    eoi.CreatedDate,
                    opportunityRecord == null ? null : opportunityRecord.UAE_Resident_Status__c
                )
            ));
        }
        
        if (!toUpdate.isEmpty()) update toUpdate;
    }
    // ============================================================
    // End v2.2 — Arvind
    // ============================================================


    // 2.3 The Modon Egypt Oracle receipt sync, as it stands in UAT and PreProd. Held commented so one
    // copy of this class deploys everywhere: it calls ModonEgyptConstants and is driven by
    // ModonEgypt_OracleIntegrationControlUtil, neither of which exists in MREQA or Production.
    // public static void modonEgyptSyncReceiptToOracle (Map<Id, SObject> ModonEgyptNewMap, Map<Id, SObject> ModonEgyptOldMap) {
    //
    //         // Filtering only Modon - Egypt EOI receipts to get it synced to Oracle whose status is EOI Confirmed
    //         Set<Id> eoiIds = new Set<Id>();
    //         for (Id eoiId : ModonEgyptNewMap.keySet()) {
    //             ExpressionOfInterest__c newEoi = (ExpressionOfInterest__c) ModonEgyptNewMap.get(eoiId);
    //             ExpressionOfInterest__c oldEoi = (ExpressionOfInterest__c) ModonEgyptOldMap.get(eoiId);
    //             if (oldEoi.Status__c != newEoi.Status__c && newEoi.Status__c == ModonEgyptConstants.EOI_STATUS_CONFIRMED) {	//v4.0
    //                 eoiIds.add(newEoi.Id);
    //             }
    //         }
    //
    //         if (!eoiIds.isEmpty()) {
    //             //v3.1 (line 28)
    //             List<Receipt__c> eoiReceiptsToSync = [SELECT Id, Oracle_Receipt_Id__c, ExpressionOfInterest__c, ExpressionOfInterest__r.Status__c, SalesOrder__c, SalesOrderInstallment__c
    //                                                   FROM Receipt__c WHERE ExpressionOfInterest__c IN :eoiIds
    //                                                   AND Oracle_Receipt_Id__c = null
    //                                                   AND Receipt_Type__c =: ModonEgyptConstants.EOI_RECEIPT];	//v3.1
    //
    //             if (!eoiReceiptsToSync.isEmpty()) {
    //                 receiptTriggerHelper.passEgyptReceipts(eoiReceiptsToSync);
    //             }
    //         }
    //
    //     }
}