SELECT de.SubscriberKey,
        de.EmailAddress,
        de.[CRM Status],
        de.AllSubsStatus
FROM ResubscribeDE_QA as de
WHERE de.ScriptResponse != 'OK'
OR de.ScriptResponse IS NULL
AND de.EmailAddress LIKE '%@horizontal.com'