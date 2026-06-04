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
        ROW_NUMBER() OVER (
            PARTITION BY Email
            ORDER BY SubscriberKey
        ) AS RowNum

    FROM [Master_IPv2_temp]

) x

WHERE x.RowNum = 1