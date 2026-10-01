/**********************************************************************************************************************
* Name               : UnitTriggerHandlerTest
* Description        : Test class for UnitTriggerHandler
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           prateek.b.bansal@pwc.com         15 Jan 2024     Initial Draft
* 2.0           Shahil Sinha (Horizontal)        30 Dec 2025     Added tests for Sakneen integration
**********************************************************************************************************************/
@isTest
public class UnitTriggerHandlerTest {

    @isTest
    static void testInsertUnits() {
        Test.startTest();
        
        // Insert Egypt unit
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned'
        );
        insert egyptUnit;
        
        // Insert non-Egypt unit
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit',
            Source_Entity__c = 'Modon - UAE',
            PlotNo__c = '102',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert uaeUnit;
        
        Test.stopTest();
        
        System.assertEquals(2, [SELECT COUNT() FROM Unit__c], 'Both units should be inserted');
    }

    @isTest
    static void testUpdateUnits() {
        // Create units
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            GrossFloorAreaGFA__c = 200
        );
        insert egyptUnit;
        
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit',
            Source_Entity__c = 'Modon - UAE',
            PlotNo__c = '102',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert uaeUnit;
        
        Test.startTest();
        
        // Update Egypt unit (tracked field)
        egyptUnit.GrossFloorAreaGFA__c = 300;
        egyptUnit.Status__c = 'Sold';
        update egyptUnit;
        
        // Update non-Egypt unit
        uaeUnit.BlockComment__c = 'Test comment';
        update uaeUnit;
        
        Test.stopTest();
        
        Unit__c updatedEgypt = [SELECT GrossFloorAreaGFA__c, Status__c FROM Unit__c WHERE Id = :egyptUnit.Id];
        System.assertEquals(300, updatedEgypt.GrossFloorAreaGFA__c, 'GFA should be updated');
        System.assertEquals('Sold', updatedEgypt.Status__c, 'Status should be updated');
    }

    @isTest
    static void testDeleteUnits() {
        // Create units
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned'
        );
        insert egyptUnit;
        
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit',
            Source_Entity__c = 'Modon - UAE',
            PlotNo__c = '102',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert uaeUnit;
        
        Test.startTest();
        delete egyptUnit;
        delete uaeUnit;
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Unit__c], 'Both units should be deleted');
    }

    @isTest
    static void testBulkOperations() {
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 10; i++) {
            units.add(new Unit__c(
                Name = 'Bulk Unit ' + i,
                Source_Entity__c = (Math.mod(i, 2) == 0) ? 'Modon - Egypt' : 'Modon - UAE',
                PlotNo__c = 'B' + i,
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '2',
                Status__c = 'Available',
                Sub_Status__c = 'Un-Assigned'
            ));
        }
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new HttpMock());
        insert units;
        
        for (Unit__c u : units) {
            u.Status__c = 'Reserved';
        }
        TriggerHandler.processedIds.clear();
        update units;
        
        Test.stopTest();
        
        System.assertEquals(10, [SELECT COUNT() FROM Unit__c WHERE Status__c = 'Reserved'], 'All units should be updated');
    }

    @isTest
    static void testUpdateUnitStatusBypassForEgypt() {
        // Create an Egypt unit
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit Status Test',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '101E',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned'
        );
        insert egyptUnit;

        Test.startTest();
        // Set mock to prevent any callout exceptions if they occur
        Test.setMock(HttpCalloutMock.class, new HttpMock());
        
        // Update Egypt unit status
        egyptUnit.Status__c = 'Reserved';
        TriggerHandler.processedIds.clear();
        update egyptUnit;
        Test.stopTest();
    }

    @isTest
    static void testUpdateUnitStatusSyncForUAE() {
        // Create a UAE unit
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit Status Test',
            Source_Entity__c = 'Modon - UAE',
            PlotNo__c = '101U',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned'
        );
        insert uaeUnit;

        Test.startTest();
        // Set mock to prevent any callout exceptions
        Test.setMock(HttpCalloutMock.class, new HttpMock());
        
        // Update UAE unit status
        uaeUnit.Status__c = 'Reserved';
        TriggerHandler.processedIds.clear();
        update uaeUnit;
        Test.stopTest();
    }

    private class HttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            res.setStatusCode(200);
            return res;
        }
    }
}