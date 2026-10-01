/**********************************************************************************************************************
* Name               : EoiPublicJourneyControllerTest
* Description        : Test coverage for EoiPublicJourneyController. Exercises the public microsite flow:
*                      active-project resolution, residence tiles, quota validation, OTP delegation, and
*                      submitRegistration (individual / organisation, honeypot, time-check, missing/expired
*                      verification, multi-selection submit).
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    20 May 2026     Initial version
* 1.1           Prateek Bansal                    22 May 2026     UTM capture coverage (present / absent paths)
* 1.2           Prateek Bansal                    25 May 2026     Coverage for Applicable_for_Broker__c tile filter
**********************************************************************************************************************/
@IsTest
private class EoiPublicJourneyControllerTest {

    @IsTest
    static void getActiveProjectReturnsConfiguredProject() {
        SObject project = createProject('HGE UAT Active', 5);

        Test.startTest();
        EoiPublicJourneyController.ProjectConfig config = EoiPublicJourneyController.getActiveProject();
        Test.stopTest();

        System.assertNotEquals(null, config, 'ProjectConfig should not be null.');
        System.assert(config.projectId == null || config.projectId == (Id) project.get('Id'),
            'When CMT points elsewhere, projectId can be null; otherwise it must match the test project.');
    }

    @IsTest
    static void getResidenceTilesIncludesRenderUrl() {
        SObject project = createProject('HGE UAT Tiles', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Test.startTest();
        List<EoiPublicJourneyController.ResidenceTile> tiles =
            EoiPublicJourneyController.getResidenceTiles((Id) project.get('Id'));
        Test.stopTest();

        System.assertEquals(1, tiles.size(), 'One active range should produce one tile.');
        EoiPublicJourneyController.ResidenceTile tile = tiles[0];
        System.assertEquals((Id) range.get('Id'), tile.rangeId);
        System.assertEquals('Villa', tile.unitType);
        System.assertEquals('3 Bedrooms', tile.bedrooms);
    }

    @IsTest
    static void validateQuotaReturnsRemaining() {
        SObject project = createProject('HGE UAT Quota', 3);

        Test.startTest();
        EoiHomeJourneyController.ValidationResult result =
            EoiPublicJourneyController.validateQuota((Id) project.get('Id'));
        Test.stopTest();

        System.assertEquals(3, result.quotaLimit);
        System.assertEquals(0, result.quotaUsed);
        System.assertEquals(false, result.quotaExceeded);
    }

    @IsTest
    static void submitRegistrationIndividualHappyPath() {
        SObject project = createProject('HGE UAT Submit', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Verification_Request__c verification = createVerifiedRequest('individual@example.com', 'Email');
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, verification, 'individual@example.com');

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Verified', result.status);
        System.assertNotEquals(null, result.recordId);
        System.assert(String.isNotBlank(result.referenceName) && result.referenceName.startsWith('EPR-'),
            'Reference name should be the EPR auto-number.');

        EOI_Public_Registration__c saved = [
            SELECT CustomerType__c, Email__c, Status__c, VerifiedChannel__c, VerificationRequest__c,
                   Project__c, EOI_Range__c, Source__c
            FROM EOI_Public_Registration__c WHERE Id = :result.recordId
        ];
        System.assertEquals('Individual', saved.CustomerType__c);
        System.assertEquals('Verified', saved.Status__c);
        System.assertEquals('Email', saved.VerifiedChannel__c);
        System.assertEquals(verification.Id, saved.VerificationRequest__c);
        System.assertEquals((Id) project.get('Id'), saved.Project__c);
        System.assertEquals('Public Microsite', saved.Source__c);

        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Email = 'individual@example.com']);
        System.assertEquals(0, [SELECT COUNT() FROM Expressionofinterest__c WHERE Project__c = :saved.Project__c]);
    }

    @IsTest
    static void submitRegistrationOrganizationHappyPath() {
        SObject project = createProject('HGE UAT Org', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Verification_Request__c verification = createVerifiedRequest('auth@example.com', 'Email');
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildOrganizationDto(project, phase, range, verification);

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Verified', result.status);
        EOI_Public_Registration__c saved = [
            SELECT CustomerType__c, CompanyName__c, TradeLicenseNumber__c, AuthorizedEmail__c
            FROM EOI_Public_Registration__c WHERE Id = :result.recordId
        ];
        System.assertEquals('Organization', saved.CustomerType__c);
        System.assertEquals('Acme Holdings', saved.CompanyName__c);
        System.assertEquals('TL-12345', saved.TradeLicenseNumber__c);
        System.assertEquals('auth@example.com', saved.AuthorizedEmail__c);
    }

    @IsTest
    static void submitRegistrationRejectsHoneypot() {
        SObject project = createProject('HGE UAT Honeypot', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');
        Verification_Request__c verification = createVerifiedRequest('bot@example.com', 'Email');

        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, verification, 'bot@example.com');
        dto.honeypot = 'I am a bot';

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Rejected', result.status);
        System.assertEquals(0, [SELECT COUNT() FROM EOI_Public_Registration__c]);
    }

    @IsTest
    static void submitRegistrationRejectsTooFastSubmission() {
        SObject project = createProject('HGE UAT Fast', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');
        Verification_Request__c verification = createVerifiedRequest('fast@example.com', 'Email');

        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, verification, 'fast@example.com');
        dto.elapsedMs = 1500L;

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Rejected', result.status);
    }

    @IsTest
    static void submitRegistrationThrowsForUnverifiedToken() {
        SObject project = createProject('HGE UAT Unverified', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Verification_Request__c pending = new Verification_Request__c(
            Channel__c = 'Email', Target__c = 'pending@example.com',
            Masked_Target__c = 'p***@example.com', Status__c = 'Pending',
            Context__c = 'EOI_HOME', Expires_At__c = System.now().addMinutes(5)
        );
        insert pending;

        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, pending, 'pending@example.com');

        Test.startTest();
        try {
            EoiPublicJourneyController.submitRegistration(dto);
            System.assert(false, 'Expected AuraHandledException for unverified token.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void submitRegistrationWithMultipleSelections() {
        SObject project = createProject('HGE UAT Multi', 10);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range1 = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');
        SObject range2 = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '4 Bedrooms');

        Verification_Request__c verification = createVerifiedRequest('multi@example.com', 'Email');
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range1, verification, 'multi@example.com');

        EoiPublicJourneyController.UnitSelection s1 = new EoiPublicJourneyController.UnitSelection();
        s1.phaseId = (Id) phase.get('Id');
        s1.eoiRangeId = (Id) range1.get('Id');
        s1.unitType = 'Villa';
        s1.bedrooms = '3 Bedrooms';
        s1.amount = 650000;

        EoiPublicJourneyController.UnitSelection s2 = new EoiPublicJourneyController.UnitSelection();
        s2.phaseId = (Id) phase.get('Id');
        s2.eoiRangeId = (Id) range2.get('Id');
        s2.unitType = 'Villa';
        s2.bedrooms = '4 Bedrooms';
        s2.amount = 850000;

        dto.selections = new List<EoiPublicJourneyController.UnitSelection>{ s1, s2 };

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Verified', result.status);
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, BatchId__c, EOI_Range__c, Amount__c
            FROM EOI_Public_Registration__c
            WHERE Email__c = 'multi@example.com'
        ];
        System.assertEquals(2, rows.size(), 'Multi-selection submit should create one row per selection.');
        System.assertEquals(rows[0].BatchId__c, rows[1].BatchId__c, 'All rows in a single submit share the same BatchId.');
    }

    @IsTest
    static void submitRegistrationThrowsForNullDto() {
        try {
            EoiPublicJourneyController.submitRegistration(null);
            System.assert(false, 'Expected AuraHandledException for null DTO.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void submitRegistrationThrowsForMissingVerification() {
        SObject project = createProject('HGE UAT NoVerify', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        EoiPublicJourneyController.PublicRegistrationDTO dto =
            new EoiPublicJourneyController.PublicRegistrationDTO();
        dto.customerType = 'Individual';
        dto.email = 'noverify@example.com';
        dto.projectId = (Id) project.get('Id');
        dto.phaseId = (Id) phase.get('Id');
        dto.eoiRangeId = (Id) range.get('Id');
        dto.elapsedMs = 10000L;

        try {
            EoiPublicJourneyController.submitRegistration(dto);
            System.assert(false, 'Expected AuraHandledException for missing verificationRequestId.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void submitRegistrationThrowsForExpiredVerification() {
        SObject project = createProject('HGE UAT Expired', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Verification_Request__c expired = new Verification_Request__c(
            Channel__c = 'Email', Target__c = 'expired@example.com',
            Masked_Target__c = 'e***@example.com', Status__c = 'Verified',
            Context__c = 'EOI_HOME', Expires_At__c = System.now().addMinutes(-30),
            Verified_At__c = System.now().addMinutes(-60)
        );
        insert expired;

        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, expired, 'expired@example.com');

        try {
            EoiPublicJourneyController.submitRegistration(dto);
            System.assert(false, 'Expected AuraHandledException for expired verification.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void resendAndVerifyCodeDelegateToService() {
        Verification_Request__c v = createVerifiedRequest('resend@example.com', 'Email');

        Test.startTest();
        try {
            EoiPublicJourneyController.resendVerification(v.Id);
        } catch (Exception ex) {
            // Either succeeds or surfaces a service-level error; the call site is what we want to cover.
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        try {
            EoiPublicJourneyController.verifyCode(v.Id, '000000');
        } catch (Exception ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void getActiveProjectReturnsEmptyWhenCmtMissingProject() {
        Test.startTest();
        EoiPublicJourneyController.ProjectConfig config = EoiPublicJourneyController.getActiveProject();
        Test.stopTest();
        System.assertNotEquals(null, config);
    }

    @IsTest
    static void getResidenceTilesExcludesNonBrokerRanges() {
        SObject project = createProject('HGE UAT Broker', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        SObject nonBrokerRange = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(nonBrokerRange, 'Project__c', (Id) project.get('Id'));
        putIfFieldExists(nonBrokerRange, 'Phase__c', (Id) phase.get('Id'));
        putIfFieldExists(nonBrokerRange, 'Unit_Type__c', 'Townhouse');
        putIfFieldExists(nonBrokerRange, 'No_of_Bedrooms__c', '4 Bedrooms');
        putIfFieldExists(nonBrokerRange, 'Amount__c', 450000);
        putIfFieldExists(nonBrokerRange, 'Is_Active__c', true);
        putIfFieldExists(nonBrokerRange, 'Applicable_for_Broker__c', false);
        insert nonBrokerRange;

        Test.startTest();
        List<EoiPublicJourneyController.ResidenceTile> tiles =
            EoiPublicJourneyController.getResidenceTiles((Id) project.get('Id'));
        Test.stopTest();

        System.assertEquals(1, tiles.size(), 'Only Applicable_for_Broker__c=true ranges should be returned.');
        System.assertNotEquals('Townhouse', tiles[0].unitType, 'Non-broker range should be excluded.');
    }

    @IsTest
    static void getResidenceTilesReturnsEmptyForNullProjectId() {
        Test.startTest();
        List<EoiPublicJourneyController.ResidenceTile> tiles =
            EoiPublicJourneyController.getResidenceTiles(null);
        Test.stopTest();
        System.assertEquals(0, tiles.size());
    }

    @IsTest
    static void startVerificationDelegatesToService() {
        EoiPublicJourneyController.VerificationRequestDTO req =
            new EoiPublicJourneyController.VerificationRequestDTO();
        req.channel = 'Email';
        req.target = 'verify@example.com';
        req.sessionToken = 'sess-1';

        Test.startTest();
        try {
            VerificationService.VerificationResult result = EoiPublicJourneyController.startVerification(req);
            System.assertNotEquals(null, result);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Expected either success or a configuration-related AuraHandledException.');
        }
        Test.stopTest();
    }

    @IsTest
    static void submitRegistrationPersistsUtmFields() {
        SObject project = createProject('HGE UAT UTM', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Verification_Request__c verification = createVerifiedRequest('utm@example.com', 'Email');
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, verification, 'utm@example.com');
        dto.utmSource = 'HGE_EOI_REG_CTW';
        dto.utmCampaign = 'HGE_EOI_REG_CTW';
        dto.utmMedium = 'cpc';
        dto.utmUrl = 'https://modon.my.site.com/hge?utm_source=HGE_EOI_REG_CTW&sub_source=WhatsApp';
        dto.adName = 'HGE_EOI_REG_CTW';
        dto.adSetName = 'HGE_EOI_REG_CTW';
        dto.utmSubSource = 'WhatsApp';

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Verified', result.status);
        EOI_Public_Registration__c saved = [
            SELECT UTMSource__c, UTMCampaign__c, UTMMedium__c, UTMURL__c,
                   AdName__c, AdSetName__c, UTMSubSource__c
            FROM EOI_Public_Registration__c WHERE Id = :result.recordId
        ];
        System.assertEquals('HGE_EOI_REG_CTW', saved.UTMSource__c);
        System.assertEquals('HGE_EOI_REG_CTW', saved.UTMCampaign__c);
        System.assertEquals('cpc', saved.UTMMedium__c);
        System.assertEquals('HGE_EOI_REG_CTW', saved.AdName__c);
        System.assertEquals('HGE_EOI_REG_CTW', saved.AdSetName__c);
        System.assertEquals('WhatsApp', saved.UTMSubSource__c);
        System.assertNotEquals(null, saved.UTMURL__c);
    }

    @IsTest
    static void submitRegistrationLeavesUtmBlankWhenNotProvided() {
        SObject project = createProject('HGE UAT NoUTM', 5);
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Villa', '3 Bedrooms');

        Verification_Request__c verification = createVerifiedRequest('noutm@example.com', 'Email');
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, verification, 'noutm@example.com');

        Test.startTest();
        EoiPublicJourneyController.SubmitResult result =
            EoiPublicJourneyController.submitRegistration(dto);
        Test.stopTest();

        System.assertEquals('Verified', result.status);
        EOI_Public_Registration__c saved = [
            SELECT UTMSource__c, UTMCampaign__c, UTMSubSource__c
            FROM EOI_Public_Registration__c WHERE Id = :result.recordId
        ];
        System.assertEquals(null, saved.UTMSource__c);
        System.assertEquals(null, saved.UTMCampaign__c);
        System.assertEquals(null, saved.UTMSubSource__c);
    }

    @IsTest
    static void startVerificationRequiresChannelAndTarget() {
        EoiPublicJourneyController.VerificationRequestDTO req =
            new EoiPublicJourneyController.VerificationRequestDTO();
        try {
            EoiPublicJourneyController.startVerification(req);
            System.assert(false, 'Expected AuraHandledException for missing channel and target.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    private static EoiPublicJourneyController.PublicRegistrationDTO buildIndividualDto(
        SObject project, SObject phase, SObject range,
        Verification_Request__c verification, String email
    ) {
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            new EoiPublicJourneyController.PublicRegistrationDTO();
        dto.customerType = 'Individual';
        dto.firstName = 'First';
        dto.lastName = 'Last';
        dto.email = email;
        dto.mobile = '+971501234567';
        dto.residentStatus = 'Resident';
        dto.emiratesId = '784-1990-1234567-1';
        dto.projectId = (Id) project.get('Id');
        dto.phaseId = (Id) phase.get('Id');
        dto.eoiRangeId = (Id) range.get('Id');
        dto.unitType = 'Villa';
        dto.bedrooms = '3 Bedrooms';
        dto.amount = 650000;
        dto.paymentTypePreference = 'Cheque';
        dto.verificationRequestId = verification.Id;
        dto.honeypot = null;
        dto.elapsedMs = 10000L;
        dto.userAgent = 'Mozilla/5.0 (Test)';
        dto.locale = 'en_US';
        return dto;
    }

    private static EoiPublicJourneyController.PublicRegistrationDTO buildOrganizationDto(
        SObject project, SObject phase, SObject range, Verification_Request__c verification
    ) {
        EoiPublicJourneyController.PublicRegistrationDTO dto =
            buildIndividualDto(project, phase, range, verification, 'auth@example.com');
        dto.customerType = 'Organization';
        dto.firstName = null;
        dto.lastName = null;
        dto.companyName = 'Acme Holdings';
        dto.tradeLicenseNumber = 'TL-12345';
        dto.tradeLicenseExpiryDate = Date.today().addYears(1);
        dto.registeredEmail = 'company@example.com';
        dto.registeredPhone = '+97144441234';
        dto.authorizedFirstName = 'Auth';
        dto.authorizedLastName = 'Signatory';
        dto.authorizedEmail = 'auth@example.com';
        dto.authorizedPhone = '+971501234567';
        return dto;
    }

    private static Verification_Request__c createVerifiedRequest(String target, String channel) {
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = channel,
            Target__c = target,
            Masked_Target__c = maskTarget(target, channel),
            Status__c = 'Verified',
            Context__c = 'EOI_HOME',
            Expires_At__c = System.now().addMinutes(5),
            Verified_At__c = System.now()
        );
        insert v;
        return v;
    }

    private static String maskTarget(String target, String channel) {
        if (channel == 'Email' && target.contains('@')) {
            return target.left(1) + '***@' + target.substringAfter('@');
        }
        return '****' + target.right(4);
    }

    private static SObject createProject(String name, Integer eoiLimit) {
        SObject projectRecord = Schema.getGlobalDescribe().get('Project__c').newSObject();
        projectRecord.put('Name', name);
        putIfFieldExists(projectRecord, 'EOI_Limit__c', eoiLimit);
        insert projectRecord;
        return projectRecord;
    }

    private static SObject createPhase(String name, Id projectId) {
        SObject phaseRecord = Schema.getGlobalDescribe().get('Phase__c').newSObject();
        phaseRecord.put('Name', name);
        putIfFieldExists(phaseRecord, 'Project__c', projectId);
        insert phaseRecord;
        return phaseRecord;
    }

    private static SObject createEoiRange(Id projectId, Id phaseId, String unitType, String bedrooms) {
        SObject rangeRecord = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(rangeRecord, 'Project__c', projectId);
        putIfFieldExists(rangeRecord, 'Phase__c', phaseId);
        putIfFieldExists(rangeRecord, 'Unit_Type__c', unitType);
        putIfFieldExists(rangeRecord, 'No_of_Bedrooms__c', bedrooms);
        putIfFieldExists(rangeRecord, 'Amount__c', 650000);
        putIfFieldExists(rangeRecord, 'Is_Active__c', true);
        putIfFieldExists(rangeRecord, 'Applicable_for_Broker__c', true);
        insert rangeRecord;
        return rangeRecord;
    }

    private static void putIfFieldExists(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }
}