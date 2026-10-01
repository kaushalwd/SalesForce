/**********************************************************************************************************************
* Name               : LeadRetirementBatch                                                        
* Description        : This batch will pickup all the lead records which are open and retire it
* Usage              :                                                       
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                  Date            Comment                                                                       
* 1.0           paras.bhatt@pwc.com     28 Dec 2023      Initial Draft       
******************************************************************************************************************/

global class LeadRetirementBatch implements Database.Batchable<sObject>,Schedulable,Database.Stateful {
    private List<Lead> leadsToUpdate = new List<Lead>();

    global void execute(SchedulableContext ctx) { 
        database.executebatch(this,200);
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {

        General_Parameters__mdt gParam = General_Parameters__mdt.getInstance('SLA_Auto_Lead_Retire');
        Integer daysNr = Integer.valueOf(gParam.Value__c);

        DateTime currentDT = System.now().addDays(daysNr);
        String retiredStatus = Constants.LEAD_STATUS_RETIRED;
        // SOQL hardening: bind retired status instead of concatenating constant into SOQL.
        return Database.getQueryLocator([
            SELECT Id, Status, RetiredReason__c, RetirementComments__c
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate > :currentDT
            AND Status != :retiredStatus
        ]);
    }
    global void execute(Database.BatchableContext bc, List<Lead> scope){

        General_Parameters__mdt gParam = General_Parameters__mdt.getInstance('SLA_Auto_Lead_Retire');
        Integer daysNr = Integer.valueOf(gParam.Value__c);

        for(Lead tempLeadRecord : scope){
            tempLeadRecord.Status = Constants.LEAD_STATUS_RETIRED;
            tempLeadRecord.RetiredReason__c  = Constants.LEAD_RETIRED_REASON_RETIRED;
            tempLeadRecord.RetirementComments__c = 'Lead automatically retired by the system due to ' + daysNr + ' days inactivity';

            leadsToUpdate.add(tempLeadRecord);
        }
    
        update leadsToUpdate;
        
    }    
    global void finish(Database.BatchableContext bc){}    
}