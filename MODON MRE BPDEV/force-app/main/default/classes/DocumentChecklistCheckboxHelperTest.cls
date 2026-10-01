@IsTest
private class DocumentChecklistCheckboxHelperTest {

    // Utility to create all related data
    private static Map<String, Id> createBaseData(Boolean resident) {
        Map<String, Id> ids = new Map<String, Id>();

        Phase__c phase = new Phase__c(Name='Phase A', Is_Reservation_Form_Required__c='Yes');
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit A',
            Phase__c = phase.Id,
            PlotNo__c = 'P-101',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert unit;


        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'John',
            LastName = 'Doe',
            PersonEmail = 'john@test.com',
            PersonMailingStreet = '123 Main',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'Country',
            PassfortApprovalStatus__pc = 'Approved'
        );
        insert acc;

        Contact con = new Contact(FirstName='Jane', LastName='Smith', Email='jsmith@test.com');
        insert con;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            PrimaryContact__c = con.Id,
            Unit__c = unit.Id,
            Sub_Status__c = 'Pending With Sales',
            Modeofpayment__c = 'Cash',
            PDC_Collected__c = 'Yes',
            UAE_Resident_Status__c = resident ? 'Resident' : 'Non-Resident',
            Is_Sales_Checklist_Completed__c = false
        );
        insert so;

        ids.put('acc', acc.Id);
        ids.put('con', con.Id);
        ids.put('so', so.Id);
        return ids;
    }

    @IsTest static void test_validateSalesTeamChecklistOnly() {
        Map<String, Id> data = createBaseData(true);
         Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'John',
            LastName = 'Doe',
            PersonEmail = 'john@test.com',
            PersonMailingStreet = '123 Main',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'Country',
            PassfortApprovalStatus__pc = 'Approved'
        );
        insert acc;
        
         
           Opportunity opp2 = new Opportunity(Name='Opp2', StageName='Prospecting', CloseDate=Date.today().addDays(2), AccountId = acc.Id);
            insert opp2;
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            //PrimaryContact__c = con.Id,
            //Unit__c = unit.Id,
            Sub_Status__c = 'Pending With Sales',
            Modeofpayment__c = 'Cash',
            PDC_Collected__c = 'Yes',
             Opportunity__c = opp2.Id,
            UAE_Resident_Status__c =  'Resident',
            Is_Sales_Checklist_Completed__c = false
        );
        insert so;

        insert new Documents__c(Name='passport', Status__c='Uploaded', Account__c=data.get('acc'),opportunity__c = opp2.Id);
        insert new Documents__c(Name='resident id', Status__c='Uploaded', Account__c=data.get('acc'),opportunity__c = opp2.Id);
        insert new Documents__c(Name='signed kyc and wealth form', Status__c='Uploaded', SalesOrder__c=data.get('so'),opportunity__c = opp2.Id);
        insert new Documents__c(Name='broker form', Status__c='Uploaded', SalesOrder__c=data.get('so'),opportunity__c = opp2.Id);
        insert new Documents__c(Name='reservation form', Status__c='Uploaded', SalesOrder__c=data.get('so'),opportunity__c = opp2.Id);

        Test.startTest();
        Boolean result = DocumentChecklistCheckboxHelper.validateSalesTeamChecklistOnly(data.get('so'));
        Test.stopTest();

    }

    @IsTest static void test_recordInsertionJSON() {
        Map<String, Id> data = createBaseData(true);

        insert new Documents__c(Name='passport document', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='emirates id document', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='signed kyc and wealth form', Status__c='Uploaded', SalesOrder__c=data.get('so'));

        Test.startTest();
        Map<String, List<Map<String, Object>>> checklist = DocumentChecklistCheckboxHelper.recordInsertionJSON(data.get('so'));
        Test.stopTest();

    }

    @IsTest static void test_generateDocumentChecklist() {
         Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'John',
            LastName = 'Doe',
            PersonEmail = 'john@test.com',
            PersonMailingStreet = '123 Main',
            PersonMailingCity = 'City',
            PersonMailingCountry = 'Country',
            PassfortApprovalStatus__pc = 'Approved'
        );
        insert acc;
        Account con = [SELECT PersonContactId FROM Account LIMIT 1];
        Documents__c doc1 = new Documents__c(Name='passport doc', Status__c='Uploaded',primaryContact__c = con.PersonContactId);
        Documents__c doc2 = new Documents__c(Name='passport doc', Status__c='Pending Upload');
        insert new List<Documents__c>{doc1, doc2};

        Map<String, Object> res1 = DocumentChecklistCheckboxHelper.generateDocumentChecklist('passport','Passport', new List<Documents__c>{doc1});
        Map<String, Object> res2 = DocumentChecklistCheckboxHelper.generateDocumentChecklist('passport','Passport', new List<Documents__c>{doc2});

    }

    @IsTest static void test_handleChecklist_singleId() {
        Map<String, Id> data = createBaseData(true);

        insert new Documents__c(Name='passport', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='resident id', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='signed kyc and wealth form', Status__c='Uploaded', SalesOrder__c=data.get('so'));
        insert new Documents__c(Name='broker form', Status__c='Uploaded', SalesOrder__c=data.get('so'));
        insert new Documents__c(Name='reservation form', Status__c='Uploaded', SalesOrder__c=data.get('so'));

        Test.startTest();
        DocumentChecklistCheckboxHelper.handleChecklist(data.get('so'));
        Test.stopTest();
    }

    @IsTest static void test_handleChecklist_existingAndInsert() {
        Map<String, Id> data = createBaseData(true);

        Document_Checklist__c existing = new Document_Checklist__c(
            Sales_Order__c=data.get('so'),
            Team__c='Sales',
            Approval_Status__c='In Progress'
        );
        insert existing;

        insert new Documents__c(Name='passport', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='resident id', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='signed kyc and wealth form', Status__c='Uploaded', SalesOrder__c=data.get('so'));
        insert new Documents__c(Name='broker form', Status__c='Uploaded', SalesOrder__c=data.get('so'));
        insert new Documents__c(Name='reservation form', Status__c='Uploaded', SalesOrder__c=data.get('so'));

        Test.startTest();
        DocumentChecklistCheckboxHelper.handleChecklist(new Set<Id>{data.get('so')});
        Test.stopTest();

    }

    @IsTest static void test_toApprovePath() {
        Map<String, Id> data = createBaseData(true);

        Document_Checklist__c dc = new Document_Checklist__c(
            Sales_Order__c=data.get('so'),
            Team__c='Sales',
            Approval_Status__c='Rejected'
        );
        insert dc;

        insert new Documents__c(Name='passport', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='resident id', Status__c='Uploaded', Account__c=data.get('acc'));
        insert new Documents__c(Name='signed kyc and wealth form', Status__c='Uploaded', SalesOrder__c=data.get('so'));
        insert new Documents__c(Name='broker form', Status__c='Uploaded', SalesOrder__c=data.get('so'));
        insert new Documents__c(Name='reservation form', Status__c='Uploaded', SalesOrder__c=data.get('so'));

        Test.startTest();
        DocumentChecklistCheckboxHelper.handleChecklist(new Set<Id>{data.get('so')});
        Test.stopTest();

        Document_Checklist__c afterUpdate = [SELECT Approval_Status__c FROM Document_Checklist__c WHERE Id=:dc.Id];
    }

    @IsTest static void test_recordInsertionJSON_personAccountFallback() {
    Map<String, Id> data = createBaseData(true);

    // Keep PrimaryContact__c — don’t null it out
    insert new Documents__c(Name='passport doc', Status__c='Uploaded', Account__c=data.get('acc'));

    Test.startTest();
    Map<String, List<Map<String, Object>>> result = DocumentChecklistCheckboxHelper.recordInsertionJSON(data.get('so'));
    Test.stopTest();

}

    @IsTest static void test_eidResidentBranch() {
        Map<String, Id> data = createBaseData(true);

        insert new Documents__c(Name='passport', Status__c='Uploaded', Account__c=data.get('acc'));

        Test.startTest();
        Map<String, List<Map<String, Object>>> result = DocumentChecklistCheckboxHelper.recordInsertionJSON(data.get('so'));
        Test.stopTest();

        Boolean found = false;
        for (Map<String, Object> item : result.get('Sales')) {
            if (String.valueOf(item.get('Remarks__c')).contains('Emirates ID not uploaded')) {
                found = true;
            }
        }
    }

    @IsTest static void test_generateDocumentChecklist_sentButNotUploaded() {
        Documents__c doc = new Documents__c(Name='passport pending', Status__c='Pending Upload');
        insert doc;

        Map<String, Object> res = DocumentChecklistCheckboxHelper.generateDocumentChecklist('passport','Passport', new List<Documents__c>{doc});
    }
/*
    @IsTest static void test_handleChecklist_fallbackOnRecordTypeMissing() {
        Map<String, Id> data = createBaseData(false);

        SalesOrder__c so2 = new SalesOrder__c(
            CustomerAccount__c=data.get('acc'),
            Sub_Status__c='Draft',
            Unit__c=data.get('so')
        );
        insert so2;

        Test.startTest();
        DocumentChecklistCheckboxHelper.handleChecklist(new Set<Id>{so2.Id});
        Test.stopTest();

        System.assert(true);
    }
*/
    private class DocumentChecklistController {
        public void handleStsUpdate(List<Document_Checklist__c> newList, Map<Id, SObject> oldMap) {}
    }
}