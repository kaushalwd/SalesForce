/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ConvertLeadProcessMRE
 * Author          : Arvind
 * Created Date    : Jun 21, 2026
 * Last Modified By: Arvind
 * Last Modified On: Jun 23, 2026
 *
 * Change History  :
 *  Date          │   Author  │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 21, 2026  │  Arvind   │  Initial version
 *
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class ConvertLeadProcessMRE {

    // ─── Sales Order Relationship ─────────────────────────────────────────────
    // Child relationship API name used to count Sales Orders on Account.
    // Change this constant to match your org (e.g. 'Sales_Orders__r').
    // Default: 'Opportunities'
    @TestVisible
    private static String salesOrderRelName = 'Opportunities';


    // ─── Flow Entry Point ─────────────────────────────────────────────────────

    /**
     * @description Invocable method for Flow.
     *              Input: Lead Id
     *              Output: List of AccountMatchResult (JSON-serialisable)
     */
    @InvocableMethod(label='FastTrack KYC — Find Matching Person Accounts'
                     description='Returns Person Accounts matching the lead. Returns empty if lead has a Company (org account).')
    public static List<FlowOutput> checkFromFlow(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput inp : inputs) {
            FlowOutput out = new FlowOutput();
            out.matchCount   = 0;
            out.hasMatch     = false;
            out.isOrgAccount = false;
            try {
                Lead l = [SELECT Id, Company FROM Lead WHERE Id = :inp.leadId LIMIT 1];
                out.isOrgAccount = String.isNotBlank(l.Company);
                if (!out.isOrgAccount) {
                    List<AccountMatchResult> matches = findMatchingPersonAccounts(inp.leadId);
                    out.matchCount  = matches.size();
                    out.hasMatch    = out.matchCount > 0;
                    out.matchesJson = JSON.serialize(matches);
                }
            } catch (Exception e) {
                out.errorMessage = e.getMessage();
            }
            outputs.add(out);
        }
        return outputs;
    }

    // ─── LWC Entry Points ─────────────────────────────────────────────────────

    /**
     * @description Load initial state for the LWC.
     *              Returns KYC status + whether to skip (Company not null).
     */
    @AuraEnabled(cacheable=true)
    public static LeadKYCState getLeadKYCState(Id leadId) {
        Lead l = [
            SELECT Id, Company, Existing_Account__c,
                   New_Account_Exception_Status__c, IsConverted, Name,
                   Email, MobilePhone, EIDNumber__c, PassportNumber__c
            FROM   Lead WHERE Id = :leadId LIMIT 1
        ];

        LeadKYCState state = new LeadKYCState();
        state.leadId            = l.Id;
        state.leadName          = l.Name;
        state.isOrgAccount      = String.isNotBlank(l.Company);
        state.existingAccountId = l.Existing_Account__c;
        state.exceptionStatus   = l.New_Account_Exception_Status__c;
        state.isConverted       = l.IsConverted;
        state.hasEmail          = String.isNotBlank(l.Email);
        state.hasMobile         = String.isNotBlank(l.MobilePhone);
        state.hasEid            = String.isNotBlank(l.EIDNumber__c);
        state.hasPassport       = String.isNotBlank(l.PassportNumber__c);
        return state;
    }

    /**
     * @description Single method that returns BOTH state AND matches in one server call.
     *              Use this in the LWC instead of two separate wire calls.
     *              Reduces server roundtrips from 2 to 1 — eliminates the slow double-load.
     *              cacheable=false so it always returns fresh data (important after approval).
     */
    @AuraEnabled(cacheable=false)
    public static LeadKYCPayload getLeadKYCPayload(Id leadId) {
        LeadKYCPayload payload = new LeadKYCPayload();
        payload.matches = new List<AccountMatchResult>();

        // Safe List query — prevents 'List has no rows for assignment to SObject'
        List<Lead> leads = [
            SELECT Id, Company, Existing_Account__c,
                   New_Account_Exception_Status__c, IsConverted, Name,
                   Email, MobilePhone, EIDNumber__c, PassportNumber__c,
                   UAEResidentStatus__c, UnifiedNumber__c
            FROM   Lead WHERE Id = :leadId LIMIT 1
        ];
        if (leads.isEmpty()) {
            throw new AuraHandledException('Lead not found: ' + leadId);
        }
        Lead l = leads[0];

        // State
        LeadKYCState state = new LeadKYCState();
        state.leadId            = l.Id;
        state.leadName          = l.Name;
        state.isOrgAccount      = String.isNotBlank(l.Company);
        state.existingAccountId = l.Existing_Account__c;
        state.exceptionStatus   = l.New_Account_Exception_Status__c;
        state.isConverted       = l.IsConverted;
        state.hasEmail          = String.isNotBlank(l.Email);
        state.hasMobile         = String.isNotBlank(l.MobilePhone);
        state.hasEid            = String.isNotBlank(l.EIDNumber__c);
        state.hasPassport       = String.isNotBlank(l.PassportNumber__c);
        payload.state           = state;

        // Matches — person account only
        if (String.isBlank(l.Company)) {
            Set<String> emails    = new Set<String>();
            Set<String> mobiles   = new Set<String>();
            Set<String> eids      = new Set<String>();
            Set<String> passports = new Set<String>();

            if (String.isNotBlank(l.Email))             emails.add(l.Email.trim().toLowerCase());
            if (String.isNotBlank(l.MobilePhone))       mobiles.addAll(phoneSearchVariants(l.MobilePhone));
            if (String.isNotBlank(l.EIDNumber__c)
                && String.isNotBlank(l.UAEResidentStatus__c)
                && l.UAEResidentStatus__c.equalsIgnoreCase('Resident'))
                eids.add(l.EIDNumber__c.trim());
            if (String.isNotBlank(l.PassportNumber__c)) passports.add(l.PassportNumber__c.trim());

            if (!emails.isEmpty() || !mobiles.isEmpty() || !eids.isEmpty() || !passports.isEmpty()) {
                List<Account> accounts = queryPersonAccounts(emails, mobiles, eids, passports);
                List<AccountMatchResult> results = new List<AccountMatchResult>();
                for (Account a : accounts) {
                    AccountMatchResult r = new AccountMatchResult();
                    r.accountId      = a.Id;
                    r.name           = a.Name;
                    r.email          = a.PersonEmail;
                    r.mobile         = a.PersonMobilePhone;
                    r.eidNumber      = a.EIDNumber__pc;
                    r.passportNumber = a.PassportNumber__pc;
                    r.createdDate    = a.CreatedDate;
                    r.matchedOn      = buildMatchedOn(l, a);
                    try {
                        Id accId = a.Id;
                        r.salesOrderCount = Database.countQuery(
                            'SELECT COUNT() FROM ' + salesOrderRelName + ' WHERE AccountId = :accId'
                        );
                    } catch (Exception e) {
                        r.salesOrderCount = 0;
                    }
                    results.add(r);
                }
                payload.matches = results;
            }
        }

        // Org account match — reuse the lead we already have, no second query
        if (String.isNotBlank(l.Company) && String.isNotBlank(l.UnifiedNumber__c)) {
            String unified = l.UnifiedNumber__c.trim();
            List<Account> orgMatches = new MatchLookup().queryOrgAccountByUnifiedNumber(unified);
            if (!orgMatches.isEmpty()) {
                OrgAccountMatchResult r = new OrgAccountMatchResult();
                r.accountId           = orgMatches[0].Id;
                r.name                = orgMatches[0].Name;
                r.unifiedNumber       = orgMatches[0].UnifiedNumber__c;
                r.tradeLicenseNumber  = orgMatches[0].TradeLicenseNumber__c;
                r.mobile              = orgMatches[0].En_MobilePhone__pc;
                r.email               = orgMatches[0].EmailID__c;
                r.recordType          = orgMatches[0].RecordType.Name;
                payload.orgMatch = r;
            }
        }

        return payload;
    }

    /**
     * @description Returns matching Person Accounts for the lead.
     *              Returns empty list if lead has a Company field set.
     *              Merged accounts (Is_Merged__c = true) are always excluded.
     */
    @AuraEnabled(cacheable=true)
    public static List<AccountMatchResult> findMatchingPersonAccounts(Id leadId) {
        Lead l = [
            SELECT Id, Company, Email, MobilePhone, EIDNumber__c, PassportNumber__c,
                   UAEResidentStatus__c
            FROM   Lead WHERE Id = :leadId LIMIT 1
        ];

        if (String.isNotBlank(l.Company)) return new List<AccountMatchResult>();

        Set<String> emails    = new Set<String>();
        Set<String> mobiles   = new Set<String>();
        Set<String> eids      = new Set<String>();
        Set<String> passports = new Set<String>();

        if (String.isNotBlank(l.Email))             emails.add(l.Email.trim().toLowerCase());
        if (String.isNotBlank(l.MobilePhone))       mobiles.addAll(phoneSearchVariants(l.MobilePhone));
        // EID only matched when lead is a UAE Resident — mirrors existing conversion validation
        if (String.isNotBlank(l.EIDNumber__c)
            && String.isNotBlank(l.UAEResidentStatus__c)
            && l.UAEResidentStatus__c.equalsIgnoreCase('Resident'))
            eids.add(l.EIDNumber__c.trim());
        if (String.isNotBlank(l.PassportNumber__c)) passports.add(l.PassportNumber__c.trim());

        if (emails.isEmpty() && mobiles.isEmpty() && eids.isEmpty() && passports.isEmpty()) {
            return new List<AccountMatchResult>();
        }

        List<Account> accounts = queryPersonAccounts(emails, mobiles, eids, passports);
        List<AccountMatchResult> results = new List<AccountMatchResult>();

        for (Account a : accounts) {
            AccountMatchResult r = new AccountMatchResult();
            r.accountId      = a.Id;
            r.name           = a.Name;
            r.email          = a.PersonEmail;
            r.mobile         = a.PersonMobilePhone;
            r.eidNumber      = a.EIDNumber__pc;
            r.passportNumber = a.PassportNumber__pc;
            r.createdDate    = a.CreatedDate;
            r.matchedOn      = buildMatchedOn(l, a);

            // Direct COUNT SOQL — reliable regardless of relationship name
            try {
                Id accId = a.Id;
                r.salesOrderCount = Database.countQuery(
                    'SELECT COUNT() FROM ' + salesOrderRelName + ' WHERE AccountId = :accId'
                );
            } catch (Exception e) {
                r.salesOrderCount = 0;
            }

            results.add(r);
        }
        return results;
    }

    /**
     * @description Returns matching Org Account for the lead based on UnifiedNumber__c.
     *              Returns null if lead has no Company or no UnifiedNumber__c.
     *              Org accounts with RecordType = 'Broker Agency' are excluded.
     *              Merged accounts (Is_Merged__c = true) are excluded.
     */
    @AuraEnabled(cacheable=true)
    public static OrgAccountMatchResult findMatchingOrgAccount(Id leadId) {
        Lead l = [
            SELECT Id, Company, UnifiedNumber__c
            FROM   Lead WHERE Id = :leadId LIMIT 1
        ];

        // Only applies to org account leads
        if (String.isBlank(l.Company) || String.isBlank(l.UnifiedNumber__c)) {
            return null;
        }

        String unified = l.UnifiedNumber__c.trim();
        List<Account> matches = new MatchLookup().queryOrgAccountByUnifiedNumber(unified);

        if (matches.isEmpty()) return null;

        OrgAccountMatchResult r = new OrgAccountMatchResult();
        r.accountId          = matches[0].Id;
        r.name                = matches[0].Name;
        r.unifiedNumber       = matches[0].UnifiedNumber__c;
        r.tradeLicenseNumber  = matches[0].TradeLicenseNumber__c;
        r.mobile              = matches[0].En_MobilePhone__pc;
        r.email               = matches[0].EmailID__c;
        r.recordType          = matches[0].RecordType.Name;
        return r;
    }

    /**
     * @description Set Existing_Account__c on the lead.
     */
    @AuraEnabled
    public static void saveAccountSelection(Id leadId, Id accountId) {
        update new Lead(
            Id                              = leadId,
            Existing_Account__c             = accountId,
            New_Account_Exception_Status__c = null
        );
    }

    /**
     * @description Clear mapped account and submit for approval.
     *
     *  Scenarios:
     *  1. Approval already pending for this lead
     *       → AuraHandledException — cannot submit twice
     *  2. No active approval process configured for Lead
     *       → AuraHandledException with admin guidance
     *  3. Approval process exists, lead meets entry criteria
     *       → Status = 'Pending Approval', notification sent to approver
     *  4. Approval process exists but lead fails entry criteria
     *       → AuraHandledException, status rolled back to null
     */
    @AuraEnabled
    public static void submitException(Id leadId, String reason) {

        // Step 1 — block re-submission if an approval is already open for this lead
        List<ProcessInstance> openApprovals = [
            SELECT Id
            FROM   ProcessInstance
            WHERE  TargetObjectId = :leadId
            AND    Status         = 'Pending'
            LIMIT  1
        ];
        if (!openApprovals.isEmpty()) {
            throw new AuraHandledException(
                'An approval request is already pending for this lead. '
                + 'Please wait for the current request to be approved or rejected before submitting again.'
            );
        }

        // Step 2 — check an active approval process exists for Lead
        List<ProcessDefinition> activeProcesses = [
            SELECT Id, Name
            FROM   ProcessDefinition
            WHERE  TableEnumOrId = 'Lead'
            AND    State         = 'Active'
            LIMIT  1
        ];
        if (activeProcesses.isEmpty()) {
            throw new AuraHandledException(
                'No active approval process is configured for Lead. '
                + 'Please ask your Salesforce administrator to set up an approval process '
                + 'before submitting KYC exceptions.'
            );
        }

        // Step 3 — set Pending Approval and clear mapped account
        update new Lead(
            Id                              = leadId,
            Existing_Account__c             = null,
            New_Account_Exception_Status__c = 'Pending Approval'
        );

        // Step 4 — submit for approval
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(leadId);
            req.setComments(
                'KYC Exception: ' + (String.isBlank(reason) ? 'New account requested.' : reason)
            );
            Approval.ProcessResult res = Approval.process(req);

            if (!res.isSuccess()) {
                List<String> errs = new List<String>();
                for (Database.Error e : res.getErrors()) {
                    errs.add(e.getMessage());
                }
                // Roll back status — do not leave in Pending Approval if nothing was submitted
                update new Lead(
                    Id                              = leadId,
                    Existing_Account__c             = null,
                    New_Account_Exception_Status__c = null
                );
                throw new AuraHandledException(
                    'Approval submission failed: ' + String.join(errs, '; ')
                );
            }

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            // Unexpected error — roll back status
            update new Lead(
                Id                              = leadId,
                Existing_Account__c             = null,
                New_Account_Exception_Status__c = null
            );
            throw new AuraHandledException(
                'Could not submit for approval: ' + e.getMessage()
            );
        }
    }

    // ─── Approval Outcome Handlers ────────────────────────────────────────────

    /**
     * @description Called from LeadTriggerHandler AFTER UPDATE when
     *              New_Account_Exception_Status__c changes.
     *
     *  On APPROVED  → ensures Existing_Account__c is null + notifies owner
     *  On REJECTED  → keeps status for LWC display + notifies owner
     */
    public static void handleApprovalOutcome(
        List<Lead>       newLeads,
        Map<Id, SObject> newMap,
        List<SObject>    oldList,
        Map<Id, SObject> oldMap
    ) {
        List<Lead> toUpdate = new List<Lead>();

        for (Lead l : newLeads) {
            Lead old = (Lead) oldMap.get(l.Id);
            if (l.New_Account_Exception_Status__c == old.New_Account_Exception_Status__c) {
                continue;
            }

            if (l.New_Account_Exception_Status__c == 'Approved') {
                if (l.Existing_Account__c != null) {
                    toUpdate.add(new Lead(
                        Id                  = l.Id,
                        Existing_Account__c = null
                    ));
                }
                notifySalesAssociate(l.Id, l.OwnerId, 'approved');
            }

            if (l.New_Account_Exception_Status__c == 'Rejected') {
                toUpdate.add(new Lead(
                    Id                              = l.Id,
                    New_Account_Exception_Status__c = 'Rejected'
                ));
                notifySalesAssociate(l.Id, l.OwnerId, 'rejected');
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }


    /**
     * @description Sends a bell notification to the lead owner for KYC exception
     *              outcomes (approved/rejected).
     *              Requires a CustomNotificationType with DeveloperName
     *              'KYC_Exception_Notification' — create in Setup if needed.
     *              Silently skips if the notification type does not exist.
     */
    public static void notifySalesAssociate(Id leadId, Id ownerId, String outcome) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id FROM CustomNotificationType
                WHERE  DeveloperName = 'KYC_Exception_Notification'
                LIMIT  1
            ];
            if (notifTypes.isEmpty() || ownerId == null) return;

            String title;
            String body;
            if (outcome == 'approved') {
                title = 'KYC Exception Approved';
                body  = 'Your request to create a new account has been approved. You can now convert the lead.';
            } else {
                title = 'KYC Exception Rejected';
                body  = 'Your request to create a new account was rejected. Please re-verify and select an existing account.';
            }

            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setNotificationTypeId(notifTypes[0].Id);
            notif.setTargetId(leadId);
            notif.setTitle(title);
            notif.setBody(body);
            notif.send(new Set<String>{ ownerId });
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN,
                'ConvertLeadProcessMRE.notifySalesAssociate: ' + ex.getMessage());
        }
    }

    /**
     * @description Validate before conversion.
     *              Returns null = OK, String = block message.
     */
    @AuraEnabled
    public static String validateConvert(Id leadId) {
        Lead l = [
            SELECT Id, Company, Existing_Account__c, New_Account_Exception_Status__c
            FROM   Lead WHERE Id = :leadId LIMIT 1
        ];
        if (String.isNotBlank(l.Company))                    return null;
        if (l.Existing_Account__c != null)                   return null;
        if (l.New_Account_Exception_Status__c == 'Approved') return null;
        List<AccountMatchResult> m = findMatchingPersonAccounts(leadId);
        if (!m.isEmpty()) {
            return 'Matching account(s) found. Please verify and select an account, '
                 + 'or request an exception to create a new one.';
        }
        return null;
    }

    /**
     * @description Converts a lead using Database.convertLead().
     *              Existing_Account__c is GUARANTEED to be used when set —
     *              the standard Convert page UI is bypassed entirely.
     *
     *              PERFORMANCE: accountIdOverride lets the caller pass a
     *              freshly selected/org-matched account directly into this
     *              SAME call, instead of calling saveAccountSelection() first
     *              as a separate Apex round trip. This cuts one full
     *              client-server round trip off every conversion that
     *              requires an account selection.
     *
     *  Account decision:
     *   • Company NOT null             → org account, Salesforce handles normally
     *   • accountIdOverride provided    → used directly, takes priority
     *   • Existing_Account__c set      → setAccountId() called, no new account created
     *   • Existing_Account__c null     → new person account created
     *   • Exception Approved           → Existing_Account__c cleared by approval, new account
     */
    @AuraEnabled
    public static ConvertLeadResult convertLead(
        Id      leadId,
        String  convertedStatus,
        Boolean createOpportunity,
        String  opportunityName,
        Id      accountIdOverride
    ) {
        Lead l = [
            SELECT Id, Company, Existing_Account__c,
                   New_Account_Exception_Status__c, FirstName, LastName
            FROM   Lead WHERE Id = :leadId LIMIT 1
        ];

        // Resolve which account to use — override takes priority
        Id accountToUse = accountIdOverride != null ? accountIdOverride : l.Existing_Account__c;

        // Keep Existing_Account__c in sync for audit/reporting purposes —
        // combined into THIS transaction, no extra client round trip.
        if (accountIdOverride != null && accountIdOverride != l.Existing_Account__c) {
            update new Lead(
                Id                              = leadId,
                Existing_Account__c             = accountIdOverride,
                New_Account_Exception_Status__c = null
            );
            l.Existing_Account__c = accountIdOverride; // keep in-memory copy consistent
        }

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(
            String.isNotBlank(convertedStatus) ? convertedStatus : 'Qualified'
        );

        Boolean doCreateOpp = (createOpportunity == true);
        lc.setDoNotCreateOpportunity(!doCreateOpp);
        if (doCreateOpp && String.isNotBlank(opportunityName)) {
            lc.setOpportunityName(opportunityName);
        }

        // setAccountId for both person AND org leads — if an account was matched
        // or overridden, always pass it to LeadConvert so Salesforce reuses it
        // instead of creating a new one. Previously this was gated on
        // String.isBlank(l.Company) which silently skipped org leads entirely.
        if (accountToUse != null) {
            lc.setAccountId(accountToUse);
        }

        ConvertLeadResult result = new ConvertLeadResult();
        try {
            Database.LeadConvertResult lcr = Database.convertLead(lc);
            result.success           = lcr.isSuccess();
            result.leadId            = lcr.getLeadId();
            result.accountId         = lcr.getAccountId();
            result.contactId         = lcr.getContactId();
            result.opportunityId     = lcr.getOpportunityId();
            result.createdNewAccount = (accountToUse == null);

            // Field population for EmiratesIDExpiryDate, Passport details,
            // Nationality, UAE Resident Status, Trade License, and Unified
            // Number is now handled by Salesforce's standard "Map Lead
            // Fields" Setup configuration — Database.convertLead() populates
            // them automatically as part of account creation itself. No
            // extra Apex DML or second Account automation pass needed.

            if (!lcr.isSuccess()) {
                List<String> errs = new List<String>();
                for (Database.Error e : lcr.getErrors()) {
                    errs.add(e.getMessage());
                }
                result.errorMessage = String.join(errs, '; ');
            }
        } catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    /**
     * Queries Person Accounts matching on any of the provided lookup values.
     * Delegates to a `without sharing` inner class — see MatchLookup below for why.
     */
    private static List<Account> queryPersonAccounts(
        Set<String> emails, Set<String> mobiles,
        Set<String> eids,   Set<String> passports
    ) {
        return new MatchLookup().queryPersonAccounts(emails, mobiles, eids, passports);
    }

    /**
     * @description Duplicate-detection queries MUST see org-wide data,
     *              regardless of the running user's sharing visibility.
     *
     *              The outer class is `with sharing` — correct for conversion
     *              itself, approvals, and anything that creates/modifies data.
     *              But matching/duplicate-detection is different: its entire
     *              purpose is to catch an existing record REGARDLESS of who
     *              currently owns it or has sharing access to it. If the
     *              outer class's sharing rules hid the matching Account from
     *              the running user (e.g. private OWD, no sharing rule to the
     *              lead owner), the query would silently return zero rows —
     *              not because the data doesn't match, but because the user
     *              can't see it. That produces a false "no match found" even
     *              when a real duplicate exists.
     *
     *              This inner class is deliberately `without sharing` so
     *              matching always sees the full picture, while everything
     *              else in the outer class stays properly scoped.
     */
    private without sharing class MatchLookup {

        private List<Account> queryPersonAccounts(
            Set<String> emails, Set<String> mobiles,
            Set<String> eids,   Set<String> passports
        ) {
            List<String> ors = new List<String>();
            if (!emails.isEmpty())    ors.add('PersonEmail IN :emails');
            if (!mobiles.isEmpty())   ors.add('PersonMobilePhone IN :mobiles');
            if (!eids.isEmpty())      ors.add('EIDNumber__pc IN :eids');
            if (!passports.isEmpty()) ors.add('PassportNumber__pc IN :passports');
            if (ors.isEmpty())        return new List<Account>();

            // SOQL injection fix: email/mobile/EID/passport sets bound via queryWithBinds.
            String soql = 'SELECT Id, Name, PersonEmail, PersonMobilePhone, '
                        + 'EIDNumber__pc, PassportNumber__pc, CreatedDate'
                        + ' FROM Account'
                        + ' WHERE IsPersonAccount = TRUE'
                        + ' AND Is_Merged__c = FALSE'
                        + ' AND (' + String.join(ors, ' OR ') + ')'
                        + ' LIMIT 10';
            return Database.queryWithBinds(
                soql,
                new Map<String, Object>{
                    'emails' => emails,
                    'mobiles' => mobiles,
                    'eids' => eids,
                    'passports' => passports
                },
                AccessLevel.SYSTEM_MODE
            );
        }

        private List<Account> queryOrgAccountByUnifiedNumber(String unifiedNumber) {
            if (String.isBlank(unifiedNumber)) return new List<Account>();
            return [
                SELECT Id, Name, UnifiedNumber__c, TradeLicenseNumber__c,
                       En_MobilePhone__pc, EmailID__c, RecordType.Name
                FROM   Account
                WHERE  IsPersonAccount  = FALSE
                AND    Is_Merged__c     = FALSE
                AND    RecordType.Name != 'Broker Agency'
                AND    UnifiedNumber__c = :unifiedNumber
                LIMIT  1
            ];
        }

        private List<Account> queryOrgAccountsByUnifiedNumbers(Set<String> unifiedNumbers) {
            if (unifiedNumbers == null || unifiedNumbers.isEmpty()) return new List<Account>();
            return [
                SELECT Id, UnifiedNumber__c
                FROM   Account
                WHERE  IsPersonAccount   = FALSE
                AND    Is_Merged__c      = FALSE
                AND    RecordType.Name  != 'Broker Agency'
                AND    UnifiedNumber__c IN :unifiedNumbers
                LIMIT  200
            ];
        }
    }

    private static Id resolveFirstMatch(
        Lead l,
        Map<String,Id> byEid, Map<String,Id> byPassport,
        Map<String,Id> byEmail, Map<String,Id> byMobile
    ) {
        if (String.isNotBlank(l.EIDNumber__c) && byEid.containsKey(l.EIDNumber__c.trim()))
            return byEid.get(l.EIDNumber__c.trim());
        if (String.isNotBlank(l.PassportNumber__c) && byPassport.containsKey(l.PassportNumber__c.trim()))
            return byPassport.get(l.PassportNumber__c.trim());
        if (String.isNotBlank(l.Email) && byEmail.containsKey(l.Email.trim().toLowerCase()))
            return byEmail.get(l.Email.trim().toLowerCase());
        if (String.isNotBlank(l.MobilePhone) && byMobile.containsKey(normalisePhone(l.MobilePhone)))
            return byMobile.get(normalisePhone(l.MobilePhone));
        return null;
    }

    private static String buildMatchedOn(Lead l, Account a) {
        List<String> fields = new List<String>();
        if (String.isNotBlank(l.EIDNumber__c)
                && l.EIDNumber__c.trim() == a.EIDNumber__pc
                && String.isNotBlank(l.UAEResidentStatus__c)
                && l.UAEResidentStatus__c.equalsIgnoreCase('Resident'))
            fields.add('Emirates ID');
        if (String.isNotBlank(l.PassportNumber__c) && l.PassportNumber__c.trim() == a.PassportNumber__pc)
            fields.add('Passport');
        if (String.isNotBlank(l.Email)
                && a.PersonEmail != null
                && l.Email.trim().toLowerCase() == a.PersonEmail.trim().toLowerCase())
            fields.add('Email');
        if (String.isNotBlank(l.MobilePhone)
                && a.PersonMobilePhone != null
                && normalisePhone(l.MobilePhone) == normalisePhone(a.PersonMobilePhone))
            fields.add('Mobile');
        return fields.isEmpty() ? 'Other' : String.join(fields, ', ');
    }

    /**
     * @description Produces a canonical CORE number for precise Apex-side
     *              equality comparisons (e.g. resolveFirstMatch, buildMatchedOn).
     *              Strips punctuation, then strips a leading UAE country code
     *              (971 / 00971) or a leading 0, leaving just the subscriber
     *              number. This means "0501234567", "971501234567",
     *              "+971501234567" and "501234567" all normalise to the SAME
     *              value: "501234567".
     */
    private static String normalisePhone(String raw) {
        if (raw == null) return '';
        String digits = raw.replaceAll('[^0-9]', '');
        if (digits.startsWith('00971') && digits.length() > 11) {
            digits = digits.substring(5);
        } else if (digits.startsWith('971') && digits.length() > 9) {
            digits = digits.substring(3);
        }
        if (digits.startsWith('0') && digits.length() > 1) {
            digits = digits.substring(1);
        }
        return digits;
    }

    /**
     * @description SOQL cannot apply normalisePhone() to the stored Account
     *              field at query time, so we instead generate every common
     *              RAW format a UAE mobile number might be stored in, and
     *              search for ALL of them via an IN clause. Used wherever a
     *              `mobiles` Set is built for QUERYING (not for final
     *              equality comparison after candidates are already fetched).
     *
     *              e.g. for input "0501234567", returns:
     *              {501234567, 0501234567, 971501234567,
     *               +971501234567, 00971501234567}
     */
    private static Set<String> phoneSearchVariants(String raw) {
        Set<String> variants = new Set<String>();
        String core = normalisePhone(raw);
        if (String.isBlank(core)) return variants;
        variants.add(core);
        variants.add('0' + core);
        variants.add('971' + core);
        variants.add('+971' + core);
        variants.add('00971' + core);
        return variants;
    }

    // ─── Result Classes ───────────────────────────────────────────────────────

    public class AccountMatchResult {
        @AuraEnabled public Id       accountId;
        @AuraEnabled public String   name;
        @AuraEnabled public String   email;
        @AuraEnabled public String   mobile;
        @AuraEnabled public String   eidNumber;
        @AuraEnabled public String   passportNumber;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public Integer  salesOrderCount;
        @AuraEnabled public String   matchedOn;
    }

    public class LeadKYCState {
        @AuraEnabled public Id      leadId;
        @AuraEnabled public String  leadName;
        @AuraEnabled public Boolean isOrgAccount;
        @AuraEnabled public Id      existingAccountId;
        @AuraEnabled public String  exceptionStatus;
        @AuraEnabled public Boolean isConverted;
        @AuraEnabled public Boolean hasEmail;
        @AuraEnabled public Boolean hasMobile;
        @AuraEnabled public Boolean hasEid;
        @AuraEnabled public Boolean hasPassport;
    }

    public class LeadKYCPayload {
        @AuraEnabled public LeadKYCState           state;
        @AuraEnabled public List<AccountMatchResult> matches;
        @AuraEnabled public OrgAccountMatchResult  orgMatch;
    }

    public class ConvertLeadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id      leadId;
        @AuraEnabled public Id      accountId;
        @AuraEnabled public Id      contactId;
        @AuraEnabled public Id      opportunityId;
        @AuraEnabled public Boolean createdNewAccount;
        @AuraEnabled public String  errorMessage;
    }

    public class OrgAccountMatchResult {
        @AuraEnabled public Id     accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String unifiedNumber;
        @AuraEnabled public String tradeLicenseNumber;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String recordType;
    }

    // Flow wrappers
    public class FlowInput {
        @InvocableVariable(label='Lead Id' required=true)
        public Id leadId;
    }

    public class FlowOutput {
        @InvocableVariable(label='Has matching account')
        public Boolean hasMatch;
        @InvocableVariable(label='Match count')
        public Integer matchCount;
        @InvocableVariable(label='Is org account (Company not null)')
        public Boolean isOrgAccount;
        @InvocableVariable(label='Matches JSON')
        public String  matchesJson;
        @InvocableVariable(label='Error message')
        public String  errorMessage;
    }
}