SELECT
    Email,
    COUNT(Email) AS OccurrenceCount
FROM 
    [Master_IPv2]
WHERE 
    Email IS NOT NULL
GROUP BY 
    Email
HAVING 
    COUNT(Email) > 1


------------

SELECT
    te.Email,
    te.SubscriberKey,
    lm.Id AS LeadSubscriberKey,
    lm.CreatedDate,
    s.Status AS SubscriberStatus,
    oa_map.OldSubscriberKey,
    oa_map.OldSubscriberID
FROM [Master_IPv2] te

INNER JOIN [Master Lead] lm
    ON LOWER(te.Email) = LOWER(lm.Email)

LEFT JOIN _Subscribers s
    ON LOWER(te.Email) = LOWER(s.EmailAddress)

INNER JOIN (
    SELECT
        LOWER(s2.EmailAddress) AS Email,
        oa.SubscriberKey AS OldSubscriberKey,
        oa.SubscriberID AS OldSubscriberID
    FROM [OpenArchive] oa
    INNER JOIN _Subscribers s2
        ON oa.SubscriberKey = s2.SubscriberKey
) oa_map
    ON oa_map.Email = LOWER(te.Email)

WHERE oa_map.OldSubscriberKey IS  NULL
AND lm.CreatedDate <= '2025-12-01'


-------------------


SELECT
    d.SubscriberKey,
    d.Email,
    s.Status AS SubscriberStatus
FROM [Master_IPv2] d
LEFT JOIN _Subscribers s
    ON d.Email = s.EmailAddress
    where s.Status != 'active'


---------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    s.Status
FROM [Day12_Tier2_NonGmail_Email1] f
LEFT JOIN _Subscribers s
    ON f.Email = s.EmailAddress
WHERE s.Status != 'active'

---------------

SELECT DISTINCT f.Email, f.SubscriberKey
FROM [Day1_Tier1_Tier2_NonGmail_Email2] f
INNER JOIN [_Subscribers] s
    ON f.Email = s.EmailAddress
WHERE s.Status = 'Unsubscribed'
