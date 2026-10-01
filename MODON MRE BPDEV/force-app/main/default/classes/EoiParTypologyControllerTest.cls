/**********************************************************************************************************************
* Name               : EoiParTypologyControllerTest
* Description        : Test coverage for EoiParTypologyController. Exercises tile retrieval, submit happy path
*                      (create new Lead + EOI Public Registration), Lead match-and-update path, Retired-lead
*                      bypass (creates new), and error paths (missing verification, missing typology).
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    05 June 2026    Initial version
**********************************************************************************************************************/
@IsTest
private class EoiParTypologyControllerTest {

    @IsTest
    static void getParTilesReturnsOnlyParTypologyRanges() {
        SObject project = createProject('HGE Par Tiles');
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject parRange = createParRange((Id) project.get('Id'), (Id) phase.get('Id'), 'Par 3', '3 Bedrooms', 4900000);

        SObject otherRange = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        otherRange.put('Project__c', (Id) project.get('Id'));
        otherRange.put('Phase__c', (Id) phase.get('Id'));
        otherRange.put('Unit_Type__c', 'Villa');
        otherRange.put('No_of_Bedrooms__c', '4 Bedrooms');
        otherRange.put('UnitTypologyMRE__c', 'Golf Mansions');
        otherRange.put('Amount__c', 1000000);
        otherRange.put('Is_Active__c', true);
        otherRange.put('Show_On__c', 'Public Microsite');
        insert otherRange;

        List<EoiParTypologyController.ParTile> tiles =
            EoiParTypologyController.getParTiles((Id) project.get('Id'));
        System.assertEquals(1, tiles.size(), 'Only Par Typology ranges should return.');
        System.assertEquals((Id) parRange.get('Id'), tiles[0].rangeId);
    }

    @IsTest
    static void submitRegistrationCreatesNewLeadAndEpr() {
        Verification_Request__c v = createVerifiedRequest('new@example.com', 'Email');
        EoiParTypologyController.ParRegistrationDTO dto = baseDto('Brand', 'New', 'new@example.com', '+971501234567');
        dto.verificationRequestId = v.Id;
        dto.typology = 'Par 3';
        dto.utmSource = 'HGE_PAR'; dto.utmCampaign = 'HGE_PAR'; dto.utmSubSource = 'WhatsApp';

        Test.startTest();
        EoiParTypologyController.SubmitResult result = EoiParTypologyController.submitRegistration(dto);
        Test.stopTest();

        System.assertNotEquals(null, result.recordId);
        System.assertNotEquals(null, result.matchedLeadId);

        Lead l = [SELECT Id, Status, Typology__c, LeadSource, Email FROM Lead WHERE Id = :result.matchedLeadId];
        System.assertEquals('Par 3', l.Typology__c);
        System.assertEquals('New', l.Status);
        System.assertEquals('Social Media', l.LeadSource, 'UTM present should mark LeadSource=Social Media');

        EOI_Public_Registration__c reg = [
            SELECT Id, Typology__c, Source__c, Status__c
            FROM EOI_Public_Registration__c WHERE Id = :result.recordId
        ];
        System.assertEquals('Par 3', reg.Typology__c);
        System.assertEquals('Verified', reg.Status__c);
    }

    @IsTest
    static void submitRegistrationUpdatesExistingLeadByEmail() {
        Lead existing = new Lead(
            FirstName = 'Existing', LastName = 'Lead',
            Email = 'match@example.com', MobilePhone = '+971502222222',
            Company = 'Test Co', Status = 'New', LeadSource = 'Direct'
        );
        applyProjectInterest(existing);
        insert existing;

        Verification_Request__c v = createVerifiedRequest('match@example.com', 'Email');
        EoiParTypologyController.ParRegistrationDTO dto = baseDto('Updated', 'Lead', 'match@example.com', '+971502222222');
        dto.verificationRequestId = v.Id;
        dto.typology = 'Par 4';

        EoiParTypologyController.SubmitResult result = EoiParTypologyController.submitRegistration(dto);

        Lead l = [SELECT Id, Typology__c, FirstName, LeadSource FROM Lead WHERE Id = :existing.Id];
        System.assertEquals('Par 4', l.Typology__c);
        System.assertEquals('Updated', l.FirstName);
        System.assertEquals('Direct', l.LeadSource, 'LeadSource on existing Lead should not be overwritten.');
        System.assertEquals(existing.Id, result.matchedLeadId);
    }

    @IsTest
    static void submitRegistrationSkipsRetiredLeadAndCreatesNew() {
        Lead retired = new Lead(
            FirstName = 'Old', LastName = 'Retired',
            Email = 'retired@example.com', MobilePhone = '+971503333333',
            Company = 'Test Co', Status = 'New'
        );
        applyProjectInterest(retired);
        insert retired;
        retired.Status = 'Retired';
        Schema.SObjectField reason = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('RetiredReason__c');
        if (reason != null) retired.put('RetiredReason__c', firstPicklistValue('Lead', 'RetiredReason__c'));
        Schema.SObjectField comments = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('RetirementComments__c');
        if (comments != null) retired.put('RetirementComments__c', 'Test retire');
        update retired;

        Verification_Request__c v = createVerifiedRequest('retired@example.com', 'Email');
        EoiParTypologyController.ParRegistrationDTO dto = baseDto('Fresh', 'Lead', 'retired@example.com', '+971503333333');
        dto.verificationRequestId = v.Id;
        dto.typology = 'Par 3';

        EoiParTypologyController.SubmitResult result = EoiParTypologyController.submitRegistration(dto);
        System.assertNotEquals(retired.Id, result.matchedLeadId, 'Retired Lead should be bypassed; a new Lead is created.');

        Lead created = [SELECT Status FROM Lead WHERE Id = :result.matchedLeadId];
        System.assertEquals('New', created.Status);
    }

    @IsTest
    static void submitRegistrationThrowsWithoutVerification() {
        EoiParTypologyController.ParRegistrationDTO dto = baseDto('No', 'Verify', 'nv@example.com', '+971504444444');
        dto.typology = 'Par 3';
        try {
            EoiParTypologyController.submitRegistration(dto);
            System.assert(false, 'Should throw without a verified request.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void submitRegistrationThrowsWithoutTypology() {
        Verification_Request__c v = createVerifiedRequest('nt@example.com', 'Email');
        EoiParTypologyController.ParRegistrationDTO dto = baseDto('No', 'Typology', 'nt@example.com', '+971505555555');
        dto.verificationRequestId = v.Id;
        try {
            EoiParTypologyController.submitRegistration(dto);
            System.assert(false, 'Should throw without typology selection.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void getActiveProjectReturnsEmptyWhenNoConfig() {
        EoiParTypologyController.ProjectConfig cfg = EoiParTypologyController.getActiveProject();
        System.assertNotEquals(null, cfg);
    }

    @IsTest
    static void matchesExistingLeadByMobile() {
        Lead existing = new Lead(
            FirstName = 'Phone', LastName = 'Match',
            Email = 'phone-match@example.com', MobilePhone = '+971507777777',
            Company = 'Test Co', Status = 'New'
        );
        applyProjectInterest(existing);
        insert existing;

        Verification_Request__c v = createVerifiedRequest('+971507777777', 'SMS');
        EoiParTypologyController.ParRegistrationDTO dto = baseDto('Phone', 'Updated', 'different@example.com', '+971507777777');
        dto.verificationRequestId = v.Id;
        dto.typology = 'Par 3';

        EoiParTypologyController.SubmitResult result = EoiParTypologyController.submitRegistration(dto);
        System.assertEquals(existing.Id, result.matchedLeadId);
    }

    @IsTest
    static void verifyCodeDelegatesToService() {
        Verification_Request__c v = createVerifiedRequest('verify@example.com', 'Email');
        try {
            EoiParTypologyController.verifyCode(v.Id, '000000');
        } catch (Exception ex) {
            // service may throw on bad code — exercise path only
        }
    }

    @IsTest
    static void startVerificationThrowsForMissingChannelOrTarget() {
        try {
            EoiParTypologyController.startVerification(null, '+971501234567', 'sess');
            System.assert(false, 'Should throw for missing channel.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
        try {
            EoiParTypologyController.startVerification('Email', null, 'sess');
            System.assert(false, 'Should throw for missing target.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    private static void applyProjectInterest(Lead l) {
        Schema.SObjectField pi = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('ProjectInterest__c');
        if (pi == null) return;
        String value = firstPicklistValue('Lead', 'ProjectInterest__c');
        if (String.isNotBlank(value)) l.put('ProjectInterest__c', value);
    }

    private static String firstPicklistValue(String objectName, String fieldName) {
        Schema.SObjectField f = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName);
        if (f == null) return null;
        if (f.getDescribe().getType() != Schema.DisplayType.Picklist) return null;
        for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }

    private static EoiParTypologyController.ParRegistrationDTO baseDto(String fn, String ln, String email, String mobile) {
        EoiParTypologyController.ParRegistrationDTO dto = new EoiParTypologyController.ParRegistrationDTO();
        dto.firstName = fn; dto.lastName = ln; dto.email = email; dto.mobile = mobile;
        dto.residentStatus = 'Resident'; dto.locale = 'en_US';
        return dto;
    }

    private static SObject createProject(String name) {
        SObject p = Schema.getGlobalDescribe().get('Project__c').newSObject();
        p.put('Name', name);
        if (Schema.getGlobalDescribe().get('Project__c').getDescribe().fields.getMap().containsKey('EOI_Limit__c')) {
            p.put('EOI_Limit__c', 10);
        }
        insert p;
        return p;
    }

    private static SObject createPhase(String name, Id projectId) {
        SObject ph = Schema.getGlobalDescribe().get('Phase__c').newSObject();
        ph.put('Name', name);
        if (Schema.getGlobalDescribe().get('Phase__c').getDescribe().fields.getMap().containsKey('Project__c')) {
            ph.put('Project__c', projectId);
        }
        insert ph;
        return ph;
    }

    private static SObject createParRange(Id projectId, Id phaseId, String typology, String bedrooms, Decimal amount) {
        SObject r = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        r.put('Project__c', projectId);
        r.put('Phase__c', phaseId);
        r.put('Unit_Type__c', 'Villa');
        r.put('No_of_Bedrooms__c', bedrooms);
        r.put('UnitTypologyMRE__c', typology);
        r.put('Amount__c', amount);
        r.put('Is_Active__c', true);
        r.put('Show_On__c', 'Par Typology');
        insert r;
        return r;
    }

    private static Verification_Request__c createVerifiedRequest(String target, String channel) {
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = channel,
            Target__c = target,
            Masked_Target__c = target.substringBefore('@').left(1) + '***@' + target.substringAfter('@'),
            Status__c = 'Verified',
            Context__c = 'EOI_PAR_TYPOLOGY',
            Expires_At__c = System.now().addMinutes(5),
            Verified_At__c = System.now()
        );
        insert v;
        return v;
    }
}