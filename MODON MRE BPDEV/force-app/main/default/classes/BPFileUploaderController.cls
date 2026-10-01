/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public with sharing class BPFileUploaderController {
   
    /*
    @AuraEnabled(cacheable=true)
    public static List<Business_Process_Documents__c> getDocumentsWithFiles(Id businessProcessId) {
        String objectApiName = businessProcessId.getSObjectType().getDescribe().getName(); //nsv
       
       
        if(objectApiName=='Broker_Ledger__c') //nsv
            return [
                SELECT Id, Name, Business_Process_Step__c,Business_Process__r.Current_Business_Process_Steps_Name__c,Business_Process_Step__r.Name,Business_Process__r.Process_Flow__r.Name, Business_Process_Step__r.Assigned_To__c, Business_Process__c,Business_Process_Step__r.OwnerId,Business_Process_Step__r.Status__c, Business_Process__r.Current_Business_Process_Step__r.Assigned_To__c,
                (SELECT Id, ContentDocumentId FROM ContentDocumentLinks)
                FROM Business_Process_Documents__c
                WHERE Broker_Ledger__c = :businessProcessId 
            ];
        else
            return [
                SELECT Id, Name, Business_Process_Step__c,Business_Process__r.Current_Business_Process_Steps_Name__c,Business_Process_Step__r.Name,Business_Process__r.Process_Flow__r.Name, Business_Process_Step__r.Assigned_To__c,Business_Process_Step__r.OwnerId,Business_Process_Step__r.Status__c, Business_Process__c,
                Business_Process__r.Current_Business_Process_Step__r.Assigned_To__c,
                //(SELECT Id, ContentDocumentId FROM ContentDocumentLinks)
                (SELECT Id, ContentDocumentId, ContentDocument.CreatedDate, ContentDocument.CreatedBy.Name,ContentDocument.CreatedById, ContentDocument.Title FROM ContentDocumentLinks ORDER BY ContentDocument.CreatedDate DESC)
                FROM Business_Process_Documents__c
                WHERE Business_Process__c = :businessProcessId
            ];
    }
    */
    
    /*
    // Optional custom file insert logic (if uploading manually via Apex)
    @AuraEnabled
    public static void uploadFile(Id relatedRecordId, String base64Data, String fileName, String fileType) {
        if (String.isBlank(base64Data) || String.isBlank(fileName) || String.isBlank(fileType)) {
            throw new AuraHandledException('Invalid file data');
        }
        
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        insert cv;
        
        ContentDocument cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cd.Id;
        cdl.LinkedEntityId = relatedRecordId;
        cdl.ShareType = 'V'; // Viewer permission
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }
    */
    
    @AuraEnabled
    public static list<Business_Process_Step__c> getBusinessProcessDetails(Id businessProcessId){
        list<Business_Process_Step__c> lstBBPSteps = [SELECT ID,OwnerId,Assigned_To__c,Name
                                                      FROM Business_Process_Step__c
                                                      WHERE Business_Process__c = :businessProcessId AND Name ='SM / SD Docs Upload'];
        if(lstBBPSteps != null && !lstBBPSteps.isEmpty()){
            return lstBBPSteps;
        }
        return null;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Id> getCommissionQueueMemberIds() {
        //String queueName = 'Accounts Commission Queue';
        List<GroupMember> members = [
            SELECT UserOrGroupId, UserOrGroup.Name
            FROM GroupMember
            WHERE Group.Name='Accounts Commision'
        ];
        
        List<Id> memberIds = new List<Id>();
        for (GroupMember gm : members) {
            memberIds.add(gm.UserOrGroupId);
        }
        
        return memberIds;
        
        
    }
    @AuraEnabled
    public static void renameUploadedFile(Id businessProcessId, Id contentDocumentId) {
        
        // Fetch Business Process Flow Name + Step Owner Email
        Business_Process__c bp = [
            SELECT Id,
            Process_Flow__r.Name,
            Current_Business_Process_Step__r.Assigned_To__r.Email
            FROM Business_Process__c
            WHERE Id = :businessProcessId
            LIMIT 1
        ];
        
        // Check condition
        if (bp.Process_Flow__r.Name != 'Clash Approval') {
            return;
        }
        
        String ownerEmail = bp.Current_Business_Process_Step__r.Assigned_To__r.Email;
        
        //Fetch latest ContentVersion
        ContentVersion cv = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        
        // Rename file
        cv.Title = cv.Title + '-' + ownerEmail;
        update cv;
    }
    @AuraEnabled
    public static String getUserRoleName(Id userId) {
        if (userId == null) {
            return null;
        }
        User u = [SELECT Id, UserRoleId, UserRole.Name FROM User WHERE Id = :userId LIMIT 1];
        return u.UserRole != null ? u.UserRole.Name : null;
    }
}