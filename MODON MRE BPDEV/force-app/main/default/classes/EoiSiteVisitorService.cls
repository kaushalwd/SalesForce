/**
 * Finds or creates the EOI Site Visitor behind a verified registration, links the two
 * and keeps the visitor's counts and trail. Only proven identifiers ever match.
 */
public without sharing class EoiSiteVisitorService {

    public class Result {
        public EOI_Site_Visitor__c visitor;
        public Boolean returning = false;
        public Integer priorVisits = 0;
    }

    private static final Set<String> VERIFIED_STATUSES = new Set<String>{ 'Verified', 'Promoted', 'PromoteFailed' };

    /** identityType: Email | Mobile | UAE Pass. value: the proven identifier. u: UAE PASS payload, else null. */
    public static Result onVerified(EOI_Public_Registration__c row, String identityType, String value, UAEPassUserInfo u) {
        String email = normEmail(identityType == 'Email' ? value : (u == null ? null : u.email));
        String mobile = normMobile(identityType == 'Mobile' ? value : (u == null ? null : u.mobile));
        String uuid = identityType == 'UAE Pass' ? value : null;
        Datetime now = Datetime.now();

        Result out = new Result();
        EOI_Site_Visitor__c v = find(email, mobile, uuid);
        if (v == null) {
            v = new EOI_Site_Visitor__c(
                Identity_Key__c = identityKey(identityType, uuid != null ? uuid : (email != null ? email : mobile)),
                Identity_Type__c = identityType,
                First_Source__c = row.Source__c,
                First_Seen__c = now,
                Visit_Count__c = 0,
                Verified_Count__c = 0,
                Journey_Trail__c = ''
            );
        } else {
            out.returning = true;
            out.priorVisits = v.Visit_Count__c == null ? 0 : v.Visit_Count__c.intValue();
        }
        if (email != null && v.Verified_Email__c != email) {
            v.Verified_Email__c = email;
            v.Email_Verified_At__c = now;
        }
        if (mobile != null && v.Verified_Mobile__c != mobile) {
            v.Verified_Mobile__c = mobile;
            v.Mobile_Verified_At__c = now;
        }
        if (uuid != null) {
            v.UAE_Pass_UUID__c = uuid;
        }
        v.Last_Seen__c = now;
        v.Verified_Count__c = (v.Verified_Count__c == null ? 0 : v.Verified_Count__c) + 1;
        v.Visit_Count__c = (v.Visit_Count__c == null ? 0 : v.Visit_Count__c) + 1;
        v.Last_Registration__c = row.Id;
        v.Journey_Trail__c = trail(v.Journey_Trail__c,
            'Verified by ' + identityType.toLowerCase() + (out.returning ? ' · returning' : ' · new visitor'));
        upsert v;

        update new EOI_Public_Registration__c(
            Id = row.Id,
            Visitor__c = v.Id,
            Identity_Key__c = v.Identity_Key__c,
            Verified_Identifier__c = identityType,
            Is_Returning__c = out.returning,
            Prior_Visit_Count__c = out.priorVisits
        );
        out.visitor = v;
        return out;
    }

    /** A visitor already known for this email or mobile, or null. */
    public static EOI_Site_Visitor__c known(String email, String mobile) {
        return find(normEmail(email), normMobile(mobile), null);
    }

    public static void appendTrail(Id visitorId, String line) {
        if (visitorId == null || String.isBlank(line)) {
            return;
        }
        List<EOI_Site_Visitor__c> rows = [SELECT Journey_Trail__c FROM EOI_Site_Visitor__c WHERE Id = :visitorId LIMIT 1];
        if (rows.isEmpty()) {
            return;
        }
        rows[0].Journey_Trail__c = trail(rows[0].Journey_Trail__c, line);
        update rows[0];
    }

    public static String identityKey(String identityType, String value) {
        String type = identityType == 'UAE Pass' ? 'UAEPASS' : identityType.toUpperCase();
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(type + '|' + value)));
    }

    private static EOI_Site_Visitor__c find(String email, String mobile, String uuid) {
        List<EOI_Site_Visitor__c> rows;
        String fields = 'Id, Identity_Key__c, Identity_Type__c, Verified_Email__c, Verified_Mobile__c, UAE_Pass_UUID__c, '
            + 'Email_Verified_At__c, Mobile_Verified_At__c, Visit_Count__c, Verified_Count__c, Journey_Trail__c';
        if (uuid != null) {
            rows = Database.query('SELECT ' + fields + ' FROM EOI_Site_Visitor__c WHERE UAE_Pass_UUID__c = :uuid LIMIT 1');
            if (!rows.isEmpty()) {
                return rows[0];
            }
        }
        if (email != null) {
            rows = Database.query('SELECT ' + fields + ' FROM EOI_Site_Visitor__c WHERE Verified_Email__c = :email LIMIT 1');
            if (!rows.isEmpty()) {
                return rows[0];
            }
        }
        if (mobile != null) {
            rows = Database.query('SELECT ' + fields + ' FROM EOI_Site_Visitor__c WHERE Verified_Mobile__c = :mobile LIMIT 1');
            if (!rows.isEmpty()) {
                return rows[0];
            }
        }
        // merge: the proven value was typed on an earlier verified registration of a known visitor
        List<String> matches = new List<String>();
        if (email != null) {
            matches.add('Email__c = :email OR RegisteredEmail__c = :email');
        }
        if (mobile != null) {
            matches.add('Mobile__c = :mobile OR RegisteredPhone__c = :mobile');
        }
        Id viaRegistration = null;
        if (!matches.isEmpty()) {
            Set<String> statuses = VERIFIED_STATUSES;
            for (EOI_Public_Registration__c r : Database.query(
                'SELECT Visitor__c FROM EOI_Public_Registration__c WHERE Visitor__c != null AND Status__c IN :statuses AND ('
                + String.join(matches, ' OR ') + ') ORDER BY VerifiedAt__c DESC NULLS LAST LIMIT 1')) {
                viaRegistration = r.Visitor__c;
            }
        }
        if (viaRegistration != null) {
            rows = Database.query('SELECT ' + fields + ' FROM EOI_Site_Visitor__c WHERE Id = :viaRegistration LIMIT 1');
            if (!rows.isEmpty()) {
                return rows[0];
            }
        }
        return null;
    }

    private static String trail(String existing, String line) {
        String stamp = Datetime.now().format('dd MMM HH:mm');
        String next = stamp + '  ' + line;
        return String.isBlank(existing) ? next : (existing + '\n' + next).abbreviate(131000);
    }

    private static String normEmail(String v) {
        return String.isBlank(v) ? null : v.trim().toLowerCase();
    }

    private static String normMobile(String v) {
        if (String.isBlank(v)) {
            return null;
        }
        String digits = v.replaceAll('[^0-9]', '');
        return digits.length() < 7 ? null : '+' + digits;
    }
}