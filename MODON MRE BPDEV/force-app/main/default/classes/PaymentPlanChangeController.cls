/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PaymentPlanChangeController
 * Author          : Siva
 * Created Date    : Jun 7, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jun 14, 2026
 * Description     : 
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  July 7, 2026  │ Siva   │ Initial version
 *  AUG 6, 2026  │ Siva   │ Payment Plan Phase 2 Changes
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class PaymentPlanChangeController {

    public class RevisedInstallmentWrapper {

    @AuraEnabled
    public Id installmentId;

    @AuraEnabled
    public Id paymentPlanInstallmentId;

    @AuraEnabled
    public String installment;

    @AuraEnabled
    public Decimal milestone;

    @AuraEnabled
    public Decimal amount;

    @AuraEnabled
    public String paymentStatus;

    @AuraEnabled
public Decimal milestoneNumber;

@AuraEnabled
public String milestoneName;
@AuraEnabled public Date milestoneDate;

@AuraEnabled
public Decimal balanceAmount;

@AuraEnabled
public Boolean requiresUnallocation;
}

    public class PaymentPlanOption {

        @AuraEnabled public Id paymentPlanId;
        @AuraEnabled public String paymentPlanName;
    }



    public class InstallmentWrapper {

        @AuraEnabled public Id installmentId;

        @AuraEnabled public String installment;

        @AuraEnabled public String milestoneName;

        @AuraEnabled public Decimal milestone;

        @AuraEnabled public Decimal percentage;

        @AuraEnabled public Decimal amount;

        @AuraEnabled public String paymentStatus;

        @AuraEnabled public Boolean isEditable;
         @AuraEnabled public Decimal milestoneNumber; 
         @AuraEnabled public Date milestoneDate;
         @AuraEnabled
public Decimal balanceAmount;

@AuraEnabled
public Boolean requiresUnallocation;
@AuraEnabled
public Id paymentPlanInstallmentId;
    }

    //====================================================
    // MAIN WRAPPER
    //====================================================

    public class PaymentPlanDataWrapper {

        @AuraEnabled public Decimal salesAmount;
        @AuraEnabled public String currentStepName;

        @AuraEnabled public List<PaymentPlanOption> paymentPlans;

        @AuraEnabled public List<InstallmentWrapper> existingPlan;

        @AuraEnabled public List<InstallmentWrapper> revisedPlan;
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestStatus;
        @AuraEnabled public Id revisedPaymentPlanId;
    }

    //====================================================
    // LOAD SCREEN
    //====================================================

    @AuraEnabled(cacheable=true)
    public static PaymentPlanDataWrapper loadScreen(
        Id salesOrderId
    ) {

        PaymentPlanDataWrapper response =new PaymentPlanDataWrapper();
        String salesId;
       if(salesOrderId.getSObjectType() != SalesOrder__c.SObjectType){
        List<Business_Process__c> bpList=[Select Id, Sales_Order__c,Current_Step_Name__c from Business_Process__c where Id=:salesOrderId];
        salesId =bpList[0].Sales_Order__c;
        salesOrderId=salesId;
        response.currentStepName=bpList[0].Current_Step_Name__c;
        }

        


        SalesOrder__c so = [

            SELECT
                Id,
                TotalAmount__c,
                Unit__r.Phase__c,
                Unit__r.Phase__r.Project__c

            FROM SalesOrder__c

            WHERE Id = :salesOrderId

            LIMIT 1
        ];

        response.salesAmount =
            so.TotalAmount__c;

        List<PaymentPlanChangeRequest__c> reqList =
[
    SELECT
        Id,
        Revised_Payment_Plan__c,
        Status__c
    FROM PaymentPlanChangeRequest__c
    WHERE Sales_Order__c = :salesOrderId
    AND Status__c IN ('Draft','Approved')
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if(!reqList.isEmpty()){

    response.requestId =
        reqList[0].Id;

    response.requestStatus =
        reqList[0].Status__c;

    response.revisedPaymentPlanId =
        reqList[0].Revised_Payment_Plan__c;
}

        response.paymentPlans =
            new List<PaymentPlanOption>();

        for(PaymentPlan__c pp : [

            SELECT
                Id,
                Name

            FROM PaymentPlan__c

            WHERE
				Phase__c =
                    :so.Unit__r.Phase__c
        ]) {

            PaymentPlanOption opt =
                new PaymentPlanOption();
            opt.paymentPlanId = pp.Id;
            opt.paymentPlanName = pp.Name;
            response.paymentPlans.add(opt);
        }



        List<InstallmentWrapper> existing =
            new List<InstallmentWrapper>();

        for(SalesOrderInstallments__c inst : [

            SELECT
                Id,
                Milestone_Name__c,
                Milestone__c,
                PaymentInstallments__c,
                InstallmentAmount__c,
                PaymentStatus__c,
                MilestoneDate__c,
                MilestoneNumber__c,
                Balance_Amount__c

            FROM SalesOrderInstallments__c

            WHERE SalesOrder__c = :salesOrderId order by MilestoneNumber__c
        ]) {

            InstallmentWrapper wrap =
                new InstallmentWrapper();

            wrap.installmentId = inst.Id;

            wrap.installment =
                inst.PaymentInstallments__c;

            wrap.milestoneName =
                inst.Milestone_Name__c;

            wrap.milestone =
                inst.Milestone__c;

            wrap.amount =
                inst.InstallmentAmount__c;

            wrap.paymentStatus =
                inst.PaymentStatus__c;
            wrap.milestoneNumber =
    inst.MilestoneNumber__c;
    wrap.balanceAmount =
    inst.Balance_Amount__c;
    wrap.requiresUnallocation =
    inst.PaymentStatus__c == 'Partially Paid'
    &&
    inst.Balance_Amount__c > 5000;

   // wrap.isEditable =inst.PaymentStatus__c != 'Paid'&& inst.PaymentStatus__c != 'Partially Paid';

    wrap.milestoneDate =inst.MilestoneDate__c;
    Boolean lockRecord = false;

if(inst.PaymentStatus__c == 'Paid'){
    lockRecord = true;
}
else if(
    inst.PaymentStatus__c == 'Partially Paid'
    &&
    inst.Balance_Amount__c <= 100
){
    //lockRecord = true;
}

wrap.isEditable = !lockRecord;

            existing.add(wrap);
        }
        response.existingPlan = existing;
       /* response.revisedPlan =new List<InstallmentWrapper>();

        for(InstallmentWrapper ex : existing) {
            InstallmentWrapper rev =
                new InstallmentWrapper();

            rev.installmentId = ex.installmentId;
            rev.installment = ex.installment;
            rev.milestoneName = ex.milestoneName;
            rev.milestone = ex.milestone;
            rev.percentage = ex.percentage;
            rev.amount = ex.amount;
            rev.paymentStatus = ex.paymentStatus;
            rev.isEditable = ex.isEditable;
            response.revisedPlan.add(rev);
        }*/

        response.revisedPlan = new List<InstallmentWrapper>();

if(response.requestId != null){

    List<PaymentPlanChangeLine__c> lines = [

        SELECT
            Existing_SO_Installment__c,
            Payment_Installment__c,
            Installment_Name__c,
            Milestone__c,
            Amount__c,
            Payment_Status__c,
            Milestone_Number__c,
            Milestone_Name__c,
            Milestone_Date__c,
            Locked__c,
            Outstanding_Amount__c,
            Needs_Unallocation__c

        FROM PaymentPlanChangeLine__c

        WHERE Change_Request__c = :response.requestId

        ORDER BY Milestone_Number__c
    ];

    for(PaymentPlanChangeLine__c line : lines){

        InstallmentWrapper wrap =new InstallmentWrapper();

        wrap.installmentId =line.Existing_SO_Installment__c;
        wrap.paymentPlanInstallmentId =line.Payment_Installment__c;

        wrap.installment = line.Installment_Name__c;

        wrap.milestoneName = line.Milestone_Name__c;

        wrap.milestone = line.Milestone__c;

        wrap.amount = line.Amount__c;

        wrap.paymentStatus =line.Payment_Status__c;

        wrap.milestoneNumber = line.Milestone_Number__c;

        wrap.milestoneDate =line.Milestone_Date__c;

        wrap.balanceAmount = line.Outstanding_Amount__c;

        wrap.requiresUnallocation = line.Needs_Unallocation__c;

        wrap.isEditable =!line.Locked__c;

        response.revisedPlan.add(wrap);
    }

}
else{

    for(InstallmentWrapper ex : existing){

        InstallmentWrapper rev =
            new InstallmentWrapper();

        rev.installmentId = ex.installmentId;
        rev.paymentPlanInstallmentId =ex.paymentPlanInstallmentId;

        rev.installment = ex.installment;

        rev.milestoneName = ex.milestoneName;

        rev.milestone = ex.milestone;

        rev.amount = ex.amount;

        rev.paymentStatus =ex.paymentStatus;

        rev.isEditable = ex.isEditable;

        rev.milestoneNumber =ex.milestoneNumber;

        rev.milestoneDate =ex.milestoneDate;

        rev.balanceAmount = ex.balanceAmount;

        rev.requiresUnallocation = ex.requiresUnallocation;

        response.revisedPlan.add(rev);
    }
}

        return response;
    }



    @AuraEnabled(cacheable=true)
public static List<InstallmentWrapper> getPaymentPlanInstallments(
    Id paymentPlanId
) {

    List<InstallmentWrapper> results =
        new List<InstallmentWrapper>();

    for(PaymentInstallements__c pi : [

        SELECT
            Id,
            Name,
            Milestone__c,
            MilestoneNumber__c,
            MilestoneDate__c

        FROM PaymentInstallements__c

        WHERE PaymentInstallment__c = :paymentPlanId

        ORDER BY MilestoneNumber__c ASC
    ]) {

        InstallmentWrapper wrap =
            new InstallmentWrapper();

        wrap.installmentId =
            pi.Id;

        wrap.installment =
            pi.Name;

        wrap.milestoneName =
            pi.Name;

        wrap.milestone =
            pi.Milestone__c;

        wrap.milestoneNumber =
            pi.MilestoneNumber__c;

        wrap.paymentStatus =
            'Pending';

        wrap.isEditable =
            true;
            wrap.milestoneDate =
    pi.MilestoneDate__c;

        results.add(wrap);
    }

    return results;
}



    @AuraEnabled
    public static String saveRevisedPlan(
        List<InstallmentWrapper> revisedPlan
    ) {

        if(revisedPlan == null ||
           revisedPlan.isEmpty()) {

            return 'No Records';
        }

        Map<Id, SalesOrderInstallments__c> dbMap =
            new Map<Id, SalesOrderInstallments__c>([

                SELECT
                    Id,
                    PaymentStatus__c

                FROM SalesOrderInstallments__c

                WHERE Id IN :getIds(revisedPlan)
            ]);

        List<SalesOrderInstallments__c> updates =
            new List<SalesOrderInstallments__c>();

        for(InstallmentWrapper wrap : revisedPlan) {

            SalesOrderInstallments__c db =
                dbMap.get(wrap.installmentId);



            if(db != null &&
               (
                   db.PaymentStatus__c == 'Paid'
                   ||
                   db.PaymentStatus__c == 'Partially Paid'
               )) {

                continue;
            }

            SalesOrderInstallments__c upd =
                new SalesOrderInstallments__c();

            upd.Id = wrap.installmentId;

            upd.Milestone__c =
                wrap.milestone;

            upd.InstallmentAmount__c =
                wrap.amount;

            updates.add(upd);
        }

        if(!updates.isEmpty()) {

            update updates;
        }

        return 'Success';
    }



    private static Set<Id> getIds(
        List<InstallmentWrapper> wraps
    ) {

        Set<Id> ids = new Set<Id>();

        for(InstallmentWrapper w : wraps) {

            if(w.installmentId != null) {

                ids.add(w.installmentId);
            }
        }

        return ids;
    }

  @AuraEnabled
public static Id saveToStaging(
    Id salesOrderId,
    Id selectedPaymentPlanId,
    String revisedPlanJson
) {    

    String salesId;
    String bp;
       if(salesOrderId.getSObjectType() != SalesOrder__c.SObjectType){
        List<Business_Process__c> bpList=[Select Id, Sales_Order__c,Current_Step_Name__c from Business_Process__c where Id=:salesOrderId];
        salesId =bpList[0].Sales_Order__c;
        bp=bpList[0].Id;
        salesOrderId=salesId;
        }

    if(salesOrderId == null) {
        throw new AuraHandledException('Sales Order is required.');
    }

    if(selectedPaymentPlanId == null) {
        throw new AuraHandledException('Please select a payment plan.');
    }

    List<RevisedInstallmentWrapper> revisedPlan =
        (List<RevisedInstallmentWrapper>)JSON.deserialize(
            revisedPlanJson,
            List<RevisedInstallmentWrapper>.class
        );

    System.debug(
        'Revised Plan => ' +
        JSON.serializePretty(revisedPlan)
    );

    if(revisedPlan == null || revisedPlan.isEmpty()) {
        throw new AuraHandledException('No revised installments found.');
    }

    SalesOrder__c so = [
        SELECT Id, PaymentPlan__c
        FROM SalesOrder__c
        WHERE Id = :salesOrderId
        LIMIT 1
    ];

    PaymentPlanChangeRequest__c requestRec =
        new PaymentPlanChangeRequest__c();

    requestRec.Sales_Order__c =
        salesOrderId;

    requestRec.Existing_Payment_Plan__c =
        so.PaymentPlan__c;

    requestRec.Revised_Payment_Plan__c =
        selectedPaymentPlanId;

    requestRec.Status__c =
        'Draft';

    requestRec.Submitted_By__c =
        UserInfo.getUserId();

    requestRec.Submitted_Date__c =
        System.now();

    insert requestRec;

    Set<Id> soiIds = new Set<Id>();

for(RevisedInstallmentWrapper row : revisedPlan){

    if(row.installmentId != null){
        soiIds.add(row.installmentId);
    }
}

Map<Id, SalesOrderInstallments__c> soiMap =
    new Map<Id, SalesOrderInstallments__c>([
        SELECT
            Id,
            PaymentStatus__c,
            Balance_Amount__c
        FROM SalesOrderInstallments__c
        WHERE Id IN :soiIds
    ]);

    List<PaymentPlanChangeLine__c> lines =
        new List<PaymentPlanChangeLine__c>();

    for(RevisedInstallmentWrapper row : revisedPlan) {

        System.debug(
            'Row => ' +
            JSON.serializePretty(row)
        );

        PaymentPlanChangeLine__c line =
            new PaymentPlanChangeLine__c();

        line.Change_Request__c =
            requestRec.Id;

        line.Existing_SO_Installment__c =
            row.installmentId;

        line.Payment_Installment__c =
            row.paymentPlanInstallmentId;

        line.Installment_Name__c =
            row.installment;

        line.Milestone__c =
            row.milestone;

        line.Amount__c =
            row.amount;

        line.Payment_Status__c =
            row.paymentStatus;

        line.Milestone_Number__c =
    row.milestoneNumber;

line.Milestone_Name__c =
    row.milestoneName;

line.Milestone_Date__c =
    row.milestoneDate;

line.Outstanding_Amount__c =
    row.balanceAmount;

line.Needs_Unallocation__c =
    row.requiresUnallocation; 
SalesOrderInstallments__c soi =
    soiMap.get(row.installmentId);

Boolean requiresUnallocation = false;

if(
    soi != null &&
    soi.PaymentStatus__c == 'Partially Paid' &&
    soi.Balance_Amount__c > 5000
){
    requiresUnallocation = true;
}

line.Needs_Unallocation__c =
    requiresUnallocation;

line.Outstanding_Amount__c =
    soi != null
        ? soi.Balance_Amount__c
        : 0;       

        //line.Milestone_Number__c =
        //row.milestoneNumber;    

        line.Locked__c =
            row.paymentStatus == 'Paid'; //|| requiresUnallocation;
            //|| row.paymentStatus == 'Partially Paid';

        lines.add(line);
    }

    if(!lines.isEmpty()) {
        insert lines;
    }

    if(bp!=null){
        List<Business_Process__c> bproc=[Select Id, Current_Business_Process_Step__c from Business_Process__c where Id=:bp ];
        Business_Process_Step__c bpStep=new Business_Process_Step__c(Id=bproc[0].Current_Business_Process_Step__c, 
        Status__c='Completed', Assigned_To__c=UserInfo.getUserId());
        update bpStep;
        bpStep.Status__c='Completed';
        update bpStep;
        List<Business_Process_Step__c> bpsList = [
                Select id,Multi_Select_Step_Required_Info_Step__c,Is_Multi_Select_Reopen__c,Required_Info_Step_Sequence__c,Is_Process_End__c,Is_Single_Level_Required_Info__c,Required_Info_Step__c,Business_Process__c,Sequence__c,Step__c,Department__c,Name,Status__c,
                Re_Open_Count__c,Business_Process__r.Type__c,Assigned_To__c,Skip_Step_To_Reopen__c,
                Business_Process__r.Process_Flow__r.Name,ownerId,
                Business_Process__r.Previous_Business_Process_Step__r.Sequence__c,Section_Number__c,
                Business_Process__r.Sales_Order__c 
                FROM Business_Process_Step__c where Business_Process__c = :bp AND Sequence__c>1 AND Step__c != null];
            system.debug('bpsList::'+bpsList);
          Business_Process_Step__c businessProcesStep = [
                Select id,Multi_Select_Step_Required_Info_Step__c,Business_Process__r.Collections_Discussion_OutCome__c,Business_Process__r.D_T_Customer_Discussion_Outcome__c,Is_Multi_Select_Reopen__c,Required_Info_Step_Sequence__c,Is_Process_End__c,Business_Process_Steps_Name_Custom__c,Is_Single_Level_Required_Info__c,Required_Info_Step__c,Required_Info_Step__r.Sequence__c,/* Business_Process__r.Procedure_Number__c,*/
                 Business_Process__c,Sequence__c,Name,Business_Process__r.Name, Business_Process__r.Type__c,
                Status__c,Re_Open_Count__c,Is_check_List__c,Assigned_To__c,Business_Process__r.Process_Flow__r.Name,
                ownerId,Business_Process__r.CRM_Manager_decision__c,Section_Number__c,
                Business_Process__r.Sales_Order__r.CustomerAccount__c, Business_Process__r.Sales_Order__c
                FROM Business_Process_Step__c where id = :bproc[0].Current_Business_Process_Step__c limit 1];
         PaymentPlanChangeActivator activ=new PaymentPlanChangeActivator();
           activ.activateNextSteps(bp, bpsList, businessProcesStep,null);         

        
    }

    return requestRec.Id;
}

 @AuraEnabled
 public static Boolean IsEmployeePaymentPlanApplied(Id salesOrderId) {
    String salesId;
       if(salesOrderId.getSObjectType() != SalesOrder__c.SObjectType){
        List<Business_Process__c> bpList=[Select Id, Sales_Order__c from Business_Process__c where Id=:salesOrderId];
        salesId =bpList[0].Sales_Order__c;
        salesOrderId=salesId;
        }

  SalesOrder__c so=  [SELECT Id,CustomerAccount__r.Is_Employee_Payment_Plan_Applied__c FROM SalesOrder__c   WHERE Id = :salesOrderId];
   if(so.CustomerAccount__r.Is_Employee_Payment_Plan_Applied__c){
     return true;
   }
   return false;
 }

 @AuraEnabled
    public static void approveRequest(Id requestId) {

        if(requestId == null){
            throw new AuraHandledException(
                'Request Id is required.'
            );
        }

        PaymentPlanChangeRequest__c requestRec =
        [
            SELECT
                Id,
                Status__c
            FROM PaymentPlanChangeRequest__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        if(requestRec.Status__c != 'Draft'){
            throw new AuraHandledException(
                'Only Draft requests can be approved.'
            );
        }

        requestRec.Status__c = 'Approved';

        update requestRec;
    }
}