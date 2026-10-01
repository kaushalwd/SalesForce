/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PaymentPlanImplementationController
 * Author          : Siva
 * Created Date    : Jun 7, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jun 14, 2026
 * Description     : 
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  AUG 6, 2026  │ Siva   │ Payment Plan Phase 2 Changes
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class PaymentPlanImplementationController {

  @AuraEnabled
public static String createPlan(Id requestId) {

    if(requestId == null){
        throw new AuraHandledException(
            'Request Id is required.'
        );
    }
    AccountTriggerHandler.isTriggerDisabled =true;
    PaymentPlanChangeRequest__c requestRec =
    [
        SELECT
            Id,
            Sales_Order__c,
            Sales_Order__r.CustomerAccount__c,
            Revised_Payment_Plan__c,
            Status__c
        FROM PaymentPlanChangeRequest__c
        WHERE Id = :requestId
        LIMIT 1
    ];

    if(requestRec.Status__c != 'Approved'){
        /*throw new AuraHandledException(
            'Request must be Approved.'
        );*/
    }

    List<PaymentPlanChangeLine__c> stagingLines =
    [
        SELECT
            Id,
            Existing_SO_Installment__c,
            Payment_Installment__c,
            Milestone__c,
            Amount__c,
            Locked__c, Needs_Unallocation__c,Outstanding_Amount__c, Milestone_Date__c
        FROM PaymentPlanChangeLine__c
        WHERE Change_Request__c = :requestId
    ];

    if(stagingLines.isEmpty()){
        throw new AuraHandledException(
            'No staging lines found.'
        );
    }

    Set<Id> installmentIds = new Set<Id>();
    Set<Id> paymentInstallmentIds = new Set<Id>();

    for(PaymentPlanChangeLine__c line : stagingLines){

        if(line.Existing_SO_Installment__c != null){
            installmentIds.add(
                line.Existing_SO_Installment__c
            );
        }

        if(line.Payment_Installment__c != null){
            paymentInstallmentIds.add(
                line.Payment_Installment__c
            );
        }
    }

    if(installmentIds.isEmpty()){
        SalesOrderInstallments__c soi=[Select Id from SalesOrderInstallments__c where SalesOrder__c=:requestRec.Sales_Order__c order by MilestoneNumber__c LIMIT 1 ];
        installmentIds.add(soi.Id);
    }

    Map<Id, SalesOrderInstallments__c> oldInstallmentMap =
    new Map<Id, SalesOrderInstallments__c>
    (
        [
            SELECT
                Id,
                SalesOrder__c,
                PaymentInstallments__c,
                Milestone__c,
                InstallmentAmount__c,
                PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE Id IN :installmentIds
        ]
    );

    Map<Id, PaymentInstallements__c> paymentInstallmentMap =
    new Map<Id, PaymentInstallements__c>
    (
        [
            SELECT
                Id,
                Name,
                MilestoneDate__c,
                MileStoneNumber__c,
                MilestoneDescription__c
            FROM PaymentInstallements__c
            WHERE Id IN :paymentInstallmentIds
        ]
    );

    List<SalesOrderInstallments__c> newInstallments =
        new List<SalesOrderInstallments__c>();

    List<SalesOrderInstallments__c> oldInstallmentsToUpdate =
        new List<SalesOrderInstallments__c>();

    for(PaymentPlanChangeLine__c line : stagingLines){

        /*
         * Paid / Partially Paid
         * Keep untouched
         */
        if(line.Locked__c){
            continue;
        }

        if(line.Needs_Unallocation__c){
            // write un allocate logic 
        }

        
        SalesOrderInstallments__c oldInst =line.Existing_SO_Installment__c !=null ?
            oldInstallmentMap.get(
                line.Existing_SO_Installment__c
            ): oldInstallmentMap.get(installmentIds.iterator().next());
         
       // SalesOrderInstallments__c oldInst =oldInstallmentMap.get(line.Existing_SO_Installment__c);

        if(oldInst == null){
            continue;
        }

        SalesOrderInstallments__c newInst =
            oldInst.clone(
                false,
                true,
                false,
                false
            );

        /*
         * Selected Payment Plan Installment
         */
        PaymentInstallements__c ppInst =
            paymentInstallmentMap.get(
                line.Payment_Installment__c
            );

        newInst.PaymentInstallments__c =
            line.Payment_Installment__c;

        newInst.Milestone__c =
            line.Milestone__c;

        newInst.InstallmentAmount__c =
            line.Amount__c;
         newInst.PaymentStatus__c='Not Paid'; 
        if(ppInst != null){

            if(line.Milestone_Date__c != null){
        newInst.MilestoneDate__c =line.Milestone_Date__c;
           }
       else{
        newInst.MilestoneDate__c = ppInst.MilestoneDate__c;
       }

            newInst.MilestoneNumber__c =
                ppInst.MileStoneNumber__c;
            newInst.MilestoneDescription__c=ppInst.MilestoneDescription__c;

        }

        newInstallments.add(newInst);

        /*
         * Mark old installment inactive
         */
        SalesOrderInstallments__c insta =
            new SalesOrderInstallments__c(
                Id = oldInst.Id,
                IsSuperseded__c = true
            );

        oldInstallmentsToUpdate.add(insta);
    }

    if(!newInstallments.isEmpty()){
        insert newInstallments;
    }

    if(!oldInstallmentsToUpdate.isEmpty()){
       // update oldInstallmentsToUpdate;
    }

    /*
     * Update Sales Order Payment Plan
     */
    SalesOrder__c so =
        new SalesOrder__c(
            Id = requestRec.Sales_Order__c,
            PaymentPlan__c =
                requestRec.Revised_Payment_Plan__c
        );

    update so;
    Account  acc=new Account(Id=requestRec.Sales_Order__r.CustomerAccount__c, 
    Is_Employee_Payment_Plan_Applied__c =true  );
    update acc;

    /*
     * Mark Request Implemented
     */
    requestRec.Status__c =
        'Implemented';

    update requestRec;
    cancelInvoicesOrDeleteSOI(requestRec.Id);
    return 'Success';
}

//@future
Public static void cancelInvoicesOrDeleteSOI(Id requestId ){
    
    PaymentPlanChangeRequest__c requestRec =
    [
        SELECT
            Id,
            Sales_Order__c,
            Existing_Payment_Plan__c,
            Revised_Payment_Plan__c,
            Status__c
        FROM PaymentPlanChangeRequest__c
        WHERE Id = :requestId
        LIMIT 1
    ];
   
     List<PaymentPlanChangeLine__c> stagingLines =
    [
        SELECT
            Id,
            Existing_SO_Installment__c,
            Payment_Installment__c,
            Milestone__c,
            Amount__c,
            Locked__c, Needs_Unallocation__c,Outstanding_Amount__c
        FROM PaymentPlanChangeLine__c
        WHERE Change_Request__c = :requestId
    ];

    Set<Id> lockedSOIIds=new Set<Id> ();
    for(PaymentPlanChangeLine__c line:stagingLines){
           if(line.Locked__c){
            lockedSOIIds.add(line.Existing_SO_Installment__c);
           }
    }
    List<SalesOrderInstallments__c> unPaidList=new List<SalesOrderInstallments__c>();
    List<SalesOrderInstallments__c> partailList=new List<SalesOrderInstallments__c>();
    Set<Id> cancelIds=new Set<Id>();
    for(SalesOrderInstallments__c soi:   [ SELECT
                Id,
                SalesOrder__c,
                PaymentInstallments__c,
                Milestone__c,
                InstallmentAmount__c,
                PaymentStatus__c
            FROM SalesOrderInstallments__c where SalesOrder__c=:requestRec.Sales_Order__c and PaymentInstallments__r.PaymentInstallment__c=:requestRec.Existing_Payment_Plan__c]){             
                if(soi.PaymentStatus__c!='Paid'){
                   cancelIds.add(soi.Id);
                   unPaidList.add(soi); //need to keep buffer amount logic here
                 }
                 
            }
     List<Invoice__c> invoiceList= [Select Id from Invoice__c where SalesOrderInstallment__c IN : cancelIds];
     List<Invoice__c> invoiceUpdateList=new List<Invoice__c>();
     for(Invoice__c inv:invoiceList){
        invoiceUpdateList.add(new Invoice__c(Id=inv.Id, isCancelled__c=true,PaymentPlanChangeRequest__c=requestRec.ID));
     }

     if(invoiceUpdateList.size()>0)
     update invoiceUpdateList;
    
    if(unPaidList.size()>0){
        List<SalesOrderInstallments__c> deleteSOIList=new List<SalesOrderInstallments__c>();
        for(SalesOrderInstallments__c soi: unPaidList){
            SalesOrderInstallments__c deleteSOI=new SalesOrderInstallments__c();
            deleteSOI.ID=soi.ID;
            deleteSOIList.add(deleteSOI);
         }  
         delete deleteSOIList;
    }      
}


@InvocableMethod(label='Create Employee Plan')
public Static void createBusinessProcessForEP(List<Id> recordId){
List<Process_Flow__c> pfList=[Select Id from Process_Flow__c where Name='Employee Payment Plan'];
CreateBusinessProcess.createPreRegistration(recordId[0],pfList[0].Id );

}

}