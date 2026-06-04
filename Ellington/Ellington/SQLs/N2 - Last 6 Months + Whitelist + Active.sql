SELECT 
    ls.Email,
    ls.FirstName,
    ls.LastName,
    s.Status,
    ls.Id AS SubscriberKey

FROM Lead_Salesforce ls


INNER JOIN _Subscribers s
    ON ls.Id = s.SubscriberKey


LEFT JOIN UnsubscribeArchive u
    ON ls.Id = u.SubscriberKey


LEFT JOIN BounceArchive b
    ON ls.Id = b.SubscriberKey


LEFT JOIN ComplaintArchive c
    ON ls.Id = c.SubscriberKey

WHERE 
    ls.CreatedDate >= '2025-12-01'

    
    AND s.Status = 'Active'

    
    AND (
        ls.LeadSource = 'digital_marketing_paid'
        OR ls.LeadSource = 'Digital Marketing - Paid'
        OR ls.LeadSource = 'Social'
        OR ls.LeadSource = 'digital_marketing_organic'
        OR ls.LeadSource = 'Digital Marketing - Organic'
        OR ls.LeadSource = 'Mobile App'
        OR ls.LeadSource = 'digital_marketing_internal'
        OR ls.LeadSource = 'Digital Marketing - Internal'
    )

    
    AND ls.Status NOT IN (
        'Duplicate',
        'Incomplete Data',
        'Not a Lead'
    )

    
    AND u.SubscriberKey IS NULL
    AND b.SubscriberKey IS NULL
    AND c.SubscriberKey IS NULL