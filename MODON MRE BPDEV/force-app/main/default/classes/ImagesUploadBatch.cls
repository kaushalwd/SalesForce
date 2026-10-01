global without sharing class ImagesUploadBatch implements Database.Batchable<sObject>,Database.AllowsCallouts {
    
    global String imageContentVersionId;
    global String projectName;
    
    global ImagesUploadBatch(String imageContentVersionId, String projectName){
        this.imageContentVersionId = imageContentVersionId;
        this.projectName = projectName;
    }
    
    global ImagesUploadBatch(){}
    
    global Database.QueryLocator start(Database.BatchableContext BC) {       
        String labelValue = system.Label.SOStatus;
        List<String> filterString = new List<String>();
        if (String.isNotBlank(labelValue)) {
            if (labelValue.contains(',')) {
                // Split by comma and trim spaces
                for (String s : labelValue.split(',')) {
                    filterString.add(s.trim());
                }
            } else {
                // No comma, just single value
                filterString.add(labelValue.trim());
            }
        }
        string queryString = null;
        
        if(projectName != null){
            queryString ='select Id, Unit__c,Unit__r.Name,Unit__r.Unit_Image_Name_pc__c, UnitOption__r.Name, UnitOption__r.Type__c,Unit__r.Phase__c, Image_Name_pc__c, ProjectName__c from SalesOrder__c where ProjectName__c = :projectName and Status__c NOT IN : filterString';
        }else {
            queryString ='select Id, Unit__c,Unit__r.Name, Unit__r.Unit_Image_Name_pc__c, UnitOption__r.Name, UnitOption__r.Type__c,Unit__r.Phase__c, Image_Name_pc__c, ProjectName__c from SalesOrder__c where Status__c NOT IN : filterString and SOCreationDate__c >= YESTERDAY ';
        }
        
        system.debug('queryString----'+Database.getQueryLocator(queryString));
        return Database.getQueryLocator(queryString);
    }

    global void execute(Database.BatchableContext BC, List<SalesOrder__c> scope) {
         CreateUnitExteriorImage.createUnitExteriorImage(scope);
    }

    global void finish(Database.BatchableContext BC) {}
}