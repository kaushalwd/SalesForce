/**
 * Test coverage for the migrated Google Geocoding v4 classes:
 * GeoapifyLocationController + GeoapifyReverseGeocodingService
 */
@isTest
private class GeoapifyLocationControllerTest {

    private class GoogleV4Mock implements HttpCalloutMock {


        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"results":[{' +
                '"placeId":"ChIJRcbZaklDXz4RYlEphFBu5r0",' +
                '"formattedAddress":"Sheikh Mohammed bin Rashid Blvd, Downtown Dubai, Dubai, UAE",' +
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

    private class EmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody('{"results":[]}');
            return res;
        }
    }

    /* ---------- GeoapifyLocationController ---------- */













































































    @isTest
    static void testSearchLocation() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());

        Test.startTest();
        List<GeoapifyLocationController.LocationSearchResult> results =
            GeoapifyLocationController.searchLocation('Burj Khalifa Dubai');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].label.contains('Dubai'));
        System.assertEquals(25.2048, results[0].lat);
        System.assertEquals(55.2708, results[0].lon);
        System.assertEquals('ChIJRcbZaklDXz4RYlEphFBu5r0', results[0].placeId);




    }

    @isTest
    static void testSearchLocationBlank() {



        List<GeoapifyLocationController.LocationSearchResult> results =
            GeoapifyLocationController.searchLocation('');
        System.assertEquals(0, results.size());


    }

    @isTest
    static void testGetAddressFromLatLong() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());
        Test.startTest();
        GeoapifyLocationController.LocationResult r =
            GeoapifyLocationController.getAddressFromLatLong(25.2048, 55.2708);


        Test.stopTest();

        System.assert(r.formatted.contains('Dubai'));
        // street: Google's street-level components only, in Google's order
        System.assertEquals('1, Sheikh Mohammed bin Rashid Boulevard, Downtown Dubai', r.street);
        // addressLine1 stays the short "<number> <route>" form
        System.assertEquals('1 Sheikh Mohammed bin Rashid Boulevard', r.addressLine1);
        System.assertEquals('Dubai', r.city);
        System.assertEquals('Dubai', r.state);
        System.assertEquals('United Arab Emirates', r.country);
        System.assertEquals('ae', r.countryCode);
        System.assertEquals(25.2048, r.latitude);
        System.assertEquals(55.2708, r.longitude);
    }

    @isTest
    static void testGetAddressFromLatLongNoResults() {
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Boolean threw = false;

        Test.startTest();
        try {
            GeoapifyLocationController.getAddressFromLatLong(0, 0);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Expected exception when no results found');

    }



    @isTest
    static void testStreetCappedAt255() {
        Test.setMock(HttpCalloutMock.class, new LongAddressMock());

        Test.startTest();
        GeoapifyLocationController.LocationResult r =
            GeoapifyLocationController.getAddressFromLatLong(13.0163, 77.7066);
        Test.stopTest();
        System.assert(r.street.length() <= 250, 'street must fit a 250-char text field');
        System.assert(r.addressLine1.length() <= 250, 'addressLine1 must fit a 250-char text field');
    }

    private class LongAddressMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Build many street-level components to force a >255-char street
            String compJson = '';
            for (Integer i = 1; i <= 30; i++) {
                compJson += '{"longText":"Very Long Building And Layout Segment Number ' + i + '",' +
                    '"shortText":"Seg' + i + '","types":["sublocality_level_2","sublocality"]},';
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[{"placeId":"ChIJlong","granularity":"ROOFTOP",' +
                '"formattedAddress":"Long Address, Bengaluru, Karnataka 560036, India",' +
                '"location":{"latitude":13.0163,"longitude":77.7066},' +
                '"addressComponents":[' + compJson +
                '{"longText":"Bengaluru","shortText":"Bengaluru","types":["locality"]},' +
                '{"longText":"Karnataka","shortText":"KA","types":["administrative_area_level_1"]},' +
                '{"longText":"560036","shortText":"560036","types":["postal_code"]},' +
                '{"longText":"India","shortText":"IN","types":["country"]}]}]}');
            return res;
        }
    }

    /* ---------- GeoapifyReverseGeocodingService ---------- */

















    @isTest
    static void testServiceReverseGeocode() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());



        Test.startTest();
        GeoapifyReverseGeocodingService.GeoapifyResult r =
            GeoapifyReverseGeocodingService.testReverseGeocode();



        Test.stopTest();

        System.assert(r.formatted.contains('Dubai'));
        System.assertEquals('Dubai', r.city);
        System.assertEquals('ae', r.countryCode);
        System.assertEquals(25.2048, r.latitude);
    }

    @isTest
    static void testServiceSearchLocation() {
        Test.setMock(HttpCalloutMock.class, new GoogleV4Mock());


        Test.startTest();
        List<GeoapifyReverseGeocodingService.LocationSearchResult> results =
            GeoapifyReverseGeocodingService.searchLocation('Burj Khalifa');



        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(25.2048, results[0].lat);
    }
}