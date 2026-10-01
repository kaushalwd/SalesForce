/**********************************************************************************************************************
* Name               : OIC_DPGBrokerUserAPI
* Description        : Returns Broker User Information based on User Id.
* Usage              : POST /services/apexrest/dpg/brokeruserinfo/
* Created By         : Modon
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       Modon    -              Initial.
* 2.0       Arvind   10 Jul 2026    Response handling delegated to OIC_RestResponse. BRK-xxx codes registered
*                                     dynamically. ContactId added to the SELECT (it was read but never queried,
*                                     throwing SObjectException on every broker user). Unknown / non-Id UserId
*                                     now returns 404 / 400 instead of 500. Profile.Name re-enabled.
* 3.0       Jay Patel 17 Sep 2026    MCR-73 — USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/brokeruserinfo/*')
global with sharing class OIC_DPGBrokerUserAPI {

    /* ====================================================================================
     *  ERROR CODES  (USR-001 / USR-002 / USR-004 already live in the shared registry)
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('BRK-001', 400, 'UserId is not a valid Salesforce Id.');
        OIC_RestResponse.define('BRK-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_INVALID_ID = 'BRK-001';
    private static final String ERR_UNEXPECTED = 'BRK-999';

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void getBrokerUserInfo() {
        try {
            RestRequest req = RestContext.request;

            if (req == null || req.requestBody == null || req.requestBody.size() == 0) {
                OIC_RestResponse.failure(OIC_RestResponse.INVALID_REQUEST_BODY).send();
                return;
            }

            Map<String, Object> input =
                (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

            String userId = (String) input.get('UserId');

            if (String.isBlank(userId)) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.MISSING_REQUIRED_FIELD, 'UserId is mandatory.'
                ).send();
                return;
            }

            // A malformed Id is the caller's fault -- a clean 400, not a 500.
            try {
                Id.valueOf(userId.trim());
            } catch (System.StringException se) {
                OIC_RestResponse.failure(ERR_INVALID_ID,
                    'Invalid UserId: "' + userId + '" is not a valid Salesforce Id.').send();
                return;
            }

            // ContactId was read below but never selected -- SObjectException on every hit.
            //3.0 MCR-73: Enforce CRUD/FLS via USER_MODE on User query
            List<User> users = [
                SELECT Id, Name, Username, Email, IsActive,
                       Profile.Name,
                       ContactId,
                       Contact.Broker_Type__c,
                       Contact.AccountId,
                       Contact.Account.Name
                FROM User
                WHERE Id = :userId
                WITH USER_MODE
                LIMIT 1
            ];

            if (users.isEmpty()) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.RECORD_NOT_FOUND, 'No User found for Id ' + userId
                ).send();
                return;
            }
            User usr = users[0];

            OIC_RestResponse res = OIC_RestResponse.success()
                .put('UserId',   usr.Id)
                .put('Name',     usr.Name)
                .put('Username', usr.Username)
                .put('Email',    usr.Email)
                .put('Profile',  (usr.Profile != null) ? usr.Profile.Name : null)
                .put('Active',   usr.IsActive)
                .put('IsBroker', usr.ContactId != null && String.isNotBlank(usr.Contact.Broker_Type__c));

            // Community users only. A standard User has no Contact, and a Contact may have
            // no Account -- v1.0 dereferenced Contact.Account.Name unguarded.
            if (usr.ContactId != null) {
                res.put('ContactId',   usr.ContactId)
                   .put('BrokerType',  usr.Contact.Broker_Type__c)
                   .put('AccountId',   usr.Contact.AccountId)
                   .put('AccountName', (usr.Contact.Account != null) ? usr.Contact.Account.Name : null);
            }

            res.flat().send();

        } catch (Exception ex) {
            //3.0 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Broker User API',
                'OIC_DPGBrokerUserAPI',
                'getBrokerUserInfo'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).send();
        }
    }
}