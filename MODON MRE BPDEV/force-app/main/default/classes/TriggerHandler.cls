/**********************************************************************************************************************
* Name               : TriggerHandler                                                        
* Description        : This class is used to handle apex trigger events acorss the system
* Usage              : Called from all apex triggers
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           paras.bhatt@pwc.com         12 Dec 2022     Initial Draft   
* 1.1			prateek bansal				6 June			Used metadata instead of query
******************************************************************************************************************/
public without sharing virtual class TriggerHandler {
    
    public static Set<Id> processedIds {get;set;} 
    //private static ApexTriggerConfiguration__mdt triggerConfig {get;set;} //v1.1
    
    private static Map<String, ApexTriggerConfiguration__mdt> triggerConfigByLabel;//v1.1
    static {
        processedIds = new Set<Id>();
    }
    
    public void run(String objectName) {
        //v1.1 start
        /*
        if (triggerConfig == null || (triggerConfig!=null && triggerConfig.MasterLabel != objectName)) {
            triggerConfig = [SELECT DeveloperName,MasterLabel,
                                IsRunBeforeInsert__c,IsRunBeforeUpdate__c,IsRunAfterInsert__c,IsRunAfterUpdate__c,IsRunBeforeDelete__c,IsRunAfterDelete__c,IsRunTrigger__c
                                FROM ApexTriggerConfiguration__mdt 
                                WHERE MasterLabel =: objectName];
            
        }
		*/
        
        if (triggerConfigByLabel == null) {
            triggerConfigByLabel = new Map<String, ApexTriggerConfiguration__mdt>();
            for (ApexTriggerConfiguration__mdt cfg : ApexTriggerConfiguration__mdt.getAll().values()) {
                triggerConfigByLabel.put(cfg.MasterLabel, cfg);
            }
        }
        ApexTriggerConfiguration__mdt triggerConfig = triggerConfigByLabel.get(objectName); //v1.1 end
        
        if (triggerConfig != null && triggerConfig.IsRunTrigger__c) {
            if (Trigger.isBefore && Trigger.isInsert && triggerConfig.IsRunBeforeInsert__c) {
                this.beforeInsert();
            } else if (Trigger.isBefore && Trigger.isUpdate && triggerConfig.IsRunBeforeUpdate__c) {
                this.beforeUpdate();
            } else if (Trigger.isAfter && Trigger.isInsert && triggerConfig.IsRunAfterInsert__c) {
                this.afterInsert();
            } else if(Trigger.isAfter && Trigger.isUpdate && triggerConfig.IsRunAfterUpdate__c) {
                this.afterUpdate();
            } else if(Trigger.isBefore && Trigger.isdelete && triggerConfig.IsRunBeforeDelete__c) {
                this.beforeDelete();
            } else if(Trigger.isAfter && Trigger.isdelete && triggerConfig.IsRunAfterDelete__c) {
                this.afterDelete();
            }
        }
    } 
    
    /** Preprocessing Methods **/
    @TestVisible
    protected void beforeInsert() {
        this.beforeInsertMethod(this.newList(), this.newMap());
    }
    
    @TestVisible
    protected void beforeUpdate() {
        this.beforeUpdateMethod(this.newList(), this.newMap(), this.oldList(), this.oldMap());
    }
    
    @TestVisible
    protected void beforeDelete() {
        this.beforeDeleteMethod(this.oldList(), this.oldMap());
    }
    
    @TestVisible
    protected void afterInsert() {
        Map<Id, SObject> newMap = this.newMap();
        List<SObject> newList = this.newList();
        addProcessedIds(Trigger.New);
        this.afterInsertMethod(newList, newMap);
    }
    
    @TestVisible
    protected void afterUpdate() {
        Map<Id, SObject> newMap = this.newMap();
        List<SObject> newList = this.newList();
        Map<Id, SObject> oldMap = this.oldMap();
        List<SObject> oldList = this.oldList();
        addProcessedIds(Trigger.New);
        this.afterUpdateMethod(newList, newMap, oldList, oldMap);
    }
    
    @TestVisible
    protected void afterDelete() {
        afterDeleteMethod(this.oldList(), this.oldMap());
    }
    
    
    /** Methods to override in the Trigger Handlers extending this class **/
    //*** Before Insert Action***//
    @TestVisible
    protected virtual void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        
        //Override me
    }
    
    //*** Before Update Action***//
    @TestVisible
    protected virtual void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        
        //Override me
    }
    
    //*** Before Delete Action***//
    @TestVisible
    protected virtual void beforeDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        
        //Override me
    }
    
    //*** After Insert Action***//
    @TestVisible
    protected virtual void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        
        //Override me   
    }
    
    //*** After Update Action***//
    @TestVisible
    protected virtual void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        
        //Override me
    }
    
    //*** After Delete Action***//
    @TestVisible
    protected virtual void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        
        //Override me
    }
    
    /** Methods to handle recursion **/
    @TestVisible
    private static void addProcessedIds (List<SObject> sobjs) {
        
        for (SObject sobj : sobjs) {
            processedIds.add(sobj.Id);
        }
    }
    
    @TestVisible
    private static List<SObject> filterList (List<SObject> sobjs) {
        
        if (sobjs == null) return null;
        
        List<SObject> filteredList = new List<SObject>();
        
        for (SObject sobj : sobjs) {
            
            if (!processedIds.contains(sobj.Id)) 
                filteredList.add(sobj);
        }
        
        return filteredList;
    }
    
    @TestVisible
    private static Map<Id, SObject> filterMap (Map<Id, SObject> idToSObj) {
        
        if (idToSObj == null) return null;
        
        Map<Id, SObject> filteredMap = new Map<Id, SObject>();
        
        for (Id sobjId : idToSObj.keySet()) {
            
            if (!processedIds.contains(sobjId)) 
                filteredMap.put(sobjId, idToSObj.get(sobjId));
        }
        
        return filteredMap;
    }
    
    @TestVisible
    private List<SObject> newList() {
        
        return filterList(Trigger.new);
    }
    
    @TestVisible
    private Map<Id, SObject> newMap() {
        
        return filterMap(Trigger.newMap);
    }
    
    @TestVisible
    private List<SObject> oldList() {
        
        return filterList(Trigger.old);
    }
    
    @TestVisible
    private Map<Id, SObject> oldMap() {
        
        return filterMap(Trigger.oldMap);
    }
    
}