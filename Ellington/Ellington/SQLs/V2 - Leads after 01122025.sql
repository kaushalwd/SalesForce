SELECT 
    Email,
    FirstName,
    LastName,
    Status,
    Id as SubscriberKey
FROM Lead_Salesforce ls
WHERE ls.CreatedDate >= '2025-12-01'
    And ( ls.LeadSource = 'digital_marketing_paid'
    Or ls.LeadSource = 'Digital Marketing - Paid'
    OR ls.LeadSource = 'Social'
    Or ls.LeadSource = 'digital_marketing_organic'
    Or ls.LeadSource = 'Digital Marketing - Organic'
    Or ls.LeadSource = 'Mobile App'
    Or ls.LeadSource = 'digital_marketing_internal'
    Or ls.LeadSource = 'Digital Marketing - Internal')
    AND ls.Status != 'Duplicate'
    AND ls.Status != 'Incomplete Data'
    AND ls.Status != 'Not a Lead'