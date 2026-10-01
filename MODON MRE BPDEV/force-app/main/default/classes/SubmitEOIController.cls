/**-------------------------------------------------------------------
 * Description : A controller for submitEoiLwc Component
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Abdallah Hdaib   07-02-2024         Code Creation
 * v1.1         Arvind           15-04 - 2025         KYC Validation -EOI Range + quota per project field
 * -------------------------------------------------------------------
*/
public without sharing class SubmitEOIController {

    @AuraEnabled
    public static RespondWrap eoiSubmissionCheck(String requestWrapParam) {

        RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap = new RespondWrap();
        respWrap.result = '';

        Expressionofinterest__c eoi = [
            SELECT Id, Status__c, EOI_Amount_AED__c, Amount__c, Account__c
            FROM Expressionofinterest__c
            WHERE Id = :reqWrap.eoiId
        ];

        if (eoi == null) {
            respWrap.result = 'EOI record not found.';
            return respWrap;
        }

        // ── Check 1: Account / KYC (Signzy) — shown first ────────────────────
        if (eoi.Account__c != null) {

            Account accBase = [
                SELECT Id,
                       IsPersonAccount,
                       RecordType.DeveloperName,
                       KYC_Status__c,
                       KYC_Link_Status__c
                FROM Account
                WHERE Id = :eoi.Account__c
            ];

            String rtDevName = accBase.RecordType.DeveloperName;

            List<Account_Field_Validation__mdt> rules = [
                SELECT Field_API_Name__c, Field_Label__c
                FROM   Account_Field_Validation__mdt
                WHERE  Object_API_Name__c            = 'Account'
                AND    Record_Type_Developer_Name__c = :rtDevName
                AND    Is_Active__c                  = TRUE
            ];

            Set<String> fieldApiNames = new Set<String>{
                'Id', 'IsPersonAccount', 'RecordType.DeveloperName',
                'KYC_Status__c', 'KYC_Link_Status__c'
            };
            for (Account_Field_Validation__mdt rule : rules) {
                fieldApiNames.add(rule.Field_API_Name__c);
            }

            Id accId = eoi.Account__c;
            String soql = 'SELECT ' + String.join(new List<String>(fieldApiNames), ', ')
                        + ' FROM Account WHERE Id = :accId';
            Account acc = Database.query(soql);

            // ── 1a. PERSON ACCOUNT ────────────────────────────────────────────
            if (acc.IsPersonAccount) {

                // Step 1: Check if ALL metadata fields are filled
                Boolean allMetadataFieldsFilled = true;

                for (Account_Field_Validation__mdt rule : rules) {
                    Object fieldValue = acc.get(rule.Field_API_Name__c);
                    if (fieldValue == null || String.isBlank(String.valueOf(fieldValue))) {
                        allMetadataFieldsFilled = false;
                        break;
                    }
                }

                if (allMetadataFieldsFilled) {
                    // All metadata fields filled — allow submit, skip KYC

                } else {
                    // Metadata fields not filled — enforce KYC check
                    List<String> kycErrors = new List<String>();

                    if ((acc.KYC_Status__c == null || acc.KYC_Status__c != 'COMPLETED')
                            && (acc.KYC_Link_Status__c == null || acc.KYC_Link_Status__c != 'KYC Active')) {
                        kycErrors.add('Signzy KYC must be completed before submitting the EOI');
                    }

                    if (!kycErrors.isEmpty()) {
                        respWrap.result = 'Account KYC validation failed: '
                                        + String.join(kycErrors, ' & ') + '.';
                        return respWrap;
                    }
                }

            // ── 1b. ORG ACCOUNT ───────────────────────────────────────────────
            } else {

                List<String> missingFields = new List<String>();

                for (Account_Field_Validation__mdt rule : rules) {
                    Object fieldValue = acc.get(rule.Field_API_Name__c);
                    if (fieldValue == null || String.isBlank(String.valueOf(fieldValue))) {
                        missingFields.add(rule.Field_Label__c);
                    }
                }
                if (!missingFields.isEmpty()) {
                    respWrap.result = 'The following required Account field(s) are missing: '
                                    + String.join(missingFields, ', ') + '.';
                    return respWrap;
                }
            }
        }

        // ── Check 2: Signed document uploaded — shown second ──────────────────
        List<Documents__c> eoiDocs = [
            SELECT Id, Status__c, Name
            FROM Documents__c
            WHERE Expressionofinterest__c = :reqWrap.eoiId
            AND   Name IN ('Signed EOI Form')
        ];

        List<String> docNames = new List<String>();
        for (Documents__c doc : eoiDocs) {
            if (doc.Status__c != 'Uploaded') {
                docNames.add(doc.Name);
            }
        }
        if (!docNames.isEmpty()) {
            respWrap.result = 'Please upload the required signed documents: '
                            + String.join(docNames, ', ');
            return respWrap;
        }

        // ── Check 3: Payment receipt — shown third ────────────────────────────
        List<Receipt__c> receiptObj = [
            SELECT Id FROM Receipt__c
            WHERE Expressionofinterest__c = :reqWrap.eoiId
        ];
        if (receiptObj.isEmpty()
                && eoi.EOI_Amount_AED__c != null
                && eoi.EOI_Amount_AED__c != 0) {
            respWrap.result = 'Please make sure payment is created.';
            return respWrap;
        }

        // ── All checks passed ─────────────────────────────────────────────────
        respWrap.result = 'Success';
        return respWrap;
    }

    @AuraEnabled
    public static RespondWrap submitEoi(String requestWrapParam) {

        RequestWrap reqWrap = (RequestWrap) JSON.deserializeStrict(requestWrapParam, RequestWrap.class);
        RespondWrap respWrap = new RespondWrap();

        Expressionofinterest__c eoi = [
            SELECT Id, Status__c
            FROM Expressionofinterest__c
            WHERE Id = :reqWrap.eoiId
        ];

        if (eoi != null) {
            eoi.Status__c = 'Submitted';
            update eoi;

            Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
            request.setComments(reqWrap.comments);
            request.setObjectId(eoi.Id);
            request.setSubmitterId(UserInfo.getUserId());
            request.setProcessDefinitionNameOrId('EOI_Approval_Process');
            request.setSkipEntryCriteria(true);
            Approval.ProcessResult result = Approval.process(request);
        }
        return respWrap;
    }

    public class RequestWrap {
        @AuraEnabled public String eoiId;
        @AuraEnabled public String comments;
    }

    public class RespondWrap {
        @AuraEnabled public String result;
    }
}