public class PaymentMilestoneExtentionActivator implements StepActivator { 
 
    private static final String CATEGORY_UP_TO_30_DAYS = 
        'Upto 30 days'; 
    private static final String CATEGORY_UP_TO_60_DAYS = 
        'Upto 60 days'; 
    private static final String CATEGORY_ABOVE_60_DAYS = 
        'Greater than 60 days'; 
 
    private static final String STEP_CFO_APPROVAL = 'CFO Approval'; 
    private static final String STEP_CCO_APPROVAL = 'CCO Approval'; 
    private static final String STEP_CEO_APPROVAL = 'CEO Approval'; 
 
    public List<Business_Process_Step__c> activateNextSteps( 
        Id stepId, 
        List<Business_Process_Step__c> bpsList, 
        Business_Process_Step__c previousStep, 
        String nextStepOwnerID 
    ) { 
        System.debug( 
            'PaymentMilestoneExtentionActivator.activateNextSteps called' 
        ); 
 
        List<Business_Process_Step__c> stepsToActivate = 
            new List<Business_Process_Step__c>(); 
 
        if (previousStep.Required_Info_Step__c != null) { 
            stepsToActivate.add( 
                new Business_Process_Step__c( 
                    Id = previousStep.Required_Info_Step__c, 
                    Status__c = 'Provided Info' 
                ) 
            ); 
        } else { 
            String category = getPaymentExtensionCategory(previousStep); 
 
            System.debug('Payment Extension Category: ' + category); 
            System.debug('Previous Step: ' + previousStep.Name); 
 
            Set<String> skipStepNames = getStepsToSkip(category); 
 
            System.debug('Steps to skip: ' + skipStepNames); 
 
            Decimal nextSequence = previousStep.Sequence__c + 1; 
 
            Map<Decimal, Business_Process_Step__c> stepsBySequence = 
                new Map<Decimal, Business_Process_Step__c>(); 
 
            for (Business_Process_Step__c step : bpsList) { 
                if (step.Sequence__c != null) { 
                    stepsBySequence.put(step.Sequence__c, step); 
                } 
            } 
 
            if (previousStep.Status__c == 'Completed') { 
                while (stepsBySequence.containsKey(nextSequence)) { 
                    Business_Process_Step__c nextStep = 
                        stepsBySequence.get(nextSequence); 
 
                    if (skipStepNames.contains(nextStep.Name)) { 
                        System.debug( 
                            'Skipping approval step: ' + nextStep.Name 
                        ); 
 
                        nextSequence++; 
                        continue; 
                    } 
 
                    Business_Process_Step__c stepToOpen = 
                        new Business_Process_Step__c( 
                            Id = nextStep.Id, 
                            Status__c = getActivationStatus(nextStep) 
                        ); 
 
                    stepsToActivate.add(stepToOpen); 
 
                    System.debug( 
                        'Activating next step: ' + stepToOpen 
                    ); 
 
                    break; 
                } 
            } 
        } 
 
        if (!stepsToActivate.isEmpty()) { 
            update stepsToActivate; 
        } 
 
        return stepsToActivate; 
    } 
 
    /** 
     * Dynamically calculates the payment extension category based on: 
     * 
     * Payment Extension No Of Days
     */ 
    private static String getPaymentExtensionCategory( 
        Business_Process_Step__c previousStep 
    ) { 
        if (previousStep.Business_Process__r == null) { 
            System.debug( 
                LoggingLevel.WARN, 
                'Business Process relationship is not available.' 
            ); 
            return ''; 
        } 
 
        Decimal numberOfExtensionDays = null;
        try {
            numberOfExtensionDays = previousStep.Business_Process__r.Payment_Extension_No_Of_Days__c;
        } catch (Exception ex) {
            // Not queried in SOQL
        }

        if (numberOfExtensionDays == null) {
            try {
                if (String.isNotBlank(previousStep.Business_Process__r.Payment_Extension_Category__c)) {
                    return previousStep.Business_Process__r.Payment_Extension_Category__c;
                }
            } catch (Exception ex) {
                // Not queried in SOQL
            }
            System.debug(
                LoggingLevel.WARN,
                'Payment Extension No Of Days and Category are blank.'
            );
            return '';
        }
 
        System.debug( 
            'Number of Extension Days: ' + numberOfExtensionDays 
        ); 
 
        /* 
         * Prevent negative extension days 
         * from being treated as a valid extension. 
         */ 
        if (numberOfExtensionDays < 0) { 
            System.debug( 
                LoggingLevel.WARN, 
                'Payment Extension No Of Days cannot be negative.' 
            ); 
            return ''; 
        } 
 
        if (numberOfExtensionDays <= 30) { 
            return CATEGORY_UP_TO_30_DAYS; 
        } 
 
        if (numberOfExtensionDays <= 60) { 
            return CATEGORY_UP_TO_60_DAYS; 
        } 
 
        return CATEGORY_ABOVE_60_DAYS; 
    } 
 
    private static Set<String> getStepsToSkip(String category) { 
        Set<String> skipStepNames = new Set<String>(); 
 
        if (category == CATEGORY_UP_TO_30_DAYS) { 
            skipStepNames.add(STEP_CFO_APPROVAL); 
            skipStepNames.add(STEP_CCO_APPROVAL); 
            skipStepNames.add(STEP_CEO_APPROVAL); 
 
        } else if (category == CATEGORY_UP_TO_60_DAYS) { 
            skipStepNames.add(STEP_CEO_APPROVAL); 
 
        } else if (category == CATEGORY_ABOVE_60_DAYS) { 
            // Full approval flow. No approvals are skipped. 
 
        } else { 
            System.debug( 
                LoggingLevel.WARN, 
                'Unable to determine the Payment Extension Category. ' + 
                'The full approval flow will be followed.' 
            ); 
        } 
 
        return skipStepNames; 
    } 
 
    private static String getActivationStatus( 
        Business_Process_Step__c step 
    ) { 
        if (step.Status__c == 'Required Info') { 
            return 'Provided Info'; 
        } 
 
        if ( 
            step.Re_Open_Count__c != null && 
            step.Re_Open_Count__c > 0 
        ) { 
            return 'Re Open'; 
        } 
 
        if (step.Assigned_To__c != null) { 
            return 'Accepted'; 
        } 
 
        return 'Open'; 
    } 
}