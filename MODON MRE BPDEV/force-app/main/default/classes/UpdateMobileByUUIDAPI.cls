/* **
 * 1.0          Sivannarayana                               01 Jult 2026    Initial Draft
 * 1.1          Sivannarayana                               07 Jult 2026    User Update
 * 1.2          Jay Patel                                   21 Sep 2026    MCR-73 — USER_MODE SOQL/DML
 ****/
@RestResource(urlMapping='/updateMobileByUUID')
global with sharing class UpdateMobileByUUIDAPI {

    global class MobileUpdateRequest {
        public String uuid;
        public String mobile_number;
    }

    global class MobileUpdateResponse {
        public String uuid;
        public String status;
        public String message;
        public String user_id;
        public String contact_id;
        public String account_id;
    }

    @HttpPost
    global static void updateMobileNumber() {
        String requestBody = '';

        try {
            requestBody = RestContext.request.requestBody.toString();

            if (String.isBlank(requestBody)) {
                sendResponseAndLog(400, null, 'Failure', 'Request body is empty', null, null, null, requestBody);
                return;
            }

            MobileUpdateRequest req =
                (MobileUpdateRequest) JSON.deserialize(requestBody, MobileUpdateRequest.class);

            if (String.isBlank(req.uuid)) {
                sendResponseAndLog(400, null, 'Failure', 'UUID is required', null, null, null, requestBody);
                return;
            }

            if (String.isBlank(req.mobile_number)) {
                sendResponseAndLog(400, req.uuid, 'Failure', 'Mobile number is required', null, null, null, requestBody);
                return;
            }

            //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on User query
            List<User> users = [
                SELECT Id, ContactId, UUID__c
                FROM User
                WHERE UUID__c = :req.uuid
                WITH USER_MODE
                LIMIT 2
            ];

            if (users.isEmpty()) {
                sendResponseAndLog(404, req.uuid, 'Failure', 'No User found for the provided UUID', null, null, null, requestBody);
                return;
            }

            if (users.size() > 1) {
                sendResponseAndLog(400, req.uuid, 'Failure', 'Multiple Users found for the provided UUID', null, null, null, requestBody);
                return;
            }

            User usr = users[0];

            if (usr.ContactId == null) {
                sendResponseAndLog(400, req.uuid, 'Failure', 'User does not have ContactId', usr.Id, null, null, requestBody);
                return;
            }

            //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
            Contact con = [
                SELECT Id, AccountId, MobilePhone, En_MobilePhone__c
                FROM Contact
                WHERE Id = :usr.ContactId
                WITH USER_MODE
                LIMIT 1
            ];

            if (con.AccountId == null) {
                sendResponseAndLog(400, req.uuid, 'Failure', 'Contact does not have AccountId', usr.Id, con.Id, null, requestBody);
                return;
            }

            Savepoint sp = Database.setSavepoint();

            try {
                Contact conUpdate = new Contact(
                    Id = con.Id,
                    MobilePhone = req.mobile_number,
                    En_MobilePhone__c = req.mobile_number
                );
                //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact update
                Database.update(conUpdate, AccessLevel.USER_MODE);

                Account accUpdate = new Account(
                    Id = con.AccountId,
                    PersonMobilePhone = req.mobile_number,
                    En_MobilePhone__pc = req.mobile_number
                );
                //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Account update
                Database.update(accUpdate, AccessLevel.USER_MODE);
                
               updateUserPhone(usr.Id, req.mobile_number);

                sendResponseAndLog(
                    200,
                    req.uuid,
                    'Success',
                    'Mobile number updated successfully',
                    usr.Id,
                    con.Id,
                    con.AccountId,
                    requestBody
                );

            } catch (Exception dmlEx) {
                Database.rollback(sp);

                sendResponseAndLog(
                    500,
                    req.uuid,
                    'Failure',
                    'Failed to update mobile number: ' + dmlEx.getMessage(),
                    usr.Id,
                    con.Id,
                    con.AccountId,
                    requestBody
                );
            }

        } catch (Exception ex) {
            sendResponseAndLog(500, null, 'Failure', ex.getMessage(), null, null, null, requestBody);

            insert LoggerService.createApexLog(
                ex,
                'Update Mobile By UUID API',
                'UpdateMobileByUUIDAPI',
                'updateMobileNumber'
            );
        }
    }
    
    @future
public static void updateUserPhone(Id userId, String mobileNumber) {
    try {
        if (userId == null || String.isBlank(mobileNumber)) {
            return;
        }

        User userUpdate = new User(
            Id = userId,
            Phone = mobileNumber
        );

        //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on User update
        Database.update(userUpdate, AccessLevel.USER_MODE);

    } catch (Exception ex) {
        insert LoggerService.createApexLog(
            ex,
            'Update User Phone',
            'UpdateMobileByUUIDAPI',
            'updateUserPhone'
        );
    }
}

    private static void sendResponseAndLog(
        Integer statusCode,
        String uuid,
        String status,
        String message,
        String userId,
        String contactId,
        String accountId,
        String requestBody
    ) {
        MobileUpdateResponse response = new MobileUpdateResponse();
        response.uuid = uuid;
        response.status = status;
        response.message = message;
        response.user_id = userId;
        response.contact_id = contactId;
        response.account_id = accountId;

        String responseBody = JSON.serialize(response);

        insert LoggerService.createAPILog(
            'Update Mobile By UUID API',
            'UpdateMobileByUUIDAPI',
            'updateMobileNumber',
            requestBody,
            responseBody,
            'Status Code: ' + statusCode,
            'Inbound REST API'
        );

        sendResponse(statusCode, response);
    }

    private static void sendResponse(Integer statusCode, MobileUpdateResponse response) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
    }
}