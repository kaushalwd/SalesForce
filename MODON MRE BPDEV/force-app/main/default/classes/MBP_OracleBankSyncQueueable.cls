/**********************************************************************************************************************
* Name               : MBP_OracleBankSyncQueueable
* Description        : Queueable class responsible for synchronizing Bank Account
*                      details from Salesforce Account to Oracle via OIC integration.
*                      Handles callouts, response parsing, and Account update logic
*                      including BankPartyId and BranchPartyId mapping.
* Usage              : Invoked from Trigger / Service Layer after Supplier sync
*                      to asynchronously push Bank details to Oracle system.
* Created By         : Upendra Reddy
**********************************************************************************************************************/

public class MBP_OracleBankSyncQueueable implements Queueable, Database.AllowsCallouts {

    private List<Account> accList;
    private Integer startIndex;

    private static final Integer CHUNK_SIZE = 50;

    public MBP_OracleBankSyncQueueable(List<Account> accounts, Integer startIndex) {
        this.accList = accounts;
        this.startIndex = startIndex;
    }

    public void execute(QueueableContext qc) {

        Integer endIndex = Math.min(startIndex + CHUNK_SIZE, accList.size());

        OIC_Credential__mdt cred = [
            SELECT Endpoint__c, Username__c, Password__c
            FROM OIC_Credential__mdt
            WHERE DeveloperName = 'MBP_BankIntegration'
            LIMIT 1
        ];

        List<Account> accountsToUpdate = new List<Account>();

        for (Integer i = startIndex; i < endIndex; i++) {

            Account acc = accList[i];
            Account accUpdate = new Account(Id = acc.Id);

            try {

                String jsonBody;

                if (Test.isRunningTest()) {
                    jsonBody = '{"test":"payload"}';
                } else {
                    jsonBody = MBP_OracleBankPayloadBuilder.buildBankJson(acc);
                }

                MBP_OracleIntegrationService.OracleResponseWrapper response =
                    MBP_OracleIntegrationService.sendRequest(
                        cred.Endpoint__c,
                        jsonBody,
                        cred.Username__c,
                        cred.Password__c
                    );

                accUpdate.OIC_Bank_Response__c =
                    String.isNotBlank(response.body)
                    ? response.body
                    : response.errorMessage;

                if (response.isSuccess) {

                    accUpdate.OIC_Bank_Sync_Status__c = 'Synced';

                    if (String.isNotBlank(response.body)) {

                        Object parsed = JSON.deserializeUntyped(response.body);

                        if (parsed instanceof List<Object>) {

                            List<Object> resList = (List<Object>) parsed;

                            if (!resList.isEmpty()) {

                                Map<String, Object> resMap = (Map<String, Object>) resList[0];

                                if (resMap.containsKey('BankPartyId')
                                    && String.isBlank(acc.OIC_BANK_PARTY_ID__c)) {

                                    accUpdate.OIC_BANK_PARTY_ID__c =
                                        String.valueOf(resMap.get('BankPartyId'));

                                    accUpdate.OIC_BANK_ID__c =
                                        String.valueOf(resMap.get('BankPartyId'));
                                }

                                if (resMap.containsKey('BranchPartyId')
                                    && String.isBlank(acc.OIC_BANK_BRANCH_PARTY_ID__c)) {

                                    accUpdate.OIC_BANK_BRANCH_PARTY_ID__c =
                                        String.valueOf(resMap.get('BranchPartyId'));
                                }
                            }
                        }
                    }

                } else {
                    accUpdate.OIC_Bank_Sync_Status__c = 'Failed';
                }

                accountsToUpdate.add(accUpdate);

            } catch (Exception ex) {

                accUpdate.OIC_Bank_Sync_Status__c = 'Failed';
                accUpdate.OIC_Bank_Response__c = ex.getMessage();

                accountsToUpdate.add(accUpdate);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }

        if (endIndex < accList.size()) {

            System.enqueueJob(
                new MBP_OracleBankSyncQueueable(accList, endIndex)
            );
        }
    }
}