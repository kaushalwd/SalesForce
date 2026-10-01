/**********************************************************************************************************************
* Name               : VerificationSender
* Description        : Interface for OTP delivery channels
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    11 May 2026     Initial sender interface
**********************************************************************************************************************/
public interface VerificationSender {
    void send(VerificationMessage message);
}