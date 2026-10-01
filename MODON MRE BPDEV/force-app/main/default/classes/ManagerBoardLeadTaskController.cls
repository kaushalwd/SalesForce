/**********************************************************************************************************************
* Name               : ManagerBoardLeadTaskController                                                        
* Description        : This class is used as a backend report for the Managers
* Usage              : Called from LWC LeadTaskPivot component
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           rajasekhar.raghavarapu@activemindsit.com    03 Jul 2025     Initial Draft          
* 2.0           ravikumar.pasumarthi@activemindsit.com     11 Mar 2026     Move profile names to custom labels from hardcoding
***********************************************************************************************************************/
public with sharing class ManagerBoardLeadTaskController {

    @AuraEnabled(cacheable=true)
    public static List<LeadWrapper> getLeadsWithTasks() {
        //Variable declaration
        List<LeadWrapper> wrappers = new List<LeadWrapper>();
        List<Lead> leads = new List<Lead>();
        List<String> profileNames = new List<String>();
        // Get the profile names from custom label configurations
        String profileLabel = System.Label.ManagerBoardLeadTask_Profiles;
        for(String p : profileLabel.split(',')){
            profileNames.add(p.trim());
            system.debug('Check for ProfileLabel' + p);
        }
        
        // Fetch the leads based on the profiles
        if(profileNames.size() > 0)
        {
            leads = [
                SELECT Id, LeadSource, Owner.Name, CreatedDate, Status, LeadNumber__c,
                    (SELECT Id, Subject FROM Tasks  ORDER BY CreatedDate ASC LIMIT 3)
                FROM Lead
                WHERE LeadOwnerProfileName__c IN :profileNames
            AND Status in ('New', 'In Progress', 'Qualified', 'Lead Qualified')
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        }
        // Create LeadWrapper instances for each Lead
        for (Lead l : leads) {
            LeadWrapper w = new LeadWrapper();
            w.leadId = l.Id;
            w.leadSource = l.LeadSource;
            w.ownerName = l.Owner.Name;
            w.createdDate = l.CreatedDate;
            w.status = l.Status;
            w.leadNumber = l.LeadNumber__c;
            w.leadUrl = '/' + l.Id;

            // Initialize task subjects
           Integer index = 0;
                for (Task t : l.Tasks) {
                    if (index == 0) {
                        w.task1 = t.Subject;
                        w.task1Url = '/' + t.Id;
                    } else if (index == 1) {
                        w.task2 = t.Subject;
                        w.task2Url = '/' + t.Id;
                    } else if (index == 2) {
                        w.task3 = t.Subject;
                        w.task3Url = '/' + t.Id;
                    }
                    index++;
                }
            wrappers.add(w);
        }

        return wrappers;
    }

    public class LeadWrapper {
        @AuraEnabled public Id leadId;
        @AuraEnabled public String leadSource;
        @AuraEnabled public String ownerName;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String status;
        @AuraEnabled public String leadNumber;
        @AuraEnabled public String leadUrl;
        @AuraEnabled public String task1;
        @AuraEnabled public String task1Url;
        @AuraEnabled public String task2;
        @AuraEnabled public String task2Url;
        @AuraEnabled public String task3;
        @AuraEnabled public String task3Url;
    }
}