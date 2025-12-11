select
l.SubscriberKey,
l.Status as AllsubSstatus,
m.Status__c as CRMStatus,
m.Id as GuestSubsId,
m.LastModifiedDate
from _ListSubscribers as l
inner join [QA_MasterDE_Riverland_Ru] as m on m.Contact__c = l.SubscriberKey
where ListID = '2320' and (l.Status= 'Unsubscribed' and m.Status__c ='Subscribed') 
and LastModifiedDate > '10/10/2024'