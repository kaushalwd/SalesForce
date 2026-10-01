/**
 * @description Controller for the Account Merge LWC (accountMergeFinder).
 *
 * Org-specific field API names:
 *   ERP ID      : OraclePartyId__c
 *   Passport    : PassportNumber__pc
 *   Emirates ID : EIDNumber__pc
 *   Sales Order : SalesOrder__c, lookup CustomerAccount__c
 *   Error log   : Merge_Error__c   (Long Text Area — NEW)
 *   Comment     : Merge_Comment__c (Long Text Area — NEW, mandatory on submit)
 *
 * Master selection rules:
 *   PORTAL → IsCustomerPortal = true (must also have OraclePartyId__c)
 *   ERP    → any record with OraclePartyId__c
 *   ANY    → no ERP exists, any record can be master
 *
 * Merge_Error__c lifecycle:
 *   • Written by AccountMergeQueueable when it fails
 *   • Blocks re-submission via submitMergeRequest() guard
 *   • Cleared by clearMergeError() → also resets master + victims
 *   • Cleared on Rejected / Recalled by AccountMergeApprovalHandler
 *
 * Merge_Comment__c lifecycle:
 *   • Mandatory — set by saveFieldOverrides() before submission
 *   • Contains field labels of values copied from child (comma-separated)
 *     plus any free-text notes entered by the user
 *   • Cleared on Rejected / Recalled / Error reset
 */
public with sharing class AccountMergeController {

    // ─────────────────────────────────────────────────────────────────────
    // Inner classes
    // ─────────────────────────────────────────────────────────────────────

    public class DuplicateResult {
        @AuraEnabled public AccountWrapper       sourceAccount;
        @AuraEnabled public List<AccountWrapper> accounts;
        @AuraEnabled public CountWrapper         counts;
        @AuraEnabled public String               suggestedMasterId;
        @AuraEnabled public String               masterSelectionRule; // PORTAL | ERP | ANY
        @AuraEnabled public String               currentUserName;     // for auto-generated comment
    }

    public class AccountWrapper {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  accountNumber;
        @AuraEnabled public String  erpId;
        @AuraEnabled public Boolean hasErpId;
        @AuraEnabled public Boolean isPortalUser;
        @AuraEnabled public Boolean isPersonAccount;
        @AuraEnabled public String  recordTypeDeveloperName;
        @AuraEnabled public Integer salesOrderCount;
        @AuraEnabled public Boolean matchPassport;
        @AuraEnabled public Boolean matchEid;
        @AuraEnabled public Boolean matchMobile;
        @AuraEnabled public Boolean matchEmail;
        @AuraEnabled public String  mergeStatus;
        @AuraEnabled public String  mergeError;       // Merge_Error__c — surfaced to LWC
        @AuraEnabled public Boolean hasMergeError;    // convenience flag
        @AuraEnabled public Boolean canBeMaster;
    }

    public class CountWrapper {
        @AuraEnabled public Integer all;
        @AuraEnabled public Integer passport;
        @AuraEnabled public Integer eid;
        @AuraEnabled public Integer mobile;
        @AuraEnabled public Integer email;
    }

    public class ComparisonRow {
        @AuraEnabled public String       fieldApiName;
        @AuraEnabled public String       fieldLabel;
        @AuraEnabled public String       fieldType;
        @AuraEnabled public Boolean      isEditable;
        @AuraEnabled public String       section;
        @AuraEnabled public String       helpText;
        @AuraEnabled public Boolean      isNewSection;
        @AuraEnabled public String       masterValue;
        @AuraEnabled public List<String> childValues;
        @AuraEnabled public Boolean      hasDifference;
    }

    public class ComparisonResult {
        @AuraEnabled public List<ComparisonRow> rows;
        @AuraEnabled public List<String>        childNames;
        @AuraEnabled public List<String>        childIds;
        @AuraEnabled public String              recordTypeName;
    }

    public class SubmittedMergeRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  accountNumber;
        @AuraEnabled public Boolean isMaster;
    }

    // ─────────────────────────────────────────────────────────────────────
    // getAccountDuplicates
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static DuplicateResult getAccountDuplicates(Id accountId) {
        try {
            Account src = [
                SELECT Id, Name, AccountNumber, OraclePartyId__c,
                       IsPersonAccount, IsCustomerPortal,
                       Merge_Status__c, Merge_Error__c,
                       PassportNumber__pc, EIDNumber__pc,
                       PersonEmail, PersonMobilePhone,
                       UnifiedNumber__c, UAEVATRegisterNumber__c, TradeLicenseNumber__c,
                       Source_Entity__c, Source_Entity__pc,
                       RecordType.DeveloperName
                FROM   Account
                WHERE  Id = :accountId
                AND    Is_Merged__c = false
                AND    Source_Entity__c  != 'Modon - Egypt'
                AND    Source_Entity__pc != 'Modon - Egypt'
                LIMIT  1
            ];

            // ── Person Account matching fields ────────────────────────────
            String srcPassport = src.PassportNumber__pc;
            String srcEid      = src.EIDNumber__pc;
            String srcMobile   = src.PersonMobilePhone;
            String srcEmail    = src.PersonEmail;

            // ── Organisation Account matching fields ──────────────────────
            String srcUnified  = src.UnifiedNumber__c;
            String srcVat      = src.UAEVATRegisterNumber__c;
            String srcTrade    = src.TradeLicenseNumber__c;

            List<String> orClauses = new List<String>();
            if (src.IsPersonAccount) {
                // Person Account — match by identity fields (NO changes to this block)
                if (String.isNotBlank(srcPassport)) orClauses.add('PassportNumber__pc    = :srcPassport');
                if (String.isNotBlank(srcEid))      orClauses.add('EIDNumber__pc         = :srcEid');
                if (String.isNotBlank(srcMobile))   orClauses.add('PersonMobilePhone     = :srcMobile');
                if (String.isNotBlank(srcEmail))    orClauses.add('PersonEmail           = :srcEmail');
            } else {
                // Organisation Account — match by UAE business registration fields
                if (String.isNotBlank(srcUnified)) orClauses.add('UnifiedNumber__c      = :srcUnified');
                if (String.isNotBlank(srcVat))     orClauses.add('UAEVATRegisterNumber__c = :srcVat');
                if (String.isNotBlank(srcTrade))   orClauses.add('TradeLicenseNumber__c = :srcTrade');
            }

            List<Account> dupes = new List<Account>();
            if (!orClauses.isEmpty()) {
                String typeFilter = src.IsPersonAccount
                    ? 'AND IsPersonAccount = true '
                    : 'AND IsPersonAccount = false ';
                String soql =
                    'SELECT Id, Name, AccountNumber, OraclePartyId__c, '
                  + 'IsPersonAccount, IsCustomerPortal, Merge_Status__c, Merge_Error__c, '
                  + 'PassportNumber__pc, EIDNumber__pc, PersonEmail, PersonMobilePhone, '
                  + 'UnifiedNumber__c, UAEVATRegisterNumber__c, TradeLicenseNumber__c, '
                  + 'Source_Entity__c, Source_Entity__pc, '
                  + 'RecordType.DeveloperName '
                  + 'FROM Account '
                  + 'WHERE Id != :accountId '
                  + 'AND Merge_Status__c != \'Pending\' '
                  + 'AND Merge_Status__c != \'Approved\' '
                  + 'AND Is_Merged__c = false '
                  + 'AND Source_Entity__c  != \'Modon - Egypt\' '
                  + 'AND Source_Entity__pc != \'Modon - Egypt\' '
                  + typeFilter
                  + 'AND (' + String.join(orClauses, ' OR ') + ') LIMIT 200';
                dupes = Database.query(soql);
            }

            Set<Id> allIds = new Set<Id>{ accountId };
            for (Account a : dupes) allIds.add(a.Id);
            Map<Id, Integer> soCountMap = getSalesOrderCounts(allIds);

            Boolean anyPortal = src.IsCustomerPortal;
            Boolean anyErp    = String.isNotBlank(src.OraclePartyId__c);
            String  portalId  = src.IsCustomerPortal ? src.Id : null;
            for (Account a : dupes) {
                if (a.IsCustomerPortal)                  { anyPortal = true; portalId = a.Id; }
                if (String.isNotBlank(a.OraclePartyId__c)) anyErp = true;
            }

            String masterRule        = anyPortal ? 'PORTAL' : anyErp ? 'ERP' : 'ANY';
            String suggestedMasterId = anyPortal ? portalId : null;

            AccountWrapper srcW = buildWrapper(src, soCountMap, masterRule);
            if (suggestedMasterId == null && masterRule == 'ERP' && srcW.hasErpId) {
                suggestedMasterId = src.Id;
            }

            CountWrapper counts = new CountWrapper();
            counts.all = 0; counts.passport = 0; counts.eid = 0;
            counts.mobile = 0; counts.email = 0;

            List<AccountWrapper> wrappers = new List<AccountWrapper>();
            for (Account a : dupes) {
                AccountWrapper w = buildWrapper(a, soCountMap, masterRule);
                if (src.IsPersonAccount) {
                    w.matchPassport = String.isNotBlank(srcPassport) && srcPassport == a.PassportNumber__pc;
                    w.matchEid      = String.isNotBlank(srcEid)      && srcEid      == a.EIDNumber__pc;
                    w.matchMobile   = String.isNotBlank(srcMobile)   && srcMobile   == a.PersonMobilePhone;
                    w.matchEmail    = String.isNotBlank(srcEmail)    && srcEmail    == a.PersonEmail;
                } else {
                    // Org Account — map filter slots to UAE business fields
                    w.matchPassport = String.isNotBlank(srcUnified) && srcUnified == a.UnifiedNumber__c;
                    w.matchMobile   = String.isNotBlank(srcVat)     && srcVat     == a.UAEVATRegisterNumber__c;
                    w.matchEmail    = String.isNotBlank(srcTrade)   && srcTrade   == a.TradeLicenseNumber__c;
                    w.matchEid      = false;
                }
                if (w.matchPassport) counts.passport++;
                if (w.matchEid)      counts.eid++;
                if (w.matchMobile)   counts.mobile++;
                if (w.matchEmail)    counts.email++;
                if (suggestedMasterId == null && masterRule == 'ERP' && w.hasErpId) {
                    suggestedMasterId = a.Id;
                }
                wrappers.add(w);
            }
            counts.all = wrappers.size();

            DuplicateResult result     = new DuplicateResult();
            result.sourceAccount       = srcW;
            result.accounts            = wrappers;
            result.counts              = counts;
            result.suggestedMasterId   = suggestedMasterId;
            result.masterSelectionRule = masterRule;
            result.currentUserName      = UserInfo.getName();
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error loading duplicates: ' + e.getMessage());
        }
    }

    private static AccountWrapper buildWrapper(
        Account a, Map<Id,Integer> soCountMap, String rule
    ) {
        AccountWrapper w          = new AccountWrapper();
        w.id                      = a.Id;
        w.name                    = a.Name;
        w.accountNumber           = a.AccountNumber;
        w.erpId                   = a.OraclePartyId__c;
        w.hasErpId                = String.isNotBlank(a.OraclePartyId__c);
        w.isPortalUser            = a.IsCustomerPortal;
        w.isPersonAccount         = a.IsPersonAccount;
        w.salesOrderCount         = soCountMap.containsKey(a.Id) ? soCountMap.get(a.Id) : 0;
        w.mergeStatus             = a.Merge_Status__c;
        w.mergeError              = a.Merge_Error__c;
        w.hasMergeError           = String.isNotBlank(a.Merge_Error__c);
        w.matchPassport           = false;
        w.matchEid                = false;
        w.matchMobile             = false;
        w.matchEmail              = false;
        w.recordTypeDeveloperName = a.RecordType != null ? a.RecordType.DeveloperName : '';

        if      (rule == 'PORTAL') w.canBeMaster = a.IsCustomerPortal && String.isNotBlank(a.OraclePartyId__c);
        else if (rule == 'ERP')    w.canBeMaster = String.isNotBlank(a.OraclePartyId__c);
        else                       w.canBeMaster = true;
        return w;
    }

    // ─────────────────────────────────────────────────────────────────────
    // getComparisonFields — CMT-driven, filtered by record type
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static ComparisonResult getComparisonFields(
        Id masterAccountId, List<Id> victimAccountIds
    ) {
        try {
            Account masterForRt = [
                SELECT RecordType.DeveloperName FROM Account WHERE Id = :masterAccountId LIMIT 1
            ];
            String rtDevName = masterForRt.RecordType != null
                ? masterForRt.RecordType.DeveloperName : '';

            List<Merge_Comparison_Field__mdt> cmtFields = [
                SELECT Field_API_Name__c, Field_Label__c, Data_Type__c,
                       Display_Order__c, Is_Editable__c, Section__c, Help_Text__c,
                       Record_Type_Developer_Name__c
                FROM   Merge_Comparison_Field__mdt
                WHERE  Is_Active__c = true
                ORDER  BY Display_Order__c ASC, Field_Label__c ASC
            ];

            List<Merge_Comparison_Field__mdt> filteredFields = new List<Merge_Comparison_Field__mdt>();
            for (Merge_Comparison_Field__mdt f : cmtFields) {
                String rtFilter = f.Record_Type_Developer_Name__c;
                if (String.isBlank(rtFilter)) {
                    filteredFields.add(f);
                } else {
                    for (String allowed : rtFilter.split(',')) {
                        if (allowed.trim().equalsIgnoreCase(rtDevName)) {
                            filteredFields.add(f);
                            break;
                        }
                    }
                }
            }
            if (filteredFields.isEmpty()) filteredFields = cmtFields;

            Set<String> fieldNames = new Set<String>{ 'Id', 'Name' };
            for (Merge_Comparison_Field__mdt f : filteredFields) {
                if (String.isNotBlank(f.Field_API_Name__c)) fieldNames.add(f.Field_API_Name__c);
            }

            List<Id> allIds = new List<Id>{ masterAccountId };
            allIds.addAll(victimAccountIds);
            List<Account> accounts = Database.query(
                'SELECT ' + String.join(new List<String>(fieldNames), ', ')
                + ' FROM Account WHERE Id IN :allIds'
            );

            Map<Id, Account> accMap = new Map<Id, Account>();
            for (Account a : accounts) accMap.put(a.Id, a);
            Account master = accMap.get(masterAccountId);

            List<String>  childNames = new List<String>();
            List<String>  childIds   = new List<String>();
            List<Account> children   = new List<Account>();
            for (Id vid : victimAccountIds) {
                if (accMap.containsKey(vid)) {
                    Account c = accMap.get(vid);
                    childNames.add(c.Name);
                    childIds.add(c.Id);
                    children.add(c);
                }
            }

            List<ComparisonRow> rows = new List<ComparisonRow>();
            String lastSection = '';
            for (Merge_Comparison_Field__mdt cf : filteredFields) {
                if (String.isBlank(cf.Field_API_Name__c)) continue;
                ComparisonRow row = new ComparisonRow();
                row.fieldApiName = cf.Field_API_Name__c;
                row.fieldLabel   = cf.Field_Label__c;
                row.fieldType    = cf.Data_Type__c;
                row.isEditable   = cf.Is_Editable__c;
                row.section      = cf.Section__c;
                row.helpText     = cf.Help_Text__c;
                row.isNewSection = String.isNotBlank(cf.Section__c) && cf.Section__c != lastSection;
                if (row.isNewSection) lastSection = cf.Section__c;

                row.masterValue   = getFieldValue(master, cf.Field_API_Name__c);
                row.childValues   = new List<String>();
                row.hasDifference = false;
                for (Account child : children) {
                    String cv = getFieldValue(child, cf.Field_API_Name__c);
                    row.childValues.add(cv);
                    if (cv != row.masterValue) row.hasDifference = true;
                }
                rows.add(row);
            }

            ComparisonResult result = new ComparisonResult();
            result.rows           = rows;
            result.childNames     = childNames;
            result.childIds       = childIds;
            result.recordTypeName = rtDevName;
            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading comparison: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // saveFieldOverrides — also saves mandatory Merge_Comment__c
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String saveFieldOverrides(
        Id                  masterAccountId,
        Map<String, String> fieldOverrides,
        String              mergeComment
    ) {
        try {

            Set<String> editableFields = new Set<String>();
            for (Merge_Comparison_Field__mdt f : [
                SELECT Field_API_Name__c FROM Merge_Comparison_Field__mdt
                WHERE  Is_Active__c = true AND Is_Editable__c = true
            ]) {
                editableFields.add(f.Field_API_Name__c);
            }

            Account toUpdate  = new Account(Id = masterAccountId);
            Boolean hasUpdate = false;
            Map<String, Schema.SObjectField> fieldMap =
                Schema.Account.SObjectType.getDescribe().fields.getMap();

            if (fieldOverrides != null) {
                for (String fn : fieldOverrides.keySet()) {
                    if (!editableFields.contains(fn))             continue;
                    if (!fieldMap.containsKey(fn.toLowerCase())) continue;

                    String rawVal = fieldOverrides.get(fn);
                    Schema.DisplayType ft = fieldMap.get(fn.toLowerCase()).getDescribe().getType();

                    try {
                        if      (ft == Schema.DisplayType.DATE)
                            toUpdate.put(fn, String.isBlank(rawVal) ? null : Date.parse(rawVal));
                        else if (ft == Schema.DisplayType.DATETIME)
                            toUpdate.put(fn, String.isBlank(rawVal) ? null : DateTime.parse(rawVal));
                        else if (ft == Schema.DisplayType.BOOLEAN)
                            toUpdate.put(fn, rawVal == 'true');
                        else if (ft == Schema.DisplayType.DOUBLE   || ft == Schema.DisplayType.INTEGER
                              || ft == Schema.DisplayType.LONG     || ft == Schema.DisplayType.PERCENT
                              || ft == Schema.DisplayType.CURRENCY)
                            toUpdate.put(fn, String.isBlank(rawVal) ? null : Decimal.valueOf(rawVal));
                        else
                            toUpdate.put(fn, String.isBlank(rawVal) ? null : rawVal);
                        hasUpdate = true;
                    } catch (Exception fx) {
                        System.debug('saveFieldOverrides skip field ' + fn + ': ' + fx.getMessage());
                    }
                }
            }

            // Save comment only when provided (auto-generated from Use clicks)
            if (String.isNotBlank(mergeComment)) toUpdate.Merge_Comment__c = mergeComment.left(32000);
            update toUpdate;

            return 'SUCCESS';

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving overrides: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // getPendingMergeDetails
    // Called on page load when master Merge_Status__c = Pending|Merged.
    // Returns master + linked victims for the submitted/merged screen table.
    // Victims are excluded from getAccountDuplicates while Pending so this
    // dedicated method is needed to show the full account list.
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<SubmittedMergeRow> getPendingMergeDetails(Id masterAccountId) {
        try {
            List<SubmittedMergeRow> rows = new List<SubmittedMergeRow>();

            Account master = [
                SELECT Id, Name, AccountNumber FROM Account
                WHERE  Id = :masterAccountId LIMIT 1
            ];
            SubmittedMergeRow masterRow = new SubmittedMergeRow();
            masterRow.id            = master.Id;
            masterRow.name          = master.Name;
            masterRow.accountNumber = master.AccountNumber;
            masterRow.isMaster      = true;
            rows.add(masterRow);

            // Include pending victims AND already-merged victims
            for (Account v : [
                SELECT Id, Name, AccountNumber FROM Account
                WHERE  Master_Account__c = :masterAccountId
                AND    (Eligible_For_Merge__c = true OR Is_Merged__c = true)
                ORDER  BY Name ASC
            ]) {
                SubmittedMergeRow vRow = new SubmittedMergeRow();
                vRow.id            = v.Id;
                vRow.name          = v.Name;
                vRow.accountNumber = v.AccountNumber;
                vRow.isMaster      = false;
                rows.add(vRow);
            }
            return rows;

        } catch (Exception e) {
            throw new AuraHandledException('Error loading merge details: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // submitMergeRequest
    // Blocked if Merge_Error__c is populated — user must clear error first
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String submitMergeRequest(Id masterAccountId, List<Id> victimAccountIds) {

        List<Id> flaggedVictimIds = new List<Id>();

        try {
            Account master = [
                SELECT Id, Name, OraclePartyId__c, IsCustomerPortal, IsPersonAccount,
                       Merge_Error__c, Merge_Comment__c
                FROM   Account WHERE Id = :masterAccountId LIMIT 1
            ];

            // ── Block if previous merge error is unresolved ───────────────
            if (String.isNotBlank(master.Merge_Error__c)) {
                throw new AuraHandledException(
                    'This account has an unresolved merge error. '
                  + 'Click "Clear Error & Retry" to reset it before resubmitting.');
            }


            if (master.IsCustomerPortal && String.isBlank(master.OraclePartyId__c)) {
                throw new AuraHandledException(
                    'The portal account selected as Master must have an ERP ID (OraclePartyId__c).');
            }
            if (victimAccountIds == null || victimAccountIds.isEmpty()) {
                throw new AuraHandledException('No victim accounts provided.');
            }
            for (Account v : [
                SELECT Id, IsPersonAccount FROM Account WHERE Id IN :victimAccountIds
            ]) {
                if (v.IsPersonAccount != master.IsPersonAccount) {
                    throw new AuraHandledException(
                        'Cannot merge Person Accounts with Organisation Accounts.');
                }
            }

            // ── Set master to Pending FIRST ───────────────────────────────
            // Approval process entry criteria requires Merge_Status__c = Pending
            // on the MASTER before Approval.process() is called.
            update new Account(
                Id                      = masterAccountId,
                Merge_Status__c         = 'Pending',
                Merge_Error__c          = null,
                Merge_Requested_By__c   = UserInfo.getUserId(),
                Merge_Requested_Date__c = DateTime.now()
            );

            // ── Flag victims as Pending ───────────────────────────────────
            // Also fetch victim names for the approval comment
            List<Account> victimAccounts = [
                SELECT Id, Name FROM Account WHERE Id IN :victimAccountIds
            ];
            List<String> victimNames = new List<String>();
            List<Account> toFlag = new List<Account>();
            for (Account vAcc : victimAccounts) {
                if (vAcc.Id == masterAccountId) continue;
                victimNames.add(vAcc.Name);
                toFlag.add(new Account(
                    Id                      = vAcc.Id,
                    Eligible_For_Merge__c   = true,
                    Master_Account__c       = masterAccountId,
                    Merge_Status__c         = 'Pending',
                    Merge_Error__c          = null,
                    Merge_Requested_By__c   = UserInfo.getUserId(),
                    Merge_Requested_Date__c = DateTime.now()
                ));
                flaggedVictimIds.add(vAcc.Id);
            }
            if (!toFlag.isEmpty()) update toFlag;

            // ── Submit to Approval Process ────────────────────────────────
            String approvalComment =
                'Merge requested for ' + victimAccountIds.size() + ' victim account(s).'
              + ' Master: ' + master.Name
              + ' | Child(ren): ' + String.join(victimNames, ', ')
              + ' | Requested by: ' + UserInfo.getName()
              + ' on ' + DateTime.now().format('dd/MM/yyyy HH:mm');

            try {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(masterAccountId);
                req.setSubmitterId(UserInfo.getUserId());
                req.setProcessDefinitionNameOrId('Account_Merge_Approval');
                req.setComments(approvalComment);
                Approval.ProcessResult res = Approval.process(req);

                if (res == null || !res.isSuccess()) {
                    rollbackVictims(flaggedVictimIds);
                    rollbackMaster(masterAccountId);
                    throw new AuraHandledException(
                        'Approval process submission failed. Please contact your administrator.');
                }

            } catch (AuraHandledException rethrow) {
                throw rethrow;
            } catch (Exception approvalEx) {
                rollbackVictims(flaggedVictimIds);
                rollbackMaster(masterAccountId);
                throw buildApprovalException(approvalEx.getMessage());
            }

            return 'SUCCESS';

        } catch (AuraHandledException e) { throw e; }
        catch (Exception e) {
            rollbackVictims(flaggedVictimIds);
            rollbackMaster(masterAccountId);
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // clearMergeError — called by LWC "Clear Error & Retry" button
    // Resets master and all victims so user can start a fresh submission
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String clearMergeError(Id masterAccountId) {
        try {
            update new Account(
                Id               = masterAccountId,
                Merge_Status__c  = null,
                Merge_Error__c   = null,
                Merge_Comment__c = null
            );

            List<Account> victims = [
                SELECT Id FROM Account
                WHERE  Master_Account__c     = :masterAccountId
                AND    Eligible_For_Merge__c = true
            ];
            if (!victims.isEmpty()) {
                List<Account> toReset = new List<Account>();
                for (Account v : victims) {
                    toReset.add(new Account(
                        Id                      = v.Id,
                        Eligible_For_Merge__c   = false,
                        Master_Account__c       = null,
                        Merge_Status__c         = null,
                        Merge_Error__c          = null,
                        Merge_Comment__c        = null,
                        Merge_Requested_By__c   = null,
                        Merge_Requested_Date__c = null
                    ));
                }
                update toReset;
            }
            return 'SUCCESS';

        } catch (Exception e) {
            throw new AuraHandledException('Clear error failed: ' + e.getMessage());
        }
    }


    // ─────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────

    @TestVisible
    private static AuraHandledException buildApprovalException(String msg) {
        if (msg == null) msg = '';
        if (msg.containsIgnoreCase('NO_APPLICABLE_PROCESS')
         || msg.containsIgnoreCase('No applicable approval process')) {
            return new AuraHandledException(
                'No active Approval Process found. Ensure "Account_Merge_Approval" '
              + 'is active in Setup → Process Automation → Approval Processes.');
        }
        if (msg.containsIgnoreCase('SELF_APPROVAL_NOT_ALLOWED')) {
            return new AuraHandledException(
                'The current user cannot approve their own submission. '
              + 'Please contact an approver to process this request.');
        }
        if (msg.containsIgnoreCase('ALREADY_IN_PROCESS')) {
            return new AuraHandledException(
                'This account already has a pending approval request.');
        }
        return new AuraHandledException('Approval process error: ' + msg);
    }

    @TestVisible
    private static void rollbackMaster(Id masterAccountId) {
        if (masterAccountId == null) return;
        try {
            update new Account(
                Id                      = masterAccountId,
                Merge_Status__c         = null,
                Merge_Error__c          = null,
                Merge_Requested_By__c   = null,
                Merge_Requested_Date__c = null
            );
        } catch (Exception rb) {
            System.debug('Rollback master failed: ' + rb.getMessage());
        }
    }

    @TestVisible
    private static void rollbackVictims(List<Id> victimIds) {
        if (victimIds == null || victimIds.isEmpty()) return;
        try {
            List<Account> toReset = new List<Account>();
            for (Id vid : victimIds) {
                toReset.add(new Account(
                    Id                      = vid,
                    Eligible_For_Merge__c   = false,
                    Master_Account__c       = null,
                    Merge_Status__c         = null,
                    Merge_Error__c          = null,
                    Merge_Requested_By__c   = null,
                    Merge_Requested_Date__c = null
                ));
            }
            update toReset;
        } catch (Exception rb) {
            System.debug('Rollback victims failed: ' + rb.getMessage());
        }
    }

    @TestVisible
    private static String getFieldValue(Account a, String fieldName) {
        if (a == null) return '';
        Object val = a.get(fieldName);
        if (val == null) return '';
        if (val instanceof Date)     return ((Date)     val).format();
        if (val instanceof DateTime) return ((DateTime) val).format();
        return String.valueOf(val);
    }

    @TestVisible
    private static Map<Id, Integer> getSalesOrderCounts(Set<Id> accountIds) {
        Map<Id, Integer> result = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT CustomerAccount__c accId, COUNT(Id) cnt
            FROM   SalesOrder__c
            WHERE  CustomerAccount__c IN :accountIds
            GROUP  BY CustomerAccount__c
        ]) {
            result.put((Id) ar.get('accId'), (Integer) ar.get('cnt'));
        }
        return result;
    }
}