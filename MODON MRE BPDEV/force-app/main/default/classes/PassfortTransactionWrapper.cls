/**********************************************************************************************************************
* Name               : PassfortTransactionWrapper                                                        
* Description        : This class wrapper class for creating entity validation api request JSON for passfort transactions
* Usage              : used in PassfortTransactionProcessHelper class
* Created By         : PWC IN                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                Date            Comment                                                                       
* 1.0       kishor.sitaram.chaudhari@pwc.com         13 May 2024      Initial Draft 
* 1.1       kumaravel                                01 April 2026    added gender / unit name     
******************************************************************************************************************/

public class PassfortTransactionWrapper {

    public List<Applications> applications;
    public String id;
    public String root_id;
    public String invoke_type;
    public String refresh;
    public String role;
    public Collected_data collected_data;
    
    public class Applications {
        public Product product;
    }

    public class Product {
        public String alias;
    }
    
    public class Collected_data {
        public String entity_type;
        public Personal_details personal_details;
        public List<Addresses> address_history;
        public List<Addresses> addresses;
        public Contact_details contact_details;
        public Custom_fields_data custom_fields_data;
        public Metadata metadata;
        public Ownership_structure ownership_structure;
    }
    
    public class Personal_details {
        public Name name;
        public String dob;
        public String nationality;
        public String gender; // 1.1      
    }
    
    public class Name {
        public List<String> given_names;
        public String family_name;
        public String title;
    }
    
    public class Contact_details {
        public String phone_number;
        public String email;
    }
    
    public class Custom_fields_data {
        public String s_applicant_ownership;
        public String s_residence_status; //Resident / Non-Resident
        public String s_occupation;
        public String s_purpose_of_transaction_1;
        public String s_are_you_the_real_beneficiary_of_this_transaction;
        public String s_transaction_specific_risk; // 1. Domestic bank transfer, 2. Own Cheque, Own credit card, 3. Debit card,
                                                    //4. Cash, 5. Virtual Assets / Cryptocurrency, 6. 3rd Party cheque / Credit / Debit card,
                                                    //7. Any other forms of payment which do not state the true payer,
                                                    //8. Payments divided into smaller parts with short intervals in-between (structured payment),
                                                    //9. Cross Border Transfer
        public String s_source_of_income_1; // 1. Business, 2. Salary, 3. Others (please specify)
        public String s_source_of_income_explanation_1;
        public String s_channel_risk; //  1. No Agents Involved, 2. Face to face interaction, 3. Non Face to face meeting, 4. Intermediaries / sources through 3rd party / broker, 5. Direct Sales Partner
        public String n_inventory_count; // needs to be provided data in number format.
        public String s_eid;
        public String s_passport_number;
        public String s_employer_business_name;
        public String s_joint_applicant_name;
        public String s_project_name;
        public String s_unit_name; //1.1
        public String s_pep;
        
        // fields for Company only
        public String s_customer_risk; //1. Sole Private Establishment (UAE based) 
                                        // 2. Freezone Company/ Representative Office (UAE based),
                                        //3. Government/ Semi Government Company (UAE based),
                                        //4. Complex Business Structure (Non UAE based),
                                        //5. Foreign Company (Non UAE based),
                                        //6. Offshore Company (Non UAE based),
                                        //7. Non-Profit Organisation eg. Charity/ Donations Organization (UAE / Non UAE based),
                                        //8. Money Value Transfer Services eg. Currency exchange,
                                        //9. Virtual or Digital Asset Exchange (UAE / Non UAE based)
                                        
        public String s_trade_license;
        public String d_trade_license_expiry_date;
        public String s_description_of_business_activity;   
        public String s_purpose_of_transaction;
        public String s_source_of_income; // 1. Business, 2. Salary, 3. Others (please specify)
        public String s_source_of_income_explanation;
    }
    
    public class Addresses {
        public Address address;
        public String type;
    }   
    public class Address {
        public String type;
        public String country;
        public String state_province;
        public String county;
        public String route;
        public String original_freeform_address;
    }
    
    public class Metadata{
        // fields for Company only
        public String country_of_incorporation;
        public String bvd_id;
        public String name;
        public String incorporation_date;
        public String company_number; //as number is reserved word in apex
        public List<Tax_ids> tax_ids;
        public List<Addresses> addresses;
        public List<Addresses> address_history;
    }
    
    public class Tax_ids{
        public String tax_id_type;
        public String value;
    }    
    
    public class Ownership_structure{
      public List<Beneficial_owners> beneficial_owners;
    }
    
    public class Beneficial_owners{
        public String entity_type;
        public Linked_profile linked_profile;
        public String calculated_percentage;
    }
    
    public class Linked_profile {
        public String id;
    }
}