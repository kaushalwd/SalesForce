/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PreUnitCancellationValidator
 * Author          : Active Minds
 * Created Date    : Sep 6, 2026
 * Last Modified By: Active Minds
 * Last Modified On: Sep 6, 2026
 * Description     : StepValidator for the Business_Process__c "Unit Cancellation and Release
 *                    Process" flow. Blocks completing "Customer Bank Details Upload" when
 *                    Cancellation_Type__c = 'Cancellation with Refund' and the linked Account
 *                    is missing any bank detail.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Sep 6, 2026  │ Active Minds │   Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class PreUnitCancellationValidator implements StepValidator {

    public void ValidateSteps(Business_Process_Step__c bpStep) {

        switch on bpStep.Name {

            when 'Customer Bank Details Upload' {

                Business_Process__c bproc = [
                    SELECT Id, Cancellation_Type__c, Account__c
                    FROM Business_Process__c
                    WHERE Id = :bpStep.Business_Process__c
                ];

                if (bproc.Cancellation_Type__c == 'Cancellation with Refund') {

                    if (bproc.Account__c == null) {
                        throw new AuraHandledException(
                            'Bank details cannot be validated: no Account is linked to this Business Process.'
                        );
                    }

                    Account acc = [
                        SELECT Id, Bank_Name__c, Beneficiary_Name__c, Bank_Account_Number__c,
                               IBAN_Number__c, Bank_Branch_Name__c, Swift_Code__c, Bank_Country__c
                        FROM Account
                        WHERE Id = :bproc.Account__c
                    ];

                    List<String> missingFields = new List<String>();

                    if (String.isBlank(acc.Bank_Name__c))           missingFields.add('Bank Name');
                    if (String.isBlank(acc.Beneficiary_Name__c))    missingFields.add('Beneficiary Name');
                    if (String.isBlank(acc.Bank_Account_Number__c)) missingFields.add('Bank Account Number');
                    if (String.isBlank(acc.IBAN_Number__c))         missingFields.add('IBAN Number');
                    if (String.isBlank(acc.Bank_Branch_Name__c))    missingFields.add('Bank Branch Name');
                    if (String.isBlank(acc.Swift_Code__c))          missingFields.add('Swift Code');
                    if (String.isBlank(acc.Bank_Country__c))        missingFields.add('Bank Country');

                    if (!missingFields.isEmpty()) {
                        throw new AuraHandledException(
                            'Cannot complete Customer Bank Details Upload — the following bank details are missing on the Account: '
                            + String.join(missingFields, ', ') + '.'
                        );
                    }
                }
            }

            when else {

            }
        }
    }
}