/**********************************************************************************************************************
* Name               : UAEPassUserAPI                                                        
* Description        : This class contains main integration methods for UAEPass.
* Usage              : Used to integrate with UAEPass.
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                17 02 2026      Initial Draft       
* 2.0           Arvind                      24 07 2026      Added Person Account fields (mobile, full name AR,
*                                                            nationality, gender) to Account query and UserDTO.
*                                                            Business Account fields removed - not supported
*                                                            in this org. Original query structure and logic
*                                                            otherwise unchanged.

***********************************************************************************************************************/
@RestResource(urlMapping='/UAEPassUserAPI/*')
global class UAEPassUserAPI {
    
    @HttpGet
    global static void findUser() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        UAEResponse responseMsg = new UAEResponse();
        
        String requestId = String.valueOf(UUID.randomUUID());
        
        try {
            String userName = req.params.get('UserName');
            String eidNumber = req.params.get('EidNumber');
            String passportNumber = req.params.get('PassportNumber');
            String uuid = req.params.get('UUID');
            System.debug('>>>>>>>>>>>>>>>>>> userName  '+userName);
            System.debug('>>>>>>>>>>>>>>>>>> eidNumber  '+eidNumber);
            System.debug('>>>>>>>>>>>>>>>>>> passportNumber  '+passportNumber);
            System.debug('>>>>>>>>>>>>>>>>>> UUID  '+uuid);
            if (String.isBlank(userName)) {
                responseMsg.Status = 'Failure';
                responseMsg.ValidUser = false;
            }else{   
                	List<User> resetusers = [
                                                SELECT Id, Email, Phone, Username, FirstName, LastName, Contact.AccountId, UUID__c
                                                FROM User
                                                WHERE Username = :userName
                                                AND IsActive = true
                                                LIMIT 1
                                            ];	
                    // SOQL injection fix: static SOQL with binds (no string concat into literals).
                    // Arvind | v2.0 | 24 Jul 2026 | Added PersonMobilePhone, AccountnameArabic__pc, Nationality__pc, PersonGenderIdentity (Person Account fields only)
                    List<Account> accList;
                    if (!String.isBlank(eidNumber) && !String.isBlank(passportNumber)) {
                        accList = [
                            SELECT Id, Name, PersonEmail, PassportNumber__pc, EIDNumber__pc, PersonMobilePhone,
                                   AccountnameArabic__pc, Nationality__pc, PersonGenderIdentity
                            FROM Account
                            WHERE PersonEmail = :userName
                            AND EIDNumber__pc = :eidNumber
                            AND PassportNumber__pc = :passportNumber
                        ];
                    } else if (!String.isBlank(eidNumber)) {
                        accList = [
                            SELECT Id, Name, PersonEmail, PassportNumber__pc, EIDNumber__pc, PersonMobilePhone,
                                   AccountnameArabic__pc, Nationality__pc, PersonGenderIdentity
                            FROM Account
                            WHERE PersonEmail = :userName
                            AND EIDNumber__pc = :eidNumber
                        ];
                    } else if (!String.isBlank(passportNumber)) {
                        accList = [
                            SELECT Id, Name, PersonEmail, PassportNumber__pc, EIDNumber__pc, PersonMobilePhone,
                                   AccountnameArabic__pc, Nationality__pc, PersonGenderIdentity
                            FROM Account
                            WHERE PersonEmail = :userName
                            AND PassportNumber__pc = :passportNumber
                        ];
                    } else {
                        accList = [
                            SELECT Id, Name, PersonEmail, PassportNumber__pc, EIDNumber__pc, PersonMobilePhone,
                                   AccountnameArabic__pc, Nationality__pc, PersonGenderIdentity
                            FROM Account
                            WHERE PersonEmail = :userName
                        ];
                    }
                    UserDTO userDto;
                    if (accList.size() > 0 && resetusers.size() > 0 && 
                        (String.isBlank(resetusers.get(0).UUID__c) || 
                         (!String.isBlank(resetusers.get(0).UUID__c) && !String.isBlank(uuid) 
                          && resetusers.get(0).UUID__c == uuid ) )) {
                        // Arvind | v2.0 | 24 Jul 2026 | Now passing accList[0] into UserDTO so Person Account fields can be attached; uses new 4-arg overload, old 3-arg constructor untouched
               			 userDto = new UserDTO(resetusers[0],false,false,accList[0]);
                        if(String.isBlank(resetusers.get(0).UUID__c) && !String.isBlank(uuid)){
                            User obj_User = resetusers.get(0);
                            obj_User.UUID__c = uuid;
                            update obj_User;
                        }
                    }
                    
                    if (userDto == null) {
                        returnError(res, requestId, 'User not found', 200);
                        return;
                    }
                
                	String uaepassClientId = System.Label.UAE_Pass_ClientId;
                    String uaepassClientSecret = System.Label.UAE_Pass_Client_Secret;
                    String accessToken = AuthTokenService.generateToken(uaepassClientId, uaepassClientSecret);
                
                
                    ExchangeResponse response = new ExchangeResponse('success', accessToken, userDto, null);
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    res.addHeader('Content-Type', 'application/json');
                    res.statusCode = 200;                  
            }             
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'UAEPassAPI', 'UAEPassAPI', 'findUser'
            ));
            ExchangeResponse response = new ExchangeResponse('success', null, null, 'Could not parse auth code redirect URI');
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            return;
        }
    }
   
     global class ExchangeResponse {
        String access_token;
        String state;
        String errMsg;
        Boolean success;
        Object data;
        
        public ExchangeResponse(String state, String access_token,Object data,string errMsg) {
            this.access_token = access_token;
            this.state = state;
            this.success = true;
            this.data = data;
            this.errMsg =errMsg;
        }      
    }
    
    public class UAEResponse{
        public String Status;
        public Boolean ValidUser;
    }
   private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }
}