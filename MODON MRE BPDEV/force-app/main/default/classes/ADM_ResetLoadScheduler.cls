public class ADM_ResetLoadScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        List<AssignmentUser__c> usersToReset = [
            SELECT Id, Current_Load__c
            FROM AssignmentUser__c
            WHERE IsActive__c = true AND Current_Load__c > 0
        ];

        for (AssignmentUser__c user : usersToReset) {
            user.Current_Load__c = 0;
        }

        if (!usersToReset.isEmpty()) {
            update usersToReset;
        }
    }
}