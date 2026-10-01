/**********************************************************************************************************************
* Name               : ModonEgypt_DPGReadAPI
* Description        : Generic REST API to fetch Salesforce data dynamically based on request JSON.
*
* Features:
* - Supports any Salesforce object
* - Uses configured Field Set by default
* - Allows custom field list from request
* - Supports Id filtering
* - Supports CreatedDate range filtering
* - Supports LastModifiedDate range filtering
* - Supports dynamic filters (field / operator / value, with AND / OR / NOT grouping)
* - Supports ORDER BY
* - Supports LIMIT
* - Supports Source Entity restriction (Modon Egypt)
*
* Endpoint:
* POST /services/apexrest/DPGReadAPI
*
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — createApexLog (SYSTEM_MODE SOQL retained)
**********************************************************************************************************************/
@RestResource(urlMapping='/DPGReadAPI')
global with sharing class ModonEgypt_DPGReadAPI {

    /*
     * Default and Maximum Limits
     */
    private static final Integer DEFAULT_LIMIT = 10000;
    private static final Integer MAX_LIMIT = 50000;

    /*
     * Source Entity Restriction
     */
    private static final String SOURCE_ENTITY_VALUE = 'Modon - Egypt';

    /*
     * Allowed operators for dynamic "filters" conditions.
     * Kept as an explicit allow-list to prevent SOQL injection via operatorType.
     */
    private static final Set<String> ALLOWED_OPERATORS = new Set<String>{
        '=', '!=', '<>', '>', '<', '>=', '<=',
        'LIKE', 'NOT LIKE', 'IN', 'NOT IN', 'INCLUDES', 'EXCLUDES'
    };

    /*
     * SOQL date literals allowed to pass through unquoted for DATE/DATETIME fields.
     */
    private static final Set<String> SOQL_DATE_LITERALS = new Set<String>{
        'TODAY', 'YESTERDAY', 'TOMORROW',
        'LAST_WEEK', 'THIS_WEEK', 'NEXT_WEEK',
        'LAST_MONTH', 'THIS_MONTH', 'NEXT_MONTH',
        'LAST_90_DAYS', 'NEXT_90_DAYS',
        'THIS_QUARTER', 'LAST_QUARTER', 'NEXT_QUARTER',
        'THIS_YEAR', 'LAST_YEAR', 'NEXT_YEAR',
        'THIS_FISCAL_QUARTER', 'LAST_FISCAL_QUARTER', 'NEXT_FISCAL_QUARTER',
        'THIS_FISCAL_YEAR', 'LAST_FISCAL_YEAR', 'NEXT_FISCAL_YEAR'
    };

    /*
     * Object -> Field Set Mapping
     */
    private static final Map<String, String> OBJECT_FIELDSET_MAP = new Map<String, String>{
        'Unit__c' => 'DPG_Unit_Fields'
    };

    /*
     * Dynamic Filter Condition Wrapper
     *
     * Example:
     * { "fieldName": "Status__c", "operatorType": "=", "value": "Available", "logicalOperator": "AND" }
     * { "fieldName": "City__c", "operatorType": "IN", "valueList": ["Cairo","Giza"] }
     * { "fieldName": "Price__c", "operatorType": ">=", "value": "1000000" }
     */
    global class FilterCondition {

        // API name of the field to filter on. Supports relationship traversal e.g. "Owner.Email".
        public String fieldName;

        // Operator to apply. Allowed: = , != , <> , > , < , >= , <= , LIKE , NOT LIKE , IN , NOT IN , INCLUDES , EXCLUDES
        public String operatorType;

        // Value to compare against, for all operators except IN / NOT IN / INCLUDES / EXCLUDES.
        // Use the literal string "null" (case-insensitive) with = or != to filter on null / not null.
        public String value;

        // List of values to compare against, required for IN / NOT IN / INCLUDES / EXCLUDES.
        public List<String> valueList;

        // How this condition joins to the NEXT condition in the list: AND or OR.
        // Only used when filterLogic is not supplied. Defaults to AND. Ignored on the last condition.
        public String logicalOperator;
    }

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

        // Dynamic WHERE conditions. Combined with AND to all other filters (Ids, dates, Source Entity).
        // Internally the conditions in this list are combined per logicalOperator / filterLogic below.
        public List<FilterCondition> filters;

        // Optional custom logic referencing 1-based indices of "filters", e.g. "(1 AND 2) OR 3".
        // If omitted, conditions are combined left-to-right using each condition's logicalOperator (default AND).
        public String filterLogic;

        // Field API name used to sort the response records.
        public String sortField;

        // Sorting order for records (ASC for ascending or DESC for descending).
        public String sortDirection;

        // Maximum number of records to return in the response.
        public Integer limitSize;
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

            String soql = buildQuery(request, selectedFields);

            List<SObject> records = Database.queryWithBinds(soql, new Map<String, Object>(), AccessLevel.SYSTEM_MODE);

            List<Object> responseRecords =
                buildResponseWrapper(
                    records,
                    selectedFields,
                    request.objectName
                );

            response.statusCode = 200;

            response.responseBody = Blob.valueOf(
                JSON.serialize(
                    new Map<String,Object>{
                        'success' => true,
                        'objectName' => request.objectName,
                        'count' => responseRecords.size(),
                        'records' => responseRecords
                    }
                )
            );
        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Modon Egypt DPG Read API',
                'ModonEgypt_DPGReadAPI',
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

    private static List<Object> buildResponseWrapper(
        List<SObject> records,
        List<String> fields,
        String objectName
    ) {
        List<Object> responseList = new List<Object>();

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .fields
                .getMap();

        for(SObject record : records) {
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

            responseList.add(recordWrapper);
        }

        return responseList;
    }

    /*
     * Validate Incoming Request
     */
    private static void validateRequest(QueryRequest request) {

        if(request == null) {
            throw new ModonEgyptDPGReadAPIException('Request body is required.');
        }

        if(String.isBlank(request.objectName)) {
            throw new ModonEgyptDPGReadAPIException('objectName is mandatory.');
        }

        if(!Schema.getGlobalDescribe().containsKey(request.objectName)) {
            throw new ModonEgyptDPGReadAPIException('Invalid objectName : ' + request.objectName);
        }

        if(request.lastNDays != null && request.lastNDays <= 0) {
            throw new ModonEgyptDPGReadAPIException('Please provide positive integer number in lastNDays to fetch last N days data based on Date Time field given in dateFilterFieldForLastNDays attribute, else provide null.');
        }

        if((request.lastNDays == null || request.lastNDays < 0) && !String.isBlank(request.dateFilterFieldForLastNDays)) {
            throw new ModonEgyptDPGReadAPIException('Please provide dateFilterFieldForLastNDays and lastNDays both, as both attributes should have values if you want to fetch Last N days data.');
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

                throw new ModonEgyptDPGReadAPIException(
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

                throw new ModonEgyptDPGReadAPIException(
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
    }

    /*
     * Get Fields
     *
     * Priority:
     * 1. Fields from Request bOdy if given
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
                'Developer Exception: FieldSet is not configured in OBJECT_FIELDSET_MAP variable for the given object.',
                new List<String>{ request.objectName }
            );
            throw new ModonEgyptDPGReadAPIException(errorMessage);
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
    private static String buildQuery(QueryRequest request, List<String> fields) {

        List<String> conditions = new List<String>();

        Map<String, Schema.SObjectField> fieldMap =
            Schema.getGlobalDescribe()
                .get(request.objectName)
                .getDescribe()
                .fields
                .getMap();

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

        /*
        * Dynamic filters (field / operator / value with AND / OR / NOT grouping)
        */
        String dynamicFilterClause = buildFilterClause(request, fieldMap);

        if (String.isNotBlank(dynamicFilterClause)) {
            conditions.add(dynamicFilterClause);
        }

        addSourceEntityFilter(request.objectName, conditions);
        addMireDpgZoneCondition(conditions);

        String whereClause = conditions.isEmpty()
            ? ''
            : ' WHERE ' + String.join(conditions, ' AND ');

        String orderByClause = buildOrderByClause(request);

        Integer limitSize = getLimitSize(request.limitSize);

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
                String.valueOf(limitSize)
            }
        );
    }

    /*
     * Build Dynamic Filter Clause
     *
     * Combines all "filters" conditions into a single, parenthesized WHERE fragment.
     * - If filterLogic is provided, conditions are combined per that expression (e.g. "(1 AND 2) OR 3").
     * - Otherwise, conditions are combined left-to-right using each condition's logicalOperator (default AND).
     */
    private static String buildFilterClause(
        QueryRequest request,
        Map<String, Schema.SObjectField> fieldMap
    ) {

        if (request.filters == null || request.filters.isEmpty()) {
            return '';
        }

        Map<Integer, String> conditionByIndex = new Map<Integer, String>();
        List<String> sequentialParts = new List<String>();

        for (Integer i = 0; i < request.filters.size(); i++) {

            FilterCondition fc = request.filters[i];

            String conditionStr = buildSingleCondition(request.objectName, fc, fieldMap);

            conditionByIndex.put(i + 1, conditionStr);

            sequentialParts.add(conditionStr);

            if (i < request.filters.size() - 1) {

                String joiner = String.isBlank(fc.logicalOperator)
                    ? 'AND'
                    : fc.logicalOperator.trim().toUpperCase();

                if (joiner != 'AND' && joiner != 'OR') {
                    joiner = 'AND';
                }

                sequentialParts.add(joiner);
            }
        }

        if (String.isNotBlank(request.filterLogic)) {
            return '(' + resolveFilterLogic(request.filterLogic, conditionByIndex) + ')';
        }

        return '(' + String.join(sequentialParts, ' ') + ')';
    }

    /*
     * Resolve a custom filterLogic expression (e.g. "(1 AND 2) OR 3") into a SOQL fragment,
     * substituting each numeric index with its corresponding built condition.
     * Only digits, AND, OR, NOT and parentheses are permitted in the expression.
     */
    private static String resolveFilterLogic(
        String filterLogic,
        Map<Integer, String> conditionByIndex
    ) {

        String normalized = filterLogic.trim();

        String strippedForValidation = normalized
            .replaceAll('(?i)\\bAND\\b', '')
            .replaceAll('(?i)\\bOR\\b', '')
            .replaceAll('(?i)\\bNOT\\b', '')
            .replaceAll('[0-9\\s()]', '');

        if (String.isNotBlank(strippedForValidation)) {
            throw new ModonEgyptDPGReadAPIException(
                'Invalid filterLogic expression. Only digits, AND, OR, NOT and parentheses are allowed: ' + filterLogic
            );
        }

        Matcher numberMatcher = Pattern.compile('\\d+').matcher(normalized);

        String result = '';
        Integer lastEnd = 0;

        while (numberMatcher.find()) {

            Integer idx = Integer.valueOf(numberMatcher.group());

            if (!conditionByIndex.containsKey(idx)) {
                throw new ModonEgyptDPGReadAPIException(
                    'filterLogic references condition index ' + idx + ' which does not exist in filters list.'
                );
            }

            result += normalized.substring(lastEnd, numberMatcher.start());
            result += '(' + conditionByIndex.get(idx) + ')';
            lastEnd = numberMatcher.end();
        }

        result += normalized.substring(lastEnd);

        return result;
    }

    /*
     * Build a single "field operator value" SOQL fragment from a FilterCondition.
     */
    private static String buildSingleCondition(
        String objectName,
        FilterCondition fc,
        Map<String, Schema.SObjectField> fieldMap
    ) {

        if (fc == null || String.isBlank(fc.fieldName) || String.isBlank(fc.operatorType)) {
            throw new ModonEgyptDPGReadAPIException('Each filter condition must include fieldName and operatorType.');
        }

        String fieldName = fc.fieldName.trim();
        String operatorType = fc.operatorType.trim().toUpperCase();

        if (!Pattern.matches('^[a-zA-Z0-9_]+(\\.[a-zA-Z0-9_]+)*$', fieldName)) {
            throw new ModonEgyptDPGReadAPIException('Invalid fieldName in filters: ' + fc.fieldName);
        }

        if (!ALLOWED_OPERATORS.contains(operatorType)) {
            throw new ModonEgyptDPGReadAPIException(
                'Unsupported operatorType: ' + fc.operatorType +
                '. Allowed operators: ' + String.join(new List<String>(ALLOWED_OPERATORS), ', ')
            );
        }

        if (!fieldName.contains('.') && !fieldMap.containsKey(fieldName)) {
            throw new ModonEgyptDPGReadAPIException(
                'Invalid field in filters: ' + fieldName + ' does not exist on object ' + objectName + '.'
            );
        }

        Schema.DisplayType fieldType = resolveFieldType(fieldName, fieldMap);

        if (operatorType == 'IN' || operatorType == 'NOT IN') {

            if (fc.valueList == null || fc.valueList.isEmpty()) {
                throw new ModonEgyptDPGReadAPIException(
                    'valueList is required for operatorType ' + operatorType + ' on field ' + fieldName + '.'
                );
            }

            List<String> formattedValues = new List<String>();

            for (String v : fc.valueList) {
                formattedValues.add(formatValue(v, fieldType));
            }

            return fieldName + ' ' + operatorType + ' (' + String.join(formattedValues, ',') + ')';
        }

        if (operatorType == 'INCLUDES' || operatorType == 'EXCLUDES') {

            if (fc.valueList == null || fc.valueList.isEmpty()) {
                throw new ModonEgyptDPGReadAPIException(
                    'valueList is required for operatorType ' + operatorType + ' on field ' + fieldName + '.'
                );
            }

            List<String> escapedValues = new List<String>();

            for (String v : fc.valueList) {
                escapedValues.add(String.escapeSingleQuotes(v));
            }

            return fieldName + ' ' + operatorType + ' (\'' + String.join(escapedValues, '\',\'') + '\')';
        }

        if (fc.value == null) {
            throw new ModonEgyptDPGReadAPIException(
                'value is required for operatorType ' + operatorType + ' on field ' + fieldName + '.'
            );
        }

        String formattedValue;

        if (operatorType == 'LIKE' || operatorType == 'NOT LIKE') {
            // LIKE always compares against a quoted string regardless of the field's describe type.
            formattedValue = '\'' + String.escapeSingleQuotes(fc.value) + '\'';
        } else {
            formattedValue = formatValue(fc.value, fieldType);
        }

        return fieldName + ' ' + operatorType + ' ' + formattedValue;
    }

    /*
     * Resolve the Schema.DisplayType for a (possibly relationship-traversed) field path,
     * so filter values can be quoted/formatted correctly. Falls back to STRING when the
     * path can't be fully resolved (safe default: value gets quoted).
     */
    private static Schema.DisplayType resolveFieldType(
        String fieldName,
        Map<String, Schema.SObjectField> baseFieldMap
    ) {

        List<String> parts = fieldName.split('\\.');
        Map<String, Schema.SObjectField> currentFieldMap = baseFieldMap;

        for (Integer i = 0; i < parts.size(); i++) {

            String part = parts[i];
            Boolean isLastPart = (i == parts.size() - 1);

            if (isLastPart) {
                if (!currentFieldMap.containsKey(part)) {
                    return Schema.DisplayType.STRING;
                }
                return currentFieldMap.get(part).getDescribe().getType();
            }

            Schema.SObjectField relationshipField = findFieldByRelationshipName(currentFieldMap, part);

            if (relationshipField == null) {
                return Schema.DisplayType.STRING;
            }

            List<Schema.SObjectType> referenceTargets = relationshipField.getDescribe().getReferenceTo();

            if (referenceTargets.isEmpty()) {
                return Schema.DisplayType.STRING;
            }

            currentFieldMap = referenceTargets[0].getDescribe().fields.getMap();
        }

        return Schema.DisplayType.STRING;
    }

    private static Schema.SObjectField findFieldByRelationshipName(
        Map<String, Schema.SObjectField> fieldMap,
        String relationshipName
    ) {

        for (Schema.SObjectField sf : fieldMap.values()) {

            Schema.DescribeFieldResult dfr = sf.getDescribe();

            if (dfr.getType() == Schema.DisplayType.REFERENCE &&
                String.isNotBlank(dfr.getRelationshipName()) &&
                dfr.getRelationshipName().equalsIgnoreCase(relationshipName)) {
                return sf;
            }
        }

        return null;
    }

    /*
     * Format a raw string value into a safe SOQL literal based on the target field's type.
     */
    private static String formatValue(String rawValue, Schema.DisplayType fieldType) {

        if (rawValue == null || rawValue.trim().equalsIgnoreCase('null')) {
            return 'null';
        }

        String trimmedValue = rawValue.trim();

        switch on fieldType {
            when INTEGER, DOUBLE, CURRENCY, PERCENT, LONG {

                if (!Pattern.matches('^-?\\d+(\\.\\d+)?$', trimmedValue)) {
                    throw new ModonEgyptDPGReadAPIException('Invalid numeric value provided in filters: ' + rawValue);
                }

                return trimmedValue;
            }
            when BOOLEAN {

                String lowerValue = trimmedValue.toLowerCase();

                if (lowerValue != 'true' && lowerValue != 'false') {
                    throw new ModonEgyptDPGReadAPIException(
                        'Invalid boolean value provided in filters: ' + rawValue + '. Use true or false.'
                    );
                }

                return lowerValue;
            }
            when DATE, DATETIME {

                // SOQL date literals (TODAY, LAST_N_DAYS:30, etc.) are passed through unquoted.
                // Otherwise the value is expected to already be a valid SOQL date/datetime literal
                // (e.g. 2026-01-01 or 2026-01-01T00:00:00Z) and is passed through unquoted as well.
                return trimmedValue;
            }
            when else {
                return '\'' + String.escapeSingleQuotes(rawValue) + '\'';
            }
        }
    }

    /*
     * Build Order By Clause
     */
    private static String buildOrderByClause(
        QueryRequest request
    ) {

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

        String sortDirection =
            String.isBlank(request.sortDirection)
            ? 'DESC'
            : request.sortDirection.toUpperCase();

        if(sortDirection != 'ASC' && sortDirection != 'DESC') {
            sortDirection = 'DESC';
        }

        return
            ' ORDER BY ' +
            sortField +
            ' ' +
            sortDirection;
    }

    /*
     * Effective Limit
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
                'Project__r.Source_Entity__c = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }

        if(objectName == 'PaymentInstallements__c') {
            conditions.add(
                'PaymentInstallment__r.Project__r.Source_Entity__c = \'' +
                SOURCE_ENTITY_VALUE +
                '\''
            );
            return;
        }

        if(objectName == 'UnitPaymentPlanMapping__c') {
            conditions.add(
                'Payment_Plan__r.Project__r.Source_Entity__c = \'' +
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
        throw new ModonEgyptDPGReadAPIException('Technical Error: Source Entity Filter is missing, Developer needs to update addSourceEntityFilter method before live the code for new Object.');

    }

    /**
    * Adds MIRE DPG zone filter to the SOQL conditions.
    */
    private static void addMireDpgZoneCondition(List<String> conditions) {
        if (String.isBlank(System.Label.MIRE_DPG_Zones)) {
            throw new ModonEgyptDPGReadAPIException('Technical Error: Zone is missing.');
        }

        Set<String> mireDpgZones = new Set<String>();

        for (String zone : System.Label.MIRE_DPG_Zones.split(',')) {
            if (String.isNotBlank(zone)) {
                mireDpgZones.add('\'' + String.escapeSingleQuotes(zone.trim()) + '\'');
            }
        }

        conditions.add('Zone__c IN (' + String.join(mireDpgZones, ',') + ')');
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

		if(fieldSet != null) {
			for(Schema.FieldSetMember member : fieldSet.getFields()) {
				fields.add(member.getFieldPath());
			}
		} else {
			String errorMessage = String.format(
                'FieldSet is not configured at Salesforce side for given object name: {0} in Object Manager. Please Contact Modon Egypt Salesforce IT team/Administrator.',
                new List<String>{ objectName }
            );
            throw new ModonEgyptDPGReadAPIException(errorMessage);
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
                   // finalFields.add(relationshipName + '.Id');
                    finalFields.add(relationshipName + '.Name');
                }

                //Remove that field having Id as we need to send only name.
                finalFields.remove(field);
            }
        }

        /*
        * Add Extra Fields
        */
        if(extraFields != null && !extraFields.isEmpty()) {
            finalFields.addAll(extraFields);
        }

        return new List<String>(finalFields);
    }

    public class ModonEgyptDPGReadAPIException extends Exception {
        //Custom Exception class to throw custom exception.
    }
}