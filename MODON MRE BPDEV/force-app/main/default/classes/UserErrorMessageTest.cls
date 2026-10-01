/* @Created modified on  : 16-01-2026 * 
* * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj        16-01-2026      Initial Draft 
* 
**/
@IsTest
public class UserErrorMessageTest {

    @IsTest
    static void testBlankSystemMessage() {
        Map<String, String> errorMap = new Map<String, String>{
            'error occurred' => 'User friendly error'
        };

        String result = UserErrorMessage.getUserErrorMessage('', errorMap);

        System.assertEquals(null, result);
    }

    @IsTest
    static void testNullSystemMessage() {
        Map<String, String> errorMap = new Map<String, String>{
            'some error' => 'User error'
        };

        String result = UserErrorMessage.getUserErrorMessage(null, errorMap);

        System.assertEquals(null, result);
    }

    @IsTest
    static void testMatchingSystemMessage() {
        Map<String, String> errorMap = new Map<String, String>{
            'invalid field value' => 'Please check the entered value'
        };

        String systemMessage =
            'System Error: Invalid field value for record insert';

        String result =
            UserErrorMessage.getUserErrorMessage(systemMessage, errorMap);

        System.assertEquals(
            'Please check the entered value',
            result
        );
    }

    @IsTest
    static void testCaseInsensitiveAndTrimMatch() {
        Map<String, String> errorMap = new Map<String, String>{
            '  INVALID FIELD VALUE  ' => 'Invalid input provided'
        };

        String systemMessage =
            'Error: invalid field value found';

        String result =
            UserErrorMessage.getUserErrorMessage(systemMessage, errorMap);

        System.assertEquals(
            'Invalid input provided',
            result
        );
    }

    @IsTest
    static void testNoMatchingKey() {
        Map<String, String> errorMap = new Map<String, String>{
            'duplicate record' => 'Duplicate record exists'
        };

        String systemMessage = 'Validation failed';

        String result =
            UserErrorMessage.getUserErrorMessage(systemMessage, errorMap);

        System.assertEquals(null, result);
    }
}