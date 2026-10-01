public class ManagementLeadController {
    public static Map<String,String> projectMap = new Map<String,String>();
    public static Map<String,String> phaseMap = new Map<String,String>();
    public static Map<String,String> unitMap = new Map<String,String>();
    
    @AuraEnabled(cacheable=true)
    public static loadWrapper getAvailableUnits(){
        loadWrapper lWrap = new loadWrapper();
        Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();
        List<PicklistOption> projectList = new List<PicklistOption>();
        List<PicklistOption> phaseList = new List<PicklistOption>();
        List<Unit__c> unitList = new List<Unit__c>();
        Map<String,List<PicklistOption>> projectPhaseMap = new Map<String,List<PicklistOption>>();
        projectList.add(new PicklistOption('-- All Projects --',''));
        //phaseList.add(new PicklistOption('-- All Phases --',''));
        Set<Id> projectIdset = new Set<Id>();
        For(Unit__c unit:[SELECT Id,Project_Name__c,Phase_Name__c,Status__c,TotalPrice__c,ApprovalStatus__c,Name,Phase__c,Phase__r.Name,Phase__r.Project__c,Phase__r.Project__r.Name,Sub_Status__c FROM Unit__c WHERE ApprovalStatus__c = 'Released' AND Sub_Status__c = 'Un-Assigned' AND (NOT Status__c IN ('Sold','Reserved'))]){
            if(unit.Phase__c <> null && unit.Phase__r.Project__c <> null && !projectMap.containsKey(unit.Phase__r.Project__c)){
                projectMap.put(unit.Phase__r.Project__c,unit.Phase__r.Project__r.Name);
                projectList.add(new PicklistOption(unit.Phase__r.Project__r.Name,unit.Phase__r.Project__c));
                projectIdset.add(unit.Phase__r.Project__c);
            }
            if(unit.Phase__c <> null && !phaseMap.containsKey(unit.Phase__c)){
                phaseMap.put(unit.Phase__c,unit.Phase__r.Name);
                phaseList.add(new PicklistOption(unit.Phase__r.Name,unit.Phase__c));
            }
            unitMap.put(unit.Name,unit.Id);
            unitList.add(unit);
        }
        for(Phase__c phase:[SELECT Id,Name,Project__r.name,Project__c FROM Phase__c WHERE Project__c IN:projectIdset ]){
            if(phase.Project__c <> null &&  projectPhaseMap.containsKey(phase.Project__r.name )){
                List<PicklistOption> tempPhaseList = new List<PicklistOption>();
                tempPhaseList.add(new PicklistOption(phase.Name,phase.Id));
                tempPhaseList.addAll(projectPhaseMap.get(phase.Project__r.name));
                projectPhaseMap.put(phase.Project__r.name,tempPhaseList);
            }else if(phase.Project__c <> null){
                List<PicklistOption> tempPhaseList = new List<PicklistOption>();
                tempPhaseList.add(new PicklistOption(phase.Name,phase.Id));
                projectPhaseMap.put(phase.Project__r.name,tempPhaseList);
            }
        }
        System.debug('projectPhaseMap::'+projectPhaseMap);
        picklistMap.put('projectList',projectList);
        picklistMap.put('phaseList',phaseList);  
        lWrap.PicklistOptionMap = picklistMap;
        lWrap.unitList = unitList;
        lWrap.projectPhaseMap = projectPhaseMap;
        return lWrap;
    }
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    public class loadWrapper {
        @AuraEnabled public Map<String, List<PicklistOption>> PicklistOptionMap = new Map<String, List<PicklistOption>>();
        @AuraEnabled public List<Unit__c> unitList = new List<Unit__c>();
        @AuraEnabled public Map<String,List<PicklistOption>> projectPhaseMap = new Map<String,List<PicklistOption>>();
    }
    @AuraEnabled(cacheable=true)
    public static List<User> searchUsers(String searchTerm) {
        String searchKey = '%' + searchTerm + '%';
        List<User> users = [
            SELECT Id, Name, Email
            FROM User
            WHERE IsActive = TRUE AND (Name LIKE :searchKey OR Email LIKE :searchKey)
            ORDER BY Name
            LIMIT 10
        ];
        return users;
    }
    @AuraEnabled
    public static void createLead(String firstName, String lastName, String email, String mobile, String salesPersonName, List<Id> selectedRowIds,dateTime blockedUntil) {
        try {
            System.debug('salesPersonName::' + salesPersonName);
            System.debug('selectedRowIds::' + selectedRowIds);
            
            // -----------------------------
            // 0) Duplicate PRE-CHECK (blocking)
            // -----------------------------
            // We only attempt duplicate detection if at least one identifier is present
            Boolean hasIdentifier = !String.isBlank(email) || !String.isBlank(mobile);
            List<String> dupErrors = new List<String>();
            
            Set<Id> unitIds = new Set<Id>();
            if (selectedRowIds != null) unitIds.addAll(selectedRowIds);
            
            // Normalize values for key building
            String normEmail  = String.isBlank(email)  ? '' : email.trim().toLowerCase();
            String normMobile = String.isBlank(mobile) ? '' : mobile.trim();
            String sourceKey  = 'management lead'; // normalized
            
            // Build candidate keys (what we plan to create)
            Set<String> candidateKeys = new Set<String>();
            if (hasIdentifier) {
                if (!unitIds.isEmpty()) {
                    // Allocated case: one lead per unit
                    for (Id uid : unitIds) {
                        candidateKeys.add(normEmail + '|' + normMobile + '|' + 'allocated' + '|' + String.valueOf(uid) + '|' + sourceKey);
                    }
                } else {
                    // Un-Allocated case: single lead without a unit
                    candidateKeys.add(normEmail + '|' + normMobile + '|' + 'un-allocated' + '|' + '' + '|' + sourceKey);
                }
                
                // Query existing "in-progress" leads and build keys to compare
                List<Lead> existing;
                if (!unitIds.isEmpty()) {
                    // Match by units; we'll compare email/mobile in Apex
                    existing = [
                        SELECT Id, Email, MobilePhone, Unit_Allocated_Status__c, Referral_Unit__c,
                        LeadSource, Status, IsConverted
                        FROM Lead
                        WHERE IsConverted = false
                        AND Status != 'Retired'
                        AND LeadSource = 'Management Lead'
                        AND Referral_Unit__c IN :unitIds
                    ];
                } else {
                    // Un-Allocated + no unit
                    existing = [
                        SELECT Id, Email, MobilePhone, Unit_Allocated_Status__c, Referral_Unit__c,
                        LeadSource, Status, IsConverted
                        FROM Lead
                        WHERE IsConverted = false
                        AND Status != 'Retired'
                        AND LeadSource = 'Management Lead'
                        AND Unit_Allocated_Status__c = 'Un-Allocated'
                        AND Referral_Unit__c = null
                    ];
                }
                
                Set<String> existingKeys = new Set<String>();
                for (Lead ex : existing) {
                    String e  = String.isBlank(ex.Email)        ? '' : ex.Email.trim().toLowerCase();
                    String m  = String.isBlank(ex.MobilePhone)  ? '' : ex.MobilePhone.trim();
                    String s  = String.isBlank(ex.Unit_Allocated_Status__c) ? '' : ex.Unit_Allocated_Status__c.trim().toLowerCase();
                    String u  = ex.Referral_Unit__c == null ? '' : String.valueOf(ex.Referral_Unit__c);
                    String ls = String.isBlank(ex.LeadSource)   ? '' : ex.LeadSource.trim().toLowerCase();
                    existingKeys.add(e + '|' + m + '|' + s + '|' + u + '|' + ls);
                }
                
                // Friendly messages (fetch unit names if needed)
                Map<Id,String> unitNameById = new Map<Id,String>();
                if (!unitIds.isEmpty()) {
                    for (Unit__c uRec : [SELECT Id, Name FROM Unit__c WHERE Id IN :unitIds]) {
                        unitNameById.put(uRec.Id, uRec.Name);
                    }
                    for (Id uid : unitIds) {
                        String k = normEmail + '|' + normMobile + '|' + 'allocated' + '|' + String.valueOf(uid) + '|' + sourceKey;
                        if (existingKeys.contains(k)) {
                            dupErrors.add('A lead is already in progress for unit "' + (unitNameById.get(uid) != null ? unitNameById.get(uid) : String.valueOf(uid)) + '" with the same Email/Mobile.');
                        }
                    }
                } else {
                    String k = normEmail + '|' + normMobile + '|' + 'un-allocated' + '|' + '' + '|' + sourceKey;
                    if (existingKeys.contains(k)) {
                        dupErrors.add('A lead is already in progress (Un-Allocated) with the same Email/Mobile.');
                    }
                }
                
                if (!dupErrors.isEmpty()) {
                    // Block the operation before any DML
                    throw new AuraHandledException(String.join(dupErrors, '\n'));
                }
            }
            // -----------------------------
            // 1) Build records (as in your code)
            // -----------------------------
            List<String> errorMessages = new List<String>();
            List<Lead> leadObjList = new List<Lead>();
            String projectInterest = 'Muheira';
            if (selectedRowIds != null && !selectedRowIds.isEmpty()) {
                List<Unit__c> unitList = new List<Unit__c>();
                String unitName = ''; 
                String unitIdsVal = '';
                String projectName = '';
			    for (Unit__c unit : [SELECT Id, Name,Phase__r.Project__r.Name FROM Unit__c WHERE Id IN :selectedRowIds]) {
                    Unit__c u = new Unit__c();
                    u.Id               = unit.Id;
                    u.BlockedBy__c     = UserInfo.getUserId();
                    u.BlockedFor__c    = salesPersonName;
                    u.Sub_Status__c    = 'Assigned';
                    u.BlockComment__c  = 'Management Lead';
                    u.BlockUntil__c = blockedUntil;
                    //u.status__c = 'Reserved';
                    unitList.add(u);
                    unitName += unit.Name+',';
                    unitIdsVal += unit.Id+',';
                    if(!projectName.contains(unit.Phase__r.Project__r.Name)){
                       projectName += unit.Phase__r.Project__r.Name+',';
                       projectInterest = unit.Phase__r.Project__r.name;
                    }
                }
                unitName = unitName.removeEnd(',');
                unitIdsVal = unitIdsVal.removeEnd(',');
                projectName = projectName.removeEnd(',');
                if (!unitList.isEmpty()) {
                        Database.SaveResult[] srUnits = Database.update(unitList, false);
                        for (Integer i = 0; i < srUnits.size(); i++) {
                            if (!srUnits[i].isSuccess()) {
                                for (Database.Error de : srUnits[i].getErrors()) {
                                    errorMessages.add('Unit ' + String.valueOf(unitList[i].Id) + ': ' + de.getMessage());
                                }
                            }
                        }
                    }               
                    Lead leadObj = new Lead();
                    leadObj.Unit_Allocated_Status__c = 'Allocated';
                    leadObj.FirstName    = firstName;
                    leadObj.LastName     = lastName;
                    leadObj.Email        = email;
                    leadObj.MobilePhone  = mobile;
                	if(salesPersonName <> null){
                    	leadObj.OwnerId      = salesPersonName;
                    }
                    leadObj.LeadSource   = 'Management Lead';
                    leadObj.Referral_Type__c = 'Management';
                    leadObj.Referral_Approve_Reject_By__c = UserInfo.getUserId();
                    leadObj.Referral_Unit_Name__c = unitName;
                    leadObj.Referral_Unit_Ids__c =  unitIdsVal;
                    leadObj.Referral_Project_Name__c = projectName;
                    leadObj.ProjectInterest__c = projectInterest;
                    leadObjList.add(leadObj);
                
            } else {
                Lead leadObj = new Lead();
                leadObj.FirstName    = firstName;
                leadObj.LastName     = lastName;
                leadObj.Email        = email;
                leadObj.MobilePhone  = mobile;
                if(salesPersonName <> null){
                	leadObj.OwnerId      = salesPersonName;
                }
                leadObj.LeadSource   = 'Management Lead';
                leadObj.Referral_Type__c = 'Management';
                leadObj.Referral_Approve_Reject_By__c = UserInfo.getUserId();
                leadObj.Unit_Allocated_Status__c = 'Un-Allocated';
                leadObjList.add(leadObj);
            }
            
            // -----------------------------
            // 2) Insert leads (partial success) and collect errors
            // -----------------------------
            for (Lead l : leadObjList) {
                Database.SaveResult srLead = Database.insert(l, false);
                if (!srLead.isSuccess()) {
                    for (Database.Error de : srLead.getErrors()) {
                        errorMessages.add('Lead: ' + de.getMessage());
                    }
                }
            }
            
            if (!errorMessages.isEmpty()) {
                throw new AuraHandledException(String.join(errorMessages, '\n'));
            }
            
        } catch (AuraHandledException ahe) {
            throw ahe; // surface clean message to LWC
        } catch (DmlException dml) {
            throw new AuraHandledException('Create Lead failed: ' + dml.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Create Lead failed: ' + ex.getMessage());
        }
    }
    
    //************ Management Lead History ********************//
    @AuraEnabled(cacheable=true)
    public static List<managementLeadWrapper> getManagementLeads(){
        Set<Id> ownerIdset = new Set<Id>();
        
        // A) Collect owner ids
        for (Lead lead : [
            SELECT Id, Name, OwnerId
            FROM Lead
            WHERE LeadSource = 'Management Lead'
        ]) {
            ownerIdset.add(lead.OwnerId);
        }
        
        // B) Owner map
        Map<Id,String> ownerMap = new Map<Id,String>();
        for (User user : [SELECT Id, Name FROM User WHERE Id IN :ownerIdset]) {
            ownerMap.put(user.Id, user.Name);
        }
        
        // C) Main query — include Unit lookup + name + CreatedDate
        List<managementLeadWrapper> leadList = new List<managementLeadWrapper>();
        for (Lead lead : [
            SELECT Id, Name, Status, OwnerId, Email, MobilePhone, LeadSource,
            Unit_Allocated_Status__c, Referral_Unit__c, Referral_Unit__r.Name,
            Referral_Unit_Name__c, Lead_Age_Days__c,Referral_Project_Name__c,
            IsConverted, ConvertedOpportunityId, CreatedDate
            FROM Lead
            WHERE LeadSource = 'Management Lead'
             ORDER BY CreatedDate DESC
        ]) {
            managementLeadWrapper m = new managementLeadWrapper();
            m.Id                   = lead.Id;
            m.Name                 = lead.Name;
            m.Email                = lead.Email;
            m.Mobile               = lead.MobilePhone;
            m.LeadSource           = lead.LeadSource;
            m.UnitAllocatedStatus  = lead.Unit_Allocated_Status__c;
            m.leadStatus           = lead.Status;
            m.IsConverted          = lead.IsConverted ? 'Yes' : 'No';
            m.LeadAgeHistory       = lead.Lead_Age_Days__c != null ? String.valueOf(lead.Lead_Age_Days__c) + ' Days' : '0 Days';
            m.OwnerName            = ownerMap.get(lead.OwnerId);
            m.CreatedDate          = lead.CreatedDate;
            m.projectName = lead.Referral_Project_Name__c;
            // NEW: Unit info (prefer relationship name; fall back to existing text field if you have it)
            m.ReferralUnitId       = lead.Referral_Unit__c;
            m.ReferralUnitName     = lead.Referral_Unit_Name__c;//(lead.Referral_Unit__r != null ? lead.Referral_Unit__r.Name : null);
           // if (m.ReferralUnitName == null) m.ReferralUnitName = lead.Referral_Unit_Name__c;
            
            leadList.add(m);
        }
        return leadList;
    }
    
    public class managementLeadWrapper{
        @AuraEnabled public String  Name;
        @AuraEnabled public Id      Id;
        @AuraEnabled public String  Email;
        @AuraEnabled public String  Mobile;
        @AuraEnabled public String  LeadSource;
        @AuraEnabled public String  UnitAllocatedStatus;
        @AuraEnabled public String  leadStatus;
        @AuraEnabled public String  IsConverted;
        @AuraEnabled public String  LeadAgeHistory;
        @AuraEnabled public String  OwnerName;
        @AuraEnabled public String  newOwnerName;
        @AuraEnabled public Datetime CreatedDate;     // keep as Datetime for accuracy
        @AuraEnabled public String projectName;
        // NEW:
        @AuraEnabled public Id      ReferralUnitId;
        @AuraEnabled public String  ReferralUnitName;
    }
    
    //********* Re-Assign Management Lead History ***********//
    @AuraEnabled
    public static ReassignResult reassignLeadOwners(List<Id> leadIds, Id newOwnerId,DateTime blockedUntil) {
        ReassignResult res = new ReassignResult();
        if (leadIds == null || leadIds.isEmpty() || newOwnerId == null) {
            res.errorCount = 1;
            res.errors.add(new ReassignError('N/A','leadIds/newOwnerId missing'));
            return res;
        }
        
        User u = [SELECT Id, Name FROM User WHERE Id = :newOwnerId LIMIT 1];
        res.ownerName = u.Name;
        
        List<Lead> toUpdate = [
            SELECT Id, OwnerId,Referral_Unit_Ids__c
            FROM Lead
            WHERE Id IN :leadIds
        ];
        List<String> unitIdset = new List<String>();
        for (Lead l : toUpdate){
            l.OwnerId = newOwnerId;
            if(l.Referral_Unit_Ids__c <> null){
            	unitIdset = l.Referral_Unit_Ids__c.contains(',') ? l.Referral_Unit_Ids__c.split(',') : new List<String>{l.Referral_Unit_Ids__c};
            }
         }
        if(!unitIdset.isEmpty()){
            List<Unit__c> unitList = new List<Unit__c>();
            for(Unit__c unit:[SELECT Id FROM Unit__c WHERE Id IN: unitIdset]){
                Unit__c unitObj = new Unit__c();
                unitObj.Id               = unit.Id;
                unitObj.BlockedBy__c     = UserInfo.getUserId();
                unitObj.BlockedFor__c    = newOwnerId;
                unitObj.Sub_Status__c    = 'Assigned';
                unitObj.BlockComment__c  = 'Management Lead';
                unitObj.BlockUntil__c = blockedUntil;
                //unitObj.status__c = 'Reserved';
                unitList.add(unitObj);
            }
            if(!unitList.isEmpty()){
                update unitList;
            }
        }
        try {
            Database.SaveResult[] srs = Database.update(toUpdate, false);
            for (Integer i = 0; i < srs.size(); i++) {
                if (srs[i].isSuccess()) {
                    res.successIds.add(toUpdate[i].Id);
                } else {
                    for (Database.Error e : srs[i].getErrors()) {
                        res.errors.add(new ReassignError(String.valueOf(toUpdate[i].Id), e.getMessage()));
                        res.errorCount++;
                    }
                }
            }
            if(!res.successIds.isEmpty()){
                List<Task> taskList = new List<Task>();
                for(Task task:[SELECT Id FROM Task WHERE WhoId IN:res.successIds AND Status = 'Open' ]){
                    Task taskUpdate = new Task();
                    taskUpdate.Id = task.Id;
                    taskUpdate.OwnerId = newOwnerId;
                    taskList.add(taskUpdate);
                }
                if(!taskList.isEmpty()){
                    update taskList;
                }
            }
            res.successCount = res.successIds.size();
        } catch (Exception e) {
            res.errors.add(new ReassignError('N/A', e.getMessage()));
            res.errorCount++;
        }
        return res;
    }
    
    public class ReassignResult {
        @AuraEnabled public List<Id> successIds = new List<Id>();
        @AuraEnabled public Integer successCount = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public String ownerName;
        @AuraEnabled public List<ReassignError> errors = new List<ReassignError>();
    }
    public class ReassignError {
        @AuraEnabled public String id;
        @AuraEnabled public String message;
        public ReassignError(String i, String m) { id = i; message = m; }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getNamesByEmail(List<String> emails) {
        // Guard
        if (emails == null || emails.isEmpty()) return new Map<String, String>();
        
        // Dedup & trim
        Set<String> emailSet = new Set<String>();
        for (String e : emails) {
            if (e != null) emailSet.add(e.trim());
        }
        if (emailSet.isEmpty()) return new Map<String, String>();
        
        // Query Users by Email (common for salespeople). Add Contacts if you store them there.
        Map<String, String> byEmail = new Map<String, String>();
        for (User u : [
            SELECT Name, Email
            FROM User
            WHERE Email IN :emailSet
        ]) {
            if (u.Email != null) byEmail.put(u.Email, u.Name);
        }
        
        return byEmail;
    }
    @AuraEnabled(cacheable=true)
    public static List<Option> searchUsersByName(String q, Integer limitSize) {
        String query = (q == null) ? '' : q.trim();
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 50) ? 20 : limitSize;
        
        // Basic active user search by Name OR Email
        List<User> users = [
            SELECT Id, Name, Email
            FROM User
            WHERE IsActive = true
            AND (Name LIKE :('%' + query + '%') OR Email LIKE :('%' + query + '%'))
            ORDER BY Name
            LIMIT :lim
        ];
        
        List<Option> out = new List<Option>();
        for (User u : users) {
            String label = u.Name + (u.Email != null ? ' — ' + u.Email : '');
            out.add(new Option(u.Id, label, u.Email));
        }
        return out;
    }
    
    public class Option {
        @AuraEnabled public String value; // User.Id
        @AuraEnabled public String label; // "Name — Email"
        @AuraEnabled public String email; // for convenience
        public Option(String v, String l, String e) {
            value = v; label = l; email = e;
        }
    }
    //************ LEAD FROM CSV **********************//
     // ===== DTOs =====
    public class RowError {
        @AuraEnabled public Integer rowNumber;
        @AuraEnabled public String message;
        public RowError(Integer rowNumber, String message) {
            this.rowNumber = rowNumber; this.message = message;
        }
    }
    public class RowOutcome {
        @AuraEnabled public Integer rowId;   // mirrors client _rowId
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;  // "Created" or error reason
        @AuraEnabled public Id recordId;     // created Lead Id (if success)
        public RowOutcome(Integer rowId, Boolean success, String message, Id recordId) {
            this.rowId = rowId; this.success = success; this.message = message; this.recordId = recordId;
        }
    }
    public class CreateResult {
        @AuraEnabled public Integer createdCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<RowError> errors;
        @AuraEnabled public List<RowOutcome> outcomes; // per-row results
    }

    // ===== Utility =====
    private static String stringValue(Object v) {
        if (v == null) return null;
        if (v instanceof String) return (String)v;
        return String.valueOf(v);
    }
    private static String nvl(String a, String b) {
        return String.isBlank(a) ? b : a;
    }
    private static void maybePut(SObject sob, String fieldApi, Object val) {
        String s = stringValue(val);
        if (!String.isBlank(s)) sob.put(fieldApi, s.trim());
    }
    private static String firstError(Database.SaveResult r) {
        if (r == null || r.getErrors() == null || r.getErrors().isEmpty()) return 'Unknown error';
        return r.getErrors()[0].getMessage();
    }
   // Normalizes any object to a safe, comparable string (never null)
    private static String normStr(Object o, Boolean lower) {
        if (o == null) return '';
        String s = String.valueOf(o).trim();
        return lower ? s.toLowerCase() : s;
    }
    
    private static String makeCompositeKey(
        String email,
        String mobile,
        String allocStatus,
        String referralUnitId,
        String leadSource
    ) {
        List<String> parts = new List<String>{
            normStr(email,       true),
            normStr(mobile,      true),
            normStr(allocStatus, true),
            normStr(referralUnitId, false),  // keep Id case as-is
            normStr(leadSource,  true)
        };
        return String.join(parts, '||');
    }

    // ====== Main: create leads & return per-row outcomes ======
    @AuraEnabled
    public static CreateResult createLeadsFromCsv(
        List<Map<String, Object>> rows,
        String salesPersonEmailColumn,
        String unitColumn
    ) {
        CreateResult out = new CreateResult();
        out.createdCount = 0;
        out.errorCount = 0;
        out.errors = new List<RowError>();
        out.outcomes = new List<RowOutcome>();

        if (rows == null || rows.isEmpty()) return out;

        // Normalize incoming column keys
        String emailCol = salesPersonEmailColumn;
        String unitCol  = unitColumn;

        // Collect lookups from CSV
        Set<String> ownerEmails = new Set<String>();
        Set<String> unitNames   = new Set<String>();

        // For duplicate pre-checks
        Set<String> leadEmails     = new Set<String>();
        Set<String> leadMobiles    = new Set<String>();
        Set<String> leadSources    = new Set<String>();
        Set<String> allocStatuses  = new Set<String>();

        Integer rowIdx = 0;
        for (Map<String, Object> r : rows) {
            rowIdx++;
            if (!String.isBlank(emailCol) && r.containsKey(emailCol)) {
                String em = stringValue(r.get(emailCol));
                if (!String.isBlank(em)) ownerEmails.add(em.trim());
            }
            if (!String.isBlank(unitCol) && r.containsKey(unitCol)) {
                String un = stringValue(r.get(unitCol));
                if (!String.isBlank(un)) unitNames.add(un.trim());
            }
            String lEmail  = stringValue(r.get('Email'));
            String lMobile = stringValue(r.get('MobilePhone'));
            if (!String.isBlank(lEmail))  leadEmails.add(lEmail.trim());
            if (!String.isBlank(lMobile)) leadMobiles.add(lMobile.trim());
            leadSources.add('Management Lead');
        }
        allocStatuses.add('Allocated');
        allocStatuses.add('Un-Allocated');

        // Owners
        Map<String, Id> ownerByEmail = new Map<String, Id>();
        if (!ownerEmails.isEmpty()) {
            for (User u : [
                SELECT Id, Email
                FROM User
                WHERE IsActive = true AND Email IN :ownerEmails
            ]) if (u.Email != null) ownerByEmail.put(u.Email.trim(), u.Id);
        }

        // Units
        Map<String, Unit__c> unitByName = new Map<String, Unit__c>();
        if (!unitNames.isEmpty()) {
            for (Unit__c u : [
                SELECT Id, Name
                FROM Unit__c
                WHERE Name IN :unitNames
            ]) if (u.Name != null) unitByName.put(u.Name.trim(), u);
        }
        Set<Id> unitIdsForQuery = new Set<Id>();
        for (String nm : unitNames) {
            Unit__c u = unitByName.get(nm);
            if (u != null) unitIdsForQuery.add(u.Id);
        }

        // Pre-query existing in-progress leads (IsConverted=false, Status!=Retired)
        Map<Id, Lead> existingMap = new Map<Id, Lead>();
        if (!leadEmails.isEmpty()) {
            for (Lead ex : [
                SELECT Id, Email, MobilePhone, LeadSource, Referral_Unit__c, Unit_Allocated_Status__c, Status, IsConverted
                FROM Lead
                WHERE IsConverted=false AND Status!='Retired' AND Email IN :leadEmails
            ]) existingMap.put(ex.Id, ex);
        }
        if (!leadMobiles.isEmpty()) {
            for (Lead ex : [
                SELECT Id, Email, MobilePhone, LeadSource, Referral_Unit__c, Unit_Allocated_Status__c, Status, IsConverted
                FROM Lead
                WHERE IsConverted=false AND Status!='Retired' AND MobilePhone IN :leadMobiles
            ]) existingMap.put(ex.Id, ex);
        }
        if (!unitIdsForQuery.isEmpty()) {
            for (Lead ex : [
                SELECT Id, Email, MobilePhone, LeadSource, Referral_Unit__c, Unit_Allocated_Status__c, Status, IsConverted
                FROM Lead
                WHERE IsConverted=false AND Status!='Retired' AND Referral_Unit__c IN :unitIdsForQuery
            ]) existingMap.put(ex.Id, ex);
        }
        if (!leadSources.isEmpty()) {
            for (Lead ex : [
                SELECT Id, Email, MobilePhone, LeadSource, Referral_Unit__c, Unit_Allocated_Status__c, Status, IsConverted
                FROM Lead
                WHERE IsConverted=false AND Status!='Retired' AND LeadSource IN :leadSources
            ]) existingMap.put(ex.Id, ex);
        }
        if (!allocStatuses.isEmpty()) {
            for (Lead ex : [
                SELECT Id, Email, MobilePhone, LeadSource, Referral_Unit__c, Unit_Allocated_Status__c, Status, IsConverted
                FROM Lead
                WHERE IsConverted=false AND Status!='Retired' AND Unit_Allocated_Status__c IN :allocStatuses
            ]) existingMap.put(ex.Id, ex);
        }

        Set<String> existingKeys = new Set<String>();
        for (Lead ex : existingMap.values()) {
            existingKeys.add(makeCompositeKey(
                ex.Email,
                ex.MobilePhone,
                ex.Unit_Allocated_Status__c,
                (String)ex.get('Referral_Unit__c'),
                ex.LeadSource
            ));
        }

        // Build list to insert + keep mapping to input row ids
        List<Lead> toInsert = new List<Lead>();
        List<Integer> sourceRowIds = new List<Integer>();

        rowIdx = 0;
        for (Map<String, Object> r : rows) {
            rowIdx++;

            // Try to preserve client row key
            Integer rowIdFromClient = null;
            if (r != null && r.containsKey('_rowId')) {
                Object rv = r.get('_rowId');
                if (rv instanceof Integer)        rowIdFromClient = (Integer) rv;
                else if (rv instanceof Long)      rowIdFromClient = Integer.valueOf((Long) rv);
                else if (rv instanceof String)    rowIdFromClient = Integer.valueOf((String) rv);
            }
            Integer rowKey = (rowIdFromClient == null) ? rowIdx : rowIdFromClient;

            try {
                Lead l = new Lead();
                l.LeadSource       = 'Management Lead';
                l.Referral_Type__c = 'Management';

                // Names
                String lastName  = stringValue(r.get('LastName'));
                String firstName = stringValue(r.get('FirstName'));
                if (String.isBlank(lastName)) {
                    String nm = stringValue(r.get('Name'));
                    String ln = stringValue(r.get('Surname'));
                    if (!String.isBlank(nm)) lastName = nm;
                    else if (!String.isBlank(ln)) lastName = ln;
                    else if (!String.isBlank(firstName)) lastName = firstName;
                    else lastName = 'Unknown';
                }
                l.FirstName = firstName;
                l.LastName  = lastName;

                // Company
                l.Company = nvl(stringValue(r.get('Company')), 'Unknown Company');

                // Optional mappings
                maybePut(l, 'Email',        r.get('Email'));
                maybePut(l, 'Phone',        r.get('Phone'));
                maybePut(l, 'MobilePhone',  r.get('MobilePhone'));
                maybePut(l, 'Title',        r.get('Title'));
                maybePut(l, 'Street',       r.get('Street'));
                maybePut(l, 'City',         r.get('City'));
                maybePut(l, 'State',        r.get('State'));
                maybePut(l, 'PostalCode',   r.get('PostalCode'));
                maybePut(l, 'Country',      r.get('Country'));
                maybePut(l, 'Description',  r.get('Description'));

                // Owner by Sales Person Email
                if (!String.isBlank(emailCol)) {
                    String em = stringValue(r.get(emailCol));
                    if (!String.isBlank(em)) {
                        Id ownerId = ownerByEmail.get(em.trim());
                        if (ownerId != null) l.OwnerId = ownerId;
                    }
                }

                // Unit mapping -> Referral_Unit__c + Unit_Allocated_Status__c
                String unitName = String.isBlank(unitCol) ? null : stringValue(r.get(unitCol));
                if (!String.isBlank(unitName) && unitByName.containsKey(unitName.trim())) {
                    Unit__c unitRec = unitByName.get(unitName.trim());
                    l.Referral_Unit__c         = unitRec.Id;
                    l.Unit_Allocated_Status__c = 'Allocated';
                } else {
                    l.Unit_Allocated_Status__c = 'Un-Allocated';
                }

                // Composite duplicate key
                String candidateKey = makeCompositeKey(
                    (String) l.get('Email'),
                    (String) l.get('MobilePhone'),
                    (String) l.get('Unit_Allocated_Status__c'),
                    (String) l.get('Referral_Unit__c'),
                    (String) l.get('LeadSource')
                );
                if (existingKeys.contains(candidateKey)) {
                    out.errorCount++;
                    String msg = 'Duplicate in-progress lead exists for same Email/Mobile/Unit/Status/Lead Source';
                    out.errors.add(new RowError(rowIdx, msg));
                    out.outcomes.add(new RowOutcome(rowKey, false, msg, null));
                    continue;
                }

                toInsert.add(l);
                sourceRowIds.add(rowKey);

            } catch (Exception buildEx) {
                out.errorCount++;
                String msg = 'Build error: ' + buildEx.getMessage();
                out.errors.add(new RowError(rowIdx, msg));
                out.outcomes.add(new RowOutcome(rowKey, false, msg, null));
            }
        }

        // DML with partial success
        if (!toInsert.isEmpty()) {
            Database.SaveResult[] sr = Database.insert(toInsert, /*allOrNone*/ false);
            for (Integer i = 0; i < sr.size(); i++) {
                Database.SaveResult res = sr[i];
                Integer srcRowId = sourceRowIds[i];
                if (res.isSuccess()) {
                    out.createdCount++;
                    out.outcomes.add(new RowOutcome(srcRowId, true, 'Created', res.getId()));
                } else {
                    out.errorCount++;
                    String msg = firstError(res);
                    out.errors.add(new RowError(i + 1, msg));
                    out.outcomes.add(new RowOutcome(srcRowId, false, msg, null));
                }
            }
        }
        return out;
    }
    
    //*************** CSV Lead Creation End************* //
    // ======== PENDING APPROVAL LIST ========
    @AuraEnabled(cacheable=true)
    public static List<approvalLeadWrapper> getPendingApprovalLeads() {
        // Owner names for display
        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : [
            SELECT OwnerId
            FROM Lead
            WHERE LeadSource = 'Management Lead'
            AND Referral_Approval_Status__c = 'Pending for Approval'
            AND IsConverted = false
        ]) ownerIds.add(l.OwnerId);
        
        Map<Id, String> ownerMap = new Map<Id, String>();
        if (!ownerIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :ownerIds]) {
                ownerMap.put(u.Id, u.Name);
            }
        }
        
        List<approvalLeadWrapper> out = new List<approvalLeadWrapper>();
        for (Lead l : [
            SELECT Id, Name, Email, MobilePhone, Status, OwnerId, CreatedDate,
            Unit_Allocated_Status__c,
            Referral_Unit__c, Referral_Unit__r.Name, Referral_Unit_Name__c,
            Lead_Age_Days__c, Referral_Approval_Status__c,Referral_Approval_Comments__c,RetiredReason__c,RetirementComments__c   
            FROM Lead
            WHERE LeadSource = 'Management Lead'
            AND Referral_Approval_Status__c = 'Pending for Approval'
            AND IsConverted = false
            ORDER BY CreatedDate DESC
        ]) {
            approvalLeadWrapper w = new approvalLeadWrapper();
            w.Id                    = l.Id;
            w.Name                  = l.Name;
            w.Email                 = l.Email;
            w.Mobile                = l.MobilePhone;
            w.leadStatus            = l.Status;
            w.OwnerName             = ownerMap.get(l.OwnerId);
            w.CreatedDate           = l.CreatedDate;
            w.UnitAllocatedStatus   = l.Unit_Allocated_Status__c;
            w.ReferralUnitId        = l.Referral_Unit__c;
            w.ReferralUnitName      = l.Referral_Unit_Name__c;//(l.Referral_Unit__r != null ? l.Referral_Unit__r.Name : l.Referral_Unit_Name__c);
            w.LeadAgeHistory        = l.Lead_Age_Days__c != null ? String.valueOf(l.Lead_Age_Days__c) + ' Days' : '0 Days';
            w.RetireLeadReason = l.RetiredReason__c;
            w.RetireLeadComments = l.RetirementComments__c; 
            
            out.add(w);
        }
        return out;
    }
    
    // Wrapper for the new component
    public class approvalLeadWrapper {
        @AuraEnabled public Id       Id;
        @AuraEnabled public String   Name;
        @AuraEnabled public String   Email;
        @AuraEnabled public String   Mobile;
        @AuraEnabled public String   OwnerName;
        @AuraEnabled public String   leadStatus;
        @AuraEnabled public String   LeadAgeHistory;
        @AuraEnabled public String   UnitAllocatedStatus;
        @AuraEnabled public Id       ReferralUnitId;
        @AuraEnabled public String   ReferralUnitName;
        @AuraEnabled public Datetime CreatedDate;
        @AuraEnabled public String   RetireLeadReason;
        @AuraEnabled public String RetireLeadComments;
        
    }
    
    // ======== APPROVE / REJECT ACTION ========
    @AuraEnabled
    public static ApprovalActionResult updateReferralApprovalStatus(List<Id> leadIds, String decision) {
        ApprovalActionResult res = new ApprovalActionResult();
        if (leadIds == null || leadIds.isEmpty() || String.isBlank(decision)) {
            res.errorCount = 1;
            res.errors.add(new ReassignError('N/A', 'leadIds/decision missing'));
            return res;
        }
        
        // Use the exact picklist values you maintain in your org.
        // If your picklist uses "Approved" instead of "Approve", change accordingly.
        String target = (decision != null && decision.toLowerCase() == 'approve') ? 'Approved' : 'Rejected';
        
        List<Lead> toUpdate = [
            SELECT Id, Referral_Approval_Status__c,Referral_Unit_Ids__c
            FROM Lead
            WHERE Id IN :leadIds
        ];
        Map<Id,List<String>> leadUnitsMap = new Map<Id,List<String>>();
        for (Lead l : toUpdate){
            l.Referral_Approval_Status__c = target;
            if(target != 'Approved'){
              l.Referral_Approval_Comments__c = '';
            }
            if(target == 'Approved'){
                l.Status = 'Retired';
                l.Referral_Approval_Status__c = target;
                l.Referral_Approval_Date__c = System.today();
                if(target == 'Approved' && l.Referral_Unit_Ids__c <> null){
                    List<String> unitIdList = l.Referral_Unit_Ids__c.contains(',') ? l.Referral_Unit_Ids__c.split(',') : new List<String>{l.Referral_Unit_Ids__c};
                    leadUnitsMap.put(l.Id,unitIdList);
                }
            }
        }
        Set<Id> successLeadIdset = new Set<Id>();
        Database.SaveResult[] srs = Database.update(toUpdate, false);
        for (Integer i = 0; i < srs.size(); i++) {
            if (srs[i].isSuccess()) {
                res.successIds.add(toUpdate[i].Id);
                successLeadIdset.add(toUpdate[i].Id);
            } else {
                for (Database.Error e : srs[i].getErrors()) {
                    system.debug('Error:'+e.getMessage());
                    res.errorCount++;
                    res.errors.add(new ReassignError(String.valueOf(toUpdate[i].Id), e.getMessage()));
                }
            }
        }
        List<String> unitIds = new List<String>();
        for(Id leadIdvar: successLeadIdset){
            if(leadUnitsMap.containsKey(leadIdvar)){
            	unitIds.addAll(leadUnitsMap.get(leadIdvar));
            }
        }
        if(!unitIds.isEmpty()){
            List<Unit__c> updateUnitList = new List<Unit__c>();
            for(Unit__c unit:[SELECT Id FROM Unit__c WHERE Id IN: unitIds]){
                Unit__c unitUpdate = new Unit__c();
                unitUpdate.Id = unit.Id;
                unitUpdate.BlockedFor__c = null;
                unitUpdate.BlockComment__c = '';
                unitUpdate.BlockedBy__c = null;
                unitUpdate.Sub_Status__c = 'Un-Assigned';
                unitUpdate.Status__c = 'Available';
                updateUnitList.add(unitUpdate);
            }
            if(!updateUnitList.isEmpty()){
                update updateUnitList;
            }
        }
        res.successCount = res.successIds.size();
        res.newStatus = target;
        return res;
    }
    
    public class ApprovalActionResult {
        @AuraEnabled public List<Id> successIds = new List<Id>();
        @AuraEnabled public Integer  successCount = 0;
        @AuraEnabled public Integer  errorCount = 0;
        @AuraEnabled public String   newStatus;
        @AuraEnabled public List<ReassignError> errors = new List<ReassignError>();
    }
    
}