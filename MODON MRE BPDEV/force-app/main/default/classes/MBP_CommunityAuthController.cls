public without sharing class MBP_CommunityAuthController {

@AuraEnabled 
public static String startLoginWithOTP(String username, String password) {
    try {
        // 1. Attempt login to validate username and password
        ApexPages.PageReference loginPage = Site.login(username, password, '/');

        if (loginPage == null) {
            return 'ERROR: Wrong username or password.';
        }

        // 2. Check if user is frozen
        if (checkFrozenUser(username)) {
            return 'ERROR: This user is frozen.';
        }

        // 3. Skip OTP if MFA not required
        if (Label.MFA_ENABLED != 'true') {
            return 'SUCCESS:OTP not required, login allowed';
        }

        // 4. Proceed with OTP generation and sending
        return handleOtpFlow(username);

    } catch (Exception e) {
        return 'ERROR: ' + e.getMessage();
    }
}

public static String handleOtpFlow(String username) {
    // Fetch user record
    User u = [SELECT Id, Email, FirstName FROM User WHERE Username = :username LIMIT 1];

    // Generate 6-digit OTP
    Integer otpInt = Math.abs(Crypto.getRandomInteger());
    String otp = String.valueOf(Math.mod(otpInt, 1000000));
    while (otp.length() < 6) {
        otp = '0' + otp;
    }

    u.OTP_Code__c = otp;
    update u;

    // Compose email content
    String firstName = String.isBlank(u.FirstName) ? 'User' : u.FirstName;
    String bodyHtml = 'Hi ' + firstName + ',<br><br>' +
        'Please use the following One-Time Password (OTP) to complete your login process:<br><br>' +
        '<strong>OTP: ' + otp + '</strong><br><br>' +
        'This OTP is valid for a single login attempt and is issued in accordance with Modon secure login policies.<br><br>' +
        'Please do not share this code with anyone.<br><br>' +
        'If you did not request this login, please contact Modon support immediately.<br><br>' +
        'Thank you,<br><br>Regards,<br>Modon Broker Team';

    String fullHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(bodyHtml);

    String personalizationsEntry = '[{"to": [{"email": "' + u.Email + '" } ] }]';
    String gridConfigName = 'Al Naseem';

    BP_SendGridUtilityClass.sendEmail(personalizationsEntry, gridConfigName, 'Your Secure OTP for Modon Login', fullHtml, true);

    return 'SUCCESS:OTP sent to ' + u.Email;
}


    @AuraEnabled
    public static String verifyOTPOnly(String username, String otp) {
        try {
            User u = [SELECT Id, OTP_Code__c FROM User WHERE Username = :username LIMIT 1];

            if (u.OTP_Code__c == null || u.OTP_Code__c != otp) {
                return 'Invalid OTP';
            }

            // Clear OTP after verification
            u.OTP_Code__c = null;
            update u;

            return 'OTP Verified';
        } catch (Exception e) {
            return 'OTP verification failed: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String doLogin(String username, String password, String startUrl) {
        try {
            if (checkFrozenUser(username)) {
                throw new CalloutException('This user is frozen');
            }

            ApexPages.PageReference pageRef = Site.login(username, password, startUrl);
            if (pageRef != null) {
                return pageRef.getUrl();
            }

            throw new CalloutException('Login failed');
        } catch (Exception e) {
            System.debug('Login Exception: ' + e.getMessage());
            if (e.getMessage() == 'This user is frozen') {
                throw new AuraHandledException(e.getMessage());
            } else {
                throw new AuraHandledException('Wrong username or password');
            }
        }
    }

    // Same response every time, so the reply cannot be used to tell which usernames exist.
    @TestVisible private static final String FORGOT_PASSWORD_GENERIC_RESPONSE =
        'SUCCESS:If the username is eligible, password reset instructions will be sent to the registered email.';

    @AuraEnabled
    public static String forgotPassword(String userid) {
        try {
            List<User> users = [SELECT Id, Email, IsActive FROM User WHERE Username = :userid LIMIT 1];

            if (users.isEmpty()) {
                System.debug('forgotPassword: no user for the supplied username.');
                return FORGOT_PASSWORD_GENERIC_RESPONSE;
            }

            if (Site.isValidUsername(userid)) {
                System.resetPassword(users[0].Id, true);
            } else {
                System.debug('forgotPassword: username is not a valid community user.');
            }
            return FORGOT_PASSWORD_GENERIC_RESPONSE;

        } catch (Exception e) {
            System.debug('forgotPassword error: ' + e.getMessage());
            return FORGOT_PASSWORD_GENERIC_RESPONSE;
        }
    }

    public static Boolean checkFrozenUser(String username) {
        UserLogin user = [
            SELECT IsFrozen, UserId 
            FROM UserLogin 
            WHERE UserId IN (
                SELECT Id FROM User WHERE Username = :username
            )
            LIMIT 1
        ];
        return user.IsFrozen;
    }
    
    @AuraEnabled
    public static String loginWithUAEPass(String uaePassUUID, String uaePassEmail) {
        try {
            // 1. Find user by UAE Pass UUID first, fallback to email
            List<User> users = [
                SELECT Id, Username, IsActive, UAE_Pass_UUID__c
                FROM User
                WHERE UAE_Pass_UUID__c = :uaePassUUID
                AND IsActive = true
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                users = [
                    SELECT Id, Username, IsActive, UAE_Pass_UUID__c
                    FROM User
                    WHERE Email = :uaePassEmail
                    AND IsActive = true
                    AND UserType = 'PowerPartner'
                    LIMIT 1
                ];
            }
            
            if (users.isEmpty()) {
                throw new AuraHandledException('NO_USER_FOUND');
            }
            
            User u = users[0];
            
            if (checkFrozenUser(u.Username)) {
                throw new AuraHandledException('FROZEN_USER');
            }
            
            // 2. Build stable deterministic password from userId + UUID
            String stablePassword = buildStablePassword(u.Id, uaePassUUID);
            
            // 3. Only call setPassword if UUID not yet stored (first time) or changed
            if (u.UAE_Pass_UUID__c != uaePassUUID) {
                System.setPassword(u.Id, stablePassword);
                u.UAE_Pass_UUID__c = uaePassUUID;
                update u;
            }
            
            // 4. Actually establish the session
            ApexPages.PageReference pageRef = Site.login(u.Username, stablePassword, '/Brokers/s/');
            
            if (pageRef == null) {
                throw new AuraHandledException('LOGIN_FAILED');
            }
            
            return pageRef.getUrl();
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('loginWithUAEPass error: ' + e.getMessage());
            throw new AuraHandledException('Login error: ' + e.getMessage());
        }
    }
    
    private static String buildStablePassword(String userId, String uuid) {
        String salt    = 'M0d0n@UAE#2025$Secure';
            //Label.MBP_UAEPass_PasswordSalt;
        Blob   hmac    = Crypto.generateMac('HmacSHA256', Blob.valueOf(userId + uuid), Blob.valueOf(salt));
        String encoded = EncodingUtil.base64Encode(hmac);
        return encoded.substring(0, 20) + 'Aa1!';
    }
    
    private static String generateTempPassword() {
        String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$';
        String pwd = '';
        for (Integer i = 0; i < 16; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            pwd += chars.substring(idx, idx + 1);
        }
        return pwd;
    }
    @AuraEnabled
    public static String doLogout() {
        try {
            // Invalidate current Salesforce session
            String sessionId = UserInfo.getSessionId();
            if (sessionId != null) {
                List<AuthSession> sessions = [
                    SELECT Id 
                    FROM AuthSession 
                    WHERE UsersId = :UserInfo.getUserId() 
                    AND IsCurrent = true 
                    LIMIT 1
                ];
                if (!sessions.isEmpty()) {
                    delete sessions;
                }
            }
        } catch (Exception e) {
            System.debug('Session invalidation error: ' + e.getMessage());
        }
        
        return 'https://stg-id.uaepass.ae/idshub/logout?redirect_uri=' 
            + EncodingUtil.urlEncode(
                'https://modonproperties--bpdev.sandbox.my.site.com/Brokers/login', 
                'UTF-8'
            );
    }
}