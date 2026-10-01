public class autoAssignBroker {

    @AuraEnabled
    public static String autoProcessBrokerSR(Id srId, Id taskId) {

        List<Id> docIds = new List<Id>{
            '069VG00000J2uKvYAJ'
        };

        Map<String, String> result =
            MBP_aiservicerequest.validateDocuments(docIds, null);

       
        ServiceRequest__c sr = [
            SELECT Id, Registration__r.Trade_License_Number__c
            FROM ServiceRequest__c
            WHERE Id = :srId
            LIMIT 1
        ];

        String expectedLicense = sr.Registration__r.Trade_License_Number__c;

        String aiOutput = '';
        for(String key : result.keySet()){
            if(key != 'FINAL_STATUS'){
                aiOutput += result.get(key);
            }
        }

        aiOutput = aiOutput.toUpperCase();
      
        Boolean isMatch = false;

        if(!String.isBlank(expectedLicense)){
            String cleanLicense = expectedLicense.replace(' ', '').toUpperCase();

            if(aiOutput.contains(cleanLicense)){
                isMatch = true;
            }
        }

    

        String finalStatus;
        if(isMatch){
            finalStatus = 'ALL_VALID';
        } else {
            finalStatus = 'SOME_INVALID';
        }


        Task currentTask = [
            SELECT Id, Status, IsClosed, Broker_Registration_Status__c,Comments__c
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];

      if(!currentTask.IsClosed){

    currentTask.Status = 'Completed';
    currentTask.ActivityDate = Date.today();

    if(finalStatus == 'ALL_VALID'){
        currentTask.Broker_Registration_Status__c = 'Approved';
    } else {
        currentTask.Broker_Registration_Status__c = 'Require more Information';

        currentTask.Comments__c = 'Trade License not matched with uploaded document. Please provide valid document.';
    }

    update currentTask;
}
        currentTask = [
            SELECT Id, Status, IsClosed
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];

      
        String nextSubject;
        String returnValue;

        if(finalStatus == 'ALL_VALID'){
            nextSubject = 'Validation by Compliance Team';
            returnValue = 'APPROVED';
        } else {
            nextSubject = 'Require more information';
            returnValue = 'REJECTED';
        }

        List<Task> nextTasks = [
            SELECT Id, Status, IsClosed
            FROM Task
            WHERE WhatId = :srId
            AND Subject = :nextSubject
            LIMIT 1
        ];

        if(!nextTasks.isEmpty()){

            Task nextTask = nextTasks[0];


            if(!nextTask.IsClosed){
                nextTask.Status = 'Open';
                update nextTask;
            }

        } else {


            insert new Task(
                WhatId = srId,
                Subject = nextSubject,
                Status = 'Open'
            );
        }

        return returnValue;
    }

}