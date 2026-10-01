@IsTest
private class SignzyFlowRequestWrapperTest {

    @IsTest
    static void cover_buildAndSerialize() {
        // Build full request with nested classes
        SignzyFlowRequestWrapper req = new SignzyFlowRequestWrapper();
        req.flowId = 'FLOW-123';
        req.userId = 'USER-456';

        req.userInfo = new SignzyFlowRequestWrapper.UserInfo();
        req.userInfo.phoneNumber = '+971500000000';
        req.userInfo.dateOfBirth = '1996-12-08';
        req.userInfo.emailAddress = 'user@example.com';
        req.userInfo.externalReferenceId = 'EXT-REF-789';

        req.userInfo.name = new SignzyFlowRequestWrapper.NameCls();
        req.userInfo.name.firstName = 'John';
        req.userInfo.name.lastName  = 'Doe';

        req.userInfo.address = new SignzyFlowRequestWrapper.AddressCls();
        req.userInfo.address.street     = '123 Main St';
        req.userInfo.address.street2    = 'Suite 4B';
        req.userInfo.address.city       = 'Dubai';
        req.userInfo.address.region     = 'DU';
        req.userInfo.address.postalCode = '00000';
        req.userInfo.address.country    = 'AE';

        req.userInfo.id = new SignzyFlowRequestWrapper.IDInfoCls();
        req.userInfo.id.idType  = 'passport';
        req.userInfo.id.country = 'AE';

        req.processingConfig = new SignzyFlowRequestWrapper.ProcessingConfig();
        req.processingConfig.callbackUrl         = 'https://example.com/callback';
        req.processingConfig.authKeyForCallback  = 'secret-key';
        req.processingConfig.redirectTime        = 10;
        req.processingConfig.successRedirectUrl  = 'https://example.com/success';
        req.processingConfig.failureRedirectUrl  = 'https://example.com/failure';
        req.processingConfig.journeyLinkValidity = 60;

        Test.startTest();
        // Serialize (exercise all fields)
        String jsonOut = JSON.serialize(req);
        // And deserialize back to typed object
        SignzyFlowRequestWrapper roundTrip =
            (SignzyFlowRequestWrapper) JSON.deserialize(jsonOut, SignzyFlowRequestWrapper.class);
        Test.stopTest();
    }

    @IsTest
    static void cover_deserializeFromJson() {
        // Full JSON covering all properties and inner classes
        String jsonIn = '{' +
            '"flowId":"FLOW-XYZ",' +
            '"userId":"USER-ABC",' +
            '"userInfo":{' +
                '"phoneNumber":"+971511111111",' +
                '"dateOfBirth":"1990-01-01",' +
                '"emailAddress":"abc@example.com",' +
                '"externalReferenceId":"EXT-0001",' +
                '"name":{"firstName":"Amy","lastName":"Lee"},' +
                '"address":{"street":"Palm Jumeirah","street2":"Tower 1","city":"Dubai","region":"DU","postalCode":"12345","country":"AE"},' +
                '"id":{"idType":"emirates_id","country":"AE"}' +
            '},' +
            '"processingConfig":{' +
                '"callbackUrl":"https://example.com/cb",' +
                '"authKeyForCallback":"k123",' +
                '"redirectTime":5,' +
                '"successRedirectUrl":"https://example.com/ok",' +
                '"failureRedirectUrl":"https://example.com/err",' +
                '"journeyLinkValidity":120' +
            '}' +
        '}';

        Test.startTest();
        // Deserialize into the wrapper (coverage)
        SignzyFlowRequestWrapper req =
            (SignzyFlowRequestWrapper) JSON.deserialize(jsonIn, SignzyFlowRequestWrapper.class);
        // Re-serialize to touch getters/fields again
        String jsonOut = JSON.serialize(req);
        Test.stopTest();
    }
}