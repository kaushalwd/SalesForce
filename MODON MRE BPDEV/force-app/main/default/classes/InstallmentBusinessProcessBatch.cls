/**********************************************************************************************************************
* Name               :  InstallmentBusinessProcessBatch
* Description        : Creates an "Installment Payment Verification" Business Process for each
*                       Sales Order Installment passed in, one at a time (batch size 1).
* Usage              : Database.executeBatch(new InstallmentBusinessProcessBatch(commentByInstallmentId, parentBusinessProcessId), 1);
* Created By         : Sivannarayana Peddireddi
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment
* 1.0           sivannaryana.p@modon.com     08-09-2026      Initial Draft
**********************************************************************************************************************/
public without sharing class InstallmentBusinessProcessBatch implements Database.Batchable<sObject> {

    // SalesOrderInstallments__c Id -> the Payment Readiness comment entered for it, copied onto
    // the created Business Process's Process_Comment__c.
    public Map<Id, String> commentByInstallmentId = new Map<Id, String>();
    public Id parentBusinessProcessId;

    public InstallmentBusinessProcessBatch(Map<Id, String> commentByInstallmentId, Id parentBusinessProcessId) {
        this.commentByInstallmentId = commentByInstallmentId;
        this.parentBusinessProcessId = parentBusinessProcessId;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Set<Id> installmentIds = commentByInstallmentId.keySet();

        return Database.getQueryLocator([
            SELECT Id
            FROM SalesOrderInstallments__c
            WHERE Id IN :installmentIds
        ]);
    }

    public void execute(Database.BatchableContext BC, List<SalesOrderInstallments__c> installmentList) {
        try {
            List<Process_Flow__c> pflow = [
                SELECT Id, Name
                FROM Process_Flow__c
                WHERE Active__c = true
                AND Name = 'Installment Payment Verification'
            ];

            if (pflow.isEmpty()) return;

            Map<Id, Id> businessProcessIdByInstallmentId = new Map<Id, Id>();

            for (SalesOrderInstallments__c installment : installmentList) {
                String businessProcessIdResult = CreateBusinessProcess.createPreRegistration(installment.Id, pflow[0].Id);
                try {
                    businessProcessIdByInstallmentId.put(installment.Id, (Id) businessProcessIdResult);
                } catch (Exception invalidIdEx) {
                    // createPreRegistration returned an error message instead of a record Id.
                }
            }

            if (!businessProcessIdByInstallmentId.isEmpty()) {
                Set<Id> installmentPaymentVerificationBpIds = new Set<Id>();
                for (Business_Process__c bp : [
                    SELECT Id
                    FROM Business_Process__c
                    WHERE Id IN :businessProcessIdByInstallmentId.values()
                    AND Type__c = 'Installment Payment Verification'
                ]) {
                    installmentPaymentVerificationBpIds.add(bp.Id);
                }

                List<SalesOrderInstallments__c> installmentsToUpdate = new List<SalesOrderInstallments__c>();
                List<Business_Process__c> businessProcessesToUpdate = new List<Business_Process__c>();
                for (Id installmentId : businessProcessIdByInstallmentId.keySet()) {
                    Id businessProcessId = businessProcessIdByInstallmentId.get(installmentId);
                    if (installmentPaymentVerificationBpIds.contains(businessProcessId)) {
                        installmentsToUpdate.add(new SalesOrderInstallments__c(
                            Id = installmentId,
                            Payment_Confirmation_Process__c = businessProcessId
                        ));

                        Business_Process__c bpUpdate = new Business_Process__c(
                            Id = businessProcessId,
                            Process_Comment__c = commentByInstallmentId.get(installmentId)
                        );
                        if (parentBusinessProcessId != null) {
                            bpUpdate.Parent_Business_Process__c = parentBusinessProcessId;
                        }
                        businessProcessesToUpdate.add(bpUpdate);
                    }
                }

                if (!installmentsToUpdate.isEmpty()) {
                    update installmentsToUpdate;
                }
                if (!businessProcessesToUpdate.isEmpty()) {
                    update businessProcessesToUpdate;
                }
            }

        } catch (DmlException e) {
            LoggerService.save(LoggerService.createApexLog(e, 'Installment Payment Verification BP Creation', 'InstallmentBusinessProcessBatch', 'execute'));
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, 'Installment Payment Verification BP Creation', 'InstallmentBusinessProcessBatch', 'execute'));
        }
    }

    public void finish(Database.BatchableContext BC) {
    }
}