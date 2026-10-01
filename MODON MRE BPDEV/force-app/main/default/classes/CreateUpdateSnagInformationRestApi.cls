@RestResource(urlMapping='/createUpdateSnagInformation/*')
global with sharing class CreateUpdateSnagInformationRestApi {

    @HttpPost
    global static CreateUpdateSnagInformationDtos.ApiResponseWrapper doPost() {
        RestRequest req = RestContext.request;
        String uri = req.requestURI != null ? req.requestURI.toLowerCase() : '';
        String requestBody = req.requestBody != null ? req.requestBody.toString() : '';

        if (uri.endsWith('/createsnaginformation')) {
            return CreateUpdateSnagInformationService.createSnagInformation(requestBody);
        } else if (uri.endsWith('/createdesnaginformation')) {
            return CreateUpdateSnagInformationService.createDeSnagInformation(requestBody);
        } else {
            CreateUpdateSnagInformationDtos.ApiResponseWrapper res =
                new CreateUpdateSnagInformationDtos.ApiResponseWrapper();

            res.status = 'Error';
            res.message = 'Invalid POST endpoint';
            res.errors.add('Supported POST endpoints: /createSnagInformation, /createDeSnagInformation');
            RestContext.response.statusCode = 400;
            return res;
        }
    }
}