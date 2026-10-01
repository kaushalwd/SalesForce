global class UserAccessDTO {
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
    public string EIDNumber;
    public string phone;
      
    public UserAccessDTO(UserAccess__c user) {
        this.id = user.Id;
        this.email = user.Email__c;
        this.username = user.Email__c;
        this.firstName = user.First_Name__c;
        this.lastname = user.Last_Name__c;
        this.accountId=user.Account__c;
        /*this.street =user.Street__c;
        this.state =user.State__c;
        this.city =user.City__c;
        this.country =user.Country__c;
        this.postalCode =user.PostalCode__c;*/
        this.EIDNumber=user.Account__r.EIDNumber__pc;
        this.phone =user.Account__r.PersonMobilePhone;
        
    }

}