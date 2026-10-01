public without sharing class InvoiceLineTriggerHandler extends TriggerHandler {
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    }
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    }
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    	System.debug('invoice line trigger');
        CommissionLogicHandler.handleInvoiceLineHoldAmt(newList,oldMap);
    }
}