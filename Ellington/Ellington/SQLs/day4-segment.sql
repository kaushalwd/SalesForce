select top 346 
    dg.SubscriberKey,
    dg.Email,
    dg.FirstName,
    dg.LastName
    
    from [Tier 2 - Gmail V2] dg
    
    LEFT JOIN [Day3_Tier2_Gmail_Email2_V2] d3
    ON dg.SubscriberKey = d3.SubscriberKey

    LEFT JOIN [Day3_Tier2_NonGmail_Email2_V2] d3n
    ON dg.SubscriberKey = d3n.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_Gmail_Email2_V2] d2
    ON dg.SubscriberKey = d2.SubscriberKey
    
    LEFT JOIN [Day2_Tier1_Tier2_NonGmail_Email2_V2] d2n
    ON dg.SubscriberKey = d2n.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_Gmail_Email2_V2] d1
    ON dg.SubscriberKey = d1.SubscriberKey
    
    LEFT JOIN [Day1_Tier1_Tier2_NonGmail_Email2_V2] d1n
    ON dg.SubscriberKey = d1n.SubscriberKey
    
WHERE 
    d1.SubscriberKey IS NULL
    AND d1n.SubscriberKey IS NULL
    AND d2.SubscriberKey IS NULL
    AND d2n.SubscriberKey IS NULL
    AND d3.SubscriberKey IS NULL
    AND d3n.SubscriberKey IS NULL