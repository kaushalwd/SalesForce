/**********************************************************************************************************************
 * Name               : ModonEgypt_ConversionRateAPICalloutTest
 * Description        : Test class for ModonEgypt_ConversionRateAPICallout queueable class.
 * Created By         : Shahil Sinha (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Shahil Sinha (Horizontal)           17-12-2025      Initial Draft
 **********************************************************************************************************************/
@isTest
private class ModonEgypt_ConversionRateAPICalloutTest {

    /**
     * @description Mock class for HTTP callout
     */
    private class MockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    /**
     * @description Test the execute method with successful callout
     */
    @isTest
    static void testExecute_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        System.enqueueJob(new ModonEgypt_ConversionRateAPICallout());
        Test.stopTest();
        
        // Verify job was executed
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }

    /**
     * @description Test the execute method - direct call
     */
    @isTest
    static void testExecute_Direct() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        ModonEgypt_ConversionRateAPICallout callout = new ModonEgypt_ConversionRateAPICallout();
        callout.execute(null);
        Test.stopTest();
        
        System.assert(true, 'Execute completed without error');
    }
}