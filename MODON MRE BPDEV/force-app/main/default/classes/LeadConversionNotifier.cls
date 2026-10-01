/**
 * Called from the ASYNCHRONOUS path of a record-triggered Flow on Lead.
 *
 * The async path is a separate transaction, so the HTTP callout is allowed
 * here and the parsed response is handed straight back to the Flow as
 * output variables.
 * @author      Arvind
* @created     08-25-2026
* ------------------------------------------------------------------------------------
* Version  Author      			Date          Comment
* 1.0      Arvind    			05-09-2026    Initial Draft
* 1.1      Arvind    			22-09-2026    Added MobilePhone to request and response
 */
public with sharing class LeadConversionNotifier {

    private static final String NAMED_CREDENTIAL = 'callout:Loqate_Integration';
    
    private static final String RESOURCE_PATH = '/XXMODON_AWS_CONVLEAD_INT/1.0/leadConvNotify';

    private static final Integer TIMEOUT_MS = 60000;

    // ---------- Flow input ----------
    public class Request {
        @InvocableVariable(label='Lead Id' required=true)
        public Id leadId;
    }

    // ---------- Flow output ----------
    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success = false;

        @InvocableVariable(label='HTTP Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Lead Id')
        public String leadId;

        @InvocableVariable(label='Mobile Phone')
        public String mobilePhone;

        @InvocableVariable(label='Account Id')
        public String accountId;

        @InvocableVariable(label='Primary Contact Id')
        public String primaryContactId;

        @InvocableVariable(label='Opportunity Id')
        public String opportunityId;

        @InvocableVariable(label='Raw Response Body')
        public String rawResponse;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Notify External System of Lead Conversion'
        description='Posts converted Lead details to the external REST API and returns the IDs from the response. Use on an asynchronous Flow path.'
        category='Lead'
        callout=true
    )
    public static List<Result> notify(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> ids = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.leadId != null) {
                ids.add(r.leadId);
            }
        }

        Map<Id, Lead> leadsById = new Map<Id, Lead>([
            SELECT Id, Name, Company, Email, MobilePhone, Status, IsConverted, ConvertedDate,
                   ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId,
                   ConvertedOpportunity.StageName
            FROM Lead
            WHERE Id IN :ids AND IsConverted = true
        ]);

        for (Request r : requests) {
            results.add(process(r == null ? null : r.leadId, leadsById));
        }
        return results;
    }

    private static Result process(Id leadId, Map<Id, Lead> leadsById) {
        Result out = new Result();
        out.leadId = leadId;

        Lead ld = leadId == null ? null : leadsById.get(leadId);
        if (ld == null) {
            out.errorMessage = 'Lead not found or not converted: ' + leadId;
            return out;
        }

        // Always return the Lead's mobile, even if the callout is skipped or fails.
        out.mobilePhone = ld.MobilePhone;

        if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
            out.errorMessage = 'Callout limit reached in this transaction.';
            return out;
        }

        // This org always creates an Opportunity on convert. If one is missing,
        // something converted the Lead outside the normal path — fail loudly
        // rather than POSTing a null opportunityId the API can't use.
        if (ld.ConvertedOpportunityId == null) {
            out.accountId        = ld.ConvertedAccountId;
            out.primaryContactId = ld.ConvertedContactId;
            out.errorMessage =
                'Lead ' + ld.Id + ' converted without an Opportunity. ' +
                'Notification not sent.';
            return out;
        }
        
        System.debug('Print Request '+ buildBody(ld));

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + (String.isBlank(RESOURCE_PATH) ? '' : RESOURCE_PATH));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=UTF-8');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT_MS);
        req.setBody(buildBody(ld));

        try {
            HttpResponse res = new Http().send(req);
            out.statusCode  = res.getStatusCode();
            out.rawResponse = res.getBody();
            out.success     = out.statusCode >= 200 && out.statusCode < 300;

            if (out.success) {
                applyResponse(out, res.getBody(), ld);
            } else {
                out.errorMessage = 'HTTP ' + out.statusCode + ' ' + res.getStatus();
            }
        } catch (Exception e) {
            out.errorMessage = e.getTypeName() + ': ' + e.getMessage();
        }
        return out;
    }

    private static String buildBody(Lead ld) {
        Map<String, Object> body = new Map<String, Object>{
            //'event'             => 'lead.converted',
            //'isConverted'       => ld.IsConverted,
            //'convertedDate'     => ld.ConvertedDate,
            'leadId'            => ld.Id,
            //'leadStatus'        => ld.Status,
            //'company'           => ld.Company,
            'MobilePhone'       => ld.MobilePhone,
            'accountId'         => ld.ConvertedAccountId,
            'contactId'  		=> ld.ConvertedContactId,
            'opportunityId'     => ld.ConvertedOpportunityId
            //'opportunityStatus' => ld.ConvertedOpportunity.StageName
        };
        return JSON.serialize(body, true);
    }

    /**
     * Reads the values back out of the response. Falls back to the Salesforce
     * values when the API echoes nothing, so the Flow always has usable data.
     */
    private static void applyResponse(Result out, String body, Lead ld) {
        Map<String, Object> parsed;
        if (String.isNotBlank(body)) {
            try {
                Object o = JSON.deserializeUntyped(body);
                if (o instanceof Map<String, Object>) {
                    parsed = (Map<String, Object>) o;
                }
            } catch (Exception ignored) {
                // Non-JSON body; fall through to the Salesforce values.
            }
        }

        out.leadId           = pick(parsed, 'leadId',           ld.Id);
        out.mobilePhone      = pick(parsed, 'MobilePhone',      ld.MobilePhone);
        out.accountId        = pick(parsed, 'accountId',        ld.ConvertedAccountId);
        out.primaryContactId = pick(parsed, 'primaryContactId', ld.ConvertedContactId);
        out.opportunityId    = pick(parsed, 'opportunityId',    ld.ConvertedOpportunityId);
    }

    /** Tolerates camelCase and snake_case keys, plus a nested "data" object. */
    private static String pick(Map<String, Object> parsed, String key, Object fallback) {
        if (parsed != null) {
            String snake = key.replaceAll('([a-z])([A-Z])', '$1_$2').toLowerCase();
            for (String k : new List<String>{ key, snake }) {
                if (parsed.containsKey(k) && parsed.get(k) != null) {
                    return String.valueOf(parsed.get(k));
                }
            }
            if (parsed.get('data') instanceof Map<String, Object>) {
                return pick((Map<String, Object>) parsed.get('data'), key, fallback);
            }
        }
        return fallback == null ? null : String.valueOf(fallback);
    }
}