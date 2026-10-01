/**
 * RelixPersonaService - which Relix journey (persona) a buyer gets.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Relix freezes the persona onto the case when it is
 *                                    created, so it must be right first time. It is read from what
 *                                    MODON already holds on the buyer: an organisation account is a
 *                                    company; a person's Nationality__pc and UAE_Resident_Status__pc
 *                                    decide between the three individual journeys.
 *
 * ASSUMPTIONS (open with MODON, see the review note R5):
 *   - a GCC national takes INDIVIDUAL_UAE_GCC even when not resident;
 *   - any other Non-Resident takes INDIVIDUAL_NON_RESIDENT (enhanced due diligence in Relix);
 *   - everyone else takes INDIVIDUAL_EXPAT.
 * The six GCC values are MODON's exact Nationality picklist labels (read from DEV, 24 Sep 2026).
 *
 * OWNERSHIP. Owner: MODON.
 */
public with sharing class RelixPersonaService {

    public static final String P_GCC = 'INDIVIDUAL_UAE_GCC';
    public static final String P_EXPAT = 'INDIVIDUAL_EXPAT';
    public static final String P_NON_RESIDENT = 'INDIVIDUAL_NON_RESIDENT';
    public static final String P_CORPORATE = 'CORPORATE_ENTITY';

    public static final Set<String> GCC_NATIONALITIES = new Set<String>{
        'United Arab Emirates', 'Saudi Arabia', 'Kuwait', 'Qatar', 'Bahrain', 'Oman'
    };
    public static final String NON_RESIDENT = 'Non-Resident';

    public static String forCompany() { return P_CORPORATE; }

    public static String forPerson(String nationality, String residencyStatus) {
        if (nationality != null && GCC_NATIONALITIES.contains(nationality.trim())) { return P_GCC; }
        if (residencyStatus != null && NON_RESIDENT.equalsIgnoreCase(residencyStatus.trim())) { return P_NON_RESIDENT; }
        return P_EXPAT;
    }

    public static Boolean isCorporate(String persona) { return P_CORPORATE == persona; }
}