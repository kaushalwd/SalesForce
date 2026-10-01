/**********************************************************************************************************************
* Name               : DirectDebitRequestTriggerHelper                                                        
* Description        : This class is used as a helper for DirectDebitRequest Trigger
* Usage              : Called from DirectDebitRequestTriggerHandler
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    22 Mar 2025     Initial Draft   
* 1.1			Suresh						16-09-2025		changes for max amount
* 1.2			Suresh						15-06-2026		Direct Debit cancellation added
* 1.3			Prateek Bansal				26-08-2026		Discarded exempted from the one mandate per Sales Order check
******************************************************************************************************************/
public with sharing class DirectDebitRequestTriggerHelper {
    
    public static Id getQueueIdByName(String queueName) {
        List<Group> lst_queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = :queueName LIMIT 1];
    
        if (!lst_queue.isEmpty()) {
            return lst_queue[0].Id;
        } else if (Test.isRunningTest()) {
            return UserInfo.getUserId(); // fallback for tests only when queue doesn't exist
        } else {
            return null;
        }
    }
    
    public static void updateDirectDebitRequest(List<SObject> newList){
        List<DirectDebitRequest__c> lst_DirectDebitRequest = new List<DirectDebitRequest__c>();
        lst_DirectDebitRequest = (List<DirectDebitRequest__c>)newList;
        Set<String> set_SalesOrder = new Set<String>();
        Map<String, SalesOrder__c> map_SOEscrow = new Map<String, SalesOrder__c>();
        List<SalesOrder__c> lst_SalesOrder = new List<SalesOrder__c>();
        for(DirectDebitRequest__c obj_DDRequest : lst_DirectDebitRequest){
            set_SalesOrder.add(obj_DDRequest.SalesOrder__c);
        }
        if(set_SalesOrder.size() > 0){
            lst_SalesOrder = [select Id, Name, VirtualAccount__r.EscrowAccount__r.Name, VirtualAccount__r.EscrowAccount__r.OIC__c 
                              from SalesOrder__c where Id = :set_SalesOrder];
            for(SalesOrder__c obj_SalesOrder : lst_SalesOrder){
                if(!map_SOEscrow.containsKey(obj_SalesOrder.Id)){
                    map_SOEscrow.put(obj_SalesOrder.Id, obj_SalesOrder);
                }
            }
        }
        for(DirectDebitRequest__c obj_DDRequest : lst_DirectDebitRequest){
            SalesOrder__c obj_SalesOrder = map_SOEscrow.get(obj_DDRequest.SalesOrder__c);
            if(obj_SalesOrder != null){
                obj_DDRequest.Originator_Name__c = obj_SalesOrder.VirtualAccount__r.EscrowAccount__r.Name;
           	    obj_DDRequest.OIC__c = obj_SalesOrder.VirtualAccount__r.EscrowAccount__r.OIC__c;
            }            
        }  
        
    }
    
    public static void updateDDRequestOwner(List<SObject> newList){
        Id ddQueueId = DirectDebitRequestTriggerHelper.getQueueIdByName('DirectDebitQueue');
        if(!String.isBlank(ddQueueId)){
            for(DirectDebitRequest__c dd: (List<DirectDebitRequest__c>) newList){
                if(dd.IsSubmitted__c){
                    dd.OwnerId = ddQueueId;
                }                
            }
        }
    }
    
    public static void validateDirectDebitRequestUniqueValidation(List<SObject> newList){
        Set<Id> salesOrderIdset = new Set<Id>();
        Set<Id> existingDDSalesOrderSet = new Set<Id>();
        for(DirectDebitRequest__c dd: (List<DirectDebitRequest__c>) newList){
            if(dd.SalesOrder__c <> null){
                salesOrderIdset.add(dd.SalesOrder__c);
            }
        }
        if(!salesOrderIdset.isEmpty()){
            // Discarded is a UAEDDS outcome: discardDDA removes the mandate from the bank, so it is
            // finished there and must not block a replacement on the same Sales Order, exactly like
            // Cancelled and Rejected By Bank. No FAB mandate carries this status.
            for(DirectDebitRequest__c dd:[SELECT Id,SalesOrder__c FROM DirectDebitRequest__c WHERE SalesOrder__c IN: salesOrderIdset AND
                                          ( NOT Status__c IN ('Cancelled','Rejected By Bank','Discarded'))]){
                existingDDSalesOrderSet.add(dd.SalesOrder__c);
            }
            if(!existingDDSalesOrderSet.isEmpty()){
                for(DirectDebitRequest__c dd: (List<DirectDebitRequest__c>) newList){
                    if(dd.SalesOrder__c <> null && existingDDSalesOrderSet.contains(dd.SalesOrder__c)){
                        dd.addError('Direct Debit Request for this Sales Order already exist !');
                    }
                }
            }
        }
    }
    public static void createDirectDebitTransaction(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        List<DirectDebit_Transactions__c> lst_DirectDebitTransactions = new List<DirectDebit_Transactions__c>();
        List<DirectDebitRequest__c> lst_DirectDebitRequest = new List<DirectDebitRequest__c>(); 
        if(oldList != null){
            lst_DirectDebitRequest = (List<DirectDebitRequest__c>)newList;
            for(DirectDebitRequest__c obj_DirectDebitRequest : lst_DirectDebitRequest){
                DirectDebitRequest__c old_DirectDebitRequest = (DirectDebitRequest__c)oldMap.get(obj_DirectDebitRequest.Id);
                //1.5 A UAEDDS mandate never raises a transaction row.
                if(obj_DirectDebitRequest.Gateway__c == 'UAEDDS'){
                    continue;
                }
                if(obj_DirectDebitRequest.Approve__c && old_DirectDebitRequest.Approve__c != obj_DirectDebitRequest.Approve__c){
                //if(obj_DirectDebitRequest.Approve__c && old_DirectDebitRequest.Approve__c != obj_DirectDebitRequest.Approve__c){
                    DirectDebit_Transactions__c obj_DDTransaction = new DirectDebit_Transactions__c();
                    obj_DDTransaction.Direct_Debit_Request__c =  obj_DirectDebitRequest.Id;
                    obj_DDTransaction.Collection_Amount__c = obj_DirectDebitRequest.Collection_Amount__c;
                    obj_DDTransaction.Currency__c = 'AED';
                    obj_DDTransaction.Request_Type__c = obj_DirectDebitRequest.Request_Type__c;
                    lst_DirectDebitTransactions.add(obj_DDTransaction);
                } else if(oldList != null && old_DirectDebitRequest.isActive__c != obj_DirectDebitRequest.isActive__c 
                          && obj_DirectDebitRequest.isActive__c == false && obj_DirectDebitRequest.Approve__c == true
                    	  && old_DirectDebitRequest.Status__c != obj_DirectDebitRequest.Status__c
                          && String.isNotBlank(obj_DirectDebitRequest.DDA_Unique_Number__c)
                          && obj_DirectDebitRequest.Status__c == 'Cancelled'){
                    //1.2 added          
                    DirectDebit_Transactions__c obj_DDTransaction = new DirectDebit_Transactions__c();
                    obj_DDTransaction.Direct_Debit_Request__c =  obj_DirectDebitRequest.Id;
                    obj_DDTransaction.Collection_Amount__c = obj_DirectDebitRequest.Collection_Amount__c;
                    obj_DDTransaction.Currency__c = 'AED';
                    obj_DDTransaction.Request_Type__c = 'Cancellation';
                    obj_DDTransaction.DDA_Reference__c = obj_DirectDebitRequest.DDA_Unique_Number__c;          
                    lst_DirectDebitTransactions.add(obj_DDTransaction); 
                } else{}
            }
        }  
        if(lst_DirectDebitTransactions.size() > 0){
            insert lst_DirectDebitTransactions;
        }
    }
    
    public static void populateCommenceAndExpireDates(List<SObject> newList) {
            List<DirectDebitRequest__c> ddRequests = (List<DirectDebitRequest__c>) newList;
        
            //Collect SalesOrder Ids
            Set<Id> salesOrderIds = new Set<Id>();
            for (DirectDebitRequest__c dd : ddRequests) {
                if(dd.Gateway__c == 'UAEDDS'){
                    continue;
                } 
                if (dd.SalesOrder__c != null) {
                    salesOrderIds.add(dd.SalesOrder__c);
                }
            }
        
            if (salesOrderIds.isEmpty()) return;
        
            //Query related SalesOrderInstallments
            Map<Id, List<SalesOrderInstallments__c>> salesOrderToInstallmentsMap = new Map<Id, List<SalesOrderInstallments__c>>();
            for (SalesOrderInstallments__c installment : [
                SELECT SalesOrder__c, MilestoneNumber__c, MilestoneDate__c, InstallmentAmount__c
                FROM SalesOrderInstallments__c
                WHERE SalesOrder__c IN :salesOrderIds
                AND MilestoneNumber__c != null
                AND MilestoneDate__c != null
                AND MilestoneNumber__c > 1
                AND PaymentStatus__c != 'Paid'
            ]) {
                if (!salesOrderToInstallmentsMap.containsKey(installment.SalesOrder__c)) {
                    salesOrderToInstallmentsMap.put(installment.SalesOrder__c, new List<SalesOrderInstallments__c>());
                }
                salesOrderToInstallmentsMap.get(installment.SalesOrder__c).add(installment);
            }
        
            //Query SalesOrder with path to BeneficiaryName__c
            Map<Id, String> salesOrderToBeneficiaryMap = new Map<Id, String>();
            for (SalesOrder__c so : [
                SELECT Id,
                       Unit__r.Phase__r.EscrowAccount__r.BeneficiaryName__c
                FROM SalesOrder__c
                WHERE Id IN :salesOrderIds
            ]) {
                if (so.Unit__r != null && 
                    so.Unit__r.Phase__r != null &&
                    so.Unit__r.Phase__r.EscrowAccount__r != null) {
                    salesOrderToBeneficiaryMap.put(so.Id, so.Unit__r.Phase__r.EscrowAccount__r.BeneficiaryName__c);
                }
            }
        
            //Assign Commences_On__c, Expires_On__c and Originator_Name__c
            for (DirectDebitRequest__c dd : ddRequests) {
                Decimal maxAmount = 0;
                Id soId = dd.SalesOrder__c;
                if (soId == null) continue;
        
                // Commence/Expire Dates
                if (salesOrderToInstallmentsMap.containsKey(soId)) {
                    List<SalesOrderInstallments__c> installments = salesOrderToInstallmentsMap.get(soId);
        			
                    if (installments != null && !installments.isEmpty()) {
                    // Sort by MilestoneNumber__c (ascending)
                    for (Integer i = 0; i < installments.size(); i++) {
                        for (Integer j = i + 1; j < installments.size(); j++) {
                            if (Integer.valueOf(installments[i].MilestoneNumber__c) > Integer.valueOf(installments[j].MilestoneNumber__c)) {
                                SalesOrderInstallments__c temp = installments[i];
                                installments[i] = installments[j];
                                installments[j] = temp;
                            }
                        }
                        if(installments[i].InstallmentAmount__c > maxAmount){
                            maxAmount = installments[i].InstallmentAmount__c;
                        }
                    }
        
                    dd.Commences_On__c = installments[0].MilestoneDate__c;
                    Date lastDate = installments[installments.size() - 1].MilestoneDate__c;
                    dd.Expires_On__c = lastDate != null ? lastDate.addDays(365) : null;
                    dd.Maximum_Amount__c = maxAmount;
                }
                }
        
                // Originator Name (Beneficiary)
                if (salesOrderToBeneficiaryMap.containsKey(soId)) {
                    dd.Originator_Name__c = salesOrderToBeneficiaryMap.get(soId);
                }
            }
	}
    
    // Send notifications on record creation
	public static void sendCreateNotifications(List<SObject> newList) {
        List<DirectDebitRequest__c> ddRequests = (List<DirectDebitRequest__c>) newList;
        System.debug('>>> sendCreateNotifications called for: ' + ddRequests);
        List<Id> recipientIds = getDirectDebitQueueUserIds();
        if (recipientIds.isEmpty()) return;
    
            for (DirectDebitRequest__c dd : ddRequests) {
                NotificationUtility.sendNotification(
                    'Direct_Debit_Assigned_Notification',
                    recipientIds,
                    true,
                    dd.Id,
                    null,
                    'New Direct Debit Request Assigned',
                    'A new Direct Debit Request has been assigned to you.',
                    dd.Id,
                    'Direct_Debit_Notification'
                );
            }
    }

    // Send notifications when Status__c is changed
    public static void sendStatusChangeNotifications(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<DirectDebitRequest__c> ddRequests = (List<DirectDebitRequest__c>) newList;
        System.debug('>>> sendStatusChangeNotifications called. New: ' + ddRequests + ', Old: ' + oldMap);
        List<Id> recipientIds = getDirectDebitQueueUserIds();
        if (recipientIds.isEmpty()) return;
    
        for (DirectDebitRequest__c dd : ddRequests) {
            system.debug('dd '+dd);
            DirectDebitRequest__c oldDD = (DirectDebitRequest__c) oldMap.get(dd.Id);
            system.debug('oldDD '+oldDD);
            if (oldDD != null && dd.Status__c != oldDD.Status__c) {
                NotificationUtility.sendNotification(
                                                       'Direct_Debit_Status_Change_Notification',
                                                        recipientIds,
                                                        true,
                                                        dd.Id,
                                                        null,
                                                        'Direct Debit Status Updated',
                                                        'The status has been changed to ' + dd.Status__c + '. Please review.',
                                                        dd.Id,
                                                        'Direct_Debit_Notification'
                );
            }
        }
    }

    // Utility: Get all user IDs from DirectDebitQueue
    private static List<Id> getDirectDebitQueueUserIds() {
        List<Id> userIds = new List<Id>();
        Id queueId = getQueueIdByName('DirectDebitQueue');
        if (String.isBlank(queueId)) return userIds;
    
        for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queueId]) {
            userIds.add(gm.UserOrGroupId);
        }
        System.debug('>>> Queue User Ids: ' + userIds);
        return userIds;
    }
}