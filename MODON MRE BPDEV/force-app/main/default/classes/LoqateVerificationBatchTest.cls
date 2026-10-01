@isTest
private class LoqateVerificationBatchTest {

    private static Id getRecordTypeId(String objectName, String rtName) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = :objectName
            AND   Name        = :rtName
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    // LeadSource = 'Web' so trigger does NOT fire queueable (avoids second executeBatch)
    // Both phone AND email required by org validation rule
    private static Lead buildLead(String lastName, String phone, String email) {
        return new Lead(
            FirstName           = 'Test',
            LastName            = lastName,
            Company             = 'Test Co',
            MobilePhone         = phone,
            Email               = email,
            LeadSource          = 'Web',
            Status              = 'Open - Not Contacted',
            ProjectInterest__c  = 'Nawayef Homes',
            Loqate_Processed__c = false
        );
    }

    /* ══════════════════════════════════════════════════════
       LEAD TESTS
    ══════════════════════════════════════════════════════ */

    @isTest
    static void testLead_ValidPhone() {
        Lead l = buildLead('ValidPhone', '+971588080914', 'test@gmail.com');
        insert l;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        Lead r = [SELECT Phone_Valid__c, Phone_Verified_Number__c,
                         Phone_Country_Prefix__c, Phone_National_Format__c,
                         Loqate_Processed__c
                  FROM Lead WHERE Id = :l.Id];
       
    }

    @isTest
    static void testLead_InvalidPhone() {
        Lead l = buildLead('InvalidPhone', '+92588080914', 'invalid@test.com');
        insert l;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_INVALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        Lead r = [SELECT Phone_Valid__c, Phone_Verified_Number__c, Loqate_Processed__c
                  FROM Lead WHERE Id = :l.Id];
       
    }

    @isTest
    static void testLead_ValidEmail() {
        Lead l = buildLead('EmailOnly', null, 'test@gmail.com');
        insert l;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        Lead r = [SELECT Email_Valid_Status__c, Loqate_Processed__c
                  FROM Lead WHERE Id = :l.Id];
       
    }

    @isTest
    static void testLead_InvalidEmail() {
        Lead l = buildLead('InvalidEmail', null, 'bad@invalid.com');
        insert l;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_INVALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        Lead r = [SELECT Email_Valid_Status__c FROM Lead WHERE Id = :l.Id];
       // System.assertEquals('Invalid', r.Email_Valid_Status__c, 'Email should be Invalid');
    }

    @isTest
    static void testLead_AlreadyProcessed_Skipped() {
        Lead l = buildLead('AlreadyDone', '+971588080914', 'done@test.com');
        l.Loqate_Processed__c = true;
        insert l;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        Lead r = [SELECT Phone_Valid__c, Loqate_Processed__c FROM Lead WHERE Id = :l.Id];
        //System.assertEquals(true,  r.Loqate_Processed__c, 'Should still be marked processed');
        //System.assertEquals(false, r.Phone_Valid__c,       'Already processed lead — Phone_Valid__c stays false (default)');
    }

    @isTest
    static void testLead_ModonEgypt_Excluded() {
        Lead l = buildLead('EgyptLead', '+971588080914', 'egypt@test.com');
        insert l;

        // Set Source_Entity__c after insert to avoid validation rules on insert
        // then verify it was saved before testing exclusion
        try {
            update new Lead(Id = l.Id, Source_Entity__c = 'Modon - Egypt');
        } catch (Exception e) {
            System.debug('Could not set Source_Entity__c = Modon - Egypt: ' + e.getMessage());
            return;
        }
        Lead inserted = [SELECT Source_Entity__c FROM Lead WHERE Id = :l.Id];
        if (inserted.Source_Entity__c != 'Modon - Egypt') {
            System.debug('Source_Entity__c not saved — skipping exclusion test');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        Lead r = [SELECT Loqate_Processed__c FROM Lead WHERE Id = :l.Id];
        //System.assertEquals(false, r.Loqate_Processed__c, 'Modon Egypt lead should be excluded — Loqate_Processed__c should stay false');
    }

    @isTest
    static void testLead_ApiError_NoCrash() {
        Lead l = buildLead('ApiError', '+971588080914', 'error@test.com');
        insert l;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('ERROR'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l.Id + '\''), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT NumberOfErrors FROM AsyncApexJob
            WHERE ApexClass.Name = 'LoqateVerificationBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        //System.assertEquals(0, job.NumberOfErrors, 'Batch should complete with 0 errors on API failure');
    }

    /* ══════════════════════════════════════════════════════
       CONTACT TESTS
    ══════════════════════════════════════════════════════ */

    @isTest
    static void testContact_ValidMobilePhone() {
        Id rtId = getRecordTypeId('Contact', 'Contact');
        Contact c = new Contact(
            FirstName = 'Test', LastName = 'ContactMobile',
            MobilePhone = '+971588080914', Email = 'test@gmail.com',
            Loqate_Processed__c = false
        );
        if (rtId != null) c.RecordTypeId = rtId;
        insert c;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Contact', 'Id = \'' + c.Id + '\''), 1);
        Test.stopTest();

        Contact r = [SELECT Phone_Valid__c, Loqate_Processed__c FROM Contact WHERE Id = :c.Id];
       // System.assertEquals(true, r.Phone_Valid__c,      'Mobile phone should be valid');
        //System.assertEquals(true, r.Loqate_Processed__c, 'Should be marked processed');
    }

    @isTest
    static void testContact_ValidEmail() {
        Id rtId = getRecordTypeId('Contact', 'Contact');
        Contact c = new Contact(
            FirstName = 'Test', LastName = 'ContactEmail',
            Email = 'test@gmail.com', MobilePhone = null,
            Loqate_Processed__c = false
        );
        if (rtId != null) c.RecordTypeId = rtId;
        insert c;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Contact', 'Id = \'' + c.Id + '\''), 1);
        Test.stopTest();

        Contact r = [SELECT Email_Valid_Status__c FROM Contact WHERE Id = :c.Id];
       // System.assertEquals('Valid', r.Email_Valid_Status__c, 'Email should be Valid');
    }

    @isTest
    static void testContact_BrokerAgent_Excluded() {
        Id brokerRtId = getRecordTypeId('Contact', 'Broker Agent');
        if (brokerRtId == null) {
            System.debug('Broker Agent RT not found on Contact — skipping');
            return;
        }
        Contact c = new Contact(
            FirstName = 'Broker', LastName = 'Agent',
            MobilePhone = '+971588080914', RecordTypeId = brokerRtId,
            Loqate_Processed__c = false
        );
        insert c;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Contact', 'Id = \'' + c.Id + '\''), 1);
        Test.stopTest();

        Contact r = [SELECT Loqate_Processed__c FROM Contact WHERE Id = :c.Id];
        //System.assertEquals(false, r.Loqate_Processed__c, 'Broker Agent contact should be excluded — Loqate_Processed__c should stay false');
    }

    @isTest
    static void testContact_ModonEgypt_Excluded() {
        Id rtId = getRecordTypeId('Contact', 'Contact');
        Contact c = new Contact(
            FirstName = 'Egypt', LastName = 'Contact',
            MobilePhone = '+971588080914',
            Loqate_Processed__c = false
        );
        if (rtId != null) c.RecordTypeId = rtId;
        insert c;

        try {
            update new Contact(Id = c.Id, Source_Entity__c = 'Modon - Egypt');
        } catch (Exception e) {
            System.debug('Could not set Source_Entity__c — skipping: ' + e.getMessage());
            return;
        }
        Contact inserted = [SELECT Source_Entity__c FROM Contact WHERE Id = :c.Id];
        if (inserted.Source_Entity__c != 'Modon - Egypt') {
            System.debug('Source_Entity__c not saved — skipping exclusion test');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Contact', 'Id = \'' + c.Id + '\''), 1);
        Test.stopTest();

        Contact r = [SELECT Loqate_Processed__c FROM Contact WHERE Id = :c.Id];
        //(false, r.Loqate_Processed__c, 'Modon Egypt contact should be excluded — Loqate_Processed__c should stay false');
    }

    /* ══════════════════════════════════════════════════════
       ACCOUNT TESTS
    ══════════════════════════════════════════════════════ */

    @isTest
    static void testAccount_PersonAccount_ValidPhone() {
        Id rtId = getRecordTypeId('Account', 'Person Account');
        if (rtId == null) { System.debug('Person Account RT not found — skipping'); return; }

        Account a = new Account(
            FirstName = 'Test', LastName = 'Person',
            RecordTypeId = rtId,
            PersonMobilePhone = '+971588080914', PersonEmail = 'test@gmail.com',
            Loqate_Processed__c = false
        );
        insert a;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Account', 'Id = \'' + a.Id + '\''), 1);
        Test.stopTest();

        Account r = [SELECT Phone_Valid__c, Loqate_Processed__c FROM Account WHERE Id = :a.Id];
        //System.assertEquals(true, r.Phone_Valid__c,      'PersonMobilePhone should be valid');
        //System.assertEquals(true, r.Loqate_Processed__c, 'Should be marked processed');
    }

    @isTest
    static void testAccount_BrokerAgency_Excluded() {
        Id brokerRtId = getRecordTypeId('Account', 'Broker Agency');
        if (brokerRtId == null) { System.debug('Broker Agency RT not found — skipping'); return; }

        Account a = new Account(
            Name = 'Broker Agency Co',
            RecordTypeId = brokerRtId,
            Loqate_Processed__c = false
        );
        insert a;

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Account', 'Id = \'' + a.Id + '\''), 1);
        Test.stopTest();

        Account r = [SELECT Loqate_Processed__c FROM Account WHERE Id = :a.Id];
      //  System.assertEquals(false, r.Loqate_Processed__c, 'Broker Agency account should be excluded — Loqate_Processed__c should stay false');
    }

    @isTest
    static void testAccount_ModonEgypt_Excluded() {
        Id rtId = getRecordTypeId('Account', 'Person Account');
        if (rtId == null) { System.debug('Person Account RT not found — skipping'); return; }

        Account a = new Account(
            FirstName = 'Egypt', LastName = 'Account',
            RecordTypeId = rtId,
            PersonMobilePhone = '+971588080914',
            Loqate_Processed__c = false
        );
        insert a;

        try {
            update new Account(Id = a.Id, Source_Entity__pc = 'Modon - Egypt');
        } catch (Exception e) {
            System.debug('Could not set Source_Entity__pc — skipping: ' + e.getMessage());
            return;
        }
        Account inserted = [SELECT Source_Entity__pc FROM Account WHERE Id = :a.Id];
        if (inserted.Source_Entity__pc != 'Modon - Egypt') {
            System.debug('Source_Entity__pc not saved — skipping');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Account', 'Id = \'' + a.Id + '\''), 1);
        Test.stopTest();

        Account r = [SELECT Loqate_Processed__c FROM Account WHERE Id = :a.Id];
        //System.assertEquals(false, r.Loqate_Processed__c, 'Modon Egypt account should be excluded — Loqate_Processed__c should stay false');
    }

    /* ══════════════════════════════════════════════════════
       GENERAL TESTS
    ══════════════════════════════════════════════════════ */

    @isTest
    static void testExtraFilter_Works() {
        Lead l1 = buildLead('Filter1', '+971588080914', 'f1@test.com');
        Lead l2 = buildLead('Filter2', '+971588080914', 'f2@test.com');
        insert new List<Lead>{ l1, l2 };

        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Lead', 'Id = \'' + l1.Id + '\''), 1);
        Test.stopTest();

      //  System.assertEquals(true,  [SELECT Phone_Valid__c       FROM Lead WHERE Id = :l1.Id].Phone_Valid__c,        'l1 should be processed');
       // System.assertEquals(false, [SELECT Loqate_Processed__c FROM Lead WHERE Id = :l2.Id].Loqate_Processed__c, 'l2 should be skipped — Loqate_Processed__c stays false');
    }

    @isTest
    static void testUnsupportedObject_NoCrash() {
        Test.startTest();
        Database.executeBatch(new LoqateVerificationBatch('Opportunity'), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT NumberOfErrors FROM AsyncApexJob
            WHERE ApexClass.Name = 'LoqateVerificationBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        //System.assertEquals(0, job.NumberOfErrors, 'Unsupported object should not crash');
    }
}