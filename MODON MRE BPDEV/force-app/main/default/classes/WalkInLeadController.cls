/**
* @description       : Walk-In Lead Controller
* @author            : Krishna Chaitanya
* @last modified on  : 07-31-2025
* @last modified by  : Krishna Chaitanya
**/
public without sharing class WalkInLeadController {
    private static final String OIC_USERNAME = 'modon_dev_int_user';
    private static final String OIC_PASSWORD = '01F81a1226$';
    private static final String API_KEY = 'DU26-XM36-ME49-BW58';
    
    @AuraEnabled
    public static Id createLead(
        String firstName,
        String lastName,
        String email,
        String phone,
        String type,
        String appointment,
        Datetime appointmentDateTime,
        Id brokerAccountId,
    Id brokerContactId) {
            //validateEmail(email);
            //validatePhone(phone);
            
            
            if (type == 'Broker' && brokerAccountId != null) {
                List<Contact> contacts = [
                    SELECT Id 
                    FROM Contact 
                    WHERE AccountId = :brokerAccountId 
                    ORDER BY CreatedDate ASC 
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    brokerContactId = contacts[0].Id;
                }
            }
            
            try {
                Lead lead = new Lead(
                    FirstName = firstName,
                    LastName = lastName,
                    Email = email,
                    Phone = phone,
                    Status = 'New',
                    LeadSource = 'Walk-In',
                    BrokerAgency__c = brokerAccountId,
                    BrokerAgent__c = brokerContactId,
                    Appointment_Date_Time__c = appointmentDateTime
                );
                insert lead;
                
                return lead.Id;
            } catch (Exception ex) {
                throw new AuraHandledException('Lead creation failed: ' + ex.getMessage());
            }
        }
    
    @AuraEnabled(cacheable=true)
public static List<Contact> getBrokerContacts(Id accountId) {
    try {
        return [
            SELECT Id, Name, Email, Phone, Title 
            FROM Contact 
            WHERE AccountId = :accountId 
            ORDER BY Name
        ];
    } catch (Exception e) {
        throw new AuraHandledException('Error fetching broker contacts: ' + e.getMessage());
    }
}
    
    @AuraEnabled
    public static Id createAccount(
        String name,
        String phone,
        String appointment,
        Datetime appointmentDateTime
    ) {
        try {
            // Get Broker Agency Record Type
            RecordType brokerRt = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND Name = 'Broker Agency'
                LIMIT 1
            ];
            
            // Create Account
            Account acc = new Account(
                Name = name,
                Phone = phone,
                Appointment_Date_Time__c = appointmentDateTime,
                RecordTypeId = brokerRt.Id
            );
            insert acc;
            
            
            return acc.Id;
        } catch (Exception ex) {
            throw new AuraHandledException('Account creation failed: ' + ex.getMessage());
        }
    }
    
    
    private static void validateEmail(String email) {
        String endpoint = 'https://modondev-modonfusioncloud.integration.eu-frankfurt-1.ocp.oraclecloud.com/ic/api/integration/v1/flows/rest/XXMODON_LOQATE_EMAIL/1.0/loqate/emailvalidation';
        String payload = JSON.serialize(new Map<String, Object>{
            'Email' => email,
                'Timeout' => 5000,
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        System.debug('Email Validation Response: ' + res.getBody());
        if (res.getStatusCode() != 200 || !res.getBody().toLowerCase().contains('valid')) {
            throw new AuraHandledException('Email validation failed.');
        }
    }
    
    private static void validatePhone(String phone) {
        String endpoint = 'https://modondev-modonfusioncloud.integration.eu-frankfurt-1.ocp.oraclecloud.com/ic/api/integration/v1/flows/rest/XXMODODN_LOQATE_PHONENUMBER/1.0/loqate/phonenumbervalidation';
        String payload = JSON.serialize(new Map<String, Object>{
            'Phone' => phone,
                'Country' => 'AE',
                'Iso3Country' => 'True',
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        System.debug('Phone Validation Response: ' + res.getBody());
        
        if (res.getStatusCode() != 200 || !res.getBody().toLowerCase().contains('valid')) {
            throw new AuraHandledException('Phone number validation failed.');
        }
    }
    
    private static HttpResponse sendPostRequest(String endpoint, String payload) {
        String credentials = OIC_USERNAME + ':' + OIC_PASSWORD;
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(credentials));
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', authHeader);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        
        Http http = new Http();
        return http.send(req);
    }
    
public class BrokerWrapper {
    @AuraEnabled public Id id { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public Datetime appointmentDateTime { get; set; }
    
    // Default constructor
    public BrokerWrapper() {}
    
    // Constructor with id and name (for backward compatibility)
    public BrokerWrapper(Id id, String name) {
        this.id = id;
        this.name = name;
        this.appointmentDateTime = null;
    }
    
    // Constructor with all fields
    public BrokerWrapper(Id id, String name, Datetime appointmentDateTime) {
        this.id = id;
        this.name = name;
        this.appointmentDateTime = appointmentDateTime;
    }
}
    
@AuraEnabled(cacheable=true)
public static List<BrokerWrapper> getAllBrokerAccounts(String searchKey) {
    String key = '%' + searchKey + '%';
    
    Id brokerRTId = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'Account' 
        AND Name = 'Broker Agency'  
        LIMIT 1
    ].Id;
    
    List<Account> brokers = [
        SELECT Id, Name, Appointment_Date_Time__c
        FROM Account
        WHERE RecordTypeId = :brokerRTId 
        AND (Name LIKE :key)
        LIMIT 20
    ];
    
    List<BrokerWrapper> result = new List<BrokerWrapper>();
    for (Account acc : brokers) {
        // Use the new constructor with all three parameters
        result.add(new BrokerWrapper(acc.Id, acc.Name, acc.Appointment_Date_Time__c));
    }
    return result;
}

@AuraEnabled(cacheable=true)
public static List<BrokerWrapper> searchAccounts(String searchKey) {
    String key = '%' + searchKey + '%';

    // Safely get RecordType - use the same logic as getAllBrokerAccounts
    List<RecordType> rtList = [
        SELECT Id 
        FROM RecordType 
        WHERE SObjectType = 'Account' 
        AND Name = 'Broker Agency'
        LIMIT 1
    ];

    if (rtList.isEmpty()) {
        return new List<BrokerWrapper>();
    }

    Id brokerRTId = rtList[0].Id;

    List<Account> brokers = [
        SELECT Id, Name, Appointment_Date_Time__c
        FROM Account
        WHERE RecordTypeId = :brokerRTId 
        AND Name LIKE :key
        LIMIT 20
    ];

    List<BrokerWrapper> result = new List<BrokerWrapper>();
    for (Account acc : brokers) {
        // Use the new constructor with all three parameters
        result.add(new BrokerWrapper(acc.Id, acc.Name, acc.Appointment_Date_Time__c));
    }
    return result;
}
    
    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeadsForSiteUser(String searchKey) {
        String key = '%' + searchKey + '%';
        return [
            SELECT Id, FirstName, LastName, Email, Phone, CreatedDate,Appointment_Date_Time__c
            FROM Lead
            WHERE LeadSource = 'Walk-In'
            //AND Appointment_Date_Time__c = NULL
            AND (FirstName LIKE :key OR LastName LIKE :key OR Email LIKE :key OR Phone LIKE :key)
        ];
    }
    
@AuraEnabled
public static void updateLeadAppointment(Id leadId, Datetime appointmentDateTime) {
    if (leadId == null || appointmentDateTime == null) {
        throw new AuraHandledException('Lead ID and Appointment DateTime are required');
    }
    
    try {
        Lead leadToUpdate = [SELECT Id, Appointment_Date_Time__c FROM Lead WHERE Id = :leadId LIMIT 1];
        leadToUpdate.Appointment_Date_Time__c = appointmentDateTime;
        update leadToUpdate;
    } catch(QueryException e) {
        throw new AuraHandledException('No Lead found with Id: ' + leadId);
    } catch(DmlException e) {
        throw new AuraHandledException('Error updating Lead: ' + e.getMessage());
    } catch(Exception e) {
        throw new AuraHandledException('Unexpected error: ' + e.getMessage());
    }
}
    
    
   @AuraEnabled
public static void updateAccountAppointment(Id brokerId, Datetime appointmentDateTime) {
    if(brokerId == null) {
        throw new AuraHandledException('Broker Account Id is required');
    }

    List<Account> accounts = [SELECT Id, Appointment_Date_Time__c FROM Account WHERE Id = :brokerId ];
    
    if(accounts.isEmpty()) {
        throw new AuraHandledException('No Account found with Id: ' + brokerId);
    }
    
    Account accToUpdate = accounts[0];
    accToUpdate.Appointment_Date_Time__c = appointmentDateTime;
    update accToUpdate;
}

    
}