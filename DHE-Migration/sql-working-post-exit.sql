SELECT 
    SUR.ContactId,
    SUR.Survey_Date__c,
    M.FirstName
FROM 
    (
        SELECT 
            ContactId,
            Survey_Date__c,
            ROW_NUMBER() OVER (PARTITION BY ContactId ORDER BY Survey_Date__c DESC) AS latestRow
        FROM 
            [Master_SurveyInvitation_Salesforce_Copy]
    ) AS SUR
JOIN 
    [MasterDE_AD_Copy] M ON SUR.ContactId = M.id
WHERE 
    SUR.latestRow = 1