/**********************************************************************************************************************
* Name               : DirectDebitLWCController                                                        
* Description        : This class is used to handle all the methods for Direct Debit UI
* Usage              : Called from LWC
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      19 Feb 2025     Initial Draft 
* 2.0           Suresh                      13 Oct 2025     UI changes
* 3.0           Suresh                      29 Nov 2025     DD Charge Status update
******************************************************************************************************************/
public without sharing class DirectDebitLWCController {

    public class DirectDebitCollectionWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public SalesOrderInstallments__c soInstallment;
        @AuraEnabled public String ddOwnerName;
    }
    
    @AuraEnabled
    public static String createDirectDebitTransaction(String soInstallmentsId) {
        System.debug('DirectDebitLWCController >>>>  createDirectDebitTransaction >> soInstallmentsId >> '+soInstallmentsId);
        Set<Id> set_SOIID = new Set<Id>();
        Set<Id> set_SalesOrderId = new Set<Id>();
        List<SalesOrderInstallments__c> lst_SOI = new List<SalesOrderInstallments__c>();
        List<DirectDebit_Transactions__c> lst_DDTransaction = new List<DirectDebit_Transactions__c>();
        List<DirectDebitRequest__c> lst_DD = new List<DirectDebitRequest__c>();
        Map<String, DirectDebitRequest__c> map_DD = new Map<String, DirectDebitRequest__c>();
        try{
            if(!String.isBlank(soInstallmentsId)){
                set_SOIID = (Set<Id>)System.JSON.deserialize(soInstallmentsId, Set<Id>.class);
                if(set_SOIID.size() > 0){
                    lst_SOI = [select Id, Name, InstallmentAmount__c, Instalment_Number__c, InstalmentPaymentDueDate__c, 
                                             IsHandoverPayment__c, Milestone__c, MilestoneDate__c, MilestoneDescription__c, 
                                             MilestoneNumber__c, PaymentStatus__c, SalesOrder__c, SalesOrder__r.Direct_Debit_Request__c,
                                             SalesOrder__r.Direct_Debit_Request__r.Approve__c 
                                             from SalesOrderInstallments__c where PaymentStatus__c != 'Paid'
                                             and Id IN :set_SOIID];
                    for(SalesOrderInstallments__c obj_SOI : lst_SOI){
                        set_SalesOrderId.add(obj_SOI.SalesOrder__c);
                    }
                    if(set_SalesOrderId.size() > 0){
                       lst_DD = [select Id, DDA_Unique_Number__c, Status__c, isActive__c, IsSubmitted__c, SalesOrder__c, CustomerAccountName__c 
                                 from DirectDebitRequest__c where isActive__c = true and IsSubmitted__c = true 
                                 and DDA_Unique_Number__c != '' and Status__c = 'Approved By Bank' 
                                 and SalesOrder__c IN :set_SalesOrderId]; 
                        for(DirectDebitRequest__c obj_DD : lst_DD){
                            if(obj_DD.SalesOrder__c != null && !map_DD.containsKey(obj_DD.SalesOrder__c)){
                                map_DD.put(obj_DD.SalesOrder__c, obj_DD);
                            }
                        }
                    }
                    for(SalesOrderInstallments__c obj_Installment : lst_SOI){
                        if(obj_Installment.SalesOrder__c != null && map_DD != null && map_DD.containsKey(obj_Installment.SalesOrder__c)){
                           DirectDebitRequest__c obj_DD = map_DD.get(obj_Installment.SalesOrder__c); 
                           DirectDebit_Transactions__c obj_DDTransaction = new DirectDebit_Transactions__c();
                           obj_DDTransaction.Direct_Debit_Request__c =  obj_DD.Id;
                           obj_DDTransaction.Collection_Amount__c = obj_Installment.InstallmentAmount__c;
                           obj_DDTransaction.Currency__c = 'AED';
                           obj_DDTransaction.Request_Type__c = 'Collection';
                           obj_DDTransaction.SOInstallment__c = obj_Installment.Id;
                           obj_DDTransaction.Transaction_Status__c = 'Initiated';
                           lst_DDTransaction.add(obj_DDTransaction); 
                        }
                                
                    }
                    if(lst_DDTransaction.size() > 0){
                        insert lst_DDTransaction;
                    }
                }
            }
            return 'Success';
        }catch(Exception exe){
            return 'Failure :  '+exe.getMessage();
        }        
    }    
    
    @AuraEnabled(cacheable=false)
    public static List<DirectDebitCollectionWrapper> getSalesOrderInstallments(String query, Integer rowLimit, Integer rowOffSet){
        
        List<DirectDebitCollectionWrapper> lst_DDCollectionWrapper = new List<DirectDebitCollectionWrapper>();
        Set<Id> set_SalesOrderId = new Set<Id>();
        Set<Id> set_SOIId = new Set<Id>();
        List<DirectDebitRequest__c> lst_DD = new List<DirectDebitRequest__c>();
        List<DirectDebit_Transactions__c> lst_DDT = new List<DirectDebit_Transactions__c>();
        Map<String, DirectDebitRequest__c> map_DD = new Map<String, DirectDebitRequest__c>();
        Map<String, DirectDebit_Transactions__c> map_SOIDDT = new Map<String, DirectDebit_Transactions__c>();
        try{
            query = query+' ORDER BY SalesOrder__r.Name ASC ' ;
            
            system.debug('DirectDebitLWCController >>>> query::'+query);
            List<SalesOrderInstallments__c> lst_SalesOrderInstallments = Database.query(query);
            
            for(SalesOrderInstallments__c obj_SOI : lst_SalesOrderInstallments){
                set_SalesOrderId.add(obj_SOI.SalesOrder__c);
                set_SOIId.add(obj_SOI.Id);
            }
            lst_DDT = [SELECT Id, Transaction_Status__c, SOInstallment__c from DirectDebit_Transactions__c 
                       where (Transaction_Status__c != 'Initiated' or Transaction_Status__c != '') and SOInstallment__c IN :set_SOIId];
            for(DirectDebit_Transactions__c obj_DDT : lst_DDT){
                if(obj_DDT.SOInstallment__c != null && !map_SOIDDT.containsKey(obj_DDT.SOInstallment__c)){
                    map_SOIDDT.put(obj_DDT.SOInstallment__c, obj_DDT);
                }
            }
            if(set_SalesOrderId.size() > 0){
               lst_DD = [select Id, DDA_Unique_Number__c, Status__c, isActive__c, IsSubmitted__c, SalesOrder__c, CustomerAccountName__c
                         from DirectDebitRequest__c where isActive__c = true and IsSubmitted__c = true 
                         and DDA_Unique_Number__c != '' and Status__c = 'Approved By Bank' 
                         and SalesOrder__c IN :set_SalesOrderId]; 
                for(DirectDebitRequest__c obj_DD : lst_DD){
                    if(obj_DD.SalesOrder__c != null && !map_DD.containsKey(obj_DD.SalesOrder__c)){
                        map_DD.put(obj_DD.SalesOrder__c, obj_DD);
                    }
                }
            }
            //system.debug('DirectDebitLWCController >>>> SOInstallments >>>> '+System.JSON.serialize(lst_SalesOrderInstallments));
            if(!lst_SalesOrderInstallments.isEmpty()){
                for(SalesOrderInstallments__c obj_SOInstallment: lst_SalesOrderInstallments){
                    DirectDebitCollectionWrapper wrap = new DirectDebitCollectionWrapper();
                    if(map_DD.containsKey(obj_SOInstallment.SalesOrder__c) 
                       && (obj_SOInstallment.PaymentStatus__c == 'Not paid' || obj_SOInstallment.PaymentStatus__c == 'Partially Paid')
                       && !map_SOIDDT.containsKey(obj_SOInstallment.Id)){
                        wrap.soInstallment = obj_SOInstallment;
                        wrap.Id = obj_SOInstallment.Id;
                        wrap.ddOwnerName = map_DD.get(obj_SOInstallment.SalesOrder__c).CustomerAccountName__c;
                        lst_DDCollectionWrapper.add(wrap);
                    }
                  }
                }
            system.debug('DirectDebitLWCController >>>> SOInstallments lst_DDCollectionWrapper >>>> '+System.JSON.serialize(lst_DDCollectionWrapper));
        }catch(Exception ex){
            system.debug('DirectDebitLWCController >>>> Exception >>>> '+ex);
        } 
        return lst_DDCollectionWrapper;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Project__c> getProjectDetails(){
        list<Project__c> lst_ProjectDetails = new list<Project__c>();
        lst_ProjectDetails = [select Id, Name from Project__c order by Name asc];
        system.debug('getProjectDetails  >>>>   '+System.JSON.serialize(lst_ProjectDetails));
        return lst_ProjectDetails;
    }
    
    
    @AuraEnabled(cacheable=false)
    public static List<Unit__c> getUnitDetails(String projectNameParam){
        system.debug('getUnitDetails  >>>>   '+projectNameParam);
        list<Unit__c> lst_UnitDetails = new list<Unit__c>();
        if (String.isNotBlank(projectNameParam)) {
            lst_UnitDetails =  [select Id, Category__c, Phase__r.Project__r.Name, Model__c,Island_Name__c,Type__c, 
                                       Phase__r.Name from Unit__c where Phase__r.Project__r.Name = :projectNameParam];
        }
        return lst_UnitDetails;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Phase__c> getPhaseDetails(String projectName){ 
        list<Phase__c> lst_Phases = new list<Phase__c>();
        lst_Phases = [select Id,Name from Phase__c  where Project__r.Name = :projectName order by Name asc];
        return lst_Phases;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<SalesOrder__c> getSaleOrderDetails(String phaseName){ 
        list<SalesOrder__c> lst_SalesOrder = new list<SalesOrder__c>();
        lst_SalesOrder = [SELECT Id, Name from SalesOrder__c where Phase_Name__c = :phaseName order by Name asc];
        return lst_SalesOrder;
    }
}