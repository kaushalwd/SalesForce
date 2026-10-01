/**********************************************************************************************************************
* Name               : UnitSyncConfigAPI
* Description        : UnitSyncConfigAPI to get the user and Bucket details
* Usage              : UnitSyncConfigAPI DPG External System
* Created By         : Arvind Kesharani
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                           Date            Description
* -------  -------------------------------- --------------- -------------------------------------------------------
* 1.0      Arvind Kesharani              14 July 2026         Initial Draft
* 1.1      Jay Patel                     21 Sep 2026          MCR-73 — USER_MODE SOQL, createApexLog
****************************************************************************************************/

@RestResource(urlMapping='/unitSyncConfigAPI/*')
global with sharing class UnitSyncConfigAPI {

    // POST /services/apexrest/unitSyncConfigAPI
    // Receives unit sync payload from OIC and returns success/status.

    @HttpPost
    global static void handleSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String responseBody;
        Integer statusCode;

        try {
            String rawBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(rawBody);

            String unitId   = (String) payload.get('Id');
            String unitName = (String) payload.get('Name');

            if (String.isBlank(unitId)) {
                statusCode   = 400;
                responseBody = JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Missing required field: Id is required',
                    'id'      => unitId,
                    'name'    => unitName,
                    'status'  => 'FAILED'
                });
            } else {
                statusCode   = 200;
                responseBody = JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'message' => 'Successfully updated for ' + unitId + ' record',
                    'id'      => unitId,
                    'name'    => unitName,
                    'status'  => 'PROCESSED'
                });
            }
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Unit Sync Config API',
                'UnitSyncConfigAPI',
                'handleSync'
            ));
            statusCode   = 500;
            responseBody = JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Error: ' + e.getMessage(),
                'id'      => null,
                'name'    => null,
                'status'  => 'FAILED'
            });
        }

        res.statusCode   = statusCode;
        res.responseBody = Blob.valueOf(responseBody);
    }

    // GET /services/apexrest/unitSyncConfigAPI/bucket/{bucketId}
    // GET /services/apexrest/unitSyncConfigAPI/user/{userId}
    // OIC calls these on-demand using the BucketId / BlockedFor Id
    // received in the POST payload to fetch full related record details.

    @HttpGet
    global static void getDetails() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        // Extract path relative to unitSyncConfigAPI regardless of
        // how many segments come before it (versioned vs unversioned URLs).
        // e.g. /services/apexrest/unitSyncConfigAPI/bucket/{id}
        //   or /services/apexrest/v57.0/unitSyncConfigAPI/bucket/{id}
        String uri          = req.requestURI;
        String relativePath = uri.substringAfter('unitSyncConfigAPI');
        // relativePath = '/bucket/{id}' or '/user/{id}'
        String[] parts      = relativePath.split('/');
        // parts: ['', 'bucket', '{id}']  → parts[1]=type, parts[2]=id

        if (parts.size() < 3 || String.isBlank(parts[1]) || String.isBlank(parts[2])) {
            res.statusCode   = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Invalid URL. Use /unitSyncConfigAPI/bucket/{id} or /unitSyncConfigAPI/user/{id}',
                'status'  => 'FAILED'
            }));
            return;
        }

        String type     = parts[1].toLowerCase();
        String recordId = parts[2];

        if (type == 'bucket') {
            getBucketDetails(recordId, res);
        } else if (type == 'user') {
            getUserDetails(recordId, res);
        } else {
            res.statusCode   = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Unknown type: ' + type + '. Use bucket or user.',
                'status'  => 'FAILED'
            }));
        }
    }

    // ─── Bucket Details ───────────────────────────────────────────────────────

    private static void getBucketDetails(String bucketId, RestResponse res) {
        try {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Bucket__c query
            List<Bucket__c> buckets = [
                SELECT Id, Name, Active__c, Bucket_Group_Id__c,
                       Number_of_units__c, Number_of_Users__c
                FROM Bucket__c
                WHERE Id = :bucketId
                WITH USER_MODE
                LIMIT 1
            ];

            if (buckets.isEmpty()) {
                res.statusCode   = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Bucket not found for Id: ' + bucketId,
                    'status'  => 'NOT_FOUND'
                }));
                return;
            }

            Bucket__c b  = buckets[0];
            res.statusCode   = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'status'  => 'PROCESSED',
                'message' => 'Bucket details retrieved for ' + bucketId,
                'data'    => new Map<String, Object>{
                    'Id'            => b.Id,
                    'Name'          => b.Name,
                    'Active'        => b.Active__c,
                    'BucketGroupId' => b.Bucket_Group_Id__c,
                    'NumberOfUnits' => b.Number_of_units__c,
                    'NumberOfUsers' => b.Number_of_Users__c
                }
            }));
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Unit Sync Config API',
                'UnitSyncConfigAPI',
                'getBucketDetails'
            ));
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => e.getMessage(),
                'status'  => 'FAILED'
            }));
        }
    }

    // ─── User Details (BlockedFor) ────────────────────────────────────────────

    private static void getUserDetails(String userId, RestResponse res) {
        try {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on User query
            List<User> users = [
                SELECT Id, FirstName, LastName, Email
                FROM User
                WHERE Id = :userId
                WITH USER_MODE
                LIMIT 1
            ];

            if (users.isEmpty()) {
                res.statusCode   = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'User not found for Id: ' + userId,
                    'status'  => 'NOT_FOUND'
                }));
                return;
            }

            User u           = users[0];
            res.statusCode   = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'status'  => 'PROCESSED',
                'message' => 'User details retrieved for ' + userId,
                'data'    => new Map<String, Object>{
                    'UserId'    => u.Id,
                    'FirstName' => u.FirstName,
                    'LastName'  => u.LastName,
                    'Email'     => u.Email
                }
            }));
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Unit Sync Config API',
                'UnitSyncConfigAPI',
                'getUserDetails'
            ));
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => e.getMessage(),
                'status'  => 'FAILED'
            }));
        }
    }
}