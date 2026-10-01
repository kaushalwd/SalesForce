/**********************************************************************************************************************
    * Name               : SalesOrderTriggerHandler                                                         
    * Description        : Handles all Sales Order trigger events (merged: PROD + DEV)
    * Usage              : Called from SalesOrderTrigger
    * Created By         : PwC Digital Middle East
    * Last Modified By   : Fatima Khan 
    * Last Modified Date : 07 Apr 2026
    * --------------------------------------------------------------------------------------------------------------------
    * Version  Author                       Date            Comment                                                                       
    * 1.0      abdallah.hdaib@pwc.com       22 Jan 2023     Initial Production Draft
    * 2.0      Fatima Khan                  14 Oct 2025     Integrated SLA + Automation logic while preserving PROD stability
    * 3.0      Shahil Sinha (Horizontal)    30 Dec 2025     Implemented changes related to Sakneen Integration
    * 3.1      Shahil Sinha (Horizontal)    15 Jan 2025     Fixed Sakneen sync - Use Trigger context to bypass TriggerHandler processedIds filtering
    * 3.2      Shahil Sinha (Horizontal)    23 Jan 2026     Removed the call to the filter method from OpportunityFilterHelper and moved the required logic into SalesOrderFilterHelper.
    * 4.0      suresh.bhethi@amgs.com       16 DEC 2025     SPA FinalCopy added
    * 5.0      Shahil Sinha (Horizontal)    11 Feb 2026     Calling createModonEgyptDocumentRecords method to create Bulk Cheque document on the Egypt specific Sales Orders
    * 6.0      Dinesh                       04 Feb 2026     Adding By Pass logic for SLA related changes for the Property Transfer SR
    * 7.0      suresh.bhethi@amgs.com       09 MAR 2026     Added the new feature - PDC SLA Timer
    * 8.0      Fatima Khan                  07 Apr 2026     Removed Round Robin Functions for Matrix Based Assignment
    * 10.0      Mirza Baig                   25 Apr 2026     Moved the method 'removeBucketOnSalesOrderUnit' under condition, so it will only run for MRE.
    * 11.0      Mirza Baig                   20 Apr 2026     Calling the helper to send the data to Xebo in after update method.
    * 12.0      Manoj Vallapuneni            03 May 2026     Bypass the cancellation trigger logic
    * 13.0      Mirza Baig                   02 May 2026     Moved the method 'manageJointOwner' under condition, so it will only run for MRE.
    * 13.1      Mirza Baig                   12 May 2026     Moved the method 'createDocumentRecords' outside condition, so it will only run for both MIRE and MRE.
	* 14.0		Manoj						 17 May 2026	 Bypass the cancellation
	* 15.0      Narendra Agrawal            12 May 2026     Moved the method 'createDocumentRecords' back inside condition, so it will only run for MRE.
    * 17.0      Mirza Baig                  03 Aug 2026      Introduce a duplicate booking validation on sales order creation.
    * 18.0      Arvind                      21 Aug 2026     Comment to send the survey from Helper
    **********************************************************************************************************************/
    public without sharing class SalesOrderTriggerHandler extends TriggerHandler {
    
    
        public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
            List<SalesOrder__c> soList = (List<SalesOrder__c>) newList;
    
            /* PROD */
            SalesOrderTriggerHelper.updateCommaSeparatedField(newList);
            SalesOrderTriggerHelper.PreventSalesOrderForDefaulted(newList);
            SalesOrderTriggerHelper.populateAmountText(newList);
            SalesOrderTriggerHelper.fillBucketOnSalesOrder(newList);
    
            /* DEV */
          //v3.2 (line 32-34)
            //Map<String, Object> filteredSalesOrder = Modon_Egypt_OpportunityFilterHelper.filterAfterUpdateMethodSO(newList);
            Map<String, Object> filteredSalesOrder = Modon_Egypt_SalesOrderFilterHelper.filterBeforeInsert(newList, newMap);
            List<SalesOrder__c> otherSalesOrder = (List<SalesOrder__c>) filteredSalesOrder.get('OtherSalesOrders');
            if (!otherSalesOrder.isEmpty()) {
                /* 8.0: Uncommenting assignToQueueMembers so Associate fields are assigned */
                SalesOrderSLAHelper.assignToQueueMembers(newList, null, 'beforeInsert');
                SalesOrderStatusAutomationHelper.handlePDCCollectedSts(newList, null); 
                SalesOrderTriggerHelper.pdcSLA(newList);    //v7.0
            }
        }
    
        public override void beforeUpdateMethod(
            List<SObject> newList,
            Map<Id, SObject> newMap,
            List<SObject> oldList,
            Map<Id, SObject> oldMap
        ) {
            //v3.2 (line 48-50)
            //Map<String, Object> filteredSalesOrder = Modon_Egypt_OpportunityFilterHelper.filterAfterUpdateMethodSO(newList);
            Map<String, Object> filteredSalesOrder = Modon_Egypt_SalesOrderFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
            List<SalesOrder__c> otherSalesOrder = (List<SalesOrder__c>) filteredSalesOrder.get('OtherSalesOrders');


    
            /* PROD */
            SalesOrderTriggerHelper.populateAmountText(newList);
            SalesOrderTriggerHelper.populateCompletionDate(newList, oldMap);
            List<SalesOrder__c> oldSos = (List<SalesOrder__c>)oldList;// by raghu gajjela
            // SalesOrderTriggerHelper.salesOrderCustEmail(newList,oldSos);// 18 Arvind
            
            /* DEV */
           if (!otherSalesOrder.isEmpty()) {
			   if(!TriggerControl.bypassTransferTrigger && !TriggerControl.BypassCancelledTrigger ){ // 6.0 and 12.0 Bypass logic 
                  SalesOrderSLAHelper.assignToQueueMembers(Trigger.new, Trigger.oldMap, 'beforeUpdate');
               }
            SalesOrderStatusAutomationHelper.handlePDCCollectedSts(newList, oldMap); 
           }
        }
    

        public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
            


            SalesOrderTriggerHelper.shareVIPSalesOrder(newMap);

            
            //v3.2 (line 75-77)
            //Map<String, Object> filteredSalesOrder = Modon_Egypt_OpportunityFilterHelper.filterAfterUpdateMethodSO(newList);
            Map<String, Object> filteredSalesOrder = Modon_Egypt_SalesOrderFilterHelper.filterAfterInsert(newList, newMap);
            List<SalesOrder__c> otherSalesOrder = (List<SalesOrder__c>) filteredSalesOrder.get('OtherSalesOrders');
            if (!otherSalesOrder.isEmpty()) {
                SalesOrderTriggerHelper.createDocumentRecords(newList);//v12.1
                SalesOrderTriggerHelper.manageJointOwner(newList);//v12.0
                SalesOrderTriggerHelper.removeBucketOnSalesOrderUnit(newList);//v10.0
                List<SalesOrder__c> soList = (List<SalesOrder__c>) otherSalesOrder;


                /* DEV */
                SalesOrderStatusAutomationHelper.handleApprovalStatusonNewCreation(newList);                
                // 8.0 Remove RR Functions
                SalesOrderSLAHelper.createOrderSLAs(soList, null, false);
            }
    



            // v3.0 (line 94 - 97) Horizontal changes related to Sakneen integration
            List<SalesOrder__c> modonEgyptSalesOrders = (List<SalesOrder__c>) filteredSalesOrder.get('ModonEgyptSalesOrders');
            if (!modonEgyptSalesOrders.isEmpty()) {

                //v5.0 Calling createModonEgyptDocumentRecords method to create Bulk Cheque document on the Egypt specific Sales Orders
                SalesOrderTriggerHelper.createModonEgyptDocumentRecords(modonEgyptSalesOrders);
                SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(modonEgyptSalesOrders , 'CREATE');
                SalesOrderTriggerHelper.validateUnitAvailability(modonEgyptSalesOrders);//v17.0
            }
        }
    

        public override void afterUpdateMethod(
            List<SObject> newList,
            Map<Id, SObject> newMap,
            List<SObject> oldList,
            Map<Id, SObject> oldMap
        ) {
            //v3.2 (line 108)
            //Map<String, Object> filteredSalesOrder = Modon_Egypt_OpportunityFilterHelper.filterAfterUpdateMethodSO(newList);
    
            //v3.1 (line 111 - 115) Fixed Sakneen sync - Use Trigger context to bypass TriggerHandler processedIds filtering
            // since, the actual parameters returns null if same records gets updated twice in a single transaction
            Map<String, Object> filteredSalesOrder = Modon_Egypt_SalesOrderFilterHelper.filterAfterUpdate(Trigger.new, 
                Trigger.newMap, 
                Trigger.old, 
                Trigger.oldMap);
    
            //v3.0 (line 118 - 123) Horizontal changes related to Sakneen integration
            List<SalesOrder__c> modonEgyptSalesOrders = (List<SalesOrder__c>) filteredSalesOrder.get('ModonEgyptSalesOrders');
            if (!modonEgyptSalesOrders.isEmpty()) {
                List<SalesOrder__c> modonEgyptUnitsToSyncWithSakneen = SalesOrderTriggerHandlerUtility.filterSalesOrderForSakneenSync(modonEgyptSalesOrders, Trigger.newMap,  Trigger.oldMap);
                SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(modonEgyptUnitsToSyncWithSakneen , 'UPDATE');
                
                //v11.0 Calling the helper with new and old data
                SalesOrderTriggerHelper.processXeboSalesOrder(newList, oldMap);
            }
            List<SalesOrder__c> otherSalesOrder = (List<SalesOrder__c>) filteredSalesOrder.get('OtherSalesOrders');
    
            
    
            List<SalesOrder__c> soList = (List<SalesOrder__c>) newList;
            List<SalesOrder__c> soToRecalc = new List<SalesOrder__c>();
    
            if (!otherSalesOrder.isEmpty()) {
                /* PROD */
                SalesOrderTriggerHelper.updatUnitStatusBasedonSOStatus(newList, newMap, oldList, oldMap);
               if(!TriggerControl.bypassTransferTrigger && !TriggerControl.BypassCancelledTrigger ){ //14.0
                    SalesOrderTriggerHelper.sendSalesOrdersToOracle(newMap, oldMap);
                }
                SalesOrderTriggerHelper.shareVIPSalesOrder(newMap);
                SalesOrderTriggerHelper.createNewServiceRequestBasedOnSoStatus(newList);
                SalesOrderStatusAutomationHelper.handleSpaDocs(newList,oldMap);
                SalesOrderTriggerHelper.sendCounterSignedSPA(newList, newMap, oldList, oldMap);
                /* DEV */
               /*  SalesOrderTriggerHelper.handleCommunityUsers(newList, oldMap);
                UserAccessHelper.handleUserAccess(newList, oldMap); */
    
                if(!TriggerControl.bypassTransferTrigger && !TriggerControl.BypassCancelledTrigger ){ // 6.0 and 12.0 Bypass logic 

                    for (SalesOrder__c so : soList) {
                        if (so.Sub_Status__c == 'Pending With Sales') {
                            Boolean shouldRunChecklist = false;
                            
                            if (!so.Is_Sales_Checklist_Completed__c)
                                shouldRunChecklist = true;
                            else if (!DocumentChecklistCheckboxHelper.validateSalesTeamChecklistOnly(so.Id))
                                shouldRunChecklist = true;
                            
                            if (shouldRunChecklist){
                                System.debug('[SalesOrderSLAHelper][handleChecklist][START]');
                                DocumentChecklistCheckboxHelper.handleChecklist(so.Id);
                            }
                        }
                    }
                    SalesOrderSLAHelper.createOrderSLAWhenOwnerUpdated(newList, oldMap);
                    SalesOrderSLAHelper.orderClosedCloseSLA(newList, oldMap);
                    SalesOrderSLAHelper.closeSLAOnTeamChange(newList, oldMap);
                    SalesOrderSLAHelper.createOrderCMSLA((List<SalesOrder__c>) newList, oldMap);
                }
            }
        }
    }