/**
* @description       : This class will maprch the system error message to the custom error message
* @author            : Manoj
* @group             : 
* @Created modified on  : 16-01-2026 * 
* * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj        16-01-2026      Initial Draft 
* 
**/
public class UserErrorMessage{
    public static String getUserErrorMessage( String systemMessage, Map<String, String> errorMsgMap    ) {
        if (String.isBlank(systemMessage)) return null;

        String normalizedSystemMsg = normalize(systemMessage);

        for (String systemKey : errorMsgMap.keySet()) {
            String normalizedKey = normalize(systemKey);

            // 80% match logic (contains)
            if (normalizedSystemMsg.contains(normalizedKey)) {
                return errorMsgMap.get(systemKey);
            }
        }
        return null;
    }

    private static String normalize(String s) {
    return s == null ? '' : s.toLowerCase().trim();
}
}