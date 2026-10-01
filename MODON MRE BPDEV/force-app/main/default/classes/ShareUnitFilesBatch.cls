global class ShareUnitFilesBatch implements Database.Batchable<SObject> {
    
    private String groupName;
    private String projectName;
    private Set<Id> targetUnitIds;
    private Boolean isIdBasedExecution = false;

    // Constructor 1: For Group Name and Project Name
    global ShareUnitFilesBatch(String groupName, String projectName) {
        this.groupName = groupName;
        this.projectName = projectName;
        this.isIdBasedExecution = false;
    }

    // Constructor 2: For Group Name and explicit Unit IDs
    global ShareUnitFilesBatch(String groupName, Set<Id> targetUnitIds) {
        this.groupName = groupName;
        this.targetUnitIds = targetUnitIds;
        this.isIdBasedExecution = true;
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Dynamically choose the query based on which constructor was called
        if (this.isIdBasedExecution) {
            return Database.getQueryLocator(
                [SELECT Id FROM Unit__c WHERE Id IN :this.targetUnitIds]
            );
        } else {
            return Database.getQueryLocator(
                [SELECT Id FROM Unit__c WHERE Project_Name__c = :this.projectName]
            );
        }
    }
    
    global void execute(Database.BatchableContext bc, List<Unit__c> scope) {
        List<CollaborationGroup> grps = [SELECT Id FROM CollaborationGroup WHERE Name = :this.groupName LIMIT 1];
        if (grps.isEmpty()) {
            return;
        }
        Id gId = grps[0].Id; // Fixed index syntax here
        
        Set<Id> uIds = new Map<Id, Unit__c>(scope).keySet();
        if (uIds.isEmpty()) {
            return;
        }
        
        Set<Id> dIds = new Set<Id>();
        for (ContentDocumentLink fl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :uIds]) {
            dIds.add(fl.ContentDocumentId);
        }
        if (dIds.isEmpty()) {
            return;
        }
        
        Set<Id> shared = new Set<Id>();
        for (ContentDocumentLink ex : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE ContentDocumentId IN :dIds AND LinkedEntityId = :gId]) {
            shared.add(ex.ContentDocumentId);
        }
        
        List<ContentDocumentLink> nS = new List<ContentDocumentLink>();
        for (Id dId : dIds) {
            if (!shared.contains(dId)) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = dId;
                cdl.LinkedEntityId = gId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                nS.add(cdl);
            }
        }
        
        if (!nS.isEmpty()) {
            insert nS;
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        // Batch execution complete
    }
}