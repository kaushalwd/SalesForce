/**********************************************************************************************************************
* Name               : NumberToText
* Description        : Utility class to convert numbers (integers, longs, and string digits) into English text words.
*                      Supports values up to Trillions/Quadrillions.
* Usage              : Called by Utilities class and other numeric word conversion helpers.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           ActiveMinds      02 Jun 2026     Initial Draft
* 1.1           Narendra Agrawal 29 Jun 2026     Updated convert method to accept and handle very large amounts via String conversion to avoid Integer overflow
******************************************************************************************************************/
public class NumberToText {
    static final Integer DIGITS_PER_SET = 3;
    static final String ZERO = 'Zero';
    private static Map<Integer,String> tens = new Map<Integer,String> {
        20 => 'Twenty',
        30 => 'Thirty',
        40 => 'Forty',
        50 => 'Fifty',
        60 => 'Sixty',
        70 => 'Seventy',
        80 => 'Eighty',
        90 => 'Ninety'
    };
    private static Map<Integer,String> smallNumbers = new Map<Integer,String> {
        0 => 'Zero',
        1 => 'One',
        2 => 'Two',
        3 => 'Three',
        4 => 'Four',
        5 => 'Five',
        6 => 'Six',
        7 => 'Seven',
        8 => 'Eight',
        9 => 'Nine',
        10 => 'Ten',
        11 => 'Eleven',
        12 => 'Twelve',
        13 => 'Thirteen',
        14 => 'Fourteen',
        15 => 'Fifteen',
        16 => 'Sixteen',
        17 => 'Seventeen',
        18 => 'Eighteen',
        19 => 'Nineteen'
    };
    private static Map<Integer,String> modifiers = new Map<Integer,String> {
        1 => 'Thousand ',
        2 => 'Million ',
        3 => 'Billion ',
        4 => 'Trillion ', //v1.1
        5 => 'Quadrillion ' //v1.1
    };  

    //v1.1 START
    public static String convert(Integer value) {
        return convert(String.valueOf(value));
    }

    public static String convert(Long value) {
        return convert(String.valueOf(value));
    }
    
    /**
     * Converts a whole-number digit string to words without Integer overflow.
     * Use for currency whole parts that may exceed Integer.MAX_VALUE (2,147,483,647).
     */
    public static String convert(String digits) {
        if (String.isBlank(digits)) {
            return ZERO;
        }
      
        String numberString = digits.trim();
        // text representation of the number to convert. e.g. 'one hundred'
        String numberText = '';
		
        // If value is negative prepend the text with 'negative'
        // and then process as a positive value
        if (numberString.startsWith('-')) {


            numberText = 'negative ';
            numberString = numberString.substring(1);
        }
		// string representation of the number to convert. e.g. '100'
        numberString = numberString.replaceAll('^0+(?!$)', '');
        if (String.isBlank(numberString) || numberString == '0') {
            return numberText == '' ? ZERO : (numberText + ZERO).trim();
        }

		 // split the number into sets (hundreds, thousands, millions, billions)
        // and convert each as a three digit number.
        while (numberString.length() > 0) {
        	// Figure out how many digits are in this set
            Integer digitsInSet = Math.mod(numberString.length(), DIGITS_PER_SET) == 0
                ? DIGITS_PER_SET
                : Math.mod(numberString.length(), DIGITS_PER_SET);
			// Create a string to represent this set.
            String thisSet = numberString.substring(0, digitsInSet);
            // Convert the set into an integer and generate the text for this set.
            Integer valueToConvert = Integer.valueOf(thisSet);
            // Remove the first set from numberString now that it has been converted.
            numberString = numberString.substring(digitsInSet, numberString.length());

            if (valueToConvert > 0) {



                String setText = generateText(valueToConvert);


				// Calculate the modifierIndex to determine what set this is
                // e.g. thousands, millions, billions.
                Integer modifierKey = numberString.length() / DIGITS_PER_SET;
                
                // Create the modifier string
                String modifier = modifierKey > 0 && modifiers.containsKey(modifierKey)
                    ? ' ' + modifiers.get(modifierKey)
                    : '';

				// Build the text
                numberText += setText + modifier;
            }
        }
        return numberText.trim();
    }
    //v1.1 END

    private static String generateText(Integer value) {
        if (value < 100)
            return generateTextForTwoDigits(value);

        String numberText = '';

        // Calculate the number of hundreds
        Integer hundreds = value / 100;
        if (hundreds > 0)
            numberText = generateTextForTwoDigits(hundreds) + ' Hundred';

        // Calculate the leftover value
        Integer leftOver = Math.mod(value, 100);
        if (leftOver > 0)
            numberText += ' ' + generateTextForTwoDigits(leftOver);
        return numberText;
    }

    private static String generateTextForTwoDigits(Integer value) {
        if (value < 20) {
            return smallNumbers.get(value);
        }

        // Round the value down to the nearest 10 and get the text representation
        Integer tensKey = (value/10) * 10;
        String numberText = tens.get(tensKey);

        // Calculate the leftover value
        Integer leftOver = value - tensKey;

        if (leftOver > 0) {
            // Add a hypen for values between 21 - 99.
            // https://www.grammarly.com/blog/hyphen-in-compound-numbers/
            if (tensKey >= 20 && tensKey <= 90 && leftOver > 0) {
                numberText += '-';
            }
            numberText += generateTextForTwoDigits(leftOver);
        }
        return numberText;
    }
}