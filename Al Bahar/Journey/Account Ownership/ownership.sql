Select 
Asset.Id as [Asset:Id],
Asset.Campaign_Category__c as [Asset:Campaign_Category__c],
Asset.Division__c as [Asset:Division__c],
Asset.Campaign_Segment__c as [Asset:Campaign_Segment__c],
Asset.Year_Manufacture__c as [Asset:Year_Manufacture__c],
Asset.Make__c as [Asset:Make__c],
Account.Id as [Account:Id],
Account.Country_Code__c	as [Account:Country],
Contact.ContactKey as ContactKey,
Contact.FirstName as [Contact:FirstName],
Contact.LastName as [Contact:LastName],
Contact.Email as [Contact:Email],
Account.Id as [Contact:AccountId]

From Test_Master_Asset as Asset

INNER JOIN Test_Master_Account Account ON Asset.AccountId  = Account.Id
INNER JOIN Test_Master_Contact Contact  ON Asset.AccountId = Contact.AccountId

LEFT JOIN (
    SELECT AccountId
    FROM Test_Master_Contact
    WHERE Contact_For__c LIKE '%Machine%'
            AND Active__c = 'true'
            AND Zero_Bounce_Email_is_Validated__c = 'true'
    GROUP BY AccountId
) parts_contact ON Contact.AccountId = parts_contact.AccountId
WHERE 
Asset.Campaign_Category__c = 'Excav'
AND Asset.Make__c IN ('CAT', 'SEM')
AND Asset.Year_Manufacture__c >= Year(GETDATE())-10
AND Asset.Division__C != 'U'
AND (
    parts_contact.AccountId IS NOT NULL AND Contact.Contact_For__c LIKE '%Machine%'
    OR parts_contact.AccountId IS NULL
)
AND Contact.Active__c = 'true'
AND Contact.Zero_Bounce_Email_is_Validated__c = 'true'