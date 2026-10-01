@IsTest
private class SORelationshipCallout_QueableTest {

    private static Account mkAccount(String name, String oraclePartyId) {
        Account a = new Account(Name = name, OraclePartyId__c = oraclePartyId);
        insert a;
        return a;
    }

    private static Opportunity mkOpportunity(String name) {
        Opportunity o = new Opportunity(
            Name = name,
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Status__c = 'In Progress',
            UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(600),
            EIDNumber__c = '784-1234-1234567-1',
            Nationality__c = 'United Arab Emirates'
        );
        insert o;
        return o;
    }

    private static Documents__c getNOCLetterDoc(Id sorId) {
        return [SELECT Id, Name, Status__c, Sales_Order_Relationship__c
                FROM Documents__c
                WHERE Sales_Order_Relationship__c = :sorId AND Name = 'NOC Letter'
                LIMIT 1];
    }

    // NOC Letter validation runs on insert too (afterInsertMethod calls validateNOCLetterDocument
    // with oldMap = null), so a SOR can't be inserted directly with NOCStatus__c = 'Signed' - it must
    // be inserted first, have its auto-created NOC Letter document marked Uploaded, then be updated.
    private static void signWithNocUploaded(SalesOrderRelationship__c sor) {
        Documents__c nocDoc = getNOCLetterDoc(sor.Id);
        nocDoc.Status__c = 'Uploaded';
        update nocDoc;
        TriggerHandler.processedIds.clear();
        update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'Signed');
    }

    private static SalesOrderRelationship__c mkSignedSOR() {
        Account customer = mkAccount('Customer-' + Math.mod(Crypto.getRandomInteger(), 100000), 'PARTY-CUST-1');
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000), 'PARTY-TP-1');
        Opportunity o = mkOpportunity('Opp-' + Math.mod(Crypto.getRandomInteger(), 100000));
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

    private class RelationshipMock implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;
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

    // Covers: SORelationshipCallout_Queable constructor + execute -> OIC_CustomerRelationshipCallout
    // .createCustomerRelationship happy path, including the RelationshipSfId response being written
    // back onto the SalesOrderRelationship__c record.
    @IsTest
    static void testExecute_SignedSorWithOracleIds_UpdatesRelationshipStatus() {
        SalesOrderRelationship__c sor = mkSignedSOR();
        String responseBody = '{"SubjectPartyId":"300000023148108","SubjectSfPartyId":"001VG000016fHdeYAE",' +
            '"ObjectPartyId":"300000023148041","ObjectSfPartyId":"001VG000016f8IeYAI","Type":"Party",' +
            '"SubjectAccountId":"","SubjectSfAccountId":"","ObjectAccountId":"","ObjectSfAccountId":"",' +
            '"RelationshipId":"REL-1","Status":"S","ErrorMessage":"",' +
            '"RelationshipSfId":"' + sor.Id + '"}';
        Test.setMock(HttpCalloutMock.class, new RelationshipMock(200, responseBody));

        Test.startTest();
        System.enqueueJob(new SORelationshipCallout_Queable(new Set<Id>{ sor.Id }));
        Test.stopTest();

        SalesOrderRelationship__c updated = [SELECT Id, RelationshipSyncStatus__c, RelationshipOracleId__c
                                              FROM SalesOrderRelationship__c WHERE Id = :sor.Id];
        Assert.areEqual('S', updated.RelationshipSyncStatus__c, 'RelationshipSyncStatus__c should be updated from the OIC response');
        Assert.areEqual('REL-1', updated.RelationshipOracleId__c, 'RelationshipOracleId__c should be updated from the OIC response');
    }

    // Covers: SORelationshipCallout_Queable.execute's error path when the callout response can't
    // be parsed into OIC_CustomerRelationshipRequestVO - the exception is caught and logged rather
    // than surfacing out of the queueable job.
    @IsTest
    static void testExecute_CalloutResponseUnparseable_LogsErrorInsteadOfThrowing() {
        SalesOrderRelationship__c sor = mkSignedSOR();
        Test.setMock(HttpCalloutMock.class, new RelationshipMock(200, 'not-valid-json'));

        Test.startTest();
        System.enqueueJob(new SORelationshipCallout_Queable(new Set<Id>{ sor.Id }));
        Test.stopTest();

        Assert.isFalse(
            [SELECT count() FROM Logger__c] == 0,
            'Expected the unparseable callout response to be logged rather than thrown from the queueable'
        );
    }

    // Covers: SORelationshipCallout_Queable.execute with an empty id set - no callout should be
    // attempted and OIC_CustomerRelationshipCallout.createCustomerRelationship should no-op.
    @IsTest
    static void testExecute_EmptySorIdSet_NoOp() {
        Test.startTest();
        System.enqueueJob(new SORelationshipCallout_Queable(new Set<Id>()));
        Test.stopTest();

        Assert.areEqual(0, [SELECT count() FROM Logger__c], 'No callout or logging should occur for an empty id set');
    }
}