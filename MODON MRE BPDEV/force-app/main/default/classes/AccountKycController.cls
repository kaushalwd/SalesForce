/**********************************************************************************************************************
* Name        : AccountKycController
* Description : Backing controller for the accountKycForm LWC.
*
*               Launch points:
*                 Account (person)  -> updates that Account
*                 Opportunity       -> updates Opportunity.AccountId (person accounts)
*                 Contact           -> updates the Contact AND Contact.AccountId (org account)
*
*               Everything the form renders is driven by the CONFIG block below plus a runtime
*               describe call, so adding or removing a field is a one-line change here and
*               requires no edit to the LWC.
* --------------------------------------------------------------------------------------------------------------------
* Version  Author              Date            Description
* -------  ------------------- --------------- ------------------------------------------------------------------
* 1.0      Arvind Kesharani    14 Jul 2026     Initial draft (AccountAddressController)
* 1.1      Arvind Kesharani    11 Aug 2026     Org billing fields fix
* 1.2      Arvind Kesharani    12 Aug 2026     Added TradeName__c
* 2.0                          29 Aug 2026     Rewrite. Config-driven fields, Contact launch point,
*                                              wrapper-based context resolution, savepoint on multi-object save.
* 2.1                          22 Sep 2026     Source of Income is shown and locked to Salary for the
*                                              employed instead of being hidden. Visibility rule removed;
*                                              AUTO_SET_RULES literals re-applied server side on save.
****************************************************************************************************/
public with sharing class AccountKycController {

    /* ==================================================================================
     *  CONFIG - the only block you edit to change the form
     * ================================================================================== */

    /**
     * Your org contains BOTH Trade_License_Number__c and TradeLicenseNumber__c with the
     * identical label "Trade License Number". Flip this constant if the other one is live.
     */
    private static final String TRADE_LICENCE_FIELD = 'Trade_License_Number__c';

    /* ---- Person Account, grouped into the sections the form renders ---- */

    private static final List<String> PERSON_IDENTITY_FIELDS = new List<String>{
        'Salutation',
        'FirstName',
        'MiddleName',                            // optional - see OPTIONAL_FIELDS
        'LastName',
        'AccountnameArabic__pc',                 // optional - see OPTIONAL_FIELDS
        'PersonBirthdate',
        'PersonGenderIdentity',
        'Nationality__pc',
        'CountryOfResidence__pc',
        'UAE_Resident_Status__pc',               // picklist, writable - drives EID visibility
        'Do_you_hold_dual_nationality__pc',
        'Other_Nationality_If_Applicable__pc',   // shown only when dual nationality = Yes
        'AreYouPoliticallyExposedPersonPEP__pc'  // checkbox - cannot be enforced
        // 'UAEResident__c'   <- formula (Yes/No). Re-add to show it read only.
        // Removed 30 Aug: 'Name' (calculated on person accounts - DML fails),
        //                 'PersonEmail', 'PersonMobilePhone'
    };

    private static final List<String> PERSON_EID_FIELDS = new List<String>{
        'EIDNumber__pc',
        'Emirates_ID_Issue_Date__pc',
        'EmiratesIDExpiryDate__pc',
        'EID_Issue_Emirates__pc',
        'EID_Sponsor__pc'
    };

    private static final List<String> PERSON_PASSPORT_FIELDS = new List<String>{
        'PassportNumber__pc',
        'PassportIssueDate__pc',
        'PassportExpiryDate__pc',
        'PassportIssuancePlace__pc'
    };

    private static final List<String> PERSON_EMPLOYMENT_FIELDS = new List<String>{
        'Employment_Status__pc',
        'Profession_As_Per_EID__pc',             // "Profession" - all customers
        'Occupation__pc',                        // "Position" - employed only
        'EmployerBusinessName__pc',              // "Company Name" - employed only
        'Salary_Range__pc',                      // "Monthly Salary Range" - employed only
        'SourceOfIncome__pc',                    // locked to Salary when employed (greyed, not hidden)
        'OtherSourceOfIncome__pc'                // shown only when Source of Income = Others
    };

    /** Everything written to a person account, for the save path. */
    private static List<String> personAccountFields() {
        List<String> all = new List<String>(PERSON_IDENTITY_FIELDS);
        all.addAll(PERSON_EID_FIELDS);
        all.addAll(PERSON_PASSPORT_FIELDS);
        all.addAll(PERSON_EMPLOYMENT_FIELDS);
        return all;
    }

    /** Org Account fields, reached only through a Contact. */
    private static final List<String> ORG_ACCOUNT_FIELDS = new List<String>{
        'Name',
        'LegalStructure__c',                     // picklist from describe
        'Nature_Of_Business__c',
        'Company_Country_Of_Origin__c',          // country list borrowed - see OPTION_SOURCE_FIELD
        'DateOfEstablishment__c',                // must not be a future date
        TRADE_LICENCE_FIELD,
        'TradeLicenseExpiryDate__c',             // must be a future date
        'UnifiedNumber__c',
        'UAEVATRegisterNumber__c',
        'SourceOfIncome__c',                     // Business / Investor only for an org account
        'POAAuthorizationNo__c',
        'POA_Issued_by__c',
        'POAPlaceofIssuance__c',
        'POAAuthorizationDate__c',
        'POAAuthorizationExpiryDate__c'
        // 'TradeName__c'    <- exists in the org, dropped from the 29 Aug list. Uncomment to restore.
    };

    /* ---- Contact, same grouping. Name is a read-only formula so first / last are used. ---- */

    private static final List<String> CONTACT_IDENTITY_FIELDS = new List<String>{
        'Salutation',
        'FirstName',
        'MiddleName',
        'LastName',
        'AccountnameArabic__c',                  // optional - see OPTIONAL_FIELDS
        'Birthdate',
        'GenderIdentity',
        'Nationality__c',
        'CountryOfResidence__c',
        'UAE_Resident_Status__c',
        'Do_you_hold_dual_nationality__c',
        'Other_Nationality_If_Applicable__c',
        'AreYouPoliticallyExposedPersonPEP__c'
        // 'Designation__c'  <- in the CMDT screenshot, absent from the 29 Aug list.
    };

    private static final List<String> CONTACT_EID_FIELDS = new List<String>{
        'EIDNumber__c',
        'Emirates_ID_Issue_Date__c',
        'EmiratesIDExpiryDate__c',
        'EID_Issue_Emirates__c',
        'EID_Sponsor__c'
    };

    private static final List<String> CONTACT_PASSPORT_FIELDS = new List<String>{
        'PassportNumber__c',
        'PassportIssueDate__c',
        'PassportExpiryDate__c',
        'PassportIssuancePlace__c'
    };

    private static final List<String> CONTACT_EMPLOYMENT_FIELDS = new List<String>{
        'Employment_Status__c',
        'Profession_As_Per_EID__c',
        'Occupation__c',
        'EmployerBusinessName__c',
        'Salary_Range__c',
        'SourceOfIncome__c',
        'OtherSourceOfIncome__c'
    };

    /** Everything written to a contact, for the save path. */
    private static List<String> contactFields() {
        List<String> all = new List<String>(CONTACT_IDENTITY_FIELDS);
        all.addAll(CONTACT_EID_FIELDS);
        all.addAll(CONTACT_PASSPORT_FIELDS);
        all.addAll(CONTACT_EMPLOYMENT_FIELDS);
        return all;
    }

    private static final List<String> PERSON_ADDRESS_FIELDS = new List<String>{
        'PersonMailingStreet', 'PersonMailingCity', 'PersonMailingState',
        'PersonMailingCountry', 'PersonMailingPostalCode'
    };

    /** Org Account address - billing, reached only through a Contact. */
    private static final List<String> ACCOUNT_ADDRESS_FIELDS = new List<String>{
        'BillingStreet', 'BillingCity', 'BillingState', 'BillingCountry', 'BillingPostalCode'
    };

    private static final List<String> CONTACT_ADDRESS_FIELDS = new List<String>{
        'MailingStreet', 'MailingCity', 'MailingState', 'MailingCountry', 'MailingPostalCode'
    };

    /**
     * Render a Text field as a dropdown. Key is Object.FieldApiName.
     * The field stays Text in the database - this only constrains what this form offers.
     * Anyone editing via page layout, data loader or API can still write any value.
     */
    private static final List<String> UAE_EMIRATES = new List<String>{
        'Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman',
        'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah'
    };

    private static final List<String> POSITION_LEVELS = new List<String>{
        'Entry Level', 'Mid Level', 'Manager / Senior Specialist', 'Executive'
    };

    private static final Map<String, List<String>> OPTION_OVERRIDES = new Map<String, List<String>>{
        'Account.EID_Issue_Emirates__pc' => UAE_EMIRATES,
        'Contact.EID_Issue_Emirates__c'  => UAE_EMIRATES,
        'Account.Occupation__pc'         => POSITION_LEVELS,
        'Contact.Occupation__c'          => POSITION_LEVELS,
        'Account.SourceOfIncome__c'      => new List<String>{ 'Business', 'Investor' }
        // Add more here, remembering the comma on the line above:
        // ,'Account.Occupation__pc'        => new List<String>{ 'Engineer', 'Doctor', 'Teacher' }
        // ,'Account.Nature_Of_Business__c' => new List<String>{ 'Trading', 'Manufacturing' }
        // ,'Account.POA_Issued_by__c'      => new List<String>{ 'Dubai Courts' }
        // ,'Account.POAPlaceofIssuance__c' => new List<String>{ 'Dubai', 'Abu Dhabi', 'Sharjah' }
    };

    /**
     * Borrow another field's picklist values. Used where a field should offer
     * the same country list as an existing picklist rather than duplicating it.
     * Key and value are both Object.FieldApiName on the same object.
     */
    private static final Map<String, String> OPTION_SOURCE_FIELD = new Map<String, String>{
        'Account.Other_Nationality_If_Applicable__pc' => 'CountryOfResidence__pc',
        'Contact.Other_Nationality_If_Applicable__c'  => 'CountryOfResidence__c',
        'Account.Company_Country_Of_Origin__c'        => 'CountryOfResidence__pc'
    };

    /**
     * DEPENDENT OPTIONS - narrows a picklist based on another field's value.
     * Taken from the Employment Status specification (30 Aug):
     *   Employed      -> Source of Income is hidden and forced to Salary
     *   Self Employed -> Business, Investor, Landlord, Others
     *   Unemployed    -> Investor, Landlord, Others
     *   Retired       -> Investor, Landlord, Pension, Others
     *   Student       -> Others only
     *   House Wife    -> Others only
     * A status not listed here shows the field's full picklist.
     */
    private static final String OTHERS = 'Others (please specify)';

    private static final Map<String, List<String>> INCOME_BY_EMPLOYMENT =
        new Map<String, List<String>>{
            'self employed' => new List<String>{ 'Business', 'Investor', 'Landlord', OTHERS },
            'unemployed'    => new List<String>{ 'Investor', 'Landlord', OTHERS },
            'retired'       => new List<String>{ 'Investor', 'Landlord', 'Pension', OTHERS },
            'student'       => new List<String>{ OTHERS },
            'house wife'    => new List<String>{ OTHERS }
        };

    private static final Map<String, DependentOptions> DEPENDENT_OPTIONS =
        new Map<String, DependentOptions>{
            'Account.SourceOfIncome__pc' =>
                new DependentOptions('Employment_Status__pc', INCOME_BY_EMPLOYMENT),
            'Contact.SourceOfIncome__c' =>
                new DependentOptions('Employment_Status__c', INCOME_BY_EMPLOYMENT)
        };

    /**
     * VISIBILITY RULES - a field is rendered only when its controlling field
     * holds (or does not hold) one of the listed values. A field that is not
     * visible is not validated and not written; its stored value is left alone.
     *
     * negate = true inverts the match, e.g. Source of Income shows for every
     * employment status EXCEPT Employed.
     */
    private static final Set<String> RESIDENT = new Set<String>{ 'resident' };
    private static final Set<String> YES      = new Set<String>{ 'yes' };
    private static final Set<String> EMPLOYED = new Set<String>{ 'employed' };
    private static final Set<String> OTHER_INCOME = new Set<String>{ 'others (please specify)' };

    private static final Map<String, VisibilityRule> VISIBILITY_RULES =
        new Map<String, VisibilityRule>{

        // ---- Emirates ID block: residents only ----
        'Account.EIDNumber__pc'            => new VisibilityRule('UAE_Resident_Status__pc', RESIDENT, false),
        'Account.Emirates_ID_Issue_Date__pc' => new VisibilityRule('UAE_Resident_Status__pc', RESIDENT, false),
        'Account.EmiratesIDExpiryDate__pc' => new VisibilityRule('UAE_Resident_Status__pc', RESIDENT, false),
        'Account.EID_Issue_Emirates__pc'   => new VisibilityRule('UAE_Resident_Status__pc', RESIDENT, false),
        'Account.EID_Sponsor__pc'          => new VisibilityRule('UAE_Resident_Status__pc', RESIDENT, false),
        'Contact.EIDNumber__c'             => new VisibilityRule('UAE_Resident_Status__c', RESIDENT, false),
        'Contact.Emirates_ID_Issue_Date__c'=> new VisibilityRule('UAE_Resident_Status__c', RESIDENT, false),
        'Contact.EmiratesIDExpiryDate__c'  => new VisibilityRule('UAE_Resident_Status__c', RESIDENT, false),
        'Contact.EID_Issue_Emirates__c'    => new VisibilityRule('UAE_Resident_Status__c', RESIDENT, false),
        'Contact.EID_Sponsor__c'           => new VisibilityRule('UAE_Resident_Status__c', RESIDENT, false),
        // Profession_As_Per_EID is deliberately NOT here - it applies to
        // residents and non-residents alike (30 Aug).

        // ---- Dual nationality ----
        'Account.Other_Nationality_If_Applicable__pc' =>
            new VisibilityRule('Do_you_hold_dual_nationality__pc', YES, false),
        'Contact.Other_Nationality_If_Applicable__c' =>
            new VisibilityRule('Do_you_hold_dual_nationality__c', YES, false),

        // ---- Employment chain ----
        'Account.Occupation__pc'           => new VisibilityRule('Employment_Status__pc', EMPLOYED, false),
        'Contact.Occupation__c'            => new VisibilityRule('Employment_Status__c', EMPLOYED, false),

        'Account.EmployerBusinessName__pc' => new VisibilityRule('Employment_Status__pc', EMPLOYED, false),
        'Contact.EmployerBusinessName__c'  => new VisibilityRule('Employment_Status__c', EMPLOYED, false),
        'Account.Salary_Range__pc'         => new VisibilityRule('Employment_Status__pc', EMPLOYED, false),
        'Contact.Salary_Range__c'          => new VisibilityRule('Employment_Status__c', EMPLOYED, false),

        // Source of income has NO visibility rule (changed 22 Sep). It used to be
        // hidden for the employed; it is now always on screen, and the LWC greys
        // it out and shows Salary while Employment Status is Employed. Putting a
        // rule back here would hide the field again and stop it being written,
        // because buildRecord() skips fields that are not visible.

        'Account.OtherSourceOfIncome__pc'  => new VisibilityRule('SourceOfIncome__pc', OTHER_INCOME, false),
        'Contact.OtherSourceOfIncome__c'   => new VisibilityRule('SourceOfIncome__c', OTHER_INCOME, false)
    };

    /**
     * When the controlling field takes one of the given values, clear the listed
     * fields and then apply the literal / copied values. Runs in the LWC as the
     * user changes the field, so they see the effect immediately.
     */
    private static final List<AutoSetRule> AUTO_SET_RULES = new List<AutoSetRule>{
        new AutoSetRule(
            'Account', 'Employment_Status__pc', EMPLOYED,
            new List<String>{ 'Occupation__pc', 'EmployerBusinessName__pc', 'Salary_Range__pc',
                              'SourceOfIncome__pc', 'OtherSourceOfIncome__pc' },
            new Map<String, String>{ 'SourceOfIncome__pc' => 'Salary' },
            new Map<String, String>{ 'EmployerBusinessName__pc' => 'EID_Sponsor__pc' }
        ),
        new AutoSetRule(
            'Contact', 'Employment_Status__c', EMPLOYED,
            new List<String>{ 'Occupation__c', 'EmployerBusinessName__c', 'Salary_Range__c',
                              'SourceOfIncome__c', 'OtherSourceOfIncome__c' },
            new Map<String, String>{ 'SourceOfIncome__c' => 'Salary' },
            new Map<String, String>{ 'EmployerBusinessName__c' => 'EID_Sponsor__c' }
        )
    };

    /** Label shown in the form, overriding the field label from describe. */
    private static final Map<String, String> LABEL_OVERRIDES = new Map<String, String>{
        'Account.CountryOfResidence__pc'    => 'Country Of Residence',
        'Contact.CountryOfResidence__c'     => 'Country Of Residence',
        'Account.Profession_As_Per_EID__pc' => 'Profession',
        'Contact.Profession_As_Per_EID__c'  => 'Profession',
        'Account.EmployerBusinessName__pc'  => 'Company Name',
        'Contact.EmployerBusinessName__c'   => 'Company Name',
        'Account.Occupation__pc'            => 'Position',
        'Contact.Occupation__c'             => 'Position',
        'Account.Salary_Range__pc'          => 'Monthly Salary Range',
        'Contact.Salary_Range__c'           => 'Monthly Salary Range',
        'Account.AccountnameArabic__pc'     => 'Name in Arabic',
        'Contact.AccountnameArabic__c'      => 'Name in Arabic',
        'Account.Company_Country_Of_Origin__c' => 'Company Country Of Origin',
        'Account.DateOfEstablishment__c'    => 'Date Of Establishment'
    };

    /**
     * Date fields that must fall in the future (expiry) or the past (issue).
     * Checked in the LWC and again here.
     */
    private static final Map<String, String> DATE_RULES = new Map<String, String>{
        'Account.EmiratesIDExpiryDate__pc'   => 'future',
        'Account.PassportExpiryDate__pc'     => 'future',
        'Account.Emirates_ID_Issue_Date__pc' => 'past',
        'Account.PassportIssueDate__pc'      => 'past',
        'Account.PersonBirthdate'            => 'past',
        'Contact.EmiratesIDExpiryDate__c'    => 'future',
        'Contact.PassportExpiryDate__c'      => 'future',
        'Contact.Emirates_ID_Issue_Date__c'  => 'past',
        'Contact.PassportIssueDate__c'       => 'past',
        'Contact.Birthdate'                  => 'past',

        // Org account, reached through a contact
        'Account.DateOfEstablishment__c'     => 'past',
        'Account.TradeLicenseExpiryDate__c'  => 'future',
        'Account.POAAuthorizationDate__c'    => 'past',
        'Account.POAAuthorizationExpiryDate__c' => 'future'
    };

    /** Which field holds resident status on each object. */
    private static final Map<String, String> RESIDENT_STATUS_FIELD = new Map<String, String>{
        'Account' => 'UAE_Resident_Status__pc',
        'Contact' => 'UAE_Resident_Status__c'
    };

    /** Fields displayed but never written, on top of anything describe reports as not updateable. */
    private static final Set<String> FORCE_READ_ONLY = new Set<String>{
        'Account.UAEResident__c'   // formula field
    };

    /** Rendered but never enforced. Everything else in the lists above is mandatory. */
    private static final Set<String> OPTIONAL_FIELDS = new Set<String>{
        'Account.MiddleName',
        'Contact.MiddleName',
        'Account.AccountnameArabic__pc',
        'Contact.AccountnameArabic__c'
    };

    /**
     * Server side format check. The LWC masks as the user types, but the value
     * is still validated here - the client can be bypassed.
     */
    private static final Map<String, FormatRule> FORMAT_RULES = new Map<String, FormatRule>{
        'Account.EIDNumber__pc' => new FormatRule(
            '^784-[0-9]{4}-[0-9]{7}-[0-9]$',
            'Emirates ID must be in the format 784-YYYY-NNNNNNN-N'
        ),
        'Contact.EIDNumber__c' => new FormatRule(
            '^784-[0-9]{4}-[0-9]{7}-[0-9]$',
            'Emirates ID must be in the format 784-YYYY-NNNNNNN-N'
        )
    };

    private class FormatRule {
        String pattern;
        String message;
        FormatRule(String p, String m) { this.pattern = p; this.message = m; }
    }

    public class DependentOptionSet {
        @AuraEnabled public String controllingValue;
        @AuraEnabled public List<PicklistOption> options;
    }

    private class DependentOptions {
        String controllingField;
        Map<String, List<String>> byValue;
        DependentOptions(String f, Map<String, List<String>> m) {
            this.controllingField = f;
            this.byValue = m;
        }
    }

    private class VisibilityRule {
        String controllingField;
        Set<String> values;
        Boolean negate;
        VisibilityRule(String f, Set<String> v, Boolean n) {
            this.controllingField = f;
            this.values = v;
            this.negate = n;
        }
    }

    public class AutoSetRule {
        @AuraEnabled public String targetObject;
        @AuraEnabled public String whenField;
        @AuraEnabled public List<String> whenValues;
        @AuraEnabled public List<String> clearFields;
        @AuraEnabled public Map<String, String> setLiteral;
        @AuraEnabled public Map<String, String> copyFromField;

        public AutoSetRule(String obj, String f, Set<String> vals, List<String> clear,
                           Map<String, String> lit, Map<String, String> copy) {
            this.targetObject  = obj == 'Contact' ? 'contact' : 'account';
            this.whenField     = f;
            this.whenValues    = new List<String>(vals);
            this.clearFields   = clear;
            this.setLiteral    = lit;
            this.copyFromField = copy;
        }
    }


    /* ==================================================================================
     *  WRAPPERS
     * ================================================================================== */

    public class FormContext {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String sourceObjectType;
        @AuraEnabled public Boolean isPersonAccount;
        @AuraEnabled public Boolean includeContactSection;
        @AuraEnabled public String accountName;
        @AuraEnabled public String contactName;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PicklistOption(String l, String v) { this.label = l; this.value = v; }
    }

    public class FieldDescriptor {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean readOnly;
        @AuraEnabled public Integer maxLength;
        @AuraEnabled public List<PicklistOption> options;
        @AuraEnabled public String dateRule;
        @AuraEnabled public String formatPattern;
        @AuraEnabled public String formatMessage;
        @AuraEnabled public String mask;
        @AuraEnabled public String visibleWhenField;
        @AuraEnabled public List<String> visibleWhenValues;
        @AuraEnabled public Boolean visibleWhenNegate;
        @AuraEnabled public String optionsControlledBy;
        @AuraEnabled public List<DependentOptionSet> dependentOptions;
    }

    public class AddressFieldMap {
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
        @AuraEnabled public String postalCode;
    }

    public class FormSection {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String targetObject;      // 'account' | 'contact'
        @AuraEnabled public Boolean isAddress;
        @AuraEnabled public String villaLabel;
        @AuraEnabled public String villaValue;
        @AuraEnabled public Boolean villaRequired;
        @AuraEnabled public AddressFieldMap addressFields;
        @AuraEnabled public List<FieldDescriptor> fields;
    }

    public class FormDefinition {
        @AuraEnabled public FormContext context;
        @AuraEnabled public List<AutoSetRule> autoSetRules;
        @AuraEnabled public List<FormSection> sections;
        @AuraEnabled public Map<String, Object> accountValues;
        @AuraEnabled public Map<String, Object> contactValues;
    }


    /* ==================================================================================
     *  CONTEXT
     * ================================================================================== */

    @AuraEnabled
    public static FormContext resolveContext(Id sourceRecordId) {
        if (sourceRecordId == null) {
            throw new AuraHandledException('No record was provided to load the form.');
        }

        FormContext ctx = new FormContext();
        ctx.sourceObjectType = sourceRecordId.getSObjectType().getDescribe().getName();

        if (ctx.sourceObjectType == 'Account') {
            ctx.accountId = sourceRecordId;

        } else if (ctx.sourceObjectType == 'Opportunity') {
            List<Opportunity> opps = [
                SELECT AccountId FROM Opportunity WHERE Id = :sourceRecordId LIMIT 1
            ];
            if (opps.isEmpty())            throw new AuraHandledException('Could not find this opportunity.');
            if (opps[0].AccountId == null) throw new AuraHandledException('This opportunity has no related account.');
            ctx.accountId      = opps[0].AccountId;
            ctx.opportunityId  = sourceRecordId;

        } else if (ctx.sourceObjectType == 'Contact') {
            List<Contact> cons = [
                SELECT AccountId, Name FROM Contact WHERE Id = :sourceRecordId LIMIT 1
            ];
            if (cons.isEmpty())            throw new AuraHandledException('Could not find this contact.');
            if (cons[0].AccountId == null) throw new AuraHandledException('This contact is not linked to an account.');
            ctx.accountId   = cons[0].AccountId;
            ctx.contactId   = sourceRecordId;
            ctx.contactName = cons[0].Name;

        } else {
            throw new AuraHandledException('This form cannot be launched from ' + ctx.sourceObjectType + '.');
        }

        Account acc = [SELECT Id, Name, IsPersonAccount FROM Account WHERE Id = :ctx.accountId LIMIT 1];
        ctx.isPersonAccount = acc.IsPersonAccount;
        ctx.accountName     = acc.Name;

        // Contact-scoped fields apply only when launched from a Contact against an org account.
        // A person account's contact is a shadow record and must not receive DML.
        ctx.includeContactSection = (ctx.contactId != null && !ctx.isPersonAccount);

        if (ctx.contactId != null && ctx.isPersonAccount) {
            // Launched from a person account's shadow contact - treat as the person account flow.
            ctx.contactId = null;
        }

        if (!ctx.isPersonAccount && !ctx.includeContactSection) {
            throw new AuraHandledException(
                'This is a business account. Open the form from one of its contacts so the ' +
                'contact details can be captured alongside the account.'
            );
        }

        return ctx;
    }


    /* ==================================================================================
     *  LOAD
     * ================================================================================== */

    @AuraEnabled
    public static FormDefinition loadForm(Id sourceRecordId) {
        FormContext ctx = resolveContext(sourceRecordId);

        FormDefinition def = new FormDefinition();
        def.context      = ctx;
        def.autoSetRules = AUTO_SET_RULES;
        def.sections     = new List<FormSection>();
        def.contactValues = new Map<String, Object>();

        if (ctx.includeContactSection) {
            def.sections.add(buildSection(
                'contactIdentity', 'Identity', 'contact', false,
                Contact.SObjectType, CONTACT_IDENTITY_FIELDS
            ));
            def.sections.add(buildSection(
                'contactEid', 'Emirates ID', 'contact', false,
                Contact.SObjectType, CONTACT_EID_FIELDS
            ));
            def.sections.add(buildSection(
                'contactPassport', 'Passport', 'contact', false,
                Contact.SObjectType, CONTACT_PASSPORT_FIELDS
            ));
            def.sections.add(buildSection(
                'contactEmployment', 'Employment', 'contact', false,
                Contact.SObjectType, CONTACT_EMPLOYMENT_FIELDS
            ));
            def.sections.add(buildSection(
                'contactAddress', 'Mailing address', 'contact', true,
                Contact.SObjectType, CONTACT_ADDRESS_FIELDS
            ));
            def.sections.add(buildSection(
                'accountDetails', 'Related business account', 'account', false,
                Account.SObjectType, ORG_ACCOUNT_FIELDS
            ));
            def.sections.add(buildSection(
                'accountAddress', 'Business billing address', 'account', true,
                Account.SObjectType, ACCOUNT_ADDRESS_FIELDS
            ));
        } else {
            def.sections.add(buildSection(
                'personIdentity', 'Identity', 'account', false,
                Account.SObjectType, PERSON_IDENTITY_FIELDS
            ));
            def.sections.add(buildSection(
                'personEid', 'Emirates ID', 'account', false,
                Account.SObjectType, PERSON_EID_FIELDS
            ));
            def.sections.add(buildSection(
                'personPassport', 'Passport', 'account', false,
                Account.SObjectType, PERSON_PASSPORT_FIELDS
            ));
            def.sections.add(buildSection(
                'personEmployment', 'Employment', 'account', false,
                Account.SObjectType, PERSON_EMPLOYMENT_FIELDS
            ));
            def.sections.add(buildSection(
                'accountAddress', 'Mailing address', 'account', true,
                Account.SObjectType, PERSON_ADDRESS_FIELDS
            ));
            // Billing is mirrored from the mailing address above at save time.
        }

        // Load current values for everything we are rendering
        Set<String> accFields = new Set<String>{ 'Id' };
        Set<String> conFields = new Set<String>{ 'Id' };
        for (FormSection s : def.sections) {
            for (FieldDescriptor fd : s.fields) {
                if (s.targetObject == 'account') accFields.add(fd.apiName);
                else                             conFields.add(fd.apiName);
            }
        }

        def.accountValues = toValueMap(queryOne('Account', accFields, ctx.accountId), accFields);

        if (ctx.includeContactSection) {
            def.contactValues = toValueMap(queryOne('Contact', conFields, ctx.contactId), conFields);
        }

        // The villa number is stored inside the street line. Pull it back out so
        // the user sees what they entered last time in its own input, and the
        // street field shows only the street.
        for (FormSection sec : def.sections) {
            if (!sec.isAddress || sec.addressFields == null) continue;

            Map<String, Object> vals = sec.targetObject == 'contact'
                ? def.contactValues
                : def.accountValues;

            String streetField = sec.addressFields.street;
            if (String.isBlank(streetField)) continue;

            Object raw = vals.get(streetField);
            List<String> parts = splitVilla(raw == null ? '' : String.valueOf(raw));

            sec.villaValue = parts[0];
            vals.put(streetField, parts[1]);
        }

        return def;
    }

    private static FormSection buildSection(
        String key, String label, String targetObject, Boolean isAddress,
        SObjectType sot, List<String> apiNames
    ) {
        FormSection s = new FormSection();
        s.key          = key;
        s.label        = label;
        s.targetObject = targetObject;
        s.isAddress    = isAddress;
        s.fields       = describeFields(sot, apiNames);

        if (isAddress) {
            s.addressFields  = buildAddressMap(apiNames);
            s.villaLabel     = VILLA_LABEL;
            s.villaRequired  = true;
        }

        return s;
    }

    /**
     * Derives which field in the section is street, city, state, country and
     * postal code by matching the suffix. Keeps the LWC free of any hardcoded
     * knowledge of Billing vs Mailing vs PersonMailing.
     */
    private static AddressFieldMap buildAddressMap(List<String> apiNames) {
        AddressFieldMap m = new AddressFieldMap();
        for (String f : apiNames) {
            if      (f.endsWith('PostalCode')) m.postalCode = f;
            else if (f.endsWith('Street'))     m.street = f;
            else if (f.endsWith('City'))       m.city = f;
            else if (f.endsWith('State'))      m.state = f;
            else if (f.endsWith('Country'))    m.country = f;
        }
        return m;
    }

    private static List<FieldDescriptor> describeFields(SObjectType sot, List<String> apiNames) {
        String objectName = sot.getDescribe().getName();
        Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();
        List<FieldDescriptor> out = new List<FieldDescriptor>();

        for (String apiName : apiNames) {
            Schema.SObjectField f = fieldMap.get(apiName);
            if (f == null) {
                System.debug(LoggingLevel.WARN,
                    'AccountKycController: field not found -> ' + objectName + '.' + apiName);
                continue;
            }

            Schema.DescribeFieldResult d = f.getDescribe();
            if (!d.isAccessible()) continue;

            String qualified = objectName + '.' + d.getName();

            FieldDescriptor fd = new FieldDescriptor();
            fd.apiName   = d.getName();
            fd.label     = LABEL_OVERRIDES.containsKey(qualified)
                             ? LABEL_OVERRIDES.get(qualified)
                             : d.getLabel();
            fd.maxLength = d.getLength();
            fd.readOnly  = !d.isUpdateable() || FORCE_READ_ONLY.contains(qualified);
            fd.type      = mapType(d.getType());
            fd.options   = new List<PicklistOption>();

            // Text field rendered as a dropdown with a fixed list
            if (OPTION_OVERRIDES.containsKey(qualified)) {
                fd.type = 'picklist';
                for (String v : OPTION_OVERRIDES.get(qualified)) {
                    fd.options.add(new PicklistOption(v, v));
                }

            // Field that borrows another field's picklist values
            } else if (OPTION_SOURCE_FIELD.containsKey(qualified)) {
                Schema.SObjectField srcField = fieldMap.get(OPTION_SOURCE_FIELD.get(qualified));
                if (srcField != null) {
                    fd.type = 'picklist';
                    for (Schema.PicklistEntry e : srcField.getDescribe().getPicklistValues()) {
                        if (e.isActive()) fd.options.add(new PicklistOption(e.getLabel(), e.getValue()));
                    }
                }
                if (fd.options.isEmpty()) {
                    // Source field missing or not a picklist - fall back to its own type
                    fd.type = mapType(d.getType());
                    if (fd.type == 'picklist') {
                        for (Schema.PicklistEntry e : d.getPicklistValues()) {
                            if (e.isActive()) fd.options.add(new PicklistOption(e.getLabel(), e.getValue()));
                        }
                    }
                }

            } else if (fd.type == 'picklist' || fd.type == 'multipicklist') {
                for (Schema.PicklistEntry e : d.getPicklistValues()) {
                    if (e.isActive()) fd.options.add(new PicklistOption(e.getLabel(), e.getValue()));
                }
            }

            // A checkbox defaults to false, so "unanswered" and "no" are the same value.
            // It can never be enforced as required.
            fd.required = !fd.readOnly
                       && fd.type != 'boolean'
                       && !OPTIONAL_FIELDS.contains(qualified);

            if (FORMAT_RULES.containsKey(qualified)) {
                FormatRule fr = FORMAT_RULES.get(qualified);
                fd.formatPattern = fr.pattern;
                fd.formatMessage = fr.message;
                fd.mask = 'emiratesId';
            }

            if (VISIBILITY_RULES.containsKey(qualified)) {
                VisibilityRule vr = VISIBILITY_RULES.get(qualified);
                fd.visibleWhenField  = vr.controllingField;
                fd.visibleWhenValues = new List<String>(vr.values);
                fd.visibleWhenNegate = vr.negate;
            }

            if (DATE_RULES.containsKey(qualified)) {
                fd.dateRule = DATE_RULES.get(qualified);
            }

            if (DEPENDENT_OPTIONS.containsKey(qualified)) {
                DependentOptions dep = DEPENDENT_OPTIONS.get(qualified);
                fd.optionsControlledBy = dep.controllingField;
                fd.dependentOptions = new List<DependentOptionSet>();

                for (String ctrlValue : dep.byValue.keySet()) {
                    DependentOptionSet optionSet = new DependentOptionSet();
                    optionSet.controllingValue = ctrlValue;
                    optionSet.options = new List<PicklistOption>();
                    for (String v : dep.byValue.get(ctrlValue)) {
                        optionSet.options.add(new PicklistOption(v, v));
                    }
                    fd.dependentOptions.add(optionSet);
                }
            }

            out.add(fd);
        }
        return out;
    }

    private static String mapType(Schema.DisplayType t) {
        switch on t {
            when EMAIL                  { return 'email'; }
            when PHONE                  { return 'phone'; }
            when DATE                   { return 'date'; }
            when DATETIME               { return 'datetime'; }
            when BOOLEAN                { return 'boolean'; }
            when PICKLIST               { return 'picklist'; }
            when MULTIPICKLIST          { return 'multipicklist'; }
            when DOUBLE, INTEGER, LONG  { return 'number'; }
            when CURRENCY               { return 'currency'; }
            when PERCENT                { return 'percent'; }
            when URL                    { return 'url'; }
            when TEXTAREA               { return 'textarea'; }
            when else                   { return 'string'; }
        }
    }

    private static SObject queryOne(String objectName, Set<String> fields, Id recordId) {
        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ')
                    + ' FROM ' + String.escapeSingleQuotes(objectName)
                    + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        if (rows.isEmpty()) throw new AuraHandledException('Could not find the ' + objectName + ' record.');
        return rows[0];
    }

    private static Map<String, Object> toValueMap(SObject rec, Set<String> fields) {
        Map<String, Object> m = new Map<String, Object>();
        if (rec == null) return m;
        for (String f : fields) {
            try { m.put(f, rec.get(f)); } catch (Exception e) { /* not queried */ }
        }
        return m;
    }


    /* ==================================================================================
     *  SAVE
     * ================================================================================== */

    @AuraEnabled
    public static String saveForm(String payloadJson) {

        // Untyped parsing. Typed deserialize into an inner class with
        // Map<String, Object> members is brittle - a single unexpected value
        // type aborts the whole payload with no indication of which field.
        Id sourceRecordId;
        Map<String, Object> accountValues;
        Map<String, Object> contactValues;

        try {
            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);

            Object src = raw.get('sourceRecordId');
            if (src != null && String.isNotBlank(String.valueOf(src))) {
                sourceRecordId = Id.valueOf(String.valueOf(src));
            }

            accountValues = raw.get('accountValues') == null
                ? new Map<String, Object>()
                : (Map<String, Object>) raw.get('accountValues');

            contactValues = raw.get('contactValues') == null
                ? new Map<String, Object>()
                : (Map<String, Object>) raw.get('contactValues');

        } catch (Exception e) {
            throw new AuraHandledException(
                'The form data could not be read (' + e.getTypeName() + '). Close the form and try again.'
            );
        }

        if (sourceRecordId == null) {
            throw new AuraHandledException('No record was provided to save against.');
        }

        // Re-resolve server side. The client is never trusted for which records get written.
        FormContext ctx = resolveContext(sourceRecordId);

        List<String> missing = new List<String>();

        List<String> accDetailFields = ctx.includeContactSection
            ? ORG_ACCOUNT_FIELDS
            : personAccountFields();

        // One address is captured. Billing is never shown - it is filled from
        // whatever was captured, so the two always agree.
        List<String> accAddressFields;

        if (ctx.includeContactSection) {
            // Two addresses are captured independently: the contact's mailing
            // address and the business account's billing address. Each has its
            // own villa / building number.
            applyVillaPrefix(buildAddressMap(CONTACT_ADDRESS_FIELDS).street, contactValues, missing);
            applyVillaPrefix(buildAddressMap(ACCOUNT_ADDRESS_FIELDS).street, accountValues, missing);
            accAddressFields = ACCOUNT_ADDRESS_FIELDS;

        } else {
            // Person account mailing address -> the same account's billing address
            applyVillaPrefix(buildAddressMap(PERSON_ADDRESS_FIELDS).street, accountValues, missing);
            mirrorAddress(accountValues, PERSON_ADDRESS_FIELDS,
                          accountValues, ACCOUNT_ADDRESS_FIELDS);
            accAddressFields = new List<String>(PERSON_ADDRESS_FIELDS);
            accAddressFields.addAll(ACCOUNT_ADDRESS_FIELDS);
        }

        List<FieldDescriptor> accDesc = describeFields(Account.SObjectType, accDetailFields);
        accDesc.addAll(describeFields(Account.SObjectType, accAddressFields));

        Account acc = (Account) buildRecord('Account', ctx.accountId, accDesc, accountValues, missing);

        Contact con = null;
        if (ctx.includeContactSection) {
            List<FieldDescriptor> conDesc = describeFields(Contact.SObjectType, contactFields());
            conDesc.addAll(describeFields(Contact.SObjectType, CONTACT_ADDRESS_FIELDS));
            con = (Contact) buildRecord('Contact', ctx.contactId, conDesc, contactValues, missing);
        }

        if (!missing.isEmpty()) {
            throw new AuraHandledException('Complete these fields before saving: ' + String.join(missing, ', '));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            update acc;
            if (con != null) update con;
            return 'SUCCESS';
        } catch (DmlException e) {
            Database.rollback(sp);
            // AuraHandledException hides its message from Apex tests and from the
            // debug log, so the real reason is written out before it is wrapped.
            System.debug(LoggingLevel.ERROR, 'AccountKycController save failed: ' + e.getDmlMessage(0));
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'AccountKycController save failed: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Copies a captured address onto a second set of address fields, matching
     * street to street, city to city and so on. Source and target may be the
     * same map (person account mailing -> billing) or different maps
     * (contact mailing -> the related account's billing).
     *
     * The villa prefix is applied to the source street before this runs, so the
     * mirrored street carries it too.
     */
    private static void mirrorAddress(
        Map<String, Object> source, List<String> sourceFields,
        Map<String, Object> target, List<String> targetFields
    ) {
        if (source == null || target == null) return;

        AddressFieldMap src = buildAddressMap(sourceFields);
        AddressFieldMap tgt = buildAddressMap(targetFields);

        copyIfPresent(source, src.street,     target, tgt.street);
        copyIfPresent(source, src.city,       target, tgt.city);
        copyIfPresent(source, src.state,      target, tgt.state);
        copyIfPresent(source, src.country,    target, tgt.country);
        copyIfPresent(source, src.postalCode, target, tgt.postalCode);
    }

    private static void copyIfPresent(
        Map<String, Object> source, String sourceField,
        Map<String, Object> target, String targetField
    ) {
        if (String.isBlank(sourceField) || String.isBlank(targetField)) return;
        if (!source.containsKey(sourceField)) return;
        target.put(targetField, source.get(sourceField));
    }

    /**
     * Splits a stored street line back into villa and street. Mirrors the join
     * done by applyVillaPrefix: the villa is the part before the first comma,
     * and only when it is short enough to plausibly be a unit number rather
     * than a street name.
     *
     * Returns a two element list: [villa, street].
     */
    private static final Integer MAX_VILLA_LENGTH = 30;
    private static final String VILLA_LABEL = 'Villa / building number';

    private static List<String> splitVilla(String savedStreet) {
        String raw = savedStreet == null ? '' : savedStreet.trim();
        if (String.isBlank(raw)) {
            return new List<String>{ '', '' };
        }

        Integer comma = raw.indexOf(',');
        if (comma < 0) {
            return new List<String>{ '', raw };
        }

        String first = raw.substring(0, comma).trim();
        String rest  = raw.substring(comma + 1).trim();

        if (String.isNotBlank(first) && first.length() <= MAX_VILLA_LENGTH && String.isNotBlank(rest)) {
            return new List<String>{ first, rest };
        }

        return new List<String>{ '', raw };
    }

    /**
     * The villa / building number is captured separately in the form for clarity
     * but is not a field of its own - it is prefixed onto the street line.
     * Guards against double-prefixing when a record is edited a second time.
     */
    private static void applyVillaPrefix(
        String streetField, Map<String, Object> values, List<String> missing
    ) {
        if (values == null || String.isBlank(streetField)) return;

        Object villaObj = values.get('villaNumber');
        String villa = villaObj == null ? '' : String.valueOf(villaObj).trim();
        values.remove('villaNumber');

        if (String.isBlank(villa)) {
            missing.add(VILLA_LABEL);
            return;
        }

        Object streetObj = values.get(streetField);
        String street = streetObj == null ? '' : String.valueOf(streetObj).trim();

        if (street.startsWithIgnoreCase(villa)) {
            return;   // already prefixed
        }

        String combined = String.isBlank(street) ? villa : villa + ', ' + street;
        if (combined.length() > 255) {
            combined = combined.substring(0, 255);
        }
        values.put(streetField, combined);
    }

    /**
     * Re-applies the literal values from AUTO_SET_RULES server side. The LWC
     * greys these fields out so they cannot be edited in the form, but the
     * payload is still client supplied - this makes sure an Employed record
     * gets Source of Income = Salary whatever arrived.
     *
     * Only setLiteral is applied. copyFromField (Company Name from EID Sponsor)
     * is a convenience for the user, not a rule, so it is left alone.
     */
    private static void applyLockedValues(String objectName, Map<String, Object> submitted) {
        if (submitted == null) return;

        String objectKey = objectName == 'Contact' ? 'contact' : 'account';

        for (AutoSetRule rule : AUTO_SET_RULES) {
            if (rule.targetObject != objectKey) continue;
            if (rule.setLiteral == null || rule.setLiteral.isEmpty()) continue;

            // The controlling field must be part of this payload, otherwise the
            // rule belongs to the other flow and does not apply.
            if (!submitted.containsKey(rule.whenField)) continue;

            Object ctrlVal = submitted.get(rule.whenField);
            String ctrl = ctrlVal == null ? '' : String.valueOf(ctrlVal).trim().toLowerCase();

            if (!new Set<String>(rule.whenValues).contains(ctrl)) continue;

            for (String lockedField : rule.setLiteral.keySet()) {
                submitted.put(lockedField, rule.setLiteral.get(lockedField));
            }
        }
    }

    private static SObject buildRecord(
        String objectName, Id recordId, List<FieldDescriptor> descriptors,
        Map<String, Object> submitted, List<String> missing
    ) {
        if (submitted == null) submitted = new Map<String, Object>();

        applyLockedValues(objectName, submitted);

        Map<String, Object> writable = new Map<String, Object>{ 'Id' => recordId };

        for (FieldDescriptor fd : descriptors) {
            if (fd.readOnly) continue;

            // A hidden field is neither enforced nor written. Its stored value
            // is left untouched rather than cleared.
            if (String.isNotBlank(fd.visibleWhenField)) {
                Object ctrlVal = submitted.get(fd.visibleWhenField);
                String ctrl = ctrlVal == null ? '' : String.valueOf(ctrlVal).trim().toLowerCase();
                Boolean matched = new Set<String>(fd.visibleWhenValues).contains(ctrl);
                Boolean visible = (fd.visibleWhenNegate == true) ? !matched : matched;
                if (!visible) continue;
            }

            Object val = submitted.get(fd.apiName);

            if (fd.type == 'boolean') {
                writable.put(fd.apiName, val == null ? false : val);
                continue;
            }

            if (isBlank(val)) {
                if (fd.required) missing.add(fd.label);
                writable.put(fd.apiName, null);
                continue;
            }

            if (val instanceof String && fd.maxLength > 0 && ((String) val).length() > fd.maxLength) {
                throw new AuraHandledException(
                    fd.label + ' is too long. Maximum ' + fd.maxLength + ' characters.'
                );
            }

            if (String.isNotBlank(fd.formatPattern) && val instanceof String) {
                if (!Pattern.matches(fd.formatPattern, (String) val)) {
                    throw new AuraHandledException(fd.formatMessage);
                }
            }

            if (String.isNotBlank(fd.dateRule)) {
                validateDate(fd, val);
            }

            writable.put(fd.apiName, val);
        }

        return (SObject) JSON.deserialize(JSON.serialize(writable), Type.forName(objectName));
    }

    /**
     * Expiry dates must be in the future, issue dates and birthdates in the past.
     * The LWC checks the same thing so the user sees it inline, but a value can
     * reach here without passing through the form.
     */
    private static void validateDate(FieldDescriptor fd, Object val) {
        Date d;
        try {
            d = Date.valueOf(String.valueOf(val));
        } catch (Exception e) {
            throw new AuraHandledException(fd.label + ' is not a valid date.');
        }

        Date today = Date.today();

        if (fd.dateRule == 'future' && d <= today) {
            throw new AuraHandledException(fd.label + ' must be a future date.');
        }
        if (fd.dateRule == 'past' && d > today) {
            throw new AuraHandledException(fd.label + ' cannot be in the future.');
        }
    }

    private static Boolean isBlank(Object val) {
        if (val == null) return true;
        if (val instanceof String) return String.isBlank((String) val);
        return false;
    }
}