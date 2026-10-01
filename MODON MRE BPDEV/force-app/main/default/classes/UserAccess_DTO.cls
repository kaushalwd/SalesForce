/**
* @description       : Community/Portal UserAccess
* @author            : Manoj
* @last modified on  : 30 May 2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dce 2025   		Update code 
**/
global class UserAccess_DTO {
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
    public string userimageurl;
    
    public UserAccess_DTO(string id,string email,string username,string FirstName,string LastName,string Account,string Street,string State,string City,string Country,string PostalCode,string EIDNumberpc,string PersonMobilePhone,string imageurl) {
        this.id = Id;
        this.email = email;
        this.username = username;
        this.firstName = FirstName;
        this.lastname = LastName;
        this.accountId=Account;
        this.street =Street;
        this.state =State;
        this.city =City;
        this.country =Country;
        this.postalCode =PostalCode;
        this.EIDNumber=EIDNumberpc;   
        this.phone =PersonMobilePhone;   
        this.userimageurl =imageurl; 
    }
    
    
}