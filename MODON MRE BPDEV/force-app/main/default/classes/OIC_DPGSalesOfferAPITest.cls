@isTest
public class OIC_DPGSalesOfferAPITest {

    @testSetup
    static void setupData() {
        // Create related project
        Project__c project = new Project__c(Name = 'Test Project66');
        insert project;

        Phase__c phase = new Phase__c(Name = 'Test Phase66', Project__c = project.Id);
        insert phase;
		
        Bucket__c obj_Bucket = new Bucket__c(Name = 'Online Sales');
        insert obj_Bucket;
        
        Unit__c unit = new Unit__c(
            Name = 'Unit 1',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = '2',
            FloorNumber__c = '5',
            TotalArea__c = 120.5,
            TotalGFAsqm__c = 100.0,
            TotalGrossSellableAreaGSA__c = 110.0,
            PlotAreasqm__c = 90.0,
            PlotNo__c = 'P-1236',
            MDPlotId__c = 'MD-0012',
            UnitClassification__c = 'Villa',
            Bucket__c = obj_Bucket.Id
        );
        insert unit;
    }

    @isTest
    static void testGenerateSalesOfferDPG_Success() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
		PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        // Create mock request body
        OIC_DPGSalesOfferAPI.SalesOfferRequest requestObj = new OIC_DPGSalesOfferAPI.SalesOfferRequest();
        requestObj.CustomerName = 'John Doe';
        requestObj.CustomerEmail = 'john@example.com';
        requestObj.Project = 'Proj123';
        requestObj.Unit = unit.Id;
        requestObj.UnitType = 'Type1';
        requestObj.Exterior = '';
        requestObj.PaymentPlan = paymentPlan.Id;
        requestObj.DPGInteractiveURL = 'http://test.com';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestBody = Blob.valueOf(JSON.serialize(requestObj));
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestURI = '/services/apexrest/dpg/generatesalesoffer';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGSalesOfferAPI.generateSalesOfferDPG();
        Test.stopTest();
		String responseBody = res.responseBody.toString();
       }
}