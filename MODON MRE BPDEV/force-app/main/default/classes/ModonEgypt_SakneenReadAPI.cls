/**********************************************************************************************************************
* Name               : ModonEgypt_SakneenReadAPI
* Description        : Generic REST API to fetch Salesforce data dynamically based on request JSON.
*
* Features:
* - Supports any Salesforce object
* - Uses configured Field Set by default
* - Allows custom field list from request
* - Supports Id filtering
* - Supports CreatedDate range filtering
* - Supports LastModifiedDate range filtering
* - Supports dynamic filters
* - Supports ORDER BY
* - Supports LIMIT
* - Supports Source Entity restriction (Modon Egypt)
* - Supports keyset (cursor-based) pagination + a response byte-size guard, so a single
*   synchronous call can never exceed Salesforce's ~6,000,000 byte Blob response limit.
*
* Pagination contract:
* - Every response now includes "hasMore" (Boolean) and "nextCursor" (String, nullable).
* - If hasMore = true, call the endpoint again with the SAME request body plus
*   "cursor": "<nextCursor value>" to fetch the next page. Do not change objectName,
*   fields, filters, sortField or sortDirection between pages of the same pull -
*   the cursor is only valid for the exact query shape it was issued from.
* - Pages stop early (before reaching the requested/derived limit) if the accumulated
*   JSON response would otherwise approach the platform's Blob size ceiling. This is
*   independent of limitSize/MAX_LIMIT, which cap record COUNT, not response BYTES.
*
* Endpoint:
* POST /services/apexrest/SakneenReadAPI
*
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE SOQL, createApexLog
**********************************************************************************************************************/
@RestResource(urlMapping='/SakneenReadAPI')
global with sharing class ModonEgypt_SakneenReadAPI {

    /*
     * Default and Maximum Limits (record COUNT caps)
     */
    private static final Integer DEFAULT_LIMIT = 2000;
    private static final Integer MAX_LIMIT = 50000;

    /*
     * Response BYTE-SIZE guard.
     * Salesforce synchronous Apex REST responses are capped at 6,000,000 bytes
     * (System.LimitException: BlobValue length exceeds maximum: 6000000).
     * We stop building the response before crossing this threshold, leaving
     * headroom for the JSON wrapper (success/objectName/count/hasMore/nextCursor keys).
     */
    private static final Integer MAX_RESPONSE_BYTES = 5500000;

    /*
     * Source Entity Restriction
     */
    private static final String SOURCE_ENTITY_VALUE = 'Modon - Egypt';

    /*
     * Object -> Field Set Mapping
     */
    private static final Map<String, String> OBJECT_FIELDSET_MAP = new Map<String, String>{
        'Account'                   => 'Sakneen_Account_Fields',
        'Opportunity'               => 'Sakneen_Opportunity_Fields',
        'Expressionofinterest__c'   => 'Sakneen_EOI_Fields',
        'Lead'                      => 'Sakneen_Lead_Fields',
        'UnitPaymentPlanMapping__c' => 'Sakneen_Unit_Payment_Plan_Mapping_Fields',
        'SalesOrder__c' => 'Sakneen_SalesOrder_Fields',
        'Unit__c' => 'Sakneen_Unit_Fields',
        'PaymentPlan__c' => 'Sakneen_Payment_Plan_Fields',
        'PaymentInstallements__c' => 'Sakneen_Payment_Installment_Fields',
        'Bucket__c' => 'Sakneen_Bucket_Fields'
    };

    /*
     * Request Wrapper
     */
    global class QueryRequest {

        // Salesforce object API name from which data needs to be fetched.
        public String objectName;

        // List of record IDs to fetch specific records from the requested object.
        public List<String> ids;

        // List of field API names to be included in the response data.
        public List<String> fields;

        // List of extra fields API names to be included in the response data. Example: Owner.Email, User.ProfileName etc.
        public List<String> extraFields;

        // Start date and time filter to fetch records created on or after this timestamp.
        public Datetime createdDateFrom;

        // End date and time filter to fetch records created on or before this timestamp.
        public Datetime createdDateTo;

        // Start date and time filter to fetch records modified on or after this timestamp.
        public Datetime lastModifiedFrom;

        // End date and time filter to fetch records modified on or before this timestamp.
        public Datetime lastModifiedTo;

        // Number of previous days used to filter records based on the selected date field.
        public Integer lastNDays;

        // Date field API name (CreatedDate or LastModifiedDate) used for LastNDays filtering.
        public String dateFilterFieldForLastNDays;

        // Field API name used to sort the response records.
        public String sortField;

        // Sorting order for records (ASC for ascending or DESC for descending).
        public String sortDirection;

        // Maximum number of records to return in the response (page size cap; still bounded by MAX_LIMIT).
        public Integer limitSize;

        // Opaque cursor returned as "nextCursor" from a previous call. Pass it back to fetch the next page.
        // Leave null/blank to fetch the first page.
        public String cursor;
    }

    /*
     * Internal holder for a decoded cursor: the exact, already-escaped SOQL literal
     * for the sort field's value, and the last record Id seen on the previous page.
     */
    private class CursorData {
        Boolean present = false;
        String sortFieldLiteral;
        String lastId;
    }

    /*
     * Internal holder for the page-building result.
     */
    private class PagedResult {
        List<Object> records = new List<Object>();
        Boolean hasMore = false;
        String nextCursor;
    }

    /*
     * REST Entry Point
     */
    @HttpPost
    global static void getRecords() {

        RestResponse response = RestContext.response;

        try {

            QueryRequest request =
                (QueryRequest) JSON.deserialize(
                    RestContext.request.requestBody.toString(),
                    QueryRequest.class
                );

            validateRequest(request);

            List<String> selectedFields = getSelectedFields(request);

            String sortField = resolveSortField(request);
            String sortDirection = resolveSortDirection(request);
            Integer effectiveLimit = getLimitSize(request.limitSize);

            Schema.DisplayType sortFieldType = getFieldType(request.objectName, sortField);
            CursorData cursorData = decodeCursor(request.cursor);

            // Query one extra record beyond the page size so we can tell whether
            // another page exists without a second round-trip.
            String soql = buildQuery(
                request,
                selectedFields,
                sortField,
                sortDirection,
                cursorData,
                effectiveLimit + 1
            );

            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on dynamic SOQL query
            List<SObject> records = Database.queryWithBinds(soql, new Map<String, Object>(), AccessLevel.USER_MODE);

            PagedResult paged = buildPagedResponse(
                records,
                selectedFields,
                request.objectName,
                sortField,
                sortFieldType,
                effectiveLimit
            );

            response.statusCode = 200;

            response.responseBody = Blob.valueOf(
                JSON.serialize(
                    new Map<String,Object>{
                        'success' => true,
                        'objectName' => request.objectName,
                        'count' => paged.records.size(),
                        'hasMore' => paged.hasMore,
                        'nextCursor' => paged.nextCursor,
                        'records' => paged.records
                    }
                )
            );
        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Modon Egypt Sakneen Read API',
                'ModonEgypt_SakneenReadAPI',
                'getRecords'
            ));
            response.statusCode = 500;
            response.responseBody =
                Blob.valueOf(
                    JSON.serialize(
                        new Map<String, Object>{
                            'success' => false,
                            'message' => ex.getMessage()
                        }
                    )
                );
        }
    }

    /*
     * Build the page: flattens records into wrapper maps while tracking the
     * accumulated JSON size, so we never hand Blob.valueOf() a payload that
     * would exceed the platform limit. Also applies the "fetch limit+1" trick
     * to detect whether a further page exists.
     */
    private static PagedResult buildPagedResponse(
        List<SObject> records,
        List<String> fields,
        String objectName,
        String sortField,
        Schema.DisplayType sortFieldType,
        Integer effectiveLimit
    ) {

        PagedResult result = new PagedResult();

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap();

        Integer runningBytes = 0;
        SObject lastIncluded;

        for (Integer i = 0; i < records.size(); i++) {

            // We queried effectiveLimit + 1 records purely to detect a next page.
            // Never include that extra record in the response itself.
            if (i >= effectiveLimit) {
                result.hasMore = true;
                break;
            }

            SObject record = records[i];

            Map<String,Object> recordWrapper = buildRecordWrapper(record, fields, fieldMap);

            // Rough but safe size estimate: serialize just this record plus a
            // couple of bytes for the surrounding array separators.
            Integer recordBytes = JSON.serialize(recordWrapper).length() + 2;

            if (runningBytes + recordBytes > MAX_RESPONSE_BYTES && !result.records.isEmpty()) {
                // Stop before crossing the byte ceiling. Do not include this record;
                // it becomes the first record of the next page instead.
                result.hasMore = true;
                break;
            }

            runningBytes += recordBytes;
            result.records.add(recordWrapper);
            lastIncluded = record;

            // If we've now consumed every record the query returned (i.e. there was
            // no "+1" extra record), there is no further page.
            if (i == records.size() - 1) {
                result.hasMore = false;
            }
        }

        if (result.hasMore && lastIncluded != null) {
            result.nextCursor = encodeCursor(lastIncluded, sortField, sortFieldType);
        }

        return result;
    }

    /*
     * Flatten a single SObject (including simple dot-notation relationship fields)
     * into a Map suitable for JSON serialization.
     */
    private static Map<String,Object> buildRecordWrapper(
        SObject record,
        List<String> fields,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        Map<String,Object> recordWrapper = new Map<String,Object>();

        for(String field : fields) {
            if(field.contains('.')) {
                List<String> relationshipParts = field.split('\\.');

                if(relationshipParts.size() == 2) {
                    String relationshipName = relationshipParts[0];
                    String relationshipField = relationshipParts[1];

                    SObject relationshipRecord = record.getSObject(relationshipName);

                    if(relationshipRecord != null) {
                        if(!recordWrapper.containsKey(relationshipName)) {
                            recordWrapper.put(relationshipName, new Map<String,Object>());
                        }

                        Map<String,Object> relationshipWrapper = (Map<String,Object>) recordWrapper.get(relationshipName);

                        relationshipWrapper.put(relationshipField, relationshipRecord.get(relationshipField));
                    }
                }

                continue;
            }

            if(fieldMap.containsKey(field)) {
                recordWrapper.put(field, record.get(field));
            }
        }

        return recordWrapper;
    }

    /*
     * Validate Incoming Request
     */
    private static void validateRequest(QueryRequest request) {

        if(request == null) {
            throw new ModonEgyptSakneenReadAPIException('Request body is required.');
        }

        if(String.isBlank(request.objectName)) {
            throw new ModonEgyptSakneenReadAPIException('objectName is mandatory.');
        }

        if(!Schema.getGlobalDescribe().containsKey(request.objectName)) {
            throw new ModonEgyptSakneenReadAPIException('Invalid objectName : ' + request.objectName);
        }

        if(request.lastNDays != null && request.lastNDays <= 0) {
            throw new ModonEgyptSakneenReadAPIException('Please provide positive integer number in lastNDays to fetch last N days data based on Date Time field given in dateFilterFieldForLastNDays attribute, else provide null.');
        }

        if((request.lastNDays == null || request.lastNDays < 0) && !String.isBlank(request.dateFilterFieldForLastNDays)) {
            throw new ModonEgyptSakneenReadAPIException('Please provide dateFilterFieldForLastNDays and lastNDays both, as both attributes should have values if you want to fetch Last N days data.');
        }

        //Validate dateFilterFieldForLastNDays should be a valid date time field API name
        if(String.isNotBlank(request.dateFilterFieldForLastNDays)) {
            Map<String, Schema.SObjectField> fieldMap =
                Schema.getGlobalDescribe()
                    .get(request.objectName)
                    .getDescribe()
                    .fields
                    .getMap();

            if(!fieldMap.containsKey(request.dateFilterFieldForLastNDays)) {

                throw new ModonEgyptSakneenReadAPIException(
                    String.format(
                        'Invalid dateFilterFieldForLastNDays value: {0}. Field does not exist on object: {1}.',
                        new List<String>{
                            request.dateFilterFieldForLastNDays,
                            request.objectName
                        }
                    )
                );
            }

            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(request.dateFilterFieldForLastNDays)
                .getDescribe();

            if(fieldDescribe.getType() != Schema.DisplayType.DATETIME) {

                throw new ModonEgyptSakneenReadAPIException(
                    String.format(
                        'Invalid dateFilterFieldForLastNDays value: {0}. Field must be a DateTime field on object: {1}.',
                        new List<String>{
                            request.dateFilterFieldForLastNDays,
                            request.objectName
                        }
                    )
                );
            }
        }

        if(String.isNotBlank(request.sortDirection)) {
            String dir = request.sortDirection.toUpperCase();
            if(dir != 'ASC' && dir != 'DESC') {
                throw new ModonEgyptSakneenReadAPIException('sortDirection must be ASC or DESC.');
            }
        }
    }

    /*
     * Get Fields
     *
     * Priority:
     * 1. Fields from Request body if given
     * 2. Fields from Field Set if no fields provided into request body
     * 3. Id (This is the default field to query at least, if nothing is specifid in request body and field set)
     */
    private static List<String> getSelectedFields(
        QueryRequest request
    ) {

        if(request.fields != null && !request.fields.isEmpty()) {

            return enrichLookupNames(
                request.objectName,
                request.fields,
                request.extraFields
            );
        }

        String fieldSetName = OBJECT_FIELDSET_MAP.get(request.objectName);

        if(String.isBlank(fieldSetName)) {
            String errorMessage = String.format(
                'FieldSet is not configured at Salesforce side for given object name: {0} in Object Manager. Either provide list of fields API Names in fields attribute OR Please Contact Modon Egypt Salesforce IT team/Administrator.',
                new List<String>{ request.objectName }
            );
            throw new ModonEgyptSakneenReadAPIException(errorMessage);
        }

        return enrichLookupNames(
            request.objectName,
            getFieldSetFields(
                request.objectName,
                fieldSetName
            ),
            request.extraFields
        );
    }

    /*
    * Build SOQL Query
    */
    private static String buildQuery(
        QueryRequest request,
        List<String> fields,
        String sortField,
        String sortDirection,
        CursorData cursorData,
        Integer queryLimit
    ) {

        List<String> conditions = new List<String>();

        /*
        * Id Filter, if list of specific Ids are provided.
        */
        if (request.ids != null && !request.ids.isEmpty()) {

            List<String> idValues = new List<String>();

            for (String recordId : request.ids) {

                if (String.isNotBlank(recordId)) {
                    idValues.add(
                        '\'' +
                        String.escapeSingleQuotes(recordId) +
                        '\''
                    );
                }
            }

            if (!idValues.isEmpty()) {
                conditions.add(
                    'Id IN (' +
                    String.join(idValues, ',') +
                    ')'
                );
            }
        }

        /*
        * LAST_N_DAYS filter takes precedence, over explicit date range filters.
        */
        if (request.lastNDays != null && request.lastNDays > 0) {

            String dateField = request.dateFilterFieldForLastNDays;

            if (!String.isBlank(dateField)) {
               conditions.add(dateField + ' = LAST_N_DAYS:' + request.lastNDays);
            }
        } else {
            /*
            * CreatedDate Filters
            */
            if (request.createdDateFrom != null) {
                conditions.add(
                    'CreatedDate >= ' +
                    request.createdDateFrom.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                );
            }

            if (request.createdDateTo != null) {
                conditions.add(
                    'CreatedDate <= ' +
                    request.createdDateTo.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                );
            }

            /*
            * LastModifiedDate Filters
            */
            if (request.lastModifiedFrom != null) {
                conditions.add(
                    'LastModifiedDate >= ' +
                    request.lastModifiedFrom.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                );
            }

            if (request.lastModifiedTo != null) {
                conditions.add(
                    'LastModifiedDate <= ' +
                    request.lastModifiedTo.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                );
            }
        }

        addSourceEntityFilter(request.objectName, conditions);

        /*
        * Keyset pagination filter (cursor). Uses the classic composite predicate:
        *   (sortField > lastValue) OR (sortField = lastValue AND Id > lastId)
        * so that pagination is stable and gap/duplicate-free even when many
        * records share the same sortField value (e.g. same LastModifiedDate).
        */
        if (cursorData != null && cursorData.present) {
            String operator = (sortDirection == 'ASC') ? '>' : '<';

            conditions.add(
                '(' +
                sortField + ' ' + operator + ' ' + cursorData.sortFieldLiteral +
                ' OR (' +
                sortField + ' = ' + cursorData.sortFieldLiteral +
                ' AND Id ' + operator + ' \'' + String.escapeSingleQuotes(cursorData.lastId) + '\'))'
            );
        }

        String whereClause = conditions.isEmpty()
            ? ''
            : ' WHERE ' + String.join(conditions, ' AND ');

        // Secondary sort on Id guarantees a stable, unique ordering for the cursor to key off.
        String orderByClause = ' ORDER BY ' + sortField + ' ' + sortDirection + ', Id ' + sortDirection;


        if(fields != null && !fields.contains(sortField)) {
            fields.add(sortField);
        }

        return String.format(
            '''
            SELECT {0}
            FROM {1}
            {2}
            {3}
            LIMIT {4}
            ''',
            new List<String>{
                String.join(fields, ','),
                request.objectName,
                whereClause,
                orderByClause,
                String.valueOf(queryLimit)
            }
        );
    }

    /*
     * Resolve Sort Field (falls back to LastModifiedDate if missing/invalid)
     */
    private static String resolveSortField(QueryRequest request) {

        String sortField = String.isBlank(request.sortField) ? 'LastModifiedDate' : request.sortField;

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(request.objectName)
                .getDescribe()
                .fields
                .getMap();

        if(!fieldMap.containsKey(sortField)) {
            sortField = 'LastModifiedDate';
        }

        return sortField;
    }

    /*
     * Resolve Sort Direction (defaults to DESC; validateRequest already rejects bad values)
     */
    private static String resolveSortDirection(QueryRequest request) {

        String sortDirection =
            String.isBlank(request.sortDirection)
            ? 'DESC'
            : request.sortDirection.toUpperCase();

        if(sortDirection != 'ASC' && sortDirection != 'DESC') {
            sortDirection = 'DESC';
        }

        return sortDirection;
    }

    /*
     * Effective Limit (record-count cap; independent of the byte-size guard)
     */
    private static Integer getLimitSize(
        Integer requestedLimit
    ) {

        if(requestedLimit == null || requestedLimit <= 0) {
            return DEFAULT_LIMIT;
        }

        return Math.min(requestedLimit, MAX_LIMIT);
    }

    /*
     * Apply Source Entity Restriction
     */
    private static void addSourceEntityFilter(
        String objectName,
        List<String> conditions
    ) {

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap();

        if(fieldMap.containsKey('Source_Entity__c')) {
            conditions.add(
                'Source_Entity__c = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }
        else if(fieldMap.containsKey('Source_Entity__pc')) {
            conditions.add(
                'Source_Entity__pc = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }

        //For PaymentPlan__c and PaymentInstallements__c there is no Source_Entity__c field directly on the object
        if(objectName == 'PaymentPlan__c') {
            conditions.add(
                'Phase__r.Project__r.Source_Entity__c = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }

        if(objectName == 'PaymentInstallements__c') {
            conditions.add(
                'PaymentInstallment__r.Phase__r.Project__r.Source_Entity__c = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }

        if(objectName == 'UnitPaymentPlanMapping__c') {
            conditions.add(
                'Payment_Plan__r.Phase__r.Project__r.Source_Entity__c = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }

        //Developer Note:
        //Throw Exception if filter of Source Entity was not applied, in future for any new Object.
        //Developer neeed to add if block in this method for that new object like Horizontal added for PaymentPlan__c and PaymentInstallements__c.
        //If There is no direct Source_Entity__c or Source_Entity__pc field available of that new Object then only this Exception will come and then
        //Developer need to update this method, so that this error should not be thrown for any object.
        throw new ModonEgyptSakneenReadAPIException('Technical Error: Source Entity Filter is missing, Developer needs to update addSourceEntityFilter method before live the code for new Object.');

    }

    /*
     * Read Fields from Field Set
     */
    private static List<String> getFieldSetFields(
        String objectName,
        String fieldSetName
    ) {

        List<String> fields = new List<String>();

        Schema.FieldSet fieldSet =
            Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fieldSets
                .getMap()
                .get(fieldSetName);

        for(Schema.FieldSetMember member : fieldSet.getFields()) {
            fields.add(member.getFieldPath());
        }

        return fields;
    }

    /*
     * Add Lookup Name Fields
     */
    private static List<String> enrichLookupNames(String objectName, List<String> fields, List<String> extraFields) {
        Set<String> finalFields = new Set<String>(fields);

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap();

        for(String field : fields) {

            if(!fieldMap.containsKey(field)) {
                continue;
            }

            Schema.DescribeFieldResult dfr = fieldMap.get(field).getDescribe();

            //Add Id and Name field if field is Reference type field i.e. Lookup or Master Detail field.
            if(dfr.getType() == Schema.DisplayType.REFERENCE) {
                String relationshipName = dfr.getRelationshipName();
                if(String.isNotBlank(relationshipName)) {
                    finalFields.add(relationshipName + '.Id');
                    finalFields.add(relationshipName + '.Name');
                }
            }
        }

        /*
        * Add Extra Fields
        */
        if(extraFields != null && !extraFields.isEmpty()) {
            finalFields.addAll(extraFields);
        }

        // Id is required as the tie-breaker for keyset pagination; make sure it's always selected.
        finalFields.add('Id');

        return new List<String>(finalFields);
    }

    /*
     * Get a field's DisplayType, defaulting to STRING if it can't be resolved
     * (falls back to quoted-string literal formatting, which is always safe).
     */
    private static Schema.DisplayType getFieldType(String objectName, String fieldName) {

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap();

        if(!fieldMap.containsKey(fieldName)) {
            return Schema.DisplayType.STRING;
        }

        return fieldMap.get(fieldName).getDescribe().getType();
    }

    /*
     * Format a field's raw value as a literal that can be embedded directly into a SOQL WHERE clause.
     */
    private static String formatSoqlLiteral(Object rawValue, Schema.DisplayType fieldType) {

        if(rawValue == null) {
            return 'null';
        }

        if(fieldType == Schema.DisplayType.DATE) {
            Date d = (Date) rawValue;
            return d.year() + '-' + zeroPad(d.month()) + '-' + zeroPad(d.day());
        }

        if(fieldType == Schema.DisplayType.DATETIME) {
            Datetime dt = (Datetime) rawValue;
            return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        }

        if(fieldType == Schema.DisplayType.DOUBLE ||
           fieldType == Schema.DisplayType.INTEGER ||
           fieldType == Schema.DisplayType.CURRENCY ||
           fieldType == Schema.DisplayType.PERCENT) {
            return String.valueOf(rawValue);
        }

        if(fieldType == Schema.DisplayType.BOOLEAN) {
            return String.valueOf(rawValue);
        }

        // Default: treat as string-like (STRING, PICKLIST, EMAIL, PHONE, TEXTAREA, ID, REFERENCE, etc.)
        return '\'' + String.escapeSingleQuotes(String.valueOf(rawValue)) + '\'';
    }

    private static String zeroPad(Integer value) {
        return value < 10 ? '0' + value : String.valueOf(value);
    }

    /*
     * Encode the pagination cursor from the last record included in the current page.
     */
    private static String encodeCursor(SObject lastRecord, String sortField, Schema.DisplayType sortFieldType) {

        Object rawSortValue = lastRecord.get(sortField);
        String literal = formatSoqlLiteral(rawSortValue, sortFieldType);
        String lastId = (Id) lastRecord.get('Id');

        Map<String,String> cursorPayload = new Map<String,String>{
            'lit' => literal,
            'id' => lastId
        };

        return EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(cursorPayload)));
    }

    /*
     * Decode an incoming cursor string back into its component parts.
     * Returns a CursorData with present=false if no cursor was supplied.
     */
    private static CursorData decodeCursor(String cursor) {

        CursorData data = new CursorData();

        if(String.isBlank(cursor)) {
            return data;
        }

        try {
            String jsonStr = EncodingUtil.base64Decode(cursor).toString();

            Map<String,Object> cursorPayload = (Map<String,Object>) JSON.deserializeUntyped(jsonStr);

            data.sortFieldLiteral = (String) cursorPayload.get('lit');
            data.lastId = (String) cursorPayload.get('id');
            data.present = String.isNotBlank(data.sortFieldLiteral) && String.isNotBlank(data.lastId);

        } catch (Exception ex) {
            throw new ModonEgyptSakneenReadAPIException('Invalid cursor supplied. Request the first page (omit cursor) and retry.');
        }

        return data;
    }

    public class ModonEgyptSakneenReadAPIException extends Exception {
        //Custom Exception class to throw custom exception.
    }
}