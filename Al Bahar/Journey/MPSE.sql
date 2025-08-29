SELECT  mpse.Id AS [MPSE:Id]
        , mpse.Campaign_Name__c as [MPSE:CampaignName]
        , mpse.Campaign_Start_Date__c as [MPSE:CampaignStartDate]
        , mpse.Campaign_End_Date__c as [MPSE:CampaignEndDate]
        , mpse.Account__c as [MPSE:AccountId]
        , mpse.Dealer_Sales_Rep__c as [MPSE:SalesDealerId]
        , a.Id AS [Account:Id]
        , a.Name As [Account:Name]
        , Concat(a.BillingStreet,' ',a.BillingCity,' ', a.BillingCountry) as [Account:BillingAddress]
        , c.ContactKey As ContactKey
        , c.FirstName As [Contact:FirstName]   
        , c.LastName As [Contact:LastName]
        , c.Email As [Contact:Email]
        , c.AccountId As [Contact:AccountId]
        , c.Id AS ContactId
        , c.Contact_For__c As [Contact:ContactFor]
FROM [Test_Master_AfterMarket MPSE] AS mpse
INNER JOIN Test_Master_Account a ON mpse.Account__c = a.Id
INNER JOIN Test_Master_Contact c ON c.AccountId = a.Id
LEFT JOIN (
    SELECT AccountId
    FROM Test_Master_Contact
    WHERE Contact_For__c LIKE '%Parts%' 
            AND Active__c = 'true'
            AND Zero_Bounce_Email_is_Validated__c = 'true'
    GROUP BY AccountId
) parts_contact ON c.AccountId = parts_contact.AccountId
WHERE
(
    parts_contact.AccountId IS NOT NULL AND c.Contact_For__c LIKE '%Parts%'
    OR parts_contact.AccountId IS NULL
)
AND c.Active__c = 'true'
AND c.Zero_Bounce_Email_is_Validated__c = 'true'	
AND Campaign_Name__c LIKE '%PM Kit%'
AND MONTH(Campaign_End_Date__c) = MONTH(GETDATE())