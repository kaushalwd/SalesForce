SELECT TOP 24533
        dg.SubscriberKey,
        dg.Email,
        dg.FirstName,
        dg.LastName,
        dg.SourceTier,
        1 AS priority_group
    FROM (
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 1' AS SourceTier FROM [Tier 1 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 2' AS SourceTier FROM [Tier 2 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 3' AS SourceTier FROM [Tier 3 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 4' AS SourceTier FROM [Tier 4 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 5' AS SourceTier FROM [Tier 5 - NonGmail V2]
    ) dg
    
    LEFT JOIN [Day12_Tier4_Gmail_Email2_V2] d12 
        ON dg.SubscriberKey = d12.SubscriberKey

    LEFT JOIN [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] d12n 
        ON dg.SubscriberKey = d12n.SubscriberKey

    LEFT JOIN [Day13_Tier4_Tier5_Gmail_TeaserEmail_1] d13 
        ON dg.SubscriberKey = d13.SubscriberKey

    LEFT JOIN [Day13_Tier1_Tier2_Tier3_NonGmail_TeaserEmail_1] d13n 
        ON dg.SubscriberKey = d13n.SubscriberKey

    LEFT JOIN [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] d14 
        ON dg.SubscriberKey = d14.SubscriberKey

    LEFT JOIN [Day14_NonGmail_TeaserEmail_1] d14n 
        ON dg.SubscriberKey = d14n.SubscriberKey

    LEFT JOIN [Day15_Gmail_TeaserEmail_1] d15 
        ON dg.SubscriberKey = d15.SubscriberKey

    LEFT JOIN [Day15_NonGmail_TeaserEmail_1] d15n 
        ON dg.SubscriberKey = d15n.SubscriberKey

    WHERE 
        d12.SubscriberKey IS NULL
        AND d12n.SubscriberKey IS NULL
        AND d13.SubscriberKey IS NULL
        AND d13n.SubscriberKey IS NULL
        AND d14.SubscriberKey IS NULL
        AND d14n.SubscriberKey IS NULL
        AND d15.SubscriberKey IS NULL
        AND d15n.SubscriberKey IS NULL
        AND LOWER(dg.Email) LIKE '%hotmail%'

------------------------------------------------------------------------------------

SELECT TOP 23782
    sub.SubscriberKey,
    sub.Email,
    sub.FirstName,
    sub.LastName,
    sub.SourceTier
FROM (
    SELECT 
        main.SubscriberKey,
        main.Email,
        main.FirstName,
        main.LastName,
        main.SourceTier,
        main.Priority,
        
        ROW_NUMBER() OVER (
            PARTITION BY CASE WHEN main.Email LIKE '%@hotmail.%' THEN 'Hotmail' ELSE 'Other' END 
            ORDER BY main.Priority ASC
        ) as DomainRank,
        
        CASE WHEN main.Email LIKE '%@hotmail.%' THEN 'Hotmail' ELSE 'Other' END as DomainType
    FROM (
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 1' AS SourceTier, 1 AS Priority FROM [Tier 1 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 2' AS SourceTier, 2 AS Priority FROM [Tier 2 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 3' AS SourceTier, 3 AS Priority FROM [Tier 3 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 4' AS SourceTier, 4 AS Priority FROM [Tier 4 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 5' AS SourceTier, 5 AS Priority FROM [Tier 5 - NonGmail V2]
    ) main
    WHERE NOT EXISTS (
        SELECT 1 
        FROM [Day15_NonGmail_TeaserEmail_1] ex 
        WHERE ex.SubscriberKey = main.SubscriberKey
    )

    AND EXISTS (
        SELECT 1 
        FROM _Subscribers sub_status
        WHERE sub_status.SubscriberKey = main.SubscriberKey
        AND sub_status.Status NOT IN('Bounced', 'Held', 'Unsubscribed', 'Complaint')
    )
) sub

WHERE (sub.DomainType = 'Hotmail' AND sub.DomainRank <= 14437)
   OR (sub.DomainType = 'Other' AND sub.DomainRank <= 9345)

ORDER BY 
    CASE WHEN sub.DomainType = 'Hotmail' THEN 0 ELSE 1 END ASC,
    sub.Priority ASC


------------------------------------------------------------------------------------

SELECT TOP 6333
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
        'Tier 1' AS SourceTier,
        1 AS Priority
    FROM [Tier 1 - Gmail V2]

    UNION ALL

    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 2' AS SourceTier,
        2 AS Priority
    FROM [Tier 2 - Gmail V2]

    UNION ALL

    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 3' AS SourceTier,
        3 AS Priority
    FROM [Tier 3 - Gmail V2]

    UNION ALL

    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 4' AS SourceTier,
        4 AS Priority
    FROM [Tier 4 - Gmail V2]

) sub
WHERE NOT EXISTS (
    SELECT 1 
    FROM [Day15_Gmail_TeaserEmail_1] ex 
    WHERE ex.SubscriberKey = sub.SubscriberKey
)
AND NOT EXISTS (
    SELECT 1 
    FROM [Day15_Tier1_Tier2_Tier3_Tier4_Gmail_Email3_V2] ex1 
    WHERE ex1.SubscriberKey = sub.SubscriberKey
)
ORDER BY sub.Priority ASC