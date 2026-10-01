public class Modon_Egypt_ContactFilterHelper {
    
    //*** Filters for beforeInsertMethod ***//
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList) {
        List<Contact> modonEgyptContacts = new List<Contact>();
        List<Contact> otherContacts = new List<Contact>();
        Map<Id, Contact> modonEgyptMap = new Map<Id, Contact>();
        Map<Id, Contact> otherMap = new Map<Id, Contact>();

        for (SObject obj : newList) {
            Contact c = (Contact) obj; 
            if (c.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptContacts.add(c);
                modonEgyptMap.put(c.Id, c);
            } else {
                otherContacts.add(c);
                otherMap.put(c.Id, c);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptContacts' => modonEgyptContacts,
            'OtherContacts' => otherContacts,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap
        };
    }
    
     //*** Filters for beforeUpdateMethod ***//
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<Contact> modonEgyptContacts = new List<Contact>();
        List<Contact> otherContacts = new List<Contact>();
        Map<Id, Contact> modonEgyptMap = new Map<Id, Contact>();
        Map<Id, Contact> otherMap = new Map<Id, Contact>();
        Map<Id, Contact> modonEgyptOldMap = new Map<Id, Contact>();
        Map<Id, Contact> otherOldMap = new Map<Id, Contact>();

        for (SObject obj : newList) {
            Contact c = (Contact) obj;
            if (c.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptContacts.add(c);
                modonEgyptMap.put(c.Id, c);
            } else {
                otherContacts.add(c);
                otherMap.put(c.Id, c);
            }
        }

        for (SObject obj : oldList) {
            Contact c = (Contact) obj;
            if (c.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldMap.put(c.Id, c);
            } else {
                otherOldMap.put(c.Id, c);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptContacts' => modonEgyptContacts,
            'OtherContacts' => otherContacts,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap,
            'ModonEgyptOldMap' => modonEgyptOldMap,
            'OtherOldMap' => otherOldMap
        };
    }
    
     //*** Filters for afterInsertMethod ***//
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<Contact> modonEgyptContacts = new List<Contact>();
        List<Contact> otherContacts = new List<Contact>();
        Map<Id, Contact> modonEgyptMap = new Map<Id, Contact>();
        Map<Id, Contact> otherMap = new Map<Id, Contact>();

        for (SObject obj : newList) {
            Contact c = (Contact) obj;
            if (c.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptContacts.add(c);
                modonEgyptMap.put(c.Id, c);
            } else {
                otherContacts.add(c);
                otherMap.put(c.Id, c);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptContacts' => modonEgyptContacts,
            'OtherContacts' => otherContacts,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap
        };
    }
    
     //*** Filters for afterUpdateMethod ***//
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<Contact> modonEgyptContacts = new List<Contact>();
        List<Contact> otherContacts = new List<Contact>();
        Map<Id, Contact> modonEgyptMap = new Map<Id, Contact>();
        Map<Id, Contact> otherMap = new Map<Id, Contact>();
        Map<Id, Contact> modonEgyptOldMap = new Map<Id, Contact>();
        Map<Id, Contact> otherOldMap = new Map<Id, Contact>();

        for (SObject obj : newList) {
            Contact c = (Contact) obj;
            if (c.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptContacts.add(c);
                modonEgyptMap.put(c.Id, c);
            } else {
                otherContacts.add(c);
                otherMap.put(c.Id, c);
            }
        }

        for (SObject obj : oldList) {
            Contact c = (Contact) obj;
            if (c.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldMap.put(c.Id, c);
            } else {
                otherOldMap.put(c.Id, c);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptContacts' => modonEgyptContacts,
            'OtherContacts' => otherContacts,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap,
            'ModonEgyptOldMap' => modonEgyptOldMap,
            'OtherOldMap' => otherOldMap
        };
    }
    

}