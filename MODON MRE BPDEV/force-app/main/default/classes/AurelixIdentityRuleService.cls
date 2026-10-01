/**
 * AurelixIdentityRuleService - the ONE residency rule for a buyer's identity documents.
 *
 * Version  Author       Date         Detail
 * 1.2      Aurelix Dev  27 Sep 2026  MODON'S LEAD RULES, NOT THE 17 SEP TABLE (27 Sep: the console must behave as
 *                                    MODON's Sales App does). The console creates and converts Leads, and the
 *                                    active Lead rules require only a passport number for a Non-Resident
 *                                    (Passport_Number_Mandatory_Validation); every other identity field is
 *                                    optional, and a Resident needs none. needsFor keeps its flags for what
 *                                    is SHOWN and adds *Required flags for what is OWED: only
 *                                    passportNumberRequired, for a Non-Resident. An entered value is still
 *                                    checked as MODON checks it: the Emirates ID format, an issue date not in
 *                                    the future, and an expiry not in the past, TODAY ACCEPTED as MODON's
 *                                    "< TODAY()" rules accept it (usableExpiry is now >= today; it was > today).
 * 1.1      Aurelix Dev  27 Sep 2026  Passport expiry is no longer owed when blank (business confirmed 27 Sep 2026:
 *                                    MODON's own mandatory rule, Passport_ExpiryDate_Mandatory_Validation,
 *                                    is inactive on Lead and Opportunity, and no Account_KYC_Validation__mdt
 *                                    row asks for it). needsFor still lists it, because that flag also
 *                                    decides where the field is shown and saved. An expiry that is entered
 *                                    must still be after today, as MODON's active past-date rule requires.
 * 1.0      Aurelix Dev  17 Sep 2026  MSC-174 (B2). Until now the rule lived twice and said the same
 *                                    thing in both places: privately in
 *                                    SalesConsoleLeadController.identityNeedsFor and as the client
 *                                    mirror in c/mscEoiUtils - "Resident = Emirates ID only". The
 *                                    decision of 17 Sep 2026 (build brief, section 3) is:
 *                                      Resident      Emirates ID number + expiry AND passport
 *                                                    number + issue date + expiry
 *                                      Non-Resident  passport number + issue date + expiry
 *                                      blank         nothing yet - residency is asked first
 *                                    This class owns that table. The lead controller delegates to
 *                                    needsFor; the client mirror repeats it; stateFor lets any
 *                                    surface (the manual-KYC readiness check, B5's checklist) ask
 *                                    what one record still lacks, in the same shape the lead
 *                                    controller already reports.
 *
 * OWNERSHIP. Aurelix-owned. Reads Account and Contact, writes nothing. MODON's
 * CustomerKYCHandler.isValidEmiratesId is CALLED for the Emirates ID shape, never modified.
 *
 * DATE SEMANTICS - unchanged from the lead controller (usableExpiry / usableIssue there, private):
 * an expiry is usable only strictly after today; an issue date must not be in the future. Repeated
 * here rather than made public on the controller, because B2 edits that class in one named method
 * only.
 */
public with sharing class AurelixIdentityRuleService {

    public static final String RESIDENT     = 'Resident';
    public static final String NON_RESIDENT = 'Non-Resident';

    /* Reason codes. The three the lead controller's IdentityStateDTO already uses ... */
    public static final String REASON_MISSING = 'missing';
    public static final String REASON_EXPIRED = 'expired';
    public static final String REASON_FUTURE  = 'future';
    /* ... plus one additive code: an Emirates ID that is present but not 784-YYYY-NNNNNNN-C. */
    public static final String REASON_FORMAT  = 'format';

    /** What kind of record stateFor was asked about. */
    public static final String SUBJECT_PERSON  = 'Person';
    public static final String SUBJECT_CONTACT = 'Contact';
    public static final String SUBJECT_COMPANY = 'Company';

    /* ══════════════════════════════════════════════════════════════════════════════
     * THE TABLE
     * ══════════════════════════════════════════════════════════════════════════════ */

    /**
     * The identity set a residency requires. Returns the lead controller's own DTO type so no
     * consumer changes shape. Case-insensitive, whitespace-tolerant; anything that is neither
     * Resident nor Non-Resident requires nothing, exactly as before.
     */
    public static SalesConsoleLeadController.IdentityNeedDTO needsFor(String residentStatus) {
        SalesConsoleLeadController.IdentityNeedDTO n =
            new SalesConsoleLeadController.IdentityNeedDTO();
        String r = residentStatus == null ? '' : residentStatus.trim();
        /* shown */
        if (RESIDENT.equalsIgnoreCase(r)) {
            n.eidNumber          = true;
            n.eidExpiry          = true;
            n.passportNumber     = true;
            n.passportIssueDate  = true;
            n.passportExpiryDate = true;
        } else if (NON_RESIDENT.equalsIgnoreCase(r)) {
            n.passportNumber     = true;
            n.passportIssueDate  = true;
            n.passportExpiryDate = true;
            /* 1.2 - owed: MODON's Passport_Number_Mandatory_Validation, the only one active */
            n.passportNumberRequired = true;
        }
        return n;
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * THE STATE OF ONE RECORD
     * ══════════════════════════════════════════════════════════════════════════════ */

    /**
     * The same fields as SalesConsoleLeadController.IdentityStateDTO, in the same order, plus
     * three additive ones: eidNumberReason (missing | format), the `missing` labels a screen can
     * print, and `subject` so a caller knows whether a company Id was passed by mistake.
     */
    public class IdentityStateDTO {
        @AuraEnabled public SalesConsoleLeadController.IdentityNeedDTO needs;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public String nationality;
        @AuraEnabled public String eidNumber;
        @AuraEnabled public Date eidExpiry;
        @AuraEnabled public String passportNumber;
        @AuraEnabled public Date passportIssueDate;
        @AuraEnabled public Date passportExpiryDate;
        /* null | missing | expired | future | format - codes, never sentences */
        @AuraEnabled public String eidNumberReason;
        @AuraEnabled public String eidExpiryReason;
        @AuraEnabled public String passportIssueReason;
        @AuraEnabled public String passportExpiryReason;
        /** True when nothing is left to ask. */
        @AuraEnabled public Boolean complete = false;
        /** Field labels still owed, in display order. Empty when complete. */
        @AuraEnabled public List<String> missing = new List<String>();
        @AuraEnabled public Id recordId;
        /** Person | Contact | Company. A company carries no identity of its own: pass its POA Contact. */
        @AuraEnabled public String subject;
    }

    /**
     * What this Account or Contact holds, what its own residency demands, and what is still owed.
     * A person Account is read on its __pc fields; a Contact on its own fields; a non-person
     * Account is reported as a Company with nothing required and nothing complete - the identity
     * belongs to the authorised POA Contact and that is the Id to pass.
     */
    public static IdentityStateDTO stateFor(Id accountOrContactId) {
        IdentityStateDTO s = new IdentityStateDTO();
        s.recordId = accountOrContactId;
        if (accountOrContactId == null) {
            s.needs = needsFor(null);
            return s;
        }
        Schema.SObjectType t = accountOrContactId.getSobjectType();
        if (t == Account.SObjectType) {
            readAccount(accountOrContactId, s);
        } else if (t == Contact.SObjectType) {
            readContact(accountOrContactId, s);
        } else {
            s.needs = needsFor(null);
            return s;
        }
        if (s.subject == SUBJECT_COMPANY) {
            s.needs = needsFor(null);
            return s;
        }
        s.needs = needsFor(s.residentStatus);
        evaluate(s);
        return s;
    }

    private static void readAccount(Id accountId, IdentityStateDTO s) {
        for (Account a : [
            SELECT Id, IsPersonAccount, UAE_Resident_Status__pc, Nationality__pc,
                   EIDNumber__pc, EmiratesIDExpiryDate__pc,
                   PassportNumber__pc, PassportIssueDate__pc, PassportExpiryDate__pc
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ]) {
            if (a.IsPersonAccount != true) {
                s.subject = SUBJECT_COMPANY;
                return;
            }
            s.subject            = SUBJECT_PERSON;
            s.residentStatus     = a.UAE_Resident_Status__pc;
            s.nationality        = a.Nationality__pc;
            s.eidNumber          = a.EIDNumber__pc;
            /* EmiratesIDExpiryDate__pc, not EID_Expiry_Date__pc - the same choice the lead
               controller documents (the latter is populated on zero records). */
            s.eidExpiry          = a.EmiratesIDExpiryDate__pc;
            s.passportNumber     = a.PassportNumber__pc;
            s.passportIssueDate  = a.PassportIssueDate__pc;
            s.passportExpiryDate = a.PassportExpiryDate__pc;
        }
    }

    private static void readContact(Id contactId, IdentityStateDTO s) {
        for (Contact c : [
            SELECT Id, UAE_Resident_Status__c, Nationality__c,
                   EIDNumber__c, EmiratesIDExpiryDate__c,
                   PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ]) {
            s.subject            = SUBJECT_CONTACT;
            s.residentStatus     = c.UAE_Resident_Status__c;
            s.nationality        = c.Nationality__c;
            s.eidNumber          = c.EIDNumber__c;
            s.eidExpiry          = c.EmiratesIDExpiryDate__c;
            s.passportNumber     = c.PassportNumber__c;
            s.passportIssueDate  = c.PassportIssueDate__c;
            s.passportExpiryDate = c.PassportExpiryDate__c;
        }
    }

    /**
     * Applies the table to what the DTO holds. Separated from the readers so the whole matrix
     * can be tested without DML - the org's own format rules would refuse to store the invalid
     * shapes the `format` branch exists for.
     */
    @TestVisible
    private static void evaluate(IdentityStateDTO s) {
        if (s.needs == null) {
            s.needs = needsFor(s.residentStatus);
        }
        String obj = s.subject == SUBJECT_CONTACT ? 'Contact' : 'Account';
        List<String> owed = new List<String>();

        /* residency decides which rules apply, so an unset value is itself a gap - the same
           position AurelixManualKycService takes */
        if (String.isBlank(s.residentStatus)) {
            owed.add(fieldLabel(obj, obj == 'Contact' ? 'UAE_Resident_Status__c' : 'UAE_Resident_Status__pc'));
        }

        /* 1.2 - a blank value is owed only where MODON requires it; an entered one is always checked */
        s.eidNumberReason = null;
        if (s.needs.eidNumber) {
            if (String.isBlank(s.eidNumber)) {
                s.eidNumberReason = s.needs.eidNumberRequired == true ? REASON_MISSING : null;
            } else if (!CustomerKYCHandler.isValidEmiratesId(s.eidNumber)) {
                s.eidNumberReason = REASON_FORMAT;
            }
            if (s.eidNumberReason != null) {
                owed.add(fieldLabel(obj, obj == 'Contact' ? 'EIDNumber__c' : 'EIDNumber__pc'));
            }
        }

        s.eidExpiryReason = null;
        if (s.needs.eidExpiry) {
            s.eidExpiryReason = s.eidExpiry == null
                ? (s.needs.eidExpiryRequired == true ? REASON_MISSING : null)
                : (usableExpiry(s.eidExpiry) ? null : REASON_EXPIRED);
            if (s.eidExpiryReason != null) {
                owed.add(fieldLabel(obj, obj == 'Contact' ? 'EmiratesIDExpiryDate__c' : 'EmiratesIDExpiryDate__pc'));
            }
        }

        if (s.needs.passportNumberRequired == true && String.isBlank(s.passportNumber)) {
            owed.add(fieldLabel(obj, obj == 'Contact' ? 'PassportNumber__c' : 'PassportNumber__pc'));
        }

        s.passportIssueReason = null;
        if (s.needs.passportIssueDate) {
            s.passportIssueReason = s.passportIssueDate == null
                ? (s.needs.passportIssueDateRequired == true ? REASON_MISSING : null)
                : (usableIssue(s.passportIssueDate) ? null : REASON_FUTURE);
            if (s.passportIssueReason != null) {
                owed.add(fieldLabel(obj, obj == 'Contact' ? 'PassportIssueDate__c' : 'PassportIssueDate__pc'));
            }
        }

        /* 1.1: optional; only an expired date is owed */
        s.passportExpiryReason = null;
        if (s.needs.passportExpiryDate) {
            s.passportExpiryReason = (s.passportExpiryDate != null && !usableExpiry(s.passportExpiryDate))
                ? REASON_EXPIRED
                : null;
            if (s.passportExpiryReason != null) {
                owed.add(fieldLabel(obj, obj == 'Contact' ? 'PassportExpiryDate__c' : 'PassportExpiryDate__pc'));
            }
        }

        s.missing  = owed;
        s.complete = owed.isEmpty();
    }

    /* 1.2 - MODON's "< TODAY()" rules (Passport_Expir_Date_Should_not_be_Past, EID_ExpiryDate_Cannot_be_Past):
       today is still usable. */
    @TestVisible
    private static Boolean usableExpiry(Date d) {
        return d != null && d >= Date.today();
    }

    /* Passport_Issue_Date_Should_not_be_Future */
    @TestVisible
    private static Boolean usableIssue(Date d) {
        return d != null && d <= Date.today();
    }

    /** The org's own label for a field, so the console prints what Setup prints; API name if unknown. */
    public static String fieldLabel(String objectApiName, String fieldApiName) {
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
        if (sot == null || String.isBlank(fieldApiName)) {
            return fieldApiName;
        }
        Schema.SObjectField f = sot.getDescribe().fields.getMap().get(fieldApiName.toLowerCase());
        return f == null ? fieldApiName : f.getDescribe().getLabel();
    }
}