SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    s.Status
FROM [Day14_NonGmail_TeaserEmail_1] f
LEFT JOIN _Subscribers s
    ON f.Email = s.EmailAddress
WHERE s.Status != 'active'


SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    s.Status
FROM [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] f
LEFT JOIN _Subscribers s
    ON f.Email = s.EmailAddress
WHERE s.Status != 'active'


--------------------------------------------------------------------------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    x.Reason
FROM [Day14_NonGmail_TeaserEmail_1] f
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

----------------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    x.Reason
FROM [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] f
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


--------------------------------------------------------------------------------    

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Unsubscribed' as Reason
FROM [Day14_NonGmail_TeaserEmail_1] f
INNER JOIN UnsubscribeArchive u ON f.SubscriberKey = u.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Bounced' as Reason
FROM [Day14_NonGmail_TeaserEmail_1] f
INNER JOIN BounceArchive b ON f.SubscriberKey = b.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Complaint' as Reason
FROM [Day14_NonGmail_TeaserEmail_1] f
INNER JOIN ComplaintArchive c ON f.SubscriberKey = c.SubscriberKey

---------------------------------------------------------------------------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Unsubscribed' as Reason
FROM [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] f
INNER JOIN UnsubscribeArchive u ON f.SubscriberKey = u.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Bounced' as Reason
FROM [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] f
INNER JOIN BounceArchive b ON f.SubscriberKey = b.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Complaint' as Reason
FROM [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] f
INNER JOIN ComplaintArchive c ON f.SubscriberKey = c.SubscriberKey

---------------------------------------------------------------------------------

SELECT
    Email,
    COUNT(Email) AS OccurrenceCount
FROM 
    [Day14_NonGmail_TeaserEmail_1]
WHERE 
    Email IS NOT NULL
GROUP BY 
    Email
HAVING 
    COUNT(Email) > 1



SELECT
    Email,
    COUNT(Email) AS OccurrenceCount
FROM 
    [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1]
WHERE 
    Email IS NOT NULL
GROUP BY 
    Email
HAVING 
    COUNT(Email) > 1


---------------------------------------------------------------------------------


SELECT 
    current_day.Email,
    'Day12' AS OverlapSource
FROM 
    [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] AS current_day
INNER JOIN 
    [Day12_Tier4_Gmail_Email2_V2] AS past_day12
    ON current_day.Email = past_day12.Email          

UNION 

SELECT 
    current_day.Email,
    'Day13' AS OverlapSource
FROM 
    [Day14_Tier1_Tier2_Tier4_Tier5_Gmail_TeaserEmail_1] AS current_day
INNER JOIN 
    [Day13_Tier4_Tier5_Gmail_TeaserEmail_1] AS past_day13
    ON current_day.Email = past_day13.Email    
    
------------------------------------------------------------------------------------------

SELECT 
    current_day.Email,
    'Day12' AS OverlapSource
FROM 
    [Day14_NonGmail_TeaserEmail_1] AS current_day
INNER JOIN 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS past_day12
    ON current_day.Email = past_day12.Email          

UNION

SELECT 
    current_day.Email,
    'Day13' AS OverlapSource
FROM 
    [Day14_NonGmail_TeaserEmail_1] AS current_day
INNER JOIN 
    [Day13_Tier1_Tier2_Tier3_NonGmail_TeaserEmail_1] AS past_day13
    ON current_day.Email = past_day13.Email  

---------------------------------------------

SELECT 
    current_day.SubscriberKey,
    archive.emailname_,
    archive.SendDate
FROM 
    [Day11_Tier3_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [SendLogArchive] AS archive
    ON current_day.SubscriberKey = archive.SubscriberKey
WHERE 
    archive.SendDate >= DATEADD(day, -5, GETDATE())
    AND archive.emailname_ LIKE '%Email 2%'


-----------------------



SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    x.Reason
FROM [Day14_NonGmail_TeaserEmail_1] f
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