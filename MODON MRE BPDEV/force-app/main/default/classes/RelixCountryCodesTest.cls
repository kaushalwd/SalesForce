/**
 * RelixCountryCodesTest - country names, alpha-3 codes and picklist matching (Relix plan R4, rule R-g).
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R4 (docs/relix). Pure class: no data, no callouts.
 */
@IsTest
private class RelixCountryCodesTest {

    private static final Set<String> PICKLIST = new Set<String>{
        'India', 'Côte d\'Ivoire', 'Réunion', 'São Tomé and Príncipe', 'United States', 'Dominica', 'Pakistan'
    };

    @IsTest
    static void nameForAlpha3ReadsTheCopiedMap() {
        Assert.areEqual('India', RelixCountryCodes.nameForAlpha3('IND'), 'a plain code');
        Assert.areEqual('India', RelixCountryCodes.nameForAlpha3(' ind '), 'case and spaces are ignored');
        Assert.areEqual('Pakistan', RelixCountryCodes.nameForAlpha3('PAK'), 'another code');
    }

    @IsTest
    static void nameForAlpha3AppliesTheRgFixes() {
        Assert.areEqual('United States', RelixCountryCodes.nameForAlpha3('USA'), 'USA reads as United States');
        Assert.areEqual('Dominica', RelixCountryCodes.nameForAlpha3('DMA'), 'DMA reads as Dominica');
        Assert.areEqual('Côte d\'Ivoire', RelixCountryCodes.nameForAlpha3('CIV'), 'accented as in the picklist');
        Assert.areEqual('Réunion', RelixCountryCodes.nameForAlpha3('REU'), 'accented as in the picklist');
        Assert.areEqual('São Tomé and Príncipe', RelixCountryCodes.nameForAlpha3('STP'), 'accented as in the picklist');
    }

    @IsTest
    static void nameForAlpha3UnknownOrBlankIsNull() {
        Assert.isNull(RelixCountryCodes.nameForAlpha3('ZZZ'), 'unknown code');
        Assert.isNull(RelixCountryCodes.nameForAlpha3(''), 'blank code');
        Assert.isNull(RelixCountryCodes.nameForAlpha3(null), 'null code');
    }

    @IsTest
    static void alpha3ForNameIgnoresCaseAccentsAndPunctuation() {
        Assert.areEqual('CIV', RelixCountryCodes.alpha3ForName('COTE D\'IVOIRE'), 'no accents, upper case');
        Assert.areEqual('REU', RelixCountryCodes.alpha3ForName('reunion'), 'no accent');
        Assert.areEqual('USA', RelixCountryCodes.alpha3ForName('United States of America'), 'second name of USA');
        Assert.isNull(RelixCountryCodes.alpha3ForName('Atlantis'), 'unknown name');
        Assert.isNull(RelixCountryCodes.alpha3ForName(' '), 'blank name');
    }

    @IsTest
    static void matchPicklistReturnsThePicklistValueItself() {
        Assert.areEqual('India', RelixCountryCodes.matchPicklist('INDIA', PICKLIST), 'case-insensitive');
        Assert.areEqual('Côte d\'Ivoire', RelixCountryCodes.matchPicklist('Cote d’Ivoire', PICKLIST),
            'accents and apostrophes are ignored');
        Assert.areEqual('São Tomé and Príncipe', RelixCountryCodes.matchPicklist('SAO TOME AND PRINCIPE', PICKLIST),
            'accents are ignored');
    }

    @IsTest
    static void matchPicklistFallsBackToThePreferredNameOfTheSameCountry() {
        Assert.areEqual('United States', RelixCountryCodes.matchPicklist('United States of America', PICKLIST),
            'same alpha-3 code, the preferred name is active');
        Assert.areEqual('Dominica', RelixCountryCodes.matchPicklist('Commonwealth of Dominica', PICKLIST),
            'same alpha-3 code, the preferred name is active');
    }

    @IsTest
    static void matchPicklistWithoutAMatchIsNull() {
        Assert.isNull(RelixCountryCodes.matchPicklist('Atlantis', PICKLIST), 'unknown country');
        Assert.isNull(RelixCountryCodes.matchPicklist('France', PICKLIST), 'known country, not an active value');
        Assert.isNull(RelixCountryCodes.matchPicklist(null, PICKLIST), 'no name');
        Assert.isNull(RelixCountryCodes.matchPicklist('India', new Set<String>()), 'no active values');
        Assert.isNull(RelixCountryCodes.matchPicklist('India', null), 'no value set');
        Assert.isNull(RelixCountryCodes.matchPicklist('***', PICKLIST), 'nothing left after normalising');
    }

    @IsTest
    static void normaliseFoldsAccentsAndDropsPunctuation() {
        Assert.areEqual('cotedivoire', RelixCountryCodes.normalise('Côte d\'Ivoire'), 'accents folded');
        Assert.areEqual('saotomeandprincipe', RelixCountryCodes.normalise('São Tomé and Príncipe'), 'accents folded');
        Assert.areEqual('strasseoeuvre', RelixCountryCodes.normalise('Straße Œuvre'), 'ligatures expanded');
        Assert.areEqual('congodrc', RelixCountryCodes.normalise(' Congo [DRC] '), 'brackets and spaces dropped');
        Assert.areEqual('abc123', RelixCountryCodes.normalise('ABC-123'), 'digits kept');
        Assert.areEqual('', RelixCountryCodes.normalise(''), 'empty stays empty');
        Assert.isNull(RelixCountryCodes.normalise(null), 'null stays null');
    }
}