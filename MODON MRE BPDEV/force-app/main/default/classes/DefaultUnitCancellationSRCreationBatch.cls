public without sharing class DefaultUnitCancellationSRCreationBatch implements Database.Batchable<sObject>, Schedulable {
    
    public set<Id> srIds = new set<Id>();
    
    public DefaultUnitCancellationSRCreationBatch(){
        srIds =  new set<Id>();
    }
    
    public DefaultUnitCancellationSRCreationBatch(set<Id> srRecIds){
        srIds =  srRecIds;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        
        string cancelledString ='Cancelled';
        string cancellationType ='Conditional Cancellation';
        Id defaultUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'Default_SR');
        system.debug('---defaultUpdateRecordTypeId ----start-----SR--------------'+defaultUpdateRecordTypeId );
       
        // SOQL injection fix: bind optional srIds instead of concatenating Id literals into IN (...).
        String query = 'SELECT Id, Name, RecordTypeName__c, Legal_Decision__c, ' +
               'SalesOrder__r.Totalpaidamount__c, Cancellation_Date__c, ' +
               'SalesOrder__c, SalesOrder__r.Name, RecordTypeId ' +
               'FROM ServiceRequest__c ' +
               'WHERE Cancellation_Date__c != NULL ' +
               'AND Legal_Decision__c = :cancellationType ' +
               'AND SalesOrder__r.Total_Outstanding__c > 0 ' +
               'AND Cancellation_Date__c = YESTERDAY ' +
               'AND Status__c != :cancelledString ' +
               'AND RecordTypeId = :defaultUpdateRecordTypeId ';

        if (srIds != null && !srIds.isEmpty()) {
            List<String> safeSrIds = new List<String>();

            for (Id srId : srIds) {
                if (srId != null) {
                    safeSrIds.add('\'' + String.escapeSingleQuotes(String.valueOf(srId)) + '\'');
                }
            }

            if (!safeSrIds.isEmpty()) {
                query += ' AND Id IN (' + String.join(safeSrIds, ',') + ')';
            }
        }

        System.debug('---------- query :--------------- ' + query);

        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<ServiceRequest__c> srRecords){
        try{
            
            Id ucUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'DefaultUnitCancellation');
            system.debug('------------ucUpdateRecordTypeId --------------'+ucUpdateRecordTypeId );
            system.debug('------------srRecords--------------'+srRecords);
  
            List<ServiceRequest__c> ServiceRequestToCreate = new List<ServiceRequest__c>();
            Set<string>phaseIds = new Set<string>();
            
            for(ServiceRequest__c md : srRecords){
                system.debug('---ucUpdateRecordTypeId---------SR--------------'+md);
                /*ServiceRequest__c newSR= new ServiceRequest__c();
                newSR.Name__c ='Default Unit Cancellation - '+md.SalesOrder__r.Name;
                newSR.SalesOrder__c = md.SalesOrder__c;
                newSR.Type__c = 'Normal';
                newSR.Status__c='New';
                newSR.RecordTypeId = ucUpdateRecordTypeId ;
                newSR.Source_Of_SR__c='Default Unit Cancellation';*/
                ServiceRequest__c newSR= createUnitCancellation(md,ucUpdateRecordTypeId );
                ServiceRequestToCreate.add(newSR);
            }
             system.debug('-111111--ServiceRequestToCreate------phhhh-----------------'+ServiceRequestToCreate);
           
            if(ServiceRequestToCreate.size()>0 && !ServiceRequestToCreate.isEmpty()){
                system.debug('-----------ServiceRequestToCreate--------------'+ServiceRequestToCreate);
                Database.saveResult[]  srList = Database.insert(ServiceRequestToCreate,false);
            }
            
        }catch (DmlException e){
            system.debug('-DmlException -------plot handover---------'+e);
           LoggerService.save(LoggerService.createApexLog(e,'Plot Handover SRCreation','DefaultUnitCancellationSRCreationBatch','execute'));
        }
        catch(Exception ex){
            system.debug('-Exception -------plot handover---------'+ex);
            LoggerService.save(LoggerService.createApexLog(ex,'Plot Handover SRCreation','DefaultUnitCancellationSRCreationBatch','execute'));
        }
    }
    
    public void finish(Database.BatchableContext BC) {
    }
    
    public static ServiceRequest__c createUnitCancellation(ServiceRequest__c md,string ucUpdateRecordTypeId ){
        system.debug('---ucUpdateRecordTypeId---------SR--------------'+md);
        ServiceRequest__c newSR= new ServiceRequest__c();
        newSR.Name__c ='Default Unit Cancellation - '+md.SalesOrder__r.Name;
        newSR.SalesOrder__c = md.SalesOrder__c;
        newSR.Type__c = 'Normal';
        newSR.Status__c='New';
        newSR.RecordTypeId = ucUpdateRecordTypeId ;
        newSR.Source_Of_SR__c='Default Unit Cancellation';
        newSR.Legal_Decision__c = md.Legal_Decision__c;
        newSR.Total_Paid_Amount__c = md.SalesOrder__r.Totalpaidamount__c;
        return newSR;
    }
    
    //Schedulable execute method
    public void execute(SchedulableContext SC){
        Database.executeBatch(new DefaultUnitCancellationSRCreationBatch(),1);
    }
}