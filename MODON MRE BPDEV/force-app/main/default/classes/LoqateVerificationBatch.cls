/**
 *Name               : LoqateVerificationBatch                                                        
* Description        : This class is used as controller for LWC (unitSearchLwc)
* Usage              : Batch is for Old Data or any data wnat to Call the Loqate API                                                   
* Created By         :Arvind Kesharwani
 *Version       Author                          Date            Comment   
 1.0            Arvind Kesharwani             04/20/2026       Intial Dreaft

 * LoqateVerificationBatch
 * Validates phone + email fields via Loqate API for Lead, Contact, Account.
 *
 * Record type filters:
 *   Lead    - ALL record types, no filter
 *   Contact - exclude Broker Agent
 *   Account - exclude Broker Agency
 *
 * Run from Execute Anonymous:
 *   Database.executeBatch(new LoqateVerificationBatch('Lead'),    1);
 *   Database.executeBatch(new LoqateVerificationBatch('Contact'), 1);
 *   Database.executeBatch(new LoqateVerificationBatch('Account'), 1);
 */
global class LoqateVerificationBatch
        implements Database.Batchable<SObject>, Database.AllowsCallouts {

     private static final String NAMED_CRED = 'callout:Loqate_Integration';
     private static final String PHONE_ENDPOINT = '/XXMODODN_LOQATE_PHONENUMBERV2/1.0/loqate/phonenumbervalidation';
     private static final String EMAIL_ENDPOINT = '/XXMODON_LOQATE_EMAIL/1.0/loqate/emailvalidation';
     private static String API_KEY;
// Static block runs once when the class is referenced
    static {
        List<OIC_Credential__mdt> creds = [
            SELECT DeveloperName, Endpoint__c, Password__c 
            FROM OIC_Credential__mdt 
            WHERE DeveloperName IN ('Loqate_EMAIL_ENDPOINT', 'Loqate_PHONE_ENDPOINT')
        ];
        for (OIC_Credential__mdt mdt : creds) {
            if (mdt.DeveloperName == 'Loqate_PHONE_ENDPOINT') {
              //  PHONE_ENDPOINT = mdt.Endpoint__c;
                API_KEY = mdt.Password__c;
            } else if (mdt.DeveloperName == 'Loqate_EMAIL_ENDPOINT') {
               // EMAIL_ENDPOINT = mdt.Endpoint__c;
                API_KEY = mdt.Password__c;

            }
        }
    }
    
    private String objectName;
    private String extraFilter;

    global LoqateVerificationBatch(String objectName) {
        this.objectName  = objectName;
        this.extraFilter = '';
    }
        

    global LoqateVerificationBatch(String objectName, String extraFilter) {
        this.objectName  = objectName;
        this.extraFilter = String.isBlank(extraFilter) ? '' : ' AND (' + extraFilter + ')';
    }

    /* ── Start ───────────────────────────────────────────────────────── */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        String query;

        if (objectName == 'Lead') {
            // Lead — ALL record types, exclude Modon Egypt
            query = 'SELECT Id, Email, MobilePhone FROM Lead '
                  + 'WHERE Loqate_Processed__c = false '
                  + 'AND (Email != null OR MobilePhone != null) '
                  + 'AND (Source_Entity__c = null OR Source_Entity__c != \'Modon - Egypt\')'
                  + extraFilter;

        } else if (objectName == 'Contact') {
            // Contact — exclude Broker Agent + Modon Egypt
            query = 'SELECT Id, Email, MobilePhone FROM Contact '
                  + 'WHERE Loqate_Processed__c = false '
                  + 'AND (Email != null OR MobilePhone != null) '
                  + 'AND (RecordType.Name = null OR RecordType.Name != \'Broker Agent\') '
                  + 'AND (Source_Entity__c = null OR Source_Entity__c != \'Modon - Egypt\')'
                  + extraFilter;

        } else if (objectName == 'Account') {
            // Account — exclude Broker Agency + Modon Egypt
            // Person Account: Source_Entity__pc | Account: Source_Entity__c
            query = 'SELECT Id, PersonEmail, PersonMobilePhone, RecordType.Name FROM Account '
                  + 'WHERE Loqate_Processed__c = false '
                  + 'AND (PersonEmail != null OR PersonMobilePhone != null) '
                  + 'AND RecordType.Name != \'Broker Agency\' '
                  + 'AND (Source_Entity__pc = null OR Source_Entity__pc != \'Modon - Egypt\') '
                  + 'AND (Source_Entity__c = null OR Source_Entity__c != \'Modon - Egypt\')'
                  + extraFilter;

        } else {
            return Database.getQueryLocator(
                'SELECT Id FROM Lead WHERE Id = null'
            );
        }

        System.debug('[LoqateBatch] Query: ' + query);
        return Database.getQueryLocator(query);
    }

    /* ── Execute ─────────────────────────────────────────────────────── */
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<SObject> toUpdate = new List<SObject>();

        for (SObject record : scope) {
            SObject updated = Schema.getGlobalDescribe()
                                    .get(objectName)
                                    .newSObject(record.Id);

            if (objectName == 'Lead') {
                processPhone(record, updated, 'MobilePhone');
                processEmail(record, updated, 'Email');

            } else if (objectName == 'Contact') {
                processPhone(record, updated, 'MobilePhone');
                processEmail(record, updated, 'Email');

            } else if (objectName == 'Account') {
                processPhone(record, updated, 'PersonMobilePhone');
                processEmail(record, updated, 'PersonEmail');
            }

            // Mark processed — skipped on next batch run
            updated.put('Loqate_Processed__c', true);
            toUpdate.add(updated);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    /* ── Finish ──────────────────────────────────────────────────────── */
    global void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT TotalJobItems, JobItemsProcessed, NumberOfErrors
            FROM   AsyncApexJob WHERE Id = :bc.getJobId()
        ];
        System.debug('[LoqateBatch] ' + objectName + ' done. '
            + 'Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems
            + '  Errors: '  + job.NumberOfErrors);
    }

    /* ── Phone validation ────────────────────────────────────────────── */
    private void processPhone(SObject record, SObject updated, String phoneField) {
        String phone = (String) record.get(phoneField);
        if (String.isBlank(phone)) return;

        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(NAMED_CRED + PHONE_ENDPOINT);
            req.setHeader('Content-Type', 'application/json');
           Map<String, String> payload = new Map<String, String>{
                'Key' => API_KEY,
                'Phone' => phone
            };
            req.setBody(JSON.serialize(payload));
            req.setTimeout(10000);
            HttpResponse res = new Http().send(req);

            System.debug('[LoqateBatch] PHONE_RESPONSE ' + objectName
                       + ' Id=' + record.Id + ' Body=' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String,Object> body  = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>       items = (List<Object>) body.get('Items');
                if (items != null && !items.isEmpty()) {
                    Map<String,Object> item  = (Map<String,Object>) items[0];
                    Boolean            valid = 'Yes'.equalsIgnoreCase((String) item.get('IsValid'));

                    updated.put('Phone_Valid__c',           valid);
                    updated.put('Phone_Verified_Number__c', valid ? (String) item.get('PhoneNumber')                        : null);
                    updated.put('Phone_Country_Prefix__c',  valid ? String.valueOf(item.get('CountryPrefix'))               : null);
                    updated.put('Phone_National_Format__c', valid ? cleanNationalFormat((String) item.get('NationalFormat')) : null);
                }
            }
        } catch (Exception e) {
            System.debug('[LoqateBatch] PHONE_ERROR ' + objectName
                       + ' Id=' + record.Id + ' Msg=' + e.getMessage());
        }
    }

    /* ── Email validation ────────────────────────────────────────────── */
    private void processEmail(SObject record, SObject updated, String emailField) {
        String email = (String) record.get(emailField);
        if (String.isBlank(email)) return;

        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
          req.setEndpoint(NAMED_CRED + EMAIL_ENDPOINT);
            req.setHeader('Content-Type', 'application/json');
           Map<String, String> payload = new Map<String, String>{
                'Key' => API_KEY,
                'Email' => email
            };
            req.setBody(JSON.serialize(payload));
            req.setTimeout(10000);
            HttpResponse res = new Http().send(req);

            System.debug('[LoqateBatch] EMAIL_RESPONSE ' + objectName
                       + ' Id=' + record.Id + ' Body=' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String,Object> body  = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>       items = (List<Object>) body.get('Items');
                if (items != null && !items.isEmpty()) {
                    Map<String,Object> item  = (Map<String,Object>) items[0];
                    String             code  = (String) item.get('ResponseCode');
                    Boolean            valid = 'Valid'.equalsIgnoreCase(code);

                    updated.put('Email_Valid_Status__c', valid ? 'Valid' : 'Invalid');
                }
            }
        } catch (Exception e) {
            System.debug('[LoqateBatch] EMAIL_ERROR ' + objectName
                       + ' Id=' + record.Id + ' Msg=' + e.getMessage());
        }
    }

    /* ── Helpers ─────────────────────────────────────────────────────── */
    private static String cleanNationalFormat(String raw) {
        if (String.isBlank(raw)) return null;
        String digits = raw.replaceAll('[^0-9]', '');
        digits = digits.replaceFirst('^0+', '');
        return String.isBlank(digits) ? null : digits;
    }
}