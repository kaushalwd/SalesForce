@isTest
public class ChargeServiceTest {
    private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER { get { return 'Service_Request_Management_Property_Transfer_Title_Deed'; } }
    
    @isTest
    static void testChargeCreation() {
        
        Id prtyRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        
        Phase__c p=TestDataFactory.creatPhase();
            Unit__c u=TestDataFactory.createunit();
        u.Phase__c=p.id;
        update u;        
        SalesOrder__c soobj=TestDataFactory.createsalesOrder();
        soobj.Unit__c=u.id;
        update soobj;
        Test.starttest();
        ServiceRequest__c sr = TestDataFactory.createServiceRequest('Normal',prtyRecordTypeId);
        sr.SalesOrder__c=soobj.id;
        sr.UnitId__c=u.id;
        sr.NOC_Extension_Date__c=Date.today();
        sr.Is_NOC_Extended__c=True;
        update sr;
        Financial_Setup__c fs=new Financial_Setup__c();
        fs.Sub_Type__c ='Normal';
        fs.Type__c='NOC';
        fs.Value__c=2500;
        fs.Fee_Type__c='Amount';
        fs.SR_RecordType__c='Service_Request_Management_Property_Transfer_Title_Deed';
        fs.Phase__c=p.id;
        
        insert fs;
        Financial_Setup__c fs1=new Financial_Setup__c();
        fs1.Sub_Type__c ='Normal';
        fs1.Type__c='Extension Fee';
        fs1.Value__c=2500;
        fs1.Fee_Type__c='Amount';
        fs1.SR_RecordType__c='Service_Request_Management_Property_Transfer_Title_Deed';
        fs1.Phase__c=p.id;
        
        insert fs1;
        ChargeService.createChargesOnSR(new List<ServiceRequest__c>{ sr });
        Test.stopTest();
    }
}