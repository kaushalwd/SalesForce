/**********************************************************************************************************************
* Name               : MBP_OracleSupplierBulkSyncBatch
* Description        : Pushes Broker Agency Accounts whose Oracle supplier sync has NOT succeeded yet to
*                      Oracle Fusion via OIC, using the existing
*                      MBP_OracleSupplierPayloadBuilder.buildSupplierJson(Account).
*                      Fire-and-forget: the response is not parsed and the Account is not updated.
* Criteria           : 1. RecordType = Broker Agency
*                      2. IsPartner  = true
*                      3. Either has a Closed 'Broker Registration' ServiceRequest__c (via
*                         Registration__r.Broker_Agency__c), OR has no Broker Registration SR at all.
*                         Agencies whose Broker Registration SR is still open are excluded.
*                      4. OIC_Supplier_Response__c is blank OR its Status is not SUCCESS
* Usage              : Database.executeBatch(new MBP_OracleSupplierBulkSyncBatch(), 5);
* Created By         : Upendra Reddy
**********************************************************************************************************************/
public class MBP_OracleSupplierBulkSyncBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private static final String SR_STATUS_CLOSED       = 'Closed';
    private static final String SR_RT_BROKER_REGISTRATION = 'Broker Registration';

    public Database.QueryLocator start(Database.BatchableContext bc) {

        Set<Id> closedSrAgencyIds = new Set<Id>();
        Set<Id> anySrAgencyIds    = new Set<Id>();

        for (ServiceRequest__c sr : [
            SELECT Status__c, Registration__r.Broker_Agency__c
            FROM ServiceRequest__c
            WHERE RecordType.Name = :SR_RT_BROKER_REGISTRATION
              AND Registration__r.Broker_Agency__c != null
        ]) {
            Id agencyId = sr.Registration__r.Broker_Agency__c;
            anySrAgencyIds.add(agencyId);
            if (sr.Status__c == SR_STATUS_CLOSED) {
                closedSrAgencyIds.add(agencyId);
            }
        }

        System.debug('Agencies with any Broker Registration SR   : ' + anySrAgencyIds.size());
        System.debug('Agencies with Closed Broker Registration SR: ' + closedSrAgencyIds.size());

        Id brokerAgencyRT = BRConstants.BROKER_AGENCY_RT;

        return Database.getQueryLocator([
            SELECT Id, Name, Agency_Status__c, VAT_Status__c, VAT_Certificate_Type__c,
                   BillingCity, BillingState, BillingStreet, BillingPostalCode, BillingCountry,
                   RecordTypeId, UAEVATRegisterNumber__c, LastModifiedDate, OIC_SUPPLIER_NUMBER__c,
                   Trade_License_Number__c, Trade_License_Status__c, TradeLicenseExpiryDate__c,
                   OIC_Supplier_Response__c
            FROM Account
            WHERE RecordTypeId = :brokerAgencyRT
              AND IsPartner = true
              AND (Id IN :closedSrAgencyIds OR Id NOT IN :anySrAgencyIds)
        ]);
    }

    // ---- Execute: skip already-successful, fire the rest -------------------------------------------------------
    public void execute(Database.BatchableContext bc, List<Account> scope) {

        List<OIC_Credential__mdt> credList = [
            SELECT Endpoint__c, Username__c, Password__c
            FROM OIC_Credential__mdt
            WHERE DeveloperName = 'MBP_BrokerSupplierIntegration'
            LIMIT 1
        ];

        if (credList.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'OIC Credential metadata MBP_BrokerSupplierIntegration not found');
            return;
        }

        OIC_Credential__mdt cred = credList[0];

        for (Account acc : scope) {

            // Response is long text (not filterable in SOQL), so the SUCCESS check happens here.
            if (isSuccessResponse(acc.OIC_Supplier_Response__c)) {
                continue;
            }

            try {
                String jsonBody = Test.isRunningTest()
                    ? '{"dummy":"supplier"}'
                    : MBP_OracleSupplierPayloadBuilder.buildSupplierJson(acc);

                // Fire and forget - response intentionally ignored.
                MBP_OracleIntegrationService.sendRequest(
                    cred.Endpoint__c,
                    jsonBody,
                    cred.Username__c,
                    cred.Password__c
                );

                System.debug('Bulk supplier sync sent | ' + acc.Id + ' | ' + acc.Name);

            } catch (Exception ex) {
                
                System.debug(LoggingLevel.ERROR,
                    'Bulk supplier sync failed to send | ' + acc.Id + ' | ' + ex.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(' Oracle Supplier Bulk Sync Batch completed');
    }

    // ---- Helper: true only when the stored OIC response has "Status" : "SUCCESS" (exact uppercase) -----------
    // Expected format:
    // [ { "SupplierSFID" : "001...", "SupplierId" : 3000..., ..., "Status" : "SUCCESS", "Message" : "" } ]
    private static final String SUCCESS_STATUS = 'SUCCESS';

    private static Boolean isSuccessResponse(String responseBody) {

        if (String.isBlank(responseBody)) {
            return false;
        }

        try {
            List<Object> jsonList = (List<Object>) JSON.deserializeUntyped(responseBody);
            if (jsonList.isEmpty()) {
                return false;
            }
            Map<String, Object> resMap = (Map<String, Object>) jsonList[0];

            return SUCCESS_STATUS.equals(String.valueOf(resMap.get('Status')));

        } catch (Exception ex) {
       
            return false;
        }
    }
}