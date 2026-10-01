/**********************************************************************************************************************
* Name               : EmailSenderConfigService
* Description        : Resolves configured org-wide sender email addresses
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    14 May 2026     Initial org-wide sender resolver
**********************************************************************************************************************/
public without sharing class EmailSenderConfigService {
    private static Map<String, Id> orgWideEmailIdByAddress = new Map<String, Id>();

    public static Id getOrgWideEmailAddressId(String fromEmail) {
        if (String.isBlank(fromEmail)) return null;

        String normalizedEmail = fromEmail.trim().toLowerCase();
        if (orgWideEmailIdByAddress.containsKey(normalizedEmail)) {
            return orgWideEmailIdByAddress.get(normalizedEmail);
        }

        List<OrgWideEmailAddress> addresses = [
            SELECT Id, Address
            FROM OrgWideEmailAddress
            WHERE Address = :fromEmail.trim()
            LIMIT 1
        ];
        Id orgWideEmailAddressId = addresses.isEmpty() ? null : addresses[0].Id;
        orgWideEmailIdByAddress.put(normalizedEmail, orgWideEmailAddressId);
        return orgWideEmailAddressId;
    }
}