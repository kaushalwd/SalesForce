/**********************************************************************************************************************
* Name               : CaseSearchByMobileAPI
* Description        : Retrieves existing Case records matching a given mobile number, checked
*                       against both Customer_Phone__c and Visitor_Phone_Search__c.
* Usage              : GET /services/apexrest/getCasesByMobileNumber/?mobileNumber=971501234567
***********************************************************************************************************************/
@RestResource(urlMapping='/getCasesByMobileNumber/*')
global class CaseSearchByMobileAPI {

    global class CaseSearchResult {
        global Integer totalSize;
        global List<Case> records;

        global CaseSearchResult(Integer totalSize, List<Case> records) {
            this.totalSize = totalSize;
            this.records = records;
        }
    }

    @HttpGet
    global static void getCasesByMobileNumber() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());

        try {
            String mobileNumber = req.params.get('mobileNumber');

            if (String.isBlank(mobileNumber)) {
                returnError(res, requestId, 'Missing mobileNumber parameter', 400);
                return;
            }

            mobileNumber = mobileNumber.replaceAll('[^0-9]', '');

            if (String.isBlank(mobileNumber)) {
                returnError(res, requestId, 'mobileNumber must contain digits', 400);
                return;
            }

            List<Case> cases = [
                SELECT Id, CaseNumber, Type, Status, Subject,
                       Customer_Phone__c, Visitor_Phone_Search__c,
                       Comments_Shared_with_Customer__c, CreatedDate
                FROM Case
                WHERE Customer_Phone__c = :mobileNumber
                   OR Visitor_Phone_Search__c = :mobileNumber
                ORDER BY CreatedDate DESC
                LIMIT 1000
            ];

            APIResponse response = new APIResponse(
                'success', requestId, new CaseSearchResult(cases.size(), cases), null
            );
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;

        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Case Search By Mobile API', 'CaseSearchByMobileAPI', 'getCasesByMobileNumber'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }

    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = status;
    }
}