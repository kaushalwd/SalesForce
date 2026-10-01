/**********************************************************************************************************************
* Name               : InviteTokenSignerTest
* Description        : Test coverage for InviteTokenSigner. Exercises sign/verify roundtrip, tampered token rejection,
*                      expired token rejection, malformed input rejection, and missing-secret rejection.
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    04 June 2026    Initial version
**********************************************************************************************************************/
@IsTest
private class InviteTokenSignerTest {

    private static final String TEST_SECRET = 'test-secret-base64-payload-abcdef1234567890';

    @IsTest
    static void generateAndVerifyRoundtrip() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Roundtrip', 'Tester', 'rt@example.com');

        Test.startTest();
        String token = InviteTokenSigner.generate(l.Id);
        InviteTokenSigner.TokenPayload payload = InviteTokenSigner.verify(token);
        Test.stopTest();

        System.assertEquals(l.Id, payload.leadId, 'Lead Id should roundtrip through token.');
        System.assert(payload.expiresAt > System.now(), 'Expiry should be in the future.');
        System.assert(payload.expiresAt < System.now().addDays(6), 'Default expiry should be within 5 days.');
    }

    @IsTest
    static void generateWithCustomExpiry() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Custom', 'Expiry', 'ce@example.com');

        Test.startTest();
        String token = InviteTokenSigner.generate(l.Id, 3);
        InviteTokenSigner.TokenPayload payload = InviteTokenSigner.verify(token);
        Test.stopTest();

        System.assert(payload.expiresAt < System.now().addDays(4), 'Custom 3-day expiry should be honoured.');
        System.assert(payload.expiresAt > System.now().addDays(2), 'Expiry should not be earlier than expected.');
    }

    @IsTest
    static void generateRejectsNullLeadId() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        try {
            InviteTokenSigner.generate(null);
            System.assert(false, 'Expected TokenException for null Lead Id.');
        } catch (InviteTokenSigner.TokenException ex) {
            System.assert(ex.getMessage().contains('Lead Id'), 'Error message should mention Lead Id.');
        }
    }

    @IsTest
    static void verifyRejectsTamperedSignature() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Tamper', 'Test', 'tt@example.com');
        String token = InviteTokenSigner.generate(l.Id);
        // Flip a character in the signature half
        List<String> parts = token.split('\\.');
        String tampered = parts[0] + '.' + (parts[1].startsWith('A') ? 'B' : 'A') + parts[1].substring(1);

        Test.startTest();
        try {
            InviteTokenSigner.verify(tampered);
            System.assert(false, 'Tampered signature should be rejected.');
        } catch (InviteTokenSigner.TokenException ex) {
            System.assert(ex.getMessage().contains('signature'), 'Error should mention signature.');
        }
        Test.stopTest();
    }

    @IsTest
    static void verifyRejectsTamperedPayload() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Payload', 'Tamper', 'pt@example.com');
        String token = InviteTokenSigner.generate(l.Id);
        List<String> parts = token.split('\\.');
        // Replace payload with garbage but keep original signature
        String tampered = InviteTokenSigner.base64UrlEncode(Blob.valueOf('{"lid":"0Q0000000000001","exp":9999999999999}')) + '.' + parts[1];

        try {
            InviteTokenSigner.verify(tampered);
            System.assert(false, 'Tampered payload should be rejected.');
        } catch (InviteTokenSigner.TokenException ex) {
            System.assert(ex.getMessage().contains('signature'), 'Error should mention signature.');
        }
    }

    @IsTest
    static void verifyRejectsMalformedToken() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        for (String bad : new List<String>{ null, '', 'no-dot-here', 'too.many.dots' }) {
            try {
                InviteTokenSigner.verify(bad);
                System.assert(false, 'Malformed token should be rejected: ' + bad);
            } catch (InviteTokenSigner.TokenException ex) {
                System.assert(String.isNotBlank(ex.getMessage()));
            }
        }
    }

    @IsTest
    static void verifyRejectsExpiredToken() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        // Manually build an expired token with the same secret
        Lead l = newLead('Expired', 'Token', 'et@example.com');
        Long pastExp = System.now().addDays(-1).getTime();
        Map<String, Object> payload = new Map<String, Object>{ 'lid' => String.valueOf(l.Id), 'exp' => pastExp };
        Blob payloadBlob = Blob.valueOf(JSON.serialize(payload));
        String payloadB64 = InviteTokenSigner.base64UrlEncode(payloadBlob);
        Blob sig = Crypto.generateMac('HmacSHA256', payloadBlob, Blob.valueOf(TEST_SECRET));
        String sigB64 = InviteTokenSigner.base64UrlEncode(sig);
        String expiredToken = payloadB64 + '.' + sigB64;

        Test.startTest();
        try {
            InviteTokenSigner.verify(expiredToken);
            System.assert(false, 'Expired token should be rejected.');
        } catch (InviteTokenSigner.TokenException ex) {
            System.assert(ex.getMessage().toLowerCase().contains('expired'), 'Error should mention expiry.');
        }
        Test.stopTest();
    }

    private static Lead newLead(String firstName, String lastName, String email) {
        Lead l = new Lead(FirstName = firstName, LastName = lastName, Email = email, Company = 'Test', Status = 'New');
        Schema.SObjectField projectInterest = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('ProjectInterest__c');
        if (projectInterest != null && projectInterest.getDescribe().getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry e : projectInterest.getDescribe().getPicklistValues()) {
                if (e.isActive()) { l.put('ProjectInterest__c', e.getValue()); break; }
            }
        }
        insert l;
        return l;
    }

    @IsTest
    static void verifyRejectsMissingSecret() {
        InviteTokenSigner.secretOverride = null;
        try {
            InviteTokenSigner.verify('anything.anything');
            System.assert(false, 'Should throw when secret is not configured.');
        } catch (InviteTokenSigner.TokenException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }
}