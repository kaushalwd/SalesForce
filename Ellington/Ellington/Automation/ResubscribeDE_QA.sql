SELECT 
    SubscriberKey, 
    EmailAddress, 
    [CRM Status], 
    AllSubsStatus
FROM (
    SELECT 
        de.Id as SubscriberKey, 
        de.Email as EmailAddress, 
        de.HasOptedOutOfEmail, 
        de.Status__c as [CRM Status], 
        l.status as AllSubsStatus,
        /* Partitions the data by SubscriberKey and ranks them */
        ROW_NUMBER() OVER (PARTITION BY de.Id ORDER BY de.Id) as rn
    FROM Lead_Salesforce as de
    INNER JOIN [_listsubscribers] AS l
          ON de.Id = l.subscriberkey
    WHERE de.Status__c = 'Subscribed' 
      AND (de.HasOptedOutOfEmail = 'False' OR  de.HasOptedOutOfEmail = 0)
      AND l.status = 'Unsubscribed'
) as sub
WHERE sub.rn = 1