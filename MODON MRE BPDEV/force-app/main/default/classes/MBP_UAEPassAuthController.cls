public without sharing class MBP_UAEPassAuthController {

    private static final String CLIENT_ID     = 'sandbox_stage';
    private static final String CLIENT_SECRET = 'sandbox_stage';
    private static final String REDIRECT_URI  = 'https://modonproperties--bpdev.sandbox.my.site.com/Brokers/s/uaepass-callback';
    private static final String SCOPE         = 'urn:uae:digitalid:profile:general';
    private static final String ACR_VALUES    = 'urn:safelayer:tws:policies:authentication:level:low';
    private static final String AUTH_BASE     = 'https://stg-id.uaepass.ae/idshub/authorize';
    private static final String TOKEN_URL     = 'https://stg-id.uaepass.ae/idshub/token';
    private static final String USERINFO_URL  = 'https://stg-id.uaepass.ae/idshub/userinfo';

    @AuraEnabled(cacheable=false)
    public static String getAuthorizeUrl() {
        String state = generateState();
        return AUTH_BASE
            + '?response_type=code'
            + '&client_id='    + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(REDIRECT_URI, 'UTF-8')
            + '&scope='        + EncodingUtil.urlEncode(SCOPE, 'UTF-8')
            + '&state='        + state
            + '&acr_values='   + EncodingUtil.urlEncode(ACR_VALUES, 'UTF-8');
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> authenticateWithCode(String code) {
        String credentials = EncodingUtil.base64Encode(
            Blob.valueOf(CLIENT_ID + ':' + CLIENT_SECRET)
        );

        HttpRequest tokenReq = new HttpRequest();
        tokenReq.setEndpoint(TOKEN_URL
            + '?grant_type=authorization_code'
            + '&redirect_uri=' + EncodingUtil.urlEncode(REDIRECT_URI, 'UTF-8')
            + '&code='         + EncodingUtil.urlEncode(code, 'UTF-8')
        );
        tokenReq.setMethod('POST');
        tokenReq.setHeader('Authorization', 'Basic ' + credentials);
        tokenReq.setHeader('Content-Type', 'multipart/form-data; charset=UTF-8');
        tokenReq.setTimeout(20000);

        HttpResponse tokenRes = new Http().send(tokenReq);
        if (tokenRes.getStatusCode() != 200) {
            throw new AuraHandledException(
                'Token exchange failed (' + tokenRes.getStatusCode() + '): ' + tokenRes.getBody()
            );
        }

        Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody());
        String accessToken = (String) tokenData.get('access_token');

        HttpRequest userReq = new HttpRequest();
        userReq.setEndpoint(USERINFO_URL);
        userReq.setMethod('GET');
        userReq.setHeader('Authorization', 'Bearer ' + accessToken);
        userReq.setTimeout(20000);

        HttpResponse userRes = new Http().send(userReq);
        if (userRes.getStatusCode() != 200) {
            throw new AuraHandledException(
                'Userinfo failed (' + userRes.getStatusCode() + '): ' + userRes.getBody()
            );
        }

        Map<String, Object> userInfo = (Map<String, Object>) JSON.deserializeUntyped(userRes.getBody());
        userInfo.put('access_token', accessToken);
        return userInfo;
    }

    @AuraEnabled(cacheable=false)
    public static String loginWithUAEPass(String uaePassUUID, String uaePassEmail) {
        try {
            // 1. Find by UUID first, fallback to email
            List<User> users = [
                SELECT Id, Username, IsActive, UAE_Pass_UUID__c
                FROM User
                WHERE UAE_Pass_UUID__c = :uaePassUUID
                  AND IsActive = true
                LIMIT 1
            ];

            if (users.isEmpty()) {
                users = [
                    SELECT Id, Username, IsActive, UAE_Pass_UUID__c
                    FROM User
                    WHERE Email = :uaePassEmail
                      AND IsActive = true
                      AND UserType = 'PowerPartner'
                    LIMIT 1
                ];
            }

            if (users.isEmpty()) {
                throw new AuraHandledException('NO_USER_FOUND');
            }

            User u = users[0];

            // 2. Check frozen
            UserLogin ul = [
                SELECT IsFrozen FROM UserLogin
                WHERE UserId = :u.Id
                LIMIT 1
            ];
            if (ul.IsFrozen) {
                throw new AuraHandledException('FROZEN_USER');
            }

            // 3. Stable deterministic password
            String stablePassword = buildStablePassword(u.Id, uaePassUUID);

            // 4. Set password only on first UAE Pass login or if UUID changed
            if (u.UAE_Pass_UUID__c != uaePassUUID) {
                System.setPassword(u.Id, stablePassword);
                u.UAE_Pass_UUID__c = uaePassUUID;
                update u;
            }

            // 5. Establish session
            ApexPages.PageReference pageRef = Site.login(u.Username, stablePassword, '/Brokers/s/');
            if (pageRef == null) {
                throw new AuraHandledException('LOGIN_FAILED');
            }

            return pageRef.getUrl();

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('loginWithUAEPass error: ' + e.getMessage());
            throw new AuraHandledException('Login error: ' + e.getMessage());
        }
    }

    private static String buildStablePassword(String userId, String uuid) {
        String salt    = Label.MBP_UAEPass_PasswordSalt;
        Blob   hmac    = Crypto.generateMac('HmacSHA256', Blob.valueOf(userId + uuid), Blob.valueOf(salt));
        String encoded = EncodingUtil.base64Encode(hmac);
        return encoded.substring(0, 20) + 'Aa1!';
    }

    private static String generateState() {
        String base = String.valueOf(Math.random()).replace('0.', '');
        String ts   = String.valueOf(DateTime.now().getTime());
        return (base + ts).substring(0, 16);
    }
}