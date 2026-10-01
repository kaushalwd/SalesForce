/*
* Version       Author                      Date            Comment                                                                       
* 2.0 			Sameer Sewani				16 March 2026   Create a new method and changed the method parameters
*/

public without sharing class MBP_LoqateIntegration {
    
    private static final Modon_Generic_Metadata__mdt CONFIG = Modon_Generic_Metadata__mdt.getInstance('MBP_LoqateIntegration');
    private static final String API_KEY = CONFIG?.Api_Key__c;
    
    public static Boolean isEmailValid(String email) {
        String endpoint = CONFIG?.Endpoint__c;
        
        String payload = JSON.serialize(new Map<String, Object>{
            'Email' => email,
                'Timeout' => 5000,
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        
        // Technical issue = throw so Queueable can mark API Error
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Email validation callout failed with status: ' + res.getStatusCode());
        }
        
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (!jsonResponse.containsKey('Items')) {
            throw new CalloutException('Invalid response structure from Loqate.');
        }
        
        List<Object> items = (List<Object>) jsonResponse.get('Items');
        if (items.isEmpty()) {
            throw new CalloutException('No items found in response.');
        }
        
        Map<String, Object> resultItem = (Map<String, Object>) items[0];
        String responseCode = (String) resultItem.get('ResponseCode');
        
        return new Set<String>{'Valid', 'Valid_CatchAll'}.contains(responseCode);
    }
    
    
    public static void enqueueLeadValidation(List<Lead> leads) {
        
        Set<Id> leadIds = new Set<Id>();
        List<Lead> pendingUpdates = new List<Lead>();
        
        for (Lead l : leads) {
            
            
            leadIds.add(l.Id);
        }
        
        
        
        if (!leadIds.isEmpty()) {
            System.enqueueJob(new MBP_LoqateValidateLeadJob(new List<Id>(leadIds)));
        }
    }    
    @AuraEnabled
    public static String validateLeadEmailAndPhone(Id leadId) {
        Lead l = [
            SELECT Id, Email, MobilePhone, Email_Validated__c,Phone_Validated__c 
            FROM Lead 
            WHERE Id = :leadId
        ];
        
        // Validate Email
        try {
            validateEmail(l.Email);
        } catch (Exception e) {
            return 'EMAIL_INVALID: ' ;
            //+ e.getMessage();
        }
        
        // Validate Phone
        Boolean isPhoneValid = false;
        try {
            isPhoneValid = validatePhone(l.MobilePhone);
        } catch (Exception e) {
            return 'PHONE_INVALID: ' ;
            //+ e.getMessage();
        }
        
        if (!isPhoneValid) {
            return 'PHONE_INVALID: Phone did not pass validation';
        }
        
        // If both valid → update checkbox
        l.Email_Validated__c  = true;
        update l;
        
        return 'SUCCESS';
    }

    @AuraEnabled
    public static String validateLeadEmailAndPhoneNEW(Id leadId) {
        Lead l = [
            SELECT Id, Email, MobilePhone  //,Lead_Validation_Status__c 
            FROM Lead 
            WHERE Id = :leadId
        ];
        
        Boolean emailExists = String.isNotBlank(l.Email);
        Boolean phoneExists = String.isNotBlank(l.MobilePhone);
        Boolean emailValidated = false;
        Boolean phoneValidated = false;
        String emailMessage = '';
        String phoneMessage = '';
        
        // Validate Email if exists
        if (emailExists) {
            try {
                validateEmail(l.Email);
                emailValidated = true;
                emailMessage = 'Email validated successfully';
            } catch (Exception e) {
                emailValidated = false;
                emailMessage = 'Email validation failed: ' + e.getMessage();
            }
        } else {
            emailMessage = 'No email provided';
        }
        
        // Validate Phone if exists
        if (phoneExists) {
            try {
                //phoneValidated = validatePhoneInternational(l.MobilePhone);
                
                
                //V2.0
                MBP_LoqateIntegration.PhoneValidationResult phoneResult = validatePhoneInternational(l.MobilePhone);
                phoneValidated = phoneResult.isValid;
                //V2.0
                
                if (phoneValidated) {
                    phoneMessage = 'Phone validated successfully';
                } else {
                    phoneMessage = 'Phone validation failed: Invalid format';
                }
            } catch (Exception e) {
                phoneValidated = false;
                phoneMessage = 'Phone validation failed: ' + e.getMessage();
            }
        } else {
            phoneMessage = 'No phone provided';
        }
        
        // Determine status based on what's valid
        String status;
        String resultMessage;
        
        if (emailValidated && phoneValidated) {
            status = 'Valid - Email & Phone';
            resultMessage = 'SUCCESS_BOTH';
        } else if (emailValidated) {
            status = 'Valid - Email Only';
            resultMessage = 'SUCCESS_EMAIL_ONLY';
        } else if (phoneValidated) {
            status = 'Valid - Phone Only';
            resultMessage = 'SUCCESS_PHONE_ONLY';
        } else {
            status = 'Pending Validation';
            resultMessage = 'PENDING';
        }
        
        // Update lead with status
        //l.Lead_Validation_Status__c = status;
        update l;
        
        // Return formatted message
        return resultMessage + ':' + emailMessage + '|' + phoneMessage;
    }
    
    
    
    
    
    @AuraEnabled
    public static void validateEmail(String email) {
        String endpoint = '/XXMODON_LOQATE_EMAIL/1.0/loqate/emailvalidation';
        
        String payload = JSON.serialize(new Map<String, Object>{
            'Email' => email,
                'Timeout' => 5000,
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        System.debug('payload--' + payload);
        System.debug('res.getBody()::' + res.getBody());
        System.debug('res.getStatusCode()::' + res.getStatusCode());
        
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Email validation callout failed with status: ' + res.getStatusCode());
        } 
        
        // Parse JSON response
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        system.debug('jsonResponse--'+jsonResponse);
        
        if (!jsonResponse.containsKey('Items')) {
            throw new AuraHandledException('Invalid response structure from Loqate.');
        }
        
        List<Object> items = (List<Object>) jsonResponse.get('Items');
        if (items.isEmpty()) {
            throw new AuraHandledException('No items found in response.');
        }
        
        Map<String, Object> resultItem = (Map<String, Object>) items[0];
        String responseCode = (String) resultItem.get('ResponseCode');
        String responseMessage = (String) resultItem.get('ResponseMessage');
        
        if (!new Set<String>{'Valid', 'Valid_CatchAll'}.contains(responseCode)) {
            throw new AuraHandledException('Email is invalid: ' + responseMessage);
        }
        
    }
    
    @AuraEnabled
    public static Boolean validatePhone(String phone) {
        String endpoint = '/XXMODODN_LOQATE_PHONENUMBER/1.0/loqate/phonenumbervalidation';
        
        String payload = JSON.serialize(new Map<String, Object>{
            'Phone' => phone,
                'Country' => '+971',
                'Iso3Country' => 'True',
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        System.debug('res.getBody()::' + res.getBody());
        
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Phone number validation failed with status: ' + res.getStatusCode());
        }
        
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        String isValid = (String) result.get('IsValid');
        String phoneNumber = (String) result.get('PhoneNumber');
        
        System.debug('"IsValid" : ' + isValid + ', "PhoneNumber" : ' + phoneNumber);
        
        return isValid == 'Yes';
    }
    
    public static HttpResponse sendPostRequest(String endpoint, String payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Loqate_Integration'+endpoint);
        req.setMethod('POST');
        // req.setHeader('Authorization', authHeader);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        
        Http http = new Http();
        return http.send(req);
    }
    
    // NEW: Validate phone for any country - auto-detects country code
    @AuraEnabled
    public static PhoneValidationResult validatePhoneInternational(String phone) {
        String endpoint = '/XXMODODN_LOQATE_PHONENUMBER/1.0/loqate/phonenumbervalidation';
        
        // Detect country code from phone number
        String countryCode = detectCountryCodeFromPhone(phone);
        
        String payload = JSON.serialize(new Map<String, Object>{
            'Phone' => phone,
                'Country' => countryCode,  // Use detected country code
                'Iso3Country' => 'True',
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        System.debug('International phone validation - Phone: ' + phone + ', Country: ' + countryCode);
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        System.debug('International validation response: ' + res.getBody());
        
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Phone number validation failed with status: ' + res.getStatusCode());
        }
        
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        String isValid = (String) result.get('IsValid');
        String phoneNumber = (String) result.get('PhoneNumber');
        
        System.debug('International validation result - IsValid: ' + isValid + ', PhoneNumber: ' + phoneNumber);
        
        
        
        //return isValid == 'Yes';
        return new PhoneValidationResult(isValid == 'Yes', phoneNumber);
        
    }
    
    // NEW: Validate phone with specified country code
    @AuraEnabled
    public static Boolean validatePhoneWithCountry(String phone, String countryCode) {
        String endpoint = '/XXMODODN_LOQATE_PHONENUMBER/1.0/loqate/phonenumbervalidation';
        
        // Default to UAE if no country code provided
        if (String.isBlank(countryCode)) {
            countryCode = '+971';
        }
        
        String payload = JSON.serialize(new Map<String, Object>{
            'Phone' => phone,
                'Country' => countryCode,  // Use provided country code
                'Iso3Country' => 'True',
                'AdditionalFields' => 'True',
                'Key' => API_KEY
                });
        
        System.debug('Phone validation with specified country - Phone: ' + phone + ', Country: ' + countryCode);
        
        HttpResponse res = sendPostRequest(endpoint, payload);
        System.debug('Validation with country response: ' + res.getBody());
        
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Phone number validation failed with status: ' + res.getStatusCode());
        }
        
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        String isValid = (String) result.get('IsValid');
        String phoneNumber = (String) result.get('PhoneNumber');
        
        System.debug('Validation with country result - IsValid: ' + isValid + ', PhoneNumber: ' + phoneNumber);
        
        return isValid == 'Yes';
    }
    
    // Helper method to detect country code from phone number (PRIVATE)
    private static String detectCountryCodeFromPhone(String phone) {
        if (String.isBlank(phone)) {
            return '+971';  // Default to UAE if no phone
        }
        
        // Clean the phone number
        String cleanedPhone = phone.replaceAll('[^+0-9]', '');
        
        // Check for country codes
        if (cleanedPhone.startsWith('+1')) return '+1';      // USA/Canada
        if (cleanedPhone.startsWith('+44')) return '+44';    // UK
        if (cleanedPhone.startsWith('+91')) return '+91';    // India
        if (cleanedPhone.startsWith('+971')) return '+971';  // UAE
        if (cleanedPhone.startsWith('+966')) return '+966';  // Saudi Arabia
        if (cleanedPhone.startsWith('+974')) return '+974';  // Qatar
        if (cleanedPhone.startsWith('+973')) return '+973';  // Bahrain
        if (cleanedPhone.startsWith('+968')) return '+968';  // Oman
        if (cleanedPhone.startsWith('+20')) return '+20';    // Egypt
        if (cleanedPhone.startsWith('+33')) return '+33';    // France
        if (cleanedPhone.startsWith('+49')) return '+49';    // Germany
        if (cleanedPhone.startsWith('+81')) return '+81';    // Japan
        if (cleanedPhone.startsWith('+82')) return '+82';    // South Korea
        if (cleanedPhone.startsWith('+86')) return '+86';    // China
        if (cleanedPhone.startsWith('+61')) return '+61';    // Australia
        if (cleanedPhone.startsWith('+64')) return '+64';    // New Zealand
        if (cleanedPhone.startsWith('+34')) return '+34';    // Spain
        if (cleanedPhone.startsWith('+39')) return '+39';    // Italy
        if (cleanedPhone.startsWith('+7')) return '+7';      // Russia
        if (cleanedPhone.startsWith('+27')) return '+27';    // South Africa
        if (cleanedPhone.startsWith('+55')) return '+55';    // Brazil
        if (cleanedPhone.startsWith('+52')) return '+52';    // Mexico
        if (cleanedPhone.startsWith('+90')) return '+90';    // Turkey
        if (cleanedPhone.startsWith('+92')) return '+92';    // Pakistan
        if (cleanedPhone.startsWith('+60')) return '+60';    // Malaysia
        if (cleanedPhone.startsWith('+62')) return '+62';    // Indonesia
        if (cleanedPhone.startsWith('+63')) return '+63';    // Philippines
        if (cleanedPhone.startsWith('+65')) return '+65';    // Singapore
        if (cleanedPhone.startsWith('+66')) return '+66';    // Thailand
        if (cleanedPhone.startsWith('+84')) return '+84';    // Vietnam
        if (cleanedPhone.startsWith('+41')) return '+41';    // Switzerland
        if (cleanedPhone.startsWith('+46')) return '+46';    // Sweden
        if (cleanedPhone.startsWith('+47')) return '+47';    // Norway
        if (cleanedPhone.startsWith('+48')) return '+48';    // Poland
        if (cleanedPhone.startsWith('+31')) return '+31';    // Netherlands
        if (cleanedPhone.startsWith('+32')) return '+32';    // Belgium
        if (cleanedPhone.startsWith('+351')) return '+351';  // Portugal
        if (cleanedPhone.startsWith('+353')) return '+353';  // Ireland
        if (cleanedPhone.startsWith('+358')) return '+358';  // Finland
        if (cleanedPhone.startsWith('+420')) return '+420';  // Czech Republic
        if (cleanedPhone.startsWith('+421')) return '+421';  // Slovakia
        if (cleanedPhone.startsWith('+370')) return '+370';  // Lithuania
        if (cleanedPhone.startsWith('+371')) return '+371';  // Latvia
        if (cleanedPhone.startsWith('+372')) return '+372';  // Estonia
        if (cleanedPhone.startsWith('+380')) return '+380';  // Ukraine
        if (cleanedPhone.startsWith('+381')) return '+381';  // Serbia
        if (cleanedPhone.startsWith('+385')) return '+385';  // Croatia
        if (cleanedPhone.startsWith('+386')) return '+386';  // Slovenia
        if (cleanedPhone.startsWith('+387')) return '+387';  // Bosnia
        if (cleanedPhone.startsWith('+389')) return '+389';  // North Macedonia
        if (cleanedPhone.startsWith('+40')) return '+40';    // Romania
        if (cleanedPhone.startsWith('+43')) return '+43';    // Austria
        if (cleanedPhone.startsWith('+45')) return '+45';    // Denmark
        if (cleanedPhone.startsWith('+30')) return '+30';    // Greece
        if (cleanedPhone.startsWith('+36')) return '+36';    // Hungary
        if (cleanedPhone.startsWith('+54')) return '+54';    // Argentina
        if (cleanedPhone.startsWith('+56')) return '+56';    // Chile
        if (cleanedPhone.startsWith('+57')) return '+57';    // Colombia
        if (cleanedPhone.startsWith('+58')) return '+58';    // Venezuela
        if (cleanedPhone.startsWith('+51')) return '+51';    // Peru
        if (cleanedPhone.startsWith('+593')) return '+593';  // Ecuador
        if (cleanedPhone.startsWith('+595')) return '+595';  // Paraguay
        if (cleanedPhone.startsWith('+598')) return '+598';  // Uruguay
        if (cleanedPhone.startsWith('+93')) return '+93';    // Afghanistan
        if (cleanedPhone.startsWith('+94')) return '+94';    // Sri Lanka
        if (cleanedPhone.startsWith('+95')) return '+95';    // Myanmar
        if (cleanedPhone.startsWith('+98')) return '+98';    // Iran
        if (cleanedPhone.startsWith('+212')) return '+212';  // Morocco
        if (cleanedPhone.startsWith('+213')) return '+213';  // Algeria
        if (cleanedPhone.startsWith('+216')) return '+216';  // Tunisia
        if (cleanedPhone.startsWith('+218')) return '+218';  // Libya
        if (cleanedPhone.startsWith('+220')) return '+220';  // Gambia
        if (cleanedPhone.startsWith('+221')) return '+221';  // Senegal
        if (cleanedPhone.startsWith('+222')) return '+222';  // Mauritania
        if (cleanedPhone.startsWith('+223')) return '+223';  // Mali
        if (cleanedPhone.startsWith('+224')) return '+224';  // Guinea
        if (cleanedPhone.startsWith('+225')) return '+225';  // Ivory Coast
        if (cleanedPhone.startsWith('+226')) return '+226';  // Burkina Faso
        if (cleanedPhone.startsWith('+227')) return '+227';  // Niger
        if (cleanedPhone.startsWith('+228')) return '+228';  // Togo
        if (cleanedPhone.startsWith('+229')) return '+229';  // Benin
        if (cleanedPhone.startsWith('+230')) return '+230';  // Mauritius
        if (cleanedPhone.startsWith('+231')) return '+231';  // Liberia
        if (cleanedPhone.startsWith('+232')) return '+232';  // Sierra Leone
        if (cleanedPhone.startsWith('+233')) return '+233';  // Ghana
        if (cleanedPhone.startsWith('+234')) return '+234';  // Nigeria
        if (cleanedPhone.startsWith('+235')) return '+235';  // Chad
        if (cleanedPhone.startsWith('+236')) return '+236';  // CAR
        if (cleanedPhone.startsWith('+237')) return '+237';  // Cameroon
        if (cleanedPhone.startsWith('+238')) return '+238';  // Cape Verde
        if (cleanedPhone.startsWith('+239')) return '+239';  // Sao Tome
        if (cleanedPhone.startsWith('+240')) return '+240';  // Equatorial Guinea
        if (cleanedPhone.startsWith('+241')) return '+241';  // Gabon
        if (cleanedPhone.startsWith('+242')) return '+242';  // Congo
        if (cleanedPhone.startsWith('+243')) return '+243';  // DR Congo
        if (cleanedPhone.startsWith('+244')) return '+244';  // Angola
        if (cleanedPhone.startsWith('+245')) return '+245';  // Guinea-Bissau
        if (cleanedPhone.startsWith('+246')) return '+246';  // Diego Garcia
        if (cleanedPhone.startsWith('+247')) return '+247';  // Ascension
        if (cleanedPhone.startsWith('+248')) return '+248';  // Seychelles
        if (cleanedPhone.startsWith('+249')) return '+249';  // Sudan
        if (cleanedPhone.startsWith('+250')) return '+250';  // Rwanda
        if (cleanedPhone.startsWith('+251')) return '+251';  // Ethiopia
        if (cleanedPhone.startsWith('+252')) return '+252';  // Somalia
        if (cleanedPhone.startsWith('+253')) return '+253';  // Djibouti
        if (cleanedPhone.startsWith('+254')) return '+254';  // Kenya
        if (cleanedPhone.startsWith('+255')) return '+255';  // Tanzania
        if (cleanedPhone.startsWith('+256')) return '+256';  // Uganda
        if (cleanedPhone.startsWith('+257')) return '+257';  // Burundi
        if (cleanedPhone.startsWith('+258')) return '+258';  // Mozambique
        if (cleanedPhone.startsWith('+260')) return '+260';  // Zambia
        if (cleanedPhone.startsWith('+261')) return '+261';  // Madagascar
        if (cleanedPhone.startsWith('+262')) return '+262';  // Reunion
        if (cleanedPhone.startsWith('+263')) return '+263';  // Zimbabwe
        if (cleanedPhone.startsWith('+264')) return '+264';  // Namibia
        if (cleanedPhone.startsWith('+265')) return '+265';  // Malawi
        if (cleanedPhone.startsWith('+266')) return '+266';  // Lesotho
        if (cleanedPhone.startsWith('+267')) return '+267';  // Botswana
        if (cleanedPhone.startsWith('+268')) return '+268';  // Swaziland
        if (cleanedPhone.startsWith('+269')) return '+269';  // Comoros
        if (cleanedPhone.startsWith('+290')) return '+290';  // St Helena
        if (cleanedPhone.startsWith('+291')) return '+291';  // Eritrea
        if (cleanedPhone.startsWith('+297')) return '+297';  // Aruba
        if (cleanedPhone.startsWith('+298')) return '+298';  // Faroe Islands
        if (cleanedPhone.startsWith('+299')) return '+299';  // Greenland
        if (cleanedPhone.startsWith('+350')) return '+350';  // Gibraltar
        if (cleanedPhone.startsWith('+352')) return '+352';  // Luxembourg
        if (cleanedPhone.startsWith('+354')) return '+354';  // Iceland
        if (cleanedPhone.startsWith('+355')) return '+355';  // Albania
        if (cleanedPhone.startsWith('+356')) return '+356';  // Malta
        if (cleanedPhone.startsWith('+357')) return '+357';  // Cyprus
        if (cleanedPhone.startsWith('+358')) return '+358';  // Finland
        if (cleanedPhone.startsWith('+359')) return '+359';  // Bulgaria
        if (cleanedPhone.startsWith('+370')) return '+370';  // Lithuania
        if (cleanedPhone.startsWith('+371')) return '+371';  // Latvia
        if (cleanedPhone.startsWith('+372')) return '+372';  // Estonia
        if (cleanedPhone.startsWith('+373')) return '+373';  // Moldova
        if (cleanedPhone.startsWith('+374')) return '+374';  // Armenia
        if (cleanedPhone.startsWith('+375')) return '+375';  // Belarus
        if (cleanedPhone.startsWith('+376')) return '+376';  // Andorra
        if (cleanedPhone.startsWith('+377')) return '+377';  // Monaco
        if (cleanedPhone.startsWith('+378')) return '+378';  // San Marino
        if (cleanedPhone.startsWith('+379')) return '+379';  // Vatican
        if (cleanedPhone.startsWith('+380')) return '+380';  // Ukraine
        if (cleanedPhone.startsWith('+381')) return '+381';  // Serbia
        if (cleanedPhone.startsWith('+382')) return '+382';  // Montenegro
        if (cleanedPhone.startsWith('+383')) return '+383';  // Kosovo
        if (cleanedPhone.startsWith('+385')) return '+385';  // Croatia
        if (cleanedPhone.startsWith('+386')) return '+386';  // Slovenia
        if (cleanedPhone.startsWith('+387')) return '+387';  // Bosnia
        if (cleanedPhone.startsWith('+389')) return '+389';  // North Macedonia
        if (cleanedPhone.startsWith('+420')) return '+420';  // Czech Republic
        if (cleanedPhone.startsWith('+421')) return '+421';  // Slovakia
        if (cleanedPhone.startsWith('+423')) return '+423';  // Liechtenstein
        if (cleanedPhone.startsWith('+880')) return '+880';  // Bangladesh
        if (cleanedPhone.startsWith('+960')) return '+960';  // Maldives
        if (cleanedPhone.startsWith('+961')) return '+961';  // Lebanon
        if (cleanedPhone.startsWith('+962')) return '+962';  // Jordan
        if (cleanedPhone.startsWith('+963')) return '+963';  // Syria
        if (cleanedPhone.startsWith('+964')) return '+964';  // Iraq
        if (cleanedPhone.startsWith('+965')) return '+965';  // Kuwait
        if (cleanedPhone.startsWith('+967')) return '+967';  // Yemen
        if (cleanedPhone.startsWith('+968')) return '+968';  // Oman
        if (cleanedPhone.startsWith('+970')) return '+970';  // Palestine
        if (cleanedPhone.startsWith('+972')) return '+972';  // Israel
        if (cleanedPhone.startsWith('+975')) return '+975';  // Bhutan
        if (cleanedPhone.startsWith('+976')) return '+976';  // Mongolia
        if (cleanedPhone.startsWith('+977')) return '+977';  // Nepal
        if (cleanedPhone.startsWith('+992')) return '+992';  // Tajikistan
        if (cleanedPhone.startsWith('+993')) return '+993';  // Turkmenistan
        if (cleanedPhone.startsWith('+994')) return '+994';  // Azerbaijan
        if (cleanedPhone.startsWith('+995')) return '+995';  // Georgia
        if (cleanedPhone.startsWith('+996')) return '+996';  // Kyrgyzstan
        if (cleanedPhone.startsWith('+998')) return '+998';  // Uzbekistan
        
        // If starts with + but unknown code, use +971
        if (cleanedPhone.startsWith('+')) return '+971';
        
        // If local UAE number (starts with 05)
        if (cleanedPhone.startsWith('05') && cleanedPhone.length() == 10) {
            return '+971';
        }
        
        // Default to UAE
        return '+971';
    }
    
    // NEW: Batch validate multiple phones with country detection
    @AuraEnabled
    //public static Map<String, Boolean> validatePhonesInternational(List<String> phones) {
    
    //V2.0
    public static Map<String, PhoneValidationResult> validatePhonesInternational(List<String> phones) {
        
    //V2.0
        
        //Map<String, Boolean> results = new Map<String, Boolean>();
        
        //V2.0
        Map<String, PhoneValidationResult> results = new Map<String, PhoneValidationResult>();
        
        //V2.0
        
        for (String phone : phones) {
            try {
                results.put(phone, validatePhoneInternational(phone));
            } catch (Exception e) {
                //results.put(phone, false);
                
                //V2.0
                results.put(phone, new MBP_LoqateIntegration.PhoneValidationResult(false, null));
                //V2.0
                
            }
        }
        
        return results;
    }
    
    //V2.0    
    public class PhoneValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String phoneNumber;
        
        public PhoneValidationResult(Boolean isValid, String phoneNumber) {
            this.isValid = isValid;
            this.phoneNumber = phoneNumber;
        }
    }
    //V2.0
    
}