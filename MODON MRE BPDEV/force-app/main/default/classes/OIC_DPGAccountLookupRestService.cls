/**********************************************************************************************************************
* Name        : OIC_DPGAccountLookupRestService
* Description : REST endpoint that DPG calls via HTTP POST to look up a customer by ANY ONE (or a combination) of:
*               email, mobile, Emirates ID, or trade license number - returning whichever record actually matches.
*               Person Accounts are tried first, then Organization Accounts.
* Usage       : POST /services/apexrest/dpg/accountsearch/
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       -        -              Initial.
* 2.0       Arvind                      10 Jul 2026    Response handling delegated to OIC_RestResponse. ACC-xxx codes registered
*                                                     dynamically. "No match" is now an explicit matchFound=false success, not a
*                                                     success=false. Trade licence lookup now checks TradeLicenseNumber__c.
* 2.1       pprajapati@horizontal.com   25 Aug 2026    Adopted OIC_RequestContext for Section 0 identity resolution and validation.
* 2.2       Jay Patel                   22 Sep 2026    MCR-73 — with sharing, USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/accountsearch/*')
global with sharing class OIC_DPGAccountLookupRestService {

    private static final String TYPE_PERSON = 'Person Account';
    private static final String TYPE_ORG    = 'Organization Account';

    /* ====================================================================================
     *  ERROR CODES - registered into the shared registry at class load.
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('ACC-000', 400, 'Request body cannot be empty.');
        OIC_RestResponse.define('ACC-001', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('ACC-002', 400,
            'At least one of email, mobile, emiratesId, or tradeLicenseNumber is required.');
        OIC_RestResponse.define('ACC-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY = 'ACC-000';
    private static final String ERR_MALFORMED  = 'ACC-001';
    private static final String ERR_NO_CRITERIA = 'ACC-002';
    private static final String ERR_UNEXPECTED = 'ACC-999';

    global class DPGLookupException extends Exception {
        public String errorCode;
    }

    private static DPGLookupException buildEx(String code, String message) {
        DPGLookupException ex = new DPGLookupException(message);
        ex.errorCode = code;
        return ex;
    }

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void searchAccount() {
        OIC_RequestContext ctx = OIC_RequestContext.current().resolveIdentity();
        if (!ctx.isValid()) {
            ctx.toRestResponse().send();
            return;
        }

        try {
            // ---- 1. Parse the incoming JSON body ------------------------------------
            String rawBody = (ctx.getRawBody() != null) ? ctx.getRawBody().trim() : '';
            if (String.isBlank(rawBody)) {
                throw buildEx(ERR_EMPTY_BODY, null);
            }

            AccountLookupRequestWrapper input;
            try {
                input = (AccountLookupRequestWrapper) JSON.deserialize(
                    rawBody, AccountLookupRequestWrapper.class);
            } catch (Exception parseEx) {
                throw buildEx(ERR_MALFORMED, 'Malformed JSON payload: ' + parseEx.getMessage());
            }

            String email             = normalize(input.email);
            String mobile            = normalize(input.mobile);
            String emiratesId        = normalize(input.emiratesId);
            String tradeLicenseNumber = normalize(input.tradeLicenseNumber);

            if (String.isBlank(email) && String.isBlank(mobile)
                    && String.isBlank(emiratesId) && String.isBlank(tradeLicenseNumber)) {
                throw buildEx(ERR_NO_CRITERIA, null);
            }

            // ---- 2. PERSON ACCOUNT first ---------------------------------------------
            Account personMatch = findPersonAccount(email, mobile, emiratesId);
            if (personMatch != null) {
                personResponse(personMatch).send();
                return;
            }

            // ---- 3. ORGANIZATION ACCOUNT via trade license number ---------------------
            Account orgMatch   = null;
            Contact orgContact = null;

            if (String.isNotBlank(tradeLicenseNumber)) {
                orgMatch = findOrgAccountByTradeLicense(tradeLicenseNumber);
                if (orgMatch != null) {
                    orgContact = findContactForAccount(orgMatch.Id, email, mobile);
                }
            }

            // ---- 4. ORGANIZATION ACCOUNT via Contact email/mobile ---------------------
            if (orgMatch == null && (String.isNotBlank(email) || String.isNotBlank(mobile))) {
                orgContact = findOrgContactByEmailOrMobile(email, mobile);
                if (orgContact != null) {
                    orgMatch = orgContact.Account;
                }
            }

            if (orgMatch != null) {
                orgResponse(orgMatch, orgContact).send();
                return;
            }

            // ---- 5. Nothing matched. This is a valid, successful search --------------
            OIC_RestResponse.success()
                .put('matchFound', false)
                .put('message', 'No Person Account or Organization Account matched the supplied details.')
                .flat()
                .send();

        } catch (DPGLookupException lookupEx) {
            OIC_RestResponse.failure(lookupEx.errorCode, lookupEx.getMessage()).send();

        } catch (Exception ex) {
            //2.2 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Account Lookup REST Service',
                'OIC_DPGAccountLookupRestService',
                'searchAccount'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).send();
        }
    }

    /* ====================================================================================
     *  RESPONSE BUILDERS  -- payload built dynamically, flat on the wire
     * ==================================================================================== */
    private static OIC_RestResponse personResponse(Account acc) {
        return OIC_RestResponse.success()
            .put('matchFound',         true)
            .put('message',            'Match found.')
            .put('accountType',        TYPE_PERSON)
            .put('recordTypeName',     acc.RecordType != null ? acc.RecordType.Name : null)
            .put('accountId',          acc.Id)
            .put('accountName',        acc.Name)
            .put('email',              acc.PersonEmail)
            .put('mobile',             acc.PersonMobilePhone)
            .put('emiratesId',         acc.EIDNumber__pc)
            .put('passportNumber',     acc.En_PassportNumber__pc)
            .put('nationality',        acc.En_Nationality__pc)
            .put('tradeLicenseNumber', acc.TradeLicenseNumber__c)
            .put('unifiedNumber',      acc.UnifiedNumber__c)
            .flat();
    }

    private static OIC_RestResponse orgResponse(Account acc, Contact contact) {
        String contactMobile = (contact == null)
            ? null
            : (String.isNotBlank(contact.MobilePhone) ? contact.MobilePhone : contact.Phone);

        return OIC_RestResponse.success()
            .put('matchFound',         true)
            .put('message',            'Match found.')
            .put('accountType',        TYPE_ORG)
            .put('recordTypeName',     acc.RecordType != null ? acc.RecordType.Name : null)
            .put('accountId',          acc.Id)
            .put('accountName',        acc.Name)
            .put('email',              contact == null ? null : contact.Email)
            .put('mobile',             contactMobile)
            .put('tradeLicenseNumber', acc.TradeLicenseNumber__c)
            .put('unifiedNumber',      acc.UnifiedNumber__c)
            .put('contactId',          contact == null ? null : contact.Id)
            .put('contactName',        contact == null ? null : contact.Name)
            .flat();
    }

    /* ====================================================================================
     *  PERSON ACCOUNT lookup
     * ==================================================================================== */
    private static Account findPersonAccount(String email, String mobile, String emiratesId) {
        if (String.isBlank(email) && String.isBlank(mobile) && String.isBlank(emiratesId)) return null;

        //2.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
        List<Account> results = [
            SELECT Id, Name, PersonTitle, AccountnameArabic__c, AccountNumber,
                   En_EIDNumber__pc, Emirates_ID_Issue_Date__pc, EmiratesIDExpiryDate__pc,
                   En_PersonEmail__c, En_Nationality__pc, PersonMobilePhone, PersonEmail, EIDNumber__pc, Call_Phone__c,
                   En_PassportNumber__pc, Masked_Passport_Number__c, PassportIssueDate__pc,
                   PassportExpiryDate__pc, PassportIssuancePlace__pc, PersonBirthdate,
                   MaritalStatus__pc, UAE_Resident_Status__pc, CustomerType__c, UAEResident__c,
                   UnifiedNumber__c, TradeLicenseNumber__c, RecordType.Name
            FROM Account
            WHERE IsPersonAccount = true
            AND (
                (PersonEmail != null AND PersonEmail = :email)
                OR (PersonMobilePhone != null AND PersonMobilePhone = :mobile)
                OR (EIDNumber__pc != null AND EIDNumber__pc = :emiratesId)
            )
            WITH USER_MODE
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    /* ====================================================================================
     *  ORGANIZATION ACCOUNT lookup
     * ==================================================================================== */
    /**
     * Matches on TradeLicenseNumber__c OR UnifiedNumber__c.
     * v1.0 matched the supplied trade licence against UnifiedNumber__c only, which meant a
     * genuine trade licence number never matched unless it happened to equal the unified number.
     */
    private static Account findOrgAccountByTradeLicense(String tradeLicenseNumber) {
        //2.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
        List<Account> results = [
            SELECT Id, Name, UnifiedNumber__c, TradeLicenseNumber__c, TradeName__c, RecordType.Name
            FROM Account
            WHERE IsPersonAccount = false
              AND (TradeLicenseNumber__c = :tradeLicenseNumber
                   OR UnifiedNumber__c = :tradeLicenseNumber)
            WITH USER_MODE
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Best-matching Contact under a known Organization Account. Tries email/mobile first,
     * then falls back to the oldest Contact on the account.
     */
    private static Contact findContactForAccount(Id accountId, String email, String mobile) {
        if (String.isNotBlank(email) || String.isNotBlank(mobile)) {
            //2.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
            List<Contact> results = [
                SELECT Id, Name, Email, Phone, MobilePhone, Title
                FROM Contact
                WHERE AccountId = :accountId
                AND (
                    (Email != null AND Email = :email)
                    OR (MobilePhone != null AND MobilePhone = :mobile)
                    OR (Phone != null AND Phone = :mobile)
                )
                WITH USER_MODE
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!results.isEmpty()) return results[0];
        }

        // No email/mobile match (or none supplied) -- return the account's first Contact
        // so the caller still gets a name/id.
        //2.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
        List<Contact> fallback = [
            SELECT Id, Name, Email, Phone, MobilePhone, Title
            FROM Contact
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback[0];
    }

    /**
     * Matches a Contact directly by email/mobile where the parent Account is an
     * Organization Account, for cases where DPG has only an email/phone.
     */
    private static Contact findOrgContactByEmailOrMobile(String email, String mobile) {
        if (String.isBlank(email) && String.isBlank(mobile)) return null;

        //2.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
        List<Contact> results = [
            SELECT Id, Name, Email, Phone, MobilePhone, AccountId,
                   Account.Name, Account.UnifiedNumber__c, Account.TradeLicenseNumber__c, Account.RecordType.Name
            FROM Contact
            WHERE Account.IsPersonAccount = false
            AND (
                (Email != null AND Email = :email)
                OR (MobilePhone != null AND MobilePhone = :mobile)
                OR (Phone != null AND Phone = :mobile)
            )
            WITH USER_MODE
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    /* ====================================================================================
     *  HELPERS
     * ==================================================================================== */
    private static String normalize(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    /* ====================================================================================
     *  REQUEST DTO   (no response DTO -- OIC_RestResponse builds the payload dynamically)
     * ==================================================================================== */
    global class AccountLookupRequestWrapper {
        global String email;
        global String mobile;
        global String emiratesId;
        global String tradeLicenseNumber;
    }
}