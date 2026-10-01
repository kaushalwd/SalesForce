/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft    
* 2.0           sivannaryana.p@modon.com     07-22-2026      LPC Process Changes 
**********************************************************************************************************************/
public without sharing class BusinessProcessHandler extends TriggerHandler {
    
    //public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){}
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){}
  
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        
        
        List<Business_Process__c> bpList = (List<Business_Process__c>) newList;
       /*
        Set<Id> chargeIds = new Set<Id>();
        for (Business_Process__c bp : bpList) {
            if (bp.Charge__c != null) {
                chargeIds.add(bp.Charge__c);
            }
        }

        if(chargeIds.isEmpty()) return;

        // Fetch related Charge records
        Map<Id, Charge__c> chargeMap = new Map<Id, Charge__c>(
            [SELECT Id, Amount__c FROM Charge__c WHERE Id IN :chargeIds]
        );

        // Set LPC Amount from Charge
        for (Business_Process__c bp : bpList) {
            if (bp.Charge__c != null && chargeMap.containsKey(bp.Charge__c)) {
              //  bp.LPC_Amount__c = chargeMap.get(bp.Charge__c).Amount__c;
            }
        }
*/
    }
    
      public override   void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
           List<Id> lpcSRIds=new List<Id>();
             List<Id> salesOrderIds=new List<Id>();
          MAP<ID,Decimal> lpcAmountMap=new MAP<ID,Decimal> ();
          for(Business_Process__c pr : (List<Business_Process__c>) newList) {
              if(pr.Type__c=='Late Payment Charge Waiver'){
                  //lpcSRIds.add(pr.ID);
                  salesOrderIds.add(pr.Sales_Order__c);
                  Decimal lpcAmmount=LPCCalculationService.getLPCBySalesOrder(pr.Sales_Order__c);
                  Decimal paidAmount=LPCCalculationService.getPaidLpcInvoiceAmount(pr.Sales_Order__c);
                  Decimal lpcAmountFinal=lpcAmmount-paidAmount;
                  if(lpcAmountFinal<=0){
                      //Need to trhow an error 
                  }
                  lpcAmountMap.put(pr.ID,lpcAmountFinal);
              }
          }
          List<Business_Process__c> bpUpdateList=new List<Business_Process__c>();
          for(ID bpID:lpcAmountMap.keySet()){
              Business_Process__c bp=new Business_Process__c();
              bp.Id=bpID;
              bp.LPC_Amount__c=lpcAmountMap.get(bpID);
              bpUpdateList.add(bp);
          }
          if(!bpUpdateList.isEmpty()){
              update bpUpdateList;
          }
         // updateSOEInstallment(salesOrderIds.get(0));
      }
    
        public void updateSOEInstallment(ID salesorderID){
            List<SalesOrderInstallments__c> soeInstallmentLIst=[SELECT Id,SO_Oracle_Party_Id__c FROM SalesOrderInstallments__c where SO_Oracle_Party_Id__c !=null and MilestoneDate__c <=TODAY and SalesOrder__c =:salesorderID];
            List<SalesOrderInstallments__c> soeInstallmentLIstUpdate=new List<SalesOrderInstallments__c>();
           
            for(SalesOrderInstallments__c soeInstallment:soeInstallmentLIst) {
                SalesOrderInstallments__c insertSOE=new SalesOrderInstallments__c();
                insertSOE.ID=soeInstallment.ID;
                insertSOE.LPC_Freeze_Start_Date__c= Date.today();
                insertSOE.LPC_Freeze_End_Date__c=Date.today().addDays(30);
                soeInstallmentLIstUpdate.add(insertSOE);
            }
            update soeInstallmentLIstUpdate;
        }
    
  

    public override  void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) { 
        Map<Id, Business_Process__c> bpMap=new Map <Id, Business_Process__c>();
        Map<Id, Business_Process_Step__c> bpStepMap=new Map <Id, Business_Process_Step__c>();
        List<Id> bpStepList=new List<Id>();
        for(Business_Process__c pr : (List<Business_Process__c>) newList) {
            if(oldMap!=null && pr.Legal_Status__c!=null && pr.Legal_Status__c=='Open Collections Step'){
             Business_Process__c oldPr = (Business_Process__c) oldMap.get(pr.Id);
                if(oldPr.Legal_Status__c!='Open Collections Step' && oldPr.Legal_Status__c!='Open External Counsel' && pr.Current_Business_Process_Step__c!=null 
                   && pr.Current_Business_process_StepName__c=='Legal Discussions'){
                    bpMap.put(pr.Id,pr); 
                       bpStepList.add(pr.Current_Business_Process_Step__c);
                   }
            }
        }
        if(bpMap.isEmpty()) return;
       
        for(Business_Process_Step__c step:[Select Id, Business_Process__c from Business_Process_Step__c where Business_Process__c IN:bpMap.keySet() and Business_Process_Steps_Name_Custom__c='Collections Customer Negotiations']){
           bpStepMap.put(step.Business_Process__c, step);
            
        }
        if(bpStepMap.isEmpty()) return;
        LwcApproveRejectBpstepController.requestForMoreInfoMultipleSteps(bpStepList, bpStepMap.values()[0].Id,'Legal Team asked to reOpen');
    
    }

}