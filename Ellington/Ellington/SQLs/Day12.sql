SELECT TOP 7818
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
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 3' AS SourceTier FROM [Tier 3 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 4' AS SourceTier FROM [Tier 4 - NonGmail V2]
        UNION ALL
        SELECT SubscriberKey, Email, FirstName, LastName, 'Tier 5' AS SourceTier FROM [Tier 5 - NonGmail V2]
    ) dg
    LEFT JOIN [Day11_Tier3_Tier4_Gmail_Email2_V2] d11 ON dg.SubscriberKey = d11.SubscriberKey
    LEFT JOIN [Day11_Tier3_NonGmail_Email2_V2] d11n ON dg.SubscriberKey = d11n.SubscriberKey
    LEFT JOIN [Day10_Tier2_Tier3_Gmail_Email2_V2] d10 ON dg.SubscriberKey = d10.SubscriberKey
    LEFT JOIN [Day10_Tier3_NonGmail_Email2_V2] d10n ON dg.SubscriberKey = d10n.SubscriberKey
    LEFT JOIN [Day9_Tier2_Gmail_Email2_V2] d9 ON dg.SubscriberKey = d9.SubscriberKey
    LEFT JOIN [Day9_Tier3_NonGmail_Email2_V2] d9n ON dg.SubscriberKey = d9n.SubscriberKey
    LEFT JOIN [Day8_Tier2_Gmail_Email2_V2] d8 ON dg.SubscriberKey = d8.SubscriberKey
    LEFT JOIN [Day8_Tier2_Tier3_NonGmail_Email2_V2] d8n ON dg.SubscriberKey = d8n.SubscriberKey
    LEFT JOIN [Day7_Tier2_Gmail_Email2_V2] d7 ON dg.SubscriberKey = d7.SubscriberKey
    LEFT JOIN [Day7_Tier2_NonGmail_Email2_V2] d7n ON dg.SubscriberKey = d7n.SubscriberKey
    LEFT JOIN [Day6_Tier2_Gmail_Email2_V2] d6 ON dg.SubscriberKey = d6.SubscriberKey
    LEFT JOIN [Day6_Tier2_NonGmail_Email2_V2] d6n ON dg.SubscriberKey = d6n.SubscriberKey
    LEFT JOIN [Day5_Tier2_Gmail_Email2_V2] d5 ON dg.SubscriberKey = d5.SubscriberKey
    LEFT JOIN [Day5_Tier2_NonGmail_Email2_V2] d5n ON dg.SubscriberKey = d5n.SubscriberKey
    LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4 ON dg.SubscriberKey = d4.SubscriberKey
    LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n ON dg.SubscriberKey = d4n.SubscriberKey
    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3 ON dg.SubscriberKey = d3.SubscriberKey
    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n ON dg.SubscriberKey = d3n.SubscriberKey
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2 ON dg.SubscriberKey = d2.SubscriberKey
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n ON dg.SubscriberKey = d2n.SubscriberKey
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1 ON dg.SubscriberKey = d1.SubscriberKey
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n ON dg.SubscriberKey = d1n.SubscriberKey
    WHERE 
        d1.SubscriberKey IS NULL
        AND d1n.SubscriberKey IS NULL
        AND d2.SubscriberKey IS NULL
        AND d2n.SubscriberKey IS NULL
        AND d3.SubscriberKey IS NULL
        AND d3n.SubscriberKey IS NULL
        AND d4.SubscriberKey IS NULL
        AND d4n.SubscriberKey IS NULL
        AND d5.SubscriberKey IS NULL
        AND d5n.SubscriberKey IS NULL
        AND d6.SubscriberKey IS NULL
        AND d6n.SubscriberKey IS NULL
        AND d7.SubscriberKey IS NULL
        AND d7n.SubscriberKey IS NULL
        AND d8.SubscriberKey IS NULL
        AND d8n.SubscriberKey IS NULL
        AND d9.SubscriberKey IS NULL
        AND d9n.SubscriberKey IS NULL
        AND d10.SubscriberKey IS NULL
        AND d10n.SubscriberKey IS NULL
        AND d11.SubscriberKey IS NULL
        AND d11n.SubscriberKey IS NULL
) as x
WHERE (x.Email LIKE '%hotmail%' AND x.domain_rank <= 3000)
   OR (x.Email NOT LIKE '%hotmail%')
ORDER BY x.priority_group ASC, x.domain_rank ASC