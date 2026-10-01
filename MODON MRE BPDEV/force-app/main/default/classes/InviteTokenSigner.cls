/**********************************************************************************************************************
* Name               : InviteTokenSigner
* Description        : HMAC-SHA256 signer/verifier for public-invite microsite tokens. Payload carries the encrypted
*                      Lead Id and an expiry timestamp. Signature is computed with a secret stored on
*                      Site_Config__mdt.Active_Microsite.Invite_Token_Secret__c. Format:
*                          <urlEncode(base64(payloadJson))>.<urlEncode(base64(hmacSha256))>
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    04 June 2026    Initial invite token signer for HGE invite flow
**********************************************************************************************************************/
public without sharing class InviteTokenSigner {

    private static final String CMT_RECORD_NAME = 'Active_Microsite';
    private static final String HMAC_ALGORITHM = 'HmacSHA256';
    private static final Integer DEFAULT_EXPIRY_DAYS = 5;

    @TestVisible
    private static String secretOverride = null;

    public class TokenException extends Exception {}

    public class TokenPayload {
        public Id leadId;
        public DateTime expiresAt;
    }

    public static String generate(Id leadId) {
        return generate(leadId, DEFAULT_EXPIRY_DAYS);
    }

    public static String generate(Id leadId, Integer expiryDays) {
        if (leadId == null) throw new TokenException('Lead Id is required to generate a token.');
        Integer days = expiryDays == null || expiryDays <= 0 ? DEFAULT_EXPIRY_DAYS : expiryDays;
        Long expiresAt = System.now().addDays(days).getTime();
        Map<String, Object> payload = new Map<String, Object>{
            'lid' => String.valueOf(leadId),
            'exp' => expiresAt
        };
        Blob payloadBlob = Blob.valueOf(JSON.serialize(payload));
        String payloadB64 = base64UrlEncode(payloadBlob);
        Blob sigBlob = Crypto.generateMac(HMAC_ALGORITHM, payloadBlob, Blob.valueOf(readSecret()));
        String sigB64 = base64UrlEncode(sigBlob);
        return payloadB64 + '.' + sigB64;
    }

    public static TokenPayload verify(String token) {
        if (String.isBlank(token)) throw new TokenException('Token is required.');
        if (!token.contains('.')) throw new TokenException('Token format is invalid.');
        List<String> parts = token.split('\\.');
        if (parts.size() != 2) throw new TokenException('Token format is invalid.');

        String payloadB64 = parts[0];
        String sigB64 = parts[1];

        Blob payloadBlob;
        try {
            payloadBlob = base64UrlDecode(payloadB64);
        } catch (Exception ex) {
            throw new TokenException('Token format is invalid.');
        }

        Blob expectedSig = Crypto.generateMac(HMAC_ALGORITHM, payloadBlob, Blob.valueOf(readSecret()));
        String expectedB64 = base64UrlEncode(expectedSig);
        if (!constantTimeEquals(expectedB64, sigB64)) {
            throw new TokenException('Token signature does not match.');
        }

        Map<String, Object> claims;
        try {
            claims = (Map<String, Object>) JSON.deserializeUntyped(payloadBlob.toString());
        } catch (Exception ex) {
            throw new TokenException('Token payload is invalid.');
        }
        String leadIdStr = (String) claims.get('lid');
        Object expRaw = claims.get('exp');
        if (String.isBlank(leadIdStr) || expRaw == null) {
            throw new TokenException('Token payload is incomplete.');
        }
        Long expMillis;
        try {
            expMillis = (Long) expRaw;
        } catch (Exception ex) {
            expMillis = Long.valueOf(String.valueOf(expRaw));
        }
        if (System.now().getTime() > expMillis) {
            throw new TokenException('Token has expired.');
        }

        TokenPayload result = new TokenPayload();
        result.leadId = Id.valueOf(leadIdStr);
        result.expiresAt = DateTime.newInstance(expMillis);
        return result;
    }

    private static String readSecret() {
        if (String.isNotBlank(secretOverride)) return secretOverride;
        String recordName = CMT_RECORD_NAME;
        List<Site_Config__mdt> rows = Database.queryWithBinds(
            'SELECT Invite_Token_Secret__c FROM Site_Config__mdt ' +
            'WHERE DeveloperName = :recordName LIMIT 1',
            new Map<String, Object>{ 'recordName' => recordName },
            AccessLevel.SYSTEM_MODE
        );
        if (rows.isEmpty() || String.isBlank(rows[0].Invite_Token_Secret__c)) {
            throw new TokenException('Invite token secret is not configured.');
        }
        return rows[0].Invite_Token_Secret__c;
    }

    @TestVisible
    private static String base64UrlEncode(Blob b) {
        String std = EncodingUtil.base64Encode(b);
        return std.replace('+', '-').replace('/', '_').replace('=', '');
    }

    @TestVisible
    private static Blob base64UrlDecode(String s) {
        String b64 = s.replace('-', '+').replace('_', '/');
        Integer mod = Math.mod(b64.length(), 4);
        if (mod == 2) b64 += '==';
        else if (mod == 3) b64 += '=';
        else if (mod == 1) throw new TokenException('Token payload is invalid.');
        return EncodingUtil.base64Decode(b64);
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) return false;
        Integer mismatch = 0;
        for (Integer i = 0; i < a.length(); i++) {
            mismatch |= a.charAt(i) ^ b.charAt(i);
        }
        return mismatch == 0;
    }
}