@IsTest
private class LeadConversionNotifierTest {

    private static final String ENDPOINT_PREFIX = 'callout:Loqate_Integration';

    /**
     * Inserting and converting a Lead in this org fires the lead-scoring
     * integration too, and a single mock has to answer every callout in the
     * transaction. Anything that isn't the endpoint under test gets a bland
     * 200 so those async jobs don't blow up the test.
     */
    private static HttpResponse ignoreOtherIntegrations() {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setStatus('OK');
        res.setBody('{}');
        return res;
    }

    private class Mock implements HttpCalloutMock {
        private Integer code;
        private String body;
        Mock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            if (!req.getEndpoint().startsWith(ENDPOINT_PREFIX)) {
                return ignoreOtherIntegrations();
            }
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('application/json; charset=UTF-8',
                req.getHeader('Content-Type'));
            System.assertEquals('application/json', req.getHeader('Accept'));

            Map<String, Object> sent =
                (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertNotEquals(null, sent.get('leadId'));
            System.assertNotEquals(null, sent.get('accountId'));
            System.assertNotEquals(null, sent.get('contactId'));
            System.assertNotEquals(null, sent.get('opportunityId'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setStatus(code == 200 ? 'OK' : 'Error');
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            return res;
        }
    }

    /** Simulates the endpoint being unreachable / the request timing out. */
    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            if (!req.getEndpoint().startsWith(ENDPOINT_PREFIX)) {
                return ignoreOtherIntegrations();
            }
            throw new CalloutException('Read timed out');
        }
    }

    /**
     * The org requires ProjectInterest__c on Lead. Read the first active value
     * from the describe rather than hard-coding one, so the test keeps working
     * when the picklist is re-configured.
     */
    private static String activeProjectInterest() {
        for (Schema.PicklistEntry e :
             Lead.ProjectInterest__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                return e.getValue();
            }
        }
        return null;
    }

    private static final List<String> FIRST_NAMES =
        new List<String>{ 'Asha', 'Bilal', 'Carmen', 'Dhruv', 'Elena', 'Farid' };
    private static final List<String> LAST_NAMES =
        new List<String>{ 'Menon', 'Okonkwo', 'Vasquez', 'Lindqvist', 'Haddad', 'Zheng' };
    private static final List<String> COMPANIES =
        new List<String>{ 'Northwind Traders', 'Contoso Freight', 'Fabrikam Metals',
                          'Tailspin Studios', 'Woodgrove Bank', 'Litware Labs' };

    private static Integer counter = 0;

    /**
     * Each Lead gets a wholly different person and company name, not just a
     * numeric suffix. The org's duplicate rules match fuzzily, so "Menon1" and
     * "Menon2" at similar companies still collide on the Contact/Account that
     * the first conversion created.
     */
    private static Lead newLead() {
        Integer i = Math.mod(counter, FIRST_NAMES.size());
        counter++;
        return new Lead(
            FirstName          = FIRST_NAMES[i],
            LastName           = LAST_NAMES[i],
            Company            = COMPANIES[i],
            Email              = FIRST_NAMES[i].toLowerCase() + '.' +
                                 LAST_NAMES[i].toLowerCase() + counter + '@example.invalid',
            ProjectInterest__c = activeProjectInterest()
        );
    }

    private static Id convertOneLead() {
        Lead ld = newLead();
        insert ld;

        // In this org the converted status is labelled "Converted" but its API
        // name is "Qualified"; setConvertedStatus() wants the API name.
        LeadStatus convertedStatus =
            [SELECT ApiName FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus(convertedStatus.ApiName);
        lc.setDoNotCreateOpportunity(false);
        lc.setOpportunityName(ld.Company + ' - New Business');

        Database.LeadConvertResult r = Database.convertLead(lc);
        System.assert(r.isSuccess(), 'Lead conversion failed');
        return ld.Id;
    }

    private static List<LeadConversionNotifier.Request> reqFor(Id leadId) {
        LeadConversionNotifier.Request req = new LeadConversionNotifier.Request();
        req.leadId = leadId;
        return new List<LeadConversionNotifier.Request>{ req };
    }

    @IsTest
    static void returnsIdsFromApiResponse() {
        Id leadId = convertOneLead();
        Lead ld = [SELECT ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId
                   FROM Lead WHERE Id = :leadId];

        String body = JSON.serialize(new Map<String, Object>{
            'leadId'           => leadId,
            'accountId'        => ld.ConvertedAccountId,
            'primaryContactId' => ld.ConvertedContactId,
            'opportunityId'    => ld.ConvertedOpportunityId
        });

        Test.setMock(HttpCalloutMock.class, new Mock(200, body));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals(1, results.size());
        LeadConversionNotifier.Result out = results[0];
        System.assertEquals(true, out.success);
        System.assertEquals(200, out.statusCode);
        System.assertEquals(body, out.rawResponse);
        System.assertEquals(String.valueOf(leadId), out.leadId);
        System.assertEquals(String.valueOf(ld.ConvertedAccountId), out.accountId);
        System.assertEquals(String.valueOf(ld.ConvertedContactId), out.primaryContactId);
        System.assertEquals(String.valueOf(ld.ConvertedOpportunityId), out.opportunityId);
        System.assertEquals(null, out.errorMessage);
    }

    @IsTest
    static void fallsBackToSalesforceIdsWhenResponseIsEmpty() {
        Id leadId = convertOneLead();
        Lead ld = [SELECT ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId
                   FROM Lead WHERE Id = :leadId];

        Test.setMock(HttpCalloutMock.class, new Mock(200, '{}'));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(String.valueOf(leadId), results[0].leadId);
        System.assertEquals(String.valueOf(ld.ConvertedAccountId), results[0].accountId);
        System.assertEquals(String.valueOf(ld.ConvertedContactId), results[0].primaryContactId);
        System.assertEquals(String.valueOf(ld.ConvertedOpportunityId), results[0].opportunityId);
    }

    @IsTest
    static void readsSnakeCaseAndNestedDataKeys() {
        Id leadId = convertOneLead();

        Test.setMock(HttpCalloutMock.class, new Mock(200,
            '{"data":{"lead_id":"L-1","account_id":"A-1",' +
            '"primary_contact_id":"C-1","opportunity_id":"O-1"}}'));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals('L-1', results[0].leadId);
        System.assertEquals('A-1', results[0].accountId);
        System.assertEquals('C-1', results[0].primaryContactId);
        System.assertEquals('O-1', results[0].opportunityId);
    }

    /** A JSON array is valid JSON but not a Map, so the parsed map stays null. */
    @IsTest
    static void toleratesNonObjectJsonResponse() {
        Id leadId = convertOneLead();
        Lead ld = [SELECT ConvertedAccountId FROM Lead WHERE Id = :leadId];

        Test.setMock(HttpCalloutMock.class, new Mock(200, '["unexpected"]'));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(String.valueOf(ld.ConvertedAccountId), results[0].accountId);
    }

    @IsTest
    static void reportsHttpErrorWithoutThrowing() {
        Id leadId = convertOneLead();

        Test.setMock(HttpCalloutMock.class, new Mock(500, '{"error":"boom"}'));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(500, results[0].statusCode);
        System.assert(results[0].errorMessage.contains('500'),
            'Expected status code in message: ' + results[0].errorMessage);
    }

    @IsTest
    static void reportsCalloutExceptionWithoutThrowing() {
        Id leadId = convertOneLead();

        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(null, results[0].statusCode);
        System.assertNotEquals(null, results[0].errorMessage);
        System.assert(results[0].errorMessage.contains('CalloutException'),
            'Expected the exception type name: ' + results[0].errorMessage);
    }

    @IsTest
    static void reportsUnconvertedLead() {
        Lead ld = newLead();
        insert ld;

        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(ld.Id));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('not converted'),
            'Unexpected message: ' + results[0].errorMessage);
    }

    @IsTest
    static void failsLoudlyWhenNoOpportunityWasCreated() {
        Lead ld = newLead();
        insert ld;

        LeadStatus convertedStatus =
            [SELECT ApiName FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus(convertedStatus.ApiName);
        lc.setDoNotCreateOpportunity(true);
        System.assert(Database.convertLead(lc).isSuccess());

        Test.setMock(HttpCalloutMock.class, new Mock(200, '{}'));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(ld.Id));
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(null, results[0].opportunityId);
        System.assertNotEquals(null, results[0].accountId,
            'Account Id should still be returned for troubleshooting');
        System.assertNotEquals(null, results[0].primaryContactId);
        System.assert(results[0].errorMessage.contains('without an Opportunity'),
            'Unexpected message: ' + results[0].errorMessage);
    }

    @IsTest
    static void toleratesNonJsonResponseBody() {
        Id leadId = convertOneLead();
        Lead ld = [SELECT ConvertedAccountId, ConvertedOpportunityId
                   FROM Lead WHERE Id = :leadId];

        // webhook.site replies with plain text unless you configure otherwise.
        Test.setMock(HttpCalloutMock.class, new Mock(200, 'This URL has no default content configured.'));
        Test.startTest();
        List<LeadConversionNotifier.Result> results =
            LeadConversionNotifier.notify(reqFor(leadId));
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(String.valueOf(ld.ConvertedAccountId), results[0].accountId);
        System.assertEquals(String.valueOf(ld.ConvertedOpportunityId), results[0].opportunityId);
    }

    @IsTest
    static void handlesEmptyInput() {
        Test.startTest();
        System.assertEquals(0, LeadConversionNotifier.notify(
            new List<LeadConversionNotifier.Request>()).size());
        System.assertEquals(0, LeadConversionNotifier.notify(null).size());
        Test.stopTest();
    }

    /** A null entry or a null leadId still has to produce a Result for the Flow. */
    @IsTest
    static void handlesNullRequestEntries() {
        LeadConversionNotifier.Request blank = new LeadConversionNotifier.Request();

        Test.startTest();
        List<LeadConversionNotifier.Result> results = LeadConversionNotifier.notify(
            new List<LeadConversionNotifier.Request>{ null, blank });
        Test.stopTest();

        System.assertEquals(2, results.size());
        for (LeadConversionNotifier.Result out : results) {
            System.assertEquals(false, out.success);
            System.assertEquals(null, out.leadId);
            System.assert(out.errorMessage.contains('Lead not found'),
                'Unexpected message: ' + out.errorMessage);
        }
    }

    /** Two Leads in one invocation each get their own callout and Result. */
    @IsTest
    static void processesMultipleRequestsInOneInvocation() {
        Id first  = convertOneLead();
        Id second = convertOneLead();

        Test.setMock(HttpCalloutMock.class, new Mock(200, '{}'));

        LeadConversionNotifier.Request a = new LeadConversionNotifier.Request();
        a.leadId = first;
        LeadConversionNotifier.Request b = new LeadConversionNotifier.Request();
        b.leadId = second;

        Test.startTest();
        List<LeadConversionNotifier.Result> results = LeadConversionNotifier.notify(
            new List<LeadConversionNotifier.Request>{ a, b });
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals(true, results[1].success);
        System.assertEquals(String.valueOf(first),  results[0].leadId);
        System.assertEquals(String.valueOf(second), results[1].leadId);
    }
}