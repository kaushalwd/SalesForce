/**********************************************************************************************************************
* Name               : CustomerPortalUserService                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : Active minds                                                      
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	                29 May 2025    Initial Draft 
* 2.0 			Manoj						13 Oct 2025    Update Responce
* 3.0           Manoj                       17 Oct 2025    Updated return values and added resetPasswordAndReturnAccessDTO
* 4.0           Manoj                       02 Dec 2025    Updated password reset process with base64 decoding
* 5.0           Suresh                      08 Jan 2026    Profile added in SOQL Query
* 6.0 			Manoj						10 Mar 2026	   Add the Email to SOQL Query
***********************************************************************************************************************/
public class CustomerPortalUserService {
    /**
     * Fetch a User record by email.
     * @param email Email of the user (used as Username)
     * @return UserDTO containing user info or null if not found
     */
    public static UserDTO getUserByEmail(String email) { // 6.0 Add the Email to SOQL Query 
        List<User> users = [SELECT Id, Email,Phone, Username,Contact.AccountId,FirstName,LastName,UUID__c FROM User WHERE (Username = :email OR Email =: email) and isactive =true and Profile.Name = 'Modon Customer Community Plus' LIMIT 1  ];
        if (users.isEmpty()) return null;
        return new UserDTO(users[0],false,false);  // 4.0 Updated to use UserDTO wrapper 
    }
    /**
     * Reset user password and return UserDTO.
     * @param email Email of the user
     * @param Password New password
     * @param Reset Boolean flag for reset
     * @return UserDTO or null if user not found / password reset fails
     */
    public static UserDTO getUserAccessReset(String email,string Password,boolean Reset) { // 6.0 Add the Email to SOQL Query 
        List<User> resetusers = [ SELECT Id, Email, Username,Contact.AccountId,FirstName,LastName,UUID__c FROM User WHERE (Username = :email OR Email =: email) and isactive =true LIMIT 1 ];
        if(!resetusers.isEmpty() && resetusers[0].Id != null){
            try{
                System.setPassword(resetusers[0].id,Password);
            }catch(Exception ex){
                return null;
            }                        
        }else{
            return null;
        }
        return new UserDTO(resetusers[0],false,false);  // 4.0 Updated to use UserDTO wrapper
    }
   /**
     * Updated method for password reset with base64 decoding support.
     * @param email Email of the user
     * @param Password Base64 encoded password string
     * @return UserDTO or null if user not found / password reset fails
     */
    public static UserDTO getUserAccessResetNew(String email,string Password) { // 6.0 Add the Email to SOQL Query 
        List<User> resetusers = [ SELECT Id, Email, Username,Contact.AccountId,FirstName,LastName,Phone,UUID__c FROM User WHERE (Username = :email OR Email =: email) and isactive =true LIMIT 1 ];
        // if(resetusers[0].id != null){
        if (!resetusers.isEmpty()) {
            try{
                if(Password != null){
                    Blob decodedBlob = EncodingUtil.base64Decode(Password);
                    String decodedPassword = decodedBlob.toString();
                    system.debug('passwordConValues--'+decodedPassword);
                    System.setPassword(resetusers[0].id,decodedPassword);
                }else{
                    return null;          
                }
                
            }catch(Exception ex){
                return null;
            }            
        }else{
            return null;
        }
        return new UserDTO(resetusers[0],false,false);  // 4.0 Updated to use UserDTO wrapper
    } 
    /**
     * Reset password and return UserDTO for access.
     * Used in scenarios where a plain password is provided.
     * @param email Email of the user
     * @param password New password
     * @return UserDTO or null if user not found / password reset fails
     */
    public static UserDTO resetPasswordAndReturnAccessDTO(String email, String password) { // 6.0 Add the Email to SOQL Query 
        List<User> resetUsers = [SELECT Id, Email, Username,Contact.AccountId,FirstName,LastName,UUID__c
                                 FROM User WHERE (Username = :email OR Email =: email) AND IsActive = true LIMIT 1];
        
        if (resetUsers.isEmpty()) {
            return null;
        }
        try {
            //Reset the password
            System.setPassword(resetUsers[0].Id, password);
        } catch (Exception ex) {
            return null; // Password reset failed
        }
        
        return new UserDTO(resetUsers[0],false,false);  // 4.0 Updated to use UserDTO wrapper 
    }
}