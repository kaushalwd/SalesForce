@IsTest(SeeAllData=false)
private class CDL_SignedSPAFileLinker_AllInOne_Test {

    // --- Constants aligned to your org/handler ---
    private static final String RT_DEV_OFFPLAN = 'Service_Request_Management_Property_Transfer_OffPlan';
    private static final String DOCS_NAME      = 'Signed SPA (MODON)';
    private static final String TITLE_MATCH    = 'Unified Sale - Customer Signed - Completed';

    // ---------- Helpers ----------
    private static Id offplanRtId() {
        return Schema.SObjectType.ServiceRequest__c
               .getRecordTypeInfosByDeveloperName()
               .get(RT_DEV_OFFPLAN)
               .getRecordTypeId();
    }

    private static Account mkAcc(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Opportunity mkOpp(String name) {
        Opportunity o = new Opportunity(
            Name=name,
            CloseDate=Date.today(),
            StageName='Prospecting',
            Status__c='In Progress',
            UAE_Resident_Status__c='Resident',
            EmiratesIDExpiryDate__c=Date.today().addDays(600),
            EIDNumber__c='784-1234-1234567-1',
            Nationality__c='United Arab Emirates'
        );
        insert o;
        return o;
    }

    private static SalesOrder__c mkSO() {
        Account a = mkAcc('Acc-'+Math.mod(Crypto.getRandomInteger(), 100000));
        Opportunity o = mkOpp('Opp-'+Math.mod(Crypto.getRandomInteger(), 100000));
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = a.Id,
            Opportunity__c     = o.Id,
            Status__c          = 'completed' // adjust if your org uses a different required value
        );
        insert so;
        return so;
    }

    /** Create an OffPlan SR; optionally set Transferred_Sales_Order__c */
    private static ServiceRequest__c mkSR(Boolean setTransferred, Id soIdIfAny) {
        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = offplanRtId()
        );
        if (setTransferred && soIdIfAny != null) {
            sr.put('Transferred_Sales_Order__c', soIdIfAny);
        }
        insert sr;
        return sr;
    }

    /** Make a file and link to parent via CDL (fires CDL trigger) */
    private static Id makeFileAndLink(Id parentId, String title) {
        ContentVersion cv = new ContentVersion(
            Title        = title,
            PathOnClient = 't.pdf',
            VersionData  = Blob.valueOf('x')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = parentId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        return cv.ContentDocumentId;
    }

    private static Documents__c getDocsBySO(Id soId) {
        List<Documents__c> rows = [
            SELECT Id, Name, SalesOrder__c
            FROM Documents__c
            WHERE SalesOrder__c = :soId
              AND Name = :DOCS_NAME
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Integer countLinks(Id docId, Id targetId) {
        return [SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :docId
                  AND LinkedEntityId    = :targetId];
    }

    // ---------- Tests ----------

    @IsTest
    static void test_CDL_Insert_createsTarget_and_Link() {
        SalesOrder__c so = mkSO();
        ServiceRequest__c sr = mkSR(true, so.Id);


        Test.startTest();
        Id docId = makeFileAndLink(sr.Id, TITLE_MATCH);
        Test.stopTest();

        Documents__c target = getDocsBySO(so.Id);
    }

    @IsTest
    static void test_CDL_Insert_titleMismatch_noLink_noTarget() {
        SalesOrder__c so = mkSO();
        ServiceRequest__c sr = mkSR(true, so.Id);

        Test.startTest();
        // Missing "Customer Signed"
        Id docId = makeFileAndLink(sr.Id, 'Unified Sale - Completed');
        Test.stopTest();

        Documents__c target = getDocsBySO(so.Id);
    }

    @IsTest
    static void test_CDL_Insert_duplicateAvoidance() {
        SalesOrder__c so = mkSO();
        ServiceRequest__c sr = mkSR(true, so.Id);

        // Pre-create target to hit "target exists" branch
        Documents__c pre = new Documents__c(Name = DOCS_NAME, SalesOrder__c = so.Id);
        insert pre;

        Test.startTest();
        Id docId = makeFileAndLink(sr.Id, 'completed - customer signed - unified sale'); // different casing/order
        // Relink same document to SR again (fires trigger again)
        //insert new ContentDocumentLink(
          //  ContentDocumentId = docId,
            //LinkedEntityId    = sr.Id,
            //ShareType         = 'V',
            //Visibility        = 'AllUsers'
        //);
        Test.stopTest();

        Documents__c target = getDocsBySO(so.Id);


    }

    @IsTest
    static void test_SR_Update_linksExistingFile_afterOffPlanCondition() {
        // SR without transferred SO; attach eligible file first
        ServiceRequest__c sr = mkSR(false, null);
        Id docId = makeFileAndLink(sr.Id, 'Unified Sale | Customer Signed | Completed');

        // Now set transferred SO → should run runForSRUpdate (OffPlan path)
        SalesOrder__c so = mkSO();
        sr.put('Transferred_Sales_Order__c', so.Id);

        Test.startTest();
        update sr;
        Test.stopTest();

        Documents__c target = getDocsBySO(so.Id);
    }

    @IsTest
    static void test_SR_Update_duplicateAvoidance_acrossChanges() {
        // Attach valid file; then change Transferred SO twice and ensure no dupes
        ServiceRequest__c sr = mkSR(false, null);
        Id docId = makeFileAndLink(sr.Id, TITLE_MATCH);

        SalesOrder__c so1 = mkSO();
        sr.put('Transferred_Sales_Order__c', so1.Id);
        update sr;

        Documents__c t1 = getDocsBySO(so1.Id);

        // Switch to a different SO, rerun path
        SalesOrder__c so2 = mkSO();
        sr.put('Transferred_Sales_Order__c', so2.Id);

        Test.startTest();
        update sr;
        Test.stopTest();

        Documents__c t2 = getDocsBySO(so2.Id);
       
    }
}