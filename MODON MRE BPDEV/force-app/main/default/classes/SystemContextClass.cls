/**********************************************************************************************************************
* Name               : SystemContextClass                                                        
* Description        : Centralized data access layer for SOQL queries used across Case, SLA, Queue, and Assignment logic.
* Usage              : Called from ServcieUtility,CaseTriggerHelper
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      04 Mar 2025     Initial Draft 
* 2.0			ravikumar.pasumarthi@activemindsit.com		12 Dec 2025		Change in isExternalChannelCase method
* 3.0			ravikumar.pasumarthi@activemindsit.com		12 May 2026		Added method getUserGroups
* 4.0			ravikumar.pasumarthi@activemindsit.com		26 May 2026		Added method getAccountFromSO
* 5.0           jay.patel                                   28 Aug 2026     Bulk query helpers for CaseTriggerHelper
* 6.0           jay.patel                                   04 Sep 2026     Include PersonContactId on Account queries used by identifyCustomer (MCR-215)
***********************************************************************************************************************/
public without sharing class SystemContextClass {
    
    /**
     * Method Name: getHolidays
     * Retrieves all Holiday records.
     * @return Holiday[]
     */
    public static Holiday[] getHolidays()//from CaseTriggerHelper.createCaseSLAs,createSLAForSR, ServiceUtility.getHolidays,isHoliday 
    {system.debug('debug: in SystemContextClass.getHolidays method');
        return [SELECT Id,ActivityDate,IsRecurrence FROM Holiday];
    }
    
    /**
     * Method Name: getBusinessHours
     * Retrieves default Business Hours.
     * @return BusinessHours
     */
    public static BusinessHours getBusinessHours()//from CaseSLATriggerHelper.approveSLAExtensions, CaseTriggerHelper.createCaseSLAs,createSLAForSR, ServiceUtility.getBusinessHours,isWithinBusinessHours
    {system.debug('debug: in SystemContextClass.getBusinessHours method');
        return [SELECT Id FROM BusinessHours WHERE IsDefault = true Limit 1];
    }
    
    /**
     * Method Name: getActiveBusinessHours
     * Returns active Business Hours mapped by Name.
     * @return Map<String, BusinessHours>
     */
    public static Map<String, BusinessHours> getActiveBusinessHours()//from CaseSLATriggerHelper.approveSLAExtensions, CaseTriggerHelper.createCaseSLAs,createSLAForSR, ServiceUtility.getBusinessHours,isWithinBusinessHours
    {system.debug('debug: in SystemContextClass.getActiveBusinessHours method');
     	List<BusinessHours> allHours = [SELECT Id, Name FROM BusinessHours where IsActive = true order by Name];
     	Map<String,BusinessHours> mapBH = new Map<String,BusinessHours>();
         for (BusinessHours bh : allHours) {
            mapBH.put(bh.Name, bh);
        }
        return mapBH;
    }
    
    /**
     * Method Name: getActiveBusinessHoursBasedOnId
     * Returns active Business Hours mapped by Id.
     * @return Map<Id, BusinessHours>
     */
    public static Map<Id, BusinessHours> getActiveBusinessHoursBasedOnId()//from CaseSLATriggerHelper.approveSLAExtensions, CaseTriggerHelper.createCaseSLAs,createSLAForSR, ServiceUtility.getBusinessHours,isWithinBusinessHours
    {system.debug('debug: in SystemContextClass.getActiveBusinessHours method');
     	List<BusinessHours> allHours = [SELECT Id, Name FROM BusinessHours where IsActive = true order by Name];
     	Map<Id,BusinessHours> mapBH = new Map<Id,BusinessHours>();
         for (BusinessHours bh : allHours) {
            mapBH.put(bh.Id, bh);
        }
        return mapBH;
    }
    
    /**
     * Method Name: getAccounts
     * Retrieves Account records by Id.
     * @param accountIds Set of Account Ids.
     * @return List<Account>
     */
	public static List<Account> getAccounts(Set<Id> accountIds)//from CaseTriggerHelper.identifyCustomer,updatePrimaryAssigneeForVIPCases,updatePrimaryAssigneeForVIPCases
    {system.debug('debug: in SystemContextClass.getAccounts method');
        return [select Id,Name, ownerid,Account_Manager__c,Account_Manager__r.Email,Account_Manager__r.Name,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c from account where id in: accountIds];
    }
    
    /**
     * Method Name: getAccountsOfContacts
     * Retrieves AccountId for given Contact Ids.
     * @param contactIds Set of Contact Ids.
     * @return List<Contact>
     */
    public static List<Contact> getAccountsOfContacts(Set<Id> contactIds)//from CaseTriggerHelper.updatePrimaryAssigneeForVIPCases
    {system.debug('debug: in SystemContextClass.getAccountsOfContacts method');
        return [select id,AccountId from contact where id in: contactIds];
    }
    
    /**
     * Method Name: getMasterSLADetailsForCase
     * Retrieves active Master SLA records for Case object.
     * @return List<Master_SLA__c>
     */
    public static List<Master_SLA__c> getMasterSLADetailsForCase()//from CaseTriggerHelper.createCaseSLAs,getQueueOrOwnerIdBasedOnCategoryAndSubCategory,getQueueOrOwnerIdBasedOnCategoryAndSubCategoryV1
    {system.debug('debug: in SystemContextClass.getMasterSLADetailsForCase method');
        List<Master_SLA__c> masterSLAList =  [SELECT ID,Name,Category__c,Sub_Category__c,SLA_Hrs__c,Case_Type__c,Is_Available_For_Extension__c,GroupName__c,Case_Origin__c,Send_Survey__c,Escalation_1_Contact__c,Escalation_2_Contact__c,Escalation_3_Contact__c,GroupLead__c,Response_SLA__c,Escalation_1_SLA__c,Escalation_2_SLA__c,Escalation_3_SLA__c,Business_Hours__c from Master_SLA__c where ObjectName__c = :ServiceConstants.SOBJECT_CASE and IsActive__c = true order by name desc];
     	system.debug('debug: masterSLAList.size() ' + masterSLAList.size());	system.debug('debug: masterSLAList ' + masterSLAList);
     	return masterSLAList;
    }
    
    /**
     * Method Name: getMasterSLADetailsForSR
     * Retrieves active Master SLA records for Service Request object.
     * @return List<Master_SLA__c>
     */
	public static List<Master_SLA__c> getMasterSLADetailsForSR()//from CaseTriggerHelper.createSLAForSR
    {system.debug('debug: in SystemContextClass.getMasterSLADetailsForSR method');
        List<Master_SLA__c> masterSLAList =  [SELECT ID,Name,Category__c,Sub_Category__c,SLA_Hrs__c,Case_Type__c,Is_Available_For_Extension__c,GroupName__c,Case_Origin__c,Send_Survey__c,Escalation_1_Contact__c,Escalation_2_Contact__c,Escalation_3_Contact__c,GroupLead__c,Response_SLA__c,Escalation_1_SLA__c,Escalation_2_SLA__c,Escalation_3_SLA__c,Business_Hours__c from Master_SLA__c where ObjectName__c = :ServiceConstants.SOBJECT_SR and IsActive__c = true order by name desc];
     	system.debug('debug: masterSLAList.size() ' + masterSLAList.size());	system.debug('debug: masterSLAList ' + masterSLAList);
     	return masterSLAList;
    }
    
    /**
     * Method Name: getLoggedInUserDetails
     * Retrieves logged-in user details.
     * @return User
     */
    public static User getLoggedInUserDetails()//from CaseTriggerHelper.updateCaseOrigin, checkIsCaseClosed
    {system.debug('debug: in SystemContextClass.getLoggedInUserDetails method');
        return [SELECT Id,Name,UserName,Email,Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }
    
    /**
     * Method Name: getQueueNames
     * Retrieves all Queue groups.
     * @return List<Group>
     */
    public static List<Group> getQueueNames()//from CaseTriggerHelper.updateOwnerEmail, ServiceUtility.getQueueDevNameIdMap,getQueueIdNameMap,getQueueIdDevNameMap
    {system.debug('debug: in SystemContextClass.getQueueNames method');
        return [SELECT Id, Name, DeveloperName,Email FROM Group WHERE Type = 'Queue'];
    }
    
    /**
     * Method Name: getUserDetails
     * Retrieves User records by Id.
     * @param userIds Set of User Ids.
     * @return List<User>
     */
   public static List<User> getUserDetails(Set<Id> userIds)//from CaseTriggerHelper.updateOwnerEmail
    {system.debug('debug: in SystemContextClass.getUserDetails method');
     //if (!Test.isRunningTest()) 
        //{
        return [SELECT Id, Name, Email,ManagerId,UserName FROM User WHERE Id in : userIds ];
        //} else{
         //   return[SELECT Id, Name, Email, ManagerId FROM User WHERE Profile.name='System Administrator' limit 1];
        //}
    }
    
   /* private static Map<Id, User> userCache = new Map<Id, User>();

    public static List<User> getUserDetails(Set<Id> userIds) {
        System.debug('debug: in SystemContextClass.getUserDetails method');
		List<User> results = new List<User>();
        if (!Test.isRunningTest()) 
        {
        Set<Id> missingIds = new Set<Id>();
        for (Id uid : userIds) {
            if (!userCache.containsKey(uid)) {
                missingIds.add(uid);
            }
        }

        if (!missingIds.isEmpty()) {
            for (User u : [
                SELECT Id, Name, Email, ManagerId
                FROM User
                WHERE Id IN :missingIds
            ]) {
                userCache.put(u.Id, u);
            }
        }

        
        for (Id uid : userIds) {
            if (userCache.containsKey(uid)) {
                results.add(userCache.get(uid));
            }
        }
        }
        else
        {
            for (User u : [
                SELECT Id, Name, Email, ManagerId
                FROM User
                WHERE Profile.name='System Administrator' limit 1
            ]) {
                results.add(u);
            }
             
        }
        return results;
    }*/
    
    /**
     * Method Name: getOpenCases
     * Retrieves all non-closed Case records.
     * @return List<Case>
     */
    public static List<Case> getOpenCases() //from CaseTriggerHelper.assignParentId
    {
        Set<String> excludedStatuses = new Set<String>{
            ServiceConstants.CASE_STATUS_RESOLVED,
            ServiceConstants.CASE_STATUS_CLOSED_WITH_RESOLUTION,
            ServiceConstants.CASE_STATUS_CLOSED_WITHOUT_RESOLUTION,
            ServiceConstants.CASE_STATUS_CLOSED_WITH_SERVICE_REQUEST,
            ServiceConstants.CASE_STATUS_CLOSED
        };
        return [
            SELECT Id, Unit__c, AccountId, CaseCategory__c, CaseSubCategory__c, CreatedDate, CaseType__c, Account_Customer_Type__c, Customer_Phone__c, Customer_Email__c 
            FROM Case 
            WHERE Status NOT IN :excludedStatuses 
            ORDER BY CreatedDate
        ];
    }
    
    /*public static List<Case> getResolvedCases()
    {system.debug('debug: in SystemContextClass.getResolvedCases method');
        String query = 'SELECT Id,Unit__c,AccountId,CaseCategory__c,CaseSubCategory__c,CreatedDate,CaseType__c,Customer_Phone__c,Customer_Email__c ' +
               'FROM Case ' +
               'WHERE Status NOT IN (\'' + ServiceConstants.CASE_STATUS_CLOSED + '\', ' +
                                      '\'' + ServiceConstants.CASE_STATUS_CLOSED_WITH_RESOLUTION + '\', ' +
                                      '\'' + ServiceConstants.CASE_STATUS_CLOSED_WITHOUT_RESOLUTION + '\', ' +
                                      '\'' + ServiceConstants.CASE_STATUS_CLOSED_WITH_SERVICE_REQUEST + '\') ' +
               'ORDER BY CreatedDate';
     	system.debug('Query : ' + query);
        List<Case> openCases = Database.query(query);
        return openCases;
    } */

    /**
     * Method Name: getRoundRobinMembers
     * Retrieves Round Robin assignment members.
     * @return Map<Id, RoundRobinAssignmentMatrix__c>
     */
    public static Map<Id,RoundRobinAssignmentMatrix__c> getRoundRobinMembers() // from assignToQueueMembers, updateRRMatrix
    {system.debug('debug: in SystemContextClass.getRoundRobinMembers method');
     Map<Id,RoundRobinAssignmentMatrix__c> rrMemberMap = new Map<Id,RoundRobinAssignmentMatrix__c>();
     for(RoundRobinAssignmentMatrix__c rec: [select id, User__c,From_Date__c, User_Queue__c ,To_Date__C,Threshold__c,CurrentLoad__c,Language__c,LastAssignmentTime__c from RoundRobinAssignmentMatrix__c where Application_Type__c = :ServiceConstants.ROUNDROBIN_APPLICATION_TYPE_SERVICE_CLOUD order by LastAssignmentTime__c])
     {
         system.debug('debug: rec.User__c ' + rec.User__c);
         system.debug('debug: rec ' + rec);
         rrMemberMap.put(rec.User__c,rec);
     }
     system.debug('debug: rrMemberMap' + rrMemberMap);
     return rrMemberMap;
    }
    
   /* public static List<AggregateResult> getOpenCasesAggregatedBySpecificOwners(List<Id> allMemberIds)
    {system.debug('debug: in SystemContextClass.getOpenCasesAggregatedBySpecificOwners method');
        String query = 'SELECT OwnerId, COUNT(Id) caseCount ' +
            'FROM Case ' +
            'WHERE OwnerId IN : allMemberIds ' +
            'AND Status NOT IN (\'' + ServiceConstants.CASE_STATUS_RESOLVED + '\', ' +
            '\'' + ServiceConstants.CASE_STATUS_CLOSED_WITH_RESOLUTION + '\', ' +
            '\'' + ServiceConstants.CASE_STATUS_CLOSED_WITHOUT_RESOLUTION + '\', ' +
            '\'' + ServiceConstants.CASE_STATUS_CLOSED_WITH_SERVICE_REQUEST + '\', ' +
            '\'' + ServiceConstants.CASE_STATUS_CLOSED + '\') ' +
            'GROUP BY OwnerId';
        system.debug('query :' + query);
        return Database.query(query);//[SELECT OwnerId, COUNT(Id) caseCount FROM Case WHERE OwnerId IN :allMemberIds GROUP BY OwnerId];
    }*/
    
    /**
     * Method Name: getAccountsByUnitIds
     * Retrieves Unit records linked to Accounts.
     * @param unitIdSet Set of Unit Ids.
     * @return List<Unit__c>
     */
    public static List<unit__c> getAccountsByUnitIds(Set<Id> unitIdSet) //from CaseTriggerHelper.identifyCustomer
    {system.debug('debug: in SystemContextClass.getAccountsByUnitIds method');
        set <id> accountIdSet = new set <id>();
        List<unit__c> unitList = [SELECT Id,name,Opportunity__r.AccountId from unit__c where Opportunity__r.AccountId  != null and Id in:unitIdSet  limit 100];
     	return unitList;    
    }
    
    /**
     * Method Name: getAccountsByAccountIds
     * Retrieves Account records by Account Ids.
     * @param accountIdSet Set of Account Ids.
     * @return List<Account>
     */
    public static List<Account> getAccountsByAccountIds(Set<Id> accountIdSet) //from CaseTriggerHelper.identifyCustomer
    {system.debug('debug: in SystemContextClass.getAccountsByAccountIds method');
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> accountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts order by CreatedDate desc limit 1) from account where id in :accountIdSet];
        return accountList;
    }
    
    /**
     * Method Name: getAccountsByContactIds
     * Retrieves Accounts linked to given Contacts.
     * @param contactIdSet Set of Contact Ids.
     * @return List<Account>
     */
    public static List<Account> getAccountsByContactIds(Set<Id> contactIdSet)// from CaseTriggerHelper.identifyCustomer
    {system.debug('debug: in SystemContextClass.getAccountsByContactIds method');
		List<Contact> contactList = [select id,AccountId from contact where Id in : contactIdSet];
		Set<Id> accountIdSet = new Set<Id>();
     	 for(Contact con: contactList)
         {
             accountIdSet.add(con.AccountId);
             contactIdSet.add(con.Id);
         }
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> accountList = [SELECT Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts where Id in : contactIdSet order by CreatedDate desc limit 1) FROM Account WHERE Id IN :accountIdSet];
		system.debug('debug: accountList' + accountList);	system.debug('debug: accountList' + accountList.size());
        return accountList;
    }
    
    /**
     * Method Name: getAccountsByEmirateIds
     * Retrieves Accounts using Emirates ID values.
     * @param emiratesIdSet Set of Emirates IDs.
     * @return List<Account>
     */
    public static List<Account> getAccountsByEmirateIds(Set<string> emiratesIdSet)// from CaseTriggerHelper.identifyCustomer
    {system.debug('debug: in SystemContextClass.getAccountsByEmirateIds method');
     List<Contact> contactList = [select id,AccountId from contact where EIDNumber__c in : emiratesIdSet];
		Set<Id> accountIdSet = new Set<Id>();
     	Set<Id> contactIdSet = new Set<Id>();
         for(Contact con: contactList)
         {
             accountIdSet.add(con.AccountId);
             contactIdSet.add(con.Id);
         }
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> accountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts order by CreatedDate desc limit 1) from account where EIDNumber__pc in :emiratesIdSet];
		system.debug('debug: accountList' + accountList);	system.debug('debug: accountList' + accountList.size());
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> secondAccountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts where Id in : contactIdSet order by CreatedDate desc limit 1) from Account where Id in :accountIdSet];
		system.debug('debug: secondAccountList' + secondAccountList);	system.debug('debug: secondAccountList' + secondAccountList.size()); 
		accountList.addAll(secondAccountList);
		system.debug('debug: total accountList' + accountList);	system.debug('debug: total accountList' + accountList.size());
        return accountList;
    }
    
    /**
     * Method Name: getAccountsByPhone
     * Retrieves Accounts using phone numbers.
     * @param phoneSet Set of phone numbers.
     * @return List<Account>
     */
    public static List<Account> getAccountsByPhone(Set<string> phoneSet)// from CaseTriggerHelper.identifyCustomer
    {system.debug('debug: in SystemContextClass.getAccountsByPhone method');	system.debug('debug: phoneSet' + phoneSet);
     	List<Contact> contactList = [select id,AccountId,MobilePhone,Phone from contact where (Phone in : phoneSet or MobilePhone in :phoneSet) order by CreatedDate desc];
     	//List<Contact> contactListPersonAccount = [select id,AccountId,MobilePhone,Phone from contact where is_active__c = true and (Phone in : phoneSet or Account.PersonMobilePhone in :phoneSet) order by LastModifiedDate desc];
		Set<Id> accountIdSet = new Set<Id>();
		Set<Id> contactIdSet = new Set<Id>();
         for(Contact con: contactList)
         {
             accountIdSet.add(con.AccountId);
             contactIdSet.add(con.Id);
         }
     	
     //contactSet.addAll(contactList);
     	system.debug('debug: accountIdSet' + accountIdSet);	system.debug('debug: contactIdSet' + contactIdSet);
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> accountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts order by CreatedDate desc limit 1) from account where (Phone in :phoneSet or PersonMobilePhone in :phoneSet)]; // If search number is from personaccount
     	system.debug('debug: accountList' + accountList);	system.debug('debug: accountList' + accountList.size());
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> secondAccountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts where Id in : contactIdSet order by CreatedDate desc limit 1) from Account where Id in :accountIdSet];
		system.debug('debug: secondAccountList' + secondAccountList);	system.debug('debug: secondAccountList' + secondAccountList.size()); 
		accountList.addAll(secondAccountList);
     	system.debug('debug: total accountList' + accountList);	system.debug('debug: total accountList' + accountList.size());
     	//List<Account> accountContatList = [select Id,Name,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,(select id,name,email,phone,EIDNumber__c from contacts where is_active__c = true limit 1) from account where Phone in :phoneSet];
        return accountList;
    }
    
    /**
     * Method Name: getAccountsByEmail
     * Retrieves Accounts using email addresses.
     * @param emailSet Set of emails.
     * @return List<Account>
     */
    public static List<Account> getAccountsByEmail(Set<string> emailSet)// from CaseTriggerHelper.identifyCustomer
    {system.debug('debug: in SystemContextClass.getAccountsByEmail method');
     	List<Contact> contactList = [select id,AccountId from contact where email in : emailSet];
		Set<Id> accountIdSet = new Set<Id>();
		Set<Id> contactIdSet = new Set<Id>();
         for(Contact con: contactList)
         {
             accountIdSet.add(con.AccountId);
             contactIdSet.add(con.Id);
         }
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> accountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts order by CreatedDate desc limit 1) from account where PersonEmail in :emailSet];
		system.debug('debug: accountList' + accountList);	system.debug('debug: accountList' + accountList.size());
        //6.0 MCR-215: Include PersonContactId for identifyCustomer
        List<Account> secondAccountList = [select Id,Name,PersonMobilePhone,Phone,PersonEmail,PersonContactId,CustomerType__c,Account_Manager__c,RecordType.Name,EIDNumber__pc,Classification_Level_1__c,Classification_Level_2__c,Classification_Level_3__c,(select id,name,email,phone,MobilePhone,EIDNumber__c from contacts where Id in : contactIdSet order by CreatedDate desc limit 1) from Account where Id in :accountIdSet];
		system.debug('debug: secondAccountList' + secondAccountList);	system.debug('debug: secondAccountList' + secondAccountList.size()); 
		accountList.addAll(secondAccountList);
		system.debug('debug: total accountList' + accountList);	system.debug('debug: total accountList' + accountList.size());
        return accountList;
    }
    
    /**
     * Method Name: getPendingApprovalRequests
     * Retrieves latest pending approval requests.
     * @param idSet Target record Ids.
     * @return List<ProcessInstance>
     */
    public static List<ProcessInstance> getPendingApprovalRequests(Set<Id> idSet)//from CaseTriggerHelper.removeDepartmentTransferPendingCases
    {
        List<ProcessInstance> procIns = [SELECT Id,Status,TargetObjectId  FROM ProcessInstance WHERE TargetObjectId in :idSet ORDER BY CreatedDate DESC LIMIT 1];
        return procIns;
    }
    
    /**
     * Method Name: getCaseSLAs
     * Retrieves CaseSLA records for given Cases.
     * @param caseIdSet Set of Case Ids.
     * @return List<CaseSLA__c>
     */
    public static List<CaseSLA__c> getCaseSLAs(Set<Id> caseIdSet)//from ServiceUtility.getPendingSLAExtensions
    {
        return [SELECT Id,Status__c,CaseId__c from CaseSLA__c where CaseId__c in :caseIdSet];
    }
    
    /**
     * Method Name: getOpenTasksForCases
     * Retrieves open Tasks for given Cases.
     * @param caseIdSet Set of Case Ids.
     * @return List<Task>
     */
    public static List<Task> getOpenTasksForCases(Set<Id> caseIdSet)//from ServiceUtility.getOpenTasks
    {
        List<Task> openTaskList = [Select Id,WhatId,Status,OwnerId from task where whatid in :caseIdSet and IsClosed = false];system.debug('openTask :' + openTaskList);
        return openTaskList;
    }
    
    /**
     * Method Name: getOpportunitiesWithUnits
     * Retrieves Opportunities with active Units.
     * @param accountIds Set of Account Ids.
     * @return List<Opportunity>
     */
    public static List<opportunity> getOpportunitiesWithUnits(Set<Id> accountIds)//from CaseTriggerHelper.validateUnit
    {
        List<Opportunity> oppList = [Select Id,Unit__c,AccountId from Opportunity where AccountId in :accountIds and Unit__r.BlockReason__c != :ServiceConstants.UNIT_BLOCK_REASON]; system.debug('oppList.size() :' + oppList.size());
        return oppList;
    }
    
    /**
     * Method Name: getAccountOfUnits
     * Retrieves Unit records with related Account.
     * @param unitIds Set of Unit Ids.
     * @return List<Unit__c>
     */
    public static List<Unit__c> getAccountOfUnits(Set<Id> unitIds)//from CaseTriggerHelper.validateUnit
    {
        List<Unit__c> unitList = [select id,Opportunity__c,Opportunity__r.AccountId from unit__c where Id in :unitIds]; system.debug('unitList.size() :' + unitList.size());
        return unitList;
    }
    
    /**
     * Method Name: getCurrentUserGroups
     * Retrieves groups associated with current user.
     * @return List<GroupMember>
     */
    public static List<GroupMember> getCurrentUserGroups()
    {
        List<GroupMember> grps = [select Id,userorgroupid,userorgroup.name,userorgroup.email,Group.name,groupid,Group.DeveloperName from groupmember where userorgroup.name != null and userorgroupid = :UserInfo.getUserId()];
        return grps;
    }
    
    public static User getUserDetailsBasedOnUserName(string userName)
    {
        User usr = [select Id,Name,UserName from User where UserName = :userName and IsActive = true limit 1];
        return usr;
    } 
    
    /*public static void grantCaseAccess(List<CaseShare> caseShares)
    {
        insert caseShares;
    }*/
    
    public static SalesOrder__c getLatestSalesOrderOfUnit(string unitId)
    {
        List<SalesOrder__c> so = new List<SalesOrder__c>();
        so = [select Id,Status__c from SalesOrder__c where Unit__c = :unitId and Status__c NOT IN :Label.Case_Unit_SO_Exclude_Status.split(',') ORDER BY CreatedDate DESC];//3.0
        system.debug('debug: so ' + so);
        if(so != null && so.size() >0)
            return so[0];
        else 
            return null;
    }
    
    public static List<GroupMember> getUserGroups(string userId)//3.0
    {
        List<GroupMember> grps = [select Id,userorgroupid,userorgroup.name,userorgroup.email,Group.name,groupid,Group.DeveloperName from groupmember where userorgroup.name != null and userorgroupid = :userId];
        return grps;
    }
    
    public static string getAccountFromSO(Id soId)//4.0
    {
        Id accountId;
        SalesOrder__c so = [SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id = :soId limit 1];
        accountId = (so != null) ? so.CustomerAccount__c : null;
        return accountId;
    }

    public static Map<Id, Id> getLatestSalesOrdersByUnitIds(Set<Id> unitIds)//5.0
    {
        Map<Id, Id> unitToSoMap = new Map<Id, Id>();
        if(unitIds == null || unitIds.isEmpty())
        {
            return unitToSoMap;
        }
        for(SalesOrder__c so : [
            SELECT Id, Unit__c
            FROM SalesOrder__c
            WHERE Unit__c IN :unitIds
            AND Status__c NOT IN :Label.Case_Unit_SO_Exclude_Status.split(',')
            ORDER BY CreatedDate DESC
        ])
        {
            if(so.Unit__c != null && !unitToSoMap.containsKey(so.Unit__c))
            {
                unitToSoMap.put(so.Unit__c, so.Id);
            }
        }
        return unitToSoMap;
    }

    public static Map<Id, Id> getAccountsFromSalesOrders(Set<Id> soIds)//5.0
    {
        Map<Id, Id> soToAccountMap = new Map<Id, Id>();
        if(soIds == null || soIds.isEmpty())
        {
            return soToAccountMap;
        }
        for(SalesOrder__c so : [SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id IN :soIds])
        {
            soToAccountMap.put(so.Id, so.CustomerAccount__c);
        }
        return soToAccountMap;
    }

    public static List<GroupMember> getUserGroupsByUserIds(Set<Id> userIds)//5.0
    {
        if(userIds == null || userIds.isEmpty())
        {
            return new List<GroupMember>();
        }
        return [
            SELECT Id, UserOrGroupId, UserOrGroup.Name, UserOrGroup.Email, Group.Name, GroupId, Group.DeveloperName
            FROM GroupMember
            WHERE UserOrGroup.Name != null
            AND UserOrGroupId IN :userIds
        ];
    }

    public static User findActiveUserByUserName(String userName)//5.0
    {
        if(String.isBlank(userName))
        {
            return null;
        }
        List<User> users = [SELECT Id, Name, UserName FROM User WHERE UserName = :userName AND IsActive = true LIMIT 1];
        return users.isEmpty() ? null : users[0];
    }

    public static List<Task> getTasksByWhatIds(Set<Id> whatIds)//5.0
    {
        if(whatIds == null || whatIds.isEmpty())
        {
            return new List<Task>();
        }
        return [SELECT Id, WhatId, Status, OwnerId FROM Task WHERE WhatId IN :whatIds];
    }
        
}