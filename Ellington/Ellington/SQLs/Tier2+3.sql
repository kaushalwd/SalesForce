SELECT TOP 2361
    sub.SubscriberKey,
    sub.Email,
    sub.FirstName,
    sub.LastName,
    sub.SourceTier
FROM (
    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 3' AS SourceTier,
        1 AS Priority
    FROM [Tier 3 - NonGmail V2]

    UNION ALL

    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 2' AS SourceTier,
        2 AS Priority
    FROM [Tier 2 - NonGmail V2]
) sub
WHERE NOT EXISTS (
    SELECT 1 
    FROM [Day12_Tier2_NonGmail_Email1] ex1 
    WHERE ex1.SubscriberKey = sub.SubscriberKey
)
AND NOT EXISTS (
    SELECT 1 
    FROM [Day13_Tier2_NonGmail_Email1] ex2 
    WHERE ex2.SubscriberKey = sub.SubscriberKey
)
AND NOT EXISTS (
    SELECT 1 
    FROM [Day12_Tier3_Gmail_Email1] ex3 
    WHERE ex3.SubscriberKey = sub.SubscriberKey
)
AND NOT EXISTS (
    SELECT 1 
    FROM [Day13_Tier3_Gmail_Email1] ex4 
    WHERE ex4.SubscriberKey = sub.SubscriberKey
)
ORDER BY sub.Priority ASC