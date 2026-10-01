/**********************************************************************************************************************
* Name               : UnitSyncHandler
* Description        : UnitSyncHandler DPG External System for Real Time sync
* Usage              : UnitSyncHandler DPG External System
* Created By         : Arvind Kesharani
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                           Date            Description
* -------  -------------------------------- --------------- -------------------------------------------------------
* 1.0      Arvind Kesharani              14 July 2026         Initial Draft
* 1.1      Arvind Kesharani              23 July 2026         Switched from Queueable to @future(callout=true)
*                                                             so the DPG sync runs independently of the Queueable
*                                                             slot already consumed by UpdateUnitStatusQueueable.
*                                                             SyncJob inner class retained for direct testing only.
****************************************************************************************************/
public class UnitSyncHandler {

    private static final String ENDPOINT = 'callout:Loqate_Integration/XXMODON_DPG_UPDATE_UNIT/1.0/salesforce/updateUnit';

    // ─── Entry point called from the trigger handler ──────────────────────────
    // Uses @future(callout=true) instead of System.enqueueJob so the DPG sync
    // never competes with the Queueable slot already consumed by
    // UpdateUnitStatusQueueable. Zero changes needed to any other class.
    public static void handleTriggerEvent(List<Unit__c> newList, Map<Id, Unit__c> oldMap, Boolean isInsert) {
        Set<Id> unitIds = new Set<Id>();

        for (Unit__c u : newList) {
            if (isInsert) {
                unitIds.add(u.Id);
            } else if (hasRelevantChange(u, oldMap.get(u.Id))) {
                unitIds.add(u.Id);
            }
        }

        if (!unitIds.isEmpty()) {
            // @future accepts List<String>, not Set<Id> — convert here.
            List<String> unitIdList = new List<String>();
            for (Id i : unitIds) unitIdList.add(i);
            syncUnitsDPGAsync(unitIdList);
        }
    }

    private static Boolean hasRelevantChange(Unit__c newU, Unit__c oldU) {
        return newU.BasePrice__c != oldU.BasePrice__c
            || newU.TotalGrossSellableAreaGSA__c != oldU.TotalGrossSellableAreaGSA__c
            || newU.TotalGFAsqm__c != oldU.TotalGFAsqm__c
            || newU.TotalArea__c != oldU.TotalArea__c
            || newU.PlotAreasqm__c != oldU.PlotAreasqm__c
            || newU.Status__c != oldU.Status__c
            || newU.Phase__c != oldU.Phase__c
            || newU.Number_of_Bedrooms__c != oldU.Number_of_Bedrooms__c
            || newU.Name != oldU.Name
            || newU.Project_Name__c != oldU.Project_Name__c
            || newU.FloorNumber__c != oldU.FloorNumber__c
            || newU.BlockUntil__c != oldU.BlockUntil__c
            || newU.BlockedFor__c != oldU.BlockedFor__c
            || newU.Bucket__c != oldU.Bucket__c
            || newU.InventoryStatus__c != oldU.InventoryStatus__c
            || newU.Typology__c != oldU.Typology__c;
    }

    // ─── @future callout — runs independently of the Queueable slot ──────────
    // Salesforce allows up to 50 @future calls per transaction and they run
    // in their own async context with callout support, completely separate from
    // the Queueable governor limit. High-traffic safe: all unit IDs for a bulk
    // transaction are batched into a single @future call.
    @future(callout=true)
    public static void syncUnitsDPGAsync(List<String> unitIdStrings) {
        Set<Id> unitIds = new Set<Id>();
        for (String s : unitIdStrings) unitIds.add((Id) s);
        syncUnits(unitIds);
    }

    // ─── Core sync logic — shared by @future and SyncJob ─────────────────────
    public static void syncUnits(Set<Id> unitIds) {
        List<Unit__c> units = [
            SELECT Id, Name, BasePrice__c, TotalPrice__c, TotalGrossSellableAreaGSA__c, TotalGFAsqm__c,
                   TotalArea__c, PlotAreasqm__c, Status__c, Phase__c, Phase__r.Name,
                   Number_of_Bedrooms__c, Project_Name__c, FloorNumber__c,
                   BlockUntil__c, BlockedFor__c, BlockedFor__r.Email,
                   Bucket__c, Bucket__r.Name,
                   InventoryStatus__c, Typology__c
            FROM Unit__c
            WHERE Id IN :unitIds
        ];

        List<Logger__c> errorLogs = new List<Logger__c>();

        for (Unit__c u : units) {
            try {
                Map<String, Object> payload = new Map<String, Object>{
                    'Id'                        => u.Id,
                    'Name'                      => u.Name,
                    'Status'                    => u.Status__c,
                    'Phase'                     => u.Phase__r != null ? u.Phase__r.Name : null,
                    'Number_of_Bedrooms'        => u.Number_of_Bedrooms__c,
                    'ProjectName'               => u.Project_Name__c,
                    'FloorNumber'               => u.FloorNumber__c,
                    'BlockUntil'                => u.BlockUntil__c != null
                                                    ? u.BlockUntil__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                                                    : null,
                    'BlockedFor'                => u.BlockedFor__r != null ? u.BlockedFor__r.Email : null,
                    'BucketId'                  => u.Bucket__c,
                    'ShowUnitPrice'             => isBucketOnlineSales(
                                                    u.Bucket__c != null && u.Bucket__r != null
                                                        ? u.Bucket__r.Name : null),
                    'InventoryStatus'           => u.InventoryStatus__c,
                    'Typology'                  => u.Typology__c,
                    'BasePrice'                 => u.BasePrice__c,
                    'TotalPrice'                => u.TotalPrice__c,
                    'TotalGrossSellableAreaGSA' => u.TotalGrossSellableAreaGSA__c,
                    'TotalGFAsqm'               => u.TotalGFAsqm__c,
                    'TotalArea'                 => u.TotalArea__c,
                    'PlotAreasqm'               => u.PlotAreasqm__c
                };

                String serializedPayload = JSON.serialize(payload);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(ENDPOINT);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(serializedPayload);
                req.setTimeout(20000);

                Http http       = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Boolean success = (Boolean) body.get('success');
                    if (success == true) {
                        // Log successful sync for audit trail
                        errorLogs.add(LoggerService.createAPILog(
                            'UnitSync', 'UnitSyncHandler', 'syncUnits',
                            serializedPayload, res.getBody(),
                            String.valueOf(res.getStatusCode()) + ' ' + res.getStatus(),
                            'OIC Success Log'
                        ));
                    } else {
                        errorLogs.add(buildErrorLog(
                            'UnitSync', 'UnitSyncHandler', 'syncUnits',
                            serializedPayload, res.getBody(),
                            u.Id, (String) body.get('message'),
                            res.getStatusCode(), res.getStatus()
                        ));
                    }
                } else {
                    errorLogs.add(buildErrorLog(
                        'UnitSync', 'UnitSyncHandler', 'syncUnits',
                        serializedPayload, res.getBody(),
                        u.Id, 'Non-200 response from external system',
                        res.getStatusCode(), res.getStatus()
                    ));
                }

            } catch (Exception e) {
                errorLogs.add(buildErrorLog(
                    'UnitSync', 'UnitSyncHandler', 'syncUnits',
                    'Unit Id: ' + u.Id, null,
                    u.Id, e.getMessage(),
                    null, null
                ));
            }
        }

        if (!errorLogs.isEmpty()) {
            LoggerService.save(errorLogs);
        }
    }

    // ─── Safely compares bucket name to OnlineSalesBucket label ──────────────
    // Returns false instead of throwing if the label is missing in this sandbox.
    private static Boolean isBucketOnlineSales(String bucketName) {
        if (String.isBlank(bucketName)) return false;
        try {
            return bucketName == System.Label.OnlineSalesBucket;
        } catch (Exception e) {
            return false;
        }
    }

    // ─── Error log builder ────────────────────────────────────────────────────
    private static Logger__c buildErrorLog(String process, String cls, String method,
                                            String reqBody, String respBody,
                                            String sfid, String oicMsg,
                                            Integer httpCode, String httpStatus) {
        String statusCode   = httpCode != null ? String.valueOf(httpCode) + ' ' + httpStatus : 'EXCEPTION';
        String fullRespBody = 'SFID: ' + sfid + ' | OIC Msg: ' + oicMsg
                            + (String.isNotBlank(respBody) ? ' | Response: ' + respBody : '');
        return LoggerService.createAPILog(process, cls, method, reqBody, fullRespBody, statusCode, 'OIC Error Log');
    } //End 12.0

    // ─── SyncJob — retained for direct testing / manual execution only ────────
    // Not called from the trigger path. Use Workbench Apex Execute to test:
    //   System.enqueueJob(new UnitSyncHandler.SyncJob(new Set<Id>{ 'a03...' }));
    public class SyncJob implements Queueable, Database.AllowsCallouts {
        private Set<Id> unitIds;
        public SyncJob(Set<Id> unitIds) { this.unitIds = unitIds; }
        public void execute(QueueableContext context) {
            syncUnits(unitIds);
        }
    }
}