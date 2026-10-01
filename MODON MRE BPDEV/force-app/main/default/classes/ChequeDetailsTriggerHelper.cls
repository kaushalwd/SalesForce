/**********************************************************************************************************************
* Name               : ChequeDetailsTriggerHelper                                                        
* Description        : This class is used to handle all the Sales Order trigger instances
* Usage              : Called from ChequeDetailsTrigger
* Created By         : Hanmanthu kottala                                                  
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           hanmanthu kottala        28 July 2025     Initial Draft       
******************************************************************************************************************/

public class ChequeDetailsTriggerHelper {
    public Final Static Set<String> SO_Status = new Set<String> {'Completed', 'Cancelled', 'Cancelled SR', 'Voided'};
        public Final Static Set<String> SOI_status = new Set<String> {'Not Paid', 'Partially Paid'};   
            
            public static void addDefaultLookups(List<Cheque_Details__c> newList , Map <Id, Sobject> oldMap) {
                Set<String> unitNames = new Set<String>();
                Map<String, List<Date>> customerNamesByDate = new Map<String, List<Date>> (); 
                
                for(Cheque_Details__c thisDetails : newList) { 
                    if(thisDetails.UnitName__c != null) {
                        unitNames.add(thisDetails.UnitName__c);
                    }
                    system.debug(Trigger.isUpdate+'ispdate'+thisDetails.Sales_Order__c);
                    if((thisDetails.Cheque_Issuer__c != null && thisDetails.Cheque_Date__c != null && oldMap == null ) ||  ( thisDetails.Sales_Order__c == null && oldMap != null)) {
                        
                        if(!customerNamesByDate.containsKey(thisDetails.Cheque_Issuer__c.toUpperCase())) {
                            customerNamesByDate.put(thisDetails.Cheque_Issuer__c.toUpperCase(), new List<Date>()); 
                        } 
                        customerNamesByDate.get(thisDetails.Cheque_Issuer__c.toUpperCase()).add(thisDetails.Cheque_Date__c);
                    }
                }
                
                if(!unitNames.isEmpty()) {
                    Map<String, Id> unitNameById = new Map<String, Id> ();                     
                    String query = 'SELECT ' + Utility.getAllFields('Unit__c') + ' FROM Unit__c  WHERE Name IN :unitNames';
                    
                    for(Unit__c thisUnit : (List<Unit__c>) Database.queryWithBinds(
                        query,
                        new Map<String, Object>{ 'unitNames' => unitNames },
                        AccessLevel.SYSTEM_MODE
                    )) {
                        system.debug('thisUnit.Name'+thisUnit.Name);
                        unitNameById.put(thisUnit.Name.toUpperCase(), thisUnit.Id);
                    }
                    
                    for(Cheque_Details__c thisDetails : newList) {
                        if(thisDetails.UnitName__c != null && unitNameById.containsKey(thisDetails.UnitName__c.toUpperCase())) {
                            thisDetails.Unit__c = unitNameById.get(thisDetails.UnitName__c.toUpperCase()) != null ? unitNameById.get(thisDetails.UnitName__c.toUpperCase()) : thisDetails.Unit__c;
                        }
                    }
                    
                }
                
                if(!customerNamesByDate.isEmpty()) {
                    system.debug('customerNamesByDate'+customerNamesByDate);
                    try{
                        Map<String, SalesOrder__c> customerNamebyOrder = new Map<String, SalesOrder__c>();
                        for(SalesOrder__c thisOrder : [SELECT Id, Name, Unit__c, Unit__r.Name, CustomerAccount__r.Name, (SELECT Id, Name, MilestoneDate__c, MilestoneNumber__c  FROM Sales_Order_Installments__r WHERE PaymentStatus__c IN: SOI_STATUS ) 
                                                       FROM SalesOrder__c WHERE CustomerAccount__r.Name IN: customerNamesByDate.keySet() AND Status__c NOT IN:SO_Status ORDER BY SOCreationDate__c ASC]) {
                                                           customerNamebyOrder.put(thisOrder.CustomerAccount__r.Name.toUpperCase(), thisOrder);
                                                       }
                         system.debug('customerNamebyOrder'+customerNamebyOrder);
                        if(!customerNamebyOrder.isEmpty()) {
                            for(Cheque_Details__c thisDetails : newList) {
                                if(thisDetails.Cheque_Issuer__c != null && customerNamebyOrder.containsKey(thisDetails.Cheque_Issuer__c.toUpperCase())) {
                                    SalesOrder__c thisOrder = customerNamebyOrder.get(thisDetails.Cheque_Issuer__c.toUpperCase());
                                    thisDetails.Sales_Order__c = thisOrder.Id;
                                    thisDetails.Unit__c = thisDetails.Unit__c == null ? thisOrder.Unit__c : thisDetails.Unit__c;
                                    thisDetails.UnitName__c = thisDetails.UnitName__c == null ? thisOrder.Unit__r.Name : thisDetails.UnitName__c;
                                    thisDetails.Account__c = thisOrder.CustomerAccount__c;
                                    for(SalesOrderInstallments__c thisInstallment : thisOrder.Sales_Order_Installments__r) {
                                        Date endDate = thisDetails.Cheque_Date__c.addDays(5);
                                        Date startDate = thisDetails.Cheque_Date__c.addDays(-5);
                                        if(startDate <= thisInstallment.MilestoneDate__c && thisInstallment.MilestoneDate__c <= endDate) {
                                            thisDetails.MileStoneNumber__c = String.valueOf(thisInstallment.MilestoneNumber__c);
                                            thisDetails.Sales_Order_Installment__c = thisInstallment.Id;
                                        }
                                    }
                                }
                            }
                        }
                        
                        
                    } catch(Exception ex) { 
                        System.debug(ex.getMessage());
                    }            
                }
            }
}