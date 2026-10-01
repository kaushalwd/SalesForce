public class autoAssignBrokerQueue implements Queueable, Database.AllowsCallouts {

    Set<Id> srIds;
    Integer attempt;

    public autoAssignBrokerQueue(Set<Id> srIds, Integer attempt){
        this.srIds = srIds;
        this.attempt = attempt;
    }

    public void execute(QueueableContext context){

        List<Task> assignmentTasks = [
            SELECT Id, WhatId
            FROM Task
            WHERE WhatId IN :srIds
            AND Subject = 'Assignment of Broker Manager'
        ];

        if(!assignmentTasks.isEmpty()){

            for(Task t : assignmentTasks){
                String res = autoAssignBroker.autoProcessBrokerSR(t.WhatId, t.Id);
               
            }

        } else if(attempt < 3 && !Test.isRunningTest()){

            System.enqueueJob(new autoAssignBrokerQueue(srIds, attempt + 1));

        }
    }
}