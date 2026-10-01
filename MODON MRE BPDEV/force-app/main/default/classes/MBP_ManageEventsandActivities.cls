/* Version       Author                          Date            Comment                                                                      
* 1.0           raghu.chilukuri@activemindsit.com    19 Dec 2023      Initial Draft(Event and Activity Record creation,Calendar logic)      
* 1.1           raghu.chilukuri@activemindsit.com    08/03/26         code Refinement
* 1.2           raghu.chilukuri@activemindsit.com    12/03/26         Added agency-based event filtering and user context handling And added a New Method publishEvent for the event status Handelling
* 1.3           raghu.chilukuri@activemindsit.com    31/08/26         Added getEventContext and finalizeEventWizard for the agency-assignment wizard;
*                                                                       extracted upsertAgencyMappings; assignAgenciesToEvent no longer hardcodes
*                                                                       'Pending for Approval' — status transitions now live in finalizeEventWizard.
* 1.4           raghu.chilukuri@activemindsit.com    31/08/26         getEventContext now also returns communicationSent, based on whether a
*                                                                       Communication__c record exists for the event (EventorActivity__c lookup) —
*                                                                       the same record CommunicationController creates when an email actually sends.
**********************************************************************************************
*/
public with sharing class MBP_ManageEventsandActivities {

    // Event types that skip approval and publish immediately once the wizard
    // is finalized. Everything else routes through 'Pending for Approval'.
    private static final Set<String> DIRECT_PUBLISH_TYPES = new Set<String>{
        'Open House', 'Broker Meeting', 'Broker Briefing'
    };

    /**
 * @description Fetches available agencies for event assignment based on selected filter type, country, emirate, and excludes already assigned agencies for the given event.
 * @param filterType Selected agency filter type such as UAE or International.
 * @param country Selected bank country used for international filtering.
 * @param emirate Selected emirate used for UAE filtering.
 * @param eventId Event or Activity record Id.
 * @return List of matching Account records for agency assignment.
 */
    
   @AuraEnabled(cacheable=true)
public static List<Account> getAgencies(String filterType, String country, String emirate, Id eventId) {
    try {
        Set<Id> assigned = new Set<Id>();
        if (eventId != null) {
            for (Agency_Mapping__c m : [
                SELECT Agency__c
                FROM Agency_Mapping__c
                WHERE Event_and_Activity__c = :eventId
                AND Status__c = 'Assigned'
            ]) {
                if (m.Agency__c != null) assigned.add(m.Agency__c);
            }
        }

        // SOQL injection fix: emirate/country filters bound via queryWithBinds (no string concat into literals).
        Map<String, Object> binds = new Map<String, Object>{ 'assigned' => assigned };
        String query = 'SELECT Id, Name, Type_of_Registration__c, BillingCountry, BillingCity, Phone, Website, Bank_Country__c ' +
                       'FROM Account WHERE Type_of_Registration__c != null';

        if (!assigned.isEmpty()) {
            query += ' AND Id NOT IN :assigned';
        }

        if (filterType == 'UAE') {
            query += ' AND Type_of_Registration__c = \'UAE Broker\'';
            if (emirate != null && emirate != 'All') {
                String emirateLike = '%' + emirate + '%';
                binds.put('emirate', emirate);
                binds.put('emirateLike', emirateLike);
                query += ' AND (BillingCity = :emirate OR BillingCity LIKE :emirateLike)';
            }
        } else if (filterType == 'International') {
            query += ' AND Type_of_Registration__c = \'International Broker\'';
            if (country != null && country != 'All' && country != 'null') {
                binds.put('country', country);
                query += ' AND Bank_Country__c = :country';
            }
        }

        return Database.queryWithBinds(query + ' ORDER BY Name', binds, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
        System.debug('Error fetching agencies: ' + e.getMessage());
        return new List<Account>();
    }
}


/**
 * @description Fetches agency Ids already assigned to the given event or activity.
 * @param eventId Event or Activity record Id.
 * @return List of assigned Agency Account Ids.
 */

    
    @AuraEnabled(cacheable=true)
    public static List<Id> getAssignedAgencies(Id eventId) {
        try {
            if (eventId == null) return new List<Id>();
            List<Agency_Mapping__c> mappings = [SELECT Agency__c FROM Agency_Mapping__c WHERE Event_and_Activity__c = :eventId AND Status__c = 'Assigned'];
            List<Id> assignedIds = new List<Id>();
            for (Agency_Mapping__c mapping : mappings) assignedIds.add(mapping.Agency__c);
            return assignedIds;
        } catch (Exception e) {
            System.debug('Error fetching assigned agencies: ' + e.getMessage());
            return new List<Id>();
        }
    }

    /**
 * @description Fetches and sorts available bank country picklist values from Account.Bank_Country__c.
 * @return List of bank country values.
 */
    
    @AuraEnabled(cacheable=true)
    public static List<String> getBankCountries() {
        try {
            List<Map<String, String>> picklistMap = MBP_utilityclass.getDynamicPicklistValues('Account', 'Bank_Country__c');
            List<String> countries = new List<String>();
            for (Map<String, String> item : picklistMap) if (item.containsKey('value') && item.get('value') != null) countries.add(item.get('value'));
            countries.sort();
            return countries;
        } catch (Exception e) {
            System.debug('Error fetching bank countries: ' + e.getMessage());
            return new List<String>();
        }
    }

    /**
 * @description Fetches active agency contacts with email for the selected agencies and broker types for event communication.
 * @param request Wrapper containing selected agency Ids and broker types.
 * @return List of contact details including id, name, email, account name, and broker type.
 */
    
    @AuraEnabled
    public static List<Map<String, String>> getAgencyContactsForEvent(ContactRequest request) {
        List<Map<String, String>> contactsList = new List<Map<String, String>>();
        if (request == null || request.agencyIds == null || request.agencyIds.isEmpty()) return contactsList;
        
        List<String> brokerTypes = request.brokerTypes != null ? request.brokerTypes : new List<String>();
        List<Contact> contacts;
        
        if (brokerTypes.isEmpty() || brokerTypes.contains('All')) {
            contacts = [SELECT Id, Name, Email, AccountId, Agent_Status__c, Account.Name, Broker_Type__c
                       FROM Contact WHERE AccountId IN :request.agencyIds AND Email != null AND Agent_Status__c = 'Active' ORDER BY Name];
        } else {
            contacts = [SELECT Id, Name, Email, AccountId, Agent_Status__c, Account.Name, Broker_Type__c
                       FROM Contact WHERE AccountId IN :request.agencyIds AND Email != null AND Agent_Status__c = 'Active'
                       AND Broker_Type__c IN :brokerTypes ORDER BY Name];
        }
        
        for (Contact con : contacts) contactsList.add(new Map<String, String>{
            'id' => con.Id, 'name' => con.Name, 'email' => con.Email,
            'accountName' => con.Account.Name, 'brokerType' => con.Broker_Type__c
        });
        
        return contactsList;
    }


    /**
 * @description Fetches available org-wide email addresses for use as sender addresses in event communication.
 * @return List of label/value pairs for org-wide email addresses.
 */
    
        @AuraEnabled
        public static List<Map<String, String>> getOrgWideEmailAddresses() {
            List<OrgWideEmailAddress> addresses = [
                SELECT Id, Address, DisplayName 
                FROM OrgWideEmailAddress 
                ORDER BY DisplayName
            ];

            List<Map<String, String>> emailAddresses = new List<Map<String, String>>();

            for (OrgWideEmailAddress emailAddr : addresses) {
                emailAddresses.add(new Map<String, String>{
                    'label' => emailAddr.DisplayName + ' (' + emailAddr.Address + ')',
                    'value' => emailAddr.Address
                });
            }

            return emailAddresses;
        }


        /**
 * @description Assigns selected agencies to the event and updates existing mappings, marking removed agencies as unassigned.
 * Note: as of 1.3 this no longer sets the event's Status__c — that transition is
 * owned by finalizeEventWizard, which knows whether the event's Type__c requires
 * approval or can publish directly. Kept for any callers that just need the
 * mapping saved without moving the record's status.
 * @param eventId Event or Activity record Id.
 * @param agencyIds List of selected Agency Account Ids.
 * @return Status message indicating success or failure of assignment processing.
 */
    
    @AuraEnabled
    public static String assignAgenciesToEvent(String eventId, List<Id> agencyIds) {
        try {
            if (eventId == null) return 'Error: No event selected';

            upsertAgencyMappings(eventId, agencyIds);

            return 'Success: ' + (agencyIds != null ? agencyIds.size() : 0) + ' agencies assigned to the event';

        } catch (Exception e) {
            System.debug('Error in assignAgenciesToEvent: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            return 'Error: Could not save agency assignments. ' + e.getMessage();
        }
    }

    /**
 * @description Returns the event's type/status/timing plus whether the agency-assignment
 * wizard's final step should be "Submit for Approval" or "Publish", based on Type__c.
 * communicationSent reflects whether any Communication__c record exists for this event
 * (created by CommunicationController when an email is actually sent) — not a guess.
 * startDateTime/endDateTime are epoch-millis strings (or null) so the client can format
 * and count down without timezone-string parsing.
 * @param eventId Event or Activity record Id.
 * @return Map with keys 'name', 'type', 'status', 'requiresApproval', 'communicationSent', 'startDateTime', 'endDateTime'.
 */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getEventContext(Id eventId) {
        Event_and_Activity__c ev = [
            SELECT Id, Name, Type__c, Status__c, Start_Date_and_Time__c, End_Date_and_Time__c
            FROM Event_and_Activity__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        Boolean requiresApproval = ev.Type__c == null || !DIRECT_PUBLISH_TYPES.contains(ev.Type__c);

        Integer communicationCount = [
            SELECT COUNT()
            FROM Communication__c
            WHERE EventorActivity__c = :eventId
        ];

        return new Map<String, String>{
            'name' => ev.Name,
            'type' => ev.Type__c,
            'status' => ev.Status__c,
            'requiresApproval' => String.valueOf(requiresApproval),
            'communicationSent' => String.valueOf(communicationCount > 0),
            'startDateTime' => ev.Start_Date_and_Time__c != null ? String.valueOf(ev.Start_Date_and_Time__c.getTime()) : null,
            'endDateTime' => ev.End_Date_and_Time__c != null ? String.valueOf(ev.End_Date_and_Time__c.getTime()) : null
        };
    }

    /**
 * @description Single call used by the agency-assignment wizard's final step: upserts
 * the agency mappings, then moves the event to 'Pending for Approval' (types that need
 * review) or straight to 'Published' (Open House / Broker Meeting / Broker Briefing).
 * Sending the actual email (and the Communication__c record that comes with it) is
 * handled separately by CommunicationController.processCommunication.
 * @param eventId Event or Activity record Id.
 * @param agencyIds List of selected Agency Account Ids.
 * @param requiresApproval Whether this event's type requires approval before publishing.
 * @return The event's new status, e.g. 'Published' or 'Pending for Approval'.
 */
    @AuraEnabled
    public static String finalizeEventWizard(Id eventId, List<Id> agencyIds, Boolean requiresApproval) {
        try {
            upsertAgencyMappings(eventId, agencyIds);

            String newStatus = requiresApproval ? 'Pending for Approval' : 'Published';
            update new Event_and_Activity__c(Id = eventId, Status__c = newStatus);

            return newStatus;
        } catch (Exception e) {
            System.debug('Error in finalizeEventWizard: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Could not finalize assignment: ' + e.getMessage());
        }
    }

    /**
 * @description Shared upsert logic for agency mappings: marks newly selected agencies
 * as Assigned, creates mappings for ones that don't exist yet, and marks any
 * previously-assigned agency that's no longer selected as Unassigned.
 * @param eventId Event or Activity record Id.
 * @param agencyIds List of currently selected Agency Account Ids.
 */
    private static void upsertAgencyMappings(Id eventId, List<Id> agencyIds) {
        List<Agency_Mapping__c> existingMappings = [
            SELECT Id, Agency__c, Status__c, Communication__c
            FROM Agency_Mapping__c
            WHERE Event_and_Activity__c = :eventId
        ];

        Map<Id, Agency_Mapping__c> agencyIdToMapping = new Map<Id, Agency_Mapping__c>();
        for (Agency_Mapping__c mapping : existingMappings) {
            agencyIdToMapping.put(mapping.Agency__c, mapping);
        }

        List<Agency_Mapping__c> mappingsToUpdate = new List<Agency_Mapping__c>();

        // Process agencies to assign
        if (agencyIds != null && !agencyIds.isEmpty()) {
            for (Id agencyId : agencyIds) {
                if (agencyIdToMapping.containsKey(agencyId)) {
                    Agency_Mapping__c mapping = agencyIdToMapping.get(agencyId);
                    if (mapping.Status__c != 'Assigned') {
                        mapping.Status__c = 'Assigned';
                        mappingsToUpdate.add(mapping);
                    }
                } else {
                    // Create new mapping
                    mappingsToUpdate.add(new Agency_Mapping__c(
                        Event_and_Activity__c = eventId,
                        Agency__c = agencyId,
                        Status__c = 'Assigned'
                    ));
                }
            }
        }

        // Process agencies to unassign
        for (Id existingAgencyId : agencyIdToMapping.keySet()) {
            if (agencyIds == null || !agencyIds.contains(existingAgencyId)) {
                Agency_Mapping__c mapping = agencyIdToMapping.get(existingAgencyId);
                if (mapping.Status__c != 'Unassigned') {
                    mapping.Status__c = 'Unassigned';
                    mappingsToUpdate.add(mapping);
                }
            }
        }

        // Update mappings
        if (!mappingsToUpdate.isEmpty()) {
            upsert mappingsToUpdate;
        }
    }

/**
 * @description Fetches published events and activities dynamically based on mode such as Today, Future, Past, or custom date range.
 * @param mode Filter mode used to determine which events to return.
 * @param startDate Start datetime string used when mode is Range.
 * @param endDate End datetime string used when mode is Range.
 * @return List of Event_and_Activity__c records matching the requested criteria.
 */
    
@AuraEnabled(cacheable=true)
public static List<Event_and_Activity__c> getEventsDynamic(String mode, String startDate, String endDate) {
    try {
        DateTime now = DateTime.now();
        Integer currentYear = now.year();
        DateTime startOfYearDT = DateTime.newInstance(Date.newInstance(currentYear, 1, 1), Time.newInstance(0,0,0,0));
        DateTime endOfYearDT = DateTime.newInstance(Date.newInstance(currentYear, 12, 31), Time.newInstance(23,59,59,999));

        // SOQL injection fix: mode/date/agency filters bound via queryWithBinds.
        Map<String, Object> binds = new Map<String, Object>{
            'startOfYearDT' => startOfYearDT,
            'endOfYearDT' => endOfYearDT,
            'now' => now
        };

        List<String> whereClauses = new List<String>{
            'Status__c = \'Published\'',
            '(Start_Date_and_Time__c >= :startOfYearDT AND End_Date_and_Time__c <= :endOfYearDT)'
        };

        if (mode == 'Today') {
            Date today = Date.today();
            DateTime startOfDay = DateTime.newInstance(today, Time.newInstance(0,0,0,0));
            DateTime endOfDay = DateTime.newInstance(today, Time.newInstance(23,59,59,999));
            binds.put('startOfDay', startOfDay);
            binds.put('endOfDay', endOfDay);
            whereClauses.add('(Start_Date_and_Time__c <= :endOfDay AND End_Date_and_Time__c >= :startOfDay)');
        /* Update Version 1.2
        @description :
        * Refactored mode-based filtering logic for better readability and structure.
        * Added logic to fetch current logged-in user's Contact and associated Agency (Account).
        * Applied additional filter to fetch only events mapped to the user's agency via Agency_Mapping__c.
        * Ensures only 'Assigned' events related to the agency are visible.
        * Added debug logs for query and agency details for easier troubleshooting.
        */
        } else if (mode == 'Future') {
            whereClauses.add('End_Date_and_Time__c > :now');
        } else if (mode == 'Past') {
            whereClauses.add('Start_Date_and_Time__c < :now');
        } else if (mode == 'Range' && startDate != null && endDate != null) {
            DateTime startDt = DateTime.valueOfGmt(startDate.replace('T',' '));
            DateTime endDt = DateTime.valueOfGmt(endDate.replace('T',' '));
            binds.put('startDt', startDt);
            binds.put('endDt', endDt);
            whereClauses.add(
                '((Start_Date_and_Time__c >= :startDt AND Start_Date_and_Time__c <= :endDt) ' +
                'OR (End_Date_and_Time__c >= :startDt AND End_Date_and_Time__c <= :endDt) ' +
                'OR (Start_Date_and_Time__c <= :startDt AND End_Date_and_Time__c >= :endDt))'
            );
        }

        User currentUser = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Id agencyAccountId;

        if (currentUser.ContactId != null) {
            Contact userContact = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :currentUser.ContactId
                LIMIT 1
            ];
            agencyAccountId = userContact.AccountId;
        }

        if (agencyAccountId != null) {
            binds.put('agencyAccountId', agencyAccountId);
            whereClauses.add(
                'Id IN (SELECT Event_and_Activity__c FROM Agency_Mapping__c ' +
                'WHERE Agency__c = :agencyAccountId ' +
                'AND Status__c = \'Assigned\')'
            );
        }

        String query =
            'SELECT Id, Name, Start_Date_and_Time__c, End_Date_and_Time__c, ' +
            'Location__c, Description__c, External_Link__c, Social_Media_Link__c, ' +
            'Virtual_Tour_Link__c, CreatedDate, Status__c, Type__c ' +
            'FROM Event_and_Activity__c ' +
            'WHERE ' + String.join(whereClauses, ' AND ') +
            ' ORDER BY Start_Date_and_Time__c ' + (mode == 'Past' ? 'DESC' : 'ASC');

        System.debug('Event Query => ' + query);
        System.debug('Agency Account Id => ' + agencyAccountId);

        return Database.queryWithBinds(query, binds, AccessLevel.SYSTEM_MODE);

    } catch (Exception e) {
        System.debug('Error fetching events: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        return new List<Event_and_Activity__c>();

        /*Update 1.2 Ends Here */
    }
}
    
    /**
 * @description Wrapper class used to pass selected agency Ids and broker types for fetching event communication contacts.
 */
    
    // Wrapper class for contact request
    public class ContactRequest {
        @AuraEnabled public List<String> agencyIds { get; set; }
        @AuraEnabled public List<String> brokerTypes { get; set; }
    }


/** Update Version 1.2 New method Addition
 * @description To Make Status as Published through Button If the event is Approved
 */

        @AuraEnabled
    public static String publishEvent(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required');
        }

        update new Event_and_Activity__c(
            Id = recordId,
            Status__c = 'Published'
        );

        return 'Event/Activity published successfully';
    }


}