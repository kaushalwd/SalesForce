/**********************************************************************************************************************
* Name               : CreateCommissionLineBatch                                                        
* Description        : This class is used to handle internal commission Creation Logic
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           dinesh.selvam@modon.com             05/10/2025      Initial Draft
* 2.0           Dinesh Selvam                       27/04/2026      Excluded the "Modon Egypt" Project
**********************************************************************************************************************/
public class CreateCommissionLineBatch  implements Database.Batchable<SObject>, Database.Stateful,Schedulable {
    public void execute(SchedulableContext sc) {
        CreateCommissionLineBatch batchJob = new CreateCommissionLineBatch(null);
        Database.executeBatch(batchJob, 1);
    }
    public String queryString;
    public CreateCommissionLineBatch(String queryString){
        this.queryString = queryString;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date startDate = Date.valueOf(System.Label.Commission_Calc_Starting_Date_Direct);
        Date endDate = Date.valueOf(System.Label.Commission_Calc_End_Date_Direct);

		List<String> LeadSourceList = System.label.CommissionLeadSource.contains(',')?System.label.CommissionLeadSource.split(','):new List<String>{System.label.CommissionLeadSource};
        List<String> spaStsList = System.label.CommissionSPAStatus.contains(',')?System.label.CommissionSPAStatus.split(','):new List<String>{System.label.CommissionSPAStatus};
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')?System.label.CommissionCancelStatus.split(','):new List<String>{System.label.CommissionCancelStatus};
        String MODON_EGYPT_SOURCE_ENTITY = Constants.MODON_EGYPT_SOURCE_ENTITY;
        String query = 'SELECT Id,ownerId FROM SalesOrder__c WHERE (NOT(Status__c IN: cancellStatus)) AND Resale__c = false AND (Opportunity__r.LeadSource IN:LeadSourceList OR Opportunity__r.LeadSource = null) AND IsCommissionLineExist__c = false AND Unit__r.Unit_Sold_Date__c !=NULL AND Unit__r.Unit_Launch_Date__c != NULL AND Source_Entity__c !=:MODON_EGYPT_SOURCE_ENTITY';//2.0 Excluded "Modon Egypt" Projects
        if(queryString <> null){
            query = queryString;
        }
        return Database.getQueryLocator(query);
    }
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        CommissionLogicHandler.createCommissionLine((List<SalesOrder__c>)scope);
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('createCommissionLineBatch completed.');
    }
}