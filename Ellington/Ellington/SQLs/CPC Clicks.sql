SELECT 
    c.SubscriberKey,
    c.JobID,
    c.EventDate,
    c.URL,
    l.Email 
FROM [ClickArchive] c
LEFT JOIN [Master Lead] l ON c.SubscriberKey = l.Id
WHERE c.URL LIKE '%2623%' 
And l.Email Not like '%horizontal%'
And l.Email Not like '%ellington%'
AND c.EventDate >= '2026-04-26'

