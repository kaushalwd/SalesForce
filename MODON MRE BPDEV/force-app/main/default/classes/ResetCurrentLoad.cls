public class ResetCurrentLoad {
   public static void resetCurrentLoad() {
       
        List<RoundRobinAssignmentMatrix__c> matrixRecords = [SELECT Id, CurrentLoad__c, Application_Type__c 
            FROM RoundRobinAssignmentMatrix__c 
            WHERE Application_Type__c = 'Service Cloud'];
       
        for (RoundRobinAssignmentMatrix__c record : matrixRecords) {
            record.CurrentLoad__c = 0; 
            record.LastAssignmentTime__c = null;
        }
        
        update matrixRecords;
    }
}