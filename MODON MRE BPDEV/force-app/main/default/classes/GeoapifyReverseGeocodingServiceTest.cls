/**
 * Test coverage for GeoapifyReverseGeocodingService (Google Geocoding API v4, mocked callouts).
 */
@isTest
private class GeoapifyReverseGeocodingServiceTest {

    /* ---------- Mocks ---------- */

    private class GoogleV4Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"results":[{' +
                '"placeId":"ChIJRcbZaklDXz4RYlEphFBu5r0",' +
                '"formattedAddress":"1 Sheikh Mohammed bin Rashid Blvd, Downtown Dubai, Dubai, UAE",' +
                '"location":{"latitude":25.2048,"longitude":55.2708},' +
                '"granularity":"ROOFTOP",' +
                '"addressComponents":[' +
                '{"longText":"1","shortText":"1","types":["street_number"]},' +
                '{"longText":"Sheikh Mohammed bin Rashid Boulevard","shortText":"Sheikh Mohammed bin Rashid Blvd","types":["route"]},' +
                '{"longText":"Downtown Dubai","shortText":"Downtown Dubai","types":["sublocality_level_1","sublocality","political"]},' +
                '{"longText":"Dubai","shortText":"Dubai","types":["locality","political"]},' +
                '{"longText":"Dubai","shortText":"Dubai","types":["administrative_area_level_1","political"]},' +
                '{"longText":"United Arab Emirates","shortText":"AE","types":["country","political"]}' +
                ']}]}');
            return res;
        }
    }

    private class EmptyResultsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[]}');

            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setBody('{"error":{"message":"API key not valid"}}');

            return res;
        }
    }

    /* ---------- reverseGeocode ---------- */

    @isTest
    static void testReverseGeocodeSuccess() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());
        Test.startTest();
        GeoapifyReverseGeocodingService.GeoapifyResult r =
            GeoapifyReverseGeocodingService.reverseGeocode(25.2048, 55.2708);
        Test.stopTest();






        System.assert(r.formatted.contains('Dubai'));
        // addressLine1: Google's street-level components in Google's order
        System.assertEquals('1, Sheikh Mohammed bin Rashid Boulevard, Downtown Dubai', r.addressLine1);
        System.assertEquals('Dubai', r.city);
        System.assertEquals('Dubai', r.state);
        System.assertEquals('United Arab Emirates', r.country);
        System.assertEquals('ae', r.countryCode);
        System.assertEquals(null, r.postcode); // UAE addresses have no postal code
        System.assertEquals(25.2048, r.latitude);
        System.assertEquals(55.2708, r.longitude);
    }



    @isTest
    static void testTestReverseGeocodeHelper() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());

        Test.startTest();
        GeoapifyReverseGeocodingService.GeoapifyResult r =
            GeoapifyReverseGeocodingService.testReverseGeocode();
        Test.stopTest();

        // Hardcoded Dubai coordinates inside the helper
        System.assertEquals(25.2048, r.latitude);
        System.assertEquals(55.2708, r.longitude);
        System.assertEquals('Dubai', r.city);





    }

    @isTest
    static void testReverseGeocodeNoResults() {
        Test.setMock(HttpCalloutMock.class, new EmptyResultsMock());
        Boolean threw = false;

        Test.startTest();
        try {
            GeoapifyReverseGeocodingService.reverseGeocode(0, 0);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected exception when no address found');

    }

    @isTest
    static void testReverseGeocodeApiError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Boolean threw = false;

        Test.startTest();
        try {
            GeoapifyReverseGeocodingService.reverseGeocode(25.2048, 55.2708);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected exception on non-200 status');

    }

    /* ---------- searchLocation ---------- */

    @isTest
    static void testSearchLocationSuccess() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());

        Test.startTest();
        List<GeoapifyReverseGeocodingService.LocationSearchResult> results =
            GeoapifyReverseGeocodingService.searchLocation('Burj Khalifa Dubai');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].label.contains('Dubai'));
        System.assertEquals(25.2048, results[0].lat);
        System.assertEquals(55.2708, results[0].lon);
        System.assertEquals('ChIJRcbZaklDXz4RYlEphFBu5r0', results[0].placeId);
    }



    @isTest
    static void testSearchLocationBlank() {
        // No mock needed — blank input returns early without a callout


        List<GeoapifyReverseGeocodingService.LocationSearchResult> results =
            GeoapifyReverseGeocodingService.searchLocation('');
        System.assertEquals(0, results.size());










    }

    @isTest
    static void testSearchLocationApiError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Boolean threw = false;
        Test.startTest();
        try {
            GeoapifyReverseGeocodingService.searchLocation('Burj Khalifa');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected exception on non-200 status');

    }
}