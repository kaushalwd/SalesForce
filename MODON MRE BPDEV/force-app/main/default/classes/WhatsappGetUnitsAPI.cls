/**********************************************************************************************************************
* Name        : WhatsappGetUnitsAPI
* Description : Returns sales orders for a customer by phone number for WhatsApp integration.
* Usage       : GET /services/apexrest/whatsappGetUnitsAPI/?phone=...
* --------------------------------------------------------------------------------------------------------------------
* Version   Author    Date           Comment
* 1.0       -         -              Initial.
* 1.1       Jay Patel 21 Sep 2026    MCR-73 — with sharing, USER_MODE SOQL
***********************************************************************************************************************/
@RestResource(urlMapping='/whatsappGetUnitsAPI/*')
global with sharing class WhatsappGetUnitsAPI {

    @HttpGet
    global static void findUnits() {
         RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String phone = req.params.get('phone');
            if (String.isBlank(phone)) {
                returnError(res, requestId, 'Missing phone parameter', 400);
                return;
            }

            if (String.isNotBlank(phone)){
                phone = SFGenesys_Services.sanitizePhoneNumber(phone);
            }
            system.debug('phone==>' + phone);
            //List<Account> accntLst = [SELECT Id FROM Account WHERE PersonMobilePhone = :phone  LIMIT 1];
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
            List<Account> accntLst = [
                SELECT Id 
                FROM Account 
                WHERE PersonMobilePhone LIKE :('%' + phone + '%') 
                WITH USER_MODE
                LIMIT 1
            ];
            system.debug('accntLst==>' + accntLst);
            if (accntLst == null) {
                returnError(res, requestId, 'No account exists for this phone number.', 200);
                return;
            }
            List<CommunityHomeControllerAPI.SalesOrderWrapper> communithomeCon =new List<CommunityHomeControllerAPI.SalesOrderWrapper>();
            
            String accountId;
            if(!accntLst.isEmpty()){
                accountId = accntLst[0].Id;
            }
            
            if(accountId != null){
                 communithomeCon = CommunityHomeControllerAPI.getSalesOrdersByCustomer(accountId, null, null);
            }else{
                returnError(res, requestId, 'There are no units available at this time.', 200);
                return;
            } 
           
            APIResponse response = new APIResponse('success', requestId, communithomeCon, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
         	} catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'WhatsApp Get Units API', 'WhatsappGetUnitsAPI', 'findUnits'
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