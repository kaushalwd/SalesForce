public class PasswordGenerator {

    public static String generatePassword() {
        // Character sets
        String upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        String lowerChars = 'abcdefghijklmnopqrstuvwxyz';
        String numberChars = '0123456789';
        String specialChars = '!@#$%^&*';

        // Ensure inclusion of required character types
        String password = '';
        password += getRandomChar(upperChars);
        password += getRandomChar(numberChars);
        password += getRandomChar(specialChars);

        // Remaining characters (5 more) from all categories
        String allChars = upperChars + lowerChars + numberChars + specialChars;
        for (Integer i = 0; i < 5; i++) {
            password += getRandomChar(allChars);
        }

        // Shuffle the final password to avoid predictable pattern
        password = shuffleString(password);

        return password;
    }

    private static String getRandomChar(String chars) {
        Integer randomInteger = Crypto.getRandomInteger();
        if(randomInteger < 0) {randomInteger = randomInteger * -1;}
        Integer index = Math.mod(randomInteger, chars.length());
        system.debug('index :' + index);
        return chars.substring(index, index + 1);
    }

    private static String shuffleString(String input) {
        List<String> chars = new List<String>();
        for (Integer i = 0; i < input.length(); i++) {
            chars.add(input.substring(i, i + 1));
        }

        // Fisher–Yates shuffle
        for (Integer i = chars.size() - 1; i > 0; i--) {
            Integer randomInteger = Crypto.getRandomInteger();
        if(randomInteger < 0) {randomInteger = randomInteger * -1;}
            Integer j = Math.mod(randomInteger, i + 1);
            String temp = chars[i];
            chars[i] = chars[j];
            chars[j] = temp;
        }

        return String.join(chars, '');
    }
}