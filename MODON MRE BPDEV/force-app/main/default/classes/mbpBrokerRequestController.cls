public with sharing class mbpBrokerRequestController {

    @AuraEnabled(cacheable=true)
    public static List<BrokerRequest__c> getRequests(Map<String, Object> params) {

        System.debug('===== getRequests METHOD START =====');
        System.debug('Incoming params: ' + params);

        User currentUser = MBP_utilityclass.getCurrentUser();
        System.debug('Current User: ' + currentUser);

        Id contactId = currentUser.ContactId;
        System.debug('ContactId of current user: ' + contactId);

        if(contactId == null){
            System.debug('ERROR: User does not have ContactId');
            throw new AuraHandledException('User does not have a Contact record');
        }

        Date startDateFilter;
        Date endDateFilter;

        if(params != null){
            if(params.containsKey('startDate') && params.get('startDate') != null){
                System.debug('Raw startDate param: ' + params.get('startDate'));
                startDateFilter = Date.valueOf((String)params.get('startDate'));
                System.debug('Parsed startDateFilter: ' + startDateFilter);
            }

            if(params.containsKey('endDate') && params.get('endDate') != null){
                System.debug('Raw endDate param: ' + params.get('endDate'));
                endDateFilter = Date.valueOf((String)params.get('endDate'));
                System.debug('Parsed endDateFilter: ' + endDateFilter);
            }
        }

        String query =
            'SELECT Id, Name, CreatedDate, Request_Type__c, Request_SubType__c,' +
            ' Description__c, Status__c, Priority__c, CreatedBy.Name,' +
            ' (SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension FROM ContentDocumentLinks)' +
            ' FROM BrokerRequest__c WHERE Broker__c = :contactId';

        System.debug('Base Query: ' + query);

        if(startDateFilter != null){
            query += ' AND DAY_ONLY(CreatedDate) >= :startDateFilter';
            System.debug('Added startDateFilter condition');
        }

        if(endDateFilter != null){
            query += ' AND DAY_ONLY(CreatedDate) <= :endDateFilter';
            System.debug('Added endDateFilter condition');
        }

        query += ' ORDER BY CreatedDate DESC';

        System.debug('Final SOQL Query: ' + query);

        Map<String, Object> binds = new Map<String, Object>{
            'contactId' => contactId,
            'startDateFilter' => startDateFilter,
            'endDateFilter' => endDateFilter
        };
        List<BrokerRequest__c> results = (List<BrokerRequest__c>) Database.queryWithBinds(
            query, binds, AccessLevel.SYSTEM_MODE
        );

        System.debug('Records Returned: ' + results.size());
        System.debug('Records Data: ' + results);
        System.debug('===== getRequests METHOD END =====');

        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Object getPicklistValues(String picklistType) {

        System.debug('===== getPicklistValues START =====');
        System.debug('Requested Picklist Type: ' + picklistType);

        if(picklistType == 'requestTypes'){
            return getPicklistOptions('BrokerRequest__c', 'Request_Type__c');
        }

        if(picklistType == 'priorityOptions'){
            return getPicklistOptions('BrokerRequest__c', 'Priority__c');
        }

        if(picklistType == 'statusOptions'){
            return getPicklistOptions('BrokerRequest__c', 'Status__c');
        }

        if(picklistType == 'dependentSubTypes'){
            return getDependentPicklistValues('BrokerRequest__c', 'Request_Type__c', 'Request_SubType__c');
        }

        throw new AuraHandledException('Invalid picklist type');
    }

    @AuraEnabled
    public static Id createRequest(Map<String, Object> requestData, String fileData, String fileName) {

        System.debug('===== createRequest START =====');
        System.debug('Incoming requestData: ' + requestData);
        System.debug('Incoming fileName: ' + fileName);
        System.debug('FileData present: ' + (fileData != null));

        User currentUser = MBP_utilityclass.getCurrentUser();
        System.debug('Current User: ' + currentUser);

        Id contactId = currentUser.ContactId;
        System.debug('ContactId: ' + contactId);

        if(contactId == null){
            System.debug('ERROR: User does not have Contact record');
            throw new AuraHandledException('User does not have a Contact record');
        }

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(requestData));

        System.debug('Parsed Request Data Map: ' + data);

        BrokerRequest__c br = new BrokerRequest__c(
            Broker__c = contactId,
            Request_Type__c = (String)data.get('Request_Type__c'),
            Request_SubType__c = (String)data.get('Request_SubType__c'),
            Description__c = (String)data.get('Description__c'),
            Priority__c = (String)data.get('Priority__c'),
            Status__c = 'New'
        );

        System.debug('BrokerRequest__c Record Before Insert: ' + br);

        insert br;

        System.debug('BrokerRequest Inserted Successfully. Id: ' + br.Id);

        if(fileData != null && fileName != null){
            System.debug('File upload detected');

            Blob fileBlob = EncodingUtil.base64Decode(fileData);
            System.debug('Decoded File Blob Size: ' + fileBlob.size());

            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName,
                VersionData = fileBlob,
                FirstPublishLocationId = br.Id
            );

            System.debug('ContentVersion before insert: ' + cv);

            insert cv;

            System.debug('File uploaded successfully');
        }

        System.debug('===== createRequest END =====');
        return br.Id;
    }

    private static List<Map<String, String>> getPicklistOptions(String objectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Schema.DescribeFieldResult fieldDescribe = objDescribe.fields.getMap().get(fieldName).getDescribe();

        for(Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()){
            if(entry.isActive()){
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        return options;
    }

    private static Map<String, List<Map<String, String>>> getDependentPicklistValues(
        String objectName,
        String controllingFieldName,
        String dependentFieldName
    ) {
        Map<String, List<Map<String, String>>> dependencyMap = new Map<String, List<Map<String, String>>>();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

        Schema.DescribeFieldResult controllingDescribe = fieldsMap.get(controllingFieldName).getDescribe();
        Schema.DescribeFieldResult dependentDescribe = fieldsMap.get(dependentFieldName).getDescribe();

        List<Schema.PicklistEntry> controllingEntries = controllingDescribe.getPicklistValues();
        List<Schema.PicklistEntry> dependentEntries = dependentDescribe.getPicklistValues();

        List<String> controllingValues = new List<String>();

        for(Schema.PicklistEntry controllingEntry : controllingEntries){
            if(controllingEntry.isActive()){
                controllingValues.add(controllingEntry.getValue());
                dependencyMap.put(controllingEntry.getValue(), new List<Map<String, String>>());
            }
        }

        for(Schema.PicklistEntry dependentEntry : dependentEntries){
            if(!dependentEntry.isActive()){
                continue;
            }

            String entryJson = JSON.serialize(dependentEntry);
            Map<String, Object> entryMap = (Map<String, Object>) JSON.deserializeUntyped(entryJson);
            String validFor = (String) entryMap.get('validFor');

            if(String.isBlank(validFor)){
                continue;
            }

            for(Integer i = 0; i < controllingValues.size(); i++){
                if(isValidForIndex(validFor, i)){
                    String controllingValue = controllingValues[i];
                    dependencyMap.get(controllingValue).add(
                        new Map<String, String>{
                            'label' => dependentEntry.getLabel(),
                            'value' => dependentEntry.getValue()
                        }
                    );
                }
            }
        }

        System.debug('Dependent Picklist Map: ' + dependencyMap);
        return dependencyMap;
    }

    private static Boolean isValidForIndex(String validFor, Integer index) {
        String base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        Integer charIndex = index / 6;
        Integer bitIndex = 5 - Math.mod(index, 6);

        if(charIndex >= validFor.length()){
            return false;
        }

        String currentChar = validFor.substring(charIndex, charIndex + 1);
        Integer decodedValue = base64Chars.indexOf(currentChar);

        if(decodedValue < 0){
            return false;
        }

        return (decodedValue & (1 << bitIndex)) != 0;
    }

    @AuraEnabled
public static Id updateRequest(Map<String, Object> requestData, String fileData, String fileName, List<Id> deleteFileIds) {

    System.debug('===== updateRequest START =====');
    System.debug('Incoming requestData: ' + requestData);
    System.debug('Incoming fileName: ' + fileName);
    System.debug('Incoming deleteFileIds: ' + deleteFileIds);

    User currentUser = MBP_utilityclass.getCurrentUser();
    Id contactId = currentUser.ContactId;

    if (contactId == null) {
        throw new AuraHandledException('User does not have a Contact record');
    }

    Map<String, Object> data =
        (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(requestData));

    Id requestId = (Id)data.get('Id');

    if (requestId == null) {
        throw new AuraHandledException('Request Id is required for update');
    }

    BrokerRequest__c br = [
        SELECT Id, Broker__c, Status__c, Request_Type__c, Request_SubType__c, Description__c, Priority__c
        FROM BrokerRequest__c
        WHERE Id = :requestId
        AND Broker__c = :contactId
        LIMIT 1
    ];

    if (br.Status__c != 'Draft') {
        throw new AuraHandledException('Only Draft requests can be edited');
    }

    br.Request_Type__c = (String)data.get('Request_Type__c');
    br.Request_SubType__c = (String)data.get('Request_SubType__c');
    br.Description__c = (String)data.get('Description__c');
    br.Priority__c = (String)data.get('Priority__c');

    update br;

    if (deleteFileIds != null && !deleteFileIds.isEmpty()) {
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :br.Id
            AND ContentDocumentId IN :deleteFileIds
        ];

        if (!linksToDelete.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : linksToDelete) {
                docIds.add(cdl.ContentDocumentId);
            }

            delete linksToDelete;

            List<ContentDocument> docsToDelete = [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN :docIds
            ];

            if (!docsToDelete.isEmpty()) {
                delete docsToDelete;
            }
        }
    }

    if (fileData != null && fileName != null) {
        Blob fileBlob = EncodingUtil.base64Decode(fileData);

        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = fileBlob,
            FirstPublishLocationId = br.Id
        );
        insert cv;
    }

    System.debug('===== updateRequest END =====');
    return br.Id;
}

@AuraEnabled
public static String getRequestsCSVData(String startDateFilter, String endDateFilter) {

    System.debug('===== getRequestsCSVData START =====');
    System.debug('startDateFilter: ' + startDateFilter);
    System.debug('endDateFilter: ' + endDateFilter);

    User currentUser = MBP_utilityclass.getCurrentUser();
    Id contactId = currentUser.ContactId;

    if (contactId == null) {
        throw new AuraHandledException('User does not have a Contact record');
    }

    Date startDate;
    Date endDate;

    if (String.isNotBlank(startDateFilter)) {
        startDate = Date.valueOf(startDateFilter);
    }

    if (String.isNotBlank(endDateFilter)) {
        endDate = Date.valueOf(endDateFilter);
    }

    String query =
        'SELECT Id, Name, CreatedDate, Request_Type__c, Request_SubType__c, ' +
        'Description__c, Status__c, Priority__c, CreatedBy.Name ' +
        'FROM BrokerRequest__c ' +
        'WHERE Broker__c = :contactId';

    if (startDate != null) {
        query += ' AND DAY_ONLY(CreatedDate) >= :startDate';
    }

    if (endDate != null) {
        query += ' AND DAY_ONLY(CreatedDate) <= :endDate';
    }

    query += ' ORDER BY CreatedDate DESC';

    List<BrokerRequest__c> requests = (List<BrokerRequest__c>) Database.queryWithBinds(
        query,
        new Map<String, Object>{
            'contactId' => contactId,
            'startDate' => startDate,
            'endDate' => endDate
        },
        AccessLevel.SYSTEM_MODE
    );

    if (requests.isEmpty()) {
        return '';
    }

    String csv = 'S.No,Request Number,Type,Sub Type,Status,Priority,Description,Created Date,Created By\n';

    Integer index = 1;
    for (BrokerRequest__c req : requests) {
        List<String> row = new List<String>();
        row.add(csvEscape(String.valueOf(index)));
        row.add(csvEscape(req.Name));
        row.add(csvEscape(req.Request_Type__c));
        row.add(csvEscape(req.Request_SubType__c));
        row.add(csvEscape(req.Status__c));
        row.add(csvEscape(req.Priority__c));
        row.add(csvEscape(req.Description__c));
        row.add(csvEscape(req.CreatedDate != null ? req.CreatedDate.format('dd/MM/yyyy') : ''));
        row.add(csvEscape(req.CreatedBy != null ? req.CreatedBy.Name : ''));

        csv += String.join(row, ',') + '\n';
        index++;
    }

    System.debug('===== getRequestsCSVData END =====');
    return csv;
}

private static String csvEscape(String value) {
    if (value == null) {
        value = '';
    }
    value = value.replace('"', '""');
    return '"' + value + '"';
}
}