public without sharing class SOIDefaultTrackerInvocable {

    @InvocableMethod(label='SOI Tracker Update')
    public static void trackerSOITracker(List<Id> soiIds) {
        if(soiIds.isEmpty()) return;

        Map<Id,SalesOrderInstallments__c> soiMap = new Map<Id,SalesOrderInstallments__c>([
            SELECT Id, SalesOrder__c
            FROM SalesOrderInstallments__c
            WHERE Id IN :soiIds
        ]);

          Set<Id> salesOrderIds = new Set<Id>();

        for(SalesOrderInstallments__c soi : soiMap.values()){
            if(soi.SalesOrder__c != null){
                salesOrderIds.add(soi.SalesOrder__c);
            }
        }

        Map<Id,Business_Process__c> bpMap = new Map<Id,Business_Process__c>();
        Map<Id,Business_Process_Step__c> bpStepMap = new Map<Id,Business_Process_Step__c>();
         Set<Id> bpIds=new Set<Id>();
        for(Business_Process__c bp :[
            SELECT Id, Sales_Order__c, Status__c, Current_Business_Process_Step__c
            FROM Business_Process__c
            WHERE Type__c='Default And Termination'
            AND Sales_Order__c IN :salesOrderIds
        ]){
            bpMap.put(bp.Sales_Order__c,bp);
            bpIds.add(bp.Id);
        }

        List<Business_Process__c> bpUpdates = new List<Business_Process__c>();

        List<AggregateResult> results = [
            SELECT
                SalesOrderInstallment__r.SalesOrder__c SalesOrderId,
                SUM(InvoiceBalance__c) TotalBalance
            FROM Invoice__c
            WHERE SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds
            AND SalesOrderInstallment__r.MilestoneDate__c < TODAY
            //AND InvoiceBalance__c > 0
            AND SalesOrderInstallment__r.PaymentStatus__c != 'Cancelled'
            GROUP BY SalesOrderInstallment__r.SalesOrder__c
        ];

        for (AggregateResult ar : results) {

    Id salesOrderId =
        (Id) ar.get('SalesOrderId');

    Decimal totalBalance =
        (Decimal) ar.get('TotalBalance');

/*totalBalanceMap.put(
        salesOrderId,
        totalBalance == null ? 0 : totalBalance
    );*/

    if(totalBalance <=500 && bpMap.size()>0 && bpMap.containsKey(salesOrderId)) {

        bpStepMap.put (bpMap.get(salesOrderId).Id,new Business_Process_Step__c(Id=bpMap.get(salesOrderId).Current_Business_Process_Step__c, Is_Process_End__c=true, Status__c='Completed', Remarks_Comments__c='Paid System Closed'));
        Business_Process__c bp=new Business_Process__c();
         bp.Id =bpMap.get(salesOrderId).Id;
         bp.Status__c = 'Completed';
         bp.D_T_Customer_Discussion_Outcome__c='Paid System Closed';
         bpUpdates.add(bp);
    }
}

if(bpStepMap.size()>0)
update bpStepMap.values();

if(bpUpdates.size()>0)
update bpUpdates;

    }

}