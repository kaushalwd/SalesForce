SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    s.Status
FROM [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] f
LEFT JOIN _Subscribers s
    ON f.Email = s.EmailAddress
WHERE s.Status != 'active'


--------------------------------------------------------------------------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Unsubscribed' as Reason
FROM [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] f
INNER JOIN UnsubscribeArchive u ON f.SubscriberKey = u.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Bounced' as Reason
FROM [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] f
INNER JOIN BounceArchive b ON f.SubscriberKey = b.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Complaint' as Reason
FROM [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] f
INNER JOIN ComplaintArchive c ON f.SubscriberKey = c.SubscriberKey

---------------------------------------------------------------------------------

SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Unsubscribed' as Reason
FROM [Day12_Tier4_Gmail_Email2_V2] f
INNER JOIN UnsubscribeArchive u ON f.SubscriberKey = u.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Bounced' as Reason
FROM [Day12_Tier4_Gmail_Email2_V2] f
INNER JOIN BounceArchive b ON f.SubscriberKey = b.SubscriberKey
UNION
SELECT DISTINCT
    f.Email,
    f.SubscriberKey,
    'Complaint' as Reason
FROM [Day12_Tier4_Gmail_Email2_V2] f
INNER JOIN ComplaintArchive c ON f.SubscriberKey = c.SubscriberKey

---------------------------------------------------------------------------------

Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2SELECT
    Email,
    COUNT(Email) AS OccurrenceCount
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2]
WHERE 
    Email IS NOT NULL
GROUP BY 
    Email
HAVING 
    COUNT(Email) > 1


---------------------------------------------------------------------------------


SELECT 
    current_day.Email,
    'Day1' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day1_Tier1_Tier2_Gmail_Email2_V2] AS past_day1
    ON current_day.Email = past_day1.Email

UNION

SELECT 
    current_day.Email,
    'Day2' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day2_Tier1_Tier2_Gmail_Email2_V2] AS past_day2
    ON current_day.Email = past_day2.Email

UNION

SELECT 
    current_day.Email,
    'Day3' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day3_Tier2_Gmail_Email2_V2] AS past_day3
    ON current_day.Email = past_day3.Email

UNION

SELECT 
    current_day.Email,
    'Day4' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day4_Tier2_Gmail_Email2_V2] AS past_day4
    ON current_day.Email = past_day4.Email

UNION

SELECT 
    current_day.Email,
    'Day5' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day5_Tier2_Gmail_Email2_V2] AS past_day5
    ON current_day.Email = past_day5.Email

UNION

SELECT 
    current_day.Email,
    'Day6' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day6_Tier2_Gmail_Email2_V2] AS past_day6
    ON current_day.Email = past_day6.Email   

UNION

SELECT 
    current_day.Email,
    'Day7' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day7_Tier2_Gmail_Email2_V2] AS past_day7
    ON current_day.Email = past_day7.Email   

UNION

SELECT 
    current_day.Email,
    'Day8' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day8_Tier2_Gmail_Email2_V2] AS past_day8
    ON current_day.Email = past_day8.Email       

UNION

SELECT 
    current_day.Email,
    'Day9' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day9_Tier2_Gmail_Email2_V2] AS past_day9
    ON current_day.Email = past_day9.Email       

UNION

SELECT 
    current_day.Email,
    'Day10' AS OverlapSource
FROM 
    [Day11_Tier3_Tier4_Gmail_Email2_V2] AS current_day
INNER JOIN 
    [Day10_Tier2_Tier3_Gmail_Email2_V2] AS past_day9
    ON current_day.Email = past_day9.Email      

---------------------------------------------

SELECT 

    current_day.Email,
    'Day1' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day1_Tier1_Tier2_NonGmail_Email2_V2] AS past_day1
    ON current_day.Email = past_day1.Email

UNION

SELECT 
    current_day.Email,
    'Day2' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day2_Tier1_Tier2_NonGmail_Email2_V2] AS past_day2
    ON current_day.Email = past_day2.Email

UNION

SELECT 
    current_day.Email,
    'Day3' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day3_Tier2_NonGmail_Email2_V2] AS past_day3
    ON current_day.Email = past_day3.Email

UNION

SELECT 
    current_day.Email,
    'Day4' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day4_Tier2_NonGmail_Email2_V2] AS past_day4
    ON current_day.Email = past_day4.Email

UNION

SELECT 
    current_day.Email,
    'Day5' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day5_Tier2_NonGmail_Email2_V2] AS past_day5
    ON current_day.Email = past_day5.Email

UNION

SELECT 
    current_day.Email,
    'Day6' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day6_Tier2_NonGmail_Email2_V2] AS past_day6
    ON current_day.Email = past_day6.Email   

UNION

SELECT 
    current_day.Email,
    'Day7' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day7_Tier2_NonGmail_Email2_V2] AS past_day7
    ON current_day.Email = past_day7.Email      

UNION

SELECT 
    current_day.Email,
    'Day8' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day8_Tier2_Tier3_NonGmail_Email2_V2] AS past_day8
    ON current_day.Email = past_day8.Email

UNION

SELECT 
    current_day.Email,
    'Day9' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day9_Tier3_NonGmail_Email2_V2] AS past_day9
    ON current_day.Email = past_day9.Email     

UNION

SELECT 
    current_day.Email,
    'Day10' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day10_Tier3_NonGmail_Email2_V2] AS past_day10
    ON current_day.Email = past_day10.Email

UNION

SELECT 
    current_day.Email,
    'Day11' AS OverlapSource
FROM 
    [Day12_Tier3_Tier4_Tier5_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [Day11_Tier3_NonGmail_Email2_V2] AS past_day11
    ON current_day.Email = past_day11.Email         
---------------------------------------------

SELECT 
    current_day.SubscriberKey,
    archive.emailname_,
    archive.SendDate
FROM 
    [Day11_Tier3_NonGmail_Email2_V2] AS current_day
INNER JOIN 
    [SendLogArchive] AS archive
    ON current_day.SubscriberKey = archive.SubscriberKey
WHERE 
    archive.SendDate >= DATEADD(day, -5, GETDATE())
    AND archive.emailname_ LIKE '%Email 2%'


-----------------------

