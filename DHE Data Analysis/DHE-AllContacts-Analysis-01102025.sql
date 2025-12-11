/**** Contacts not in GF and BF CRM, but exist All Contacts | DE: Extra_Contact_All_Contacts ****/
/*  12,24,465  */

SELECT a.SubscriberKey
FROM ENT.AllContacts a
LEFT JOIN Contact_Salesforce c ON a.SubscriberKey = c._ContactKey
LEFT JOIN Contact_Salesforce_GVB2B g ON a.SubscriberKey = g.ContactKey
WHERE c._ContactKey IS NULL AND g.ContactKey IS NULL AND a.SubscriberKey like '003%'


/**** Contacts not in GF and BF CRM, but exist All Contacts | DE: Extra_User_All_Contacts ****/
/*   305   */
SELECT a.SubscriberKey
FROM ENT.AllContacts a
LEFT JOIN User_Salesforce_GVB2B g ON a.SubscriberKey = g.ContactKey
WHERE g.ContactKey IS NULL AND a.SubscriberKey like '005%'


/**** Contacts present in both Extra_User_All_Contacts and Contact_Salesforce (with CreatedById) | DE: Extra_Users_Present_in_GF ****/
/* 244 */

SELECT e.ContactKey
FROM Extra_User_All_Contacts e
LEFT JOIN Contact_Salesforce c 
    ON e.ContactKey = c.CreatedById
WHERE c.CreatedById IS NULL

/**** Contacts not present in Extra_User_All_Contacts, but exist in Contact_Salesforce (with CreatedById) | DE: Users_In_GF ****/
/* 61 */
SELECT DISTINCT e.ContactKey
FROM Extra_User_All_Contacts e
WHERE e.ContactKey IN (
    SELECT DISTINCT c.CreatedById
    FROM Contact_Salesforce c
)


/* Contacts exist in 'AllContacts' and 'TotalRecords_In_AllContacts_Not_migrated' | DE: Not_Migrated_AllContacts */
/*   7,62,002   */

SELECT a.SubscriberKey
FROM ENT.AllContacts a
INNER JOIN TotalRecords_In_AllContacts_Not_migrated c 
ON a.SubscriberKey = c.SubscriberKey
WHERE a.SubscriberKey like '003%'

/***** Contacts need to be identify | DE: Data_Can_Be_Removed_30092025 ****/
/*   4,72,033   */

SELECT DISTINCT a.ContactKey
FROM Extra_Contact_All_Contacts a
LEFT JOIN TotalRecords_In_AllContacts_Not_migrated c
    ON a.ContactKey = c.SubscriberKey
WHERE c.SubscriberKey IS NULL


/***** Contacts exist in All Subscribers (BF records which were not migrated) | DE: Query_Extra_Contacts ****/
/*   2,31,326   */

SELECT DISTINCT e.contactKey
FROM Extra_Contact_All_Contacts e
Inner JOIN _subscribers s
ON e.ContactKey = s.SubscriberKey


/***** BF records which were not migrated and not exist in 'All Subscribers' | DE: Not_Exist_In_AllSubscribers    *****/
/*   9,93,139   */

SELECT DISTINCT e.ContactKey
FROM Extra_Contact_All_Contacts e
LEFT JOIN _Subscribers s
    ON e.ContactKey = s.SubscriberKey
WHERE s.SubscriberKey IS NULL