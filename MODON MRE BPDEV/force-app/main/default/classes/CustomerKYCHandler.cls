/**********************************************************************************************************************
* Name               : CustomerKYCHandler                                                        
* Description        : This class is used to handle all the Signzy KYC Automation related Logics
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0          dinesh.selvam@modon.com             11 Nov 2025     Handle the Entire Offers & Collections Automation Changes 
* 2.0          dinesh.selvam@modon.com             05 Apr 2026     Bug fix "EID & Passport" Documents stored in Salesforce hotfix
* 2.1          dinesh.selvam@modon.com             05 Apr 2026     Bug fix "Mobile Validation" & "SOQL Query Fields" Added
* 2.2          dinesh selvam                       05 Apr 2026     Source Of Income values fix & Dynamic folder for documents fix
* 2.3          dinesh selvam                       22 Apr 2026     Re-Send KYC link - Active Link will be resend without creating new
* 2.4          dinesh selvam                       23 Apr 2026     Handle the different label of EID & Passport from response
* 2.5          Arvind                              29 Apr 2026     Fixing re-send signzy link for Expired KYC
* 2.6          Siva                                15 June 2026    Duplicate Placeholders FIX
* 2.7          Siva                                18 June 2026    Duplicate Rules Skipping 
* 2.8          Arvind                              13 Junly 2026   Logic added for get the geo location address
* 2.9          Arvind                              28 July 2026    Journey_Status__c tracking added for customer step drop-off visibility and Fix the Document attchement issue
* 3.0          Arvind                              31 July 2026    Surface Profession_As_Per_EID__c to the LWC via
*                                                                    loadInitialData()/kycWrapper.profession so the
*                                                                    front-end can default Employment Status from the
*                                                                    EID-scanned profession (House Wife, Unemployed,
*                                                                    Student, Retired, Self Employed, Employed).
* 4.0          Rushi Patel                         20 August 2026    Bug Fix to prepopulate Nationality and Residence, added new method to get the DocuSign URL
* 4.2         Arvind                           31 August 2026    Split Signzy "Given Names" into First / Middle name.
* 4.3         Narendra Agrawal                 06 Sep 2026     Trade license API endpoint and Authorization from
*                                                                Modon_Generic_Metadata__mdt by Organization.IsSandbox.
* 4.4         Rushi Patel                      22 Sep 2026     Send the Signzy KYC link over SMS as well as email,
*                                                                via CustomerKYCSmsNotifier / NotificationDispatcher.
**********************************************************************************************************************/
public without sharing class CustomerKYCHandler {
    private static Boolean isSandbox;
    public static String createJourneyURL;
    public static String getJourneyStatusURL;
    public static String authKey;
    public static String OICuserName;
    public static String OICpassword;
    public static String authHeader;

    /** 2.9 Arvind 28 July 2026 - Track journey step navigation for analytics/monitoring (Journey_Status__c) **/
@AuraEnabled
public static void updateJourneyStatus(String kycId, String status){
    try{
        if(kycId == null || status == null){
            return;
        }
        String recordIdStr = EncryptionService.decrypt(kycId);
        Id recordId = (Id)recordIdStr;
        String objectName = recordId.getSObjectType().getDescribe().getName();

        KYC_Response__c kyc = new KYC_Response__c();
        if(objectName == 'Contact'){
            for(KYC_Response__c k : [SELECT Id FROM KYC_Response__c WHERE Contact__c = :recordId ORDER BY CreatedDate DESC LIMIT 1]){
                kyc.Id = k.Id;
            }
        }else{
            for(KYC_Response__c k : [SELECT Id FROM KYC_Response__c WHERE Customer__c = :recordId ORDER BY CreatedDate DESC LIMIT 1]){
                kyc.Id = k.Id;
            }
        }

        if(kyc.Id <> null){
            kyc.Journey_Status__c = status;
            update kyc;
        }
    }catch(Exception ex){
        // Silent by design — this is a non-critical tracking call and must never block or surface errors to the customer
        System.debug('updateJourneyStatus error: '+ex.getMessage());
    }
}
    
    public static final Map<String, String> EXT_TO_MIME = new Map<String, String>{
    'pdf'  => 'application/pdf',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg'
        };

    public static Boolean isSandbox() {
        if (isSandbox == null) {
            isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        }
        return isSandbox;
    }

    static{
        SignzyAPIConfig__c signzyAPIConfig = SignzyAPIConfig__c.getOrgDefaults();
        if(isSandbox()){
            createJourneyURL =  signzyAPIConfig.Journey_Creation_URL_Sandbox__c;
            getJourneyStatusURL =  signzyAPIConfig.Get_Journey_Status_URL_Sandbox__c;
            authKey = signzyAPIConfig.Auth_Token_Sandbox__c;
            OICuserName = signzyAPIConfig.OICUserName_Sandbox__c;
            OICpassword = signzyAPIConfig.OICPassword_Sandbox__c;
        }else{
            createJourneyURL =  signzyAPIConfig.Journey_Creation_URL_Production__c;
            getJourneyStatusURL =  signzyAPIConfig.Get_Journey_Status_URL_Production__c;
            authKey = signzyAPIConfig.Auth_Token_Production__c;
            OICuserName = signzyAPIConfig.OICUserName_Production__c;
            OICpassword = signzyAPIConfig.OICPassword_Production__c;
        }
    }

    // 4.3: OIC host + Basic auth from CMDT. Sandbox uses SignzyOICCredentials; production uses the new record.
    private static OIC_Credential__mdt getSignzyOicCredential() {
        String developerName = isSandbox()
            ? System.Label.SignzyOICCredentials
            : 'SignzyCreateJourneyOIC_Production';
        return [
            SELECT Endpoint__c, Username__c, Password__c, Method__c
            FROM OIC_Credential__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static String loadInitialData(String kycId){
        String recordIdStr = EncryptionService.decrypt(kycId);
        Id recordId = (Id)recordIdStr;
        
        String objectName = recordId.getSObjectType().getDescribe().getName();
        System.debug('objectName::'+objectName);
        List<KYC_Response__c> kycResList = new List<KYC_Response__c>();
        if(objectName =='Contact'){
            kycResList = [SELECT Id,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Profession_As_Per_EID__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,MiddleName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Contact__r.Account.Is_Trade_License_Uploaded__c,Signzy_Journey_Status__c,
                          Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,contact__r.Is_KYC_Link_Active__c,contact__r.KYC_Link_Status__c, Journey_Status__c, Residential_Country__c FROM KYC_Response__c WHERE Contact__c = :recordId ORDER BY CreatedDate DESC LIMIT 1 ];
                          // Added Residential_Country__c - Rushi Patel - 20th August 2026
                          // 4.2 Added MiddleName__c - <Arvind> - 31 August 2026
            
        }
        if(objectName !='Contact'){
            kycResList = [SELECT Id,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Profession_As_Per_EID__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,MiddleName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Signzy_Journey_Status__c,
                          Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,Customer__r.Is_KYC_Link_Active__c,Customer__r.KYC_Link_Status__c, Journey_Status__c, Residential_Country__c FROM KYC_Response__c WHERE Customer__c = :recordId ORDER BY CreatedDate DESC LIMIT 1 ];
                          // Added Residential_Country__c - Rushi Patel - 20th August 2026
                          // 4.2 Added MiddleName__c - <Arvind> - 31 August 2026
        }            
        if(!kycResList.isEmpty()){ // Updated logic to show correct page on LWC based on Journey Status - Rushi Patel - 20th August 2026
            if(kycResList[0].Journey_Status__c == 'DocuSign Signature Complete'){
                return 'COMPLETED';
            }
            if(kycResList[0].Signzy_Journey_Status__c == 'COMPLETED' && kycResList[0].Journey_Status__c == 'KYC Data Submitted - Signing Session Starting'){
                return 'DOCUSIGN_PENDING';
            }
            if(kycResList[0].Signzy_Journey_Status__c == 'ABANDONED' || kycResList[0].Signzy_Journey_Status__c == 'TERMINATED'){
                return 'error';
            }
            String message = getSignzyJourney(kycResList[0].Id);
            System.debug('message::'+message);
            kycResList = new List<KYC_Response__c>();
            if(objectName =='Contact'){
                kycResList = [SELECT Id,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Profession_As_Per_EID__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,MiddleName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Contact__r.Account.Is_Trade_License_Uploaded__c,Contact__r.UAE_Resident_Status__c,
                              Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,contact__r.Is_KYC_Link_Active__c,contact__r.KYC_Link_Status__c,contact__r.Nationality__c, Residential_Country__c FROM KYC_Response__c WHERE Contact__c = :recordId ORDER BY CreatedDate DESC LIMIT 1 ];
                
            }
            if(objectName !='Contact'){
                kycResList = [SELECT Id,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Profession_As_Per_EID__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,MiddleName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Customer__r.UAE_Resident_Status__pc,Customer__r.Nationality__pc,
                              Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,Customer__r.Is_KYC_Link_Active__c,Customer__r.KYC_Link_Status__c, Residential_Country__c FROM KYC_Response__c WHERE Customer__c = :recordId ORDER BY CreatedDate DESC LIMIT 1 ];
            }
            for(KYC_Response__c kycObj: kycResList){
                kycWrapper kyc = new kycWrapper();
                kyc.emirate = kycObj.Resident_Emirates__c;
                // kyc.residentStatus =  objectName == 'Contact' ? kycObj.contact__r.UAE_Resident_Status__c : kycObj.Customer__r.UAE_Resident_Status__pc;
                kyc.nationality = objectName == 'Contact' ? kycObj.contact__r.Nationality__c : kycObj.Customer__r.Nationality__pc;
                kyc.dualNationality = kycObj.Dual_Citizen__c;
                kyc.pepStatus = kycObj.Is_Politically_Exposed__c ? 'Yes':'No';
                kyc.dualNationalityCountry = kycObj.Other_Nationality_If_Applicable__c;
                kyc.street = kycObj.Street__c;
                kyc.city = kycObj.City__c;
                kyc.state = kycObj.State__c;
                kyc.postalCode = kycObj.Postal_Code__c;
                kyc.country = kycObj.Residential_Country__c; // Added to prepopulate Country on LWC Form - Rushi Patel - 20th August 2026
                kyc.middleName = kycObj.MiddleName__c; // 4.2 <Arvind> 31 August 2026
                kyc.employmentStatus = kycObj.Employment_Status__c;
                kyc.position = kycObj.Position__c;
                kyc.companyName = kycObj.EID_Sponsor__c <> null ? kycObj.EID_Sponsor__c : kycObj.Company_Name__c;
                kyc.eidSponsorName = kycObj.EID_Sponsor__c;
                // 3.0 Arvind 31 July 2026 - surface EID Profession to the LWC so it can default
                // Employment Status (House Wife / Unemployed / Student / Retired / Self Employed / Employed)
                kyc.profession = kycObj.Profession_As_Per_EID__c;
                kyc.sourceOfIncome = kycObj.Source_of_Income__c;
                kyc.otherSourceOfIncome = kycObj.Other_Source_Of_Income__c;
                kyc.salaryrange = kycObj.Salary__c;
                if(objectName !='Contact'){
                    kyc.isKycExpired = kycObj.Customer__r.Is_KYC_Link_Active__c;
                    kyc.kycCompleted = kycObj.Customer__r.KYC_Link_Status__c == 'COMPLETED' ? true:false;
                    kyc.isCorporateAccount = false;
                }else if(objectName =='Contact'){
                    kyc.isKycExpired = kycObj.Contact__r.Is_KYC_Link_Active__c;
                    kyc.kycCompleted = kycObj.Contact__r.KYC_Link_Status__c == 'COMPLETED' ? true:false;
                    kyc.isCorporateAccount = true;
                    kyc.IsTradeLicenseUploaded = kycObj.Contact__r.Account.Is_Trade_License_Uploaded__c;
                }
                return JSON.serialize(kyc);
            }
            return null;
        }else if(recordId <> null && objectName !='Contact'){
            for(Account acc : [SELECT Id,FirstName,MiddleName,LastName,UAEResident__c,Nationality__pc,AreYouPoliticallyExposedPersonPEP__pc,PersonMailingCity,personMailingStreet,personMailingState,personMailingPostalCode,Occupation__pc,
                               EmployerBusinessName__pc,SourceOfIncome__pc,OtherSourceOfIncome__pc,Is_KYC_Link_Active__c,Salary_Range__c,Employment_Status__c,Resident_Emirates__c FROM Account WHERE Id =:recordId]){
                                   kycWrapper kyc = new kycWrapper();
                                   kyc.emirate = acc.Resident_Emirates__c;
                                   kyc.firstName = acc.firstName;
                                   kyc.middleName = acc.MiddleName; // 4.2 <Arvind> 31 August 2026
                                   kyc.lastName = acc.lastName;
                                   kyc.nationality = acc.Nationality__pc;
                                   kyc.dualNationality ='No';
                                   kyc.pepStatus = acc.AreYouPoliticallyExposedPersonPEP__pc ? 'Yes':'No';
                                   kyc.street = acc.personMailingStreet;
                                   kyc.city = acc.PersonMailingCity;
                                   kyc.state = acc.personMailingState;
                                   kyc.postalCode = acc.personMailingPostalCode;
                                   kyc.employmentStatus = acc.Employment_Status__c;
                                   kyc.position = acc.Occupation__pc;
                                   kyc.companyName = acc.EmployerBusinessName__pc;
                                   kyc.sourceOfIncome = acc.SourceOfIncome__pc;
                                   kyc.otherSourceOfIncome = acc.OtherSourceOfIncome__pc;
                                   kyc.salaryrange =  acc.Salary_Range__c;
                                   kyc.isKycExpired = true;
                                   kyc.kycCompleted = false;
                                   kyc.isCorporateAccount = false;
                                   kyc.IsTradeLicenseUploaded = false;
                                   return JSON.serialize(kyc);
                               }
            return null;
            
        }else if(recordId <> null && objectName == 'Contact'){
            for(Contact con:[SELECT Id,FirstName,MiddleName,LastName,Nationality__c,AreYouPoliticallyExposedPersonPEP__c,Occupation__c,MailingCity,MailingStreet,MailingPostalCode,MailingState,MailingCountry,
                             EmployerBusinessName__c,SourceOfIncome__c,OtherSourceOfIncome__c,UAE_Resident_Status__c,Account.Is_Trade_License_Uploaded__c FROM Contact WHERE Id =:recordId]){
                                 kycWrapper kyc = new kycWrapper();
                                 kyc.emirate = con.MailingCity;
                                 kyc.firstName = con.firstName;
                                 kyc.middleName = con.MiddleName; // 4.2 <Arvind> 31 August 2026
                                 kyc.lastName = con.lastName;
                                 kyc.nationality = con.Nationality__c;
                                 kyc.pepStatus = con.AreYouPoliticallyExposedPersonPEP__c ? 'Yes':'No';
                                 kyc.street = con.MailingStreet;
                                 kyc.city = con.MailingCity;
                                 kyc.state = con.MailingState;
                                 kyc.postalCode = con.MailingPostalCode;
                                 kyc.isKycExpired = true;
                                 kyc.kycCompleted = false;
                                 kyc.isCorporateAccount = true;
                                 kyc.IsTradeLicenseUploaded = con.Account.Is_Trade_License_Uploaded__c;
                                 return JSON.serialize(kyc);
                                 
                             }
        }
        return null;
    }
    @AuraEnabled
    public static String handleCustomerEarlyData(String customerInfo,String recordId){
        try{
            system.debug('recordId:'+recordId);
            system.debug('customerInfo:'+customerInfo);
            if(recordId <> null && customerInfo <> null){
                kycWrapper kWrap = (kycWrapper) JSON.deserialize(customerInfo,kycWrapper.class);
                system.debug('kWrap:'+kWrap);
                Id recordIdval = EncryptionService.decrypt(recordId);
                String objectName = recordIdval.getSObjectType().getDescribe().getName();
                if(recordIdval <> null){
                    KYC_Response__c kyc = new KYC_Response__c();
                    if(objectName == 'Contact'){
                        for(KYC_Response__c kycId:[SELECT Id FROM KYC_Response__c WHERE Contact__c =:recordIdval ORDER BY CreatedDate DESC LIMIT 1]){
                            kyc.Id = kycId.Id;
                        }
                    }else if(objectName =='Account'){
                        for(KYC_Response__c kycId:[SELECT Id FROM KYC_Response__c WHERE Customer__c =:recordIdval ORDER BY CreatedDate DESC LIMIT 1]){
                            kyc.Id = kycId.Id;
                        }
                    }
                    
                    kyc.City__c = kWrap.city;
                    kyc.Street__c = kWrap.street;
                    kyc.State__c = kWrap.state <> null && kWrap.state <> '' ? kWrap.state : kWrap.emirate;
                    kyc.Postal_Code__c = kWrap.postalCode;
                    kyc.Residential_Country__c = kWrap.country;
                    kyc.Employment_Status__c = kWrap.employmentStatus;
                    kyc.Source_of_Income__c =  kWrap.sourceOfIncome;
                    kyc.Other_Source_Of_Income__c = kWrap.otherSourceOfIncome;
                    kyc.Position__c =  kWrap.position;
                    kyc.Company_Name__c =  kWrap.companyName <> null ? kWrap.companyName: kwrap.OrgcompanyName;
                    kyc.Other_Nationality_If_Applicable__c = kWrap.dualNationalityCountry;
                    kyc.Salary__c = kWrap.salaryrange;
                    kyc.Resident_Emirates__c = kWrap.emirate;
                    kyc.Dual_Citizen__c = kwrap.dualNationality;
                    upsert kyc;
                    
                    if(objectName == 'Contact'){
                        Account acc = new Account();
                        acc.Id = [SELECT AccountId FROM Contact WHERE Id =:recordIdval LIMIT 1].AccountId;
                        acc.Company_Name_as_per_Trade_License__c = kwrap.OrgcompanyName;
                        acc.TradeLicenseNumber__c = kwrap.tradeLicenseNumber;
                        acc.TradeLicenseExpiryDate__c = kwrap.tradeLicenseExpiryDate;
                        acc.Company_Country_Of_Origin__c = kwrap.countryAddr;
                        acc.Nature_Of_Business__c = kwrap.natureBusiness;
                        acc.LegalStructure__c = kwrap.LegalStructure;
                        acc.Company_Address__c = kwrap.bussinessAddr;
                        //Duplicate Issue Fix
                        Database.DMLOptions dmlOptions = new Database.DMLOptions();
                        dmlOptions.DuplicateRuleHeader.allowSave = true;
                        Database.SaveResult sr = Database.update(acc, dmlOptions);
                      //  update acc;
                    }
                    
                    Set<Id> kycIdset = new Set<Id>();
                    Set<Id> corporatekycIdset = new Set<Id>();
                    for(KYC_Response__c kycObj:[SELECT Id,Customer__c,Contact__c,Signzy_Journey_Status__c FROM KYC_Response__c WHERE Id =:kyc.Id]){
                        if(kycObj.Customer__c <> null && kycObj.Contact__c == null){// && kycObj.Signzy_Journey_Status__c == 'COMPLETED'){
                            kycIdset.add(kycObj.Id);
                        }
                        if(kycObj.Contact__c <> null && kycObj.Customer__c == null){
                            corporatekycIdset.add(kycObj.Id);
                        }
                    }
                    if(!kycIdset.isEmpty()){
                        return updateKycInfoToAccount(kycIdset);
                    }
                    if(!corporatekycIdset.isEmpty()){
                        updateKycInfoToContact(corporatekycIdset);
                    }
                }
            }
        }catch(Exception ex){
            LoggerService.createApexLog(ex,'SignzyKYC','CustomerKYCHandler','handleCustomerEarlyData');
            return null;
        }
        return null;
    }
    @future
    public static void updateDraftKYCData(Id recordId,String journeyUrl,String journeyId,String response, decimal expireyValidity){
        if(recordId <> null){
            String objectName = recordId.getSObjectType().getDescribe().getName();
            if(recordId <> null){
                Id recordTypeId = Schema.SObjectType.KYC_Response__c.getRecordTypeInfosByDeveloperName().get('Individual_KYC').getRecordTypeId();
                
                KYC_Response__c kyc = new KYC_Response__c();
                kyc.recordTypeId = recordTypeId;
                if(objectName == 'Contact'){
                    kyc.Contact__c = recordId;
                }else{
                    kyc.Customer__c = recordId;
                }
                kyc.Signzy_Journey_ID__c = journeyId;
                kyc.SignzyURL__c = journeyUrl;
                kyc.KYC_Send_By__c = UserInfo.getUserId();
                kyc.Signzy_Journey_Status__c  = 'IN PROGRESS';
                upsert kyc;
                
                List<KYC_Response__c> closeRestOfJourney = new List<KYC_Response__c>();
                for(KYC_Response__c kycRes:[SELECT Id FROM KYC_Response__c WHERE Id !=: kyc.Id AND (Signzy_Journey_Status__c  = 'IN PROGRESS' OR Signzy_Journey_Status__c  = '') AND (Contact__c =: recordId OR Customer__c =: recordId)]){
                    KYC_Response__c kycRes1 = new KYC_Response__c();
                    kycRes1.Id = kycRes.Id;
                    kycRes1.Signzy_Journey_Status__c = 'CLOSED BY USER';
                    closeRestOfJourney.add(kycRes1);
                }
                update closeRestOfJourney;
                if(objectName != 'Contact'){
                    Account acc = new Account();
                    acc.Id = recordId;
                    acc.KYC_Send_Date_Time__c = DateTime.now();
                    acc.KYC_Expiry_Time_in_Seconds__c = expireyValidity <> null ? expireyValidity :0;
                    acc.SignzyURL__c = journeyUrl;
                    acc.Signzy_Journey_Status__c = 'IN PROGRESS';
                     //Duplicate Issue Fix
                    Database.DMLOptions dmlOptions = new Database.DMLOptions();
                    dmlOptions.DuplicateRuleHeader.allowSave = true;
                    Database.SaveResult sr = Database.update(acc, dmlOptions);
                   // update acc;  
                }else if(objectName == 'Contact'){
                    Contact con = new Contact();
                    con.Id = recordId;
                    con.KYC_Send_Date_Time__c = DateTime.now();
                    con.KYC_Expiry_Time_in_Seconds__c = expireyValidity <> null ? expireyValidity :0;
                    con.SignzyURL__c = journeyUrl;
                    con.Signzy_Journey_Status__c = 'IN PROGRESS';
                    //Duplicate Issue Fix
                    Database.DMLOptions dmlOptions = new Database.DMLOptions();
                    dmlOptions.DuplicateRuleHeader.allowSave = true;
                    Database.SaveResult sr = Database.update(con, dmlOptions);
                    //update con;  
                }
                createFileLog(kyc.Id,response,'createSignzy-journey-'+datetime.now());
            }
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<PicklistOption>> getRequiredPicklists() {
        Map<String, List<PicklistOption>> picklistMap = new Map<String, List<PicklistOption>>();
        
        // Call the same helper method for each picklist you need
        picklistMap.put('nationalityOptions', getPicklistOptions('Account', 'Nationality__pc'));
        picklistMap.put('employmentOptions', getPicklistOptions('Account', 'Employment_Status__c'));
        picklistMap.put('incomeSourceOptions', getPicklistOptions('Account', 'SourceOfIncome__c'));
        picklistMap.put('salaryRangeOptions', getPicklistOptions('Account', 'Salary_Range__c'));
        picklistMap.put('legalTypeOptions', getPicklistOptions('Account', 'LegalStructure__c'));
        picklistMap.put('occupationOptions', getEmployementOccupationValues());        
        return picklistMap;
    }
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getNationalityPicklistValues() {
        return getPicklistOptions('Account', 'Nationality__pc');
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getEmployementStatusPicklistValues() {
        return getPicklistOptions('Account', 'Employment_Status__c');
    }
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getEmployementOccupationValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        List<String> optionsVal = System.Label.CustomerOccupations.contains(',') ? System.Label.CustomerOccupations.split(',') : new List<String>{System.Label.CustomerOccupations};
            if(optionsVal <> null){
                for(String s: optionsVal){
                    options.add(new PicklistOption(s,s));  
                } 
            }
        return options;
    }
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getIncomeSourcePicklistValues() {
        return getPicklistOptions('Account', 'SourceOfIncome__pc');
    }
    
    @AuraEnabled
    public static List<PicklistOption> getSourceOfIncomePicklistValues(String employmentSts) {
        List<PicklistOption> options = new List<PicklistOption>();
        
        List<String> optionsVal = mapSourceOfIncome(employmentSts);
        if(optionsVal <> null){
            for(String s: optionsVal){
                options.add(new PicklistOption(s,s));  
            } 
        }
        return options;
    }
    
    // This single method does all the work dynamically
    private static List<PicklistOption> getPicklistOptions(String objectName, String fieldName) {
        List<PicklistOption> options = new List<PicklistOption>();
        try {
            // Use dynamic Apex to describe any field
            SObjectType schemaType = Schema.getGlobalDescribe().get(objectName);
            Map<String, Schema.SObjectField> fieldMap = schemaType.getDescribe().fields.getMap();
            Schema.DescribeFieldResult fieldResult = fieldMap.get(fieldName).getDescribe();
            
            // The rest of the logic is the same
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for (Schema.PicklistEntry p : ple) {
                options.add(new PicklistOption(p.getLabel(), p.getValue()));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving picklist for ' + fieldName + ': ' + e.getMessage());
        }
        return options;
    }
    
    // You need this simple wrapper class for the return type
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    public static String createSignzyJourney(String recordId){
        String Nationality, ResidencyStatus;
        OIC_Credential__mdt config = getSignzyOicCredential(); // 4.3
      //  String endpoint = config.Endpoint__c; // 4.3: sandbox vs production from OIC_Credential__mdt
        String endpoint ='https://modonprod-modonfusioncloud.integration.eu-frankfurt-1.ocp.oraclecloud.com'; // //***FOR LIVE TESTING*** config.Endpoint__c; //
        


        String objectName = ((Id)recordId).getSObjectType().getDescribe().getName();
        if(objectName != 'Contact'){
            Account accOBJ = [SELECT Id,SignzyURL__c,KYC_Expiry_Time_in_Seconds__c,Not_Required_Multidocument_Auth_UAE__c,UAE_Resident_Status__pc,Nationality__pc FROM Account WHERE Id=:recordId LIMIT 1];
            Nationality = accOBJ.Nationality__pc;
            ResidencyStatus = accOBJ.UAE_Resident_Status__pc == 'Non-Resident' ? 'International' : 'Resident';
        }else if(objectName == 'Contact'){
            Contact con = [SELECT Id,SignzyURL__c,KYC_Expiry_Time_in_Seconds__c,Not_Required_Multidocument_Auth_UAE__c,UAE_Resident_Status__c,Nationality__c FROM Contact WHERE Id=:recordId LIMIT 1];
            Nationality = con.Nationality__c;
            ResidencyStatus = con.UAE_Resident_Status__c == 'Non-Resident' ? 'International' : 'Resident';
        }
        List<Signzy_Journey__mdt> journeyList = new List<Signzy_Journey__mdt>();
        Signzy_Journey__mdt journey;
        
        system.debug('nationality:'+Nationality);
        system.debug('residentStatus:'+ResidencyStatus);
        if(Nationality <> null && ResidencyStatus == 'International'){
            journeyList = [SELECT Id,Journey_Type__c,Expiry_Validity_in_Seconds__c,Signzy_Flow_ID__c,Defaul_Document__c,Session_Expiry_Validity__c,Secondary_Document__c,country__c FROM Signzy_Journey__mdt WHERE MasterLabel  = 'Global KYC' LIMIT 1];
            if(journeyList.isEmpty()){
                journeyList = [SELECT Id,Journey_Type__c,Expiry_Validity_in_Seconds__c,Signzy_Flow_ID__c,Defaul_Document__c,Session_Expiry_Validity__c,Secondary_Document__c,country__c FROM Signzy_Journey__mdt WHERE MasterLabel  = 'Global KYC' LIMIT 1];
            }
        }
        system.debug('journeyList:'+journeyList);
        if(!journeyList.isEmpty()){
            journey =  journeyList[0];
        }else{
            if(objectName != 'Contact'){
                Account accOBJ = [SELECT Id,SignzyURL__c,KYC_Expiry_Time_in_Seconds__c,Not_Required_Multidocument_Auth_UAE__c FROM Account WHERE Id=:recordId LIMIT 1];
                if(accOBJ.Not_Required_Multidocument_Auth_UAE__c){
                    journey = [SELECT Id,Journey_Type__c,Expiry_Validity_in_Seconds__c,Signzy_Flow_ID__c,Defaul_Document__c,Session_Expiry_Validity__c,Secondary_Document__c,country__c FROM Signzy_Journey__mdt WHERE Default_Journey__c = true LIMIT 1];
                }else{
                    journey = [SELECT Id,Journey_Type__c,Expiry_Validity_in_Seconds__c,Signzy_Flow_ID__c,Defaul_Document__c,Session_Expiry_Validity__c,Secondary_Document__c,country__c FROM Signzy_Journey__mdt WHERE Multi_Document_Authentication__c  = true LIMIT 1];
                }
            }else if(objectName == 'Contact'){
                Contact con = [SELECT Id,SignzyURL__c,KYC_Expiry_Time_in_Seconds__c,Not_Required_Multidocument_Auth_UAE__c FROM Contact WHERE Id=:recordId LIMIT 1];
                if(con.Not_Required_Multidocument_Auth_UAE__c){
                    journey = [SELECT Id,Journey_Type__c,Expiry_Validity_in_Seconds__c,Signzy_Flow_ID__c,Defaul_Document__c,Session_Expiry_Validity__c,Secondary_Document__c,country__c FROM Signzy_Journey__mdt WHERE Default_Journey__c = true LIMIT 1];
                }else{
                    journey = [SELECT Id,Journey_Type__c,Expiry_Validity_in_Seconds__c,Signzy_Flow_ID__c,Defaul_Document__c,Session_Expiry_Validity__c,Secondary_Document__c,country__c FROM Signzy_Journey__mdt WHERE Multi_Document_Authentication__c  = true LIMIT 1];
                }
            }
        }
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();
        String body = generateSignzyCreateJourneyRequest(recordId,journey);
        System.debug('body:'+body);
        request.setMethod('POST');
        //request.setEndPoint(createJourneyURL);
        request.setEndPoint(endpoint+'/'+createJourneyURL.trim());
        request.setBody(body);
        request.setTimeout(12000);
        request.setHeader('Content-Type','application/json');
        request.setHeader('Authorization', 'Basic ' +EncodingUtil.base64Encode(Blob.valueOf(config.Username__c + ':' + config.Password__c)));
        
        // request.setHeader('Authorization',authKey);
        Http http = new Http();
        response = http.send(request);
        System.debug('response:'+response.getbody());
        if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
            JourneyResponseWrapper responseWrap = (JourneyResponseWrapper) JSON.deserialize(response.getBody(),JourneyResponseWrapper.class);
            if(responseWrap <> null && responseWrap.result <> null){
                updateDraftKYCData(recordId,responseWrap.result.journeyUrl,responseWrap.result.journeyId,response.getBody(),journey.Expiry_Validity_in_Seconds__c);
                return responseWrap.result.journeyUrl;
            }
        }else{
            updateDraftKYCData(recordId,null ,null,response.getBody(),journey.Expiry_Validity_in_Seconds__c);
            CustomerKYCErrorLogHelper.logErrorHandler(null,null,'Signzy Process','CustomerKYCHandler','getSignzyStatus',null,response.getBody());

        }
        return null;
    }
    public static String generateSignzyCreateJourneyRequest(String accountId,Signzy_Journey__mdt journey){
        String objectName = ((Id)accountId).getSObjectType().getDescribe().getName();
        SignzyFlowRequestWrapper requestWrapper = new SignzyFlowRequestWrapper();
        // 4.3: sandbox uses Signzy_Journey__mdt; production uses the live Signzy flow
        if (isSandbox()) {
           // requestWrapper.flowId = 'a6b56853-2a3b-477d-8c3b-ea96d94cc08a';  //Hard Coded flow Id for testing into sandbox
            //requestWrapper.flowId = '047cb62e-ecfa-4e32-8b0a-254507da6f04'; //Some more flow Id for testing into sandbox
            requestWrapper.flowId = 'd9c19bf0-72f2-4030-86d7-ec7ece455ac9'; //Some more flow Id for testing into sandbox
        } else {
            requestWrapper.flowId = journey.Signzy_Flow_ID__c;  //For production it should come from journey
        }

        requestWrapper.userId = System.Label.SignzyUserID;
        SignzyFlowRequestWrapper.ProcessingConfig pConfig = new SignzyFlowRequestWrapper.ProcessingConfig();
        SignzyFlowRequestWrapper.UserInfo userInfo = new SignzyFlowRequestWrapper.UserInfo();
        SignzyFlowRequestWrapper.IDInfoCls idInfo = new SignzyFlowRequestWrapper.IDInfoCls();
        if(journey.Defaul_Document__c <> null){
            //idInfo.idType = journey.Defaul_Document__c;
            //idInfo.country = journey.country__c;
            userInfo.id = idInfo;
            requestWrapper.userInfo = userInfo;
        }
        if(journey.Secondary_Document__c <> null){
            //idInfo.idType2 = journey.Secondary_Document__c;
 		}
        
        pConfig.journeyLinkValidity = journey.Expiry_Validity_in_Seconds__c <> null ? integer.valueOf(journey.Expiry_Validity_in_Seconds__c):null;
        pConfig.journeySessionExpiry = journey.Session_Expiry_Validity__c <> null ? integer.valueOf(journey.Session_Expiry_Validity__c):3600;
        pConfig.redirectTime = 0;
        if(objectName == 'Contact'){
            for(Contact con:[SELECT Id,KYC_Site_Link__c,Nationality__c,UAE_Resident_Status__c FROM Contact WHERE Id=:accountId]){
                pConfig.successRedirectUrl = con.KYC_Site_Link__c+EncryptionService.encrypt(accountId);
                pConfig.failureRedirectUrl = System.Label.SignzyErrorURL+EncryptionService.encrypt(accountId);
                if(con.Nationality__c == 'United Arab Emirates'){
                    //idInfo.idType2 = 'Passport';
                   // idInfo.country = 'AE';
                   // idInfo.idType = 'Resident Id Card';
                }else if(con.UAE_Resident_Status__c == 'Resident'){
                    //idInfo.idType2 = 'International Passport';
                    //idInfo.country = 'AE';
                    //idInfo.idType = 'Resident Id Card'; 
                }
            }
        }else{
            for(Account acc:[SELECT Id,KYC_Site_Link__pc,Nationality__pc,UAE_Resident_Status__pc FROM Account WHERE Id=:accountId]){
                pConfig.successRedirectUrl = acc.KYC_Site_Link__pc+EncryptionService.encrypt(accountId);
                pConfig.failureRedirectUrl = System.Label.SignzyErrorURL+EncryptionService.encrypt(accountId);
                if(acc.Nationality__pc == 'United Arab Emirates'){
                   // idInfo.idType2 = 'Passport';
                   // idInfo.country = 'AE';
                  //  idInfo.idType = 'Resident Id Card';
                }else if(acc.UAE_Resident_Status__pc == 'Resident'){
                   // idInfo.idType2 = 'International Passport';
                   // idInfo.country = 'AE';
                   // idInfo.idType = 'Resident Id Card'; 
                }
            }
        }
        requestWrapper.processingConfig = pConfig;
        return JSON.serialize(requestWrapper,true);
    }
    @AuraEnabled
    public static void getErrorSignzyJourney(String KycId){
        try{
        String recordIdStr = EncryptionService.decrypt(KycId);
        Id recordId = (Id)recordIdStr;
        Id kycRecordId = null;
        system.debug('recordId::'+recordId);
        String objectName = recordId.getSObjectType().getDescribe().getName();
        system.debug('objectName::'+objectName);
        if(objectName == 'Contact'){
            kycRecordId = [SELECT Id,Signzy_Journey_ID__c FROM KYC_Response__c WHERE Contact__c =:recordId ORDER BY CreatedDate DESC LIMIT 1].Id;
        }else{
            kycRecordId = [SELECT Id,Signzy_Journey_ID__c FROM KYC_Response__c WHERE Customer__c =:recordId ORDER BY CreatedDate DESC LIMIT 1].Id;
        }
        if(kycRecordId <> null){
            getSignzyJourney(kycRecordId);
        }
        }catch(Exception ex){}
    }
    @AuraEnabled
    public static String getSignzyJourney(Id kycId){
        String JourneyID = [SELECT Id,Signzy_Journey_ID__c FROM KYC_Response__c WHERE Id =:kycId LIMIT 1].Signzy_Journey_ID__c;
        return invokeSignzyJourneyStatusAPI(kycId,JourneyID);
        
    }
    public static String invokeSignzyJourneyStatusAPI(Id kycId,String signzyJourneyID){
        OIC_Credential__mdt config = getSignzyOicCredential(); // 4.3
       // String endpoint = config.Endpoint__c; // 4.3: sandbox vs production from OIC_Credential__mdt
                String endpoint ='https://modonprod-modonfusioncloud.integration.eu-frankfurt-1.ocp.oraclecloud.com'; // //***FOR LIVE TESTING*** config.Endpoint__c; //


        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();
        request.setMethod('GET');
        //request.setEndPoint(getJourneyStatusURL+'/'+signzyJourneyID);
        request.setEndPoint(endpoint.trim()+'/'+getJourneyStatusURL.trim()+signzyJourneyID);
        request.setTimeout(12000);
        request.setHeader('Authorization', 'Basic ' +EncodingUtil.base64Encode(Blob.valueOf(config.Username__c + ':' + config.Password__c)));
        
        Http http = new Http();
        response = http.send(request);
        if (response.getStatusCode() == 301 || response.getStatusCode() == 302) {
            String newUrl = response.getHeader('Location');
            request.setEndpoint(newUrl); 
            response = http.send(request); 
            System.debug(response.getBody());
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String oneLineJson = JSON.serialize(result); 
                String jsonBody = parse(oneLineJson);
                System.debug('res1:'+jsonBody);
                createFileLog(kycId,jsonBody,'SignzyGetStatus'+datetime.now());
                SignzyJourneyStatusWrapper statusWrapper = (SignzyJourneyStatusWrapper) JSON.deserialize(jsonBody,SignzyJourneyStatusWrapper.class);
                System.debug(statusWrapper);
                if(statusWrapper <> null && statusWrapper.result <> null){
                    return mapSignzyJourneyData(kycId,statusWrapper);
                }
            }
        }else if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
            
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String oneLineJson = JSON.serialize(result); 
            String jsonBody = parse(oneLineJson);
            System.debug('res1:'+jsonBody);
            createFileLog(kycId,jsonBody,'SignzyGetStatus'+datetime.now());
            SignzyJourneyStatusWrapper statusWrapper = (SignzyJourneyStatusWrapper) JSON.deserialize(jsonBody,SignzyJourneyStatusWrapper.class);
            System.debug(statusWrapper);
            if(statusWrapper <> null && statusWrapper.result <> null){
                return mapSignzyJourneyData(kycId,statusWrapper);
            }
        }else{
            CustomerKYCErrorLogHelper.logErrorHandler(kycId,null,'Signzy Process','CustomerKYCHandler','getSignzyStatus',null,response.getBody());
        }
        return null;
    }
    public static String parse(String jsonString) {
        String cleanedJson = jsonString
            .replace('"Issuing State Name":', '"issuingStateName":')
            .replace('"Age at Issue":', '"ageAtIssue":')
            .replace('"Given Names":', '"givenNames":')
            .replace('"MRZ Strings":', '"mrzStrings":')
            .replace('"Surname And Given Names":', '"surnameAndGivenNames":')
            .replace('"Final Checkdigit":', '"finalCheckdigit":')
            .replace('"Nationality Code":', '"nationalityCode":')
            .replace('"Date of Expiry Checkdigit":', '"dateOfExpiryCheckdigit":')
            .replace('"Document Class Code":', '"documentClassCode":')
            .replace('"Issuing State Code":', '"issuingStateCode":')
            .replace('"Document Number":', '"documentNumber":')
            .replace('"Document Number Checkdigit":', '"documentNumberCheckdigit":')
            .replace('"Optional Data":', '"optionalData":')
            .replace('"Date Of Expiry":', '"dateOfExpiry":')
            .replace('"Date of Expiry":', '"dateOfExpiry1":')//
            .replace('"Date of Birth Checkdigit":', '"dateOfBirthCheckdigit":')
            .replace('"Date of Birth":', '"dateOfBirth":')
            .replace('"Optional Data CheckDigit":', '"optionalDataCheckDigit":')
            .replace('"Identity Card Number":', '"identityCardNumber":')
            .replace('"Nationality(Arabic (U.A.E.))":', '"nationalityArabicUAE":')
            .replace('"Years Since Issue":', '"yearsSinceIssue":')
            .replace('"Date of Issue":', '"dateOfIssue":')
            .replace('"Issue Date":', '"dateOfIssue1":')
            .replace('"Sex(Arabic (U.A.E.))":', '"sexArabicUAE":')
            .replace('"Surname And Given Names(Arabic (U.A.E.))":', '"surnameAndGivenNamesArabicUAE":')
            .replace('"Place of Issue":', '"placeOfIssue":')
            .replace('"Place Of Issue":', '"placeOfIssue1":')
            .replace('"Profession(Arabic (U.A.E.))":', '"professionArabicUAE":')
            .replace('"Sponsor(Arabic (U.A.E.))":', '"sponsorArabicUAE":')
            .replace('"Place of Issue(Arabic (U.A.E.))":', '"placeOfIssueArabicUAE":')
            .replace('"MRZ Type":', '"mrzType":')
            .replace('"fieldList" : [ "" ]', '"fieldList" : [ [] ]')
            .replace('"fieldList" : [""]', '"fieldList" : [ [] ]')
            .replace('"fieldList":[""]', '"fieldList" : [ [] ]')
            .replace('"Place Of Birth"','"placeOfBirth"')
            .replace('"Place of Birth"','"placeOfBirth1"');
        
        return cleanedJson;
    }
    public static String mapSignzyJourneyData(Id kycId,SignzyJourneyStatusWrapper statusWrapper){
        System.debug('statusWrapper::'+statusWrapper);
        /**2.4 Handle the different label of EID & Passport from response**/
        List<String> SignzyEIDIdentifier = System.label.SignzyEIDIdentifier.contains(',') ? System.label.SignzyEIDIdentifier.split(','):new List<String>{System.label.SignzyEIDIdentifier};
        List<String> SignzyPassportIdentifier = System.label.SignzyPassportIdentifier.contains(',') ? System.label.SignzyPassportIdentifier.split(','):new List<String>{System.label.SignzyPassportIdentifier};
        
        SignzyJourneyStatusWrapper.CapturedData cData = new SignzyJourneyStatusWrapper.CapturedData();
        SignzyJourneyStatusWrapper.faceMatch facematch = new SignzyJourneyStatusWrapper.faceMatch();
        String docType = null;
        
        if(statusWrapper.result <> null && statusWrapper.result.capturedData <> null){
            cData = statusWrapper.result.capturedData;
        }
       /* if(statusWrapper.result <> null && statusWrapper.result.selfieAnalysis <> null && statusWrapper.result.selfieAnalysis.faceMatch <> null){
            facematch = statusWrapper.result.selfieAnalysis.faceMatch;
        } */
        if(cData <> null){
            docType = cData.idType;
        }
        
        KYC_Response__c kyc = new KYC_Response__c();
        kyc.Id = kycId;
        if(statusWrapper.result <> null && statusWrapper.result.documentIntelligence <> null && statusWrapper.result.documentIntelligence.extractedFields <> null){
            docType = statusWrapper.result.documentIntelligence.predictedIdTypeFront <> null ? statusWrapper.result.documentIntelligence.predictedIdTypeFront.FDSIDList.dDescription:docType;
            
            SignzyJourneyStatusWrapper.extractedFieldsCls docExtraction = new SignzyJourneyStatusWrapper.extractedFieldsCls();

            system.debug('docExtraction' + docExtraction);
            docExtraction = statusWrapper.result.documentIntelligence.extractedFields;

            /** 4.2 <Arvind> 31 August 2026 - Signzy returns every given name inside firstName.
             *  First token -> FirstName__c, remaining tokens -> MiddleName__c. **/
            List<String> givenNameParts = splitGivenNames(docExtraction.firstName);
            kyc.FirstName__c         = givenNameParts[0];
            kyc.MiddleName__c        = givenNameParts[1];
            kyc.Customer_LastName__c = docExtraction.lastName;
            kyc.Name_in_Arabic__c    = docExtraction.surnameAndGivenNamesArabicUAE;

            /** 4.2 <Arvind> 31 August 2026 - Fallback when Signzy sends one combined "names" string.
             *  First token -> First, last token -> Last, everything between -> Middle. **/
            if(docExtraction.names <> null &&
               (String.isBlank(kyc.FirstName__c) || String.isBlank(kyc.Customer_LastName__c))){
                List<String> fullNameParts = splitFullName(docExtraction.names);
                kyc.FirstName__c         = fullNameParts[0];
                kyc.MiddleName__c        = fullNameParts[1];
                kyc.Customer_LastName__c = fullNameParts[2];
            }

            try{
                if(String.isNotBlank(kyc.FirstName__c)){
                    kyc.FirstName__c = nameToProperCase(kyc.FirstName__c);
                }
                if(String.isNotBlank(kyc.MiddleName__c)){ // 4.2 <Arvind> 31 August 2026
                    kyc.MiddleName__c = nameToProperCase(kyc.MiddleName__c);
                }
                if(String.isNotBlank(kyc.Customer_LastName__c)){
                    kyc.Customer_LastName__c = nameToProperCase(kyc.Customer_LastName__c);
                }
            }catch(Exception e){}
            kyc.Gender__c = docExtraction.Sex;
            kyc.Date_Of_Birth__c = docExtraction.dateOfBirth <> null ? handleStringData(docExtraction.dateOfBirth) <> null ? handleStringData(docExtraction.dateOfBirth) : null:null;
            kyc.Age__c = docExtraction.Age;
            kyc.Nationality_Code__c = docExtraction.nationalityCode;
            kyc.Nationality_in_Arabic__c = docExtraction.nationalityArabicUAE;
            kyc.Identity_Card_Number__c = docExtraction.documentNumber;

            //  // Populate Nationality on KYC Response if the retrieved value is present on Account Nationality field - Rushi Patel - 20th August 2026
            if (String.isNotBlank(docExtraction.Nationality)) {
                for (Schema.PicklistEntry ple : Account.Nationality__pc.getDescribe().getPicklistValues()) {
                    if (ple.isActive() && ple.getValue().equalsIgnoreCase(docExtraction.Nationality)) {
                        kyc.Nationality__c = ple.getValue();
                        break;
                    }
                }
            }
            
            //*** EID Info
            if(docType <> null && SignzyEIDIdentifier.contains(docType)){ /** 2.3 Added to handle dynamic doc identifier **/
                kyc.Emirates_ID__c = docExtraction.identityCardNumber;
                if(kyc.Emirates_ID__c <> null && kyc.Emirates_ID__c <> ''){
                    try{
                    	kyc.Emirates_ID__c = formatEmiratesId(kyc.Emirates_ID__c);
                    }catch(Exception e){}
                }
                kyc.Identity_Card_Number__c = docExtraction.documentNumber;//dateOfExpiry
                kyc.EID_Expiry_Date__c = docExtraction.dateOfExpiry <> null ? handleStringData(docExtraction.dateOfExpiry) <> null ? handleStringData(docExtraction.dateOfExpiry):null : null;
                if(kyc.EID_Expiry_Date__c == null){
                    kyc.EID_Expiry_Date__c = docExtraction.dateOfExpiry1 <> null ? handleStringData(docExtraction.dateOfExpiry1) <> null ? handleStringData(docExtraction.dateOfExpiry1):null : null;
                }
                kyc.EID_Issue_Date__c = docExtraction.dateOfIssue <> null ? handleStringData(docExtraction.dateOfIssue) <> null ? handleStringData(docExtraction.dateOfIssue):null : null;
                if(kyc.EID_Issue_Date__c == null){
                   kyc.EID_Issue_Date__c = docExtraction.dateOfIssue1 <> null ? handleStringData(docExtraction.dateOfIssue1) <> null ? handleStringData(docExtraction.dateOfIssue1):null : null;
                }
                kyc.Document_Number__c = docExtraction.documentNumber;
                kyc.EID_Years_Since_Issue__c = docExtraction.yearsSinceIssue;
                kyc.Profession_As_Per_EID__c = docExtraction.Profession;
                kyc.Profession_As_Per_EID_Arabic__c = docExtraction.professionArabicUAE;
                kyc.EID_Issue_Emirates__c = docExtraction.issuingStateName;
                kyc.EID_Issue_Emirates_Arabic__c = docExtraction.professionArabicUAE;
                kyc.EID_Sponsor__c = docExtraction.Sponsor;
                kyc.EID_Sponsor_Arabic__c = docExtraction.sponsorArabicUAE;
            }
            system.debug('docType>>> '+docType);
            if(docType <> null && docType.containsIgnoreCase('Passport')){
                kyc.Passport_Number__c = docExtraction.documentNumber;
                kyc.Passport_Issue_Date__c = docExtraction.dateOfIssue <>  null ? handleStringData(docExtraction.dateOfIssue) <> null ? handleStringData(docExtraction.dateOfIssue):null : null;
                if(kyc.Passport_Issue_Date__c == null){
                    kyc.Passport_Issue_Date__c = docExtraction.dateOfIssue1 <>  null ? handleStringData(docExtraction.dateOfIssue1) <> null ? handleStringData(docExtraction.dateOfIssue1):null : null; 
                }
                kyc.Passport_Expiry_Date__c = docExtraction.dateOfExpiry <> null ? handleStringData(docExtraction.dateOfExpiry) <> null ? handleStringData(docExtraction.dateOfExpiry):null : null;
                if(kyc.Passport_Expiry_Date__c == null){
                    kyc.Passport_Expiry_Date__c = docExtraction.dateOfExpiry1 <> null ? handleStringData(docExtraction.dateOfExpiry1) <> null ? handleStringData(docExtraction.dateOfExpiry1):null : null; 
                }
                kyc.Passport_Issued_Place__c = docExtraction.placeOfIssue;
                if(kyc.Passport_Issued_Place__c == null || kyc.Passport_Issued_Place__c ==''){
                    kyc.Passport_Issued_Place__c = docExtraction.placeOfIssue1;
                }
                kyc.Place_Of_Birth__c = docExtraction.placeOfBirth;
                if( kyc.Place_Of_Birth__c == '' || kyc.Place_Of_Birth__c == null){
                   kyc.Place_Of_Birth__c = docExtraction.placeOfBirth1;  
                }
            }
            if(statusWrapper.result <> null && statusWrapper.result.amlCheckResult <> null){
                kyc.amlCheckResult__c = String.valueOf(statusWrapper.result.amlCheckResult);
            }
            
            if(statusWrapper.result.documentIntelligence.completeStatus <> null){
                if(cData <> null){
                    docType = cData.idType+' - Uploaded Document Type: '+docType;
                }
                kyc.Document_1_Message__c = 'Document Type: '+docType+', Message: '+statusWrapper.result.documentIntelligence.completeStatus.message;
            }
            
        }
        
        if(statusWrapper.result <> null && statusWrapper.result.documentIntelligence2 <> null && statusWrapper.result.documentIntelligence2.extractedFields <> null && statusWrapper.result.documentIntelligence2.attempts <> null){
            SignzyJourneyStatusWrapper.extractedFieldsCls docExtraction = new SignzyJourneyStatusWrapper.extractedFieldsCls();
            docExtraction = statusWrapper.result.documentIntelligence2.extractedFields; 
            kyc.Passport_Number__c = docExtraction.documentNumber;
            kyc.Passport_Issue_Date__c = docExtraction.dateOfIssue <> null ? handleStringData(docExtraction.dateOfIssue) <> null ? handleStringData(docExtraction.dateOfIssue):null : null;
            if(kyc.Passport_Issue_Date__c == null){
                 kyc.Passport_Issue_Date__c = docExtraction.dateOfIssue1 <> null ? handleStringData(docExtraction.dateOfIssue1) <> null ? handleStringData(docExtraction.dateOfIssue1):null : null;  
            }
            kyc.Passport_Expiry_Date__c = docExtraction.dateOfExpiry <> null ? handleStringData(docExtraction.dateOfExpiry) <> null ? handleStringData(docExtraction.dateOfExpiry):null: null;
            if(kyc.Passport_Expiry_Date__c == null){
               kyc.Passport_Expiry_Date__c = docExtraction.dateOfExpiry1 <> null ? handleStringData(docExtraction.dateOfExpiry1) <> null ? handleStringData(docExtraction.dateOfExpiry1):null: null; 
            }
            kyc.Passport_Issued_Place__c = docExtraction.placeOfIssue;
            if(kyc.Passport_Issued_Place__c == null || kyc.Passport_Issued_Place__c == ''){
                kyc.Passport_Issued_Place__c = docExtraction.placeOfIssue1;
            }
            kyc.Place_Of_Birth__c = docExtraction.placeOfBirth;
            if(kyc.Place_Of_Birth__c == '' || kyc.Place_Of_Birth__c == null){
                 kyc.Place_Of_Birth__c = docExtraction.placeOfBirth1;
            }
        }
        if(facematch <> null){
            kyc.Selfied_Analysis_Message__c = facematch.message;
            kyc.Selfied_Analysis_Verified__c = facematch.verified == true ? 'true':'false';
        }
        //**** Signzy Info
        kyc.Signzy_UserId__c = statusWrapper.result.userId;
        kyc.Signzy_Journey_Message__c = statusWrapper.result.message;
        kyc.Signzy_Client_ID__c = statusWrapper.result.clientId;
        kyc.Signzy_Step__c = statusWrapper.result.step;
        kyc.Signzy_Flow_ID__c = statusWrapper.result.flow.flowId;
        
        KYC_Response__c kycObj = [SELECT customer__c,Contact__c FROM KYC_Response__c WHERE Id=: kyc.Id LIMIT 1];
        Id recordId = null;
        if(kycObj.customer__c <> null){
            recordId = kycObj.customer__c;
            List<Id> accountIdset=new List<Id>();
            accountIdset.add(kycObj.customer__c);
            GenerateCustomerDocumentAccount.generateCustomerDocuments(accountIdset);
        }else if(kycObj.Contact__c <> null){
            recordId = kycObj.Contact__c;
        }

        /** 4.2 <Arvind> 31 August 2026 - build the attachment file-name prefix from First + Middle + Last
         *  so document titles keep the customer's complete name after the split. **/
        String attachmentNamePrefix = buildFullName(kyc.FirstName__c, kyc.MiddleName__c, kyc.Customer_LastName__c);
        
        //******************** EMIRATES ID & PASSPORT IMAGE CAPTURE ***************************************//
        try{ 
            if(statusWrapper.result.documentIntelligence.graphicFields <> null && statusWrapper.result.documentIntelligence.graphicFields.fieldList <> null){
                docType = statusWrapper.result.documentIntelligence.predictedIdTypeFront <> null ? statusWrapper.result.documentIntelligence.predictedIdTypeFront.FDSIDList.dDescription:docType;
                for(integer i = 0;i<statusWrapper.result.documentIntelligence.graphicFields.fieldList.size();i++){
                    for(SignzyJourneyStatusWrapper.GraphicField gField:statusWrapper.result.documentIntelligence.graphicFields.fieldList[i]){
                        if(gField.fieldType <> null && gField.fieldType == 'CROPPED_DOCUMENT'){
                            attachImageFromUrl(recordId, gField.value,attachmentNamePrefix+'-'+docType+'-'+gField.docSide,docType+'-'+gField.docSide);
                        }
                    }
                }
            }
            
        }catch(Exception ex){
            system.debug('Error: Handling Signzy Attachments: '+ex.getMessage());
        }
        
        //********************PASSPORT IMAGE CAPTURE ***************************************//
        try{ 
            if(statusWrapper.result.documentIntelligence2.graphicFields <> null && statusWrapper.result.documentIntelligence2.graphicFields.fieldList <> null){
                docType = statusWrapper.result.documentIntelligence2.predictedIdTypeFront <> null ? statusWrapper.result.documentIntelligence2.predictedIdTypeFront.FDSIDList.dDescription:docType;
                for(integer i = 0;i<statusWrapper.result.documentIntelligence2.graphicFields.fieldList.size();i++){
                    for(SignzyJourneyStatusWrapper.GraphicField gField:statusWrapper.result.documentIntelligence2.graphicFields.fieldList[i]){
                        if(gField.fieldType <> null && gField.fieldType == 'CROPPED_DOCUMENT' && gField.docSide=='FRONT'){
                            attachImageFromUrl(recordId, gField.value,attachmentNamePrefix+'-'+docType+'-'+gField.docSide,'Passport');
                        }
                    }
                }
                
            }
            if(statusWrapper.result.documentIntelligence2.completeStatus <> null){
                if(cData <> null){
                    docType = cData.idType2+' - Uploaded Document Type: '+docType;
                }
                kyc.Document_2_Message__c = 'Document Type: '+docType+', Message: '+statusWrapper.result.documentIntelligence2.completeStatus.message;
            }
           
        }catch(Exception ex){
            system.debug('Error: Handling Signzy Attachments: '+ex.getMessage());
            return 'Error!'+ex.getMessage();
        }
        try{
            update kyc;
            Set<Id> kycIdset = new Set<Id>();
            Set<Id> corporatekycIdset = new Set<Id>();
            for(KYC_Response__c kycOBJrec:[SELECT Id,Customer__c,Contact__c,Signzy_Journey_Status__c FROM KYC_Response__c WHERE Id=:kyc.Id]){
                if(kycOBJrec.Customer__c <> null && kycOBJrec.Contact__c == null && statusWrapper.result.currentStatus == 'COMPLETED'){
                    kycIdset.add(kycOBJrec.Id);
                }
                if(kycOBJrec.Contact__c <> null && kycOBJrec.Customer__c == null && statusWrapper.result.currentStatus == 'COMPLETED'){
                    corporatekycIdset.add(kycOBJrec.Id);
                }
            }
            if(!kycIdset.isEmpty()){
                updateKycInfoToAccount(kycIdset);
            }
            if(!corporatekycIdset.isEmpty()){
                updateKycInfoToContact(corporatekycIdset);
            }
            
            KYC_Response__c kycObjsts = new KYC_Response__c();
            kycObjsts.Signzy_Journey_Status__c = statusWrapper.result.currentStatus;
            if(kycObjsts.Signzy_Journey_Status__c == 'COMPLETED'){
                kycObjsts.KYC_Completed_Date__c = system.today();
            }
            kycObjsts.Id = kyc.Id;
            update kycObjsts;
            
            if(kycObj.customer__c <> null){
                Account acc = new Account();
                acc.Id = kycObj.customer__c;
                acc.KYC_Link_Status__c = statusWrapper.result.currentStatus;
                //Duplicate Issue Fix
                Database.DMLOptions dmlOptions = new Database.DMLOptions();
                dmlOptions.DuplicateRuleHeader.allowSave = true;
                Database.SaveResult sr = Database.update(acc, dmlOptions);
                //update acc;
            }else if(kycObj.Contact__c <> null){
                Contact con = new Contact();
                con.Id = kycObj.Contact__c;
                con.KYC_Link_Status__c = statusWrapper.result.currentStatus;
                //Duplicate Issue Fix
                Database.DMLOptions dmlOptions = new Database.DMLOptions();
                dmlOptions.DuplicateRuleHeader.allowSave = true;
                Database.SaveResult sr = Database.update(con, dmlOptions);
               // update con;
            }
            return 'Success';
        }catch(Exception ex){
            system.debug('Error: Handling Data Update: '+ex.getMessage());
            CustomerKYCErrorLogHelper.logError(kyc.Id,null,'Signzy Process','CustomerKYCHandler','mapSignzyJourneyData',ex);
            return 'Error!'+ex.getMessage();
        }
    }
    /**** public static void updateCompletedKYCtoAccount(List<sObject> newList,Map<Id,sObject> oldMap){
Id individualRecordTypeId = Schema.SObjectType.KYC_Response__c.getRecordTypeInfosByDeveloperName().get('Individual_KYC').getRecordTypeId();
Id corporateRecordTypeId = Schema.SObjectType.KYC_Response__c.getRecordTypeInfosByDeveloperName().get('Corporate_KYC').getRecordTypeId();

Set<Id> kycIdset = new Set<Id>();
Set<Id> corporatekycIdset = new Set<Id>();
for(KYC_Response__c kyc:(List<KYC_Response__c>)newList){
KYC_Response__c oldRecord = oldMap <> null ? (KYC_Response__c)oldMap.get(kyc.Id) : null;
if(kyc.Migrate_Data__c && individualRecordTypeId == kyc.recordTypeId && kyc.Customer__c <> null && kyc.Contact__c == null && kyc.Signzy_Journey_Status__c == 'COMPLETED' && (oldRecord == null ||(oldMap <> null && kyc.Migrate_Data__c <> oldRecord.Migrate_Data__c))){
kycIdset.add(kyc.Id);
}
if(kyc.Migrate_Data__c && individualRecordTypeId == kyc.recordTypeId && kyc.Contact__c <> null && kyc.Customer__c == null && kyc.Signzy_Journey_Status__c == 'COMPLETED' && (oldRecord == null ||(oldMap <> null && kyc.Migrate_Data__c <> oldRecord.Migrate_Data__c))){
corporatekycIdset.add(kyc.Id);
}
}
if(!kycIdset.isEmpty()){
//updateKycInfoToAccount(kycIdset);
}
if(!corporatekycIdset.isEmpty()){
//updateKycInfoToContact(corporatekycIdset);
}
} ***/
    @AuraEnabled
    public static String sendKYCForm(Id accountId){
        try{
            if(accountId <> null){
                String recordTypeName = [SELECT Id,RecordType.Name FROM Account WHERE Id =: accountId LIMIT 1].RecordType.Name;
                if(recordTypeName !='Organization Account'){
                    List<Account> accObjList = [SELECT Id,Nationality__pc,UAE_Resident_Status__pc,PersonMobilePhone,PersonEmail,PersonContactId FROM Account WHERE Id=:accountId];
                    if(accObjList[0].Nationality__pc == null || accObjList[0].UAE_Resident_Status__pc == null){
                        return System.Label.SignzyNationalityMissingErrorMsg;
                    }
                    if(accObjList[0].PersonEmail == null){
                        return System.Label.SignzyEmailMissingErrorMsg;
                    }
                    if(accObjList[0].PersonMobilePhone == null){ /** 2.1 Added Missing Missing Mobile Phone Validation **/
                        return System.Label.SignzyPhoneMissingErrorMsg;
                    }
                    String recordId = EncryptionService.encrypt(accountId);
                    Account acc = new Account();
                    acc.Id = accountId;
                    acc.AccountID_EncryptedId__c = recordId;
                    if(resendKycLink(accountId)){
                    	acc.KYCSiteLink__pc = createSignzyJourney(accountId); /**2.3 Adding Logic to resend kyc link**/
                    }
                    acc.Send_KYC_Verification_Email__c = true;
                    SalesOrder__c so = getLatestUnitInfo(accObjList[0].PersonContactId);
                    if(so <> null){
                       acc.KYCProjectName__pc = so.ProjectName__c;
                       acc.KYCUnitName__pc = so.Unit__r.Name;
                       acc.KYCMasterPlanName__pc = so.Unit__r.phase__r.EntityName__c;
                    }
                    Database.DMLOptions dmlOptions = new Database.DMLOptions();
                    dmlOptions.DuplicateRuleHeader.allowSave = true;
                    Database.SaveResult sr = Database.update(acc, dmlOptions);
                    //update acc;
                    /** 4.4 Send the KYC link over SMS as well as the email. The link is read back from
                        the record inside the notifier, so it covers both a freshly created journey and
                        an active link being re-sent. **/
                    if(sr.isSuccess()){
                        CustomerKYCSmsNotifier.sendForAccount(accountId);
                    }
                }else if(recordTypeName == 'Organization Account'){
                    List<Contact> conList = new List<Contact>(); /** 2.1 Added Missing SOQL Fields**/
                    for(Power_of_Attorney__c poa:[SELECT Id,Contact__c,Contact__r.Nationality__c,Contact__r.UAE_Resident_Status__c,Contact__r.Email,Contact__r.MobilePhone FROM Power_of_Attorney__c WHERE Organization_Account__c =:accountId AND Contact__c != null]){
                        if(poa.Contact__r.Nationality__c == null || poa.Contact__r.UAE_Resident_Status__c == null){
                            return System.Label.SignzyNationalityMissingErrorMsg;
                        }
                        if(poa.Contact__r.Email == null){
                            return System.Label.SignzyEmailMissingErrorMsg;
                        }
                        if(poa.Contact__r.MobilePhone == null){ /** 2.1 Added Missing Mobile Phone Validation**/
                           return System.Label.SignzyPhoneMissingErrorMsg;
                    	}
                        Contact con = new Contact();
                        con.Id = poa.Contact__c;
                        con.ContactEncryptID__c = EncryptionService.encrypt(poa.Contact__c);
                        con.Send_KYC_Verification_Email__c = true;
                        if(resendKycLink(poa.Contact__c)){
                        	con.KYCSiteLink__c = createSignzyJourney(poa.Contact__c); /**2.3 Adding Logic to resend kyc link**/
                        }
                        SalesOrder__c so = getLatestUnitInfo(poa.Contact__c);
                        if(so <> null){
                           con.KYCProjectName__c = so.ProjectName__c;
                           con.KYCUnitName__c = so.Unit__r.Name;
                           con.KYCMasterPlanName__c = so.Unit__r.phase__r.EntityName__c;
                       }
                        conList.add(con);
                    }
                    if(!conList.isEmpty()){
                        Database.DMLOptions dmlOptions = new Database.DMLOptions();
                        dmlOptions.DuplicateRuleHeader.allowSave = true;
                        Database.update(conList, dmlOptions);
                       // update conList;
                        /** 4.4 Send the KYC link over SMS to each Power of Attorney contact. **/
                        Set<Id> poaContactIds = new Set<Id>();
                        for(Contact poaCon : conList){
                            poaContactIds.add(poaCon.Id);
                        }
                        CustomerKYCSmsNotifier.sendForContacts(poaContactIds);
                    }else{
                        return System.Label.SignzyPOAErrorMsg;
                    }
                }
                return System.Label.SignzyMailSentSuccessMsg;
            }
            return null;
        }catch(Exception e){
            return 'Error! '+e.getMessage();
        }
    }
    /** 2.3 Re-Send KYC link - Active Link will be resend without creating new **/
    public static boolean resendKycLink(Id recordId){        
        String objectName = recordId.getSObjectType().getDescribe().getName();
        System.debug('objectName::'+objectName);
        List<KYC_Response__c> kycResList = new List<KYC_Response__c>();
        if(objectName =='Contact'){
            kycResList = [SELECT Id,Signzy_Step__c,Signzy_Journey_ID__c,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Contact__r.Account.Is_Trade_License_Uploaded__c,Signzy_Journey_Status__c,  //v2.5
                          Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,contact__r.Is_KYC_Link_Active__c,contact__r.KYC_Link_Status__c FROM KYC_Response__c WHERE Contact__c = :recordId ORDER BY CreatedDate DESC LIMIT 1 ];
            
        }
        if(objectName !='Contact'){
            kycResList = [SELECT Id,Signzy_Step__c,Signzy_Journey_ID__c,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Signzy_Journey_Status__c,    //v2.5
                          Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,Customer__r.Is_KYC_Link_Active__c,Customer__r.KYC_Link_Status__c FROM KYC_Response__c WHERE Customer__c = :recordId ORDER BY CreatedDate DESC LIMIT 1 ];
        }            
        if(!kycResList.isEmpty()){
            if(kycResList[0].Signzy_Journey_Status__c == 'ABANDONED' || kycResList[0].Signzy_Journey_Status__c == 'TERMINATED' || kycResList[0].Signzy_Journey_Status__c == 'COMPLETED' || kycResList[0].Signzy_Step__c == 'JOURNEY_EXPIRED'){ /**2.5  Fixing re-send signzy link for Expired KYC**/
                return true;
            }
            if(kycResList[0].Signzy_Journey_ID__c <> null){
                String message = getSignzyJourney(kycResList[0].Id);
                if(objectName =='Contact'){
                    kycResList = [SELECT Id,Signzy_Journey_ID__c,Signzy_Step__c,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Contact__r.Account.Is_Trade_License_Uploaded__c,Signzy_Journey_Status__c,     //v2.5
                                  Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,contact__r.Is_KYC_Link_Active__c,contact__r.KYC_Link_Status__c FROM KYC_Response__c WHERE Id = :kycResList[0].Id ORDER BY CreatedDate DESC LIMIT 1 ];
                    
                }
                if(objectName !='Contact'){
                    kycResList = [SELECT Id,Signzy_Journey_ID__c,Signzy_Step__c,Other_Nationality_If_Applicable__c,EID_Sponsor__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,City__c,Street__c,State__c,Postal_Code__c,Signzy_Journey_Status__c,      //v2.5
                                  Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,Customer__r.Is_KYC_Link_Active__c,Customer__r.KYC_Link_Status__c FROM KYC_Response__c WHERE  Id = :kycResList[0].Id ORDER BY CreatedDate DESC LIMIT 1 ];
                } 
                if(kycResList[0].Signzy_Journey_Status__c == 'ABANDONED' || kycResList[0].Signzy_Journey_Status__c == 'TERMINATED' || kycResList[0].Signzy_Journey_Status__c == 'COMPLETED' || kycResList[0].Signzy_Step__c == 'JOURNEY_EXPIRED' ){//v2.5
                   return true;
                }
            }
        }else{
            return true;
        }
        return false;
    }
    public static SalesOrder__c getLatestUnitInfo(Id contactId){
        if(contactId <> null){
            for(SalesOrder__c so:[SELECT Id,unit__r.Name,ProjectName__c,unit__r.phase__r.EntityName__c FROM SalesOrder__c WHERE PrimaryContact__c =:contactId AND Status__c NOT IN ('Voided','Cancelled SR','Cancelled','System cancelled') ORDER BY CreatedDate DESC LIMIT 1]){
                return so;
            }
        }
        return null;
    }
    public static void createFileLog(Id recordId, String requestResponseBody, String logName) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = logName + ' - ' + Datetime.now().format();
            cv.PathOnClient = logName + '.txt';
            cv.VersionData = Blob.valueOf(requestResponseBody);
            cv.FirstPublishLocationId = recordId;
            
            insert cv;
            System.debug('API Log File created successfully for record: ' + recordId);
            
        } catch (Exception e) {
            System.debug('Error creating API log file: ' + e.getMessage());
        }
    }
    public static String updateKycInfoToAccount(Set<Id> kycIdset){
        String signingURL = '';
        Set<Id> alreadyProcessedAccIds = new Set<Id>();
        Set<Id> accountIdset = new Set<Id>();
        List<Account> accountUpdateList = new List<Account>();
        String customerName = '';
        Id kycRecordId = null;
        // 4.2 <Arvind> 31 August 2026 - MiddleName__c added to the select list
        for(KYC_Response__c kycOBJ :[SELECT Id,Identity_Card_Number__c,Customer__c,Gender__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,MiddleName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,Nationality_in_Arabic__c,City__c,Street__c,State__c,Postal_Code__c,Residential_Country__c,Date_Of_Birth__c,Emirates_ID__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,EID_Expiry_Date__c,Place_Of_Birth__c,Passport_Issue_Date__c,EID_Issue_Date__c,
                                     Name_in_Arabic__c,EID_Issue_Emirates__c,Profession_As_Per_EID__c,Profession_As_Per_EID_Arabic__c,EID_Sponsor__c,EID_Sponsor_Arabic__c,Passport_Number__c,Passport_Expiry_Date__c,Passport_Issued_Place__c,Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Other_Nationality_If_Applicable__c FROM KYC_Response__c WHERE Id IN :kycIdset ORDER BY CreatedDate]){
                                         accountIdset.add(kycOBJ.Customer__c);
                                         kycRecordId = kycOBJ.Id;
                                         customerName =  kycOBJ.FirstName__c <> null ? kycOBJ.FirstName__c:'' +' '+kycOBJ.Customer_LastName__c <> null ? kycOBJ.Customer_LastName__c:'N/A';
                                         Account acc = new Account();
                                         acc.Id = kycOBJ.Customer__c;
                                         if(nullCheck(kycOBJ.FirstName__c) <> null){
                                             acc.firstName = kycOBJ.FirstName__c;
                                         }if(nullCheck(kycOBJ.MiddleName__c) <> null){ // 4.2 <Arvind> 31 August 2026
                                             acc.MiddleName = kycOBJ.MiddleName__c;
                                         }if(nullCheck(kycOBJ.Customer_LastName__c) <> null){
                                             acc.LastName = kycOBJ.Customer_LastName__c;
                                         }if(nullCheck(kycOBJ.Name_in_Arabic__c) <> null){
                                             acc.AccountnameArabic__pc = kycOBJ.Name_in_Arabic__c;
                                         }if(nullCheck(kycOBJ.Date_Of_Birth__c) <> null){
                                             acc.PersonBirthdate = kycOBJ.Date_Of_Birth__c;
                                         }if(nullCheck(kycOBJ.Emirates_ID__c) <> null){
                                             acc.EIDNumber__pc = kycOBJ.Emirates_ID__c;
                                             acc.En_EIDNumber__pc = kycOBJ.Emirates_ID__c;
                                         }if(nullCheck(kycOBJ.EID_Expiry_Date__c) <> null){
                                             acc.EmiratesIDExpiryDate__pc = kycOBJ.EID_Expiry_Date__c;//
                                         }if(nullCheck(kycOBJ.EID_Issue_Date__c) <> null){
                                             acc.Emirates_ID_Issue_Date__pc = kycOBJ.EID_Issue_Date__c;//
                                         }if(nullCheck(kycOBJ.Passport_Number__c) <> null){
                                             acc.PassportNumber__pc = kycOBJ.Passport_Number__c;
                                             acc.Masked_Passport_Number__c = kycOBJ.Passport_Number__c;
                                             acc.En_PassportNumber__pc = kycOBJ.Passport_Number__c;
                                         }if(nullCheck(kycOBJ.Passport_Expiry_Date__c) <> null){
                                             acc.PassportExpiryDate__pc = kycOBJ.Passport_Expiry_Date__c;
                                         }if(nullCheck(kycOBJ.Passport_Issue_Date__c) <> null){
                                             acc.PassportIssueDate__pc = kycOBJ.Passport_Issue_Date__c;
                                         }if(nullCheck(kycOBJ.Passport_Issued_Place__c) <> null){
                                             acc.PassportIssuancePlace__pc = kycOBJ.Passport_Issued_Place__c;
                                         }if(nullCheck(kycOBJ.Employment_Status__c) <> null){
                                             acc.Employment_Status__pc = kycOBJ.Employment_Status__c;
                                         }if(nullCheck(kycOBJ.Nationality__c) <> null){
                                             acc.Nationality__pc = kycOBJ.Nationality__c;
                                         }if(nullCheck(kycOBJ.Street__c) <> null){
                                             acc.PersonMailingStreet = kycOBJ.Street__c;
                                         }if(nullCheck(kycOBJ.City__c) <> null){
                                             acc.PersonMailingCity = kycOBJ.City__c;
                                         }if(nullCheck(kycOBJ.State__c) <> null){
                                             acc.PersonMailingState = kycOBJ.State__c;
                                         }if(nullCheck(kycOBJ.Postal_Code__c) <> null){
                                             acc.PersonMailingPostalCode = kycOBJ.Postal_Code__c;
                                         }if(nullCheck(kycOBJ.Residential_Country__c) <> null){
                                             acc.PersonMailingCountry = kycOBJ.Residential_Country__c;
                                         }else if(nullCheck(kycOBJ.Nationality__c) <> null){
                                             acc.PersonMailingCountry = kycOBJ.Nationality__c;
                                             if(kycOBJ.Resident_Status__c !='International'){
                                                 acc.PersonMailingCountry = 'United Arab Emirates'; 
                                             }
                                         }if(nullCheck(kycOBJ.Nationality_in_Arabic__c) <> null){
                                             acc.NationalityArabic__pc = kycOBJ.Nationality_in_Arabic__c;
                                         }if(nullCheck(kycOBJ.Resident_Status__c) <> null){
                                             acc.UAE_Resident_Status__pc = kycOBJ.Resident_Status__c =='International' ?'Non-Resident':'Resident';
                                         }if(nullCheck(kycOBJ.Source_of_Income__c) <> null){
                                             acc.SourceOfIncome__pc = kycOBJ.Source_of_Income__c;
                                         }if(nullCheck(kycOBJ.Company_Name__c) <> null){
                                             acc.EmployerBusinessName__pc = kycOBJ.Company_Name__c;
                                         }if(nullCheck(kycOBJ.Position__c) <> null){
                                             acc.Occupation__pc = kycOBJ.Position__c;
                                         }if(nullCheck(kycOBJ.Other_Source_Of_Income__c) <> null){
                                             acc.OtherSourceOfIncome__pc = kycOBJ.Other_Source_Of_Income__c;
                                         }if(nullCheck(kycOBJ.EID_Sponsor__c) <> null){
                                             acc.EID_Sponsor__pc = kycOBJ.EID_Sponsor__c;
                                         }if(nullCheck(kycOBJ.EID_Sponsor_Arabic__c) <> null){
                                             acc.EID_Sponsor_Arabic__pc =  kycOBJ.EID_Sponsor_Arabic__c;
                                         }if(nullCheck(kycOBJ.Profession_As_Per_EID__c) <> null){
                                             acc.Profession_As_Per_EID__pc = kycOBJ.Profession_As_Per_EID__c;
                                         }if(nullCheck(kycOBJ.Profession_As_Per_EID_Arabic__c) <> null){
                                             acc.Profession_As_Per_EID_Arabic__pc = kycOBJ.Profession_As_Per_EID_Arabic__c; 
                                         }if(nullCheck(kycOBJ.Gender__c) <> null){
                                             acc.PersonGenderIdentity = kycOBJ.Gender__c == 'M' ? 'Male' : kycOBJ.Gender__c == 'F' ? 'Female' :'';
                                         }if(nullCheck(kycOBJ.EID_Issue_Emirates__c) <> null){
                                             acc.EID_Issue_Emirates__pc = kycOBJ.EID_Issue_Emirates__c;
                                         }if(nullCheck(kycOBJ.Passport_Issued_Place__c)<> null){
                                             acc.PassportIssuancePlace__pc = kycOBJ.Passport_Issued_Place__c;
                                         }
                                         if(nullCheck(kycOBJ.Dual_Citizen__c)<> null){
                                             acc.Do_you_hold_dual_nationality__pc = kycOBJ.Dual_Citizen__c;
                                         }
                                         if(nullCheck(kycOBJ.Salary__c)<> null){
                                             acc.Salary_Range__pc =  kycOBJ.Salary__c;
                                         }
                                         if(nullCheck(kycOBJ.Other_Nationality_If_Applicable__c)<> null){
                                             acc.Other_Nationality_If_Applicable__pc = kycOBJ.Other_Nationality_If_Applicable__c;
                                         }
                                         if(nullCheck(kycOBJ.Place_Of_Birth__c)<> null){
                                             acc.Place_Of_Birth__pc = kycOBJ.Place_Of_Birth__c;
                                         }
                                         if(nullCheck(kycOBJ.Resident_Emirates__c)<> null){
                                             acc.Resident_Emirates__pc = kycOBJ.Resident_Emirates__c;
                                         }
                                         if(nullCheck(kycOBJ.Identity_Card_Number__c)<> null){
                                             acc.UnifiedNumber__pc = kycOBJ.Identity_Card_Number__c;
                                         }
                                         acc.KYC_Completed_Date__c = System.today();
                                         acc.PurposeOfTransaction__pc = System.Label.PurposeOfTransactionCompliance;
                                         try{
                                             acc.NoOfPropertyPurchasedWithModon__pc = kycOBJ.Customer__c <> null ? getNoOfPropertyWithModon(kycOBJ.Customer__c) : 0;
                                         }catch(Exception ex){}
                                         accountUpdateList.add(acc);
                                     }
        if(!accountUpdateList.IsEmpty()){
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.DuplicateRuleHeader.allowSave = true;
            Database.update(accountUpdateList, dmlOptions);
           // update accountUpdateList;
            Map<Id,Id> existingDocsMap = new Map<Id,Id>();
            Id personContactId = null;
            Map<Id,Id> personContactIdMap = new Map<Id,Id>();
            for(Account accObj:[SELECT Id,PersonContactId FROM Account WHERE IsPersonAccount = true AND Id=:accountIdset]){
                personContactId = accObj.PersonContactId;
                personContactIdMap.put(accObj.Id,accObj.PersonContactId);
            }
            if(personContactId != null){
                for(Documents__c doc:[SELECT Id,Name,Account__c,Account__r.IsPersonAccount,PrimaryContact__c FROM Documents__c WHERE PrimaryContact__c =:personContactId AND Name = 'KYC Form - Signed']){
                    existingDocsMap.put(doc.PrimaryContact__c,doc.Id);
                }
                List<Documents__c> documentList = new List<Documents__c>();
                for(Account acc: accountUpdateList){
                    Documents__c doc= new Documents__c();
                    doc.Name = 'KYC Form - Signed';
                    // doc.Account__c = acc.Id;
                    doc.PrimaryContact__c = personContactId;
                    doc.DocuSignURL__c = null;
                    if(existingDocsMap.containsKey(personContactId)){
                        doc.Id = existingDocsMap.get(personContactId);
                    }
                    documentList.add(doc);
                }
                if(!documentList.isEmpty()){
                    upsert documentList;
                    
                    SignzyKYCPlatformEvent__e signzy = new SignzyKYCPlatformEvent__e();
                    signzy.DocumentID__c = documentList[0].Id;
                    signzy.AccountID__c = accountUpdateList[0].id;
                    signzy.KYCID__c = kycRecordId;
                    
                    Database.SaveResult sr = EventBus.publish(signzy);
                    
                }
            }
        }
        return 'Error';
    }
    @future(callout=true)
    public static void callDocuSignLink(String docId,String ReturnUrl,blob pdfBlob,Id kycId){
        try{
            String returnSignURL = SignzyDocuSignDocumentHelper.generateDocusignURL(docId, ReturnUrl,pdfBlob);
            Documents__c doc = new Documents__c();
            doc.DocuSignURL__c = returnSignURL;
            doc.Id = docId;
            update doc;
        }catch(Exception ex){
            CustomerKYCErrorLogHelper.logError(kycId,null,'Signzy Process','CustomerKYCHandler','callDocuSignLink',ex);
        }
    }
    @AuraEnabled
    public static String fetchDocuSignUrl(String kycId) {
        system.debug('kycId::'+kycId);
        if (kycId == null) return null;
        String recordIdStr = EncryptionService.decrypt(kycId);
        Id recordId = (Id)recordIdStr;
        system.debug('recordId::'+recordId);
        String objectName = recordId.getSObjectType().getDescribe().getName();
        system.debug('objectName::'+objectName);
        if(objectName == 'Contact'){
            for(Documents__c d : [SELECT Id, DocuSignURL__c FROM Documents__c WHERE PrimaryContact__c = :recordId AND Name LIKE '%KYC%']){
                if(d.DocuSignURL__c != null){
                    return d.DocuSignURL__c; 
                }
            }
        }else {
            for(Documents__c d : [SELECT Id, DocuSignURL__c FROM Documents__c WHERE PrimaryContact__r.AccountId = :recordId AND Name LIKE '%KYC%']){
                if(d.DocuSignURL__c != null){
                    return d.DocuSignURL__c; 
                }
            }
        }
        return null;
    }

    // Regenrate the DocuSign URL for resuming the KYC Process - Rushi Patel - 20th August 2026
    @AuraEnabled
    public static String regenerateAndFetchDocuSignUrl(String kycId) {
        system.debug('kycId::'+kycId);
        if (kycId == null) return null;
        String recordIdStr = EncryptionService.decrypt(kycId);
        Id recordId = (Id)recordIdStr;
        String objectName = recordId.getSObjectType().getDescribe().getName();
        
        List<Documents__c> docs = new List<Documents__c>();
        if(objectName == 'Contact'){
            docs = [SELECT Id, DocuSignURL__c, EnvelopID__c FROM Documents__c WHERE PrimaryContact__c = :recordId AND Name LIKE '%KYC%' LIMIT 1];
        } else {
            docs = [SELECT Id, DocuSignURL__c, EnvelopID__c FROM Documents__c WHERE PrimaryContact__r.AccountId = :recordId AND Name LIKE '%KYC%' LIMIT 1];
        }
        
        if (!docs.isEmpty() && docs[0].EnvelopID__c != null) {
            String returnUrl = System.Label.SignzyThankYouURL + '?id=' + docs[0].Id;
            String newUrl = SignzyDocuSignDocumentHelper.docuSignURLRegeneration(docs[0].Id, docs[0].EnvelopID__c, returnUrl);
            if (String.isNotBlank(newUrl) && !newUrl.containsIgnoreCase('exception')) {
                return newUrl;
            }
        }
        return null;
    }
    public static void updateKycInfoToContact(Set<Id> kycIdset){
        Set<Id> alreadyProcessedAccIds = new Set<Id>();
        Id kycRecordId = null;
        List<Contact> ContactUpdateList = new List<Contact>();
        // 4.2 <Arvind> 31 August 2026 - MiddleName__c added to the select list
        for(KYC_Response__c kycOBJ :[SELECT Id,Contact__c,Customer__c,Gender__c,Is_Politically_Exposed__c,Dual_Citizen__c,FirstName__c,MiddleName__c,Customer_LastName__c,Resident_Status__c,Nationality__c,Nationality_in_Arabic__c,City__c,Street__c,State__c,Postal_Code__c,Residential_Country__c,Date_Of_Birth__c,Emirates_ID__c,Source_of_Income__c,Position__c,Company_Name__c,Salary__c,EID_Expiry_Date__c,Place_Of_Birth__c,Contact__r.AccountId,
                                     Name_in_Arabic__c,EID_Issue_Date__c,EID_Issue_Emirates__c,Profession_As_Per_EID__c,Profession_As_Per_EID_Arabic__c,EID_Sponsor__c,EID_Sponsor_Arabic__c,Passport_Number__c,Passport_Expiry_Date__c,Passport_Issued_Place__c,Resident_Emirates__c,Other_Source_Of_Income__c,Employment_Status__c,Other_Nationality_If_Applicable__c,Passport_Issue_Date__c  FROM KYC_Response__c WHERE Id IN :kycIdset ORDER BY CreatedDate]){
                                         kycRecordId = kycOBJ.Id;
                                         Contact con = new Contact();
                                         con.Id = kycOBJ.Contact__c;
                                         if(nullCheck(kycOBJ.FirstName__c) <> null){
                                             con.firstName = kycOBJ.FirstName__c.toUpperCase();
                                         }if(nullCheck(kycOBJ.MiddleName__c) <> null){ // 4.2 <Arvind> 31 August 2026
                                             con.MiddleName = kycOBJ.MiddleName__c.toUpperCase();
                                         }if(nullCheck(kycOBJ.Customer_LastName__c) <> null){
                                             con.LastName = kycOBJ.Customer_LastName__c.toUpperCase();
                                         }if(nullCheck(kycOBJ.Name_in_Arabic__c) <> null){
                                             con.AccountnameArabic__c = kycOBJ.Name_in_Arabic__c;
                                         }if(nullCheck(kycOBJ.Date_Of_Birth__c) <> null){
                                             con.Birthdate = kycOBJ.Date_Of_Birth__c;
                                         }if(nullCheck(kycOBJ.Emirates_ID__c) <> null){
                                             con.EIDNumber__c = kycOBJ.Emirates_ID__c;
                                             con.En_EIDNumber__c  = kycOBJ.Emirates_ID__c;
                                         }if(nullCheck(kycOBJ.EID_Expiry_Date__c) <> null){
                                             con.EmiratesIDExpiryDate__c = kycOBJ.EID_Expiry_Date__c;
                                         }if(nullCheck(kycOBJ.EID_Issue_Date__c) <> null){
                                             con.Emirates_ID_Issue_Date__c = kycOBJ.EID_Issue_Date__c;//
                                         }if(nullCheck(kycOBJ.Passport_Number__c) <> null){
                                             con.PassportNumber__c = kycOBJ.Passport_Number__c;
                                             con.En_PassportNumber__c = kycOBJ.Passport_Number__c;
                                         }if(nullCheck(kycOBJ.Passport_Expiry_Date__c) <> null){
                                             con.PassportExpiryDate__c = kycOBJ.Passport_Expiry_Date__c;
                                         }if(nullCheck(kycOBJ.Passport_Issue_Date__c) <> null){
                                             con.PassportIssueDate__c = kycOBJ.Passport_Issue_Date__c;
                                         }if(nullCheck(kycOBJ.Passport_Issued_Place__c) <> null){
                                             con.PassportIssuancePlace__c = kycOBJ.Passport_Issued_Place__c;
                                             con.Passport_Issued_Place__c = kycOBJ.Passport_Issued_Place__c;
                                         }if(nullCheck(kycOBJ.Nationality__c) <> null){
                                             con.Nationality__c = kycOBJ.Nationality__c;
                                         }if(nullCheck(kycOBJ.Street__c) <> null){
                                             con.MailingStreet = kycOBJ.Street__c;
                                         }if(nullCheck(kycOBJ.City__c) <> null){
                                             con.MailingCity = kycOBJ.City__c;
                                         }if(nullCheck(kycOBJ.State__c) <> null){
                                             con.MailingState = kycOBJ.State__c;
                                         }if(nullCheck(kycOBJ.Postal_Code__c) <> null){
                                             con.MailingPostalCode = kycOBJ.Postal_Code__c;
                                         }if(nullCheck(kycOBJ.Residential_Country__c) <> null){
                                             con.MailingCountry = kycOBJ.Residential_Country__c;
                                         }else if(nullCheck(kycOBJ.Nationality__c) <> null){
                                             con.MailingCountry = kycOBJ.Nationality__c;
                                         }if(nullCheck(kycOBJ.Nationality_in_Arabic__c) <> null){
                                             con.NationalityArabic__c = kycOBJ.Nationality_in_Arabic__c;
                                         }if(nullCheck(kycOBJ.Resident_Status__c) <> null){
                                             con.UAE_Resident_Status__c = kycOBJ.Resident_Status__c =='International' ?'Non-Resident':'Resident';
                                         }if(nullCheck(kycOBJ.EID_Sponsor__c) <> null){
                                             con.EID_Sponsor__c = kycOBJ.EID_Sponsor__c;
                                         }if(nullCheck(kycOBJ.EID_Sponsor_Arabic__c) <> null){
                                             con.EID_Sponsor_Arabic__c =  kycOBJ.EID_Sponsor_Arabic__c;
                                         }if(nullCheck(kycOBJ.Profession_As_Per_EID__c) <> null){
                                             con.Profession_As_Per_EID__c = kycOBJ.Profession_As_Per_EID__c;
                                         }if(nullCheck(kycOBJ.Profession_As_Per_EID_Arabic__c) <> null){
                                             con.Profession_As_Per_EID_Arabic__c = kycOBJ.Profession_As_Per_EID_Arabic__c; 
                                         }if(nullCheck(kycOBJ.Gender__c) <> null){
                                             con.GenderIdentity = kycOBJ.Gender__c == 'M' ? 'Male' : kycOBJ.Gender__c == 'F' ? 'Female' :'';
                                         }if(nullCheck(kycOBJ.EID_Issue_Emirates__c) <> null){
                                             con.EID_Issue_Emirates__c = kycOBJ.EID_Issue_Emirates__c;
                                         }if(nullCheck(kycOBJ.Passport_Issued_Place__c)<> null){
                                             con.PassportIssuancePlace__c = kycOBJ.Passport_Issued_Place__c;
                                         }
                                         if(nullCheck(kycOBJ.Dual_Citizen__c)<> null){
                                             con.Do_you_hold_dual_nationality__c = kycOBJ.Dual_Citizen__c;
                                         }if(nullCheck(kycOBJ.Other_Nationality_If_Applicable__c)<> null){
                                             con.Other_Nationality_If_Applicable__c = kycOBJ.Other_Nationality_If_Applicable__c;
                                         }
                                         if(nullCheck(kycOBJ.Place_Of_Birth__c)<> null){
                                             con.Place_Of_Birth__c = kycOBJ.Place_Of_Birth__c;
                                         }
                                         if(nullCheck(kycOBJ.Resident_Emirates__c)<> null){
                                             con.Resident_Emirates__c = kycOBJ.Resident_Emirates__c;
                                         }
                                         con.EmployerBusinessName__c = kycOBJ.Company_Name__c;
                                         con.KYC_Completed_Date__c = System.today();
                                         con.PurposeOfTransaction__c = System.Label.PurposeOfTransactionCompliance;
                                         try{
                                             con.NoOfPropertyPurchasedWithModon__c = kycOBJ.Contact__r.AccountId <> null ? getNoOfPropertyWithModon(kycOBJ.Contact__r.AccountId) : 0;
                                         }catch(Exception ex){}
                                         ContactUpdateList.add(con);
                                     }
        if(!ContactUpdateList.IsEmpty()){
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.DuplicateRuleHeader.allowSave = true;
            Database.update(ContactUpdateList, dmlOptions);
            //update ContactUpdateList;
            Map<Id,Id> existingDocsMap = new Map<Id,Id>();
            for(Documents__c doc:[SELECT Id,Name,Account__c,Account__r.IsPersonAccount,PrimaryContact__c FROM Documents__c WHERE Name = 'KYC Form - Signed' AND PrimaryContact__c =:ContactUpdateList[0].Id]){
                existingDocsMap.put(doc.PrimaryContact__c,doc.Id);
            }
            List<Documents__c> documentList = new List<Documents__c>();
            for(Contact con: ContactUpdateList){
                Documents__c doc= new Documents__c();
                doc.Name = 'KYC Form - Signed';
                doc.PrimaryContact__c = con.Id;
                doc.DocuSignURL__c = null;
                if(existingDocsMap.containsKey(con.Id)){
                    doc.Id = existingDocsMap.get(con.Id);
                }
                documentList.add(doc);
            }
            if(!documentList.isEmpty()){
                upsert documentList;
                
                SignzyKYCPlatformEvent__e signzy = new SignzyKYCPlatformEvent__e();
                signzy.DocumentID__c = documentList[0].Id;
                signzy.AccountID__c = ContactUpdateList[0].id;
                signzy.KYCID__c = kycRecordId;
                
                Database.SaveResult sr = EventBus.publish(signzy);
                
            }
        }
    }
    
    public static String nullCheck(String value){
        if(value <> null && value <> ''){
            return value;
        }
        return null;
    }
    public static date nullCheck(date value){
        if(value <> null){
            return value;
        }
        return null;
    }
    public static decimal nullCheck(decimal value){
        if(value <> null){
            return value;
        }
        return null;
    }
    public class kycWrapper{
        @AuraEnabled public String emirate;
        @AuraEnabled public String firstName;
        @AuraEnabled public String middleName; // 4.2 <Arvind> 31 August 2026
        @AuraEnabled public String lastName;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public String nationality;
        @AuraEnabled public String dualNationality;
        @AuraEnabled public String pepStatus;
        @AuraEnabled public boolean useAsPermanentAddress;
        @AuraEnabled public String otherCountry;
        @AuraEnabled public String villaNumber;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String employmentStatus;
        @AuraEnabled public String position;
        @AuraEnabled public String employerName;
        @AuraEnabled public String companyName;
        @AuraEnabled public String eidSponsorName;
        @AuraEnabled public String profession;
        @AuraEnabled public String sourceOfIncome;
        @AuraEnabled public String otherSourceOfIncome;
        @AuraEnabled public String salaryrange;
        @AuraEnabled public boolean isKycExpired;
        @AuraEnabled public boolean kycCompleted;
        @AuraEnabled public String dualNationalityCountry;
        @AuraEnabled public boolean isCorporateAccount;
        @AuraEnabled public boolean IsTradeLicenseUploaded;
        @AuraEnabled public String OrgcompanyName;
        @AuraEnabled public String tradeLicenseNumber;
        @AuraEnabled public date tradeLicenseExpiryDate;
        @AuraEnabled public String bussinessAddr;
        @AuraEnabled public String countryAddr;
        @AuraEnabled public String natureBusiness;
        @AuraEnabled public String LegalStructure;
    }
    public class JourneyResponseWrapper {
        public Result result;
    }
    public class Result {
        public String journeyId;
        public String journeyUrl;
        public Long createdAt;
        public String ttl;
    }
    public static date handleStringData(String dateString){
        try{
            List<String> dateParts = dateString.contains('/') ? dateString.split('/'):null; 
            if(dateParts <> null && dateParts.size() > 0){
                Integer day = Integer.valueOf(dateParts[0]);     
                Integer month = Integer.valueOf(dateParts[1]); 
                Integer year = Integer.valueOf(dateParts[2]);   
                
                Date myDate = Date.newInstance(year, month, day);
                
                System.debug(myDate); 
                return myDate;
            }
        }catch(Exception ex){
            system.debug('exception:'+ex);
            return null;
        }
        return null;
    }
    @AuraEnabled
    public static String validateGenerateKYCDocument(Id docId){
        Id accountId = [SELECT Id,Account__c FROM Documents__c WHERE Id=:docId LIMIT 1].Account__c;
            String soqlQuery = queryByFieldSet('Account', 'PersonAccountFiledSet');
        if(soqlQuery <> null && soqlQuery <> '' && accountId <> null){
            soqlQuery = soqlQuery+' WHERE Id=:accountId';
            List<sObject> sObjectList = Database.queryWithBinds(
                soqlQuery,
                new Map<String, Object>{ 'accountId' => accountId },
                AccessLevel.SYSTEM_MODE
            );
            if(!sObjectList.isEmpty() && sObjectList.size()> 0){
                Set<String> emptyFieldSet = areAnyFieldsEmpty(sObjectList[0],'Account','PersonAccountFiledSet');
                system.debug('emptyFieldSet:'+emptyFieldSet);

                    if (!emptyFieldSet.isEmpty()) {
                    String errorFileds = '';
                    for(String field: emptyFieldSet){
                        errorFileds +=field+',';
                    }
                    errorFileds = errorFileds.removeEnd(',');
                    return 'Error : '+errorFileds+' Missing!';
                    }
                return 'Success!';
                }
            }
            return 'Error! Please Contact Admin.';
    }
    public static Set<String> areAnyFieldsEmpty(SObject record, String sObjectName, String fieldSetName) {
        if (record == null) {
            System.debug(LoggingLevel.WARN, 'FieldSetUtils.areAnyFieldsEmpty was called with a null record.');
            //return true;
        }
        Set<String> emptyFieldsset = new Set<String>();
        Map<String, Schema.FieldSet> fieldSetMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fieldSets.getMap();

        if (!fieldSetMap.containsKey(fieldSetName)) {
            throw new AuraHandledException('FieldSet not found: ' + fieldSetName + ' on object ' + sObjectName);
        }

        List<Schema.FieldSetMember> fieldSetMembers = fieldSetMap.get(fieldSetName).getFields();

        for (Schema.FieldSetMember fsm : fieldSetMembers) {
            String fieldApiName = fsm.getFieldPath();
            Object fieldValue = record.get(fieldApiName);
            if (fieldValue == null || (fieldValue instanceof String && String.isBlank((String) fieldValue))) {
                System.debug(LoggingLevel.INFO, 'Empty field found: ' + fieldApiName);
                emptyFieldsset.add(fsm.getLabel());
                return emptyFieldsset;
            }
        }

        return null;
    }
    public static String queryByFieldSet(
        String sObjectName,
        String fieldSetName
    ) {
        Map<String, Schema.FieldSet> fieldSetMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fieldSets.getMap();
        
        if (!fieldSetMap.containsKey(fieldSetName)) {
            throw new AuraHandledException('FieldSet not found: ' + fieldSetName + ' on object ' + sObjectName);
        }
        
        List<String> fieldsToQuery = new List<String>();
        for (Schema.FieldSetMember fsm : fieldSetMap.get(fieldSetName).getFields()) {
            fieldsToQuery.add(fsm.getFieldPath());
        }
        
        if (fieldsToQuery.isEmpty()) {
            throw new AuraHandledException('FieldSet is empty: ' + fieldSetName + ' on object ' + sObjectName);
        }
        
        String soqlQuery = 'SELECT ' + String.join(fieldsToQuery, ', ') + ' FROM ' + sObjectName;
        
        System.debug(LoggingLevel.INFO, 'Dynamic SOQL Query: ' + soqlQuery);
        return soqlQuery;
    }
    @AuraEnabled(cacheable=true)
    public static expiryTrackerWrapper getAccountDetails(String recordId) {
        expiryTrackerWrapper eWrap = new expiryTrackerWrapper();
        try {
            Id recordIdvar = (Id) recordId;
            String objectName = recordIdvar.getSObjectType().getDescribe().getName();
            if(objectName !='Contact'){
                List<Account> accountList = [
                    SELECT EmiratesIDExpiryDate__pc, PassportExpiryDate__pc, KYC_Completed_Date__c
                    FROM Account
                    WHERE Id = :recordIdvar
                    LIMIT 1
                ];
                eWrap.accountData =  accountList.size() > 0 ? accountList[0]:null;
                eWrap.objectName = 'Account';
            }else if(objectName =='Contact'){
                List<Contact> ContactList = [
                    SELECT EmiratesIDExpiryDate__c, PassportExpiryDate__c, KYC_Completed_Date__c
                    FROM Contact
                    WHERE Id = :recordIdvar
                    LIMIT 1
                ];
                eWrap.contactData = ContactList.size() > 0 ? ContactList[0]:null;
                eWrap.objectName = 'Contact';
            }
            return eWrap;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching account details: ' + e.getMessage());
        }
    }
    public class expiryTrackerWrapper{
        @AuraEnabled public Account accountData;
        @AuraEnabled public Contact contactData;
        @AuraEnabled public String objectName;
    }
    public static List<String> mapSourceOfIncome(String employmentSts){
        /**2.2 Source Of Income fix & Dynamic Value fix **/
        List<String> employedSourceOfIncome = System.Label.SignzyemployedSourceOfIncome.contains(',')?System.Label.SignzyemployedSourceOfIncome.split(','):new List<String>{System.Label.SignzyemployedSourceOfIncome};
        List<String> selfemployedSourceOfIncome = System.Label.SignzyselfemployedSourceOfIncome.contains(',')?System.Label.SignzyselfemployedSourceOfIncome.split(','):new List<String>{System.Label.SignzyselfemployedSourceOfIncome}; 
        List<String> notEmployed = System.Label.SignzynotEmployed.contains(',')?System.Label.SignzynotEmployed.split(','):new List<String>{System.Label.SignzynotEmployed};  
        List<String> retired = System.Label.Signzyretired.contains(',')?System.Label.Signzyretired.split(','):new List<String>{System.Label.Signzyretired}; 
        List<String> Student = System.Label.SignzyStudentSourceOfIncome.contains(',')?System.Label.SignzyStudentSourceOfIncome.split(','):new List<String>{System.Label.SignzyStudentSourceOfIncome}; 
        List<String> Homemaker = System.Label.SignzyHomemakerSourceOfIncome.contains(',')?System.Label.SignzyHomemakerSourceOfIncome.split(','):new List<String>{System.Label.SignzyHomemakerSourceOfIncome}; 
                                
        Map<String,List<String>> mapIncomeSourceMap = new Map<String,List<String>>();
        mapIncomeSourceMap.put('Employed',employedSourceOfIncome);
        mapIncomeSourceMap.put('Self Employed',selfemployedSourceOfIncome);
        mapIncomeSourceMap.put('Unemployed',notEmployed);
        mapIncomeSourceMap.put('Retired',retired);
        mapIncomeSourceMap.put('Student',Student);
        mapIncomeSourceMap.put('House Wife',Homemaker);
        
        if(employmentSts <> null && mapIncomeSourceMap.containsKey(employmentSts)){
            return mapIncomeSourceMap.get(employmentSts);
        }
        return null;
    }
    @future(callout=true)
    public static void attachImageFromUrl(Id recordId, String imageUrl,String fileName,String folderName) {
        /** 2.0 Fixed the Document folders name to Store Signzy Documents in Salesforce **/
        List<String> eidDocFrontNames = System.label.SignzyEIDDocFrontName.contains(',') ? System.label.SignzyEIDDocFrontName.split(','):new List<String>{System.label.SignzyEIDDocFrontName};
        List<String> eidDocBackNames = System.label.SignzyEIDDocBackName.contains(',') ? System.label.SignzyEIDDocBackName.split(','):new List<String>{System.label.SignzyEIDDocBackName};
        List<String> passportDocNames = System.label.SignzyPassportDocName.contains(',') ? System.label.SignzyPassportDocName.split(','):new List<String>{System.label.SignzyPassportDocName};
        if(folderName!=null){
            if(eidDocFrontNames.contains(folderName)){
                folderName =  'Emirates/National ID Front';
            }else if(eidDocBackNames.contains(folderName)){
                folderName =  'Emirates/National ID Back';
            } else if(passportDocNames.contains(folderName)){
                folderName = 'Passport';
            }
        }
        // 1. Make the HTTP Callout
        HttpRequest request = new HttpRequest();
        request.setEndpoint(imageUrl);
        request.setMethod('GET');
        request.setTimeout(120000); // 120 second timeout
        
        Http http = new Http();
        HttpResponse response;
        
        try {
            response = http.send(request);
            
            // 2. Check for a successful response and get the image data as a Blob
            if (response.getStatusCode() == 200) {
                
                Map<String,Id> docMap = new Map<String,Id>();
                String objectName = recordId.getSObjectType().getDescribe().getName();
                if(objectName != 'Contact'){
                    Id primaryContactId = null;
                    for(Account accObj:[SELECT Id,PersonContactId FROM Account WHERE Id=:recordId AND IsPersonAccount = true]){
                        primaryContactId = accObj.PersonContactId;
                    }
                    if(primaryContactId != null){
                        for(Documents__c doc:[SELECT Id,Name FROM Documents__c WHERE PrimaryContact__c =:primaryContactId]){
                            docMap.put(doc.Name,doc.Id); 
                        } 
                    }else{
                        for(Documents__c doc:[SELECT Id,Name FROM Documents__c WHERE Account__c =:recordId]){
                            docMap.put(doc.Name,doc.Id); 
                        }
                    }
                }else if(objectName == 'Contact'){
                    for(Documents__c doc:[SELECT Id,Name FROM Documents__c WHERE PrimaryContact__c =:recordId]){
                        docMap.put(doc.Name,doc.Id); 
                    }
                }
                
                Id parentId = null;
                Documents__c doc = new Documents__c();
                if(docMap.containsKey(folderName)){
                    doc.Id = docMap.get(folderName);
                }
                doc.Name = folderName;
                
                if(objectName != 'Contact'){
                    for(Account accObj:[SELECT Id,PersonContactId FROM Account WHERE Id =:recordId AND IsPersonAccount = true]){
                        doc.PrimaryContact__c = accObj.PersonContactId;   
                    }
                    if(doc.PrimaryContact__c == null){
                        doc.Account__c = recordId;
                    }
                }else if(objectName == 'Contact'){
                    doc.PrimaryContact__c = recordId;
                }
                upsert doc;
                
                Blob imageBlob = response.getBodyAsBlob();
                
                // 3. Create the Salesforce File (ContentVersion)
                ContentVersion cv = new ContentVersion();
                cv.Title              = fileName;
                cv.PathOnClient       = fileName+'.jpg';
                cv.VersionData        = imageBlob;
                cv.Origin             = 'H';
                cv.FirstPublishLocationId = doc.Id;         // <- critical to avoid private library
                // cv.NetworkId = Network.getNetworkId();    // uncomment for Experience Cloud
                
                insert cv;
                
                // After inserting the ContentVersion, get the ContentDocumentId
                Id contentDocumentId = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                    LIMIT 1
                ].ContentDocumentId;
                
                // 4. Link the File to the record (ContentDocumentLink) — might already exist;
                // protect against DUPLICATE_VALUE if FirstPublishLocationId created it.
                try {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = contentDocumentId;
                    cdl.LinkedEntityId    = doc.Id;
                    cdl.ShareType         = 'V';
                    cdl.Visibility        = 'AllUsers';
                    insert cdl;
                } catch (DmlException ex) {
                    // Ignore “already linked” duplicates; rethrow others
                    if (ex.getDmlType(0) != StatusCode.DUPLICATE_VALUE) {
                        throw ex;
                    }
                }
            } else {
                // Handle errors: Log the issue, send an email, etc.
                System.debug('Error from image download: ' + response.getStatus());
            }
            
        } catch (Exception e) {
            // Handle exceptions (e.g., timeout, invalid URL)
            System.debug('An exception occurred: ' + e.getMessage());
        }
    }
    public static String handleTradeLicenseVerificationAPI(String base64,String accountId,String contentType){
        base64 = 'data:'+contentType+';base64,'+base64;// 'data:image/jpeg;base64,'+base64;
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();
        String body ='{"files":["'+base64+'"]}';
        System.debug('body:'+body);
        request.setMethod('POST');
        // 4.3: sandbox vs production from Modon_Generic_Metadata__mdt — no comment/uncomment
        Modon_Generic_Metadata__mdt kycMeta = isSandbox()
            ? Modon_Generic_Metadata__mdt.getInstance('CustomerKYCHandler')
            : Modon_Generic_Metadata__mdt.getInstance('CustomerKYCHandler_Production');
        request.setEndPoint(kycMeta?.Endpoint__c);
        request.setBody(body);
        request.setTimeout(120000);
        request.setHeader('Content-Type','application/json');
        request.setHeader('Authorization', kycMeta?.Api_Key__c); // 4.3
        Http http = new Http();
        response = http.send(request);
        System.debug('response::'+response.getBody());
        if(response.getStatusCode() != 200){
            return response.getBody();
        }else  if(response.getStatusCode() == 200 || response.getStatusCode() == 201){
            SignzyTradeLicenseWrapper responseWrapper = SignzyTradeLicenseWrapper.parse(response.getBody());
            System.debug('responseWrapper:'+responseWrapper);
            if(responseWrapper <> null && responseWrapper.error == null){
                mapKYCTradeLicenseValues(responseWrapper,accountId,response.getBody());
                return 'Success';
            }else if(responseWrapper <> null && responseWrapper.error != null){
                return responseWrapper.error.message;
            }
        }
        return 'Success';
    }
    public static blob getDataBlobValue(Id linkedId){
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :linkedId 
            LIMIT 1
        ]; 
        if(!links.isEmpty()){ 
            ContentVersion version = [
                SELECT Id, Title, FileType, VersionData 
                FROM ContentVersion 
                WHERE ContentDocumentId = :links[0].ContentDocumentId 
                ORDER BY VersionNumber DESC 
                LIMIT 1
            ];
            
            return version.VersionData;
        }
        return null;
    }
    @AuraEnabled
    public static String handlePOAFile(String base64,String contactEncryptId,String fileName){
        try{
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64);
            
            insert cv;
            System.debug('contactEncryptId:'+contactEncryptId);
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            Id contactId = EncryptionService.decrypt(contactEncryptId);
            Id poaId = [SELECT Id FROM Power_of_Attorney__c WHERE Contact__c =:contactId LIMIT 1].Id;
            Id documentIdPOA = null;
            for(Documents__c doc:[SELECT Id FROM Documents__c WHERE Power_of_Attorney__c =:poaId AND Name = 'Power Of Attorney']){
                documentIdPOA = doc.Id;
            }
            Documents__c doc = new Documents__c();
            doc.Id = documentIdPOA;
            doc.Name = 'Power Of Attorney';
            doc.Power_of_Attorney__c = poaId;
            upsert doc;
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = doc.Id; // <--- Map the LinkedEntityId
            cdl.ShareType = 'V'; // 'V' for Viewer
            cdl.Visibility = 'AllUsers'; // Makes it visible to all community users
            insert cdl;
            return 'Success';
        }catch(Exception ex){
            return 'Error! '+ex.getMessage();  
        }
    }
    @AuraEnabled
    public static String tradeLicenseuploadFile(String base64, String fileName,String accountId){
        try {
            String fileType = fileName.substringAfterLast('.');
            if (!fileType.equalsIgnoreCase('pdf') && !fileType.equalsIgnoreCase('png') && !fileType.equalsIgnoreCase('jpg') && !fileType.equalsIgnoreCase('jpeg')) {
                return 'Error: Invalid file type. Only PDF, PNG, and JPG are accepted.';
            }
            system.debug('accountId:'+accountId);
            String decryptContactId = EncryptionService.decrypt(accountId);
            accountId = [SELECT AccountId FROM Contact WHERE Id =:decryptContactId LIMIT 1].AccountId;
            String message = handleTradeLicenseVerificationAPI(base64,accountId,EXT_TO_MIME.get(fileType));
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64);
            
            insert cv;
            
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            Id documentIdtradeLicense = null;
            for(Documents__c doc:[SELECT Id FROM Documents__c WHERE Account__c =:accountId AND Name = 'Commercial trade License (Resident)']){
                documentIdtradeLicense = doc.Id;
            }
            Documents__c doc = new Documents__c();
            doc.Id = documentIdtradeLicense;
            doc.Name = 'Commercial trade License (Resident)';
            doc.Account__c = accountId;
            upsert doc;
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = doc.Id; // <--- Map the LinkedEntityId
            cdl.ShareType = 'V'; // 'V' for Viewer
            cdl.Visibility = 'AllUsers'; // Makes it visible to all community users
            insert cdl;
            
            return message;
        }catch(Exception e){
            return 'Error! '+e.getMessage();
        }
    }
    public static void mapKYCTradeLicenseValues(SignzyTradeLicenseWrapper responseWrapper, String accountId, String response){
        Id recordTypeId = Schema.SObjectType.KYC_Response__c.getRecordTypeInfosByDeveloperName().get('Corporate_KYC').getRecordTypeId();
        if(responseWrapper.result <> null){
            KYC_Response__c kyc = new KYC_Response__c();
            kyc.Customer__c = accountId;
            kyc.RecordTypeId = recordTypeId;    
            
            Account acc = new Account();
            acc.Id = accountId;
            acc.Is_Trade_License_Uploaded__c = true;
            acc.PurposeOfTransaction__c = System.Label.PurposeOfTransactionCompliance;
            if(responseWrapper.result.licenseDetails <> null){
                SignzyTradeLicenseWrapper.LicenseDetails lcDetails = responseWrapper.result.licenseDetails;
                kyc.Trade_License_Number__c = lcDetails.licenseNumber;
                kyc.Parent_License_Number__c = lcDetails.parentLicenseNumber;
                kyc.Company_Name__c = lcDetails.companyName;
                kyc.Trade_Name__c = lcDetails.tradeName;
                kyc.Operating_Number__c = lcDetails.operatingNumber;
                kyc.Legal_Type__c = lcDetails.legalType;
                kyc.Trade_License_Issue_Date__c = getTradeLicenseDateFormat(lcDetails.issueDate);// lcDetails.issueDate;
                kyc.Trade_License_Expiry_Date__c = getTradeLicenseDateFormat(lcDetails.expiryDate); // lcDetails.expiryDate;
                kyc.Business_Unit__c = lcDetails.businessUnit;
                kyc.D_B_D_U_N_S_number__c = lcDetails.duNsNumber;
                kyc.Main_License_Number__c = lcDetails.mainLicenseNumber;
                kyc.Register_Number_of_the_Company__c = lcDetails.registerNumber;
                kyc.DCCI_Number__c = lcDetails.dcciNumber;
                kyc.ACCI_Number__c = lcDetails.acciNumber;
                kyc.ADCCI_Number__c = lcDetails.adcciNumber;
                kyc.Type_of_the_License__c = lcDetails.type;
                
                acc.Legal_Type__c = lcDetails.legalType;
                
                if (lcDetails.licenseNumber != null && lcDetails.licenseNumber != 'NA') {
                    acc.TradeLicenseNumber__c = lcDetails.licenseNumber;
                    acc.Trade_License_Number__c = lcDetails.licenseNumber;
                    acc.UnifiedNumber__c  = lcDetails.licenseNumber;
                }
                if (lcDetails.companyName != null && lcDetails.companyName != 'NA') {
                    acc.Company_Name_as_per_Trade_License__c = lcDetails.companyName;
                    acc.Name = lcDetails.companyName;
                }
                if (lcDetails.tradeName != null && lcDetails.tradeName != 'NA') {
                    acc.TradeName__c = lcDetails.tradeName;
                }
                if (lcDetails.registerNumber != null && lcDetails.registerNumber != 'NA') {
                    acc.Register_Number_of_the_Company__c = lcDetails.registerNumber;
                }
                if (kyc.Trade_License_Expiry_Date__c != null) {
                    acc.TradeLicenseExpiryDate__c = kyc.Trade_License_Expiry_Date__c;
                }
                if (kyc.Trade_License_Issue_Date__c != null) {
                    acc.Trade_License_Issue_Date__c = kyc.Trade_License_Issue_Date__c;
                }
                
            }
            if(responseWrapper.result.otherLicenseDetails <> null){
                SignzyTradeLicenseWrapper.OtherLicenseDetails othrLcDetails = responseWrapper.result.otherLicenseDetails;
                kyc.The_Dubai_Chamber_Number__c = othrLcDetails.dubaiChamberNumber;
                kyc.Established_Card_Number_MOHRE__c = othrLcDetails.establishmentCardMohere;
                kyc.Federation_Registration_Number__c = othrLcDetails.fedRegNumber;
                kyc.Tax_Registration_Number__c = othrLcDetails.taxRegNumber;
                kyc.Establishment_Date__c = getTradeLicenseDateFormat(othrLcDetails.establishmentDate); //othrLcDetails.establishmentDate
                kyc.Cham_M_Number__c = othrLcDetails.chamMNumber;
                kyc.Company_File_Number__c = othrLcDetails.companyFileNumber;
                kyc.Account_Number_associate_With_Trade_LIC__c = othrLcDetails.accountNumber;
                kyc.VAT_Number__c = othrLcDetails.vatNumber;
                kyc.Country_Of_Origin__c = othrLcDetails.countryOfOrigin;
                
                if (othrLcDetails.vatNumber != null && othrLcDetails.vatNumber != 'NA') {
                    acc.UAEVATRegisterNumber__c = othrLcDetails.vatNumber;
                }
                if (othrLcDetails.taxRegNumber != null && othrLcDetails.taxRegNumber != 'NA') {
                    acc.Company_Tax_Registration_Number__c = othrLcDetails.taxRegNumber;
                }
                if (othrLcDetails.countryOfOrigin != null && othrLcDetails.countryOfOrigin != 'NA') {
                    acc.Company_Country_Of_Origin__c = othrLcDetails.countryOfOrigin;
                }
                if (othrLcDetails.establishmentCardMohere != null && othrLcDetails.establishmentCardMohere != 'NA') {
                    acc.Established_Card_Number_MOHRE__c = othrLcDetails.establishmentCardMohere;
                }
                if (kyc.Establishment_Date__c != null) {
                    acc.DateOfEstablishment__c = kyc.Establishment_Date__c;
                }
                
            }
            if(responseWrapper.result.licenseActivities <> null && responseWrapper.result.licenseActivities.activities <> null){
                kyc.License_Activities__c = String.valueOf(responseWrapper.result.licenseActivities.activities);
                acc.Nature_Of_Business__c = kyc.License_Activities__c;
            }
            if(responseWrapper.result.address <> null){
                SignzyTradeLicenseWrapper.Address addr = responseWrapper.result.address;
                kyc.Company_TelephoneTRD__c = addr.telephone;
                kyc.Company_MobileNumberTRD__c = addr.mobileNumber;
                kyc.Unit__c = addr.unit;
                kyc.Unit_Number__c = addr.unitNumber;
                kyc.Premises_Number__c = addr.premisesNumber;
                kyc.Floor_Number__c = addr.floorNumber;
                kyc.Building_Name__c = addr.buildingName;
                kyc.Building_Number__c = addr.buildingNumber;
                kyc.Business_Unit__c = addr.businessUnit;
                kyc.Area_Name__c = addr.areaName;
                kyc.Zone__c = addr.zone;
                kyc.Address__c = addr.address;
                kyc.StreetTRD__c = addr.street;
                kyc.Area_Name__c = addr.areaName;
                kyc.Contact_Email__c = addr.email;
                
                List<String> streetParts = new List<String>();
                if (addr.buildingName != 'NA') streetParts.add(addr.buildingName);
                if (addr.buildingNumber != 'NA') streetParts.add('Bldg ' + addr.buildingNumber);
                if (addr.floorNumber != 'NA') streetParts.add('Floor ' + addr.floorNumber);
                if (addr.unitNumber != 'NA') streetParts.add('Unit ' + addr.unitNumber);
                if (addr.address != 'NA') streetParts.add(addr.address);
                if (addr.street != 'NA') streetParts.add(addr.street);
                
                acc.ShippingStreet = String.join(streetParts, ', ');
                acc.BillingStreet = String.join(streetParts, ', ');
                if (addr.areaName != 'NA') {
                    acc.ShippingCity = addr.areaName;
                    acc.BillingCity = addr.areaName;
                } else if (addr.mainArea != 'NA') {
                    acc.ShippingCity = addr.mainArea;
                    acc.BillingCity = addr.mainArea;
                } else if (addr.area != 'NA') {
                    acc.ShippingCity = addr.area;
                    acc.BillingCity = addr.area;
                }
                
                if (addr.region != 'NA') {
                    acc.ShippingState = addr.region;
                    acc.billingState = addr.region;
                }
                
                if (addr.zone != 'NA') {
                    acc.ShippingPostalCode = addr.zone;
                    acc.BillingPostalCode = addr.zone;
                } else if (addr.makaniNumber != 'NA') {
                    acc.ShippingPostalCode = addr.makaniNumber;
                    acc.BillingPostalCode = addr.makaniNumber;
                }
                if (addr.telephone != 'NA') acc.Phone = addr.telephone;
                //   if (addr.mobileNumber != 'NA') acc.Mobile_Number__c = addr.mobileNumber; 
                if (addr.email != 'NA') acc.Company_Email_Address__c = addr.email;
                
                acc.Company_Address__c = addr.address;
                
            }
            if(responseWrapper.result.licensePartners <> null){
                kyc.License_Partners__c = String.valueOf(responseWrapper.result.licensePartners);
            }
            for(KYC_Response__c kycObj: [SELECT Id FROM KYC_Response__c WHERE Customer__c =:accountId AND RecordTypeId =:recordTypeId ORDER BY CreatedDate DESC LIMIT 1]){
                kyc.Id = kycObj.Id;
            }
            kyc.KYC_Completed_Date__c = System.today();
            upsert kyc;
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.DuplicateRuleHeader.allowSave = true;
            Database.update(acc, dmlOptions);
            //update acc;
            
            if(response <> null){
                createFileLog(kyc.Id,response,'tradeLicenseExtraction-'+datetime.now());
            }
        }
    }
    @AuraEnabled
    public static Account getTradeLicenseInfo(String contactIdStr){
        if(contactIdStr <> null){
            String contactId = EncryptionService.decrypt(contactIdStr);
            Id AccountId = [SELECT Id,AccountId FROM Contact WHERE Id=:contactId LIMIT 1].AccountId;
            return [SELECT Id,Name,Company_Name_as_per_Trade_License__c,TradeLicenseNumber__c,AddressFormula__c,Company_Country_Of_Origin__c,TradeLicenseExpiryDate__c,Nature_Of_Business__c,Company_Address__c FROM Account WHERE Id =:AccountId LIMIT 1];
        }
        return null;
    }
    public static date getTradeLicenseDateFormat(String dateValue){
        try{
            if(dateValue <> null && dateValue <> '' && dateValue.contains('/')){
                List<String> parts = dateValue.split('/');
                Date expiryDate = Date.newInstance(
                    Integer.valueOf(parts[2]), // year
                    Integer.valueOf(parts[1]), // month
                    Integer.valueOf(parts[0])  // day
                );
                return expiryDate;
            }
            return null;
        }catch(Exception ex){
            system.debug('Exception ex:'+ex.getMessage());
            return null;
        }
    }
//2.9 Arvind
    @AuraEnabled
    public static void getSignedKYCDocument(String docId){
        if(docId <> null){  
            SignzyDocuSignDocumentHelper.fetchSignedCopyToFiles(docId);
            
            // 01 Sept 2026 - Rushi Patel - Update KYC Response status when embedded signing completes
            try {
                Documents__c doc = [SELECT Id, PrimaryContact__c, PrimaryContact__r.AccountId, Account__c, Account__r.PersonContactId FROM Documents__c WHERE Id = :docId LIMIT 1];
                Set<Id> targetIds = new Set<Id>();
                
                if (doc.PrimaryContact__c != null) {
                    targetIds.add(doc.PrimaryContact__c);
                    if (doc.PrimaryContact__r.AccountId != null) {
                        targetIds.add(doc.PrimaryContact__r.AccountId);
                    }
                }
                if (doc.Account__c != null) {
                    targetIds.add(doc.Account__c);
                    if (doc.Account__r.PersonContactId != null) {
                        targetIds.add(doc.Account__r.PersonContactId);
                    }
                }
                
                if (!targetIds.isEmpty()) {
                    List<KYC_Response__c> kycList = [SELECT Id, Journey_Status__c FROM KYC_Response__c 
                                                     WHERE (Contact__c IN :targetIds OR Customer__c IN :targetIds) 
                                                     ORDER BY CreatedDate DESC LIMIT 1];
                    if (!kycList.isEmpty() && kycList[0].Journey_Status__c != 'DocuSign Signature Complete') {
                        kycList[0].Journey_Status__c = 'DocuSign Signature Complete';
                        update kycList;
                    }
                }
            } catch (Exception e) {
                System.debug('Error updating KYC Response DocuSign status: ' + e.getMessage());
            }
        }
    }
   /* @AuraEnabled
    public static void getSignedKYCDocument(String docId){
        if(docId <> null){  
            if([SELECT Id FROM Documents__c WHERE Status__c != 'Uploaded' AND Id =:docId].size() > 0){
                SignzyDocuSignDocumentHelper.fetchSignedCopyToFiles(docId);
            }
        }
    }*/
    public static decimal getNoOfPropertyWithModon(Id recordId){
        try{
            return [SELECT Id FROM SalesOrder__c WHERE CustomerAccount__c =:recordId AND (NOT Status__c IN ('Cancelled','System cancelled','Cancelled SR','Voided'))  LIMIT 100].size();
        }catch(Exception ex){
            return 0;
        }
    }

    /** 4.2 <Arvind> 31 August 2026 - Signzy returns every given name inside firstName.
     *  Returns [0] = first name, [1] = middle name (null when there is only one token).
     *  "MOHAMMED ALI HASSAN" -> ['MOHAMMED', 'ALI HASSAN']
     *  "MOHAMMED"            -> ['MOHAMMED', null]
     **/
    public static List<String> splitGivenNames(String givenNames){
        List<String> result = new List<String>{null, null};
        if(String.isBlank(givenNames)){
            return result;
        }
        List<String> parts = givenNames.trim().replaceAll('\\s+', ' ').split(' ');
        result[0] = parts[0];
        if(parts.size() > 1){
            List<String> middleParts = new List<String>();
            for(Integer i = 1; i < parts.size(); i++){
                middleParts.add(parts[i]);
            }
            result[1] = String.join(middleParts, ' ');
        }
        return result;
    }

    /** 4.2 <Arvind> 31 August 2026 - Fallback used when Signzy sends one combined "names" string.
     *  Returns [0] = first, [1] = middle, [2] = last.
     *  A single token is treated as the surname, matching the previous behaviour.
     *  "MOHAMMED ALI HASSAN AL MANSOORI" -> ['MOHAMMED', 'ALI HASSAN AL', 'MANSOORI']
     **/
    public static List<String> splitFullName(String fullName){
        List<String> result = new List<String>{null, null, null};
        if(String.isBlank(fullName)){
            return result;
        }
        List<String> parts = fullName.trim().replaceAll('\\s+', ' ').split(' ');
        if(parts.size() == 1){
            result[2] = parts[0];
            return result;
        }
        result[0] = parts[0];
        result[2] = parts[parts.size() - 1];
        if(parts.size() > 2){
            List<String> middleParts = new List<String>();
            for(Integer i = 1; i < parts.size() - 1; i++){
                middleParts.add(parts[i]);
            }
            result[1] = String.join(middleParts, ' ');
        }
        return result;
    }

    /** 4.2 <Arvind> 31 August 2026 - Join First + Middle + Last, skipping blanks. **/
    public static String buildFullName(String firstName, String middleName, String lastName){
        List<String> parts = new List<String>();
        if(String.isNotBlank(firstName)){
            parts.add(firstName.trim());
        }
        if(String.isNotBlank(middleName)){
            parts.add(middleName.trim());
        }
        if(String.isNotBlank(lastName)){
            parts.add(lastName.trim());
        }
        return parts.isEmpty() ? '' : String.join(parts, ' ');
    }

    public static String nameToProperCase(String input) {
        if (String.isBlank(input)) return input;

        // Trim + collapse multiple spaces into single space
        String s = input.trim().replaceAll('\\s+', ' ').toLowerCase();

        // Title-case each word
        List<String> parts = s.split(' ');
        for (Integer i = 0; i < parts.size(); i++) {
            String w = parts[i];
            if (w.length() == 0) continue;

            parts[i] = w.substring(0, 1).toUpperCase() +
                       (w.length() > 1 ? w.substring(1) : '');
        }
        return String.join(parts, ' ');
    }
    // Formats to 784-YYYY-XXXXXXX-X
    public static String formatEmiratesId(String input) {
        if (String.isBlank(input)) return input;

        // Keep digits only (removes spaces, dashes, etc.)
        String digits = input.replaceAll('[^0-9]', '');

        // Emirates ID is typically 15 digits
        if (digits.length() != 15) {
            // You can also throw an exception if you prefer
            return input; // or: throw new IllegalArgumentException('Invalid Emirates ID length');
        }

        return digits.substring(0, 3) + '-' +
               digits.substring(3, 7) + '-' +
               digits.substring(7, 14) + '-' +
               digits.substring(14, 15);
    }

    // Optional: quick validity check (digits-only + length + starts with 784)
    public static Boolean isValidEmiratesId(String input) {
        if (String.isBlank(input)) return false;
        String digits = input.replaceAll('[^0-9]', '');
        return digits.length() == 15 && digits.startsWith('784');
    }
    /* public static void mapKYCDocuments(List<Documents__c> newList, Map<Id,Documents__c> oldMap){
List<String> lstAccountDocNames = System.Label.PassfortCompanyDocNames.split(',');
List<String> lstContactDocNames = System.Label.PassfortIndividualDocNames.split(',');
List<String> lstAccountOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
List<String> lstContactOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');
Map<String,String> docNameMap = new Map<String,String>();
docNameMap.put('Emirates/National ID Front','Emirates ID');
docNameMap.put('Emirates/National ID Back','Emirates ID');
docNameMap.put('Passport','Passport');
docNameMap.put('KYC Form - Signed','Signed KYC and Wealth Form');

Set<Id> accountId =new Set<Id>();
Set<Id> personaccountId =new Set<Id>();
Set<Id> contactId =new Set<Id>();
Map<String,Id> targetDocIdMap = new Map<String,Id>();
for(Documents__c doc: newList){
Documents__c oldData = oldMap <> null ? oldMap.get(doc.Id) : null;
if((doc.Account__c <> null || doc.PrimaryContact__c <> null)  && doc.Status__c == 'Uploaded' && (lstContactDocNames.contains(doc.Name) || lstAccountDocNames.contains(doc.Name)) && (oldData == null || (oldData <> null && (oldData.Account__c <> doc.Account__c || oldData.PrimaryContact__c <> doc.PrimaryContact__c || oldData.Status__c <> doc.Status__c)))){
if(doc.Account__c <> null){
personaccountId.add(doc.Account__c);
}
}
}
Map<Id,Id> personContactIdmap = new Map<Id,Id>();
if(!personaccountId.isEmpty()){
for(Account acc:[SELECT Id,PersonContactId FROM Account WHERE Id IN:personaccountId AND IsPersonAccount = true]){
personContactIdmap.put(acc.Id,acc.PersonContactId);
}
}
for(Documents__c doc:newList){
Documents__c oldData = oldMap <> null ?  oldMap.get(doc.Id) : null;
if((doc.Account__c <> null || doc.PrimaryContact__c <> null)  && doc.Status__c == 'Uploaded' && (lstContactDocNames.contains(doc.Name) || lstAccountDocNames.contains(doc.Name)) && (oldData == null || (oldData <> null && (oldData.Account__c <> doc.Account__c || oldData.PrimaryContact__c <> doc.PrimaryContact__c || oldData.Status__c <> doc.Status__c)))){
if(doc.Account__c <> null && lstAccountOptionalDocNames.contains(doc.Name)){
accountId.add(doc.Account__c);
targetDocIdMap.put(doc.Name+doc.Account__c,doc.Id);
}
if((doc.PrimaryContact__c <> null && lstContactDocNames.contains(doc.Name)) || (personContactIdmap.containskey(doc.Account__c))){
Id contactIdvar = personContactIdmap.containskey(doc.Account__c) ? personContactIdmap.get(doc.Account__c) : doc.PrimaryContact__c;
contactId.add(contactIdvar);
targetDocIdMap.put(doc.Name+contactIdvar,doc.Id);
} 
}
}
System.debug('targetDocIdMap:'+targetDocIdMap);
if(!targetDocIdMap.values().isEmpty()){
List<ContentDocumentLink> alldocLinks = [
SELECT Id,
ContentDocumentId,
LinkedEntityId,
ContentDocument.CreatedDate
FROM ContentDocumentLink
WHERE LinkedEntityId IN :targetDocIdMap.values()
ORDER BY ContentDocument.CreatedDate DESC
];
System.debug('alldocLinks:'+alldocLinks);
Map<Id, Id> docToContentDocumentId = new Map<Id, Id>();
for (ContentDocumentLink cdl : alldocLinks) {
if (!docToContentDocumentId.containsKey(cdl.LinkedEntityId)) {
docToContentDocumentId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
}
}
if(!contactId.isEmpty()){
Map<Id,Id> documentIdMap = new Map<Id,Id>();
List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

for(Documents__c doc:[SELECT Id,Name,status__c,Opportunity__r.PrimaryContact__c FROM Documents__c WHERE Opportunity__r.PrimaryContact__c IN: contactId AND (status__c != 'Uploaded' OR Name = 'Emirates ID') AND Name IN: docNameMap.values()]){
String DocName = doc.Name == 'Emirates ID' ? 'Emirates/National ID Front' : doc.Name;
if(targetDocIdMap.containsKey(DocName+doc.Opportunity__r.PrimaryContact__c)){
Id targetDocId = targetDocIdMap.get(DocName+doc.Opportunity__r.PrimaryContact__c);
documentIdMap.put(targetDocId,doc.Id);
ContentDocumentLink newLink = new ContentDocumentLink();
newLink.ContentDocumentId = docToContentDocumentId.get(targetDocId);
newLink.LinkedEntityId    = doc.Id;   // link to Documents__c record
newLink.ShareType         = 'V';         // View
newLink.Visibility        = 'AllUsers';
linksToInsert.add(newLink);
}
}
System.debug('linksToInsert:'+linksToInsert);
if(!linksToInsert.isEmpty()){
database.insert(linksToInsert,false);
}
}
}
}*/ 
}