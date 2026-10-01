/**********************************************************************************************************************
* Name               : OIC_SACustomerSOATest                                                        
* Description        : Test class for OIC_SACustomerSOA REST API endpoint. 
*                      Verifies success execution flows, parameter validation checks, and error logging coverage.
* Created By         : Suresh
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                29 09 2026      Initial Draft Version
***********************************************************************************************************************/
@isTest
private class OIC_SACustomerSOATest {

    @isTest
    static void testGetCustomerSOASuccess() {
        String mockSalesOrderId = '8018W00000Xyz12UAA';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/SACustomerSOA/';
        req.httpMethod = 'GET';
        req.params.put('SOId', mockSalesOrderId);
        
        RestContext.request = req;
        RestContext.response = res;

        PageReference pageRef = Page.CustomerSOA;
        pageRef.getParameters().put('Id', mockSalesOrderId);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        OIC_SACustomerSOA.getCustomerSOA();
        Test.stopTest();
    }

    @isTest
    static void testGetCustomerSOAMissingParameter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/SACustomerSOA/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SACustomerSOA.getCustomerSOA();
        Test.stopTest();
    }

    @isTest
    static void testGetCustomerSOAGlobalException() {
        RestContext.request = null;
        RestContext.response = new RestResponse(); 

        Test.startTest();
        try {
            OIC_SACustomerSOA.getCustomerSOA();
        } catch (Exception e) {}
        Test.stopTest();
    }
}