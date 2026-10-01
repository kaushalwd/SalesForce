/**********************************************************************************************************************
* Name               : JointOwnerKYCValidationTest
* Description        : Tests for JointOwnerTriggerHelper.checkJointOwnerKYC - the KYC gate applied when a
*                      Joint Owner is created from the standard record page.
* Usage              : Covers JointOwnerTriggerHelper.checkJointOwnerKYC / isEgyptRecord / parentsWithFiles
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date                Comment
* 1.0           rushi.patel@horizontal.com       22 September 2026   Initial Draft
*
* NOTE: JointOwnerTriggerHelper.bypassKYCCheck defaults to TRUE in test context so the existing test
*       classes that insert JointOwner__c records are unaffected. Every test here that exercises the
*       gate must set it to FALSE explicitly - see setGateActive() below.
******************************************************************************************************************/
@isTest
private class JointOwnerKYCValidationTest {

    private static final String DOC_KYC_FORM  = 'KYC Form - Signed';
    private static final String DOC_PASSPORT  = 'Passport';
    private static final String DOC_EID_FRONT = 'Emirates/National ID Front';
    private static final String DOC_EID_BACK  = 'Emirates/National ID Back';
    private static final String DOC_TRADE_LIC = 'Commercial trade License (Resident)';

    private static final String NATIONALITY   = 'United Arab Emirates';

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /** The gate is bypassed by default in tests. Turn it on for the cases that assert its behaviour. */
    private static void setGateActive(){
        JointOwnerTriggerHelper.bypassKYCCheck = false;
    }

    private static Id personRecordTypeId(){
        return [SELECT Id FROM RecordType
                WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id;
    }

    private static Account newPersonAccount(String lastName, Date kycDate,
                                            String nationality, String residentStatus,
                                            String manualApproval){
        Account acc = new Account(
            FirstName              = 'Test',
            LastName               = lastName,
            RecordTypeId           = personRecordTypeId(),
            KYC_Completed_Date__c  = kycDate,
            Manual_KYC_Approval__c = manualApproval
        );
        acc.put('Nationality__pc', nationality);
        acc.put('UAE_Resident_Status__pc', residentStatus);
        insert acc;
        return acc;
    }

    /**
     * Organization accounts are deliberately created with NO KYC data. Corporate
     * KYC is read from the Power of Attorney contact, not the account, so leaving
     * the account blank proves the gate is reading the right record.
     */
    private static Account newOrgAccount(String name){
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    private static Id personContactId(Id accountId){
        return [SELECT PersonContactId FROM Account WHERE Id = :accountId].PersonContactId;
    }

    private static Opportunity newOpportunity(String sourceEntity){
        Opportunity opp = new Opportunity(
            Name      = 'Test opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.today()
        );
        if(String.isNotBlank(sourceEntity)){
            opp.Source_Entity__c = sourceEntity;
        }
        insert opp;
        return opp;
    }

    /**
     * Creates the Documents__c records. fileMode drives what is attached:
     *   'file'       -> ContentVersion / ContentDocumentLink (the primary path)
     *   'attachment' -> classic Attachment (the fallback path in parentsWithFiles)
     *   'none'       -> record exists but holds no file, which must FAIL the gate
     */
    private static void createDocs(Id contactId, Id accountId, List<String> docNames, String fileMode){
        List<Documents__c> docs = new List<Documents__c>();
        for(String docName : docNames){
            docs.add(new Documents__c(
                Name             = docName,
                PrimaryContact__c = contactId,
                Account__c        = accountId
            ));
        }
        insert docs;

        if(fileMode == 'none'){ return; }

        if(fileMode == 'attachment'){
            List<Attachment> atts = new List<Attachment>();
            for(Documents__c doc : docs){
                atts.add(new Attachment(
                    ParentId = doc.Id,
                    Name     = 'test.pdf',
                    Body     = Blob.valueOf('test content')
                ));
            }
            insert atts;
            return;
        }

        // Salesforce Files path
        List<ContentVersion> versions = new List<ContentVersion>();
        for(Integer i = 0; i < docs.size(); i++){
            versions.add(new ContentVersion(
                Title         = 'Test File ' + i,
                PathOnClient  = 'test' + i + '.pdf',
                VersionData   = Blob.valueOf('test content')
            ));
        }
        insert versions;

        Map<Id, Id> contentDocByVersion = new Map<Id, Id>();
        for(ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versions]){
            contentDocByVersion.put(cv.Id, cv.ContentDocumentId);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for(Integer i = 0; i < docs.size(); i++){
            links.add(new ContentDocumentLink(
                ContentDocumentId = contentDocByVersion.get(versions[i].Id),
                LinkedEntityId    = docs[i].Id,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }
        insert links;
    }

    private static JointOwner__c buildJointOwner(Id accountId, Id opportunityId){
        return new JointOwner__c(
            JointOwnerAccount__c   = accountId,
            Opportunity__c         = opportunityId,
            OwnershipPercentage__c = 10,
            RelationshipType__c    = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
    }

    /** Inserts and asserts the gate blocked it with a message containing expectedFragment. */
    private static void assertBlocked(JointOwner__c jo, String expectedFragment){
        Boolean blocked = false;
        String actualMessage = '';
        try {
            insert jo;
        } catch (DmlException e){
            blocked = true;
            actualMessage = e.getMessage();
        }
        System.assertEquals(true, blocked, 'Expected the KYC gate to block this joint owner.');
        System.assertEquals(true, actualMessage.contains(expectedFragment),
            'Expected message to contain "' + expectedFragment + '" but got: ' + actualMessage);
    }

    // ------------------------------------------------------------------
    // Person Account - happy paths
    // ------------------------------------------------------------------

    @isTest
    static void personAccountNonResidentWithAllDocsSucceeds(){
        Account acc = newPersonAccount('NonResPass', System.today(), NATIONALITY, 'Non-Resident', null);
        Opportunity opp = newOpportunity(null);
        createDocs(personContactId(acc.Id), null,
                   new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'file');

        Test.startTest();
        setGateActive();
        insert buildJointOwner(acc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :acc.Id],
            'A non-resident person account with both required documents should pass the gate.');
    }

    @isTest
    static void personAccountResidentWithAllFourDocsSucceeds(){
        Account acc = newPersonAccount('ResPass', System.today(), NATIONALITY, 'Resident', null);
        Opportunity opp = newOpportunity(null);
        createDocs(personContactId(acc.Id), null,
                   new List<String>{ DOC_KYC_FORM, DOC_PASSPORT, DOC_EID_FRONT, DOC_EID_BACK }, 'file');

        Test.startTest();
        setGateActive();
        insert buildJointOwner(acc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :acc.Id],
            'A resident person account with all four documents should pass the gate.');
    }

    @isTest
    static void manualKycApprovalOverridesMissingKycDate(){
        // No KYC_Completed_Date__c, so KYC_Status__c evaluates to 'KYC not complete'.
        // Manual_KYC_Approval__c = 'Approved' must still let it through.
        Account acc = newPersonAccount('ManualAppr', null, NATIONALITY, 'Non-Resident', 'Approved');
        Opportunity opp = newOpportunity(null);
        createDocs(personContactId(acc.Id), null,
                   new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'file');

        Test.startTest();
        setGateActive();
        insert buildJointOwner(acc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :acc.Id],
            'Manual KYC Approval = Approved should satisfy the KYC status check on its own.');
    }

    // ------------------------------------------------------------------
    // Person Account - blocked paths
    // ------------------------------------------------------------------

    @isTest
    static void kycNotCompleteIsBlocked(){
        Account acc = newPersonAccount('NoKyc', null, NATIONALITY, 'Non-Resident', null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(acc.Id, opp.Id), 'KYC is not complete');
        Test.stopTest();
    }

    @isTest
    static void expiredKycIsBlocked(){
        // KYC_Status__c formula returns 'KYC Expired' once the completed date is
        // more than 3 months old, which is not in ACCEPTED_KYC_STATUSES.
        Account acc = newPersonAccount('ExpiredKyc', System.today().addMonths(-6),
                                       NATIONALITY, 'Non-Resident', null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(acc.Id, opp.Id), 'KYC is not complete');
        Test.stopTest();
    }

    @isTest
    static void missingNationalityIsBlocked(){
        Account acc = newPersonAccount('NoNat', System.today(), null, 'Non-Resident', null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(acc.Id, opp.Id), 'Add Nationality on');
        Test.stopTest();
    }

    @isTest
    static void missingResidentStatusIsBlocked(){
        Account acc = newPersonAccount('NoRes', System.today(), NATIONALITY, null, null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(acc.Id, opp.Id), 'Add UAE Resident Status on');
        Test.stopTest();
    }

    @isTest
    static void missingDocumentsAreAllReportedTogether(){
        Account acc = newPersonAccount('NoDocs', System.today(), NATIONALITY, 'Resident', null);
        Opportunity opp = newOpportunity(null);
        // Resident needs four documents; supply only two.
        createDocs(personContactId(acc.Id), null,
                   new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'file');

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(acc.Id, opp.Id), DOC_EID_FRONT);
        Test.stopTest();
    }

    @isTest
    static void documentRecordWithoutAFileIsBlocked(){
        // The records exist with the right names but hold no file at all.
        // parentsWithFiles must not report them as satisfied.
        Account acc = newPersonAccount('DocNoFile', System.today(), NATIONALITY, 'Non-Resident', null);
        Opportunity opp = newOpportunity(null);
        createDocs(personContactId(acc.Id), null,
                   new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'none');

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(acc.Id, opp.Id), 'Missing documents.');
        Test.stopTest();
    }

    @isTest
    static void missingJointOwnerAccountIsBlocked(){
        Opportunity opp = newOpportunity(null);
        JointOwner__c jo = buildJointOwner(null, opp.Id);

        Test.startTest();
        setGateActive();
        assertBlocked(jo, 'Select a Joint Owner Account');
        Test.stopTest();
    }

    // ------------------------------------------------------------------
    // Organization Account - Power of Attorney path
    // ------------------------------------------------------------------

    @isTest
    static void orgAccountWithPoaAndDocsSucceeds(){
        // Uses the classic Attachment path so the parentsWithFiles fallback is covered.
        Account orgAcc = newOrgAccount('Test Org Pass');

        Contact poaContact = new Contact(
            LastName                = 'POA Contact',
            AccountId               = orgAcc.Id,
            Nationality__c          = NATIONALITY,
            UAE_Resident_Status__c  = 'Non-Resident',
            KYC_Completed_Date__c   = System.today()
        );
        insert poaContact;

        insert new Power_of_Attorney__c(
            Organization_Account__c = orgAcc.Id,
            Contact__c              = poaContact.Id
        );

        Opportunity opp = newOpportunity(null);
        createDocs(poaContact.Id, null, new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'attachment');
        createDocs(null, orgAcc.Id, new List<String>{ DOC_TRADE_LIC }, 'attachment');

        Test.startTest();
        setGateActive();
        insert buildJointOwner(orgAcc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :orgAcc.Id],
            'An org account with a POA, contact documents and a trade licence should pass the gate.');
    }

    @isTest
    static void orgAccountWithoutPoaIsBlocked(){
        Account orgAcc = newOrgAccount('Test Org No POA');
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(orgAcc.Id, opp.Id), 'has no Power of Attorney record');
        Test.stopTest();
    }

    @isTest
    static void orgAccountWithPoaButNoContactIsBlocked(){
        Account orgAcc = newOrgAccount('Test Org Blank POA');
        insert new Power_of_Attorney__c(Organization_Account__c = orgAcc.Id);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(orgAcc.Id, opp.Id), 'Add a Contact to the Power of Attorney for');
        Test.stopTest();
    }

    @isTest
    static void orgAccountMissingTradeLicenceIsBlocked(){
        // Contact-level documents are complete, but neither account-level
        // document exists, so the gate must still block.
        Account orgAcc = newOrgAccount('Test Org No Licence');

        Contact poaContact = new Contact(
            LastName               = 'POA Contact',
            AccountId              = orgAcc.Id,
            Nationality__c         = NATIONALITY,
            UAE_Resident_Status__c = 'Non-Resident',
            KYC_Completed_Date__c  = System.today()
        );
        insert poaContact;

        insert new Power_of_Attorney__c(
            Organization_Account__c = orgAcc.Id,
            Contact__c              = poaContact.Id
        );

        Opportunity opp = newOpportunity(null);
        createDocs(poaContact.Id, null, new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'file');

        Test.startTest();
        setGateActive();
        // The account-level document must be attributed to the ACCOUNT.
        assertBlocked(buildJointOwner(orgAcc.Id, opp.Id), 'Test Org No Licence: ' + DOC_TRADE_LIC);
        Test.stopTest();
    }

    @isTest
    static void orgAccountMissingDocsAreGroupedByOwningRecord(){
        // The whole point of the grouped message: contact documents must be listed
        // under the POA CONTACT'S name and account documents under the ACCOUNT'S,
        // so nobody goes looking for a Passport on the organization account.
        Account orgAcc = newOrgAccount('Grouped Org');

        Contact poaContact = new Contact(
            FirstName              = 'Poa',
            LastName               = 'Signatory',
            AccountId              = orgAcc.Id,
            Nationality__c         = NATIONALITY,
            UAE_Resident_Status__c = 'Non-Resident',
            KYC_Completed_Date__c  = System.today()
        );
        insert poaContact;

        insert new Power_of_Attorney__c(
            Organization_Account__c = orgAcc.Id,
            Contact__c              = poaContact.Id
        );

        Opportunity opp = newOpportunity(null);
        // Nothing uploaded anywhere, so both groups appear in one message.

        Boolean blocked = false;
        String actualMessage = '';
        Test.startTest();
        setGateActive();
        try {
            insert buildJointOwner(orgAcc.Id, opp.Id);
        } catch (DmlException e){
            blocked = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'Expected the gate to block on missing documents.');
        System.assertEquals(true,
            actualMessage.contains('Poa Signatory: ' + DOC_KYC_FORM + ', ' + DOC_PASSPORT),
            'Contact documents must be listed under the POA contact name: ' + actualMessage);
        System.assertEquals(true,
            actualMessage.contains('Grouped Org: ' + DOC_TRADE_LIC),
            'Account documents must be listed under the account name: ' + actualMessage);
        System.assertEquals(false,
            actualMessage.contains('Grouped Org: ' + DOC_KYC_FORM),
            'Contact documents must NOT be attributed to the account: ' + actualMessage);
    }

    /**
     * Builds an org account with a POA contact, letting the caller control the
     * contact's KYC. Used by the tests that pin WHERE corporate KYC is read from.
     */
    private static Account orgWithPoaContact(String orgName, String contactLastName,
                                             Date contactKycDate, String contactManualApproval,
                                             Date accountKycDate){
        Account orgAcc = new Account(Name = orgName, KYC_Completed_Date__c = accountKycDate);
        insert orgAcc;

        Contact poaContact = new Contact(
            LastName               = contactLastName,
            AccountId              = orgAcc.Id,
            Nationality__c         = NATIONALITY,
            UAE_Resident_Status__c = 'Non-Resident',
            KYC_Completed_Date__c  = contactKycDate,
            Manual_KYC_Approval__c = contactManualApproval
        );
        insert poaContact;

        insert new Power_of_Attorney__c(
            Organization_Account__c = orgAcc.Id,
            Contact__c              = poaContact.Id
        );

        createDocs(poaContact.Id, null, new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'file');
        createDocs(null, orgAcc.Id, new List<String>{ DOC_TRADE_LIC }, 'file');
        return orgAcc;
    }

    @isTest
    static void orgAccountReadsKycFromPoaContactNotTheAccount(){
        // The account has a perfectly good KYC date; the POA contact has none.
        // Corporate KYC lives on the authorised signatory, so this must BLOCK -
        // if it saves, the gate is reading the wrong record.
        Account orgAcc = orgWithPoaContact('Org Acct Has Kyc', 'Unverified Signatory',
                                           null, null, System.today());
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(orgAcc.Id, opp.Id), 'KYC is not complete for Unverified Signatory');
        Test.stopTest();
    }

    @isTest
    static void orgAccountPassesOnPoaContactKycAlone(){
        // Mirror image: the account has NO KYC, the POA contact does. Must save.
        Account orgAcc = orgWithPoaContact('Org Contact Has Kyc', 'Verified Signatory',
                                           System.today(), null, null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        insert buildJointOwner(orgAcc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :orgAcc.Id],
            'A POA contact with complete KYC should satisfy the check on its own.');
    }

    @isTest
    static void orgAccountPoaContactExpiredKycIsBlocked(){
        // Contact KYC_Status__c formula returns 'KYC Expired' past 3 months.
        Account orgAcc = orgWithPoaContact('Org Expired Kyc', 'Expired Signatory',
                                           System.today().addMonths(-6), null, null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        assertBlocked(buildJointOwner(orgAcc.Id, opp.Id), 'KYC is not complete for Expired Signatory');
        Test.stopTest();
    }

    @isTest
    static void orgAccountPoaContactManualApprovalOverrides(){
        // No KYC date anywhere, but the CONTACT is manually approved. Must save.
        Account orgAcc = orgWithPoaContact('Org Manual Appr', 'Approved Signatory',
                                           null, 'Approved', null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        setGateActive();
        insert buildJointOwner(orgAcc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :orgAcc.Id],
            'Manual KYC Approval on the POA contact should satisfy the check.');
    }

    @isTest
    static void orgAccountWithoutPoaReportsPoaNotKyc(){
        // The POA check now runs BEFORE the KYC check, because without a POA
        // there is no contact to read the KYC from. The old order reported
        // "KYC is not complete" here, which sent people to the wrong record.
        Account orgAcc = newOrgAccount('Org Order Check');
        Opportunity opp = newOpportunity(null);

        Boolean blocked = false;
        String actualMessage = '';
        Test.startTest();
        setGateActive();
        try {
            insert buildJointOwner(orgAcc.Id, opp.Id);
        } catch (DmlException e){
            blocked = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'Expected the gate to block.');
        System.assertEquals(true, actualMessage.contains('has no Power of Attorney record'),
            'Missing POA must be reported before KYC: ' + actualMessage);
        System.assertEquals(false, actualMessage.contains('KYC is not complete'),
            'KYC must not be reported when there is no POA to read it from: ' + actualMessage);
    }

    // ------------------------------------------------------------------
    // Egypt exclusion, bypass flag, and update behaviour
    // ------------------------------------------------------------------

    // @isTest
    // static void egyptOpportunitySkipsTheGate(){
    //     // An account with no KYC at all would normally be blocked outright.
    //     // Modon - Egypt must skip the gate entirely.
    //     Account acc = newPersonAccount('EgyptSkip', null, null, null, null);
    //     Opportunity opp = newOpportunity(Constants.MODON_EGYPT_SOURCE_ENTITY);

    //     Test.startTest();
    //     setGateActive();
    //     insert buildJointOwner(acc.Id, opp.Id);
    //     Test.stopTest();

    //     System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :acc.Id],
    //         'Modon - Egypt joint owners must not be blocked by the UAE KYC gate.');
    // }

    @isTest
    static void bypassFlagDefaultsToTrueInTestContext(){
        // Guards the default that keeps the 31 pre-existing test classes green:
        // the same record that kycNotCompleteIsBlocked() rejects must insert
        // cleanly when the flag is left at its default.
        Account acc = newPersonAccount('BypassOn', null, null, null, null);
        Opportunity opp = newOpportunity(null);

        Test.startTest();
        insert buildJointOwner(acc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :acc.Id],
            'bypassKYCCheck should default to true in test context.');
    }

    /**
     * The update tests need their joint owner to already exist in a PREVIOUS
     * transaction. TriggerHandler stamps every processed record Id into a static
     * processedIds set during afterInsert, and filters those Ids out of
     * Trigger.new / Trigger.oldMap for the rest of the transaction. So a record
     * inserted and then updated in the same test method never reaches the
     * handler at all - not a behaviour of this gate, but of the framework.
     * @testSetup runs in its own transaction, which resets the static.
     */
    @testSetup
    static void setupUpdateFixtures(){
        Account originalAcc = newPersonAccount('UpdateOriginal', null, null, null, null);
        newPersonAccount('UpdateTarget', null, null, null, null);
        Opportunity opp = newOpportunity(null);
        insert buildJointOwner(originalAcc.Id, opp.Id);
    }

    private static JointOwner__c setupJointOwner(){
        return [SELECT Id, JointOwnerAccount__c, OwnershipPercentage__c
                FROM JointOwner__c
                WHERE JointOwnerAccount__r.LastName = 'UpdateOriginal'
                LIMIT 1];
    }

    @isTest
    static void updateWithUnchangedAccountSkipsTheGate(){
        // A joint owner created before the gate existed, or while it was
        // bypassed, must stay editable. Only a change to JointOwnerAccount__c
        // re-runs the check - otherwise an expiring KYC would freeze the record
        // and block the very ownership-percentage fixes this class demands.
        JointOwner__c jo = setupJointOwner();

        Test.startTest();
        setGateActive();
        jo.OwnershipPercentage__c = 15;
        update jo;
        Test.stopTest();

        System.assertEquals(15,
            [SELECT OwnershipPercentage__c FROM JointOwner__c WHERE Id = :jo.Id].OwnershipPercentage__c,
            'Updating a field other than the account must not re-trigger the KYC gate.');
    }

    @isTest
    static void updateChangingAccountReRunsTheGate(){
        JointOwner__c jo = setupJointOwner();
        Account targetAcc = [SELECT Id FROM Account WHERE LastName = 'UpdateTarget' LIMIT 1];

        Test.startTest();
        setGateActive();
        Boolean blocked = false;
        String actualMessage = '';
        try {
            jo.JointOwnerAccount__c = targetAcc.Id;
            update jo;
        } catch (DmlException e){
            blocked = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'Changing JointOwnerAccount__c must re-run the KYC gate.');
        System.assertEquals(true, actualMessage.contains('KYC is not complete'),
            'Expected a KYC status failure but got: ' + actualMessage);
    }

    @isTest
    static void bulkInsertIsEvaluatedPerRecord(){
        // One passing and one failing joint owner in the same DML. The error
        // must land on the failing record only, not on newList[0] blindly.
        Account goodAcc = newPersonAccount('BulkGood', System.today(), NATIONALITY, 'Non-Resident', null);
        Account badAcc  = newPersonAccount('BulkBad', null, null, null, null);
        Opportunity opp = newOpportunity(null);
        createDocs(personContactId(goodAcc.Id), null,
                   new List<String>{ DOC_KYC_FORM, DOC_PASSPORT }, 'file');

        List<JointOwner__c> joLst = new List<JointOwner__c>{
            buildJointOwner(goodAcc.Id, opp.Id),
            buildJointOwner(badAcc.Id, opp.Id)
        };

        Test.startTest();
        setGateActive();
        List<Database.SaveResult> results = Database.insert(joLst, false);
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess(),
            'The joint owner with complete KYC should have saved.');
        System.assertEquals(false, results[1].isSuccess(),
            'The joint owner without KYC should have been rejected.');
        System.assertEquals(true, results[1].getErrors()[0].getMessage().contains('KYC is not complete'),
            'The error must be attached to the failing record: '
            + results[1].getErrors()[0].getMessage());
    }
}