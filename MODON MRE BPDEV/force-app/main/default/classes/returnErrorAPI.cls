public class returnErrorAPI {

    public static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = status;
    }
}