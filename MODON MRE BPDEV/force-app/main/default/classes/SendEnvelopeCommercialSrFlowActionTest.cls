@IsTest
public class SendEnvelopeCommercialSrFlowActionTest {

    @IsTest
    static void testDeedSuccess() {

        SendEnvelopeCommercialSrFlowAction.isTestMode = true;

        SendEnvelopeCommercialSrFlowAction.Request req =
            new SendEnvelopeCommercialSrFlowAction.Request();

        req.serviceRequestId = UserInfo.getUserId();
        req.documentType = 'DEED';

        Test.startTest();
        List<SendEnvelopeCommercialSrFlowAction.Response> result =
            SendEnvelopeCommercialSrFlowAction.sendEnvelope(
                new List<SendEnvelopeCommercialSrFlowAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals('Success', result[0].status);
        System.assertEquals('TEST_DEED_ENVELOPE_ID', result[0].docuSignId);
    }

    @IsTest
    static void testNocSuccess() {

        SendEnvelopeCommercialSrFlowAction.isTestMode = true;

        SendEnvelopeCommercialSrFlowAction.Request req =
            new SendEnvelopeCommercialSrFlowAction.Request();

        req.serviceRequestId = UserInfo.getUserId();
        req.documentType = 'NOC';

        Test.startTest();
        List<SendEnvelopeCommercialSrFlowAction.Response> result =
            SendEnvelopeCommercialSrFlowAction.sendEnvelope(
                new List<SendEnvelopeCommercialSrFlowAction.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals('Success', result[0].status);
        System.assertEquals('TEST_NOC_ENVELOPE_ID', result[0].docuSignId);
    }

    @IsTest
    static void testInvalidDocumentType() {

        SendEnvelopeCommercialSrFlowAction.Request req =
            new SendEnvelopeCommercialSrFlowAction.Request();

        req.serviceRequestId = UserInfo.getUserId();
        req.documentType = 'INVALID';

        Test.startTest();
        List<SendEnvelopeCommercialSrFlowAction.Response> result =
            SendEnvelopeCommercialSrFlowAction.sendEnvelope(
                new List<SendEnvelopeCommercialSrFlowAction.Request>{ req }
            );
        Test.stopTest();
 
    }
}