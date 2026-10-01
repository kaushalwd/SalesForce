public without sharing class MBP_DynamicLwcController {

    private static final Pattern SAFE_IDENT = Pattern.compile('^[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*$');

    @AuraEnabled(cacheable=true)
    public static List<sObject> fetchRecords(String objectApiName, List<String> fieldList, Integer pageSize, Integer pageNumber, String sortBy, Boolean isDesc) {
        if (String.isBlank(objectApiName) || fieldList == null || fieldList.isEmpty()) {
            return new List<sObject>();
        }

        String sanitizedObjectName = resolveObjectApiName(objectApiName);
        if (String.isBlank(sanitizedObjectName)) {
            return new List<sObject>();
        }

        List<String> sanitizedFields = new List<String>();
        for (String f : fieldList) {
            if (String.isNotBlank(f) && SAFE_IDENT.matcher(f.trim()).matches()) {
                sanitizedFields.add(f.trim());
            }
        }
        if (sanitizedFields.isEmpty()) {
            return new List<sObject>();
        }

        String fields = String.join(sanitizedFields, ',');
        String sanitizedSortBy = (String.isNotBlank(sortBy) && SAFE_IDENT.matcher(sortBy.trim()).matches())
            ? sortBy.trim() : 'Id';
        String order = (isDesc != null && isDesc) ? 'DESC' : 'ASC';
        Integer offsetVal = (pageNumber != null && pageSize != null && pageNumber > 0) ? (pageNumber - 1) * pageSize : 0;
        Integer limitVal = (pageSize != null && pageSize > 0) ? pageSize : 10;

        String query = 'SELECT ' + fields +
                       ' FROM ' + sanitizedObjectName +
                       ' ORDER BY ' + sanitizedSortBy + ' ' + order +
                       ' LIMIT :limitVal' +
                       ' OFFSET :offsetVal';

        return Database.queryWithBinds(
            query,
            new Map<String, Object>{
                'limitVal' => limitVal,
                'offsetVal' => offsetVal
            },
            AccessLevel.SYSTEM_MODE
        );
    }

    @AuraEnabled(cacheable=true)
    public static Integer fetchTotalCount(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return 0;
        }
        String sanitizedObjectName = resolveObjectApiName(objectApiName);
        if (String.isBlank(sanitizedObjectName)) {
            return 0;
        }
        String query = 'SELECT COUNT() FROM ' + sanitizedObjectName;
        return Database.countQueryWithBinds(query, new Map<String, Object>(), AccessLevel.SYSTEM_MODE);
    }

    private static String resolveObjectApiName(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return null;
        }
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName.trim());
        return sot == null ? null : sot.getDescribe().getName();
    }
}