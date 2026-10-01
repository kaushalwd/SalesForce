@isTest
private class EoiSiteVisitorServiceTest {

    private static EOI_Public_Registration__c reg(String email, String mobile, String source) {
        EOI_Public_Registration__c r = new EOI_Public_Registration__c(
            Status__c = 'Verified', CustomerType__c = 'Individual', FirstName__c = 'Sara', LastName__c = 'Test',
            Email__c = email, Mobile__c = mobile, ResidentStatus__c = 'Non Resident', PassportNumber__c = 'P1',
            Source__c = source, VerifiedAt__c = Datetime.now(), VerifiedChannel__c = 'Email'
        );
        insert r;
        return r;
    }

    @isTest
    static void firstEmailVerificationCreatesTheVisitorAndLinksTheRow() {
        EOI_Public_Registration__c r = reg('sara@example.com', '+971501234567', 'Wadeem Microsite');
        Test.startTest();
        EoiSiteVisitorService.Result res = EoiSiteVisitorService.onVerified(r, 'Email', 'Sara@Example.com', null);
        Test.stopTest();
        System.assertEquals(false, res.returning);
        System.assertEquals(0, res.priorVisits);
        EOI_Site_Visitor__c v = [SELECT Identity_Type__c, Verified_Email__c, Verified_Mobile__c, Visit_Count__c, Verified_Count__c,
            First_Source__c, Last_Registration__c, Journey_Trail__c, Identity_Key__c FROM EOI_Site_Visitor__c WHERE Id = :res.visitor.Id];
        System.assertEquals('Email', v.Identity_Type__c);
        System.assertEquals('sara@example.com', v.Verified_Email__c, 'lower-cased');
        System.assertEquals(null, v.Verified_Mobile__c, 'typed mobile is not verified');
        System.assertEquals(1, v.Visit_Count__c);
        System.assertEquals(1, v.Verified_Count__c);
        System.assertEquals('Wadeem Microsite', v.First_Source__c);
        System.assertEquals(r.Id, v.Last_Registration__c);
        System.assert(v.Journey_Trail__c.contains('new visitor'));
        System.assertEquals(EoiSiteVisitorService.identityKey('Email', 'sara@example.com'), v.Identity_Key__c);
        EOI_Public_Registration__c back = [SELECT Visitor__c, Identity_Key__c, Verified_Identifier__c, Is_Returning__c, Prior_Visit_Count__c
            FROM EOI_Public_Registration__c WHERE Id = :r.Id];
        System.assertEquals(v.Id, back.Visitor__c);
        System.assertEquals(v.Identity_Key__c, back.Identity_Key__c);
        System.assertEquals('Email', back.Verified_Identifier__c);
        System.assertEquals(false, back.Is_Returning__c);
        System.assertEquals(0, back.Prior_Visit_Count__c);
    }

    @isTest
    static void sameEmailAgainIsReturning() {
        EOI_Public_Registration__c a = reg('sara@example.com', '+971501234567', 'Wadeem Microsite');
        EoiSiteVisitorService.onVerified(a, 'Email', 'sara@example.com', null);
        EOI_Public_Registration__c b = reg('sara@example.com', '+971501234567', 'ADIB Microsite');
        Test.startTest();
        EoiSiteVisitorService.Result res = EoiSiteVisitorService.onVerified(b, 'Email', 'sara@example.com', null);
        Test.stopTest();
        System.assertEquals(true, res.returning);
        System.assertEquals(1, res.priorVisits);
        System.assertEquals(1, [SELECT COUNT() FROM EOI_Site_Visitor__c]);
        EOI_Site_Visitor__c v = [SELECT Visit_Count__c, Verified_Count__c, Last_Registration__c FROM EOI_Site_Visitor__c];
        System.assertEquals(2, v.Visit_Count__c);
        System.assertEquals(2, v.Verified_Count__c);
        System.assertEquals(b.Id, v.Last_Registration__c);
        System.assertEquals(true, [SELECT Is_Returning__c FROM EOI_Public_Registration__c WHERE Id = :b.Id].Is_Returning__c);
    }

    @isTest
    static void mobileVerifiedLaterMergesIntoTheEmailVisitor() {
        EOI_Public_Registration__c a = reg('sara@example.com', '+971501234567', 'Wadeem Microsite');
        EoiSiteVisitorService.onVerified(a, 'Email', 'sara@example.com', null);
        EOI_Public_Registration__c b = reg('other@example.com', '+971501234567', 'Wadeem Microsite');
        Test.startTest();
        EoiSiteVisitorService.Result res = EoiSiteVisitorService.onVerified(b, 'Mobile', '+971501234567', null);
        Test.stopTest();
        System.assertEquals(true, res.returning, 'mobile was typed on the earlier verified registration');
        System.assertEquals(1, [SELECT COUNT() FROM EOI_Site_Visitor__c]);
        EOI_Site_Visitor__c v = [SELECT Verified_Email__c, Verified_Mobile__c, Mobile_Verified_At__c FROM EOI_Site_Visitor__c];
        System.assertEquals('sara@example.com', v.Verified_Email__c);
        System.assertEquals('+971501234567', v.Verified_Mobile__c);
        System.assertNotEquals(null, v.Mobile_Verified_At__c);
    }

    @isTest
    static void uaePassWithKnownEmailReusesTheVisitorAndStoresTheUuid() {
        EOI_Public_Registration__c a = reg('sara@example.com', null, 'Wadeem Microsite');
        EoiSiteVisitorService.onVerified(a, 'Email', 'sara@example.com', null);
        EOI_Public_Registration__c b = reg('sara@example.com', '+971501234567', 'Wadeem Microsite');
        UAEPassUserInfo u = (UAEPassUserInfo) JSON.deserialize(
            '{"uuid":"uuid-1","email":"sara@example.com","mobile":"971501234567","emiratesId":"784-1990-1234567-1"}', UAEPassUserInfo.class);
        Test.startTest();
        EoiSiteVisitorService.Result res = EoiSiteVisitorService.onVerified(b, 'UAE Pass', 'uuid-1', u);
        Test.stopTest();
        System.assertEquals(true, res.returning);
        EOI_Site_Visitor__c v = [SELECT UAE_Pass_UUID__c, Verified_Mobile__c, Identity_Type__c FROM EOI_Site_Visitor__c];
        System.assertEquals('uuid-1', v.UAE_Pass_UUID__c);
        System.assertEquals('+971501234567', v.Verified_Mobile__c, 'UAE PASS proves the mobile too');
        System.assertEquals('Email', v.Identity_Type__c, 'first proof is kept');
        System.assertEquals(1, [SELECT COUNT() FROM EOI_Site_Visitor__c]);
    }

    @isTest
    static void unknownPersonIsNotKnownAndTrailAppends() {
        System.assertEquals(null, EoiSiteVisitorService.known('nobody@example.com', '+971500000000'));
        EOI_Public_Registration__c a = reg('sara@example.com', null, 'Wadeem Microsite');
        EoiSiteVisitorService.Result res = EoiSiteVisitorService.onVerified(a, 'Email', 'sara@example.com', null);
        System.assertNotEquals(null, EoiSiteVisitorService.known('SARA@example.com', null));
        Test.startTest();
        EoiSiteVisitorService.appendTrail(res.visitor.Id, 'Payment captured  CKO-1');
        EoiSiteVisitorService.appendTrail(null, 'ignored');
        Test.stopTest();
        String trail = [SELECT Journey_Trail__c FROM EOI_Site_Visitor__c WHERE Id = :res.visitor.Id].Journey_Trail__c;
        System.assert(trail.contains('Verified by email'));
        System.assert(trail.contains('Payment captured  CKO-1'));
    }

    /** The real site guest user, with only its permission set, can complete a verification and leave the trail. */
    @isTest
    static void siteGuestUserWritesVisitorAndTasks() {
        // 11 Sep 2026 (Aurelix): the guest user's display name differs per org (QA: "EOI Microsite User");
        // find it by type and profile so this branch runs everywhere the site is deployed.
        List<User> guests = [SELECT Id FROM User WHERE UserType = 'Guest' AND Profile.Name = 'Modon EOI Microsite Profile' AND IsActive = true LIMIT 1];
        if (guests.isEmpty()) {
            return;
        }
        Id regId;
        Id requestId;
        System.runAs(guests[0]) {
            EOIService.IdentityRequest r = new EOIService.IdentityRequest();
            r.customerType = 'Individual';
            r.firstName = 'Guest';
            r.lastName = 'Probe';
            r.email = 'guest.probe@example.com';
            r.mobile = '+971509998877';
            r.passportNumber = 'P99';
            r.locale = 'en';
            r.userAgent = 'test';
            regId = EOIWadeemSiteController.submitIdentity(r);
            requestId = EOIWadeemSiteController.startOtp(regId, 'Email').verificationRequestId;
        }
        Verification_Request__c vr = [SELECT Id FROM Verification_Request__c WHERE Id = :requestId];
        vr.Code_Hash__c = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf('424242|' + UserInfo.getOrganizationId())));
        update vr;
        Test.startTest();
        System.runAs(guests[0]) {
            System.assertEquals(true, EOIWadeemSiteController.verifyOtp(regId, requestId, '424242').verified);
        }
        Test.stopTest();
        Id visitorId = [SELECT Visitor__c FROM EOI_Public_Registration__c WHERE Id = :regId].Visitor__c;
        System.assertNotEquals(null, visitorId, 'guest created and linked the visitor');
        System.assertEquals(2, [SELECT COUNT() FROM Task WHERE WhatId = :visitorId], 'guest wrote both milestones');
    }
}