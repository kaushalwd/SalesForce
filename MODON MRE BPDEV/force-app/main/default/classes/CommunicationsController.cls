/*
@description       : Communication controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class CommunicationsController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEmailCommunications(String recordId, Date startDate, Date endDate) {
        List<Map<String, Object>> emailList = new List<Map<String, Object>>();

        if (String.isBlank(recordId)) {
            return emailList;
        }

        // Default date range = current year
        Date start = (startDate == null) ? Date.newInstance(System.today().year(), 1, 1) : startDate;
        Date end1  = (endDate == null)   ? Date.newInstance(System.today().year(), 12, 31) : endDate;

        Datetime startDT = DateTime.newInstance(start.year(), start.month(), start.day());
        Datetime endDT   = DateTime.newInstance(end1.year(), end1.month(), end1.day()).addDays(1);

        Account acc = [
            SELECT Id, RecordType.DeveloperName, PersonContactId
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];

        // Collect all possible related ids.
        // Always include Account Id for both Individual and Organization.
        Set<Id> relatedIdsToFetch = new Set<Id>();
        relatedIdsToFetch.add(acc.Id);

        // For Person Account, also include PersonContactId if communications are linked to contact
        if (acc.PersonContactId != null) {
            relatedIdsToFetch.add(acc.PersonContactId);
        }

        // For Organization Account, include Primary Owner Contact if available.
        // Do not return early if no primary contact exists.
        if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
            List<Contact> primaryContacts = [
                SELECT Id
                FROM Contact
                WHERE AccountId = :acc.Id
                AND Primary_Owner__c = TRUE
                LIMIT 1
            ];

            if (!primaryContacts.isEmpty()) {
                relatedIdsToFetch.add(primaryContacts[0].Id);
            }
        }

        // Sales Orders for this Account
        List<SalesOrder__c> soList = [
            SELECT Id, CustomerAccount__c
            FROM SalesOrder__c
            WHERE CustomerAccount__c = :acc.Id
        ];
        Map<Id, Id> soToAccount = new Map<Id, Id>();
        for (SalesOrder__c so : soList) {
            soToAccount.put(so.Id, so.CustomerAccount__c);
            relatedIdsToFetch.add(so.Id);
        }

        // Cases for this Account
        List<Case> caseList = [
            SELECT Id, AccountId
            FROM Case
            WHERE AccountId = :acc.Id
        ];
        Map<Id, Id> caseToAccount = new Map<Id, Id>();
        for (Case cs : caseList) {
            caseToAccount.put(cs.Id, cs.AccountId);
            relatedIdsToFetch.add(cs.Id);
        }

        // Fetch Email communications (Account/Contact/SO/Case)
        List<Communication_Matrix__c> comms = [
            SELECT Id,
                   Message_Subject__c,
                   Message_Content__c,
                   Category__c,
                   ReceiverEmails__c,
                   CreatedDate,
                   Related_Record_Id__c,
                   Related_Record_Link__c,
                   Object_Type__c
            FROM Communication_Matrix__c
            WHERE Communication_Type__c = 'Email'
              AND Related_Record_Id__c IN :relatedIdsToFetch
              AND CreatedDate >= :startDT
              AND CreatedDate <  :endDT
            ORDER BY CreatedDate DESC
        ];

        // Prepare data for LWC (and also derive AccountId when record is SO/Case)
        for (Communication_Matrix__c c : comms) {
            Map<String, Object> emailData = new Map<String, Object>();
            emailData.put('Id', c.Id);
            emailData.put('Subject', c.Message_Subject__c != null ? c.Message_Subject__c : 'No Subject');
            emailData.put('Content', c.Message_Content__c);
            emailData.put('Category', c.Category__c);
            emailData.put('CreatedDate', c.CreatedDate);
            emailData.put('reciver', c.ReceiverEmails__c);

            // Resolve AccountId even if Communication Matrix is linked to SalesOrder/Case
            Id commAccountId;

            // 1) Direct Account
            if (c.Related_Record_Id__c != null && String.valueOf(c.Related_Record_Id__c).startsWith('001')) {
                commAccountId = c.Related_Record_Id__c;
            }
            // 2) SalesOrder -> CustomerAccount
            else if (c.Related_Record_Id__c != null && soToAccount.containsKey(c.Related_Record_Id__c)) {
                commAccountId = soToAccount.get(c.Related_Record_Id__c);
            }
            // 3) Case -> AccountId
            else if (c.Related_Record_Id__c != null && caseToAccount.containsKey(c.Related_Record_Id__c)) {
                commAccountId = caseToAccount.get(c.Related_Record_Id__c);
            }
            // 4) Fallback: try to extract Id from Related_Record_Link__c
            else if (String.isNotBlank(c.Related_Record_Link__c)) {
                String link = c.Related_Record_Link__c;
                String possibleId = link.replaceAll('.*?([a-zA-Z0-9]{15,18}).*', '$1');

                if (String.isNotBlank(possibleId) && possibleId.length() >= 15) {
                    try {
                        Id parsedId = (Id)possibleId;

                        if (String.valueOf(parsedId).startsWith('001')) {
                            commAccountId = parsedId;
                        } else if (soToAccount.containsKey(parsedId)) {
                            commAccountId = soToAccount.get(parsedId);
                        } else if (caseToAccount.containsKey(parsedId)) {
                            commAccountId = caseToAccount.get(parsedId);
                        }
                    } catch (Exception e) {
                        // ignore
                    }
                }
            }

            emailData.put('AccountId', commAccountId);

            emailList.add(emailData);
        }

        return emailList;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAccountDocuments(String recordId, Date startDate, Date endDate) {
        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> docList = new List<Map<String, Object>>();

        if (String.isBlank(recordId)) {
           
            result.put('documents', docList);
            return result;
        }

        Account acc = [
            SELECT Id, RecordType.DeveloperName, EIDNumber__pc, PassportNumber__pc
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];

        String emiratesIdValue;
        String passportNumberValue;

        if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
            List<Contact> primaryContacts = [
                SELECT Id, EIDNumber__c, PassportNumber__c
                FROM Contact
                WHERE AccountId = :acc.Id
                AND Primary_Owner__c = TRUE
                LIMIT 1
            ];

            if (!primaryContacts.isEmpty()) {
                emiratesIdValue = primaryContacts[0].EIDNumber__c;
                passportNumberValue = primaryContacts[0].PassportNumber__c;
            }
        } else {
            emiratesIdValue = acc.EIDNumber__pc;
            passportNumberValue = acc.PassportNumber__pc;
        }

        // Fetch related Documents__c records
        List<Documents__c> docs = [
            SELECT Id, Name, CreatedDate
            FROM Documents__c
            WHERE Account__c = :recordId
            ORDER BY CreatedDate DESC
        ];
        

        List<String> docNames = new List<String>();
        for (Documents__c d : docs) {
            docNames.add(d.Name);
        }


        Set<Id> docIds = new Set<Id>();
        for (Documents__c d : docs) {
            docIds.add(d.Id);
        }

        // Fetch attached Files
        Map<Id, List<ContentDocumentLink>> docFileMap = new Map<Id, List<ContentDocumentLink>>();
        if (!docIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId, ContentDocument.Id, ContentDocument.Title,
                       ContentDocument.FileType, ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :docIds
            ]) {
                if (!docFileMap.containsKey(cdl.LinkedEntityId)) {
                    docFileMap.put(cdl.LinkedEntityId, new List<ContentDocumentLink>());
                }
                docFileMap.get(cdl.LinkedEntityId).add(cdl);
            }
        }
        

        // --- Group Passport & Emirates files ---
        List<Map<String, Object>> passportFiles = new List<Map<String, Object>>();
        List<Map<String, Object>> emiratesFiles = new List<Map<String, Object>>();

        for (Documents__c d : docs) {
            
            if (docFileMap.containsKey(d.Id)) {
                for (ContentDocumentLink link : docFileMap.get(d.Id)) {
                    Map<String, Object> fileData = new Map<String, Object>{
                        'Title' => link.ContentDocument.Title,
                        'FileType' => link.ContentDocument.FileType,
                        'PreviewUrl' => '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + link.ContentDocument.LatestPublishedVersionId,
                        'DownloadUrl' => '/sfc/servlet.shepherd/document/download/' + link.ContentDocument.Id
                    };
                    

                    // Passport grouping
                    if (d.Name == 'Passport') {
                         
                        passportFiles.add(fileData);
                    }

                    // Emirates grouping
                    if (d.Name == 'Emirates/National ID Front' || d.Name == 'Emirates/National ID Back') {
                        
                        emiratesFiles.add(fileData);
                    }
                }
            }
        }

        // Build cards for each section
        if (!passportFiles.isEmpty()) {
            docList.add(new Map<String, Object>{
                'Id' => 'Passport',
                'Name' => 'Passport',
                'Files' => passportFiles
            });
        }

        if (!emiratesFiles.isEmpty()) {
            docList.add(new Map<String, Object>{
                'Id' => 'Emirates',
                'Name' => 'Emirates/National ID',
                'Files' => emiratesFiles
            });
        }
        

        // Add to response
        result.put('documents', docList);
        result.put('emiratesId', emiratesIdValue);
        result.put('passportNumber', passportNumberValue);

        
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getVoiceCalls(String recordId, Date startDate, Date endDate) {
        List<Map<String, Object>> callList = new List<Map<String, Object>>();

        if (String.isBlank(recordId)) {
            
            return callList;
        }

        // Default date range = current year
        Date start = (startDate == null) ? Date.newInstance(System.today().year(), 1, 1) : startDate;
        Date end1 = (endDate == null) ? Date.newInstance(System.today().year(), 12, 31) : endDate;

        List<VoiceCall> calls = [
            SELECT Id, Account__c, CallStartDateTime, CallEndDateTime,
                   CallDurationInSeconds, CallResolution, Call_Summary__c, CreatedDate, Owner.Name
            FROM VoiceCall
            WHERE Account__c = :recordId
              AND CreatedDate >= :DateTime.newInstance(start.year(), start.month(), start.day())
              AND CreatedDate <= :DateTime.newInstance(end1.year(), end1.month(), end1.day()).addDays(1)
            ORDER BY CreatedDate DESC
        ];

        return callList;
    }
}