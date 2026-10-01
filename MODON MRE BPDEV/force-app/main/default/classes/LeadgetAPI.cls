/**
 * LeadgetAPI
 * -----------------------------------------------------------------------------
 * GET /services/apexrest/leads/v1
 *
 * Headers sent by OIC:
 *   MobilePhone   : +971501234567
 *   Authorization : Bearer <access_token>
 */
@RestResource(urlMapping='/leads/v1/*')
global with sharing class LeadgetAPI {

    /* ============================ WRAPPERS ============================ */

    global class ServiceResponse {
        global String  status;
        global String  message;
        global Integer recordCount = 0;
        global List<LeadDTO> leads = new List<LeadDTO>();
    }

    global class LeadDTO {
        global String   leadId;
        global String   leadNumber;
        global String   projectName;
        global String   status;
        global Boolean  hasBeenContacted;
        global Datetime lastContactedOn;
        global AgentDTO assignedAgent;
        global String   language;
        global Datetime createdOn;
        global Boolean  isBrokerLead;
        global Boolean  isDuplicateLead;
        global String   leadSource;
        global String   leadSubSource;
    }

    global class AgentDTO {
        global String agentId;
        global String agentName;
    }

    /* ============================ ENTRY POINT ============================ */

    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        ServiceResponse out = new ServiceResponse();

        try {
            String mobile = getMobileHeader();

            if (String.isBlank(mobile)) {
                send(res, 400, out, 'ERROR', 'Mandatory header "MobilePhone" is missing.');
                return;
            }

            String digits = normalisePhone(mobile);
            if (digits == null || digits.length() < 9) {
                send(res, 400, out, 'ERROR',
                     'Header "MobilePhone" must contain at least 9 digits.');
                return;
            }

            String pattern = '%' + digits;

            List<Lead> leads = [
                SELECT Id, Status, LeadSource, CreatedDate, LastActivityDate,
                       OwnerId, Owner.Name, OwnerName__c,
                       LeadNumber__c, ProjectInterest__c, LanguagePreference__c,
                       Last_Activity__c, Call_Task_Status__c,
                       Is_Duplicate__c, SubSource__c
                FROM Lead
                WHERE MobilePhone LIKE :pattern
                   OR Phone LIKE :pattern
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            if (leads.isEmpty()) {
                send(res, 404, out, 'SUCCESS', 'No lead found for the supplied MobilePhone.');
                return;
            }

            for (Lead l : leads) {
                out.leads.add(buildDTO(l));
            }
            out.status      = 'SUCCESS';
            out.message     = 'Lead(s) retrieved successfully.';
            out.recordCount = out.leads.size();

            res.statusCode   = 200;
            res.responseBody = Blob.valueOf(JSON.serializePretty(out, true));

        } catch (Exception e) {
            send(res, 500, out, 'ERROR',
                 'Unexpected error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
        }
    }

    /* ============================ MAPPING ============================ */

    private static LeadDTO buildDTO(Lead l) {
        LeadDTO d = new LeadDTO();

        d.leadId      = l.Id;
        d.leadNumber  = l.LeadNumber__c;
        d.projectName = l.ProjectInterest__c;
        d.status      = l.Status;
        d.language    = l.LanguagePreference__c;
        d.createdOn   = l.CreatedDate;

        // Contact history
        Datetime lastContact = toDatetime(l.Last_Activity__c);
        if (lastContact == null && l.LastActivityDate != null) {
            lastContact = Datetime.newInstance(l.LastActivityDate, Time.newInstance(0,0,0,0));
        }
        String callStatus = toText(l.Call_Task_Status__c);
        d.lastContactedOn  = lastContact;
        d.hasBeenContacted = lastContact != null
                             || (String.isNotBlank(callStatus)
                                 && !'Not Contacted'.equalsIgnoreCase(callStatus));

        // Assigned agent
        if (l.OwnerId != null) {
            AgentDTO a = new AgentDTO();
            a.agentId   = l.OwnerId;
            a.agentName = String.isNotBlank(l.OwnerName__c)
                          ? l.OwnerName__c
                          : (l.Owner != null ? l.Owner.Name : null);
            d.assignedAgent = a;
        }

        // Flags
        d.isBrokerLead    = 'Broker Portal'.equalsIgnoreCase(l.LeadSource);
        d.isDuplicateLead = toBoolean(l.Is_Duplicate__c);

        // Source
        d.leadSource    = l.LeadSource;
        d.leadSubSource = toText(l.SubSource__c);

        return d;
    }

    /* ============================ HELPERS ============================ */

    /** Reads the MobilePhone header sent by OIC, tolerating casing differences. */
    private static String getMobileHeader() {
        RestRequest req = RestContext.request;
        if (req == null || req.params == null) { return null; }

        String v = req.params.get('MobilePhone');
        if (String.isNotBlank(v)) { return v.trim(); }

        for (String k : req.params.keySet()) {
            if (k != null && k.equalsIgnoreCase('MobilePhone')) {
                String h = req.params.get(k);
                if (String.isNotBlank(h)) { return h.trim(); }
            }
        }
        return null;
    }

    /** Keeps the last 9 digits so any format of the same number matches. */
    @TestVisible
    private static String normalisePhone(String raw) {
        if (String.isBlank(raw)) { return null; }
        String digits = raw.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) { return null; }
        return digits.length() > 9
               ? digits.substring(digits.length() - 9)
               : digits;
    }

    private static String toText(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    private static Boolean toBoolean(Object o) {
        if (o instanceof Boolean) { return (Boolean) o; }
        return o != null && 'true'.equalsIgnoreCase(String.valueOf(o));
    }

    private static Datetime toDatetime(Object o) {
        if (o instanceof Datetime) { return (Datetime) o; }
        if (o instanceof Date) {
            return Datetime.newInstance((Date) o, Time.newInstance(0,0,0,0));
        }
        return null;
    }

    private static void send(RestResponse res, Integer code, ServiceResponse out,
                             String status, String message) {
        out.status  = status;
        out.message = message;
        res.statusCode   = code;
        res.responseBody = Blob.valueOf(JSON.serializePretty(out, true));
    }
}