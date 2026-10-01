/**
 * AurelixKycDocumentService - the KYC document placeholders and the required-documents checklist
 * for the Sales Console.
 *
 * Version  Author       Date         Detail
 * 1.10     Aurelix Dev  29 Sep 2026  A regeneration starts a new round: the lock's round start is also the latest
 *                                    DocuSign send of the contact's "KYC Form" (dfsle__EnvelopeStatus__c), or now
 *                                    while a generation is underway. kycRoundStart returns the 1.8 rule alone.
 * 1.9      Aurelix Dev  29 Sep 2026  currentRoundStart and latestFilingOn expose the 1.8 round rule, so
 *                                    AurelixManualKycService 4.16 can file a renewal's signed copy. No rule change.
 * 1.8      Aurelix Dev  29 Sep 2026  Only this round's signed form locks: a "KYC Form - Signed" file counts only if
 *                                    filed on or after the round start, the later of the latest manual KYC request
 *                                    (ProcessInstance) and KYC_Completed_Date__c. Neither known: any file counts.
 * 1.7      Aurelix Dev  29 Sep 2026  An expired KYC ('KYC Expired') opens the files again for the renewal, unless a
 *                                    manual approval (which never expires) is on record.
 * 1.6      Aurelix Dev  29 Sep 2026  A company's signatory rows follow AurelixPoaResolver.bookingSubject (the primary
 *                                    contact, else the POA row), so no POA row is needed. lockCodeForRow unchanged.
 * 1.5      Aurelix Dev  29 Sep 2026  The lock moves to the signed form: files lock once "KYC Form - Signed" holds a
 *                                    file or KYC is Active; generating the form no longer locks. FORM_SIGNED replaces
 *                                    FORM_GENERATED. KYC_FILES_LOCK_ON_MANUAL_APPROVAL stays off.
 * 1.4      Aurelix Dev  29 Sep 2026  replaceFile: files the new version and removes the rep's own earlier file(s) on
 *                                    the row (owner, creator, Origin 'C'; Signzy's are 'H'). Files lock once the KYC
 *                                    form is produced or KYC is Active (manual approval only with its switch).
 * 1.3      Aurelix Dev  28 Sep 2026  The joint owner's manual KYC route: a person who is
 *                                    not on the booking yet, because MODON's JointOwnerTriggerHelper refuses
 *                                    them until their KYC is complete, may have their checklist too. Such a
 *                                    party is accepted when SalesConsoleJointOwnerService.partyProblem says so
 *                                    (a usable person, not the buyer, and a unit that can still take a joint
 *                                    owner). A joint owner already on the booking is accepted as before.
 * 1.2      Aurelix Dev  21 Sep 2026  M12, agreed with MODON on 21 Sep: "KYC Form - Signed" is
 *                                    no longer uploadable. It is produced by the DocuSign chain
 *                                    and filed by AurelixManualKycService.fileSignedCopy, so an
 *                                    Upload on that row only invited a rep to satisfy the gate with
 *                                    the wrong file. The row says canUpload = false, and uploadFile
 *                                    refuses it even if asked directly.
 * 1.1      Aurelix Dev  18 Sep 2026  uploadFile: the checklist's Upload posts the file through
 *                                    here (base64 -> ContentVersion with FirstPublishLocationId =
 *                                    the row), the way the console already files proof images,
 *                                    instead of lightning-file-upload, whose drop-zone widget
 *                                    outweighed the row it sat on. Only a KYC-named Documents__c
 *                                    row the caller can read is accepted; MODON's
 *                                    ContentDocumentLink trigger still marks it Uploaded.
 * 1.0      Aurelix Dev  18 Sep 2026  MSC-175 (B3 + B5).
 *                                    B3 PLACEHOLDERS. In the internal app the Documents__c rows a
 *                                    customer needs come from the Account quick action "Generate
 *                                    Documents" (flow Generate_Customer_Documents ->
 *                                    GenerateCustomerDocumentAccount). The console never ran it,
 *                                    so console-created customers had no rows and nothing to
 *                                    upload onto. ensurePlaceholders now calls the SAME MODON code:
 *                                      person buyer / joint owner
 *                                        GenerateCustomerDocumentAccount.generateCustomerDocuments
 *                                        - the six PersonAccount template rows, on the person
 *                                          contact (EID Front/Back, Passport, KYC Form,
 *                                          KYC Form - Signed, Other Supporting Document)
 *                                      organisation
 *                                        PassfortRelatedEntitiesController.getDocumentRecords on
 *                                        the company (Commercial trade License (Resident),
 *                                        Certificate of Incorporation (Non Resident), Other
 *                                        Supporting Document) and again on the authorised POA
 *                                        Contact (the individual set). The Account template set
 *                                        is NOT used for companies: its licence row is named
 *                                        "TradeLicense", which the booking gate does not check.
 *                                    Both MODON methods skip names that already exist, so this is
 *                                    re-runnable and the console inserts no Documents__c itself.
 *                                    B5 CHECKLIST. getChecklist returns exactly the rows the
 *                                    booking gate and Option 2 test, each with whether a FILE is
 *                                    on it - the same without-sharing presence test the gate
 *                                    makes, so a tick can never disagree with the verdict.
 *
 * OWNERSHIP. Aurelix-owned. Everything it calls or reads is MODON's and is unmodified:
 *   GenerateCustomerDocumentAccount, PassfortRelatedEntitiesController  called
 *   Documents__c, ContentDocumentLink, Attachment, JointOwner__c           read
 *
 * THE MATRIX (what UnitSearchLwcController.checkKYCEligibility v14+ and
 * AurelixKycEligibilityService.evaluateOrganisation actually check, by exact Documents__c.Name):
 *   Person, Resident       KYC Form - Signed, Passport, Emirates/National ID Front, ...Back
 *   Person, Non-Resident   KYC Form - Signed, Passport
 *   Organisation           the POA's rows (1.6: the primary contact's) per THEIR residency, plus
 *                          on the company ONE of Commercial trade License (Resident) /
 *                          Certificate of Incorporation (Non Resident)
 * The checklist never gates anything; the server does.
 */
public with sharing class AurelixKycDocumentService {

    public static final String DOC_SIGNED_KYC = 'KYC Form - Signed';
    public static final String DOC_PASSPORT   = 'Passport';
    public static final String DOC_EID_FRONT  = 'Emirates/National ID Front';
    public static final String DOC_EID_BACK   = 'Emirates/National ID Back';
    public static final String DOC_TRADE_LIC  = 'Commercial trade License (Resident)';
    public static final String DOC_CERT_INC   = 'Certificate of Incorporation (Non Resident)';
    public static final String DOC_KYC_FORM   = 'KYC Form';

    public static final String TYPE_PERSON       = 'Person';
    public static final String TYPE_ORGANISATION = 'Organisation';
    public static final String RESIDENT          = 'Resident';

    public static final String ROLE_BUYER     = 'Buyer';
    public static final String ROLE_OWNER     = 'Joint owner';
    public static final String ROLE_SIGNATORY = 'Signatory';
    public static final String ROLE_COMPANY   = 'Company';

    /* 1.4 - replace on re-upload, and the lock */
    /** MODON's Documents__c.Status__c value for a row that waits for its file. */
    public static final String STATUS_PENDING_UPLOAD = 'Pending Upload';
    /** Why the files are locked. 1.5: FORM_SIGNED replaces FORM_GENERATED. */
    public static final String LOCK_FORM_SIGNED     = 'FORM_SIGNED';
    public static final String LOCK_KYC_ACTIVE      = 'KYC_ACTIVE';
    public static final String LOCK_MANUAL_APPROVED = 'MANUAL_APPROVED';
    /** Sales_Console_Config__mdt switch: does a manual KYC approval lock the files too? No record means off. */
    public static final String FLAG_LOCK_ON_MANUAL_APPROVAL = 'KYC_FILES_LOCK_ON_MANUAL_APPROVAL';
    /** ContentVersion.Origin of a file uploaded as content. Signzy's images are Chatter files ('H'). */
    private static final String ORIGIN_CONTENT = 'C';
    private static final String KYC_ACTIVE = 'KYC Active';
    /** 1.7 - MODON's formula output once ADDMONTHS(KYC_Completed_Date__c, 3) has passed. */
    private static final String KYC_EXPIRED = 'KYC Expired';
    private static final String MANUAL_APPROVED = 'Approved';
    /** 1.8 - MODON's manual KYC approval processes: a person's on the Account, a POA's on the Contact. */
    private static final String MANUAL_KYC_PROCESS         = 'Submit_for_Manual_KYC';
    private static final String MANUAL_KYC_PROCESS_CONTACT = 'Submit_for_Manual_KYC_Contact';

    /** Tests set this instead of the metadata record. */
    @TestVisible private static Boolean manualLockOverride;
    /** 1.8 - tests: the latest manual KYC request by record (no approval process in a test); null reads the org. */
    @TestVisible private static Map<Id, Datetime> manualRequestOverride;
    /** 1.10 - tests: when each "KYC Form" row last went out for signature, by row; null reads the org. */
    @TestVisible private static Map<Id, Datetime> formSendOverride;

    /** One required document and whether a file is on it. */
    public class RowDTO {
        @AuraEnabled public Id documentId;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean hasFile = false;
        @AuraEnabled public Datetime uploadedOn;
        @AuraEnabled public Id fileId;
        /** The company's second acceptable document - "or ...". */
        @AuraEnabled public Boolean alternative = false;
        /** True when a Documents__c row exists to upload onto. 1.4: false on a locked row with a file. */
        @AuraEnabled public Boolean canUpload = false;
        /** 1.4 - the row holds a file the running user uploaded, so Upload replaces it. */
        @AuraEnabled public Boolean replaceable = false;
        /** 1.4 - the row holds a file and the files are locked; no Upload is offered. */
        @AuraEnabled public Boolean locked = false;
    }

    /** One subject: the buyer, a joint owner, the signatory, or the company. */
    public class GroupDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String role;
        @AuraEnabled public String subjectName;
        @AuraEnabled public String residency;
        @AuraEnabled public Id subjectId;
        @AuraEnabled public Boolean isCompany = false;
        /** One of the rows is enough (the company's licence OR certificate). */
        @AuraEnabled public Boolean either = false;
        @AuraEnabled public List<RowDTO> rows = new List<RowDTO>();
        @AuraEnabled public Integer done = 0;
        @AuraEnabled public Integer total = 0;
    }

    public class ChecklistDTO {
        @AuraEnabled public Boolean available = false;
        @AuraEnabled public String blockedReason;
        @AuraEnabled public String customerType;
        @AuraEnabled public List<GroupDTO> groups = new List<GroupDTO>();
        @AuraEnabled public Integer done = 0;
        @AuraEnabled public Integer total = 0;
        /** Rows MODON's methods created during this call; 0 when everything already existed. */
        @AuraEnabled public Integer placeholdersCreated = 0;
        /** 1.4 - why the files on record are locked (LOCK_*), null when they are not. */
        @AuraEnabled public String lockCode;
        /** 1.4 - the same as the sentence the server refuses a replace with. */
        @AuraEnabled public String lockReason;
    }

    public class PlaceholderResultDTO {
        @AuraEnabled public String customerType;
        @AuraEnabled public Integer created = 0;
        @AuraEnabled public String blockedReason;
    }

    /* ── the subjects a booking has ──────────────────────────────────────────── */

    private class Subject {
        Id accountId;
        Id contactId;
        String name;
        String residency;
        String role;
        Boolean isCompany = false;
    }

    private class Resolved {
        String customerType;
        String blockedReason;
        List<Subject> subjects = new List<Subject>();
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * B3 - placeholders, created the way the internal app creates them
     * ══════════════════════════════════════════════════════════════════════════ */

    /**
     * Make sure the booking's subject(s) carry their Documents__c rows. partyAccountId narrows
     * it to one joint owner (who must be on this booking); null means the buyer. Idempotent.
     */
    @AuraEnabled
    public static PlaceholderResultDTO ensurePlaceholders(Id opportunityId, Id partyAccountId) {
        PlaceholderResultDTO out = new PlaceholderResultDTO();
        Resolved r = resolve(opportunityId, partyAccountId);
        out.customerType = r.customerType;
        if (r.blockedReason != null) {
            out.blockedReason = r.blockedReason;
            return out;
        }
        try {
            out.created = createMissing(r.subjects);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return out;
    }

    /** MODON's own creators, one call per subject kind. Returns how many rows appeared. */
    private static Integer createMissing(List<Subject> subjects) {
        Set<Id> parents = new Set<Id>();
        List<Id> personAccounts = new List<Id>();
        List<Id> passfortSubjects = new List<Id>();
        for (Subject s : subjects) {
            if (s.isCompany) {
                if (s.accountId != null) { passfortSubjects.add(s.accountId); parents.add(s.accountId); }
            } else if (s.accountId != null && s.role != ROLE_SIGNATORY) {
                personAccounts.add(s.accountId);
                if (s.contactId != null) { parents.add(s.contactId); }
            } else if (s.contactId != null) {
                passfortSubjects.add(s.contactId);
                parents.add(s.contactId);
            }
        }
        Integer before = countRows(parents);
        if (!personAccounts.isEmpty()) {
            /* the internal app's "Generate Documents" quick action, exactly */
            GenerateCustomerDocumentAccount.generateCustomerDocuments(personAccounts);
        }
        for (Id subjectId : passfortSubjects) {
            /* creates the gate-named rows for a company or a contact; skips existing names */
            PassfortRelatedEntitiesController.getDocumentRecords(subjectId);
        }
        return Math.max(0, countRows(parents) - before);
    }

    private static Integer countRows(Set<Id> parents) {
        if (parents.isEmpty()) { return 0; }
        return [
            SELECT COUNT() FROM Documents__c
            WHERE PrimaryContact__c IN :parents OR Account__c IN :parents
        ];
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * B5 - the checklist
     * ══════════════════════════════════════════════════════════════════════════ */

    /** The document names a subject needs, by customer type and residency. */
    public static List<String> requiredNames(String customerType, String residency) {
        List<String> names = new List<String>{ DOC_SIGNED_KYC, DOC_PASSPORT };
        if (String.isNotBlank(residency) && residency.trim().equalsIgnoreCase(RESIDENT)) {
            names.add(DOC_EID_FRONT);
            names.add(DOC_EID_BACK);
        }
        return names;
    }

    /** The company's acceptable rows, in the order they are offered. */
    public static List<String> companyNames() {
        return new List<String>{ DOC_TRADE_LIC, DOC_CERT_INC };
    }

    /**
     * The checklist for the buyer (partyAccountId null) or for one joint owner. Placeholders are
     * ensured first so the rows to upload onto exist before the list is drawn.
     */
    @AuraEnabled(cacheable=false)
    public static ChecklistDTO getChecklist(Id opportunityId, Id partyAccountId) {
        ChecklistDTO dto = new ChecklistDTO();
        Resolved r = resolve(opportunityId, partyAccountId);
        dto.customerType = r.customerType;
        if (r.blockedReason != null) {
            dto.blockedReason = r.blockedReason;
            return dto;
        }
        try {
            dto.placeholdersCreated = createMissing(r.subjects);
        } catch (Exception e) {
            /* the list still renders - a rep can see what is missing even if creation failed */
            dto.blockedReason = null;
        }

        /* rows for every subject in one query per parent field */
        Set<Id> contactIds = new Set<Id>();
        Set<Id> companyIds = new Set<Id>();
        for (Subject s : r.subjects) {
            if (s.isCompany) { companyIds.add(s.accountId); }
            else if (s.contactId != null) { contactIds.add(s.contactId); }
        }
        Set<String> wanted = new Set<String>{ DOC_SIGNED_KYC, DOC_PASSPORT, DOC_EID_FRONT, DOC_EID_BACK };
        wanted.addAll(companyNames());

        Map<Id, Map<String, List<Documents__c>>> byParent = new Map<Id, Map<String, List<Documents__c>>>();
        Set<Id> allDocIds = new Set<Id>();
        if (!contactIds.isEmpty()) {
            for (Documents__c d : [
                SELECT Id, Name, PrimaryContact__c FROM Documents__c
                WHERE PrimaryContact__c IN :contactIds AND Name IN :wanted
                ORDER BY CreatedDate
            ]) { file(byParent, d.PrimaryContact__c, d); allDocIds.add(d.Id); }
        }
        if (!companyIds.isEmpty()) {
            for (Documents__c d : [
                SELECT Id, Name, Account__c FROM Documents__c
                WHERE Account__c IN :companyIds AND Name IN :wanted
                ORDER BY CreatedDate
            ]) { file(byParent, d.Account__c, d); allDocIds.add(d.Id); }
        }
        FileContext fc = new FileContext();
        Map<Id, FileInfo> files = fc.newestFiles(allDocIds);
        /* 1.4 - rows holding a file this rep uploaded, and whether the subject's files are locked */
        Set<Id> ownRows = fc.ownFiles(allDocIds).keySet();
        String lock = lockCodeFor(lockSubject(r.subjects));
        Boolean isLocked = lock != null;
        dto.lockCode   = lock;
        dto.lockReason = lockSentence(lock);

        for (Subject s : r.subjects) {
            GroupDTO g = new GroupDTO();
            g.role        = s.role;
            g.subjectName = s.name;
            g.residency   = s.residency;
            g.subjectId   = s.isCompany ? s.accountId : s.contactId;
            g.isCompany   = s.isCompany;
            g.key         = s.role + '-' + String.valueOf(g.subjectId);
            Map<String, List<Documents__c>> rows = byParent.get(g.subjectId);

            if (s.isCompany) {
                g.either = true;
                Boolean anyFile = false;
                Integer i = 0;
                for (String name : companyNames()) {
                    RowDTO row = rowFor(name, rows, files, ownRows, isLocked);
                    row.alternative = i > 0;
                    if (row.hasFile) { anyFile = true; }
                    g.rows.add(row);
                    i++;
                }
                g.total = 1;
                g.done  = anyFile ? 1 : 0;
            } else {
                for (String name : requiredNames(TYPE_PERSON, s.residency)) {
                    RowDTO row = rowFor(name, rows, files, ownRows, isLocked);
                    if (row.hasFile) { g.done++; }
                    g.rows.add(row);
                }
                g.total = g.rows.size();
            }
            dto.groups.add(g);
            dto.done  += g.done;
            dto.total += g.total;
        }
        dto.available = true;
        return dto;
    }

    private static void file(Map<Id, Map<String, List<Documents__c>>> byParent, Id parent, Documents__c d) {
        if (parent == null) { return; }
        if (!byParent.containsKey(parent)) { byParent.put(parent, new Map<String, List<Documents__c>>()); }
        Map<String, List<Documents__c>> m = byParent.get(parent);
        if (!m.containsKey(d.Name)) { m.put(d.Name, new List<Documents__c>()); }
        m.get(d.Name).add(d);
    }

    /**
     * Where several rows share a name, the one with a file wins; else the oldest.
     * 1.4: ownRows hold a file the running user uploaded; isLocked takes Upload off a row with a file.
     */
    private static RowDTO rowFor(String name, Map<String, List<Documents__c>> rows, Map<Id, FileInfo> files,
                                 Set<Id> ownRows, Boolean isLocked) {
        RowDTO row = new RowDTO();
        row.name = name;
        List<Documents__c> candidates = rows == null ? null : rows.get(name);
        if (candidates == null || candidates.isEmpty()) { return row; }
        Documents__c chosen = candidates[0];
        for (Documents__c d : candidates) {
            if (files.containsKey(d.Id)) { chosen = d; break; }
        }
        row.documentId = chosen.Id;
        /* 1.2: the signed form arrives from DocuSign, never from a rep's upload */
        row.canUpload  = name != DOC_SIGNED_KYC;
        FileInfo f = files.get(chosen.Id);
        if (f != null) {
            row.hasFile    = true;
            row.fileId     = f.fileId;
            row.uploadedOn = f.uploadedOn;
        }
        /* 1.4 - a locked row keeps what it holds; an empty one can still be filled */
        if (row.canUpload && row.hasFile && isLocked == true) {
            row.locked    = true;
            row.canUpload = false;
        }
        row.replaceable = row.canUpload && ownRows != null && ownRows.contains(chosen.Id);
        return row;
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 1.4 - the lock
     * ══════════════════════════════════════════════════════════════════════════ */

    /** Whose KYC state locks this checklist: the person, or for a company its signatory (the POA). */
    private static Id lockSubject(List<Subject> subjects) {
        for (Subject s : subjects) {
            if (s.isCompany != true && s.contactId != null) { return s.contactId; }
        }
        return null;
    }

    /** The plain sentence for a lock code; null for none. */
    public static String lockSentence(String code) {
        if (code == LOCK_FORM_SIGNED) {
            return 'The signed KYC form is on file, so files on record can no longer be replaced.';
        }
        if (code == LOCK_KYC_ACTIVE) {
            return 'KYC is complete, so files on record can no longer be replaced.';
        }
        if (code == LOCK_MANUAL_APPROVED) {
            return 'Manual KYC is approved, so files on record can no longer be replaced.';
        }
        return null;
    }

    /**
     * Why a contact's files are locked, or null. The contact is a person's own contact or a company's
     * POA. 1.5: a file on "KYC Form - Signed", KYC Active, or (only with its switch) a manual approval.
     * 1.7: an expired KYC is not locked unless manually approved. 1.8: only a form signed this round locks.
     */
    public static String lockCodeFor(Id contactId) {
        if (contactId == null) { return null; }
        return new StateContext().lockCode(contactId);
    }

    /**
     * 1.9 - when this contact's current KYC round began, as the lock reads it; null when unknown. For
     * AurelixManualKycService 4.16 (filing a renewal's signed copy).
     */
    public static Datetime currentRoundStart(Id contactId) {
        if (contactId == null) { return null; }
        return new StateContext().roundStartFor(contactId);
    }

    /**
     * 1.10 - the KYC round alone (the 1.8 rule, without the latest form send), so AurelixManualKycService
     * can tell this round's form from last round's. Null when unknown.
     */
    public static Datetime kycRoundStart(Id contactId) {
        if (contactId == null) { return null; }
        StateContext ctx = new StateContext();
        Contact c = ctx.subject(contactId);
        return c == null ? null : ctx.kycRoundStartOf(c);
    }

    /** 1.9 - when the newest file on these rows was filed (without sharing); null when none. */
    public static Datetime latestFilingOn(Set<Id> rowIds) {
        return new FileContext().latestFiling(rowIds);
    }

    /** A row's subject: its contact, or for a company's own row the company's POA. */
    private static String lockCodeForRow(Documents__c row) {
        Id contactId = row.PrimaryContact__c;
        if (contactId == null && row.Account__c != null) {
            for (Account a : [
                SELECT Id, IsPersonAccount, PersonContactId FROM Account WHERE Id = :row.Account__c LIMIT 1
            ]) {
                contactId = a.IsPersonAccount == true ? a.PersonContactId : AurelixPoaResolver.resolve(a.Id, null);
            }
        }
        return lockCodeFor(contactId);
    }

    /** KYC_FILES_LOCK_ON_MANUAL_APPROVAL. No record means off. */
    private static Boolean manualApprovalLocks() {
        if (manualLockOverride != null) { return manualLockOverride; }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(FLAG_LOCK_ON_MANUAL_APPROVAL);
        return cfg != null && cfg.Is_Active__c == true;
    }

    private static Boolean isActive(String kycStatus) {
        return kycStatus != null && kycStatus.trim().equalsIgnoreCase(KYC_ACTIVE);
    }

    /** 1.7 */
    private static Boolean isExpired(String kycStatus) {
        return kycStatus != null && kycStatus.trim().equalsIgnoreCase(KYC_EXPIRED);
    }

    /** 1.7 */
    private static Boolean isApproved(String manualApproval) {
        return manualApproval != null && manualApproval.trim().equalsIgnoreCase(MANUAL_APPROVED);
    }

    /**
     * 1.8 - the round start: the later of the latest manual KYC request and the start of the completion
     * day (running user's time zone). Null when neither is known.
     */
    @TestVisible
    private static Datetime roundStart(Datetime lastManualRequest, Date completed) {
        Datetime fromCompletion = completed == null
            ? null : Datetime.newInstance(completed, Time.newInstance(0, 0, 0, 0));
        return laterOf(lastManualRequest, fromCompletion);
    }

    /** 1.8 - the later of two moments; a missing one gives way. */
    private static Datetime laterOf(Datetime a, Datetime b) {
        if (a == null) { return b; }
        if (b == null) { return a; }
        return a > b ? a : b;
    }

    /** 1.8 - the later of two dates; a missing one gives way. */
    private static Date laterDate(Date a, Date b) {
        if (a == null) { return b; }
        if (b == null) { return a; }
        return a > b ? a : b;
    }

    /* 1.8 - the manual KYC definition's Id by name, once per transaction, as AurelixManualKycService 4.4
       reads it. Null if unreadable. */
    private static Map<String, Id> manualProcessIds = new Map<String, Id>();
    private static Id manualKycProcessId(Boolean onContact) {
        String objectName = onContact == true ? 'Contact' : 'Account';
        if (!manualProcessIds.containsKey(objectName)) {
            String name = onContact == true ? MANUAL_KYC_PROCESS_CONTACT : MANUAL_KYC_PROCESS;
            Id found;
            try {
                for (ProcessDefinition d : [
                    SELECT Id FROM ProcessDefinition
                    WHERE DeveloperName = :name AND TableEnumOrId = :objectName
                    LIMIT 1
                ]) {
                    found = d.Id;
                }
            } catch (Exception e) {
                found = null;
            }
            manualProcessIds.put(objectName, found);
        }
        return manualProcessIds.get(objectName);
    }

    /**
     * Which of the named rows on a contact carry a file. Used by the generation gate for the
     * identity-proof presence test; the same without-sharing check as the checklist.
     */
    public static Set<String> namesWithFile(Id contactId, List<String> names) {
        Set<String> present = new Set<String>();
        if (contactId == null || names == null || names.isEmpty()) { return present; }
        Map<Id, String> nameById = new Map<Id, String>();
        for (Documents__c d : [
            SELECT Id, Name FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name IN :names
        ]) { nameById.put(d.Id, d.Name); }
        Map<Id, FileInfo> files = new FileContext().newestFiles(nameById.keySet());
        for (Id docId : files.keySet()) { present.add(nameById.get(docId)); }
        return present;
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 1.1 - upload onto a row
     * ══════════════════════════════════════════════════════════════════════════ */

    private static final Map<String, String> EXT_TO_MIME = new Map<String, String>{
        'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'pdf' => 'application/pdf'
    };
    /** Same ceiling as the console's proof capture (4 MB decoded). */
    public static final Integer MAX_BYTES = 4 * 1024 * 1024;

    /** The names this endpoint files onto - the checklist's rows, nothing else. */
    private static Set<String> uploadableNames() {
        /* 1.2: not DOC_SIGNED_KYC - that row is filled by the DocuSign chain only */
        Set<String> names = new Set<String>{ DOC_PASSPORT, DOC_EID_FRONT, DOC_EID_BACK };
        names.addAll(companyNames());
        return names;
    }

    /**
     * File a document onto one of the checklist's rows. Returns the new ContentVersion Id.
     * Refused for any row that is not a KYC row the caller can read.
     * 1.4: adds; refused on a row that already holds a file once the files are locked.
     */
    @AuraEnabled
    public static Id uploadFile(Id documentId, String base64Data, String fileName) {
        return fileOnto(documentId, base64Data, fileName, false);
    }

    /**
     * 1.4 - the same, and then the running user's own earlier file(s) on the row are removed, in the
     * same transaction. Anybody else's file stays. Refused once the files are locked.
     */
    @AuraEnabled
    public static Id replaceFile(Id documentId, String base64Data, String fileName) {
        return fileOnto(documentId, base64Data, fileName, true);
    }

    private static Id fileOnto(Id documentId, String base64Data, String fileName, Boolean replace) {
        if (documentId == null) {
            throw new AuraHandledException('No document row was supplied.');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('The file was empty.');
        }
        String safeName = String.isBlank(fileName) ? 'document.pdf' : fileName.trim();
        String ext = safeName.contains('.') ? safeName.substringAfterLast('.').toLowerCase() : '';
        if (!EXT_TO_MIME.containsKey(ext)) {
            throw new AuraHandledException('That file type is not supported. Use a JPG, PNG or PDF.');
        }
        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('The file could not be read.');
        }
        if (body.size() > MAX_BYTES) {
            throw new AuraHandledException('That file is too large. The limit is 4 MB.');
        }
        /* with sharing: the row must be readable by the caller and be a KYC row */
        List<Documents__c> rows = [
            SELECT Id, Name, PrimaryContact__c, Account__c FROM Documents__c WHERE Id = :documentId LIMIT 1
        ];
        if (rows.isEmpty() || !uploadableNames().contains(rows[0].Name)) {
            throw new AuraHandledException('That document row cannot be uploaded to from here.');
        }

        /* 1.4 - locked: nothing is replaced, and a row that holds a file keeps it as it is */
        FileContext fc = new FileContext();
        Boolean hasFile = !fc.newestFiles(new Set<Id>{ documentId }).isEmpty();
        String lock = lockCodeForRow(rows[0]);
        if (lock != null && (replace == true || hasFile)) {
            throw refusal(lockSentence(lock));
        }
        /* 1.4 - read before the insert, so the new file can never be among them */
        List<OwnFile> mine = replace == true ? fc.ownFiles(new Set<Id>{ documentId }).get(documentId) : null;

        Savepoint sp = Database.setSavepoint();
        try {
            ContentVersion cv = new ContentVersion(
                Title = safeName, PathOnClient = safeName, VersionData = body,
                FirstPublishLocationId = documentId);
            insert cv;
            if (mine != null && !mine.isEmpty()) {
                removeOwn(documentId, mine);
                restorePendingIfEmpty(documentId);
            }
            return cv.Id;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw refusal(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw refusal(e.getMessage());
        }
    }

    /**
     * 1.4 - removes the rep's own earlier files from a row in user mode: deleted when only on this row,
     * else unlinked from it.
     */
    private static void removeOwn(Id rowId, List<OwnFile> mine) {
        List<ContentDocument> toDelete = new List<ContentDocument>();
        Set<Id> toUnlink = new Set<Id>();
        for (OwnFile f : mine) {
            if (f.places.size() == 1 && f.places.contains(rowId)) {
                toDelete.add(new ContentDocument(Id = f.contentDocumentId));
            } else {
                toUnlink.add(f.contentDocumentId);
            }
        }
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete, true, AccessLevel.USER_MODE);
        }
        if (!toUnlink.isEmpty()) {
            Database.delete([
                SELECT Id FROM ContentDocumentLink
                WHERE LinkedEntityId = :rowId AND ContentDocumentId IN :toUnlink
            ], true, AccessLevel.USER_MODE);
        }
    }

    /**
     * 1.4 - a row left with no file goes back to Pending Upload (MODON's trigger never resets it).
     * Without sharing: the rep cannot edit Documents__c.
     */
    @TestVisible
    private static void restorePendingIfEmpty(Id rowId) {
        if (rowId == null) { return; }
        if (!new FileContext().newestFiles(new Set<Id>{ rowId }).isEmpty()) { return; }
        new StatusContext().setPending(rowId);
    }

    /** An AuraHandledException whose getMessage() is the sentence too (tests read it). */
    private static AuraHandledException refusal(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /* ── resolution ─────────────────────────────────────────────────────────── */

    private static Resolved resolve(Id opportunityId, Id partyAccountId) {
        Resolved r = new Resolved();
        if (opportunityId == null) {
            r.blockedReason = 'No booking was provided.';
            return r;
        }
        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__c,
                   Account.Name, Account.IsPersonAccount, Account.PersonContactId,
                   Account.UAE_Resident_Status__pc, Account.RecordType.Name
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].AccountId == null) {
            r.blockedReason = 'This booking has no customer yet.';
            return r;
        }
        Opportunity opp = opps[0];

        /* a joint owner: must be a party on this booking, and a person.
           1.3: or a person the rep is about to add (the joint owner's manual KYC route) */
        if (partyAccountId != null && partyAccountId != opp.AccountId) {
            if (!new PartyContext().onBooking(opportunityId, partyAccountId)) {
                String problem = SalesConsoleJointOwnerService.partyProblem(opportunityId, partyAccountId);
                if (problem != null) {
                    r.blockedReason = problem;
                    return r;
                }
            }
            List<Account> parties = [
                SELECT Id, Name, IsPersonAccount, PersonContactId, UAE_Resident_Status__pc
                FROM Account WHERE Id = :partyAccountId LIMIT 1
            ];
            if (parties.isEmpty() || parties[0].IsPersonAccount != true) {
                r.blockedReason = 'Only a person has identity documents of their own.';
                return r;
            }
            r.customerType = TYPE_PERSON;
            Subject s = new Subject();
            s.accountId = parties[0].Id;
            s.contactId = parties[0].PersonContactId;
            s.name      = parties[0].Name;
            s.residency = parties[0].UAE_Resident_Status__pc;
            s.role      = ROLE_OWNER;
            r.subjects.add(s);
            return r;
        }

        if (opp.Account.IsPersonAccount == true) {
            r.customerType = TYPE_PERSON;
            Subject s = new Subject();
            s.accountId = opp.AccountId;
            s.contactId = opp.Account.PersonContactId != null ? opp.Account.PersonContactId : opp.PrimaryContact__c;
            s.name      = opp.Account.Name;
            s.residency = opp.Account.UAE_Resident_Status__pc;
            s.role      = ROLE_BUYER;
            r.subjects.add(s);
            return r;
        }

        r.customerType = TYPE_ORGANISATION;
        /* 1.6 - the primary contact (the POA, as MODON's gate reads it); a POA row only when none is set */
        Id poaId = AurelixPoaResolver.bookingSubject(opp.AccountId, opp.PrimaryContact__c);
        if (poaId == null) {
            r.blockedReason = 'Primary Contact is not set on this booking.';
            return r;
        }
        for (Contact c : [SELECT Id, Name, UAE_Resident_Status__c FROM Contact WHERE Id = :poaId LIMIT 1]) {
            Subject s = new Subject();
            s.accountId = opp.AccountId;
            s.contactId = c.Id;
            s.name      = c.Name;
            s.residency = c.UAE_Resident_Status__c;
            s.role      = ROLE_SIGNATORY;
            r.subjects.add(s);
        }
        Subject co = new Subject();
        co.accountId = opp.AccountId;
        co.name      = opp.Account.Name;
        co.role      = ROLE_COMPANY;
        co.isCompany = true;
        r.subjects.add(co);
        return r;
    }

    /* ── without sharing: files and party membership ─────────────────────────── */

    public class FileInfo {
        public Id fileId;
        public Datetime uploadedOn;
    }

    /**
     * File presence WITHOUT SHARING, deliberately: a document uploaded by somebody else - Sales
     * Operations, the DocuSign callback, the customer through Signzy - must still count. The
     * same rule the eligibility service applies.
     */
    private without sharing class FileContext {
        Map<Id, FileInfo> newestFiles(Set<Id> parentIds) {
            Map<Id, FileInfo> out = new Map<Id, FileInfo>();
            if (parentIds == null || parentIds.isEmpty()) { return out; }
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId, ContentDocumentId, ContentDocument.ContentModifiedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :parentIds
            ]) {
                Datetime stamp = l.ContentDocument == null ? null : l.ContentDocument.ContentModifiedDate;
                FileInfo held = out.get(l.LinkedEntityId);
                if (held == null || (stamp != null && (held.uploadedOn == null || stamp > held.uploadedOn))) {
                    FileInfo f = new FileInfo();
                    f.fileId = l.ContentDocumentId;
                    f.uploadedOn = stamp;
                    out.put(l.LinkedEntityId, f);
                }
            }
            /* classic attachments still count, as they do for the gate */
            for (Attachment a : [
                SELECT Id, ParentId, CreatedDate FROM Attachment WHERE ParentId IN :parentIds
            ]) {
                if (!out.containsKey(a.ParentId)) {
                    FileInfo f = new FileInfo();
                    f.uploadedOn = a.CreatedDate;
                    out.put(a.ParentId, f);
                }
            }
            return out;
        }

        /**
         * 1.8 - when the newest file on these rows was filed (creation or ContentModifiedDate, or an
         * attachment's creation); null when none. Unreadable dates count as now, keeping the lock on.
         */
        Datetime latestFiling(Set<Id> parentIds) {
            Datetime latest;
            if (parentIds == null || parentIds.isEmpty()) { return latest; }
            for (ContentDocumentLink l : [
                SELECT ContentDocumentId, ContentDocument.CreatedDate, ContentDocument.ContentModifiedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :parentIds
            ]) {
                Datetime stamp = l.ContentDocument == null ? null
                    : laterOf(l.ContentDocument.CreatedDate, l.ContentDocument.ContentModifiedDate);
                latest = laterOf(latest, stamp == null ? Datetime.now() : stamp);
            }
            for (Attachment a : [
                SELECT CreatedDate FROM Attachment WHERE ParentId IN :parentIds
            ]) {
                latest = laterOf(latest, a.CreatedDate == null ? Datetime.now() : a.CreatedDate);
            }
            return latest;
        }

        /**
         * 1.4 - per row, the running user's own files: owner and creator are the user and the latest
         * version is not a Chatter file (Signzy's are). Each carries every non-person record it sits on
         * (read without sharing), so the caller can tell delete from unlink.
         */
        Map<Id, List<OwnFile>> ownFiles(Set<Id> rowIds) {
            Map<Id, List<OwnFile>> out = new Map<Id, List<OwnFile>>();
            if (rowIds == null || rowIds.isEmpty()) { return out; }
            Id me = UserInfo.getUserId();
            Map<Id, Set<Id>> rowsByFile = new Map<Id, Set<Id>>();
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId, ContentDocumentId, ContentDocument.OwnerId, ContentDocument.CreatedById
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :rowIds
            ]) {
                if (l.ContentDocument == null
                        || l.ContentDocument.OwnerId != me || l.ContentDocument.CreatedById != me) {
                    continue;
                }
                if (!rowsByFile.containsKey(l.ContentDocumentId)) {
                    rowsByFile.put(l.ContentDocumentId, new Set<Id>());
                }
                rowsByFile.get(l.ContentDocumentId).add(l.LinkedEntityId);
            }
            if (rowsByFile.isEmpty()) { return out; }

            Set<Id> uploaded = new Set<Id>();
            for (ContentVersion v : [
                SELECT ContentDocumentId, Origin FROM ContentVersion
                WHERE ContentDocumentId IN :rowsByFile.keySet() AND IsLatest = true
            ]) {
                if (v.Origin == ORIGIN_CONTENT) { uploaded.add(v.ContentDocumentId); }
            }
            if (uploaded.isEmpty()) { return out; }

            Map<Id, Set<Id>> places = new Map<Id, Set<Id>>();
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink
                WHERE ContentDocumentId IN :uploaded
            ]) {
                if (l.LinkedEntityId == null || l.LinkedEntityId.getSobjectType() == User.SObjectType) {
                    continue;
                }
                if (!places.containsKey(l.ContentDocumentId)) {
                    places.put(l.ContentDocumentId, new Set<Id>());
                }
                places.get(l.ContentDocumentId).add(l.LinkedEntityId);
            }

            for (Id fileId : uploaded) {
                OwnFile f = new OwnFile();
                f.contentDocumentId = fileId;
                f.places = places.containsKey(fileId) ? places.get(fileId) : new Set<Id>();
                for (Id rowId : rowsByFile.get(fileId)) {
                    if (!out.containsKey(rowId)) { out.put(rowId, new List<OwnFile>()); }
                    out.get(rowId).add(f);
                }
            }
            return out;
        }
    }

    /** 1.4 - one of the rep's own files, and every record (not person) it sits on. */
    public class OwnFile {
        public Id contentDocumentId;
        public Set<Id> places = new Set<Id>();
    }

    /** 1.4 - the one field write the guard needs; see restorePendingIfEmpty. */
    private without sharing class StatusContext {
        void setPending(Id rowId) {
            update new Documents__c(Id = rowId, Status__c = STATUS_PENDING_UPLOAD);
        }
    }

    /**
     * 1.4 - the subject's KYC state, read without sharing so a record out of the rep's sight cannot
     * open the lock. 1.8: the approval history too.
     */
    private without sharing class StateContext {
        /** 1.9 - the subject's KYC facts the lock and the round start read; null when not found. */
        Contact subject(Id contactId) {
            for (Contact c : [
                SELECT Id, AccountId, IsPersonAccount, KYC_Status__c, KYC_Completed_Date__c, Manual_KYC_Approval__c,
                       Account.KYC_Status__c, Account.KYC_Completed_Date__c, Account.Manual_KYC_Approval__c
                FROM Contact WHERE Id = :contactId LIMIT 1
            ]) {
                return c;
            }
            return null;
        }

        /** 1.9 - currentRoundStart: the round start for a contact, as lockCode reads it. */
        Datetime roundStartFor(Id contactId) {
            Contact c = subject(contactId);
            return c == null ? null : roundStartOf(c);
        }

        /**
         * 1.8 - the later of the latest manual KYC request (a person's Account, a POA's Contact) and the
         * completion date. 1.9: moved out of lockCode unchanged.
         * 1.10 - and the latest send of the contact's KYC form, or now while a generation is on its way.
         */
        Datetime roundStartOf(Contact c) {
            return laterOf(kycRoundStartOf(c), formRoundStart(c.Id));
        }

        /** 1.10 - the 1.8 rule alone, as it was before the form send joined it. */
        Datetime kycRoundStartOf(Contact c) {
            Boolean person = c.IsPersonAccount == true && c.Account != null;
            return roundStart(
                latestManualRequest(person ? c.AccountId : c.Id, !person),
                person ? laterDate(c.Account.KYC_Completed_Date__c, c.KYC_Completed_Date__c)
                       : c.KYC_Completed_Date__c);
        }

        /**
         * 1.10 - when the contact's KYC form last went out: the newest DocuSign envelope on its "KYC Form"
         * rows, or now while a generation is underway. Null when neither.
         */
        Datetime formRoundStart(Id contactId) {
            if (contactId == null) { return null; }
            List<Documents__c> rows = [
                SELECT Id, Document_Status__c, Document_Error_Message__c, EnvelopID__c,
                       Auto_Generate_Document__c, Auto_Send_DocuSign_Email__c
                FROM Documents__c
                WHERE PrimaryContact__c = :contactId AND Name = :DOC_KYC_FORM
            ];
            if (rows.isEmpty()) { return null; }
            for (Documents__c r : rows) {
                if (AurelixKycGenerationGate.generationUnderway(r)) { return Datetime.now(); }
            }
            return latestFormSend(new Map<Id, Documents__c>(rows).keySet());
        }

        /**
         * 1.10 - the newest envelope sourced from these rows (dfsle__EnvelopeStatus__c, read dynamically).
         * Null when none or unreadable.
         */
        Datetime latestFormSend(Set<Id> rowIds) {
            if (formSendOverride != null) {
                Datetime latest;
                for (Id r : rowIds) { latest = laterOf(latest, formSendOverride.get(r)); }
                return latest;
            }
            Set<String> sources = new Set<String>();
            for (Id r : rowIds) {
                sources.add(String.valueOf(r));
                sources.add(String.valueOf(r).left(15));
            }
            Datetime latest;
            try {
                for (SObject e : Database.query(
                        'SELECT dfsle__Sent__c, CreatedDate FROM dfsle__EnvelopeStatus__c '
                        + 'WHERE dfsle__SourceId__c IN :sources ORDER BY CreatedDate DESC LIMIT 50')) {
                    Datetime sent = (Datetime) e.get('dfsle__Sent__c');
                    latest = laterOf(latest, sent != null ? sent : (Datetime) e.get('CreatedDate'));
                }
            } catch (Exception ex) {
                return null;
            }
            return latest;
        }

        String lockCode(Id contactId) {
            Contact c = subject(contactId);
            if (c == null) { return null; }
            Boolean person = c.IsPersonAccount == true && c.Account != null;

            /* MODON's formula: a person's on the Account, a POA's on the Contact */
            if (isActive(c.KYC_Status__c) || (person && isActive(c.Account.KYC_Status__c))) {
                return LOCK_KYC_ACTIVE;
            }

            /* 1.7 - KYC expired: the files open again for the renewal, unless manually approved (that never
               expires, so the signed-form lock below still applies) */
            Boolean approved = isApproved(person ? c.Account.Manual_KYC_Approval__c : c.Manual_KYC_Approval__c);
            if (!approved && (isExpired(c.KYC_Status__c) || (person && isExpired(c.Account.KYC_Status__c)))) {
                return null;
            }

            /* 1.5 - the signed form is on file ("KYC Form - Signed"); a generated form no longer locks.
               1.8 - only if filed in the current round (see roundStartOf).
               1.10 - a regenerated form starts a new round, so the files open until it is signed. */
            Set<Id> signedRows = new Map<Id, Documents__c>([
                SELECT Id FROM Documents__c
                WHERE PrimaryContact__c = :contactId AND Name = :DOC_SIGNED_KYC
            ]).keySet();
            Datetime lastFiled = new FileContext().latestFiling(signedRows);
            if (lastFiled != null) {
                Datetime since = roundStartOf(c);
                if (since == null || lastFiled >= since) {
                    return LOCK_FORM_SIGNED;
                }
            }

            /* only while the switch is on (off by business decision); see the 1.4 and 1.5 headers */
            if (approved && manualApprovalLocks()) {
                return LOCK_MANUAL_APPROVED;
            }
            return null;
        }

        /**
         * 1.8 - when the latest manual KYC request on this record was submitted (ProcessInstance, picked in
         * Apex by definition as AurelixManualKycService 4.4 does). Unreadable: null, the completion date decides.
         */
        Datetime latestManualRequest(Id targetId, Boolean onContact) {
            if (targetId == null) { return null; }
            if (manualRequestOverride != null) { return manualRequestOverride.get(targetId); }
            Id processId = manualKycProcessId(onContact);
            if (processId == null) { return null; }
            try {
                for (ProcessInstance pi : [
                    SELECT CreatedDate, ProcessDefinitionId FROM ProcessInstance
                    WHERE TargetObjectId = :targetId
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ]) {
                    if (pi.ProcessDefinitionId == processId) { return pi.CreatedDate; }
                }
            } catch (Exception e) {
                return null;
            }
            return null;
        }
    }

    /** Is this Account a joint owner on a Sales Order of this booking? */
    private without sharing class PartyContext {
        Boolean onBooking(Id opportunityId, Id accountId) {
            return [
                SELECT COUNT() FROM JointOwner__c
                WHERE JointOwnerAccount__c = :accountId
                  AND SalesOrder__r.Opportunity__c = :opportunityId
            ] > 0;
        }
    }
}