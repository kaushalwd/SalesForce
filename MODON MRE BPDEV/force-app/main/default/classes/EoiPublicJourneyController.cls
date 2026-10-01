/**********************************************************************************************************************
* Name               : EoiPublicJourneyController
* Description        : Apex controller for the public-facing EOI microsite (LWR Experience Cloud).
*                      Reads CMT to resolve active project, exposes residence tiles, runs OTP verification, and inserts
*                      one EOI_Public_Registration__c per submission. Does NOT create Lead / Opportunity / EOI directly;
*                      promotion happens via the internal back-office action on the registration record.
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    16 May 2026     Initial public microsite controller (v1)
* 1.1           Prateek Bansal                    22 May 2026     Capture UTM params from landing URL onto registration
* 1.2           Prateek Bansal                    25 May 2026     Public tiles filtered by EOI_Range__c.Applicable_for_Broker__c = true
**********************************************************************************************************************/
public without sharing class EoiPublicJourneyController {

    private static final String CMT_RECORD_NAME = 'Active_Microsite';
    private static final String SOURCE_PUBLIC_MICROSITE = 'Public Microsite';
    private static final String STATUS_NEW = 'New';
    private static final String STATUS_VERIFIED = 'Verified';
    private static final String STATUS_DUPLICATE = 'Duplicate';
    private static final String STATUS_QUOTA_CLOSED = 'QuotaClosed';
    private static final String CONTEXT_EOI_HOME = 'EOI_HOME';
    private static final Integer VERIFICATION_WINDOW_MINUTES = 15;
    private static final Integer MIN_SUBMIT_ELAPSED_MS = 5000;

    @AuraEnabled(cacheable=true)
    public static ProjectConfig getActiveProject() {
        ProjectConfig config = new ProjectConfig();
        String activeName = readActiveProjectName();
        if (String.isBlank(activeName)) return config;

        List<SObject> projects = Database.queryWithBinds(
            'SELECT Id, Name, EOI_Limit__c FROM Project__c WHERE Name = :activeName LIMIT 1',
            new Map<String, Object>{ 'activeName' => activeName },
            AccessLevel.SYSTEM_MODE
        );
        if (projects.isEmpty()) return config;

        SObject project = projects[0];
        Id projectId = (Id) project.get('Id');
        config.projectId = projectId;
        config.name = (String) project.get('Name');
        Object limitValue = project.get('EOI_Limit__c');
        config.eoiLimit = limitValue == null ? 0 : ((Decimal) limitValue).intValue();

        Integer used = Database.countQueryWithBinds(
            'SELECT COUNT() FROM Expressionofinterest__c WHERE Project__c = :projectId',
            new Map<String, Object>{ 'projectId' => projectId },
            AccessLevel.SYSTEM_MODE
        );
        config.quotaUsed = used;
        config.quotaRemaining = Math.max(0, config.eoiLimit - used);
        config.quotaOpen = config.eoiLimit == 0 || used < config.eoiLimit;
        return config;
    }

    @AuraEnabled(cacheable=true)
    public static List<ResidenceTile> getResidenceTiles(Id projectId) {
        List<ResidenceTile> tiles = new List<ResidenceTile>();
        if (projectId == null) return tiles;
        for (EOI_Range__c r : [
            SELECT Id, Project__c, Phase__c, Phase__r.Name, Unit_Type__c,
                   No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c
            FROM EOI_Range__c
            WHERE Project__c = :projectId
              AND Is_Active__c = true
              AND Applicable_for_Broker__c = true
            ORDER BY Phase__r.Name ASC, Unit_Type__c ASC, No_of_Bedrooms__c ASC
        ]) {
            ResidenceTile tile = new ResidenceTile();
            tile.rangeId = r.Id;
            tile.projectId = r.Project__c;
            tile.phaseId = r.Phase__c;
            tile.phaseName = r.Phase__r != null ? r.Phase__r.Name : null;
            tile.unitType = r.Unit_Type__c;
            tile.bedrooms = r.No_of_Bedrooms__c;
            tile.unitTypology = r.UnitTypologyMRE__c;
            tile.amount = r.Amount__c;
            tiles.add(tile);
        }
        return tiles;
    }

    @AuraEnabled
    public static EoiHomeJourneyController.ValidationResult validateQuota(Id projectId) {
        return EoiHomeJourneyController.validateEOI(null, projectId);
    }

    @AuraEnabled
    public static VerificationService.VerificationResult startVerification(VerificationRequestDTO req) {
        if (req == null || String.isBlank(req.channel) || String.isBlank(req.target)) {
            throw new AuraHandledException('Channel and target are required.');
        }
        VerificationService.VerificationStartRequest svcReq = new VerificationService.VerificationStartRequest();
        svcReq.channel = req.channel;
        svcReq.target = req.target;
        svcReq.context = CONTEXT_EOI_HOME;
        svcReq.contextKey = req.sessionToken;
        return VerificationService.startVerification(svcReq);
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
    public static SubmitResult submitRegistration(PublicRegistrationDTO dto) {
        SubmitResult result = new SubmitResult();
        if (dto == null) throw new AuraHandledException('Registration data is required.');

        if (String.isNotBlank(dto.honeypot)) {
            result.status = 'Rejected';
            result.message = 'Submission rejected.';
            return result;
        }
        if (dto.elapsedMs != null && dto.elapsedMs < MIN_SUBMIT_ELAPSED_MS) {
            result.status = 'Rejected';
            result.message = 'Submission rejected.';
            return result;
        }

        Verification_Request__c verification = loadVerifiedRequest(dto.verificationRequestId);

        EoiHomeJourneyController.ValidationResult quota = validateQuota(dto.projectId);
        if (quota.quotaExceeded == true) {
            result.status = STATUS_QUOTA_CLOSED;
            result.message = 'EOI submissions are closed for the selected project.';
            return result;
        }

        if (!Schema.sObjectType.EOI_Public_Registration__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to submit registration.');
        }

        List<UnitSelection> selections = dto.selections;
        if (selections == null || selections.isEmpty()) {
            UnitSelection single = new UnitSelection();
            single.phaseId = dto.phaseId;
            single.eoiRangeId = dto.eoiRangeId;
            single.unitType = dto.unitType;
            single.bedrooms = dto.bedrooms;
            single.unitTypology = dto.unitTypology;
            single.amount = dto.amount;
            selections = new List<UnitSelection>{ single };
        }

        String batchId = generateBatchId();
        List<EOI_Public_Registration__c> rows = new List<EOI_Public_Registration__c>();
        for (UnitSelection sel : selections) {
            EOI_Public_Registration__c row = buildRegistration(dto, verification);
            row.Phase__c = sel.phaseId;
            row.EOI_Range__c = sel.eoiRangeId;
            row.UnitType__c = sel.unitType;
            row.Bedrooms__c = sel.bedrooms;
            row.UnitTypologyMRE__c = sel.unitTypology;
            row.Amount__c = sel.amount;
            row.BatchId__c = batchId;
            rows.add(row);
        }
        insert rows;

        result.recordId = rows[0].Id;
        result.referenceName = [SELECT Name FROM EOI_Public_Registration__c WHERE Id = :rows[0].Id LIMIT 1].Name;
        result.status = STATUS_VERIFIED;
        result.message = 'Registration captured.';
        return result;
    }

    private static String generateBatchId() {
        Blob b = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(b);
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' + hex.substring(12, 16)
            + '-' + hex.substring(16, 20) + '-' + hex.substring(20, 32);
    }

    private static String readActiveProjectName() {
        List<Site_Config__mdt> rows = [
            SELECT Active_Project_Name__c
            FROM Site_Config__mdt
            WHERE DeveloperName = :CMT_RECORD_NAME
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Active_Project_Name__c;
    }

    private static Verification_Request__c loadVerifiedRequest(Id verificationRequestId) {
        if (verificationRequestId == null) {
            throw new AuraHandledException('Verification is required before submission.');
        }
        List<Verification_Request__c> requests = [
            SELECT Id, Status__c, Channel__c, Verified_At__c
            FROM Verification_Request__c
            WHERE Id = :verificationRequestId
            LIMIT 1
        ];
        if (requests.isEmpty()) {
            throw new AuraHandledException('Verification record not found.');
        }
        Verification_Request__c request = requests[0];
        if (request.Status__c != STATUS_VERIFIED) {
            throw new AuraHandledException('Please complete verification before submitting.');
        }
        if (request.Verified_At__c == null ||
            request.Verified_At__c < System.now().addMinutes(-VERIFICATION_WINDOW_MINUTES)) {
            throw new AuraHandledException('Verification has expired. Please verify again.');
        }
        return request;
    }

    private static EOI_Public_Registration__c buildRegistration(
        PublicRegistrationDTO dto,
        Verification_Request__c verification
    ) {
        EOI_Public_Registration__c reg = new EOI_Public_Registration__c();
        reg.CustomerType__c = dto.customerType;
        reg.FirstName__c = dto.firstName;
        reg.LastName__c = dto.lastName;
        reg.Email__c = dto.email;
        reg.Mobile__c = dto.mobile;
        reg.Phone__c = dto.phone;
        reg.ResidentStatus__c = dto.residentStatus;
        reg.EmiratesId__c = dto.emiratesId;
        reg.PassportNumber__c = dto.passportNumber;
        reg.CompanyName__c = dto.companyName;
        reg.TradeLicenseNumber__c = dto.tradeLicenseNumber;
        reg.TradeLicenseExpiryDate__c = dto.tradeLicenseExpiryDate;
        reg.RegisteredEmail__c = dto.registeredEmail;
        reg.RegisteredPhone__c = dto.registeredPhone;
        reg.AuthorizedFirstName__c = dto.authorizedFirstName;
        reg.AuthorizedLastName__c = dto.authorizedLastName;
        reg.AuthorizedEmail__c = dto.authorizedEmail;
        reg.AuthorizedPhone__c = dto.authorizedPhone;
        reg.Project__c = dto.projectId;
        reg.Phase__c = dto.phaseId;
        reg.EOI_Range__c = dto.eoiRangeId;
        reg.UnitType__c = dto.unitType;
        reg.Bedrooms__c = dto.bedrooms;
        reg.UnitTypologyMRE__c = dto.unitTypology;
        reg.Amount__c = dto.amount;
        reg.PaymentTypePreference__c = dto.paymentTypePreference;
        reg.Status__c = STATUS_VERIFIED;
        reg.VerifiedAt__c = System.now();
        reg.VerifiedChannel__c = verification.Channel__c;
        reg.VerificationRequest__c = verification.Id;
        reg.Source__c = SOURCE_PUBLIC_MICROSITE;
        reg.SubmittedAt__c = System.now();
        reg.UserAgent__c = dto.userAgent == null ? null : dto.userAgent.left(255);
        reg.Locale__c = dto.locale;
        reg.UTMSource__c = truncate(dto.utmSource);
        reg.UTMCampaign__c = truncate(dto.utmCampaign);
        reg.UTMMedium__c = truncate(dto.utmMedium);
        reg.UTMURL__c = truncate(dto.utmUrl);
        reg.AdName__c = truncate(dto.adName);
        reg.AdSetName__c = truncate(dto.adSetName);
        reg.UTMSubSource__c = truncate(dto.utmSubSource);
        return reg;
    }

    private static String truncate(String value) {
        if (String.isBlank(value)) return null;
        return value.length() > 255 ? value.substring(0, 255) : value;
    }

    public class ProjectConfig {
        @AuraEnabled public Id projectId;
        @AuraEnabled public String name;
        @AuraEnabled public Integer eoiLimit = 0;
        @AuraEnabled public Integer quotaUsed = 0;
        @AuraEnabled public Integer quotaRemaining = 0;
        @AuraEnabled public Boolean quotaOpen = false;
    }

    public class ResidenceTile {
        @AuraEnabled public Id rangeId;
        @AuraEnabled public Id projectId;
        @AuraEnabled public Id phaseId;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public Decimal amount;
    }

    public class VerificationRequestDTO {
        @AuraEnabled public String channel { get; set; }
        @AuraEnabled public String target { get; set; }
        @AuraEnabled public String sessionToken { get; set; }
    }

    public class PublicRegistrationDTO {
        @AuraEnabled public String customerType { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        @AuraEnabled public String emiratesId { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String tradeLicenseNumber { get; set; }
        @AuraEnabled public Date tradeLicenseExpiryDate { get; set; }
        @AuraEnabled public String registeredEmail { get; set; }
        @AuraEnabled public String registeredPhone { get; set; }
        @AuraEnabled public String authorizedFirstName { get; set; }
        @AuraEnabled public String authorizedLastName { get; set; }
        @AuraEnabled public String authorizedEmail { get; set; }
        @AuraEnabled public String authorizedPhone { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id phaseId { get; set; }
        @AuraEnabled public Id eoiRangeId { get; set; }
        @AuraEnabled public String unitType { get; set; }
        @AuraEnabled public String bedrooms { get; set; }
        @AuraEnabled public String unitTypology { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String paymentTypePreference { get; set; }
        @AuraEnabled public Id verificationRequestId { get; set; }
        @AuraEnabled public String honeypot { get; set; }
        @AuraEnabled public Long elapsedMs { get; set; }
        @AuraEnabled public String userAgent { get; set; }
        @AuraEnabled public String locale { get; set; }
        @AuraEnabled public String utmSource { get; set; }
        @AuraEnabled public String utmCampaign { get; set; }
        @AuraEnabled public String utmMedium { get; set; }
        @AuraEnabled public String utmUrl { get; set; }
        @AuraEnabled public String adName { get; set; }
        @AuraEnabled public String adSetName { get; set; }
        @AuraEnabled public String utmSubSource { get; set; }
        @AuraEnabled public List<UnitSelection> selections { get; set; }
    }

    public class UnitSelection {
        @AuraEnabled public Id phaseId { get; set; }
        @AuraEnabled public Id eoiRangeId { get; set; }
        @AuraEnabled public String unitType { get; set; }
        @AuraEnabled public String bedrooms { get; set; }
        @AuraEnabled public String unitTypology { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
    }

    public class SubmitResult {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String referenceName;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }
}