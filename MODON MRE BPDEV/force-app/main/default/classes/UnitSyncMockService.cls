/**********************************************************************************************************************
* Name        : UnitSyncMockService
* Description : Mock REST endpoint for unit sync integration testing.
* --------------------------------------------------------------------------------------------------------------------
* Version   Author    Date           Comment
* 1.0       -         -              Initial.
* 1.1       Jay Patel 21 Sep 2026    MCR-73 — createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/unitSyncMock/*')
global with sharing class UnitSyncMockService {

    @HttpPost
    global static void handleSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String responseBody;
        Integer statusCode;

        try {
            String rawBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(rawBody);

            String unitId = (String) payload.get('Id');
            String unitName = (String) payload.get('Name');
            String projectName = (String) payload.get('ProjectName');

            if (String.isBlank(unitId)) {
                statusCode = 400;
                responseBody = JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Missing required field: Id is required',
                    'id' => unitId,
                    'name' => unitName,
                    'status' => 'FAILED'
                });
            } else {
                // Mock "processing" — in a real OIC integration this is where
                // the payload would be validated and applied on their side.
                statusCode = 200;
                responseBody = JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'message' => 'Successfully updated for ' + unitId + ' record',
                    'id' => unitId,
                    'name' => unitName,
                    'status' => 'PROCESSED'
                });
            }
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Unit Sync Mock Service',
                'UnitSyncMockService',
                'handleSync'
            ));
            statusCode = 500;
            responseBody = JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Mock service error: ' + e.getMessage(),
                'id' => null,
                'name' => null,
                'status' => 'FAILED'
            });
        }

        res.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(responseBody);
    }
}