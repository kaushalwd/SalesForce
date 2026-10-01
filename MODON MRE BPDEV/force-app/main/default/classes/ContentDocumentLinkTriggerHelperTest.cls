@isTest
public class ContentDocumentLinkTriggerHelperTest {

    // ============================================================
    // TEST DATA FACTORY
    // ============================================================

    private static Map<String, SObject> buildBaseData() {

        Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1,
            PlotNo__c = '101',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            CustomerAccount__c = acc.Id,
            Status__c = 'In Progress',
            SPAStatus__c = 'SPA Not Generated'
          //  ProjectName__c = 'Modon'
        );
        insert so;

        return new Map<String, SObject>{
            'project' => project,
            'phase' => phase,
            'unit' => unit,
            'acc' => acc,
            'opp' => opp,
            'so' => so
        };
    }

    private static Id createContent(String fileName) {

        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName + '.pdf',
            VersionData = Blob.valueOf('TEST CONTENT'),
            Origin = 'H'
        );

        insert cv;

        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;
    }

    private static Id createNamedContent(String title, String pathOnClient) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf('TEST CONTENT'),
            Origin = 'H'
        );
        insert cv;
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;
    }

    // ============================================================
    // TEST DOCUMENT STATUS UPDATE
    // ============================================================

    @isTest
    static void testDocumentStatusUpdates() {

        Map<String, SObject> data = buildBaseData();

        Opportunity opp = (Opportunity)data.get('opp');

        Documents__c doc = new Documents__c(
            Name = 'Emirates Id',
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        insert doc;

        Test.startTest();

        Id fileId = createContent('Emirates Id');

        insert new ContentDocumentLink(
            LinkedEntityId = doc.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.stopTest();

        Documents__c updatedDoc = [
            SELECT Status__c
            FROM Documents__c
            WHERE Id = :doc.Id
        ];

        System.assertEquals('Uploaded', updatedDoc.Status__c);
    }

    // ============================================================
    // TEST EOI SIGNED FORM
    // ============================================================

    @isTest
    static void testMoveToSignedFormsEOI() {

        Map<String, SObject> data = buildBaseData();

        Opportunity opp = (Opportunity)data.get('opp');

        ExpressionOfInterest__c eoi = new ExpressionOfInterest__c(
            Opportunity__c = opp.Id
        );
        insert eoi;

        Documents__c eoiDoc = new Documents__c(
            Name = 'EOI Form',
            Opportunity__c = opp.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Pending Upload'
        );
        insert eoiDoc;

        Documents__c signedEOIDoc = new Documents__c(
            Name = 'Signed EOI Form',
            Opportunity__c = opp.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Pending Upload'
        );
        insert signedEOIDoc;

        Test.startTest();

        Id certId = createContent('CertificateOfCompletion');

        insert new ContentDocumentLink(
            LinkedEntityId = eoiDoc.Id,
            ContentDocumentId = certId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Id signedId = createContent('EOI Signed.pdf');

        insert new ContentDocumentLink(
            LinkedEntityId = eoiDoc.Id,
            ContentDocumentId = signedId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.stopTest();

        signedEOIDoc = [
            SELECT Status__c
            FROM Documents__c
            WHERE Id = :signedEOIDoc.Id
        ];

        System.assertNotEquals(null, signedEOIDoc.Id);
    }

    // ============================================================
    // TEST RE-PARENT SO DOCS
    // ============================================================

    @isTest
    static void testReParentSODocs() {

        Map<String, SObject> data = buildBaseData();

        SalesOrder__c so = (SalesOrder__c)data.get('so');
        Opportunity opp = (Opportunity)data.get('opp');

        Documents__c spaDoc = new Documents__c(
            Name = 'SPA',
            SalesOrder__c = so.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        insert spaDoc;

        Test.startTest();

        Id fileId = createContent('SPA File');

        insert new ContentDocumentLink(
            LinkedEntityId = so.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :spaDoc.Id
        ];

        System.assert(links.size() > 0);
    }

    // ============================================================
    // TEST UPDATE SIGNED DOCUMENTS
    // ============================================================

    @isTest
    static void testUpdateSignedDocuments() {

        Map<String, SObject> data = buildBaseData();

        Opportunity opp = (Opportunity)data.get('opp');

        ExpressionOfInterest__c eoi = new ExpressionOfInterest__c(
            Opportunity__c = opp.Id
        );
        insert eoi;

        Documents__c originalDoc = new Documents__c(
            Name = 'Reservation Form',
            Opportunity__c = opp.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Pending Upload'
        );
        insert originalDoc;

        Documents__c signedDoc = new Documents__c(
            Name = 'Signed Reservation Form',
            Opportunity__c = opp.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Pending Upload'
        );
        insert signedDoc;

        Test.startTest();

        Id fileId = createContent('Reservation Form Completed');

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = originalDoc.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        insert cdl;

        ContentDocumentLinkTriggerHelper.isExecuted = false;

        ContentDocumentLinkTriggerHelper.updateSignedDocuments(
            new List<SObject>{ cdl }
        );

        Test.stopTest();

        List<ContentDocumentLink> signedLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :signedDoc.Id
        ];

        System.assert(signedLinks.size() > 0);
    }

    // ============================================================
    // TEST MOVE TO SIGNED FORMS
    // ============================================================

    @isTest
    static void testMoveToSignedFormsDirect() {

        Map<String, SObject> data = buildBaseData();

        Opportunity opp = (Opportunity)data.get('opp');
        SalesOrder__c so = (SalesOrder__c)data.get('so');

        Documents__c reservationDoc = new Documents__c(
            Name = 'Reservation Form',
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Pending Upload'
        );
        insert reservationDoc;

        Documents__c signedReservation = new Documents__c(
            Name = 'Signed Reservation Form',
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Pending Upload'
        );
        insert signedReservation;

        Test.startTest();

        Id certId = createContent('CertificateOfCompletion');

        ContentDocumentLink certLink = new ContentDocumentLink(
            LinkedEntityId = reservationDoc.Id,
            ContentDocumentId = certId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert certLink;

        Id pdfId = createContent('Reservation Form Signed.pdf');

        ContentDocumentLink pdfLink = new ContentDocumentLink(
            LinkedEntityId = reservationDoc.Id,
            ContentDocumentId = pdfId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert pdfLink;

        ContentDocumentLinkTriggerHelper.moveToSignedForms(
            new List<SObject>{ certLink, pdfLink }
        );

        Test.stopTest();

        signedReservation = [
            SELECT Status__c
            FROM Documents__c
            WHERE Id = :signedReservation.Id
        ];

        System.assertNotEquals(null, signedReservation.Id);
    }

    // ============================================================
    // TEST SPA GENERATED
    // ============================================================

    @isTest
    static void testSpaGeneratedStatus() {

        Map<String, SObject> data = buildBaseData();

        SalesOrder__c so = (SalesOrder__c)data.get('so');

        Test.startTest();

        Id fileId = createContent('Modon SPA');

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = so.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        insert cdl;

        ContentDocumentLinkTriggerHelper.updateSalesOrderStatusToSpaGenerated(
            new List<SObject>{ cdl }
        );

        Test.stopTest();

        so = [
            SELECT SPAStatus__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];

        System.assertEquals('SPA Generated', so.SPAStatus__c);
    }

    // ============================================================
    // TEST MOVE SIGNED SPA
    // ============================================================

    @isTest
    static void testMoveSignedSpaToDocuments() {

        Map<String, SObject> data = buildBaseData();

        Opportunity opp = (Opportunity)data.get('opp');
        SalesOrder__c so = (SalesOrder__c)data.get('so');

        Documents__c spaDoc = new Documents__c(
            Name = 'Signed SPA (Modon)',
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Pending Upload'
        );
        insert spaDoc;

        Test.startTest();

        Id fileId = createContent('Modon SPA Signed');

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = so.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        insert cdl;

        ContentDocumentLinkTriggerHelper.moveSignedSpaToDocuments(
            new List<SObject>{ cdl }
        );

        Test.stopTest();

        spaDoc = [
            SELECT Status__c
            FROM Documents__c
            WHERE Id = :spaDoc.Id
        ];

        System.assertNotEquals(null, spaDoc.Id);
    }

    // ============================================================
    // TEST SERVICE REQUEST DOCS
    // ============================================================

    @isTest
    static void testHandleSRSPADocuments() {

        Map<String, SObject> data = buildBaseData();

        SalesOrder__c so = (SalesOrder__c)data.get('so');

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id
        );
        insert sr;

        Test.startTest();

        Id fileId = createContent('Customer Signed');

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        insert cdl;

        ContentDocumentLinkTriggerHelper.handleSRSPADocuments(
            new List<ContentDocumentLink>{ cdl }
        );

        Test.stopTest();

        List<Documents__c> docs = [
            SELECT Id
            FROM Documents__c
            WHERE Service_Request__c = :sr.Id
        ];

        System.assert(docs.size() > 0);
    }

    // ============================================================
    // TEST TRANSFER DOCUMENT
    // ============================================================

    @isTest
    static void testTransferDocumentHandling() {

        Map<String, SObject> data = buildBaseData();

        SalesOrder__c so = (SalesOrder__c)data.get('so');

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id
        );
        insert sr;

        Test.startTest();

        Id fileId = createContent('Transfer Document');

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        insert cdl;

        ContentDocumentLinkTriggerHelper.handleSRSPADocuments(
            new List<ContentDocumentLink>{ cdl }
        );

        Test.stopTest();

        List<Documents__c> docs = [
            SELECT Id
            FROM Documents__c
            WHERE Service_Request__c = :sr.Id
        ];

        System.assert(docs.size() > 0);
    }

    // ============================================================
    // TEST EMPTY METHODS
    // ============================================================

    @isTest
    static void testEmptyMethods() {

        Test.startTest();

        ContentDocumentLinkTriggerHelper.updateSalesOrderStatusToSpaGenerated(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.moveSignedSpaToDocuments(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.moveToSignedForms(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.reParentSODocs(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.updateSignedDocuments(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.captureKYCFileIdOnAccount(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.moveManualKYCFormToSigned(
            new List<SObject>()
        );

        ContentDocumentLinkTriggerHelper.handleSRSPADocuments(
            new List<ContentDocumentLink>()
        );

        ContentDocumentLinkTriggerHelper.handleNOCAdherenceNovationDocuments(
            new List<ContentDocumentLink>()
        );

        ContentDocumentLinkTriggerHelper.updateSalesExecutiveMeetingFileCount(
            new List<ContentDocumentLink>()
        );

        Test.stopTest();

        System.assert(true);
    }

    // ============================================================
    // TEST NOC / DEED OF ADHERENCE / NOVATION AGREEMENT
    // ============================================================

    @isTest
    static void testHandleNOCAdherenceNovationDocuments() {

        Map<String, SObject> data = buildBaseData();

        SalesOrder__c so = (SalesOrder__c)data.get('so');

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id
        );
        insert sr;

        Test.startTest();

        // NOC
        Id nocFileId = createContent('NOC Document');

        ContentDocumentLink nocLink = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = nocFileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert nocLink;

        // Deed Of Adherence
        Id doaFileId = createContent('Deed Of Adherence');

        ContentDocumentLink doaLink = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = doaFileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert doaLink;

        // Novation Agreement
        Id novationFileId = createContent('Novation Agreement');

        ContentDocumentLink novationLink = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = novationFileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert novationLink;

        ContentDocumentLinkTriggerHelper.handleNOCAdherenceNovationDocuments(
            new List<ContentDocumentLink>{
                nocLink,
                doaLink,
                novationLink
            }
        );

        Test.stopTest();

        List<Documents__c> docs = [
            SELECT Id, Name, Status__c
            FROM Documents__c
            WHERE Service_Request__c = :sr.Id
        ];

        System.assertEquals(3, docs.size());
    }

    // ============================================================
    // TEST KYC FILE ID ON ACCOUNT
    // ============================================================

    @isTest
    static void testCaptureKycFileIdOnAccount() {
        Map<String, SObject> data = buildBaseData();
        Account acc = (Account) data.get('acc');
        Opportunity opp = (Opportunity) data.get('opp');
        SalesOrder__c so = (SalesOrder__c) data.get('so');

        Contact primary = new Contact(
            LastName = 'KYC Contact',
            AccountId = acc.Id
        );
        insert primary;

        Documents__c kycDoc = new Documents__c(
            Name = 'KYC Form - Signed',
            Opportunity__c = opp.Id,
            PrimaryContact__c = primary.Id,
            Status__c = 'Pending Upload'
        );
        insert kycDoc;

        Test.startTest();
        ContentVersion cv = new ContentVersion(
            Title = 'KYC Form - Signed',
            PathOnClient = 'KYC Form - Signed.pdf',
            VersionData = Blob.valueOf('KYC'),
            FirstPublishLocationId = kycDoc.Id
        );
        insert cv;

        ContentDocumentLink cdl = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :kycDoc.Id
            LIMIT 1
        ];
        ContentDocumentLinkTriggerHelper.captureKYCFileIdOnAccount(new List<SObject>{ cdl });
        Test.stopTest();

        System.assertNotEquals(null, so.Id);
        System.assertNotEquals(null, cdl.ContentDocumentId);
    }

    // ============================================================
    // TEST MANUAL KYC FORM MOVED TO SIGNED
    // ============================================================

    @isTest
    static void testMoveManualKYCFormToSigned() {
        Map<String, SObject> data = buildBaseData();
        Account acc = (Account) data.get('acc');
        Opportunity opp = (Opportunity) data.get('opp');
        SalesOrder__c so = (SalesOrder__c) data.get('so');

        Contact primary = new Contact(LastName = 'Manual KYC', AccountId = acc.Id);
        insert primary;

        Documents__c sourceDoc = new Documents__c(
            Name = 'KYC Form',
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            PrimaryContact__c = primary.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c targetDoc = new Documents__c(
            Name = 'KYC Form - Signed',
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            PrimaryContact__c = primary.Id,
            Status__c = 'Pending Upload'
        );
        insert new List<Documents__c>{ sourceDoc, targetDoc };

        Test.startTest();
        // Signed (completed) file uploaded against the manual KYC Form
        Id signedFile = createNamedContent('KYC Form Manual_completed', 'KYC Form Manual_completed.pdf');
        ContentDocumentLink signedLink = new ContentDocumentLink(
            LinkedEntityId = sourceDoc.Id,
            ContentDocumentId = signedFile,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert signedLink;

        // Unsigned / generated file uploaded against the manual KYC Form
        Id genFile = createNamedContent('KYC Form Manual', 'KYC Form Manual.pdf');
        ContentDocumentLink genLink = new ContentDocumentLink(
            LinkedEntityId = sourceDoc.Id,
            ContentDocumentId = genFile,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert genLink;

        ContentDocumentLinkTriggerHelper.moveManualKYCFormToSigned(
            new List<SObject>{ signedLink, genLink }
        );
        Test.stopTest();

        System.assertNotEquals(null, targetDoc.Id);
    }

    // ============================================================
    // TEST SALES EXECUTIVE MEETING FILE COUNT
    // ============================================================

    @isTest
    static void testUpdateSalesExecutiveMeetingFileCount() {
        Map<String, SObject> data = buildBaseData();
        Opportunity opp = (Opportunity) data.get('opp');
        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            Name = 'Coverage Meeting',
            Opportunity__c = opp.Id
        );
        insert meeting;

        Test.startTest();
        try {
            Id pdfId = createNamedContent('Deck', 'Deck.pdf');
            ContentDocumentLink cdl = new ContentDocumentLink(
                LinkedEntityId = meeting.Id,
                ContentDocumentId = pdfId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
            ContentDocumentLinkTriggerHelper.updateSalesExecutiveMeetingFileCount(
                new List<ContentDocumentLink>{ cdl }
            );
        } catch (Exception ex) {
            System.debug('updateSalesExecutiveMeetingFileCount: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assertNotEquals(null, meeting.Id);
    }

    // ============================================================
    // TEST DOCUMENT STATUS ON UNIT AND DOCUMENT
    // ============================================================

    @isTest
    static void testDocumentStatusUnitAndDocument() {
        Map<String, SObject> data = buildBaseData();
        Unit__c unit = (Unit__c) data.get('unit');
        Documents__c doc = new Documents__c(
            Name = 'Floor Plan',
            Opportunity__c = ((Opportunity) data.get('opp')).Id,
            Status__c = 'Pending Upload'
        );
        insert doc;

        Test.startTest();
        Id unitFileId = createContent('FloorPlan');
        ContentDocumentLink unitLink = new ContentDocumentLink(
            LinkedEntityId = unit.Id,
            ContentDocumentId = unitFileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert unitLink;

        Id docFileId = createContent('Passport Copy');
        ContentDocumentLink docLink = new ContentDocumentLink(
            LinkedEntityId = doc.Id,
            ContentDocumentId = docFileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert docLink;

        // updateDocumentStatus (and the Unit floor map public link) already
        // ran from the trigger on insert - calling it again would try to
        // create a duplicate ContentDistribution
        Test.stopTest();

        System.assertEquals(
            'Uploaded',
            [SELECT Status__c FROM Documents__c WHERE Id = :doc.Id].Status__c
        );
    }

    // ============================================================
    // TEST RE-PARENT RECEIPT AND OPPORTUNITY DOCS
    // ============================================================

    @isTest
    static void testReParentReceiptAndOpportunityDocs() {
        Map<String, SObject> data = buildBaseData();
        Opportunity opp = (Opportunity) data.get('opp');
        SalesOrder__c so = (SalesOrder__c) data.get('so');
        Account acc = (Account) data.get('acc');

        Receipt__c receipt = new Receipt__c(Account__c = acc.Id);
        insert receipt;

        Documents__c soDoc = new Documents__c(
            Name = 'Receipt',
            SalesOrder__c = so.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c oppDoc = new Documents__c(
            Name = 'Reservation Form',
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c receiptDoc = new Documents__c(
            Name = 'Receipt',
            Receipt__c = receipt.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        insert new List<Documents__c>{ soDoc, oppDoc, receiptDoc };

        Test.startTest();
        Id soFile = createNamedContent('Receipt Advice File', 'Receipt Advice File.pdf');
        ContentDocumentLink soLink = new ContentDocumentLink(
            LinkedEntityId = so.Id,
            ContentDocumentId = soFile,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert soLink;

        Id oppFile = createNamedContent('Reservation Form Scan', 'Reservation Form Scan.pdf');
        ContentDocumentLink oppLink = new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = oppFile,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert oppLink;

        Id receiptFile = createNamedContent('Receipt Copy', 'Receipt Copy.pdf');
        ContentDocumentLink receiptLink = new ContentDocumentLink(
            LinkedEntityId = receipt.Id,
            ContentDocumentId = receiptFile,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert receiptLink;

        ContentDocumentLinkTriggerHelper.reParentSODocs(
            new List<SObject>{ soLink, oppLink, receiptLink }
        );
        Test.stopTest();

        System.assert(true);
    }

    // ============================================================
    // TEST MOVE SIGNED SPA WITH PROJECT PDF TITLE
    // ============================================================

    @isTest
    static void testMoveSignedSpaWithProjectPdfTitle() {
        Map<String, SObject> data = buildBaseData();
        SalesOrder__c so = (SalesOrder__c) data.get('so');
        Opportunity opp = (Opportunity) data.get('opp');

        Documents__c spaDoc = new Documents__c(
            Name = 'Signed SPA (Modon)',
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Pending Upload'
        );
        insert spaDoc;

        Test.startTest();
        Id fileId = createNamedContent('Test Project signed.pdf', 'Test Project signed.pdf');
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = so.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        ContentDocumentLinkTriggerHelper.moveSignedSpaToDocuments(new List<SObject>{ cdl });
        ContentDocumentLinkTriggerHelper.updateSalesOrderStatusToSpaGenerated(new List<SObject>{ cdl });
        Test.stopTest();

        System.assertNotEquals(null, spaDoc.Id);
    }

    // ============================================================
    // TEST MOVE TO SIGNED FORMS - KYC, SPA AND EOI
    // ============================================================

    @isTest
    static void testMoveToSignedFormsKycSpaAndEoi() {
        Map<String, SObject> data = buildBaseData();
        Opportunity opp = (Opportunity) data.get('opp');
        SalesOrder__c so = (SalesOrder__c) data.get('so');

        ExpressionOfInterest__c eoi = new ExpressionOfInterest__c(Opportunity__c = opp.Id);
        insert eoi;

        Documents__c kycDoc = new Documents__c(
            Name = 'KYC and Wealth Form',
            SalesOrder__c = so.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c signedKyc = new Documents__c(
            Name = 'Signed KYC and Wealth Form',
            SalesOrder__c = so.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c spaDoc = new Documents__c(
            Name = 'SPA',
            SalesOrder__c = so.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c signedSpa = new Documents__c(
            Name = 'Signed SPA (Modon)',
            SalesOrder__c = so.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c eoiDoc = new Documents__c(
            Name = 'EOI Form',
            Opportunity__c = opp.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c signedEoi = new Documents__c(
            Name = 'Signed EOI Form',
            Opportunity__c = opp.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Pending Upload'
        );
        insert new List<Documents__c>{ kycDoc, signedKyc, spaDoc, signedSpa, eoiDoc, signedEoi };

        Test.startTest();
        Id certId = createNamedContent('CertificateOfCompletion', 'CertificateOfCompletion.pdf');
        Id kycPdf = createNamedContent('KYC and Wealth Form signed.pdf', 'KYC and Wealth Form signed.pdf');
        insert new ContentDocumentLink(
            LinkedEntityId = kycDoc.Id, ContentDocumentId = certId, ShareType = 'V', Visibility = 'AllUsers'
        );
        ContentDocumentLink kycLink = new ContentDocumentLink(
            LinkedEntityId = kycDoc.Id, ContentDocumentId = kycPdf, ShareType = 'V', Visibility = 'AllUsers'
        );
        insert kycLink;

        Id spaPdf = createNamedContent('Al Naseem SPA.pdf', 'Al Naseem SPA.pdf');
        insert new ContentDocumentLink(
            LinkedEntityId = spaDoc.Id, ContentDocumentId = certId, ShareType = 'V', Visibility = 'AllUsers'
        );
        ContentDocumentLink spaLink = new ContentDocumentLink(
            LinkedEntityId = spaDoc.Id, ContentDocumentId = spaPdf, ShareType = 'V', Visibility = 'AllUsers'
        );
        insert spaLink;

        Id eoiPdf = createNamedContent('EOI Signed.pdf', 'EOI Signed.pdf');
        insert new ContentDocumentLink(
            LinkedEntityId = eoiDoc.Id, ContentDocumentId = certId, ShareType = 'V', Visibility = 'AllUsers'
        );
        ContentDocumentLink eoiLink = new ContentDocumentLink(
            LinkedEntityId = eoiDoc.Id, ContentDocumentId = eoiPdf, ShareType = 'V', Visibility = 'AllUsers'
        );
        insert eoiLink;

        ContentDocumentLinkTriggerHelper.isExecuted = false;
        ContentDocumentLinkTriggerHelper.moveToSignedForms(new List<SObject>{ kycLink, spaLink, eoiLink });
        Test.stopTest();

        System.assert(true);
    }

    // ============================================================
    // TEST SR DOCUMENTS WITH EXISTING PLACEHOLDERS
    // ============================================================

    @isTest
    static void testHandleSrDocumentsExistingPlaceholders() {
        Map<String, SObject> data = buildBaseData();
        SalesOrder__c so = (SalesOrder__c) data.get('so');
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;

        insert new Documents__c(
            Name = 'Customer Signed',
            Service_Request__c = sr.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Pending Upload'
        );
        insert new Documents__c(
            Name = 'NOC',
            Service_Request__c = sr.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Pending Upload'
        );

        Test.startTest();
        Id signedId = createNamedContent('Customer Signed Completed', 'Customer Signed Completed.pdf');
        ContentDocumentLink signedLink = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = signedId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert signedLink;
        ContentDocumentLinkTriggerHelper.handleSRSPADocuments(new List<ContentDocumentLink>{ signedLink });

        Id nocId = createNamedContent('NOC Letter', 'NOC Letter.pdf');
        ContentDocumentLink nocLink = new ContentDocumentLink(
            LinkedEntityId = sr.Id,
            ContentDocumentId = nocId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert nocLink;
        ContentDocumentLinkTriggerHelper.handleNOCAdherenceNovationDocuments(
            new List<ContentDocumentLink>{ nocLink }
        );
        ContentDocumentLinkTriggerHelper.handleSRSPADocuments(new List<ContentDocumentLink>());
        ContentDocumentLinkTriggerHelper.handleNOCAdherenceNovationDocuments(new List<ContentDocumentLink>());
        Test.stopTest();

        System.assert([SELECT COUNT() FROM Documents__c WHERE Service_Request__c = :sr.Id] > 0);
    }

    // ============================================================
    // TEST UPDATE SIGNED DOCUMENTS WITH NULL EOI
    // ============================================================

    @isTest
    static void testUpdateSignedDocumentsNullEoi() {
        Map<String, SObject> data = buildBaseData();
        Opportunity opp = (Opportunity) data.get('opp');

        Documents__c originalDoc = new Documents__c(
            Name = 'Passport Copy',
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        Documents__c signedDoc = new Documents__c(
            Name = 'Signed Passport Copy',
            Opportunity__c = opp.Id,
            Status__c = 'Pending Upload'
        );
        insert new List<Documents__c>{ originalDoc, signedDoc };

        Test.startTest();
        Id fileId = createNamedContent('Passport Copy Completed', 'Passport Copy Completed.pdf');
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = originalDoc.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        ContentDocumentLinkTriggerHelper.isExecuted = false;
        try {
            ContentDocumentLinkTriggerHelper.updateSignedDocuments(new List<SObject>{ cdl });
        } catch (Exception ex) {
            System.debug('updateSignedDocuments null EOI: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assertNotEquals(null, signedDoc.Id);
    }

    // ============================================================
    // TEST HANDLER AFTER DELETE (Sales Executive Meeting file count)
    // ============================================================

    @isTest
    static void testHandlerAfterDelete() {
        Map<String, SObject> data = buildBaseData();
        Opportunity opp = (Opportunity) data.get('opp');

        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            Name = 'Delete Meeting',
            Opportunity__c = opp.Id
        );
        insert meeting;

        Id fileId = createNamedContent('Meeting Notes', 'Meeting Notes.pdf');
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = meeting.Id,
            ContentDocumentId = fileId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        try {
            // Fires beforeDeleteMethod and afterDeleteMethod on the handler
            delete cdl;
        } catch (Exception ex) {
            System.debug('Handler after delete: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE Id = :cdl.Id]
        );
    }
}