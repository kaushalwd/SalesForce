public class HandleSalesOrderJunctionObjcet {
    @InvocableMethod(label='Initiate SalesOrder Junction Logioc' category='Sales Order')
    public static void initiatefuture(List<String> SOId) {
        Set<String> salesOrderIds = New Set<String>(SOId);
        createUpdateSalesorderJunctionObject(salesOrderIds);
    }
    @future(callout= true)
    public static void createUpdateSalesorderJunctionObject(Set<String> sales_orderIds){
        List<SalesOrder__c> sales_order_list = [SELECT Id, Name, Sales_Order_Junction_Object__c, 
                                                (SELECT Id, Name, MilestoneNumber__c, InstallmentAmount__c FROM Sales_Order_Installments__r ORDER BY MilestoneNumber__c ASC), 
                                                (SELECT Id, Name, OwnershipPercentage__c FROM Joint_Owners__r ORDER BY CreatedDate asc) 
                                                FROM SalesOrder__c WHERE Id IN: sales_orderIds];
        
        List<Sales_Order_Junction_Object__c> list_to_insert = New List<Sales_Order_Junction_Object__c>();
        List<Sales_Order_Junction_Object__c> list_to_update = New List<Sales_Order_Junction_Object__c>();
        Set<Id> so_Id_set = New Set<Id>();
        for(SalesOrder__c record:sales_order_list){
            if(record.Sales_Order_Junction_Object__c != null){
                list_to_update.add(prepareData(record, record.Sales_Order_Junction_Object__c));
            }else{
                so_Id_set.add(record.Id);
                list_to_insert.add(prepareData(record, null));
            }
        }
        try{
            if(list_to_insert.size()>0){
                INSERT list_to_insert;
            }
            if(list_to_update.size()>0){
                UPDATE list_to_update;
            }
        }Catch(Exception ex){
            LoggerService.save(LoggerService.createApexLog(ex,'HandleSalesOrderJunctionObjcet','createUpdateSalesorderJunctionObject',''));
            throw ex;
        }
        if(so_Id_set.size()>0){
            updateSalesOrder(so_Id_set);
        }
    }
    
    public static Sales_Order_Junction_Object__c prepareData(SalesOrder__c record, String sojo_Id){
        Sales_Order_Junction_Object__c sojo_rec = sojo_Id != null ? New Sales_Order_Junction_Object__c (Id = sojo_Id) : New Sales_Order_Junction_Object__c();
        String comments;
        if(record.Sales_Order_Installments__r.size()>0){
            for(SalesOrderInstallments__c soi_rec:record.Sales_Order_Installments__r){
                if(soi_rec.MilestoneNumber__c <= 10){
                    String sojo_field = 'Instalment_Amount_'+soi_rec.MilestoneNumber__c+'__c';
                    sojo_rec.put(sojo_field, soi_rec.InstallmentAmount__c);
                }else{
                    comments += soi_rec.InstallmentAmount__c+' (New Instalment Field is needed); ';
                }
            }
        }
        Decimal share_percentage = 0;
        if(record.Joint_Owners__r.size()>0){
            for(Integer i=0; i<record.Joint_Owners__r.size(); i++){
                share_percentage += record.Joint_Owners__r[i].OwnershipPercentage__c;
                String jo_field = 'JO_'+(i+1)+'__c';
                String jo_field_share = 'Joint_Owner_'+(i+1)+'_Share__c';
                sojo_rec.put(jo_field, record.Joint_Owners__r[i].Id);
                sojo_rec.put(jo_field_share, record.Joint_Owners__r[i].OwnershipPercentage__c);
            }
        }
        sojo_rec.put('Total_Joint_Owner_Share__c', share_percentage);
        sojo_rec.put('Sales_Order__c', record.Id);
        return sojo_rec;
    }
    
    //@future(callout= true)
    public static void updateSalesOrder(Set<Id> so_id_set){
        List<Sales_Order_Junction_Object__c> list_sojo = [SELECT Id, Sales_Order__c FROM Sales_Order_Junction_Object__c WHERE Sales_Order__c IN:so_id_set];
        Map<String, SalesOrder__c> so_to_update_map = New Map<String, SalesOrder__c>();
        if(list_sojo.size()>0){
            for(Sales_Order_Junction_Object__c rec:list_sojo){
                if(rec.Sales_Order__c != null){
                    so_to_update_map.put(rec.Id, New SalesOrder__c (Id = rec.Sales_Order__c, Sales_Order_Junction_Object__c = rec.Id));
                }
            }
        }
        
        try{
            if(so_to_update_map.values().size()>0){
                UPDATE so_to_update_map.values();
            }
        }Catch(Exception ex){
            LoggerService.save(LoggerService.createApexLog(ex,'HandleSalesOrderJunctionObjcet','createUpdateSalesorderJunctionObject',''));
            throw ex;
        }
    }
}