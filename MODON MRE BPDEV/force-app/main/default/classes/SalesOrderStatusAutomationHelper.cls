/**********************************************************************************************************************
* Name               : SalesOrderStatusAutomationHelper                                                        
* Description        : This class is used as a handle the new "Sales Order Journey Automation"
* Created By         : ActiveMinds                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Dselvam        						02 Dec 2025     Initial Draft 
* 1.1           Raghu Gajjela                       02 Jan 2026     Added salesorder email sending to customer in 'checkDownPaymentStatus' method.
* 1.2           Dselvam                             08 Jan 2026     Added condition to upload correct "SPA" files into the folders and avoid duplicate file upload if already uploaded.
* 2.0           Dselvam                             09 Jan 2026     Added Contion like SO Name, Unit Name and SPA - to check SPA file and move to respective SPA folder.
* 3.0           Dselvam                             08 Apr 2026     Added Finance Step Automation, DP & ADM Buffer Logic, SPA CounterSigned SO Closing Automation
* 3.1           DSelvam                             11 Apr 2026     Reverted back previous spa doc condition to store relavant folder
* 4.1           Sireesha                            04 May 2026     calling ADM creation method when So status is completed
* 5.0           Arvind                              06 Jun 2026     P1 FIX - Too many SOQL queries: 101.
* 5.1           Arvind                              06 Jun 2026     FIX - Added closingTheStatus(Set<Id>, List<String>)                                                                 
* 6.0           Arvind Kesharwani                   20 Aug 2026     FIX + MOVED - Removed the legacy duplicate Xibo survey
* 7.0           Arvind Kesharwani                   22 Sep 2026     CHANGE - DP & ADM 'Paid' vs 'Partially Paid' now driven by the invoice
*                                                                   outstanding amount instead of the receipt-driven InvoiceStatus__c.
*                                                                   Paid when (InvoiceAmount__c - SUM(Applied Allocation.ApprovedReceiptAmount__c))
*                                                                   is <= Label.DownpaymentBufferAmount (2000) / Label.ADMBufferAmount (100),
*                                                                   otherwise 'Partially Paid'.
*                                                                   Cleared Date is now stamped on buffer-promoted records too.
******************************************************************************************************************/
public class SalesOrderStatusAutomationHelper {
    private static final String ROW_CAUSE = 'Manual'; // or 'Manual' temporarily
    private static Boolean ran = false;
    public static Boolean alreadyRan() { if (ran) return true; ran = true; return false; }

    // 5.0 - P1 FIX - Arvind - 06 Jun 2026
    // Caches Sales_Order_Sub_Status_Meta_Data__mdt for the entire transaction.
    // Without this, handleStatusClose() queried this MDT every time it was called
    // (fired 615x per transaction) causing "Too many SOQL queries: 101" crash.
    // Static variables persist for the whole transaction so DB is hit only once.
    private static List<Sales_Order_Sub_Status_Meta_Data__mdt> cachedSubStatusMeta;

    // 5.0 - P1 FIX - Arvind - 06 Jun 2026
    // Returns cached MDT list. Queries DB only on first call per transaction.
    // All subsequent calls return the cached list instantly.
    // Only called from handleStatusClose(). No other method affected.
    private static List<Sales_Order_Sub_Status_Meta_Data__mdt> getSubStatusMeta() {
        if (cachedSubStatusMeta == null) {
            cachedSubStatusMeta = [
                SELECT Current_Sub_Status__c, Sales_Order_Status__c, Next_Sub_Status__c,
                       Approval_Status__c, Alert_Message__c, Sales_Journey_Flow__c
                FROM   Sales_Order_Sub_Status_Meta_Data__mdt
            ];
        }
        return cachedSubStatusMeta;
    }

    public static Boolean anyAssociateFieldChanged(SalesOrder__c oldR, SalesOrder__c newR) {
        return oldR.Finance_Associate__c            != newR.Finance_Associate__c ||
               oldR.Customer_Management_Associate__c != newR.Customer_Management_Associate__c ||
               oldR.SalesAssociate__c                != newR.SalesAssociate__c ||
               oldR.Sales_Operations_Associate__c    != newR.Sales_Operations_Associate__c;
    }
    
    @AuraEnabled
    public static String getAdmPaymentStatus(Id salesOrderId) {
        SalesOrder__c so = [SELECT ADM_Fees_and_Dari__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
        return so.ADM_Fees_and_Dari__c;
    }
/* 
    @AuraEnabled
    public static void updateWaiverMemoNumber(Id salesOrderId, String waiverMemoNumber) {
        if (String.isBlank(waiverMemoNumber)) return;
        List<Offers_Collections__c> offerList = [
            SELECT Id FROM Offers_Collections__c WHERE Sales_Order__c = :salesOrderId
        ];
        for (Offers_Collections__c offer : offerList) {
            offer.Waiver_Memo_No__c = waiverMemoNumber;
        }
        if (!offerList.isEmpty()) {
            update offerList;
        }
    }
     */
    public static void validatestatusAutomation(List<Sales_Order_Status_Approvals__c> newList){
    Map<Id,String> salesOrderMap = new Map<Id,String>();
        /******* STATUS AUTOMATE MAPPING *******
* "Reservation Form Generated --> checkReservationForm"
* "Reservation Form Signed --> checkReservationForm"
* "Broker Form Generated --> checkBrokerForm"
* "Broker Form Signed --> checkBrokerForm"
* "SPA Generated & Signed (Customer) --> checkSPAStatus"
* "Down Payment Collected --> checkDownPaymentStatus"
* "ADM + Dari Fee Collected --> checkADMFeeDariFeeStatus"
* "SPA In-Progress --> checkSPAStatus"
* "Signed SPA (Customer) --> checkSPAStatus"
* "Signed SPA (Modon) --> checkSPAStatus"
* *************************************/
        
        /**************************************
* ******* AUTO CLOSE STEP ************
* Pending With Sales
* Pending With Sales Team
* Pending With Sales Operation
* Pending With CM
* Under Finance Verification
**************************************/
        Set<Id> autoCloseStatus = new Set<Id>();
        Set<Id> reservationFormcheck = new Set<Id>();
        Set<Id> brokerFormcheck = new Set<Id>();
        Set<Id> spaStatuscheck = new Set<Id>();
        Set<Id> dpCheck = new Set<Id>();
        Set<Id> admCheck = new Set<Id>();
        
        List<String> autoCloseStatusList = new List<String>{
                'pending with sales',
                'spa in progress',
                'pending with sales team',
                'pending with sales operation',
                'pending with cm',
                'document checklist verified by - sales operation',
                'document checklist verified by - customer management',
                'under finance verification',
                'completed'
                };
                    List<String> reservationFormStatusList = new List<String>{
                        'reservation form generated',
                            'reservation form signed'
                            };
                                List<String> brokerFormStatusList = new List<String>{
                                    'broker form generated',
                                        'broker form signed'
                                        };
                                            List<String> spaStatusList = new List<String>{
                                                'spa in-progress',
                                                    'signed spa (customer)',
                                                    'signed spa (modon)',
                                                    'spa generated & signed (customer)',
                                                    'spa in progress',
                                                    'spa signed (customer)'
                                                    };
                                                        Set<Id> soAppIdpendingSales = new Set<Id>();
        for(Sales_Order_Status_Approvals__c soApp: newList){
            salesOrderMap.put(soApp.Sales_Order__c,soApp.Current_Sub_Status__c);
            if(autoCloseStatusList.contains(soApp.Current_Sub_Status__c.toLowerCase())){
                autoCloseStatus.add(soApp.Id);
            }
        }
        Map<Id,SalesOrder__c> soAppMap = new Map<Id,SalesOrder__c>();
        for(SalesOrder__c soapp:[SELECT Id,Is_Sales_Checklist_Completed__c FROM SalesOrder__c WHERE ID IN: salesOrderMap.keySet() AND (NOT Status__c IN ('Voided','Cancelled'))]){
            soAppMap.put(soapp.Id,soapp);
        }
        for(Id soId: salesOrderMap.keySet()){
            if(soAppMap.containsKey(soId)){
                String subStatus = salesOrderMap.get(soId).toLowerCase();
                if(reservationFormStatusList.contains(subStatus)){
                    reservationFormcheck.add(soId); 
                }else if(brokerFormStatusList.contains(subStatus)){
                    brokerFormcheck.add(soId);
                }else if(spaStatusList.contains(subStatus)){
                    spaStatuscheck.add(soId); 
                }else if(salesOrderMap.get(soId) == 'Down Payment Collected'){
                    dpCheck.add(soId);
                }else if(salesOrderMap.get(soId) == 'ADM + Dari Fee Collected'){
                    admCheck.add(soId);
                }
            }
        }
        
        if(!autoCloseStatus.isEmpty()){
            autoCloseStatus(autoCloseStatus);
        }
        if(!reservationFormcheck.isEmpty()){
            checkReservationForm(reservationFormcheck);
        }
        if(!brokerFormcheck.isEmpty()){
            checkBrokerForm(brokerFormcheck);
        }
        if(!spaStatuscheck.isEmpty()){
            checkSPAStatus(spaStatuscheck); 
        }
        if(!dpCheck.isEmpty()){
            checkDownPaymentStatus(dpCheck);
        }
        if(!admCheck.isEmpty()){
            checkADMFeeDariFeeStatus(admCheck);
        }
    }
    public static void autoCloseStatus(Set<Id> soAppIdset){
        Set<Id> soIdset =new Set<Id>();
        List<Sales_Order_Status_Approvals__c> soaListUpdate = new List<Sales_Order_Status_Approvals__c>();
        for(Sales_Order_Status_Approvals__c soa:[SELECT Id,Sales_Order__c,Sales_Order__r.Is_Reservation_Form_Required__c,Current_Sub_Status__c FROM Sales_Order_Status_Approvals__c WHERE ID IN:soAppIdset AND Approval_Status__c = 'Pending']){
            Sales_Order_Status_Approvals__c soaObj = new Sales_Order_Status_Approvals__c();
            soaObj.Id =  soa.id;
            soaObj.Approval_Status__c = 'Approved';
            soaObj.Comments__c = soa.Current_Sub_Status__c+' Closing this step to update in Sales Order';
            soaObj.Completed_Date__c = System.today();
            soaListUpdate.add(soaObj);
            if(soa.Current_Sub_Status__c == 'Under Finance Verification'){
                soIdset.add(soa.Sales_Order__c);
            }
        }
        if(!soaListUpdate.isEmpty()){
            update soaListUpdate;
            if(!soIdset.isEmpty()){
            	closeFinaceVerificationStep(soIdset); /**3.0 Finance Step Auto Close After DP & ADM Paid**/
            }
        }
    }
    public static void handleStatusClose(List<Sales_Order_Status_Approvals__c> newList,Map<Id,Sales_Order_Status_Approvals__c> oldMap){
        Set<Id> soAppIdset = new Set<Id>();
        List<Sales_Order_Status_Approvals__c> salesOrderStsApprvlList = new List<Sales_Order_Status_Approvals__c>();
        List<Sales_Order_Status_Approvals__c> newSalesOrderStsApprvlList = new List<Sales_Order_Status_Approvals__c>();
        Map<String,Sales_Order_Sub_Status_Meta_Data__mdt> statusMetaDataMap = new Map<String,Sales_Order_Sub_Status_Meta_Data__mdt>();
        Map<String,Sales_Order_Sub_Status_Meta_Data__mdt> approvalDataMap = new Map<String,Sales_Order_Sub_Status_Meta_Data__mdt>();
        
        Set<Id> recordIdset = new Set<Id>();
        for(Sales_Order_Status_Approvals__c record : newList){
            Sales_Order_Status_Approvals__c oldRecord = oldMap.get(record.Id);
            if(record.Approval_Status__c <> null && record.Approval_Status__c <> oldRecord.Approval_Status__c && (record.Approval_Status__c == 'Approved' || record.Approval_Status__c == 'Rejected')){
                recordIdset.add(record.Id);
            }
        }
        if(!recordIdset.isEmpty()){ 
            // 5.0 - P1 FIX - Arvind - 06 Jun 2026
            // ORIGINAL LINE REMOVED: for(Sales_Order_Sub_Status_Meta_Data__mdt soMdt:[SELECT ... FROM Sales_Order_Sub_Status_Meta_Data__mdt]){
            // That inline query fired every time this method was called (615x total per transaction).
            // REPLACED WITH: getSubStatusMeta() which returns the same data from static cache.
            // Everything inside the loop below is 100% identical to original - zero logic change.
            for(Sales_Order_Sub_Status_Meta_Data__mdt soMdt : getSubStatusMeta()){
                statusMetaDataMap.put(soMdt.Sales_Journey_Flow__c+soMdt.Current_Sub_Status__c+soMdt.Approval_Status__c,soMdt);
                approvalDataMap.put(soMdt.Current_Sub_Status__c+soMdt.Sales_Journey_Flow__c,soMdt);
            }         
            for(Sales_Order_Status_Approvals__c record : [SELECT Id,Approval_Status__c,Flow__c,Current_Sub_Status__c,Next_Sub_Status__c,Sales_Order_Status__c,Sales_Order__c FROM Sales_Order_Status_Approvals__c WHERE Id IN: recordIdset]){
                soAppIdset.add(record.Id);
                
                Sales_Order_Status_Approvals__c soApp = new Sales_Order_Status_Approvals__c();
                soApp.Id = record.Id;
                soApp.Approve_Rejected_By__c = UserInfo.getUserId();
                soApp.Approval_Rejected_Date__c = DateTime.now();
                soApp.Completed_Date__c = DateTime.now();
                salesOrderStsApprvlList.add(soApp);
                
                
                System.debug('statusMetaDataMap:'+record.Flow__c+record.Current_Sub_Status__c+record.Approval_Status__c+' output:'+statusMetaDataMap.containsKey(record.Flow__c+record.Current_Sub_Status__c+record.Approval_Status__c));
                if(statusMetaDataMap.containsKey(record.Flow__c+record.Current_Sub_Status__c+record.Approval_Status__c) && statusMetaDataMap.get(record.Flow__c+record.Current_Sub_Status__c+record.Approval_Status__c).Next_Sub_Status__c <> null){
                    Sales_Order_Sub_Status_Meta_Data__mdt mdtData = approvalDataMap.get(statusMetaDataMap.get(record.Flow__c+record.Current_Sub_Status__c+record.Approval_Status__c).Next_Sub_Status__c+record.Flow__c);
                    if(mdtData <> null){
                        Sales_Order_Status_Approvals__c soAppNew = new Sales_Order_Status_Approvals__c();
                        soAppNew.Sales_Order__c = record.Sales_Order__c;
                        soAppNew.Approval_Status__c = 'Pending';
                        soAppNew.Alert_Message__c = mdtData.Alert_Message__c;
                        soAppNew.Current_Sub_Status__c = mdtData.Current_Sub_Status__c;
                        soAppNew.Next_Sub_Status__c = mdtData.Next_Sub_Status__c;
                        soAppNew.Sales_Order_Status__c = mdtData.Sales_Order_Status__c;
                        soAppNew.Submitted_Date__c = DateTime.now();
                        soAppNew.Flow__c = record.Flow__c;
                        newSalesOrderStsApprvlList.add(soAppNew);
                        
                    }
                }
            }
            if(!salesOrderStsApprvlList.isEmpty()){
                update salesOrderStsApprvlList;
            }
            if(!newSalesOrderStsApprvlList.isEmpty()){
                insert newSalesOrderStsApprvlList;
            }
            
        }
    }
    public static void handleApprovalStatusonNewCreation(List<sObject> salesOrderList){
        List<Sales_Order_Status_Approvals__c> approvalsToInsert = new List<Sales_Order_Status_Approvals__c>();
        Set<Id> soIdset = new Set<Id>();
        for(SalesOrder__c so: (List<SalesOrder__c>)salesOrderList){
            if(so.Source_Entity__c != 'Modon - Egypt' && so.Resale__c == false){
                soIdset.add(so.Id);
            }
        }
        Map<Id,List<Sales_Order_Sub_Status_Meta_Data__mdt>> createFirstTransitionMap = new Map<Id,List<Sales_Order_Sub_Status_Meta_Data__mdt>>();
        if(!soIdset.isEmpty()){
            Map<String,Sales_Order_Sub_Status_Meta_Data__mdt> journeyflowMap = new  Map<String,Sales_Order_Sub_Status_Meta_Data__mdt>();
            for(Sales_Order_Sub_Status_Meta_Data__mdt transition:[SELECT Current_Sub_Status__c, Sales_Order_Status__c, Next_Sub_Status__c,Sales_Journey_Flow__c FROM Sales_Order_Sub_Status_Meta_Data__mdt
                                                                  WHERE IsDefaultStatus__c = true]){
                                                                      
                                                                      journeyflowMap.put(transition.Sales_Journey_Flow__c,transition);  
                                                                  }
            Map<Id,String> soJourneyFlow = new Map<Id,String>();
            for(SalesOrder__c soObj:[SELECT Id,Sales_Journey_Flow__c FROM SalesOrder__c WHERE Id IN:soIdset]){
                soJourneyFlow.put(soObj.Id,soObj.Sales_Journey_Flow__c);
            }
            for(SalesOrder__c so: (List<SalesOrder__c>)salesOrderList){
                String flowName = soJourneyFlow.get(so.Id);
                if(journeyflowMap.containsKey(flowName)){
                    Sales_Order_Sub_Status_Meta_Data__mdt matchedTransition = journeyflowMap.get(flowName);
                    approvalsToInsert.add(new Sales_Order_Status_Approvals__c(
                        Sales_Order__c = so.Id,
                        Sales_Order_Status__c = matchedTransition.Sales_Order_Status__c,
                        Current_Sub_Status__c = matchedTransition.Current_Sub_Status__c,
                        Next_Sub_Status__c = matchedTransition.Next_Sub_Status__c,
                        Approval_Status__c = 'Pending',
                        Flow__c = flowName,
                        Submitted_Date__c = System.today()
                    ));
                }
            }
            insert approvalsToInsert;
        }
    }
    public static void handleStsUpdateFromDocuChecklist(List<Document_Checklist__c> newList, Map<Id,Document_Checklist__c> oldMap){
        Map<String,String> docStatusValuesMap = new Map<String,String>();
        docStatusValuesMap.put('New-Sales-Approved-Reservation', 'Pending With Sales Operation');
        docStatusValuesMap.put('New-Sales-Approved-SPA', 'SPA In Progress');
        docStatusValuesMap.put('In Progress-Sales-Approved', 'Pending With Sales Operation');
        docStatusValuesMap.put('In Progress-Sales-Rejected', 'Pending With Sales Team');
        docStatusValuesMap.put('In Progress-Sales Operation-Approved', 'Document Checklist Verified By - Sales Operation');
        docStatusValuesMap.put('In Progress-Sales Operation-Rejected', 'Pending With Sales Team');
        docStatusValuesMap.put('In Progress-Customer Management-Approved', 'Document Checklist Verified By - Customer Management');
        docStatusValuesMap.put('In Progress-Customer Management-Rejected', 'Pending With Sales Operation');
        docStatusValuesMap.put('In Progress-Finance-Approved', 'Pending with CM');
        docStatusValuesMap.put('In Progress-Finance-Rejected', 'Pending With Sales Operation');
        
        Set<Id> docCheckListIdset = new Set<Id>();
        for(Document_Checklist__c docCheck: newList){
            Document_Checklist__c oldData = oldMap == null ? null : oldMap.get(docCheck.Id);
            if(docCheck.Approval_Status__c <> null && (docCheck.Approval_Status__c == 'Approved' || docCheck.Approval_Status__c == 'Rejected') && (oldData == null ||(oldData <> null && oldData.Approval_Status__c <> docCheck.Approval_Status__c ))){
                docCheckListIdset.add(docCheck.Id);
            }
        }
        if(!docCheckListIdset.isEmpty()){
            Map<Id,String> salesOrderStsMap = new Map<Id,String>();
            Map<Id,String> salesOrderFlowMap = new Map<Id,String>();
            for(Document_Checklist__c doc:[SELECT Id,Sales_Order__c,Sales_Order__r.Status__c,Team__c,Approval_Status__c,Sales_Order__r.Sales_Journey_Flow__c FROM Document_Checklist__c WHERE Id IN: docCheckListIdset]){
                String key = doc.Sales_Order__r.Status__c+'-'+doc.Team__c+'-'+doc.Approval_Status__c;
                if(doc.Sales_Order__r.Status__c == 'New' && doc.Sales_Order__r.Sales_Journey_Flow__c.contains('SPA')){
                    key = key+'-SPA';
                }else if(doc.Sales_Order__r.Status__c == 'New' && doc.Sales_Order__r.Sales_Journey_Flow__c.contains('Reservation')){
                     key = key+'-Reservation';
                }
                System.debug('key:'+key);
                if(docStatusValuesMap.containsKey(key)){
                    salesOrderStsMap.put(doc.Sales_Order__c,docStatusValuesMap.get(key));
                    salesOrderFlowMap.put(doc.Sales_Order__c,doc.Sales_Order__r.Sales_Journey_Flow__c);
                }
            }
            System.debug('salesOrderStsMap:'+salesOrderStsMap);
            System.debug('salesOrderFlowMap:'+salesOrderFlowMap);
            Map<String, Sales_Order_Sub_Status_Meta_Data__mdt> statusMetaDataMap = new Map<String, Sales_Order_Sub_Status_Meta_Data__mdt>();
            for (Sales_Order_Sub_Status_Meta_Data__mdt soMdt : [
                SELECT Current_Sub_Status__c, Sales_Order_Status__c, Next_Sub_Status__c, Approval_Status__c, Alert_Message__c,Sales_Journey_Flow__c
                FROM Sales_Order_Sub_Status_Meta_Data__mdt
                WHERE Current_Sub_Status__c IN :salesOrderStsMap.values() AND Sales_Journey_Flow__c IN:salesOrderFlowMap.values()
            ]) {
                statusMetaDataMap.put(soMdt.Current_Sub_Status__c+soMdt.Sales_Journey_Flow__c, soMdt);
            }
            
            List<Sales_Order_Status_Approvals__c> soAppNewList = new List<Sales_Order_Status_Approvals__c>();
            for (Id soId : salesOrderStsMap.keySet()) {
                Sales_Order_Sub_Status_Meta_Data__mdt mdtData = statusMetaDataMap.get(salesOrderStsMap.get(soId)+salesOrderFlowMap.get(soId));
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
                soAppNew.Flow__c = salesOrderFlowMap.get(soId);
                System.debug('Prepared new Sales_Order_Status_Approvals__c: ' + soAppNew);
                
                soAppNewList.add(soAppNew);
            }
            if(!soAppNewList.isEmpty()){
                insert soAppNewList;
            }
        }
    }
    public static void updateSOSubStatus(List<Sales_Order_Status_Approvals__c> newList,Map<Id,Sales_Order_Status_Approvals__c> oldMap){
        Set<Id> soApprovalIdSet = new Set<Id>();
        for(Sales_Order_Status_Approvals__c record : newList){
            Sales_Order_Status_Approvals__c oldRecord = oldMap.get(record.Id);
            if(record.Approval_Status__c <> null && record.Approval_Status__c <> oldRecord.Approval_Status__c && (record.Approval_Status__c == 'Approved' || record.Approval_Status__c == 'Rejected')){
                soApprovalIdSet.add(record.Id);
            }
        }
        Map<Id,SalesOrder__c> soStatusUpdateMap = new Map<Id,SalesOrder__c>();
        for(Sales_Order_Status_Approvals__c soa:[SELECT Id,Alert_Message__c,Next_Sub_Status__c,Current_Sub_Status__c,Sales_Order__c,Sales_Order_Status__c,Sales_Order__r.Status__c FROM Sales_Order_Status_Approvals__c WHERE Id IN: soApprovalIdSet ]){ //AND Approval_Status__c = 'Approved'
            SalesOrder__c soUpd = new SalesOrder__c();
            soUpd.Id = soa.Sales_Order__c;
            if(soa.Sales_Order__r.Status__c != soa.Sales_Order_Status__c){
                soUpd.Status__c = soa.Sales_Order_Status__c;
            }
            soUpd.Sub_Status__c = soa.Current_Sub_Status__c;
            soUpd.AlertMessage__c = soa.Alert_Message__c;
            soStatusUpdateMap.put(soUpd.Id,soUpd);
        }
        if(!soStatusUpdateMap.values().isEmpty()){
            update soStatusUpdateMap.values();
        }
        
    }
    
    /**
     * parseBufferAmount — V7.0 — Arvind Kesharwani — 22 Sep 2026
     * Null/blank-safe read of the buffer Custom Labels (DownpaymentBufferAmount = 2000,
     * ADMBufferAmount = 100). Thresholds stay in Labels so they can be changed by an
     * admin without a deployment. A blank or non-numeric Label falls back to 0, which
     * means "no buffer" rather than throwing at runtime.
     */
    @TestVisible
    private static Decimal parseBufferAmount(String labelValue){
        if(String.isBlank(labelValue)) return 0;
        try{
            return Decimal.valueOf(labelValue.trim());
        }catch(Exception e){
            System.debug('V7.0 parseBufferAmount: invalid buffer label value -> ' + labelValue);
            return 0;
        }
    }

    public static void checkDownPaymentStatus(Set<Id> salesOrderIdSet){
        Set<Id> salesOrderIdsetDPCollected= new Set<Id>();
        Set<Id> salesOrderIdsetDPPaid= new Set<Id>();
        List<SalesOrderInstallments__c> salesOrderInstallements = [SELECT Id, Name, Milestone__c FROM SalesOrderInstallments__c WHERE SalesOrder__c IN: salesOrderIdSet AND MilestoneNumber__c = 1 AND (NOT SalesOrder__r.Status__c IN ('Voided','Cancelled'))];
        if(!salesOrderInstallements.isEmpty()){
            Set<Id> soInstallmentIdset = new Set<Id>();
            for(SalesOrderInstallments__c soId: salesOrderInstallements){
                soInstallmentIdset.add(soId.Id);
            }
            List<Invoice__c> invoiceObjLst = [SELECT Id, Name,SalesOrderInstallment__r.SalesOrder__r.IsDownPaymentCollected__c, InvoiceStatus__c, AppliedAmount__c, InvoiceAmount__c,SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.SalesOrder__r.Down_Payment_Status__c,TotalPaidAmount__c  FROM Invoice__c WHERE SalesOrderInstallment__c =: soInstallmentIdset];
            Map<Id,Invoice__c> invoiceMap = new Map<Id,Invoice__c>();
            for(Invoice__c inv: invoiceObjLst){
                invoiceMap.put(inv.Id,inv);
            }
            Map<Id,SalesOrder__c> salesOrderUpdateMap = new Map<Id,SalesOrder__c>();
            if(!invoiceObjLst.isEmpty()){
                List<SalesOrder__c> updateDPCollectedCheck = new List<SalesOrder__c>(); 
                Set<Id> closeFinanceStep = new Set<Id>();
                 /**3.0 DP & ADM Payment Buffer Amount Added & Considered to Make Status to Paid & Collected**/
                Map<Id,decimal> totalPaidAmountMap = new Map<Id,decimal>();
                for(AggregateResult alloc:[SELECT SUM(ApprovedReceiptAmount__c) TOTALAMT,Invoice__c INV FROM Allocation__c  WHERE Invoice__c IN: invoiceMap.keySet() AND Status__c ='Applied' AND ApprovedReceiptAmount__c <> null GROUP BY Invoice__c]){
                    totalPaidAmountMap.put((Id) alloc.get('INV'), (Decimal) alloc.get('TOTALAMT'));
                }
                /**
                 * Arvind Kesharwani - 22 Sep 2026 : V7.0 - Down Payment 'Paid' is now driven
                 * by the OUTSTANDING AMOUNT on the invoice, not by the receipt-driven
                 * Invoice.InvoiceStatus__c.
                 * Remaining = InvoiceAmount__c - SUM(Applied Allocation.ApprovedReceiptAmount__c).
                 * When Remaining is LESS THAN OR EQUAL TO Label.DownpaymentBufferAmount (2000),
                 * the Down Payment is treated as fully Paid and the Finance step is closed,
                 * whatever the invoice status says. Remaining ABOVE 2000 stays 'Partially Paid'.
                 */
                Decimal dpBufferAmount = parseBufferAmount(System.Label.DownpaymentBufferAmount);
                for(Invoice__c invObj: invoiceObjLst){
                    /** Arvind Kesharwani - 22 Sep 2026 : V7.0 - outstanding-amount driven Paid evaluation **/
                    Decimal dpTotalPaidAmount = (totalPaidAmountMap.containsKey(invObj.Id) && totalPaidAmountMap.get(invObj.Id) <> null)
                                                 ? totalPaidAmountMap.get(invObj.Id) : 0;
                    Decimal dpInvoiceAmount   = invObj.InvoiceAmount__c <> null ? invObj.InvoiceAmount__c : 0;
                    Decimal dpRemainingAmount = dpInvoiceAmount - dpTotalPaidAmount;
                    // Cancelled invoices are never promoted; a zero-paid invoice is never promoted
                    // even when its own amount happens to sit below the buffer.
                    Boolean isDPPaidWithinBuffer = invObj.InvoiceStatus__c != 'Cancelled'
                                                   && dpTotalPaidAmount > 0
                                                   && dpRemainingAmount <= dpBufferAmount;

                    if(invoiceMap.containsKey(invObj.Id) && invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c <> null && (invObj.AppliedAmount__c + (Decimal.valueOf(System.Label.DownpaymentBufferAmount))) >= invObj.InvoiceAmount__c){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        Id soId = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Id = soId;
                        if(invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__r.IsDownPaymentCollected__c == false){
                        	SalesOrder.IsDownPaymentCollected__c = true;
                            system.debug('debug:IsDownPaymentCollected__c');
                            updateDPCollectedCheck.add(SalesOrder);
                            salesOrder.Down_Payment_Status__c = 'Collected';
                            salesOrder.Down_Payment_Collected_Date__c = System.today();
                            salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                            salesOrderIdsetDPCollected.add(soId);
                        }
                         /**3.0 DP & ADM Payment Buffer Amount Added & Considered to Make Status to Paid & Collected**/
                        if(invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__r.Down_Payment_Status__c == 'Generated'|| invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__r.Down_Payment_Status__c == null ){
                             salesOrder.Down_Payment_Reversal_Reason__c = '';
                             salesOrder.Down_Payment_Status__c = 'Collected';
                        }
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                    }
                    /** Arvind Kesharwani - 22 Sep 2026 : V7.0 - 'Paid' now also reached when the
                     *  remaining amount is below the buffer **/
                    if(invObj.InvoiceStatus__c == 'Paid' || isDPPaidWithinBuffer){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Down_Payment_Status__c = 'Paid';
                        salesOrder.Down_Payment_Cleared_Date__c = System.today();
                        salesOrder.Down_Payment_Reversal_Reason__c = '';
                        salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                        salesOrderIdsetDPPaid.add(salesOrder.Id);
                        closeFinanceStep.add(salesOrder.Id);
                        //salesOrderIdsetDPCollected.add(salesOrder.Id);
                    }else if(invObj.InvoiceStatus__c == 'Partially Paid'){
                        /** Arvind Kesharwani - 22 Sep 2026 : V7.0 - the buffer promotion that used
                         *  to live here is handled by isDPPaidWithinBuffer above, so this branch is
                         *  now reached only when the outstanding amount is still at or above the buffer. **/
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Down_Payment_Status__c = 'Partially Paid';
                        salesOrder.Down_Payment_Reversal_Reason__c = '';
                        salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                       // salesOrderIdsetDPCollected.add(salesOrder.Id);
                    }else if(invObj.InvoiceStatus__c == 'Cancelled'){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Down_Payment_Status__c = 'Cancelled';
                        salesOrder.Down_Payment_Reversal_Reason__c = '';
                        salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                    }else if((invObj.AppliedAmount__c + (Decimal.valueOf(System.Label.DownpaymentBufferAmount))) >= invObj.InvoiceAmount__c){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Down_Payment_Status__c = 'Collected';
                        salesOrder.Down_Payment_Collected_Date__c = System.today();
                        salesOrder.Down_Payment_Reversal_Reason__c = '';
                        salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                       // salesOrderIdsetDPCollected.add(salesOrder.Id);
                    }else if(invObj.AppliedAmount__c > 0 && (invObj.AppliedAmount__c + (Decimal.valueOf(System.Label.DownpaymentBufferAmount))) < invObj.InvoiceAmount__c){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Down_Payment_Status__c = 'Partially Collected';
                        salesOrder.Down_Payment_Reversal_Reason__c = '';
                        salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                        //salesOrderIdsetDPCollected.add(salesOrder.Id);
                    }
                    else{
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        salesOrder.Down_Payment_Status__c = 'Generated';
                        salesOrder.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                    }
                    
                }
                // Arvind Kesharwani - 20 Aug 2026 : V6.0 - REMOVED legacy duplicate Xibo call.
                // Original block removed here:
                //   Set<String> soIdsForXiboSurvey = new Set<String>();
                //   ... soIdsForXiboSurvey.add(String.valueOf(soId)); ...
                //   if(!soIdsForXiboSurvey.isEmpty() && !Test.isRunningTest()){
                //       sendRequestToXiboApi.getSurvey_Future(soIdsForXiboSurvey,'SalesOrder__c');
                //   }
                // REPLACED WITH the call to sendDownPaymentSurvey() below, right after the
                // update updateDPCollectedCheck DML — see that method (added after this one)
                // for the current implementation using SurveyTrackerService.
                if(!updateDPCollectedCheck.isEmpty()){
                    update updateDPCollectedCheck;
                    closingTheStatus(salesOrderIdsetDPCollected,'Down Payment Collected');

                    // Arvind Kesharwani - 20 Aug 2026 : V6.0 - Down Payment Collected survey sent
                    // right after the DML that flips IsDownPaymentCollected__c false -> true.
                    // THIS IS THE SINGLE SOURCE OF TRUTH for this survey — do not add any other
                    // call to SurveyTrackerService or sendRequestToXiboApi for this event
                    // elsewhere in the codebase. salesOrderIdsetDPCollected already contains
                    // exactly the Sales Order Ids whose flag just flipped, so no additional
                    // filtering is needed here.
                    if(!salesOrderIdsetDPCollected.isEmpty() && !Test.isRunningTest()){
                        sendDownPaymentSurvey(salesOrderIdsetDPCollected);
                    }
                }
                
                if(!salesOrderUpdateMap.values().isEmpty()){
                    update salesOrderUpdateMap.values();
                    if(!closeFinanceStep.isEmpty()){
                        closeFinaceVerificationStep(closeFinanceStep); /** 3.0 Closing the finance Step After DP & ADM Paid **/
                    }
                } 
            } 
        }
    }

    /**
     * sendDownPaymentSurvey — V6.0 — Arvind Kesharwani — 20 Aug 2026
     */
    @TestVisible
    private static void sendDownPaymentSurvey(Set<Id> salesOrderIdsetDPCollected) {
        if (salesOrderIdsetDPCollected == null || salesOrderIdsetDPCollected.isEmpty()) return;

        Xebo_Survey_Config__mdt directCfg   = Xebo_Survey_Config__mdt.getInstance('Sales_Order_Down_Payment_Direct');
        Xebo_Survey_Config__mdt indirectCfg = Xebo_Survey_Config__mdt.getInstance('Sales_Order_Down_Payment_Indirect');

        List<SalesOrder__c> soRecs = [SELECT Id, Sales_Type__c, FormulaEmail__c, FormulaMobile__c, ProjectName__c,
                                      Unit__r.Name, CustomerAccount__r.Name, SalesAssociate__r.Name,
                                      PrimaryContact__r.FirstName, PrimaryContact__r.LastName,
                                      Primary_Contact_Nationality__c, Primary_Contact_Residence_Status__c
                                      FROM SalesOrder__c
                                      WHERE Id IN :salesOrderIdsetDPCollected
                                      AND Source_Entity__c != 'Modon - Egypt'];

        List<SurveyTrackerService.SurveyTrackerRequest> requests =
            new List<SurveyTrackerService.SurveyTrackerRequest>();

        for (SalesOrder__c so : soRecs) {

            String collectorId;
            if (so.Sales_Type__c == 'Direct' && directCfg != null) {
                collectorId = directCfg.Collector_Id__c;
            } else if (so.Sales_Type__c == 'Indirect' && indirectCfg != null) {
                collectorId = indirectCfg.Collector_Id__c;
            } else {
                continue;
            }
            if (String.isBlank(collectorId)) continue;

            SurveyTrackerService.SurveyTrackerRequest req = new SurveyTrackerService.SurveyTrackerRequest();
            req.collectorId   = collectorId;
            req.medium        = 2; // Email
            req.contactEmail  = so.FormulaEmail__c;
            req.contactMobile = so.FormulaMobile__c;
            req.recordId      = so.Id;
            req.objectApiName = 'SalesOrder__c';
            req.triggerEvent  = 'Down Payment Collected';

            req.fname         = so.PrimaryContact__r != null ? so.PrimaryContact__r.FirstName : null;
            req.lname         = so.PrimaryContact__r != null ? so.PrimaryContact__r.LastName  : null;
            req.nationality   = so.Primary_Contact_Nationality__c;
            req.residency     = so.Primary_Contact_Residence_Status__c;

            // Legacy payload fields — keys kept exactly as originally sent to Xebo
            List<Map<String, Object>> legacyFields = new List<Map<String, Object>>();
            if (so.Unit__r != null && String.isNotBlank(so.Unit__r.Name))
                legacyFields.add(new Map<String, Object>{'key' => 'unitname',    'value' => so.Unit__r.Name});
            if (so.CustomerAccount__r != null && String.isNotBlank(so.CustomerAccount__r.Name))
                legacyFields.add(new Map<String, Object>{'key' => 'accountName', 'value' => so.CustomerAccount__r.Name});
            if (String.isNotBlank(so.ProjectName__c))
                legacyFields.add(new Map<String, Object>{'key' => 'projectname', 'value' => so.ProjectName__c});
            if (so.SalesAssociate__r != null && String.isNotBlank(so.SalesAssociate__r.Name))
                legacyFields.add(new Map<String, Object>{'key' => 'salesasso',   'value' => so.SalesAssociate__r.Name});
            if (String.isNotBlank(so.Sales_Type__c))
                legacyFields.add(new Map<String, Object>{'key' => 'salestype',   'value' => so.Sales_Type__c});
            legacyFields.add(new Map<String, Object>{'key' => 'recordId',   'value' => String.valueOf(so.Id)});
            legacyFields.add(new Map<String, Object>{'key' => 'closedDate', 'value' => String.valueOf(System.today())});

            req.extraInfoJson = JSON.serialize(legacyFields);

            requests.add(req);
        }

        if (!requests.isEmpty()) {
            SurveyTrackerService.createAndSend(requests);
        }
    }

    public static void checkBrokerForm(Set<Id> salesOrderIdSet){
        Set<Id> salesOrderIdsettoClsStatus= new Set<Id>();
        Set<Id> salesOrderIdsettoSignClsStatus= new Set<Id>();
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderIdSet AND Name LIKE '%Broker%' AND (NOT SalesOrder__r.Status__c IN ('Voided','Cancelled'))];
        if(!salesOrderDocs.isEmpty()){
            Map<Id,List<Documents__c>> brokerMap = new Map<Id,List<Documents__c>>();
            for(Documents__c doc:salesOrderDocs){
                if(brokerMap.containsKey(doc.SalesOrder__c)){
                    brokerMap.get(doc.SalesOrder__c).add(doc);
                }else{
                    brokerMap.put(doc.SalesOrder__c,new List<Documents__c>{doc});
                }
            }
            Map<Id,SalesOrder__c> soUpdateMap = new Map<Id,SalesOrder__c>();
            for(Id soId: brokerMap.keySet()){
                for(Documents__c doc:brokerMap.get(soId)){
                    SalesOrder__c so = new SalesOrder__c();
                    so.Id = soId;
                    if(doc.Name == 'Broker Form' && doc.Status__c == 'Uploaded'){
                        // so.Sub_Status__c = 'Reservation Form Generated';
                        salesOrderIdsettoClsStatus.add(soId);
                        salesOrderIdsettoSignClsStatus.add(soId);
                    }
                    if(doc.Name == 'Signed Broker Form' && doc.Status__c == 'Uploaded'){
                        //so.Sub_Status__c = 'Reservation Form Signed';
                        salesOrderIdsettoSignClsStatus.add(soId);
                    }
                    soUpdateMap.put(so.Id,so);
                }
            }
            if(!soUpdateMap.isEmpty()){
                update soUpdateMap.values();
                if(!salesOrderIdsettoClsStatus.isEmpty()){
                    closingTheStatus(salesOrderIdsettoClsStatus,'Broker Form Generated');
                }
                if(!salesOrderIdsettoSignClsStatus.isEmpty()){
                    closingTheStatus(salesOrderIdsettoSignClsStatus,'Broker Form Signed');
                }
            }
        }
    }
    public static void checkReservationForm(Set<Id> salesOrderIdSet){
        Set<Id> salesOrderIdsettoClsStatus= new Set<Id>();
        Set<Id> salesOrderIdsettoSignClsStatus= new Set<Id>();
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderIdSet AND Name LIKE '%Reservation%' AND (NOT SalesOrder__r.Status__c IN ('Voided','Cancelled'))];
        if(!salesOrderDocs.isEmpty()){
            Map<Id,List<Documents__c>> reservationMap = new Map<Id,List<Documents__c>>();
            for(Documents__c doc:salesOrderDocs){
                if(reservationMap.containsKey(doc.SalesOrder__c)){
                    reservationMap.get(doc.SalesOrder__c).add(doc);
                }else{
                    reservationMap.put(doc.SalesOrder__c,new List<Documents__c>{doc});
                }
            }
            Map<Id,SalesOrder__c> soUpdateMap = new Map<Id,SalesOrder__c>();
            for(Id soId: reservationMap.keySet()){
                for(Documents__c doc:reservationMap.get(soId)){
                    SalesOrder__c so = new SalesOrder__c();
                    so.Id = soId;
                    if(doc.Name == 'Reservation Form' && doc.Status__c == 'Uploaded'){
                        // so.Sub_Status__c = 'Reservation Form Generated';
                        salesOrderIdsettoClsStatus.add(soId);
                    }
                    if(doc.Name == 'Signed Reservation Form' && doc.Status__c == 'Uploaded'){
                        //so.Sub_Status__c = 'Reservation Form Signed';
                        salesOrderIdsettoSignClsStatus.add(soId);
                    }
                    soUpdateMap.put(so.Id,so);
                }
            }
            if(!soUpdateMap.isEmpty()){
                update soUpdateMap.values();
                if(!salesOrderIdsettoClsStatus.isEmpty()){
                    closingTheStatus(salesOrderIdsettoClsStatus,'Reservation Form Generated');
                }
                if(!salesOrderIdsettoSignClsStatus.isEmpty()){
                    closingTheStatus(salesOrderIdsettoSignClsStatus,'Reservation Form Signed');
                }
            }
        }
    }
    public static void checkADMFeeDariFeeStatus(Set<Id> salesOrderIdSet){
        Set<Id> salesOrderIdsetADMCollected= new Set<Id>();
        Set<Id> salesOrderIdsetADMPaid= new Set<Id>();
        
        if(!salesOrderIdSet.isEmpty()){
            Set<Id> closeFinanceStep = new Set<Id>();
            List<Invoice__c> invoiceObjLst = [SELECT Id, Name, InvoiceStatus__c, AppliedAmount__c, InvoiceAmount__c,Sales_Order__c,Sales_Order__r.Discount_on_ADM_fee_Amount__c,Sales_Order__r.IsADMCollectedWithWaiverRequest__c,TotalPaidAmount__c FROM Invoice__c WHERE Sales_Order__c =: salesOrderIdSet AND Is_ADM_Fees_and_Dari_charges__c = true AND (NOT Sales_Order__r.Status__c IN ('Voided','Cancelled'))];
            Map<Id,Invoice__c> invoiceMap = new Map<Id,Invoice__c>();
            for(Invoice__c inv: invoiceObjLst){
                invoiceMap.put(inv.Id,inv);
            }
            Map<Id,SalesOrder__c> salesOrderUpdateMap = new Map<Id,SalesOrder__c>();
            if(!invoiceObjLst.isEmpty()){
                 /** 3.0 DP & ADM Buffer Amount Logic **/
                Map<Id,decimal> totalPaidAmountMap = new Map<Id,decimal>();
                for(AggregateResult alloc:[SELECT SUM(ApprovedReceiptAmount__c) TOTALAMT,Invoice__c INV FROM Allocation__c  WHERE Invoice__c IN: invoiceMap.keySet() AND Status__c ='Applied' AND ApprovedReceiptAmount__c <> null GROUP BY Invoice__c]){
                    totalPaidAmountMap.put((Id) alloc.get('INV'), (Decimal) alloc.get('TOTALAMT'));
                }
                /**
                 * Arvind Kesharwani - 22 Sep 2026 : V7.0 - ADM + Dari 'Paid' is now driven
                 * by the OUTSTANDING AMOUNT on the invoice, not by the receipt-driven
                 * Invoice.InvoiceStatus__c.
                 * Remaining = InvoiceAmount__c - SUM(Applied Allocation.ApprovedReceiptAmount__c).
                 * When Remaining is LESS THAN OR EQUAL TO Label.ADMBufferAmount (100), the ADM +
                 * Dari fee is treated as fully Paid and the Finance step is closed, whatever the
                 * invoice status says. Remaining ABOVE 100 stays 'Partially Paid'.
                 */
                Decimal admBufferAmount = parseBufferAmount(System.Label.ADMBufferAmount);
                for(Invoice__c invObj: invoiceObjLst){
                    /** Arvind Kesharwani - 22 Sep 2026 : V7.0 - outstanding-amount driven Paid evaluation **/
                    Decimal admTotalPaidAmount = (totalPaidAmountMap.containsKey(invObj.Id) && totalPaidAmountMap.get(invObj.Id) <> null)
                                                  ? totalPaidAmountMap.get(invObj.Id) : 0;
                    Decimal admInvoiceAmount   = invObj.InvoiceAmount__c <> null ? invObj.InvoiceAmount__c : 0;
                    Decimal admRemainingAmount = admInvoiceAmount - admTotalPaidAmount;
                    // Cancelled invoices are never promoted; a zero-paid invoice is never promoted
                    // even when its own amount happens to sit below the buffer.
                    Boolean isADMPaidWithinBuffer = invObj.InvoiceStatus__c != 'Cancelled'
                                                    && admTotalPaidAmount > 0
                                                    && admRemainingAmount <= admBufferAmount;
                    /** Arvind Kesharwani - 22 Sep 2026 : V7.0 - 'Paid' now also reached when the
                     *  remaining amount is below the buffer **/
                    if(invObj.InvoiceStatus__c == 'Paid' || isADMPaidWithinBuffer){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrder.ADM_Fees_and_Dari__c = 'Paid';
                        salesOrder.ADM_Fees_Dari_charges_Reversal_Reason__c = '';
                        salesOrder.ADM_Fees_Dari_charges_Cleared_Date__c = System.today();
                        salesOrder.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                        salesOrderIdsetADMPaid.add(salesOrder.Id);
                        closeFinanceStep.add(salesOrder.Id);
                       // salesOrderIdsetADMCollected.add(salesOrder.Id);
                    }else if(invObj.InvoiceStatus__c == 'Partially Paid'){
                        /** Arvind Kesharwani - 22 Sep 2026 : V7.0 - the buffer promotion that used
                         *  to live here is handled by isADMPaidWithinBuffer above, so this branch is
                         *  now reached only when the outstanding amount is still at or above the buffer. **/
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrder.ADM_Fees_and_Dari__c = 'Partially Paid';
                        salesOrder.ADM_Fees_Dari_charges_Reversal_Reason__c = '';
                        salesOrder.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                        //salesOrderIdsetADMCollected.add(salesOrder.Id);
                    }else if(invObj.InvoiceStatus__c == 'Cancelled'){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrder.ADM_Fees_and_Dari__c = 'Cancelled';
                        salesOrder.ADM_Fees_Dari_charges_Reversal_Reason__c = '';
                        salesOrder.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                    }else if((invObj.AppliedAmount__c + (Decimal.valueOf(System.label.ADMBufferAmount))) >= invObj.InvoiceAmount__c){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrder.ADM_Fees_and_Dari__c = 'Collected';
                        salesOrder.ADM_Dari_Fee_Collected_Date__c = System.today();
                        salesOrder.ADM_Fees_Dari_charges_Reversal_Reason__c = '';
                        salesOrder.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                         salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                       // salesOrderIdsetADMCollected.add(salesOrder.Id);
                    }else if(invObj.AppliedAmount__c > 0 && (invObj.AppliedAmount__c + (Decimal.valueOf(System.label.ADMBufferAmount))) < invObj.InvoiceAmount__c){
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrder.ADM_Fees_and_Dari__c = 'Partially Collected';
                        salesOrder.ADM_Fees_Dari_charges_Reversal_Reason__c = '';
                        salesOrder.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                         /**3.0 DP & ADM Payment Buffer Amount Added & Considered to Make Status to Paid & Collected**/
                        if(invObj.AppliedAmount__c + (Decimal.valueOf(System.label.ADMBufferAmount)) >= invObj.InvoiceAmount__c){
                          	salesOrder.ADM_Fees_and_Dari__c = 'Collected';
                            salesOrder.ADM_Dari_Fee_Collected_Date__c = System.today();
                        }
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                        //salesOrderIdsetADMCollected.add(salesOrder.Id);
                    }else{
                        SalesOrder__c salesOrder = new SalesOrder__c();
                        salesOrder.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrder.ADM_Fees_and_Dari__c = 'Generated';
                        salesOrder.ADM_Fees_Dari_charges_Reversal_Reason__c = '';
                        salesOrder.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        salesOrderUpdateMap.put(salesOrder.Id,salesOrder);
                    }
                    List<SalesOrder__c> admCheckUpdate = new List<SalesOrder__c>();
                    if(invoiceMap.get(invObj.Id).Sales_Order__r.IsADMCollectedWithWaiverRequest__c == false && ((invoiceMap.get(invObj.Id).Sales_Order__r.Discount_on_ADM_fee_Amount__c + invObj.AppliedAmount__c) > 0 && (invoiceMap.get(invObj.Id).Sales_Order__r.Discount_on_ADM_fee_Amount__c + invObj.AppliedAmount__c + (Decimal.valueOf(System.label.ADMBufferAmount))) >= invObj.InvoiceAmount__c)){
                        salesOrderIdsetADMCollected.add(invoiceMap.get(invObj.Id).Sales_Order__c);
                        SalesOrder__c salesOrderAdmCheck = new SalesOrder__c();
						salesOrderAdmCheck.Id = invoiceMap.get(invObj.Id).Sales_Order__c;
                        salesOrderAdmCheck.IsADMCollectedWithWaiverRequest__c = true;
                        admCheckUpdate.add(salesOrderAdmCheck);
                    }
                    if(invoiceMap.get(invObj.Id).Sales_Order__r.IsADMCollectedWithWaiverRequest__c == true && !salesOrderIdsetADMCollected.contains(invoiceMap.get(invObj.Id).Sales_Order__c) ){
                       salesOrderIdsetADMCollected.add(invoiceMap.get(invObj.Id).Sales_Order__c); 
                    } 
                    if(!admCheckUpdate.isEmpty()){
                        update admCheckUpdate;
                    }
                }
                if(!salesOrderIdsetADMCollected.isEmpty()){
                        closingTheStatus(salesOrderIdsetADMCollected,'ADM + Dari Fee Collected');
                    }
                if(!salesOrderUpdateMap.values().isEmpty()){
                    update salesOrderUpdateMap.values();
                    /** 3.0 Automate the finance step closing Logic **/
                    if(!closeFinanceStep.isEmpty()){
                        closeFinaceVerificationStep(closeFinanceStep);
                    }
                } 
            } 
        }
    }
    public static void checkSPAStatus(Set<Id> salesOrderIdSet){
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c,SalesOrder__r.SPAStatus__c FROM Documents__c WHERE SalesOrder__c =: salesOrderIdSet AND Name LIKE '%SPA%' AND (NOT SalesOrder__r.Status__c IN ('Voided','Cancelled')) ORDER BY Name];
        if(!salesOrderDocs.isEmpty()){
            Set<Id> spaStsstepCloseId = new Set<Id>();
            Set<Id> spaSignedCustomerStsstepCloseId = new Set<Id>();
            Set<Id> spaSignedMODONStsstepCloseId = new Set<Id>();
            Map<Id,String> spaStatusMap = new Map<Id,String>();
            List<String> spaStatus = new List<String>{'SPA Generated','Pending with Customer'};
            List<String> customerSpaStatus = new List<String>{'Pending for Validation','Pending with Modon'};
            List<String> modonSpaStatus = new List<String>{'SPA Signed (Modon)'};
            for(SalesOrder__c soObj: [SELECT Id,SPAStatus__c FROM SalesOrder__c WHERE Id IN:salesOrderIdSet]){
                spaStatusMap.put(soObj.Id,soObj.SPAStatus__c);
            }
            Map<Id,List<Documents__c>> spaDocMap = new Map<Id,List<Documents__c>>();
            for(Documents__c doc:salesOrderDocs){
                if(spaDocMap.containsKey(doc.SalesOrder__c)){
                    spaDocMap.get(doc.SalesOrder__c).add(doc);
                }else{
                    spaDocMap.put(doc.SalesOrder__c,new List<Documents__c>{doc});
                }
            }
            System.debug('spaDocMap::'+spaDocMap);
            Map<Id,SalesOrder__c> soUpdateMap = new Map<Id,SalesOrder__c>();
            for(Id soId: spaDocMap.keySet()){
                for(Documents__c doc:spaDocMap.get(soId)){
                    System.debug('docName:'+doc.Name);
                    if((doc.Name == 'Signed SPA (Modon)' && doc.Status__c == 'Uploaded') || (spaStatusMap.containsKey(soId) && spaStatusMap.get(soId) != null && modonSpaStatus.contains(spaStatusMap.get(soId))) ){
                        spaSignedMODONStsstepCloseId.add(soId);
                    }
                    if((doc.Name == 'Signed SPA (Customer)' && doc.Status__c == 'Uploaded') || (spaStatusMap.containsKey(soId) && spaStatusMap.get(soId) != null && (customerSpaStatus.contains(spaStatusMap.get(soId)) ||  modonSpaStatus.contains(spaStatusMap.get(soId))))){
                        spaSignedCustomerStsstepCloseId.add(soId);
                    }
                    if((doc.Name == 'SPA' && doc.Status__c == 'Uploaded') || (spaStatusMap.containsKey(soId) && spaStatusMap.get(soId) != null && (spaStatus.contains(spaStatusMap.get(soId))||customerSpaStatus.contains(spaStatusMap.get(soId)) ||modonSpaStatus.contains(spaStatusMap.get(soId)) ))){
                        spaStsstepCloseId.add(soId);
                    }
                    System.debug('spaStsstepCloseId:'+spaStsstepCloseId);
                }
            }
            List<SalesOrder__c> soSPADateUpdate = new List<SalesOrder__c>();
            if(!spaStsstepCloseId.isEmpty()){
                soSPADateUpdate.clear();
                closingTheStatus(spaStsstepCloseId,'SPA In-Progress');
                closingTheStatus(spaStsstepCloseId,'SPA In Progress');
                for(SalesOrder__c so:[SELECT Id,SPAStatus__c FROM SalesOrder__c WHERE Id IN: spaStsstepCloseId AND SPAStatus__c !='SPA Generated']){
                    SalesOrder__c soUpd = new SalesOrder__c();
                    soUpd.Id = so.id;
                    soUpd.SPAStatus__c = 'SPA Generated';
                    soSPADateUpdate.add(soUpd);
                }
            }
            if(!spaSignedCustomerStsstepCloseId.isEmpty()){
                soSPADateUpdate.clear();
                closingTheStatus(spaSignedCustomerStsstepCloseId,'Signed SPA (Customer)'); 
                closingTheStatus(spaSignedCustomerStsstepCloseId,'SPA Signed (Customer)');
                for(SalesOrder__c so:[SELECT Id FROM SalesOrder__c WHERE Id IN: spaStsstepCloseId AND SPAStatus__c !='Pending for Validation']){
                    SalesOrder__c soUpd = new SalesOrder__c();
                    soUpd.Id = so.id;
                    soUpd.SPAStatus__c = 'Pending for Validation';
                    soUpd.SPACustomerSignedDate__c = System.today();
                    soSPADateUpdate.add(soUpd);
                }
            }
            if(!spaSignedMODONStsstepCloseId.isEmpty()){
                soSPADateUpdate.clear();
                closingTheStatus(spaSignedMODONStsstepCloseId,'Signed SPA (Modon)'); 
                for(SalesOrder__c so:[SELECT Id,ADM_Fees_and_Dari__c,Down_Payment_Status__c FROM SalesOrder__c WHERE Id IN: spaStsstepCloseId AND SPAStatus__c !='SPA Signed (Modon)']){
                    SalesOrder__c soUpd = new SalesOrder__c();
                    soUpd.Id = so.id;
                    soUpd.SPAStatus__c = 'SPA Signed (Modon)';
                    soUpd.SPACounterSignedDate__c = System.today();
                     /** 3.0 Closing the Sales Order After MODON Signed the SPA **/
                    if(so.ADM_Fees_and_Dari__c == 'Paid' && so.Down_Payment_Status__c == 'Paid'){
                        soUpd.Status__c = 'Completed';
                        soUpd.Sub_Status__c = 'Completed';
                    }
                    soSPADateUpdate.add(soUpd);
                }
            }
            if(!soSPADateUpdate.isEmpty()){
                update soSPADateUpdate;
                //start added logic v4.1 by sireesha for ADM creation 
                Set<Id> completedSOIds = new Set<Id>();
                
                for (SalesOrder__c so : soSPADateUpdate) {
                    if (so.Status__c == 'Completed') {
                        completedSOIds.add(so.Id);
                    }
                }
                
                if (!completedSOIds.isEmpty()) {
                    List<SalesOrder__c> admSOList = [
                        SELECT Id,
                        Unit_Name__c,
                        CustomerAccount__c,
                        Unit__c,
                        Opportunity__c,
                        Status__c,
                        is_Transferred_SO__c
                        FROM SalesOrder__c
                        WHERE Id IN :completedSOIds
                        AND Status__c = 'Completed'
                        AND is_Transferred_SO__c = false
                    ];
                    
                    if (!admSOList.isEmpty()) {
                        ADMSRService.createADMServiceRequests(admSOList);
                    }
                }//v4.1 end
            }
            
        }
    }
    public static void updateMOPfromPayment(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> receiptIdset = new Set<Id>();
        for(Receipt__c rec:(List<Receipt__c>) newList){
            if(rec.Modeofpayment__c <> null && rec.Modeofpayment__c <> ((Receipt__c)oldMap.get(rec.Id)).Modeofpayment__c){
                receiptIdset.add(rec.id);
            }
        }
        if(!receiptIdset.isEmpty()){
            Set<Id> invoiceIdset = new Set<Id>();
            for(Allocation__c alloc:[SELECT Id,Receipt__c,Receipt__r.ModeOfPayment__c,Invoice__c,Receipt__r.Is_PDC__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c FROM Allocation__c WHERE Receipt__c IN: receiptIdset AND ( NOT Receipt__r.Status__c IN ('Reversed','Cancelled','Rejected')) AND Invoice__r.SalesOrderInstallment__c != null AND Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Resale__c = false]){
                invoiceIdset.add(alloc.Invoice__c);
            }
            if(!invoiceIdset.isEmpty()){
                updateModeOfPayment(invoiceIdset);
            }
        }
    }
    public static void updateMOPfromAllocation(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> allocIdset = new Set<Id>();
        for(Allocation__c alloc: (List<Allocation__c>)newList){
            Allocation__c oldData = oldMap <> null ? (Allocation__c)oldMap.get(alloc.Id) : null;
            if(alloc.Invoice__c <> null && alloc.Receipt__c <> null && (oldMap == null ||(oldMap <> null && (oldData.Invoice__c <> alloc.Invoice__c || oldData.Receipt__c <> alloc.Receipt__c)))){
                allocIdset.add(alloc.Invoice__c);
            }
        }
        if(!allocIdset.isEmpty()){
            Set<Id> invoiceIdset = new Set<Id>();
            for(Allocation__c alloc:[SELECT Id,Receipt__c,Receipt__r.ModeOfPayment__c,Invoice__c,
                                     Receipt__r.Is_PDC__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c 
                                     FROM Allocation__c 
                                     WHERE Id IN: allocIdset AND ( NOT Receipt__r.Status__c IN ('Reversed','Cancelled','Rejected')) 
                                     AND Invoice__r.SalesOrderInstallment__c != null 
                                     AND  Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Resale__c = false
                                     AND Receipt__r.ModeOfPayment__c != 'Credit Note']){
                                         invoiceIdset.add(alloc.Invoice__c);
                                     }
            if(!invoiceIdset.isEmpty()){
                updateModeOfPayment(invoiceIdset);
            }
        }
    }
    public static void updateModeOfPayment(Set<Id> invoiceIdset){
        Set<Id> soIdset = new Set<Id>();
        Map<Id,Set<String>> invoiceMOPmap = new Map<Id,Set<String>>();
        for(Allocation__c alloc:[SELECT Id,Receipt__c,Receipt__r.ModeOfPayment__c,Invoice__c,Receipt__r.Is_PDC__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c FROM Allocation__c WHERE Invoice__c IN: invoiceIdset AND ( NOT Receipt__r.Status__c IN ('Reversed','Cancelled','Rejected')) AND Invoice__r.SalesOrderInstallment__c != null AND  Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Resale__c = false]){
            soIdset.add(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c);
            String modeOfpayment = alloc.Receipt__r.Is_PDC__c == true ? 'PDC' : alloc.Receipt__r.ModeOfPayment__c;
            if(!invoiceMOPmap.containsKey(alloc.Invoice__c)){
                invoiceMOPmap.put(alloc.Invoice__c,new Set<String>{modeOfpayment});
            }else{
                invoiceMOPmap.get(alloc.Invoice__c).add(modeOfpayment);
            }
        }
        if(!invoiceMOPmap.isEmpty()){
            List<Invoice__c> invoiceList= new List<Invoice__c>();
            for(Id invoiceId: invoiceMOPmap.keySet()){
                Set<String> vals = invoiceMOPmap.get(invoiceId);
                List<String> listVals = new List<String>(vals);
                
                Invoice__c invoice = new Invoice__c();
                invoice.Id = invoiceId;
                invoice.ModeOfPayment__c = String.join(listVals, ';');
                invoiceList.add(invoice);
            }
            if(!invoiceList.isEmpty()){
                update invoiceList;
                Map<Id,String> soMapModeOfPayment = new Map<Id,String>();
                for(Invoice__c inv:[SELECT Id,SalesOrderInstallment__r.SalesOrder__c,Modeofpayment__c FROM Invoice__c WHERE Id IN: invoiceMOPmap.keySet()]){
                    if(soMapModeOfPayment.containsKey(inv.SalesOrderInstallment__r.SalesOrder__c)){
                        String mopString = soMapModeOfPayment.get(inv.SalesOrderInstallment__r.SalesOrder__c)+';'+inv.Modeofpayment__c;
                        soMapModeOfPayment.put(inv.SalesOrderInstallment__r.SalesOrder__c,mopString);
                    }else{
                        soMapModeOfPayment.put(inv.SalesOrderInstallment__r.SalesOrder__c,inv.Modeofpayment__c);  
                    }
                }
                if(!soMapModeOfPayment.values().isEmpty()){
                    List<SalesOrder__c> soList = new List<SalesOrder__c>();
                    for(Id soId: soMapModeOfPayment.keySet()){
                        SalesOrder__c so = new SalesOrder__c();
                        so.Id = soId;
                        so.Modeofpayment__c = soMapModeOfPayment.get(soId);
                        soList.add(so);
                    }
                    if(!soList.isEmpty()){
                        update soList;
                    }
                }
            }
        }
    }
    /*
public static void saleorderStatusApprovals(List<sObject> newList,Map<Id, sObject> oldMap){
Set<Id> salesOrderApprovalIdSet = new Set<Id>(); 
List<Sales_Order_Status_Approvals__c> salesOrderStsApprvlList = new List<Sales_Order_Status_Approvals__c>();
List<Sales_Order_Status_Approvals__c> newSalesOrderStsApprvlList = new List<Sales_Order_Status_Approvals__c>();
Map<String,Sales_Order_Sub_Status_Meta_Data__mdt> statusMetaDataMap = new Map<String,Sales_Order_Sub_Status_Meta_Data__mdt>();
Map<String,Sales_Order_Sub_Status_Meta_Data__mdt> approvalDataMap = new Map<String,Sales_Order_Sub_Status_Meta_Data__mdt>();
Set<Id> soStsIdset = new Set<Id>();
for(Sales_Order_Sub_Status_Meta_Data__mdt soMdt:[SELECT Current_Sub_Status__c, Sales_Order_Status__c, Next_Sub_Status__c,Approval_Status__c,Alert_Message__c FROM Sales_Order_Sub_Status_Meta_Data__mdt]){
statusMetaDataMap.put(soMdt.Current_Sub_Status__c+soMdt.Approval_Status__c,soMdt);
approvalDataMap.put(soMdt.Current_Sub_Status__c,soMdt);
}         
for(Sales_Order_Status_Approvals__c record : (List<Sales_Order_Status_Approvals__c>)newList){
Sales_Order_Status_Approvals__c oldRecord = (Sales_Order_Status_Approvals__c) oldMap.get(record.Id);
if(record.Approval_Status__c <> null && record.Approval_Status__c <> oldRecord.Approval_Status__c && (record.Approval_Status__c == 'Approved' || record.Approval_Status__c == 'Rejected')){
Sales_Order_Status_Approvals__c soApp = new Sales_Order_Status_Approvals__c();
soApp.Id = record.Id;
soApp.Approve_Rejected_By__c = UserInfo.getUserId();
soApp.Approval_Rejected_Date__c = DateTime.now();
salesOrderStsApprvlList.add(soApp);
System.debug('statusMetaDataMap:'+record.Current_Sub_Status__c+record.Approval_Status__c+' output:'+statusMetaDataMap.containsKey(record.Current_Sub_Status__c+record.Approval_Status__c));
if(statusMetaDataMap.containsKey(record.Current_Sub_Status__c+record.Approval_Status__c) && statusMetaDataMap.get(record.Current_Sub_Status__c+record.Approval_Status__c).Next_Sub_Status__c <> null){
Sales_Order_Sub_Status_Meta_Data__mdt mdtData = approvalDataMap.get(statusMetaDataMap.get(record.Current_Sub_Status__c+record.Approval_Status__c).Next_Sub_Status__c);
if(mdtData <> null){
Sales_Order_Status_Approvals__c soAppNew = new Sales_Order_Status_Approvals__c();
soAppNew.Sales_Order__c = record.Sales_Order__c;
soAppNew.Approval_Status__c = 'Pending';
soAppNew.Alert_Message__c = mdtData.Alert_Message__c;
soAppNew.Current_Sub_Status__c = mdtData.Current_Sub_Status__c;
soAppNew.Next_Sub_Status__c = mdtData.Next_Sub_Status__c;
soAppNew.Sales_Order_Status__c = mdtData.Sales_Order_Status__c;
soAppNew.Submitted_Date__c = DateTime.now();
newSalesOrderStsApprvlList.add(soAppNew);

}
}
}
}
if(!salesOrderStsApprvlList.isEmpty()){
update salesOrderStsApprvlList;
for(Sales_Order_Status_Approvals__c newSoa: salesOrderStsApprvlList){
salesOrderApprovalIdSet.add(newSoa.Id);
}
updateSOSubStatus(salesOrderApprovalIdSet);
}
if(!newSalesOrderStsApprvlList.isEmpty()){
Set<Id> pendingWithStsId = new Set<Id>();
insert newSalesOrderStsApprvlList;
Set<Id> brokerStsId = new Set<Id>();
for(Sales_Order_Status_Approvals__c soa: newSalesOrderStsApprvlList){
if(soa.Current_Sub_Status__c == 'Reservation Form Generated' || soa.Current_Sub_Status__c == 'Reservation Form Signed'){
soStsIdset.add(soa.Id);
}
if(soa.Current_Sub_Status__c == 'Broker Form Generated' || soa.Current_Sub_Status__c == 'Broker Form Signed'){
brokerStsId.add(soa.Id);
}
if(soa.Current_Sub_Status__c == 'Pending with Sales' || soa.Current_Sub_Status__c == 'Pending With Sales Team' || soa.Current_Sub_Status__c == 'Pending With Sales Operation' || soa.Current_Sub_Status__c == 'Completed' ||  soa.Current_Sub_Status__c == 'Document Checklist Verified By - Customer Management' || soa.Current_Sub_Status__c == 'Pending with CM' || soa.Current_Sub_Status__c == 'Under Finance Verification'){
pendingWithStsId.add(soa.Id);
}
}
if(!soStsIdset.isEmpty()){
skipReservationStatus(soStsIdset);
}
if(!pendingWithStsId.isEmpty()){
skipPendingWithStatus(pendingWithStsId);
}
if(!brokerStsId.isEmpty()){
skipBrokerFormStatus(brokerStsId);
}
}
} 
public static void skipPendingWithStatus(Set<Id> soStsIdset){
List<Sales_Order_Status_Approvals__c> soaListUpdate = new List<Sales_Order_Status_Approvals__c>();
for(Sales_Order_Status_Approvals__c soa:[SELECT Id,Sales_Order__c,Sales_Order__r.Is_Reservation_Form_Required__c,Current_Sub_Status__c FROM Sales_Order_Status_Approvals__c WHERE ID IN:soStsIdset]){
Sales_Order_Status_Approvals__c soaObj = new Sales_Order_Status_Approvals__c();
soaObj.Id =  soa.id;
soaObj.Approval_Status__c = 'Approved';
soaObj.Comments__c = soa.Current_Sub_Status__c+' Closing this step to update in Sales Order';
soaObj.Completed_Date__c = System.today();
soaListUpdate.add(soaObj);
}
if(!soaListUpdate.isEmpty()){
update soaListUpdate;
}
}
public static void skipReservationStatus(Set<Id> soStsIdset){

if(!soStsIdset.isEmpty()){
List<Sales_Order_Status_Approvals__c> soaListUpdate = new List<Sales_Order_Status_Approvals__c>();
for(Sales_Order_Status_Approvals__c soa:[SELECT Id,Sales_Order__c,Sales_Order__r.Is_Reservation_Form_Required__c FROM Sales_Order_Status_Approvals__c WHERE ID IN:soStsIdset]){
if(soa.Sales_Order__r.Is_Reservation_Form_Required__c == 'No'){
Sales_Order_Status_Approvals__c soaObj = new Sales_Order_Status_Approvals__c();
soaObj.Id =  soa.id;
soaObj.Approval_Status__c = 'Approved';
soaObj.Comments__c = 'Reservation Form Not Required';
soaObj.Completed_Date__c = System.today();
soaListUpdate.add(soaObj);
}
}
if(!soaListUpdate.isEmpty()){
update soaListUpdate;
}
}
}
public static void skipBrokerFormStatus(Set<Id> soStsIdset){

if(!soStsIdset.isEmpty()){
List<Sales_Order_Status_Approvals__c> soaListUpdate = new List<Sales_Order_Status_Approvals__c>();
for(Sales_Order_Status_Approvals__c soa:[SELECT Id,Sales_Order__c,Sales_Order__r.Is_Reservation_Form_Required__c,Sales_Order__r.opportunity__r.BrokerAgency__c FROM Sales_Order_Status_Approvals__c WHERE ID IN:soStsIdset]){
if(soa.Sales_Order__r.opportunity__r.BrokerAgency__c == null){
Sales_Order_Status_Approvals__c soaObj = new Sales_Order_Status_Approvals__c();
soaObj.Id =  soa.id;
soaObj.Approval_Status__c = 'Approved';
soaObj.Comments__c = 'Broker Form Not Required';
soaObj.Completed_Date__c = System.today();
soaListUpdate.add(soaObj);
}
}
if(!soaListUpdate.isEmpty()){
update soaListUpdate;
}
}
}
public static void autoStatusClosure(List<sObject> soAppList){
Set<Id> salesOrderIdsetDownPayment = new Set<Id>();
Set<Id> salesOrderIdsetADMPayment = new Set<Id>();
Set<Id> IsReservationFormGeneratedStep = new Set<Id>();
Set<Id> IsReservationFormSignedStep = new Set<Id>();
Set<Id> IsBrokerFormGeneratedStep = new Set<Id>();
Set<Id> IsBrokerFormSignedStep = new Set<Id>();
for(Sales_Order_Status_Approvals__c soa: (List<Sales_Order_Status_Approvals__c>)soAppList){
if(soa.Approval_Status__c == 'Pending'){
if(soa.Current_Sub_Status__c == 'Down Payment Collected'){
salesOrderIdsetDownPayment.add(soa.Sales_Order__c); 
}
if(soa.Current_Sub_Status__c == 'ADM + Dari Fee Collected'){
salesOrderIdsetADMPayment.add(soa.Sales_Order__c); 
}
if(soa.Current_Sub_Status__c == 'Reservation Form Generated'){
IsReservationFormGeneratedStep.add(soa.Sales_Order__c); 
}
if(soa.Current_Sub_Status__c == 'Reservation Form Signed'){
IsReservationFormSignedStep.add(soa.Sales_Order__c); 
}
if(soa.Current_Sub_Status__c == 'Broker Form Generated'){
IsBrokerFormGeneratedStep.add(soa.Sales_Order__c); 
}
if(soa.Current_Sub_Status__c == 'Broker Form Signed'){
IsBrokerFormSignedStep.add(soa.Sales_Order__c); 
}
}
}
if(!salesOrderIdsetDownPayment.isEmpty()){
checkDownPaymentStatus(salesOrderIdsetDownPayment);
}
if(!salesOrderIdsetADMPayment.isEmpty()){
checkADMFeeDariFeeStatus(salesOrderIdsetADMPayment);
}
if(!IsReservationFormGeneratedStep.isEmpty()){
skipReservationStatus(IsReservationFormGeneratedStep);
}
if(!IsReservationFormSignedStep.isEmpty()){
skipReservationStatus(IsReservationFormSignedStep);
}
if(!IsBrokerFormGeneratedStep.isEmpty()){
skipBrokerFormStatus(IsBrokerFormGeneratedStep);
}
if(!IsBrokerFormSignedStep.isEmpty()){
skipBrokerFormStatus(IsBrokerFormSignedStep);
}
} */
    public static void closingTheStatus(Set<Id> salesOrderIdsettoClsStatus,String currentSts){
        Map<Id,Sales_Order_Status_Approvals__c> soApprovalStsUpdateMap = new Map<Id,Sales_Order_Status_Approvals__c>();
        if(!salesOrderIdsettoClsStatus.isEmpty()){
            for(Sales_Order_Status_Approvals__c so:[SELECT Id FROM Sales_Order_Status_Approvals__c WHERE Sales_Order__c IN:salesOrderIdsettoClsStatus AND Current_Sub_Status__c =: currentSts AND Approval_Status__c = 'Pending']){
                Sales_Order_Status_Approvals__c soUpd = new Sales_Order_Status_Approvals__c();
                soUpd.Id = so.Id;
                soUpd.Approval_Status__c = 'Approved';
                soApprovalStsUpdateMap.put(soUpd.Id,soUpd);
            }
            if(!soApprovalStsUpdateMap.values().isEmpty()){
                update soApprovalStsUpdateMap.values();
            }
        }
    }

    // 5.1 - FIX - Arvind - 06 Jun 2026
    // OVERLOAD: ADMWaiverController, DocuSignRecipientStatusTriggerHelper and
    // AllocationTriggerHandler call closingTheStatus with List<String> instead of String.
    // Adding this overload avoids touching those 3 dependent classes.
    // Delegates to the original String method for each status in the list.
    // Zero logic change to the original method above.
    public static void closingTheStatus(Set<Id> salesOrderIdsettoClsStatus, List<String> currentStsList){
        if(salesOrderIdsettoClsStatus == null || salesOrderIdsettoClsStatus.isEmpty()) return;
        if(currentStsList == null || currentStsList.isEmpty()) return;
        for(String sts : currentStsList){
            closingTheStatus(salesOrderIdsettoClsStatus, sts);
        }
    } 
    public static void handlePDCStatusAllocation(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> receiptIdset = new Set<Id>();
        for(Allocation__c alloc: (List<Allocation__c>)newList){
            Allocation__c oldRecord = (Allocation__c) oldMap.get(alloc.Id);
            if(oldRecord == null ||(alloc.Receipt__c <> oldRecord.Receipt__c)){
                receiptIdset.add(alloc.Receipt__c);
            }
        }
        if(!receiptIdset.isEmpty()){
            updatePDCStatus(receiptIdset);
        }
    }
    public static void handlePDCStatusReceipt(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> receiptIdset = new Set<Id>();
        for(Receipt__c rec: (List<Receipt__c>)newList){
            Receipt__c oldRecord = oldMap <> null ? (Receipt__c) oldMap.get(rec.Id) : null;
            if(rec.Instrument_Received_Date__c <> null && rec.ChequeDate__c <> null && (oldRecord == null || (oldRecord <> null && (oldRecord.Instrument_Received_Date__c <> rec.Instrument_Received_Date__c || oldRecord.ChequeDate__c <> rec.ChequeDate__c || rec.Modeofpayment__c <> oldRecord.Modeofpayment__c)))){
                receiptIdset.add(rec.Id);
            }
        }
        if(!receiptIdset.isEmpty()){
            updatePDCStatus(receiptIdset);
        }
    }
    public static void updatePDCStatus(Set<Id> receiptIdset){
        Set<Id> soIdset = new Set<Id>();
        Set<Id> invoiceIdset = new Set<Id>();
        Map<Id,decimal> soTotalAmt = new Map<Id,decimal>();
        for(Allocation__c alloc:[SELECT Id,Invoice__c,Invoice__r.Sales_Order__c,
                                 Invoice__r.SalesOrderInstallment__r.SalesOrder__c,Receipt__c,
                                 Invoice__r.SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c,
                                 Invoice__r.InvoiceAmount__c,Invoice__r.AppliedAmount__c 
                                 FROM Allocation__c WHERE Receipt__c IN: receiptIdset AND Invoice__r.SalesOrderInstallment__c <> null 
                                 AND Invoice__r.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c !='Non-Resident' 
                                 AND  Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Resale__c = false 
                                 AND Invoice__r.SalesOrderInstallment__r.MilestoneNumber__c !=1 
                                 AND ( NOT Invoice__r.SalesOrderInstallment__r.MilestoneDescription__c LIKE '%handover%')]){// AND Invoice__r.SalesOrderInstallment__r.MilestoneNumber__c !=1
            if(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c <> null && alloc.Invoice__r.InvoiceAmount__c <= alloc.Invoice__r.AppliedAmount__c){
                soIdset.add(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c); 
                soTotalAmt.put(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c,alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c);
                invoiceIdset.add(alloc.Invoice__c);
            }
        }
        Map<Id,decimal> pdcCount = new Map<Id,decimal>();
        Map<Id,Set<Id>> pdcReceiptMap = new Map<Id,Set<Id>>();
        if(!soIdset.isEmpty()){
            for(Allocation__c alloc:[SELECT Id,Invoice__c,Invoice__r.Sales_Order__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c,Receipt__c FROM Allocation__c WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN:soIdset AND Receipt__r.Is_PDC__c = true AND Invoice__r.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c !='Non-Resident' AND  Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Resale__c = false AND Invoice__r.SalesOrderInstallment__r.MilestoneNumber__c !=1 AND ( NOT Invoice__r.SalesOrderInstallment__r.MilestoneDescription__c LIKE '%handover%')]){ //AND Invoice__r.SalesOrderInstallment__r.MilestoneNumber__c !=1
                if(alloc.Invoice__r.SalesOrderInstallment__c <> null && alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c <> null && pdcReceiptMap.containsKey(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c)){
                    pdcReceiptMap.get(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c).add(alloc.Receipt__c);  
                }else if(alloc.Invoice__r.SalesOrderInstallment__c <> null && alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c <> null){
                    pdcReceiptMap.put(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c,new Set<Id>{alloc.Receipt__c}); 
                }
            }
            Map<Id,decimal> soNoOfInstallment = new Map<Id,decimal>();
            Map<Id,decimal> totalPDCAmountMap = new Map<Id,decimal>();
            for(SalesOrder__c soObj:[SELECT Id,NoOfInstallment__c,TotalPDCAmount__c FROM SalesOrder__c WHERE Id IN:soIdset ]){
                soNoOfInstallment.put(soObj.Id,soObj.NoOfInstallment__c > 0 ? soObj.NoOfInstallment__c - 1 : soObj.NoOfInstallment__c);
                totalPDCAmountMap.put(soObj.Id,soObj.TotalPDCAmount__c);
            }
            Map<Id,decimal> overAllPDCAmount = new Map<Id,Decimal>();
            List<Id> invoiceIdList = new List<Id>();
            for(AggregateResult agg: [SELECT SUM(AllocationAmount__c) SUMVAL,Invoice__r.SalesOrderInstallment__r.SalesOrder__c SOID FROM Allocation__c WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN:soIdset AND Receipt__r.Is_PDC__c = true AND Invoice__r.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c !='Non-Resident' AND  Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Resale__c = false AND Invoice__r.SalesOrderInstallment__r.MilestoneNumber__c !=1 AND ( NOT Invoice__r.SalesOrderInstallment__r.MilestoneDescription__c LIKE '%handover%') GROUP BY Invoice__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c]){
                if(!overAllPDCAmount.containsKey((Id)agg.get('SOID'))){
                	overAllPDCAmount.put((Id)agg.get('SOID'), (Decimal) agg.get('SUMVAL'));
                   // invoiceIdList.add((Id)agg.get('INV'));
                }else{
                    Decimal overAmt = overAllPDCAmount.get((Id)agg.get('SOID'));
                    overAmt += (Decimal) agg.get('SUMVAL');
                   overAllPDCAmount.put((Id)agg.get('SOID'), overAmt); 
                }
            }
            List<SalesOrder__c> soList = new List<SalesOrder__c>();
            for(Id soId: soIdset){ 
                SalesOrder__c so = new SalesOrder__c();
                so.Id = soId;
                so.No_Of_PDC_Collected__c = pdcReceiptMap.containsKey(soId) ? pdcReceiptMap.get(soId).size():0;
                //so.PDC_Collected__c = (so.No_Of_PDC_Collected__c > 0 && soNoOfInstallment.get(soId) <= so.No_Of_PDC_Collected__c) || (so.No_Of_PDC_Collected__c == soNoOfInstallment.get(soId)) ? 'Yes' : 'No';
                so.Applied_PDC_Amount__c = overAllPDCAmount.containsKey(soId) ? overAllPDCAmount.get(soId) : 0;
                so.PDC_Collected__c = totalPDCAmountMap.containsKey(soId) && so.Applied_PDC_Amount__c >= totalPDCAmountMap.get(soId) ? 'Yes' : 'No';
                system.debug('Applied AMT:'+so.Applied_PDC_Amount__c+' totalPDCAmountMap:'+totalPDCAmountMap.get(soId));
                so.Applied_PDC_Amount_Percent__c = so.Applied_PDC_Amount__c <> null && soTotalAmt.get(soId) <> null ? (so.Applied_PDC_Amount__c / soTotalAmt.get(soId) ) * 100 : 0;
                soList.add(so);
            }
            if(!soList.isEmpty()){
                update soList;
                if(!invoiceIdset.isEmpty()){
                	updateModeOfPayment(invoiceIdset);
                }
            }
        }
    }
    
    public static void closeSLAOnTeamChange(List<SalesOrder__c> newList, Map<Id, SObject> oldMap) {
        List<CaseSLA__c> slaUpdates = new List<CaseSLA__c>();
        
        for (SalesOrder__c so : newList) {
            SalesOrder__c oldSo = (SalesOrder__c) oldMap.get(so.Id);
            if (oldSo == null) continue;
            
            if (so.Sub_Status__c != oldSo.Sub_Status__c) {
                String oldTeam = getTeamFromSubStatus(oldSo.Sub_Status__c);
                String newTeam = getTeamFromSubStatus(so.Sub_Status__c);
                
                if (oldTeam != newTeam) {
                    List<CaseSLA__c> activeSLAs = [
                        SELECT Id, Status__c, EndTime__c
                        FROM CaseSLA__c
                        WHERE SalesOrder__c = :so.Id
                        AND Status__c = 'OnTrack'
                        LIMIT 1
                    ];
                    for (CaseSLA__c sla : activeSLAs) {
                        sla.EndTime__c = System.now();
                        sla.Status__c = 'Resolved';
                        slaUpdates.add(sla);
                    }
                }
            }
        }
        
        if (!slaUpdates.isEmpty()) {
            update slaUpdates;
        }
    }
    
    public static String getTeamFromSubStatus(String subStatus) {
        if (subStatus == null) return null;
        
        if (subStatus == 'Reservation Form Generated' 
            || subStatus == 'Pending with Sales'
            || subStatus == 'Down Payment Collected'
            || subStatus == 'ADM + Dari Fee Collected'
            || subStatus == 'Reservation Form Signed'
            || subStatus == 'Broker Form Generated'
            || subStatus == 'Broker Form Signed'
            || subStatus == 'Pending With Sales Team') return 'Sales';
        
        if (subStatus == 'Pending With Sales Operation'
            || subStatus == 'Document Checklist Verified By - Sales Operation'
            || subStatus == 'SPA In-Progress'
            || subStatus == 'Signed SPA (Customer)') return 'Sales Operation';
        
        if (subStatus == 'Pending with CM'
            || subStatus == 'Document Checklist Verified By - Customer Management'
            || subStatus == 'Signed SPA (Modon)') return 'Customer Management';
        
        return null; 
    }
    public static void validateTheSOChecklistAccount(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> accountIdset = new Set<Id>();
        for(Account acc: (List<Account>) newList){
            Account oldData = (Account) oldMap.get(acc.Id);
            if((acc.PersonEmail <> null && oldData.PersonEmail <> acc.PersonEmail) || (acc.Phone <> null && acc.Phone <> oldData.Phone) || (acc.PersonMobilePhone <> null && acc.PersonMobilePhone <> oldData.PersonMobilePhone) || (acc.EmailID__c <> null && acc.EmailID__c <> oldData.EmailID__c) || (acc.PersonMailingAddress <> null && acc.PersonMailingAddress <> oldData.PersonMailingAddress) ||(acc.PassfortApprovalStatus__pc <> null && acc.PassfortApprovalStatus__pc <> oldData.PassfortApprovalStatus__pc) ||(acc.PassfortApprovalStatus__c <> null && acc.PassfortApprovalStatus__c <> oldData.PassfortApprovalStatus__c)){
                accountIdset.add(acc.Id);
            }
        }
        if(!accountIdset.isEmpty()){
            Set<Id> soIdset = new Set<Id>();
            for(SalesOrder__c so :[SELECT Id FROM SalesOrder__c WHERE Is_Sales_Checklist_Completed__c = false AND Sub_Status__c = 'Pending With Sales' AND CustomerAccount__c IN:accountIdset]){
                soIdset.add(so.Id);
            }
            if(!soIdset.isEmpty()){
                DocumentChecklistCheckboxHelper.handleChecklist(soIdset);
            }
        }
    }
    public static void handleSOCheckBoxHelper(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> soIdset = new Set<Id>();
        for(SalesOrder__c so : (List<SalesOrder__c>) newList){
            SalesOrder__c oldData = (SalesOrder__c)oldMap.get(so.Id);
            if(so.Is_Sales_Checklist_Completed__c == false && so.Sub_Status__c == 'Pending With Sales'){
            	soIdset.add(so.Id);
            }
        }
        if(!soIdset.isEmpty()){
            DocumentChecklistCheckboxHelper.handleChecklist(soIdset);
        }
    }
    public static void handleDocumentUploadAccount(List<sObject> newList, Map<Id,sObject> oldMap){
        List<String> individualDocList = System.label.PassfortIndividualDocNames.contains(',') ? System.label.PassfortIndividualDocNames.split(',') : new list<String>{System.label.PassfortIndividualDocNames}; 
            Set<Id> accountIdset = new Set<Id>();
        for(Documents__c doc:(List<Documents__c>) newList){
            Documents__c oldData = oldMap <> null ?(Documents__c) OldMap.get(doc.Id) : null;
            if(doc.status__c =='Uploaded' && doc.Account__c <> null && individualDocList.contains(doc.Name) && (oldData == null ||(oldData <> null && oldData.status__c <> doc.Status__c))){
                accountIdset.add(doc.Account__c);
            }
        }
        if(!accountIdset.isEmpty()){
            Set<Id> soIdset = new Set<Id>();
            for(SalesOrder__c so :[SELECT Id FROM SalesOrder__c WHERE Is_Sales_Checklist_Completed__c = false AND Sub_Status__c = 'Pending With Sales' AND CustomerAccount__c IN:accountIdset]){
                soIdset.add(so.Id);
            }
            if(!soIdset.isEmpty()){
                DocumentChecklistCheckboxHelper.handleChecklist(soIdset);
            }
        }
    }
    public static void handlePDCCollectedSts(List<sObject> newList,Map<Id,sObject> oldMap){
        Set<Id> contactIdset = new Set<Id>();
        for(SalesOrder__c so: (List<SalesOrder__c>) newList){
            SalesOrder__c oldData = oldMap <> null ? (SalesOrder__c) oldMap.get(so.Id) : null;
            if(so.UAE_Resident_Status__c == 'Non-Resident' && (oldData == null ||(so.UAE_Resident_Status__c <> oldData.UAE_Resident_Status__c))){
               so.PDC_Collected__c = 'Non-Resident';
            }
            else if(oldData <> null && so.ExcludePDCCheck__c == true && oldData.ExcludePDCCheck__c != so.ExcludePDCCheck__c  && so.UAE_Resident_Status__c =='Resident'){
               so.PDC_Collected__c = 'Not Required'; 
            }else if(oldData <> null && so.ExcludePDCCheck__c == false && oldData.ExcludePDCCheck__c != so.ExcludePDCCheck__c && oldData.ExcludePDCCheck__c == true && so.UAE_Resident_Status__c =='Resident'){
               so.PDC_Collected__c = 'No'; 
            }
        }
    }
    public static void updateDDPaymentMethod(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> soIdset = new Set<Id>();
        for(DirectDebitRequest__c dd: (List<DirectDebitRequest__c>) newList){
            if(dd.SalesOrder__c <> null && dd.Status__c != 'Cancelled' && dd.Status__c != 'Rejected'){
                soIdset.add(dd.SalesOrder__c); 
            }
        }
        if(!soIdset.isEmpty()){
            List<SalesOrder__c> soUpdateList = new List<SalesOrder__c>();
            for(Id soId: soIdset){
                SalesOrder__c so = new SalesOrder__c();
                so.Id = soId;
                so.PDC_Collected__c = 'Direct Debit';
                so.Modeofpayment__c = 'Direct Debit';
                soUpdateList.add(so);
            }
            if(!soUpdateList.isEmpty()){
                update soUpdateList;
            }
        }
    }
/*    public static void updateRelavantDocumentsinSO(List<sObject> newList, Map<Id,sObject> oldMap){
        Map<String,String> docNameMap = new Map<String,String>();
        docNameMap.put('Passport','Passport');
        docNameMap.put('Emirates/National ID Front','Emirates ID');
        docNameMap.put('Emirates/National ID Back','Emirates ID');
        docNameMap.put('KYC Form - Signed','Signed KYC and Wealth Form');
        
        Map<Id,Id> primaryContactIdMap = new Map<Id,Id>();
        for(Documents__c doc:(List<Documents__c>) newList){
            Documents__c oldData = oldMap <> null ? (Documents__c)oldMap.get(doc.Id) : null;
            if(doc.Status__c == 'Uploaded' && docNameMap.keySet().contains(doc.Name) && doc.PrimaryContact__c <> null && (oldData == null || (oldData <> null && (doc.Status__c <> oldData.Status__c || doc.PrimaryContact__c <> oldData.PrimaryContact__c)))){
                primaryContactIdMap.put(doc.Id,doc.PrimaryContact__c);
            }
        }
        if(!primaryContactIdMap.values().isEmpty()){
            copyDocumentfromPrimaryContact(primaryContactIdMap);
        }
    }
    @AuraEnabled
    public static String copyDocumentfromPrimaryContactLWC(Id recordId){
        try{
            Map<String,String> docNameMap = new Map<String,String>();
            docNameMap.put('Passport','Passport');
            docNameMap.put('Emirates/National ID Front','Emirates ID');
            docNameMap.put('Emirates/National ID Back','Emirates ID');
            docNameMap.put('KYC Form - Signed','Signed KYC and Wealth Form');
            Id primaryContactId = [SELECT Id,PrimaryContact__c FROM SalesOrder__c WHERE Id=: recordId LIMIT 1].PrimaryContact__c;
            Map<Id,Id> primaryContactIdMap = new Map<Id,Id>();
            for(Documents__c doc:[SELECT Id,PrimaryContact__c FROM Documents__c WHERE PrimaryContact__c =:primaryContactId AND Name IN: docNameMap.keySet()]){
                primaryContactIdMap.put(doc.Id,doc.PrimaryContact__c);
            }
            System.debug('primaryContactIdMap:'+primaryContactIdMap);
            if(!primaryContactIdMap.values().isEmpty()){
                copyDocumentfromPrimaryContact(primaryContactIdMap);
            }
            return 'Success! Files Copied from related "Primary Contact".';
        }catch(Exception ex){
            return 'Error! '+ex.getMessage();
        }
    }
    public static void soDocCreation(List<sObject> newList){
        Map<String,String> docNameMap = new Map<String,String>();
        docNameMap.put('Passport','Passport');
        docNameMap.put('Emirates/National ID Front','Emirates ID');
        docNameMap.put('Emirates/National ID Back','Emirates ID');
        docNameMap.put('KYC Form - Signed','Signed KYC and Wealth Form');
        Map<Id,Id> primaryContactIdMap = new Map<Id,Id>();
        Set<Id> soIdset = new Set<Id>();
        Set<Id> contactIdset = new Set<Id>();
        for(Documents__c doc:(List<Documents__c>) newList){
            if(doc.Status__c != 'Uploaded' && docNameMap.values().contains(doc.Name) && doc.SalesOrder__c <> null ){
                soIdset.add(doc.SalesOrder__c);
            }
        }
        if(!soIdset.isEmpty()){
            for(SalesOrder__c so:[SELECT Id,PrimaryContact__c FROM SalesOrder__c WHERE Id IN:soIdset AND PrimaryContact__c != null AND Status__c != 'Cancelled']){
                contactIdset.add(so.PrimaryContact__c);
            }
            if(!contactIdset.isEmpty()){
                for(Documents__c doc:[SELECT Id,PrimaryContact__c FROM Documents__c WHERE PrimaryContact__c IN:contactIdset AND Name IN: docNameMap.keySet()]){
                    primaryContactIdMap.put(doc.Id,doc.PrimaryContact__c);
                }
                if(!primaryContactIdMap.values().isEmpty()){
                    copyDocumentfromPrimaryContact(primaryContactIdMap);
                }
            }
        }
    }
    public static void copyDocumentfromPrimaryContact(Map<Id,Id> primaryContactIdMap){
        Map<String,String> docNameMap = new Map<String,String>();
        docNameMap.put('Passport','Passport');
        docNameMap.put('Emirates/National ID Front','Emirates ID');
        docNameMap.put('Emirates/National ID Back','Emirates ID');
        docNameMap.put('KYC Form - Signed','Signed KYC and Wealth Form');
        if(!primaryContactIdMap.values().isEmpty()){
            Map<String,Id> targetDocMap = new Map<String,Id>();
            for(Documents__c soDoc:[SELECT Id,Name,SalesOrder__r.PrimaryContact__c FROM  Documents__c WHERE SalesOrder__r.PrimaryContact__c IN:primaryContactIdMap.values() AND SalesOrder__r.Status__c != 'Cancelled' AND Status__c != 'Uploaded' AND Name IN: docNameMap.values()]){
                targetDocMap.put(soDoc.Name+soDoc.SalesOrder__r.PrimaryContact__c,soDoc.Id);
            }
            system.debug('targetDocMap:'+targetDocMap);
            if(!targetDocMap.values().isEmpty()){
                Map<String,ContentDocumentLink> contentDocLinkMap = new Map<String,ContentDocumentLink>();
                Map<String,Id> contactIdMap = new Map<String,Id>();
                for( ContentDocumentLink srcLinks : [SELECT Id, ContentDocumentId,ContentDocument.Title,LinkedEntity.Name, LinkedEntityId, ShareType, Visibility
                                                     FROM ContentDocumentLink
                                                     WHERE LinkedEntityId IN :primaryContactIdMap.keySet() AND LinkedEntity.Name IN:docNameMap.keySet()]){
                                                         
                                                         contentDocLinkMap.put(docNameMap.get(srcLinks.LinkedEntity.Name)+primaryContactIdMap.get(srcLinks.LinkedEntityId),srcLinks);
                                                     }
                System.debug('contentDocLinkMap:'+contentDocLinkMap);
                if(!contentDocLinkMap.values().isEmpty()){
                    relinkFilesToTargets(contentDocLinkMap,targetDocMap,primaryContactIdMap);
                }
            }
        }
    }
    public static void relinkFilesToTargets(Map<String,ContentDocumentLink> contentDocLinkMap,Map<String,Id> targetDocIdMap,Map<Id,Id> primaryContactIdMap) {
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for(Documents__c doc:[SELECT Id,Name,SalesOrder__r.PrimaryContact__c FROM Documents__c WHERE Id IN: targetDocIdMap.values()]) {
            ContentDocumentLink l = contentDocLinkMap.get(doc.Name+doc.SalesOrder__r.PrimaryContact__c);
            if(l <> null){
                newLinks.add(new ContentDocumentLink(
                    ContentDocumentId = l.ContentDocumentId,
                    LinkedEntityId    = doc.Id,
                    ShareType         = l.ShareType != null ? l.ShareType : 'V', // View
                    Visibility        = l.Visibility != null ? l.Visibility : 'AllUsers'
                ));
            }
        }
        if (!newLinks.isEmpty()) {
            insert newLinks;
        }
    } */
    public static void updatePDCinstrumentReceivedInfo(List<sObject> newlist, Map<Id,sObject> oldMap){
        for(Receipt__c rcp:(List<Receipt__c>) newlist){
            Receipt__c oldData = oldMap <> null ? (Receipt__c) oldMap.get(rcp.Id) : null;
            if(rcp.Modeofpayment__c == 'Cheque' && (oldData == null || (oldData <> null && oldData.Modeofpayment__c <> rcp.Modeofpayment__c))){
                rcp.Instrument_Received_Date__c = System.today();
                rcp.Instrument_Received_By__c = UserInfo.getUserId();
            }
        }
    }
    public static void handleInvoiceChange(List<Invoice__c> newlist, Map<Id,Invoice__c> oldMap){
        Set<Id> invoiceIdset = new Set<Id>();
        for(Invoice__c inv:newlist){
            Invoice__c oldData = oldMap <> null ? oldMap.get(inv.Id):null;
            if(inv.AppliedAmount__c <> oldData.AppliedAmount__c || inv.InvoiceStatus__c <> oldData.InvoiceStatus__c){
                invoiceIdset.add(inv.Id);
            }
        }
        if(!invoiceIdset.isEmpty()){
            Set<Id> SalesOrderIdADMFee = new Set<Id>();
            Set<Id> SalesOrderIddownpayment = new Set<Id>();
            for(Invoice__c inv:[SELECT Id,SalesOrderInstallment__c,Is_ADM_Fees_and_Dari_charges__c,SalesOrderInstallment__r.MilestoneNumber__c,SalesOrderInstallment__r.SalesOrder__c,Sales_Order__c FROM Invoice__c WHERE Id IN: invoiceIdset AND (Is_ADM_Fees_and_Dari_charges__c = true OR SalesOrderInstallment__r.PaymentInstallments__r.Name = 'Down Payment' OR SalesOrderInstallment__r.MilestoneNumber__c = 1)]){
                if(inv.Is_ADM_Fees_and_Dari_charges__c == true){ 
                    SalesOrderIdADMFee.add(inv.Sales_Order__c);
                }
                if(inv.SalesOrderInstallment__c <> null && inv.SalesOrderInstallment__r.MilestoneNumber__c == 1){
                    SalesOrderIddownpayment.add(inv.SalesOrderInstallment__r.SalesOrder__c);
                }
            }
            if(!SalesOrderIdADMFee.isEmpty()){
                SalesOrderStatusAutomationHelper.checkADMFeeDariFeeStatus(SalesOrderIdADMFee);
            }
            if(!SalesOrderIddownpayment.isEmpty()){
                SalesOrderStatusAutomationHelper.checkDownPaymentStatus(SalesOrderIddownpayment);
            }
        }
    }
    /*public static void handleSOSubStatusChange(List<sObject> newList, Map<Id,sObject> oldMap){
        Map<Id,String> subStatusMap = new Map<Id,String>();
        for(SalesOrder__c so: (List<SalesOrder__c>) newList){
            SalesOrder__c oldData = oldMap <> null ? (SalesOrder__c) oldMap.get(so.Id) : null;
            if(oldData <> null && so.Sub_Status__c <> null && so.Sub_Status__c <> oldData.Sub_Status__c){
                subStatusMap.put(so.Id,so.Sub_Status__c);
            }
        }
        if(!subStatusMap.values().isEmpty()){
            Map<Id,String> statusMap = new Map<Id,String>();
            for(Sales_Order_Status_Approvals__c soa:[SELECT Id,Approval_Status__c,Current_Sub_Status__c,Sales_Order__c FROM Sales_Order_Status_Approvals__c WHERE Sales_Order__c IN: subStatusMap.keySet() AND Current_Sub_Status__c IN: subStatusMap.values() AND Approval_Status__c = 'Approved' ORDER BY Sales_Order__c,CreatedDate ASC]){
                statusMap.put(soa.Sales_Order__c,soa.Current_Sub_Status__c);
            }
            List<Sales_Order_Status_Approvals__c> soAppList = new List<Sales_Order_Status_Approvals__c>();
            for(Id id: subStatusMap.keySet()){
                if((subStatusMap.containsKey(id) && !subStatusMap.containsKey(statusMap.get(id)))){
                    Sales_Order_Status_Approvals__c soaObj = new Sales_Order_Status_Approvals__c();
                    soaObj.Approval_Status__c = 'Approved';
                    // soaObj.Comments__c = soa.Current_Sub_Status__c+' Closing this step to update in Sales Order';
                    soaObj.Completed_Date__c = System.today();
                    // soaListUpdate.add(soaObj);
                    soAppList.add(soaObj);
                }
            }
        }
    }*/
    @AuraEnabled
    public static String copyIdfromPrimaryContactLWC(Id recordId){
        try{
            Id primaryId = [SELECT Id,PrimaryContact__c FROM Opportunity WHERE Id =:recordId].PrimaryContact__c;
            updateOpptyIdInfo(new Set<Id> {primaryId});
            return 'Success!'; 
        }catch(Exception ex){
            return 'Error!'+ex.getMessage();
        }
    }
    public static void updateOpptyIdInfo(Set<Id> primaryContactIdset){
        List<Opportunity> oppUpdateList = new List<Opportunity>();
        for(Opportunity con:[SELECT Id,PrimaryContact__r.UAE_Resident_Status__c,PrimaryContact__r.EID_Expiry_Date__c,PrimaryContact__r.EIDNumber__c,PrimaryContact__r.PassportNumber__c,PrimaryContact__r.PassportExpiryDate__c,PrimaryContact__r.PassportIssueDate__c FROM Opportunity WHERE PrimaryContact__c IN: primaryContactIdset]){
            Opportunity oppUpd = new Opportunity();
            oppUpd.Id = con.Id;
            oppUpd.UAE_Resident_Status__c = con.PrimaryContact__r.UAE_Resident_Status__c;
            oppUpd.EIDNumber__c = isValidFormatted(con.PrimaryContact__r.EIDNumber__c) ? con.PrimaryContact__r.EIDNumber__c: format(con.PrimaryContact__r.EIDNumber__c);
            oppUpd.EmiratesIDExpiryDate__c = con.PrimaryContact__r.EID_Expiry_Date__c;
            oppUpd.PassportExpiryDate__c = con.PrimaryContact__r.PassportExpiryDate__c;
            oppUpd.PassportIssueDate__c = con.PrimaryContact__r.PassportIssueDate__c;
            oppUpd.PassportNumber__c = con.PrimaryContact__r.PassportNumber__c;
            oppUpdateList.add(oppUpd);
        }
        if(!oppUpdateList.isEmpty()){
            update oppUpdateList;
        }
    }
    public static String format(String input) {
        // keep digits only
        String digits = input == null ? '' : input.replaceAll('[^\\d]', '');
        // must be exactly 15 digits: 3-4-7-1
        if (!Pattern.matches('^\\d{15}$', digits)) return input;
        return digits.replaceAll('^(\\d{3})(\\d{4})(\\d{7})(\\d)$', '$1-$2-$3-$4');
    }

    public static Boolean isValidFormatted(String eid) {
        return eid != null && Pattern.matches('^784-\\d{4}-\\d{7}-\\d$', eid);
    }

    public static void applyAssociateSharing(Map<Id, sObject> oldMap,Map<Id, sObject> newMap) {
        Set<Id> soIds = new Set<Id>(newMap.keySet());

        // Build desired users from NEW values
        Map<Id, Set<Id>> desiredUsersBySO = new Map<Id, Set<Id>>();
        for (SalesOrder__c so : (List<SalesOrder__c>)newMap.values()) {
            SalesOrder__c oldData = (SalesOrder__c) oldMap.get(so.Id);
            Set<Id> u = new Set<Id>();
            if (so.Finance_Associate__c != null && oldData.Finance_Associate__c <> so.Finance_Associate__c ) u.add(so.Finance_Associate__c);
            if (so.Customer_Management_Associate__c != null && oldData.Customer_Management_Associate__c <> so.Customer_Management_Associate__c != null) u.add(so.Customer_Management_Associate__c);
            if (so.SalesAssociate__c != null && oldData.SalesAssociate__c <> so.SalesAssociate__c) u.add(so.SalesAssociate__c);
            if (so.Sales_Operations_Associate__c != null && oldData.Sales_Operations_Associate__c <> so.Sales_Operations_Associate__c)    u.add(so.Sales_Operations_Associate__c);
            desiredUsersBySO.put(so.Id, u);
        }

        // Existing shares (by this RowCause)
        List<SalesOrder__Share> existing = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM SalesOrder__Share
            WHERE ParentId IN :soIds AND RowCause = :ROW_CAUSE
        ];

        // Build nested map WITHOUT putIfAbsent
        Map<Id, Map<Id, SalesOrder__Share>> existingBySO = new Map<Id, Map<Id, SalesOrder__Share>>();
        for (SalesOrder__Share sh : existing) {
            Map<Id, SalesOrder__Share> innerVal = existingBySO.get(sh.ParentId);
            if (innerVal == null) {
                innerVal = new Map<Id, SalesOrder__Share>();
                existingBySO.put(sh.ParentId, innerVal);
            }
            innerVal.put(sh.UserOrGroupId, sh);
        }

        List<SalesOrder__Share> toInsert = new List<SalesOrder__Share>();
        List<SalesOrder__Share> toUpdate = new List<SalesOrder__Share>();
        List<SalesOrder__Share> toDelete = new List<SalesOrder__Share>();

        for (Id soId : soIds) {
            Set<Id> desired = desiredUsersBySO.get(soId);
            Map<Id, SalesOrder__Share> current = existingBySO.get(soId);
            if (current == null) current = new Map<Id, SalesOrder__Share>();

            // Ensure Edit shares for all desired users
            for (Id uid : desired) {
                if (!current.containsKey(uid)) {
                    SalesOrder__Share sh = new SalesOrder__Share();
                    sh.ParentId      = soId;
                    sh.UserOrGroupId = uid;
                    sh.AccessLevel   = 'Edit';
                    sh.RowCause      = ROW_CAUSE;
                    toInsert.add(sh);
                } else if (current.get(uid).AccessLevel != 'Edit') {
                    SalesOrder__Share sh = current.get(uid);
                    sh.AccessLevel = 'Edit';
                    toUpdate.add(sh);
                }
            }

            // Remove shares no longer desired
            for (Id uid : current.keySet()) {
                if (!desired.contains(uid)) {
                    toDelete.add(current.get(uid));
                }
            }
        }
                                                 try{
                if (!toInsert.isEmpty()) insert toInsert;
                if (!toUpdate.isEmpty()) update toUpdate;
                if (!toDelete.isEmpty()) delete toDelete;
                                                 
                                                 }catch(Exception ex){
                                                     
                                                 }
                                                 
    }
     public static void handleSpaDocs(List<sObject> newList, Map<Id, sObject> oldMap) {

        Set<String> targetStatuses = new Set<String>{
            'SPA Generated',
            'Pending for Validation',
            'SPA Signed (Modon)'
        };
        /** 3.1 Reverted back previous spa doc condition to store relavant folder **/
        List<SalesOrder__c> toProcess = new List<SalesOrder__c>();
        for (SalesOrder__c so : (List<SalesOrder__c>) newList) {
           SalesOrder__c oldSo = (SalesOrder__c) oldMap.get(so.Id);
            if (oldSo.SPAStatus__c != so.SPAStatus__c && targetStatuses.contains(so.SPAStatus__c)) {
                toProcess.add(so);
             }
        }
	    if (toProcess.isEmpty()) {
            return;
        }

        Set<Id> salesOrderIds = new Set<Id>();
        for (SalesOrder__c so : toProcess) {
            salesOrderIds.add(so.Id);
        }
	    List<ContentDocumentLink> allSOLinks = [
            SELECT Id,
                   ContentDocumentId,
                   LinkedEntityId,
                   ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :salesOrderIds AND ContentDocument.Title LIKE '%spa%' /** 1.2 Pick Correct SPA Files and Upload in the respective Document**/
            ORDER BY ContentDocument.CreatedDate DESC
        ];

        Map<Id, Id> soIdToContentDocumentId = new Map<Id, Id>();
        for (ContentDocumentLink cdl : allSOLinks) {
            if (!soIdToContentDocumentId.containsKey(cdl.LinkedEntityId)) {  /** 3.1 Reverted back previous spa doc condition to store relavant folder **/
                soIdToContentDocumentId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }

        if (soIdToContentDocumentId.isEmpty()) {
            return;
        }

        Map<Id, String> soIdToDocName = new Map<Id, String>();
        Set<String> docNamesNeeded = new Set<String>();

        for (SalesOrder__c so : toProcess) {
            if (!soIdToContentDocumentId.containsKey(so.Id)) {
                continue; // no file
            }

            String nameForDoc;
            if (so.SPAStatus__c == 'SPA Generated') {
                nameForDoc = 'SPA';
            }else if (so.SPAStatus__c == 'Pending for Validation') {
                nameForDoc = 'Signed SPA (Customer)';
            } else if (so.SPAStatus__c == 'SPA Signed (Modon)') {
                nameForDoc = 'Signed SPA (Modon)';
            } else {
                continue;
            }

            soIdToDocName.put(so.Id, nameForDoc);
            docNamesNeeded.add(nameForDoc);
        }

        if (soIdToDocName.isEmpty()) {
            return;
        }

        List<Documents__c> existingFolders = [
            SELECT Id, Name, SalesOrder__c
            FROM Documents__c
            WHERE SalesOrder__c IN :salesOrderIds
              AND Name IN :docNamesNeeded AND status__c != 'Uploaded' /** 1.2 To Avoid the duplicate upload, If file is already "Uploaded" **/
        ];

        // key: "<SalesOrderId>||<Name>" -> Documents__c
        Map<String, Documents__c> keyToFolder = new Map<String, Documents__c>();
        for (Documents__c d : existingFolders) {
            String key = d.SalesOrder__c + '||' + d.Name;
            keyToFolder.put(key, d);
        }

        if (keyToFolder.isEmpty()) {
            // no matching folders for these SOs / names
            return;
        }

		Set<Id> folderIds = new Set<Id>();
        Set<Id> contentDocIds = new Set<Id>();

        for (SalesOrder__c so : toProcess) {
            if (!soIdToDocName.containsKey(so.Id)) continue;
            if (!soIdToContentDocumentId.containsKey(so.Id)) continue;

            String key = so.Id + '||' + soIdToDocName.get(so.Id);
            Documents__c folder = keyToFolder.get(key);
            if (folder == null) continue;

            folderIds.add(folder.Id);
            contentDocIds.add(soIdToContentDocumentId.get(so.Id));
        }

        if (folderIds.isEmpty() || contentDocIds.isEmpty()) {
            return;
        }

        // 6. Check existing ContentDocumentLinks so we don't create duplicates
        List<ContentDocumentLink> existingLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :folderIds
              AND ContentDocumentId IN :contentDocIds
        ];

        Set<String> existingLinkKey = new Set<String>();
        for (ContentDocumentLink l : existingLinks) {
            existingLinkKey.add(l.LinkedEntityId + '||' + l.ContentDocumentId);
        }

        // 7. Create new ContentDocumentLinks (this is the "upload under the folder" part)
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

        for (SalesOrder__c so : toProcess) {
            Id contentDocId = soIdToContentDocumentId.get(so.Id);
            String docName = soIdToDocName.get(so.Id);
            if (contentDocId == null || docName == null) continue;

            String key = so.Id + '||' + docName;
            Documents__c folder = keyToFolder.get(key);
            if (folder == null) continue;

            String linkKey = folder.Id + '||' + contentDocId;
            if (existingLinkKey.contains(linkKey)) {
                // file already linked to this folder
                continue;
            }

            ContentDocumentLink newLink = new ContentDocumentLink();
            newLink.ContentDocumentId = contentDocId;
            newLink.LinkedEntityId    = folder.Id;   // link to Documents__c record
            newLink.ShareType         = 'V';         // View
            newLink.Visibility        = 'AllUsers';
            linksToInsert.add(newLink);
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }
    public static void handleFinanceVerificationStatus(List<Sales_Order_Status_Approvals__c> newList, Map<Id,Sales_Order_Status_Approvals__c> oldMap){
        Set<Id> soIdset = new Set<Id>();
        for(Sales_Order_Status_Approvals__c obj: newList){
            Sales_Order_Status_Approvals__c oldData = oldMap <> null ? oldMap.get(obj.Id):null;
            if(obj.Current_Sub_Status__c == 'Under Finance Verification' && (oldData == null || (oldData <> null && oldData.Current_Sub_Status__c <> obj.Current_Sub_Status__c))){
                soIdset.add(obj.Sales_Order__c);
            }
        }
    }
    public static void closeFinaceVerificationStep(Set<Id> soIdset){
        Set<Id> soIdexist = new Set<Id>();
        Map<Id,Document_Checklist__c> soExistDocIdMap = new Map<Id,Document_Checklist__c>();
        Map<Id,SalesOrder__c> salesOrderMap = new Map<Id,SalesOrder__c>();
        List<Document_Checklist__c> soaListUpdate = new List<Document_Checklist__c>();
        for(Document_Checklist__c so:[SELECT Id,Sales_Order__c,Sales_Order__r.Finance_Associate__c FROM Document_Checklist__c WHERE Team__c = 'Finance' AND Approval_Status__c = 'Pending' AND
                                                Sales_Order__c IN:soIdset AND Sales_Order__r.Sub_Status__c = 'Under Finance Verification' AND Sales_Order__r.Down_Payment_Status__c = 'Paid' AND Sales_Order__r.ADM_Fees_and_Dari__c = 'Paid' AND Sales_Order__r.Source_Entity__c != 'Modon - Egypt' ORDER BY CreatedDate DESC LIMIT 1]){
              soExistDocIdMap.put(so.Sales_Order__c,so);
        }
        for(SalesOrder__c so:[SELECT Id,Finance_Associate__c FROM SalesOrder__c WHERE Id IN: soIdset AND Sub_Status__c = 'Under Finance Verification' AND Down_Payment_Status__c = 'Paid' AND ADM_Fees_and_Dari__c = 'Paid' AND Source_Entity__c != 'Modon - Egypt']){
            salesOrderMap.put(so.Id,so);
        }
        for(Id soId: salesOrderMap.keySet()){
              Document_Checklist__c soaObj = new Document_Checklist__c();
              soaObj.Id =  soExistDocIdMap.containsKey(soId) ? soExistDocIdMap.get(soId).Id:null;
              soaObj.Approval_Status__c = 'Approved';
              soaObj.Document_Description__c = 'Auto finance verification step - Completion';
              soaObj.Approve_Rejected_Date_Time__c = System.today();
              soaObj.team__c = 'Finance';
              //soaObj.Approve_Reject_By__c = soExistDocIdMap.containsKey(soId) ? soExistDocIdMap.get(soId).Sales_Order__r.Finance_Associate__c:null;
              soaObj.Sales_Order__c = soId;
              soaListUpdate.add(soaObj);
        }
        
        if(!soaListUpdate.isEmpty()){
            upsert soaListUpdate;
        }
    }
}