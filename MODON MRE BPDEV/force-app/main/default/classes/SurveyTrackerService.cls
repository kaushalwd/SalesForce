/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : SurveyTrackerService
 * Author          : Arvind Kesharwani
 * Created Date    : Jun 17, 2026
 *
 * Description     : This is used for XEBO Integration
 *  
 * Change History  :
 *  Date          │   Author            │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 17, 2026  │ Arvind Kesharwani   │ Initial version
 *  Jul 19, 2026  │ Arvind Kesharwani   │ V1.1 - Sales Order support:
 *                │                     │  - buildTracker populates new SalesOrder__c
 *                │                     │    lookup; lookup routing is now based on the
 *                │                     │    Id's sObject type (type-safe: prevents DML
 *                │                     │    field-integrity failure when a non-Lead Id
 *                │                     │    was assigned to Lead__c)
 *                │                     │  - Added lname, residency, nationality
 *                │                     │    invocable variables mapped into extraInfo
 *                │                     │    (keys: lName, residency, nationality)
 *  Sep 22, 2026  │ Arvind Kesharwani   │ V1.2 - agentName support:
 *                │                     │  - Added agentName invocable variable
 *                │                     │    (Lead Owner full name) mapped into extraInfo
 *                │                     │    (key: agentName)
 *                │                     │  - Class declared without sharing so that
 *                │                     │    non-admin profiles can insert Survey_Tracker__c
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class SurveyTrackerService {

    private static final Integer BATCH_SIZE = 50;

    @TestVisible
    private static Map<String, Xebo_Survey_Config__mdt> mockConfigMap;

    // ── REQUEST ──────────────────────────────────────────────────────────────
    public class SurveyTrackerRequest {

        @InvocableVariable(label='Collector ID' required=true)
        public String  collectorId;

        @InvocableVariable(label='Medium (1=SMS 2=Email 3=WhatsApp 10=Link)' required=true)
        public Integer medium;

        @InvocableVariable(label='Email (required if Medium=2)')
        public String  contactEmail;

        @InvocableVariable(label='Mobile (required if Medium=1 or 3, also sent on Medium=2)')
        public String  contactMobile;

        @InvocableVariable(label='External Unique ID (required if Medium=10)')
        public String  extUniqueId;

        @InvocableVariable(label='Language Key')
        public String  langKey;

        // ── extraInfo fields ──────────────────────────────────────────────────
        @InvocableVariable(label='First Name')
        public String  fname;

        // Arvind Kesharwani Jul 19, 2026 : V1.1 - new survey fields
        @InvocableVariable(label='Last Name')
        public String  lname;

        @InvocableVariable(label='Residency')
        public String  residency;

        @InvocableVariable(label='Nationality')
        public String  nationality;
        // End V1.1

        // Arvind Kesharwani Sep 22, 2026 : V1.2 - Lead Owner name
        @InvocableVariable(label='Agent Name'
            description='Lead Owner full name — passed to Xebo as agentName extraInfo key')
        public String  agentName;
        // End V1.2

        @InvocableVariable(label='Service Name')
        public String  serviceName;

        @InvocableVariable(label='Service Type')
        public String  serviceType;

        @InvocableVariable(label='Region')
        public String  region;

        @InvocableVariable(label='City')
        public String  city;

        @InvocableVariable(label='License Status')
        public String  licenseStatus;

        @InvocableVariable(label='ID Number')
        public String  idNumber;

        @InvocableVariable(label='Extra Info JSON (additional fields only)'
            description='Optional. Format: [{"key":"X","value":"Y"}]')
        public String  extraInfoJson;

        // ── Tracker / Salesforce fields ───────────────────────────────────────
        @InvocableVariable(label='Record ID')
        public String  recordId;

        @InvocableVariable(label='Object API Name')
        public String  objectApiName;

        @InvocableVariable(label='Trigger Event Label')
        public String  triggerEvent;
    }

    // ── RESULT ───────────────────────────────────────────────────────────────
    public class SurveyTrackerResult {

        @InvocableVariable(label='Survey Tracker ID')
        public String  surveyTrackerId;

        @InvocableVariable(label='Is Queued')
        public Boolean isQueued;

        @InvocableVariable(label='Error Message')
        public String  errorMessage;
    }

    // ── Internal wrapper — holds both request body and HTTP result ────────────
    private class XeboResult {
        String  requestBody;
        Integer responseCode;
        String  responseBody;
        Boolean success;
    }

    private class Payload {
        Id                   trackerId;
        SurveyTrackerRequest request;
        Payload(Id tid, SurveyTrackerRequest req) { trackerId = tid; request = req; }
    }

    // ── ① FLOW + APEX ENTRY POINT ────────────────────────────────────────────
    @InvocableMethod(
        label       = 'Create Tracker & Send Survey'
        description = 'Creates Survey_Tracker__c then sends Xebo survey. Works for any Salesforce object.'
    )
    public static List<SurveyTrackerResult> createAndSend(List<SurveyTrackerRequest> requests) {

        List<SurveyTrackerResult> results = new List<SurveyTrackerResult>();
        if (requests == null || requests.isEmpty()) return results;

        List<Survey_Tracker__c> trackers = new List<Survey_Tracker__c>();
        for (SurveyTrackerRequest req : requests) {
            trackers.add(buildTracker(req));
        }

        try {
            insert trackers; // DML #1
        } catch (DmlException e) {
            for (SurveyTrackerRequest req : requests) {
                SurveyTrackerResult r = new SurveyTrackerResult();
                r.isQueued     = false;
                r.errorMessage = 'Tracker insert failed: ' + e.getMessage();
                results.add(r);
            }
            return results;
        }

        List<Payload> payloads = new List<Payload>();
        for (Integer i = 0; i < trackers.size(); i++) {
            payloads.add(new Payload(trackers[i].Id, requests[i]));
        }

        System.enqueueJob(new SurveyQueueable(payloads));

        for (Survey_Tracker__c t : trackers) {
            SurveyTrackerResult r = new SurveyTrackerResult();
            r.surveyTrackerId = t.Id;
            r.isQueued        = true;
            results.add(r);
        }
        return results;
    }

    // ── ② SYNCHRONOUS ENTRY POINT (used by Anonymous Apex / unit tests) ──────
    public static SurveyTrackerResult createAndSendNow(SurveyTrackerRequest request) {

        SurveyTrackerResult     result  = new SurveyTrackerResult();
        Survey_Tracker__c       tracker = buildTracker(request);
        Xebo_Survey_Config__mdt cfg     = loadConfigMap().get(request.collectorId);

        // No matching metadata record — insert Failed tracker immediately
        if (cfg == null) {
            result.isQueued          = false;
            result.errorMessage      = 'No active Xebo config found for Collector ID: ' + request.collectorId;
            tracker.Status__c        = 'Failed';
            tracker.Response_Body__c = result.errorMessage;
            insert tracker;
            result.surveyTrackerId   = tracker.Id;
            return result;
        }

        try {
            // ── Callout FIRST — before any DML ───────────────────────────────
            XeboResult xebo = callXebo(cfg, new List<SurveyTrackerRequest>{ request });

            // ── Set final status then insert in one DML ───────────────────────
            tracker.Status__c        = xebo.success ? 'Sent' : 'Failed';
            tracker.Response_Code__c = xebo.responseCode;
            tracker.Request_Body__c  = trunc(xebo.requestBody,  32768);
            tracker.Response_Body__c = trunc(xebo.responseBody, 32768);
            insert tracker;
            result.surveyTrackerId   = tracker.Id;

            result.isQueued = xebo.success;
            if (!xebo.success) result.errorMessage = xebo.responseBody;

        } catch (Exception e) {
            result.isQueued          = false;
            result.errorMessage      = e.getMessage();
            tracker.Status__c        = 'Failed';
            tracker.Response_Body__c = trunc(e.getMessage(), 32768);
            if (tracker.Id == null) {
                insert tracker;
                result.surveyTrackerId = tracker.Id;
            } else {
                update tracker;
            }
        }
        return result;
    }

    // ── INNER QUEUEABLE ──────────────────────────────────────────────────────
    public class SurveyQueueable implements Queueable, Database.AllowsCallouts {

        private List<Payload> payloads;

        public SurveyQueueable(List<Payload> payloads) {
            this.payloads = payloads;
        }

        public void execute(QueueableContext ctx) {

            Map<String, Xebo_Survey_Config__mdt> configMap = loadConfigMap();

            // Group payloads by Collector ID
            Map<String, List<Payload>> byCollector = new Map<String, List<Payload>>();
            for (Payload p : payloads) {
                if (!byCollector.containsKey(p.request.collectorId)) {
                    byCollector.put(p.request.collectorId, new List<Payload>());
                }
                byCollector.get(p.request.collectorId).add(p);
            }

            List<Survey_Tracker__c> toUpdate = new List<Survey_Tracker__c>();

            for (String collectorId : byCollector.keySet()) {

                List<Payload>           collectorGroup = byCollector.get(collectorId);
                Xebo_Survey_Config__mdt cfg            = configMap.get(collectorId);

                // No matching metadata — mark all as Failed
                if (cfg == null) {
                    for (Payload p : collectorGroup) {
                        toUpdate.add(new Survey_Tracker__c(
                            Id               = p.trackerId,
                            Status__c        = 'Failed',
                            Response_Body__c = 'No active Xebo config found for Collector ID: ' + collectorId
                        ));
                    }
                    continue;
                }

                // Batch 50 contacts per API call
                for (Integer i = 0; i < collectorGroup.size(); i += BATCH_SIZE) {

                    List<Payload> chunk = slicePayloads(collectorGroup, i, BATCH_SIZE);

                    List<SurveyTrackerRequest> chunkReqs = new List<SurveyTrackerRequest>();
                    for (Payload p : chunk) chunkReqs.add(p.request);

                    XeboResult xebo = new XeboResult();
                    xebo.success      = false;
                    xebo.responseCode = 0;
                    xebo.responseBody = '';
                    xebo.requestBody  = '';

                    try {
                        xebo = callXebo(cfg, chunkReqs);
                    } catch (Exception e) {
                        xebo.responseBody = e.getMessage();
                    }

                    for (Payload p : chunk) {
                        toUpdate.add(new Survey_Tracker__c(
                            Id               = p.trackerId,
                            Status__c        = xebo.success ? 'Sent' : 'Failed',
                            Response_Code__c = xebo.responseCode,
                            Request_Body__c  = trunc(xebo.requestBody,  32768),
                            Response_Body__c = trunc(xebo.responseBody, 32768)
                        ));
                    }
                }
            }

            if (!toUpdate.isEmpty()) update toUpdate; // DML #2
        }
    }

    // ── PRIVATE HELPERS ──────────────────────────────────────────────────────

    private static Survey_Tracker__c buildTracker(SurveyTrackerRequest req) {
        Survey_Tracker__c t = new Survey_Tracker__c(
            Collector_Id__c  = req.collectorId,
            Medium__c        = req.medium,
            Status__c        = 'Pending',
            Trigger_Event__c = req.triggerEvent,
            Sent_Date__c     = System.now(),
            Record_Id__c     = req.recordId,
            Object_Name__c   = req.objectApiName
        );
        // Arvind Kesharwani Jul 19, 2026 : V1.1 - route recordId to the correct lookup
        // based on the Id's sObject type. NOTE: assigning a non-Lead Id to Lead__c does
        // NOT throw at assignment time — it fails later at DML insert with a
        // field-integrity error — so the lookup must be chosen by type, not try/catch.
        if (String.isNotBlank(req.recordId)) {
            try {
                Id rid = (Id) req.recordId;
                if (rid.getSObjectType() == Lead.SObjectType) {
                    t.Lead__c = rid;                                  // existing Lead behaviour preserved
                } else if (rid.getSObjectType() == SalesOrder__c.SObjectType) {
                    t.SalesOrder__c = rid;                            // V1.1: Sales Order lookup
                }
                // any other object: Record_Id__c / Object_Name__c still capture it
            } catch (Exception e) { }
        }
        return t;
    }

    // Builds contacts, fires HTTP, returns request body + response together
    private static XeboResult callXebo(Xebo_Survey_Config__mdt cfg, List<SurveyTrackerRequest> reqs) {

        XeboResult result = new XeboResult();
        List<Map<String, Object>> contacts = new List<Map<String, Object>>();

        for (SurveyTrackerRequest req : reqs) {
            Map<String, Object> contact = new Map<String, Object>();

            if (req.medium == 1 && String.isNotBlank(req.contactMobile)) {
                contact.put('mobile', req.contactMobile);

            } else if (req.medium == 2) {
                if (String.isNotBlank(req.contactEmail))  contact.put('email',  req.contactEmail);
                if (String.isNotBlank(req.contactMobile)) contact.put('mobile', req.contactMobile);

            } else if (req.medium == 3 && String.isNotBlank(req.contactMobile)) {
                contact.put('mobile', req.contactMobile);

            } else if (req.medium == 10 && String.isNotBlank(req.extUniqueId)) {
                contact.put('extUniqueId', req.extUniqueId);
            }

            if (String.isNotBlank(req.langKey)) contact.put('langKey', req.langKey);

            List<Map<String, Object>> extraInfo = new List<Map<String, Object>>();

            if (String.isNotBlank(req.fname))         extraInfo.add(new Map<String,Object>{'key'=>'fName',          'value'=>req.fname});
            // Arvind Kesharwani Jul 19, 2026 : V1.1 - new survey fields
            if (String.isNotBlank(req.lname))         extraInfo.add(new Map<String,Object>{'key'=>'lName',          'value'=>req.lname});
            if (String.isNotBlank(req.residency))     extraInfo.add(new Map<String,Object>{'key'=>'residency',      'value'=>req.residency});
            if (String.isNotBlank(req.nationality))   extraInfo.add(new Map<String,Object>{'key'=>'nationality',    'value'=>req.nationality});
            // End V1.1
            // Arvind Kesharwani Sep 22, 2026 : V1.2 - Lead Owner name
            if (String.isNotBlank(req.agentName))     extraInfo.add(new Map<String,Object>{'key'=>'agentName',      'value'=>req.agentName});
            // End V1.2
            if (String.isNotBlank(req.contactEmail))  extraInfo.add(new Map<String,Object>{'key'=>'Email',          'value'=>req.contactEmail});
            if (String.isNotBlank(req.contactMobile)) extraInfo.add(new Map<String,Object>{'key'=>'mobile',         'value'=>req.contactMobile});
            if (String.isNotBlank(req.serviceName))   extraInfo.add(new Map<String,Object>{'key'=>'Service_name',   'value'=>req.serviceName});
            if (String.isNotBlank(req.serviceType))   extraInfo.add(new Map<String,Object>{'key'=>'service_type',   'value'=>req.serviceType});
            if (String.isNotBlank(req.region))        extraInfo.add(new Map<String,Object>{'key'=>'region',         'value'=>req.region});
            if (String.isNotBlank(req.city))          extraInfo.add(new Map<String,Object>{'key'=>'city',           'value'=>req.city});
            if (String.isNotBlank(req.licenseStatus)) extraInfo.add(new Map<String,Object>{'key'=>'license_status', 'value'=>req.licenseStatus});
            if (String.isNotBlank(req.idNumber))      extraInfo.add(new Map<String,Object>{'key'=>'iD_number',      'value'=>req.idNumber});

            if (String.isNotBlank(req.extraInfoJson)) {
                try {
                    List<Object> parsed = (List<Object>) JSON.deserializeUntyped(req.extraInfoJson);
                    for (Object item : parsed) {
                        extraInfo.add((Map<String, Object>) item);
                    }
                } catch (Exception e) { /* skip malformed JSON */ }
            }

            if (!extraInfo.isEmpty()) contact.put('extraInfo', extraInfo);
            contacts.add(contact);
        }

        if (contacts.isEmpty()) {
            result.success      = false;
            result.responseCode = 400;
            result.responseBody = '{"error":"No valid contact data for medium ' + reqs[0].medium + '"}';
            result.requestBody  = '';
            return result;
        }

        Map<String, Object> payload = new Map<String, Object>{
            'medium'   => reqs[0].medium,
            'contacts' => contacts
        };
        result.requestBody = JSON.serialize(payload);

        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(cfg.Base_URL__c + cfg.Collector_Id__c + '/combined/auto');
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('x-api-key', cfg.API_Key__c);
        httpReq.setBody(result.requestBody);
        httpReq.setTimeout(120000);

        try {
            HttpResponse res    = new Http().send(httpReq);
            result.responseCode = res.getStatusCode();
            result.responseBody = res.getBody();
            result.success      = (result.responseCode >= 200 && result.responseCode < 300);
        } catch (Exception e) {
            result.success      = false;
            result.responseCode = 0;
            result.responseBody = e.getMessage();
        }

        return result;
    }

    private static Map<String, Xebo_Survey_Config__mdt> loadConfigMap() {
        if (mockConfigMap != null) return mockConfigMap;
        Map<String, Xebo_Survey_Config__mdt> resultMap = new Map<String, Xebo_Survey_Config__mdt>();
        for (Xebo_Survey_Config__mdt cfg : Xebo_Survey_Config__mdt.getAll().values()) {
            if (cfg.Is_Active__c) {
                resultMap.put(cfg.Collector_Id__c, cfg);
            }
        }
        return resultMap;
    }

    private static Xebo_Survey_Config__mdt loadConfig(String collectorId) {
        if (mockConfigMap != null) return mockConfigMap.get(collectorId);
        for (Xebo_Survey_Config__mdt cfg : Xebo_Survey_Config__mdt.getAll().values()) {
            if (cfg.Is_Active__c && cfg.Collector_Id__c == collectorId) {
                return cfg;
            }
        }
        return null;
    }

    private static List<Payload> slicePayloads(List<Payload> src, Integer start, Integer size) {
        List<Payload> result = new List<Payload>();
        for (Integer i = start; i < Math.min(start + size, src.size()); i++) result.add(src[i]);
        return result;
    }

    private static String trunc(String s, Integer max) {
        return (s != null && s.length() > max) ? s.substring(0, max) : s;
    }
}