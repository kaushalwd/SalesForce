/* last year records = */

SELECT 
    SubscriberKey,
    EmailAddress,
    Status
FROM (
    SELECT DISTINCT
        s.SubscriberKey,
        s.EmailAddress,
        s.Status,
        ROW_NUMBER() OVER (PARTITION BY s.EmailAddress ORDER BY o.EventDate DESC) as RowNum
    FROM OpenArchive o
    INNER JOIN _Subscribers s
        ON o.SubscriberKey = s.SubscriberKey
    WHERE o.EventDate >= DATEADD(YEAR, -1, GETDATE())
        AND s.Status = 'Active'
) x
WHERE x.RowNum = 1

------------------------

/* last year records check in ComplainArchive = 0 */

SELECT 
    l.SubscriberKey,
    l.EmailAddress
FROM last_1year_records l
WHERE EXISTS (
    SELECT 1 
    FROM ComplaintArchive c 
    WHERE c.SubscriberKey = l.SubscriberKey
)

------------------------

/* last year records join with Lead_Salesforce = 15448 */

SELECT 
        l._ContactKey AS ContactKey,
        l.FirstName,
        l.LastName,
        l.Email
    FROM last_1year_records ly
    INNER JOIN  Lead_Salesforce l
        ON l._ContactKey = ly.SubscriberKey
        
------------------------

SELECT 
    MIN(EventDate) as First_Event_Date
FROM [OpenArchive]

Result -> Aug 9 2025 8:02AM

------------------------

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


------------------

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
FROM [Total Engagements] te
LEFT JOIN [UnsubscribeArchive] u ON te.SubscriberKey = u.SubscriberKey
LEFT JOIN [BounceArchive] b ON te.SubscriberKey = b.SubscriberKey
LEFT JOIN [ComplaintArchive] c ON te.SubscriberKey = c.SubscriberKey
WHERE u.SubscriberKey IS NOT NULL 
   OR b.SubscriberKey IS NOT NULL 
   OR c.SubscriberKey IS NOT NULL

-------------------

/* Gmail Audience */

SELECT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [Total Engagements]
WHERE Email LIKE '%@gmail.com'

----------------

/* NonGmail Audience */

SELECT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [Total Engagements]
WHERE Email Not LIKE '%@gmail.com'

----------------

/* Tier 1 - Leads who clicked in last 3 months  */

SELECT
    de.SubscriberKey,
    de.FirstName,
    de.LastName,
    de.Email,
    c.EventDate AS ClickDate
FROM [Total Engagements] de
INNER JOIN _Click c ON de.SubscriberKey = c.SubscriberKey
WHERE c.EventDate >= DATEADD(month, -3, GETDATE())

----------------

/* Tier 2 - Leads who opened in last 3 months and not in above Tiers  */

SELECT
    te.SubscriberKey,
    te.FirstName,
    te.LastName,
    te.Email
FROM [Total Engagements] te
INNER JOIN _Open o ON te.SubscriberKey = o.SubscriberKey
LEFT JOIN [Tier 1] t1 ON te.SubscriberKey = t1.SubscriberKey
WHERE o.EventDate >= DATEADD(month, -3, GETDATE())
  AND t1.SubscriberKey IS NULL

----------------

/* Tier 3 - Leads who opened in last 6 months and not in above Tiers  */

SELECT
    te.SubscriberKey,
    te.FirstName,
    te.LastName,
    te.Email
FROM [Total Engagements] te
INNER JOIN _Open o ON te.SubscriberKey = o.SubscriberKey
LEFT JOIN [Tier 1] t1 ON te.SubscriberKey = t1.SubscriberKey
LEFT JOIN [Tier 2] t2 ON te.SubscriberKey = t2.SubscriberKey
WHERE o.EventDate >= DATEADD(month, -6, GETDATE())
  AND t1.SubscriberKey IS NULL
  AND t2.SubscriberKey IS NULL

----------------

/* Tier 4 - New leads created after 1st December 2025 and not in above Tiers  */

SELECT
    l.SubscriberKey,
    l.FirstName,
    l.LastName,
    l.Email
FROM [leads_from_Dec_25] l
LEFT JOIN [Tier 1] t1 ON l.SubscriberKey = t1.SubscriberKey
LEFT JOIN [Tier 2] t2 ON l.SubscriberKey = t2.SubscriberKey
LEFT JOIN [Tier 3] t3 ON l.SubscriberKey = t3.SubscriberKey
WHERE t1.SubscriberKey IS NULL
  AND t2.SubscriberKey IS NULL
  AND t3.SubscriberKey IS NULL

----------------

/* Tier 5 - Leads who opened anytime in past 1 year and not in above Tiers  */


SELECT
    l.SubscriberKey,
    l.FirstName,
    l.LastName,
    l.Email
FROM [Total Engagements] l
INNER JOIN _Open o ON l.SubscriberKey = o.SubscriberKey
LEFT JOIN [Tier 1] t1 ON l.SubscriberKey = t1.SubscriberKey
LEFT JOIN [Tier 2] t2 ON l.SubscriberKey = t2.SubscriberKey
LEFT JOIN [Tier 3] t3 ON l.SubscriberKey = t3.SubscriberKey
LEFT JOIN [Tier 4] t4 ON l.SubscriberKey = t4.SubscriberKey
WHERE o.EventDate >= DATEADD(year, -1, GETDATE())
  AND t1.SubscriberKey IS NULL
  AND t2.SubscriberKey IS NULL
  AND t3.SubscriberKey IS NULL
  AND t4.SubscriberKey IS NULL