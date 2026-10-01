/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes 
**********************************************************************************************************************/
public without sharing class DefaultTrackerInvocable {

    public class Request {

        @InvocableVariable(required=true)
        public Id salesOrderInstallmentId;

        @InvocableVariable(required=true)
        public Id invoiceId;
    }

    @InvocableMethod(label='Remove SOI From Default Tracker')
    public static void removeSOI(List<Request> requests){

        if(requests == null || requests.isEmpty()){
            return;
        }

        Set<Id> soiIds = new Set<Id>();

        for(Request req : requests){
            if(req.salesOrderInstallmentId != null){
                soiIds.add(req.salesOrderInstallmentId);
            }
        }

        if(soiIds.isEmpty()){
            return;
        }

        // Get SOIs
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

        // Business Process
        Map<Id,Business_Process__c> bpMap = new Map<Id,Business_Process__c>();
         Set<Id> bpIds=new Set<Id>();
        for(Business_Process__c bp :[
            SELECT Id, Sales_Order__c, Status__c
            FROM Business_Process__c
            WHERE Type__c='Default And Termination'
            AND Sales_Order__c IN :salesOrderIds
        ]){
            bpMap.put(bp.Sales_Order__c,bp);
            bpIds.add(bp.Id);
        }

        // Trackers
        Map<Id,Default_Tracker__c> trackerMap = new Map<Id,Default_Tracker__c>();
        
        for(Default_Tracker__c dt :[
            SELECT Id,
                   Business_Process__c,
                   Count__c,

                   Sales_Order_Installment_1__c,
                   Sales_Order_Installment_2__c,
                   Sales_Order_Installment_3__c,
                   Sales_Order_Installment_4__c,
                   Sales_Order_Installment_5__c,
                   Sales_Order_Installment_6__c,
                   Sales_Order_Installment_7__c,

                   Invoice_1__c,
                   Invoice_2__c,
                   Invoice_3__c,
                   Invoice_4__c,
                   Invoice_5__c,
                   Invoice_6__c,
                   Invoice_7__c

            FROM Default_Tracker__c
            WHERE Business_Process__c IN :bpIds
        ]){
            trackerMap.put(dt.Business_Process__c,dt);
        }

        List<Default_Tracker__c> trackerUpdates = new List<Default_Tracker__c>();
        List<Business_Process__c> bpUpdates = new List<Business_Process__c>();

        for(Request req : requests){

            SalesOrderInstallments__c soi = soiMap.get(req.salesOrderInstallmentId);

            if(soi == null) continue;

            Business_Process__c bp = bpMap.get(soi.SalesOrder__c);

            if(bp == null) continue;

            Default_Tracker__c tracker = trackerMap.get(bp.Id);

            if(tracker == null) continue;

            Integer foundIndex = 0;

            // Find matching slot
            for(Integer i=1;i<=7;i++){

                if(
                    (Id)tracker.get('Sales_Order_Installment_'+i+'__c') == req.salesOrderInstallmentId &&
                    (Id)tracker.get('Invoice_'+i+'__c') == req.invoiceId
                ){
                    foundIndex = i;
                    break;
                }
            }

            if(foundIndex == 0){
                continue;
            }

            // Shift remaining slots
            for(Integer i=foundIndex;i<7;i++){

                tracker.put(
                    'Sales_Order_Installment_'+i+'__c',
                    tracker.get('Sales_Order_Installment_'+(i+1)+'__c')
                );

                tracker.put(
                    'Invoice_'+i+'__c',
                    tracker.get('Invoice_'+(i+1)+'__c')
                );
            }

            // Clear last slot
            tracker.put('Sales_Order_Installment_7__c', null);
            tracker.put('Invoice_7__c', null);

            Integer count = tracker.Count__c == null ? 0 : Integer.valueOf(tracker.Count__c);

            count = Math.max(count - 1, 0);

            tracker.Count__c = count;

            trackerUpdates.add(tracker);

            if(count == 0){
                bp.Status__c = 'Completed';
				bp.D_T_Customer_Discussion_Outcome__c='Paid System Closed';
                bpUpdates.add(bp);
            }
        }

        if(!trackerUpdates.isEmpty()){
            update trackerUpdates;
        }

        if(!bpUpdates.isEmpty()){
            update bpUpdates;
        }
    }
}