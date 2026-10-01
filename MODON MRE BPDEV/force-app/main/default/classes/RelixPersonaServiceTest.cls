/**
 * RelixPersonaServiceTest - the persona rule (SCW-181).
 */
@IsTest
private class RelixPersonaServiceTest {

    @IsTest
    static void companyIsCorporate() {
        System.assertEquals('CORPORATE_ENTITY', RelixPersonaService.forCompany());
        System.assert(RelixPersonaService.isCorporate('CORPORATE_ENTITY'));
        System.assert(!RelixPersonaService.isCorporate('INDIVIDUAL_EXPAT'));
    }

    @IsTest
    static void gccNationalIsP1EvenWhenNotResident() {
        System.assertEquals('INDIVIDUAL_UAE_GCC', RelixPersonaService.forPerson('United Arab Emirates', 'Resident'));
        System.assertEquals('INDIVIDUAL_UAE_GCC', RelixPersonaService.forPerson('Oman', 'Non-Resident'));
        System.assertEquals('INDIVIDUAL_UAE_GCC', RelixPersonaService.forPerson(' Saudi Arabia ', null));
    }

    @IsTest
    static void nonResidentIsP3AndEveryoneElseIsP2() {
        System.assertEquals('INDIVIDUAL_NON_RESIDENT', RelixPersonaService.forPerson('India', 'Non-Resident'));
        System.assertEquals('INDIVIDUAL_NON_RESIDENT', RelixPersonaService.forPerson('India', 'non-resident'));
        System.assertEquals('INDIVIDUAL_EXPAT', RelixPersonaService.forPerson('India', 'Resident'));
        System.assertEquals('INDIVIDUAL_EXPAT', RelixPersonaService.forPerson(null, null));
    }
}