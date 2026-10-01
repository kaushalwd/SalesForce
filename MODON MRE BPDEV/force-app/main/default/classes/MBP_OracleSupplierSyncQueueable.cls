/**********************************************************************************************************************
* Name               : MBP_OracleSupplierSyncQueueable
* Description        : Queueable class responsible for synchronizing Salesforce Account
*                      (Supplier) data with Oracle via OIC integration.
*                      Handles callouts, response parsing, and Account update logic.
* Usage              : Invoked from Trigger / Service Layer to asynchronously
*                      sync Supplier data to Oracle system.
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com   11 Feb 2026      Initial Draft – Implemented Queueable framework with
*                                                              Database.AllowsCallouts for Oracle Supplier sync.
*                                                              Added payload generation, OIC credential retrieval,
*                                                              response parsing, and Account update handling.

**********************************************************************************************************************/


public class MBP_OracleSupplierSyncQueueable 
implements Queueable, Database.AllowsCallouts {

    private List<Account> accList;
    private Integer startIndex;

    private static final Integer CHUNK_SIZE = 50;

    public MBP_OracleSupplierSyncQueueable(List<Account> accounts, Integer startIndex) {
        this.accList = accounts;
        this.startIndex = startIndex;
    }

    public void execute(QueueableContext qc) {

     

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

        List<Account> accountsToUpdate = new List<Account>();

        Integer endIndex = Math.min(startIndex + CHUNK_SIZE, accList.size());

        for (Integer i = startIndex; i < endIndex; i++) {

            Account acc = accList[i];
            Account accUpdate = new Account(Id = acc.Id);

            try {

                String jsonBody = Test.isRunningTest()
                    ? '{"dummy":"supplier"}'
                    : MBP_OracleSupplierPayloadBuilder.buildSupplierJson(acc);

                MBP_OracleIntegrationService.OracleResponseWrapper response =
                    MBP_OracleIntegrationService.sendRequest(
                        cred.Endpoint__c,
                        jsonBody,
                        cred.Username__c,
                        cred.Password__c
                    );

                accUpdate.OIC_Supplier_Response__c = response.body;

                if (response.isSuccess) {

                    List<Object> jsonList =
                        (List<Object>) JSON.deserializeUntyped(response.body);

                    if (!jsonList.isEmpty()) {

                        Map<String, Object> resMap =
                            (Map<String, Object>) jsonList[0];

                        accUpdate.OIC_Supplier_Sync_Status__c = 'Synced';

                        accUpdate.OIC_Supplier_Vendor_ID__c =
                            String.valueOf(resMap.get('SupplierId'));

                        accUpdate.OIC_Supplier_Party_ID__c =
                            String.valueOf(resMap.get('SupplierPartyId'));

                        accUpdate.OIC_SUPPLIER_NUMBER__c =
                            String.valueOf(resMap.get('SupplierNumber'));

                        accUpdate.OIC_Supplier_Address_ID__c =
                            String.valueOf(resMap.get('SupplierAddressId'));

                        accUpdate.OIC_Supplier_Site_ID__c =
                            String.valueOf(resMap.get('SupplierSiteId'));
                    }
                    else {
                        accUpdate.OIC_Supplier_Sync_Status__c = 'Failed';
                    }

                } else {
                    accUpdate.OIC_Supplier_Sync_Status__c = 'Failed';
                }

                accountsToUpdate.add(accUpdate);

            } catch (Exception ex) {

                accUpdate.OIC_Supplier_Sync_Status__c = 'Failed';
                accUpdate.OIC_Supplier_Response__c = ex.getMessage();

                accountsToUpdate.add(accUpdate);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }

        if (endIndex < accList.size()) {

            System.enqueueJob(
                new MBP_OracleSupplierSyncQueueable(accList, endIndex)
            );
        }

        System.debug('🔵 Oracle Supplier Sync Queueable Completed');
    }
}