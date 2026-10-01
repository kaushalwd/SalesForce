/**********************************************************************************************************************
* Name               : SalesExecutiveKPIController
* Description        : Apex controller for Sales Executive KPI Manager component
* Usage              : Handles data retrieval and saving of KPIs
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Rushi Patel      24 Aug 2026     Initial Draft
******************************************************************************************************************/
public with sharing class SalesExecutiveKPIController {

    public class KPIWrapper {
        @AuraEnabled public Integer srNo;
        @AuraEnabled public Id userId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Id kpiId;
        @AuraEnabled public Decimal presentable;
        @AuraEnabled public Decimal punctuality;
        @AuraEnabled public Decimal teamWork;
        @AuraEnabled public Decimal target;
        @AuraEnabled public String month;
        @AuraEnabled public String year;
    }

    @AuraEnabled
    public static List<KPIWrapper> getSalesExecutiveKPIs() {
        // Initialize list to hold the result wrappers
        List<KPIWrapper> result = new List<KPIWrapper>();
        
        // Query all active users with 'Sales Management' profile
        List<User> salesExecs = [SELECT Id, FirstName, LastName FROM User WHERE Profile.Name = 'Sales Management' AND IsActive = true ORDER BY FirstName, LastName];
        
        if (salesExecs.isEmpty()) {
            return result;
        }
        
        // Collect user IDs to query existing KPI records
        Set<Id> userIds = new Set<Id>();
        for (User u : salesExecs) {
            userIds.add(u.Id);
        }
        
        // Fetch existing KPI records for the users
        List<Sales_Executive_Teams_KPI__c> existingKPIs = [
            SELECT Id, Sales_Executive__c, Presentable__c, Punctuality__c, Team_Work__c, Target__c, Month__c, Year__c
            FROM Sales_Executive_Teams_KPI__c
            WHERE Sales_Executive__c IN :userIds
        ];
        
        // Map user IDs to their respective KPI record for quick lookup
        Map<Id, Sales_Executive_Teams_KPI__c> userToKPIMap = new Map<Id, Sales_Executive_Teams_KPI__c>();
        for (Sales_Executive_Teams_KPI__c kpi : existingKPIs) {
            userToKPIMap.put(kpi.Sales_Executive__c, kpi);
        }
        
        // Get current date details for default mapping
        Integer currentYear = Date.today().year();
        Integer currentMonth = Date.today().month();
        List<String> months = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        String currentMonthName = months[currentMonth - 1];
        String currentYearStr = String.valueOf(currentYear);
        
        Integer srNo = 1;
        for (User u : salesExecs) {
            KPIWrapper wrapper = new KPIWrapper();
            wrapper.srNo = srNo++;
            wrapper.userId = u.Id;
            wrapper.firstName = u.FirstName;
            wrapper.lastName = u.LastName;
            
            // If KPI exists for user, populate wrapper with existing values
            if (userToKPIMap.containsKey(u.Id)) {
                Sales_Executive_Teams_KPI__c kpi = userToKPIMap.get(u.Id);
                wrapper.kpiId = kpi.Id;
                wrapper.presentable = kpi.Presentable__c;
                wrapper.punctuality = kpi.Punctuality__c;
                wrapper.teamWork = kpi.Team_Work__c;
                wrapper.target = kpi.Target__c;
                wrapper.month = kpi.Month__c;
                wrapper.year = kpi.Year__c;
            } else {
                // If no KPI exists, initialize with default empty values
                wrapper.kpiId = null;
                wrapper.presentable = null;
                wrapper.punctuality = null;
                wrapper.teamWork = null;
                wrapper.target = null;
                wrapper.month = currentMonthName;
                wrapper.year = currentYearStr;
            }
            
            result.add(wrapper);
        }
        
        return result;
    }

    @AuraEnabled
    public static void saveKPIs(String kpiListJSON) {
        // Deserialize JSON payload into list of wrapper objects
        List<KPIWrapper> wrappers = (List<KPIWrapper>) JSON.deserialize(kpiListJSON, List<KPIWrapper>.class);
        List<Sales_Executive_Teams_KPI__c> kpisToUpsert = new List<Sales_Executive_Teams_KPI__c>();
        
        // Iterate over each wrapper to construct the KPI records
        for (KPIWrapper w : wrappers) {
            Sales_Executive_Teams_KPI__c kpi = new Sales_Executive_Teams_KPI__c();
            
            // Assign Id if updating an existing record
            if (w.kpiId != null) {
                kpi.Id = w.kpiId;
            }
            
            // Map fields
            kpi.Sales_Executive__c = w.userId;
            kpi.Presentable__c = w.presentable;
            kpi.Punctuality__c = w.punctuality;
            kpi.Team_Work__c = w.teamWork;
            kpi.Target__c = w.target;
            kpi.Month__c = w.month;
            kpi.Year__c = w.year;
            
            kpisToUpsert.add(kpi);
        }
        
        // Upsert the list of KPI records
        if (!kpisToUpsert.isEmpty()) {
            upsert kpisToUpsert;
        }
    }
}