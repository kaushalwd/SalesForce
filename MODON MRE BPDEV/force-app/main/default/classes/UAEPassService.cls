/**
 * UAE Pass OAuth service: authorize URL, code-for-token exchange, userinfo.
 * Config-driven via UAEPassConfig__mdt (active record). All callouts are
 * server-side (UAE Pass blocks browser CORS on token/userinfo).
 * @author Aurelix
 */
public inherited sharing class UAEPassService {

    private static final Integer STATE_TTL_MINUTES = 15;
    private static final Integer TIMEOUT_MS = 30000;
    /* @TestVisible (11 Sep 2026, Aurelix): lets tests inject an in-memory config so they do not
       depend on an active UAEPassConfig__mdt record, which carries secrets and is not shipped. */
    @TestVisible private static UAEPassConfig__mdt cachedConfig;

    public static UAEPassConfig__mdt getConfig() {
        if (cachedConfig == null) {
            for (UAEPassConfig__mdt c : [
                SELECT Base_Url__c, Client_Id__c, Client_Secret__c, Redirect_Uri__c,
                       Scope__c, Acr_Values__c, State_Secret__c
                FROM UAEPassConfig__mdt
                WHERE Is_Active__c = true
                LIMIT 1
            ]) {
                cachedConfig = c;
            }
        }
        if (cachedConfig == null) {
            throw new UAEPassException('No active UAEPassConfig__mdt record.');
        }
        return cachedConfig;
    }

    // ---------- state (CSRF guard) ----------

    /** Opaque state: nonce.expiryEpoch.hmac — validated statelessly on return. */
    public static String generateState() {
        String nonce = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        Long expiry = Datetime.now().addMinutes(STATE_TTL_MINUTES).getTime();
        String payload = nonce + '.' + expiry;
        return payload + '.' + sign(payload);
    }

    public static Boolean validateState(String state) {
        if (String.isBlank(state)) {
            return false;
        }
        List<String> parts = state.split('\\.');
        if (parts.size() != 3) {
            return false;
        }
        String payload = parts[0] + '.' + parts[1];
        // constant-time comparison via double HMAC
        Blob a = Crypto.generateMac('hmacSHA256', Blob.valueOf(sign(payload)), Blob.valueOf(getConfig().State_Secret__c));
        Blob b = Crypto.generateMac('hmacSHA256', Blob.valueOf(parts[2]), Blob.valueOf(getConfig().State_Secret__c));
        if (EncodingUtil.convertToHex(a) != EncodingUtil.convertToHex(b)) {
            return false;
        }
        Long expiry;
        try {
            expiry = Long.valueOf(parts[1]);
        } catch (Exception e) {
            return false;
        }
        return Datetime.now().getTime() <= expiry;
    }

    private static String sign(String payload) {
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(payload), Blob.valueOf(getConfig().State_Secret__c));
        return EncodingUtil.base64Encode(mac).replace('+', '-').replace('/', '_').replace('=', '');
    }

    // ---------- OAuth steps ----------

    public static String getAuthorizeUrl(String state) {
        UAEPassConfig__mdt cfg = getConfig();
        return cfg.Base_Url__c + '/idshub/authorize'
            + '?response_type=code'
            + '&client_id=' + EncodingUtil.urlEncode(cfg.Client_Id__c, 'UTF-8')
            + '&scope=' + EncodingUtil.urlEncode(cfg.Scope__c, 'UTF-8')
            + '&state=' + EncodingUtil.urlEncode(state, 'UTF-8')
            + '&acr_values=' + EncodingUtil.urlEncode(cfg.Acr_Values__c, 'UTF-8')
            + '&ui_locales=en'
            + '&redirect_uri=' + EncodingUtil.urlEncode(cfg.Redirect_Uri__c, 'UTF-8');
    }

    public static String exchangeCodeForToken(String code) {
        if (String.isBlank(code)) {
            throw new UAEPassException('Missing authorization code.');
        }
        UAEPassConfig__mdt cfg = getConfig();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(cfg.Base_Url__c + '/idshub/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(TIMEOUT_MS);
        // redirect_uri must be byte-identical to the authorize call: same config field
        req.setBody('grant_type=authorization_code'
            + '&client_id=' + EncodingUtil.urlEncode(cfg.Client_Id__c, 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(cfg.Client_Secret__c, 'UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(cfg.Redirect_Uri__c, 'UTF-8')
            + '&code=' + EncodingUtil.urlEncode(code, 'UTF-8'));

        HttpResponse res = new Http().send(req);
        Map<String, Object> body = parseJson(res.getBody());
        if (res.getStatusCode() != 200) {
            throw new UAEPassException('Token exchange failed: ' + errorOf(body, res.getStatusCode()));
        }
        String token = (String) body.get('access_token');
        if (String.isBlank(token)) {
            throw new UAEPassException('Token exchange returned no access token.');
        }
        return token;
    }

    public static UAEPassUserInfo getUserInfo(String accessToken) {
        if (String.isBlank(accessToken)) {
            throw new UAEPassException('Missing access token.');
        }
        UAEPassConfig__mdt cfg = getConfig();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(cfg.Base_Url__c + '/idshub/userinfo');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT_MS);

        HttpResponse res = new Http().send(req);
        Map<String, Object> body = parseJson(res.getBody());
        if (res.getStatusCode() != 200) {
            throw new UAEPassException('Userinfo failed: ' + errorOf(body, res.getStatusCode()));
        }
        return UAEPassUserInfo.parse(body);
    }

    /** Single entry point for the callback: validates state, then completes the flow. */
    public static UAEPassUserInfo completeLogin(String code, String state) {
        if (!validateState(state)) {
            throw new UAEPassException('Invalid or expired state.');
        }
        return getUserInfo(exchangeCodeForToken(code));
    }

    /** Logout must be a top-level browser redirect to this URL, never a server call. */
    public static String getLogoutUrl(String postLogoutRedirect) {
        return getConfig().Base_Url__c + '/idshub/logout?redirect_uri='
            + EncodingUtil.urlEncode(postLogoutRedirect, 'UTF-8');
    }

    // ---------- helpers ----------

    private static Map<String, Object> parseJson(String body) {
        try {
            Object o = JSON.deserializeUntyped(body);
            return o instanceof Map<String, Object> ? (Map<String, Object>) o : new Map<String, Object>();
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }

    private static String errorOf(Map<String, Object> body, Integer status) {
        String err = (String) body.get('error');
        return String.isBlank(err) ? ('HTTP ' + status) : err;
    }
}