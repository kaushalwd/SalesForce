/**
* -----------------------------------------------------------------------------------------------
* Author       : Upendra Reddy
* Created Date : 04-July-2025
* Description  : 
*     The MBP_BrokerOpportunityController class provides broker-related data operations to the LWC.
*     Use Cases:
*       - Fetch Opportunities based on Broker Agency with data masking based on broker role.
*       - Retrieve Sales Orders associated with a specific Opportunity.
*       - Fetch distinct Project names for picklist population in the UI.


* 1.1       Raghu        06 jan 2026     Updates include:
*                                                              - Fixed Filter issue.


* -----------------------------------------------------------------------------------------------
*/

public without sharing class MBP_BrokerOpportunityController {


@AuraEnabled(cacheable=true) 
public static List<Map<String, Object>> getOpportunitiesForAgency(
    Id accountId,
    Date startDate,
    Date endDate
) {
   /* Version 1.1  starts*/
    Date queryStartDate;
    Date queryEndDate;
    
    if (startDate != null && endDate != null) {
      
        queryStartDate = startDate;
        queryEndDate = endDate;
        System.debug(' Using custom dates for opportunities: ' + startDate + ' to ' + endDate);
    } 
    else {
       
        Date today = Date.today();
        queryStartDate = Date.newInstance(today.year(), 1, 1);
        queryEndDate = today;
        System.debug(' No dates provided, using default: ' + queryStartDate + ' to ' + queryEndDate);
    }
    /* Version 1.1  Ends*/

    // CreatedDate holds a time, so binding a plain date cut the window at midnight and left out
    // everything raised on the last day. Same end of day handling MBP_BrokerLeadcontroller uses.
    Datetime windowStart = Datetime.newInstance(queryStartDate, Time.newInstance(0, 0, 0, 0));
    Datetime windowEnd = Datetime.newInstance(queryEndDate, Time.newInstance(23, 59, 59, 999));

    User currentUser = [
        SELECT Id, ContactId, Contact.AccountId, Contact.Broker_Type__c 
        FROM User 
        WHERE Id = :UserInfo.getUserId()
    ];
    
    Id contactId = currentUser.ContactId;
    String brokerType = currentUser.Contact.Broker_Type__c;
    
/* Version 1.1  starts*/
    List<Opportunity> opps = [
        SELECT Id, Name, StageName, Project__r.Name, ProjectInterest__c, BrokerAgentMobile__c,
               BrokerAgent__c, BrokerAgent__r.Name, BrokerAgency__r.Name, SalesManager__r.FirstName,
               Probability, UAE_Resident_Status__c, Nationality__c, LeadSource,
               Email__c, Mobile__c, CreatedDate, (SELECT Id, ProjectName__c, Owner.FirstName, Owner.LastName 
                FROM Sales_Orders__r
                ORDER BY CreatedDate DESC )
        FROM Opportunity
        WHERE BrokerAgency__c = :accountId
        AND CreatedDate >= :windowStart
        AND CreatedDate <= :windowEnd
        ORDER BY CloseDate DESC
    ];
/* Version 1.1  Ends*/
    
    
     List<Map<String, Object>> results = new List<Map<String, Object>>();
    for (Opportunity opp : opps) {
        Boolean mask = true;

        if (brokerType == 'Agency Admin') {
            mask = true;
        } else if (brokerType == 'Owner') {
            mask = opp.BrokerAgent__c != contactId;
        } else if (brokerType == 'Agent') {
            if (opp.BrokerAgent__c != contactId) {
                continue; 
            }
            mask = false;
        }

        SalesOrder__c so = (opp.Sales_Orders__r != null && !opp.Sales_Orders__r.isEmpty()) 
                           ? opp.Sales_Orders__r[0] 
                           : null;

        Map<String, Object> oppMap = new Map<String, Object>();
        oppMap.put('Id', opp.Id);
        oppMap.put('Name', opp.Name);
        oppMap.put('StageName', opp.StageName);
        oppMap.put('Email__c', mask ? maskEmail(opp.Email__c) : opp.Email__c);
        oppMap.put('Mobile__c', mask ? maskMobile(opp.Mobile__c) : opp.Mobile__c);
        oppMap.put('ProjectName', so != null ? so.ProjectName__c : null);
        oppMap.put(
            'SalesManagerName',
            so != null && so.Owner != null
                ? so.Owner.FirstName + ' ' + so.Owner.LastName
                : ''
        );
        oppMap.put('BrokerAgentName', opp.BrokerAgent__r != null ? opp.BrokerAgent__r.Name : '');
        oppMap.put('BrokerAgencyName', opp.BrokerAgency__r != null ? opp.BrokerAgency__r.Name : '');
        oppMap.put('UAE_Resident_Status__c', opp.UAE_Resident_Status__c);
        oppMap.put('CreatedDate', opp.CreatedDate.format()); 
        results.add(oppMap);
    }
    return results;
}



    
    private static String maskEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) return '*****@****';
        List<String> parts = email.split('@');
        String user = parts[0];
        String domain = parts[1];
        if (user.length() <= 2) return '***@' + domain;
        return user.substring(0, 1) + '***' + user.substring(user.length() - 1) + '@' + domain;
    }
    
    private static String maskMobile(String mobile) {
        if (String.isBlank(mobile) || mobile.length() < 4) return '**********';
        return '••••••' + mobile.substring(mobile.length() - 4);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SalesOrder__c> getSalesOrdersForOpportunity(Id opportunityId) {
        return [
            SELECT Id, Name, TotalAmount__c ,ProjectName__c,Status__c,Number_of_bedrooms__c,Unit_Name__c,Opportunity__r.ProjectInterest__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
        ];
    }
    
   
    
    @AuraEnabled(cacheable=true)
    public static User getUserInfo() {
        return [SELECT ContactId, Contact.AccountId,Contact.Broker_Type__c FROM User WHERE Id = :UserInfo.getUserId()];
    }
    
    
}