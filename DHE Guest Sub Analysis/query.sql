- Total contacts
- Find out if status was changes for these records in CRM
- Count of All subscribers records with Status as Unsubscribed

Common records on bith DEs = 96

SELECT DISTINCT
    d2.SubscriberKey,
    d2.ContactId,
    d2.Email,
    d2.Asset,
    d2.UnsubscribeType,
    d2.DateAdded
FROM [Temp_Pause_Data] d2
INNER JOIN [GS-AllUpdates] d1
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.P_Contact__c))


SELECT DISTINCT
    d2.SubscriberKey,
    d2.ContactId,
    d2.Email,
    d2.Asset,
    d2.UnsubscribeType,
    d2.DateAdded
FROM [Temp_Pause_Data] d2
INNER JOIN [GS-AllUpdates] d1
    ON LOWER(TRIM(d2.SubscriberKey)) = LOWER(TRIM(d1.ParentId))

-------------

Common records on bith DEs with all the fields

SELECT DISTINCT
    d1.Account_PersonContactId,
    d1.Field,
    d1.NewValue,
    d1.OldValue
FROM [GS-AllUpdates] d1
INNER JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.P_Contact__c))

-------------------
36 Records unique records with Subscribed status


SELECT DISTINCT
    d1.FieldName,
    d1.NewValue,
    d1.OldValue,
    d1.Parent,
    d1.P_Status__c,
    d1.P_Consent_Collection_Asset__c,
    d1.P_Consent_Collection_Sub_Asset__c,
    d1.P_Subscription_Date__c,
    d1.P_Email__c,
    d1.P_Contact__c,
    d1.P_Contact__r,
    d1.P_Contact__r_Latest_Channel_Source__c,
    d1.P_Contact__r_Receive_Updates__c,
    d1.ParentId
FROM [GS-AllUpdates] d1
INNER JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.P_Contact__c))
WHERE
    LOWER(TRIM(d1.NewValue)) = 'Subscribed'
    AND LOWER(TRIM(d1.OldValue)) = 'Unsubscribed'



--------------

Only One Record

SELECT DISTINCT
    d1.FieldName,
    d1.NewValue,
    d1.OldValue,
    d1.Parent,
    d1.P_Status__c,
    d1.P_Consent_Collection_Asset__c,
    d1.P_Consent_Collection_Sub_Asset__c,
    d1.P_Subscription_Date__c,
    d1.P_Email__c,
    d1.P_Contact__c,
    d1.P_Contact__r,
    d1.P_Contact__r_Latest_Channel_Source__c,
    d1.P_Contact__r_Receive_Updates__c,
    d1.ParentId
FROM [GS-AllUpdates] d1
INNER JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.P_Contact__c))
WHERE
    LOWER(TRIM(d1.NewValue)) = 'Unsubscribed'
    AND LOWER(TRIM(d1.OldValue)) = 'Subscribed'


-----------
SELECT DISTINCT
    d1.P_Contact__c
FROM [GS-AllUpdates] d1
INNER JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.P_Contact__c))
WHERE
    LOWER(TRIM(d1.NewValue)) = 'Subscribed'
    AND LOWER(TRIM(d1.OldValue)) = 'Unsubscribed'


    -----------

SELECT
    c.SubscriberKey,
    c.EventDate,
    c.JobID,
    c.URL,
    c.LinkName,
    c.IsUnique
FROM _Click c
Inner Join GS-All-Unsub G
ON C.SubscriberKey = G.P_Contact__c
WHERE c.SubscriberKey = 'SUK001'
  AND c.EventDate >= DATEADD(day, -3, GETDATE())
  AND c.LinkName LIKE '%cloud.explore%'
  AND c.IsUnique = 1 



