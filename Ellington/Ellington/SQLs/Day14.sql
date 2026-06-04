SELECT
    final.SubscriberKey,
    final.Email,
    final.FirstName,
    final.LastName,
    final.SourceTier
FROM (

    SELECT TOP 12403
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

    WHERE 
        d12.SubscriberKey IS NULL
        AND d12n.SubscriberKey IS NULL
        AND d13.SubscriberKey IS NULL
        AND d13n.SubscriberKey IS NULL
        AND LOWER(dg.Email) LIKE '%hotmail%'

    UNION ALL

    
    SELECT TOP 809
        dg.SubscriberKey,
        dg.Email,
        dg.FirstName,
        dg.LastName,
        dg.SourceTier,
        2 AS priority_group
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

    WHERE 
        d12.SubscriberKey IS NULL
        AND d12n.SubscriberKey IS NULL
        AND d13.SubscriberKey IS NULL
        AND d13n.SubscriberKey IS NULL
        AND LOWER(dg.Email) NOT LIKE '%hotmail%'

) final

------------------------------------------------------------------------------------


SELECT TOP 13212
    x.SubscriberKey,
    x.Email,
    x.FirstName,
    x.LastName,
    x.SourceTier
FROM (
    SELECT 
        dg.SubscriberKey,
        dg.Email,
        dg.FirstName,
        dg.LastName,
        dg.SourceTier,
        ROW_NUMBER() OVER (
            PARTITION BY CASE WHEN dg.Email LIKE '%hotmail%' THEN 'Hotmail' ELSE 'Other' END 
            ORDER BY dg.SubscriberKey
        ) as domain_rank,
        CASE WHEN dg.Email LIKE '%hotmail%' THEN 1 ELSE 2 END as priority_group
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
    LEFT JOIN [Day12_Tier4_Gmail_Email2_V2] d12 ON dg.SubscriberKey = d12.SubscriberKey
    LEFT JOIN [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] d12n ON dg.SubscriberKey = d12n.SubscriberKey
    LEFT JOIN [Day13_Tier4_Tier5_Gmail_TeaserEmail_1] d13 ON dg.SubscriberKey = d13.SubscriberKey
    LEFT JOIN [Day13_Tier1_Tier2_Tier3_NonGmail_TeaserEmail_1] d13n ON dg.SubscriberKey = d13n.SubscriberKey
    
    WHERE 
        d12.SubscriberKey IS NULL
        AND d12n.SubscriberKey IS NULL
        AND d13.SubscriberKey IS NULL
        AND d13n.SubscriberKey IS NULL
) as x
WHERE (x.Email LIKE '%hotmail%' AND x.domain_rank <= 12750)
   OR (x.Email NOT LIKE '%hotmail%')
ORDER BY x.priority_group ASC, x.domain_rank ASC

------------------------------------------------------------------------------------------------------


SELECT TOP 3747 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
FROM (
    SELECT SubscriberKey, Email, FirstName, LastName FROM [Tier 1 - Gmail V2]
    UNION ALL
    SELECT SubscriberKey, Email, FirstName, LastName FROM [Tier 2 - Gmail V2]
    UNION ALL
    SELECT SubscriberKey, Email, FirstName, LastName FROM [Tier 4 - Gmail V2]
    UNION ALL
    SELECT SubscriberKey, Email, FirstName, LastName FROM [Tier 5 - Gmail V2]
) dg

LEFT JOIN [Day12_Tier4_Gmail_Email2_V2] d12 
    ON dg.SubscriberKey = d12.SubscriberKey

LEFT JOIN [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] d12n 
    ON dg.SubscriberKey = d12n.SubscriberKey

LEFT JOIN [Day13_Tier4_Tier5_Gmail_TeaserEmail_1] d13
ON dg.SubscriberKey = d13.SubscriberKey

LEFT JOIN [Day13_Tier1_Tier2_Tier3_NonGmail_TeaserEmail_1] d13n
ON dg.SubscriberKey = d13n.SubscriberKey

WHERE 
    d12.SubscriberKey IS NULL
    AND d12n.SubscriberKey IS NULL
    AND d13.SubscriberKey IS NULL
    AND d13n.SubscriberKey IS NULL