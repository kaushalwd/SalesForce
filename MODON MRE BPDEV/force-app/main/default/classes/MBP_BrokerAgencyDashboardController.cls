/**********************************************************************************************************************
* Name               : MBP_BrokerAgencyDashboardController                                                       
* Description        : This class is for managing agents
* Usage              : 
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sanath H M              01 July 2025     
******************************************************************************************************************/
public with sharing class MBP_BrokerAgencyDashboardController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLoggedInUserDetail(){
        Map<String, Object> result = new Map<String, Object>();
        User usr = [SELECT Id, Name, Username, UserRole.Name, Profile.Name, UserRole.Id, AccountId, Account.Name,
                    ContactId, Contact.AccountId, Email, UserRoleId, ProfileId, FullPhotoUrl,
                    Title, Manager.Name, MobilePhone, Contact.Broker_Type__c
                    FROM USER 
                    WHERE Id=:UserInfo.getUserId()];
        
        List<PermissionSetAssignment> psAssignments = [
            SELECT Id, AssigneeId, PermissionSet.Name, PermissionSet.Label
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = 'Modon_Limited_Login_Access'];
        
        result.put('user', usr); 
        if(!psAssignments.isEmpty()){
            result.put('isLimitedLoginAccess', true); 
        }else {
            result.put('isLimitedLoginAccess', false); 
        }
        
        system.debug('result:::'+result);
        return result;
    } 
    @AuraEnabled(cacheable=true) 
public static AgencyDashboardDetails getAgentDashboardDetails(String ContactId){
    Map<String, Object> result = getLoggedInUserDetail();
    User user = (User)result.get('user');
    AgencyDashboardDetails valsToReturn = new AgencyDashboardDetails();
    system.debug('result:::'+result);
    system.debug('user:::'+user);
    integer soldUnitCount = 0;
    Decimal totalSum=0;
    //Need to add the logic for parent child accounts

    // ------------------- ADDED FILTER LOGIC -------------------
    Date today = Date.today();
    Date fyStart;
    Date fyEnd;
    Date startDate;
    Date endDate;
    String filterType = null; // you can pass this from LWC or set default

    if (String.isNotBlank(filterType)) {
        if (filterType == 'Current FY') {
            fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            fyEnd = fyStart.addYears(1).addDays(-1);
            startDate = fyStart;
            endDate = fyEnd;
        } else if (filterType == 'Previous FY') {
            fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            Date prevFyStart = fyStart.addYears(-1);
            Date prevFyEnd = fyStart.addDays(-1);
            startDate = prevFyStart;
            endDate = prevFyEnd;
        } 
    }
    // ----------------------------------------------------------

    List<Account> accountList = [Select Id, Broker_Classification__c, Rank__c, Broker_Classification__r.name from Account where Id =: user.AccountId];
    valsToReturn.accountClassification = accountList.size() > 0 ? accountList[0].Broker_Classification__r.name : 'Starter' ;
    valsToReturn.accountRank = accountList.size() > 0 ? Integer.valueOf(accountList[0].Rank__c):0;
    
    
    Set<String> excludedStatuses = new Set<String>{ BRConstants.RETIRED, BRConstants.CONVERTED_LEAD };
    String soldStatus = BRConstants.UNIT_STATUS_SOLD;

    String leadQuery = 'select count() from lead where BrokerAgent__c =:ContactId and isConverted=false and status NOT IN :excludedStatuses';
    if (startDate != null && endDate != null) {
        leadQuery += ' and CreatedDate >= :startDate and CreatedDate <= :endDate';
    }
    Map<String, Object> agentBinds = new Map<String, Object>{
        'ContactId' => ContactId,
        'excludedStatuses' => excludedStatuses,
        'startDate' => startDate,
        'endDate' => endDate,
        'soldStatus' => soldStatus
    };
    Integer openLeads = Database.countQueryWithBinds(leadQuery, agentBinds, AccessLevel.SYSTEM_MODE);


    String oppQuery = 'select count() from Opportunity where BrokerAgent__c =:ContactId and isclosed=false';
    if (startDate != null && endDate != null) {
        oppQuery += ' and CreatedDate >= :startDate and CreatedDate <= :endDate';
    }
    Integer openOpportunity = Database.countQueryWithBinds(oppQuery, agentBinds, AccessLevel.SYSTEM_MODE);

    String soQuery = 'select Id,Status__c, TotalAmount__c from SalesOrder__c where Opportunity__r.BrokerAgent__c =:ContactId and Status__c = :soldStatus';
    if (startDate != null && endDate != null) {
        soQuery += ' and CreatedDate >= :startDate and CreatedDate <= :endDate';
    }
    list<SalesOrder__c> salesOrderList = (List<SalesOrder__c>) Database.queryWithBinds(soQuery, agentBinds, AccessLevel.SYSTEM_MODE);
    
    for(SalesOrder__c salesOrder : salesOrderList){
        if(salesOrder.Status__c == BRConstants.UNIT_STATUS_SOLD && salesOrder.TotalAmount__c != null){
            totalSum = totalSum + salesOrder.TotalAmount__c;
        }
    }
    soldUnitCount = salesOrderList.size();
    String totalSumString = getShortStringValue(totalSum);
    valsToReturn.kpiList.add(new map<string,string>{'label' =>'Open Leads' , 'value' => String.valueOf(openLeads), 'link' =>'/sales'});
    valsToReturn.kpiList.add(new map<string,string>{'label' =>'Open Opportunities' , 'value' => String.valueOf(openOpportunity), 'link' =>'/sales'});
    valsToReturn.kpiList.add(new map<string,string>{'label' =>'Units Sold' , 'value' => String.ValueOf(soldUnitCount), 'link' =>'/sales'});
    valsToReturn.kpiList.add(new map<string,string>{'label' =>'Total Sales Value' , 'value' => totalSumString,'link' =>'/sales'});
    system.debug('valsToReturn:::'+valsToReturn);
    return valsToReturn;
}

    @AuraEnabled(cacheable=true) 
public static AgencyDashboardDetails getAgencyDashboardDetails(String accountId, String filterType, Date startDate, Date endDate) {
    Map<String, Object> result = getLoggedInUserDetail();
    User user = (User)result.get('user');
    AgencyDashboardDetails valsToReturn = new AgencyDashboardDetails();
    Set<Id> accountIds = new Set<Id>();
    Integer soldUnitCount = 0;
    Decimal totalSum = 0;

    accountIds.add(accountId);

    
    Date today = Date.today();
    Date fyStart;
    Date fyEnd;

    if (String.isNotBlank(filterType)) {
        if (filterType == 'Current FY') {
            fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            fyEnd = fyStart.addYears(1).addDays(-1);
            startDate = fyStart;
            endDate = fyEnd;
        } else if (filterType == 'Previous FY') {
            fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            Date prevFyStart = fyStart.addYears(-1);
            Date prevFyEnd = fyStart.addDays(-1);
            startDate = prevFyStart;
            endDate = prevFyEnd;
        } 
    }

    List<Account> accountList = [
        SELECT Id, Broker_Classification__c, Rank__c, Broker_Classification__r.Name 
        FROM Account 
        WHERE Id = :user.AccountId
    ];
    valsToReturn.accountClassification = accountList.size() > 0 ? accountList[0].Broker_Classification__r.Name : 'Starter';
    valsToReturn.accountRank = accountList.size() > 0 ? Integer.valueOf(accountList[0].Rank__c) : 0;

 
    Set<String> excludedStatuses = new Set<String>{ BRConstants.RETIRED, BRConstants.CONVERTED_LEAD };
    String soldStatus = BRConstants.UNIT_STATUS_SOLD;

    String leadQuery = 'SELECT COUNT() FROM Lead WHERE BrokerAgency__c IN :accountIds AND isConverted=false AND status NOT IN :excludedStatuses';
    if (startDate != null && endDate != null) {
        leadQuery += ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate';
    }
    // CreatedDate holds a time, so binding a plain date cut the window at midnight and left out
    // everything raised on the last day. Same end of day handling MBP_BrokerLeadcontroller uses.
    // All three queries below share this map, so they stay in step.
    Map<String, Object> agencyBinds = new Map<String, Object>{
        'accountIds' => accountIds,
        'excludedStatuses' => excludedStatuses,
        'startDate' => startDate == null ? null : Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
        'endDate' => endDate == null ? null : Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 999)),
        'soldStatus' => soldStatus
    };
    Integer openLeads = Database.countQueryWithBinds(leadQuery, agencyBinds, AccessLevel.SYSTEM_MODE);

    String oppQuery = 'SELECT COUNT() FROM Opportunity WHERE BrokerAgency__c IN :accountIds AND isClosed=false';
    if (startDate != null && endDate != null) {
        oppQuery += ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate';
    }
    Integer openOpportunity = Database.countQueryWithBinds(oppQuery, agencyBinds, AccessLevel.SYSTEM_MODE);

    
    String soQuery = 'SELECT Id, Status__c, TotalAmount__c FROM SalesOrder__c WHERE Opportunity__r.BrokerAgency__c IN :accountIds AND Status__c = :soldStatus';
    if (startDate != null && endDate != null) {
        soQuery += ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate';
    }
    List<SalesOrder__c> salesOrderList = (List<SalesOrder__c>) Database.queryWithBinds(soQuery, agencyBinds, AccessLevel.SYSTEM_MODE);

    for (SalesOrder__c salesOrder : salesOrderList) {
        if (salesOrder.TotalAmount__c != null) {
            totalSum += salesOrder.TotalAmount__c;
        }
    }
    soldUnitCount = salesOrderList.size();
    String totalSumString = getShortStringValue(totalSum);

   
    valsToReturn.kpiList.add(new Map<String,String>{'label' =>'Open Leads', 'value' => String.valueOf(openLeads), 'link' =>'/sales'});
    valsToReturn.kpiList.add(new Map<String,String>{'label' =>'Open Opportunities', 'value' => String.valueOf(openOpportunity), 'link' =>'/sales'});
    valsToReturn.kpiList.add(new Map<String,String>{'label' =>'Units Sold', 'value' => String.valueOf(soldUnitCount), 'link' =>'/sales'});
    valsToReturn.kpiList.add(new Map<String,String>{'label' =>'Total Sales Value', 'value' => totalSumString, 'link' =>'/sales'});

    System.debug('Agency Dashboard KPIs: ' + valsToReturn);
    return valsToReturn;
}

    
    private static string getShortStringValue(decimal num){
        string valueToReturn = '0';
        if(num > 1000000){
            valueToReturn = ((num/1000000).setScale(1)+' M').replace('.0','');
        }else if(num>1000){
            valueToReturn = ((num/1000).setScale(1)+' K' ).replace('.0','');
        }
        return valueToReturn;
    }
    
    public class AgencyDashboardDetails{
        @AuraEnabled public list<map<string,string>> kpiList;
        @AuraEnabled public String accountClassification {get;set;}
        @AuraEnabled public Integer accountRank {get;set;}    
        public AgencyDashboardDetails(){
            kpiList= new list<map<string,string>>();
        }
    }
}