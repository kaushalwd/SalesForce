SELECT
    d.EmailAddress,
    d.SubscriberKey
FROM [Last One year Data - 12 May 2026] d
INNER JOIN (
    SELECT
        EmailAddress
    FROM [Last One year Data - 12 May 2026]
    WHERE EmailAddress IS NOT NULL
    GROUP BY EmailAddress
    HAVING COUNT(DISTINCT SubscriberKey) > 1
) x
ON d.EmailAddress = x.EmailAddress