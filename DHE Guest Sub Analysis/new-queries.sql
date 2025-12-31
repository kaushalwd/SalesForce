



/*How many records in Temp_Pause_Data are not present DE-1 - Table name*/
/* TempPause_Updated_GSData */
459

SELECT DISTINCT
    d2.SubscriberKey,
    d2.ContactId,
    d2.Email,
    d2.Asset,
    d2.UnsubscribeType,
    d2.DateAdded
FROM [Temp_Pause_Data] d2
LEFT JOIN [DE1-GSData] d1
    ON LOWER(TRIM(d2.SubscriberKey)) = LOWER(TRIM(d1.ParentId))
WHERE d1.ParentId IS NULL

/* How many records are not present in Temp_Pause_Data and present in DE-1 - Table name - DE1_Updated_GSData */
719

SELECT DISTINCT
    d1.ParentId AS SubscriberKey
FROM [DE1-GSData] d1
LEFT JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d1.ParentId)) = LOWER(TRIM(d2.SubscriberKey))
WHERE d2.SubscriberKey IS NULL



/* Count of unique Guest Subscription ids which got updated from DE TempPause_Updated_GSData */
459

SELECT DISTINCT
    SubscriberKey
FROM [TempPause_Updated_GSData]



/*List down Guest Subscription ids along with Old Value, New value etc in sheet from TempPause_Updated_GSData */
/* Unique_GS_List */
652

SELECT DISTINCT
    d2.SubscriberKey,
    d1.FieldName,
    d1.NewValue,
    d1.OldValue
FROM [Temp_Pause_Data] d2
INNER JOIN [DE1-GSData] d1
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.P_Contact__c))





SELECT DISTINCT
    d1.ParentId AS SubscriberKey
FROM [Contacts-DE-Unique] d1
Inner JOIN [Contacts-DE2] d2
    ON LOWER(TRIM(d1.ContactId)) = LOWER(TRIM(d2.Account_PersonContactId))