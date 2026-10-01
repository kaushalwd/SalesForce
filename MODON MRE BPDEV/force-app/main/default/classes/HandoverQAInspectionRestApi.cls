@RestResource(urlMapping='/qaSnagging/*')
Global class HandoverQAInspectionRestApi {
    /*
     * =========================================================
     * MAIN REST ENTRY METHODS
     * =========================================================
     */

    @HttpPost
    global static HandoverQAInspectionDtos.ApiResponseWrapper doPost() {
        RestRequest req = RestContext.request;
        String uri = req.requestURI != null ? req.requestURI.toLowerCase() : '';
        String requestBody = req.requestBody != null ? req.requestBody.toString() : '';

        if (uri.endsWith('/savesnaggingsection')) {
            return HandoverQAInspectionService.saveSnaggingSection(requestBody);
        } else if (uri.endsWith('/savedesnaggingsection')) {
            return HandoverQAInspectionService.saveDeSnaggingSection(requestBody);
        } else if (uri.endsWith('/createsnag')) {
            return HandoverQAInspectionService.createSnag(requestBody);
        } else {
            HandoverQAInspectionDtos.ApiResponseWrapper res = new HandoverQAInspectionDtos.ApiResponseWrapper();
            res.status = 'Error';
            res.message = 'Invalid POST endpoint';
            res.errors.add('Supported POST endpoints: /saveSnaggingSection, /saveDeSnaggingSection, /createSnag');
            RestContext.response.statusCode = 400;
            return res;
        }
    }

    @HttpPut
    global static HandoverQAInspectionDtos.ApiResponseWrapper doPut() {
        RestRequest req = RestContext.request;
        String uri = req.requestURI != null ? req.requestURI.toLowerCase() : '';
        String requestBody = req.requestBody != null ? req.requestBody.toString() : '';

        if (uri.endsWith('/updatesnag')) {
            return HandoverQAInspectionService.updateSnag(requestBody);
        } else {
            HandoverQAInspectionDtos.ApiResponseWrapper res = new HandoverQAInspectionDtos.ApiResponseWrapper();
            res.status = 'Error';
            res.message = 'Invalid PUT endpoint';
            res.errors.add('Supported PUT endpoint: /updateSnag');
            RestContext.response.statusCode = 400;
            return res;
        }
    }
}