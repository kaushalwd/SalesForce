/**
 * RelixKycController - the server side of the Account action "Send UAE KYC (Relix)" (LWC relixSendKyc).
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  30 Sep 2026  The Account send carries RelixConfig.defaultAmount() (RELIX_DEFAULT_AMOUNT, 1) as its
 *                                    amount. Dalil staging rejects a journey without a transaction block and asked
 *                                    for 0 or 1 while the sale amount is unknown. Row off or blank = no amount, as before.
 * 1.1      MODON Dev  26 Sep 2026  Review fixes. An unexpected fault no longer throws (an exception leaving an
 *                                    @AuraEnabled method rolled back its own log row): send() rolls back to a
 *                                    savepoint taken before its first DML, logs, and returns the safe message as a
 *                                    problem; getStatus() and refresh() log and return a StatusView whose new error
 *                                    field holds the safe message. Only the type and the class and line are logged.
 *                                    send() and refresh() also require the custom permission Relix_KYC_Send on the
 *                                    server. A company's POA counts: its active KYC and live Signzy link ask for
 *                                    confirmation, its live POA case of another company counts as live, and the POA
 *                                    cases the company started are listed and refreshed with the company's.
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R1/R2 (docs/relix). Shows the Account's Relix cases, sends a
 *                                    journey through RelixKycService.start (propertyRef 'ACC-<Account Id>',
 *                                    no amount, Q-01) and refreshes the cases through refreshForUser, which reads
 *                                    but leaves the KYC-date and identity writes to the integration path (R-a).
 *
 * ACCESS. Every method first asks UserRecordAccess whether the running user can read (status, refresh) or edit
 * (send) the Account, because the service and the case reader run without sharing. send() and refresh() also need
 * the custom permission Relix_KYC_Send (permission set Relix_Account_Action), checked here and not only by
 * the page's visibility rule. A user without access gets one safe sentence (AuraHandledException) and nothing else.
 *
 * WHAT LEAVES THE SERVER. Case display fields, three yes/no flags and a masked email (first letter + ***@domain).
 * Never the journey link, Relix error text, names or numbers. Unexpected faults are logged through
 * RelixLogger (type, class and line only) and the caller gets a generic message in the result, not an
 * exception, so the log row is committed.
 *
 * SIGNZY. Reads Is_KYC_Link_Active__c and KYC_Status__c (Signzy's and MODON's formulas) on the Account and, for a
 * company, on its POA Contact, only to warn before a second link. Writes nothing on them and calls no Signzy code.
 *
 * OWNERSHIP. Owner: MODON.
 */
public with sharing class RelixKycController {

    @TestVisible
    private static final String MSG_NO_ACCESS = 'You do not have access to this account.';
    @TestVisible
    private static final String MSG_GENERIC = 'UAE KYC (Relix) could not be completed right now. Please try again, or ask your administrator.';
    @TestVisible
    private static final String MSG_SWITCHED_OFF = 'Relix KYC is not switched on in this org.';

    private static final String REASON_KYC_ACTIVE = 'This buyer\'s KYC is still active.';
    private static final String REASON_SIGNZY_LIVE = 'A Signzy KYC link is still live for this buyer.';
    private static final String REASON_RELIX_LIVE = 'A Relix KYC link is already live for this buyer.';
    private static final String REASON_CONFIRM = 'Confirm to send a new UAE KYC link anyway.';
    private static final String REASON_SEPARATOR = ' ';

    private static final String KYC_ACTIVE = 'KYC Active';
    private static final String PROPERTY_REF_PREFIX = 'ACC-';
    private static final String LOG_METHOD = 'controller';
    private static final String LOG_SEPARATOR = ': ';
    private static final String EMAIL_AT = '@';
    private static final String EMAIL_MASK = '***@';
    /** The custom permission that lets a rep send and refresh (permission set Relix_Account_Action). */
    @TestVisible
    private static final String SEND_PERMISSION = 'Relix_KYC_Send';

    private static final Integer MAX_CASES = 5;
    private static final Integer REFRESH_AFTER_SECONDS = 30;

    private static final List<String> LIVE_SEND_STATES = new List<String>{
        RelixKycService.SEND_SENDING,
        RelixKycService.SEND_SENT,
        RelixKycService.SEND_UNCERTAIN
    };

    /** Test hook: when set, the status read throws it, so the safe-error path can be tested. */
    @TestVisible
    private static Exception simulatedFault;
    /** Test hook: how many status reads succeed before simulatedFault is thrown (0 = the first one throws). */
    @TestVisible
    private static Integer statusReadsBeforeFault = 0;
    private static Integer statusReads = 0;

    /** One Relix case of the Account, as the action shows it. */
    public class CaseView {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public String persona;
        @AuraEnabled public String repStatus;
        @AuraEnabled public String relixStatus;
        @AuraEnabled public String decision;
        @AuraEnabled public String reviewReason;
        @AuraEnabled public Datetime linkSentAt;
        @AuraEnabled public Datetime linkExpiresAt;
        @AuraEnabled public Datetime lastReadAt;
        @AuraEnabled public Boolean live;
    }

    /** What the action needs to decide between sending at once and asking first. error is set only on a fault. */
    public class StatusView {
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public Boolean isCompany;
        @AuraEnabled public Boolean kycActive;
        @AuraEnabled public Boolean signzyLinkLive;
        @AuraEnabled public Boolean hasLiveRelixCase;
        @AuraEnabled public String recipientMasked;
        @AuraEnabled public List<CaseView> cases;
        @AuraEnabled public String error;
    }

    /** The outcome of a send: queued, needs confirmation, or the problems to fix first. */
    public class SendResult {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public Boolean needsConfirmation;
        @AuraEnabled public String confirmReason;
        @AuraEnabled public List<String> problems;
        @AuraEnabled public StatusView status;
    }

    // ================================================================ entry points

    /**
     * The Account's Relix state: switch, KYC flags, masked recipient and the newest cases (at most 5).
     * @param accountId the Account the action was opened on
     * @return the status view; on an unexpected fault only its error (the safe message) is set
     */
    @AuraEnabled
    public static StatusView getStatus(Id accountId) {
        try {
            requireAccess(accountId, false);
            return buildStatus(accountId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            return failedStatus(e, accountId);
        }
    }

    /**
     * Sends a Relix journey for the Account, or says why not. Without confirmation it stops when the buyer's KYC
     * is active or a Signzy or Relix link is live. The Boolean parameter is the signature fixed in docs/relix/07
     * section 7 (the LWC calls it by name). On an unexpected fault everything this call saved is rolled back, the
     * fault is logged and the safe message comes back as the only problem.
     * @param accountId the person or company Account
     * @param confirmed true when the rep confirmed a second link
     * @return the send result with a fresh status
     */
    @AuraEnabled
    public static SendResult send(Id accountId, Boolean confirmed) {
        Savepoint beforeSend;
        try {
            requireAccess(accountId, true);
            requireSendPermission();
            beforeSend = Database.setSavepoint();
            return sendChecked(accountId, confirmed == true);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            if (beforeSend != null) {
                Database.rollback(beforeSend);
            }
            return failedSend(e, accountId);
        }
    }

    /**
     * Reads up to 5 of the Account's cases from Relix now (each at most once per 30 seconds), then returns the status.
     * The KYC-date and identity writes stay with the integration path (docs/relix/07 section 8, R-a). A fault is
     * logged and returned in the view's error; the reads already saved stand (a read can be repeated safely, and a
     * savepoint cannot be taken before the callouts).
     * @param accountId the Account the action was opened on
     * @return the status view after the read
     */
    @AuraEnabled
    public static StatusView refresh(Id accountId) {
        try {
            requireAccess(accountId, false);
            requireSendPermission();
            List<Id> due = new CaseReader().dueForRead(accountId, System.now().addSeconds(-REFRESH_AFTER_SECONDS));
            if (!due.isEmpty() && RelixConfig.isEnabled()) {
                // One call, before any DML or logging here: the service makes every callout before its own DML.
                RelixKycService.refreshForUser(due);
            }
            return buildStatus(accountId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            return failedStatus(e, accountId);
        }
    }

    // ================================================================ send

    private static SendResult sendChecked(Id accountId, Boolean confirmed) {
        StatusView before = buildStatus(accountId);
        SendResult out = new SendResult();
        out.ok = false;
        out.needsConfirmation = false;
        out.problems = new List<String>();
        out.status = before;
        if (!before.enabled) {
            out.problems.add(MSG_SWITCHED_OFF);
            return out;
        }
        String reason = confirmReason(before);
        if (!confirmed && reason != null) {
            out.needsConfirmation = true;
            out.confirmReason = reason;
            return out;
        }
        RelixKycService.StartResult started = RelixKycService.start(startRequest(accountId, confirmed));
        out.ok = started.isOk();
        out.problems.addAll(started.problems);
        out.status = buildStatus(accountId);
        return out;
    }

    private static RelixKycService.StartRequest startRequest(Id accountId, Boolean confirmed) {
        RelixKycService.StartRequest request = new RelixKycService.StartRequest();
        request.subjectId = accountId;
        request.propertyRef = PROPERTY_REF_PREFIX + accountId;
        // The sale amount is not known on the Account; Relix requires a transaction, so the configured default goes.
        request.amount = RelixConfig.defaultAmount();
        request.resendConfirmed = confirmed;
        return request;
    }

    /**
     * Why a send should be confirmed first.
     * @param view the Account's status
     * @return the plain reasons, or null when nothing needs confirming
     */
    @TestVisible
    private static String confirmReason(StatusView view) {
        List<String> reasons = new List<String>();
        if (view.kycActive) {
            reasons.add(REASON_KYC_ACTIVE);
        }
        if (view.signzyLinkLive) {
            reasons.add(REASON_SIGNZY_LIVE);
        }
        if (view.hasLiveRelixCase) {
            reasons.add(REASON_RELIX_LIVE);
        }
        if (reasons.isEmpty()) {
            return null;
        }
        reasons.add(REASON_CONFIRM);
        return String.join(reasons, REASON_SEPARATOR);
    }

    // ================================================================ status

    private static StatusView buildStatus(Id accountId) {
        if (simulatedFault != null && statusReads++ >= statusReadsBeforeFault) {
            throw simulatedFault;
        }
        Account acc = loadAccount(accountId);
        CaseReader reader = new CaseReader();
        Datetime now = System.now();
        StatusView view = new StatusView();
        view.enabled = RelixConfig.isEnabled();
        view.isCompany = !acc.IsPersonAccount;
        // A company is signed for by its POA: the POA's own KYC and Signzy link count as well (signzy C-03).
        Contact poa = view.isCompany ? reader.poa(accountId) : null;
        view.kycActive = acc.KYC_Status__c == KYC_ACTIVE || (poa != null && poa.KYC_Status__c == KYC_ACTIVE);
        view.signzyLinkLive = acc.Is_KYC_Link_Active__c == true || (poa != null && poa.Is_KYC_Link_Active__c == true);
        view.recipientMasked = maskEmail(view.isCompany ? (poa == null ? null : poa.Email) : acc.PersonEmail);
        view.hasLiveRelixCase = reader.countLive(accountId, poa == null ? null : poa.Id, now) > 0;
        view.cases = new List<CaseView>();
        for (Relix_KYC_Case__c row : reader.latestCases(accountId)) {
            view.cases.add(toView(row, now));
        }
        return view;
    }

    private static Account loadAccount(Id accountId) {
        // SYSTEM_MODE: reps may lack FLS on MODON's KYC formula fields; the class keeps with sharing and the
        // caller has already checked the user's access to this Account through UserRecordAccess.
        List<Account> accounts = [
            SELECT Id, IsPersonAccount, Name, PersonEmail, KYC_Status__c, Is_KYC_Link_Active__c
            FROM Account
            WHERE Id = :accountId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw safe(MSG_NO_ACCESS);
        }
        return accounts[0];
    }

    private static CaseView toView(Relix_KYC_Case__c row, Datetime now) {
        CaseView v = new CaseView();
        v.id = row.Id;
        v.name = row.Name;
        v.role = row.Role__c;
        v.persona = row.Persona__c;
        v.repStatus = row.Rep_Status__c;
        v.relixStatus = row.Relix_Status__c;
        v.decision = row.Decision__c;
        v.reviewReason = row.Review_Reason__c;
        v.linkSentAt = row.Link_Sent_At__c;
        v.linkExpiresAt = row.Link_Expires_At__c;
        v.lastReadAt = row.Last_Read_At__c;
        v.live = isLive(row, now);
        return v;
    }

    /**
     * A link the buyer can still use: undecided, sent (or maybe sent) and not expired.
     * @param row a case row with Decision__c, Send_State__c and Link_Expires_At__c
     * @param now the time to compare the expiry with
     * @return true when the link is live
     */
    @TestVisible
    private static Boolean isLive(Relix_KYC_Case__c row, Datetime now) {
        return row.Decision__c == RelixPassRule.OPEN
            && LIVE_SEND_STATES.contains(row.Send_State__c)
            && (row.Link_Expires_At__c == null || row.Link_Expires_At__c > now);
    }

    /**
     * Masks an email for display.
     * @param email the address, possibly blank
     * @return first character + '***@' + domain, or null when there is no usable address
     */
    @TestVisible
    private static String maskEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        String trimmed = email.trim();
        Integer at = trimmed.lastIndexOf(EMAIL_AT);
        if (at < 1 || at >= trimmed.length() - 1) {
            return null;
        }
        return trimmed.left(1) + EMAIL_MASK + trimmed.substring(at + 1);
    }

    // ================================================================ access and errors

    private static void requireAccess(Id accountId, Boolean needEdit) {
        if (accountId == null || accountId.getSobjectType() != Account.SObjectType) {
            throw safe(MSG_NO_ACCESS);
        }
        Id userId = UserInfo.getUserId();
        // SYSTEM_MODE: UserRecordAccess only reports the running user's own access to this one record.
        List<UserRecordAccess> access = [
            SELECT RecordId, HasReadAccess, HasEditAccess
            FROM UserRecordAccess
            WHERE UserId = :userId AND RecordId = :accountId
            WITH SYSTEM_MODE
        ];
        Boolean allowed = !access.isEmpty() && (needEdit ? access[0].HasEditAccess : access[0].HasReadAccess);
        if (!allowed) {
            throw safe(MSG_NO_ACCESS);
        }
    }

    // signzy C-11: the action's visibility rule is not a security control; the server checks the permission too.
    private static void requireSendPermission() {
        if (!FeatureManagement.checkPermission(SEND_PERMISSION)) {
            throw safe(MSG_NO_ACCESS);
        }
    }

    // K4: returned, not thrown, so the log row commits. The view carries only the safe message.
    private static StatusView failedStatus(Exception e, Id accountId) {
        logFault(e, accountId);
        StatusView view = new StatusView();
        view.error = MSG_GENERIC;
        view.cases = new List<CaseView>();
        return view;
    }

    private static SendResult failedSend(Exception e, Id accountId) {
        logFault(e, accountId);
        SendResult out = new SendResult();
        out.ok = false;
        out.needsConfirmation = false;
        out.problems = new List<String>{ MSG_GENERIC };
        return out;
    }

    // The exception type and the first line of its stack (class and line only); never the message, which may quote
    // a value.
    private static void logFault(Exception e, Id accountId) {
        String origin = e.getStackTraceString() == null ? '' : e.getStackTraceString().substringBefore('\n');
        RelixLogger.failure(LOG_METHOD, e.getTypeName() + (String.isBlank(origin) ? '' : LOG_SEPARATOR + origin), accountId);
    }

    private static AuraHandledException safe(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    // ================================================================ reads across sharing

    /**
     * The Account's Relix rows and its POA. without sharing, justified: Relix_KYC_Case__c is Private and its rows are
     * created by other reps and by the Relix jobs, and a POA Contact may sit under another Account. WITH SYSTEM_MODE
     * alone would still apply the sharing of a with-sharing class. Every caller has checked the user's access to the
     * Account first, and only display fields, yes/no flags and a masked email leave the outer class.
     *
     * A company's cases are its own rows and the POA rows it started (Company_Case__r.Account__c), because a POA
     * Contact under another Account puts that Account on its POA row (F-08). The service locks a live link per buyer
     * (Buyer_Ref__c + Role__c), so a live POA case of the same Contact started by another company counts as live here.
     */
    private without sharing class CaseReader {

        List<Relix_KYC_Case__c> latestCases(Id accountId) {
            return [
                SELECT Id, Name, Role__c, Persona__c, Rep_Status__c, Relix_Status__c, Decision__c, Review_Reason__c,
                       Send_State__c, Link_Sent_At__c, Link_Expires_At__c, Last_Read_At__c
                FROM Relix_KYC_Case__c
                WHERE Account__c = :accountId OR Company_Case__r.Account__c = :accountId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT :MAX_CASES
            ];
        }

        Integer countLive(Id accountId, Id poaId, Datetime now) {
            List<String> poaRefs = poaId == null ? new List<String>() : new List<String>{ String.valueOf(poaId) };
            return [
                SELECT COUNT()
                FROM Relix_KYC_Case__c
                WHERE (Account__c = :accountId OR Company_Case__r.Account__c = :accountId
                       OR (Role__c = :RelixKycService.ROLE_POA AND Buyer_Ref__c IN :poaRefs))
                  AND Decision__c = :RelixPassRule.OPEN
                  AND Send_State__c IN :LIVE_SEND_STATES
                  AND (Link_Expires_At__c = null OR Link_Expires_At__c > :now)
                WITH SYSTEM_MODE
            ];
        }

        List<Id> dueForRead(Id accountId, Datetime readBefore) {
            List<Id> ids = new List<Id>();
            for (Relix_KYC_Case__c row : [
                SELECT Id
                FROM Relix_KYC_Case__c
                WHERE (Account__c = :accountId OR Company_Case__r.Account__c = :accountId)
                  AND Case_Id__c != null
                  AND (Last_Read_At__c = null OR Last_Read_At__c < :readBefore)
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT :MAX_CASES
            ]) {
                ids.add(row.Id);
            }
            return ids;
        }

        // The company's current POA (AurelixPoaResolver), resolved once, with the fields the status shows.
        Contact poa(Id companyId) {
            Id poaId = AurelixPoaResolver.resolve(companyId, null);
            if (poaId == null) {
                return null;
            }
            List<Contact> contacts = [
                SELECT Id, Email, KYC_Status__c, Is_KYC_Link_Active__c FROM Contact WHERE Id = :poaId WITH SYSTEM_MODE LIMIT 1
            ];
            return contacts.isEmpty() ? null : contacts[0];
        }
    }
}