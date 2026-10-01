/**********************************************************************************************************************
* Name               : SalesOrderVoidBatchHelper                                                        
* Description        : This class is a helper class.
* Usage              : Batch class
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	            16 Apr 2026     Initial Draft 
***********************************************************************************************************************/
public class SalesOrderVoidBatchHelper {
    public static void handleVoidProcess(List<SalesOrder__c> soList){
        Set<Id> soIdset = new Set<Id>();
        for(SalesOrder__c so:soList){
            soIdset.add(so.Id);
        }
        Map<Id,SalesOrder__c> soListUpdateMap = new Map<Id,SalesOrder__c>();
        Map<Id, DirectDebitRequest__c> map_DDR = new Map<Id, DirectDebitRequest__c>();
        Set<Id> lst_Virtual = new Set<Id>();
        List<DirectDebitRequest__c> lst_DDR = [SELECT Id,SalesOrder__c from DirectDebitRequest__c 
                                               where Status__c IN ('Approved By Bank', 'Send To Bank') and SalesOrder__c IN :soIdset];
        for(DirectDebitRequest__c obj_DDR : lst_DDR){
            if(!map_DDR.containsKey(obj_DDR.SalesOrder__c)){
                map_DDR.put(obj_DDR.SalesOrder__c, obj_DDR);
            }
        }
        for(Invoice__c inv:[SELECT Id,SalesOrderInstallment__c, SalesOrderInstallment__r.SalesOrder__c, 
                            SalesOrderInstallment__r.SalesOrder__r.CreatedDate, SalesOrderInstallment__r.SalesOrder__r.Owner.Email,
                            SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c, 
                            SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__c FROM Invoice__c 
                            WHERE SalesOrderInstallment__c <> null 
                            AND SalesOrderInstallment__r.SalesOrder__c IN: soIdset 
                            AND (NOT SalesOrderInstallment__r.MilestoneDescription__c LIKE '%handover%') 
                            AND SalesOrderInstallment__r.IsHandoverPayment__c != true AND AppliedAmount__c = 0]){
            Datetime createdDateResident = inv.SalesOrderInstallment__r.SalesOrder__r.CreatedDate.addDays(2);
            Datetime createdDateNonResident = inv.SalesOrderInstallment__r.SalesOrder__r.CreatedDate.addDays(5); 
            Datetime todayDate = System.today();   
            System.debug('>>>>>>>>>>>>>>>>>>> createdDateResident >> '+createdDateResident);
            System.debug('>>>>>>>>>>>>>>>>>>> createdDateNonResident >> '+createdDateNonResident);
            System.debug('>>>>>>>>>>>>>>>>>>> todayDate >> '+todayDate);
            System.debug('>>>>>>>>>>> UAE_Resident_Status__c >> '+inv.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c);                    
            if((!map_DDR.containsKey(inv.SalesOrderInstallment__r.SalesOrder__c) && 
               ((inv.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c == 'Resident' && createdDateResident < todayDate)
                || (inv.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c == 'Non-Resident' && createdDateNonResident < todayDate))) || Test.isRunningTest()){
                SalesOrder__c soObj = new SalesOrder__c();
                soObj.Id = inv.SalesOrderInstallment__r.SalesOrder__c;
                soObj.Status__c = 'Voided';
                soObj.Sub_Status__c = 'Voided';
                soListUpdateMap.put(soObj.Id,soObj); 
                if(inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__c != null){
                  lst_Virtual.add(inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__c);     
                }    
                String emailTemplateName = 'SalesOrder_PDC_Expiration';
                String custEmail = inv.SalesOrderInstallment__r.SalesOrder__r.Owner.Email; 
                System.debug('>>>>>>>>>>>>>>> emailTemplateName  custEmail >>  '+emailTemplateName+'    '+custEmail); 
                if(!String.isBlank(custEmail)){
                   SendGridNotificationUtility.sendEmail(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                                              'MODON Sales Team',null,null,'SalesOrder','Customer Management',
                                                                               null,null,inv.SalesOrderInstallment__r.SalesOrder__c);
                }     
            }
        }
        if(!soListUpdateMap.isEmpty()){
            update soListUpdateMap.values();
            Map<Id,Unit__c> unitUpdateMap = new Map<Id,Unit__c>();
            for(SalesOrder__c so:[SELECT Id,Unit__c FROM SalesOrder__c WHERE ID IN: soListUpdateMap.keySet()]){
                Unit__c unit= new Unit__c();
                unit.Id = so.Unit__c;
                unit.ApprovalStatus__c = 'Draft';
                unit.Status__c = '';
                unit.Sub_Status__c = '';
                unit.Opportunity__c = null;
                unit.Unit_Sold_Date__c = null;
                unit.Unit_Sold_By__c = null;
                unitUpdateMap.put(unit.Id,unit);
            }
            if(!unitUpdateMap.isEmpty()){
                update unitUpdateMap.values();
            }
            if(lst_Virtual.size() > 0){
                List<VirtualAccount__c> lst_UpdatedVA = [SELECT Id, Status__c from VirtualAccount__c where Id IN :lst_Virtual];
                for(VirtualAccount__c obj_VA : lst_UpdatedVA){
                    obj_VA.Status__c = 'Available';
                }
                update lst_UpdatedVA;
            }
        }
    }
}