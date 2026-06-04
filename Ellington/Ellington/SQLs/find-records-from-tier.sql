SELECT 
    rm.[SubscriberKey],
    tiers.[Source_Tier] AS [Matched_Tier]
FROM [ng - 3] AS rm
INNER JOIN (
    SELECT [SubscriberKey], 'Tier 1 - NonGmail V2' AS [Source_Tier] FROM [Tier 1 - NonGmail V2]
    UNION ALL
    SELECT [SubscriberKey], 'Tier 2 - NonGmail V2' AS [Source_Tier] FROM [Tier 2 - NonGmail V2]
    UNION ALL
    SELECT [SubscriberKey], 'Tier 3 - NonGmail V2' AS [Source_Tier] FROM [Tier 3 - NonGmail V2]
    UNION ALL
    SELECT [SubscriberKey], 'Tier 4 - NonGmail V2' AS [Source_Tier] FROM [Tier 4 - NonGmail V2]
    UNION ALL
    SELECT [SubscriberKey], 'Tier 5 - NonGmail V2' AS [Source_Tier] FROM [Tier 5 - NonGmail V2]
) AS tiers 
ON rm.[SubscriberKey] = tiers.[SubscriberKey]



------------------------------------------------------------------------


SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    s.Status
FROM (    
    SELECT Email, SubscriberKey FROM [Tier 1 - NonGmail V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Tier 2 - NonGmail V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Tier 3 - NonGmail V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Tier 4 - NonGmail V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Tier 5 - NonGmail V2]
) f
LEFT JOIN _Subscribers s
    ON f.Email = s.EmailAddress
WHERE s.Status != 'active'