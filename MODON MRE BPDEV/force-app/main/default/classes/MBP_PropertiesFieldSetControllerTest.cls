@isTest
private class MBP_PropertiesFieldSetControllerTest {

    @isTest
    static void testGetFieldSetColumnsSuccess() {
        Test.startTest();
        List<MBP_PropertiesFieldSetController.ColumnDef> columns = 
            MBP_PropertiesFieldSetController.getFieldSetColumns('Project__c', 'Properties_Fields');
        Test.stopTest();

        System.assertNotEquals(null, columns, 'Returned columns list should not be null');
        System.assert(columns.size() > 0, 'Expected at least one field in the field set');
        for (MBP_PropertiesFieldSetController.ColumnDef col : columns) {
            System.assertNotEquals(null, col.label, 'Column label should not be null');
            System.assertNotEquals(null, col.fieldName, 'Column fieldName should not be null');
        }
    }

    @isTest
    static void testMissingObjectNameAndFieldSetName() {
        Boolean exceptionThrown = false;
        try {
            MBP_PropertiesFieldSetController.getFieldSetColumns('', '');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.debug('Exception message: ' + ex.getMessage());
        }
        System.assert(exceptionThrown, 'AuraHandledException should be thrown when object and field set names are missing');
    }

    @isTest
    static void testInvalidObjectName() {
        Boolean exceptionThrown = false;
        try {
            MBP_PropertiesFieldSetController.getFieldSetColumns('InvalidObject', 'Properties_Fields');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.debug('Exception message: ' + ex.getMessage());
        }
        System.assert(exceptionThrown, 'AuraHandledException should be thrown for unknown object');
    }

    @isTest
    static void testInvalidFieldSetName() {
        Boolean exceptionThrown = false;
        try {
            MBP_PropertiesFieldSetController.getFieldSetColumns('Project__c', 'Nonexistent_FieldSet');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.debug('Exception message: ' + ex.getMessage());
        }
        System.assert(exceptionThrown, 'AuraHandledException should be thrown for missing field set');
    }

}