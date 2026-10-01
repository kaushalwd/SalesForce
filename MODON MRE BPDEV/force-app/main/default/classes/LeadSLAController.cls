public with sharing class LeadSLAController {
   
@AuraEnabled(cacheable=true)
public static Task getActiveTask(Id leadId) {
   
        List<Task> tasks = [
            SELECT Id, Subject, Status, CurrentTaskSLA__c
            FROM Task
            WHERE WhoId = :leadId AND IsClosed != true
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return tasks.isEmpty() ? null : tasks[0];

   
}
}