SELECT 
    d4.SubscriberKey,
    'Duplicate found in Day 9' as Status,
    CASE 
        WHEN d4.SegmentSource = 'Day9_Gmail' THEN 'Gmail'
        ELSE 'Non-Gmail'
    END as SegmentType
FROM (
    SELECT SubscriberKey, 'Day9_Gmail' as SegmentSource FROM [Day9_Tier3_Gmail_Email1]
    UNION
    SELECT SubscriberKey, 'Day9_NonGmail' as SegmentSource FROM [Day9_Tier2_NonGmail_Email1]
) d4
WHERE d4.SubscriberKey IN (
    SELECT SubscriberKey FROM [Day8_Tier3_Gmail_Email1]
    UNION
    SELECT SubscriberKey FROM [Day8_Tier2_NonGmail_Email1]
)