/**********************************************************************************************************************
* Name               : SalesOrderTriggerHelper                                                        
* Description        : This class is used as a helper to handle all the Sales Order trigger instances
* Usage              : Called from SalesOrderTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com         22 Jan 2023     Initial Draft      
* 1.1           manoj.vallapuneni@modon.com    25 Dec 2024     Update as per of the Inventory manager page and picklist value
* 1.2           Sirisha Reddy                  15 Sep 2025     Added So boolean Flag criteria for ADM Creation 
* 1.3           Kumaravel                       10 Oct 2025     update oracel call out methid
* 1.4           Prateek                         12 Dec 2025     Added source entity check for populating amount in words for Egypt Modon sales orders
* 1.5           suresh.bhethi@amgs.com          16 DEC 2025     SPA FinalCopy added
* 1.6           raghu.gajjela@amgs.com          22 DEC 2025     Updated the SO.Status=down Payment collected to IsDownPaymentCollected__c = true
* 2.0           Milin (Horizontal)             09 Feb 2026     Updating EgyptChequeReceiptTotalAmountInWords__c as per EgyptChequeReceiptTotalAmount__c
* 3.0           Shahil Sinha (Horizontal)      11 Feb 2026     Added createModonEgyptDocumentRecords method to create Bulk Cheque document on the Egypt specific Sales Orders
* 4.0           Shahil Sinha (Horizontal)      11 Feb 2026     Commenting EgyptChequeReceiptTotalAmountInWords__c logic
* 6.0           suresh.bhethi@amgs.com       09 MAR 2026     Added the new feature - PDC SLA Timer
* 8.0           Mirza Baig			    	   20 APR 2026     Added the new method (processXeboSalesOrder) to send the data to XEBO
* 9.0			Narendra					 18 May 2026	  Populating Opportunity lookup on document record
* 10.0          Arvind                             06 Jun 2026     P1 FIX - Too many SOQL queries: 101. Cached VIP User and Group
*                                                                   queries in shareVIPSalesOrder() and setOwner(). Were firing 13x
*                                                                   per transaction. Now queried once only per transaction.
* 10.1          Arvind                             06 Jun 2026     FIX - createNewServiceRequestBasedOnSoStatus() signature changed
*                                                                   from List<SObject> to List<SalesOrder__c> to match all callers.
* 10.2          Arvind                             06 Jun 2026     FIX - Duplicate SalesOrder__Share error in shareVIPSalesOrder().
*                                                                   Added alreadySharedSOIds static Set to prevent duplicate inserts
*                                                                   when method is called multiple times in one transaction.
* 13.0          Mirza Baig                      03 Aug 2026    Prevented duplicate Unit booking by validating active Sales Orders.
* 14.0          Arvind Kesharwani               21 Aug 2026    salesOrderCustEmail() replaced: legacy Xibo future callout
******************************************************************************************************************/
public without sharing class SalesOrderTriggerHelper {

    // 10.0 - P1 FIX - Arvind - 06 Jun 2026
    // Static cache for VIP User and Group. Without caching, these queries fired
    // 13x each per transaction pushing SOQL count to 101.
    // Now queried once per transaction regardless of how many times methods are called.
    private static List<User>  cachedVIPOwner;
    private static List<Group> cachedVIPGroup;

    // 10.2 - FIX - Arvind - 06 Jun 2026
    // Tracks SalesOrder IDs already shared this transaction to prevent duplicate
    // SalesOrder__Share insert errors when shareVIPSalesOrder() is called multiple
    // times for the same record in one transaction.
    private static Set<Id> alreadySharedSOIds = new Set<Id>();

    //send SPA to customer using the sendgrid and communication matrix
    public static void sendCounterSignedSPA(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        List<SalesOrder__c> lst_FinalSO = new List<SalesOrder__c>();
        for(SalesOrder__c newSO : (List<SalesOrder__c>)newList){
            SalesOrder__c  oldRecord = (SalesOrder__c)oldMap.get(newSO.Id);
            if(newSO.status__c != oldRecord.Status__c &&  newSO.Status__c == 'Completed'){
                lst_FinalSO.add(newSO);
            }
        }
        if(lst_FinalSO.size() > 0){
                Database.executeBatch(new SPAFinalCustomerCopyBatch(lst_FinalSO), 1);
        }        
    }
    //v6.0 start
    public static void pdcSLA(list<SObject> newSalesOrders) {
        Integer InitialHour = Integer.valueOf(System.Label.PDCSLAHour);
        Integer ExtendedHour = Integer.valueOf(System.Label.PDCExtensionSLAHour);
        for(SalesOrder__c salesOrder : (List<SalesOrder__c>) newSalesOrders) {
            Datetime nowDt = Datetime.now();
            String team = 'Unknown';
        if (
            (salesOrder.Sub_Status__c == 'Pending with Sales' && salesOrder.Is_Sales_Checklist_Completed__c == false)
            || (salesOrder.Status__c == 'New' && String.isBlank(salesOrder.Sub_Status__c))
            || salesOrder.Sub_Status__c == 'Down Payment Collected'
            || salesOrder.Sub_Status__c == 'ADM + Dari Fee Collected'
            || salesOrder.Sub_Status__c == 'Reservation Form Generated'
            || salesOrder.Sub_Status__c == 'Broker Form Generated'
            || salesOrder.Sub_Status__c == 'Pending With Sales Team') team = 'Sales';
            else if (salesOrder.Sub_Status__c == 'Pending With Sales Operation') team = 'Sales Operation';
            else if (salesOrder.Sub_Status__c == 'Under Finance Verification') team = 'Finance';
            else if (salesOrder.Sub_Status__c == 'Pending with CM') team = 'Customer Management';
            else team = 'Unknown';
            BusinessHours bh = SalesOrderPDCSLAHelper.getBusinessHours(team);
            Datetime after24Hours = nowDt.addHours(InitialHour);
            if(!BusinessHours.isWithin(bh.Id, after24Hours)){
               after24Hours = BusinessHours.nextStartDate(bh.Id, after24Hours);
            } 
            salesOrder.PDC_SLA__c = after24Hours; 
            Datetime after48Hours = after24Hours.addHours(ExtendedHour);
            if(!BusinessHours.isWithin(bh.Id, after48Hours)){
               after48Hours = BusinessHours.nextStartDate(bh.Id, after48Hours);
            }
            salesOrder.PDC_Extended_SLA__c = after48Hours;      
        }
    }
    //v6.0 end
    public static void setOwner(list<SObject> newList, Map<Id, SObject> oldMap){ // Call this Before Insert and Before Update
        
        //list<Group> vipManagementGrp = [select Id, DeveloperName, Type from Group where Type = 'Queue' and DeveloperName = 'VIP_Managers'];
        // 10.0 - P1 FIX - Arvind - 06 Jun 2026: replaced inline query with static cache
        if (cachedVIPOwner == null) {
            cachedVIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];
        }
        list<User> VIPOwner = cachedVIPOwner;
        
        for(SalesOrder__c newSO : (List<SalesOrder__c>)newList){
            
            if(oldMap == null){
                if(VIPOwner <> null && !VIPOwner.isEmpty() && (newSO.CustomerType__c == Constants.CUSTOMER_TYPE_VIP || newSO.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP))
                    newSO.OwnerId = VIPOwner[0].Id;
            }
            
            SalesOrder__c oldRecord;
            if(oldMap <> null){
                oldRecord = (SalesOrder__c)oldMap.get(newSO.Id);
                if(VIPOwner <> null && !VIPOwner.isEmpty() && ( (newSO.CustomerType__c == Constants.CUSTOMER_TYPE_VIP && newSO.CustomerType__c <> oldRecord.CustomerType__c) || (newSO.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP && newSO.CustomerType__c <> oldRecord.CustomerType__c)))
                    newSO.OwnerId = VIPOwner[0].Id;
            }
        }
    }
    
    //send email using sendgrid
    public static void sendGrid(list<SObject> newListSO, Map<Id, SObject> oldMap){
        List<Id> soIds = new List<Id>();
        for(SalesOrder__c soObj : (List<SalesOrder__c>)newListSO){
            if(soObj.Email_Reminder__c != Null && soObj.Email_Reminder__c != ((SalesOrder__c) oldMap.get(soObj.Id)).Email_Reminder__c){
                soIds.add(soObj.Id);  
            }
        }
        if(!soIds.isEmpty()){
        System.debug('soIds SendGrid Trigger helper::=>'+ soIds);
        //SendGridEmailServiceVF.sendEmailUsingSendGrid(soIds);
        String isSendPayment = System.Label.sendGridAttachment;
        System.debug('soIds SendGrid Trigger helper::=>'+ soIds);
        if(isSendPayment == 'True'){
            System.enqueueJob(new SendGridEmailServiceVF(soIds)); 
        }else{
            System.enqueueJob(new SendGridEmailServiceVF_v1(soIds));  
        }
        }
    }
    
    public static void populateCompletionDate(list<SObject> newList, Map<Id, SObject> oldMap){ // Call this Before Update
        for(SalesOrder__c newSO : (List<SalesOrder__c>)newList){
            SalesOrder__c oldRecord;
            if(oldMap <> null){
                oldRecord = (SalesOrder__c)oldMap.get(newSO.Id);
                if(newSO.Status__c == 'Completed' && oldRecord.Status__c != 'Completed'){
                    newSO.SOCompletion_Date__c = System.Today();
                } else if(newSO.Status__c != 'Completed' && oldRecord.Status__c == 'Completed'){
                    newSO.SOCompletion_Date__c = null;
                }
            }
        }
    }
    
    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('SalesOrder__c');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(SalesOrder__c soObj : (List<SalesOrder__c>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.SalesOrder__c = soObj.Id;
                    tempD.Opportunity__c = soObj.Opportunity__c;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    public static void populateAmountText(List<SObject> newList){
        // For egypt we have different currency
        String currencyUnit = 'dirhams';
        String currencySubUnit = 'fils';
        for(SalesOrder__c so : (List<SalesOrder__c>)newList){
            system.debug('==>' + so.Source_Entity__c);
            if(so.Source_Entity__c == 'Modon - Egypt'){ //v1.4
                if( so.currencyISOCode == 'EGP' ){
                    currencyUnit = 'egyptian pound';
                    currencySubUnit = 'piastres';
                }

                //Added lines 477-488, Narendra Agrawal, HZTL(To support mutlicurrency for Egypt)
                if( so.currencyISOCode == 'USD' ){currencyUnit = 'us dollar';currencySubUnit = 'cents';}
                
                if( so.currencyISOCode == 'EUR' ){ currencyUnit = 'euro';currencySubUnit = 'cents';}
                
                if( so.currencyISOCode == 'SAR' ){currencyUnit = 'saudi riyal'; currencySubUnit = 'halalas';
                } 
            }else{
                currencyUnit = 'dirhams';
                currencySubUnit = 'fils';
            }//v1.4

            system.debug('so.currencyISOCode=>'+ so.currencyISOCode);
               
            if(so.TotalAmount__c !=null){ so.Totalamountinwords__c = Utilities.amountInWords (so.TotalAmount__c ,currencyUnit,currencySubUnit ); }
            if(so.Totalpaidamount__c  !=null){ so.Totalpaidamountinwords__c   = Utilities.amountInWords (so.Totalpaidamount__c  ,currencyUnit,currencySubUnit ); }
            //v2.0 - Updating EgyptChequeReceiptTotalAmountInWords__c as per EgyptChequeReceiptTotalAmount__c
            //if(so.EgyptChequeReceiptTotalAmount__c  !=null){ so.EgyptChequeReceiptTotalAmountInWords__c   = Utilities.amountInWords (so.EgyptChequeReceiptTotalAmount__c  ,currencyUnit,currencySubUnit ); } //v4.0
        }
    }
    
    public static void manageJointOwner(List<sObject> newList){ // call this After Insert.
        
        Map<String, List<SalesOrder__c>> oppSalesOrderMap = new Map<String, List<SalesOrder__c>>();
        set<Id> opportunityIdSet = new set<Id>();
        for(SalesOrder__c soObj : (List<SalesOrder__c>)newList){
            if(String.isNotBlank(soObj.Opportunity__c)){
                List<SalesOrder__c> tempSoLst = oppSalesOrderMap.get(soObj.Opportunity__c);
                if(tempSoLst == null){
                    tempSoLst = new List<SalesOrder__c>();
                }
                tempSoLst.add(soObj);
                opportunityIdSet.add(soObj.Opportunity__c);
                oppSalesOrderMap.put(soObj.Opportunity__c, tempSoLst);
            }
        }
        
        
        if(opportunityIdSet != null && opportunityIdSet.size() > 0){
            Map<String, List<JointOwner__c>> oppJointOwnerMap = new Map<String, List<JointOwner__c>>();
            
            for(Opportunity oppObj : [SELECT Id, (SELECT Id, SalesOrder__c, Opportunity__c, JointOwnerAccount__c, OwnershipPercentage__c, RelationshipSubType__c, RelationshipType__c, SalesOrder__r.Status__c FROM Joint_Owners__r) FROM Opportunity WHERE Id IN : opportunityIdSet]){
                if(!oppObj.Joint_Owners__r.isEmpty()){
                    oppJointOwnerMap.put(oppObj.Id, oppObj.Joint_Owners__r);
                }
            }
            List<JointOwner__c> updateJoLst = new List<JointOwner__c>();
            List<JointOwner__c> insertJoLst = new List<JointOwner__c>();
            set<String> joSet = new set<String>();
            if(oppJointOwnerMap.size() > 0){
                for(String oppId : opportunityIdSet){
                    if(oppJointOwnerMap.containsKey(oppId)){
                        for(SalesOrder__c soObj : oppSalesOrderMap.get(oppId)){
                            for(JointOwner__c joObj : oppJointOwnerMap.get(oppId)){
                                if(String.isNotBlank(joObj.SalesOrder__c)){
                                    JointOwner__c joObjClone = joObj.clone();
                                    joObjClone.SalesOrder__c = soObj.Id;
                                    joObjClone.Opportunity__c = null;
                                    insertJoLst.add(joObjClone);
                                }else if(String.isBlank(joObj.SalesOrder__c) && !joSet.contains(joObj.Id)){
                                    joObj.SalesOrder__c = soObj.Id;
                                    updateJoLst.add(joObj);
                                    joSet.add(joObj.Id);
                                }
                            }
                        }
                    }
                }
            }
            
            if(!updateJoLst.isEmpty()){
                UPDATE updateJoLst;
            }
            if(!insertJoLst.isEmpty()){
                INSERT insertJoLst;
            }
        }
    }
    
    public static void updatUnitStatusBasedonSOStatus(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this after update
        
        set<string> unitIds = new set<string>();
        
        for(SalesOrder__c newSO : (List<SalesOrder__c>)newList){
            SalesOrder__c  oldRecord = (SalesOrder__c)oldMap.get(newSO.Id);
            if(newSO.Status__c == 'Cancelled' && newSO.Status__c  <> oldRecord.Status__c ){
                unitIds.add(newSO.Unit__c );
            }
        }
        system.debug('unitIds:::' + unitIds);
        
        if(!unitIds.isEmpty()){
            list<Unit__c> unitsCurrent = [Select Id, Status__c, BlockReason__c, Source_Entity__c from Unit__c where Id in: unitIds ];
            list<Unit__c> unitsToUpdate = new list<Unit__c>();
            
            system.debug('unitsCurrent:::' + unitsCurrent);
            
            if(unitsCurrent <> null && !unitsCurrent.isEmpty()){
                for(Unit__c unt: unitsCurrent){
                    Unit__c unitToUpdate = new Unit__c();
                    //  unitToUpdate.Id = unt.Id;unitToUpdate.Status__c = 'Booking cancelled';unitToUpdate.BlockReason__c = 'Sales Order Cancelled';unitsToUpdate.add(unitToUpdate);
                    //Update as per of the Inventory manager page and picklist value 
                    unitToUpdate.Id = unt.Id;unitToUpdate.Status__c = '';
                    unitToUpdate.ApprovalStatus__c='Draft'; 
                    unitToUpdate.Sub_Status__c =''; 
                    unitToUpdate.BlockReason__c = 'Sales Order Cancelled';
                    unitToUpdate.Unit_Sold_Date__c = null;
                    unitsToUpdate.add(unitToUpdate);
                }
                
                if(!unitsToUpdate.isEmpty()){
                    update unitsToUpdate;
                }
            }
        }
        
    }
    
    public static void updateCommaSeparatedField(List<SObject> newList) {
        for (SObject sobj : newList) {
            SalesOrder__c newRec = (SalesOrder__c) sobj;
            newRec.SearchHelper__c = newRec.FormulaAccountName__c + ', ' + newRec.FormulaEmail__c + ', ' + newRec.FormulaEID__c + ', ' + newRec.FormulaMobile__c;
        }
    }
    
    // 10.0 - P1 FIX - Arvind - 06 Jun 2026
    // User query (old line 285) and Group query (old line 293) were firing 13x per
    // transaction = 26 wasted SOQL queries. Both now use static cache - DB hit once only.
    // All sharing logic is 100% identical to original - zero logic change.
    // 10.2 - FIX - Arvind - 06 Jun 2026
    // Added alreadySharedSOIds guard to prevent duplicate SalesOrder__Share insert
    // error when this method is called multiple times in the same transaction.
    public static void shareVIPSalesOrder(map<ID,SObject> SalesOrderMap){
        //list<Group> VIPOwner = [select id,name, DeveloperName,Type from Group where type ='Queue' and DeveloperName = 'VIP_Managers'];
        // 10.0 - P1 FIX - Arvind - 06 Jun 2026: replaced inline query with static cache
        if (cachedVIPOwner == null) {
            cachedVIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];
        }

        set<ID> SalesOrderIDs = new set<ID>();
        for(SalesOrder__c so : (List<SalesOrder__c>)SalesOrderMap.values()){
            if(!cachedVIPOwner.isEmpty() && so.OwnerID == cachedVIPOwner[0].Id){
                SalesOrderIDs.add(so.Id);
            }
        }

        // 10.0 - P1 FIX - Arvind - 06 Jun 2026: replaced inline query with static cache
        if (cachedVIPGroup == null) {
            cachedVIPGroup = [select id,name, DeveloperName,Type from Group where type ='Regular' and DeveloperName = 'VIP_Managers'];
        }
        list<SalesOrder__Share> shareRecordToBeCreated = new list<SalesOrder__Share>();

        if(!cachedVIPGroup.isEmpty() && !SalesOrderIDs.isEmpty()){
            // 10.2 - FIX - Arvind - 06 Jun 2026
            // Remove IDs already processed earlier in this transaction to prevent
            // duplicate SalesOrder__Share insert errors.
            SalesOrderIDs.removeAll(alreadySharedSOIds);

            if(!SalesOrderIDs.isEmpty()){
                map<id,SalesOrder__Share> existingShareRecords = new map<id,SalesOrder__Share>();
                for(SalesOrder__Share existingRecord : [select id,ParentID from SalesOrder__Share where ParentID in :SalesOrderIDs and UserOrGroupId=:cachedVIPGroup[0].Id ]){
                    existingShareRecords.put(existingRecord.ParentID,existingRecord);
                }
                for(Id tempSOID : SalesOrderIDs){
                    if(!existingShareRecords.containsKey(tempSOID)){
                        shareRecordToBeCreated.add(new SalesOrder__Share(AccessLevel ='Edit', ParentID =tempSOID,RowCause='Manual',UserOrGroupId=cachedVIPGroup[0].Id));
                    }
                }
                if(!shareRecordToBeCreated.IsEmpty()){
                    database.insert(shareRecordToBeCreated,false);
                }
                // Mark these IDs as done for the rest of this transaction
                alreadySharedSOIds.addAll(SalesOrderIDs);
            }
        }
    }
    
//Sales Order API Callout Trigger Point - BEGIN
    public static void sendSalesOrdersToOracle(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){ // call this After Insert and After Update
       
        set<string> currRecIds = new set<string>();
        set<string> currDpIds = new set<string>();
        //OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('Cut_Off_Date');
        //Date cutOffDate = Date.valueOf(oicParams.Value__c);
       
        /*if(oldMap == null){ // for Insert
           
            for(String key : newMap.keySet()){
                SalesOrder__c rec = (SalesOrder__c) newMap.get(key);
                if(rec.CreatedDate >= cutOffDate && rec.OICIntegrationStatus__c <> 'S'){
                    currRecIds.add(rec.Id); // uncommented for new changes
                   
                }
            }
           
           
        }*/
        if(oldMap <> null){ // for Update
            for(String key : newMap.keySet()){
                SalesOrder__c newRecord = (SalesOrder__c) newMap.get(key);
                SalesOrder__c oldRecord;
                oldRecord = (SalesOrder__c)oldMap.get(newRecord.Id);
               
                // if( newRecord.CreatedDate >= cutOffDate && (newRecord.TotalAmount__c <> oldRecord.TotalAmount__c ||
                //if( newRecord.TotalAmount__c <> oldRecord.TotalAmount__c || (newRecord.Status__c <> oldRecord.Status__c && newRecord.Status__c == 'Reservation form generated')){  // kumaravel disabled no new changes
                if( newRecord.TotalAmount__c <> oldRecord.TotalAmount__c || (newRecord.Status__c <> oldRecord.Status__c) || (newRecord.Down_Payment_Status__c <> oldRecord.Down_Payment_Status__c )){                                          
                                                                currRecIds.add(newRecord.Id);
                                                               
                }
 
                // before salesorder status revamp
                /*if(newRecord.Status__c <> oldRecord.Status__c && newRecord.Status__c =='Down payment collected'){
                    currDpIds.add(newRecord.Id);
                }*/
 
                // after salesorder status revamp
               // system.debug ( 'New dp ' +  newRecord.Down_Payment_Status__c + ' : old dp ' + oldRecord.Down_Payment_Status__c);
                 system.debug ( 'New dp status' +  newRecord.Status__c + ' : old dp status ' + oldRecord.Status__c);
 
 
                if(  (newRecord.Down_Payment_Status__c <> oldRecord.Down_Payment_Status__c && (newRecord.Down_Payment_Status__c == 'Collected' || newRecord.Down_Payment_Status__c == 'Partially Collected') )  || (newRecord.Status__c <> oldRecord.Status__c && newRecord.Status__c =='Down payment collected' ) ){
                    currDpIds.add(newRecord.Id);
                    system.debug('yest');
 
                }                
               
               
            }
           
        }
       
        /*if(!currRecIds.isEmpty() && oldMap == null){
            if(!system.isBatch() && !Test.isRunningTest()){
                System.enqueueJob(new CustomerSalesOrderCallout_Queable(currRecIds));
            }
        }*/
        if(!currRecIds.isEmpty() && oldMap <> null){
            if(!system.isBatch()){
                if(currDpIds.size() > 0){                    
                    System.enqueueJob(new salesorderQueuableService(currDpIds));
                }else{                
                System.enqueueJob(new CustomerSalesOrderCallout_Queable(currRecIds));
                //sendSalesOrdersToOracle_Future(currRecIds);
            }
        }
        }        
    }
   
    @future(callout = true)
    public static void sendSalesOrdersToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(recIds);
    } 
    
    //Sales Order API Callout Trigger Point - END
    
   // 10.1 - FIX - Arvind - 06 Jun 2026
   // Changed parameter from List<SObject> to List<SalesOrder__c> to match all call
   // sites. Removed unnecessary cast inside the loop. Logic is 100% unchanged.
   public static void createNewServiceRequestBasedOnSoStatus(List<SalesOrder__c> newList) {

        List<SalesOrder__c> soList = new List<SalesOrder__c>();

        for (SalesOrder__c newSO : newList) {
            //Added the boolean flag criteria
            if (newSO.Status__c == 'Completed' && newSO.SPAStatus__c == 'SPA Signed (Modon)' && newSO.is_Transferred_SO__c == False) {
                soList.add(newSO);
            }
        }
       
        if (!soList.isEmpty()) {
            ADMSRService.createADMServiceRequests(soList);
        }
    }
     public static void PreventSalesOrderForDefaulted(List<SalesOrder__c> newSalesOrders) {
        Set<Id> accountIds = new Set<Id>();

for (SalesOrder__c so : newSalesOrders) {
    if (so.CustomerAccount__c != null) {
        accountIds.add(so.CustomerAccount__c);
    }
}

if (accountIds.isEmpty()) return;

Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Customer_Defaulted__c 
     FROM Account 
     WHERE Id IN :accountIds]
);

for (SalesOrder__c so : newSalesOrders) {
    if (so.CustomerAccount__c != null && accountMap.containsKey(so.CustomerAccount__c)) {
        if (accountMap.get(so.CustomerAccount__c).Customer_Defaulted__c == true) {
            so.addError('Cannot create Sales Order. The related Customer Account is marked as defaulted.');
        }
    }
        }
    }
    
    // Added for sening emails to customer 26-06-2025 Raghu gajjela
    // this runs based on salesorder SPA status(V14.0)
  /* public static void salesOrderCustEmail(List<SalesOrder__c> newList, List<SalesOrder__c> oldList) {
         System.debug('debug: in SalesOrderController.salesOrderCustEmail method');
        
         if (newList.isEmpty()) return;
        
        Set<String> salesOrderForClosureSet = new Set<String>();
        
         for (SalesOrder__c newRec : newList) {
           SalesOrder__c oldRec = null;
            
           // Match old record by Id
             for (SalesOrder__c oldSO : oldList) {
                 if (oldSO.Id == newRec.Id) {oldRec = oldSO; break; }
             }
            
             // System.debug('debug: oldRec.Id: ' + (oldRec != null ? oldRec.Id : 'null'));
             // System.debug('debug: oldRec.SPAStatus__c: ' + (oldRec != null ? oldRec.SPAStatus__c : 'null'));
             // SPAStatus changed to 'Pending for Validation'
            // if (oldRec != null && oldRec.SPAStatus__c != newRec.SPAStatus__c && newRec.SPAStatus__c == 'Pending for Validation') {salesOrderForClosureSet.add(newRec.Id); } condition chnageed as per Hassan
            //if (oldRec != null && oldRec.Status__c != newRec.Status__c && newRec.Status__c == 'Down payment collected') {salesOrderForClosureSet.add(newRec.Id); }
            ///V1.6
              System.debug('debug: in SalesOrderController.salesOrderCustEmail method');
             if (oldRec != null && oldRec.IsDownPaymentCollected__c != newRec.IsDownPaymentCollected__c && newRec.IsDownPaymentCollected__c == true) {salesOrderForClosureSet.add(newRec.Id); }
         }
        
         if (!salesOrderForClosureSet.isEmpty()) { sendRequestToXiboApi.getSurvey_Future(salesOrderForClosureSet, 'SalesOrder__c');
            
         }
    }*/

    /**
     * salesOrderCustEmail — full method replacement (V14.0)
     * ─────────────────────────────────────────────────────────────────────────────
     * Arvind Kesharwani | 09-08-2026
     * Replaced legacy Xibo future callout (sendRequestToXiboApi.getSurvey_Future)
     * ─────────────────────────────────────────────────────────────────────────────
     */
    
    
    public static void fillBucketOnSalesOrder(list<SObject> newSalesOrders) {
        Set<Id> unitIds = new Set<Id>();
        for(SalesOrder__c salesOrder : (List<SalesOrder__c>) newSalesOrders) {
            unitIds.add(salesOrder.Unit__c);
        }

        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Bucket__c FROM Unit__c WHERE Id IN :unitIds]);

        for(SalesOrder__c salesOrder : (List<SalesOrder__c>) newSalesOrders) {
            salesOrder.Bucket__c = unitMap.get(salesOrder.Unit__c) != null ? unitMap.get(salesOrder.Unit__c).Bucket__c : null;
        }
    }

    public static void removeBucketOnSalesOrderUnit(list<SObject> newSalesOrders) {
        Set<Id> unitIds = new Set<Id>();
        for(SalesOrder__c salesOrder : (List<SalesOrder__c>) newSalesOrders) {
            unitIds.add(salesOrder.Unit__c);
        }

        Unit__c[] units = [SELECT Id, Bucket__c FROM Unit__c WHERE Id IN :unitIds];
        for(Unit__c unit : units) {
            unit.Bucket__c = null;
        }

        if (!units.isEmpty())
            update units;
    }
    
    //v3.0 Added createModonEgyptDocumentRecords method to create Bulk Cheque document on the Egypt specific Sales Orders
    public static void createModonEgyptDocumentRecords(List<SObject> newList){
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        
        lstDocumentsCurrent = DocumentsUtility.getEgyptDocumentsForSObject(ModonEgyptConstants.SALES_ORDER_API_NAME, ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY);
        
        Documents__c doc;
        
        if(!lstDocumentsCurrent.isEmpty()){
            
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            
            for(SalesOrder__c sObj : (List<SalesOrder__c>)newList){
                
                for(Documents__c templateDoc: lstDocumentsCurrent){
                    doc = new Documents__c();
                    doc.Name = templateDoc.Name;
                    doc.Status__c = templateDoc.Status__c;
                    doc.GenerateDocument__c = templateDoc.GenerateDocument__c;
                    doc.SendForESignature__c = templateDoc.SendForESignature__c;
                    doc.SalesOrder__c = sObj.Id;
                    doc.Opportunity__c = sObj.Opportunity__c;
                    lstDocumentsToInsert.add(doc);   
                }   
            }       
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;   
            }   
        }   
    }

    //v8.0
    public static void processXeboSalesOrder(List<SObject> newSalesOrder,  Map<Id, SObject> oldSalesOrderMap){
        
        if(newSalesOrder == null || newSalesOrder.isEmpty()) return;
        
        Set<Id> salesOrderIds = new Set<Id>();
        
        for(SalesOrder__c rec : (List<SalesOrder__c>) newSalesOrder){
            
            SalesOrder__c oldRec = oldSalesOrderMap != null && oldSalesOrderMap.containsKey(rec.Id)
                ? (SalesOrder__c) oldSalesOrderMap.get(rec.Id)
                : null;
            
            if(rec.Status__c == ModonEgyptConstants.SALES_ORDER_STATUS_DOWNPAYMENT_COLLECTED &&
               oldRec != null &&
               rec.Status__c != oldRec.Status__c &&
               rec.source_entity__c == ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY &&
               rec.CustomerAccount__c != null){
                   
                   salesOrderIds.add(rec.Id);
               }
        }
        
        if(!salesOrderIds.isEmpty()){
            System.enqueueJob(new XeboIntegration(salesOrderIds));
        }
    }

    /**
     * Validates that a Unit is not already associated with another active Sales Order
     * (excluding Cancelled and Voided records) to prevent duplicate bookings.
     * 
     * @param modonEgyptSalesOrders List of Sales Orders to validate.
     * 
     * version: 13.0
     */
    public static void validateUnitAvailability(SalesOrder__c[] modonEgyptSalesOrders) {

        // Collect all Unit Ids from the incoming Sales Orders.
        Set<Id> unitIds = new Set<Id>();

        for (SalesOrder__c so : modonEgyptSalesOrders) {
            if (so.Unit__c != null) {
                unitIds.add(so.Unit__c);
            }
        }

        // Map to store existing active Sales Orders by Unit for quick lookup.
        Map<Id, SalesOrder__c> existingSalesOrdersByUnit = new Map<Id, SalesOrder__c>();

        // Retrieve active Sales Orders for the requested Units.
        if (!unitIds.isEmpty()) {
            for (SalesOrder__c existingSO : [
                SELECT Id, Name, Unit__c
                FROM SalesOrder__c
                WHERE Unit__c IN :unitIds
                AND Status__c NOT IN ('cancelled', 'voided')
            ]) {
                existingSalesOrdersByUnit.put(existingSO.Unit__c, existingSO);
            }
        }

        // Validate each Sales Order against existing active bookings.
        for (SalesOrder__c so : modonEgyptSalesOrders) {
            if (so.Unit__c != null) {
                SalesOrder__c existingSO = existingSalesOrdersByUnit.get(so.Unit__c);

                // Prevent booking if the Unit is already linked to another active Sales Order.
                if (existingSO != null && existingSO.Id != so.Id) {
                    so.addError(ModonEgyptConstants.MSG_UNIT_NOT_AVAILABLE_FOR_BOOKING);
                }
            }
        }
    }
}