SELECT 
    Email,
    MAX(FirstName) as FirstName,
    MAX(LastName) as LastName,
    MAX(Status) as Status,
    Max(Id) as SubscriberKey
FROM Lead_Salesforce
WHERE CreatedDate >= '2025-12-01'
    And LeadSource = 'Digital Marketing - Paid'
    And LeadSource = 'Social'
    And LeadSource = 'Digital Marketing - Organic'
    And LeadSource = 'Mobile App'
    And LeadSource = 'Digital Marketing - Internal'
    AND Status != 'Duplicate'
    AND Status != 'Qualified'
    AND Status != 'Incomplete Data'
    AND Status != 'Not a Lead'
    AND Status != 'Agent/Broker'
GROUP BY Email

------------------------

SELECT distinct
    Id as SubscriberKey,
    Email,
    FirstName,
    LastName,
    Status
FROM Lead_Salesforce
WHERE CreatedDate >= '2025-12-01'
AND Status != 'Not a Lead'
And Status != 'Agent/Broker'