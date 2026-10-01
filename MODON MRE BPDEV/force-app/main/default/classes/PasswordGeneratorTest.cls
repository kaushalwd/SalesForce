@isTest
public class PasswordGeneratorTest {

    @isTest static void testGeneratePassword() {
        String password = PasswordGenerator.generatePassword();

        System.assertNotEquals(null, password, 'Password should not be null');
        System.assertEquals(8, password.length(), 'Password length should be 8 characters');

        Boolean hasUpper = false;
        Boolean hasNumber = false;
        Boolean hasSpecial = false;

        Pattern upperPattern = Pattern.compile('[A-Z]');
        Pattern numberPattern = Pattern.compile('[0-9]');
        Pattern specialPattern = Pattern.compile('[!@#$%^&*]');

        for (Integer i = 0; i < password.length(); i++) {
            String c = password.substring(i, i + 1);
            Matcher mUpper = upperPattern.matcher(c);
            Matcher mNumber = numberPattern.matcher(c);
            Matcher mSpecial = specialPattern.matcher(c);

            if (mUpper.matches()) {
                hasUpper = true;
            }
            if (mNumber.matches()) {
                hasNumber = true;
            }
            if (mSpecial.matches()) {
                hasSpecial = true;
            }
        }

         }
}