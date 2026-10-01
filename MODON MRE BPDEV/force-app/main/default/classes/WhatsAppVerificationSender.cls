/**********************************************************************************************************************
* Name               : WhatsAppVerificationSender
* Description        : Placeholder sender for WhatsApp OTP delivery provider integration
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    11 May 2026     Initial WhatsApp sender placeholder
**********************************************************************************************************************/
public class WhatsAppVerificationSender implements VerificationSender {
    public void send(VerificationMessage message) {
        throw new VerificationService.VerificationException('WhatsApp verification sender is not configured.');
    }
}