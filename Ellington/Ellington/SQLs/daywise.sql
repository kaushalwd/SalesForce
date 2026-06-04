SELECT TOP 240
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
) sub
WHERE NOT EXISTS (
    SELECT 1 
    FROM [Day1_Tier1_Tier2_Gmail_Email2_V2] ex1 
    WHERE ex1.SubscriberKey = sub.SubscriberKey
)
AND NOT EXISTS (
    SELECT 1 
    FROM [Day1_Tier1_Tier2_NonGmail_Email2_V2] ex2 
    WHERE ex2.SubscriberKey = sub.SubscriberKey
)
ORDER BY sub.Priority ASC

------------------------------


select top 288 
    d3.SubscriberKey,
    d3.Email,
    d3.[FirstName],
    d3.[LastName]
    
    from [Tier 2 Gmail] d3
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d1
    ON d3.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON d3.SubscriberKey = d1n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d2
    ON d3.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON d3.SubscriberKey = d2n.SubscriberKey
    
WHERE 
    d1.SubscriberKey IS NULL
    AND d2.SubscriberKey IS NULL
    AND d1n.SubscriberKey IS NULL
    AND d2n.SubscriberKey IS NULL

------------------------------------

select top 557 
    d3.SubscriberKey,
    d3.Email,
    d3.[FirstName],
    d3.[LastName]
    
    from [Tier 2 NonGmail] d3
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d1
    ON d3.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON d3.SubscriberKey = d1n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d2
    ON d3.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON d3.SubscriberKey = d2n.SubscriberKey
    
WHERE 
    d1.SubscriberKey IS NULL
    AND d2.SubscriberKey IS NULL
    AND d1n.SubscriberKey IS NULL
    AND d2n.SubscriberKey IS NULL
------------------------------------


SELECT TOP 200
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
) sub
ORDER BY sub.Priority ASC



------------

SELECT TOP 200
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
) sub
WHERE NOT EXISTS (
    SELECT 1 
    FROM [Day12_Tier3_Gmail_Email1] ex1 
    WHERE ex1.SubscriberKey = sub.SubscriberKey
)
AND NOT EXISTS (
    SELECT 1 
    FROM [Day13_Tier3_Gmail_Email1] ex2 
    WHERE ex2.SubscriberKey = sub.SubscriberKey
)
ORDER BY sub.Priority ASC

--------




/* Removal pf last send */

/* total non gmail =  22 */

    SELECT
    a.Email,
    a.SubscriberKey
FROM [Day13_Tier2_NonGmail_Email1] a
INNER JOIN [Day1_Tier1_NonGmail_Email2] b ON a.Email = b.Email


-----------




select top 1013 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
    
    from [Tier 2 - NonGmail V2] dg
    
    LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4
    ON dg.SubscriberKey = d4.SubscriberKey

    LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n
    ON dg.SubscriberKey = d4n.SubscriberKey

    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey
    
WHERE 
    d1.SubscriberKey IS NULL
    AND d1n.SubscriberKey IS NULL
    AND d2.SubscriberKey IS NULL
    AND d2n.SubscriberKey IS NULL
    AND d3.SubscriberKey IS NULL
    AND d3n.SubscriberKey IS NULL
    AND d4.SubscriberKey IS NULL
    AND d4n.SubscriberKey IS NULL


------------

select top 1359 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
    
    from [Tier 2 - NonGmail V2] dg
    
    LEFT JOIN [Day5_Tier2_Gmail_Email2_V2] d5
    ON dg.SubscriberKey = d5.SubscriberKey

    LEFT JOIN [Day5_Tier2_NonGmail_Email2_V2] d5n
    ON dg.SubscriberKey = d5n.SubscriberKey

    LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4
    ON dg.SubscriberKey = d4.SubscriberKey

    LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n
    ON dg.SubscriberKey = d4n.SubscriberKey

    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey
    
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


----------------

select top 597 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
    
    from [Tier 2 - Gmail V2] dg
    
    LEFT JOIN [Day6_Tier2_Gmail_Email2_V2] d6
    ON dg.SubscriberKey = d6.SubscriberKey

    LEFT JOIN [Day6_Tier2_NonGmail_Email2_V2] d6n
    ON dg.SubscriberKey = d6n.SubscriberKey

    LEFT JOIN [Day5_Tier2_Gmail_Email2_V2] d5
    ON dg.SubscriberKey = d5.SubscriberKey

    LEFT JOIN [Day5_Tier2_NonGmail_Email2_V2] d5n
    ON dg.SubscriberKey = d5n.SubscriberKey

    LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4
    ON dg.SubscriberKey = d4.SubscriberKey

    LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n
    ON dg.SubscriberKey = d4n.SubscriberKey

    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey
    
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

----------------

select top 6014 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
    
    from [Tier 3 - NonGmail V2] dg
    
    LEFT JOIN [Day10_Tier2_Tier3_Gmail_Email2_V2] d10
    ON dg.SubscriberKey = d10.SubscriberKey

    LEFT JOIN [Day10_Tier3_NonGmail_Email2_V2] d10n
    ON dg.SubscriberKey = d10n.SubscriberKey
    
    LEFT JOIN [Day9_Tier2_Gmail_Email2_V2] d9
    ON dg.SubscriberKey = d9.SubscriberKey

    LEFT JOIN [Day9_Tier3_NonGmail_Email2_V2] d9n
    ON dg.SubscriberKey = d9n.SubscriberKey
    
    LEFT JOIN [Day8_Tier2_Gmail_Email2_V2] d8
    ON dg.SubscriberKey = d8.SubscriberKey

    LEFT JOIN [Day8_Tier2_Tier3_NonGmail_Email2_V2] d8n
    ON dg.SubscriberKey = d8n.SubscriberKey
    
    LEFT JOIN [Day7_Tier2_Gmail_Email2_V2] d7
    ON dg.SubscriberKey = d7.SubscriberKey

    LEFT JOIN [Day7_Tier2_NonGmail_Email2_V2] d7n
    ON dg.SubscriberKey = d7n.SubscriberKey

    LEFT JOIN [Day6_Tier2_Gmail_Email2_V2] d6
    ON dg.SubscriberKey = d6.SubscriberKey

    LEFT JOIN [Day6_Tier2_NonGmail_Email2_V2] d6n
    ON dg.SubscriberKey = d6n.SubscriberKey

    LEFT JOIN [Day5_Tier2_Gmail_Email2_V2] d5
    ON dg.SubscriberKey = d5.SubscriberKey

    LEFT JOIN [Day5_Tier2_NonGmail_Email2_V2] d5n
    ON dg.SubscriberKey = d5n.SubscriberKey

    LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4
    ON dg.SubscriberKey = d4.SubscriberKey

    LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n
    ON dg.SubscriberKey = d4n.SubscriberKey

    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey
    
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

 ----------------

SELECT TOP 1706
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName

FROM (

    SELECT SubscriberKey, Email, FirstName, LastName
    FROM [Tier 3 - Gmail V2]

    UNION ALL

    SELECT SubscriberKey, Email, FirstName, LastName
    FROM [Tier 4 - Gmail V2]

) dg

LEFT JOIN [Day10_Tier2_Tier3_Gmail_Email2_V2] d10
    ON dg.SubscriberKey = d10.SubscriberKey

LEFT JOIN [Day10_Tier3_NonGmail_Email2_V2] d10n
    ON dg.SubscriberKey = d10n.SubscriberKey

LEFT JOIN [Day9_Tier2_Gmail_Email2_V2] d9
    ON dg.SubscriberKey = d9.SubscriberKey

LEFT JOIN [Day9_Tier3_NonGmail_Email2_V2] d9n
    ON dg.SubscriberKey = d9n.SubscriberKey

LEFT JOIN [Day8_Tier2_Gmail_Email2_V2] d8
    ON dg.SubscriberKey = d8.SubscriberKey

LEFT JOIN [Day8_Tier2_Tier3_NonGmail_Email2_V2] d8n
    ON dg.SubscriberKey = d8n.SubscriberKey

LEFT JOIN [Day7_Tier2_Gmail_Email2_V2] d7
    ON dg.SubscriberKey = d7.SubscriberKey

LEFT JOIN [Day7_Tier2_NonGmail_Email2_V2] d7n
    ON dg.SubscriberKey = d7n.SubscriberKey

LEFT JOIN [Day6_Tier2_Gmail_Email2_V2] d6
    ON dg.SubscriberKey = d6.SubscriberKey

LEFT JOIN [Day6_Tier2_NonGmail_Email2_V2] d6n
    ON dg.SubscriberKey = d6n.SubscriberKey

LEFT JOIN [Day5_Tier2_Gmail_Email2_V2] d5
    ON dg.SubscriberKey = d5.SubscriberKey

LEFT JOIN [Day5_Tier2_NonGmail_Email2_V2] d5n
    ON dg.SubscriberKey = d5n.SubscriberKey

LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4
    ON dg.SubscriberKey = d4.SubscriberKey

LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n
    ON dg.SubscriberKey = d4n.SubscriberKey

LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey

LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey

LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey

LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey

LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey

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


 ---------

 SELECT TOP 7818
    x.SubscriberKey,
    x.Email,
    x.FirstName,
    x.LastName
FROM (
    SELECT 
        dg.SubscriberKey,
        dg.Email,
        dg.FirstName,
        dg.LastName,
        ROW_NUMBER() OVER (
            PARTITION BY CASE WHEN dg.Email LIKE '%hotmail.com' THEN 'Hotmail' ELSE 'Other' END 
            ORDER BY dg.SubscriberKey
        ) as domain_rank,
        CASE WHEN dg.Email LIKE '%hotmail.com' THEN 1 ELSE 2 END as priority_group
    FROM [Tier 3 - NonGmail V2] dg
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
WHERE (x.Email LIKE '%hotmail.com' AND x.domain_rank <= 3000)
   OR (x.Email NOT LIKE '%hotmail.com')
ORDER BY x.priority_group ASC, x.domain_rank ASC   

-----------------------------------

select top 2217 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
    
    from [Tier 4 - Gmail V2] dg
    
    LEFT JOIN [Day11_Tier3_Tier4_Gmail_Email2_V2] d11
    ON dg.SubscriberKey = d11.SubscriberKey

    LEFT JOIN [Day11_Tier3_NonGmail_Email2_V2] d11n
    ON dg.SubscriberKey = d11n.SubscriberKey
    
    LEFT JOIN [Day10_Tier2_Tier3_Gmail_Email2_V2] d10
    ON dg.SubscriberKey = d10.SubscriberKey

    LEFT JOIN [Day10_Tier3_NonGmail_Email2_V2] d10n
    ON dg.SubscriberKey = d10n.SubscriberKey
 
    LEFT JOIN [Day9_Tier2_Gmail_Email2_V2] d9
    ON dg.SubscriberKey = d9.SubscriberKey

    LEFT JOIN [Day9_Tier3_NonGmail_Email2_V2] d9n
    ON dg.SubscriberKey = d9n.SubscriberKey
    
    LEFT JOIN [Day8_Tier2_Gmail_Email2_V2] d8
    ON dg.SubscriberKey = d8.SubscriberKey

    LEFT JOIN [Day8_Tier2_Tier3_NonGmail_Email2_V2] d8n
    ON dg.SubscriberKey = d8n.SubscriberKey
    
    LEFT JOIN [Day7_Tier2_Gmail_Email2_V2] d7
    ON dg.SubscriberKey = d7.SubscriberKey

    LEFT JOIN [Day7_Tier2_NonGmail_Email2_V2] d7n
    ON dg.SubscriberKey = d7n.SubscriberKey

    LEFT JOIN [Day6_Tier2_Gmail_Email2_V2] d6
    ON dg.SubscriberKey = d6.SubscriberKey

    LEFT JOIN [Day6_Tier2_NonGmail_Email2_V2] d6n
    ON dg.SubscriberKey = d6n.SubscriberKey

    LEFT JOIN [Day5_Tier2_Gmail_Email2_V2] d5
    ON dg.SubscriberKey = d5.SubscriberKey

    LEFT JOIN [Day5_Tier2_NonGmail_Email2_V2] d5n
    ON dg.SubscriberKey = d5n.SubscriberKey

    LEFT JOIN [Day4_Tier2_Gmail_Email2_V2] d4
    ON dg.SubscriberKey = d4.SubscriberKey

    LEFT JOIN [Day4_Tier2_NonGmail_Email2_V2] d4n
    ON dg.SubscriberKey = d4n.SubscriberKey

    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey
    
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

-------------------------

SELECT TOP 10163
    x.SubscriberKey,
    x.Email,
    x.FirstName,
    x.LastName
FROM (
    SELECT 
        dg.SubscriberKey,
        dg.Email,
        dg.FirstName,
        dg.LastName,
        ROW_NUMBER() OVER (
            PARTITION BY CASE WHEN dg.Email LIKE '%hotmail.com' THEN 'Hotmail' ELSE 'Other' END 
            ORDER BY dg.SubscriberKey
        ) as domain_rank,
        CASE WHEN dg.Email LIKE '%hotmail.com' THEN 1 ELSE 2 END as priority_group
    FROM [Tier 3 - NonGmail V2] dg
    LEFT JOIN [Day12_Tier4_Gmail_Email2_V2] d12 ON dg.SubscriberKey = d12.SubscriberKey
    LEFT JOIN [Day12_Tier3_NonGmail_Email2_V2] d12n ON dg.SubscriberKey = d12n.SubscriberKey
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
        AND d12.SubscriberKey IS NULL
        AND d12n.SubscriberKey IS NULL
) as x
WHERE (x.Email LIKE '%hotmail.com' AND x.domain_rank <= 4500)
   OR (x.Email NOT LIKE '%hotmail.com')
ORDER BY x.priority_group ASC, x.domain_rank ASC