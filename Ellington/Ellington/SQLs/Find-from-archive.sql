SELECT 
    source.SubscriberKey,
    source.SourceDE,
    activity.Type,
    activity.EventDate
FROM (
    SELECT SubscriberKey, 'Non-Gmail' as SourceDE FROM [Day8_Tier2_NonGmail_Email1]
    UNION
    SELECT SubscriberKey, 'Gmail' as SourceDE FROM [Day8_Tier3_Gmail_Email1]
) source
INNER JOIN (
    SELECT SubscriberKey, 'Bounce' as Type, EventDate FROM [BounceArchive]
    UNION
    SELECT SubscriberKey, 'Unsubscribe' as Type, EventDate FROM [UnsubscribeArchive]
    UNION
    SELECT SubscriberKey, 'Complaint' as Type, EventDate FROM [ComplaintArchive]
) activity ON source.SubscriberKey = activity.SubscriberKey
WHERE activity.EventDate >= '2026-04-27'

--------

SELECT
    d.SubscriberKey,
    d.Email,
    s.Status AS SubscriberStatus
FROM Day8_Tier3_Gmail_Email1 d
LEFT JOIN _Subscribers s
    ON d.Email = s.EmailAddress
WHERE s.Status != 'active'