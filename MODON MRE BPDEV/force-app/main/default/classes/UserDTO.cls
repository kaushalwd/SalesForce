/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 24-07-2026
* @last modified by  : Arvind
* * --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Krishna Chaitanya   13 May 2025   		Initial Draft 
* 2.0           Manoj   	        09 Dec 2025   		Add and Remove logic 
* 3.0           Arvind              24 Jul 2026         Added mobile, full name (Arabic), nationality, gender
*                                                        from Account - Person Account fields only, Business
*                                                        Account not supported in this org
**/

global class UserDTO {
    public String id;
    public String email;
    public String username;
    public string accountId;
    public string firstName;
    public string lastName;
    public String street;
    public String city;
    public String state;
    public String country;
    public String postalCode;
    public String phone; //2.0 add and remove logic
    public Boolean eidNumber;  //2.0 add and remove logic
    public Boolean passportNumber; //2.0 add and remove logic
    public String uuid; //2.0 add and remove logic

    // Arvind | v3.0 | 24 Jul 2026 | Added mobileNumber - sourced from Account.PersonMobilePhone (Person Account only)
    public String mobileNumber;
    // Arvind | v3.0 | 24 Jul 2026 | Added fullNameEn - sourced from Account.Name
    public String fullNameEn;
    // Arvind | v3.0 | 24 Jul 2026 | Added fullNameAr - sourced from Account.AccountnameArabic__pc (Person Account only)
    public String fullNameAr;
    // Arvind | v3.0 | 24 Jul 2026 | Added nationality - sourced from Account.Nationality__pc (Person Account only)
    public String nationality;
    // Arvind | v3.0 | 24 Jul 2026 | Added gender - sourced from Account.PersonGenderIdentity (Person Account only)
    public String gender;

    //2.0 add and remove logic
    public UserDTO(User user, Boolean eidNumber, Boolean passportNumber) {
        this.id = user.Id;
        this.email = user.Email;
        this.username = user.Username;
        this.firstName = user.firstname;
        this.lastName = user.lastname;
        this.accountId=user.Contact.AccountId;
        this.phone =user.Phone; //2.0 add and remove logic
        if(String.isBlank(user.UUID__c)){
            this.uuid = ''; 
        } else {
            this.uuid = user.UUID__c; 
        }  //2.0 add and remove logic      
        this.eidNumber =eidNumber;
        this.passportNumber =passportNumber;
    }

    // Arvind | v3.0 | 24 Jul 2026 | New overload (original 3-arg constructor above is untouched, so any existing callers keep working)
    // Arvind | v3.0 | 24 Jul 2026 | Accepts the matched Account so Person Account fields can be read directly - no Business Account branching, since it's not supported here
    public UserDTO(User user, Boolean eidNumber, Boolean passportNumber, Account acc) {
        // Arvind | v3.0 | 24 Jul 2026 | Reuses the original constructor for all pre-existing fields
        this(user, eidNumber, passportNumber);

        if (acc != null) {
            // Arvind | v3.0 | 24 Jul 2026 | Person Account fields read directly - no IsPersonAccount branching needed since Business Account isn't supported
            this.mobileNumber = acc.PersonMobilePhone;
            this.fullNameEn   = acc.Name;
            this.fullNameAr   = acc.AccountnameArabic__pc;
            this.nationality  = acc.Nationality__pc;
            this.gender       = acc.PersonGenderIdentity;
        }
    }
}