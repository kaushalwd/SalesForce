/**
 * RelixCountryCodes - country names and ISO alpha-3 codes for the Relix (Dalil) identity write-back.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R4 (docs/relix, rule R-g). Relix gives a nationality as a
 *                                    country name (activePassport.documentNationality) or as an alpha-3
 *                                    code (personalInfo.currentNationality). MODON's Nationality picklist
 *                                    (global value set Countries) holds names. The name -> code pairs are
 *                                    a copy of the private NationalityVsCodes map in
 *                                    PassfortTransactionProcessHelper (not called, not changed), with the
 *                                    R-g fixes: 'Côte d'Ivoire', 'Réunion' and 'São Tomé and Príncipe' carry
 *                                    their accents as in the picklist, USA reads back as 'United States'
 *                                    and DMA as 'Dominica'.
 *
 * HOW TO USE
 *   String name = RelixCountryCodes.nameForAlpha3('IND');                          // 'India'
 *   String value = RelixCountryCodes.matchPicklist('COTE D\'IVOIRE', activeValues); // 'Côte d'Ivoire'
 *
 * Pure: no SOQL, no DML, no callouts.
 *
 * OWNERSHIP. Owner: MODON.
 */
public inherited sharing class RelixCountryCodes {

    private static final Integer ALPHA3_LENGTH = 3;
    private static final Integer CHAR_LOWER_A = 97;
    private static final Integer CHAR_LOWER_Z = 122;
    private static final Integer CHAR_ZERO = 48;
    private static final Integer CHAR_NINE = 57;

    /** Name -> alpha-3, copied from PassfortTransactionProcessHelper.NationalityVsCodes with the R-g fixes. */
    private static final Map<String, String> NAME_TO_ALPHA3 = new Map<String, String>{
        'Afghanistan' => 'AFG', 'Albania' => 'ALB', 'Algeria' => 'DZA', 'American Samoa' => 'ASM',
        'Andorra' => 'AND', 'Angola' => 'AGO', 'Anguilla' => 'AIA', 'Antarctica' => 'ATA',
        'Antigua and Barbuda' => 'ATG', 'Argentina' => 'ARG', 'Armenia' => 'ARM', 'Aruba' => 'ABW',
        'Australia' => 'AUS', 'Austria' => 'AUT', 'Azerbaijan' => 'AZE', 'Bahamas' => 'BHS', 'Bolivia' => 'BOL',
        'British Virgin Islands' => 'VGB', 'Brunei' => 'BRN', 'Bahrain' => 'BHR', 'Bangladesh' => 'BGD',
        'Barbados' => 'BRB', 'Belarus' => 'BLR', 'Belgium' => 'BEL', 'Belize' => 'BLZ', 'Benin' => 'BEN',
        'Bermuda' => 'BMU', 'Bhutan' => 'BTN', 'Bosnia and Herzegovina' => 'BIH', 'Botswana' => 'BWA',
        'Bouvet Island' => 'BVT', 'Brazil' => 'BRA', 'British Indian Ocean Territory' => 'IOT', 'Bulgaria' => 'BGR',
        'Burkina Faso' => 'BFA', 'Burundi' => 'BDI', 'Cambodia' => 'KHM', 'Cameroon' => 'CMR', 'Canada' => 'CAN',
        'Chad' => 'TCD', 'Chile' => 'CHL', 'China' => 'CHN', 'Christmas Island' => 'CXR', 'Colombia' => 'COL',
        'Costa Rica' => 'CRI', 'Croatia' => 'HRV', 'Cuba' => 'CUB', 'Cyprus' => 'CYP', 'Cape Verde' => 'CPV',
        'Cayman Islands' => 'CYM', 'Central African Republic' => 'CAF', 'Cocos [Keeling] Islands' => 'CCK',
        'Comoros' => 'COM', 'Congo [DRC]' => 'COD', 'Congo [Republic]' => 'COG', 'Cook Islands' => 'COK',
        'Côte d\'Ivoire' => 'CIV', 'Czech Republic' => 'CZE', 'Denmark' => 'DNK', 'Djibouti' => 'DJI',
        'Commonwealth of Dominica' => 'DMA', 'Dominica' => 'DMA', 'Dominican Republic' => 'DOM', 'Ecuador' => 'ECU',
        'Egypt' => 'EGY', 'El Salvador' => 'SLV', 'Equatorial Guinea' => 'GNQ', 'Eritrea' => 'ERI',
        'Estonia' => 'EST', 'Ethiopia' => 'ETH', 'Fiji' => 'FJI', 'Finland' => 'FIN', 'France' => 'FRA',
        'French Guiana' => 'GUF', 'French Polynesia' => 'PYF', 'Falkland Islands [Islas Malvinas]' => 'FLK',
        'Faroe Islands' => 'FRO', 'French Southern Territories' => 'ATF', 'Gabon' => 'GAB', 'Georgia' => 'GEO',
        'Germany' => 'DEU', 'Ghana' => 'GHA', 'Gibraltar' => 'GIB', 'Greece' => 'GRC', 'Greenland' => 'GRL',
        'Grenada' => 'GRD', 'Guadeloupe' => 'GLP', 'Guam' => 'GUM', 'Guatemala' => 'GTM', 'Guernsey' => 'GGY',
        'Guinea' => 'GIN', 'Guinea-Bissau' => 'GNB', 'Guyana' => 'GUY', 'Gambia' => 'GMB', 'Haiti' => 'HTI',
        'Heard Island and McDonald Islands' => 'HMD', 'Honduras' => 'HND', 'Hong Kong' => 'HKG', 'Hungary' => 'HUN',
        'Iceland' => 'ISL', 'India' => 'IND', 'Indonesia' => 'IDN', 'Iraq' => 'IRQ', 'Ireland' => 'IRL',
        'Isle of Man' => 'IMN', 'Israel' => 'ISR', 'Italy' => 'ITA', 'Iran' => 'IRN', 'Jamaica' => 'JAM',
        'Japan' => 'JPN', 'Jersey' => 'JEY', 'Jordan' => 'JOR', 'Kazakhstan' => 'KAZ', 'Kenya' => 'KEN',
        'Kiribati' => 'KIR', 'Kosovo' => 'XKX', 'Kuwait' => 'KWT', 'Kyrgyzstan' => 'KGZ', 'Latvia' => 'LVA',
        'Laos' => 'LAO', 'Lebanon' => 'LBN', 'Lesotho' => 'LSO', 'Liberia' => 'LBR', 'Libya' => 'LBY',
        'Liechtenstein' => 'LIE', 'Lithuania' => 'LTU', 'Luxembourg' => 'LUX', 'Macedonia [FYROM]' => 'MKD',
        'Madagascar' => 'MDG', 'Malawi' => 'MWI', 'Malaysia' => 'MYS', 'Maldives' => 'MDV', 'Mali' => 'MLI',
        'Malta' => 'MLT', 'Martinique' => 'MTQ', 'Mauritania' => 'MRT', 'Mauritius' => 'MUS', 'Mayotte' => 'MYT',
        'Mexico' => 'MEX', 'Monaco' => 'MCO', 'Mongolia' => 'MNG', 'Montenegro' => 'MNE', 'Montserrat' => 'MSR',
        'Morocco' => 'MAR', 'Mozambique' => 'MOZ', 'Macau' => 'MAC', 'Marshall Islands' => 'MHL',
        'Micronesia' => 'FSM', 'Moldova' => 'MDA', 'Myanmar [Burma]' => 'MMR', 'Namibia' => 'NAM', 'Nauru' => 'NRU',
        'Nepal' => 'NPL', 'New Caledonia' => 'NCL', 'New Zealand' => 'NZL', 'Nicaragua' => 'NIC', 'Nigeria' => 'NGA',
        'Niue' => 'NIU', 'Norfolk Island' => 'NFK', 'Norway' => 'NOR', 'Netherlands' => 'NLD', 'Niger' => 'NER',
        'Northern Mariana Islands' => 'MNP', 'North Korea' => 'PRK', 'Oman' => 'OMN', 'Pakistan' => 'PAK',
        'Palau' => 'PLW', 'Panama' => 'PAN', 'Papua New Guinea' => 'PNG', 'Paraguay' => 'PRY', 'Peru' => 'PER',
        'Poland' => 'POL', 'Portugal' => 'PRT', 'Puerto Rico' => 'PRI', 'Palestinian Territories' => 'PSE',
        'Philippines' => 'PHL', 'Pitcairn Islands' => 'PCN', 'Qatar' => 'QAT', 'Russia' => 'RUS', 'Réunion' => 'REU',
        'Romania' => 'ROU', 'Rwanda' => 'RWA', 'Saint Kitts and Nevis' => 'KNA', 'Saint Lucia' => 'LCA',
        'Saint Pierre and Miquelon' => 'SPM', 'Saint Vincent and the Grenadines' => 'VCT', 'Samoa' => 'WSM',
        'San Marino' => 'SMR', 'São Tomé and Príncipe' => 'STP', 'Saudi Arabia' => 'SAU', 'Senegal' => 'SEN',
        'Serbia' => 'SRB', 'Seychelles' => 'SYC', 'Sierra Leone' => 'SLE', 'Singapore' => 'SGP', 'Slovakia' => 'SVK',
        'Slovenia' => 'SVN', 'Solomon Islands' => 'SLB', 'Somalia' => 'SOM', 'South Africa' => 'ZAF',
        'South Georgia and the South Sandwich Islands' => 'SGS', 'South Korea' => 'KOR', 'Spain' => 'ESP',
        'Sri Lanka' => 'LKA', 'Suriname' => 'SUR', 'Svalbard and Jan Mayen' => 'SJM', 'Switzerland' => 'CHE',
        'Saint Helena' => 'SHN', 'Sudan' => 'SDN', 'Swaziland' => 'SWZ', 'Sweden' => 'SWE', 'Syria' => 'SYR',
        'Tajikistan' => 'TJK', 'Thailand' => 'THA', 'Timor-Leste' => 'TLS', 'Togo' => 'TGO', 'Tokelau' => 'TKL',
        'Tonga' => 'TON', 'Trinidad and Tobago' => 'TTO', 'Tunisia' => 'TUN', 'Turkey' => 'TUR',
        'Turkmenistan' => 'TKM', 'Tuvalu' => 'TUV', 'Taiwan' => 'TWN', 'Tanzania' => 'TZA',
        'Turks and Caicos Islands' => 'TCA', 'U.S. Minor Outlying Islands' => 'UMI', 'U.S. Virgin Islands' => 'VIR',
        'United Arab Emirates' => 'ARE', 'United Kingdom' => 'GBR', 'United States' => 'USA',
        'United States of America' => 'USA', 'Uganda' => 'UGA', 'Ukraine' => 'UKR', 'Uruguay' => 'URY',
        'Uzbekistan' => 'UZB', 'Vanuatu' => 'VUT', 'Vatican City' => 'VAT', 'Venezuela' => 'VEN', 'Vietnam' => 'VNM',
        'Wallis and Futuna' => 'WLF', 'Western Sahara' => 'ESH', 'Yemen' => 'YEM', 'Zambia' => 'ZMB',
        'Zimbabwe' => 'ZWE'
    };

    /** Codes held by two names read back as this one (R-g). */
    private static final Map<String, String> PREFERRED_NAMES = new Map<String, String>{
        'USA' => 'United States',
        'DMA' => 'Dominica'
    };

    /** Lower-case accented letters and the plain letters they fold to. */
    private static final Map<String, String> FOLD_GROUPS = new Map<String, String>{
        'a' => 'àáâãäåāăą', 'c' => 'çćĉċč', 'd' => 'ďđ', 'e' => 'èéêëēĕėęě', 'g' => 'ĝğġģ',
        'h' => 'ĥħ', 'i' => 'ìíîïĩīĭįı', 'j' => 'ĵ', 'k' => 'ķ', 'l' => 'ĺļľŀł', 'n' => 'ñńņňŉ',
        'o' => 'òóôõöøōŏő', 'r' => 'ŕŗř', 's' => 'śŝşš', 't' => 'ţťŧ', 'u' => 'ùúûüũūŭůűų',
        'w' => 'ŵ', 'y' => 'ýÿŷ', 'z' => 'źżž', 'ss' => 'ß', 'ae' => 'æ', 'oe' => 'œ'
    };

    private static Map<String, String> alpha3ToName;
    private static Map<String, String> alpha3ByKey;
    private static Map<Integer, List<Integer>> foldMap;
    private static final Map<String, String> NORMALISED = new Map<String, String>();

    /**
     * The country name for an ISO alpha-3 code.
     * @param code alpha-3 code, any case, e.g. 'IND'
     * @return the name, e.g. 'India'; null when the code is blank or unknown
     */
    public static String nameForAlpha3(String code) {
        if (String.isBlank(code)) {
            return null;
        }
        return reverse().get(code.trim().toUpperCase());
    }

    /**
     * The ISO alpha-3 code for a country name, ignoring case, accents, spaces and punctuation.
     * @param countryName e.g. 'Cote d'Ivoire' or 'UNITED STATES OF AMERICA'
     * @return the code, e.g. 'CIV'; null when the name is blank or unknown
     */
    public static String alpha3ForName(String countryName) {
        if (String.isBlank(countryName)) {
            return null;
        }
        return byKey().get(normalise(countryName));
    }

    /**
     * The active picklist value naming the same country, ignoring case and accents. When no value has the
     * same spelling, the value named by the country's preferred name (same alpha-3 code) is returned.
     * @param countryName the name to match, e.g. 'INDIA'
     * @param activeValues the target field's active picklist values
     * @return the picklist value itself, e.g. 'India'; null when nothing matches
     */
    public static String matchPicklist(String countryName, Set<String> activeValues) {
        if (String.isBlank(countryName) || activeValues == null || activeValues.isEmpty()) {
            return null;
        }
        String exact = findByKey(normalise(countryName), activeValues);
        if (exact != null) {
            return exact;
        }
        String preferred = nameForAlpha3(alpha3ForName(countryName));
        return preferred == null ? null : findByKey(normalise(preferred), activeValues);
    }

    /**
     * A comparison key: lower case, accents folded to plain letters, everything but a-z and 0-9 removed.
     * @param s any text
     * @return the key, e.g. 'cotedivoire' for 'Côte d'Ivoire'; null for null
     */
    public static String normalise(String s) {
        if (s == null) {
            return null;
        }
        String cached = NORMALISED.get(s);
        if (cached != null) {
            return cached;
        }
        List<Integer> out = new List<Integer>();
        for (Integer c : s.toLowerCase().getChars()) {
            appendFolded(out, c);
        }
        String result = String.fromCharArray(out);
        NORMALISED.put(s, result);
        return result;
    }

    // ---------------------------------------------------------------- helpers

    private static String findByKey(String key, Set<String> activeValues) {
        if (String.isBlank(key)) {
            return null;
        }
        for (String value : activeValues) {
            if (key == normalise(value)) {
                return value;
            }
        }
        return null;
    }

    private static void appendFolded(List<Integer> out, Integer c) {
        if ((c >= CHAR_LOWER_A && c <= CHAR_LOWER_Z) || (c >= CHAR_ZERO && c <= CHAR_NINE)) {
            out.add(c);
            return;
        }
        List<Integer> folded = folds().get(c);
        if (folded != null) {
            out.addAll(folded);
        }
    }

    private static Map<Integer, List<Integer>> folds() {
        if (foldMap != null) {
            return foldMap;
        }
        foldMap = new Map<Integer, List<Integer>>();
        for (String plain : FOLD_GROUPS.keySet()) {
            for (Integer accented : FOLD_GROUPS.get(plain).getChars()) {
                foldMap.put(accented, plain.getChars());
            }
        }
        return foldMap;
    }

    private static Map<String, String> reverse() {
        if (alpha3ToName != null) {
            return alpha3ToName;
        }
        alpha3ToName = new Map<String, String>();
        for (String name : NAME_TO_ALPHA3.keySet()) {
            String code = NAME_TO_ALPHA3.get(name);
            if (code.length() == ALPHA3_LENGTH && !alpha3ToName.containsKey(code)) {
                alpha3ToName.put(code, name);
            }
        }
        alpha3ToName.putAll(PREFERRED_NAMES);
        return alpha3ToName;
    }

    private static Map<String, String> byKey() {
        if (alpha3ByKey != null) {
            return alpha3ByKey;
        }
        alpha3ByKey = new Map<String, String>();
        for (String name : NAME_TO_ALPHA3.keySet()) {
            alpha3ByKey.put(normalise(name), NAME_TO_ALPHA3.get(name));
        }
        return alpha3ByKey;
    }
}