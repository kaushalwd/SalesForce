select DISTINCT cm.CampaignId as CampaignId,
cm.Is_Speaker__c as [IsSpeaker],
cm.Is_Sponsor__c as [IsSponsor],
cm.ContactId,
cm.FirstName,
cm.LastName,
cm.status as CampaignMemberStatus,
cm.Email as EmailAddress,
con.Whatsapp_Number__c as PhoneNumber,
cam.name as EventName,
c.ResponseStatus,
c.InvitationLink,
Cam.EndDate,
con.MailingCountryCode AS locale,
c.Id as SurveyRecordId
from 
[SurveyInvitation] c join [Campaign Member] cm on cm.ContactId = c.ContactId
LEFT JOIN [Contact] con ON CM.ContactID=Con.ID
LEFT JOIN [Campaign] cam ON CM.CampaignId=Cam.ID
where 
cam.RecordTypeId = '012NM000002tAqPYAU'
AND (CAST(c.CreatedDate AS DATE)  = DATEADD(day, -1, CAST(cam.EndDate AS DATE))
    OR CAST(c.CreatedDate AS DATE) = DATEADD(day, +1, CAST(cam.EndDate AS DATE)))
and (cm.email like '%@horizontal.com')
