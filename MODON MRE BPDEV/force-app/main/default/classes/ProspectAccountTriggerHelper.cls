/**********************************************************************************************************************
* Name               : ProspectAccountTriggerHelper                                                        
* Description        : This class is used as a helper for ProspectAccountTriggerHandler
* Usage              : Called from ProspectAccountTriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           manoj                                    02 Feb 2025     Initial Draft  
* 2.0 			Manoj									 28 Feb 2026	 Update logic to remove creatingDocment
***********************************************************************************************************************/

public without sharing class ProspectAccountTriggerHelper 
{   
    public static void creatingDocment(List<SObject> newList)// from ProspectTriggerHandler.afterInsert
    {
        List<Prospect_Account__c> newt = new List<Prospect_Account__c>();
        Map<String,Prospect_Account__c> AccountIds= new Map<String,Prospect_Account__c>();
        Map<String,String> conIds= new Map<String,String>();
        List<String> PersonconIds= new List<String>();
        for(Prospect_Account__c pa: (List<Prospect_Account__c>)newList){
            if(pa.Account__c==null){
                //newt.add(pa);
            }else{
                AccountIds.put(pa.Account__c,pa);
            }
        }
        if (AccountIds.size() > 0) {
            List<Account> acclist= [SELECT Id,Name,PersonContactId FROM Account WHERE Id IN :AccountIds.keySet() AND IsPersonAccount = true];
            if(acclist.size()>0){
                for(Account acc:acclist){
                    if(acc.PersonContactId!=null){
                        PersonconIds.add(acc.PersonContactId);
                        conIds.put(acc.PersonContactId,acc.Id);
                    }
                }
            }
            List<Documents__c> accDocs = new List<Documents__c>();
            List<Documents__c> conDocs = new List<Documents__c>();
            if(AccountIds.size()>0){
                accDocs = [SELECT Id, Name, Account__c, Prospect_Account__c,PrimaryContact__c
                                          FROM Documents__c 
                                          WHERE Account__c IN :AccountIds.keySet()];
            }
            if(PersonconIds.size()>0){
                conDocs = [SELECT Id, Name, Account__c, Prospect_Account__c,PrimaryContact__c
                                          FROM Documents__c 
                                          WHERE PrimaryContact__c IN: PersonconIds];
            }
          
            if(accDocs.size()>0 ){
                for (Documents__c docs : accDocs) {
                    docs.Prospect_Account__c =  AccountIds.get(docs.Account__c).Id;
                }
            }else if(conDocs.size()>0){
                for (Documents__c docs : conDocs) {
                    docs.Prospect_Account__c = AccountIds.get(conIds.get(docs.PrimaryContact__c)).Id;
                }
            }else{
                for(string acc:AccountIds.keySet()){
                    if(AccountIds.containskey(acc))
                    {
                        newt.add(AccountIds.get(acc));
                    }
                }
            }
            
            // Update the records in the database
            if (!accDocs.isEmpty()) {
                update accDocs;
            }
            if (!conDocs.isEmpty()) {
                update conDocs;
            }
        }
        // if(newt.size()>0){
        //    // DocumentTypeController.creatingDocment(newt,'Prospect Account');     //2.0 
        // }
        
    }
    /*public static void checkProspectAccountAddition(List<Prospect_Account__c> newList)
    {
        Set<Id> srIds = new Set<Id>();
        map<Id,Id> mapPASR = new Map<Id,Id>();
        
        for(Prospect_Account__c pa: newList)
        {
            system.debug('Trying to add the prospect account IN FOR ' + pa.Name);
            srIds.add(pa.Service_Request__c);
            mapPASR.put(pa.Id,pa.Service_Request__c);
        }
        List<ServiceRequest__c> srList = new List<ServiceRequest__c>();
        srList = [Select Id,SubType__c from ServiceRequest__c where id in: srIds];
        Map<Id,String> mapSRSubType = new Map<Id,String>();
        for(ServiceRequest__c sr: srList)
        {
            mapSRSubType.put(sr.Id,sr.SubType__c);
        }
        
        for(Prospect_Account__c pa: newList)
        {
            system.debug('Trying to add the prospect account OUTSIDE IF ' + pa.Name);
            if(mapSRSubType.get(mapPASR.get(pa.Id)) == 'Joint Owner Deletion')
            {
                system.debug('Trying to add the prospect account INSIDE IF' + pa.Name);
                pa.addError('Trying to add the prospect account ' + pa.Name);
                pa.addError('The Service Request is for Joint Owner Deletion. So prospect account cannot be added.');
            }
        }
    }*/
    
    public static void checkProspectAccountDeletion(List<SObject> oldList)
    {
        Set<Id> srIds = new Set<Id>();
        map<Id,Id> mapPASR = new Map<Id,Id>();
        
        for(Prospect_Account__c pa: (List<Prospect_Account__c>)oldList)
        {
            srIds.add(pa.Service_Request__c);
            mapPASR.put(pa.Id,pa.Service_Request__c);
        }
        List<ServiceRequest__c> srList = new List<ServiceRequest__c>();
        srList = [Select Id,SubType__c from ServiceRequest__c where id in: srIds];
        Map<Id,String> mapSRSubType = new Map<Id,String>();
        for(ServiceRequest__c sr: srList)
        {
            mapSRSubType.put(sr.Id,sr.SubType__c);
        }
        
        for(Prospect_Account__c pa: (List<Prospect_Account__c>)oldList)
        {
            if(mapSRSubType.get(mapPASR.get(pa.Id)) == 'Joint Owner Addition')
            {
                pa.addError('The Service Request is for Joint Owner Addition. So prospect account cannot be deleted.');
            }
        }
    } 
    
    
}