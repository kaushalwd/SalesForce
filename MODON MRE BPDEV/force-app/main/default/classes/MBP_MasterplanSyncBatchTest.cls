@isTest
public class MBP_MasterplanSyncBatchTest {
        private class MasterplanBatchMock implements HttpCalloutMock {
            public HTTPResponse respond(HTTPRequest req) {
               
                if (req.getEndpoint() != null && req.getEndpoint().contains('UNIT-EXCEPTION')) {
                    throw new CalloutException('Mock callout failure');
                }
        
                HttpResponse res = new HttpResponse();
                res.setHeader('Content-Type', 'application/json');
                res.setStatusCode(200);
        
               
                if (req.getEndpoint() != null && req.getEndpoint().contains('UNIT-SUCCESS')) {
                    res.setBody('{"success":true,"url":"https://example.com/masterplan"}');
        
                
                } else if (req.getEndpoint() != null && req.getEndpoint().contains('UNIT-NOURL')) {
                    res.setBody('{"success":true,"url":""}');
        
                } else {
                    res.setBody('{"success":false}');
                }
                return res;
            }
        }


    
    @testSetup
    static void setupData() {
        Project__c proj = new Project__c(
            Name = 'Test Project',
            Broker_Sales__c = true
        );
        insert proj;
        
        Phase__c phase = new Phase__c(
            Name = 'Phase 1',
            Project__c = proj.Id
        );
        insert phase;
        
        List<Unit__c> units = new List<Unit__c>{
            new Unit__c(
                Name = 'UNIT-SUCCESS',
                Phase__c = phase.Id,
                Broker_Sales__c = true,
                Status__c = 'Available',
                PlotNo__c = '2B004',
                UnitClassification__c = 'Apartment',
                Number_of_Bedrooms__c = '1'
            ),
                new Unit__c(
                    Name = 'UNIT-FAIL',
                    Phase__c = phase.Id,
                    Broker_Sales__c = true,
                    Status__c = 'Available',
                    PlotNo__c = '2B001',
                    UnitClassification__c = 'Apartment',
                    Number_of_Bedrooms__c = '1'
                ),
                
                	new Unit__c(
                        Name = 'UNIT-NOURL',
                        Phase__c = phase.Id,
                        Broker_Sales__c = true,
                        Status__c = 'Available',
                        PlotNo__c = '2B002',
                        UnitClassification__c = 'Apartment',
                        Number_of_Bedrooms__c = '1'
                    ),
                    new Unit__c(
                        Name = 'UNIT-EXCEPTION',
                        Phase__c = phase.Id,
                        Broker_Sales__c = true,
                        Status__c = 'Available',
                        PlotNo__c = '2B003',
                        UnitClassification__c = 'Apartment',
                        Number_of_Bedrooms__c = '1'
                    )

                };
                    insert units;
    }
    
    @isTest
    static void testBatch_MasterplanSync_AllPaths() {
    
        MBP_MasterplanSyncBatch batch = new MBP_MasterplanSyncBatch('Available', null);
        Test.setMock(HttpCalloutMock.class, new MasterplanBatchMock());
    
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    
        Map<String, Unit__c> byName = new Map<String, Unit__c>();
        for (Unit__c u : [
            SELECT Name, Masterplan_URL__c, Masterplan_Status__c, Masterplan_Error__c, Masterplan_Last_Sync__c
            FROM Unit__c
        ]) {
            byName.put(u.Name, u);
            System.assertNotEquals(null, u.Masterplan_Last_Sync__c);
        }
        
        System.assertEquals('Success', byName.get('UNIT-SUCCESS').Masterplan_Status__c);
        System.assertNotEquals(null, byName.get('UNIT-SUCCESS').Masterplan_URL__c);
        System.assertEquals(null, byName.get('UNIT-SUCCESS').Masterplan_Error__c);
    
        
        System.assertEquals('Failed', byName.get('UNIT-FAIL').Masterplan_Status__c);
        System.assertNotEquals(null, byName.get('UNIT-FAIL').Masterplan_Error__c);
    
        
        System.assertEquals('Failed', byName.get('UNIT-NOURL').Masterplan_Status__c);
        System.assertEquals(null, byName.get('UNIT-NOURL').Masterplan_URL__c);
        System.assertEquals('Oracle did not return a valid URL.', byName.get('UNIT-NOURL').Masterplan_Error__c);
    
        
        System.assertEquals('Failed', byName.get('UNIT-EXCEPTION').Masterplan_Status__c);
        System.assertNotEquals(null, byName.get('UNIT-EXCEPTION').Masterplan_Error__c);
        System.assert(byName.get('UNIT-EXCEPTION').Masterplan_Error__c.contains('Mock callout failure'));
    }

    @isTest
    static void testBatch_NoArgConstructor() {
        Test.setMock(HttpCalloutMock.class, new MasterplanBatchMock());

        Test.startTest();
        Database.executeBatch(new MBP_MasterplanSyncBatch(), 200);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Unit__c WHERE Masterplan_Last_Sync__c != null] > 0,
            'No-arg constructor batch should still sync units'
        );
    }

    @isTest
    static void testBatch_PhaseFilter() {
        Phase__c phase = [SELECT Id FROM Phase__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MasterplanBatchMock());

        Test.startTest();
        Database.executeBatch(new MBP_MasterplanSyncBatch('Available', String.valueOf(phase.Id)), 200);
        Test.stopTest();

        Unit__c synced = [
            SELECT Masterplan_Last_Sync__c
            FROM Unit__c
            WHERE Name = 'UNIT-SUCCESS'
            LIMIT 1
        ];
        System.assertNotEquals(null, synced.Masterplan_Last_Sync__c);
    }
}