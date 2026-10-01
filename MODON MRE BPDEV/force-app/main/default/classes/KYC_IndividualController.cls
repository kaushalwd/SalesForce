public without sharing class KYC_IndividualController {
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
    // Default constructor: attempts to populate from Contact if id param present, else demo text
    public KYC_IndividualController() {
 	StaticResource sr = [SELECT Body, ContentType FROM StaticResource WHERE Name = 'modonLogoPlain' LIMIT 1];
		
        if (sr != null && sr.Body != null) {
            String mime = sr.ContentType == null ? 'image/png' : sr.ContentType; // ContentType often null; set explicitly if needed
            // base64 encode the binary body
            String b64 = EncodingUtil.base64Encode(sr.Body);
            logoDataUri = 'data:' + mime + ';base64,' + b64;
        } else {
            logoDataUri = '';
        }     
        Id AccountId = ApexPages.currentPage().getParameters().get('id') != null
                 ? (Id)ApexPages.currentPage().getParameters().get('id')
                 : null;
        System.debug('AccountId Ex:'+AccountId);
        if (AccountId != null) {
            try {
                Account acc = [SELECT Id, FirstName, MiddleName,LastName, PersonEmail,AddressFormula__pc,Nationality__pc,PersonMobilePhone,UAE_Resident_Status__pc,EIDNumber__pc,PassportNumber__pc,EmployerBusinessName__pc,
                             PersonBirthdate,Employment_Status__c,Employment_Status__pc,Formula_PEP__pc,Occupation__pc,OtherSourceOfIncome__pc,Do_you_hold_dual_nationality__pc,Formula_PEP__c,SourceOfIncome__pc FROM Account WHERE Id = :AccountId LIMIT 1];
                fullName = ((acc.FirstName == null ? '' : acc.FirstName) + ' ' +
            (acc.MiddleName == null ? '' : acc.MiddleName) + ' ' +
            (acc.LastName == null ? '' : acc.LastName)).replaceAll('\\s+', ' ').trim();
                email = acc.PersonEmail;
                mobileNo =acc.PersonMobilePhone;
                addressLine = (acc.AddressFormula__pc==null?'':acc.AddressFormula__pc);
                countryOfAddress = acc.Nationality__pc;
                if (acc.PersonBirthdate != null){ 
                    DateTime dt = DateTime.newInstance(acc.PersonBirthdate, Time.newInstance(0, 0, 0, 0));
					dateOfBirth = dt.format('dd MMM yyyy');
                    System.debug(dateOfBirth); // e.g. "08 Dec 1996"
                }
                residencyStatus = acc.UAE_Resident_Status__pc;
                eidNumber = acc.EIDNumber__pc;
                passportNumber = acc.PassportNumber__pc;
                nationality = acc.Nationality__pc;
                dualNationality = acc.Do_you_hold_dual_nationality__pc;
                pepStatus = acc.Formula_PEP__pc;
                countryOfAddress = acc.Nationality__pc;
                employmentStatus = acc.Employment_Status__pc <> null && acc.Employment_Status__pc <> '' ? acc.Employment_Status__pc:'N/A';
                employerName = acc.EmployerBusinessName__pc <> null && acc.EmployerBusinessName__pc <> '' ? acc.EmployerBusinessName__pc:'N/A';
                positionField = acc.Occupation__pc <> null && acc.Occupation__pc <> '' ? acc.Occupation__pc:'N/A';
                sourceOfFunds = acc.SourceOfIncome__pc;
                otherInfo = acc.OtherSourceOfIncome__pc;
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