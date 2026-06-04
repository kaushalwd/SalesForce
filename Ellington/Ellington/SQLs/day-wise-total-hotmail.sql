SELECT 
    Source_Day,
    COUNT(1) AS Hotmail_Count
FROM (
    SELECT 'Day 1' AS Source_Day, Email FROM [Day1_Tier1_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 2' AS Source_Day, Email FROM [Day2_Tier1_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 3' AS Source_Day, Email FROM [Day3_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 4' AS Source_Day, Email FROM [Day4_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 5' AS Source_Day, Email FROM [Day5_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 6' AS Source_Day, Email FROM [Day6_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 7' AS Source_Day, Email FROM [Day7_Tier2_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 8' AS Source_Day, Email FROM [Day8_Tier2_Tier3_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 9' AS Source_Day, Email FROM [Day9_Tier3_NonGmail_Email2_V2]
    UNION ALL
    SELECT 'Day 10' AS Source_Day, Email FROM [Day10_Tier3_NonGmail_Email2_V2]
) combined_days
WHERE Email LIKE '%hotmail%'
GROUP BY Source_Day




SELECT 
    Source_Day,
    COUNT(1) AS Hotmail_Count
FROM (
    SELECT 'Tier 1' AS Source_Day, Email FROM [Tier 1 - NonGmail V2]
    UNION ALL
    SELECT 'Tier 2' AS Source_Day, Email FROM [Tier 2 - NonGmail V2]
    UNION ALL
    SELECT 'Tier 3' AS Source_Day, Email FROM [Tier 3 - NonGmail V2]
    UNION ALL
    SELECT 'Tier 4' AS Source_Day, Email FROM [Tier 4 - NonGmail V2]
    UNION ALL
    SELECT 'Tier 5' AS Source_Day, Email FROM [Tier 5 - NonGmail V2]
) combined_days
WHERE Email LIKE '%hotmail%'
GROUP BY Source_Day