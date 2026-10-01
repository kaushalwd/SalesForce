/**********************************************************************************************************************
* Name               : AccountKYCValidationInvocable
* Description        : Validates the KYC details for Account/Contact related to Document based on Custom Metadata.
* Usage              : Executed via Flow
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date                  Comment
* 1.0           Rushi Patel                 26 Aug 2026           Initial draft
* 1.1           Rushi Patel                 21 September 2026     Added Resident Type matching to rule selection
* 1.2           Rushi Patel                 21 September 2026     Retired unused Record_Type_Developer_Name__c from rule matching
* 1.3           Rushi Patel                 22 September 2026     Config validation, comma separated Record Type,
*                                                                 Resident field driven by KYC_Validation_Setting__mdt,
*                                                                 blank Resident value now blocks validation
* 1.4           Rushi Patel                 22 September 2026     Cross object field paths (e.g. Account.Trade_License_Number__c)
*                                                                 and Parent Record Type scoping for Organization Account
******************************************************************************************************************/
public class AccountKYCValidationInvocable {

    // Structural fields needed to route and match records. Not configurable because the
    // routing logic itself depends on them.
    private static final Set<String> BASE_ACCOUNT_FIELDS =
        new Set<String>{'Id', 'RecordType.DeveloperName', 'RecordType.Name'};
    private static final Set<String> BASE_CONTACT_FIELDS =
        new Set<String>{'Id', 'RecordType.DeveloperName', 'RecordType.Name', 'IsPersonAccount', 'AccountId'};

    // Cache of describes so a long rule list does not re-describe the same object repeatedly
    private static Map<String, Map<String, Schema.SObjectField>> fieldMapCache =
        new Map<String, Map<String, Schema.SObjectField>>();

    // Holds the per-object configuration from KYC_Validation_Setting__mdt
    private class ObjectSetting {
        String residentFieldApiName;
        String residentFieldLabel;
        String parentRelationshipName;
    }

    // Wrapper class to receive input parameters from a Flow
    public class KYCRequest {
        @InvocableVariable(label='Document ID' required=true)
        public Id documentId;
    }

    // Wrapper class to send output results back to the Flow
    public class KYCResponse {
        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;
    }

    @InvocableMethod(label='Validate Account KYC' description='Validates the KYC details for Account/Contact related to Document based on Custom Metadata.')
    public static List<KYCResponse> validateKYC(List<KYCRequest> requests) {
        List<KYCResponse> responses = new List<KYCResponse>();

        // 1. EXTRACT DOCUMENT IDS
        Set<Id> documentIds = new Set<Id>();
        for (KYCRequest req : requests) {
            if (req.documentId != null) {
                documentIds.add(req.documentId);
            }
        }

        // If no document IDs were passed, return success for all requests by default
        if (documentIds.isEmpty()) {
            for (KYCRequest req : requests) {
                KYCResponse res = new KYCResponse();
                res.isSuccess = true;
                responses.add(res);
            }
            return responses;
        }

        // 2. FETCH ACTIVE RULES AND PER-OBJECT SETTINGS
        List<Account_KYC_Validation__mdt> kycList = [
            SELECT Field_API_Name__c, Field_Label__c, Object_API_Name__c,
                   Record_Type__c, Parent_Record_Type__c, ResidentType__c
            FROM Account_KYC_Validation__mdt
            WHERE Is_Active__c = true
        ];

        Map<String, ObjectSetting> settingsByObject = loadObjectSettings();

        // 3. VALIDATE THE CONFIGURATION BEFORE USING IT
        // A single bad field API name would otherwise break the dynamic SOQL and make every
        // document look like it had no related record, so surface it as a real error instead.
        List<String> configErrors = validateConfiguration(kycList, settingFieldPaths(settingsByObject));
        if (!configErrors.isEmpty()) {
            return failAll(requests, 'KYC validation is misconfigured: ' + String.join(configErrors, '; ')
                + '. Please correct the KYC validation custom metadata.');
        }

        // 4. BUILD THE FIELD SETS FOR THE DYNAMIC QUERIES
        Set<String> accountFields = new Set<String>(BASE_ACCOUNT_FIELDS);
        Set<String> contactFields = new Set<String>(BASE_CONTACT_FIELDS);

        addSettingFields(settingsByObject.get('account'), accountFields);
        addSettingFields(settingsByObject.get('contact'), contactFields);

        for (Account_KYC_Validation__mdt kyc : kycList) {
            if (String.isBlank(kyc.Field_API_Name__c) || String.isBlank(kyc.Object_API_Name__c)) {
                continue;
            }
            if (kyc.Object_API_Name__c.trim().equalsIgnoreCase('Account')) {
                accountFields.add(kyc.Field_API_Name__c.trim());
            } else if (kyc.Object_API_Name__c.trim().equalsIgnoreCase('Contact')) {
                contactFields.add(kyc.Field_API_Name__c.trim());
            }
        }

        // 5. QUERY RELEVANT DOCUMENTS
        Map<Id, Documents__c> docMap = new Map<Id, Documents__c>([
            SELECT Id, Account__c, PrimaryContact__c
            FROM Documents__c
            WHERE Id IN :documentIds
        ]);

        Map<Id, Id> docIdToAccountId = new Map<Id, Id>();
        Map<Id, Id> docIdToContactId = new Map<Id, Id>();
        Set<Id> allAccountIds = new Set<Id>();
        Set<Id> allContactIds = new Set<Id>();

        for (Documents__c doc : docMap.values()) {
            if (doc.Account__c != null) {
                docIdToAccountId.put(doc.Id, doc.Account__c);
                allAccountIds.add(doc.Account__c);
            } else if (doc.PrimaryContact__c != null) {
                docIdToContactId.put(doc.Id, doc.PrimaryContact__c);
                allContactIds.add(doc.PrimaryContact__c);
            }
        }

        // 6. PRE-PROCESS CONTACTS FOR PERSON ACCOUNT SCENARIOS
        // A Document pointing at a Person Account's Contact is validated against the Account instead.
        Map<Id, Contact> preContactMap = new Map<Id, Contact>();
        if (!allContactIds.isEmpty()) {
            preContactMap = new Map<Id, Contact>([
                SELECT Id, IsPersonAccount, AccountId
                FROM Contact
                WHERE Id IN :allContactIds
            ]);
            for (Contact c : preContactMap.values()) {
                if (c.IsPersonAccount && c.AccountId != null) {
                    allAccountIds.add(c.AccountId);
                }
            }
        }

        // 7. QUERY ALL REQUIRED ACCOUNT AND CONTACT DATA
        // Field names were validated in step 3, so a failure here is genuinely unexpected
        // and is reported rather than swallowed.
        Map<Id, SObject> queriedAccounts = new Map<Id, SObject>();
        Map<Id, SObject> queriedContacts = new Map<Id, SObject>();

        if (!allAccountIds.isEmpty()) {
            String accQuery = 'SELECT ' + String.join(new List<String>(accountFields), ', ')
                + ' FROM Account WHERE Id IN :allAccountIds';
            try {
                queriedAccounts = new Map<Id, SObject>(Database.query(accQuery));
            } catch (Exception e) {
                return failAll(requests, 'Unable to read Account KYC fields: ' + e.getMessage());
            }
        }

        if (!allContactIds.isEmpty()) {
            String conQuery = 'SELECT ' + String.join(new List<String>(contactFields), ', ')
                + ' FROM Contact WHERE Id IN :allContactIds';
            try {
                queriedContacts = new Map<Id, SObject>(Database.query(conQuery));
            } catch (Exception e) {
                return failAll(requests, 'Unable to read Contact KYC fields: ' + e.getMessage());
            }
        }

        // 8. EVALUATE KYC DATA AGAINST RULES FOR EACH REQUEST
        for (KYCRequest req : requests) {
            KYCResponse res = new KYCResponse();
            res.isSuccess = true;

            if (req.documentId == null || !docMap.containsKey(req.documentId)) {
                res.errorMessage = 'Document not found.';
                res.isSuccess = false;
                responses.add(res);
                continue;
            }

            Id docId = req.documentId;
            Id accId = docIdToAccountId.get(docId);
            Id conId = docIdToContactId.get(docId);

            SObject targetRecord = null;
            String objectType = '';

            if (accId != null && queriedAccounts.containsKey(accId)) {
                targetRecord = queriedAccounts.get(accId);
                objectType = 'Account';
            } else if (conId != null && preContactMap.containsKey(conId)) {
                Contact preCon = preContactMap.get(conId);
                if (preCon.IsPersonAccount && queriedAccounts.containsKey(preCon.AccountId)) {
                    targetRecord = queriedAccounts.get(preCon.AccountId);
                    objectType = 'Account';
                } else if (queriedContacts.containsKey(conId)) {
                    targetRecord = queriedContacts.get(conId);
                    objectType = 'Contact';
                }
            }

            if (targetRecord == null) {
                res.isSuccess = false;
                res.errorMessage = 'No related Account or Contact found for KYC validation.';
                responses.add(res);
                continue;
            }

            ObjectSetting setting = settingsByObject.get(objectType.toLowerCase());

            // The record's own record type
            Set<String> ownRecordTypeValues = new Set<String>{
                stringValue(getFieldValue(targetRecord, 'RecordType.DeveloperName')),
                stringValue(getFieldValue(targetRecord, 'RecordType.Name'))
            };

            // The parent record's record type, e.g. the Account behind an Organization Account Contact
            Set<String> parentRecordTypeValues = new Set<String>();
            if (setting != null && String.isNotBlank(setting.parentRelationshipName)) {
                String parentRel = setting.parentRelationshipName.trim();
                parentRecordTypeValues.add(stringValue(getFieldValue(targetRecord, parentRel + '.RecordType.DeveloperName')));
                parentRecordTypeValues.add(stringValue(getFieldValue(targetRecord, parentRel + '.RecordType.Name')));
            }

            // Resolve this record's Resident / Non-Resident value so rules can be filtered on it
            String recordResidentType = '';
            if (setting != null && String.isNotBlank(setting.residentFieldApiName)) {
                recordResidentType = stringValue(getFieldValue(targetRecord, setting.residentFieldApiName.trim()));
            }

            // Narrow the rules down to the ones that apply to this record
            List<Account_KYC_Validation__mdt> applicableRules = new List<Account_KYC_Validation__mdt>();
            Boolean residentScopedRuleExists = false;

            for (Account_KYC_Validation__mdt kyc : kycList) {
                if (String.isBlank(kyc.Object_API_Name__c)
                    || !kyc.Object_API_Name__c.trim().equalsIgnoreCase(objectType)) {
                    continue;
                }
                // Record Type on the metadata is a comma separated list; blank applies to all record types
                if (!matchesAny(kyc.Record_Type__c, ownRecordTypeValues)) {
                    continue;
                }
                if (!matchesAny(kyc.Parent_Record_Type__c, parentRecordTypeValues)) {
                    continue;
                }
                applicableRules.add(kyc);
                if (String.isNotBlank(kyc.ResidentType__c)) {
                    residentScopedRuleExists = true;
                }
            }

            List<String> missingFields = new List<String>();

            // The Resident value decides which other fields are required, so if any applicable rule
            // is scoped by Resident Type then the record must carry that value before we can go on.
            // Objects with no Resident-scoped rules are unaffected.
            if (residentScopedRuleExists && String.isBlank(recordResidentType)) {
                missingFields.add(
                    (setting != null && String.isNotBlank(setting.residentFieldLabel))
                        ? setting.residentFieldLabel
                        : 'Resident Status'
                );
            }

            for (Account_KYC_Validation__mdt kyc : applicableRules) {
                if (!matchesAny(kyc.ResidentType__c, new Set<String>{recordResidentType})) {
                    continue;
                }
                if (String.isBlank(kyc.Field_API_Name__c)) {
                    continue;
                }

                Object val = getFieldValue(targetRecord, kyc.Field_API_Name__c.trim());

                if (val == null || String.valueOf(val).trim() == '') {
                    missingFields.add(
                        String.isNotBlank(kyc.Field_Label__c) ? kyc.Field_Label__c : kyc.Field_API_Name__c
                    );
                }
            }

            if (!missingFields.isEmpty()) {
                res.isSuccess = false;
                res.errorMessage = 'The following KYC fields are missing: ' + String.join(missingFields, ', ');
            }

            responses.add(res);
        }

        return responses;
    }

    /**
     * Builds a failed response for every request, used when the configuration itself is unusable.
     */
    private static List<KYCResponse> failAll(List<KYCRequest> requests, String message) {
        List<KYCResponse> responses = new List<KYCResponse>();
        for (KYCRequest req : requests) {
            KYCResponse res = new KYCResponse();
            res.isSuccess = false;
            res.errorMessage = message;
            responses.add(res);
        }
        return responses;
    }

    private static String stringValue(Object val) {
        return val == null ? '' : String.valueOf(val).trim();
    }

    /**
     * Reads a value from a record, following a dotted path such as Account.Trade_License_Number__c
     * or Account.RecordType.DeveloperName. Returns null where any step in the path is empty.
     */
    @TestVisible
    private static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }
        List<String> parts = fieldPath.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (current == null) {
                return null;
            }
            try {
                current = current.getSObject(parts[i].trim());
            } catch (Exception e) {
                return null;
            }
        }
        if (current == null) {
            return null;
        }
        try {
            return current.get(parts[parts.size() - 1].trim());
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Loads the per-object settings, keyed on the lower cased object API name.
     */
    private static Map<String, ObjectSetting> loadObjectSettings() {
        Map<String, ObjectSetting> settingsByObject = new Map<String, ObjectSetting>();
        for (KYC_Validation_Setting__mdt s : [
            SELECT Object_API_Name__c, Resident_Field_API_Name__c, Resident_Field_Label__c,
                   Parent_Relationship_Name__c
            FROM KYC_Validation_Setting__mdt
        ]) {
            if (String.isBlank(s.Object_API_Name__c)) {
                continue;
            }
            ObjectSetting setting = new ObjectSetting();
            setting.residentFieldApiName = s.Resident_Field_API_Name__c;
            setting.residentFieldLabel = s.Resident_Field_Label__c;
            setting.parentRelationshipName = s.Parent_Relationship_Name__c;
            settingsByObject.put(s.Object_API_Name__c.trim().toLowerCase(), setting);
        }
        return settingsByObject;
    }

    /**
     * Adds the configured Resident field and parent Record Type paths to a query field set.
     */
    private static void addSettingFields(ObjectSetting setting, Set<String> fields) {
        if (setting == null) {
            return;
        }
        if (String.isNotBlank(setting.residentFieldApiName)) {
            fields.add(setting.residentFieldApiName.trim());
        }
        if (String.isNotBlank(setting.parentRelationshipName)) {
            String parentRel = setting.parentRelationshipName.trim();
            fields.add(parentRel + '.RecordType.DeveloperName');
            fields.add(parentRel + '.RecordType.Name');
        }
    }

    /**
     * Flattens the settings into object name -> the field paths that must exist on that object.
     */
    private static Map<String, List<String>> settingFieldPaths(Map<String, ObjectSetting> settingsByObject) {
        Map<String, List<String>> pathsByObject = new Map<String, List<String>>();
        for (String objectName : settingsByObject.keySet()) {
            ObjectSetting setting = settingsByObject.get(objectName);
            List<String> paths = new List<String>();
            if (String.isNotBlank(setting.residentFieldApiName)) {
                paths.add(setting.residentFieldApiName.trim());
            }
            if (String.isNotBlank(setting.parentRelationshipName)) {
                paths.add(setting.parentRelationshipName.trim() + '.RecordType.DeveloperName');
            }
            pathsByObject.put(objectName, paths);
        }
        return pathsByObject;
    }

    /**
     * Checks every configured object and field path against the schema and returns a list of
     * human readable problems. An empty list means the configuration is safe to use.
     */
    @TestVisible
    private static List<String> validateConfiguration(List<Account_KYC_Validation__mdt> kycList,
                                                      Map<String, List<String>> extraPathsByObject) {
        List<String> errors = new List<String>();
        Set<String> knownObjects = new Set<String>();

        Set<String> objectNames = new Set<String>();
        for (Account_KYC_Validation__mdt kyc : kycList) {
            if (String.isNotBlank(kyc.Object_API_Name__c)) {
                objectNames.add(kyc.Object_API_Name__c.trim().toLowerCase());
            }
        }
        objectNames.addAll(extraPathsByObject.keySet());

        for (String objectName : objectNames) {
            if (Schema.getGlobalDescribe().get(objectName) == null) {
                errors.add('unknown object "' + objectName + '"');
            } else {
                knownObjects.add(objectName);
            }
        }

        // Every rule must point at a field path that actually resolves on its object
        for (Account_KYC_Validation__mdt kyc : kycList) {
            if (String.isBlank(kyc.Object_API_Name__c) || String.isBlank(kyc.Field_API_Name__c)) {
                continue;
            }
            String objectName = kyc.Object_API_Name__c.trim().toLowerCase();
            if (!knownObjects.contains(objectName)) {
                continue; // already reported as an unknown object
            }
            String fieldPath = kyc.Field_API_Name__c.trim();
            if (!isValidFieldPath(objectName, fieldPath)) {
                errors.add('unknown field "' + fieldPath + '" on ' + kyc.Object_API_Name__c);
            }
        }

        // The configured Resident field and parent relationship must resolve too
        for (String objectName : extraPathsByObject.keySet()) {
            if (!knownObjects.contains(objectName)) {
                continue;
            }
            for (String path : extraPathsByObject.get(objectName)) {
                if (!isValidFieldPath(objectName, path)) {
                    errors.add('unknown setting path "' + path + '" on ' + objectName);
                }
            }
        }

        return errors;
    }

    /**
     * Resolves a dotted field path against an object, walking each relationship segment.
     */
    @TestVisible
    private static Boolean isValidFieldPath(String objectApiName, String fieldPath) {
        Schema.SObjectType currentType = Schema.getGlobalDescribe().get(objectApiName.toLowerCase());
        if (currentType == null || String.isBlank(fieldPath)) {
            return false;
        }
        List<String> parts = fieldPath.split('\\.');
        for (Integer i = 0; i < parts.size(); i++) {
            String part = parts[i].trim();
            Map<String, Schema.SObjectField> fieldMap = fieldMapFor(currentType);

            if (i == parts.size() - 1) {
                return fieldMap.containsKey(part.toLowerCase());
            }

            // Intermediate segment must be a relationship
            Schema.SObjectType nextType = null;
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult dfr = field.getDescribe();
                String relName = dfr.getRelationshipName();
                if (relName != null && relName.equalsIgnoreCase(part)) {
                    List<Schema.SObjectType> refs = dfr.getReferenceTo();
                    if (!refs.isEmpty()) {
                        nextType = refs[0];
                    }
                    break;
                }
            }
            if (nextType == null) {
                return false;
            }
            currentType = nextType;
        }
        return false;
    }

    private static Map<String, Schema.SObjectField> fieldMapFor(Schema.SObjectType sObjType) {
        String key = String.valueOf(sObjType).toLowerCase();
        if (!fieldMapCache.containsKey(key)) {
            fieldMapCache.put(key, sObjType.getDescribe().fields.getMap());
        }
        return fieldMapCache.get(key);
    }

    /**
     * Metadata text fields hold a comma separated list, e.g. 'Resident,Non-Resident'
     * or 'PersonAccount,OrganizationAccount'.
     * A blank configured value means the rule is not scoped and therefore applies to everything.
     * Where a rule IS scoped but the record carries no matching value, the rule does not apply.
     */
    @TestVisible
    private static Boolean matchesAny(String csvValues, Set<String> recordValues) {
        if (String.isBlank(csvValues)) {
            return true;
        }
        for (String candidate : csvValues.split(',')) {
            String trimmedCandidate = candidate.trim();
            if (String.isBlank(trimmedCandidate)) {
                continue;
            }
            for (String recordValue : recordValues) {
                if (String.isNotBlank(recordValue) && trimmedCandidate.equalsIgnoreCase(recordValue)) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Convenience wrapper for the single valued Resident Type comparison.
     */
    @TestVisible
    private static Boolean matchesResidentType(String metaResidentTypes, String recordResidentType) {
        return matchesAny(metaResidentTypes, new Set<String>{recordResidentType});
    }
}