/**
 * MBP_UAEPassLeadController
 * ─────────────────────────────────────────────────────────────────────────────
 * UAE Pass integration for Lead creation via EID lookup.
 * After the logged-in user authenticates with UAE Pass, fetches all available
 * profile fields and returns them to the LWC for Lead pre-population.
 *
 * Custom Labels required:
 *   UAEPass_Client_Id         — Connected App client_id
 *   UAEPass_Client_Secret     — Connected App client_secret
 *   UAEPass_Redirect_URI_Lead — Redirect URI registered for this lead flow
 *   UAEPass_Base_URL          — e.g. https://stg-id.uaepass.ae (staging)
 *                                      https://id.uaepass.ae     (production)
 *
 * Remote Site Settings required:
 *   stg-id.uaepass.ae  (staging)
 *   id.uaepass.ae      (production)
 */
public with sharing class MBP_UAEPassLeadController {

    private static final String BASE_URL      = 'https://stg-id.uaepass.ae';
    private static final String CLIENT_ID     = 'sandbox_stage';
    private static final String CLIENT_SECRET = 'sandbox_stage';
    private static final String REDIRECT_URI  = 'https://modonproperties--bpdev.sandbox.my.site.com/Brokers/eid-lead-capture';

    // ─── Step 1: Build the UAE Pass Authorization URL ────────────────────────
    /**
     * Returns the full UAE Pass authorization URL.
     * The LWC will redirect the browser to this URL.
     * After UAE Pass authentication, UAE Pass redirects back to REDIRECT_URI
     * with ?code=<auth_code>&state=<state>
     *
     * @param eid  The Emirates ID entered by the user (used as login_hint)
     * @return     Full authorization URL string
     */
    @AuraEnabled
    public static String getLeadAuthorizeUrl(String eid) {
        try {
            String state = generateState();
            String nonce = generateNonce();

            // Scopes — request the maximum profile dataset UAE Pass exposes
            // urn:uae:digitalid:profile       → core profile (name, DOB, gender, nationality)
            // urn:uae:digitalid:profile:general → extended profile
            // urn:uae:digitalid:idn            → Emirates ID Number
            // openid email phone               → standard OIDC claims
            String scope = EncodingUtil.urlEncode(
                'openid profile email phone urn:uae:digitalid:profile urn:uae:digitalid:profile:general urn:uae:digitalid:idn',
                'UTF-8'
            );

            String url = BASE_URL + '/idshub/authorize'
                + '?response_type=code'
                + '&client_id='     + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8')
                + '&redirect_uri='  + EncodingUtil.urlEncode(REDIRECT_URI, 'UTF-8')
                + '&scope='         + scope
                + '&state='         + state
                + '&nonce='         + nonce
                + '&acr_values=urn:safelayer:tws:policies:authentication:level:low' 
                + '&ui_locales=en';

            // Append login_hint if EID is provided — pre-fills the EID field on UAE Pass
            if (String.isNotBlank(eid)) {
                url += '&login_hint=' + EncodingUtil.urlEncode(eid.trim(), 'UTF-8');
            }

            return url;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to build UAE Pass URL: ' + e.getMessage());
        }
    }

    // ─── Step 2: Exchange Auth Code for Access Token ─────────────────────────
    /**
     * Exchanges the OAuth authorization code for an access token.
     * Called by the LWC after UAE Pass redirects back with ?code=...
     *
     * @param code  Authorization code from the UAE Pass callback
     * @return      JSON string containing access_token, token_type, expires_in
     */
    @AuraEnabled
    public static String exchangeCodeForToken(String code) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + '/idshub/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(30000);

            String body = 'grant_type=authorization_code'
                + '&client_id='     + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(CLIENT_SECRET, 'UTF-8')
                + '&redirect_uri='  + EncodingUtil.urlEncode(REDIRECT_URI, 'UTF-8')
                + '&code='          + EncodingUtil.urlEncode(code, 'UTF-8');

            req.setBody(body);
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                throw new AuraHandledException(
                    'Token exchange failed. Status: ' + res.getStatusCode()
                    + ' | Body: ' + res.getBody()
                );
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Token exchange error: ' + e.getMessage());
        }
    }

    // ─── Step 3: Fetch Full User Profile ─────────────────────────────────────
    /**
     * Calls the UAE Pass /userinfo endpoint with the access token.
     * Returns ALL available profile fields as a UAEPassProfile wrapper.
     *
     * @param accessToken  Bearer token from exchangeCodeForToken()
     * @return             UAEPassProfile with all available fields populated
     */
    @AuraEnabled
    public static UAEPassProfile getUserProfile(String accessToken) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + '/idshub/userinfo');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return mapToProfile(raw);
            } else {
                throw new AuraHandledException(
                    'Profile fetch failed. Status: ' + res.getStatusCode()
                    + ' | Body: ' + res.getBody()
                );
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Profile fetch error: ' + e.getMessage());
        }
    }

    // ─── Step 4 (Optional): Create / Upsert Lead from Profile ────────────────
    /**
     * Creates or upserts a Lead record from the UAE Pass profile data.
     * Upserts on UAE_Pass_UUID__c to prevent duplicate leads.
     *
     * @param profile  The UAEPassProfile returned from getUserProfile()
     * @return         Id of the created/updated Lead
     */
    @AuraEnabled
    public static String upsertLeadFromProfile(UAEPassProfile profile) {
        try {
            Lead l = new Lead();

            // Identity
            l.UAE_Pass_UUID__c   = profile.uuid;
            l.EIDNumber__c     = profile.idn;   // custom field — EID number

            // Name
            l.FirstName          = profile.firstNameEn;
            l.LastName           = String.isNotBlank(profile.lastNameEn) ? profile.lastNameEn : 'Unknown';

            // Localised Arabic name
           // l.First_Name_AR__c   = profile.firstNameAr;
           // l.Last_Name_AR__c    = profile.lastNameAr;

            // Contact
            l.Email              = profile.email;
            l.Phone              = profile.mobile;
            l.MobilePhone        = profile.mobile;

            // Demographics
           // l.Gender__c          = profile.gender;
            l.Birthdate__c       = parseDate(profile.dateOfBirth);
            l.Nationality__c     = profile.nationality;
           // l.Nationality_Code__c = profile.nationalityCode;

            // Address (UAE Pass returns structured address when granted)
            l.Street             = profile.streetAddress;
            l.City               = profile.city;
            l.State              = profile.emirate;
            l.Country            = 'United Arab Emirates';

            // Document
            l.EmiratesIDExpiryDate__c  = parseDate(profile.idExpiryDate);
          //  l.ID_Type__c         = profile.idType;

            // Source tracking
            l.LeadSource         = 'UAE Pass';
            l.UAE_Pass_Verified__c = true;

            // Company placeholder — required field
            if (String.isBlank(l.Company)) {
                l.Company = String.isNotBlank(profile.nationality) ? profile.nationality + ' Individual' : 'Individual';
            }

            Database.UpsertResult result = Database.upsert(l, Lead.UAE_Pass_UUID__c, false);

            if (result.isSuccess()) {
                return result.getId();
            } else {
                String errors = '';
                for (Database.Error err : result.getErrors()) {
                    errors += err.getMessage() + '; ';
                }
                throw new AuraHandledException('Lead upsert failed: ' + errors);
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Lead creation error: ' + e.getMessage());
        }
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private static UAEPassProfile mapToProfile(Map<String, Object> raw) {
        UAEPassProfile p = new UAEPassProfile();

        // Standard OIDC
        p.uuid              = str(raw, 'sub');
        p.email             = str(raw, 'email');
        p.emailVerified     = raw.containsKey('email_verified') ? String.valueOf(raw.get('email_verified')) : null;
        p.mobile            = str(raw, 'phone_number');
        p.mobileVerified    = raw.containsKey('phone_number_verified') ? String.valueOf(raw.get('phone_number_verified')) : null;

        // UAE Pass extended — English
        p.firstNameEn       = str(raw, 'firstnameEN');
        p.lastNameEn        = str(raw, 'lastnameEN');
        p.fullNameEn        = str(raw, 'fullnameEN');

        // UAE Pass extended — Arabic
        p.firstNameAr       = str(raw, 'firstnameAR');
        p.lastNameAr        = str(raw, 'lastnameAR');
        p.fullNameAr        = str(raw, 'fullnameAR');

        // Identity
        p.idn               = str(raw, 'idn');          // Emirates ID Number
        p.idType            = str(raw, 'idType');
        p.idExpiryDate      = str(raw, 'idExpiry');
        p.uuid              = String.isNotBlank(p.uuid) ? p.uuid : str(raw, 'uuid');

        // Demographics
        p.dateOfBirth       = str(raw, 'dob');
        p.gender            = str(raw, 'gender');
        p.nationality       = str(raw, 'nationality');
        p.nationalityCode   = str(raw, 'nationalityEN');

        // Address
        p.streetAddress     = str(raw, 'streetAddress');
        p.city              = str(raw, 'city');
        p.emirate           = str(raw, 'state');
        p.poBox             = str(raw, 'pobox');

        // Document / profile image
        p.profileImage      = str(raw, 'picture');

        // Raw JSON — store for debugging / future fields
        p.rawJson           = JSON.serialize(raw);

        return p;
    }

    private static String str(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? String.valueOf(val).trim() : null;
    }

    private static Date parseDate(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        try {
            // UAE Pass typically returns DD/MM/YYYY or YYYY-MM-DD
            if (dateStr.contains('/')) {
                List<String> parts = dateStr.split('/');
                if (parts.size() == 3) {
                    return Date.newInstance(
                        Integer.valueOf(parts[2]),
                        Integer.valueOf(parts[1]),
                        Integer.valueOf(parts[0])
                    );
                }
            } else {
                return Date.valueOf(dateStr); // YYYY-MM-DD
            }
        } catch (Exception e) {
            System.debug('Date parse failed for: ' + dateStr + ' → ' + e.getMessage());
        }
        return null;
    }

    private static String generateState() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 16);
    }

    private static String generateNonce() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
    }

    // ─── Inner Class: UAE Pass Profile ────────────────────────────────────────
    public class UAEPassProfile {
        @AuraEnabled public String uuid;
        @AuraEnabled public String email;
        @AuraEnabled public String emailVerified;
        @AuraEnabled public String mobile;
        @AuraEnabled public String mobileVerified;
        @AuraEnabled public String firstNameEn;
        @AuraEnabled public String lastNameEn;
        @AuraEnabled public String fullNameEn;
        @AuraEnabled public String firstNameAr;
        @AuraEnabled public String lastNameAr;
        @AuraEnabled public String fullNameAr;
        @AuraEnabled public String idn;           // Emirates ID Number
        @AuraEnabled public String idType;
        @AuraEnabled public String idExpiryDate;
        @AuraEnabled public String dateOfBirth;
        @AuraEnabled public String gender;
        @AuraEnabled public String nationality;
        @AuraEnabled public String nationalityCode;
        @AuraEnabled public String streetAddress;
        @AuraEnabled public String city;
        @AuraEnabled public String emirate;
        @AuraEnabled public String poBox;
        @AuraEnabled public String profileImage;
        @AuraEnabled public String rawJson;       // Full raw response — for debugging
    }
}