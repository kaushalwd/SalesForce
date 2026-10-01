public with sharing class ProspectAccountMatcherController {
    
    // =========================================================
    // WRAPPERS
    // =========================================================
    
    public class CandidateResult {
        @AuraEnabled public String rowId;
        @AuraEnabled public String recordType;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String eid;
        @AuraEnabled public String passport;
        @AuraEnabled public Boolean isPersonAccount;
    }
    
    public class ResolveResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
    }
    
    public class SRState {
        @AuraEnabled public Boolean hasOrg;
        @AuraEnabled public Boolean hasPrimary;
        @AuraEnabled public Id orgProspectId;
        @AuraEnabled public Boolean hasOrgContact;
    }
    
    // =========================================================
    // SR STATE
    // =========================================================
    
    @AuraEnabled(cacheable=true)
    public static SRState getSRState(Id srId) {
        
        SRState state = new SRState();
        
        state.hasOrg = false;
        state.hasPrimary = false;
        state.hasOrgContact = false;
        
        Id orgProspectId;
        
        for (
            
            Prospect_Account__c pa :
            
            [
                SELECT Id,
                Prospect_Account__c,
                Is_Primary__c,
                RecordType.Name
                
                FROM Prospect_Account__c
                
                WHERE Service_Request__c = :srId
            ]
        ) {
            
            if (pa.RecordType.Name == 'Org Account') {
                
                state.hasOrg = true;
                state.orgProspectId = pa.Id;
                
                orgProspectId = pa.Id;
            }
            
            if (pa.Is_Primary__c) {
                state.hasPrimary = true;
            }
        }
        
        // CONTACT UNDER ORG
        if (orgProspectId != null) {
            
            Integer contactCount = [
                
                SELECT COUNT()
                
                FROM Prospect_Account__c
                
                WHERE Service_Request__c = :srId
                AND Prospect_Account__c = :orgProspectId
            ];
            
            state.hasOrgContact =
                contactCount > 0;
        }
        
        return state;
    }
    // =========================================================
    // SEARCH
    // =========================================================
    
    @AuraEnabled
    public static List<CandidateResult> searchSimilarParties(
        String name,
        String email,
        String phone,
        String eid,
        String passport
    ) {
        
        List<CandidateResult> results = new List<CandidateResult>();
        
        String nameLike = String.isBlank(name)
            ? null
            : '%' + name.trim() + '%';
        
        // =====================================================
        // ACCOUNT SEARCH
        // =====================================================
        
        List<String> accConditions = new List<String>();
        
        if (!String.isBlank(name)) {
            accConditions.add('Name LIKE :nameLike');
        }
        
        if (!String.isBlank(email)) {
            accConditions.add('PersonEmail = :email');
        }
        
        if (!String.isBlank(phone)) {
            accConditions.add('PersonMobilePhone = :phone');
            accConditions.add('Phone = :phone');
        }
        
        if (!String.isBlank(eid)) {
            accConditions.add('(IsPersonAccount = true AND EIDNumber__pc = :eid)');
        }
        
        if (!String.isBlank(passport)) {
            accConditions.add('(IsPersonAccount = true AND PassportNumber__pc = :passport)');
        }
        
        if (!accConditions.isEmpty()) {
            
            String accQuery =
                'SELECT Id, Name, IsPersonAccount, ' +
                'PersonEmail, PersonMobilePhone, Phone, ' +
                'EIDNumber__pc, PassportNumber__pc ' +
                'FROM Account ' +
                'WHERE ' + String.join(accConditions, ' OR ') +
                ' LIMIT 20';
            
            for (Account acc : Database.query(accQuery)) {
                
                CandidateResult row = new CandidateResult();
                
                row.rowId = 'ACC-' + acc.Id;
                row.recordType = acc.IsPersonAccount ? 'Person Account' : 'Account';
                row.accountId = acc.Id;
                row.contactId = null;
                row.name = acc.Name;
                row.email = acc.IsPersonAccount ? acc.PersonEmail : null;
                row.phone = acc.IsPersonAccount ? acc.PersonMobilePhone : acc.Phone;
                row.eid = acc.IsPersonAccount ? (String)acc.get('EIDNumber__pc') : null;
                row.passport = acc.IsPersonAccount ? (String)acc.get('PassportNumber__pc') : null;
                row.isPersonAccount = acc.IsPersonAccount;
                
                results.add(row);
            }
        }
        
        // =====================================================
        // CONTACT SEARCH
        // =====================================================
        
        List<String> conConditions = new List<String>();
        
        if (!String.isBlank(name)) {
            conConditions.add('Name LIKE :nameLike');
        }
        
        if (!String.isBlank(email)) {
            conConditions.add('Email = :email');
        }
        
        if (!String.isBlank(phone)) {
            conConditions.add('MobilePhone = :phone');
        }
        
        if (!String.isBlank(eid)) {
            conConditions.add('EIDNumber__c = :eid');
        }
        
        if (!String.isBlank(passport)) {
            conConditions.add('PassportNumber__c = :passport');
        }
        
        if (!conConditions.isEmpty()) {
            
            String conQuery =
                'SELECT Id, Name, Email, MobilePhone, ' +
                'AccountId, EIDNumber__c, PassportNumber__c ' +
                'FROM Contact ' +
                'WHERE ' + String.join(conConditions, ' OR ') +
                ' LIMIT 20';
            
            for (Contact con : Database.query(conQuery)) {
                
                CandidateResult row = new CandidateResult();
                
                row.rowId = 'CON-' + con.Id;
                row.recordType = 'Contact';
                row.contactId = con.Id;
                row.accountId = con.AccountId;
                row.name = con.Name;
                row.email = con.Email;
                row.phone = con.MobilePhone;
                row.eid = con.EIDNumber__c;
                row.passport = con.PassportNumber__c;
                row.isPersonAccount = false;
                
                results.add(row);
            }
        }
        
        return results;
    }
    
    // =========================================================
    // RESOLVE
    // =========================================================
    
    @AuraEnabled
    public static ResolveResult resolveAccountOrContact(
        String recordTypeLabel,
        Map<String, Object> prospectFields,
        Id selectedAccountId,
        Id selectedContactId
    ) {
        
        ResolveResult result = new ResolveResult();
        
        Boolean isOrg = recordTypeLabel == 'Org Account';
        Boolean isPerson = false;
        
        Object personObj =
            prospectFields.get('IsPersonAccount__c');
        
        if (personObj != null) {
            
            if (personObj instanceof Boolean) {
                isPerson = (Boolean)personObj;
            } else {
                isPerson = String.valueOf(personObj).toLowerCase() == 'true';
            }
        }
        
        Boolean isContact =
            !isOrg && !isPerson;
        
        // =====================================================
        // CONTACT FLOW
        // =====================================================
        
        if (isContact) {
            
            Id orgAccountId;
            
            // FETCH ORG ACCOUNT FROM PARENT PROSPECT
            if (prospectFields.get('Prospect_Account__c') != null) {
                
                Prospect_Account__c parentProspect = [
                    
                    SELECT Id,
                    Account__c
                    
                    FROM Prospect_Account__c
                    
                    WHERE Id = :((Id)prospectFields.get('Prospect_Account__c'))
                    
                    LIMIT 1
                ];
                
                orgAccountId =
                    parentProspect.Account__c;
            }
            
            // EXISTING CONTACT SELECTED
            if (selectedContactId != null) {
                
                Contact existingCon = new Contact(
                    Id = selectedContactId,
                    AccountId = orgAccountId
                );
                
                update existingCon;
                
                result.contactId =
                    selectedContactId;
                
                return result;
            }
            
            // EXISTING ACCOUNT SELECTED
            if (selectedAccountId != null) {
                
                Contact con =
                    createContact(
                        selectedAccountId,
                        prospectFields
                    );
                
                result.contactId =
                    con.Id;
                
                return result;
            }
            
            // CREATE NEW CONTACT UNDER ORG ACCOUNT
            Contact con =
                createContact(
                    orgAccountId,
                    prospectFields
                );
            
            result.contactId =
                con.Id;
            
            return result;
        }
        // =====================================================
        // ACCOUNT FLOW
        // =====================================================
        
        if (selectedAccountId != null) {
            
            result.accountId =
                selectedAccountId;
            
            return result;
        }
        
        Account acc =
            createAccount(
                prospectFields,
                isPerson
            );
        
        result.accountId =
            acc.Id;
        
        return result;
    }
    
    // =========================================================
    // CREATE ACCOUNT
    // =========================================================
    
    private static Account createAccount(
        Map<String, Object> fields,
        Boolean isPerson
    ) {
        
        Account existing =
            findExistingAccount(fields);
        
        if (existing != null) {
            return existing;
        }
        
        Account acc = new Account();
        
        if (isPerson) {
            
            acc.RecordTypeId = getPersonAccountRT();
            acc.FirstName = (String)fields.get('First_Name__c');
            acc.LastName = String.isBlank((String)fields.get('Last_Name__c')) ? 'Unknown' : (String)fields.get('Last_Name__c');
            acc.PersonEmail = (String)fields.get('Email__c');
            acc.PersonMobilePhone = (String)fields.get('Mobile__c');
            
            acc.put('EIDNumber__pc', fields.get('EIDNumber__c'));
            acc.put('PassportNumber__pc', fields.get('PassportNumber__c'));
            
        } else {
            
            acc.Name = String.isBlank((String)fields.get('Account_Name__c')) ? 'Unknown Organisation' : (String)fields.get('Account_Name__c');
            acc.Phone = (String)fields.get('Mobile__c');
        }
        
        insert acc;
        
        return acc;
    }
    
    // =========================================================
    // CREATE CONTACT
    // =========================================================
    
    private static Contact createContact(
        Id accountId,
        Map<String, Object> fields
    ) {
        
        Contact existing =
            findExistingContact(fields);
        
        if (existing != null) {
            return existing;
        }
        
        Contact con = new Contact();
        
        con.AccountId = accountId;
        con.FirstName = (String)fields.get('First_Name__c');
        con.LastName = String.isBlank((String)fields.get('Last_Name__c')) ? 'Unknown' : (String)fields.get('Last_Name__c');
        con.Email = (String)fields.get('Email__c');
        con.MobilePhone = (String)fields.get('Mobile__c');
        con.EIDNumber__c = (String)fields.get('EIDNumber__c');
        con.PassportNumber__c = (String)fields.get('PassportNumber__c');
        
        insert con;
        
        return con;
    }
    
    // =========================================================
    // FIND EXISTING ACCOUNT
    // =========================================================
    
    private static Account findExistingAccount(
        Map<String, Object> fields
    ) {
        
        String email = (String)fields.get('Email__c');
        String phone = (String)fields.get('Mobile__c');
        String eid = (String)fields.get('EIDNumber__c');
        String passport = (String)fields.get('PassportNumber__c');
        
        List<String> conditions =
            new List<String>();
        
        if (!String.isBlank(email)) {
            conditions.add('PersonEmail = :email');
        }
        
        if (!String.isBlank(phone)) {
            conditions.add('PersonMobilePhone = :phone');
            conditions.add('Phone = :phone');
        }
        
        if (!String.isBlank(eid)) {
            conditions.add('(IsPersonAccount = true AND EIDNumber__pc = :eid)');
        }
        
        if (!String.isBlank(passport)) {
            conditions.add('(IsPersonAccount = true AND PassportNumber__pc = :passport)');
        }
        
        if (conditions.isEmpty()) {
            return null;
        }
        
        String query =
            'SELECT Id, IsPersonAccount ' +
            'FROM Account ' +
            'WHERE ' + String.join(conditions, ' OR ') +
            ' LIMIT 1';

        List<Account> accounts =
            Database.query(query);
        
        return accounts.isEmpty()
            ? null
            : accounts[0];
    }
    
    // =========================================================
    // FIND EXISTING CONTACT
    // =========================================================
    
    private static Contact findExistingContact(
        Map<String, Object> fields
    ) {
        
        String email = (String)fields.get('Email__c');
        String phone = (String)fields.get('Mobile__c');
        String eid = (String)fields.get('EIDNumber__c');
        String passport = (String)fields.get('PassportNumber__c');
        
        List<String> conditions =
            new List<String>();
        
        if (!String.isBlank(email)) {
            conditions.add('Email = :email');
        }
        
        if (!String.isBlank(phone)) {
            conditions.add('MobilePhone = :phone');
        }
        
        if (!String.isBlank(eid)) {
            conditions.add('EIDNumber__c = :eid');
        }
        
        if (!String.isBlank(passport)) {
            conditions.add('PassportNumber__c = :passport');
        }
        
        if (conditions.isEmpty()) {
            return null;
        }
        
        String query =
            'SELECT Id, AccountId ' +
            'FROM Contact ' +
            'WHERE ' + String.join(conditions, ' OR ') +
            ' LIMIT 1';

        List<Contact> contacts =
            Database.query(query);
        
        return contacts.isEmpty()
            ? null
            : contacts[0];
    }
    
    // =========================================================
    // PERSON ACCOUNT RT
    // =========================================================
    
    private static Id getPersonAccountRT() {
        
        return Account.SObjectType
            .getDescribe()
            .getRecordTypeInfosByName()
            .get('Person Account')
            .getRecordTypeId();
    }
}