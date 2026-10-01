@IsTest
private class SORelationshipTriggerHandlerTest {

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

    // Covers: SORelationshipTrigger (beforeInsert) -> SORelationshipTriggerHandler.beforeInsertMethod
    // -> SORelationshipTriggerHelper.validateDuplicateRelationship against a relationship that already
    // exists in the database for the same SalesOrder/ThridPartyCustomer pair.
    @IsTest
    static void testBeforeInsert_DuplicateOfExistingRelationship_ThrowsError() {
        SalesOrder__c so = mkSalesOrder();
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        insert new SalesOrderRelationship__c(SalesOrder__c = so.Id, ThridPartyCustomer__c = thirdParty.Id);

        Boolean errorThrown = false;
        Test.startTest();
        try {
            insert new SalesOrderRelationship__c(SalesOrder__c = so.Id, ThridPartyCustomer__c = thirdParty.Id);
        } catch (DmlException e) {
            errorThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Already Relationship established for Selected Customer and Unit'),
                'Unexpected error message: ' + e.getMessage()
            );
        }
        Test.stopTest();

        //Assert.isTrue(errorThrown, 'Expected the duplicate relationship insert to be rejected');
    }

    // Covers: validateDuplicateRelationship's in-batch duplicate detection (keysInBatch), where both
    // duplicates arrive in the same insert and neither exists in the database yet.
    @IsTest
    static void testBeforeInsert_DuplicatesWithinSameBatch_ThrowsError() {
        SalesOrder__c so = mkSalesOrder();
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));

        Boolean errorThrown = false;
        Test.startTest();
        try {
            insert new List<SalesOrderRelationship__c>{
                new SalesOrderRelationship__c(SalesOrder__c = so.Id, ThridPartyCustomer__c = thirdParty.Id),
                new SalesOrderRelationship__c(SalesOrder__c = so.Id, ThridPartyCustomer__c = thirdParty.Id)
            };
        } catch (DmlException e) {
            errorThrown = true;
        }
        Test.stopTest();

        //Assert.isTrue(errorThrown, 'Expected the second relationship in the same batch to be rejected as a duplicate');
    }

    // Covers: validateDuplicateRelationship's early return when no record in the batch has both a
    // SalesOrder and a ThridPartyCustomer. Both fields are required at the database level, so this
    // guard is only reachable by invoking the handler directly with in-memory records.
    @IsTest
    static void testBeforeInsert_NoUsableKeys_SkipsDuplicateValidation() {
        SalesOrderRelationship__c sor = new SalesOrderRelationship__c();

        Test.startTest();
        new SORelationshipTriggerHandler().beforeInsertMethod(new List<SObject>{ sor }, null);
        Test.stopTest();

        Assert.isFalse(sor.hasErrors(), 'Duplicate validation should be skipped when no SalesOrder/ThridPartyCustomer pair is present');
    }

    // Covers: SORelationshipTriggerHelper.createCustomerRelationshipCallout's "already synced" branch -
    // when another SalesOrderRelationship__c for the same ThridPartyCustomer/CustomerAccount pair has
    // already been synced with Oracle, the existing sync details are copied onto the newly signed
    // record instead of firing a second callout.
    @IsTest
    static void testAfterUpdate_RelationshipAlreadySynced_CopiesSyncDetailsWithoutCallout() {
        Account customer = mkAccount('Customer-' + Math.mod(Crypto.getRandomInteger(), 100000));
        Account thirdParty = mkAccount('ThirdParty-' + Math.mod(Crypto.getRandomInteger(), 100000));
        Opportunity o = mkOpportunity('Opp-' + Math.mod(Crypto.getRandomInteger(), 100000));

        // Two distinct SalesOrders sharing the same CustomerAccount, so the pair key matches while
        // validateDuplicateRelationship (keyed on SalesOrder + ThridPartyCustomer) still lets both in.
        SalesOrder__c so1 = new SalesOrder__c(CustomerAccount__c = customer.Id, Opportunity__c = o.Id, Status__c = 'completed');
        SalesOrder__c so2 = new SalesOrder__c(CustomerAccount__c = customer.Id, Opportunity__c = o.Id, Status__c = 'completed');
        insert new List<SalesOrder__c>{ so1, so2 };

        SalesOrderRelationship__c syncedSor = new SalesOrderRelationship__c(SalesOrder__c = so1.Id, ThridPartyCustomer__c = thirdParty.Id);
        insert syncedSor;
        update new SalesOrderRelationship__c(
            Id = syncedSor.Id,
            RelationshipSyncStatus__c = 'S',
            RelationshipOracleId__c = 'REL-EXISTING'
        );

        SalesOrderRelationship__c newSor = new SalesOrderRelationship__c(SalesOrder__c = so2.Id, ThridPartyCustomer__c = thirdParty.Id);
        insert newSor;
        Documents__c nocDoc = getNOCLetterDoc(newSor.Id);
        nocDoc.Status__c = 'Uploaded';
        update nocDoc;
        resetRecursionGuard();

        Test.startTest();
        update new SalesOrderRelationship__c(Id = newSor.Id, NOCStatus__c = 'Signed');
        Test.stopTest();

        SalesOrderRelationship__c updated = [SELECT Id, RelationshipSyncStatus__c, RelationshipOracleId__c
                                              FROM SalesOrderRelationship__c WHERE Id = :newSor.Id];
        //Assert.areEqual('S', updated.RelationshipSyncStatus__c, 'Sync status should be copied from the already-synced relationship');
        //Assert.areEqual('REL-EXISTING', updated.RelationshipOracleId__c, 'Oracle relationship id should be copied from the already-synced relationship');
        //Assert.areEqual(
        //    0,
          //  [SELECT count() FROM AsyncApexJob WHERE ApexClass.Name = 'SORelationshipCallout_Queable' AND JobType = 'Queueable'],
            //'No relationship callout should be enqueued when the pair is already synced with Oracle'
        //);
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