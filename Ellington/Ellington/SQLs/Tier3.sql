SELECT
    SubscriberKey,
    Email,
    FirstName,
    LastName,
    LastEngagementDate
FROM (
    SELECT
        m.SubscriberKey,
        m.Email,
        m.FirstName,
        m.LastName,
        o.EventDate AS LastEngagementDate,
        ROW_NUMBER() OVER (PARTITION BY m.Email ORDER BY o.EventDate DESC) as row_num
    FROM [Master_IPv2_Gmail] m
    INNER JOIN OpenArchive o ON m.SubscriberKey = o.SubscriberKey
    LEFT JOIN [Tier 1 - Gmail V2] ex ON m.Email = ex.Email
    LEFT JOIN [Tier 2 - Gmail V2] ex1 ON m.Email = ex1.Email
    WHERE o.EventDate >= DATEADD(month, -6, GETDATE())
      AND ex.Email IS NULL
      AND ex1.Email IS NULL
) as x
WHERE x.row_num = 1

-------------------

/***** 33197 *****/ 

SELECT 
    SubscriberKey,
    Email,
    FirstName,
    LastName,
    LastEngagementDate
FROM (
    SELECT
        m.SubscriberKey,
        m.Email,
        m.FirstName,
        m.LastName,
        o.EventDate AS LastEngagementDate,
        ROW_NUMBER() OVER (PARTITION BY m.Email ORDER BY o.EventDate DESC) as row_num
    FROM [Master_IPv2_NonGmail] m
    INNER JOIN _Subscribers s ON m.Email = s.EmailAddress
    INNER JOIN OpenArchive o ON s.SubscriberKey = o.SubscriberKey
    LEFT JOIN [Tier 1 - NonGmail V2] ex ON m.Email = ex.Email
    LEFT JOIN [Tier 2 - NonGmail V2] ex1 ON m.Email = ex1.Email
    WHERE o.EventDate >= DATEADD(month, -6, GETDATE())
    AND ex.Email IS NULL
    AND ex1.Email IS NULL
) as x
WHERE x.row_num = 1