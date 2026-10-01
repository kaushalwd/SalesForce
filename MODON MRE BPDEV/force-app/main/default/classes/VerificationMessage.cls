/**********************************************************************************************************************
* Name               : VerificationMessage
* Description        : Message DTO used by verification channel senders
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    11 May 2026     Initial verification message DTO
* 1.1           Prateek Bansal                    14 May 2026     Add configurable email sender address
**********************************************************************************************************************/
public class VerificationMessage {
    public Id verificationRequestId;
    public String channel;
    public String target;
    public String maskedTarget;
    public String context;
    public String contextKey;
    public String code;
    public String subject;
    public String body;
    public String templateName;
    public String fromEmail;
}