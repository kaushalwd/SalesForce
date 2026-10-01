/**
 * RelixRequestValidator - checks a buyer journey request before anything is sent to Relix.
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  25 Sep 2026  SCW-182. The callback URL must be https: the per-case token
 *                                    travels in it and must never cross the wire in clear.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. The limits are Dalil's (Client API Reference v2,
 *                                    section 3.1): persona one of four, propertyRef required,
 *                                    callbackUrl absolute and at most 500 characters, transaction
 *                                    sent whole or not at all with amount > 0 and a three letter
 *                                    currency, name 1 to 200, email valid and at most 254, phone
 *                                    4 to 32 with E.164 recommended. Relix rejects a bad request with
 *                                    a 400 that names the field, but a refusal here costs no callout
 *                                    and the rep reads it in plain words.
 *
 * PHONE. MODON stores mobiles in several shapes (05x, 971 5x, +971 5x, 00971). They are normalised
 * to E.164 here, once, so the same person is sent the same way every time.
 *
 * OWNERSHIP. Owner: MODON.
 */
public with sharing class RelixRequestValidator {

    public static final Set<String> PERSONAS = new Set<String>{
        'INDIVIDUAL_UAE_GCC', 'INDIVIDUAL_EXPAT', 'INDIVIDUAL_NON_RESIDENT', 'CORPORATE_ENTITY'
    };
    public static final Integer NAME_MAX = 200;
    public static final Integer EMAIL_MAX = 254;
    public static final Integer CALLBACK_MAX = 500;

    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');
    // E.164: a plus, a non-zero first digit, 7 to 15 digits in all.
    private static final Pattern PHONE_PATTERN = Pattern.compile('^\\+[1-9][0-9]{6,14}$');
    private static final Pattern CURRENCY_PATTERN = Pattern.compile('^[A-Z]{3}$');

    public class Input {
        public String persona;
        public String propertyRef;
        public String callbackUrl;
        public String buyerName;
        public String email;
        public String phone;
        public Decimal amount;
        public String currencyCode;
    }

    public class Outcome {
        public List<String> problems = new List<String>();
        public String phoneE164;
        public Boolean sendTransaction = false;
        public Boolean isValid() { return problems.isEmpty(); }
    }

    public static Outcome validate(Input i) {
        Outcome o = new Outcome();
        if (i == null) { o.problems.add('Nothing to validate.'); return o; }

        if (i.persona == null || !PERSONAS.contains(i.persona)) {
            o.problems.add('The buyer type is not one Relix accepts.');
        }
        if (String.isBlank(i.propertyRef)) {
            o.problems.add('A property reference (the unit) is required.');
        }
        if (i.callbackUrl != null) {
            if (!i.callbackUrl.startsWith('https://')) {
                o.problems.add('The callback URL must be an absolute https address.');
            }
            if (i.callbackUrl.length() > CALLBACK_MAX) {
                o.problems.add('The callback URL is longer than ' + CALLBACK_MAX + ' characters.');
            }
        }
        String name = i.buyerName == null ? '' : i.buyerName.trim();
        if (name.length() == 0) {
            o.problems.add('The buyer name is missing.');
        } else if (name.length() > NAME_MAX) {
            o.problems.add('The buyer name is longer than ' + NAME_MAX + ' characters.');
        }
        String email = i.email == null ? '' : i.email.trim();
        if (email.length() == 0) {
            o.problems.add('The buyer email is missing.');
        } else if (email.length() > EMAIL_MAX || !EMAIL_PATTERN.matcher(email).matches()) {
            o.problems.add('The buyer email is not a valid address.');
        }
        o.phoneE164 = normalisePhone(i.phone);
        if (o.phoneE164 == null) {
            o.problems.add('The buyer mobile number could not be read as an international number (for example +971501234567).');
        }
        if (i.amount != null) {
            if (i.amount <= 0) {
                o.problems.add('The transaction amount must be greater than 0.');
            } else {
                o.sendTransaction = true;
                if (i.currencyCode == null || !CURRENCY_PATTERN.matcher(i.currencyCode).matches()) {
                    o.problems.add('The currency must be three uppercase letters, for example AED.');
                }
            }
        }
        return o;
    }

    /** E.164 or null. 0501234567 becomes +971501234567; 00971... and 971... become +971... */
    public static String normalisePhone(String raw) {
        if (String.isBlank(raw)) { return null; }
        String s = raw.trim();
        Boolean plus = s.startsWith('+');
        String digits = s.replaceAll('[^0-9]', '');
        if (digits.length() == 0) { return null; }
        String e164;
        if (plus) {
            e164 = '+' + digits;
        } else if (digits.startsWith('00')) {
            e164 = '+' + digits.substring(2);
        } else if (digits.startsWith('0') && (digits.length() == 10 || digits.length() == 9)) {
            e164 = '+971' + digits.substring(1);
        } else {
            e164 = '+' + digits;
        }
        return PHONE_PATTERN.matcher(e164).matches() ? e164 : null;
    }
}