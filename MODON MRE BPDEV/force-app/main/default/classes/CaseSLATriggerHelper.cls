/**********************************************************************************************************************
* Name               : CaseSLATriggerHelper                                                        
* Description        : Contains SLA-related business logic for CaseSLA__c, including extension processing, SLA creation, and communication tracking.
* Usage              : Called from CaseSLATriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      				Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com		25 Dec 2024     Initial Draft 
* 2.0			ravikumar.pasumarthi@activemindsit.com		25 Dec 2025		Updated the method being called for identifying the MAster SLA record
******************************************************************************************************************/
public without sharing class CaseSLATriggerHelper 
{
    /** 2.0
     * Method Name: emptyMethod
     * Placeholder method for trigger events where no processing is required in handler methods
     */
    public static void emptyMethod(){system.debug('debug: in emptyMethod()');}

    /**2.0
     * Method Name: approveSLAExtensions
     * Handles SLA extension approval or rejection.
     *
     * - On approval: recalculates DueTime__c and marks SLA as Extended.
     * - On rejection: clears extension hours.
     *
     * @param newList  Updated CaseSLA__c records.
     * @param oldMap   Previous record values for comparison.
     */
    public static void approveSLAExtensions(List<CaseSLA__c> newList, Map<Id, sObject> oldMap)
    {
        system.debug('debug: in CaseSLATriggerHelper.approveSLAExtensions method');//
        List<CaseSLA__c> approveList = new List<CaseSLA__c>();
        List<CaseSLA__c> rejectList = new List<CaseSLA__c>();
        Map<Id, CaseSLA__c> oldMaps = (Map<Id, CaseSLA__c>)oldMap;
        for(CaseSLA__c csSLA: (List<CaseSLA__c>) newList)
        {

            CaseSLA__c oldRec = oldMaps.get(csSLA.Id);
            system.debug('debug: csSLA :' + csSLA);
            system.debug('debug: oldRec :' + oldRec);
            system.debug('debug: oldRec.Extension_Approval__c :' + oldRec.Extension_Approval__c);
            system.debug('debug: csSLA.Extension_Approval__c :' + csSLA.Extension_Approval__c);
            if (oldRec != null) 
            {
                system.debug('debug: inside if');
                if (csSLA.Extension_Approval__c == ServiceConstants.CASESLA_EXTENSION_APPROVAL_APPROVED && (oldRec.Extension_Approval__c != ServiceConstants.CASESLA_EXTENSION_APPROVAL_APPROVED || oldRec.Extension_Approval__c ==  null))
                {approveList.add(csSLA);}
                if (csSLA.Extension_Approval__c == ServiceConstants.CASESLA_EXTENSION_APPROVAL_REJECTED && (oldRec.Extension_Approval__c != ServiceConstants.CASESLA_EXTENSION_APPROVAL_REJECTED || oldRec.Extension_Approval__c ==  null))
                {rejectList.add(csSLA);}
            }
        }

        if(approveList.size() > 0)
        {
            system.debug('debug: approveList.size() :' + approveList.size());

            // Get the company business hours
            BusinessHours bussHours = ServiceUtility.getBusinessHours(); 

            // Get the company holidays
            Holiday[] holidays = ServiceUtility.getHolidays();

            for(CaseSLA__c csSLA: approveList)
            {
                system.debug('debug: csSLA details :' + csSLA);
                system.debug('debug: csSLA.DueTime__c :' + csSLA.DueTime__c);
                system.debug('debug: (Integer)(csSLA.Extension_In_Hours__c * 60) :' + (Integer)(csSLA.Extension_In_Hours__c * 60));
                system.debug('debug: bussHours :' + bussHours);
                system.debug('debug: holidays :' + holidays);

                csSLA.DueTime__c = ServiceUtility.CalculateDueDate(csSLA.DueTime__c,(Integer)(csSLA.Extension_In_Hours__c * 60),bussHours,holidays);
                csSLA.Status__c = ServiceConstants.CaseSLA_STATUS_EXTENDED; csSLA.Extension_In_Hours__c = null;
            }
        }

        if(rejectList.size() > 0)
        {
            system.debug('debug: rejectList.size() :' + rejectList.size());
            for(CaseSLA__c csSLA: rejectList){csSLA.Extension_In_Hours__c = null;}
        }
    }
    
    /**2.0
     * Method Name: clearCaseApprovalStatus 
     * Clears Approval_Status__c on related Case records after SLA creation.
     *
     * @param newList  Newly inserted CaseSLA__c records.
     */
    /*public static void clearCaseApprovalStatus(List<SObject> newList)
    {system.debug('debug: in CaseSLATriggerHelper.clearCanCreateSLAFlagOnCase method');
        List<CaseSLA__c> newCaseSLAList = (List<CaseSLA__c>)newList;
     	Boolean shouldUpdate = false;
        if(newCaseSLAList.size() > 0)
        {
            Set<Id> caseIds = new Set<Id>();
            for(CaseSLA__c cs: newCaseSLAList)
            {
                caseIds.add(cs.CaseId__c);
            }
            List<Case> csList = [select id,Approval_Status__c from case where id in: caseIds];
            for(Case cs: csList)
            {
                cs.Approval_Status__c = null;
                shouldUpdate = true;
            }
            if(shouldUpdate == true)
            {
            	update csList;
            }
        }
    }*/
    
    /**2.0
     * Method Name: createSLAForSR
     * Creates and inserts a CaseSLA__c record for a given Service Request.
     *
     * @param rec  ServiceRequest__c record.
     * @return     Inserted CaseSLA__c record.
     */
    public static caseSLA__c createSLAForSR(ServiceRequest__c rec)
    //public static void createSLAForSR(ServiceRequest__c rec)
    {system.debug('debug: in CaseSLATriggerHelper.createSLAForSR method');
		CaseSLA__c sla = new CaseSLA__c();
        if(rec !=null)
        {
			 // Get the company business hours
             BusinessHours bussHours = SystemContextClass.getBusinessHours();
             system.debug('bussHours ' + bussHours);
             // Get the company holidays
             Holiday[] holidays = SystemContextClass.getHolidays();
            system.debug('holidays.size() ' + holidays.size());
            List<Master_SLA__c> masterSLAList = SystemContextClass.getMasterSLADetailsForSR();
            system.debug('masterSLAList.size() ' + masterSLAList.size());
            Master_SLA__c masterSLA = CaseTriggerHelper.identifyMasterSLAForSR(rec.RecordType.Name,null,rec.Type__c,rec.SubType__c,masterSLAList); //2.0
            system.debug('masterSLA ' + masterSLA);
            if(masterSLA != null){sla = prepareServiceRequestSLARecord(rec,masterSLA, bussHours,holidays);}
        }
     	insert sla;return sla;
    }
    
    /**2.0
     * Method Name: prepareServiceRequestSLARecord
     * Prepares SLA record for a Service Request. Calculates due date and sets ownership and status.
     *
     * @param srRec     Service Request record.
     * @param sla       Master SLA configuration.
     * @param bh        Business Hours reference.
     * @param holidays  Holiday list for SLA calculation.
     * @return          Prepared CaseSLA__c record.
     */
    public static CaseSLA__c prepareServiceRequestSLARecord(ServiceRequest__c srRec,Master_SLA__c sla,BusinessHours bh,Holiday[] holidays) // from createCaseSLAs
    {system.debug('debug: in CaseSLATriggerHelper.prepareServiceRequestSLARecord method');
     system.debug('debug: in sla: ' + sla);
     system.debug('debug: in sla.SLA_Hrs__c: ' + sla.SLA_Hrs__c);                                                            
     DateTime currTime = DateTime.now();
     DateTime dueDate = ServiceUtility.CalculateDueDate(currTime,(Integer)sla.SLA_Hrs__c * 60,bh,holidays);
     system.debug('debug: dueDate in prepareCaseSLARecorda:' + dueDate);
     CaseSLA__c csSLA = new CaseSLA__c();
     csSLA.CaseId__c = srRec.CaseId__c;
     //csSLA.CaseOwner__c = srRec.OwnerId;
     csSLA.Service_Request__c = srRec.Id;
     csSLA.OwnerId = srRec.OwnerId;
     csSLA.StartTime__c = currTime;
     csSLA.DueTime__c = dueDate;
     csSLA.Master_SLA__c = sla.Id;
     csSLA.Status__c = ServiceConstants.CaseSLA_STATUS_ONTRACK;
     csSLA.Is_Extension_Allowed__c = sla.Is_Available_For_Extension__c;
     return csSLA;
    }
    
    /**2.0
     * Method Name: updateCustomerCommunicationTime
 * Updates Customer_Communication_Sent_At__c when Customer_Communication__c changes.
 * @param newList  Updated CaseSLA__c records.
 * @param oldMap   Previous record values.
 */
    public static void updateCustomerCommunicationTime(List<CaseSLA__c> newList, Map<Id, sObject> oldMap)
    {system.debug('debug: in CaseSLATriggerHelper.updateCommunicationTime method');
        Map<Id, CaseSLA__c> oldMaps = (Map<Id, CaseSLA__c>)oldMap;
        for(CaseSLA__c csSLA: (List<CaseSLA__c>) newList)
        {
            CaseSLA__c oldRec = oldMaps.get(csSLA.Id);
            if(oldRec.Customer_Communication__c != csSLA.Customer_Communication__c)
            {
                csSLA.Customer_Communication_Sent_At__c = DateTime.Now();
            }
        }
    }
    
    /*public static void clearCanCreateSLAFlagOnCase(List<SObject> newList)
    {system.debug('debug: in CaseSLATriggerHelper.clearCanCreateSLAFlagOnCase method');
        List<CaseSLA__c> newCaseSLAList = (List<CaseSLA__c>)newList;
     	Boolean shouldUpdate = false;
        if(newCaseSLAList.size() > 0)
        {
            Set<Id> caseIds = new Set<Id>();
            for(CaseSLA__c cs: newCaseSLAList)
            {
                caseIds.add(cs.CaseId__c);
            }
            List<Case> csList = [select id,CanCreateSLA__c from case where id in: caseIds AND CanCreateSLA__c = true];
            for(Case cs: csList)
            {
                cs.CanCreateSLA__c = false;
                shouldUpdate = true;
            }
            if(shouldUpdate == true)
            {
            	update csList;
            }
        }
    }*/

    /*public static void checkSLAExtensions(List<CaseSLA__c> newList, Map<Id, sObject> oldMap)
    {
        Set<Id> masterSLAIds = new Set<Id>();
        List<CaseSLA__c> checkcsSLAList = new List<CaseSLA__c>();

        for(CaseSLA__c csSLA: (List<CaseSLA__c>) newList)
        {
            CaseSLA__c oldRec = (CaseSLA__c)oldMap.get(csSLA.Id);
            if (csSLA.Request_Extension__c == true && oldRec.Request_Extension__c == false)
            {
                checkcsSLAList.add(csSLA);
                masterSLAIds.add(csSLA.Master_SLA__c);
            }
        }

        if(checkcsSLAList.size() > 0)
        {
            Map<Id, boolean> masterSLAExtensionMap = new Map<Id, boolean>();
           for(Master_SLA__c masterSLA: [select id,Is_Available_For_Extension__c from Master_SLA__c where id in: masterSLAIds])
           {
                masterSLAExtensionMap.put(masterSLA.Id, masterSLA.Is_Available_For_Extension__c);
           }

           for(CaseSLA__c csSLA: checkcsSLAList)
           {
                if(masterSLAExtensionMap.get(csSLA.Master_SLA__c) == false)
                {
                    throw new ServiceCustomException('Sorry!! This Milestone cannot be extended.');
                }
           }
        }
    }*/
}