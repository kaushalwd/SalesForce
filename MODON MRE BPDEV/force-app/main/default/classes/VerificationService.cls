/**********************************************************************************************************************
* Name               : VerificationService
* Description        : Reusable OTP verification framework for Email, WhatsApp, and SMS channels
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    11 May 2026     Initial reusable verification service
* 1.1           Prateek Bansal                    14 May 2026     Pass configured sender email to verification senders
* 1.2           Prateek Bansal                    16 May 2026     Route Verification_Request__c updates through the
*                                                                VerificationRequest_UpdateAsSystem Flow when invoked
*                                                                by Guest users (license restriction on Edit).
**********************************************************************************************************************/
public without sharing class VerificationService {
    private static final String GUEST_UPDATE_FLOW = 'VerificationRequest_UpdateAsSystem';
    private static final Integer OTP_LENGTH = 6;
    private static final Integer EXPIRY_MINUTES = 5;
    private static final Integer MAX_ATTEMPTS = 5;
    private static final Integer RESEND_COOLDOWN_SECONDS = 60;
    private static final Integer MAX_RESENDS = 3;
    private static final String STATUS_PENDING = 'Pending';
    private static final String STATUS_VERIFIED = 'Verified';
    private static final String STATUS_EXPIRED = 'Expired';
    private static final String STATUS_FAILED = 'Failed';
    @TestVisible private static String lastGeneratedCode;

    public class VerificationException extends Exception {}

    private static Boolean isGuestContext() {
        return UserInfo.getUserType() == 'Guest';
    }

    private static void persistUpdate(Verification_Request__c verification) {
        if (verification == null) return;
        if (isGuestContext()) {
            Flow.Interview interview = Flow.Interview.createInterview(
                GUEST_UPDATE_FLOW,
                new Map<String, Object>{ 'record' => verification }
            );
            interview.start();
        } else {
            update verification;
        }
    }

    private static void persistUpdate(List<Verification_Request__c> rows) {
        if (rows == null || rows.isEmpty()) return;
        if (isGuestContext()) {
            for (Verification_Request__c row : rows) {
                persistUpdate(row);
            }
        } else {
            update rows;
        }
    }

    @AuraEnabled
    public static VerificationResult startVerification(VerificationStartRequest request) {
        validateStartRequest(request);
        String channel = normalizeChannel(request.channel);
        String target = request.target.trim();
        String context = String.isBlank(request.context) ? 'GENERAL' : request.context.trim();
        String contextKey = String.isBlank(request.contextKey) ? null : request.contextKey.trim();

        MessagingConfigService.VerificationConfig config = getVerificationConfig(context, channel);
        expirePendingRequests(channel, target, context, contextKey);

        String code = generateOtp(getOtpLength(config));
        Datetime nowValue = System.now();
        Verification_Request__c verification = new Verification_Request__c(
            Channel__c = channel,
            Target__c = target,
            Masked_Target__c = maskTarget(channel, target),
            Code_Hash__c = hashCode(code),
            Status__c = STATUS_PENDING,
            Context__c = context,
            Context_Key__c = contextKey,
            Expires_At__c = nowValue.addMinutes(getExpiryMinutes(config)),
            Last_Sent_At__c = nowValue,
            Resend_Available_At__c = nowValue.addSeconds(getResendCooldownSeconds(config)),
            Attempts__c = 0,
            Max_Attempts__c = getMaxAttempts(config),
            Resend_Count__c = 0,
            Max_Resends__c = getMaxResends(config)
        );
        insert verification;

        try {
            sendCode(verification, code, config);
        } catch (Exception ex) {
            verification.Status__c = STATUS_FAILED;
            verification.Error_Message__c = ex.getMessage();
            persistUpdate(verification);
            throw new AuraHandledException(ex.getMessage());
        }

        return toResult(verification, 'Verification code sent.');
    }

    @AuraEnabled
    public static VerificationResult resendVerification(Id verificationRequestId) {
        Verification_Request__c verification = getVerification(verificationRequestId);
        ensurePending(verification);

        Datetime nowValue = System.now();
        if (verification.Resend_Available_At__c != null && nowValue < verification.Resend_Available_At__c) {
            throw new AuraHandledException('Please wait before requesting another verification code.');
        }
        Integer resendCount = toInteger(verification.Resend_Count__c);
        Integer maxResends = toInteger(verification.Max_Resends__c);
        if (maxResends > 0 && resendCount >= maxResends) {
            verification.Status__c = STATUS_FAILED;
            verification.Error_Message__c = 'Maximum resend count reached.';
            persistUpdate(verification);
            throw new AuraHandledException('Maximum resend count reached.');
        }

        MessagingConfigService.VerificationConfig config = getVerificationConfig(verification.Context__c, verification.Channel__c);
        String code = generateOtp(getOtpLength(config));
        verification.Code_Hash__c = hashCode(code);
        verification.Expires_At__c = nowValue.addMinutes(getExpiryMinutes(config));
        verification.Last_Sent_At__c = nowValue;
        verification.Resend_Available_At__c = nowValue.addSeconds(getResendCooldownSeconds(config));
        verification.Attempts__c = 0;
        verification.Resend_Count__c = resendCount + 1;
        verification.Error_Message__c = null;
        persistUpdate(verification);

        try {
            sendCode(verification, code, config);
        } catch (Exception ex) {
            verification.Status__c = STATUS_FAILED;
            verification.Error_Message__c = ex.getMessage();
            persistUpdate(verification);
            throw new AuraHandledException(ex.getMessage());
        }

        return toResult(verification, 'Verification code resent.');
    }

    @AuraEnabled
    public static VerificationResult verifyCode(Id verificationRequestId, String code) {
        Verification_Request__c verification = getVerification(verificationRequestId);
        ensurePending(verification);
        if (String.isBlank(code)) {
            throw new AuraHandledException('Verification code is required.');
        }

        Integer attempts = toInteger(verification.Attempts__c) + 1;
        verification.Attempts__c = attempts;
        if (verification.Code_Hash__c == hashCode(code.trim())) {
            verification.Status__c = STATUS_VERIFIED;
            verification.Verified_At__c = System.now();
            verification.Error_Message__c = null;
            persistUpdate(verification);
            return toResult(verification, 'Verification completed.');
        }

        Integer maxAttempts = toInteger(verification.Max_Attempts__c);
        if (maxAttempts > 0 && attempts >= maxAttempts) {
            verification.Status__c = STATUS_FAILED;
            verification.Error_Message__c = 'Maximum verification attempts reached.';
            persistUpdate(verification);
            return toResult(verification, 'Maximum verification attempts reached.');
        }

        verification.Error_Message__c = 'Invalid verification code.';
        persistUpdate(verification);
        return toResult(verification, 'Invalid verification code.');
    }

    private static void validateStartRequest(VerificationStartRequest request) {
        if (request == null) throw new AuraHandledException('Verification request is required.');
        if (String.isBlank(request.channel)) throw new AuraHandledException('Verification channel is required.');
        if (String.isBlank(request.target)) throw new AuraHandledException('Verification target is required.');
        normalizeChannel(request.channel);
    }

    private static String normalizeChannel(String channel) {
        String normalized = channel == null ? '' : channel.trim().toLowerCase();
        if (normalized == 'email') return 'Email';
        if (normalized == 'whatsapp') return 'WhatsApp';
        if (normalized == 'sms') return 'SMS';
        throw new AuraHandledException('Unsupported verification channel.');
    }

    private static Verification_Request__c getVerification(Id verificationRequestId) {
        if (verificationRequestId == null) throw new AuraHandledException('Verification request id is required.');
        List<Verification_Request__c> rows = [
            SELECT Id, Channel__c, Target__c, Masked_Target__c, Code_Hash__c, Status__c, Context__c, Context_Key__c,
                Expires_At__c, Last_Sent_At__c, Resend_Available_At__c, Attempts__c, Max_Attempts__c,
                Resend_Count__c, Max_Resends__c, Verified_At__c, Error_Message__c
            FROM Verification_Request__c
            WHERE Id = :verificationRequestId
            LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Verification request was not found.');
        return rows[0];
    }

    private static void ensurePending(Verification_Request__c verification) {
        if (verification.Status__c != STATUS_PENDING) {
            throw new AuraHandledException('Verification request is not pending.');
        }
        if (verification.Expires_At__c != null && System.now() > verification.Expires_At__c) {
            verification.Status__c = STATUS_EXPIRED;
            verification.Error_Message__c = 'Verification request expired.';
            persistUpdate(verification);
            throw new AuraHandledException('Verification request expired.');
        }
    }

    private static void expirePendingRequests(String channel, String target, String context, String contextKey) {
        List<Verification_Request__c> existing = [
            SELECT Id, Status__c, Error_Message__c
            FROM Verification_Request__c
            WHERE Channel__c = :channel
            AND Target__c = :target
            AND Context__c = :context
            AND Context_Key__c = :contextKey
            AND Status__c = :STATUS_PENDING
        ];
        for (Verification_Request__c row : existing) {
            row.Status__c = STATUS_EXPIRED;
            row.Error_Message__c = 'Superseded by a new verification request.';
        }
        persistUpdate(existing);
    }

    private static void sendCode(Verification_Request__c verification, String code, MessagingConfigService.VerificationConfig config) {
        Integer expiryMinutes = getExpiryMinutes(config);
        VerificationMessage message = new VerificationMessage();
        message.verificationRequestId = verification.Id;
        message.channel = verification.Channel__c;
        message.target = verification.Target__c;
        message.maskedTarget = verification.Masked_Target__c;
        message.context = verification.Context__c;
        message.contextKey = verification.Context_Key__c;
        message.code = code;
        message.subject = 'Your verification code';
        message.body = 'Your verification code is ' + code + '. This code will expire in ' + expiryMinutes + ' minutes.';
        message.templateName = config == null ? null : config.templateName;
        message.fromEmail = config == null ? null : config.fromEmail;
        getSender(verification.Channel__c, config).send(message);
    }

    private static VerificationSender getSender(String channel, MessagingConfigService.VerificationConfig config) {
        if (config != null && String.isNotBlank(config.senderClass)) {
            Type senderType = Type.forName(config.senderClass);
            if (senderType != null) {
                Object instance = senderType.newInstance();
                if (instance instanceof VerificationSender) return (VerificationSender) instance;
            }
        }
        if (channel == 'Email') return new EmailVerificationSender();
        if (channel == 'WhatsApp') return new WhatsAppVerificationSender();
        if (channel == 'SMS') return new SmsVerificationSender();
        throw new VerificationException('Unsupported verification channel.');
    }

    private static String generateOtp() {
        return generateOtp(OTP_LENGTH);
    }

    private static String generateOtp(Integer otpLength) {
        Integer length = otpLength == null || otpLength <= 0 ? OTP_LENGTH : otpLength;
        String code = '';
        while (code.length() < length) {
            Integer digit = Math.mod(Math.abs(Crypto.getRandomInteger()), 10);
            code += String.valueOf(digit);
        }
        lastGeneratedCode = code;
        return code;
    }

    private static MessagingConfigService.VerificationConfig getVerificationConfig(String context, String channel) {
        MessagingConfigService.VerificationConfig config = MessagingConfigService.getVerificationConfig(context, channel);
        if (config != null && config.isActive == false) {
            throw new AuraHandledException('Verification channel is not active.');
        }
        return config;
    }

    private static Integer getOtpLength(MessagingConfigService.VerificationConfig config) {
        return config == null || config.otpLength == null ? OTP_LENGTH : config.otpLength;
    }

    private static Integer getExpiryMinutes(MessagingConfigService.VerificationConfig config) {
        return config == null || config.expiryMinutes == null ? EXPIRY_MINUTES : config.expiryMinutes;
    }

    private static Integer getMaxAttempts(MessagingConfigService.VerificationConfig config) {
        return config == null || config.maxAttempts == null ? MAX_ATTEMPTS : config.maxAttempts;
    }

    private static Integer getResendCooldownSeconds(MessagingConfigService.VerificationConfig config) {
        return config == null || config.resendCooldownSeconds == null ? RESEND_COOLDOWN_SECONDS : config.resendCooldownSeconds;
    }

    private static Integer getMaxResends(MessagingConfigService.VerificationConfig config) {
        return config == null || config.maxResends == null ? MAX_RESENDS : config.maxResends;
    }

    private static String hashCode(String code) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(code + '|' + UserInfo.getOrganizationId()));
        return EncodingUtil.convertToHex(digest);
    }

    private static String maskTarget(String channel, String target) {
        if (channel == 'Email') return maskEmail(target);
        return maskPhone(target);
    }

    private static String maskEmail(String email) {
        List<String> parts = (email == null ? '' : email).split('@');
        if (parts.size() != 2 || parts[0].length() == 0) return '***';
        Integer visibleCharacters = Math.min(2, parts[0].length());
        return parts[0].substring(0, visibleCharacters) + '***@' + parts[1];
    }

    private static String maskPhone(String phone) {
        String digits = phone == null ? '' : phone.replaceAll('[^0-9]', '');
        return digits.length() > 4 ? '****' + digits.substring(digits.length() - 4, digits.length()) : '****';
    }

    private static Integer toInteger(Decimal value) {
        return value == null ? 0 : value.intValue();
    }

    private static VerificationResult toResult(Verification_Request__c verification, String message) {
        VerificationResult result = new VerificationResult();
        result.verificationRequestId = verification.Id;
        result.channel = verification.Channel__c;
        result.maskedTarget = verification.Masked_Target__c;
        result.status = verification.Status__c;
        result.expiresAt = verification.Expires_At__c;
        result.resendAvailableAt = verification.Resend_Available_At__c;
        result.message = message;
        result.verified = verification.Status__c == STATUS_VERIFIED;
        return result;
    }

    public class VerificationStartRequest {
        @AuraEnabled public String channel { get; set; }
        @AuraEnabled public String target { get; set; }
        @AuraEnabled public String context { get; set; }
        @AuraEnabled public String contextKey { get; set; }
    }

    public class VerificationResult {
        @AuraEnabled public Id verificationRequestId { get; set; }
        @AuraEnabled public String channel { get; set; }
        @AuraEnabled public String maskedTarget { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Datetime expiresAt { get; set; }
        @AuraEnabled public Datetime resendAvailableAt { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Boolean verified { get; set; }
    }
}