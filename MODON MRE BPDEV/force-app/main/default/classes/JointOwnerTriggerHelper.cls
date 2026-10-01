/**********************************************************************************************************************
* Name               : JointOwnerTriggerHelper                                                        
* Description        : This class is helper for JointOwner trigger
* Usage              : Called from JointOwnerTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         02 Feb 2024     Initial Draft
* 2.0           rushi.patel@horizontal.com       22 September 2026  KYC gate on joint owner creation -
*                                                                checkJointOwnerKYC. Mirrors
*                                                                UnitSearchLwcController.checkKYCEligibility
*                                                                against JointOwnerAccount__c. Organization
*                                                                accounts resolve their contact through
*                                                                Power_of_Attorney__c. Modon - Egypt excluded.
*                                                                bypassKYCCheck defaults true in test context;
*                                                                set false in a test to exercise the gate.
* 2.1           rushi.patel@horizontal.com       24 September 2026  Organization accounts now read KYC from the
*                                                                POA Contact instead of the org account.
*                                                                POA check moved ahead of the KYC check.
*                                                                Missing-document message grouped by the
*                                                                record each document belongs to.
******************************************************************************************************************/
public without sharing class JointOwnerTriggerHelper {

    public static void updateJO(list<SObject> newList){
        map<Id,set<ID>> soMap = new map<Id,set<ID>>();
        map<Id,SalesOrder__c> soMapToUpdate = new map<Id,SalesOrder__c>();
        map<Id, list<Decimal>> ownershipMap = new map<Id, list<Decimal>>();
        for(JointOwner__c joObj : (List<JointOwner__c>)newList){
            if(joObj.SalesOrder__c!=null && String.isNotBlank(joObj.SalesOrder__c)){
                soMap.put(joObj.SalesOrder__c,new set<ID>());
            }
        }

        for(JointOwner__c jo : [select id,SalesOrder__c, JointOwnerAccount__r.PersonContactId, OwnershipPercentage__c  from JointOwner__c where SalesOrder__c in : soMap.KeySet() order by OwnershipPercentage__c,CreatedDate ]){
            if(jo.JointOwnerAccount__r.PersonContactId!=null){
                if(soMap.get(jo.SalesOrder__c).contains(jo.JointOwnerAccount__r.PersonContactId)){
                    newList[0].addError('Duplicate Joint Owner');
                }
                soMap.get(jo.SalesOrder__c).add(jo.JointOwnerAccount__r.PersonContactId);
                // Add Ownership Percentage to the map
                if (!ownershipMap.containsKey(jo.SalesOrder__c)) {
                    ownershipMap.put(jo.SalesOrder__c, new list<Decimal>());
                }
                ownershipMap.get(jo.SalesOrder__c).add(jo.OwnershipPercentage__c);
            }
        }

        // TASK 1 FIX: previously this loop was wrapped in
        //     if(!soMap.get(soId).isEmpty()){ ... }
        // which meant a Sales Order was skipped entirely once its last joint owner
        // was deleted (the re-query above returns nothing, so soMap.get(soId) is
        // empty), leaving stale JO1__c...JO6__c values pointing at deleted records.
        // Now every Sales Order in scope is always processed: all 6 slots are
        // cleared first, then repopulated with whatever owners still exist.
        for(ID soId : soMap.keySet()){
            list<ID> ownerList = new list<id>(soMap.get(soId));
            list<Decimal> ownershipList = ownershipMap.containsKey(soId) ? ownershipMap.get(soId) : new list<Decimal>();

            if(ownerList.size()>6){
                newList[0].addError('Maximum limit reached for Joint Owner');
            }

            SalesOrder__c soToUpdate = new SalesOrder__c(id=soId);

            // Reset all 6 slots first so a deleted joint owner clears its slot
            // instead of leaving a stale reference behind.
            soToUpdate.JO1__c = null; soToUpdate.JO1_Ownership__c = null;
            soToUpdate.JO2__c = null; soToUpdate.JO2_Ownership__c = null;
            soToUpdate.JO3__c = null; soToUpdate.JO3_Ownership__c = null;
            soToUpdate.JO4__c = null; soToUpdate.JO4_Ownership__c = null;
            soToUpdate.JO5__c = null; soToUpdate.JO5_Ownership__c = null;
            soToUpdate.JO6__c = null; soToUpdate.JO6_Ownership__c = null;

            if(ownerList.size()>0){soToUpdate.JO1__c = ownerList[0]; soToUpdate.JO1_Ownership__c = ownershipList[0];}
            if(ownerList.size()>1){soToUpdate.JO2__c = ownerList[1]; soToUpdate.JO2_Ownership__c = ownershipList[1];}
            if(ownerList.size()>2){soToUpdate.JO3__c = ownerList[2]; soToUpdate.JO3_Ownership__c = ownershipList[2];}
            if(ownerList.size()>3){soToUpdate.JO4__c = ownerList[3]; soToUpdate.JO4_Ownership__c = ownershipList[3];}
            if(ownerList.size()>4){soToUpdate.JO5__c = ownerList[4]; soToUpdate.JO5_Ownership__c = ownershipList[4];}
            if(ownerList.size()>5){soToUpdate.JO6__c = ownerList[5]; soToUpdate.JO6_Ownership__c = ownershipList[5];}

            soMapToUpdate.put(soId, soToUpdate);
        }

        if(!soMapToUpdate.isEmpty()){
            update soMapToUpdate.values();
        }
    }

    public static void checkOwnershipPercentage(list<SObject> newList){
        set<Id> oppIds = new set<Id>();
        set<Id> soId = new set<Id>();
        set<Id> joIds = new set<Id>();
        map<String, Decimal> oppSOPercentageMap = new Map<String, Decimal>();

        // TASK 2: tracks the largest single joint-owner percentage already
        // committed against each Sales Order, keyed by Sales Order Id.
        map<Id, Decimal> soMaxOwnershipMap = new map<Id, Decimal>();

        for(JointOwner__c joObj : (List<JointOwner__c>)newList){
            if(String.isNotBlank(joObj.Opportunity__c)){
                oppIds.add(joObj.Opportunity__c);
            }
            if(String.isNotBlank(joObj.SalesOrder__c)){
                soId.add(joObj.SalesOrder__c);
            }
            if(String.isNotBlank(joObj.Id)){
                joIds.add(joObj.Id);
            }
        }
        String query = 'SELECT Id, OwnershipPercentage__c, Opportunity__c, SalesOrder__c FROM JointOwner__c WHERE Opportunity__c IN :oppIds AND SalesOrder__c IN :soId'; //WHERE (Opportunity__c IN :oppIds OR SalesOrder__c IN :soId) - UPDATED ON: 14/JAN/2025

        if(!joIds.isEmpty()){
            query += ' AND Id NOT IN : joIds';
        }
        List<JointOwner__c> existingOwners = (List<JointOwner__c>) Database.queryWithBinds(
            query,
            new Map<String, Object>{
                'oppIds' => oppIds,
                'soId' => soId,
                'joIds' => joIds
            },
            AccessLevel.SYSTEM_MODE
        );

        for(JointOwner__c joObj : existingOwners){
            if(String.isNotBlank(joObj.Opportunity__c) || String.isNotBlank(joObj.SalesOrder__c)){
                if(String.isNotBlank(joObj.Opportunity__c) && oppSOPercentageMap.containsKey(joObj.Opportunity__c)){
                    Decimal ownerPer = oppSOPercentageMap.get(joObj.Opportunity__c);ownerPer += joObj.OwnershipPercentage__c;oppSOPercentageMap.put(joObj.Opportunity__c, ownerPer);
                }else if(String.isNotBlank(joObj.Opportunity__c)){
                    oppSOPercentageMap.put(joObj.Opportunity__c, joObj.OwnershipPercentage__c);
                }

                if(String.isNotBlank(joObj.SalesOrder__c) && oppSOPercentageMap.containsKey(joObj.SalesOrder__c)){
                    Decimal ownerPer = oppSOPercentageMap.get(joObj.SalesOrder__c);ownerPer += joObj.OwnershipPercentage__c;oppSOPercentageMap.put(joObj.SalesOrder__c, ownerPer);
                }else if(String.isNotBlank(joObj.SalesOrder__c)){
                    oppSOPercentageMap.put(joObj.SalesOrder__c, joObj.OwnershipPercentage__c);
                }

                // TASK 2: track the largest joint-owner percentage per Sales Order
                if(String.isNotBlank(joObj.SalesOrder__c)){
                    Decimal currentMax = soMaxOwnershipMap.containsKey(joObj.SalesOrder__c) ? soMaxOwnershipMap.get(joObj.SalesOrder__c) : 0;
                    if(joObj.OwnershipPercentage__c > currentMax){
                        soMaxOwnershipMap.put(joObj.SalesOrder__c, joObj.OwnershipPercentage__c);
                    }
                }
            }
        }

        for(JointOwner__c joObj : (List<JointOwner__c>)newList){
            if(String.isNotBlank(joObj.Opportunity__c) && oppSOPercentageMap.containsKey(joObj.Opportunity__c)){
                Decimal existingOwnerPer = oppSOPercentageMap.get(joObj.Opportunity__c);
                if(existingOwnerPer + joObj.OwnershipPercentage__c >= 100){
                    joObj.addError('Ownership percentage cannot be more than 100 for opportunity.');
                }
            }
            if(String.isNotBlank(joObj.SalesOrder__c) && oppSOPercentageMap.containsKey(joObj.SalesOrder__c)){
                Decimal existingOwnerPer = oppSOPercentageMap.get(joObj.SalesOrder__c);
                if(existingOwnerPer + joObj.OwnershipPercentage__c >= 100){
                    joObj.addError('Ownership percentage cannot be more than 100 for sales order.');
                }
            }

            // TASK 2 FIX: adding/updating this joint owner must not push the
            // primary owner's remaining share below the largest single joint
            // owner's share on that Sales Order (including this one).
            // Computed directly from OwnershipPercentage__c values already in
            // hand - deliberately NOT read from PrimaryOwnerPercentage__c,
            // since that formula field is derived from these same numbers and
            // would create a circular / order-dependent check.
            if(String.isNotBlank(joObj.SalesOrder__c)){
                Decimal existingSum = oppSOPercentageMap.containsKey(joObj.SalesOrder__c) ? oppSOPercentageMap.get(joObj.SalesOrder__c) : 0;
                Decimal existingMax = soMaxOwnershipMap.containsKey(joObj.SalesOrder__c) ? soMaxOwnershipMap.get(joObj.SalesOrder__c) : 0;

                Decimal primaryAfter = 100 - (existingSum + joObj.OwnershipPercentage__c);
                Decimal maxJointOwnerAfter = existingMax > joObj.OwnershipPercentage__c ? existingMax : joObj.OwnershipPercentage__c;

                if(primaryAfter < maxJointOwnerAfter){
                    joObj.addError('This would leave the primary owner with only ' + primaryAfter +
                        '%, which is less than a joint owner\'s ' + maxJointOwnerAfter +
                        '%. The primary owner must always hold the largest percentage.');
                }
            }
        }
    }

    // ==================================================================
    // Joint Owner KYC gate
    // Rushi Patel - 22 September 2026
    //
    // Mirrors UnitSearchLwcController.checkKYCEligibility, but validates the
    // JOINT OWNER'S account (JointOwnerAccount__c) instead of the
    // Opportunity's Primary Contact. Enforced in the trigger because joint
    // owners are created from the standard record page, where no LWC runs.
    //
    // Modon - Egypt is excluded entirely (see isEgyptRecord below).
    //
    // Pass criteria (ALL must be true):
    //   1. JointOwnerAccount__c is populated.
    //   2. Organization accounts only - a Power of Attorney with a Contact exists.
    //   3. KYC is complete OR Manual KYC Approval = 'Approved'.
    //   4. Nationality is populated.
    //   5. UAE Resident Status is populated.
    //   6. The required Documents__c records all exist AND each one has an
    //      ACTUAL FILE attached (ContentDocumentLink, or classic Attachment
    //      as fallback). A record with no file FAILS.
    //
    // Where everything is read from depends on the account type. For an
    // organization account the whole check hangs off the POA contact, because
    // corporate KYC is performed against the authorised signatory and __pc
    // fields only populate on Person Accounts:
    //
    //   PERSON ACCOUNT
    //     KYC status       -> Account.KYC_Status__c (formula) / Manual_KYC_Approval__c
    //     Nationality      -> Account.Nationality__pc
    //     Resident Status  -> Account.UAE_Resident_Status__pc
    //     Contact docs     -> Documents__c.PrimaryContact__c = PersonContactId
    //
    //   ORGANIZATION ACCOUNT (via Power_of_Attorney__c junction)
    //     POA record       -> Power_of_Attorney__c.Organization_Account__c
    //     KYC status       -> POA.Contact__r.KYC_Status__c (formula, same logic
    //                         as the Account one) / Manual_KYC_Approval__c.
    //                         NOT the organization account.
    //     Nationality      -> POA.Contact__r.Nationality__c
    //     Resident Status  -> POA.Contact__r.UAE_Resident_Status__c
    //     Contact docs     -> Documents__c.PrimaryContact__c = POA.Contact__c
    //     Account docs     -> Documents__c.Account__c = JointOwnerAccount__c
    //                         (at least ONE of Commercial trade License /
    //                          Certificate of Incorporation)
    //     Business rule: exactly one POA per organization account. No POA, or
    //     a POA with no Contact, blocks the joint owner.
    //
    // Required contact documents:
    //   Resident      -> Emirates/National ID Front, Emirates/National ID Back,
    //                    KYC Form - Signed, Passport
    //   Non-Resident  -> KYC Form - Signed, Passport
    //
    // Runs on INSERT always, and on UPDATE only when JointOwnerAccount__c has
    // changed. Re-validating every update would make existing joint owners
    // uneditable the moment their KYC expires - including the ownership
    // percentage fixes this same class asks for.
    // ==================================================================

    /**
     * Test bypass for the KYC gate.
     *
     * Defaults to TRUE in test context so the 31 existing test classes that
     * insert JointOwner__c records keep passing without each one having to
     * build a full KYC fixture (account KYC status, nationality, resident
     * status, POA, and Documents__c records with real files attached).
     *
     * It is deliberately a FLAG and not a hard `if (Test.isRunningTest()) return;`
     * - a hard skip would ship this gate to production with zero test coverage,
     * where a broken gate and a working one look identical. Any test that needs
     * to exercise the real logic sets:
     *
     *     JointOwnerTriggerHelper.bypassKYCCheck = false;
     *
     * before its DML. Always FALSE outside tests, so production is unaffected.
     */
    @TestVisible
    private static Boolean bypassKYCCheck = Test.isRunningTest();

    private static final Set<String> ACCEPTED_KYC_STATUSES = new Set<String>{ 'active', 'kyc active' };

    private static final String DOC_KYC_FORM   = 'KYC Form - Signed';
    private static final String DOC_PASSPORT   = 'Passport';
    private static final String DOC_EID_FRONT  = 'Emirates/National ID Front';
    private static final String DOC_EID_BACK   = 'Emirates/National ID Back';
    private static final String DOC_TRADE_LIC  = 'Commercial trade License (Resident)';
    private static final String DOC_CERT_INC   = 'Certificate of Incorporation (Non Resident)';

    private static final Set<String> ALL_CONTACT_DOCS = new Set<String>{
        DOC_KYC_FORM, DOC_PASSPORT, DOC_EID_FRONT, DOC_EID_BACK
    };
    private static final Set<String> ACCEPTED_ACCOUNT_DOCS = new Set<String>{
        DOC_TRADE_LIC, DOC_CERT_INC
    };

    public static void checkJointOwnerKYC(List<SObject> newList, Map<Id, SObject> oldMap){

        // See bypassKYCCheck above - always false outside test context.
        if(bypassKYCCheck){ return; }

        List<JointOwner__c> recordsToCheck = new List<JointOwner__c>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> oppIds     = new Set<Id>();
        Set<Id> soIds      = new Set<Id>();

        for(JointOwner__c joObj : (List<JointOwner__c>)newList){
            // On update, only re-validate when the joint owner account itself changed.
            if(oldMap != null){
                JointOwner__c oldJo = (JointOwner__c) oldMap.get(joObj.Id);
                if(oldJo != null && oldJo.JointOwnerAccount__c == joObj.JointOwnerAccount__c){
                    continue;
                }
            }
            recordsToCheck.add(joObj);
            if(joObj.JointOwnerAccount__c != null){ accountIds.add(joObj.JointOwnerAccount__c); }
            if(joObj.Opportunity__c != null){ oppIds.add(joObj.Opportunity__c); }
            if(joObj.SalesOrder__c != null){ soIds.add(joObj.SalesOrder__c); }
        }

        if(recordsToCheck.isEmpty()){ return; }

        // -- Source entity lookups, for the Modon - Egypt exclusion -------------
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        if(!oppIds.isEmpty()){
            oppMap = new Map<Id, Opportunity>([
                SELECT Id, Source_Entity__c FROM Opportunity WHERE Id IN :oppIds
            ]);
        }
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>();
        if(!soIds.isEmpty()){
            soMap = new Map<Id, SalesOrder__c>([
                SELECT Id, Source_Entity__c FROM SalesOrder__c WHERE Id IN :soIds
            ]);
        }

        // -- Joint owner accounts ----------------------------------------------
        Map<Id, Account> accMap = new Map<Id, Account>();
        if(!accountIds.isEmpty()){
            accMap = new Map<Id, Account>([
                SELECT Id, Name, IsPersonAccount, PersonContactId,
                       KYC_Status__c, Manual_KYC_Approval__c,
                       Nationality__pc, UAE_Resident_Status__pc,
                       Source_Entity__c, Source_Entity__pc
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }

        // -- Drop Egypt records before doing any further work -------------------
        List<JointOwner__c> applicable = new List<JointOwner__c>();
        Set<Id> applicableAccountIds = new Set<Id>();
        for(JointOwner__c joObj : recordsToCheck){
            if(isEgyptRecord(joObj, oppMap, soMap, accMap)){ continue; }
            applicable.add(joObj);
            if(joObj.JointOwnerAccount__c != null){
                applicableAccountIds.add(joObj.JointOwnerAccount__c);
            }
        }
        if(applicable.isEmpty()){ return; }

        // -- Power of Attorney, organization accounts only ----------------------
        // Business rule is one POA per organization account. ORDER BY CreatedDate
        // DESC + first-wins keeps the newest if the data ever breaks that rule,
        // rather than throwing a query exception.
        Set<Id> orgAccountIds = new Set<Id>();
        for(Id accId : applicableAccountIds){
            Account acc = accMap.get(accId);
            if(acc != null && acc.IsPersonAccount != true){
                orgAccountIds.add(accId);
            }
        }

        Map<Id, Power_of_Attorney__c> poaByAccount = new Map<Id, Power_of_Attorney__c>();
        if(!orgAccountIds.isEmpty()){
            for(Power_of_Attorney__c poa : [
                SELECT Id, Organization_Account__c, Contact__c, Contact__r.Name,
                       Contact__r.Nationality__c, Contact__r.UAE_Resident_Status__c,
                       Contact__r.KYC_Status__c, Contact__r.Manual_KYC_Approval__c
                FROM Power_of_Attorney__c
                WHERE Organization_Account__c IN :orgAccountIds
                ORDER BY CreatedDate DESC
            ]){
                if(!poaByAccount.containsKey(poa.Organization_Account__c)){
                    poaByAccount.put(poa.Organization_Account__c, poa);
                }
            }
        }

        // -- Resolve the contact that carries the KYC documents -----------------
        Map<Id, Id> contactByAccount = new Map<Id, Id>();
        Set<Id> contactIds = new Set<Id>();
        for(Id accId : applicableAccountIds){
            Account acc = accMap.get(accId);
            if(acc == null){ continue; }
            Id contactId = acc.IsPersonAccount == true
                ? acc.PersonContactId
                : (poaByAccount.containsKey(accId) ? poaByAccount.get(accId).Contact__c : null);
            if(contactId != null){
                contactByAccount.put(accId, contactId);
                contactIds.add(contactId);
            }
        }

        // -- Documents, contact level and account level -------------------------
        Map<Id, Map<String, Set<Id>>> contactDocs = new Map<Id, Map<String, Set<Id>>>();
        Map<Id, Set<Id>> accountDocs = new Map<Id, Set<Id>>();
        Set<Id> allDocIds = new Set<Id>();

        if(!contactIds.isEmpty()){
            for(Documents__c doc : [
                SELECT Id, Name, PrimaryContact__c
                FROM Documents__c
                WHERE PrimaryContact__c IN :contactIds
                AND Name IN :ALL_CONTACT_DOCS
            ]){
                if(!contactDocs.containsKey(doc.PrimaryContact__c)){
                    contactDocs.put(doc.PrimaryContact__c, new Map<String, Set<Id>>());
                }
                Map<String, Set<Id>> byName = contactDocs.get(doc.PrimaryContact__c);
                if(!byName.containsKey(doc.Name)){
                    byName.put(doc.Name, new Set<Id>());
                }
                byName.get(doc.Name).add(doc.Id);
                allDocIds.add(doc.Id);
            }
        }

        if(!orgAccountIds.isEmpty()){
            for(Documents__c doc : [
                SELECT Id, Name, Account__c
                FROM Documents__c
                WHERE Account__c IN :orgAccountIds
                AND Name IN :ACCEPTED_ACCOUNT_DOCS
            ]){
                if(!accountDocs.containsKey(doc.Account__c)){
                    accountDocs.put(doc.Account__c, new Set<Id>());
                }
                accountDocs.get(doc.Account__c).add(doc.Id);
                allDocIds.add(doc.Id);
            }
        }

        // One pass tells us which document records actually hold a file.
        Set<Id> docsWithFile = parentsWithFiles(allDocIds);

        // -- Evaluate ------------------------------------------------------------
        for(JointOwner__c joObj : applicable){

            // Check 1: joint owner account must exist
            if(joObj.JointOwnerAccount__c == null){
                joObj.addError('Select a Joint Owner Account.');
                continue;
            }

            Account acc = accMap.get(joObj.JointOwnerAccount__c);
            if(acc == null){ continue; }

            String accLabel = String.isNotBlank(acc.Name) ? acc.Name : 'the joint owner';
            Boolean isPersonAccount = acc.IsPersonAccount == true;

            // Check 2: Power of Attorney, organization accounts only.
            // This runs BEFORE the KYC check because an organization account's KYC
            // now lives on the POA contact - without the POA there is nothing to
            // read the KYC from, so "no POA" is the truthful first failure.
            Power_of_Attorney__c poa;
            if(!isPersonAccount){
                poa = poaByAccount.get(joObj.JointOwnerAccount__c);
                if(poa == null){
                    joObj.addError(accLabel + ' has no Power of Attorney record.');
                    continue;
                }
                if(poa.Contact__c == null){
                    joObj.addError('Add a Contact to the Power of Attorney for ' + accLabel + '.');
                    continue;
                }
            }

            // Who owns the KYC and the contact-level data. For an organization
            // account that is the POA contact, not the account - naming the account
            // here sends people looking on the wrong record.
            String contactLabel = isPersonAccount ? accLabel : poa.Contact__r.Name;
            String sourceLabel  = isPersonAccount
                ? accLabel
                : contactLabel + ' (Power of Attorney contact for ' + accLabel + ')';

            // Check 3: KYC complete OR Manual KYC Approval = Approved.
            //
            // Person Account     -> read from the Account itself.
            // Organization Account -> read from the POA CONTACT, not the account.
            //   Corporate KYC is performed against the authorised signatory, so the
            //   organization account itself never carries a KYC date. Note this is a
            //   deliberate divergence from UnitSearchLwcController.checkKYCEligibility,
            //   which reads PrimaryContact__r.Account for both account types.
            //
            // KYC_Status__c is a FORMULA field carrying identical logic on both
            // Account and Contact (blank date -> not complete, older than 3 months
            // -> expired, otherwise active), so the same accepted-value check works
            // for either. Accepted outputs are listed in ACCEPTED_KYC_STATUSES -
            // add/remove values there if the formula wording changes. Do NOT use
            // contains('Active'), because 'Inactive' would wrongly pass.
            String kycStatus = isPersonAccount
                ? acc.KYC_Status__c
                : poa.Contact__r.KYC_Status__c;
            String manualApproval = isPersonAccount
                ? acc.Manual_KYC_Approval__c
                : poa.Contact__r.Manual_KYC_Approval__c;

            Boolean kycActive = String.isNotBlank(kycStatus)
                && ACCEPTED_KYC_STATUSES.contains(kycStatus.trim().toLowerCase());
            Boolean kycApproved = String.isNotBlank(manualApproval)
                && manualApproval.trim().equalsIgnoreCase('Approved');

            if(!kycActive && !kycApproved){
                joObj.addError('KYC is not complete for ' + sourceLabel + '.');
                continue;
            }

            String nationality = isPersonAccount
                ? acc.Nationality__pc
                : poa.Contact__r.Nationality__c;
            String residentStatus = isPersonAccount
                ? acc.UAE_Resident_Status__pc
                : poa.Contact__r.UAE_Resident_Status__c;

            // Check 3: Nationality
            if(String.isBlank(nationality)){
                joObj.addError('Add Nationality on ' + sourceLabel + '.');
                continue;
            }

            // Check 4: UAE Resident Status
            if(String.isBlank(residentStatus)){
                joObj.addError('Add UAE Resident Status on ' + sourceLabel + '.');
                continue;
            }

            Boolean isResident = residentStatus.trim().equalsIgnoreCase('Resident');

            List<String> requiredContactDocs = new List<String>{ DOC_KYC_FORM, DOC_PASSPORT };
            if(isResident){
                requiredContactDocs.add(DOC_EID_FRONT);
                requiredContactDocs.add(DOC_EID_BACK);
            }

            Id contactId = contactByAccount.get(joObj.JointOwnerAccount__c);
            Map<String, Set<Id>> docsByName = contactId != null && contactDocs.containsKey(contactId)
                ? contactDocs.get(contactId)
                : new Map<String, Set<Id>>();

            // Check 5: collect EVERY missing document so the user fixes them in one pass.
            List<String> missingDocs = new List<String>();
            for(String docName : requiredContactDocs){
                Boolean satisfied = false;
                if(docsByName.containsKey(docName)){
                    for(Id docId : docsByName.get(docName)){
                        if(docsWithFile.contains(docId)){ satisfied = true; break; }
                    }
                }
                if(!satisfied){ missingDocs.add(docName); }
            }

            Boolean accountDocSatisfied = true;
            if(!isPersonAccount){
                accountDocSatisfied = false;
                if(accountDocs.containsKey(joObj.JointOwnerAccount__c)){
                    for(Id docId : accountDocs.get(joObj.JointOwnerAccount__c)){
                        if(docsWithFile.contains(docId)){ accountDocSatisfied = true; break; }
                    }
                }
            }

            if(!missingDocs.isEmpty() || !accountDocSatisfied){
                // Grouped BY THE RECORD THE DOCUMENT HANGS OFF, because contact
                // documents and account documents live on different records. Listing
                // them all under the account name sends people to the wrong place -
                // on an organization account the KYC Form and Passport belong to the
                // POA contact, not the account.
                //
                // Document names are listed verbatim so the exact record can be found
                // or created. The trailing sentence is the part people miss: a
                // Documents__c record with the right name but no file still fails.
                List<String> groups = new List<String>();
                if(!missingDocs.isEmpty()){
                    groups.add(contactLabel + ': ' + String.join(missingDocs, ', '));
                }
                if(!accountDocSatisfied){
                    groups.add(accLabel + ': ' + DOC_TRADE_LIC + ' or ' + DOC_CERT_INC);
                }
                joObj.addError('Missing documents. ' + String.join(groups, '. ')
                    + '. Each must have a file attached.');
            }
        }
    }

    /**
     * Modon - Egypt exclusion. JointOwner__c carries no Source_Entity__c of its
     * own, so the entity is read from whichever parent the joint owner hangs
     * off. Any one of them reporting Egypt is enough to skip the record - the
     * gate is a UAE requirement and must never block an Egypt booking.
     */
    private static Boolean isEgyptRecord(JointOwner__c joObj,
                                         Map<Id, Opportunity> oppMap,
                                         Map<Id, SalesOrder__c> soMap,
                                         Map<Id, Account> accMap){
        String egypt = Constants.MODON_EGYPT_SOURCE_ENTITY;

        if(joObj.Opportunity__c != null && oppMap.containsKey(joObj.Opportunity__c)
            && oppMap.get(joObj.Opportunity__c).Source_Entity__c == egypt){
            return true;
        }
        if(joObj.SalesOrder__c != null && soMap.containsKey(joObj.SalesOrder__c)
            && soMap.get(joObj.SalesOrder__c).Source_Entity__c == egypt){
            return true;
        }
        if(joObj.JointOwnerAccount__c != null && accMap.containsKey(joObj.JointOwnerAccount__c)){
            Account acc = accMap.get(joObj.JointOwnerAccount__c);
            if(acc.Source_Entity__c == egypt || acc.Source_Entity__pc == egypt){
                return true;
            }
        }
        return false;
    }

    /**
     * Returns the SUBSET of parent Ids that hold at least one file, so every
     * required document is evaluated in a single pass rather than one query
     * per document. Read-only, no DML.
     *
     * This class is already `without sharing`, so ContentDocumentLink and
     * Attachment visibility does not depend on which user uploaded the file -
     * the same reason UnitSearchLwcController wraps its copy in a private
     * without-sharing inner class.
     */
    private static Set<Id> parentsWithFiles(Set<Id> parentIds){
        Set<Id> withFile = new Set<Id>();
        if(parentIds == null || parentIds.isEmpty()){
            return withFile;
        }
        // Salesforce Files (ContentDocument via ContentDocumentLink)
        for(ContentDocumentLink cdl : [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :parentIds
        ]){
            withFile.add(cdl.LinkedEntityId);
        }
        // Fallback: classic Attachments, only for parents still unmatched
        Set<Id> remaining = new Set<Id>(parentIds);
        remaining.removeAll(withFile);
        if(!remaining.isEmpty()){
            for(Attachment att : [
                SELECT ParentId FROM Attachment WHERE ParentId IN :remaining
            ]){
                withFile.add(att.ParentId);
            }
        }
        return withFile;
    }
}