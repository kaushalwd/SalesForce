select top 250 
q.SubscriberKey, q.CRMStatus, q.LastModifiedDate,q.EmailPreference,
case
when q.CRMStatus = 'Subscribed' then 'Active'
end as UpdatedAllsubSstatus
from [QA_AllSubs_Update_temp_Riverland] q
