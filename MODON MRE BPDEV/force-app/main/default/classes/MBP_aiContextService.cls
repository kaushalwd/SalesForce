/**
 * MBP_aiContextService
 * ---------------------------------------------------------------------------
 * Builds GROUNDED context for the AI Assistant by fetching the logged-in
 * broker's REAL Salesforce records and serializing them into a compact text
 * block, with all PII tokenized before it ever leaves Salesforce.
 *
 * Uses DYNAMIC SOQL + generic sObject.get('Field') access so the class compiles
 * regardless of exact field API names in this org (mirrors the dynamic-query
 * approach used by MBP_BrokerLeadcontroller.getFilteredLeads). A bad field name
 * surfaces at runtime (caught), not as a compile error that blocks the class.
 *
 * First build wires LEADS. Each additional domain (Commissions, Opportunities,
 * Sales Orders, Agency, Agents) is one new build<Domain>Context() method plus a
 * branch in classify() - the redact/unredact/prompt plumbing is shared.
 *
 * `without sharing` mirrors the existing controller so Owner/Agency Admin can
 * see all agency leads; isolation is enforced by the BrokerAgency__c filter.
 */
public without sharing class MBP_aiContextService {

    private static final List<String> LEAD_FIELDS = new List<String>{
        'FirstName', 'LastName', 'Email', 'MobilePhone', 'Status',
        'ProjectInterest__c', 'Project__c', 'UnitType__c', 'NumberOfBedrooms__c',
        'CustomerBudget__c', 'LeadOrigin__c', 'SalesType__c', 'Nationality__c',
        'UAEResidentStatus__c', 'PropertyReadiness__c', 'LeadNumber__c',
        'EIDNumber__c', 'PassportNumber__c', 'BrokerAgentName__c', 'CreatedDate'
    };

    public class GroundedContext {
        public String dataText;
        public Map<String, String> tokenMap;
        public Boolean hasData;
        public GroundedContext() {
            this.dataText = '';
            this.tokenMap = new Map<String, String>();
            this.hasData = false;
        }
    }

    // Intent classification (keyword routing; swap for LLM later).
    // Order matters: more specific domains are checked before generic ones.
    public static String classify(String question) {
        if (String.isBlank(question)) return 'GENERAL';
        String q = question.toLowerCase();

        if (q.contains('commission') || q.contains('payout') || q.contains('invoice')) {
            return 'COMMISSION';
        }
        if (q.contains('sales order') || q.contains('salesorder') || q.contains(' so ')
            || q.contains('booking') || q.contains('unit sold') || q.contains('units sold')) {
            return 'SALESORDER';
        }
        if (q.contains('opportunit') || q.contains('pipeline') || q.contains('deal')) {
            return 'OPPORTUNITY';
        }
        if (q.contains('agent') || q.contains('my team') || q.contains('broker') && q.contains('team')) {
            return 'AGENTS';
        }
        if (q.contains('agency') || q.contains('my company') || q.contains('trade license')
            || q.contains('vat') || q.contains('bank') || q.contains('iban')) {
            return 'AGENCY';
        }
        if (q.contains('lead') || q.contains('enquiry') || q.contains('enquiries')
            || q.contains('prospect')) {
            return 'LEADS';
        }
        return 'GENERAL';
    }

    public static GroundedContext buildContext(String intent) {
        if (intent == 'LEADS')       return buildLeadContext();
        if (intent == 'OPPORTUNITY') return buildOpportunityContext();
        if (intent == 'SALESORDER')  return buildSalesOrderContext();
        if (intent == 'COMMISSION')  return buildCommissionContext();
        if (intent == 'AGENCY')      return buildAgencyContext();
        if (intent == 'AGENTS')      return buildAgentsContext();
        return null;
    }

    // LEADS
    public static GroundedContext buildLeadContext() {
        GroundedContext ctx = new GroundedContext();

        User u = MBP_BrokerLeadcontroller.getUserDetails(UserInfo.getUserId());
        if (u == null || u.Contact == null || u.Contact.AccountId == null) {
            return ctx;
        }
        Id userId         = u.Id;
        Id accountId      = u.Contact.AccountId;
        String brokerType = u.Contact.Broker_Type__c;

        if (brokerType != 'Agent' && brokerType != 'Owner' && brokerType != 'Agency Admin') {
            return ctx; // no lead access for this broker type
        }

        // No date filter - 50 most recent leads regardless of year.
        // Agent: only leads they created. Owner / Agency Admin: ALL agency leads
        // (filtered by BrokerAgency__c only - many leads are created by internal
        List<Lead> leads;
        try {
            if (brokerType == 'Agent') {
                leads = [
                    SELECT FirstName, LastName, Email, MobilePhone, Status,
                           ProjectInterest__c, Project__c, UnitType__c, NumberOfBedrooms__c,
                           CustomerBudget__c, LeadOrigin__c, SalesType__c, Nationality__c,
                           UAEResidentStatus__c, PropertyReadiness__c, LeadNumber__c,
                           EIDNumber__c, PassportNumber__c, BrokerAgentName__c, CreatedDate
                    FROM Lead
                    WHERE BrokerAgency__c = :accountId AND CreatedById = :userId
                    WITH SYSTEM_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            } else {
                leads = [
                    SELECT FirstName, LastName, Email, MobilePhone, Status,
                           ProjectInterest__c, Project__c, UnitType__c, NumberOfBedrooms__c,
                           CustomerBudget__c, LeadOrigin__c, SalesType__c, Nationality__c,
                           UAEResidentStatus__c, PropertyReadiness__c, LeadNumber__c,
                           EIDNumber__c, PassportNumber__c, BrokerAgentName__c, CreatedDate
                    FROM Lead
                    WHERE BrokerAgency__c = :accountId
                    WITH SYSTEM_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
        } catch (Exception e) {
            ctx.dataText = 'QUERY_ERROR: ' + e.getMessage();
            return ctx;
        }

        if (leads == null || leads.isEmpty()) {
            return ctx;
        }

        Integer totalLeads = leads.size();
        try {
            if (brokerType == 'Agent') {
                totalLeads = [SELECT count() FROM Lead WHERE BrokerAgency__c = :accountId AND CreatedById = :userId WITH SYSTEM_MODE];
            } else {
                totalLeads = [SELECT count() FROM Lead WHERE BrokerAgency__c = :accountId WITH SYSTEM_MODE];
            }
        } catch (Exception e) {
            totalLeads = leads.size();
        }

        Integer n = 0;
        List<String> blocks = new List<String>();
        for (Lead ld : leads) {
            n++;
            List<String> parts = new List<String>();
            parts.add('Lead ' + n);
            parts.add('Name=' + tokenize(ctx.tokenMap, 'NM' + n, buildName(ld)));

            addPart(parts, 'Status',      fieldStr(ld, 'Status'));
            String proj = fieldStr(ld, 'ProjectInterest__c');
            if (String.isBlank(proj)) proj = fieldStr(ld, 'Project__c');
            addPart(parts, 'Project',     proj);
            addPart(parts, 'UnitType',    fieldStr(ld, 'UnitType__c'));
            addPart(parts, 'Bedrooms',    fieldStr(ld, 'NumberOfBedrooms__c'));
            addPart(parts, 'Budget',      fieldStr(ld, 'CustomerBudget__c'));
            addPart(parts, 'SalesType',   fieldStr(ld, 'SalesType__c'));
            addPart(parts, 'Origin',      fieldStr(ld, 'LeadOrigin__c'));
            addPart(parts, 'Nationality', fieldStr(ld, 'Nationality__c'));
            addPart(parts, 'Residency',   fieldStr(ld, 'UAEResidentStatus__c'));
            addPart(parts, 'Readiness',   fieldStr(ld, 'PropertyReadiness__c'));
            addPart(parts, 'LeadNo',      fieldStr(ld, 'LeadNumber__c'));
            addPart(parts, 'Agent',       agentName(ld));
            addPart(parts, 'Created',     dateStr(ld, 'CreatedDate'));

            // PII fields - tokenized
            parts.add('Email=' + tokenize(ctx.tokenMap, 'EM' + n, fieldStr(ld, 'Email')));
            parts.add('Mobile=' + tokenize(ctx.tokenMap, 'MB' + n, fieldStr(ld, 'MobilePhone')));
            String eid = fieldStr(ld, 'EIDNumber__c');
            if (String.isNotBlank(eid)) parts.add('EID=' + tokenize(ctx.tokenMap, 'ID' + n, eid));
            String pp = fieldStr(ld, 'PassportNumber__c');
            if (String.isNotBlank(pp)) parts.add('Passport=' + tokenize(ctx.tokenMap, 'PP' + n, pp));

            blocks.add(String.join(parts, ' | '));
        }

        ctx.dataText = 'TOTAL_LEADS=' + totalLeads + ' SHOWING=' + leads.size() + '\n'
            + String.join(blocks, '\n');
        ctx.hasData = true;
        return ctx;
    }

    // OPPORTUNITIES
    public static GroundedContext buildOpportunityContext() {
        GroundedContext ctx = new GroundedContext();
        Id accountId = currentAccountId();
        if (accountId == null) return ctx;

        List<Opportunity> opps;
        try {
            opps = [
                SELECT Name, StageName, ProjectInterest__c, Project__r.Name, BrokerAgent__r.Name, 
                       Nationality__c, UAE_Resident_Status__c, Email__c, Mobile__c, CreatedDate 
                FROM Opportunity 
                WHERE BrokerAgency__c = :accountId 
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC 
                LIMIT 50
            ];
        } catch (Exception e) {
            ctx.dataText = 'QUERY_ERROR: ' + e.getMessage();
            return ctx;
        }
        if (opps.isEmpty()) return ctx;

        Integer total = countAgency('Opportunity', 'BrokerAgency__c', accountId, opps.size());

        Integer n = 0;
        List<String> blocks = new List<String>();
        for (Opportunity o : opps) {
            n++;
            List<String> p = new List<String>();
            p.add('Opp ' + n);
            p.add('Name=' + tokenize(ctx.tokenMap, 'NM' + n, fieldStr(o, 'Name')));
            addPart(p, 'Stage', fieldStr(o, 'StageName'));
            String proj = fieldStr(o, 'ProjectInterest__c');
            if (String.isBlank(proj)) proj = pathStr(o, 'Project__r.Name');
            addPart(p, 'Project', proj);
            addTok(p, ctx.tokenMap, 'Agent', 'AG' + n, pathStr(o, 'BrokerAgent__r.Name'));
            addPart(p, 'Nationality', fieldStr(o, 'Nationality__c'));
            addPart(p, 'Residency', fieldStr(o, 'UAE_Resident_Status__c'));
            addPart(p, 'Created', dateStr(o, 'CreatedDate'));
            addTok(p, ctx.tokenMap, 'Email', 'EM' + n, fieldStr(o, 'Email__c'));
            addTok(p, ctx.tokenMap, 'Mobile', 'MB' + n, fieldStr(o, 'Mobile__c'));
            blocks.add(String.join(p, ' | '));
        }

        ctx.dataText = 'SUGGESTED_COLUMNS=Name | Stage | Project | Agent | Created\n'
            + 'TOTAL_OPPORTUNITIES=' + total + ' SHOWING=' + opps.size() + '\n'
            + String.join(blocks, '\n');
        ctx.hasData = true;
        return ctx;
    }

    // SALES ORDERS
    private static final List<String> SO_CANCELLED_LIST = new List<String>{
        'Cancelled','System cancelled','Cancelled SR','Voided',
        'Property Transfer Cancelled - SR','Unit Swap Cancelled - SR',
        'Unit Upgrade Cancelled - SR','Unit Cancellation Cancelled - SR',
        'Unit Consolidation Cancelled - SR','Property Transfer Title Deed Cancelled - SR'
    };

    public static GroundedContext buildSalesOrderContext() {
        GroundedContext ctx = new GroundedContext();
        Id accountId = currentAccountId();
        if (accountId == null) return ctx;

        List<SalesOrder__c> sos;
        try {
            sos = [
                SELECT Name, ProjectName__c, Phase_Name__c, Unit_Name__c, TotalAmount__c, 
                       Totalpaidamount__c, Opportunity__r.Name, CustomerAccount__r.Name, 
                       Unit__r.Status__c, CreatedDate 
                FROM SalesOrder__c 
                WHERE CustomerAccount__c = :accountId 
                  AND ProjectName__c != NULL 
                  AND Status__c NOT IN :SO_CANCELLED_LIST
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC 
                LIMIT 50
            ];
        } catch (Exception e) {
            ctx.dataText = 'QUERY_ERROR: ' + e.getMessage();
            return ctx;
        }
        if (sos.isEmpty()) return ctx;

        Integer total = sos.size();
        try {
            total = [
                SELECT count() 
                FROM SalesOrder__c 
                WHERE CustomerAccount__c = :accountId 
                  AND ProjectName__c != NULL 
                  AND Status__c NOT IN :SO_CANCELLED_LIST
                WITH SYSTEM_MODE
            ];
        } catch (Exception e) { total = sos.size(); }

        Integer n = 0;
        List<String> blocks = new List<String>();
        for (SalesOrder__c so : sos) {
            n++;
            List<String> p = new List<String>();
            p.add('SO ' + n);
            addPart(p, 'Name', fieldStr(so, 'Name'));
            addPart(p, 'Project', fieldStr(so, 'ProjectName__c'));
            addPart(p, 'Phase', fieldStr(so, 'Phase_Name__c'));
            addPart(p, 'Unit', fieldStr(so, 'Unit_Name__c'));
            addPart(p, 'UnitStatus', pathStr(so, 'Unit__r.Status__c'));
            addPart(p, 'Total', fieldStr(so, 'TotalAmount__c'));
            addPart(p, 'Paid', fieldStr(so, 'Totalpaidamount__c'));
            addTok(p, ctx.tokenMap, 'Customer', 'NM' + n, pathStr(so, 'CustomerAccount__r.Name'));
            addPart(p, 'Opportunity', pathStr(so, 'Opportunity__r.Name'));
            addPart(p, 'Created', dateStr(so, 'CreatedDate'));
            blocks.add(String.join(p, ' | '));
        }

        ctx.dataText = 'SUGGESTED_COLUMNS=Project | Unit | Customer | Total | Paid | Created\n'
            + 'TOTAL_SALES_ORDERS=' + total + ' SHOWING=' + sos.size() + '\n'
            + String.join(blocks, '\n');
        ctx.hasData = true;
        return ctx;
    }

    // COMMISSIONS (summary + recent lines)
    public static GroundedContext buildCommissionContext() {
        GroundedContext ctx = new GroundedContext();
        Id accountId = currentAccountId();
        if (accountId == null) return ctx;

        Decimal totalAmt = 0, paid = 0, pending = 0, eligible = 0;
        Integer lineCount = 0;
        try {
            List<AggregateResult> ag = [
                SELECT SUM(Commission_Amount__c) t, SUM(Total_Commission_Amount_Paid__c) pd, 
                       SUM(Total_Commission_Amount_Pending__c) pn, SUM(Current_Commission_Payout_Now__c) el, 
                       COUNT(Id) c 
                FROM Commission_Line__c 
                WHERE Broker_Agency__c = :accountId 
                  AND Commission_Line_Type__c = 'External' 
                  AND Sales_Order__r.Unit__c != null
                WITH SYSTEM_MODE
            ];
            if (!ag.isEmpty()) {
                AggregateResult ar = ag[0];
                totalAmt = nz(ar.get('t'));
                paid     = nz(ar.get('pd'));
                pending  = nz(ar.get('pn'));
                eligible = nz(ar.get('el'));
                lineCount = (Integer) ar.get('c');
            }
        } catch (Exception e) {
            ctx.dataText = 'COMMISSION QUERY_ERROR: ' + e.getMessage();
            return ctx;
        }
        if (lineCount == 0) return ctx;

        List<Commission_Line__c> lines = new List<Commission_Line__c>();
        try {
            lines = [
                SELECT Status__c, Commission_Amount__c, Total_Commission_Amount_Paid__c, 
                       Current_Commission_Payout_Now__c, Total_Commission_Amount_Pending__c, 
                       Broker_Agent__r.Name, Invoice_Date__c, Sales_Order__r.Unit__r.Name, 
                       Sales_Order__r.Unit__r.Phase__r.Project__r.Name, 
                       Sales_Order__r.CustomerAccount__r.Name, CreatedDate 
                FROM Commission_Line__c 
                WHERE Broker_Agency__c = :accountId 
                  AND Commission_Line_Type__c = 'External' 
                  AND Sales_Order__r.Unit__c != null
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC 
                LIMIT 15
            ];
        } catch (Exception e) { /* keep summary even if line fetch fails */ }

        Integer n = 0;
        List<String> blocks = new List<String>();
        for (Commission_Line__c cl : lines) {
            n++;
            List<String> p = new List<String>();
            p.add('Line ' + n);
            addPart(p, 'Project', pathStr(cl, 'Sales_Order__r.Unit__r.Phase__r.Project__r.Name'));
            addPart(p, 'Unit', pathStr(cl, 'Sales_Order__r.Unit__r.Name'));
            addPart(p, 'Status', fieldStr(cl, 'Status__c'));
            addPart(p, 'Commission', fieldStr(cl, 'Commission_Amount__c'));
            addPart(p, 'PayoutNow', fieldStr(cl, 'Current_Commission_Payout_Now__c'));
            addPart(p, 'Pending', fieldStr(cl, 'Total_Commission_Amount_Pending__c'));
            addTok(p, ctx.tokenMap, 'Customer', 'NM' + n, pathStr(cl, 'Sales_Order__r.CustomerAccount__r.Name'));
            addTok(p, ctx.tokenMap, 'Agent', 'AG' + n, pathStr(cl, 'Broker_Agent__r.Name'));
            addPart(p, 'InvoiceDate', dateStr(cl, 'Invoice_Date__c'));
            blocks.add(String.join(p, ' | '));
        }

        ctx.dataText = 'COMMISSION_SUMMARY: Total=AED ' + fmt(totalAmt) + ' | Paid=AED ' + fmt(paid)
            + ' | Pending=AED ' + fmt(pending) + ' | EligibleNow=AED ' + fmt(eligible)
            + ' | Lines=' + lineCount + '\n'
            + 'SUGGESTED_COLUMNS=Project | Unit | Status | Commission | PayoutNow | Customer\n'
            + 'TOTAL_COMMISSION_LINES=' + lineCount + ' SHOWING=' + lines.size() + '\n'
            + String.join(blocks, '\n');
        ctx.hasData = true;
        return ctx;
    }

    // AGENCY (single Account record -> key/value)
    public static GroundedContext buildAgencyContext() {
        GroundedContext ctx = new GroundedContext();
        Id accountId = currentAccountId();
        if (accountId == null) return ctx;

        List<Account> accs;
        try {
            accs = [
                SELECT Name, Type_of_Registration__c, Agency_Region__c, Phone, 
                       Company_Email_Address__c, BillingCity, BillingCountry, Licensing_Authority__c, 
                       Trade_License_Number__c, TradeLicenseExpiryDate__c, Trade_License_Status__c, 
                       UAEVATRegisterNumber__c, UAE_VAT_Expiry_Date__c, VAT_Status__c, 
                       Bank_Name__c, Bank_Account_Number__c, IBAN_Number__c, Swift_Code__c, Bank_Status__c 
                FROM Account 
                WHERE Id = :accountId 
                WITH SYSTEM_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            ctx.dataText = 'QUERY_ERROR: ' + e.getMessage();
            return ctx;
        }
        if (accs.isEmpty()) return ctx;
        Account a = accs[0];

        List<String> p = new List<String>();
        p.add('AGENCY PROFILE (single record):');
        addPart(p, 'Name', fieldStr(a, 'Name'));
        addPart(p, 'Registration', fieldStr(a, 'Type_of_Registration__c'));
        addPart(p, 'Region', fieldStr(a, 'Agency_Region__c'));
        addPart(p, 'City', fieldStr(a, 'BillingCity'));
        addPart(p, 'Country', fieldStr(a, 'BillingCountry'));
        addPart(p, 'LicensingAuthority', fieldStr(a, 'Licensing_Authority__c'));
        addPart(p, 'TradeLicenseExpiry', dateStr(a, 'TradeLicenseExpiryDate__c'));
        addPart(p, 'TradeLicenseStatus', fieldStr(a, 'Trade_License_Status__c'));
        addPart(p, 'VATExpiry', dateStr(a, 'UAE_VAT_Expiry_Date__c'));
        addPart(p, 'VATStatus', fieldStr(a, 'VAT_Status__c'));
        addPart(p, 'BankName', fieldStr(a, 'Bank_Name__c'));
        addPart(p, 'BankStatus', fieldStr(a, 'Bank_Status__c'));
        addTok(p, ctx.tokenMap, 'Phone', 'PH1', fieldStr(a, 'Phone'));
        addTok(p, ctx.tokenMap, 'Email', 'EM1', fieldStr(a, 'Company_Email_Address__c'));
        addTok(p, ctx.tokenMap, 'TradeLicenseNo', 'TL1', fieldStr(a, 'Trade_License_Number__c'));
        addTok(p, ctx.tokenMap, 'VATNumber', 'VT1', fieldStr(a, 'UAEVATRegisterNumber__c'));
        addTok(p, ctx.tokenMap, 'BankAccount', 'BA1', fieldStr(a, 'Bank_Account_Number__c'));
        addTok(p, ctx.tokenMap, 'IBAN', 'IB1', fieldStr(a, 'IBAN_Number__c'));
        addTok(p, ctx.tokenMap, 'SWIFT', 'SW1', fieldStr(a, 'Swift_Code__c'));

        ctx.dataText = 'SINGLE_RECORD=true\n' + String.join(p, '\n');
        ctx.hasData = true;
        return ctx;
    }

    // AGENTS (Contacts in the agency)
    public static GroundedContext buildAgentsContext() {
        GroundedContext ctx = new GroundedContext();
        Id accountId = currentAccountId();
        if (accountId == null) return ctx;

        List<Contact> cons;
        try {
            cons = [
                SELECT FirstName, LastName, Email, Phone, MobilePhone, Broker_Type__c, 
                       Agent_Status__c, Nationality__c, IsBroker__c, Broker_Certificate_Number__c, 
                       EIDNumber__c, PassportNumber__c, LastModifiedDate 
                FROM Contact 
                WHERE AccountId = :accountId 
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC 
                LIMIT 50
            ];
        } catch (Exception e) {
            ctx.dataText = 'QUERY_ERROR: ' + e.getMessage();
            return ctx;
        }
        if (cons.isEmpty()) return ctx;

        Integer total = countAgency('Contact', 'AccountId', accountId, cons.size());

        Integer n = 0;
        List<String> blocks = new List<String>();
        for (Contact c : cons) {
            n++;
            List<String> p = new List<String>();
            p.add('Agent ' + n);
            p.add('Name=' + tokenize(ctx.tokenMap, 'NM' + n, buildName(c)));
            addPart(p, 'Type', fieldStr(c, 'Broker_Type__c'));
            addPart(p, 'Status', fieldStr(c, 'Agent_Status__c'));
            addPart(p, 'Nationality', fieldStr(c, 'Nationality__c'));
            addTok(p, ctx.tokenMap, 'Email', 'EM' + n, fieldStr(c, 'Email'));
            String mob = fieldStr(c, 'MobilePhone');
            if (String.isBlank(mob)) mob = fieldStr(c, 'Phone');
            addTok(p, ctx.tokenMap, 'Mobile', 'MB' + n, mob);
            addTok(p, ctx.tokenMap, 'EID', 'ID' + n, fieldStr(c, 'EIDNumber__c'));
            addTok(p, ctx.tokenMap, 'Passport', 'PP' + n, fieldStr(c, 'PassportNumber__c'));
            blocks.add(String.join(p, ' | '));
        }

        ctx.dataText = 'SUGGESTED_COLUMNS=Name | Type | Status | Email | Mobile | Nationality\n'
            + 'TOTAL_AGENTS=' + total + ' SHOWING=' + cons.size() + '\n'
            + String.join(blocks, '\n');
        ctx.hasData = true;
        return ctx;
    }

    // Helpers
    private static void addPart(List<String> parts, String label, String val) {
        if (String.isNotBlank(val)) parts.add(label + '=' + val);
    }

    // Adds 'label=<token>' only when the value is non-blank (tokenizes PII).
    private static void addTok(List<String> parts, Map<String, String> tokenMap,
                               String label, String key, String val) {
        if (String.isNotBlank(val)) parts.add(label + '=' + tokenize(tokenMap, key, val));
    }

    // Agency-scoped count with a fallback when the count query fails.
    private static Integer countAgency(String objName, String field, Id accountId, Integer fallback) {
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objName);
            if (sot == null || String.isBlank(field)
                || !Pattern.compile('^[A-Za-z][A-Za-z0-9_]*$').matcher(field).matches()) {
                return fallback;
            }
            String sanitizedObj = sot.getDescribe().getName();
            String sanitizedField = field;
            return Database.countQueryWithBinds(
                'SELECT count() FROM ' + sanitizedObj + ' WHERE ' + sanitizedField + ' = :accountId',
                new Map<String, Object>{ 'accountId' => accountId },
                AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            return fallback;
        }
    }

    private static Decimal nz(Object o) {
        return o == null ? 0 : (Decimal) o;
    }

    private static String fmt(Decimal d) {
        return (d == null ? Decimal.valueOf(0) : d).setScale(2).format();
    }

    // Direct field on an sObject.
    private static String fieldStr(SObject so, String f) {
        Object o = so.get(f);
        return o == null ? null : String.valueOf(o);
    }

    // Any field, including a dotted relationship path
    // (e.g. 'Sales_Order__r.Unit__r.Phase__r.Project__r.Name').
    private static String pathStr(SObject so, String dottedPath) {
        try {
            if (!dottedPath.contains('.')) return fieldStr(so, dottedPath);
            List<String> parts = dottedPath.split('\\.');
            SObject cur = so;
            for (Integer i = 0; i < parts.size() - 1; i++) {
                if (cur == null) return null;
                cur = cur.getSObject(parts[i]);
            }
            if (cur == null) return null;
            Object o = cur.get(parts[parts.size() - 1]);
            return o == null ? null : String.valueOf(o);
        } catch (Exception e) {
            return null;
        }
    }

    private static String dateStr(SObject so, String f) {
        Object o = so.get(f);
        if (o == null) return null;
        if (o instanceof Datetime) return ((Datetime) o).date().format();
        if (o instanceof Date) return ((Date) o).format();
        return String.valueOf(o);
    }

    private static String agentName(SObject ld) {
        // Use the text field on the Lead itself (no cross-object hop, which
        // fails for community/portal users) - populated by createOrUpdateLead.
        return fieldStr(ld, 'BrokerAgentName__c');
    }

    private static String buildName(SObject rec) {
        String fn = fieldStr(rec, 'FirstName');
        String ln = fieldStr(rec, 'LastName');
        fn = (fn == null) ? '' : fn;
        ln = (ln == null) ? '' : ln;
        return (fn + ' ' + ln).trim();
    }

    // Resolves the logged-in user's agency Account Id (or null).
    private static Id currentAccountId() {
        User u = MBP_BrokerLeadcontroller.getUserDetails(UserInfo.getUserId());
        return (u != null && u.Contact != null) ? u.Contact.AccountId : null;
    }

    // Stores token -> real value, returns the token. Blank -> '(none)'.
    // Tokens are pure-ASCII (@@KEY@@) so the source is paste-safe and the model
    // keeps them verbatim; e.g. @@NM1@@.
    private static String tokenize(Map<String, String> tokenMap, String key, String realValue) {
        if (String.isBlank(realValue)) return '(none)';
        String token = '@@' + key + '@@';
        tokenMap.put(token, realValue);
        return token;
    }

    // Replace any real value found in free text with its token (scrub the question).
    public static String redact(String s, Map<String, String> tokenMap) {
        if (String.isBlank(s) || tokenMap == null) return s;
        String out = s;
        for (String token : tokenMap.keySet()) {
            String real = tokenMap.get(token);
            if (String.isNotBlank(real)) {
                out = out.replace(real, token);
            }
        }
        return out;
    }

    // Replace tokens with real values in the model's answer.
    public static String unredact(String s, Map<String, String> tokenMap) {
        if (String.isBlank(s) || tokenMap == null) return s;
        String out = s;
        for (String token : tokenMap.keySet()) {
            out = out.replace(token, tokenMap.get(token));
        }
        return out;
    }
}