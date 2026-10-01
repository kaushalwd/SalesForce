/**
 * Typed wrapper for UAE Pass userinfo claims (general-profile scope).
 * @author Aurelix
 */
public inherited sharing class UAEPassUserInfo {

    @AuraEnabled public String uuid          { get; private set; }
    @AuraEnabled public String emiratesId    { get; private set; }
    @AuraEnabled public String firstNameEn   { get; private set; }
    @AuraEnabled public String lastNameEn    { get; private set; }
    @AuraEnabled public String fullNameEn    { get; private set; }
    @AuraEnabled public String fullNameAr    { get; private set; }
    @AuraEnabled public String email         { get; private set; }
    @AuraEnabled public String mobile        { get; private set; }
    @AuraEnabled public String gender        { get; private set; }
    @AuraEnabled public String nationalityEn { get; private set; }
    @AuraEnabled public String userType      { get; private set; }
    @AuraEnabled public String idType        { get; private set; }

    private Map<String, Object> raw;

    public static UAEPassUserInfo parse(Map<String, Object> claims) {
        UAEPassUserInfo u = new UAEPassUserInfo();
        u.raw           = claims;
        u.uuid          = str(claims, 'uuid') != null ? str(claims, 'uuid') : str(claims, 'sub');
        u.emiratesId    = str(claims, 'idn');
        u.firstNameEn   = str(claims, 'firstnameEN');
        u.lastNameEn    = str(claims, 'lastnameEN');
        u.fullNameEn    = str(claims, 'fullnameEN');
        u.fullNameAr    = str(claims, 'fullnameAR');
        u.email         = str(claims, 'email');
        u.mobile        = str(claims, 'mobile');
        u.gender        = str(claims, 'gender');
        u.nationalityEn = str(claims, 'nationalityEN');
        u.userType      = str(claims, 'userType');
        u.idType        = str(claims, 'idType');
        return u;
    }

    /** SOP1 accounts are unverified; SOP2/SOP3 hold a verified Emirates ID. */
    public Boolean isVerifiedAccount() {
        return userType == 'SOP2' || userType == 'SOP3';
    }

    public Object rawClaim(String key) {
        return raw == null ? null : raw.get(key);
    }

    private static String str(Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v == null ? null : String.valueOf(v);
    }
}