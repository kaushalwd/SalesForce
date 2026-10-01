/**********************************************************************************************************************
* Name               : CreateExternalCommissionLineBatch                                                        
* Description        : This class is used to handle all the External Commission Line Creation Logic
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           dinesh.selvam@modon.com             10/04/2026      Initial Draft
* 2.0           Dinesh Selvam                       27/04/2026      Excluded "Modon Egypt" Sales Orders
* 3.0           Upendra                                   24/06/2026      Optional project-scoped constructor — when a
*                                                                   Project__c Id is supplied, the batch filters
*                                                                   Sales Orders to that project only. Default
*                                                                   (no-arg) constructor runs the full daily logic
*                                                                   unchanged.
**********************************************************************************************************************/
public class CreateExternalCommissionLineBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Id filterProjectId;


    public CreateExternalCommissionLineBatch() {}

  
    public CreateExternalCommissionLineBatch(Id projectId) {
        this.filterProjectId = projectId;
    }

    
    public Database.QueryLocator start(Database.BatchableContext bc) {

        Date commissionStartDate = Date.valueOf(System.Label.CommissionExternalStartDate);
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')
            ? System.label.CommissionCancelStatus.split(',')
            : new List<String>{ System.label.CommissionCancelStatus };
        String MODON_EGYPT_SOURCE_ENTITY = Constants.MODON_EGYPT_SOURCE_ENTITY;

        String query = 'SELECT Id, ownerId, Down_Payment_Status__c, SPAStatus__c, ExternalCommissionPaidPercent__c '
                     + 'FROM SalesOrder__c';

        if (!Test.isRunningTest()) {
            query += ' WHERE (NOT(Status__c IN: cancellStatus))'
                   + ' AND Resale__c = false'
                   + ' AND Opportunity__r.BrokerAgency__c != null'
                   + ' AND IsExternalCommissionLineExist__c = false'
                   + ' AND SOCreationDate__c >: commissionStartDate'
                   + ' AND Source_Entity__c !=: MODON_EGYPT_SOURCE_ENTITY'; // 2.0 Excluded Modon Egypt

            // 3.0 — append project filter only when a project Id was passed in
            if (filterProjectId != null) {
                query += ' AND Unit__r.Phase__r.Project__c =: filterProjectId';
                System.debug('CreateExternalCommissionLineBatch >> Project-scoped run for: ' + filterProjectId);
            }
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        CommissionLogicHandler.createExternalCommissions((List<SalesOrder__c>) scope);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('CreateExternalCommissionLineBatch completed.'
            + (filterProjectId != null ? ' Project filter: ' + filterProjectId : ' Full run.'));
    }
}