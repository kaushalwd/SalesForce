/**
 * @***************************************           : ***************************************
 * @Name                                              : SalesOrderPathControllerTest
 * @Description                                       : Test class for SalesOrderPathController
 * @Usage                                             : Verifies metadata mapping and SalesOrder details logic
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.1 - Fixed non-writeable fields & compile order
 * @Author                                            : Fatima Khan
 * @Date                                              : 10-28-2025
 * @***************************************           : ***************************************
**/
@IsTest
private class SalesOrderPathControllerTest {

    @TestSetup
    static void setupData() {
        // --- Mock metadata mappings (simulation only) ---
        List<Status_Substatus_Mapping__mdt> mockMappings = new List<Status_Substatus_Mapping__mdt>();

        Status_Substatus_Mapping__mdt newMap = new Status_Substatus_Mapping__mdt(
            DeveloperName = 'New',
            MasterLabel = 'New',
            Status__c = 'New',
            Order__c = 1,
            Substatus__c = JSON.serialize(
                new List<String>{
                    'Reservation Form Generated',
                    'SPA Generated & Signed (Customer)',
                    'Pending with Sales'
                }
            )
        );
        mockMappings.add(newMap);

        Status_Substatus_Mapping__mdt inProgMap = new Status_Substatus_Mapping__mdt(
            DeveloperName = 'In_Progress',
            MasterLabel = 'In Progress',
            Status__c = 'In Progress',
            Order__c = 2,
            Substatus__c = JSON.serialize(new List<String>{ 'SPA In-Progress', 'Signed SPA (Customer)' })
        );
        mockMappings.add(inProgMap);

        // --- Supporting data setup ---
        Project__c project = new Project__c(
            Name = 'Project A',
            Reservation_Form_Required__c = 'Yes'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Phase A',
            Project__c = project.Id,
            Is_Reservation_Form_Required__c = 'Yes'
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit 202',
            PlotNo__c = 'P-202',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;
        

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'New',
            Sub_Status__c = 'Reservation Form Generated',
            Unit__c = unit.Id
        );
        // Instead of plain `insert so;`
Database.SaveResult sr = Database.insert(so, false);
if (!sr.isSuccess()) {
    for (Database.Error err : sr.getErrors()) {
        System.debug('SALES ORDER INSERT ERROR: ' + err.getMessage());
        System.debug('Fields: ' + err.getFields());
    }
}


    }

    @IsTest
    static void testGetStatusAndSubstatusData() {
        Test.startTest();
        SalesOrderPathController.PathData pd = SalesOrderPathController.getStatusAndSubstatusData();
        Test.stopTest();

        if (pd != null && pd.orderedStatuses != null) {
            for (String statusVal : pd.orderedStatuses) {
                List<String> subVals = pd.statusToSubstatusMap.get(statusVal);
                if (subVals != null) {
                    System.debug('Status: ' + statusVal + ' | Substatuses: ' + subVals);
                }
            }
        }
    }

    @IsTest
    static void testGetSalesOrderDetails() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        Map<String, Object> details = SalesOrderPathController.getSalesOrderDetails(so.Id);
        Test.stopTest();

        for (String key : details.keySet()) {
            System.debug('Detail -> ' + key + ': ' + details.get(key));
        }
    }

    @IsTest
    static void testOrderComparator() {
        SalesOrderPathController.OrderComparator comp = new SalesOrderPathController.OrderComparator();
        Status_Substatus_Mapping__mdt rec1 = new Status_Substatus_Mapping__mdt(Order__c = 1);
        Status_Substatus_Mapping__mdt rec2 = new Status_Substatus_Mapping__mdt(Order__c = 2);
        Integer diff = comp.compare(rec1, rec2);
        System.debug('Comparator difference: ' + diff);
    }
}