global class UpdatTaskAssignmentBatch implements Database.Batchable<SObject>, Schedulable {

    // Fetch subject and queue ID from custom labels
    public static final String TARGET_SUBJECT = System.Label.Task_Subject;
    public static final Id QUEUE_ID =  System.Label.Task_Queue;

    global Database.QueryLocator start(Database.BatchableContext BC) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Subject, ActivityDate, OwnerId 
            FROM Task 
            WHERE Subject = :TARGET_SUBJECT 
              AND ActivityDate = :today
        ]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<Task> tasksToUpdate = new List<Task>();
        for (Task t : (List<Task>) scope) {
            t.OwnerId = QUEUE_ID;
            tasksToUpdate.add(t);
        }

        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Optional: log or notify
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new UpdatTaskAssignmentBatch(), 200);
    }

    public static void scheduleDailyRun() {
        String cronExp = '0 0 2 * * ?'; // Daily at 2 AM
        System.schedule('Daily Task Assignment Batch', cronExp, new UpdatTaskAssignmentBatch());
    }
}