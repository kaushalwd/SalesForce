/**********************************************************************************************************************
* Name               : EoiPublicInviteController
* Description        : Guest-facing controller for the public invite microsite (/hge/invite). Resolves an HMAC-signed
*                      token to a Lead, exposes OTP verification, and on confirm updates the Lead with the selected
*                      typology and locks Site_Confirmed__c. No EOI / Opportunity / Account / Contact writes.
*                      Safety invariant: methods touch ONLY Lead (read+update on permset allowlist) and
*                      Verification_Request__c (via reused VerificationService).
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    04 June 2026    Initial invite confirmation controller
**********************************************************************************************************************/
public without sharing class EoiPublicInviteController {

    private static final String CONTEXT_INVITE = 'EOI_INVITE';
    private static final String STATUS_VERIFIED = 'Verified';
    private static final Integer VERIFICATION_WINDOW_MINUTES = 15;
    private static final String SHOW_ON_INVITE = 'Invite Microsite';

    @AuraEnabled(cacheable=true)
    public static InviteContext resolveInvite(String token) {
        InviteContext ctx = new InviteContext();
        ctx.valid = false;
        if (String.isBlank(token)) {
            ctx.message = 'Invitation link is missing.';
            return ctx;
        }
        InviteTokenSigner.TokenPayload payload;
        try {
            payload = InviteTokenSigner.verify(token);
        } catch (InviteTokenSigner.TokenException ex) {
            ctx.expired = ex.getMessage().toLowerCase().contains('expired');
            ctx.message = ctx.expired ? 'This invitation link has expired.' : 'Invitation link is not valid.';
            return ctx;
        }

        Id leadIdFromToken = payload.leadId;
        List<Lead> leads = Database.queryWithBinds(
            'SELECT Id, FirstName, LastName, Email, MobilePhone, UAEResidentStatus__c, ' +
            'EIDNumber__c, PassportNumber__c, ProjectInterest__c, ' +
            'Site_Confirmed__c, Site_Confirmed_At__c, Selected_Typology__c ' +
            'FROM Lead WHERE Id = :leadIdFromToken LIMIT 1',
            new Map<String, Object>{ 'leadIdFromToken' => leadIdFromToken },
            AccessLevel.SYSTEM_MODE
        );
        if (leads.isEmpty()) {
            ctx.message = 'Invitation link is not valid.';
            return ctx;
        }
        Lead l = leads[0];
        ctx.valid = true;
        ctx.leadId = l.Id;
        ctx.firstName = l.FirstName;
        ctx.lastName = l.LastName;
        ctx.email = l.Email;
        ctx.mobile = l.MobilePhone;
        ctx.residentStatus = l.UAEResidentStatus__c;
        ctx.emiratesId = l.EIDNumber__c;
        ctx.passportNumber = l.PassportNumber__c;
        ctx.projectName = l.ProjectInterest__c;
        ctx.expiresAt = payload.expiresAt;

        if (l.Site_Confirmed__c == true) {
            ctx.alreadyConfirmed = true;
            ctx.confirmedAt = l.Site_Confirmed_At__c;
            ctx.confirmedTypologyId = l.Selected_Typology__c;
        }

        Id projectId = resolveProjectIdFromName(l.ProjectInterest__c);
        ctx.projectId = projectId;
        return ctx;
    }

    @AuraEnabled(cacheable=true)
    public static List<InviteTile> getInviteTiles(Id projectId) {
        List<InviteTile> tiles = new List<InviteTile>();
        if (projectId == null) return tiles;
        for (EOI_Range__c r : [
            SELECT Id, Project__c, Phase__c, Phase__r.Name, Unit_Type__c,
                   No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c, Show_On__c
            FROM EOI_Range__c
            WHERE Project__c = :projectId
              AND Is_Active__c = true
              AND Show_On__c INCLUDES (:SHOW_ON_INVITE)
            ORDER BY Phase__r.Name ASC, Unit_Type__c ASC, No_of_Bedrooms__c ASC
        ]) {
            InviteTile tile = new InviteTile();
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
    public static VerificationService.VerificationResult startVerification(String token, String channel, String sessionToken, String target) {
        if (String.isBlank(channel)) throw new AuraHandledException('Channel is required.');
        InviteTokenSigner.TokenPayload payload = verifyTokenOrThrow(token);
        Lead l = loadLeadOrThrow(payload.leadId);
        String resolvedTarget = String.isNotBlank(target)
            ? target.trim()
            : ('Email'.equalsIgnoreCase(channel) ? l.Email : l.MobilePhone);
        if (String.isBlank(resolvedTarget)) {
            throw new AuraHandledException('No contact detail provided for the selected channel.');
        }
        VerificationService.VerificationStartRequest req = new VerificationService.VerificationStartRequest();
        req.channel = channel;
        req.target = resolvedTarget;
        req.context = CONTEXT_INVITE;
        req.contextKey = String.isBlank(sessionToken) ? String.valueOf(l.Id) : sessionToken;
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
    public static ConfirmResult confirmInvite(ConfirmRequest req) {
        if (req == null) throw new AuraHandledException('Confirmation payload is required.');
        InviteTokenSigner.TokenPayload payload = verifyTokenOrThrow(req.token);
        Verification_Request__c verification = loadVerifiedRequest(req.verificationRequestId);
        Lead l = loadLeadOrThrow(payload.leadId);

        if (l.Site_Confirmed__c == true) {
            ConfirmResult locked = new ConfirmResult();
            locked.success = false;
            locked.alreadyConfirmed = true;
            locked.confirmedAt = l.Site_Confirmed_At__c;
            locked.message = 'This invitation has already been confirmed.';
            return locked;
        }

        if (req.rangeId == null) throw new AuraHandledException('Please choose a typology before confirming.');
        List<EOI_Range__c> ranges = [
            SELECT Id, Project__c, Is_Active__c, Show_On__c
            FROM EOI_Range__c
            WHERE Id = :req.rangeId
            LIMIT 1
        ];
        if (ranges.isEmpty()) throw new AuraHandledException('Selected typology is no longer available.');
        EOI_Range__c range = ranges[0];
        if (range.Is_Active__c != true || !showsOnInvite(range.Show_On__c)) {
            throw new AuraHandledException('Selected typology is no longer available.');
        }

        applyEditableUpdates(l, req);
        l.Selected_Typology__c = req.rangeId;
        l.Site_Confirmed__c = true;
        l.Site_Confirmed_At__c = System.now();
        Database.update(new List<Lead>{ l }, AccessLevel.SYSTEM_MODE);

        ConfirmResult result = new ConfirmResult();
        result.success = true;
        result.alreadyConfirmed = false;
        result.leadId = l.Id;
        result.confirmedAt = l.Site_Confirmed_At__c;
        result.message = 'Confirmation received.';
        return result;
    }

    private static InviteTokenSigner.TokenPayload verifyTokenOrThrow(String token) {
        try {
            return InviteTokenSigner.verify(token);
        } catch (InviteTokenSigner.TokenException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static Lead loadLeadOrThrow(Id leadId) {
        List<Lead> leads = Database.queryWithBinds(
            'SELECT Id, FirstName, LastName, Email, MobilePhone, UAEResidentStatus__c, ' +
            'EIDNumber__c, PassportNumber__c, Site_Confirmed__c, Site_Confirmed_At__c ' +
            'FROM Lead WHERE Id = :leadId LIMIT 1',
            new Map<String, Object>{ 'leadId' => leadId },
            AccessLevel.SYSTEM_MODE
        );
        if (leads.isEmpty()) throw new AuraHandledException('Invitation lead not found.');
        return leads[0];
    }

    private static Verification_Request__c loadVerifiedRequest(Id verificationRequestId) {
        if (verificationRequestId == null) {
            throw new AuraHandledException('Please complete verification before confirming.');
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
            throw new AuraHandledException('Please complete verification before confirming.');
        }
        if (request.Verified_At__c == null ||
            request.Verified_At__c < System.now().addMinutes(-VERIFICATION_WINDOW_MINUTES)) {
            throw new AuraHandledException('Verification has expired. Please verify again.');
        }
        return request;
    }

    private static void applyEditableUpdates(Lead l, ConfirmRequest req) {
        if (String.isNotBlank(req.firstName)) l.FirstName = req.firstName;
        if (String.isNotBlank(req.lastName)) l.LastName = req.lastName;
        if (String.isNotBlank(req.email)) {
            l.Email = req.email;
            putIfFieldExists(l, 'En_Email__c', req.email);
        }
        if (String.isNotBlank(req.mobile)) {
            l.MobilePhone = req.mobile;
            putIfFieldExists(l, 'En_MobilePhone__c', req.mobile);
        }
        if (String.isNotBlank(req.residentStatus)) l.UAEResidentStatus__c = req.residentStatus;
        if (String.isNotBlank(req.emiratesId)) {
            l.EIDNumber__c = req.emiratesId;
            putIfFieldExists(l, 'En_EIDNumber__c', req.emiratesId);
        }
        if (String.isNotBlank(req.passportNumber)) {
            l.PassportNumber__c = req.passportNumber;
            putIfFieldExists(l, 'En_PassportNumber__c', req.passportNumber);
        }
    }

    private static void putIfFieldExists(SObject record, String fieldName, Object value) {
        if (record == null || value == null) return;
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private static Boolean showsOnInvite(String showOn) {
        if (String.isBlank(showOn)) return false;
        for (String value : showOn.split(';')) {
            if (SHOW_ON_INVITE.equalsIgnoreCase(value.trim())) return true;
        }
        return false;
    }

    private static Id resolveProjectIdFromName(String projectName) {
        if (String.isBlank(projectName)) return null;
        List<Project__c> projects = [SELECT Id FROM Project__c WHERE Name = :projectName LIMIT 1];
        return projects.isEmpty() ? null : projects[0].Id;
    }

    public class InviteContext {
        @AuraEnabled public Boolean valid;
        @AuraEnabled public Boolean expired = false;
        @AuraEnabled public Boolean alreadyConfirmed = false;
        @AuraEnabled public Id leadId;
        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public String emiratesId;
        @AuraEnabled public String passportNumber;
        @AuraEnabled public DateTime expiresAt;
        @AuraEnabled public DateTime confirmedAt;
        @AuraEnabled public Id confirmedTypologyId;
        @AuraEnabled public String message;
    }

    public class InviteTile {
        @AuraEnabled public Id rangeId;
        @AuraEnabled public Id projectId;
        @AuraEnabled public Id phaseId;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public Decimal amount;
    }

    public class ConfirmRequest {
        @AuraEnabled public String token { get; set; }
        @AuraEnabled public Id verificationRequestId { get; set; }
        @AuraEnabled public Id rangeId { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        @AuraEnabled public String emiratesId { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
    }

    public class ConfirmResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Boolean alreadyConfirmed;
        @AuraEnabled public Id leadId;
        @AuraEnabled public DateTime confirmedAt;
        @AuraEnabled public String message;
    }
}