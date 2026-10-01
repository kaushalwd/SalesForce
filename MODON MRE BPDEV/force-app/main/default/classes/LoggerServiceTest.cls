@isTest
public class LoggerServiceTest {

    @isTest
    static void myTestMethod(){
        Logger__c loggerObj = new Logger__c();

        Test.startTest();
        	LoggerService.save((Logger__c) null);
        	LoggerService.save((List<Logger__c>) null);
        	LoggerService.save(loggerObj);
        	LoggerService.save(new List<Logger__c>{loggerObj});
        	LoggerService.createApexLog(new DMLException(), 'test', 'test', 'test');
            LoggerService.createApexLogforGenesys(new DMLException(), 'test', 'test', 'test','test');
            LoggerService.createAPILogforGenesys('test', 'test', 'test', 'test','test','test','test','test');
        	LoggerService.createAPILog('test', 'test', 'test', 'test','test','test','test');
        	LoggerService.createSendGridLog('test', 'test', 'test', 'test',1,'test');
            LoggerService.FlowExceptionRequest req = new LoggerService.FlowExceptionRequest();
            req.flowName = 'Test_Flow';
            req.faultErrorMessage = 'Test Fault Message';
            req.relatedRecordId = '001000000000000AAA';
            LoggerService.LogFlowException(new List<LoggerService.FlowExceptionRequest>{req});
            LoggerService.LogFlowException(null);
            LoggerService.LogFlowException(new List<LoggerService.FlowExceptionRequest>());
            LoggerService.FlowExceptionRequest nullNameReq = new LoggerService.FlowExceptionRequest();
            nullNameReq.faultErrorMessage = 'No flow name';
            LoggerService.LogFlowException(new List<LoggerService.FlowExceptionRequest>{nullNameReq});
        Test.stopTest();

        System.assert([SELECT Count() FROM Logger__c WHERE LogType__c = 'Flow Exception'] > 0, 'Flow Exception Logger record should be created');
    }

    @isTest
    static void testMobileLogMethods() {
        RestRequest restRequest = new RestRequest();
        restRequest.httpMethod = 'POST';
        restRequest.requestURI = '/services/apexrest/mobile/test';

        Exception testException;
        try {
            Integer boom = 1 / 0;
        } catch (Exception ex) {
            testException = ex;
        }

        Test.startTest();
        Logger__c mobileLogWithException = LoggerService.addMobileLog(
            restRequest, testException, 'error response', 500
        );
        Logger__c mobileLogWithoutException = LoggerService.updateMobileLog(
            new Logger__c(), restRequest, null, 'ok response', 200
        );
        Test.stopTest();

        System.assertEquals('Mobile Exception', mobileLogWithException.LogType__c);
        System.assertNotEquals(null, mobileLogWithException.Message__c);
        System.assertEquals('Mobile Exception', mobileLogWithoutException.LogType__c);
        System.assertEquals(null, mobileLogWithoutException.Message__c);
    }
}