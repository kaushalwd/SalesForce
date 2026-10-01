/**********************************************************************************************************************
* Name               : ServiceUtility                                                        
* Description        : Handles multiple utility methods that can be used in general from any functionality in Case, SLA, Business Hours, Queue and Task processing.
* Usage              : Called from CaseTriggerHelper
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      04 Mar 2025     Initial Draft 
* 2.0			ravikumar.pasumarthi@activemindsit.com		12 Dec 2025		Change in isExternalChannelCase method
* 3.0           jay.patel                                   28 Aug 2026     Bulk helpers and chained queueable for CaseTriggerHelper
***********************************************************************************************************************/

public class ServiceUtility {
    
    /**
     * Method Name: getHolidays
     * Retrieves configured Holiday records.
     * @return Holiday[]  List of holidays.
     */
    public static Holiday[] getHolidays() {
        return SystemContextClass.getHolidays();
    }
    
    /**
     * Method Name: isHoliday
     * Checks if a given datetime falls on a holiday.
     * @param checkDate  Date to validate.
     * @return           True if holiday.
     */
    public static boolean isHoliday(Datetime checkDate){
        system.debug('in ServiceUtility.isHoliday 1 parameter method');
        system.debug('checkDate :' + checkDate);
        boolean isCheckDateHoliday = false;
        Holiday[] holidays = SystemContextClass.getHolidays();
        for(Holiday currDay: holidays){if(currDay.ActivityDate == checkDate){isCheckDateHoliday = true;break;}}
        system.debug('isCheckDateHoliday :' + isCheckDateHoliday);
        return isCheckDateHoliday;
    }

    /**
     * Method Name: isHoliday
     * Checks if a given date exists in provided holiday list.
     * @param dueDate   Date to validate.
     * @param holidays  List of holidays.
     * @return          True if holiday.
     */
    public static Boolean isHoliday(Datetime dueDate, List<Holiday> holidays){
        system.debug('in ServiceUtility.isHoliday 2 parameter method');
        system.debug('dueDate :' + dueDate);
        boolean isDueDateHoliday = false;
        for (Holiday holiday : holidays) {if (holiday != null && holiday.ActivityDate == dueDate.date()) {isDueDateHoliday = true;break;}}
        system.debug('isDueDateHoliday :' + isDueDateHoliday);
        return isDueDateHoliday;
    }
    
    /**
     * Method Name: getBusinessHours
     * Retrieves default Business Hours.
     * @return BusinessHours record.
     */
    public static BusinessHours getBusinessHours() {
        return SystemContextClass.getBusinessHours();
    }
    
    /**
     * Method Name: isWithinBusinessHours
     * Checks if current datetime is within business hours.
     * @return True if within business hours.
     */
    public static boolean isWithinBusinessHours(){
        // Get the company business hours
        BusinessHours bussHours = SystemContextClass.getBusinessHours();
        Boolean isWithin= BusinessHours.isWithin(bussHours.id, DateTime.Now());
        return isWithin;
    }

    /**
     * Method Name: isWithinBusinessHours
     * Validates whether a specific datetime falls within given Business Hours.
     * @param dueDate DateTime to check.
     * @param bh BusinessHours record.
     * @return True if within hours.
     */
    public static Boolean isWithinBusinessHours(Datetime dueDate, BusinessHours bh) {
        return BusinessHours.isWithin(bh.Id, dueDate);
    }
    
    /**
     * Method Name: CalculateDueDate
     * Calculates SLA due datetime considering holidays and business hours.
     * @param startDate SLA start time.
     * @param slaInMinutes SLA duration in minutes.
     * @param bh Business Hours.
     * @param holidays Holiday list.
     * @return Calculated due datetime.
     */
    public static Datetime CalculateDueDate(Datetime startDate, Integer slaInMinutes,BusinessHours bh,Holiday[] holidays){
        system.debug('In CalculateDueDate method');  system.debug('startDate : ' + startDate);  system.debug('slaInMinutes : ' + slaInMinutes);        
        // Convert SLA minutes to milliseconds
        Long slaInMillis = slaInMinutes * 60 * 1000L;  system.debug('slaInMillis : ' + slaInMillis);
        // skip any holidays from the start datetime												
        system.debug('wileloop : ' + holidays.size()); while (isHoliday(startDate, holidays)) {startDate = startDate.addDays(1);system.debug('holiday .. startDate moved to :' + startDate);}
        system.debug('bh : ' + bh);
        // if it is non working hours, go to the business start time from the start datetime														   
        while (bh != null && !BusinessHours.isWithin(bh.Id, startDate)) {startDate = BusinessHours.nextStartDate(bh.id, startDate);   system.debug('non business hours ... startDate moved to :' + startDate);}
		Datetime endDate = (bh != null) ? BusinessHours.add(bh.Id, startDate, slaInMillis): startDate;  system.debug('endDate : ' + endDate);        
        // skip any holidays from the end datetime											  
        while (isHoliday(endDate, holidays)) {endDate = endDate.addDays(1); system.debug('enddate moved to :' + endDate);}
        system.debug('endDate calculated : ' + endDate);
        return endDate;
    }
    
    /**
     * Method Name: isStatusClosed
     * Determines if Case status represents a closed state.
     * @param recStatus Case Status value.
     * @return True if closed.
     */
    public static Boolean isStatusClosed(string recStatus){system.debug('in CaseTriggerHelper.isStatusClosed method');
        boolean result = false;                                                     
        if(recStatus == ServiceConstants.CASE_STATUS_CLOSED || recStatus == ServiceConstants.CASE_STATUS_CLOSED_WITH_RESOLUTION || recStatus == ServiceConstants.CASE_STATUS_CLOSED_WITH_SERVICE_REQUEST || recStatus == ServiceConstants.CASE_STATUS_CLOSED_WITHOUT_RESOLUTION  || recStatus == ServiceConstants.CASE_STATUS_CLOSED_AS_DUPLICATE)
        {
            result = true;
        }
        return result;
    }
    
    /*public static Boolean isStatusClosed(string recStatus){system.debug('in CaseTriggerHelper.isStatusClosed method');
        boolean result = false; 
        if(recStatus == ServiceConstants.CASE_STATUS_CLOSED)
        {
            result = true;
        }
        return result;
    }*/

    /**
     * Method Name: getQueueDevNameIdMap
     * Returns map of Queue DeveloperName to Id.
     * @return Map<String, Id>
     */    
    public static Map<String, Id> getQueueDevNameIdMap(){
        Map<String, Id> queueMap = new Map<String, Id>(); //QueueName,QueueId
        List<Group> queueList = SystemContextClass.getQueueNames();
        for (Group grp : queueList) 
        {
            // Populate the queue map with queue developer names and their Ids
            queueMap.put(grp.DeveloperName, grp.Id);
        }
        return queueMap;
    }
    
    /*public static Map<String, Id> getQueueNameIdMap(){
        Map<String, Id> queueMap = new Map<String, Id>(); //QueueName,QueueId
        List<Group> queueList = SystemContextClass.getQueueNames();
        for (Group grp : queueList) 
        {
            // Populate the queue map with queue developer names and their Ids
            queueMap.put(grp.Name, grp.Id);
        }
        return queueMap;
    }*/
    
    /**
     * Method Name: getQueueIdNameMap
     * Returns map of Queue Id to Name.
     * @return Map<Id, String>
     */
    public static Map<Id,String> getQueueIdNameMap(){
        Map<Id,String> queueMap = new Map<Id,String>(); //QueueName,QueueId
        List<Group> queueList = SystemContextClass.getQueueNames();
        for (Group grp : queueList) 
        {
            // Populate the queue map with queue developer names and their Ids
            queueMap.put(grp.Id,grp.Name);
        }
        return queueMap;
    }
    
    /**
     * Method Name: getQueueIdDevNameMap
     * Returns map of Queue Id to DeveloperName.
     * @return Map<Id, String>
     */
    public static Map<Id,String> getQueueIdDevNameMap(){
        Map<Id,String> queueMap = new Map<Id,String>(); //QueueName,QueueId
        List<Group> queueList = SystemContextClass.getQueueNames();
        for (Group grp : queueList) 
        {
            // Populate the queue map with queue developer names and their Ids
            queueMap.put(grp.Id,grp.DeveloperName);
        }
        return queueMap;
    }
    
    /**
     * Method Name: isSFUserId
     * Checks whether an Id represents a Salesforce User.
     * @param userOrGroupId Id to check.
     * @return True if User Id.
     */
    public static boolean isSFUserId(Id userOrGroupId){system.debug('in CaseTriggerHelper.isSFUserId method');
        return (String.valueOf(userOrGroupId).substring(0, 3) == '005');
    }
   
    /*public static boolean hasOpenTask(Id objectId){
        boolean result = false;
        //List<Task> openTaskList = [select id,WhatId,status from task where whatid = :objectId and status != 'Completed']; system.debug('openTask :' + openTaskList);
          List<Task> openTaskList = [select id,WhatId,status from task where whatid = :objectId and 
                                     Status NOT IN ('Completed', 'Customer Not Interested', 'Customer Not Available')]; system.debug('openTask :' + openTaskList);
        if(openTaskList.size() > 0)
        {
            result = true;
        }
        system.debug('result :' + result);   
        return result;
    }*/
    
    /**
     * Method Name: getOpenTasks
     * Retrieves open tasks for given Cases.
     * @param caseIdSet Set of Case Ids.
     * @return Map<CaseId, TaskId>
     */
    public static Map<Id,Id> getOpenTasks(Set<Id> caseIdSet)
    {
        List<Task> tasksList = SystemContextClass.getOpenTasksForCases(caseIdSet); 
        Map<Id,Id> caseTaskMap = new Map<Id, Id>();// CaseId,TaskId
							   
		 
        for(Task tk: tasksList){caseTaskMap.put(tk.WhatId, tk.Id);} return caseTaskMap;
    }

    /**
     * Method Name: getOpenTasksWithDetails
     * Retrieves open task records for given Case Ids.
     * @param caseIdSet Set of Case Ids.
     * @return List<Task>
     */
    public static List<Task> getOpenTasksWithDetails(Set<Id> caseIdSet)
    {
        return SystemContextClass.getOpenTasksForCases(caseIdSet); 
    }

    /**
     * Method Name: loggedInUser
     * Returns current logged-in user Id.
     * @return User Id.
     */
	public static Id loggedInUser()
    {
        return UserInfo.getUserId();
    }
    
    public static User getUserDetailsBasedOnUserName(string userName)
    {
        return SystemContextClass.getUserDetailsBasedOnUserName(userName);
    } 
    
    //2.0
    /**
     * Method Name: isExternalChannelCase
     * Determines whether case originated from an external channel.
     * @param rec Case record.
     * @return True if external channel.
     */
    /*public static boolean isExternalChannelCase(Case rec)
    {							   
        boolean result = false; if(rec.Origin != ServiceConstants.CASE_ORIGIN_FRONT_LINER && rec.Origin != ServiceConstants.CASE_ORIGIN_800MODON){result = true;} return result;						  
    }*/
    
    public static string getLatestSalesOrderOfUnit(string unitId)
    {
        string soId = null;
        if(unitId != null)
        {system.debug('debug: unitId : ' + unitId);
        	SalesOrder__c so = SystemContextClass.getLatestSalesOrderOfUnit(unitId);
        	soId = (so != null) ? so.Id : null;
        }
        system.debug('debug: soId : ' + soId);
        return soId;
    }

    public static Map<Id, Id> getLatestSalesOrdersByUnitIds(Set<Id> unitIds)
    {
        return SystemContextClass.getLatestSalesOrdersByUnitIds(unitIds);
    }

    public static Map<Id, Id> getAccountsFromSalesOrders(Set<Id> soIds)
    {
        return SystemContextClass.getAccountsFromSalesOrders(soIds);
    }

    public static List<GroupMember> getUserGroupsByUserIds(Set<Id> userIds)
    {
        return SystemContextClass.getUserGroupsByUserIds(userIds);
    }

    public static User findActiveUserByUserName(String userName)
    {
        return SystemContextClass.findActiveUserByUserName(userName);
    }
}