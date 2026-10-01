@IsTest
private class OIC_CustomerRelationshipCalloutTest {

    private class RelationshipMock implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;
        // Default body: a well-formed VO with no RelationshipSfId, i.e. nothing to write back.
        RelationshipMock(Integer statusCode) {
            this.statusCode = statusCode;
            this.responseBody = '{"RelationshipId":"","Status":"","ErrorMessage":"","RelationshipSfId":""}';
        }
        RelationshipMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    private static Account mkAccount(String name, String oraclePartyId) {
        Account a = new Account(Name = name, OraclePartyId__c = oraclePartyId);
        insert a;
        return a;
    }

    // NOC Letter validation runs on insert too (afterInsertMethod calls validateNOCLetterDocument
    // with oldMap = null), so a SOR can't be inserted directly with NOCStatus__c = 'Signed' - it must
    // be inserted first, have its auto-created NOC Letter document marked Uploaded, then be updated.
    private static void signWithNocUploaded(SalesOrderRelationship__c sor) {
        Documents__c nocDoc = [SELECT Id, Status__c FROM Documents__c
                                WHERE Sales_Order_Relationship__c = :sor.Id AND Name = 'NOC Letter' LIMIT 1];
        nocDoc.Status__c = 'Uploaded';
        update nocDoc;
        update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'Signed');
    }

    private static SalesOrderRelationship__c mkSignedSOR() {
        Account customer = mkAccount('Customer-' + Math.mod(Crypto.getRandomInteger(), 100000), 'PARTY-CUST-1');
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000), 'PARTY-TP-1');
        Opportunity o = new Opportunity(
            Name = 'Opp-' + Math.mod(Crypto.getRandomInteger(), 100000),
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Status__c = 'In Progress',
            UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(600),
            EIDNumber__c = '784-1234-1234567-1',
            Nationality__c = 'United Arab Emirates'
        );
        insert o;
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = customer.Id,
            Opportunity__c = o.Id,
            Status__c = 'completed',
            CustAcctId__c = 'CUST-ACCT-1'
        );
        insert so;
        SalesOrderRelationship__c sor = new SalesOrderRelationship__c(
            SalesOrder__c = so.Id,
            ThridPartyCustomer__c = thirdParty.Id
        );
        insert sor;
        signWithNocUploaded(sor);
        return sor;
    }

    // A non-200 response is the only case that produces a 'Callout Error Log'. The response body is
    // still a well-formed VO, so it is deserialized without throwing and only the error log is written.
    @IsTest
    static void testCreateCustomerRelationship_ErrorResponse_LogsCalloutLog() {
        SalesOrderRelationship__c sor = mkSignedSOR();
        String responseBody = '{"RelationshipId":"","Status":"","ErrorMessage":"Internal Server Error",' +
            '"RelationshipSfId":""}';
        Test.setMock(HttpCalloutMock.class, new RelationshipMock(500, responseBody));

        Test.startTest();
        OIC_CustomerRelationshipCallout.createCustomerRelationship(new Set<Id>{ sor.Id });
        Test.stopTest();

        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        Assert.isFalse(logs.isEmpty(), 'Expected a Logger__c record to be created for the failed callout');
    }

    // A 200 whose body carries no RelationshipSfId is a successful callout with nothing to write back:
    // no error log should be raised and the record's sync fields must stay untouched.
    @IsTest
    static void testCreateCustomerRelationship_SuccessResponseWithoutSfId_NoLogAndNoUpdate() {
        SalesOrderRelationship__c sor = mkSignedSOR();
        Test.setMock(HttpCalloutMock.class, new RelationshipMock(200));

        Test.startTest();
        OIC_CustomerRelationshipCallout.createCustomerRelationship(new Set<Id>{ sor.Id });
        Test.stopTest();

        Assert.areEqual(0, [SELECT count() FROM Logger__c], 'A 200 response should not raise a callout error log');
        SalesOrderRelationship__c updated = [SELECT Id, RelationshipSyncStatus__c, RelationshipOracleId__c
                                              FROM SalesOrderRelationship__c WHERE Id = :sor.Id];
        Assert.isNull(updated.RelationshipSyncStatus__c, 'Sync status should stay unset when the response carries no RelationshipSfId');
        Assert.isNull(updated.RelationshipOracleId__c, 'Oracle id should stay unset when the response carries no RelationshipSfId');
    }

    // Covers the catch block: an unparseable body makes JSON.deserialize throw, which must be logged
    // rather than escaping createCustomerRelationship.
    @IsTest
    static void testCreateCustomerRelationship_UnparseableResponse_LogsException() {
        SalesOrderRelationship__c sor = mkSignedSOR();
        Test.setMock(HttpCalloutMock.class, new RelationshipMock(200, 'not-valid-json'));

        Test.startTest();
        OIC_CustomerRelationshipCallout.createCustomerRelationship(new Set<Id>{ sor.Id });
        Test.stopTest();

        Assert.isFalse(
            [SELECT count() FROM Logger__c] == 0,
            'Expected the unparseable callout response to be logged rather than thrown'
        );
    }

    @IsTest
    static void testCreateCustomerRelationship_ResponseWithRelationshipSfId_UpdatesStatus() {
        SalesOrderRelationship__c sor = mkSignedSOR();
        String responseBody = '{"SubjectPartyId":"300000023148108","SubjectSfPartyId":"001VG000016fHdeYAE",' +
            '"ObjectPartyId":"300000023148041","ObjectSfPartyId":"001VG000016f8IeYAI","Type":"Party",' +
            '"SubjectAccountId":"","SubjectSfAccountId":"","ObjectAccountId":"","ObjectSfAccountId":"",' +
            '"RelationshipId":"","Status":"E","ErrorMessage":"Party Not Exist with given ID",' +
            '"RelationshipSfId":"' + sor.Id + '"}';
        Test.setMock(HttpCalloutMock.class, new RelationshipMock(200, responseBody));

        Test.startTest();
        OIC_CustomerRelationshipCallout.createCustomerRelationship(new Set<Id>{ sor.Id });
        Test.stopTest();

        SalesOrderRelationship__c updated = [SELECT Id, RelationshipSyncStatus__c FROM SalesOrderRelationship__c WHERE Id = :sor.Id];
        Assert.areEqual('E', updated.RelationshipSyncStatus__c, 'RelationshipSyncStatus__c should be updated from the OIC response');
    }

    @IsTest
    static void testCreateCustomerRelationship_MissingOraclePartyId_SkipsCallout() {
        Account customer = mkAccount('Customer-' + Math.mod(Crypto.getRandomInteger(), 100000), null);
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000), 'PARTY-TP-2');
        Opportunity o = new Opportunity(
            Name = 'Opp-' + Math.mod(Crypto.getRandomInteger(), 100000),
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Status__c = 'In Progress',
            UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(600),
            EIDNumber__c = '784-1234-1234567-1',
            Nationality__c = 'United Arab Emirates'
        );
        insert o;
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = customer.Id,
            Opportunity__c = o.Id,
            Status__c = 'completed'
        );
        insert so;
        SalesOrderRelationship__c sor = new SalesOrderRelationship__c(
            SalesOrder__c = so.Id,
            ThridPartyCustomer__c = thirdParty.Id
        );
        insert sor;
        signWithNocUploaded(sor);

        Test.setMock(HttpCalloutMock.class, new RelationshipMock(200));

        Test.startTest();
        OIC_CustomerRelationshipCallout.createCustomerRelationship(new Set<Id>{ sor.Id });
        Test.stopTest();

        Assert.areEqual(0, [SELECT count() FROM Logger__c], 'No callout should be attempted when the subject account has no Oracle Party Id');
    }

    @IsTest
    static void testCreateCustomerRelationship_EmptyIdSet_NoOp() {
        Test.startTest();
        OIC_CustomerRelationshipCallout.createCustomerRelationship(new Set<Id>());
        Test.stopTest();

        Assert.areEqual(0, [SELECT count() FROM Logger__c], 'No callout or logging should occur for an empty id set');
    }
}