
/* Combined of four queries */

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    s.Status
FROM (    
    SELECT Email, SubscriberKey FROM [Day18_NonGmail_Email_4_V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Day18_NonGmail_TeaserEmail_2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Day18_Gmail_Email4_V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Day18_Gmail_TeaserEmail_2]
) f
LEFT JOIN _Subscribers s
    ON f.Email = s.EmailAddress
WHERE s.Status != 'active'


--------------------------------------------------------------------------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    x.Reason
FROM (
    SELECT Email, SubscriberKey FROM [Day18_NonGmail_Email_4_V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Day18_NonGmail_TeaserEmail_2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Day18_Gmail_Email4_V2]
    UNION ALL
    SELECT Email, SubscriberKey FROM [Day18_Gmail_TeaserEmail_2]
) f
INNER JOIN (
    SELECT
        u.SubscriberKey,
        s.EmailAddress AS ArchiveEmail,
        'Unsubscribed' AS Reason
    FROM UnsubscribeArchive u
    LEFT JOIN _Subscribers s
        ON s.SubscriberKey = u.SubscriberKey

    UNION ALL

    SELECT
        b.SubscriberKey,
        s.EmailAddress AS ArchiveEmail,
        'Bounced' AS Reason
    FROM BounceArchive b
    LEFT JOIN _Subscribers s
        ON s.SubscriberKey = b.SubscriberKey

    UNION ALL

    SELECT
        c.SubscriberKey,
        s.EmailAddress AS ArchiveEmail,
        'Complaint' AS Reason
    FROM ComplaintArchive c
    LEFT JOIN _Subscribers s
        ON s.SubscriberKey = c.SubscriberKey
) x
    ON (
        x.SubscriberKey = f.SubscriberKey
        OR (x.ArchiveEmail IS NOT NULL AND x.ArchiveEmail = f.Email)
    )

---------------------------------------------------------------------------------

/* Combined of four queries */

SELECT
    main.Email,
    COUNT(main.Email) AS OccurrenceCount
FROM (
    SELECT Email FROM [Day18_NonGmail_Email_4_V2]
    UNION ALL
    SELECT Email FROM [Day18_NonGmail_TeaserEmail_2]
    UNION ALL
    SELECT Email FROM [Day18_Gmail_Email4_V2]
    UNION ALL
    SELECT Email FROM [Day18_Gmail_TeaserEmail_2]
) main
WHERE 
    main.Email IS NOT NULL
GROUP BY 
    main.Email
HAVING 
    COUNT(main.Email) > 1
---------------------------------------------------------------------------------
 
SELECT 
    current_day.Email,
    'Day18' AS OverlapSource
FROM 
    [Day18_Gmail_TeaserEmail_2] AS current_day
INNER JOIN 
    [Day18_Gmail_Email4_V2] AS past_day18
    ON current_day.Email = past_day18.Email          

UNION 

SELECT 
    current_day.Email,
    'Day17' AS OverlapSource
FROM 
    [Day18_Gmail_Email4_V2] AS current_day
INNER JOIN 
    [Day17_Gmail_Email4_V2] AS past_day17
    ON current_day.Email = past_day17.Email

------------------------------------------------------------------------------------------

SELECT 
    current_day.Email,
    'Day18' AS OverlapSource
FROM 
    [Day18_NonGmail_TeaserEmail_2] AS current_day
INNER JOIN 
    [Day18_NonGmail_Email_4_V2] AS past_day18
    ON current_day.Email = past_day18.Email          

UNION 

SELECT 
    current_day.Email,
    'Day17' AS OverlapSource
FROM 
    [Day18_NonGmail_Email_4_V2] AS current_day
INNER JOIN 
    [Day17_NonGmail_Email_4_V2] AS past_day17
    ON current_day.Email = past_day17.Email