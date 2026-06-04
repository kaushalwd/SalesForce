SELECT TOP 34989
    main.SubscriberKey,
    main.Email,
    main.FirstName,
    main.LastName,
    main.SourceTier
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
    FROM [Day16_NonGmail_Email_3_V2] ex 
    WHERE ex.SubscriberKey = main.SubscriberKey
)
AND EXISTS (
    SELECT 1 
    FROM _Subscribers sub_status
    WHERE sub_status.SubscriberKey = main.SubscriberKey
    AND sub_status.Status NOT IN ('Bounced', 'Held', 'Unsubscribed', 'Complaint')
)
ORDER BY main.Priority ASC

----------------------------------------------------------------------------------------

SELECT TOP 9790
    main.SubscriberKey,
    main.Email,
    main.FirstName,
    main.LastName,
    main.SourceTier
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
    FROM [Day17_NonGmail_Email_3_V2] ex 
    WHERE ex.SubscriberKey = main.SubscriberKey
)
AND EXISTS (
    SELECT 1 
    FROM _Subscribers sub_status
    WHERE sub_status.SubscriberKey = main.SubscriberKey
    AND sub_status.Status NOT IN ('Bounced', 'Held', 'Unsubscribed', 'Complaint')
)
ORDER BY main.Priority ASC

------------------------------------------------------------------------------------

SELECT TOP 8233
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

    UNION ALL

    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 5' AS SourceTier,
        5 AS Priority
    FROM [Tier 5 - Gmail V2]

) sub
WHERE NOT EXISTS (
    SELECT 1 
    FROM [Day16_Tier1_Tier2_Tier3_Tier4_Gmail_Email3_V2] ex 
    WHERE ex.SubscriberKey = sub.SubscriberKey
)
AND EXISTS (
    SELECT 1 
    FROM _Subscribers sub_status
    WHERE sub_status.SubscriberKey = sub.SubscriberKey
    AND sub_status.Status NOT IN ('Bounced', 'Held', 'Unsubscribed', 'Complaint')
)
ORDER BY sub.Priority ASC


------------------------------------------------------------------------------------

SELECT TOP 1948
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

    UNION ALL

    SELECT 
        SubscriberKey, 
        Email, 
        FirstName, 
        LastName, 
        'Tier 5' AS SourceTier,
        5 AS Priority
    FROM [Tier 5 - Gmail V2]

) sub
WHERE NOT EXISTS (
    SELECT 1 
    FROM [Day17_Gmail_Email3_V2] ex 
    WHERE ex.SubscriberKey = sub.SubscriberKey
)
AND EXISTS (
    SELECT 1 
    FROM _Subscribers sub_status
    WHERE sub_status.SubscriberKey = sub.SubscriberKey
    AND sub_status.Status NOT IN ('Bounced', 'Held', 'Unsubscribed', 'Complaint')
)
ORDER BY sub.Priority ASC