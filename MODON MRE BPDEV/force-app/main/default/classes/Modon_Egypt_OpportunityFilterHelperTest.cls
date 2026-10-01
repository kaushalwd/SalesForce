/**********************************************************************************************************************
* Name               : Modon_Egypt_OpportunityFilterHelperTest
* Description        : Test class for Modon_Egypt_OpportunityFilterHelper
* Created By         : Horizontal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Horizontal                          15 Sep 2025     Initial Draft
* 1.1           Shahil Sinha (Horizontal)           23 Jan 2026     Removed testFilterAfterUpdateMethodSO - method moved 
*                                                                   to Modon_Egypt_SalesOrderFilterHelper
**********************************************************************************************************************/
@IsTest
private class Modon_Egypt_OpportunityFilterHelperTest {
    
    // Helper to create an Opportunity with a fake Id (no DML needed)
    private static Opportunity createOpp(Id oppId, String sourceEntity) {
        Opportunity opp = new Opportunity();
        opp.Id = oppId;
        opp.Name = 'Test Opp';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today();
        opp.Source_Entity__c = sourceEntity;
        return opp;
    }
    
    @IsTest
    static void testFilterBeforeInsert() {
        Opportunity oppModon = createOpp((Id) '006000000000001AAA', 'Modon - Egypt');
        Opportunity oppOther = createOpp((Id) '006000000000002AAA', '');
        
        List<SObject> newList = new List<SObject>{ oppModon, oppOther };
        
        Test.startTest();
        Map<String, Object> result = Modon_Egypt_OpportunityFilterHelper.filterBeforeInsert(newList);
        Test.stopTest();
        
        List<Opportunity> modonList = (List<Opportunity>) result.get('ModonEgyptOpportunities');
        List<Opportunity> otherList = (List<Opportunity>) result.get('OtherOpportunities');
        
        System.assertEquals(1, modonList.size(), 'Should have 1 Egypt opportunity');
        System.assertEquals(1, otherList.size(), 'Should have 1 other opportunity');
        System.assertEquals('Modon - Egypt', modonList[0].Source_Entity__c);
    }
    
    @IsTest
    static void testFilterBeforeUpdate() {
        Opportunity oldModon = createOpp((Id) '006000000000003AAA', 'Modon - Egypt');
        Opportunity oldOther = createOpp((Id) '006000000000004AAA', '');
        Opportunity newModon = createOpp(oldModon.Id, 'Modon - Egypt');
        Opportunity newOther = createOpp(oldOther.Id, '');
        
        List<SObject> newList = new List<SObject>{ newModon, newOther };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ newModon.Id => newModon, newOther.Id => newOther };
        List<SObject> oldList = new List<SObject>{ oldModon, oldOther };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldModon.Id => oldModon, oldOther.Id => oldOther };
        
        Test.startTest();
        Map<String, Object> result = Modon_Egypt_OpportunityFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        Test.stopTest();
        
        List<Opportunity> modonList = (List<Opportunity>) result.get('ModonEgyptOpportunities');
        List<Opportunity> otherList = (List<Opportunity>) result.get('OtherOpportunities');
        Map<Id, Opportunity> modonNewMap = (Map<Id, Opportunity>) result.get('ModonEgyptNewMap');
        Map<Id, Opportunity> otherNewMap = (Map<Id, Opportunity>) result.get('OtherNewMap');
        Map<Id, Opportunity> modonOldMap = (Map<Id, Opportunity>) result.get('ModonEgyptOldMap');
        Map<Id, Opportunity> otherOldMap = (Map<Id, Opportunity>) result.get('OtherOldMap');
        
        System.assertEquals(1, modonList.size());
        System.assertEquals(1, otherList.size());
        System.assertEquals(1, modonNewMap.size());
        System.assertEquals(1, modonOldMap.size());
        System.assertEquals(newModon, modonNewMap.get(newModon.Id));
        System.assertEquals(oldModon, modonOldMap.get(newModon.Id));
    }
    
    @IsTest
    static void testFilterAfterInsert() {
        Opportunity oppModon = createOpp((Id) '006000000000005AAA', 'Modon - Egypt');
        Opportunity oppOther = createOpp((Id) '006000000000006AAA', '');
        
        List<SObject> newList = new List<SObject>{ oppModon, oppOther };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ oppModon.Id => oppModon, oppOther.Id => oppOther };
        
        Test.startTest();
        Map<String, Object> result = Modon_Egypt_OpportunityFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();
        
        List<SObject> modonList = (List<SObject>) result.get('ModonEgyptOpportunities');
        List<SObject> otherList = (List<SObject>) result.get('OtherOpportunities');
        Map<Id, SObject> modonMap = (Map<Id, SObject>) result.get('ModonEgyptMap');
        Map<Id, SObject> otherMap = (Map<Id, SObject>) result.get('OtherMap');
        
        System.assertEquals(1, modonList.size());
        System.assertEquals(1, otherList.size());
        System.assertEquals(oppModon, modonMap.get(oppModon.Id));
        System.assertEquals(oppOther, otherMap.get(oppOther.Id));
    }
    
    @IsTest
    static void testFilterAfterUpdate() {
        Opportunity oldModon = createOpp((Id) '006000000000007AAA', 'Modon - Egypt');
        Opportunity oldOther = createOpp((Id) '006000000000008AAA', '');
        Opportunity newModon = createOpp(oldModon.Id, 'Modon - Egypt');
        Opportunity newOther = createOpp(oldOther.Id, '');
        
        List<SObject> newList = new List<SObject>{ newModon, newOther };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ newModon.Id => newModon, newOther.Id => newOther };
        List<SObject> oldList = new List<SObject>{ oldModon, oldOther };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldModon.Id => oldModon, oldOther.Id => oldOther };
        
        Test.startTest();
        Map<String, Object> result = Modon_Egypt_OpportunityFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        Test.stopTest();
        
        List<SObject> modonList = (List<SObject>) result.get('ModonEgyptOpportunities');
        List<SObject> otherList = (List<SObject>) result.get('OtherOpportunities');
        Map<Id, SObject> modonOldMap = (Map<Id, SObject>) result.get('ModonEgyptOldMap');
        Map<Id, SObject> otherOldMap = (Map<Id, SObject>) result.get('OtherOldMap');
        
        System.assertEquals(1, modonList.size());
        System.assertEquals(1, otherList.size());
        System.assertEquals(oldModon, modonOldMap.get(oldModon.Id));
        System.assertEquals(oldOther, otherOldMap.get(oldOther.Id));
    }
    
    @IsTest
    static void testEmptyList() {
        Test.startTest();
        Map<String, Object> beforeInsertResult = Modon_Egypt_OpportunityFilterHelper.filterBeforeInsert(new List<SObject>());
        Map<String, Object> afterInsertResult = Modon_Egypt_OpportunityFilterHelper.filterAfterInsert(new List<SObject>(), new Map<Id, SObject>());
        Test.stopTest();
        
        System.assertEquals(0, ((List<Opportunity>) beforeInsertResult.get('ModonEgyptOpportunities')).size());
        System.assertEquals(0, ((List<SObject>) afterInsertResult.get('ModonEgyptOpportunities')).size());
    }
}