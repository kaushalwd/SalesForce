SELECT SubscriberKey, ContactId, UnsubscribeType, Asset, Email, DateAdded  FROM
(SELECT  t.SubscriberKey, t.ContactId, t.UnsubscribeType, t.Asset, t.Email, t.DateAdded,
ROW_NUMBER() OVER(PARTITION BY t.ContactId ORDER BY t.DateAdded DESC) RN
FROM ENT.TempPauseHandle_QA t  inner join ent.Master_Contact_Salesforce c on t.ContactId=c.Id
WHERE
DateAdded <= DATEADD(DAY, -30, GETDATE()) and
(
(Asset = 'Riverland' AND UnsubscribeType = 'Individual') or
(UnsubscribeType = 'All')
))l
WHERE RN=1