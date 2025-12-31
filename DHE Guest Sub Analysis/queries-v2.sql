
/* Records in [Temp_Pause_Data] that are NOT present in [Guest-DE-Unique] */   
 /* 457 */

SELECT DISTINCT
    d2.SubscriberKey
FROM [Temp_Pause_Data] d2
LEFT JOIN [Guest-DE-Unique] d1
    ON LOWER(TRIM(d2.SubscriberKey)) = LOWER(TRIM(d1.GuestId))
WHERE d1.GuestId IS NULL

 /* Records in [Temp_Pause_Data] that are NOT present in [Contacts-DE-Unique] */   
 /* 457 */

SELECT DISTINCT
    d2.ContactId AS SubscriberKey
FROM [Temp_Pause_Data] d2
LEFT JOIN [Contacts-DE-Unique] d1
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.ContactId))
WHERE d1.ContactId IS NULL











/* Common ContactIds in [Temp_Pause_Data] and [Contacts-DE2] */
/* 97 */

SELECT DISTINCT
    d1.Account_PersonContactId AS SubscriberKey
FROM [Contacts-DE2] d1
Inner JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d1.Account_PersonContactId)) = LOWER(TRIM(d2.ContactId))


/* All unique ContactIds that exist in [Contacts-DE-Unique] and [Temp_Pause_Data] */
/* 98 */

SELECT DISTINCT
    d1.ContactId AS SubscriberKey
FROM [Contacts-DE-Unique] d1
INNER JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d1.ContactId)) = LOWER(TRIM(d2.ContactId))


/* All unique ContactIds that exist in [Contacts-DE-Unique] but do NOT exist in [Temp_Pause_Data] */
/* 54 */

SELECT DISTINCT
    d1.ContactId AS SubscriberKey
FROM [Contacts-DE-Unique] d1
Left JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d1.ContactId)) = LOWER(TRIM(d2.ContactId))
WHERE d1.ContactId IS NULL 

/* All unique ContactIds that exist in [Contacts-DE-Unique] and [Contacts-DE2] */

SELECT DISTINCT
    d1.Account_PersonContactId AS SubscriberKey,
    d1.FieldName,
    d1.NewValue,
    d1.OldValue
FROM [Contacts-DE2] d1
Inner JOIN [Contacts-DE-Unique] d2
    ON LOWER(TRIM(d1.Account_PersonContactId)) = LOWER(TRIM(d2.ContactId))


/* Common GuestIds in [DE1-GSData] and [Temp_Pause_Data] */

SELECT DISTINCT
    d1.ParentId AS SubscriberKey
FROM [DE1-GSData] d1
LEFT JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d1.ParentId)) = LOWER(TRIM(d2.SubscriberKey))
WHERE d2.SubscriberKey IS NULL

/* Common GuestIds in [Guest-DE-Unique] and [Temp_Pause_Data]*/
/* 98 */

SELECT DISTINCT
    d1.GuestId AS SubscriberKey
FROM [Guest-DE-Unique] d1
INNER JOIN [Temp_Pause_Data] d2
    ON LOWER(TRIM(d1.GuestId)) = LOWER(TRIM(d2.SubscriberKey))



/* Records in [Temp_Pause_Data] that are NOT present in [Guest-DE1] */   
 /* 457 */

SELECT DISTINCT
    d2.SubscriberKey
FROM [Temp_Pause_Data] d2
LEFT JOIN [Guests-DE1] d1
    ON LOWER(TRIM(d2.SubscriberKey)) = LOWER(TRIM(d1.ParentId))
WHERE d1.ParentId IS NULL


SELECT DISTINCT
    d2.ContactId AS SubscriberKey
FROM [Temp_Pause_Data] d2
LEFT JOIN [Contacts-DE-Unique] d1
    ON LOWER(TRIM(d2.ContactId)) = LOWER(TRIM(d1.ContactId))
WHERE d1.ContactId IS NULL
