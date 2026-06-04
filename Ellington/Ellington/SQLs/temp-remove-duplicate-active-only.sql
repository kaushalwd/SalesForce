SELECT
    SubscriberKey,
    Email,
    FirstName,
    LastName
FROM (
    
    SELECT
        m.SubscriberKey,
        m.Email,
        m.FirstName,
        m.LastName,

        ROW_NUMBER() OVER (
            PARTITION BY m.Email
            ORDER BY m.SubscriberKey
        ) AS RowNum

    FROM [Master_IPv2_temp] m

    
    INNER JOIN _Subscribers s
        ON m.SubscriberKey = s.SubscriberKey

    WHERE s.Status != 'Active'

) x

WHERE x.RowNum = 1