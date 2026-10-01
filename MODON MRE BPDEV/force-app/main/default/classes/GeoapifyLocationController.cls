/**********************************************************************************************************************
* Name               : GeoapifyLocationController
* Description        : GeoapifyLocationController to get the address (now powered by Google Geocoding API v4)
* Usage              : GeoapifyLocationController Search the address
* Created By         : Arvind Kesharani
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                           Date            Description
* -------  -------------------------------- --------------- -------------------------------------------------------
* 1.0      Arvind Kesharani              14 July 2026         Initial Draft (Geoapify)
* 2.0      Arvind Kesharani              18 July 2026         Migrated vendor: Geoapify -> Google Geocoding API v4.
*                                                             Same class/method/field names; API key moved to
*                                                             Custom Label (Google_Maps_API_Key).
****************************************************************************************************/

public without sharing class GeoapifyLocationController {

    // API key stored in Custom Label (Setup > Custom Labels > Google_Maps_API_Key)
    private static String apiKey() {
        return System.Label.Google_Maps_API_Key;
    }

    // Only fetch the fields we actually use — controls Google billing tier
    private static final String FIELD_MASK =
        'results.placeId,results.formattedAddress,results.location,' +
        'results.granularity,results.addressComponents';

    // Force English results (otherwise Google returns the region's local
    // language — e.g. Arabic for UAE addresses). Change to 'ar' if needed.
    private static final String LANGUAGE_CODE = 'en';

    public class LocationResult {
        @AuraEnabled public String formatted;
        @AuraEnabled public String addressLine1;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
        @AuraEnabled public String countryCode;
        @AuraEnabled public String postcode;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }

    public class LocationSearchResult {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lon;
        @AuraEnabled public String placeId;
    }

    /**
     * Forward geocoding — free-text address search.
     * Google: GET https://geocode.googleapis.com/v4/geocode/address/{ADDRESS}
     * Returns the same shape as before: label + lat/lon + placeId per result.
     */
    @AuraEnabled
    public static List<LocationSearchResult> searchLocation(String searchText) {
        if (String.isBlank(searchText)) {
            return new List<LocationSearchResult>();
        }

        String endpoint =
            'https://geocode.googleapis.com/v4/geocode/address/'
            + EncodingUtil.urlEncode(searchText, 'UTF-8')
            + '?languageCode=' + LANGUAGE_CODE;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Goog-Api-Key', apiKey());
        req.setHeader('X-Goog-FieldMask', FIELD_MASK);
        req.setTimeout(120000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Location search failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        List<Object> results = (List<Object>) responseMap.get('results');
        List<LocationSearchResult> output = new List<LocationSearchResult>();

        if (results != null) {
            for (Object obj : results) {
                Map<String, Object> row = (Map<String, Object>) obj;

                LocationSearchResult r = new LocationSearchResult();
                r.label = (String) row.get('formattedAddress');
                r.placeId = (String) row.get('placeId');

                Map<String, Object> loc = (Map<String, Object>) row.get('location');
                if (loc != null) {
                    r.lat = (Decimal) loc.get('latitude');
                    r.lon = (Decimal) loc.get('longitude');
                }
                output.add(r);
            }
        }

        return output;
    }

    /**
     * Reverse geocoding — lat/lng to address.
     * Google: GET https://geocode.googleapis.com/v4/geocode/location/{LAT},{LNG}
     */
    @AuraEnabled
    public static LocationResult getAddressFromLatLong(Decimal latitude, Decimal longitude) {
        if (latitude == null || longitude == null) {
            throw new AuraHandledException('latitude and longitude are required');
        }

        String endpoint =
            'https://geocode.googleapis.com/v4/geocode/location/'
            + latitude + ',' + longitude
            + '?languageCode=' + LANGUAGE_CODE;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Goog-Api-Key', apiKey());
        req.setHeader('X-Goog-FieldMask', FIELD_MASK);
        req.setTimeout(120000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Reverse geocode failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        List<Object> results = (List<Object>) responseMap.get('results');

        if (results == null || results.isEmpty()) {
            throw new AuraHandledException('No address found for that location.');
        }

        // First result is the most precise (ROOFTOP before APPROXIMATE)
        Map<String, Object> first = (Map<String, Object>) results[0];

        LocationResult result = new LocationResult();
        result.latitude = latitude;
        result.longitude = longitude;
        // Google's exact formatted address — passed through untouched
        result.formatted = (String) first.get('formattedAddress');

        // Build fields ONLY from Google's addressComponents, in Google's
        // own order. No string manipulation of the formatted address.
        // Street-level component types (everything above city level):
        Set<String> streetTypes = new Set<String>{
            'subpremise', 'premise', 'street_number', 'route', 'street_address',
            'landmark', 'neighborhood', 'sublocality',
            'sublocality_level_1', 'sublocality_level_2',
            'sublocality_level_3', 'sublocality_level_4', 'sublocality_level_5'
        };

        String streetNumber = '';
        String route = '';
        List<String> streetParts = new List<String>();

        List<Object> comps = (List<Object>) first.get('addressComponents');
        if (comps != null) {
            for (Object c : comps) {
                Map<String, Object> comp = (Map<String, Object>) c;
                List<Object> types = (List<Object>) comp.get('types');
                String longText = (String) comp.get('longText');
                String shortText = (String) comp.get('shortText');
                if (types == null || String.isBlank(longText)) continue;

                // is this a street-level component?
                Boolean isStreetLevel = false;
                for (Object t : types) {
                    if (streetTypes.contains((String) t)) { isStreetLevel = true; break; }
                }

                if (isStreetLevel) {
                    // avoid duplicates (Google sometimes repeats values across levels)
                    if (!streetParts.contains(longText)) {
                        streetParts.add(longText);
                    }
                    if (types.contains('street_number')) streetNumber = longText;
                    if (types.contains('route'))         route = longText;
                } else if (types.contains('locality')) {
                    result.city = longText;
                } else if (result.city == null && types.contains('postal_town')) {
                    result.city = longText;
                } else if (types.contains('administrative_area_level_1')) {
                    result.state = longText;
                } else if (types.contains('postal_code')) {
                    result.postcode = longText;
                } else if (types.contains('country')) {
                    result.country = longText;
                    result.countryCode = shortText != null ? shortText.toLowerCase() : null;
                }
            }
        }

        // street: Google's street-level components joined in Google's order
        // e.g. "38, Cybele Greens C Block, 6th Cross Rd, K. C. Krishna Reddy
        //       Layout, Margondanahalli" — never contains city/state/country
        result.street = streetParts.isEmpty() ? null : String.join(streetParts, ', ');

        // addressLine1: short "<number> <route>" form, fallback to street
        String line1 = (streetNumber + ' ' + route).trim();
        if (String.isBlank(line1)) {
            line1 = result.street;
        }
        result.addressLine1 = line1;

        if (result.street == null) {
            result.street = result.addressLine1;
        }

        // Salesforce text fields max out at 255 chars — never exceed that
        result.street       = capLength(result.street, 250);
        result.addressLine1 = capLength(result.addressLine1, 250);

        return result;
    }

    /**
     * Truncates a value to maxLen characters. Cuts at the last comma before
     * the limit when possible, so we drop a whole address segment instead of
     * chopping a word in half.
     */
    private static String capLength(String value, Integer maxLen) {
        if (value == null || value.length() <= maxLen) {
            return value;
        }
        String cut = value.substring(0, maxLen);
        Integer lastComma = cut.lastIndexOf(',');
        if (lastComma > 0) {
            cut = cut.substring(0, lastComma);
        }
        return cut.trim();
    }
}