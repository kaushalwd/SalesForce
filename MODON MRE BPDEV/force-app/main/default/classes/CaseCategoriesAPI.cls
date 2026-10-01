/**********************************************************************************************************************
* Name               : CaseCategoriesAPI
* Description        : Returns every Case_Config_Category__mdt record as a flat list of
*                       category / sub-vertical / AI instruction combinations. Consumed by the
*                       WhatsApp channel AI so it can categorize an inbound customer case.
* Usage              : GET /services/apexrest/getCaseCategories/
***********************************************************************************************************************/
@RestResource(urlMapping='/getCaseCategories/*')
global class CaseCategoriesAPI {

    global class CaseCategoryWrapper {
        global String category;
        global String subverticle;
        global String AIInstruction;

        global CaseCategoryWrapper(String category, String subverticle, String aiInstruction) {
            this.category = category;
            this.subverticle = subverticle;
            this.AIInstruction = aiInstruction;
        }
    }

    @HttpGet
    global static void getCaseCategories() {

        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());

        try {
            List<CaseCategoryWrapper> categories = new List<CaseCategoryWrapper>();

            for (Case_Config_Category__mdt cfg : Case_Config_Category__mdt.getAll().values()) {
                categories.add(new CaseCategoryWrapper(
                    cfg.MasterLabel,
                    cfg.Sub_Vertical__c,
                    cfg.AI_Instruction__c
                ));
            }

            APIResponse response = new APIResponse('success', requestId, categories, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;

        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'WhatsApp Case Categorization', 'CaseCategoriesAPI', 'getCaseCategories'
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