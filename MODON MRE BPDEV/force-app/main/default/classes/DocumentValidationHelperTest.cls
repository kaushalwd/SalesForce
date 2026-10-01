@isTest
public class DocumentValidationHelperTest {

    @testSetup
    static void setup() {
        DirectDebitRequest__c ddRequest = new DirectDebitRequest__c(
            Approve__c = false,
            Reject__c = false,
            IsSubmitted__c = false
        );
        insert ddRequest;
        // Gateway__c defaults to UAEDDS, which directDebitDocumentValidation skips, and
        // No_New_FAB_Mandates refuses a FAB mandate on insert. So it is raised as UAEDDS and moved
        // across, with the record type alongside for UAEDDS_Record_Type_Matches_Gateway.
        update new DirectDebitRequest__c(
            Id = ddRequest.Id,
            Gateway__c = 'FAB Legacy',
            RecordTypeId = Schema.SObjectType.DirectDebitRequest__c
                .getRecordTypeInfosByDeveloperName().get('FAB_Legacy').getRecordTypeId()
        );
    }

    private static List<String> requiredNames() {
        return System.Label.DDDocumentNames.split(',');
    }

    private static DirectDebitRequest__c mandate() {
        return [SELECT Id, Gateway__c, Approve__c, Reject__c, IsSubmitted__c FROM DirectDebitRequest__c LIMIT 1];
    }

    /** Runs the validation as the before update trigger would, with only the given flag newly ticked. */
    private static DirectDebitRequest__c validate(DirectDebitRequest__c ddRequest, Schema.SObjectField flag) {
        DirectDebitRequest__c oldVersion = ddRequest.clone(true, true, false, false);
        ddRequest.put(flag, true);
        DocumentValidationHelper.directDebitDocumentValidation(
            new List<SObject>{ ddRequest },
            new Map<Id, SObject>{ ddRequest.Id => oldVersion },
            true
        );
        return ddRequest;
    }

    private static void uploadDocuments(Id ddRequestId, List<String> names) {
        List<Documents__c> docs = new List<Documents__c>();
        for (String name : names) {
            docs.add(new Documents__c(Name = name, Direct_Debit_Request__c = ddRequestId, Status__c = 'Uploaded'));
        }
        insert docs;
    }

    @isTest
    static void testDirectDebitDocGenerator() {
        DirectDebitRequest__c ddRequest = mandate();

        Test.startTest();
        DocumentValidationHelper.directDebitDocGenerator(new List<SObject>{ ddRequest });
        Test.stopTest();

        // One set from the after insert trigger in setup, one from the call above.
        Assert.areEqual(requiredNames().size() * 2,
                        [SELECT COUNT() FROM Documents__c WHERE Direct_Debit_Request__c = :ddRequest.Id]);
    }

    @isTest
    static void testApproveWithNoUploadedDocumentIsRefused() {
        // The generated documents are still Pending Upload, so none counts.
        Test.startTest();
        DirectDebitRequest__c ddRequest = validate(mandate(), DirectDebitRequest__c.Approve__c);
        Test.stopTest();

        Assert.isTrue(ddRequest.hasErrors(), 'approve must be refused without the documents');
        Assert.isTrue(ddRequest.getErrors()[0].getMessage().contains(requiredNames()[0]),
                      ddRequest.getErrors()[0].getMessage());
    }

    @isTest
    static void testRejectWithWrongDocumentIsRefused() {
        DirectDebitRequest__c ddRequest = mandate();
        uploadDocuments(ddRequest.Id, new List<String>{ 'Some Other Document' });

        Test.startTest();
        validate(ddRequest, DirectDebitRequest__c.Reject__c);
        Test.stopTest();

        Assert.isTrue(ddRequest.hasErrors(), 'an uploaded file with the wrong name does not satisfy the check');
        Assert.isTrue(ddRequest.getErrors()[0].getMessage().contains('You must attach the file'),
                      ddRequest.getErrors()[0].getMessage());
    }

    @isTest
    static void testSubmitWithAllDocumentsPasses() {
        DirectDebitRequest__c ddRequest = mandate();
        uploadDocuments(ddRequest.Id, requiredNames());

        Test.startTest();
        validate(ddRequest, DirectDebitRequest__c.IsSubmitted__c);
        Test.stopTest();

        Assert.isFalse(ddRequest.hasErrors(), String.valueOf(ddRequest.getErrors()));
    }

    @isTest
    static void testUntickedFlagsAreNotChecked() {
        DirectDebitRequest__c ddRequest = mandate();

        Test.startTest();
        // Not from the approve/reject action, so nothing is checked even with a flag ticked.
        DirectDebitRequest__c oldVersion = ddRequest.clone(true, true, false, false);
        ddRequest.Approve__c = true;
        DocumentValidationHelper.directDebitDocumentValidation(
            new List<SObject>{ ddRequest }, new Map<Id, SObject>{ ddRequest.Id => oldVersion }, false
        );
        Test.stopTest();

        Assert.isFalse(ddRequest.hasErrors());
    }

    @isTest
    static void testUaeddsMandateIsSkipped() {
        // UAEDDS collects its signed instrument through the bank, not these documents.
        DirectDebitRequest__c ddRequest = mandate();
        ddRequest.Gateway__c = 'UAEDDS';

        Test.startTest();
        validate(ddRequest, DirectDebitRequest__c.Approve__c);
        Test.stopTest();

        Assert.isFalse(ddRequest.hasErrors(), 'a UAEDDS mandate is never held back by the FAB document check');
    }
}