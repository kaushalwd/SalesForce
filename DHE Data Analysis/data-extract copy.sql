/***** DE: Contact_Salesforce_GVB2B *****/
select id as ContactKey, Company__c as Company from Ent.Contact_Salesforce_1

/**** Not in GF and BF CRM contacts, but in All Contacts ****/
/*  12,24,465  */

SELECT COUNT(*) as MissingCount
FROM (
    SELECT a.SubscriberKey
    FROM [AllContacts] a
    LEFT JOIN Contact_Salesforce c ON a.SubscriberKey = c._ContactKey
    LEFT JOIN Contact_Salesforce_GVB2B g ON a.SubscriberKey = g.ContactKey
    WHERE c._ContactKey IS NULL AND g.ContactKey IS NULL AND a.SubscriberKey like '003%'
) t

-----------------
/***** DE: User_Salesforce_GVB2B *****/
select ContactKey, name from Ent.User_Salesforce_1

/**** Not in GF and BF CRM Users, but in All Contacts ****/
/*  305  */

SELECT COUNT(*) as MissingCount
FROM (
    SELECT a.SubscriberKey
    FROM [AllContacts] a
    LEFT JOIN User_Salesforce_GVB2B g ON a.SubscriberKey = g.ContactKey
    WHERE g.ContactKey IS NULL AND a.SubscriberKey like '005%'
) t


----------------------

BF_Master_User_Salesforce

-----------------

/* Contacts in All Subscribers (_subscribers) */
select SubscriberKey, DateJoined, Status 
from _subscribers
where SubscriberKey like '003%'

----------------

/* Common in AllSubscribers (_subscribers) & Extra Contacts */
/* 2,31,326 */

SELECT DISTINCT e.contactKey
FROM Extra_Contact_All_Contacts e
Inner JOIN _subscribers s
ON e.ContactKey = s.SubscriberKey

---------------------

/*****  Last Email sent to subscribers  *****/

SELECT
    s.SubscriberKey,
    s.EmailAddress,
    MAX(se.EventDate) AS LastEmailSentDate
FROM _Subscribers s
INNER JOIN _Sent se
    ON s.SubscriberKey = se.SubscriberKey
GROUP BY
    s.SubscriberKey,
    s.EmailAddress

---------------------

/*****  Extra Contacts email sent check  with BFSentArchive *****/
/* 0 */

SELECT
    e.ContactKey,
    s.EmailAddress,
    MAX(se.EventDate) AS LastEmailSentDate
FROM Ent.Query_Extra_Contacts e
INNER JOIN _Subscribers s
    ON e.ContactKey = s.SubscriberKey
LEFT JOIN BFSentArchive se
    ON s.SubscriberKey = se.SubscriberKey
GROUP BY
    e.ContactKey,
    s.EmailAddress

/*****  Extra Contacts email sent check  with _Sent *****/
/* 0 */

SELECT
    e.ContactKey,
    s.EmailAddress,
    MAX(se.EventDate) AS LastEmailSentDate
FROM Ent.Query_Extra_Contacts e
INNER JOIN _Subscribers s
    ON e.ContactKey = s.SubscriberKey
LEFT JOIN _Sent se
    ON s.SubscriberKey = se.SubscriberKey
GROUP BY
    e.ContactKey,
    s.EmailAddress

----------------------

/* Common in AllSubscribers (_subscribers) & Extra Users */
/* 1 */

SELECT DISTINCT e.contactKey
FROM Extra_User_All_Contacts e
Inner JOIN _subscribers s
ON e.ContactKey = s.SubscriberKey

------------------------


/***** Source of old data to compare *****/
/* 7,52,432 contacts exist in ‘TotalRecords_In_AllContacts_Not_migrated’ and 'Extra_Contact_All_Contacts' */

select e.contactKey 
from 
Extra_Contact_All_Contacts e
Inner Join TotalRecords_In_AllContacts_Not_migrated t on t.SubscriberKey = e.contactkey


/***** 2,20,380 contacts of ‘TotalRecords_In_AllContacts_Not_migrated’ are present in _Subscribers *****/

SELECT DISTINCT e.SubscriberKey
FROM TotalRecords_In_AllContacts_Not_migrated e
Inner JOIN _subscribers s
ON e.SubscriberKey = s.SubscriberKey

------------------------

/* 5,43,030 contacts exist in 'Extra_Contact_All_Contacts' and 'TotalRecords_In_AllContacts_Not_migrated', but do not exist in Query_Extra_Contacts. */
/***** 5,43,030 *****/

SELECT e.contactKey
FROM Extra_Contact_All_Contacts e
INNER JOIN TotalRecords_In_AllContacts_Not_migrated t
    ON t.SubscriberKey = e.contactKey
LEFT JOIN Query_Extra_Contacts q
    ON t.SubscriberKey = q.contactKey
WHERE q.contactKey IS NULL

-------------------------

/* 7,62,002 contacts exist in 'AllContacts' and 'TotalRecords_In_AllContacts_Not_migrated' */

SELECT a.SubscriberKey
FROM [AllContacts] a
INNER JOIN TotalRecords_In_AllContacts_Not_migrated c 
ON a.SubscriberKey = c.SubscriberKey
WHERE a.SubscriberKey like '003%'



TotalRecords_In_AllContacts_Not_migrated - 9,72,441
Common in TotalRecords_In_AllContacts_Not_migrated & AllContacts - 7,62,002



SELECT a.ContactKey
FROM Extra_Contact_All_Contacts a
INNER JOIN TotalRecords_In_AllContacts_Not_migrated c 
ON a.ContactKey != c.SubscriberKey
WHERE a.ContactKey like '003%'



/**  **/

SELECT COUNT(*) as MissingCount
FROM (
    SELECT g.SubscriberKey, MAX(g.EventDate) AS LastEmailSentDate
    FROM BFSentArchive g
    INNER JOIN Ent.Query_Extra_Contacts a ON a.ContactKey = g.SubscriberKey
    Group by g.SubscriberKey
) t

SELECT g.SubscriberKey, MAX(g.EventDate) AS LastEmailSentDate
    FROM BFSentArchive g
    INNER JOIN Ent.Query_Extra_Contacts a ON a.ContactKey = g.SubscriberKey
    Group by g.SubscriberKey


/*****  Extra Contacts email sent check *****/
/* 0 */

SELECT
    e.ContactKey,
    s.EmailAddress,
    MAX(se.EventDate) AS LastEmailSentDate
FROM Ent.Query_Extra_Contacts e
INNER JOIN _Subscribers s
    ON e.ContactKey = s.SubscriberKey
LEFT JOIN BFSentArchive se
    ON s.SubscriberKey = se.SubscriberKey
GROUP BY
    e.ContactKey,
    s.EmailAddress












SELECT
    count(*) as MisionCount 
FROM 
    [All Contacts 25092025] a
Left Join Contact_Salesforce c     
On a.SubscriberKey = c._ContactKey
where c._ContactKey is Null AND a.SubscriberKey like '003%'

/* 1276710 */


SELECT
    count(*) as MisionCount 
FROM 
    [All Contacts 25092025] a
Left Join Contacts_SF_GVB2B c     
On a.SubscriberKey = c.SubscribertKey
where c.SubscriberKey is Null AND a.SubscriberKey like '003%'

/* 4950123 */


SELECT COUNT(*) as MissingCount
FROM (
    SELECT a.SubscriberKey
    FROM [All Contacts 25092025] a
    LEFT JOIN Contact_Salesforce c ON a.SubscriberKey = c._ContactKey
    LEFT JOIN Contacts_SF_GVB2B g ON a.SubscriberKey = g.SubscriberKey
    WHERE c._ContactKey IS NULL AND g.SubscriberKey IS NULL AND a.SubscriberKey like '003%'
) t

/* Extra Contacts in All Contacts : 1224420 */

SELECT
    count(*) as MisionCount 
FROM 
    [All Contacts 25092025] a
Left Join Users_SF_GVB2B u     
On a.SubscriberKey = u.SubscriberKey
where u.SubscriberKey is Null AND a.SubscriberKey like '005%'

/* Extra Users in All Contacts : 305 */


SELECT s.SubscriberKey
FROM [Sent_26092025] s
LEFT JOIN Extra_Contacts_AllContacts_26092025 e ON s.SubscriberKey = e.SubscriberKey
WHERE e.SubscriberKey IS NULL


/* Extra_Contact in Sent, EventDate is Null */

SELECT DISTINCT e.SubscriberKey, s.EventDate
FROM Extra_Contacts_AllContacts_26092025 e
LEFT JOIN [Sent_26092025] s
       ON e.SubscriberKey = s.SubscriberKey
where s.EventDate IS Null

/* Extra_Contact in Sent, EventDate is 2025 */

SELECT DISTINCT e.SubscriberKey, s.EventDate
FROM Extra_Contacts_AllContacts_26092025 e
LEFT JOIN [Sent_26092025] s
       ON e.SubscriberKey = s.SubscriberKey
where s.EventDate IS Not Null




/* Common in AllSubscribers & Extra Contacts */
/* 2,31,324 */

SELECT DISTINCT e.SubscriberKey
FROM Extra_Contacts_AllContacts_26092025 e
Inner JOIN [AllSubscribers_26092025] s
ON e.SubscriberKey = s.SubscriberKey

/* Present in old data BF_Master_Contact_Salesforce_GV, also in Extra contacts */
/* 52418 */

SELECT DISTINCT e.ContactKey
FROM BF_Master_Contact_Salesforce_GV e
INNER JOIN To_Exclude_From_AllContacts_26092025 s
ON e.ContactKey = s.SubscriberKey


/* Present in old data BF_Master_Contact_Salesforce_GV, also in Extra contacts */
/* 89019 */

SELECT DISTINCT e.ContactKey
FROM BF_Master_Contact_Salesforce_GV e
INNER JOIN To_Keep_In_AllContacts_26092025 s
ON e.ContactKey = s.SubscriberKey



SELECT DISTINCT e.ContactKey
FROM BF_Master_Contact_Salesforce_GV e
INNER JOIN Users_with_NoChannels_26092025 s
ON e.ContactKey = s.SubscriberKey






SELECT DISTINCT e.contactKey
FROM Extra_User_All_Contacts e
Inner JOIN Contact_Salesforce s
ON e.ContactKey = s.createdById