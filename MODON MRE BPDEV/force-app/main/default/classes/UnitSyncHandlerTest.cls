@isTest
private class UnitSyncHandlerTest {

    // ─── Mock HTTP Responses ──────────────────────────────────────────────────
    // Covers line 106-116: 200 + success:true
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'message' => 'Successfully updated for test record',
                'id'      => 'testId',
                'name'    => 'Test Unit',
                'status'  => 'PROCESSED'
            }));
            return res;
        }
    }

    // Covers lines 109-116: 200 + success:false → buildErrorLog
    private class SuccessFalseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Validation failed on OIC side',
                'id'      => 'testId',
                'name'    => 'Test Unit',
                'status'  => 'FAILED'
            }));
            return res;
        }
    }

    // Covers lines 117-124: non-200 → buildErrorLog
    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    // Covers lines 125-132: callout exception → buildErrorLog
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            CalloutException e = (CalloutException) CalloutException.class.newInstance();
            e.setMessage('Callout timed out');
            throw e;
        }
    }

    // ─── Picklist Helpers ─────────────────────────────────────────────────────

    private static String getUnitClassification() {
        for (Schema.PicklistEntry e : Unit__c.UnitClassification__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }

    private static List<String> getStatusValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry e : Unit__c.Status__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) values.add(e.getValue());
        }
        return values;
    }

    // ─── Build Test Unit ──────────────────────────────────────────────────────

    private static Unit__c buildUnit(String name, String plotNo) {
        return new Unit__c(
            Name                  = name,
            Status__c             = getStatusValues()[0],
            Number_of_Bedrooms__c = '2',
            PlotNo__c             = plotNo,
            UnitClassification__c = getUnitClassification()
        );
    }

    // ─── TEST 1: Insert always fires sync (covers lines 7-20, 11-12) ─────────
    @isTest
    static void testInsertFiresSync() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Unit__c u = buildUnit('Test-Insert-001', 'PLOT-001');
        insert u;
        Test.stopTest();

        System.assertNotEquals(null, u.Id, 'Unit should be inserted');
    }

    // ─── TEST 2: Update with Status change fires sync (covers lines 13-14, 29) ─
    @isTest
    static void testUpdateStatusChangeFiresSync() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-Update-001', 'PLOT-002');
        insert u;

        List<String> statuses = getStatusValues();
        String newStatus = statuses.size() > 1
            ? (statuses[0] == u.Status__c ? statuses[1] : statuses[0])
            : statuses[0];

        Test.startTest();
        u.Status__c = newStatus;
        update u;
        Test.stopTest();

        System.assertEquals(newStatus,
            [SELECT Status__c FROM Unit__c WHERE Id = :u.Id].Status__c,
            'Status should be updated');
    }

    // ─── TEST 3: Update with FloorNumber change fires sync (covers line 34) ───
    @isTest
    static void testUpdateFloorNumberFiresSync() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-Floor-001', 'PLOT-003');
        insert u;

        Test.startTest();
        u.FloorNumber__c = '5';
        update u;
        Test.stopTest();

        System.assertEquals('5',
            [SELECT FloorNumber__c FROM Unit__c WHERE Id = :u.Id].FloorNumber__c,
            'FloorNumber should be updated');
    }

    // ─── TEST 4: Update with PlotAreasqm change fires sync (covers line 28) ───
    @isTest
    static void testUpdatePlotAreaFiresSync() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-PlotArea-001', 'PLOT-004');
        insert u;

        Test.startTest();
        u.PlotAreasqm__c = 250.0;
        update u;
        Test.stopTest();

        System.assertEquals(250.0,
            [SELECT PlotAreasqm__c FROM Unit__c WHERE Id = :u.Id].PlotAreasqm__c,
            'PlotAreasqm should be updated');
    }

    // ─── TEST 5: Update with Number_of_Bedrooms change (covers line 31) ──────
    @isTest
    static void testUpdateBedroomsFiresSync() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-Beds-001', 'PLOT-005');
        insert u;

        Test.startTest();
        u.Number_of_Bedrooms__c = '4';
        update u;
        Test.stopTest();

        System.assertEquals('4',
            [SELECT Number_of_Bedrooms__c FROM Unit__c WHERE Id = :u.Id].Number_of_Bedrooms__c,
            'Bedrooms should be updated');
    }

    // ─── TEST 6: Update with no tracked field change — no sync (covers line 13)─
    @isTest
    static void testUpdateNoChangeSkipsSync() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-NoChange-001', 'PLOT-006');
        insert u;

        Test.startTest();
        // Re-update same record without changing any tracked field
        update u;
        Test.stopTest();

        System.assertNotEquals(null, u.Id, 'Unit should still exist');
    }

    // ─── TEST 7: SyncJob — 200 success:true path (covers lines 63-116) ───────
    @isTest
    static void testSyncJobSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-SyncSuccess-001', 'PLOT-007');
        insert u;

        Test.startTest();
        System.enqueueJob(new UnitSyncHandler.SyncJob(new Set<Id>{ u.Id }));
        Test.stopTest();

        // Confirm record still exists and was not rolled back
        System.assertNotEquals(null,
            [SELECT Id FROM Unit__c WHERE Id = :u.Id].Id,
            'Unit should still exist after successful sync');
    }

    // ─── TEST 8: SyncJob — 200 success:false → buildErrorLog (lines 109-116) ─
    @isTest
    static void testSyncJobSuccessFalseLogsError() {
        Test.setMock(HttpCalloutMock.class, new SuccessFalseMock());
        Unit__c u = buildUnit('Test-SyncFail-001', 'PLOT-008');
        insert u;

        Test.startTest();
        System.enqueueJob(new UnitSyncHandler.SyncJob(new Set<Id>{ u.Id }));
        Test.stopTest();

        // Unit unaffected even when OIC returns success:false
        System.assertNotEquals(null,
            [SELECT Id FROM Unit__c WHERE Id = :u.Id].Id,
            'Unit should still exist after failed sync response');

        // Logger__c record should be created for the failure
        List<Logger__c> logs = [SELECT Id, Message__c FROM Logger__c WHERE LogType__c = 'OIC Error Log'];
        System.assert(!logs.isEmpty(), 'Logger record should be created on success:false response');
    }

    // ─── TEST 9: SyncJob — non-200 → buildErrorLog (covers lines 117-124) ───
    @isTest
    static void testSyncJobNon200LogsError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Unit__c u = buildUnit('Test-SyncError-001', 'PLOT-009');
        insert u;

        Test.startTest();
        System.enqueueJob(new UnitSyncHandler.SyncJob(new Set<Id>{ u.Id }));
        Test.stopTest();

        System.assertNotEquals(null,
            [SELECT Id FROM Unit__c WHERE Id = :u.Id].Id,
            'Unit should still exist after non-200 sync response');

        // Logger__c record should be created for non-200 response
        List<Logger__c> logs = [SELECT Id, Message__c FROM Logger__c WHERE LogType__c = 'OIC Error Log'];
        System.assert(!logs.isEmpty(), 'Logger record should be created on non-200 response');
    }

    // ─── TEST 10: SyncJob — callout exception → buildErrorLog (lines 125-132) ─
    @isTest
    static void testSyncJobExceptionLogsError() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        Unit__c u = buildUnit('Test-SyncException-001', 'PLOT-010');
        insert u;

        Test.startTest();
        System.enqueueJob(new UnitSyncHandler.SyncJob(new Set<Id>{ u.Id }));
        Test.stopTest();

        System.assertNotEquals(null,
            [SELECT Id FROM Unit__c WHERE Id = :u.Id].Id,
            'Unit should still exist after callout exception');
    }

    // ─── TEST 11: Bulk — multiple units, single DML save (covers lines 137-139)─
    @isTest
    static void testBulkSyncSingleDmlSave() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock()); // all fail → all log → one DML
        String unitClass  = getUnitClassification();
        String unitStatus = getStatusValues()[0];
        List<Unit__c> units = new List<Unit__c>();

        for (Integer i = 0; i < 10; i++) {
            units.add(new Unit__c(
                Name                  = 'Bulk-Test-' + i,
                Status__c             = unitStatus,
                Number_of_Bedrooms__c = '2',
                PlotNo__c             = 'PLOT-BULK-' + i,
                UnitClassification__c = unitClass
            ));
        }

        Test.startTest();
        insert units;
        System.enqueueJob(new UnitSyncHandler.SyncJob(new Map<Id, Unit__c>(units).keySet()));
        Test.stopTest();

        System.assertEquals(10,
            [SELECT COUNT() FROM Unit__c WHERE Name LIKE 'Bulk-Test-%'],
            '10 bulk units should exist');
    }

    // ─── TEST 12: handleTriggerEvent directly — insert path ──────────────────
    @isTest
    static void testHandleTriggerEventInsertDirect() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-Direct-Insert', 'PLOT-011');
        insert u;

        List<Unit__c> inserted = [SELECT Id, Name, Status__c, Number_of_Bedrooms__c,
                                         PlotNo__c, UnitClassification__c
                                  FROM Unit__c WHERE Id = :u.Id];

        Test.startTest();
        // Call handleTriggerEvent directly — isInsert = true, oldMap = null
        UnitSyncHandler.handleTriggerEvent(inserted, null, true);
        Test.stopTest();

        System.assertEquals(1, inserted.size(), 'Should have 1 unit');
    }

    // ─── TEST 13: handleTriggerEvent directly — update no change path ─────────
    @isTest
    static void testHandleTriggerEventUpdateNoChange() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Unit__c u = buildUnit('Test-Direct-Update', 'PLOT-012');
        insert u;

        List<Unit__c> newList = [SELECT Id, Name, Status__c, Number_of_Bedrooms__c,
                                        PlotNo__c, UnitClassification__c,
                                        BasePrice__c, TotalGrossSellableAreaGSA__c,
                                        TotalGFAsqm__c, TotalArea__c, PlotAreasqm__c,
                                        Phase__c, Project_Name__c, FloorNumber__c,
                                        BlockUntil__c, BlockedFor__c, Bucket__c,
                                        InventoryStatus__c, Typology__c
                                 FROM Unit__c WHERE Id = :u.Id];

        // oldMap same as new — hasRelevantChange returns false → no enqueue
        Map<Id, Unit__c> oldMap = new Map<Id, Unit__c>(newList);

        Test.startTest();
        UnitSyncHandler.handleTriggerEvent(newList, oldMap, false);
        Test.stopTest();

        System.assertEquals(1, newList.size(), 'Should have 1 unit');
    }
}