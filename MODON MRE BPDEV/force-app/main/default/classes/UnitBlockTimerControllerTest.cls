/**-------------------------------------------------------------------
 * Description : Test Class for UnitBlockTimerController
 * -------------------------------------------------------------------
 * History :
 * [2024-02-08] Yazan Saeed - Code Creation
 * -------------------------------------------------------------------
*/
@isTest
public class UnitBlockTimerControllerTest {

    @isTest
    static void testMethod1(){

        //Create wrappers
        UnitBlockTimerController.RequestWrap reqWrap  = new UnitBlockTimerController.RequestWrap();
        UnitBlockTimerController.RespondWrap respWrap = new UnitBlockTimerController.RespondWrap();

        //Create an account
        Account accountObj = new Account();
        accountObj.Name = 'Test Account';
        INSERT accountObj;

        //Create a new Unit
        Unit__c unitObj = new Unit__c();
        unitObj.Name = 'Test Unit';
        unitObj.BasePrice__c = 1000;
        unitObj.AdditionalPrice__c = 0;
        unitObj.PlotAreasqm__c = 1.0;
        unitObj.PlotNo__c = '1';
        INSERT unitObj;

        //Create a new sales order with a populated status
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c = 'In Progress';
        salesOrderObj.Unit__c = unitObj.Id;
        INSERT salesOrderObj;

        reqWrap.recordId = salesOrderObj.Id;
        String serializedReqWrap = JSON.serialize(reqWrap);

        test.startTest();
        
            respWrap = UnitBlockTimerController.getUnitDetails(serializedReqWrap);
            
        test.stopTest();

    }
}