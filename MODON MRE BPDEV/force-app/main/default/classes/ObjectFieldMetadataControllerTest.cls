@isTest
public class ObjectFieldMetadataControllerTest {
    
    private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER { get { return 'Service_Request_Management_Property_Transfer_OffPlan'; } }
    
    @isTest
    static void testGetisActive() {
        Test.startTest();
        
        // Mock Metadata using Test.setMock
        //Test.setMock(System.StubProvider.class, new ObjectFieldMetadataMock());
        
        Boolean result = ObjectFieldMetadataController.getisActive('ServiceRequest__c');
        
        Test.stopTest();
        
        System.assertEquals(true, result, 'getisActive should return true for ServiceRequest__c');
    }
    
    @isTest
    static void testGetObjInfo_Valid() {
        Test.startTest();
        
        Id prprtyRec = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        
        
        ServiceRequest__c serviceRequest = TestDataFactory.createServiceRequest('Normal',prprtyRec);
        // Mock Metadata using Test.setMock
        //Test.setMock(System.StubProvider.class, new ObjectFieldMetadataMock());
        string objname='ServiceRequest__c';
        // Call method
        ObjectFieldMetadataController.FieldInfoWrapper result = ObjectFieldMetadataController.getObjInfo(objname, 'Property Transfer OffPlan', serviceRequest.Id);
        
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetRecordTypeData() {
        Test.startTest();
        
        
        Map<String, String> recordTypes = ObjectFieldMetadataController.getRecordTypeData();
        
        Test.stopTest();
        
        System.assertNotEquals(null, recordTypes, 'Record Type Data should not be null');
        System.assert(recordTypes.size() > 0, 'Record Type Data should contain at least one entry');
    }
    
    /*  // Mock class for ObjectField__mdt since we cannot insert metadata in tests
private class ObjectFieldMetadataMock implements System.StubProvider {
public Object handleMethodCall(
Object target,
String methodName,
System.Type returnType,
List<System.Type> paramTypes,
List<String> paramNames,
List<Object> paramValues
) {
if (methodName == 'query') {
List<ObjectField__mdt> mockData = new List<ObjectField__mdt>();
ObjectField__mdt mockRecord = (ObjectField__mdt) Test.createStub(ObjectField__mdt.class, new ObjectFieldMetadataMock());
mockRecord.Id = 'm001';
mockRecord.isActive__c = true;
mockRecord.Object_Name__c = 'ServiceRequest__c';
mockRecord.Object_Type__c='ServiceRequest__c';
mockRecord.Required_Fields__c = 'Name,Email';
mockRecord.Read_Only_Fields__c = 'Phone';
mockRecord.Related_Field_API_Names__c = 'Industry,Website';
mockData.add(mockRecord);
return mockData;
}
return null;
}
}
*/
    @isTest
    static void testGetObjInfo() {
        Test.startTest();
        Id prprtyRec = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        ServiceRequest__c serviceRequest = TestDataFactory.createServiceRequest('Normal',prprtyRec);
        
        
        //Test.setMock(System.StubProvider.class, new ObjectFieldMetadataMock());
        
        ObjectFieldMetadataController.FieldInfoWrapper result = ObjectFieldMetadataController.getObjInfo('ServiceRequest__c', 'Property Transfer OffPlan', serviceRequest.Id);
        
        
        
        //ObjectFieldMetadataController.FieldInfoWrapper nullRecordResult = ObjectFieldMetadataController.getObjInfo('ServiceRequest__c', SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER, null);
        
        //ObjectFieldMetadataController.FieldInfoWrapper nullObjectResult = ObjectFieldMetadataController.getObjInfo(null, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER, serviceRequest.Id);
        
        Test.stopTest();
    }
    
    @isTest
    static void test_getStatusToRecordTypeMap() {
        
        Test.startTest();
        
        // Case 1: Valid object name
        Map<String, String> result1 =
            ObjectFieldMetadataController.getStatusToRecordTypeMap('ServiceRequest__c');
        
        // Case 2: Invalid object name
        Map<String, String> result2 =
            ObjectFieldMetadataController.getStatusToRecordTypeMap('InvalidObject');
        
        // Case 3: Null input
        Map<String, String> result3 =
            ObjectFieldMetadataController.getStatusToRecordTypeMap(null);
        
        Test.stopTest();
    }
    
    @isTest
    static void testCheckExistingSR() {
        
        Id prprtyRec = Utility.getRecordTypeIdByDevName(
            ServiceRequest__c.SObjectType,
            SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER
        );
        
        SalesOrder__c so = TestDataFactory.createSalesOrder();
        
        Test.startTest();
        
        ObjectFieldMetadataController.checkExistingSR(
            so.Id,
            prprtyRec
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testCopyFilesToServiceRequest() {
        
        SalesOrder__c so = TestDataFactory.createSalesOrder();
        
        Account acc = new Account(
            Name = 'ABC'
        );
        insert acc;
        
        ServiceRequest__c sr = new ServiceRequest__c(
            AccountId__c = acc.Id
        );
        
        insert sr;
        
        Documents__c doc = new Documents__c(
            Name = 'Pre Unit Cancellation Approval Attachment',
            Service_Request__c = sr.Id
        );
        
        insert doc;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test Content')
        );
        
        insert cv;
        
        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        insert new ContentDocumentLink(
            LinkedEntityId = so.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        Test.startTest();
        
        ObjectFieldMetadataController.copyFilesToServiceRequest(
            so.Id,
            sr.Id
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteUploadedFile() {
        
        ContentVersion cv = new ContentVersion(
            Title = 'DeleteFile',
            PathOnClient = 'DeleteFile.txt',
            VersionData = Blob.valueOf('Delete Me')
        );
        
        insert cv;
        
        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        Test.startTest();
        
        ObjectFieldMetadataController.deleteUploadedFile(
            cv.ContentDocumentId
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetReceiptAmounts() {
        
        SalesOrder__c so = TestDataFactory.createSalesOrder();
        Account acc = new Account(
            Name = 'ABC'
        );
        insert acc;
        
        Receipt__c admReceipt = new Receipt__c(
            SalesOrder__c = so.Id,
            Account__c = acc.Id,
            //AppliedAmount__c = 1000,
            Is_ADM_Fees_and_Dari_charges__c = true,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = System.today()
        );
        
        Receipt__c dpReceipt = new Receipt__c(
            SalesOrder__c = so.Id,
            Receipt_Amount__c = 5000,
            Account__c = acc.Id,
            Is_ADM_Fees_and_Dari_charges__c = false,
            //Milestone__c = 1,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = System.today()
        );
        
        insert new List<Receipt__c>{ admReceipt, dpReceipt };
            
            Test.startTest();
        
        ObjectFieldMetadataController.getReceiptAmounts(so.Id);
        
        Test.stopTest();
    }
    
    @isTest
static void testSaveConsolidationRecords() {

    Unit_Consolidation__c uc = new Unit_Consolidation__c();

    List<Unit_Consolidation__c> records =
        new List<Unit_Consolidation__c>{ uc };

    Test.startTest();

    try{
        ObjectFieldMetadataController.saveConsolidationRecords(records);
    }catch(Exception e){
        System.debug(e.getMessage());
    }

    Test.stopTest();
}
    
    @isTest
static void testGetRelatedSalesOrders() {

    Account acc = new Account(
        Name = 'Test Account'
    );
    insert acc;

    SalesOrder__c so1 = new SalesOrder__c(
        //Name = 'SO-1',
        CustomerAccount__c = acc.Id,
        Status__c = 'New'
        //ProjectName__c = 'Project A'
    );
    insert so1;

    SalesOrder__c so2 = new SalesOrder__c(
        //Name = 'SO-2',
        CustomerAccount__c = acc.Id,
        Status__c = 'New'
        //ProjectName__c = 'Project B'
    );
    insert so2;

    Test.startTest();

    ObjectFieldMetadataController.getRelatedSalesOrders(so1.Id);

    Test.stopTest();
}
    
}