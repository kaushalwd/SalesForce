/**
 * SalesConsoleLeadController - the My Leads pane.
 *
 * Version  Author      Date         Detail
 * 1.34     Aurelix Dev 29 Sep 2026  Every rep finds every customer, as in the Sales App: matching and Find
 *                                   customer read without sharing (MatchLookup); booking onto a found
 *                                   customer inserts and converts the lead without sharing (OntoFoundCustomer).
 * 1.33     Aurelix Dev 29 Sep 2026  A person is matched as the Sales App's findMatchingPersonAccounts does:
 *                                   one search on email, mobile, passport or (Resident only) Emirates ID
 *                                   (personMatches), at most ten rows, strongest key first.
 * 1.32     Aurelix Dev 28 Sep 2026  Visibility only, for SalesConsoleJointOwnerService 2.2 (28 Sep: a
 *                                   joint owner is matched as a buyer is before a new person is created).
 *                                   matchPersonCandidates and matchedOnFor are public entry points over the
 *                                   private matchCandidates and accountMatchedOn, bodies unchanged, and
 *                                   MATCH_MUST_BE_CHOSEN is public so the joint owner refusal is the same
 *                                   sentence. No matching rule changed.
 * 1.31     Aurelix Dev 28 Sep 2026  SCW-205. No new customer when existing customers match, as in the Sales
 *                                   App, behind ALLOW_NEW_CUSTOMER_DESPITE_MATCH
 *                                   (AurelixNewCustomerSwitch, off). With it off, createCustomer's forceCreate
 *                                   and convertLeadToCustomer's forceStandalone are refused whenever any
 *                                   account matches, in MODON's words ("Matching accounts were found. Please
 *                                   select one before converting."), before anything is written. With no
 *                                   match, or with the switch on, nothing changes. getLeadQualifyOptions
 *                                   also carries the switch (key newCustomerDespiteMatch), so mscConsole can
 *                                   hide "Continue With New Details" without another call.
 * 1.30     Aurelix Dev 27 Sep 2026  MODON's Lead rules (Sales App parity; AurelixIdentityRuleService
 *                                   1.2). IdentityNeedDTO keeps its flags for what is shown and gains *Required
 *                                   flags for what is owed; only a Non-Resident's passport number is. identityFor,
 *                                   identityUnsatisfied and createLeadFull owe only those, and check an entered
 *                                   value as MODON does, refusing in MODON's own words; an expiry of today is
 *                                   accepted (usableExpiry >= today).
 * 1.29     Aurelix Dev 27 Sep 2026  Passport expiry is optional. MODON's mandatory
 *                                   rule for it is inactive on Lead and Opportunity; its past-date rule is
 *                                   active. So identityFor and identityUnsatisfied owe only an expired
 *                                   date, and createLeadFull no longer refuses a blank one. An entered
 *                                   date must still be after today. The field is still shown and saved
 *                                   wherever needs.passportExpiryDate says (AurelixIdentityRuleService 1.1).
 * 1.28     Aurelix Dev 17 Sep 2026  MSC-174 (B2). identityNeedsFor delegates to
 *                                   AurelixIdentityRuleService.needsFor - the one residency table.
 *                                   By the decision of 17 Sep a Resident needs the passport three
 *                                   as well as the Emirates ID pair; a Non-Resident is unchanged.
 *                                   Every path that asked this method (identityFor, the conversion
 *                                   guard, createLeadFull's refusals, lead conversion) inherits
 *                                   the table with no other edit. The three passport refusals in
 *                                   createLeadFull stop saying "for a non-resident", which the
 *                                   table made untrue. Nothing else changed.
 * 1.27     Aurelix Dev 02 Sep 2026  MSC-212. leadRowById: the one lead "Book a unit" was pressed
 *                                   on, as the row shape the pickers build, so the journey's
 *                                   customer step opens on it pre-filled. A converted lead comes
 *                                   back as its Opportunity (id set, kind Customer) and the
 *                                   journey adopts it. Additive read; no existing path changed.
 * 1.26     Aurelix Dev 02 Sep 2026  MSC-210. LeadDTO carries pendingReassign
 *                                   (ReAssignRRToSalesAssociate__c), read by the three
 *                                   toDtos queries. Additive: a marker for the list row, never
 *                                   a filter - the flag is set reliably but cleared unreliably.
 * 1.25     Aurelix Dev 30 Aug 2026  MSC-180. matchOrganisationAccount and NON_CUSTOMER_ORG_RECORD_TYPES
 *                                   public for SalesConsoleJointOwnerService. Visibility only.
 * 1.24     Aurelix Dev 25 Aug 2026  MSC-172. One customer, one account: matchers read UnifiedNumber__c
 *                                   and compare documents through docVariants; convertLeadToCustomer
 *                                   passes the lead's licence; createCustomer re-checks before the
 *                                   conversion; matchPersonAccount public. Pure widening.
 * 1.23     Aurelix Dev 24 Aug 2026  MSC-162. bookForExistingCustomer drops a malformed stored document
 *                                   the residency does not require.
 * 1.22     Aurelix Dev 22 Aug 2026  MSC-114. Mobile written to Phone and MobilePhone; createLeadDetailed
 *                                   returns LeadCreateResult; Retired/Duplicate leads leave the booking
 *                                   surfaces; CustomerDTO.needsAddress.
 * 1.21     Aurelix Dev 22 Aug 2026  MSC-111. findByIdentity searches both documents; findByContact;
 *                                   matchCandidates returns every match and the rep chooses;
 *                                   convertLeadToCustomer matches on the lead's document; date of birth.
 * 1.20     Aurelix Dev 22 Aug 2026  MSC-110. identityNeeds derived from residency; identityFor; fill-only
 *                                   identity writes; createLeadDetailed.
 * 1.19     Aurelix IT  21 Aug 2026  MSC-108. Organisation booking: UnifiedNumber__c search, broker and
 *                                   ambassador types excluded, signatories carried and chosen,
 *                                   TradeName__c / UnifiedNumber__c on the lead, stampCompanyLicence fills blanks.
 * 1.18     Aurelix IT  20 Aug 2026  MSC-080. matchAccountByDocument public. Visibility only.
 * 1.17     Aurelix IT  12 Aug 2026  My Leads lists open leads only.
 * 1.16     Aurelix IT  11 Aug 2026  Absent identifiers match nothing (null bind matched every empty row).
 * 1.15     Aurelix IT  11 Aug 2026  Reuse the rep's own open opportunity for the same buyer and project.
 * 1.14     Aurelix IT  10 Aug 2026  Organisation customers; trade licence stamped on the Account.
 * 1.2      Aurelix IT  09 Aug 2026  createCustomer.
 * 1.1      Aurelix IT  09 Aug 2026  getMyCustomers.
 * 1.0      Aurelix IT  09 Aug 2026  Initial. Ported from ModonSalesController onto the standard Lead.
 */

/**
 * Reads and creates leads for the running rep. Thin on write: LeadTriggerHandler owns duplicate
 * detection, assignment, Loqate validation and SLA on insert.
 */
public with sharing class SalesConsoleLeadController {

    /* stands in for an absent identifier so `field = :bind` matches no rows (a null bind matches
       every row where the field is empty) */
    private static final String NO_MATCH = '~~none~~';

    /* record types a company search must never return: broker agencies and ambassadors dominate the
       licence fields. NOT IN, not `= 'OrganizationAccount'`: SOQL returns null record types through
       NOT IN, and many business accounts have none. */
    /* public for SalesConsoleJointOwnerService.checkCompanyIsUsable */
    public static final Set<String> NON_CUSTOMER_ORG_RECORD_TYPES =
        new Set<String>{ 'Broker_Agency', 'Ambassador' };

    /* 1.31: the Sales App's own sentence (the Convert button of MODON's convertLeadKYC) when a rep
       tries to go on without choosing one of the matching accounts.
       1.32: public for SalesConsoleJointOwnerService; visibility only */
    public static final String MATCH_MUST_BE_CHOSEN =
        'Matching accounts were found. Please select one before converting.';

    /** 1.31. With setMessage, so an Apex caller (and a test) reads the sentence, not "Script-thrown exception". */
    private static AuraHandledException matchMustBeChosen() {
        AuraHandledException e = new AuraHandledException(MATCH_MUST_BE_CHOSEN);
        e.setMessage(MATCH_MUST_BE_CHOSEN);
        return e;
    }

    /** One row in the list, and the detail behind it. */
    public class LeadDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobile;
        @AuraEnabled public String company;
        @AuraEnabled public String status;
        @AuraEnabled public String leadSource;
        @AuraEnabled public String projectInterest;
        @AuraEnabled public String nationality;
        @AuraEnabled public Boolean isConverted = false;
        @AuraEnabled public Datetime createdDate;
        /** Populated once converted; decides whether the row offers a booking (canBook). */
        @AuraEnabled public Id opportunityId;
        /**
         * MSC-210: the lead is qualified and queued for round-robin handover
         * (ReAssignRRToSalesAssociate__c). The row is NOT hidden on it - the flag is set
         * reliably but cleared unreliably (leads have carried it for days), so hiding would
         * lose them. It only earns a quiet marker.
         */
        @AuraEnabled public Boolean pendingReassign = false;
    }

    private static List<LeadDTO> toDtos(List<Lead> leads) {
        List<LeadDTO> out = new List<LeadDTO>();
        for (Lead l : leads) {
            LeadDTO d = new LeadDTO();
            d.id = l.Id;
            d.name = l.Name;
            d.firstName = l.FirstName;
            d.lastName = l.LastName;
            d.email = l.Email;
            d.phone = l.Phone;
            d.mobile = l.MobilePhone;
            d.company = l.Company;
            d.status = l.Status;
            d.leadSource = l.LeadSource;
            d.projectInterest = l.ProjectInterest__c;
            d.nationality = l.Nationality__c;
            d.isConverted = l.IsConverted;
            d.createdDate = l.CreatedDate;
            d.opportunityId = l.ConvertedOpportunityId;
            d.pendingReassign = l.ReAssignRRToSalesAssociate__c == true;
            out.add(d);
        }
        return out;
    }

    /**
     * The rep's own leads, newest first, capped (search reaches past it). cacheable=false: the
     * list is the most mutable thing in the console. Safe because mscLeadList calls it imperatively.
     */
    @AuraEnabled(cacheable=false)
    public static List<LeadDTO> getRecentLeads() {
        return toDtos([
            SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone, Company,
                   Status, LeadSource, ProjectInterest__c, Nationality__c,
                   IsConverted, CreatedDate, ConvertedOpportunityId,
                   ReAssignRRToSalesAssociate__c
            FROM Lead
            /* converted leads are listed as customers by getMyCustomers */
            WHERE OwnerId = :UserInfo.getUserId() AND IsConverted = FALSE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]);
    }

    /* Customer picker */

    /**
     * One row of the "who is this booking for?" picker. `id` is an Opportunity id; nothing on
     * the DTO or the UI is named for one (Modon's instruction).
     */
    public class CustomerDTO {
        /** The Opportunity behind this customer. Never rendered. */
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String projectInterest;
        @AuraEnabled public Date enquiryDate;
        /** Set only for rows that are still leads; `id` is null and the console converts on selection. */
        @AuraEnabled public Id leadId;
        @AuraEnabled public String status;
        /* the two fields the validation rule demands before conversion, so the qualify panel opens prefilled */
        @AuraEnabled public String nationality;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public Boolean needsQualifyDetails;
        /* set by findByIdentity when the buyer is already an Account; `id` is never set from a lookup */
        @AuraEnabled public Id accountId;
        /* an organisation converts to a business account, which needs Company on the lead */
        @AuraEnabled public Boolean isOrganisation;
        @AuraEnabled public String companyName;
        /* 'Customer' or 'Lead' */
        @AuraEnabled public String kind;
        /* the licence value that actually matched */
        @AuraEnabled public String tradeLicence;
        /* who can sign for this company; empty on a person or lead row */
        @AuraEnabled public List<SignatoryDTO> signatories;
        /* identity already on the record, so the panels open prefilled */
        @AuraEnabled public String eidNumber;
        @AuraEnabled public Date eidExpiry;
        @AuraEnabled public String passportNumber;
        @AuraEnabled public Date passportIssueDate;
        @AuraEnabled public Date passportExpiryDate;
        /* which field found this row, as a code: 'eid' | 'passport' | 'licence' | 'unified' |
           'email' | 'mobile'. tradeLicence above stays as a display fallback. */
        @AuraEnabled public String matchedOn;
        /* address gap, said before the rep chooses: the exact sets checkBookingEligibility
           blocks on. Null on a lead row. */
        @AuraEnabled public Boolean needsAddress;
    }

    /**
     * One person who could sign for a company. The rep picks from the people the company already
     * has instead of conversion inventing one per booking.
     */
    public class SignatoryDTO {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String title;
    }

    /* The identity a lead must carry */

    /**
     * What this buyer has to carry before a Lead can be inserted and converted. Derived from
     * residency, never from customer type. The set is the superset of all three orgs' rules.
     */
    public class IdentityNeedDTO {
        /* shown for this residency */
        @AuraEnabled public Boolean eidNumber = false;
        @AuraEnabled public Boolean eidExpiry = false;
        @AuraEnabled public Boolean passportNumber = false;
        @AuraEnabled public Boolean passportIssueDate = false;
        @AuraEnabled public Boolean passportExpiryDate = false;
        /* 1.30 - owed for this residency, as MODON's active Lead rules owe them */
        @AuraEnabled public Boolean eidNumberRequired = false;
        @AuraEnabled public Boolean eidExpiryRequired = false;
        @AuraEnabled public Boolean passportNumberRequired = false;
        @AuraEnabled public Boolean passportIssueDateRequired = false;
        @AuraEnabled public Boolean passportExpiryDateRequired = false;
    }

    /**
     * The one definition; the wrapper serves the client and createLeadFull enforces against it.
     * 1.28 - MSC-174 (B2): the table itself now lives in AurelixIdentityRuleService so that the
     * manual-KYC readiness check and B5's checklist read the same answer as this class. Resident:
     * Emirates ID number + expiry AND passport number + issue + expiry. Non-Resident: the passport
     * three. Blank residency requires nothing yet. c/mscEoiUtils.identityNeedsFor mirrors it.
     */
    private static IdentityNeedDTO identityNeedsFor(String residentStatus) {
        return AurelixIdentityRuleService.needsFor(residentStatus);
    }

    /** Static per residency, so cacheable is right. */
    @AuraEnabled(cacheable=true)
    public static IdentityNeedDTO identityNeeds(String residentStatus) {
        return identityNeedsFor(residentStatus);
    }

    /* what the org will accept: expiry rules refuse a past date, so a stored past date is not
       usable. 1.30: today is usable, as MODON's "< TODAY()" rules accept it. */
    private static Boolean usableExpiry(Date d) {
        return d != null && d >= Date.today();
    }
    /* Passport_Issue_Date_Should_not_be_Future */
    private static Boolean usableIssue(Date d) {
        return d != null && d <= Date.today();
    }

    /**
     * What MODON already holds for this buyer and whether it is enough to book with; asked before
     * booking an existing customer.
     */
    public class IdentityStateDTO {
        @AuraEnabled public IdentityNeedDTO needs;
        /** The record's answer where it has one, else the rep's. */
        @AuraEnabled public String residentStatus;
        @AuraEnabled public String nationality;
        @AuraEnabled public String eidNumber;
        @AuraEnabled public Date eidExpiry;
        @AuraEnabled public String passportNumber;
        @AuraEnabled public Date passportIssueDate;
        @AuraEnabled public Date passportExpiryDate;
        /* null | 'missing' | 'expired' | 'future'; codes, never sentences */
        @AuraEnabled public String eidExpiryReason;
        @AuraEnabled public String passportIssueReason;
        @AuraEnabled public String passportExpiryReason;
        /** True when nothing is left to ask. */
        @AuraEnabled public Boolean complete = false;
    }

    /** One record's identity, whichever object carries it. */
    private class IdentityRecord {
        String residentStatus;
        String nationality;
        String eidNumber;
        Date eidExpiry;
        String passportNumber;
        Date passportIssueDate;
        Date passportExpiryDate;
    }

    /**
     * Identity lives on the contact the booking converges on: a Person Account's own fields, or the
     * chosen signatory's (already proven by resolveSignatory).
     */
    /**
     * MSC-162. Would the org accept this document at all? Mirrors two MODON validation rules.
     * Blank is storable; malformed is refused.
     */
    private static Boolean storablePassport(String value) {
        return String.isBlank(value)
            || Pattern.matches('^[a-zA-Z0-9]+$', value.trim());
    }

    private static Boolean storableEid(String value) {
        return String.isBlank(value)
            || Pattern.matches('^784-[0-9]{4}-[0-9]{7}-[0-9]{1}$', value.trim());
    }

    private static IdentityRecord readIdentityRecord(Id accountId, Contact signatory) {
        IdentityRecord r = new IdentityRecord();
        if (accountId == null) {
            return r;
        }
        /* 1.34: without sharing, so a customer the search found is read whoever owns it */
        for (Account a : new MatchLookup().identityOf(accountId)) {
            if (a.IsPersonAccount) {
                /* EmiratesIDExpiryDate__pc, not EID_Expiry_Date__pc (populated on zero records) */
                r.residentStatus = a.UAE_Resident_Status__pc;
                r.nationality = a.Nationality__pc;
                r.eidNumber = a.EIDNumber__pc;
                r.eidExpiry = a.EmiratesIDExpiryDate__pc;
                r.passportNumber = a.PassportNumber__pc;
                r.passportIssueDate = a.PassportIssueDate__pc;
                r.passportExpiryDate = a.PassportExpiryDate__pc;
            } else if (signatory != null) {
                r.residentStatus = signatory.UAE_Resident_Status__c;
                r.nationality = signatory.Nationality__c;
                r.eidNumber = signatory.EIDNumber__c;
                r.eidExpiry = signatory.EmiratesIDExpiryDate__c;
                r.passportNumber = signatory.PassportNumber__c;
                r.passportIssueDate = signatory.PassportIssueDate__c;
                r.passportExpiryDate = signatory.PassportExpiryDate__c;
            }
        }
        return r;
    }

    @AuraEnabled(cacheable=false)
    public static IdentityStateDTO identityFor(
        Id accountId,
        Id signatoryContactId,
        String residentStatus
    ) {
        Contact signatory = resolveSignatory(accountId, signatoryContactId);
        IdentityRecord onFile = readIdentityRecord(accountId, signatory);

        IdentityStateDTO s = new IdentityStateDTO();
        /* the record's own answer wins, so conversion's write-back is a no-op */
        s.residentStatus = String.isNotBlank(onFile.residentStatus)
            ? onFile.residentStatus
            : residentStatus;
        s.nationality = onFile.nationality;
        s.needs = identityNeedsFor(s.residentStatus);
        s.eidNumber = onFile.eidNumber;
        s.eidExpiry = onFile.eidExpiry;
        s.passportNumber = onFile.passportNumber;
        s.passportIssueDate = onFile.passportIssueDate;
        s.passportExpiryDate = onFile.passportExpiryDate;

        /* 1.30: a blank value is owed only where MODON requires it */
        if (s.needs.eidExpiry) {
            s.eidExpiryReason = s.eidExpiry == null
                ? (s.needs.eidExpiryRequired == true ? 'missing' : null)
                : (usableExpiry(s.eidExpiry) ? null : 'expired');
        }
        if (s.needs.passportIssueDate) {
            s.passportIssueReason = s.passportIssueDate == null
                ? (s.needs.passportIssueDateRequired == true ? 'missing' : null)
                : (usableIssue(s.passportIssueDate) ? null : 'future');
        }
        /* 1.29: optional; only an expired date is owed */
        if (s.needs.passportExpiryDate) {
            s.passportExpiryReason = (s.passportExpiryDate != null && !usableExpiry(s.passportExpiryDate))
                ? 'expired'
                : null;
        }

        s.complete = String.isNotBlank(s.residentStatus)
            && (s.needs.eidNumberRequired != true || String.isNotBlank(s.eidNumber))
            && s.eidExpiryReason == null
            && (s.needs.passportNumberRequired != true || String.isNotBlank(s.passportNumber))
            && s.passportIssueReason == null
            && s.passportExpiryReason == null;
        return s;
    }

    /**
     * Does this buyer still owe identity before booking? datesMustBeUsable = true for an account
     * row (a stale date can be repaired through a new Lead); false for a lead row (the qualify
     * panel can only fill blanks).
     */
    private static Boolean identityUnsatisfied(
        String nationality,
        String residentStatus,
        String eidNumber,
        Date eidExpiry,
        String passportNumber,
        Date passportIssueDate,
        Date passportExpiryDate,
        Boolean datesMustBeUsable
    ) {
        if (String.isBlank(nationality) || String.isBlank(residentStatus)) {
            return true;
        }
        IdentityNeedDTO needs = identityNeedsFor(residentStatus);
        /* 1.30: owed only where MODON requires it; an entered date must still be usable */
        if (needs.eidNumberRequired && String.isBlank(eidNumber)) {
            return true;
        }
        if (needs.eidExpiry
                && ((needs.eidExpiryRequired && eidExpiry == null)
                    || (eidExpiry != null && datesMustBeUsable && !usableExpiry(eidExpiry)))) {
            return true;
        }
        if (needs.passportNumberRequired && String.isBlank(passportNumber)) {
            return true;
        }
        if (needs.passportIssueDate
                && ((needs.passportIssueDateRequired && passportIssueDate == null)
                    || (passportIssueDate != null && datesMustBeUsable && !usableIssue(passportIssueDate)))) {
            return true;
        }
        /* 1.29: a blank expiry is not owed */
        if (needs.passportExpiryDate && passportExpiryDate != null
                && datesMustBeUsable && !usableExpiry(passportExpiryDate)) {
            return true;
        }
        return false;
    }

    /**
     * Picklist values for the two fields that gate conversion, from the schema. 1.31: plus
     * newCustomerDespiteMatch ('true' or 'false'), the ALLOW_NEW_CUSTOMER_DESPITE_MATCH switch, so the
     * chooser knows whether to offer "Continue With New Details". A switch flipped in Setup reaches a
     * rep on the next page load (cacheable). The server refuses regardless of what the page shows.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getLeadQualifyOptions() {
        return new Map<String, List<String>>{
            'nationality' => picklistValues(Lead.Nationality__c.getDescribe()),
            'residentStatus' => picklistValues(Lead.UAEResidentStatus__c.getDescribe()),
            'newCustomerDespiteMatch' => new List<String>{
                String.valueOf(AurelixNewCustomerSwitch.isOn() == true)
            }
        };
    }

    private static List<String> picklistValues(Schema.DescribeFieldResult f) {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry e : f.getPicklistValues()) {
            if (e.isActive()) {
                out.add(e.getValue());
            }
        }
        return out;
    }

    /**
     * Customers the running rep can start a booking for: their open opportunities, returned as
     * customers. Closed opportunities excluded.
     */
    /** cacheable=false; mscConsole calls it imperatively. The list changes constantly. */
    @AuraEnabled(cacheable=false)
    public static List<CustomerDTO> getMyCustomers() {
        List<CustomerDTO> out = new List<CustomerDTO>();
        for (Opportunity o : [
            SELECT Id, Name, ProjectInterest__c, CreatedDate,
                   Account.Name, Account.PersonEmail, Account.PersonMobilePhone,
                   PrimaryContact__r.Name, PrimaryContact__r.Email,
                   PrimaryContact__r.MobilePhone
            FROM Opportunity
            WHERE OwnerId = :UserInfo.getUserId()
              AND IsClosed = false
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ]) {
            CustomerDTO d = new CustomerDTO();
            d.id = o.Id;

            // the buyer, in the order the org populates them; Opportunity name last
            if (o.PrimaryContact__r != null && String.isNotBlank(o.PrimaryContact__r.Name)) {
                d.name  = o.PrimaryContact__r.Name;
                d.email = o.PrimaryContact__r.Email;
                d.phone = o.PrimaryContact__r.MobilePhone;
            } else if (o.Account != null && String.isNotBlank(o.Account.Name)) {
                d.name  = o.Account.Name;
                d.email = o.Account.PersonEmail;
                d.phone = o.Account.PersonMobilePhone;
            } else {
                d.name = o.Name;
            }

            d.projectInterest = o.ProjectInterest__c;
            d.enquiryDate = o.CreatedDate != null ? o.CreatedDate.date() : null;
            out.add(d);
        }

        /* then the rep's open leads, after the qualified customers */
        for (Lead l : [
            SELECT Id, Name, Email, Phone, MobilePhone, Status,
                   ProjectInterest__c, CreatedDate,
                   Nationality__c, UAEResidentStatus__c,
                   EIDNumber__c, EmiratesIDExpiryDate__c,
                   PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c
            FROM Lead
            WHERE OwnerId = :UserInfo.getUserId()
              AND IsConverted = FALSE
              /* a booking surface never offers a closed lead (Retired_Reason_Mandatory_Check);
                 deny-list so inactive-but-stored values keep surfacing */
              AND Status NOT IN ('Retired', 'Duplicate')
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            CustomerDTO d = new CustomerDTO();
            d.leadId = l.Id;
            d.name = l.Name;
            d.email = l.Email;
            d.phone = String.isNotBlank(l.MobilePhone) ? l.MobilePhone : l.Phone;
            d.projectInterest = l.ProjectInterest__c;
            d.enquiryDate = l.CreatedDate != null ? l.CreatedDate.date() : null;
            d.status = l.Status;
            d.nationality = l.Nationality__c;
            d.residentStatus = l.UAEResidentStatus__c;
            d.eidNumber = l.EIDNumber__c;
            d.eidExpiry = l.EmiratesIDExpiryDate__c;
            d.passportNumber = l.PassportNumber__c;
            d.passportIssueDate = l.PassportIssueDate__c;
            d.passportExpiryDate = l.PassportExpiryDate__c;
            /* or the derived identity set is not satisfied */
            d.needsQualifyDetails = identityUnsatisfied(
                l.Nationality__c, l.UAEResidentStatus__c,
                l.EIDNumber__c, l.EmiratesIDExpiryDate__c,
                l.PassportNumber__c, l.PassportIssueDate__c, l.PassportExpiryDate__c,
                false
            );
            out.add(d);
        }
        return out;
    }

    /**
     * Qualify an existing lead and hand back the Opportunity. Same conversion createCustomer
     * performs, with Person-Account matching.
     */
    @AuraEnabled
    public static NewCustomerDTO convertLeadToCustomer(
        Id leadId,
        String nationality,
        String residentStatus,
        /* identity from the qualify panel, written fill-only (Sales_user_cant_change_Passport_and_EID) */
        String eidNumber,
        Date eidExpiry,
        String passportNumber,
        Date passportIssueDate,
        Date passportExpiry,
        /* the account the rep chose when this method returned candidates; re-verified below */
        Id targetAccountId,
        /* the chooser's other exit: none of these is this person; converts standalone.
           1.31: refused while any account matches, unless ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on */
        Boolean forceStandalone
    ) {
        if (leadId == null) {
            throw new AuraHandledException('No lead was supplied.');
        }
        List<Lead> leads = [
            SELECT Id, Name, Email, Phone, MobilePhone, IsConverted, ConvertedOpportunityId,
                   Nationality__c, UAEResidentStatus__c,
                   EIDNumber__c, En_EIDNumber__c, EmiratesIDExpiryDate__c,
                   PassportNumber__c, En_PassportNumber__c,
                   PassportIssueDate__c, PassportExpiryDate__c, Birthdate__c,
                   /* the licence, for the matcher below (Lead has only these two fields) */
                   Trade_License_Number__c, UnifiedNumber__c, Company
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leads.isEmpty()) {
            throw new AuraHandledException('That lead could no longer be found.');
        }
        Lead l = leads[0];

        // already qualified by someone else while the picker was open
        if (l.IsConverted) {
            if (l.ConvertedOpportunityId == null) {
                throw new AuraHandledException(
                    'That lead has already been qualified but has no booking attached.'
                );
            }
            NewCustomerDTO existing = new NewCustomerDTO();
            existing.leadId = l.Id;
            existing.opportunityId = l.ConvertedOpportunityId;
            existing.name = l.Name;
            return existing;
        }

        /* the org will not convert a lead without Nationality and UAE Resident Status; written
           only when supplied and missing */
        Boolean needsUpdate = false;
        if (String.isNotBlank(nationality) && String.isBlank(l.Nationality__c)) {
            l.Nationality__c = nationality;
            needsUpdate = true;
        }
        if (String.isNotBlank(residentStatus) && String.isBlank(l.UAEResidentStatus__c)) {
            l.UAEResidentStatus__c = residentStatus;
            needsUpdate = true;
        }
        /* identity fields, fill-only; plain field and En_ twin written together, only when both blank */
        if (String.isNotBlank(eidNumber)
                && String.isBlank(l.EIDNumber__c) && String.isBlank(l.En_EIDNumber__c)) {
            l.EIDNumber__c = eidNumber.trim();
            l.En_EIDNumber__c = eidNumber.trim();
            needsUpdate = true;
        }
        if (eidExpiry != null && l.EmiratesIDExpiryDate__c == null) {
            l.EmiratesIDExpiryDate__c = eidExpiry;
            needsUpdate = true;
        }
        if (String.isNotBlank(passportNumber)
                && String.isBlank(l.PassportNumber__c) && String.isBlank(l.En_PassportNumber__c)) {
            l.PassportNumber__c = passportNumber.trim();
            l.En_PassportNumber__c = passportNumber.trim();
            needsUpdate = true;
        }
        if (passportIssueDate != null && l.PassportIssueDate__c == null) {
            l.PassportIssueDate__c = passportIssueDate;
            needsUpdate = true;
        }
        if (passportExpiry != null && l.PassportExpiryDate__c == null) {
            l.PassportExpiryDate__c = passportExpiry;
            needsUpdate = true;
        }
        if (needsUpdate) {
            try {
                update l;
            } catch (Exception e) {
                throw new AuraHandledException(
                    'The lead could not be updated before qualifying: ' + e.getMessage()
                );
            }
        }
        if (String.isBlank(l.Nationality__c) || String.isBlank(l.UAEResidentStatus__c)) {
            throw new AuraHandledException(
                'Nationality and UAE Resident Status are required before this lead can be qualified.'
            );
        }

        /* the same matcher chain createCustomer runs, on the lead's own fields */
        String leadPhone = String.isNotBlank(l.MobilePhone) ? l.MobilePhone : l.Phone;
        /* MSC-172. The licence: Trade_License_Number__c first (what createLeadFull writes), then
           UnifiedNumber__c. Blank on an individual lead. */
        /* gated on Company, so an individual lead passes a null licence as before */
        String leadLicence = null;
        if (String.isNotBlank(l.Company)) {
            leadLicence = String.isNotBlank(l.Trade_License_Number__c)
                ? l.Trade_License_Number__c
                : l.UnifiedNumber__c;
        }
        /* 1.31: forceStandalone skips the match only while ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on (as
           before); with it off the match runs, so a standalone answer can be refused below */
        Boolean standaloneAllowed = forceStandalone == true && AurelixNewCustomerSwitch.isOn();
        /* 1.33: no Company means a person (personMatches); a company lead keeps the two tiers */
        Boolean companyLead = String.isNotBlank(l.Company);
        /* the Emirates ID the person match used, so the chip names only a key that was searched */
        String chipEid = companyLead
            ? l.EIDNumber__c
            : countedEid(l.EIDNumber__c, l.UAEResidentStatus__c);
        List<Account> candidates = standaloneAllowed
            ? new List<Account>()
            : companyLead
                ? matchCandidates(
                    l.EIDNumber__c, l.PassportNumber__c, leadLicence, l.Email, leadPhone)
                : personMatches(
                    l.EIDNumber__c, l.PassportNumber__c, l.Email, leadPhone, l.UAEResidentStatus__c);

        Id existingAccountId;
        if (forceStandalone == true) {
            /* 1.31: with the switch off a match must be chosen, as in the Sales App; the throw rolls
               back the fill-only lead update above */
            if (!standaloneAllowed && !candidates.isEmpty()) {
                throw matchMustBeChosen();
            }
            /* the rep's explicit answer: never converge */
            existingAccountId = null;
        } else if (targetAccountId != null) {
            /* the rep's choice, honoured only if a fresh match still contains it */
            Boolean stillACandidate = false;
            for (Account a : candidates) {
                if (a.Id == targetAccountId) {
                    stillACandidate = true;
                    break;
                }
            }
            if (!stillACandidate) {
                throw new AuraHandledException(
                    'That customer could no longer be matched to this lead. '
                    + 'Search them again and book directly instead.'
                );
            }
            existingAccountId = targetAccountId;
        } else if (candidates.size() > 1) {
            /* more than one account matches: no conversion, the rep chooses */
            NewCustomerDTO choice = new NewCustomerDTO();
            choice.name = l.Name;
            /* leadLicence, so the chip can say what was matched on */
            choice.candidates = toCandidateDtos(
                candidates, chipEid, l.PassportNumber__c, leadLicence,
                l.Email, leadPhone);
            return choice;
        } else {
            existingAccountId = candidates.isEmpty() ? null : candidates[0].Id;
        }

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus(convertedLeadStatus());
        lc.setDoNotCreateOpportunity(false);
        lc.setOwnerId(UserInfo.getUserId());
        convergeOnAccount(lc, existingAccountId);

        /* through tryConvert for the queue-owned diagnosis; no standalone retry on this route */
        Database.LeadConvertResult result = tryConvert(lc);
        if (result == null) {
            throw new AuraHandledException(explainConversionFailure(l.Id));
        }

        /* fill-only */
        stampBirthdate(result.getAccountId(), l.Birthdate__c);

        NewCustomerDTO dto = new NewCustomerDTO();
        dto.leadId = l.Id;
        dto.opportunityId = result.getOpportunityId();
        dto.name = l.Name;
        return dto;
    }

    /** Server-side search, so the rep can find a lead older than the cap. Scoped to their own leads. */
    @AuraEnabled(cacheable=true)
    public static List<LeadDTO> searchLeads(String term) {
        if (String.isBlank(term) || term.trim().length() < 2) {
            return getRecentLeads();
        }
        String pattern = '%' + String.escapeSingleQuotes(term.trim()) + '%';
        return toDtos([
            SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone, Company,
                   Status, LeadSource, ProjectInterest__c, Nationality__c,
                   IsConverted, CreatedDate, ConvertedOpportunityId,
                   ReAssignRRToSalesAssociate__c
            FROM Lead
            // converted leads excluded here too
            WHERE OwnerId = :UserInfo.getUserId() AND IsConverted = FALSE
              AND (Name LIKE :pattern OR Email LIKE :pattern OR Phone LIKE :pattern
                   OR MobilePhone LIKE :pattern OR Company LIKE :pattern)
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]);
    }

    @AuraEnabled(cacheable=true)
    public static LeadDTO getLeadDetail(Id leadId) {
        if (leadId == null) {
            return null;
        }
        List<Lead> ls = [
            SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone, Company,
                   Status, LeadSource, ProjectInterest__c, Nationality__c,
                   IsConverted, CreatedDate, ConvertedOpportunityId,
                   ReAssignRRToSalesAssociate__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        return ls.isEmpty() ? null : toDtos(ls)[0];
    }

    /** Project picklist, read at runtime. */
    @AuraEnabled(cacheable=true)
    public static List<String> getProjectOptions() {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry e :
                Lead.ProjectInterest__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                out.add(e.getValue());
            }
        }
        return out;
    }

    /**
     * Create an individual lead (no Company). ProjectInterest__c is required by field config, so
     * it is checked here.
     */
    @AuraEnabled
    public static Id createLead(
        String firstName,
        String lastName,
        String phone,
        String email,
        String projectInterest
    ) {
        return createLeadWithIdentity(
            firstName, lastName, phone, email, projectInterest,
            null, null, null, null, null, null
        );
    }

    /** The same lead, plus the identity and qualification the org demands. */
    public static Id createLeadWithIdentity(
        String firstName,
        String lastName,
        String phone,
        String email,
        String projectInterest,
        String nationality,
        String residentStatus,
        String eidNumber,
        String passportNumber,
        /* the two dates the expiry rules demand */
        Date eidExpiry,
        Date passportExpiry
    ) {
        return createLeadFull(
            firstName, lastName, phone, email, projectInterest,
            nationality, residentStatus, eidNumber, passportNumber,
            null, null, null, null, null,
            eidExpiry, passportExpiry, null
        );
    }

    /**
     * The My Leads create path with the full identity set. The five-argument createLead stays
     * for the test class; the console no longer offers it.
     */
    /** What happened to the lead the rep just saved. */
    public class LeadCreateResult {
        @AuraEnabled public Id leadId;
        /** The owner's name off the record. */
        @AuraEnabled public String ownerName;
        /* true whenever the lead is not owned by the rep who typed it (routing or round-robin) */
        @AuraEnabled public Boolean queued = false;
    }

    @AuraEnabled
    public static LeadCreateResult createLeadDetailed(
        String firstName,
        String lastName,
        String phone,
        String email,
        String projectInterest,
        String nationality,
        String residentStatus,
        String eidNumber,
        String passportNumber,
        Date eidExpiry,
        Date passportIssueDate,
        Date passportExpiry,
        /* optional */
        Date birthdate
    ) {
        /* assignment is automation's, so the owner is read back after insert */
        return outcomeFor(createLeadFull(
            firstName, lastName, phone, email, projectInterest,
            nationality, residentStatus, eidNumber, passportNumber,
            null, null, passportIssueDate, null, null,
            eidExpiry, passportExpiry, birthdate
        ));
    }

    @TestVisible
    private static LeadCreateResult outcomeFor(Id leadId) {
        LeadCreateResult r = new LeadCreateResult();
        r.leadId = leadId;
        for (Lead l : [SELECT OwnerId, Owner.Name FROM Lead WHERE Id = :leadId LIMIT 1]) {
            r.queued = l.OwnerId != UserInfo.getUserId();
            /* Owner is polymorphic and the Name object is empty in a test transaction, so this
               is a fallback chain ending at a direct read */
            r.ownerName = l.Owner.Name;
            if (String.isBlank(r.ownerName)) {
                if (String.valueOf(l.OwnerId).startsWith('00G')) {
                    for (Group g : [SELECT Name FROM Group WHERE Id = :l.OwnerId]) {
                        r.ownerName = g.Name;
                    }
                } else {
                    for (User u : [SELECT Name FROM User WHERE Id = :l.OwnerId]) {
                        r.ownerName = u.Name;
                    }
                }
            }
        }
        return r;
    }

    /* leadRecordTypeId removed with the RecordTypeId assignment */

    /**
     * Every field this org demands before a console lead can be converted:
     * Nationality_and_UAE_Resident_are_mandato, Passport_Number_Mandatory_Validation (En_ field),
     * Passport_IssueDate_Mandatory_Validation, First_Name_Mandatory_Check. Company blank makes a
     * Person Account, set makes a business Account, so it is driven by customerType.
     */
    public static Id createLeadFull(
        String firstName,
        String lastName,
        String phone,
        String email,
        String projectInterest,
        String nationality,
        String residentStatus,
        String eidNumber,
        String passportNumber,
        String customerType,
        String companyName,
        Date passportIssueDate,
        String tradeLicence,
        /**
         * The account this buyer has already been matched to, or null. Set only when the rep picked
         * an existing customer. Must be on the record at insert: checkDuplicateLeadsAndReassignOwner
         * runs before insert.
         */
        Id existingAccountId,
        /* the two dates the expiry rules demand */
        Date eidExpiry,
        Date passportExpiry,
        /* optional; written to Lead.Birthdate__c and stamped onto the Person Account by stampBirthdate */
        Date birthdate
    ) {
        /* through the helper, which accepts both spellings */
        Boolean isOrganisation = isOrganisationType(customerType);
        if (String.isBlank(firstName)) {
            // First_Name_Mandatory_Check, said as a sentence
            throw new AuraHandledException('A first name is required to create a customer.');
        }
        /* Lead.FirstName is 40 characters and LastName 80; names from a matched account are trimmed */
        firstName = firstName.trim();
        if (firstName.length() > 40) {
            firstName = firstName.substring(0, 40).trim();
        }
        lastName = lastName == null ? lastName : lastName.trim();
        if (lastName != null && lastName.length() > 80) {
            lastName = lastName.substring(0, 80).trim();
        }
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('A last name is required to create a lead.');
        }
        if (String.isBlank(projectInterest)) {
            throw new AuraHandledException('Choose which project this lead is interested in.');
        }
        /* Lead.Trade_License_Number__c is Text(30); refused rather than truncated, an identifier
           must not be shortened */
        if (isOrganisation && String.isNotBlank(tradeLicence) && tradeLicence.trim().length() > 30) {
            throw new AuraHandledException(
                'That trade licence number is too long. Check it and try again.'
            );
        }
        /* the set this residency demands, refused here with a sentence; date-sanity checks run on
           any supplied date */
        /* 1.30 - MODON's active Lead rules, in their own words: only a Non-Resident's passport
           number is owed; any entered date is checked */
        IdentityNeedDTO needs = identityNeedsFor(residentStatus);
        if (needs.eidNumberRequired && String.isBlank(eidNumber)) {
            throw new AuraHandledException(
                'Emirates ID Number field is mandatory if the Lead is a UAE Resident'
            );
        }
        if (needs.eidExpiryRequired && eidExpiry == null) {
            throw new AuraHandledException(
                'Emirates ID Expiry Date field is mandatory if the Lead is a UAE Resident'
            );
        }
        if (eidExpiry != null && !usableExpiry(eidExpiry)) {
            throw new AuraHandledException(
                'Emirates ID Expiry Date cannot be a Past Date'
            );
        }
        if (needs.passportNumberRequired && String.isBlank(passportNumber)) {
            throw new AuraHandledException(
                'Passport Number field is mandatory if the Lead is not a UAE Resident'
            );
        }
        if (needs.passportIssueDateRequired && passportIssueDate == null) {
            throw new AuraHandledException(
                'Passport Issue Date field is mandatory if the Lead is not a UAE Resident'
            );
        }
        if (passportIssueDate != null && !usableIssue(passportIssueDate)) {
            throw new AuraHandledException(
                'Passport Issue Date cannot be a Future Date'
            );
        }
        if (passportExpiry != null && !usableExpiry(passportExpiry)) {
            throw new AuraHandledException(
                'Passport Expiry Date cannot be a Past Date'
            );
        }
        /* one normalised value for both phone fields, spaces stripped as LeadTriggerHelper.updatePhone does */
        String normalisedPhone = String.isBlank(phone) ? null : phone.trim().replace(' ', '');
        Lead l = new Lead(
            FirstName = String.isBlank(firstName) ? null : firstName.trim(),
            LastName = lastName.trim(),
            Email = String.isBlank(email) ? null : email.trim(),
            Phone = normalisedPhone,
            /* MobilePhone as well: the trigger masks before it falls back Phone->MobilePhone, so a
               lead with Phone only never got En_MobilePhone__c. Mobile_Phone_Mandatory_Check is live
               for console leads as a result. */
            MobilePhone = normalisedPhone,
            ProjectInterest__c = projectInterest,
            /* Company left null: a blank Company is what makes a person lead convert to a Person Account */
            // a lead the rep raises in the console is Self Generated
            LeadSource = 'Self Generated',
            Nationality__c = String.isBlank(nationality) ? null : nationality,
            UAEResidentStatus__c = String.isBlank(residentStatus) ? null : residentStatus,
            /* plain and encrypted field both: the rules test En_, the org reads plain */
            EIDNumber__c = String.isBlank(eidNumber) ? null : eidNumber.trim(),
            En_EIDNumber__c = String.isBlank(eidNumber) ? null : eidNumber.trim(),
            PassportNumber__c = String.isBlank(passportNumber) ? null : passportNumber.trim(),
            En_PassportNumber__c = String.isBlank(passportNumber) ? null : passportNumber.trim(),
            PassportIssueDate__c = passportIssueDate,
            /* the two dates; no En_ twin */
            EmiratesIDExpiryDate__c = eidExpiry,
            PassportExpiryDate__c = passportExpiry,
            /* optional */
            Birthdate__c = birthdate,
            Trade_License_Number__c = isOrganisation && String.isNotBlank(tradeLicence)
                ? tradeLicence.trim()
                : null
        );

        /* Company decides what conversion produces */
        /* RecordTypeId is not set: Person_Lead is not on every sales profile
           (INVALID_CROSS_REFERENCE_KEY) and where it is it restricts ProjectInterest__c. The org's
           own default (no record type) is right. */
        if (isOrganisation) {
            if (String.isBlank(companyName)) {
                throw new AuraHandledException(
                    'A company name is required to create an organisation customer.'
                );
            }
            l.Company = companyName.trim();
            /* TradeName__c and UnifiedNumber__c: Trade_Details_Are_Mandatory rejects a Lead with a
               Company while either is blank. Require_VAT_and_Unified_Before_Conversio stays dormant
               (VAT_Certificate_Type__c is never set). */
            l.TradeName__c = companyName.trim();
            if (String.isNotBlank(tradeLicence)) {
                l.UnifiedNumber__c = tradeLicence.trim();
            }
        }
        /* carried in: the customer the rep chose */
        if (existingAccountId != null) {
            l.Existing_Account__c = existingAccountId;
        }
        try {
            // LeadTriggerHandler owns duplicate detection, assignment and SLA from here
            if (existingAccountId != null) {
                /* 1.34: without sharing, as the rep may have no access to the customer */
                new OntoFoundCustomer().insertLead(l);
            } else {
                insert l;
            }
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return l.Id;
    }

    /* Create and continue */

    /** What the journey needs back to carry on booking. */
    public class NewCustomerDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id leadId;
        @AuraEnabled public String name;
        /* set only when more than one existing account matched; opportunityId and leadId are null
           and no DML has happened */
        @AuraEnabled public List<CustomerDTO> candidates;
    }

    /**
     * Create a buyer mid-booking and hand back an Opportunity: insert the Lead as createLead does
     * (LeadTriggerHandler keeps its job), then convert. Not rolled back if the conversion fails:
     * the Lead is recoverable from My Leads.
     */
    @AuraEnabled
    public static NewCustomerDTO createCustomer(
        String firstName,
        String lastName,
        String phone,
        String email,
        String projectInterest,
        String nationality,
        String residentStatus,
        String eidNumber,
        String passportNumber,
        String customerType,
        String companyName,
        Date passportIssueDate,
        String tradeLicence,
        /* the two dates; for an organisation these are the signatory's */
        Date eidExpiry,
        Date passportExpiry,
        /* optional */
        Date birthdate,
        /* the chooser's escape hatch: none of these people is this buyer, proceed standalone.
           1.31: refused while any account matches, unless ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on */
        Boolean forceCreate,
        /* MSC-139. 'Yes', 'No' or blank (nobody asked). Organisation only. */
        String isAuthorisedSignatory
    ) {
        /* matching runs before any insert, so the ambiguous answer returns without DML. A company
           is matched by its own method: matchCandidates cannot carry IsPersonAccount = false. */
        Id existingAccountId;
        String matchedTier = null;
        if (isOrganisationType(customerType)) {
            existingAccountId = matchOrganisationAccount(tradeLicence);
            matchedTier = existingAccountId == null ? null : 'licence';
        } else {
            /* 1.33: the Sales App's person match; the Emirates ID counts only for a Resident */
            List<Account> candidates =
                personMatches(eidNumber, passportNumber, email, phone, residentStatus);
            String chipEid = countedEid(eidNumber, residentStatus);
            if (forceCreate == true) {
                /* 1.31: only while ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on; with it off a match must be
                   chosen, as in the Sales App, and nothing is written */
                if (!candidates.isEmpty() && !AurelixNewCustomerSwitch.isOn()) {
                    throw matchMustBeChosen();
                }
                /* the rep rejected every candidate: create standalone unconditionally */
                existingAccountId = null;
            } else if (candidates.size() > 1) {
                /* ambiguous: nothing written, the rep chooses */
                NewCustomerDTO choice = new NewCustomerDTO();
                choice.name = (String.isBlank(firstName) ? '' : firstName.trim() + ' ')
                    + (lastName == null ? '' : lastName.trim());
                choice.candidates = toCandidateDtos(
                    candidates, chipEid, passportNumber, null, email, phone);
                return choice;
            } else {
                existingAccountId = candidates.isEmpty() ? null : candidates[0].Id;
                matchedTier = candidates.isEmpty()
                    ? null
                    : accountMatchedOn(candidates[0], chipEid, passportNumber,
                        null, email, phone);
            }
        }

        /* null accountId: the rep asked for a new customer, so duplicate review should see it */
        Id leadId = createLeadFull(
            firstName, lastName, phone, email, projectInterest,
            nationality, residentStatus, eidNumber, passportNumber,
            customerType, companyName, passportIssueDate, tradeLicence, null,
            eidExpiry, passportExpiry, birthdate
        );

        /* MSC-172. Second look, with the Lead written and the conversion one statement away: the
         * window between match and conversion is a triggered insert wide. It cannot be closed in
         * Apex (nothing to lock for a genuinely new person); only a uniqueness constraint could.
         * Runs only when the first pass found nobody. */
        if (existingAccountId == null && forceCreate != true) {
            Id lateMatch = null;
            if (isOrganisationType(customerType)) {
                lateMatch = matchOrganisationAccount(tradeLicence);
            } else {
                /* 1.33: the same person match as the first pass */
                List<Account> second =
                    personMatches(eidNumber, passportNumber, email, phone, residentStatus);
                if (!second.isEmpty()) {
                    /* strongest key, then newest; more than one means a race already produced a pair */
                    lateMatch = second[0].Id;
                }
            }
            if (lateMatch != null) {
                System.debug(LoggingLevel.WARN,
                    'Lead ' + leadId + ' matched account ' + lateMatch + ' on the '
                    + 'pre-conversion re-check but not on the first pass - a concurrent '
                    + 'booking created this customer while the lead was being written. '
                    + 'Converging rather than creating a duplicate.');
                existingAccountId = lateMatch;
                matchedTier = matchedTier == null ? 'late' : matchedTier;
            }
        }

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(convertedLeadStatus());
        lc.setDoNotCreateOpportunity(false);
        // the rep who raised it owns it, so it shows in getMyCustomers
        lc.setOwnerId(UserInfo.getUserId());
        convergeOnAccount(lc, existingAccountId);

        /* converge, and if that is refused, convert anyway: a duplicate person is a data problem,
           a blocked booking is a lost sale */
        Database.LeadConvertResult result = tryConvert(lc);
        if (result == null && existingAccountId != null) {
            /* the tier is logged: a refused document match is a compliance finding */
            System.debug(LoggingLevel.WARN,
                'Lead ' + leadId + ' could not converge on account ' + existingAccountId
                + ' (matched on ' + matchedTier + '); converting standalone instead.');
            Database.LeadConvert retry = new Database.LeadConvert();
            retry.setLeadId(leadId);
            retry.setConvertedStatus(convertedLeadStatus());
            retry.setDoNotCreateOpportunity(false);
            retry.setOwnerId(UserInfo.getUserId());
            result = tryConvert(retry);
        }
        if (result == null) {
            throw new AuraHandledException(explainConversionFailure(leadId));
        }

        /* Lead has no UnifiedNumber__c; stamp it post-conversion */
        if (isOrganisationType(customerType) && String.isNotBlank(tradeLicence)) {
            stampCompanyLicence(result.getAccountId(), tradeLicence.trim());
        }
        /* date of birth, fill-only */
        stampBirthdate(result.getAccountId(), birthdate);
        /* MSC-139. the signatory answer */
        if (isOrganisationType(customerType)) {
            linkPowerOfAttorney(
                result.getAccountId(), result.getContactId(), isAuthorisedSignatory);
        }

        NewCustomerDTO dto = new NewCustomerDTO();
        dto.leadId = leadId;
        dto.opportunityId = result.getOpportunityId();
        dto.name = (String.isBlank(firstName) ? '' : firstName.trim() + ' ') + lastName.trim();
        return dto;
    }

    /** One spelling of the organisation test. */
    private static Boolean isOrganisationType(String customerType) {
        return 'Organisation'.equalsIgnoreCase(customerType)
            || 'Organization'.equalsIgnoreCase(customerType);
    }

    /**
     * All three licence fields, matching mapKYCTradeLicenseValues. Fills blanks only: conversion
     * can land on a company MODON has held for years, and AccountTriggerHelper sends a changed
     * UnifiedNumber__c to Oracle. Not fatal.
     */
    private static void stampCompanyLicence(Id accountId, String licence) {
        if (accountId == null || String.isBlank(licence)) {
            return;
        }
        List<Account> found = [
            SELECT Id, IsPersonAccount, UnifiedNumber__c,
                   TradeLicenseNumber__c, Trade_License_Number__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        /* a Person Account must never carry a trade licence */
        if (found.isEmpty() || found[0].IsPersonAccount == true) {
            return;
        }
        Account existing = found[0];
        Account patch = new Account(Id = existing.Id);
        Boolean changed = false;
        if (String.isBlank(existing.UnifiedNumber__c)) {
            patch.UnifiedNumber__c = licence;
            changed = true;
        }
        if (String.isBlank(existing.TradeLicenseNumber__c)) {
            patch.TradeLicenseNumber__c = licence;
            changed = true;
        }
        if (String.isBlank(existing.Trade_License_Number__c)) {
            patch.Trade_License_Number__c = licence;
            changed = true;
        }
        if (!changed) {
            return;
        }
        try {
            update patch;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not stamp trade licence on account ' + accountId
                + '; compliance will report it as missing. ' + e.getMessage());
        }
    }

    /**
     * Date of birth onto the Person Account, fill-only (PersonBirthdate is a VERIFIED_FIELD).
     * Not fatal. Person Accounts only.
     */
    /**
     * MSC-139. "Is this contact the authorised signatory?" recorded as a Power_of_Attorney__c row
     * (what sendKYCForm looks up). A 'Yes' links the contact and nothing else; 'No' or blank
     * writes nothing. Fill-only, never fatal.
     */
    private static void linkPowerOfAttorney(Id accountId, Id contactId, String answer) {
        if (accountId == null || contactId == null || String.isBlank(answer)) {
            return;
        }
        if (!'Yes'.equalsIgnoreCase(answer.trim())) {
            return;
        }
        try {
            List<Power_of_Attorney__c> existing = [
                SELECT Id FROM Power_of_Attorney__c
                WHERE Organization_Account__c = :accountId AND Contact__c = :contactId
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return;
            }
            /* Name is an AutoNumber */
            insert new Power_of_Attorney__c(
                Organization_Account__c = accountId,
                Contact__c = contactId
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not link a power of attorney for contact ' + contactId
                + ' at account ' + accountId + '. ' + e.getMessage());
        }
    }

    private static void stampBirthdate(Id accountId, Date birthdate) {
        if (accountId == null || birthdate == null) {
            return;
        }
        List<Account> found = [
            SELECT Id, IsPersonAccount, PersonBirthdate
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (found.isEmpty() || found[0].IsPersonAccount != true
                || found[0].PersonBirthdate != null) {
            return;
        }
        try {
            update new Account(Id = found[0].Id, PersonBirthdate = birthdate);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not stamp the date of birth on account ' + accountId
                + '; the compliance panel will report it as missing. ' + e.getMessage());
        }
    }

    /**
     * The converted status ApiName ("Qualified" here, labelled "Converted"); setConvertedStatus
     * takes the ApiName. Queried, falling back to the constant MBP_DPGCreateLeadAPI uses.
     */
    private static String convertedLeadStatus() {
        List<LeadStatus> statuses = [
            SELECT ApiName FROM LeadStatus WHERE IsConverted = TRUE ORDER BY SortOrder LIMIT 1
        ];
        return statuses.isEmpty()
            ? Constants.EOI_HOME_FALLBACK_CONVERTED_STATUS
            : statuses[0].ApiName;
    }

    /** The buyer's existing Person Account, by email or mobile. Null when new. */
    /**
     * Identity first: the document is how the org knows a buyer. Returns a list (an Account and
     * an open Lead can both exist), accounts first. Never returns an existing Opportunity: it may
     * belong to another agent. customerType decides which document is searched.
     */
    @AuraEnabled(cacheable=false)
    public static List<CustomerDTO> findByIdentity(
        String customerType,
        String residentStatus,
        String idNumber
    ) {
        List<CustomerDTO> out = new List<CustomerDTO>();
        String doc = String.isBlank(idNumber) ? null : idNumber.trim();
        if (doc == null) {
            return out;
        }
        /* MSC-172. The same variants the create path matches on, in all four queries. */
        Set<String> docs = docBind(doc);
        /* through the helper, which accepts both spellings */
        Boolean isOrg = isOrganisationType(customerType);
        /* residency no longer decides which document field is searched */

        // accounts
        /* one select list across all three branches */
        List<Account> accounts;
        /* 1.34: every customer, whoever owns it (MatchLookup, without sharing) */
        if (isOrg) {
            /* three licence fields, none authoritative (MODON mostly populates UnifiedNumber__c).
               En_TradeLicenseNumber__c is EncryptedText and cannot be filtered. IsPersonAccount = false. */
            accounts = new MatchLookup().companiesByLicence(docs);
        } else {
            /* both documents, whatever the toggle said; LIMIT 10 */
            accounts = new MatchLookup().peopleByDocument(docs);
        }

        /* the signatories, one query for every company that matched */
        Map<Id, List<SignatoryDTO>> signatoriesByAccount =
            isOrg ? signatoriesFor(new Map<Id, Account>(accounts).keySet())
                  : new Map<Id, List<SignatoryDTO>>();

        /* mapping shared with findByContact and the candidate list via accountRow */
        for (Account a : accounts) {
            /* docMatches, not equals, so the chip agrees with the query */
            String code = isOrg
                ? (docMatches(doc, a.UnifiedNumber__c) ? 'unified' : 'licence')
                : (docMatches(doc, a.EIDNumber__pc) ? 'eid' : 'passport');
            out.add(accountRow(a, isOrg, code, doc, signatoriesByAccount));
        }

        // open leads
        List<Lead> leads;
        if (isOrg) {
            /* UnifiedNumber__c as well; `Company != null` because a lead without one is a person lead */
            leads = [
                SELECT Id, OwnerId, Name, Company, Email, Phone, MobilePhone, Status,
                       ProjectInterest__c, Nationality__c, UAEResidentStatus__c,
                       EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c,
                       PassportIssueDate__c, PassportExpiryDate__c,
                       UnifiedNumber__c, Trade_License_Number__c
                FROM Lead
                WHERE (Trade_License_Number__c IN :docs OR UnifiedNumber__c IN :docs)
                  AND Company != null
                  AND IsConverted = FALSE
                  // closed leads leave the booking surfaces
                  AND Status NOT IN ('Retired', 'Duplicate')
                ORDER BY CreatedDate DESC
                LIMIT 25
            ];
        } else {
            /* both documents; LIMIT 25 because the queue filter runs after the query */
            leads = [
                SELECT Id, OwnerId, Name, Company, Email, Phone, MobilePhone, Status,
                       ProjectInterest__c, Nationality__c, UAEResidentStatus__c,
                       EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c,
                       PassportIssueDate__c, PassportExpiryDate__c,
                       UnifiedNumber__c, Trade_License_Number__c
                FROM Lead
                WHERE (EIDNumber__c IN :docs OR PassportNumber__c IN :docs)
                  AND IsConverted = FALSE
                  // closed leads leave the booking surfaces
                  AND Status NOT IN ('Retired', 'Duplicate')
                ORDER BY CreatedDate DESC
                LIMIT 25
            ];
        }
        for (Lead l : leads) {
            /* queue-owned leads excluded here, not in the query: `Owner.Type != 'Queue'` joins the
               Name object, which is empty in a test transaction. 00G prefix = queue on a Lead. */
            if (String.valueOf(l.OwnerId).startsWith('00G')) {
                continue;
            }
            String code = isOrg
                /* docMatches, as on the account rows */
                ? (docMatches(doc, l.UnifiedNumber__c) ? 'unified' : 'licence')
                : (docMatches(doc, l.EIDNumber__c) ? 'eid' : 'passport');
            out.add(leadRow(l, isOrg, code));
        }
        return out;
    }

    /**
     * One account row, one spelling, shared by findByIdentity, findByContact and the candidate
     * list. `matchedOn` is the chip code; `doc` feeds matchedLicence.
     */
    private static CustomerDTO accountRow(
        Account a,
        Boolean isOrg,
        String matchedOn,
        String doc,
        Map<Id, List<SignatoryDTO>> signatoriesByAccount
    ) {
        CustomerDTO d = new CustomerDTO();
        d.accountId = a.Id;
        d.name = a.Name;
        d.email = a.PersonEmail;
        d.phone = a.PersonMobilePhone;
        /* nationality and residency carried through; conversion needs them */
        d.nationality = a.Nationality__pc;
        d.residentStatus = a.UAE_Resident_Status__pc;
        /* person identity, so the identity step opens prefilled; null on a business account */
        d.eidNumber = a.EIDNumber__pc;
        d.eidExpiry = a.EmiratesIDExpiryDate__pc;
        d.passportNumber = a.PassportNumber__pc;
        d.passportIssueDate = a.PassportIssueDate__pc;
        d.passportExpiryDate = a.PassportExpiryDate__pc;
        /* the full derived set; usability counts, a stale date on an account can be repaired */
        d.needsQualifyDetails = identityUnsatisfied(
            a.Nationality__pc, a.UAE_Resident_Status__pc,
            a.EIDNumber__pc, a.EmiratesIDExpiryDate__pc,
            a.PassportNumber__pc, a.PassportIssueDate__pc, a.PassportExpiryDate__pc,
            true
        );
        d.isOrganisation = isOrg;
        d.kind = 'Customer';
        d.matchedOn = matchedOn;
        /* the eligibility gate's own field sets */
        d.needsAddress = isOrg
            ? (String.isBlank(a.BillingStreet)
               || String.isBlank(a.BillingCity)
               || String.isBlank(a.BillingState)
               || String.isBlank(a.BillingPostalCode)
               || String.isBlank(a.BillingCountry)
               || String.isBlank(a.UnifiedNumber__c))
            : (String.isBlank(a.PersonMailingStreet)
               || String.isBlank(a.PersonMailingCity)
               || String.isBlank(a.PersonMailingState)
               || String.isBlank(a.PersonMailingPostalCode)
               || String.isBlank(a.PersonMailingCountry));
        if (isOrg) {
            d.companyName = a.Name;
            /* a company's email and phone are on the record, not PersonEmail / PersonMobilePhone */
            d.email = a.Company_Email_Address__c;
            d.phone = a.Phone;
            d.tradeLicence = matchedLicence(a, doc);
            List<SignatoryDTO> people = signatoriesByAccount == null
                ? null
                : signatoriesByAccount.get(a.Id);
            d.signatories = people == null ? new List<SignatoryDTO>() : people;
        }
        return d;
    }

    /** One lead row, one spelling. */
    private static CustomerDTO leadRow(Lead l, Boolean isOrg, String matchedOn) {
        CustomerDTO d = new CustomerDTO();
        d.leadId = l.Id;
        d.name = l.Name;
        d.companyName = l.Company;
        d.email = l.Email;
        d.phone = String.isNotBlank(l.MobilePhone) ? l.MobilePhone : l.Phone;
        d.projectInterest = l.ProjectInterest__c;
        d.status = l.Status;
        d.nationality = l.Nationality__c;
        d.residentStatus = l.UAEResidentStatus__c;
        d.isOrganisation = isOrg;
        d.kind = 'Lead';
        d.matchedOn = matchedOn;
        d.eidNumber = l.EIDNumber__c;
        d.eidExpiry = l.EmiratesIDExpiryDate__c;
        d.passportNumber = l.PassportNumber__c;
        d.passportIssueDate = l.PassportIssueDate__c;
        d.passportExpiryDate = l.PassportExpiryDate__c;
        /* blanks only; the qualify panel writes fill-only */
        d.needsQualifyDetails = identityUnsatisfied(
            l.Nationality__c, l.UAEResidentStatus__c,
            l.EIDNumber__c, l.EmiratesIDExpiryDate__c,
            l.PassportNumber__c, l.PassportIssueDate__c, l.PassportExpiryDate__c,
            false
        );
        return d;
    }

    /**
     * MSC-212. The lead "Book a unit" was pressed on, as the same row the pickers build, so the
     * journey's customer step opens on it pre-filled instead of making the rep re-search their
     * own lead. Converted while the drawer was open: the row comes back as its Opportunity
     * (`id` set - the DTO's own meaning of the field - and kind 'Customer') and the journey
     * continues as that booking. Null for anything the booking surfaces exclude (queue-owned,
     * Retired, Duplicate, converted-without-an-opportunity, deleted): the seed is a convenience
     * and the picker's own search remains the fallback. cacheable=false: staleness here books
     * against the wrong state.
     */
    @AuraEnabled(cacheable=false)
    public static CustomerDTO leadRowById(Id leadId) {
        if (leadId == null) {
            return null;
        }
        List<Lead> leads = [
            SELECT Id, OwnerId, Name, Company, Email, Phone, MobilePhone, Status,
                   ProjectInterest__c, Nationality__c, UAEResidentStatus__c,
                   EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c,
                   PassportIssueDate__c, PassportExpiryDate__c,
                   UnifiedNumber__c, Trade_License_Number__c, TradeName__c,
                   IsConverted, ConvertedOpportunityId
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leads.isEmpty()) {
            return null;
        }
        Lead l = leads[0];
        if (l.IsConverted) {
            if (l.ConvertedOpportunityId == null) {
                return null;
            }
            CustomerDTO existing = new CustomerDTO();
            existing.id = l.ConvertedOpportunityId;
            existing.leadId = l.Id;
            existing.name = l.Name;
            existing.kind = 'Customer';
            return existing;
        }
        /* the same exclusions findByIdentity and findByContact apply */
        if (String.valueOf(l.OwnerId).startsWith('00G')
            || l.Status == 'Retired'
            || l.Status == 'Duplicate') {
            return null;
        }
        /* an organisation lead carries Company AND TradeName__c (the Trade_Details_Are_Mandatory
           shape). Company alone is not enough: integrations stuff junk into it on person leads
           ("Individual Customer", "AI Generated Lead"). matchedOn null - nothing was searched. */
        return leadRow(l, String.isNotBlank(l.Company) && String.isNotBlank(l.TradeName__c), null);
    }

    /**
     * Search by email and mobile, the fields MODON actually populates. Encrypted twins cannot be
     * filtered in SOQL, so only the plain fields are searched. Same rows and builders as
     * findByIdentity.
     */
    @AuraEnabled(cacheable=false)
    public static List<CustomerDTO> findByContact(String customerType, String term) {
        List<CustomerDTO> out = new List<CustomerDTO>();
        String t = String.isBlank(term) ? null : term.trim();
        if (t == null) {
            return out;
        }
        Boolean isOrg = isOrganisationType(customerType);
        Boolean byEmail = t.contains('@');
        Set<String> variants = byEmail ? new Set<String>() : phoneVariants(t);
        /* too short to be an honest search key */
        if (!byEmail && variants.isEmpty()) {
            return out;
        }

        // accounts
        /* 1.34: every customer, whoever owns it (MatchLookup, without sharing) */
        MatchLookup lookup = new MatchLookup();
        List<Account> accounts;
        if (isOrg) {
            accounts = byEmail ? lookup.companiesByEmail(t) : lookup.companiesByPhone(variants);
        } else {
            accounts = byEmail ? lookup.peopleByEmail(t) : lookup.peopleByMobile(variants);
        }
        /* a company row travels with its signatories */
        Map<Id, List<SignatoryDTO>> signatoriesByAccount =
            isOrg ? signatoriesFor(new Map<Id, Account>(accounts).keySet())
                  : new Map<Id, List<SignatoryDTO>>();
        String code = byEmail ? 'email' : 'mobile';
        for (Account a : accounts) {
            out.add(accountRow(a, isOrg, code, null, signatoriesByAccount));
        }

        // open leads
        /* Email OR MobilePhone OR Phone: older console leads hold the mobile in Phone alone.
           LIMIT 50 because the queue filter runs after. */
        List<Lead> leads = byEmail
            ? [
                SELECT Id, OwnerId, Name, Company, Email, Phone, MobilePhone, Status,
                       ProjectInterest__c, Nationality__c, UAEResidentStatus__c,
                       EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c,
                       PassportIssueDate__c, PassportExpiryDate__c,
                       UnifiedNumber__c, Trade_License_Number__c
                FROM Lead
                WHERE Email = :t
                  AND IsConverted = FALSE
                  // closed leads leave the booking surfaces
                  AND Status NOT IN ('Retired', 'Duplicate')
                ORDER BY CreatedDate DESC
                LIMIT 50
            ]
            : [
                SELECT Id, OwnerId, Name, Company, Email, Phone, MobilePhone, Status,
                       ProjectInterest__c, Nationality__c, UAEResidentStatus__c,
                       EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c,
                       PassportIssueDate__c, PassportExpiryDate__c,
                       UnifiedNumber__c, Trade_License_Number__c
                FROM Lead
                WHERE (MobilePhone IN :variants OR Phone IN :variants)
                  AND IsConverted = FALSE
                  // closed leads leave the booking surfaces
                  AND Status NOT IN ('Retired', 'Duplicate')
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        for (Lead l : leads) {
            if (String.valueOf(l.OwnerId).startsWith('00G')) {
                continue;
            }
            /* a lead without a Company is a person lead */
            Boolean isCompanyLead = String.isNotBlank(l.Company);
            if (isOrg != isCompanyLead) {
                continue;
            }
            out.add(leadRow(l, isOrg, code));
        }
        return out;
    }

    /**
     * The UAE spellings of one phone number (+971..., 0..., 00971...), matched exactly. Empty set
     * for anything too short, and the caller skips the query rather than binding an empty set.
     */
    @TestVisible
    private static Set<String> phoneVariants(String raw) {
        Set<String> variants = new Set<String>();
        if (String.isBlank(raw)) {
            return variants;
        }
        String s = raw.trim().replaceAll('[\\s\\-().\\[\\]]', '');
        /* fewer than 7 digits is a fragment */
        if (s.replaceAll('[^0-9]', '').length() < 7) {
            return variants;
        }
        variants.add(raw.trim());
        variants.add(s);
        if (s.startsWith('00')) {
            variants.add('+' + s.substring(2));
        } else if (s.startsWith('+971') && s.length() > 4) {
            variants.add('0' + s.substring(4));
            variants.add('00971' + s.substring(4));
        } else if (s.startsWith('971') && s.length() > 3) {
            variants.add('+' + s);
            variants.add('0' + s.substring(3));
        } else if (s.startsWith('0')) {
            variants.add('+971' + s.substring(1));
            variants.add('971' + s.substring(1));
        }
        return variants;
    }

    /**
     * MSC-172. A document as the org might have stored it: the raw trimmed value and the one with
     * separators stripped (spaces, hyphens, dots, slashes). Nothing else: a wrong match attaches a
     * booking to a stranger. Widening only.
     */
    private static Set<String> docVariants(String raw) {
        Set<String> variants = new Set<String>();
        if (String.isBlank(raw)) {
            return variants;
        }
        String t = raw.trim();
        variants.add(t);
        String stripped = t.replaceAll('[\\s\\-./\\\\]', '');
        if (String.isNotBlank(stripped)) {
            variants.add(stripped);
        }
        /* both directions: SOQL cannot strip the stored side, and most Emirates IDs are stored with
           separators, so the 3-4-7-1 form is rebuilt from fifteen digits. EID only; a passport or
           licence has no canonical grouping. */
        if (stripped.length() == 15 && stripped.isNumeric()) {
            variants.add(
                stripped.substring(0, 3) + '-' + stripped.substring(3, 7) + '-'
                + stripped.substring(7, 14) + '-' + stripped.substring(14)
            );
        }
        return variants;
    }

    /** The bind for a document set, with the NO_MATCH sentinel for a blank input. */
    private static Set<String> docBind(String raw) {
        Set<String> variants = docVariants(raw);
        if (variants.isEmpty()) {
            variants.add(NO_MATCH);
        }
        return variants;
    }

    /**
     * MSC-172. Did this stored value match what the rep typed, answered the way the query answered
     * it: case-insensitive, both sides stripped. Names the match for the chip; never decides one.
     */
    private static Boolean docMatches(String raw, String stored) {
        if (String.isBlank(raw) || String.isBlank(stored)) {
            return false;
        }
        Set<String> wanted = new Set<String>();
        for (String v : docVariants(raw)) {
            wanted.add(v.toUpperCase());
        }
        for (String v : docVariants(stored)) {
            if (wanted.contains(v.toUpperCase())) {
                return true;
            }
        }
        return false;
    }

    /**
     * The people who could sign for these companies, one query for all. Oldest first: the
     * longest-standing contact is the likeliest signatory.
     */
    private static Map<Id, List<SignatoryDTO>> signatoriesFor(Set<Id> accountIds) {
        Map<Id, List<SignatoryDTO>> byAccount = new Map<Id, List<SignatoryDTO>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return byAccount;
        }
        /* 1.34: without sharing, as the company they sign for was found */
        for (Contact c : new MatchLookup().signatoriesOf(accountIds)) {
            SignatoryDTO s = new SignatoryDTO();
            s.contactId = c.Id;
            s.name = c.Name;
            s.firstName = c.FirstName;
            s.lastName = c.LastName;
            s.email = c.Email;
            s.phone = String.isNotBlank(c.MobilePhone) ? c.MobilePhone : c.Phone;
            s.title = c.Title;
            if (!byAccount.containsKey(c.AccountId)) {
                byAccount.put(c.AccountId, new List<SignatoryDTO>());
            }
            byAccount.get(c.AccountId).add(s);
        }
        return byAccount;
    }

    /** Which of the three licence fields the rep's number matched; falls back to whichever is populated. */
    private static String matchedLicence(Account a, String doc) {
        if (a == null) {
            return null;
        }
        if (doc != null) {
            /* docMatches, so the number shown is the one that matched */
            if (docMatches(doc, a.UnifiedNumber__c)) { return a.UnifiedNumber__c; }
            if (docMatches(doc, a.TradeLicenseNumber__c)) { return a.TradeLicenseNumber__c; }
            if (docMatches(doc, a.Trade_License_Number__c)) { return a.Trade_License_Number__c; }
        }
        if (String.isNotBlank(a.UnifiedNumber__c)) { return a.UnifiedNumber__c; }
        if (String.isNotBlank(a.TradeLicenseNumber__c)) { return a.TradeLicenseNumber__c; }
        return a.Trade_License_Number__c;
    }


    /**
     * Book for a customer the org already has: raise a lead from their own details and convert it
     * into their existing account. The rep's own open opportunity for the same project (with no
     * Sales Order) is reused; otherwise a fresh one. Unused parameters kept for the call site.
     */
    @AuraEnabled
    public static NewCustomerDTO bookForExistingCustomer(
        Id accountId,
        String firstName,
        String lastName,
        String phone,
        String email,
        String projectInterest,
        String nationality,
        String residentStatus,
        String eidNumber,
        String passportNumber,
        String customerType,
        String companyName,
        Date passportIssueDate,
        String tradeLicence,
        /** The signatory the rep chose. Null means conversion creates one. Ignored for a Person Account. */
        Id signatoryContactId,
        /* the two dates, fallback only; the stored value wins whenever the org would accept it */
        Date eidExpiry,
        Date passportExpiry,
        /* optional; stamped fill-only */
        Date birthdate,
        /* MSC-139. see createCustomer. Organisation only. */
        String isAuthorisedSignatory
    ) {
        if (accountId == null) {
            throw new AuraHandledException('No customer was supplied.');
        }

        /* resolved and re-checked first; everything below is built from it */
        Contact signatory = resolveSignatory(accountId, signatoryContactId);

        /* the lead carries the signatory's own details, read off the Contact, so conversion's
           write-back is a no-op (mscConsole sends the company name for a company match) */
        String leadFirst = firstName;
        String leadLast = lastName;
        String leadEmail = email;
        String leadPhone = phone;
        String leadNationality = nationality;
        /* set when the signatory had no first name and a placeholder is used; repaired after convert */
        Boolean firstNameWasBlank = false;
        if (signatory != null) {
            leadLast = signatory.LastName;
            leadEmail = signatory.Email;
            leadPhone = String.isNotBlank(signatory.MobilePhone)
                ? signatory.MobilePhone
                : signatory.Phone;
            leadNationality = signatory.Nationality__c;
            /* no fallback to the client's values: a borrowed value overwrites on conversion */
            firstNameWasBlank = String.isBlank(signatory.FirstName);
            /* except here: First_Name_Mandatory_Check needs a value; put back below */
            leadFirst = firstNameWasBlank ? signatory.LastName : signatory.FirstName;
        }

        /* book onto the rep's own open opportunity for this project; see reusableOpportunity */
        Id reusable = reusableOpportunity(accountId, projectInterest);
        if (reusable != null) {
            /* this path converts nothing, so set PrimaryContact__c here, fill-only */
            if (signatory != null) {
                pointOpportunityAtSignatory(reusable, signatory.Id);
                // MSC-139. the reuse path's only chance
                linkPowerOfAttorney(accountId, signatory.Id, isAuthorisedSignatory);
            }
            /* fill-only; the reuse path converts nothing */
            stampBirthdate(accountId, birthdate);
            NewCustomerDTO existing = new NewCustomerDTO();
            existing.opportunityId = reusable;
            existing.name = (String.isBlank(leadFirst) ? '' : leadFirst.trim() + ' ')
                + (leadLast == null ? '' : leadLast.trim());
            return existing;
        }
        /* the documents come off the record the booking converges on, used only when the org
           would accept them; the client's values fill what is missing or unusable */
        IdentityRecord onFile = readIdentityRecord(accountId, signatory);
        String leadResident = String.isNotBlank(onFile.residentStatus)
            ? onFile.residentStatus
            : residentStatus;
        String leadEid = String.isNotBlank(onFile.eidNumber)
            ? onFile.eidNumber
            : eidNumber;
        Date leadEidExpiry = usableExpiry(onFile.eidExpiry)
            ? onFile.eidExpiry
            : eidExpiry;
        String leadPassportNo = String.isNotBlank(onFile.passportNumber)
            ? onFile.passportNumber
            : passportNumber;
        Date leadPassportIssue = usableIssue(onFile.passportIssueDate)
            ? onFile.passportIssueDate
            : passportIssueDate;
        Date leadPassportExpiry = usableExpiry(onFile.passportExpiryDate)
            ? onFile.passportExpiryDate
            : passportExpiry;

        /* MSC-162. A stored document the org would refuse (Passport_Number_Format_Check,
           Emirates_Id_Number_Format) and this residency does not require is not put on the Lead.
           Both conditions required; a required document is never dropped. */
        IdentityNeedDTO leadNeeds = identityNeedsFor(leadResident);
        /* 1.30: "require" is the owed flag now */
        if (!leadNeeds.passportNumberRequired && !storablePassport(leadPassportNo)) {
            leadPassportNo = null;
        }
        if (!leadNeeds.eidNumberRequired && !storableEid(leadEid)) {
            leadEid = null;
        }

        /* accountId: the rep chose this customer, so duplicate review stands down */
        Id leadId = createLeadFull(
            leadFirst, leadLast, leadPhone, leadEmail, projectInterest,
            leadNationality, leadResident, leadEid, leadPassportNo,
            customerType, companyName, leadPassportIssue, tradeLicence, accountId,
            leadEidExpiry, leadPassportExpiry, birthdate
        );

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(convertedLeadStatus());
        lc.setDoNotCreateOpportunity(false);
        lc.setOwnerId(UserInfo.getUserId());
        // converge on the account we already matched
        convergeOnAccount(lc, accountId, signatory == null ? null : signatory.Id);

        Database.LeadConvertResult result;
        try {
            /* 1.34: onto the chosen customer whoever owns it (OntoFoundCustomer) */
            result = convertLead(lc);
        } catch (Exception e) {
            throw new AuraHandledException(
                'The booking could not be started for that customer: ' + e.getMessage()
            );
        }
        if (result == null || !result.isSuccess()) {
            List<String> messages = new List<String>();
            if (result != null) {
                for (Database.Error err : result.getErrors()) {
                    messages.add(err.getMessage());
                }
            }
            throw new AuraHandledException(
                'The booking could not be started for that customer: '
                    + (messages.isEmpty() ? 'conversion was rejected.' : String.join(messages, ' '))
            );
        }

        /* put back what the placeholder overwrote ("Sanju" became "Sanju Sanju") */
        if (signatory != null && firstNameWasBlank) {
            try {
                update new Contact(Id = signatory.Id, FirstName = null);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    'Could not restore the blank first name on contact ' + signatory.Id
                    + '. ' + e.getMessage());
            }
        }

        /* fill-only */
        stampBirthdate(accountId, birthdate);

        NewCustomerDTO dto = new NewCustomerDTO();
        dto.leadId = leadId;
        dto.opportunityId = result.getOpportunityId();
        /* the signatory's name, not the company's */
        dto.name = (String.isBlank(leadFirst) ? '' : leadFirst.trim() + ' ') + leadLast.trim();
        return dto;
    }

    /**
     * The rep's own open opportunity for this buyer and project, or null. Same owner, same
     * project, no Sales Order.
     */
    private static Id reusableOpportunity(Id accountId, String projectInterest) {
        // a blank project cannot be matched safely
        if (accountId == null || String.isBlank(projectInterest)) {
            return null;
        }
        List<Opportunity> open = [
            SELECT Id
            FROM Opportunity
            WHERE AccountId = :accountId
            AND OwnerId = :UserInfo.getUserId()
            AND IsClosed = FALSE
            AND ProjectInterest__c = :projectInterest
            AND Id NOT IN (
                SELECT Opportunity__c FROM SalesOrder__c WHERE Opportunity__c != NULL
            )
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return open.isEmpty() ? null : open[0].Id;
    }

    /* the strongest match: documents do not change over a lifetime */
    /**
     * Converge a lead onto an existing account. A Person Account needs its PersonContactId passed
     * too, or conversion fails with "invalid cross reference id". Business accounts take a new contact.
     */
    /** Set by tryConvert so the rep is told why. TestVisible: the diagnosis needs the StatusCode. */
    @TestVisible
    private static String lastConvertError = '';

    /**
     * Null on any failure rather than throwing. convertLead both throws and returns errors, so both
     * are caught.
     */
    private static Database.LeadConvertResult tryConvert(Database.LeadConvert lc) {
        String failure;
        try {
            /* 1.34: onto a found customer through OntoFoundCustomer (without sharing) */
            Database.LeadConvertResult r = convertLead(lc);
            if (r != null && r.isSuccess()) {
                return r;
            }
            List<String> messages = new List<String>();
            if (r != null) {
                for (Database.Error err : r.getErrors()) {
                    messages.add(err.getStatusCode() + ': ' + err.getMessage()
                        + (err.getFields() == null || err.getFields().isEmpty()
                            ? '' : ' [' + String.join(err.getFields(), ',') + ']'));
                }
            }
            failure = messages.isEmpty()
                ? 'Conversion was rejected.'
                : String.join(messages, ' ');
        } catch (Exception e) {
            failure = e.getTypeName() + ': ' + e.getMessage();
        }
        /* appended: createCustomer makes up to two attempts */
        lastConvertError = String.isBlank(lastConvertError)
            ? failure
            : lastConvertError + ' | ' + failure;
        return null;
    }

    /**
     * 1.34. Every conversion goes through here. Onto an existing customer it runs without sharing
     * (OntoFoundCustomer), as the rep may have no access to it; a new customer converts with sharing.
     */
    private static Database.LeadConvertResult convertLead(Database.LeadConvert lc) {
        if (lc.getAccountId() != null) {
            return new OntoFoundCustomer().convert(lc);
        }
        return Database.convertLead(lc, false);
    }

    /**
     * What actually happened, in words a rep can act on. The usual cause: Modon's Lead automation
     * routed the lead to the Duplicate Queue, which cannot be converted ("invalid cross reference
     * id") and the rep cannot take it back out. Read back rather than assumed.
     */
    private static String explainConversionFailure(Id leadId) {
        for (Lead l : [SELECT Id, OwnerId, Owner.Name FROM Lead WHERE Id = :leadId LIMIT 1]) {
            // 00G is a Group: on a Lead owner that means a queue
            if (String.valueOf(l.OwnerId).startsWith('00G')) {
                return 'This buyer already exists in Modon\'s records, so the new lead '
                    + 'was routed to "' + l.Owner.Name + '" for review and cannot be '
                    + 'qualified from here. Search their Emirates ID or passport again '
                    + 'and book against the existing customer instead.';
            }
        }
        /* the identity rules' own messages, translated */
        String friendly = friendlyIdentitySentence(lastConvertError);
        if (friendly != null) {
            return friendly;
        }
        return 'The customer could not be created. ' + lastConvertError;
    }

    /** Matched on fragments of the rule messages; null for anything unrecognised. */
    private static String friendlyIdentitySentence(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String probe = raw.toLowerCase();
        if (probe.contains('emirates id expiry date field is mandatory')) {
            return 'Modon requires the Emirates ID expiry date for a UAE resident. '
                + 'Add it and try again.';
        }
        if (probe.contains('emirates id number field is mandatory')) {
            return 'Modon requires an Emirates ID for a UAE resident. '
                + 'Add it and try again.';
        }
        if (probe.contains('passport issue date field is mandatory')) {
            return 'Modon requires the passport issue date for a non-resident. '
                + 'Add it and try again.';
        }
        if (probe.contains('passport expiry date field is mandatory')) {
            return 'Modon requires the passport expiry date for a non-resident. '
                + 'Add it and try again.';
        }
        if (probe.contains('emirates id expiry date cannot be a past date')) {
            return 'The Emirates ID expiry date on file has passed. '
                + 'Enter the renewed date and try again.';
        }
        if (probe.contains('passport expiry date cannot be a past date')) {
            return 'The passport expiry date on file has passed. '
                + 'Enter the renewed date and try again.';
        }
        if (probe.contains('passport issue date cannot be a future date')) {
            return 'The passport issue date cannot be in the future. '
                + 'Correct it and try again.';
        }
        if (probe.contains('cannot contain numbers or special characters')) {
            return 'The customer\'s first and last name can only contain letters. '
                + 'Correct the name and try again.';
        }
        return null;
    }

    private static void convergeOnAccount(Database.LeadConvert lc, Id accountId) {
        convergeOnAccount(lc, accountId, null);
    }

    /**
     * A business account converges on the chosen signatory too (otherwise an invented Contact
     * becomes PrimaryContact__c, the SPA signer and the Passfort entity). Honoured only after
     * resolveSignatory proved it belongs to this account; the Person Account branch still wins.
     */
    private static void convergeOnAccount(
        Database.LeadConvert lc,
        Id accountId,
        Id signatoryContactId
    ) {
        if (accountId == null) {
            return;
        }
        lc.setAccountId(accountId);
        /* 1.34: without sharing; unread, a person account would convert without its contact */
        for (Account a : new MatchLookup().identityOf(accountId)) {
            if (a.IsPersonAccount && a.PersonContactId != null) {
                lc.setContactId(a.PersonContactId);
            } else if (!a.IsPersonAccount && signatoryContactId != null) {
                lc.setContactId(signatoryContactId);
            }
        }
    }

    /**
     * Point a reused opportunity at the signatory when it has nobody (the reuse path never fires
     * Auto_Populate_Primary_Contact_Opportunity). Fill-only, written directly, not fatal.
     */
    private static void pointOpportunityAtSignatory(Id opportunityId, Id contactId) {
        if (opportunityId == null || contactId == null) {
            return;
        }
        for (Opportunity o : [
            SELECT Id, PrimaryContact__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ]) {
            if (o.PrimaryContact__c != null) {
                return;
            }
            try {
                update new Opportunity(Id = o.Id, PrimaryContact__c = contactId);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    'Could not point opportunity ' + opportunityId + ' at contact '
                    + contactId + '. ' + e.getMessage());
            }
        }
    }

    /**
     * The signatory this booking attaches to, re-read and re-checked: accepted only when it is a
     * child of this account. Null means let conversion create one.
     */
    private static Contact resolveSignatory(Id accountId, Id signatoryContactId) {
        if (accountId == null || signatoryContactId == null) {
            return null;
        }
        /* identity fields ride along for readIdentityRecord. 1.34: without sharing, as the
           company was found by the search */
        for (Contact c : new MatchLookup().signatoryOf(signatoryContactId, accountId)) {
            return c;
        }
        System.debug(LoggingLevel.WARN,
            'Signatory ' + signatoryContactId + ' does not belong to account ' + accountId
            + '; the booking will fall back to creating a contact.');
        return null;
    }

    /**
     * The company that already holds this licence, or null. A sibling of matchAccountByDocument
     * because an organisation search needs IsPersonAccount = false and the record-type exclusion.
     */
    /* public for SalesConsoleJointOwnerService; visibility only */
    public static Id matchOrganisationAccount(String tradeLicence) {
        if (String.isBlank(tradeLicence)) {
            return null;
        }
        String licence = tradeLicence.trim();
        /* 1.34: every company, whoever owns it, as the Sales App's findMatchingOrgAccount */
        List<Account> matched = new MatchLookup().companiesByExactLicence(licence);
        if (matched.isEmpty()) {
            return null;
        }
        if (matched.size() > 1) {
            /* reported, not resolved: some unified numbers are held by two companies */
            System.debug(LoggingLevel.WARN,
                'matchOrganisationAccount: licence ' + licence + ' matches more than one '
                + 'company; converging on ' + matched[0].Name + ' (' + matched[0].Id + ').');
        }
        return matched[0].Id;
    }

    /* MSC-080. public for SalesConsoleJointOwnerService; nothing else changed */
    public static Id matchAccountByDocument(
        String eidNumber,
        String passportNumber,
        String tradeLicence
    ) {
        /* NO_MATCH, not null: `field = :nullBind` matches every row where the field is null */
        if (String.isBlank(eidNumber) && String.isBlank(passportNumber)
                && String.isBlank(tradeLicence)) {
            return null;
        }
        /* MSC-172. separator variants and UnifiedNumber__c, as matchCandidates */
        Set<String> eids = docBind(eidNumber);
        Set<String> passes = docBind(passportNumber);
        Set<String> tls = docBind(tradeLicence);

        /* 1.34: every account, whoever owns it (MatchLookup, without sharing) */
        List<Account> matched = new MatchLookup().anyByDocument(eids, passes, tls, 2);
        if (matched.isEmpty()) {
            return null;
        }
        /* two accounts sharing a document is a data problem; returns the newest but logs it */
        if (matched.size() > 1) {
            System.debug(LoggingLevel.WARN,
                'matchAccountByDocument: more than one account holds this document - '
                + 'using ' + matched[0].Name + ' (' + matched[0].Id + ').');
        }
        return matched[0].Id;
    }

    /**
     * All the accounts a buyer's details match, for the rep to choose from. Two tiers, the first
     * absolute: a document match is never widened to email/phone. The document WHERE mirrors
     * matchAccountByDocument (a frozen public contract); a test pins the two together. The
     * email/phone tier matches the mobile across its UAE spellings.
     * 1.33: only a company lead's conversion uses this now; a person goes through personMatches.
     */
    @TestVisible
    private static List<Account> matchCandidates(
        String eidNumber,
        String passportNumber,
        String tradeLicence,
        String email,
        String phone
    ) {
        /* MSC-172. Sets, not single strings, and UnifiedNumber__c in the OR. Pure widening. */
        Set<String> eids = docBind(eidNumber);
        Set<String> passes = docBind(passportNumber);
        Set<String> tls = docBind(tradeLicence);

        if (String.isNotBlank(eidNumber) || String.isNotBlank(passportNumber)
                || String.isNotBlank(tradeLicence)) {
            /* 1.34: every account, whoever owns it (MatchLookup, without sharing) */
            List<Account> byDocument = new MatchLookup().rowsByDocument(eids, passes, tls);
            if (!byDocument.isEmpty()) {
                return byDocument;
            }
        }

        if (String.isBlank(email) && String.isBlank(phone)) {
            return new List<Account>();
        }
        String e = String.isBlank(email) ? NO_MATCH : email.trim();
        Set<String> phones = phoneVariants(phone);
        if (phones.isEmpty()) {
            /* the sentinel keeps the shape identical to every other matcher */
            phones.add(NO_MATCH);
        }
        return new MatchLookup().rowsByContact(e, phones);
    }

    /* 1.33: ten rows as the Sales App; more are fetched so the strongest are ranked first */
    private static final Integer PERSON_MATCH_ROWS = 10;
    private static final Integer PERSON_MATCH_FETCH = 200;

    /**
     * 1.33. The Emirates ID a person match searches: only for a Resident, as the Sales App. A blank
     * residency keeps it as a key, since a missed match makes a duplicate account. Null when not a key.
     */
    private static String countedEid(String eidNumber, String residentStatus) {
        if (String.isBlank(eidNumber)) {
            return null;
        }
        if (String.isBlank(residentStatus) || residentStatus.trim().equalsIgnoreCase('Resident')) {
            return eidNumber;
        }
        return null;
    }

    /**
     * 1.33. The spellings a mobile is searched in: the Sales App's five UAE forms (normalisePhone,
     * phoneSearchVariants) plus phoneVariants, so a number held abroad (+91...) still matches.
     */
    @TestVisible
    private static Set<String> personMatchPhones(String raw) {
        Set<String> variants = new Set<String>();
        if (String.isBlank(raw)) {
            return variants;
        }
        String core = raw.replaceAll('[^0-9]', '');
        if (core.startsWith('00971') && core.length() > 11) {
            core = core.substring(5);
        } else if (core.startsWith('971') && core.length() > 9) {
            core = core.substring(3);
        }
        if (core.startsWith('0') && core.length() > 1) {
            core = core.substring(1);
        }
        if (String.isNotBlank(core)) {
            variants.add(core);
            variants.add('0' + core);
            variants.add('971' + core);
            variants.add('+971' + core);
            variants.add('00971' + core);
        }
        variants.addAll(phoneVariants(raw));
        return variants;
    }

    /**
     * 1.33. Every person account these details match, as ConvertLeadProcessMRE.findMatchingPersonAccounts:
     * one search on email, mobile, passport or countedEid, merged accounts left out. 1.34: without
     * sharing (MatchLookup). At most ten, ranked Emirates ID, passport, email, mobile, newest first.
     */
    @TestVisible
    private static List<Account> personMatches(
        String eidNumber,
        String passportNumber,
        String email,
        String phone,
        String residentStatus
    ) {
        String eid = countedEid(eidNumber, residentStatus);
        Set<String> phones = personMatchPhones(phone);
        if (String.isBlank(eid) && String.isBlank(passportNumber)
                && String.isBlank(email) && phones.isEmpty()) {
            return new List<Account>();
        }
        Set<String> eids = docBind(eid);
        Set<String> passes = docBind(passportNumber);
        /* the Sales App's email key: trimmed, lower case (SOQL compares without case anyway) */
        Set<String> emails = new Set<String>{
            String.isBlank(email) ? NO_MATCH : email.trim().toLowerCase()
        };
        if (phones.isEmpty()) {
            phones.add(NO_MATCH);
        }
        /* 1.34: every person account, whoever owns it, as the Sales App's MatchLookup */
        List<Account> found = new MatchLookup().people(eids, passes, emails, phones, PERSON_MATCH_FETCH);

        /* ranked by the chip's own answer, so the first row is the strongest match */
        List<List<Account>> byKey = new List<List<Account>>{
            new List<Account>(), new List<Account>(), new List<Account>(), new List<Account>()
        };
        for (Account a : found) {
            String key = accountMatchedOn(a, eid, passportNumber, null, email, phone);
            Integer rank = key == 'eid' ? 0 : key == 'passport' ? 1 : key == 'email' ? 2 : 3;
            byKey[rank].add(a);
        }
        List<Account> out = new List<Account>();
        for (List<Account> sameKey : byKey) {
            for (Account a : sameKey) {
                if (out.size() == PERSON_MATCH_ROWS) {
                    return out;
                }
                out.add(a);
            }
        }
        return out;
    }

    /**
     * Which field of this account matched, as the chip code. Document outranks licence, licence
     * outranks mailbox. equalsIgnoreCase for the email.
     */
    private static String accountMatchedOn(
        Account a,
        String eidNumber, String passportNumber, String tradeLicence,
        String email, String phone
    ) {
        /* MSC-172. through docVariants, so the label agrees with the match */
        if (docMatches(eidNumber, a.EIDNumber__pc)) {
            return 'eid';
        }
        if (docMatches(passportNumber, a.PassportNumber__pc)) {
            return 'passport';
        }
        if (String.isNotBlank(tradeLicence)) {
            if (docMatches(tradeLicence, a.UnifiedNumber__c)) {
                return 'unified';
            }
            if (docMatches(tradeLicence, a.TradeLicenseNumber__c)
                    || docMatches(tradeLicence, a.Trade_License_Number__c)) {
                return 'licence';
            }
        }
        if (String.isNotBlank(email) && email.trim().equalsIgnoreCase(a.PersonEmail)) {
            return 'email';
        }
        return 'mobile';
    }

    /** The candidate accounts as rows, through the same accountRow every result goes through. */
    private static List<CustomerDTO> toCandidateDtos(
        List<Account> candidates,
        String eidNumber, String passportNumber, String tradeLicence,
        String email, String phone
    ) {
        List<CustomerDTO> out = new List<CustomerDTO>();
        for (Account a : candidates) {
            out.add(accountRow(
                a,
                a.IsPersonAccount != true,
                accountMatchedOn(a, eidNumber, passportNumber, tradeLicence, email, phone),
                null,
                null
            ));
        }
        return out;
    }

    /**
     * Delegates to matchCandidates and answers only when unambiguous: null on zero matches and on
     * more than one.
     */
    /* MSC-172. public for SalesConsoleJointOwnerService, whose null-on-ambiguous need this is. Body unchanged.
       1.33: through personMatches, with no documents */
    @TestVisible
    public static Id matchPersonAccount(String email, String phone) {
        List<Account> matched = personMatches(null, null, email, phone, null);
        return matched.size() == 1 ? matched[0].Id : null;
    }

    /**
     * 1.32: every account a person's details match, exactly as the buyer's chooser finds them
     * (matchCandidates with no trade licence). For SalesConsoleJointOwnerService, so a joint owner is
     * matched by the same rule as a buyer. Visibility only.
     * 1.33: personMatches with no residency, so a given Emirates ID is searched (countedEid).
     */
    public static List<Account> matchPersonCandidates(
        String eidNumber, String passportNumber, String email, String phone
    ) {
        return personMatches(eidNumber, passportNumber, email, phone, null);
    }

    /** 1.32: the chip code for one of those accounts (eid, passport, email or mobile). Visibility only. */
    public static String matchedOnFor(
        Account a, String eidNumber, String passportNumber, String email, String phone
    ) {
        return accountMatchedOn(a, eidNumber, passportNumber, null, email, phone);
    }
    /**
     * 1.34. The customer search without sharing, as the Sales App's ConvertLeadProcessMRE.MatchLookup,
     * so every rep finds every customer and none is created twice. Reads only; leads, opportunities
     * and every write stay with sharing in the outer class.
     */
    private without sharing class MatchLookup {

        /* findByIdentity, company: the three licence fields */
        List<Account> companiesByLicence(Set<String> docs) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE (TradeLicenseNumber__c IN :docs
                    OR Trade_License_Number__c IN :docs
                    OR UnifiedNumber__c IN :docs)
                  AND IsPersonAccount = FALSE
                  AND Is_Merged__c = FALSE
                  AND RecordType.DeveloperName NOT IN :NON_CUSTOMER_ORG_RECORD_TYPES
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
        }

        /* findByIdentity, person: both documents */
        List<Account> peopleByDocument(Set<String> docs) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE (EIDNumber__pc IN :docs OR PassportNumber__pc IN :docs)
                  AND Is_Merged__c = FALSE
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }

        /* findByContact, company email */
        List<Account> companiesByEmail(String t) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE Company_Email_Address__c = :t
                  AND IsPersonAccount = FALSE
                  AND Is_Merged__c = FALSE
                  AND RecordType.DeveloperName NOT IN :NON_CUSTOMER_ORG_RECORD_TYPES
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        }

        /* findByContact, company phone */
        List<Account> companiesByPhone(Set<String> variants) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE Phone IN :variants
                  AND IsPersonAccount = FALSE
                  AND Is_Merged__c = FALSE
                  AND RecordType.DeveloperName NOT IN :NON_CUSTOMER_ORG_RECORD_TYPES
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        }

        /* findByContact, person email */
        List<Account> peopleByEmail(String t) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE PersonEmail = :t
                  AND IsPersonAccount = TRUE
                  AND Is_Merged__c = FALSE
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        }

        /* findByContact, person mobile */
        List<Account> peopleByMobile(Set<String> variants) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE PersonMobilePhone IN :variants
                  AND IsPersonAccount = TRUE
                  AND Is_Merged__c = FALSE
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        }

        /* signatoriesFor: who can sign for the companies found, oldest first */
        List<Contact> signatoriesOf(Set<Id> accountIds) {
            return [
                SELECT Id, AccountId, FirstName, LastName, Name, Email, MobilePhone, Phone, Title
                FROM Contact
                WHERE AccountId IN :accountIds
                ORDER BY CreatedDate ASC
                LIMIT 200
            ];
        }

        /* readIdentityRecord and convergeOnAccount: the chosen customer's identity and person contact */
        List<Account> identityOf(Id accountId) {
            return [
                SELECT Id, IsPersonAccount, PersonContactId,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc,
                       PassportNumber__pc, PassportIssueDate__pc, PassportExpiryDate__pc,
                       UAE_Resident_Status__pc, Nationality__pc
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
        }

        /* resolveSignatory: accepted only as a child of this account */
        List<Contact> signatoryOf(Id contactId, Id accountId) {
            return [
                SELECT Id, AccountId, FirstName, LastName, Email, MobilePhone, Phone,
                       Nationality__c, UAE_Resident_Status__c,
                       EIDNumber__c, EmiratesIDExpiryDate__c,
                       PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c
                FROM Contact
                WHERE Id = :contactId
                  AND AccountId = :accountId
                LIMIT 1
            ];
        }

        /* matchOrganisationAccount */
        List<Account> companiesByExactLicence(String licence) {
            return [
                SELECT Id, Name
                FROM Account
                WHERE (TradeLicenseNumber__c = :licence
                    OR Trade_License_Number__c = :licence
                    OR UnifiedNumber__c = :licence)
                  AND IsPersonAccount = FALSE
                  AND Is_Merged__c = FALSE
                  AND RecordType.DeveloperName NOT IN :NON_CUSTOMER_ORG_RECORD_TYPES
                ORDER BY CreatedDate DESC
                LIMIT 2
            ];
        }

        /* matchAccountByDocument (a frozen contract: same WHERE as before) */
        List<Account> anyByDocument(Set<String> eids, Set<String> passes, Set<String> tls, Integer rows) {
            return [
                SELECT Id, Name
                FROM Account
                WHERE (EIDNumber__pc IN :eids
                       OR PassportNumber__pc IN :passes
                       OR TradeLicenseNumber__c IN :tls
                       OR Trade_License_Number__c IN :tls
                       OR UnifiedNumber__c IN :tls)
                  AND Is_Merged__c = FALSE
                ORDER BY CreatedDate DESC
                LIMIT :rows
            ];
        }

        /* matchCandidates, first tier: the documents (mirrors matchAccountByDocument) */
        List<Account> rowsByDocument(Set<String> eids, Set<String> passes, Set<String> tls) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE (EIDNumber__pc IN :eids
                       OR PassportNumber__pc IN :passes
                       OR TradeLicenseNumber__c IN :tls
                       OR Trade_License_Number__c IN :tls
                       OR UnifiedNumber__c IN :tls)
                  AND Is_Merged__c = FALSE
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }

        /* matchCandidates, second tier: email or mobile */
        List<Account> rowsByContact(String e, Set<String> phones) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE (PersonEmail = :e OR PersonMobilePhone IN :phones)
                  AND Is_Merged__c = FALSE
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }

        /* personMatches: the Sales App's one search */
        List<Account> people(
            Set<String> eids, Set<String> passes, Set<String> emails, Set<String> phones, Integer rows
        ) {
            return [
                SELECT Id, Name, PersonEmail, PersonMobilePhone, IsPersonAccount,
                       Nationality__pc, UAE_Resident_Status__pc,
                       EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                       PassportIssueDate__pc, PassportExpiryDate__pc,
                       PersonMailingStreet, PersonMailingCity, PersonMailingState,
                       PersonMailingPostalCode, PersonMailingCountry,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c,
                       Company_Email_Address__c, Phone
                FROM Account
                WHERE IsPersonAccount = TRUE
                  AND Is_Merged__c = FALSE
                  AND (EIDNumber__pc IN :eids
                       OR PassportNumber__pc IN :passes
                       OR PersonEmail IN :emails
                       OR PersonMobilePhone IN :phones)
                ORDER BY CreatedDate DESC
                LIMIT :rows
            ];
        }
    }

    /**
     * 1.34. Inserts a lead naming a found customer (Existing_Account__c) and converts it onto them
     * without sharing, as Salesforce refuses both when the rep has no access to the account
     * (INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY). The lead must be one the rep can edit.
     */
    private without sharing class OntoFoundCustomer {

        private final String NOT_YOUR_LEAD = 'That lead is not yours to qualify.';

        void insertLead(Lead l) {
            insert l;
        }

        Database.LeadConvertResult convert(Database.LeadConvert lc) {
            if (!repCanEdit(lc.getLeadId())) {
                AuraHandledException e = new AuraHandledException(NOT_YOUR_LEAD);
                e.setMessage(NOT_YOUR_LEAD);
                throw e;
            }
            return Database.convertLead(lc, false);
        }

        private Boolean repCanEdit(Id leadId) {
            if (leadId == null) {
                return false;
            }
            for (UserRecordAccess a : [
                SELECT RecordId, HasEditAccess
                FROM UserRecordAccess
                WHERE UserId = :UserInfo.getUserId() AND RecordId = :leadId
                LIMIT 1
            ]) {
                return a.HasEditAccess == true;
            }
            return false;
        }
    }
}