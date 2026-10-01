/**********************************************************************************************
 * Name           : SmsTextBuilder
 * Description     : Picks which of a configured SMS wording actually goes out, and keeps it
 *                   inside one message segment. One GSM segment carries 160 characters; past
 *                   that the carrier splits the text into 153-character parts, and on a client's
 *                   phone that split once landed inside a payment link (CP-00227). So the
 *                   configured primary wording is sent when it fits and the configured fallback
 *                   when it does not, and if neither fits the longer one still goes rather than
 *                   dropping the link.
 *                   Text outside the GSM 03.38 alphabet forces the carrier to UCS-2, which is
 *                   70 characters a segment, so merged values are mapped onto that alphabet
 *                   first. A URL is never touched.
 * Usage           : SmsTextBuilder.fit(primary, fallback); SmsTextBuilder.firstName(name);
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    13 Sep 2026    Lifted the BP-044 GSM helpers out of
 *                                             CheckoutNotificationService so the EOI rail can
 *                                             use the same rule now that its SMS copy is
 *                                             configurable and can be edited past 160 chars.
 **********************************************************************************************/
public without sharing class SmsTextBuilder {

    @TestVisible private static final Integer SMS_MAX_CHARS = 160;
    public static final String FALLBACK_NAME = 'Customer';

    private static final List<String> SMS_MONTHS = new List<String>{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' };
    private static final Set<String> SMS_SALUTATIONS = new Set<String>{
        'mr', 'mrs', 'ms', 'miss', 'mx', 'dr', 'prof', 'sheikh', 'sheikha' };

    // GSM 03.38 basic alphabet (one septet each): the ASCII part as a literal, the rest by code point.
    private static final String GSM_BASIC =
        '@$\n\r_ !"#%&\'()*+,-./0123456789:;<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
        + String.fromCharArray(new List<Integer>{ 163, 165, 232, 233, 249, 236, 242, 199, 216, 248, 197, 229, 916, 934,
            915, 923, 937, 928, 936, 931, 920, 926, 198, 230, 223, 201, 164, 161, 196, 214, 209, 220, 167, 191, 228, 246,
            241, 252, 224 });
    // GSM 03.38 extension characters (two septets each).
    private static final String GSM_EXTENSION = '^{}\\[~]|' + String.fromCharArray(new List<Integer>{ 8364 });
    private static final Map<String, String> GSM_SUBSTITUTES = gsmSubstitutes();

    private static Map<String, String> gsmSubstitutes() {
        Map<String, String> subs = new Map<String, String>();
        for (Integer quote : new List<Integer>{ 8216, 8217, 8218, 180, 96 }) {      // ' variants, acute accent, backtick
            subs.put(String.fromCharArray(new List<Integer>{ quote }), '\'');
        }
        for (Integer quote : new List<Integer>{ 8220, 8221, 8222 }) {               // " variants
            subs.put(String.fromCharArray(new List<Integer>{ quote }), '"');
        }
        for (Integer dash : new List<Integer>{ 8211, 8212, 8722 }) {                // dashes and the minus sign
            subs.put(String.fromCharArray(new List<Integer>{ dash }), '-');
        }
        subs.put(String.fromCharArray(new List<Integer>{ 8230 }), '...');           // ellipsis
        subs.put(String.fromCharArray(new List<Integer>{ 160 }), ' ');              // non-breaking space
        return subs;
    }

    /**
     * The wording to send. The primary is used when it fits one segment, otherwise the fallback.
     * When neither fits, the primary still goes: a split message beats no message.
     */
    public static String fit(String primary, String fallback) {
        if (String.isBlank(primary)) {
            return String.isBlank(fallback) ? null : fallback;
        }
        if (gsmLength(primary) <= SMS_MAX_CHARS) {
            return primary;
        }
        if (String.isNotBlank(fallback) && gsmLength(fallback) <= SMS_MAX_CHARS) {
            return fallback;
        }
        return primary;
    }

    /**
     * First name for an SMS greeting: the first word of the stored name, skipping a salutation,
     * kept only when every character has a GSM equivalent so a name is never mangled.
     */
    public static String firstName(String customerName) {
        if (String.isBlank(customerName)) {
            return FALLBACK_NAME;
        }
        for (String word : substituteGsm(customerName).trim().split('\\s+')) {
            if (String.isBlank(word) || SMS_SALUTATIONS.contains(word.replaceAll('\\.', '').toLowerCase())) {
                continue;
            }
            return isGsm(word) ? word : FALLBACK_NAME;
        }
        return FALLBACK_NAME;
    }

    /** Short expiry for an SMS, e.g. 11 Sep 14:51, with English month names whatever the running user's locale. */
    public static String shortExpiry(Datetime expiresOn) {
        if (expiresOn == null) {
            return null;
        }
        try {
            return expiresOn.format('d') + ' ' + SMS_MONTHS[Integer.valueOf(expiresOn.format('M')) - 1] + ' ' + expiresOn.format('HH:mm');
        } catch (Exception e) {
            return expiresOn.format('dd/MM/yyyy HH:mm');
        }
    }

    /** Maps typographic characters onto the GSM alphabet and drops what has no equivalent. */
    public static String toGsm(String text) {
        if (text == null) {
            return '';
        }
        List<String> kept = new List<String>();
        String mapped = substituteGsm(text);
        for (Integer i = 0; i < mapped.length(); i++) {
            String ch = mapped.substring(i, i + 1);
            if (GSM_BASIC.contains(ch) || GSM_EXTENSION.contains(ch)) {
                kept.add(ch);
            }
        }
        return String.join(kept, '');
    }

    /** Septets the text needs: an extension character costs two, everything else one. */
    public static Integer gsmLength(String text) {
        if (text == null) {
            return 0;
        }
        Integer septets = 0;
        for (Integer i = 0; i < text.length(); i++) {
            septets += GSM_EXTENSION.contains(text.substring(i, i + 1)) ? 2 : 1;
        }
        return septets;
    }

    private static String substituteGsm(String text) {
        String mapped = text;
        for (String original : GSM_SUBSTITUTES.keySet()) {
            mapped = mapped.replace(original, GSM_SUBSTITUTES.get(original));
        }
        return mapped;
    }

    private static Boolean isGsm(String text) {
        for (Integer i = 0; i < text.length(); i++) {
            String ch = text.substring(i, i + 1);
            if (!GSM_BASIC.contains(ch) && !GSM_EXTENSION.contains(ch)) {
                return false;
            }
        }
        return true;
    }
}