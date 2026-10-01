/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : LPC Process                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     22-07-2026      Initial Draft    
**********************************************************************************************************************/
public class LatePaymentChargesActivator implements StepActivator {

    private static final String STEP_VERIFY_REQUEST     = 'Verify Request';
    private static final String STEP_EXECUTE_WAIVER     = 'Collections Execute Waiver';

    private static final String STEP_CM_SENIOR_MANAGER = 'Approval from CM Senior Manager';
    private static final String STEP_CM_DIRECTOR       = 'Approval from CM Director';
    private static final String STEP_CCO               = 'Approval from CCO';
    private static final String STEP_CEO               = 'Approval from CEO';

    private static final Decimal MINIMUM_AMOUNT        = 100;

    public List<Business_Process_Step__c> activateNextSteps(
        Id stepId,
        List<Business_Process_Step__c> bpsList,
        Business_Process_Step__c previousStep,
        String nextStepOwnerID
    ) {
        List<Business_Process_Step__c> stepsToActivateList = new List<Business_Process_Step__c>();

        if (previousStep.Required_Info_Step__c != null) {
            stepsToActivateList.add(new Business_Process_Step__c(
                Id = previousStep.Required_Info_Step__c,
                Status__c = 'Provided Info'
            ));
        } else if (previousStep.Status__c == 'Completed') {

            Decimal lpcWaivedAmount = previousStep.Business_Process__r != null &&
                                      previousStep.Business_Process__r.LPCWaivedAmount__c != null
                                      ? previousStep.Business_Process__r.LPCWaivedAmount__c
                                      : 0;

            Business_Process_Step__c nextStep =
                getNextRequiredStep(previousStep, lpcWaivedAmount, bpsList);

            if (nextStep != null) {
                stepsToActivateList.add(prepareStepToOpen(nextStep));
            }
        }

        if (!stepsToActivateList.isEmpty()) {
            update stepsToActivateList;
        }

        return stepsToActivateList;
    }

    private static Business_Process_Step__c getNextRequiredStep(
        Business_Process_Step__c previousStep,
        Decimal lpcWaivedAmount,
        List<Business_Process_Step__c> bpsList
    ) {
        List<Business_Process_Step__c> sortedSteps = new List<Business_Process_Step__c>();
        sortedSteps.addAll(bpsList);
        sortedSteps.sort(new BusinessProcessStepSequenceComparator());

        // If Verify Request is completed and waiver amount is <= 100,
        // skip all approval steps and directly open Collections Execute Waiver.
        if (previousStep.Name == STEP_VERIFY_REQUEST && lpcWaivedAmount <= MINIMUM_AMOUNT) {
            return getStepByName(sortedSteps, STEP_EXECUTE_WAIVER);
        }

        Set<String> requiredApprovals = getRequiredApprovals(lpcWaivedAmount);

        for (Business_Process_Step__c step : sortedSteps) {

            if (step.Sequence__c <= previousStep.Sequence__c) {
                continue;
            }

            if (requiredApprovals.isEmpty()) {
                if (!isManagementApprovalStep(step.Name)) {
                    return step;
                }
                continue;
            }

            if (isManagementApprovalStep(step.Name)) {
                if (requiredApprovals.contains(step.Name)) {
                    return step;
                }
                continue;
            }

            return step;
        }

        return null;
    }

    private static Business_Process_Step__c getStepByName(
        List<Business_Process_Step__c> steps,
        String stepName
    ) {
        for (Business_Process_Step__c step : steps) {
            if (step.Name == stepName) {
                return step;
            }
        }
        return null;
    }

    private static Set<String> getRequiredApprovals(Decimal lpcWaivedAmount) {

        Set<String> requiredApprovals = new Set<String>();

        if (lpcWaivedAmount <= MINIMUM_AMOUNT) {
            return requiredApprovals;
        }

        requiredApprovals.add(STEP_CM_SENIOR_MANAGER);

        if (lpcWaivedAmount > 25000) {
            requiredApprovals.add(STEP_CM_DIRECTOR);
        }

        if (lpcWaivedAmount > 100000) {
            requiredApprovals.add(STEP_CCO);
        }

        if (lpcWaivedAmount > 200000) {
            requiredApprovals.add(STEP_CEO);
        }

        return requiredApprovals;
    }

    private static Boolean isManagementApprovalStep(String stepName) {
        return stepName == STEP_CM_SENIOR_MANAGER ||
               stepName == STEP_CM_DIRECTOR ||
               stepName == STEP_CCO ||
               stepName == STEP_CEO;
    }

    private static Business_Process_Step__c prepareStepToOpen(Business_Process_Step__c step) {
        Business_Process_Step__c stepToOpen = new Business_Process_Step__c();
        stepToOpen.Id = step.Id;

        if (step.Status__c == 'Required Info') {
            stepToOpen.Status__c = 'Provided Info';
        } else if (step.Re_Open_Count__c > 0) {
            stepToOpen.Status__c = 'Re Open';
        } else if (step.Assigned_To__c != null) {
            stepToOpen.Status__c = 'Accepted';
        } else {
            stepToOpen.Status__c = 'Open';
        }

        return stepToOpen;
    }

    public class BusinessProcessStepSequenceComparator implements Comparator<Business_Process_Step__c> {
        public Integer compare(Business_Process_Step__c a, Business_Process_Step__c b) {
            if (a.Sequence__c == b.Sequence__c) return 0;
            if (a.Sequence__c == null) return 1;
            if (b.Sequence__c == null) return -1;
            return a.Sequence__c < b.Sequence__c ? -1 : 1;
        }
    }
}