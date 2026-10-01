/**********************************************************************************************************************
* Name               : ServiceUtilityTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Ravikumar.pasumarthi@activemindsit.com      14 Feb 2025     Initial Draft          
******************************************************************************************************************/
@isTest
public class ServiceUtilityTest {
    
    @isTest
    static void testMethods() {
        Test.startTest();
        
        Datetime now = Datetime.now();
        
        List<Holiday> holidayList = ServiceUtility.getHolidays();
        
        Boolean holiday = ServiceUtility.isHoliday(now);
        
        Boolean holiday2 = ServiceUtility.isHoliday(now,holidayList);
        
        BusinessHours bh = ServiceUtility.getBusinessHours();
        
        Boolean isBHNow = ServiceUtility.isWithinBusinessHours();
        
        Boolean isBHNow2 = ServiceUtility.isWithinBusinessHours(now, bh);
        
        Datetime dueDate = ServiceUtility.CalculateDueDate(now, 60, bh, holidayList);
        
        Boolean currrentStatus = ServiceUtility.isStatusClosed('Closed with Resolution');
        
        Map<String , Id> queueName = ServiceUtility.getQueueDevNameIdMap();
        
        Map<Id, String> queueName2 = ServiceUtility.getQueueIdNameMap();
        
        Map<Id, String> queueName3 = ServiceUtility.getQueueIdDevNameMap();
        
        Id loggedinUser = ServiceUtility.loggedInUser();
        
        Boolean isSalesforceUser = ServiceUtility.isSFUserId(loggedinUser);
        
        Map<String, Id> ids = TestDataFactory.createTestData();
        Id testCaseId = ids.get('TestCase'); 
        
        CaseSLA__c sla = new CaseSLA__c();
        sla.CaseId__c = testCaseId;
        sla.StartTime__c = now;
        sla.DueTime__c = dueDate;
        sla.Status__c = 'OnTrack';
        insert sla;
        
        Task tsk = new Task();
        tsk.whatid = testCaseId;
        tsk.Description = 'test task description';
        tsk.Status = 'Open';
        insert tsk;
        
        ProcessDefinition pd = new ProcessDefinition();
        pd = [select id from ProcessDefinition where name = 'Case Manager Approval Process'];
        
        system.debug('case id from test method ' + testCaseId);
        Case rec = [select id,origin from case where origin != null AND Id = :testCaseId LIMIT 1];
        //Boolean channel2 = ServiceUtility.isExternalChannelCase(rec);
        
        Set<Id> caseIdSet = new Set<Id>();
        caseIdSet.add(testCaseId);
        Map<Id,Id> openTasks = ServiceUtility.getOpenTasks(caseIdSet);

        ServiceUtility.getLatestSalesOrdersByUnitIds(new Set<Id>{ ids.get('Unit') });
        ServiceUtility.getAccountsFromSalesOrders(new Set<Id>{ ids.get('SalesOrder') });
        ServiceUtility.getUserGroupsByUserIds(new Set<Id>{ UserInfo.getUserId() });
        ServiceUtility.findActiveUserByUserName(UserInfo.getUserName());
        
        Test.stopTest();
    }
}