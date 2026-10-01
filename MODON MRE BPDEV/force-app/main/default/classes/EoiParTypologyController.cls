/**********************************************************************************************************************
* Name               : EoiParTypologyController
* Description        : Guest-facing controller for the Par Typology public microsite. Captures Par 3 / Par 4 selection,
*                      matches or creates a Lead (excluding Retired status), stamps Typology__c, and stores an
*                      EOI_Public_Registration__c staging record with UTM attribution.
*                      Safety invariant: methods touch ONLY Lead (match-or-create + update),
*                      EOI_Public_Registration__c (insert), EOI_Range__c / Project__c (read) and
*                      Verification_Request__c (via reused VerificationService). No EOI / Opportunity creation.
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    05 June 2026    Initial Par Typology microsite controller
**********************************************************************************************************************/
public without sharing class EoiParTypologyController {

    private static final String CMT_RECORD_NAME = 'Active_Microsite';
    private static final String CONTEXT_PAR = 'EOI_PAR_TYPOLOGY';
    private static final String STATUS_VERIFIED = 'Verified';
    private static final Integer VERIFICATION_WINDOW_MINUTES = 15;
    private static final String SHOW_ON_PAR = 'Par Typology';
    private static final String SOURCE_PAR_MICROSITE = 'Public Microsite';

    @AuraEnabled(cacheable=true)
    public static ProjectConfig getActiveProject() {
        ProjectConfig cfg = new ProjectConfig();
        String activeName = readActiveProjectName();
        if (String.isBlank(activeName)) return cfg;
        List<Project__c> projects = Database.queryWithBinds(
            'SELECT Id, Name FROM Project__c WHERE Name = :activeName LIMIT 1',
            new Map<String, Object>{ 'activeName' => activeName },
            AccessLevel.SYSTEM_MODE
        );
        if (projects.isEmpty()) return cfg;
        cfg.projectId = projects[0].Id;
        cfg.name = projects[0].Name;
        return cfg;
    }

    @AuraEnabled(cacheable=true)
    public static List<ParTile> getParTiles(Id projectId) {
        List<ParTile> tiles = new List<ParTile>();
        if (projectId == null) return tiles;
        String showOn = SHOW_ON_PAR;
        List<EOI_Range__c> ranges = Database.queryWithBinds(
            'SELECT Id, Project__c, Phase__c, Phase__r.Name, Unit_Type__c, ' +
            'No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c, Show_On__c ' +
            'FROM EOI_Range__c ' +
            'WHERE Project__c = :projectId ' +
            'AND Is_Active__c = true ' +
            'AND Show_On__c INCLUDES (:showOn) ' +
            'ORDER BY UnitTypologyMRE__c ASC',
            new Map<String, Object>{ 'projectId' => projectId, 'showOn' => showOn },
            AccessLevel.SYSTEM_MODE
        );
        for (EOI_Range__c r : ranges) {
            ParTile t = new ParTile();
            t.rangeId = r.Id;
            t.projectId = r.Project__c;
            t.phaseId = r.Phase__c;
            t.phaseName = r.Phase__r != null ? r.Phase__r.Name : null;
            t.unitType = r.Unit_Type__c;
            t.bedrooms = r.No_of_Bedrooms__c;
            t.unitTypology = r.UnitTypologyMRE__c;
            t.amount = r.Amount__c;
            tiles.add(t);
        }
        return tiles;
    }

    @AuraEnabled
    public static VerificationService.VerificationResult startVerification(String channel, String target, String sessionToken) {
        if (String.isBlank(channel) || String.isBlank(target)) {
            throw new AuraHandledException('Channel and contact detail are required.');
        }
        VerificationService.VerificationStartRequest req = new VerificationService.VerificationStartRequest();
        req.channel = channel;
        req.target = target.trim();
        req.context = CONTEXT_PAR;
        req.contextKey = String.isBlank(sessionToken) ? target.trim() : sessionToken;
        return VerificationService.startVerification(req);
    }

    @AuraEnabled
    public static VerificationService.VerificationResult resendVerification(Id verificationRequestId) {
        return VerificationService.resendVerification(verificationRequestId);
    }

    @AuraEnabled
    public static VerificationService.VerificationResult verifyCode(Id verificationRequestId, String code) {
        return VerificationService.verifyCode(verificationRequestId, code);
    }

    @AuraEnabled
    public static SubmitResult submitRegistration(ParRegistrationDTO dto) {
        if (dto == null) throw new AuraHandledException('Submission payload is required.');
        if (String.isBlank(dto.typology)) throw new AuraHandledException('Please select a typology before submitting.');
        Verification_Request__c verification = loadVerifiedRequest(dto.verificationRequestId);

        Id projectId = dto.projectId;
        if (projectId == null) {
            ProjectConfig cfg = getActiveProject();
            projectId = cfg.projectId;
        }

        Lead matched = findMatchingLead(dto);
        Id leadId;
        DateTime confirmedAt = System.now();
        if (matched == null) {
            Lead newLead = buildNewLead(dto);
            newLead.Site_Confirmed__c = true;
            newLead.Site_Confirmed_At__c = confirmedAt;
            Database.insert(new List<Lead>{ newLead }, AccessLevel.SYSTEM_MODE);
            leadId = newLead.Id;
        } else {
            applyEditableUpdates(matched, dto);
            matched.Typology__c = dto.typology;
            matched.Site_Confirmed__c = true;
            matched.Site_Confirmed_At__c = confirmedAt;
            Database.update(new List<Lead>{ matched }, AccessLevel.SYSTEM_MODE);
            leadId = matched.Id;
        }

        EOI_Public_Registration__c reg = buildRegistration(dto, verification, projectId, leadId);
        Database.insert(new List<EOI_Public_Registration__c>{ reg }, AccessLevel.SYSTEM_MODE);

        SubmitResult result = new SubmitResult();
        result.recordId = reg.Id;
        result.matchedLeadId = leadId;
        result.referenceName = [SELECT Name FROM EOI_Public_Registration__c WHERE Id = :reg.Id LIMIT 1].Name;
        result.status = STATUS_VERIFIED;
        return result;
    }

    private static Lead findMatchingLead(ParRegistrationDTO dto) {
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        Set<String> eids = new Set<String>();
        Set<String> passports = new Set<String>();
        if (String.isNotBlank(dto.email)) emails.add(dto.email.trim());
        if (String.isNotBlank(dto.mobile)) phones.add(dto.mobile.trim());
        if (String.isNotBlank(dto.phone)) phones.add(dto.phone.trim());
        if (String.isNotBlank(dto.emiratesId)) eids.add(dto.emiratesId.trim());
        if (String.isNotBlank(dto.passportNumber)) passports.add(dto.passportNumber.trim());
        if (emails.isEmpty() && phones.isEmpty() && eids.isEmpty() && passports.isEmpty()) return null;

        String soql = 'SELECT Id, FirstName, LastName, Email, MobilePhone, Phone, UAEResidentStatus__c, ' +
                      'EIDNumber__c, PassportNumber__c, Status, Typology__c, CreatedDate ' +
                      'FROM Lead WHERE Status != \'Retired\' AND IsConverted = false ' +
                      'AND (LeadSource = null OR LeadSource NOT IN (\'Broker Portal\',\'Self Generated\')) AND (';
        List<String> ors = new List<String>();
        if (!emails.isEmpty())   ors.add('Email IN :emails');
        if (!phones.isEmpty())   ors.add('MobilePhone IN :phones');
        if (!phones.isEmpty())   ors.add('Phone IN :phones');
        if (!eids.isEmpty())     ors.add('EIDNumber__c IN :eids');
        if (!passports.isEmpty()) ors.add('PassportNumber__c IN :passports');
        soql += String.join(ors, ' OR ');
        soql += ') ORDER BY CreatedDate DESC LIMIT 1';

        List<Lead> leads = Database.queryWithBinds(
            soql,
            new Map<String, Object>{
                'emails' => emails, 'phones' => phones,
                'eids' => eids, 'passports' => passports
            },
            AccessLevel.SYSTEM_MODE
        );
        return leads.isEmpty() ? null : leads[0];
    }

    private static Lead buildNewLead(ParRegistrationDTO dto) {
        Lead l = new Lead();
        l.FirstName = dto.firstName;
        l.LastName = String.isNotBlank(dto.lastName) ? dto.lastName : 'Unknown';
        l.Email = dto.email;
        l.MobilePhone = dto.mobile;
        l.Phone = dto.phone;
        l.Status = 'New';
        l.Typology__c = dto.typology;
        applyResidentFields(l, dto);
        applyUtmFieldsForNewLead(l, dto);
        putIfFieldExists(l, 'ProjectInterest__c', readActiveProjectName());
        return l;
    }

    private static void applyEditableUpdates(Lead l, ParRegistrationDTO dto) {
        if (String.isNotBlank(dto.firstName)) l.FirstName = dto.firstName;
        if (String.isNotBlank(dto.lastName))  l.LastName  = dto.lastName;
        if (String.isNotBlank(dto.email)) {
            l.Email = dto.email;
            putIfFieldExists(l, 'En_Email__c', dto.email);
        }
        if (String.isNotBlank(dto.mobile)) {
            l.MobilePhone = dto.mobile;
            putIfFieldExists(l, 'En_MobilePhone__c', dto.mobile);
        }
        if (String.isNotBlank(dto.phone)) l.Phone = dto.phone;
        applyResidentFields(l, dto);
        putIfFieldExists(l, 'ProjectInterest__c', readActiveProjectName());
        if (l.Status == 'Retired') l.Status = 'In Progress';
    }

    private static void applyResidentFields(Lead l, ParRegistrationDTO dto) {
        if (String.isNotBlank(dto.residentStatus)) l.UAEResidentStatus__c = dto.residentStatus;
        if (String.isNotBlank(dto.emiratesId)) {
            l.EIDNumber__c = dto.emiratesId;
            putIfFieldExists(l, 'En_EIDNumber__c', dto.emiratesId);
        }
        if (String.isNotBlank(dto.passportNumber)) {
            l.PassportNumber__c = dto.passportNumber;
            putIfFieldExists(l, 'En_PassportNumber__c', dto.passportNumber);
        }
    }

    private static void applyUtmFieldsForNewLead(Lead l, ParRegistrationDTO dto) {
        Boolean hasUtm = String.isNotBlank(dto.utmSource) || String.isNotBlank(dto.utmCampaign) ||
                         String.isNotBlank(dto.utmMedium) || String.isNotBlank(dto.utmSubSource) ||
                         String.isNotBlank(dto.adName) || String.isNotBlank(dto.adSetName);
        if (hasUtm) {
            l.LeadSource = 'Social Media';
            putIfFieldExists(l, 'SubSource__c', dto.utmSubSource);
        } else {
            l.LeadSource = 'Sales Launch';
        }
        putIfFieldExists(l, 'UTMSource__c', dto.utmSource);
        putIfFieldExists(l, 'UTMCampaign__c', dto.utmCampaign);
        putIfFieldExists(l, 'UTMMedium__c', dto.utmMedium);
        putIfFieldExists(l, 'UTMURL__c', dto.utmUrl);
        putIfFieldExists(l, 'AdName__c', dto.adName);
        putIfFieldExists(l, 'AdSetName__c', dto.adSetName);
    }

    private static EOI_Public_Registration__c buildRegistration(
        ParRegistrationDTO dto,
        Verification_Request__c verification,
        Id projectId,
        Id leadId
    ) {
        EOI_Public_Registration__c reg = new EOI_Public_Registration__c();
        reg.CustomerType__c = 'Individual';
        reg.FirstName__c = dto.firstName;
        reg.LastName__c = dto.lastName;
        reg.Email__c = dto.email;
        reg.Mobile__c = dto.mobile;
        reg.Phone__c = dto.phone;
        reg.ResidentStatus__c = dto.residentStatus;
        reg.EmiratesId__c = dto.emiratesId;
        reg.PassportNumber__c = dto.passportNumber;
        reg.Project__c = projectId;
        reg.EOI_Range__c = dto.rangeId;
        reg.Typology__c = dto.typology;
        reg.Status__c = STATUS_VERIFIED;
        reg.VerifiedAt__c = System.now();
        reg.VerifiedChannel__c = verification.Channel__c;
        reg.VerificationRequest__c = verification.Id;
        reg.Source__c = SOURCE_PAR_MICROSITE;
        reg.SubmittedAt__c = System.now();
        reg.UserAgent__c = dto.userAgent == null ? null : dto.userAgent.left(255);
        reg.Locale__c = dto.locale;
        reg.UTMSource__c = truncate(dto.utmSource);
        reg.UTMCampaign__c = truncate(dto.utmCampaign);
        reg.UTMMedium__c = truncate(dto.utmMedium);
        reg.UTMURL__c = truncate(dto.utmUrl);
        reg.UTMSubSource__c = truncate(dto.utmSubSource);
        reg.AdName__c = truncate(dto.adName);
        reg.AdSetName__c = truncate(dto.adSetName);
        putIfFieldExists(reg, 'MatchedLead__c', leadId);
        return reg;
    }

    private static Verification_Request__c loadVerifiedRequest(Id verificationRequestId) {
        if (verificationRequestId == null) {
            throw new AuraHandledException('Please complete verification before submitting.');
        }
        List<Verification_Request__c> rows = [
            SELECT Id, Status__c, Channel__c, Verified_At__c
            FROM Verification_Request__c
            WHERE Id = :verificationRequestId
            LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Verification record not found.');
        Verification_Request__c v = rows[0];
        if (v.Status__c != STATUS_VERIFIED) {
            throw new AuraHandledException('Please complete verification before submitting.');
        }
        if (v.Verified_At__c == null ||
            v.Verified_At__c < System.now().addMinutes(-VERIFICATION_WINDOW_MINUTES)) {
            throw new AuraHandledException('Verification has expired. Please verify again.');
        }
        return v;
    }

    private static String readActiveProjectName() {
        List<Site_Config__mdt> rows = [
            SELECT Active_Project_Name__c FROM Site_Config__mdt
            WHERE DeveloperName = :CMT_RECORD_NAME LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Active_Project_Name__c;
    }

    private static String truncate(String value) {
        if (String.isBlank(value)) return null;
        return value.length() > 255 ? value.substring(0, 255) : value;
    }

    private static void putIfFieldExists(SObject record, String fieldName, Object value) {
        if (record == null || value == null) return;
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    public class ProjectConfig {
        @AuraEnabled public Id projectId;
        @AuraEnabled public String name;
    }

    public class ParTile {
        @AuraEnabled public Id rangeId;
        @AuraEnabled public Id projectId;
        @AuraEnabled public Id phaseId;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public Decimal amount;
    }

    public class ParRegistrationDTO {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        @AuraEnabled public String emiratesId { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String typology { get; set; }
        @AuraEnabled public Id rangeId { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id verificationRequestId { get; set; }
        @AuraEnabled public String userAgent { get; set; }
        @AuraEnabled public String locale { get; set; }
        @AuraEnabled public String utmSource { get; set; }
        @AuraEnabled public String utmCampaign { get; set; }
        @AuraEnabled public String utmMedium { get; set; }
        @AuraEnabled public String utmSubSource { get; set; }
        @AuraEnabled public String utmUrl { get; set; }
        @AuraEnabled public String adName { get; set; }
        @AuraEnabled public String adSetName { get; set; }
    }

    public class SubmitResult {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id matchedLeadId;
        @AuraEnabled public String referenceName;
        @AuraEnabled public String status;
    }
}