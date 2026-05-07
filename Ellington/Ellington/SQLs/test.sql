 SELECT id                     AS [SubscriberKey],
       firstname              AS [First Name],
       lastname               AS [Last Name],
       email                  AS [Email Address],
       subscription_status__c AS [Status],
       email_consent__c       AS [Email Subscription],
       whatsapp_consent__c    AS [WhatsApp Subscription],
       country                AS [Country of residance],
       mobilephone            AS [Phone Number],
       mobile_country_code__c AS [Locale]
FROM   [Master Lead] Wait_List__c = 'true' 