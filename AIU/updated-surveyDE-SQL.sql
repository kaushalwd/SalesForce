select DISTINCT cm.CampaignId as CampaignId,
cm.Is_Speaker__c as [IsSpeaker],
cm.Is_Sponsor__c as [IsSponsor],
cm.ContactId,
cm.FirstName,
cm.LastName,
cm.status as CampaignMemberStatus,
cm.Email as EmailAddress,
con.Whatsapp_Number__c as PhoneNumber,
c.Id, 
cam.name as EventName,
c.ResponseStatus,
c.InvitationLink,
Cam.EndDate,
con.MailingCountryCode AS locale
from 
[SurveyInvitation] c join [Campaign Member] cm on cm.ContactId = c.ContactId
LEFT JOIN [Contact] con ON CM.ContactID=Con.ID
LEFT JOIN [Campaign] cam ON CM.CampaignId=Cam.ID
where 
cam.RecordTypeId = '012NM000002tAqPYAU'
and c.ResponseStatus != 'Completed'
and cam.EndDate = DATEADD(day, -1, CAST(GETDATE() AS DATE))
and (cm.email like '%@horizontal.com')