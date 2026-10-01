/**********************************************************************************************************************
* Name               : PreUnitCancellationActivator
* Description        : StepActivator for the Business_Process__c "Unit Cancellation and Release Process" flow
*                       (Cancellation_Type__c: Cancellation with Refund / without Refund / Consolidation Cancellation).
* Usage              : BP Framework — wired via Eligibility__mdt (Business_Process_Name__c =
*                       'Unit Cancellation and Release Process') and invoked by
*                       LwcApproveRejectBpstepController when a step on this flow is approved.
* Created By         : Active Minds
**********************************************************************************************************************/
public class PreUnitCancellationActivator implements StepActivator {

    private static final String STEP_CCO_APPROVAL             = 'CCO Approval';
    private static final String STEP_UNIT_REASSIGNMENT         = 'Unit Reassignment';
    private static final String STEP_BANK_DETAILS_UPLOAD       = 'Customer Bank Details Upload';
    private static final String STEP_CLO_APPROVAL              = 'CLO Approval';
    private static final String STEP_CFO_APPROVAL              = 'CFO Approval';
    private static final String STEP_DIRECT_DEBIT_CANCELLATION = 'Direct Debit Cancellation';
    private static final String STEP_FINANCIAL_EXECUTION       = 'Financial Execution';

    private static final String CANCELLATION_WITHOUT_REFUND = 'Cancellation without Refund';
    private static final String CANCELLATION_CONSOLIDATION  = 'Consolidation Cancellation';

    public List<Business_Process_Step__c> activateNextSteps(
        Id stepId, List<Business_Process_Step__c> bpsList, Business_Process_Step__c previousStep,
        String nextStepOwnerID) {

        List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();

        if (previousStep == null || previousStep.Business_Process__c == null) {
            return stepsToActivateList;
        }

        Business_Process__c bp = [
            SELECT Id, Cancellation_Type__c, Sales_Order__c, Status__c
            FROM Business_Process__c
            WHERE Id = :previousStep.Business_Process__c
            LIMIT 1
        ];

        // =====================================================================
        // WITHOUT REFUND: the process ends once Unit Reassignment is Completed —
        // close the Business Process and skip everything still Not Actioned.
        // =====================================================================
        if (STEP_UNIT_REASSIGNMENT.equals(previousStep.Name)
            && bp.Cancellation_Type__c == CANCELLATION_WITHOUT_REFUND) {

            // Flag the step as the process end and let the standard
            // Business_Process_Step__c trigger close the Business Process
            // (Status__c = 'Completed', End_Date__c, Total_Time__c rollups) —
            // the same mechanism every other flow's Is_Process_End__c uses.
            update new Business_Process_Step__c(Id = previousStep.Id, Is_Process_End__c = true);

            List<Business_Process_Step__c> stepsToSkip = new List<Business_Process_Step__c>();
            for (Business_Process_Step__c step : bpsList) {
                if (step.Sequence__c != null
                    && previousStep.Sequence__c != null
                    && step.Sequence__c > previousStep.Sequence__c
                    && step.Status__c == 'Not Actioned') {

                    stepsToSkip.add(new Business_Process_Step__c(Id = step.Id, Status__c = 'Skipped'));
                }
            }

            if (!stepsToSkip.isEmpty()) {
                update stepsToSkip;
            }

            return stepsToActivateList;
        }

        // =====================================================================
        // GENERIC SEQUENCE PROGRESSION (mirrors DefaultActivator) — suppressed for
        // Unit Reassignment, Customer Bank Details Upload and CFO Approval, since
        // those three are handled by the dedicated rules below instead of a plain
        // "sequence + 1" hop.
        // =====================================================================
        Boolean suppressSequenceHop =
            STEP_UNIT_REASSIGNMENT.equals(previousStep.Name) ||
            STEP_BANK_DETAILS_UPLOAD.equals(previousStep.Name) ||
            STEP_CFO_APPROVAL.equals(previousStep.Name);

        if (previousStep.Status__c == 'Completed' && !suppressSequenceHop) {
            for (Business_Process_Step__c step : bpsList) {
                if (step.Sequence__c == previousStep.Sequence__c + 1) {
                    stepsToActivateList.add(createStepToOpen(step, nextStepOwnerID));
                }
            }
        }

        // =====================================================================
        // CLO APPROVAL: only opens once BOTH CCO Approval and Customer Bank
        // Details Upload are Completed. Customer Bank Details Upload is opened
        // independently in parallel at BP-creation time (see
        // CancellationBusinessProcessController), not gated behind Unit
        // Reassignment, so this is the actual join point between the two tracks.
        // =====================================================================
        if (STEP_CCO_APPROVAL.equals(previousStep.Name) || STEP_BANK_DETAILS_UPLOAD.equals(previousStep.Name)) {

            Business_Process_Step__c ccoStep;
            Business_Process_Step__c bankStep;
            Business_Process_Step__c cloStep;

            for (Business_Process_Step__c step : bpsList) {
                if (STEP_CCO_APPROVAL.equals(step.Name)) {
                    ccoStep = step;
                } else if (STEP_BANK_DETAILS_UPLOAD.equals(step.Name)) {
                    bankStep = step;
                } else if (STEP_CLO_APPROVAL.equals(step.Name)) {
                    cloStep = step;
                }
            }

            Boolean ccoDone  = ccoStep  != null && ccoStep.Status__c  == 'Completed';
            Boolean bankDone = bankStep != null && bankStep.Status__c == 'Completed';

            // Consolidation Cancellation has no Bank Details Upload step in its
            // path, so CLO Approval opens as soon as CCO Approval is Completed —
            // in parallel with Unit Reassignment — instead of waiting on it.
            Boolean readyToOpenClo = (ccoDone && bankDone)
                || (ccoDone && bp.Cancellation_Type__c == CANCELLATION_CONSOLIDATION);

            if (readyToOpenClo && cloStep != null && cloStep.Status__c == 'Not Actioned') {
                stepsToActivateList.add(createStepToOpen(cloStep, nextStepOwnerID));
            }
        }

        // =====================================================================
        // DIRECT DEBIT CANCELLATION: auto-skipped if the Sales Order has no
        // active Direct Debit. Financial Execution always opens alongside it
        // (both share Setp_No 7 on the Process Flow configuration).
        // =====================================================================
        if (STEP_CFO_APPROVAL.equals(previousStep.Name) && previousStep.Status__c == 'Completed') {

            Business_Process_Step__c directDebitStep;
            Business_Process_Step__c financialExecStep;

            for (Business_Process_Step__c step : bpsList) {
                if (STEP_DIRECT_DEBIT_CANCELLATION.equals(step.Name)) {
                    directDebitStep = step;
                } else if (STEP_FINANCIAL_EXECUTION.equals(step.Name)) {
                    financialExecStep = step;
                }
            }

            Boolean hasActiveDirectDebit =
                bp.Sales_Order__c != null &&
                [SELECT COUNT() FROM DirectDebitRequest__c WHERE SalesOrder__c = :bp.Sales_Order__c AND isActive__c = true] > 0;

            if (directDebitStep != null) {
                if (hasActiveDirectDebit) {
                    stepsToActivateList.add(createStepToOpen(directDebitStep, nextStepOwnerID));
                } else {
                    stepsToActivateList.add(new Business_Process_Step__c(
                        Id = directDebitStep.Id,
                        Status__c = 'Skipped'
                    ));
                }
            }

            if (financialExecStep != null) {
                stepsToActivateList.add(createStepToOpen(financialExecStep, nextStepOwnerID));
            }
        }

        if (!stepsToActivateList.isEmpty()) {
            update stepsToActivateList;
        }

        return stepsToActivateList;
    }

    private Business_Process_Step__c createStepToOpen(Business_Process_Step__c step, String nextStepOwnerID) {
        Business_Process_Step__c stepToOpen = new Business_Process_Step__c();
        stepToOpen.Id = step.Id;

        if (step.Status__c == 'Required Info') {
            stepToOpen.Status__c = 'Provided Info';
        } else if (step.Re_Open_Count__c != null && step.Re_Open_Count__c > 0) {
            stepToOpen.Status__c = 'Re Open';
        } else if (step.Assigned_To__c != null) {
            stepToOpen.Status__c = 'Accepted';
        } else {
            stepToOpen.Status__c = 'Open';
        }

        if (nextStepOwnerID != null) {
            stepToOpen.Assigned_To__c = nextStepOwnerID;
            stepToOpen.Status__c = 'Accepted';
        }

        return stepToOpen;
    }
}