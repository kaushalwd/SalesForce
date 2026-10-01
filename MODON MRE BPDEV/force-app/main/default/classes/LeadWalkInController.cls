public with sharing class LeadWalkInController {
    @AuraEnabled(cacheable=true)
    public static List<User> getSalesExecutiveOptions() {
        return [SELECT Id, Name FROM User WHERE IsActive = true and profile.Name ='Sales Management' Order by Name];
    }

    @AuraEnabled
    public static lead createLead(Lead lead) {
        insert lead;
        return lead;
    }
    @AuraEnabled(cacheable=true)
    public static List<String> getAdNameOptions() {
        List<String> adNameOptions = new List<String>();
        
        // Get picklist values for SubSource__c field on Lead object
        Schema.DescribeFieldResult fieldResult = Lead.SubSource__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        
        // Add picklist values to the list
        for (Schema.PicklistEntry entry : picklistEntries) {
            adNameOptions.add(entry.getLabel());
        }
        
        return adNameOptions;
    }
}