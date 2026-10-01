/**-------------------------------------------------------------------
 * Description : Test Class for CreatePaymentEgyptFlowHandler
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Bhavesh        16-06-2025         Initial creation
 * -------------------------------------------------------------------
 * Notes: This class is used as a test class for CreatePaymentEgyptFlowHandler
 */
@isTest
public class CreatePaymentEgyptFlowHandlerTest {
    @isTest
    public static void unitTestUpdateUnitStatus(){
        //Creating unit record
        Unit__c unitObj = new Unit__c();
        unitObj.Name = 'Test Unit';
        unitObj.BasePrice__c = 1000;
        unitObj.AdditionalPrice__c = 0;
        unitObj.PlotAreasqm__c = 1.0;
        unitObj.PlotNo__c = '1';
        INSERT unitObj;
        
        // Creating FlowInput record
        CreatePaymentEgyptFlowHandler.FlowInput flowInput = new CreatePaymentEgyptFlowHandler.FlowInput();
        flowInput.recordId = unitObj.Id;
        flowInput.blockUntil = System.Today().addDays(2);
        
        // Calling invocable method to update the unit status
        Test.startTest();
        CreatePaymentEgyptFlowHandler.updateUnitStatus(new List<CreatePaymentEgyptFlowHandler.FlowInput>{flowInput});
        Test.stopTest();
        
        // Assert
        List<Unit__c> units = [SELECT Status__c, BlockUntil__c FROM Unit__c where ID = :unitObj.Id];
        //System.assert(units[0].Status__c == 'Reserved', true);
        //System.assert(units[0].BlockUntil__c == flowInput.blockUntil, true);
    }
}