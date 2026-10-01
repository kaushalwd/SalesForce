/*
* Version       Author                      Date            Comment                                                                       
* 2.0 			Sameer Sewani				16 March 2026   Updted the lead checkbox field

*/

public class MBP_LoqateValidateLeadJob implements Queueable, Database.AllowsCallouts {

    private List<Id> leadIds;

    public MBP_LoqateValidateLeadJob(List<Id> leadIds) {
        this.leadIds = leadIds;
    }

    public void execute(QueueableContext context) {

        List<Lead> leads = [
            SELECT Id, Email, MobilePhone,
                   Email_Validated__c, Phone_Validated__c 
            //,Lead_Validation_Status__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        List<Lead> updates = new List<Lead>();

        for (Lead l : leads) {


            system.debug('In the lead queue');
            Boolean emailValidated = false;
            Boolean phoneValidated = false;
            String mobileNumber;
            Boolean emailExists = String.isNotBlank(l.Email);
            Boolean phoneExists = String.isNotBlank(l.MobilePhone);
            
            try {

                // EMAIL
                if (emailExists) {
                    try {
                        MBP_LoqateIntegration.validateEmail(l.Email);
                        emailValidated = true;
                        
                        system.debug('emailValidated--->>'+emailValidated);
                    } catch (Exception e) {
                        system.debug('emailValidated--->>'+emailValidated);
                        system.debug('exception-->>'+e.getMessage());
                        emailValidated = false;
                    }
                }
                
                // PHONE
                if (phoneExists) {
                    try {
                        //phoneValidated = MBP_LoqateIntegration.validatePhoneInternational(l.MobilePhone); 
                       
                        //V2.0
                        MBP_LoqateIntegration.PhoneValidationResult phoneResult = MBP_LoqateIntegration.validatePhoneInternational(l.MobilePhone);
                        //V2.0
                        
                        phoneValidated = phoneResult.isValid;
                        mobileNumber=phoneResult.phoneNumber;
                        
                        
                    } catch (Exception e) {
                        phoneValidated = false;
                    }
                }
                
            } catch (Exception e) {

                updates.add(new Lead(
                    Id = l.Id,
                    //Lead_Validation_Status__c = 'Validation Failed (API Error)',
           
                    //V2.0
                    Email_Validated__c  = false,
                    Phone_Validated__c  = false
                    
                    //V2.0
               
                ));
                continue;
            }

            String status;
            system.debug('status-->>'+status);

            if (emailExists && phoneExists) {

                if (emailValidated && phoneValidated) {
                    status = 'Valid - Email & Phone';
                    
                    //V2.0
                    updates.add(new Lead(
                        Id = l.Id,
                        Phone_Validated__c=true,
                        Email_Validated__c=true ,
                        MobilePhone=mobileNumber
                    ));
                    
                    //V2.0
                    
                }
                /*else if (!emailValidated && !phoneValidated) {
                    status = 'Invalid - Email & Phone';
                }
                else if (!emailValidated) {
                    status = 'Invalid - Email';
                }
                else {
                    status = 'Invalid - Phone';
                }*/

            }
            else if (emailExists) {
                status = emailValidated ? 'Valid - Email Only' : 'Invalid - Email';
            }
            else if (phoneExists) {
                status = phoneValidated ? 'Valid - Phone Only' : 'Invalid - Phone';
            }
            else {
                status = 'Pending Validation';
            }
            
            system.debug('status-->>'+status);
/*
            Boolean fullyValidated =
                status == 'Valid - Email & Phone'
                || status == 'Valid - Email Only'
                || status == 'Valid - Phone Only';
*/
            /*updates.add(new Lead(
                Id = l.Id
                
               
                //Lead_Validation_Status__c = status
                //,
               // Email_Validated__c  = fullyValidated
            ));*/
        }
        system.debug('updates-->>'+updates);

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}