/**
* @description       : Server-side Apex class for managing Broker Cases in Salesforce
* @author            : raghu.chilukuri@activemindsit.com.srdev
* @group             : Broker Case Management
* @last modified on  : 13-02-2025 -- Added New values for case category and 
removed Recordtype,Queue code lines as per New case management changes.
* @last modified by  : raghu.chilukuri@activemindsit.com.srdev
**/
public with sharing class MBP_ManageBrokerCases {
    
    // User Fetch
    public class UserRelatedData {
        @AuraEnabled public String accountId, accountName, contactId, contactName,contactEmail,contactPhone;
    }
    
    // getting Account And Contact Info of user
    @AuraEnabled(cacheable=true)
    public static UserRelatedData getUserRelatedData() {
        Map<String, Object> userInfo = MBP_utilityclass.getCurrentUserInfo();
        UserRelatedData data = new UserRelatedData();
        data.accountId = (String)userInfo.get('accountId');
        data.accountName = (String)userInfo.get('accountName');
        data.contactId = (String)userInfo.get('contactId');
        data.contactName = (String)userInfo.get('contactName');
        data.contactEmail = (String)userInfo.get('contactEmail');
        data.contactPhone = (String)userInfo.get('contactPhone');
        return data;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getCasecategories() {
        return new List<String>{'Broker Enquiry','Broker Commission Enquiries'};
            }
    
    //upsert a Case record
    @AuraEnabled
    public static Case upsertCase(Case caseRecord, Boolean isUpdate) {        
        Map<String, Object> userInfo = MBP_utilityclass.getCurrentUserInfo();
        if(String.isBlank(caseRecord.Subject) || String.isBlank(caseRecord.Description) || 
           String.isBlank(caseRecord.CaseCategory__c)) {
               //throw new AuraHandledException('Subject, Description, and Category are required');
               System.debug('Subject, Description, and Category are required');
           }
        
        if(!isUpdate) {
            
            caseRecord.Language_Preference__c = 'English';
            caseRecord.Origin = label.CaseOriginBrokerCases;
            caserecord.AccountId = (String)userInfo.get('accountId');
            caserecord.contactId = (String)userInfo.get('contactId');
        }
        
        upsert caseRecord;
        return caseRecord;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getCases(Boolean caseExport, String startDateFilter, String endDateFilter) {
        User currentUser = MBP_utilityclass.getCurrentUser();
        Map<String, Object> userInfo = MBP_utilityclass.getCurrentUserInfo();
        String contactId = (String)userInfo.get('contactId');
        String accountId = (String)userInfo.get('accountId');
        String brokerType = (String)userInfo.get('brokerType');
        
        if (contactId == null || accountId == null) return new List<Case>();
        
        String query = 'SELECT Id, CaseNumber, Subject, Description, Status, CreatedDate, ' +
            ' Resolution_Comments__c,CaseCategory__c,Sub_Vertical__c, Contact.Name, Account.Name, CreatedBy.Name ';
        
        if (!caseExport) {
            query += ', (SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension ' +
                'FROM ContentDocumentLinks ORDER BY ContentDocument.LastModifiedDate DESC LIMIT 1) ';
        }
        
        query += 'FROM Case WHERE ';
        
        if (brokerType == 'Agency Admin' || brokerType == 'Owner') {
            query += 'AccountId = \'' + currentUser.AccountId + '\'';
        } else if (brokerType == 'Agent') {
            query += '(CreatedById = \'' + currentUser.Id + '\' OR ContactId = \'' + currentUser.ContactId + '\')';
        } else {
            return new List<Case>();
        }
        
        if (String.isNotBlank(startDateFilter) || String.isNotBlank(endDateFilter)) {
            if (String.isNotBlank(startDateFilter) && String.isNotBlank(endDateFilter)) {
                // Both dates selected - date range
                query += ' AND DAY_ONLY(CreatedDate) >= ' + startDateFilter + 
                    ' AND DAY_ONLY(CreatedDate) <= ' + endDateFilter;
            } else if (String.isNotBlank(startDateFilter)) {
                // Only start date selected - from start date onwards
                query += ' AND DAY_ONLY(CreatedDate) >= ' + startDateFilter;
            } else if (String.isNotBlank(endDateFilter)) {
                // Only end date selected - up to end date
                query += ' AND DAY_ONLY(CreatedDate) <= ' + endDateFilter;
            }
        }
        
        query += ' ORDER BY CreatedDate ';
        return Database.query(query);
    }
    
    // handling- upload, delete, and download
    @AuraEnabled
    public static Object handleFileOperation(String operation, String base64Data, String fileName, Id caseId, Id contentDocumentId) {
        switch on operation {
            when 'upload' {
                // Upload file to case
                if (String.isBlank(base64Data) || String.isBlank(fileName) || caseId == null) {
                    throw new AuraHandledException('File data, filename, and case ID are required');
                }
                
                ContentVersion version = new ContentVersion(Title = fileName,PathOnClient = fileName,VersionData = EncodingUtil.base64Decode(base64Data));
                insert version;
                
                Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id LIMIT 1].ContentDocumentId;
                
                insert new ContentDocumentLink(ContentDocumentId = contentDocId,LinkedEntityId = caseId,ShareType = 'V');
                
                return version;
            }
            
            when 'delete' {
                // Delete file
                if (contentDocumentId == null) {
                    throw new AuraHandledException('Content Document ID is required');
                }
                
                delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1];
                return null;
            }
            
            when 'download' {
                // Get file content for download
                if (contentDocumentId == null) {
                    throw new AuraHandledException('Content Document ID is required');
                }
                
                ContentVersion cv = [SELECT Id, VersionData, FileType FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId 
                                     AND IsLatest = true LIMIT 1];
                
                String base64DataResult = EncodingUtil.base64Encode(cv.VersionData);
                String fileType = cv.FileType == 'PDF' ? 'application/pdf' : 'image/' + cv.FileType.toLowerCase();
                
                return new Map<String, String>{
                    'base64Data' => base64DataResult,
                        'fileType' => fileType
                        };
                            }
            
            when else {
                throw new AuraHandledException('Invalid file operation: ' + operation);
            }
        }
    }
    
    // csv Data
    @AuraEnabled(cacheable=true)
    public static String getCasesCSVData(String startDateFilter, String endDateFilter) {
        // Create a mock case list with date filtering
        List<Case> cases = new List<Case>();
        
        // We'll use the same logic as getCases but for export
        User currentUser = MBP_utilityclass.getCurrentUser();
        Map<String, Object> userInfo = MBP_utilityclass.getCurrentUserInfo();
        String contactId = (String)userInfo.get('contactId');
        String accountId = (String)userInfo.get('accountId');
        String brokerType = (String)userInfo.get('brokerType');
        
        if (contactId == null || accountId == null) return '';
        
        String query = 'SELECT Id, CaseNumber,CaseCategory__c, Subject, Description, Status, CreatedDate, ' +
            ' Resolution_Comments__c, Contact.Name, Account.Name, CreatedBy.Name ' +
            'FROM Case WHERE ';
        
        if (brokerType == 'Agency Admin' || brokerType == 'Owner') {
            query += 'AccountId = \'' + currentUser.AccountId + '\'';
        } else if (brokerType == 'Agent') {
            query += '(CreatedById = \'' + currentUser.Id + '\' OR ContactId = \'' + currentUser.ContactId + '\')';
        } else {
            return '';
        }
        
        // Add the same date filtering logic
        if (String.isNotBlank(startDateFilter) || String.isNotBlank(endDateFilter)) {
            if (String.isNotBlank(startDateFilter) && String.isNotBlank(endDateFilter)) {
                query += ' AND DAY_ONLY(CreatedDate) >= ' + startDateFilter + 
                    ' AND DAY_ONLY(CreatedDate) <= ' + endDateFilter;
            } else if (String.isNotBlank(startDateFilter)) {
                query += ' AND DAY_ONLY(CreatedDate) >= ' + startDateFilter;
            } else if (String.isNotBlank(endDateFilter)) {
                query += ' AND DAY_ONLY(CreatedDate) <= ' + endDateFilter;
            }
        }
        
        query += ' ORDER BY CreatedDate ';
        cases = Database.query(query);
        
        if (cases.isEmpty()) return '';
        
        // Add Resolution Comments to CSV
        String csvContent = '"Case Number","Subject","Description","Status","Created Date","Subcategory","Resolution Comments","Contact Name","Account Name"\n';
        for (Case c : cases) {
            csvContent += '"' + (c.CaseNumber != null ? c.CaseNumber.escapeCsv() : '') + '",';
            csvContent += '"' + (c.Subject != null ? c.Subject.escapeCsv() : '') + '",';
            csvContent += '"' + (c.Description != null ? c.Description.escapeCsv() : '') + '",';
            csvContent += '"' + (c.Status != null ? c.Status.escapeCsv() : '') + '",';
            csvContent += '"' + (c.CreatedDate != null ? c.CreatedDate.format() : '') + '",';
            csvContent += '"' + (c.CaseCategory__c != null ? c.CaseCategory__c.escapeCsv() : '') + '",';
            csvContent += '"' + (c.Resolution_Comments__c != null ? c.Resolution_Comments__c.escapeCsv() : '') + '",';
            csvContent += '"' + (c.Contact != null && c.Contact.Name != null ? c.Contact.Name.escapeCsv() : '') + '",';
            csvContent += '"' + (c.Account != null && c.Account.Name != null ? c.Account.Name.escapeCsv() : '') + '"\n';
        }
        return csvContent;
    }
}