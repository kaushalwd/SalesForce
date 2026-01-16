SELECT
  cp.[First Name]
FROM [UnSubs_from_010425] AS us
INNER JOIN [Communication_Preference] AS cp
  ON cp.Member = us.SubscriberID
------------


SELECT
  us.SubscriberId, cp.[Member], cp.[Email Address], us.EventDate
FROM [UnSubs_from_010425] AS us
INNER JOIN [Communication_Preference] AS cp
  ON cp.[Email Address] = us.email

------------


SELECT
  us.SubscriberId,
  cp.[Member],
  cp.[Email Address],
  MAX(us.DateUnsubscribed) AS DateUnsubscribed
FROM [Unsubs_From_AllSubscribers] AS us
INNER JOIN [Communication_Preference] AS cp
  ON cp.[Email Address] = us.EmailAddress
GROUP BY
  us.SubscriberId,
  cp.[Member],
  cp.[Email Address]
----------


SELECT
    SubscriberKey,
    SubscriberId,
    EmailAddress,
    Status,
    DateUnsubscribed
FROM _Subscribers
WHERE Status = 'Unsubscribed'
  AND DateUnsubscribed >= '2025-04-01'
  AND DateUnsubscribed <= GETDATE()

--------------

SELECT
    cp.[First Name], 
    cp.[Last Name], 
    cp.[Member], 
    cp.[Email Address], 
    cp.[IsRegistered], 
    cp.[User Type], 
    cp.[User Status], 
    cp.[Member Effective Date], 
    cp.[Member Termination Effective Date], 
    cp.[Written Language Preference], 
    cp.[State], 
    cp.[Plan ID], 
    cp.[anoc email], 
    cp.[anoc email date], 
    cp.[anoc print], 
    cp.[anoc print date], 
    cp.[benefit-news print], 
    cp.[benefit-news print date], 
    cp.[benefit-news email], 
    cp.[benefit-news email date], 
    cp.[eob print], 
    cp.[eob print date], 
    cp.[eob email], 
    cp.[eob email date], 
    cp.[partd eob print], 
    cp.[partd eob print date], 
    cp.[partd eob email], 
    cp.[partd eob email date], 
    cp.[benefit-events print], 
    cp.[benefit-events print date], 
    cp.[benefit-events email], 
    cp.[benefit-events email date], 
    cp.[benefit-events none], 
    cp.[benefit-events none date], 
    cp.[general SMS], 
    cp.[general SMS date], 
    cp.[con SCAN SMS], 
    cp.[con SCAN SMS date], 
    cp.[one_on_one SMS], 
    cp.[one_on_one SMS date], 
    cp.[SCAN-club print], 
    cp.[SCAN-club print date], 
    cp.[SCAN-club email], 
    cp.[SCAN-club email date], 
    cp.[SCAN-club none], 
    cp.[SCAN-club none date], 
    cp.[health-reminder print], 
    cp.[health-reminder print date], 
    cp.[health-reminder email], 
    cp.[health-reminder email date], 
    cp.[health-reminder none], 
    cp.[health-reminder none date], 
    cp.[health-events print], 
    cp.[health-events print date], 
    cp.[health-events email], 
    cp.[health-events email date], 
    cp.[health-events none], 
    cp.[health-events none date], 
    cp.[Health-personalized print], 
    cp.[Health-personalized print date], 
    cp.[Health-personalized email], 
    cp.[Health-personalized email date], 
    cp.[Health-personalized none], 
    cp.[Health-personalized none date], 
    cp.[Portal notification email], 
    cp.[Portal notification email date], 
    cp.[Token], 
    cp.[Phone 1 number], 
    cp.[Phone 1 type], 
    cp.[Phone 2 number], 
    cp.[Phone 2 type], 
    cp.[Enrollment Date], 
    cp.[IsRegistered Date], 
    cp.[completedPA]
FROM
    _Subscribers s
Inner Join Communication_Preference as cp on cp.[Email Address] = s.SubscriberKey
And s.Status = 'unsubscribed'
And cp.[anoc print] = 'True'
/* And cp.[User Status] = 'active' */

---------------------


SELECT
    [First Name], 
    [Last Name], 
    [Member], 
    [Email Address], 
    [IsRegistered], 
    [User Type], 
    [User Status], 
    [Member Effective Date], 
    [Member Termination Effective Date], 
    [Written Language Preference], 
    [State], 
    [Plan ID], 
    [anoc email], 
    [anoc email date], 
    [anoc print], 
    [anoc print date],
    [benefit-news print], 
    [benefit-news print date], 
    [benefit-news email], 
    [benefit-news email date], 
    [eob print], 
    [eob print date], 
    [eob email], 
    [eob email date], 
    [partd eob print], 
    [partd eob print date], 
    [partd eob email], 
    [partd eob email date], 
    [benefit-events print], 
    [benefit-events print date], 
    [benefit-events email], 
    [benefit-events email date], 
    [benefit-events none], 
    [benefit-events none date], 
    [general SMS], 
    [general SMS date], 
    [con SCAN SMS], 
    [con SCAN SMS date], 
    [one_on_one SMS], 
    [one_on_one SMS date], 
    [SCAN-club print], 
    [SCAN-club print date], 
    [SCAN-club email], 
    [SCAN-club email date], 
    [SCAN-club none], 
    [SCAN-club none date], 
    [health-reminder print], 
    [health-reminder print date], 
    [health-reminder email], 
    [health-reminder email date], 
    [health-reminder none], 
    [health-reminder none date], 
    [health-events print], 
    [health-events print date], 
    [health-events email], 
    [health-events email date], 
    [health-events none], 
    [health-events none date], 
    [Health-personalized print], 
    [Health-personalized print date], 
    [Health-personalized email], 
    [Health-personalized email date], 
    [Health-personalized none], 
    [Health-personalized none date], 
    [Portal notification email], 
    [Portal notification email date], 
    [Token], 
    [Phone 1 number], 
    [Phone 1 type], 
    [Phone 2 number], 
    [Phone 2 type], 
    [Enrollment Date], 
    [IsRegistered Date], 
    [completedPA]
FROM 
(
SELECT
    cp.[First Name], 
    cp.[Last Name], 
    cp.[Member], 
    cp.[Email Address], 
    cp.[IsRegistered], 
    cp.[User Type], 
    cp.[User Status], 
    cp.[Member Effective Date], 
    cp.[Member Termination Effective Date], 
    cp.[Written Language Preference], 
    cp.[State], 
    cp.[Plan ID], 
    cp.[anoc email], 
    cp.[anoc email date], 
    cp.[anoc print], 
    CASE
        WHEN s.Status = 'Unsubscribed' AND s.DateUnsubscribed IS NOT NULL
            THEN s.DateUnsubscribed
        WHEN u.EventDate IS NOT NULL
            THEN u.EventDate
        ELSE cp.[anoc print date]
    END AS [anoc print date],
    cp.[benefit-news print], 
    cp.[benefit-news print date], 
    cp.[benefit-news email], 
    cp.[benefit-news email date], 
    cp.[eob print], 
    cp.[eob print date], 
    cp.[eob email], 
    cp.[eob email date], 
    cp.[partd eob print], 
    cp.[partd eob print date], 
    cp.[partd eob email], 
    cp.[partd eob email date], 
    cp.[benefit-events print], 
    cp.[benefit-events print date], 
    cp.[benefit-events email], 
    cp.[benefit-events email date], 
    cp.[benefit-events none], 
    cp.[benefit-events none date], 
    cp.[general SMS], 
    cp.[general SMS date], 
    cp.[con SCAN SMS], 
    cp.[con SCAN SMS date], 
    cp.[one_on_one SMS], 
    cp.[one_on_one SMS date], 
    cp.[SCAN-club print], 
    cp.[SCAN-club print date], 
    cp.[SCAN-club email], 
    cp.[SCAN-club email date], 
    cp.[SCAN-club none], 
    cp.[SCAN-club none date], 
    cp.[health-reminder print], 
    cp.[health-reminder print date], 
    cp.[health-reminder email], 
    cp.[health-reminder email date], 
    cp.[health-reminder none], 
    cp.[health-reminder none date], 
    cp.[health-events print], 
    cp.[health-events print date], 
    cp.[health-events email], 
    cp.[health-events email date], 
    cp.[health-events none], 
    cp.[health-events none date], 
    cp.[Health-personalized print], 
    cp.[Health-personalized print date], 
    cp.[Health-personalized email], 
    cp.[Health-personalized email date], 
    cp.[Health-personalized none], 
    cp.[Health-personalized none date], 
    cp.[Portal notification email], 
    cp.[Portal notification email date], 
    cp.[Token], 
    cp.[Phone 1 number], 
    cp.[Phone 1 type], 
    cp.[Phone 2 number], 
    cp.[Phone 2 type], 
    cp.[Enrollment Date], 
    cp.[IsRegistered Date], 
    cp.[completedPA],
    ROW_NUMBER() OVER(PARTITION BY cp.[Member] ORDER BY u.EventDate) AS rn
FROM
    Communication_Preference cp
LEFT JOIN _Unsubscribe u
    ON cp.[Email Address] = u.SubscriberKey
LEFT JOIN _Subscribers s
    ON cp.[Email Address] = s.SubscriberKey
WHERE
    cp.[anoc print] = 'True'
    AND (
        u.SubscriberKey IS NOT NULL
        OR s.Status = 'Unsubscribed' 
    )
)a
WHERE rn = 1