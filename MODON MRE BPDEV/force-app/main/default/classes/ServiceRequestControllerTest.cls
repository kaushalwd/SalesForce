@isTest
public class ServiceRequestControllerTest {
        private static final string SERVICE_REQUEST_RT_DEV_NAME_ADM { get { return 'Service_Request_Management_ADM'; } }
        private static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER { get { return 'Service_Request_Management_Property_Transfer_OffPlan'; } }

    @isTest
    static void testUpdateAccUnitOnOffPlanSR() {
  
        Test.startTest();
                 List<ServiceRequest__c> srList = [SELECT Id,SalesOrder__c, Unit_Name__c,Type__c,Transferred_Sales_Order__c,Transferred_SO_Account__c,
                                                   Transferred_SO_Opp__c,SR_OriginID__c,ProjectId__c,RecordTypeName__c,SalesOrder_Completed_Date__c, 
                                                   Dari_Application_Submitted_Date__c FROM ServiceRequest__c ];

        ServiceRequestContoller.updateAccUnitOnOffPlanSR(srList);
        Test.stopTest();   
    }
    
    @isTest
    static void testCreateNewServiceRequest() {
  
	Map<String, Id> ids = TestDataFactory.createTestData();
    // Fetch test data Ids
    	Id nonvipOrganizationaccountId = ids.get('nonvipOrganizationaccount');  
        Id vipOrganizationAccountId = ids.get('vipOrganizationAccount');  
        Id vipOrganizationcontactId = ids.get('vipOrganizationcontact');  
        Id testUnitId = ids.get('testUnit');  
        Id salesorderId = ids.get('SalesOrder'); 
        Id testOpportunityId = ids.get('testOpportunity'); 
        
        Unit__c testUnit = new Unit__c(Name = 'Test Unit234', PlotNo__c = '1098');
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = vipOrganizationAccountId,
            PrimaryContact__c = vipOrganizationcontactId,
            Opportunity__c = testOpportunityId,
            Unit__c = testUnit.Id
        );
        insert testSalesOrder;
        
        ServiceRequest__c sr = new ServiceRequest__c(
            Name__c = 'Test SR',
            Type__c = 'Next of Kin',
            SalesOrder__c = salesorderId,
            AccountId__c=nonvipOrganizationaccountId,
            DebitNoteAmount__c = 250,
            UnitId__c = testUnitId,
            Transferred_Sales_Order__c = testSalesOrder.Id
        );
        insert sr;
        
        Test.startTest();
                 List<ServiceRequest__c> srList = [SELECT Id,SalesOrder__c, Unit_Name__c,Type__c,Transferred_Sales_Order__c,Transferred_SO_Account__c,Transferred_SO_Opp__c,SR_OriginID__c,ProjectId__c,RecordTypeName__c,SalesOrder_Completed_Date__c, Dari_Application_Submitted_Date__c,AccountId__c,
                                                   UnitId__c, SubType__c,OpportunityId__c FROM ServiceRequest__c Where Transferred_Sales_Order__c != null];

        ServiceRequestContoller.createNewServiceReuest(srList, 'ServiceRequest__c');
        Test.stopTest();    
    }
    
    @isTest
    static void testUpdatePenalty() {
        Test.startTest();
         List<ServiceRequest__c> srList = [SELECT Id,SalesOrder__c, Unit_Name__c,Type__c,Transferred_Sales_Order__c,Transferred_SO_Account__c,
                                           Transferred_SO_Opp__c,SR_OriginID__c,ProjectId__c,RecordTypeName__c,SalesOrder_Completed_Date__c, 
                                           Dari_Application_Submitted_Date__c FROM ServiceRequest__c ];
        for (ServiceRequest__c sr : srList) {
            sr.Dari_Application_Number__c='8888';
            sr.Dari_Application_Submitted_Date__c = Date.today();
        }
        ServiceRequestContoller.updatePenality(srList, srList);
        Test.stopTest();
    }
    
@isTest
    static void testCreateNewServiceRequest2() {

        Test.startTest();
         List<ServiceRequest__c> srList = [SELECT Id,SalesOrder__c, Unit_Name__c,Type__c,Transferred_Sales_Order__c,Transferred_SO_Account__c,
                                           Transferred_SO_Opp__c,SR_OriginID__c,ProjectId__c,RecordTypeName__c,SalesOrder_Completed_Date__c, 
                                           Dari_Application_Submitted_Date__c FROM ServiceRequest__c Where SalesOrder__c <> null];
        
        ServiceRequestContoller.createNewServiceReuest(srList, 'ServiceRequest__c');
        Test.stopTest(); 
    }     
}