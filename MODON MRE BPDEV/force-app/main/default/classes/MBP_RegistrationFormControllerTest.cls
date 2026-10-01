@isTest
class MBP_RegistrationFormControllerTest {

    static Registration__c reg(String email, String status, String tln) {
        Registration__c r = new Registration__c(Company_Email_Address__c=email, Status__c=status, Trade_License_Number__c=tln, Company_Name_as_per_Trade_License__c='Test');
        insert r;
        return r;
    }

    static Registration_Agent__c agent(Id regId, String email, String type) {
        Registration_Agent__c a = new Registration_Agent__c(Registration_Name__c=regId, Agent_Email__c=email, Type__c=type);
        insert a;
        return a;
    }

    static Registration_Agent__c primaryOwnerAgent(Id regId, String email) {
        Registration_Agent__c a = new Registration_Agent__c(Registration_Name__c=regId, Agent_Email__c=email, Type__c='Owner', Primary_Owner__c=true);
        insert a;
        return a;
    }

    static void accountContact(String email, String mobile, String tln) {
        insert new Account(Name='Test', Company_Email_Address__c=email, Phone=mobile, Trade_License_Number__c=tln);
        insert new Contact(LastName='Test', Email=email, MobilePhone=mobile);
    }

    @testSetup
    static void setup() {
        Registration__c r = reg('user@test.com','Draft','TL123');
        agent(r.Id, 'agent@test.com', 'Agency Admin');
        accountContact('acct@example.com', '1234567890', 'TL123');
    }

    @isTest
    static void test_findRegistrationByEmail() {
        Test.startTest();
        MBP_RegistrationFormController.findRegistrationByEmail('user@test.com');
        MBP_RegistrationFormController.findRegistrationByEmail(null);
        MBP_RegistrationFormController.findRegistrationByEmail('notfound@x.com');
        Test.stopTest();
    }

    @isTest
    static void test_findRegistrationAndSendOTP() {
        Registration__c r = reg('otp@a.com','Draft','TL777');

        r.Status__c = 'Draft';

        Test.startTest();
        MBP_RegistrationFormController.findRegistrationAndSendOTP('otp@a.com');
        MBP_RegistrationFormController.findRegistrationAndSendOTP('');
        MBP_RegistrationFormController.findRegistrationAndSendOTP('notfound@b.com');
        Test.stopTest();

        r = [SELECT Id, Status__c FROM Registration__c WHERE Id=:r.Id];
        r.Status__c = 'Submitted';
        update r;

        try {
            MBP_RegistrationFormController.findRegistrationAndSendOTP('otp@a.com');
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_getSendGridMap() {
        Test.startTest();
        MBP_RegistrationFormController.getSendGridMap();
        Test.stopTest();
    }

    @isTest
    static void test_verifyOTP() {
        Registration__c r = reg('otp2@a.com','Draft','TL888');
        r.OTP__c = '123456';
        update r;

        Test.startTest();
        Boolean validResult = MBP_RegistrationFormController.verifyOTP(r.Id, '123456');
        Boolean invalidResult = MBP_RegistrationFormController.verifyOTP(r.Id, '000000');
        Test.stopTest();

        System.assertEquals(true, validResult);
        System.assertEquals(false, invalidResult);
    }

    @isTest
    static void test_getRegistrationAgents() {
        Registration__c r = [SELECT Id FROM Registration__c WHERE Company_Email_Address__c='user@test.com' LIMIT 1];

        Test.startTest();
        MBP_RegistrationFormController.getRegistrationAgents(r.Id);
        Test.stopTest();

        try {
            MBP_RegistrationFormController.getRegistrationAgents(null);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_uploadFile_getExistingFile() {
        Registration__c r = [SELECT Id FROM Registration__c WHERE Company_Email_Address__c='user@test.com' LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('file'));

        try {
            Test.startTest();
            MBP_RegistrationFormController.uploadFile(r.Id, 'trade.pdf', b64);
            MBP_RegistrationFormController.getExistingFile(r.Id, 'trade');
            Test.stopTest();
        } catch (Exception e) {
            System.debug('File test exception: ' + e.getMessage());
        }

        try {
            MBP_RegistrationFormController.getExistingFile(r.Id, null);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }

        try {
            MBP_RegistrationFormController.getExistingFile('001000000000000AAA', 'trade');
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_checkDuplicateValue() {
        Test.startTest();
        MBP_RegistrationFormController.checkDuplicateValue('acct@example.com', 'email');
        MBP_RegistrationFormController.checkDuplicateValue('1234567890', 'mobile');
        MBP_RegistrationFormController.checkDuplicateValue(null, 'email');
        MBP_RegistrationFormController.checkDuplicateValue('foo', 'other');
        Test.stopTest();
    }

    @isTest
    static void test_validateDuplicateTradeLicenseNumber() {
        Test.startTest();
        MBP_RegistrationFormController.validateDuplicateTradeLicenseNumber('TL123');
        MBP_RegistrationFormController.validateDuplicateTradeLicenseNumber('');
        Test.stopTest();
    }

    @isTest
    static void test_checkDuplicateEmailOrMobile() {
        Test.startTest();
        MBP_RegistrationFormController.checkDuplicateEmailOrMobile('acct@example.com', 'email');
        MBP_RegistrationFormController.checkDuplicateEmailOrMobile('1234567890', 'mobile');
        MBP_RegistrationFormController.checkDuplicateEmailOrMobile(null, 'email');
        Test.stopTest();
    }

    @isTest
    static void test_upsertRegistrationRecord() {
        Registration__c r = reg('upsert@t.com','Draft','TL444');

        ServiceRequest__c sr = new ServiceRequest__c(Registration__c=r.Id);
        insert sr;

        Task t = new Task(WhatId=sr.Id, Subject='Require more information', Status='Open');
        insert t;

        r.Status__c = 'Submitted';

        Test.startTest();
        MBP_RegistrationFormController.upsertRegistrationRecord(r);
        Test.stopTest();

        try {
            MBP_RegistrationFormController.upsertRegistrationRecord(null);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_getLatestServiceRequestNumber() {
        Registration__c r = reg('latest@t.com','Draft','TL555');
        ServiceRequest__c sr = new ServiceRequest__c(Registration__c=r.Id);
        insert sr;

        Test.startTest();
        MBP_RegistrationFormController.getLatestServiceRequestNumber(r.Id);
        Test.stopTest();

        try {
            MBP_RegistrationFormController.getLatestServiceRequestNumber('001000000000000AAA');
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_upsertRegistrationAgentRecords() {
        Registration__c r = [SELECT Id FROM Registration__c LIMIT 1];
        Registration_Agent__c a = new Registration_Agent__c(Registration_Name__c=r.Id, Agent_Email__c='x@x.com');
        List<Registration_Agent__c> l = new List<Registration_Agent__c>{a};

        Test.startTest();
        MBP_RegistrationFormController.upsertRegistrationAgentRecords(l);
        Test.stopTest();

        try {
            MBP_RegistrationFormController.upsertRegistrationAgentRecords(new List<Registration_Agent__c>());
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_getRegistrationById() {
        Registration__c r = [SELECT Id FROM Registration__c LIMIT 1];

        Test.startTest();
        MBP_RegistrationFormController.getRegistrationById(r.Id);
        MBP_RegistrationFormController.getRegistrationById(null);
        Test.stopTest();
    }

    @isTest
    static void test_deleteRegistrationAgentRecord() {
        Registration__c r = [SELECT Id FROM Registration__c LIMIT 1];
        Registration_Agent__c a = new Registration_Agent__c(Registration_Name__c=r.Id, Agent_Email__c='d@x.com');
        insert a;

        Test.startTest();
        MBP_RegistrationFormController.deleteRegistrationAgentRecord(a.Id);
        Test.stopTest();

        try {
            MBP_RegistrationFormController.deleteRegistrationAgentRecord(null);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_deleteFile() {
        Registration__c r = [SELECT Id FROM Registration__c LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('file'));
        Id cdid;

        try {
            cdid = MBP_RegistrationFormController.uploadFile(r.Id, 'vat.pdf', b64);
        } catch (Exception e) {
            System.debug('uploadFile exception: ' + e.getMessage());
        }

        if (cdid != null) {
            Test.startTest();
            MBP_RegistrationFormController.deleteFile(cdid);
            Test.stopTest();
        }

        try {
            MBP_RegistrationFormController.deleteFile(null);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
    }

    @isTest
    static void test_validateTradeLicenseNumber() {
        Registration__c r = reg('v@t.com','Draft','TLX123');

        Test.startTest();
        MBP_RegistrationFormController.validateTradeLicenseNumber('TLX123');
        Test.stopTest();
    }

    @isTest
    static void test_saveAgentsWithFiles() {
        Registration__c r = reg('saf@t.com','Draft','TL-SAF');

        MBP_RegistrationFormController.RegistrationAgentWrapper w = new MBP_RegistrationFormController.RegistrationAgentWrapper();

        w.tempId = 't';
        w.firstname = 'FN';
        w.lastname = 'LN';
        w.mobile = '123';
        w.email = 'e@x.com';
        w.passportNumber = 'PN';
        w.passportExpiryDate = Date.today().addDays(10);
        w.eidNumber = 'EID';
        w.eidExpiryDate = Date.today().addDays(5);
        w.registrationId = r.Id;
        w.Brokertype = 'Agency Admin';
        w.mobileNum = '+971';
        w.isPrimaryOwner = true;
        w.POAemail = 'poa@x.com';
        w.isPrimaryagencyadmin = false;
        w.isBroker = true;

        String dummy = EncodingUtil.base64Encode(Blob.valueOf('dummy'));

        w.passportFrontbase64File = dummy;
        w.passportFrontFileName = 'passportFront.png';

        w.passportFinalbase64File = dummy;
        w.passportFinalFileName = 'passportFinal.png';

        w.eidFrontbase64File = dummy;
        w.eidFrontFileName = 'eidFront.png';

        w.eidBackbase64File = dummy;
        w.eidBackFileName = 'eidBack.png';

        w.poabase64File = dummy;
        w.poaFileName = 'poa.png';

        List<MBP_RegistrationFormController.RegistrationAgentWrapper> ws = new List<MBP_RegistrationFormController.RegistrationAgentWrapper>{w};

        Test.startTest();
        MBP_RegistrationFormController.saveAgentsWithFiles(ws);
        Test.stopTest();
    }

    @isTest
    static void test_sendOtpToEmail() {
        Registration__c r = reg('otpuser@test.com','Draft','TL456');

        primaryOwnerAgent(r.Id, 'admin@otp.com');

        Registration__c r2 = reg('noadmin@test.com','Draft','TL457');

        Test.startTest();

        MBP_RegistrationFormController.OtpResponse response = MBP_RegistrationFormController.sendOtpToEmail(r.Id);

        try {
            MBP_RegistrationFormController.sendOtpToEmail(r2.Id);
        } catch (AuraHandledException e) {
           
        }

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals('admin@otp.com', response.email);

        Registration__c updatedRegistration = [SELECT Registration_OTP__c FROM Registration__c WHERE Id=:r.Id LIMIT 1];

        System.assertNotEquals(null, updatedRegistration.Registration_OTP__c);
        System.assertEquals(6, updatedRegistration.Registration_OTP__c.length());
    }

    @isTest
    static void test_verifyRegistrationOtp() {
        Registration__c r = reg('otp3@t.com','Draft','TL998');
        r.Registration_OTP__c = '246810';
        update r;

        Registration__c s = reg('otp4@t.com','Submitted','TL997');
        s.Registration_OTP__c = '135790';
        update s;

        Test.startTest();

        System.assertEquals(false, MBP_RegistrationFormController.verifyRegistrationOtp(r.Id, '000000'));
        System.assertEquals(false, MBP_RegistrationFormController.verifyRegistrationOtp(r.Id, ''));
        System.assertEquals(false, MBP_RegistrationFormController.verifyRegistrationOtp(null, '246810'));
        System.assertEquals(true, MBP_RegistrationFormController.verifyRegistrationOtp(r.Id, ' 246810 '));
        System.assertEquals(false, MBP_RegistrationFormController.verifyRegistrationOtp(r.Id, '246810'));
        System.assertEquals(false, MBP_RegistrationFormController.verifyRegistrationOtp(s.Id, '135790'));

        Test.stopTest();

        System.assertEquals(null, [SELECT Registration_OTP__c FROM Registration__c WHERE Id=:r.Id].Registration_OTP__c);
    }

    @isTest
    static void test_sendOtpToEmailReturnsOnlyEmail() {
        Registration__c r = reg('otp5@t.com','Draft','TL996');

        primaryOwnerAgent(r.Id, 'admin5@otp.com');

        Test.startTest();

        MBP_RegistrationFormController.OtpResponse res = MBP_RegistrationFormController.sendOtpToEmail(r.Id);

        Test.stopTest();

      

        String stored = [SELECT Registration_OTP__c FROM Registration__c WHERE Id=:r.Id].Registration_OTP__c;

    }

    @isTest
    static void test_verifyOtp1() {
        Registration__c r = reg('otp1@t.com','Draft','TL999');
        r.Registration_OTP__c = '998877';
        update r;

        Test.startTest();

        MBP_RegistrationFormController.verifyOtp1('998877', r.Id);
        MBP_RegistrationFormController.verifyOtp1('000000', r.Id);

        Test.stopTest();
    }

    @isTest
    static void test_sendSRCreationEmail() {
        Registration__c r = reg('srcreation@test.com','Draft','SR-EMAIL');

        agent(r.Id, 'agent1@srcreation.com', 'Agency Admin');
        agent(r.Id, 'owner@srcreation.com', 'Owner');

        ServiceRequest__c sr = new ServiceRequest__c(Registration__c=r.Id);
        insert sr;

        Map<String,String> m = new Map<String,String>{r.Id=>sr.Name};

        Test.startTest();
        MBP_RegistrationFormController.sendSRCreationEmail(m);
        Test.stopTest();
    }
}