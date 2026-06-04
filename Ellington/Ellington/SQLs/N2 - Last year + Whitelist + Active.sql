SELECT 
    ls.Id AS SubscriberKey,
    ls.Email AS Email,
    ls.FirstName,
    ls.LastName,
    ls.LeadSource,
    ls.Status

FROM Lead_Salesforce ls

INNER JOIN (

    SELECT 
        EmailAddress
    FROM (
        SELECT DISTINCT
            s.EmailAddress,
            ROW_NUMBER() OVER (
                PARTITION BY s.EmailAddress 
                ORDER BY s.SubscriberKey
            ) AS RowNum

        FROM OpenArchive o

        INNER JOIN _Subscribers s
            ON o.SubscriberKey = s.SubscriberKey

        
        LEFT JOIN UnsubscribeArchive u
            ON s.SubscriberKey = u.SubscriberKey
            AND u.EventDate >= DATEADD(YEAR, -1, GETDATE())

        
        LEFT JOIN BounceArchive b
            ON s.SubscriberKey = b.SubscriberKey
            AND b.EventDate >= DATEADD(YEAR, -1, GETDATE())

        
        LEFT JOIN ComplaintArchive c
            ON s.SubscriberKey = c.SubscriberKey
            AND c.EventDate >= DATEADD(YEAR, -1, GETDATE())

        WHERE 
            o.EventDate >= DATEADD(YEAR, -1, GETDATE())
            AND s.Status = 'Active'
            AND u.SubscriberKey IS NULL
            AND b.SubscriberKey IS NULL
            AND c.SubscriberKey IS NULL

    ) x
    WHERE x.RowNum = 1

) ly
    ON ls.Email = ly.EmailAddress

WHERE 
(
    ls.LeadSource = 'digital_marketing_sfmc_db'
    OR ls.LeadSource = 'digital_marketing_paid'
    OR ls.LeadSource = 'Digital Marketing - Paid'
    OR ls.LeadSource = 'Social'
    OR ls.LeadSource = 'digital_marketing_organic'
    OR ls.LeadSource = 'Digital Marketing - Organic'
    OR ls.LeadSource = 'Mobile App'
    OR ls.LeadSource = 'digital_marketing_internal'
    OR ls.LeadSource = 'Digital Marketing - Internal'
)
AND ls.Status != 'Duplicate'
AND ls.Status != 'Not a Lead'