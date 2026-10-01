public class DocuSignTempCheck {
    public static void testBulk() {
        List<dfsle.Envelope> envelopes = new List<dfsle.Envelope>();
        envelopes = dfsle.EnvelopeService.sendEnvelopes(envelopes);
    }
}