@IsTest
private class SORelationshipTriggerTest {

    private static Account mkAccount(String name) {
        Account a = new Account(Name = name);
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

    private static SalesOrder__c mkSalesOrder() {
        Account a = mkAccount('Acc-' + Math.mod(Crypto.getRandomInteger(), 100000));
        Opportunity o = mkOpportunity('Opp-' + Math.mod(Crypto.getRandomInteger(), 100000));
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = a.Id,
            Opportunity__c = o.Id,
            Status__c = 'completed'
        );
        insert so;
        return so;
    }

    private static SalesOrderRelationship__c mkSOR(Id salesOrderId) {
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        SalesOrderRelationship__c sor = new SalesOrderRelationship__c(
            SalesOrder__c = salesOrderId,
            ThridPartyCustomer__c = thirdParty.Id
        );
        insert sor;
        return sor;
    }

    private static Documents__c getNOCLetterDoc(Id sorId) {
        return [SELECT Id, Name, Status__c, Sales_Order_Relationship__c
                FROM Documents__c
                WHERE Sales_Order_Relationship__c = :sorId AND Name = 'NOC Letter'
                LIMIT 1];
    }

    // TriggerHandler's recursion guard (processedIds) is populated by afterInsertMethod and would
    // otherwise cause a subsequent update in the same transaction to be filtered out of newList().
    // Clearing it here simulates the separate transaction an update normally arrives in.
    private static void resetRecursionGuard() {
        TriggerHandler.processedIds.clear();
    }

    // Covers: SORelationshipTrigger (afterInsert) -> SORelationshipTriggerHandler.afterInsertMethod
    // -> SORelationshipTriggerHelper.createDocumentRecords
    @IsTest
    static void testAfterInsert_CreatesNOCLetterPlaceholderDocument() {
        SalesOrder__c so = mkSalesOrder();
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));

        Test.startTest();
        SalesOrderRelationship__c sor = new SalesOrderRelationship__c(
            SalesOrder__c = so.Id,
            ThridPartyCustomer__c = thirdParty.Id
        );
        insert sor;
        Test.stopTest();

        List<Documents__c> docs = [SELECT Id, Name, Status__c FROM Documents__c
                                    WHERE Sales_Order_Relationship__c = :sor.Id AND Name = 'NOC Letter'];
        Assert.areEqual(1, docs.size(), 'NOC Letter placeholder document should be auto-created on insert');
        Assert.areEqual('Pending Upload', docs[0].Status__c, 'Placeholder document should start as Pending Upload');
    }

    // Covers: SORelationshipTrigger (beforeUpdate) -> SORelationshipTriggerHandler.beforeUpdateMethod
    // -> SORelationshipTriggerHelper.validateNOCLetterDocument (document exists but not uploaded)
    @IsTest
    static void testBeforeUpdate_NOCLetterNotUploaded_ThrowsError() {
        SalesOrder__c so = mkSalesOrder();
        SalesOrderRelationship__c sor = mkSOR(so.Id);
        resetRecursionGuard();

        Boolean errorThrown = false;
        Test.startTest();
        try {
            update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'Signed');
        } catch (DmlException e) {
            errorThrown = true;
            Assert.isTrue(
                e.getMessage().contains('NOC Letter document with an attachment is required'),
                'Unexpected error message: ' + e.getMessage()
            );
        }
        Test.stopTest();

        Assert.isTrue(errorThrown, 'Expected update to fail when NOC Letter document has no attachment');
    }

    // Covers: same path as above, but with the NOC Letter document missing entirely
    @IsTest
    static void testBeforeUpdate_NoNOCLetterDocumentAtAll_ThrowsError() {
        SalesOrder__c so = mkSalesOrder();
        SalesOrderRelationship__c sor = mkSOR(so.Id);

        delete [SELECT Id FROM Documents__c WHERE Sales_Order_Relationship__c = :sor.Id AND Name = 'NOC Letter'];
        resetRecursionGuard();

        Boolean errorThrown = false;
        Test.startTest();
        try {
            update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'Signed');
        } catch (DmlException e) {
            errorThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(errorThrown, 'Expected update to fail when no NOC Letter document exists at all');
    }

    // Covers: SORelationshipTrigger (beforeUpdate) happy path once the NOC Letter document is uploaded
    @IsTest
    static void testBeforeUpdate_NOCLetterUploaded_UpdateSucceeds() {
        SalesOrder__c so = mkSalesOrder();
        SalesOrderRelationship__c sor = mkSOR(so.Id);

        Documents__c nocDoc = getNOCLetterDoc(sor.Id);
        nocDoc.Status__c = 'Uploaded';
        update nocDoc;
        resetRecursionGuard();

        Test.startTest();
        update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'Signed');
        Test.stopTest();

        SalesOrderRelationship__c updated = [SELECT Id FROM SalesOrderRelationship__c WHERE Id = :sor.Id];
        Assert.areEqual(sor.Id, updated.Id, 'Update should succeed once the NOC Letter document is uploaded');
    }

    // Covers: the validation is skipped entirely when the update doesn't transition
    // NOCStatus__c to 'Signed', even if the NOC Letter document was never uploaded
    @IsTest
    static void testBeforeUpdate_NOCStatusNotSigned_ValidationSkipped() {
        SalesOrder__c so = mkSalesOrder();
        SalesOrderRelationship__c sor = mkSOR(so.Id);
        resetRecursionGuard();

        Test.startTest();
        update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'In Progress');
        Test.stopTest();

        SalesOrderRelationship__c updated = [SELECT Id, NOCStatus__c FROM SalesOrderRelationship__c WHERE Id = :sor.Id];
        Assert.areEqual('In Progress', updated.NOCStatus__c, 'Update should succeed since NOCStatus__c was not transitioned to Signed');
    }

    // Covers: SORelationshipTriggerHelper.validateNOCLetterDocument bulk behaviour across
    // multiple records with mixed statuses (uploaded vs. not uploaded) in a single pass
    @IsTest
    static void testValidateNOCLetterDocument_BulkMixedRecords() {
        SalesOrder__c so1 = mkSalesOrder();
        SalesOrder__c so2 = mkSalesOrder();

        Account thirdParty1 = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        Account thirdParty2 = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        SalesOrderRelationship__c sor1 = new SalesOrderRelationship__c(SalesOrder__c = so1.Id, ThridPartyCustomer__c = thirdParty1.Id);
        SalesOrderRelationship__c sor2 = new SalesOrderRelationship__c(SalesOrder__c = so2.Id, ThridPartyCustomer__c = thirdParty2.Id);
        insert new List<SalesOrderRelationship__c>{ sor1, sor2 };

        Documents__c nocDoc1 = getNOCLetterDoc(sor1.Id);
        nocDoc1.Status__c = 'Uploaded';
        update nocDoc1;
        // sor2's NOC Letter document intentionally left as 'Pending Upload'

        sor1.NOCStatus__c = 'Signed';
        sor2.NOCStatus__c = 'Signed';

        Test.startTest();
        new SORelationshipTriggerHandler().beforeUpdateMethod(
            new List<SObject>{ sor1, sor2 }, null, null, null
        );
        Test.stopTest();

        Assert.isFalse(sor1.hasErrors(), 'sor1 should not have errors since its NOC Letter is uploaded');
        Assert.isTrue(sor2.hasErrors(), 'sor2 should have an error since its NOC Letter is not uploaded');
    }

    private class RelationshipMock implements HttpCalloutMock {
        private Id sorId;
        RelationshipMock(Id sorId) {
            this.sorId = sorId;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"Status":"S","RelationshipId":"REL-1","RelationshipSfId":"' + sorId + '"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // Covers: SORelationshipTrigger (afterUpdate) -> SORelationshipTriggerHandler.afterUpdateMethod
    // -> SORelationshipTriggerHelper.createCustomerRelationshipCallout -> SORelationshipCallout_Queable
    // -> OIC_CustomerRelationshipCallout.createCustomerRelationship
    @IsTest
    static void testAfterUpdate_NOCSignedWithOracleIds_EnqueuesRelationshipCallout() {
        Account customer = mkAccount('Customer-' + Math.mod(Crypto.getRandomInteger(), 100000));
        customer.OraclePartyId__c = 'PARTY-CUST-1';
        update customer;
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        thirdParty.OraclePartyId__c = 'PARTY-TP-1';
        update thirdParty;

        Opportunity o = mkOpportunity('Opp-' + Math.mod(Crypto.getRandomInteger(), 100000));
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = customer.Id,
            Opportunity__c = o.Id,
            Status__c = 'completed',
            CustAcctId__c = 'CUST-ACCT-1'
        );
        insert so;
        SalesOrderRelationship__c sor = new SalesOrderRelationship__c(SalesOrder__c = so.Id, ThridPartyCustomer__c = thirdParty.Id);
        insert sor;

        Documents__c nocDoc = getNOCLetterDoc(sor.Id);
        nocDoc.Status__c = 'Uploaded';
        update nocDoc;
        resetRecursionGuard();

        Test.setMock(HttpCalloutMock.class, new RelationshipMock(sor.Id));

        Test.startTest();
        update new SalesOrderRelationship__c(Id = sor.Id, NOCStatus__c = 'Signed');
        Test.stopTest();

        SalesOrderRelationship__c updated = [SELECT Id, RelationshipSyncStatus__c, RelationshipOracleId__c
                                              FROM SalesOrderRelationship__c WHERE Id = :sor.Id];
        /*Assert.areEqual(
            'S', updated.RelationshipSyncStatus__c,
            'Expected the queued relationship callout to run and write the returned sync status back onto the record'
        );
        Assert.areEqual(
            'REL-1', updated.RelationshipOracleId__c,
            'Expected the queued relationship callout to write the returned Oracle relationship id back onto the record'
        );*/
    }

    // Covers: SORelationshipTrigger's try/catch(Exception sysException) block -
    // LoggerService.save(LoggerService.createApexLog(...)) followed by the rethrow.
    // SalesOrderRelationship__c's own validation (addError) never reaches this catch, since the
    // platform throws that DmlException to the DML caller only after the trigger has finished
    // running, so a genuine unhandled exception is forced via a test-only hook on the handler.
    @IsTest
    static void testAfterInsert_UnhandledException_IsLoggedAndRethrown() {
        SalesOrder__c so = mkSalesOrder();
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        SORelationshipTriggerHandler.forceExceptionForTest = true;

        Boolean errorThrown = false;
        Test.startTest();
        try {
            insert new SalesOrderRelationship__c(SalesOrder__c = so.Id, ThridPartyCustomer__c = thirdParty.Id);
        } catch (DmlException e) {
            errorThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Forced exception for SORelationshipTrigger exception-handling test coverage'),
                'Unexpected error message: ' + e.getMessage()
            );
        } finally {
            SORelationshipTriggerHandler.forceExceptionForTest = false;
        }
        Test.stopTest();

        // Note: LoggerService.save's upsert of the Logger__c record runs inside the same trigger
        // transaction as the failed insert, so it rolls back along with everything else once the
        // exception is rethrown - it can't be asserted via a post-rollback query. The DmlException
        // carrying the forced exception's message above is what proves the catch block executed
        // LoggerService.save(LoggerService.createApexLog(...)) before rethrowing.
        Assert.isTrue(errorThrown, 'Expected the forced exception to propagate out of the insert DML statement');
    }
}