public class MBP_TaskAssignment implements Queueable {
    
    private Id serviceRequestId;
    Private String agencyAdminUserId;
    private String ownerUserId;
    
    public MBP_TaskAssignment(Id serviceRequestId, Id agencyAdminUserId, Id ownerUserId) {
        this.serviceRequestId = serviceRequestId;
        this.agencyAdminUserId = agencyAdminUserId;
        this.ownerUserId = ownerUserId;
    }
    public void execute(QueueableContext context){
        List<Task> taskListToUpdate = new List<Task>();
        if (serviceRequestId == null || agencyAdminUserId == null) return;
        
        List<Task> latestTasks = [
            SELECT Id, Subject 
            FROM Task 
            WHERE WhatId = :serviceRequestId 
            AND Subject IN (:BRConstants.SERVICE_REQUEST_TASK2, :BRConstants.SERVICE_REQUEST_TASK4 )
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        system.debug('latestTasks:::'+latestTasks);
        
        if (!latestTasks.isEmpty()) {
            for(Task tsk: latestTasks){
                Task taskToUpdate = new Task();
                taskToUpdate.id = tsk.Id;
                if(tsk.Subject == BRConstants.SERVICE_REQUEST_TASK2){
                    taskToUpdate.OwnerId = agencyAdminUserId;
                }else if(tsk.Subject == BRConstants.SERVICE_REQUEST_TASK4){
                    taskToUpdate.OwnerId = ownerUserId;
                }
                taskListToUpdate.add(taskToUpdate);
                system.debug('taskListToUpdate::'+taskListToUpdate);
            }
            update taskListToUpdate;
        }
    }
}