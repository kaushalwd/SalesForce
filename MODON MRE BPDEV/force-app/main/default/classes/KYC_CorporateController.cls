public without sharing class KYC_CorporateController {
    
    public String fullName { get; set; }
    public String residencyStatus { get; set; }
    public String eidNumber { get; set; }
    public String passportNumber { get; set; }
    public String nationality { get; set; }
    public String dualNationality { get; set; }
    public String pepStatus { get; set; }
    public String email { get; set; }
    public String mobileNo { get; set; }
    public String dateOfBirth { get; set; }
    public String addressLine { get; set; }
    public String countryOfAddress { get; set; }
    public String employmentStatus { get; set; }
    public String employerName { get; set; }
    public String otherInfo { get; set; }
    public String positionField { get; set; }
    public String sourceOfFunds { get; set; }
    public String signatureName { get; set; }
    public String signatureDate { get; set; }
    public String logoDataUri {get;set;}
    public String dateValue {get;set;}
    
    public String companyName {get;set;}
    public String licenseNo {get;set;}
    public String businessAddr {get;set;}
    public String CountryOfAddr {get;set;}
    public String natureOfbusiness {get;set;}
    // Default constructor: attempts to populate from Contact if id param present, else demo text
    public KYC_CorporateController() {
    StaticResource sr = [SELECT Body, ContentType FROM StaticResource WHERE Name = 'modonLogoPlain' LIMIT 1];
        
        if (sr != null && sr.Body != null) {
            String mime = sr.ContentType == null ? 'image/png' : sr.ContentType; // ContentType often null; set explicitly if needed
            // base64 encode the binary body
            String b64 = EncodingUtil.base64Encode(sr.Body);
            logoDataUri = 'data:' + mime + ';base64,' + b64;
        } else {
            logoDataUri = '';
        }     
        Id contactId = ApexPages.currentPage().getParameters().get('id') != null
                 ? (Id)ApexPages.currentPage().getParameters().get('id')
                 : null;
        if (contactId != null) {
            try {
                Contact con = [SELECT Id,Name,Email,MobilePhone,AddressFormula__c,Nationality__c,Birthdate,UAE_Resident_Status__c,
                               EIDNumber__c,PassportNumber__c,Do_you_hold_dual_nationality__c,Formula_PEP__c,AccountId FROM Contact WHERE Id =:contactId];
                Account acc = [SELECT Id,Nature_Of_Business__c,Company_Address__c,Name,TradeLicenseNumber__c,AddressFormula__c,Company_Country_Of_Origin__c,Legal_Type__c FROM Account WHERE Id = :con.AccountId LIMIT 1];

                companyName =  (acc.Name ==null?'':acc.Name);
                licenseNo = (acc.TradeLicenseNumber__c ==null?'':acc.TradeLicenseNumber__c);
                businessAddr = (acc.Company_Address__c == null ? '' : acc.Company_Address__c);
                CountryOfAddr = (acc.Company_Country_Of_Origin__c == null ? '' : acc.Company_Country_Of_Origin__c);
                natureOfbusiness = (acc.Nature_Of_Business__c == null ? '' : acc.Nature_Of_Business__c);
                    
                fullName = (con.Name==null?'':con.Name);
                email = con.Email;
                mobileNo =con.MobilePhone;
                addressLine = (con.AddressFormula__c==null?'':con.AddressFormula__c);
                countryOfAddress = con.Nationality__c;
                if (con.Birthdate != null){ 
                    DateTime dt = DateTime.newInstance(con.Birthdate, Time.newInstance(0, 0, 0, 0));
                    dateOfBirth = dt.format('dd MMM yyyy');
                    System.debug(dateOfBirth); 
                }
                residencyStatus = con.UAE_Resident_Status__c;
                eidNumber = con.EIDNumber__c;
                passportNumber = con.PassportNumber__c;
                nationality = con.Nationality__c;
                dualNationality = con.Do_you_hold_dual_nationality__c;
                pepStatus = con.Formula_PEP__c;
                countryOfAddress = con.Nationality__c;
      
            } catch (Exception ex) {
                System.debug('Exception Ex:'+ex.getlineNumber());
                System.debug('Exception Ex:'+ex.getMessage());
                // fallback to demo data
            }
        } else {
            //populateDemo();
        }
    } 

}