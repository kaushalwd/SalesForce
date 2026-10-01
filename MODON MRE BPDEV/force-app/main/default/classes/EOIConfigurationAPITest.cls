@isTest
public class EOIConfigurationAPITest {

    @TestSetup
    static void setup() {

        // Project and Phase test records
        Project__c testProject = new Project__c(Name = 'Test Project DPG');
        insert testProject;

        Phase__c testPhase = new Phase__c(
            Name       = 'Test Phase DPG',
            Project__c = testProject.Id
        );
        insert testPhase;

        String showOnVal = getActivePicklistValue(EOI_Range__c.Show_On__c, 'DPG');
        String typologyVal = getActivePicklistValue(EOI_Range__c.UnitTypologyMRE__c, 'Range Villas');

        // EOI Range — Show_On__c must include 'DPG' to be returned by GET endpoint
        EOI_Range__c range = new EOI_Range__c(
            Project__c        = testProject.Id,
            Phase__c          = testPhase.Id,
            Unit_Type__c      = 'Villa',
            No_of_Bedrooms__c = '5 Bedrooms',
            Amount__c         = 150000
        );
        if (typologyVal != null) {
            range.UnitTypologyMRE__c = typologyVal;
        }
        if (showOnVal != null) {
            range.Show_On__c = showOnVal;
        }
        insert range;

        Account testAcc = new Account(Name = 'Test EOI Account');
        insert testAcc;

        Opportunity testOpp = new Opportunity(
            Name = 'Test EOI Opp',
            AccountId = testAcc.Id,
            StageName = 'New',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;
    }

    private static String getActivePicklistValue(Schema.SObjectField field, String preferred) {
        Schema.DescribeFieldResult dfr = field.getDescribe();
        String fallback = null;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                if (fallback == null) fallback = pe.getValue();
                if (pe.getValue().equalsIgnoreCase(preferred)) return pe.getValue();
            }
        }
        return fallback;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private static void setupContext(String method, String body) {
        RestRequest req     = new RestRequest();
        req.requestURI      = '/services/apexrest/eoi/';
        req.httpMethod      = method;
        if (body != null) req.requestBody = Blob.valueOf(body);
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    /** Parse OIC_RestResponse JSON written to RestContext (API methods are void). */
    private static Map<String, Object> parseResponse() {
        System.assertNotEquals(null, RestContext.response, 'RestContext.response expected');
        System.assertNotEquals(null, RestContext.response.responseBody, 'Response body expected');
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    private static Map<String, Object> parseData(Map<String, Object> res) {
        Object data = res.get('data');
        System.assertNotEquals(null, data, 'Expected data payload. Response=' + JSON.serialize(res));
        return (Map<String, Object>) data;
    }

    private static Map<String, Object> buildIndividualCustomer() {
        return new Map<String, Object>{
            'FirstName'           => 'Arvind',
            'LastName'            => 'Kesharwani',
            'Email'               => 'sarvind.kesharwani@modon.com',
            'Phone'               => '+971501234567',
            'ProjectInterest'     => 'Nawayef East',
            'LeadSource'          => 'Digital',
            'ResidentStatus'      => 'Resident',
            'Nationality'         => 'United Arab Emirates',
            'CustomerType'        => 'New Customer',
            'PassportNumber'      => 'N1234567',
            'PassportExpiryDate'  => '2034-05-15',
            'EmiratesId'          => '784-1990-1234567-1',
            'EmiratesIdExpiryDate'=> '2029-12-31'
        };
    }

    private static Map<String, Object> buildEoiPayload(Id projectId, Id phaseId, Id rangeId) {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        return buildEoiPayload(opp.Id, opp.AccountId, projectId, phaseId, rangeId);
    }

    private static Map<String, Object> buildEoiPayload(Id oppId, Id accId, Id projectId, Id phaseId, Id rangeId) {
        String typology = getActivePicklistValue(Expressionofinterest__c.UnitTypologyMRE__c, 'Range Villas');
        String paymentType = getActivePicklistValue(Expressionofinterest__c.Payment_Type__c, 'Bank Transfer');
        String bedrooms = getActivePicklistValue(Expressionofinterest__c.NumberofBedrooms__c, '3');
        Map<String, Object> payload = new Map<String, Object>{
            'OpportunityId' => oppId,
            'AccountId'     => accId,
            'PhaseId'       => phaseId,
            'ProjectId'     => projectId,
            'UnitType'      => 'Villa',
            'Bedrooms'      => bedrooms != null ? bedrooms : '3',
            'NumberOfUnits' => 1,
            'EOIAmount'     => 150000,
            'EoiRangeId'    => rangeId,
            'Remarks'       => 'Test remarks',
            'PaymentType'   => paymentType != null ? paymentType : 'Bank Transfer'
        };
        if (typology != null) {
            payload.put('UnitTypology', typology);
        }
        return payload;
    }

    // ====================================================================================
    // GET — EOI Configuration
    // ====================================================================================
    @isTest
    static void testGet_returnsOnlyDPGRecords() {
        setupContext('GET', null);

        Test.startTest();
        EOIConfigurationAPI.getEOIConfiguration();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'));
        System.assertNotEquals(null, res.get('requestId'));
        List<Object> data = (List<Object>) res.get('data');
        if (getActivePicklistValue(EOI_Range__c.Show_On__c, 'DPG') == 'DPG') {
            System.assert(!data.isEmpty(), 'Expected at least one EOI Range with Show_On__c = DPG');
            Map<String, Object> first = (Map<String, Object>) data[0];
            System.assertEquals('Villa', first.get('UnitType'));
            System.assertEquals(150000, first.get('EOIAmount'));
        }
    }

    @isTest
    static void testGet_withProjectFilter() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c phase = [SELECT Id FROM Phase__c LIMIT 1];
        RestRequest req = new RestRequest();
        req.requestURI  = '/services/apexrest/eoi/';
        req.httpMethod  = 'GET';
        req.params.put('projectId', proj.Id);
        req.params.put('phaseId', phase.Id);
        RestContext.request  = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        EOIConfigurationAPI.getEOIConfiguration();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'));
        List<Object> data = (List<Object>) res.get('data');
        if (getActivePicklistValue(EOI_Range__c.Show_On__c, 'DPG') == 'DPG') {
            System.assert(!data.isEmpty());
            Map<String, Object> first = (Map<String, Object>) data[0];
            System.assertEquals(String.valueOf(proj.Id), String.valueOf(first.get('ProjectId')));
            System.assertEquals(String.valueOf(phase.Id), String.valueOf(first.get('PhaseId')));
        }
    }

    // ====================================================================================
    // POST — Validation failure
    // ====================================================================================
    @isTest
    static void testPost_missingFields_returnsError() {
        setupContext('POST', '{"Customer":{},"Eoi":{}}');

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertNotEquals('Success', res.get('Status'), 'Missing fields should not succeed');
    }

    // ====================================================================================
    // POST — Success with Opportunity and Account (nested payload)
    // ====================================================================================
    @isTest
    static void testPost_success_nestedPayload() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'AccountId'     => opp.AccountId,
            'Eoi'           => buildEoiPayload(opp.Id, opp.AccountId, proj.Id, phase.Id, range.Id)
        };
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'), 'Error: ' + JSON.serialize(res));
        Map<String, Object> data = parseData(res);
        System.assertEquals(opp.Id, data.get('OpportunityId'));
        System.assertEquals(opp.AccountId, data.get('AccountId'));
        System.assertNotEquals(null, data.get('EoiId'));
        System.assertNotEquals(null, data.get('EoiReference'));

        Id eoiId = (Id) data.get('EoiId');
        Expressionofinterest__c createdEoi = [
            SELECT Id, Account__c, Opportunity__c, UnitType__c,
                   EOI_Amount_AED__c, Payment_Type__c, UnitTypologyMRE__c
            FROM   Expressionofinterest__c
            WHERE  Id = :eoiId
        ];
        System.assertEquals(opp.AccountId, createdEoi.Account__c);
        System.assertEquals(opp.Id, createdEoi.Opportunity__c);
        System.assertEquals('Villa', createdEoi.UnitType__c);
        System.assertEquals(150000, createdEoi.EOI_Amount_AED__c);
    }

    // ====================================================================================
    // POST — Success with flat payload
    // ====================================================================================
    @isTest
    static void testPost_success_flatPayload() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Map<String, Object> payload = buildEoiPayload(opp.Id, opp.AccountId, proj.Id, phase.Id, range.Id);
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'), 'Error: ' + JSON.serialize(res));
        Map<String, Object> data = parseData(res);
        System.assertEquals(opp.Id, data.get('OpportunityId'));
        System.assertEquals(opp.AccountId, data.get('AccountId'));
    }

    // ====================================================================================
    // POST — Success without AccountId (auto-resolves from Opportunity)
    // ====================================================================================
    @isTest
    static void testPost_success_resolvesAccountFromOpp() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Map<String, Object> payload = buildEoiPayload(opp.Id, null, proj.Id, phase.Id, range.Id);
        payload.remove('AccountId');
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'), 'Error: ' + JSON.serialize(res));
        Map<String, Object> data = parseData(res);
        System.assertEquals(opp.AccountId, data.get('AccountId'), 'Should resolve AccountId from Opportunity');
    }

    // ====================================================================================
    // POST — Invalid Opportunity Id -> returns 404 / EOI-008
    // ====================================================================================
    @isTest
    static void testPost_invalidOpportunityId_returnsError() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Account      acc   = [SELECT Id FROM Account LIMIT 1];

        Id fakeOppId = '006000000000001AAA';
        Map<String, Object> payload = buildEoiPayload(fakeOppId, acc.Id, proj.Id, phase.Id, range.Id);
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Failure', res.get('Status'));
        System.assertEquals('EOI-008', res.get('ErrorCode'));
    }

    // ====================================================================================
    // POST — Invalid Account Id -> returns 404 / EOI-009
    // ====================================================================================
    @isTest
    static void testPost_invalidAccountId_returnsError() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id FROM Opportunity LIMIT 1];

        Id fakeAccId = '001000000000001AAA';
        Map<String, Object> payload = buildEoiPayload(opp.Id, fakeAccId, proj.Id, phase.Id, range.Id);
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Failure', res.get('Status'));
        System.assertEquals('EOI-009', res.get('ErrorCode'));
    }

    // ====================================================================================
    // POST — Broker User attribution test
    // ====================================================================================
    @isTest
    static void testPost_brokerUser_attachesBrokerInfo() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Account brokerAgency = new Account(Name = 'Test Broker Agency');
        insert brokerAgency;
        Contact brokerContact = new Contact(
            LastName = 'Agent',
            AccountId = brokerAgency.Id,
            Phone = '+971501112233'
        );
        insert brokerContact;

        EOIConfigurationAPI.mockBrokerContact = brokerContact;

        Map<String, Object> payload = buildEoiPayload(opp.Id, opp.AccountId, proj.Id, phase.Id, range.Id);
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'));
        Id eoiId = (Id) parseData(res).get('EoiId');
        Expressionofinterest__c createdEoi = [
            SELECT BrokerAgency__c, BrokerAgent__c FROM Expressionofinterest__c WHERE Id = :eoiId
        ];
        System.assertEquals(brokerAgency.Id, createdEoi.BrokerAgency__c);
        System.assertEquals(brokerContact.Id, createdEoi.BrokerAgent__c);
    }

    @isTest
    static void testPost_emptyBody() {
        setupContext('POST', '');
        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testPost_malformedJson() {
        setupContext('POST', '{ bad json');
        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testPost_paymentTypesAndAliases() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Map<String, Object> eoiData = buildEoiPayload(opp.Id, opp.AccountId, proj.Id, phase.Id, range.Id);
        eoiData.remove('EOIAmount');
        eoiData.put('Amount', 150000);
        String chequeVal = getActivePicklistValue(Expressionofinterest__c.Payment_Type__c, 'Cheque');
        if (chequeVal != null) {
            eoiData.put('PaymentType', chequeVal);
        }

        Map<String, Object> payload = new Map<String, Object>{
            'Eoi' => eoiData
        };
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'));
    }

    @isTest
    static void testPost_success_requestContextPayload() {
        Project__c   proj  = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c     phase = [SELECT Id FROM Phase__c   LIMIT 1];
        EOI_Range__c range = [SELECT Id FROM EOI_Range__c LIMIT 1];
        Opportunity  opp   = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        String bedroomsVal = getActivePicklistValue(Expressionofinterest__c.NumberofBedrooms__c, '3');
        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType'  => 'Individual',
                'OpportunityId' => opp.Id,
                'AccountId'     => opp.AccountId,
                'CustomerEmail' => 'john.doe@example.com'
            },
            'Eoi' => new Map<String, Object>{
                'ProjectId'     => proj.Id,
                'PhaseId'       => phase.Id,
                'EoiRangeId'    => range.Id,
                'UnitType'      => 'Villa',
                'Bedrooms'      => bedroomsVal != null ? bedroomsVal : '3',
                'NumberOfUnits' => 1,
                'EoiAmount'     => 150000,
                'PaymentType'   => 'Card',
                'Remarks'       => 'DPG E2E run'
            }
        };
        setupContext('POST', JSON.serialize(payload));

        Test.startTest();
        EOIConfigurationAPI.createEOI();
        Test.stopTest();

        Map<String, Object> res = parseResponse();
        System.assertEquals('Success', res.get('Status'), 'Error: ' + JSON.serialize(res));
        Map<String, Object> data = parseData(res);
        System.assertEquals(opp.Id, data.get('OpportunityId'));
        System.assertEquals(opp.AccountId, data.get('AccountId'));
        System.assertNotEquals(null, data.get('EoiId'));
    }
}