public class PaymentMilestoneExtentionValidator implements StepValidator {
    
    public void ValidateSteps(Business_Process_Step__c bpStep) {

        switch on bpStep.Name {

            when 'Verify Request' {

                Business_Process__c bp = [
                    SELECT Id,
                           Payment_Extension_Category__c,
                           Payment_Extension_Reason__c,
                           Payment_Extension_Date__c
                    FROM Business_Process__c
                    WHERE Id = :bpStep.Business_Process__c
                ];

                List<Business_Process_Documents__c> cmDocList = [
                    SELECT Id, Name, Business_Process__c,
                           (SELECT Id FROM ContentDocumentLinks)
                    FROM Business_Process_Documents__c
                    WHERE Business_Process__c = :bpStep.Business_Process__c
                    AND   Name = 'Proof of Request'
                ];

                // 🔥 Collect all errors
                List<String> errorMessages = new List<String>();

                if (bp.Payment_Extension_Category__c == null) {
                    errorMessages.add('• Please select a Payment Extension Category.');
                }

                if (bp.Payment_Extension_Date__c == null) {
                    errorMessages.add('• Please select a Payment Extension Date.');
                }

                if (bp.Payment_Extension_Reason__c == null) {
                    errorMessages.add('• Please provide a Payment Extension Reason.');
                }

                if (cmDocList.isEmpty() || cmDocList[0].ContentDocumentLinks.isEmpty()) {
                    errorMessages.add('• Please attach the Proof of Request document.');
                }

                // 🔥 Throw ALL errors at once
                if (!errorMessages.isEmpty()) {
                    throw new AuraHandledException(
                        'Please complete the following before proceeding:\n\n' +
                        String.join(errorMessages, '\n')
                    );
                }
            }
        }
    

            // ─────────────────────────────────────────────────────────────
            // STEP 2 : Approval from CM Director
            // Validate: Approval document must be attached
            // ─────────────────────────────────────────────────────────────
            /*when 'Approval from CM Director' {

                List<Business_Process_Documents__c> cmDocList = [
                    SELECT Id, Name, Business_Process__c,
                           (SELECT Id FROM ContentDocumentLinks)
                    FROM Business_Process_Documents__c
                    WHERE Business_Process__c = :bpStep.Business_Process__c
                    AND   Name = 'CM Director Approval Document'
                ];

                if (cmDocList.size() > 0 && cmDocList[0].ContentDocumentLinks.size() == 0) {
                    throw new AuraHandledException(
                        'Please attach the CM Director Approval Document before completing this step.'
                    );
                }
            }*/

            // ─────────────────────────────────────────────────────────────
            // STEP 3 : Approval from CCO
            // Validate: CCO approval document must be attached
            // ─────────────────────────────────────────────────────────────
            /*when 'Approval from CCO' {

                List<Business_Process_Documents__c> ccoDocList = [
                    SELECT Id, Name, Business_Process__c,
                           (SELECT Id FROM ContentDocumentLinks)
                    FROM Business_Process_Documents__c
                    WHERE Business_Process__c = :bpStep.Business_Process__c
                    AND   Name = 'CCO Approval Document'
                ];

                if (ccoDocList.size() > 0 && ccoDocList[0].ContentDocumentLinks.size() == 0) {
                    throw new AuraHandledException(
                        'Please attach the CCO Approval Document before completing this step.'
                    );
                }
            }*/

            // ─────────────────────────────────────────────────────────────
            // STEP 4 : Approval from CEO
            // Validate: CEO approval document must be attached
            // Only reached when category = 'Greater than 60 days'
            // ─────────────────────────────────────────────────────────────
            /*when 'Approval from CEO' {

                List<Business_Process_Documents__c> ceoDocList = [
                    SELECT Id, Name, Business_Process__c,
                           (SELECT Id FROM ContentDocumentLinks)
                    FROM Business_Process_Documents__c
                    WHERE Business_Process__c = :bpStep.Business_Process__c
                    AND   Name = 'CEO Approval Document'
                ];

                if (ceoDocList.size() > 0 && ceoDocList[0].ContentDocumentLinks.size() == 0) {
                    throw new AuraHandledException(
                        'Please attach the CEO Approval Document before completing this step.'
                    );
                }
            }*/

            // ─────────────────────────────────────────────────────────────
            // STEP 5 : Finance Verification
            // Validate: Extension letter document must be attached
            //           + Payment Extension Date must be filled
            // ─────────────────────────────────────────────────────────────
            /*when 'Finance Verification' {

                Business_Process__c bp = [
                    SELECT Id,
                           Payment_Extension_Date__c
                    FROM Business_Process__c
                    WHERE Id = :bpStep.Business_Process__c
                ];

                if (bp.Payment_Extension_Date__c == null) {
                    throw new AuraHandledException(
                        'Please provide the Payment Extension Date before completing Finance Verification.'
                    );
                }

                List<Business_Process_Documents__c> finDocList = [
                    SELECT Id, Name, Business_Process__c,
                           (SELECT Id FROM ContentDocumentLinks)
                    FROM Business_Process_Documents__c
                    WHERE Business_Process__c = :bpStep.Business_Process__c
                    AND   Name = 'Payment Extension Letter'
                ];

                if (finDocList.size() > 0 && finDocList[0].ContentDocumentLinks.size() == 0) {
                    throw new AuraHandledException(
                        'Please attach the Payment Extension Letter before completing Finance Verification.'
                    );
                }
            }

            // ─────────────────────────────────────────────────────────────
            // Default — no validation required for other steps
            // ─────────────────────────────────────────────────────────────
            when else {
                // No validation
            }
        }*/
    }

}