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
c.EndDate,
c.name as EventName,
con.MailingCountryCode AS locale
from 
[Campaign Member] cm join [Campaign] c on cm.CampaignId = c.Id
LEFT JOIN [Contact] con ON CM.ContactID=Con.ID
where cm.status = 'Attended'
and c.RecordTypeId = '012NM000002tAqQYAU'
and (cm.email like '%@horizontal.com')