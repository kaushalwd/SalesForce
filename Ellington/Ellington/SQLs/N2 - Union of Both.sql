SELECT DISTINCT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [N2 - OpenLast1year]

UNION

SELECT DISTINCT
    SubscriberKey,
    FirstName,
    LastName,
    Email
FROM [N2 - Created_1Dec]