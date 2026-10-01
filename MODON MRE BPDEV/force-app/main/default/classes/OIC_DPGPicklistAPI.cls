/**********************************************************************************************************************
* Name        : OIC_DPGPicklistAPI
* Description : Generic picklist metadata endpoint for DPG. Given an object (Lead, Opportunity, any custom object)
*               and an optional list of fields, returns the picklist values for each field -- including dependent
*               picklists, where the valid values are grouped by their controlling field's value.
*               Object/field agnostic: it reads everything from Schema describe, so no per-field code is needed.
* Usage       : POST /services/apexrest/dpg/getPicklistValues/
*               Body: { "ObjectName": "Lead", "Fields": ["SalesType__c","UnitType__c","Status"] }
*               "Fields" is optional -- omit it to get every picklist field on the object.
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       -        13 Jul 2026    Initial. Handles picklist + multipicklist, dependent picklists (picklist or
*                                     checkbox controller), restricted flag, default value, and active-only entries.
* 1.1       Jay Patel 18 Sep 2026   MCR-73 — createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/getPicklistValues/*')
global with sharing class OIC_DPGPicklistAPI {

    /* ====================================================================================
     *  ERROR CODES
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('PCK-001', 404, 'The requested object does not exist or is not accessible.');
        OIC_RestResponse.define('PCK-002', 400, 'None of the requested fields are picklists on this object.');
    }

    private static final String ERR_NO_OBJECT = 'PCK-001';
    private static final String ERR_NO_FIELDS = 'PCK-002';

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void getPicklistValues() {
        try {
            RestRequest req = RestContext.request;

            if (req == null || req.requestBody == null || req.requestBody.size() == 0) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.INVALID_REQUEST_BODY,
                    'The request body is empty. Please send a JSON payload containing the ObjectName.'
                ).send();
                return;
            }

            Map<String, Object> input;
            try {
                input = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            } catch (Exception parseEx) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.INVALID_REQUEST_BODY, 'The request body is not valid JSON.'
                ).send();
                return;
            }

            String objectName = (String) input.get('ObjectName');
            if (String.isBlank(objectName)) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.MISSING_REQUIRED_FIELD,
                    'ObjectName is mandatory (for example "Lead").'
                ).send();
                return;
            }

            // Optional list of specific fields. When absent, every picklist field is returned.
            List<String> requestedFields = new List<String>();
            if (input.get('Fields') instanceof List<Object>) {
                for (Object o : (List<Object>) input.get('Fields')) {
                    if (o != null && String.isNotBlank(String.valueOf(o))) {
                        requestedFields.add(String.valueOf(o).trim());
                    }
                }
            }

            // ---- Resolve the object -------------------------------------------------------
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) {
                OIC_RestResponse.failure(ERR_NO_OBJECT,
                    'No object named "' + objectName + '" exists in this org.').send();
                return;
            }
            Schema.DescribeSObjectResult objDesc = sot.getDescribe();
            if (!objDesc.isAccessible()) {
                OIC_RestResponse.failure(ERR_NO_OBJECT,
                    'You do not have access to the object "' + objectName + '".').send();
                return;
            }

            Map<String, Schema.SObjectField> fieldMap = objDesc.fields.getMap();

            // ---- Decide which fields to describe ------------------------------------------
            List<String> fieldsToProcess = new List<String>();
            List<Map<String, String>> skipped = new List<Map<String, String>>();

            if (!requestedFields.isEmpty()) {
                for (String f : requestedFields) {
                    Schema.SObjectField token = fieldMap.get(f.toLowerCase());
                    if (token == null) {
                        skipped.add(skip(f, 'Field does not exist on ' + objectName + '.'));
                        continue;
                    }
                    if (!isPicklistType(token.getDescribe().getType())) {
                        skipped.add(skip(f, 'Field is not a picklist.'));
                        continue;
                    }
                    fieldsToProcess.add(f.toLowerCase());
                }
            } else {
                for (String key : fieldMap.keySet()) {
                    if (isPicklistType(fieldMap.get(key).getDescribe().getType())) {
                        fieldsToProcess.add(key);
                    }
                }
            }

            if (fieldsToProcess.isEmpty()) {
                OIC_RestResponse.failure(ERR_NO_FIELDS,
                    'No picklist fields were found for the request on "' + objectName + '".').send();
                return;
            }

            // ---- Build the picklist payload -----------------------------------------------
            List<PicklistField> picklists = new List<PicklistField>();
            for (String apiName : fieldsToProcess) {
                picklists.add(describePicklist(fieldMap.get(apiName), fieldMap));
            }

            OIC_RestResponse.success()
                .put('ObjectName', objDesc.getName())
                .put('Picklists',  picklists)
                .put('Skipped',    skipped)
                .flat()
                .send();

        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Picklist API',
                'OIC_DPGPicklistAPI',
                'getPicklistValues'
            ));
            OIC_RestResponse.fromException(ex).send();
        }
    }

    /* ====================================================================================
     *  DESCRIBE  ->  DTO
     * ==================================================================================== */
    private static PicklistField describePicklist(Schema.SObjectField token,
                                                  Map<String, Schema.SObjectField> fieldMap) {
        Schema.DescribeFieldResult dfr = token.getDescribe();

        PicklistField pf   = new PicklistField();
        pf.FieldApiName    = dfr.getName();
        pf.Label           = dfr.getLabel();
        pf.Type            = String.valueOf(dfr.getType()).toLowerCase();
        pf.Restricted      = dfr.isRestrictedPicklist();
        pf.Dependent       = dfr.isDependentPicklist();

        // Flat list of every active value (always populated).
        List<PicklistValue> allValues = new List<PicklistValue>();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (!pe.isActive()) continue;
            PicklistValue v = new PicklistValue();
            v.Label        = pe.getLabel();
            v.Value        = pe.getValue();
            v.DefaultValue = pe.isDefaultValue();
            allValues.add(v);
            if (pe.isDefaultValue()) pf.DefaultValue = pe.getValue();
        }
        pf.Values = allValues;

        // Dependent picklist: group valid values by the controlling field's value.
        if (dfr.isDependentPicklist()) {
            Schema.SObjectField controller = dfr.getController();
            if (controller != null) {
                Schema.DescribeFieldResult ctrlDfr = controller.getDescribe();
                pf.ControllingField = ctrlDfr.getName();
                pf.ValuesByController = buildDependencyMap(dfr, ctrlDfr);
            }
        }
        return pf;
    }

    /**
     * Groups a dependent field's values under each value of its controlling field.
     * The mapping lives in each PicklistEntry's base64 "validFor" bitmap, which is not
     * exposed directly -- we reach it by (de)serializing the entry to JSON.
     */
    private static Map<String, List<PicklistValue>> buildDependencyMap(
            Schema.DescribeFieldResult depDfr, Schema.DescribeFieldResult ctrlDfr) {

        // Controlling values, in the index order the bitmap is keyed on.
        List<String> controllingValues = new List<String>();
        if (ctrlDfr.getType() == Schema.DisplayType.Boolean) {
            controllingValues.add('false'); // index 0
            controllingValues.add('true');  // index 1
        } else {
            for (Schema.PicklistEntry pe : ctrlDfr.getPicklistValues()) {
                controllingValues.add(pe.getValue());
            }
        }

        Map<String, List<PicklistValue>> result = new Map<String, List<PicklistValue>>();
        for (String cv : controllingValues) {
            result.put(cv, new List<PicklistValue>());
        }

        List<PicklistEntryWrapper> depEntries = (List<PicklistEntryWrapper>) JSON.deserialize(
            JSON.serialize(depDfr.getPicklistValues()), List<PicklistEntryWrapper>.class);

        for (PicklistEntryWrapper w : depEntries) {
            if (w.active != null && !w.active) continue;
            for (Integer i = 0; i < controllingValues.size(); i++) {
                if (isValidFor(w.validFor, i)) {
                    PicklistValue v = new PicklistValue();
                    v.Label = w.label;
                    v.Value = w.value;
                    result.get(controllingValues[i]).add(v);
                }
            }
        }
        return result;
    }

    /* ====================================================================================
     *  validFor BITMAP DECODING
     * ==================================================================================== */
    /** True when the dependent value is valid for the controlling value at the given index. */
    private static Boolean isValidFor(String validForBase64, Integer controllingIndex) {
        if (String.isBlank(validForBase64)) return false;

        String hex = EncodingUtil.convertToHex(EncodingUtil.base64Decode(validForBase64));
        Integer byteIndex = controllingIndex / 8;
        Integer bitShift  = 7 - Math.mod(controllingIndex, 8);

        // Two hex chars per byte; guard against an index past the end of the bitmap.
        if ((byteIndex * 2 + 2) > hex.length()) return false;

        Integer byteVal = hexToInt(hex.substring(byteIndex * 2, byteIndex * 2 + 2));
        return (byteVal & (1 << bitShift)) != 0;
    }

    /** Apex Integer.valueOf has no radix form, so parse hex ourselves. */
    private static Integer hexToInt(String hex) {
        final String digits = '0123456789abcdef';
        String h = hex.toLowerCase();
        Integer result = 0;
        for (Integer i = 0; i < h.length(); i++) {
            result = (result * 16) + digits.indexOf(h.substring(i, i + 1));
        }
        return result;
    }

    /* ====================================================================================
     *  HELPERS
     * ==================================================================================== */
    private static Boolean isPicklistType(Schema.DisplayType t) {
        return (t == Schema.DisplayType.Picklist || t == Schema.DisplayType.MultiPicklist);
    }

    private static Map<String, String> skip(String field, String reason) {
        return new Map<String, String>{ 'Field' => field, 'Reason' => reason };
    }

    /* ====================================================================================
     *  DTOs
     * ==================================================================================== */
    /** Mirrors Schema.PicklistEntry's JSON shape so we can read the hidden validFor bitmap. */
    public class PicklistEntryWrapper {
        public Boolean active;
        public Boolean defaultValue;
        public String  label;
        public String  value;
        public String  validFor;
    }

    global class PicklistField {
        public String  FieldApiName;
        public String  Label;
        public String  Type;              // picklist | multipicklist
        public Boolean Restricted;
        public Boolean Dependent;
        public String  DefaultValue;
        public String  ControllingField;  // populated only when Dependent = true
        public List<PicklistValue> Values;                              // all active values
        public Map<String, List<PicklistValue>> ValuesByController;     // only when Dependent = true
    }

    global class PicklistValue {
        public String  Label;
        public String  Value;
        public Boolean DefaultValue;
    }
}