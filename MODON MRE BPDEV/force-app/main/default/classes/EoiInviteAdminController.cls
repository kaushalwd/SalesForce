/**********************************************************************************************************************
* Name               : EoiInviteAdminController
* Description        : Internal-only controller for generating public invite links for Leads. Builds an HMAC-signed
*                      token via InviteTokenSigner and returns the full microsite URL including ?token=<token>.
*                      With sharing because this runs in internal user context (Sales / Marketing admins).
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    04 June 2026    Initial version
**********************************************************************************************************************/
public with sharing class EoiInviteAdminController {

    private static final String INVITE_PATH = '/invite';

    @AuraEnabled
    public static InviteLinkResult generateInviteLink(Id leadId, Integer expiryDays) {
        if (leadId == null) throw new AuraHandledException('Lead Id is required.');
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Email, MobilePhone, ProjectInterest__c,
                   Site_Confirmed__c, Site_Confirmed_At__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leads.isEmpty()) throw new AuraHandledException('Lead not found.');
        Lead l = leads[0];

        InviteLinkResult result = new InviteLinkResult();
        result.leadId = l.Id;
        result.leadName = String.isBlank(l.FirstName)
            ? (l.LastName == null ? '' : l.LastName)
            : (l.FirstName + ' ' + (l.LastName == null ? '' : l.LastName));
        result.email = l.Email;
        result.mobile = l.MobilePhone;
        result.projectName = l.ProjectInterest__c;
        result.alreadyConfirmed = l.Site_Confirmed__c == true;
        result.confirmedAt = l.Site_Confirmed_At__c;

        try {
            String token = expiryDays == null
                ? InviteTokenSigner.generate(l.Id)
                : InviteTokenSigner.generate(l.Id, expiryDays);
            result.token = token;
            result.url = buildBaseUrl() + INVITE_PATH + '?token=' + token;
            result.expiresAt = InviteTokenSigner.verify(token).expiresAt;
        } catch (InviteTokenSigner.TokenException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return result;
    }

    private static String buildBaseUrl() {
        List<Site_Config__mdt> cfgs = [
            SELECT Public_Site_Base_URL__c
            FROM Site_Config__mdt
            WHERE DeveloperName = 'Active_Microsite'
            LIMIT 1
        ];
        if (cfgs.isEmpty() || String.isBlank(cfgs[0].Public_Site_Base_URL__c)) {
            throw new AuraHandledException('Public_Site_Base_URL__c is not configured on Site_Config__mdt.Active_Microsite.');
        }
        String configured = cfgs[0].Public_Site_Base_URL__c.trim();
        if (configured.endsWith('/')) configured = configured.substring(0, configured.length() - 1);
        return configured;
    }

    public class InviteLinkResult {
        @AuraEnabled public Id leadId;
        @AuraEnabled public String leadName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String projectName;
        @AuraEnabled public Boolean alreadyConfirmed;
        @AuraEnabled public DateTime confirmedAt;
        @AuraEnabled public String token;
        @AuraEnabled public String url;
        @AuraEnabled public DateTime expiresAt;
    }
}