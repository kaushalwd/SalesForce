SELECT 
    SubscriberKey,
    EmailAddress,
    Status
FROM (
    SELECT DISTINCT
        s.SubscriberKey,
        s.EmailAddress,
        ROW_NUMBER() OVER (PARTITION BY s.EmailAddress ORDER BY o.EventDate DESC) as RowNum
    FROM OpenArchive o
    INNER JOIN _Subscribers s
        ON o.SubscriberKey = s.SubscriberKey
    WHERE o.EventDate >= DATEADD(YEAR, -1, GETDATE())
        AND s.Status = 'Active'
) x
WHERE x.RowNum = 1

-----------------------

/* Last year Opened with given suppression logic for Leads */

SELECT 
    ls.Id as SubscriberKey,
    ls.Email as Email,
    ls.FirstName,
    ls.LastName,
    ls.LeadSource,
    ls.Status
FROM [Last Year Opened] ly
INNER JOIN Lead_Salesforce ls ON ls.Email = ly.EmailAddress
WHERE 
( 
    ls.LeadSource = 'digital_marketing_sfmc_db'
    Or ls.LeadSource = 'digital_marketing_paid'
    Or ls.LeadSource = 'Digital Marketing - Paid'
    Or ls.LeadSource = 'Social'
    Or ls.LeadSource = 'digital_marketing_organic'
    Or ls.LeadSource = 'Digital Marketing - Organic'
    Or ls.LeadSource = 'Mobile App'
    Or ls.LeadSource = 'digital_marketing_internal'
    Or ls.LeadSource = 'Digital Marketing - Internal')
    AND ls.Status != 'Duplicate'
    AND ls.Status != 'Not a Lead'
    

---------------------

/* Total of both DEs */

SELECT DISTINCT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [Leads Since Dec 2025]

UNION

SELECT DISTINCT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [Last Year Opened From Leads]

----------------------

/* Remove Duolicate Emails */

SELECT 
    SubscriberKey,
    Email,
    FirstName,
    LastName
FROM (
    SELECT 
        SubscriberKey,
        Email,
        FirstName,
        LastName,
        ROW_NUMBER() OVER (PARTITION BY Email ORDER BY SubscriberKey ASC) as row_num
    FROM [Total - Engagements]
) x
WHERE x.row_num = 1

-----------------------


/* Get the Unsubscribed, Bounced, Complaint from Total Engagements */

SELECT
    te.SubscriberKey,
    te.Email,
    CASE 
        WHEN u.SubscriberKey IS NOT NULL THEN 'Unsubscribed'
        WHEN b.SubscriberKey IS NOT NULL THEN 'Bounced'
        WHEN c.SubscriberKey IS NOT NULL THEN 'Complaint'
        ELSE 'Clear'
    END AS ArchiveStatus
FROM [Total - Engagements] te
LEFT JOIN [UnsubscribeArchive] u ON te.SubscriberKey = u.SubscriberKey
LEFT JOIN [BounceArchive] b ON te.SubscriberKey = b.SubscriberKey
LEFT JOIN [ComplaintArchive] c ON te.SubscriberKey = c.SubscriberKey
WHERE u.SubscriberKey IS NOT NULL 
   OR b.SubscriberKey IS NOT NULL 
   OR c.SubscriberKey IS NOT NULL


------------

/* Removal of Unsubscribed, Bounced, Complaint from Total Engagements */

SELECT
    te.SubscriberKey,
    te.Email,
    te.FirstName,
    te.LastName
FROM [Total - Engagements] te
LEFT JOIN [Removal] r ON te.SubscriberKey = r.SubscriberKey
WHERE r.SubscriberKey IS NULL

-------------------

/* Gmail Audience */

SELECT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [Total - Engagements]
WHERE Email LIKE '%@gmail.com'

----------------

/* NonGmail Audience */

SELECT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [Total - Engagements]
WHERE Email Not LIKE '%@gmail.com'

----------------