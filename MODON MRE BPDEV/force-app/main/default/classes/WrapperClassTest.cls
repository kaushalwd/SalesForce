@isTest
private class WrapperClassTest {

    @isTest
    static void testWrapperClassConstruction() {
        // Sample data for cls_cases
        Id caseId = Id.valueOf('500000000000001');
        String email = 'test@example.com';
        String unitName = 'Unit A';
        String accountName = 'Account X';
        Date closedDate = Date.today();
        String typeService = 'Maintenance';
        String recordType = 'Customer Support';
        String caseCategory = 'Technical';
        String caseSubCategory = 'HVAC';

        // Instantiate cls_cases
        WrapperClass.cls_cases caseWrapper = new WrapperClass.cls_cases(
            caseId,
            email,
            unitName,
            accountName,
            closedDate,
            typeService,
            recordType,
            caseCategory,
            caseSubCategory
        );

        // Assertions for cls_cases
        System.assertEquals(caseId, caseWrapper.extUniqueId, 'Case ID mismatch');
        System.assertEquals(email, caseWrapper.email, 'Email mismatch');
        System.assertEquals(unitName, caseWrapper.unitName, 'Unit name mismatch');
        System.assertEquals(accountName, caseWrapper.accountName, 'Account name mismatch');
        System.assertEquals(null, caseWrapper.closedTime, 'closedTime should be null due to constructor assignment');
        System.assertEquals(typeService, caseWrapper.typeService, 'TypeService mismatch');
        System.assertEquals(recordType, caseWrapper.recordType, 'RecordType mismatch');
        System.assertEquals(caseCategory, caseWrapper.CaseCategory, 'CaseCategory mismatch');
        System.assertEquals(caseSubCategory, caseWrapper.CaseSubCategory, 'CaseSubCategory mismatch');

        // Sample data for ServiceRequestWrapper
        Id srId = Id.valueOf('a0U000000000001');
        String srSalesOrder = 'SO-12345';

        WrapperClass.ServiceRequestWrapper srWrapper = new WrapperClass.ServiceRequestWrapper(
            srId,
            email,
            unitName,
            accountName,
            closedDate,
            typeService,
            srSalesOrder
        );

        // Assertions for ServiceRequestWrapper
        System.assertEquals(srId, srWrapper.extUniqueId, 'ServiceRequest ID mismatch');
        System.assertEquals(email, srWrapper.email, 'Email mismatch');
        System.assertEquals(unitName, srWrapper.unitName, 'Unit name mismatch');
        System.assertEquals(accountName, srWrapper.accountName, 'Account name mismatch');
        System.assertEquals(closedDate, srWrapper.closedTime, 'Closed date mismatch');
        System.assertEquals(typeService, srWrapper.typeService, 'Type service mismatch');
        System.assertEquals(srSalesOrder, srWrapper.salesOrder, 'Sales order mismatch');
    }
    
     @isTest
    static void testSalesOrderWrapperConstruction() {
        // ===== Test for SalesOrderWrapper =====
        Id soId = Id.valueOf('a01000000000001');
        String email = 'customer@example.com';
        String unitName = 'Villa 101';
        String accountName = 'John Doe';
        Date closedDate = Date.today();
        String salesType = 'Cash';
        String projectName = 'Modon Heights';
        String salesAssociate = 'Jane Smith';

        WrapperClass.SalesOrderWrapper soWrapper = new WrapperClass.SalesOrderWrapper(
            soId,
            email,
            unitName,
            accountName,
            closedDate,
            salesType,
            projectName,
            salesAssociate
        );

        System.assertEquals(soId, soWrapper.extUniqueId, 'SalesOrder ID mismatch');
        System.assertEquals(email, soWrapper.email, 'Email mismatch');
        System.assertEquals(unitName, soWrapper.unitname, 'Unit name mismatch');
        System.assertEquals(accountName, soWrapper.accountname, 'Account name mismatch');
        System.assertEquals(closedDate, soWrapper.closedtime, 'Closed time mismatch');
        System.assertEquals(salesType, soWrapper.salestype, 'Sales type mismatch');
        System.assertEquals(projectName, soWrapper.projectname, 'Project name mismatch');
        System.assertEquals(salesAssociate, soWrapper.salesasso, 'Sales associate mismatch');
    }
    
}