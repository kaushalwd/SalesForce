/**********************************************************************************************************************
 * Name               : ProjectPhasePicklistController
 * Description        : This class is Receipt flow selection in project and phase  
 * Usage              : Called from ProjectPhasePicklistController
 * Created By         : Active minds
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           kumaravel.mathivanan         		21 Dec 2025     Initial Draft 
 * 2.0           Manoj                              27 Jan 2026     Add the logic for the projects filter and paramater 
 ******************************************************************************************************************/
public class ProjectPhasePicklistController {

    @AuraEnabled(cacheable=true)
    public static List<Project__c> getProjects(string EntityName) { // 2.0 
        Map<id,Project__c> projectMap = new Map<id,Project__c>();
        //2.0 Started 
        list<Phase__c> phaseProjectlist = [select id,Name,EntityName__c, Project__c, Project__r.name from Phase__c where EntityName__c =: EntityName and Project__r.name not IN ('Ras El Hekma','Ras El Hekma, Egypt','Ras El Hekma, Egypt(Egypt Only)','Thahr El Bateen','') and Source_Entity__c != 'Modon - Egypt' ORDER BY Name];
        for(Phase__c ph : phaseProjectlist){
                if(!projectMap.containsKey(ph.Project__c)){
                    Project__c pr = new Project__c();
                    pr.name = ph.Project__r.name;
                    pr.id = ph.Project__c;
                    projectMap.put(ph.Project__c,pr); 
                    system.debug('projectMap22---'+projectMap);   
                }else {

                    projectMap.get(ph.Project__c).name = ph.Project__r.name;
                    projectMap.get(ph.Project__c).id = ph.Project__c;
                    system.debug('projectMap27---'+projectMap);
                }
        }
        return projectMap.values(); // End
    }

    @AuraEnabled(cacheable=true)
    public static List<Phase__c> getPhases(Id projectId) {
        return [
            SELECT Id, Name
            FROM Phase__c
            WHERE Project__c = :projectId
            ORDER BY Name
        ];
    }
}