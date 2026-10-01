@isTest
public class ConstantsTest {
    static TestMethod void runTest1(){
        Test.startTest();

        System.assertEquals(Constants.TASK_SUBJECT_FOR_LEAD_FOLLOWUP,'Lead - Follow Up');
        System.assertEquals(Constants.SALES_MANAGEMENT_PROFILE_NAME,'Sales Management');
        System.assertEquals(Constants.TASK_STATUS_AUTO_CLOSED,'Auto Closed');
        System.assertEquals(Constants.TASK_STATUS_OPEN,'Open');
        System.assertEquals(Constants.SALES_OPERATIONS_QUEUE_API_NAME,'DuplicateQueue');
        System.assertEquals(Constants.STATUS_AVAILABLE,'Available');
        System.assertEquals(Constants.TASK_STATUS_NOT_INTERESTED,'Customer Not Interested');
        System.assertEquals(Constants.TASK_STATUS_NOT_AVAILABLE,'Customer Not Available');
        System.assertEquals(Constants.LEAD_STATUS_RETIRED,'Retired');
        System.assertEquals(Constants.LEAD_RETIRED_REASON_NO_INTEREST,'No Purchase Interest');
        System.assertEquals(Constants.runRoundRobin,TRUE);

        test.stopTest();
    }
}