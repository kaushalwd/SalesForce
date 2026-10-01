/**********************************************************************************************************************
* Name               : Serviceclass                                                        
* Description        : This class is used as a Email and Phone masking
* Usage              : Called from case and contcat trigger
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      26 Dec 2024     Initial Draft          
******************************************************************************************************************/
public class Serviceclass {
    public static void handleBeforeInsert(List<SObject> newList, Map<String, String> fieldMappings) {
        for (SObject record : newList) {
            for (String customField : fieldMappings.keySet()) {
                String standardField = fieldMappings.get(customField);
                
                String customValue = (String) record.get(customField);
                if (!String.isEmpty(customValue)) {
                    // Populate standard field
                    record.put(standardField, customValue);
                    // Mask custom field
                    record.put(customField, maskField(customField, customValue));
                }
            }
        }
    }

    /**
     * Handles logic for before update operation.
     * @param newMap Map of new SObjects.
     * @param oldMap Map of old SObjects.
     * @param fieldMappings Map of custom field names to standard field names (or masked fields).
     */
    public static void handleBeforeUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap, Map<String, String> fieldMappings) {
        for (SObject newRecord : newMap.values()) {
            SObject oldRecord = oldMap.get(newRecord.Id);
            for (String customField : fieldMappings.keySet()) {
                String standardField = fieldMappings.get(customField);
                String newValue = (String) newRecord.get(customField);
                String oldValue = (String) oldRecord.get(customField);
                
                if (newValue != oldValue && !String.isEmpty(newValue)) {
                    // Populate standard field
                    newRecord.put(standardField, newValue);
                    // Mask custom field
                    newRecord.put(customField, maskField(customField, newValue));
                }
            }
        }
    }

    /**
     * Masks a field value based on its type.
     * @param fieldName The name of the field being masked.
     * @param value The value to be masked.
     * @return The masked value.
     */
    public static String maskField(String fieldName, String value) {
        if (fieldName.toLowerCase().contains('email')) {
            return maskEmail(value);
        } else if (fieldName.toLowerCase().contains('phone')) {
            return maskPhone(value);
        }else if (fieldName.toLowerCase().contains('emirates')) {
            return maskEmiratesId(value);
        }else if (fieldName.toLowerCase().contains('passport')) {
        return maskPassportNumber(value);
        }
        return value;
    }
    
	public static String maskEmail(String email) {
    if (String.isEmpty(email) || !email.contains('@')) {
        return email; 
    }

    // Split email into local and domain parts
    Integer atIndex = email.indexOf('@');
    String localPart = email.substring(0, atIndex);
    String domainPart = email.substring(atIndex + 1); // Exclude '@' in domain part

    // Fetch the number of characters to keep visible from custom labels
    Integer numFirstChars = Integer.valueOf(Label.EmailMaskFirstChars); // e.g., "1"
    Integer numLastChars = Integer.valueOf(Label.EmailMaskLastChars);  // e.g., "1"

    // Determine the first and last characters to keep visible
    String firstChars = localPart.substring(0, Math.min(numFirstChars, localPart.length()));
    String lastChars = localPart.substring(Math.max(localPart.length() - numLastChars, 0));

    // Calculate the number of stars to mask
    Integer numStars = localPart.length() - (numFirstChars + numLastChars);
    //String stars = '*'.repeat(Math.max(0, numStars)); // Dynamically create stars
	String stars = '*'.repeat(numStars);
    // Construct the masked email
    return firstChars + stars + lastChars + '@' + domainPart; // e.g., "{0}{*}{1}@{2}"
}

	public static String maskPhone(String phone) {
    if (String.isEmpty(phone) || phone.length() < 4) {
        return phone; 
    }
    Integer numFirstChars = Integer.valueOf(Label.PhoneMaskFirstChars); // PhoneMaskFirstChars is a custom label
    Integer numLastChars = Integer.valueOf(Label.PhoneMaskLastChars);  // PhoneMaskLastChars is a custom label

    //  first and last characters based on the custom label values
    String firstChars = phone.substring(0, Math.min(numFirstChars, phone.length()));
    String lastChars = phone.substring(Math.max(phone.length() - numLastChars, 0));

    // Calculate the number of stars
    Integer numStars = phone.length() - (numFirstChars + numLastChars);
    String stars = '*'.repeat(Math.max(0, numStars)); // Dynamically create the stars

    
    return firstChars + stars + lastChars;
}
        public static String maskEmiratesId(String emiratesId) {
        if (String.isEmpty(emiratesId) || emiratesId.length() < 4) {
            return emiratesId; 
        }

        Integer numFirstChars = Integer.valueOf(Label.EmiratesIdMaskFirstChars);
        Integer numLastChars = Integer.valueOf(Label.EmiratesIdMaskLastChars);

        String firstChars = emiratesId.substring(0, Math.min(numFirstChars, emiratesId.length()));
        String lastChars = emiratesId.substring(Math.max(emiratesId.length() - numLastChars, 0));

        Integer numStars = emiratesId.length() - (numFirstChars + numLastChars);
        String stars = '*'.repeat(Math.max(0, numStars));

        return firstChars + stars + lastChars;
    }
    public static String maskPassportNumber(String passportNumber) {
    if (String.isEmpty(passportNumber) || passportNumber.length() < 4) {
        return passportNumber;
    }

    // Fetch the number of characters to keep visible from custom labels
    Integer numFirstChars = Integer.valueOf(Label.PassportNumberMaskFirstChars); // e.g., "2"
    Integer numLastChars = Integer.valueOf(Label.PassportNumberMaskLastChars);  // e.g., "2"

    // Determine the first and last characters to keep visible
    String firstChars = passportNumber.substring(0, Math.min(numFirstChars, passportNumber.length()));
    String lastChars = passportNumber.substring(Math.max(passportNumber.length() - numLastChars, 0));

    // Calculate the number of stars to mask
    Integer numStars = passportNumber.length() - (numFirstChars + numLastChars);
    String stars = '*'.repeat(Math.max(0, numStars)); // Dynamically create stars

    // Construct the masked passport number
    return firstChars + stars + lastChars;
}
    

    /*private static String maskPhone(String phone) {
        if (phone.length() > 4) {
            return phone.substring(0, 1) + '********' + phone.substring(phone.length() - 1);
        }
        return phone;
    }
        if (String.isEmpty(phone) || phone.length() < 4) {
        return phone; // Return the phone number as-is if it doesn't meet masking criteria
    }
    
        String maskPattern = Label.PhoneMaskPattern; //custom label {0}******{1}
    String firstChars = phone.substring(0, 2); 
    String lastChars = phone.substring(phone.length() - 2); 
    
    // Replace placeholders with actual characters
    String maskedPhone = maskPattern.replace('{0}', firstChars).replace('{1}', lastChars);
    return maskedPhone; 

    }*/
 /* private static String maskEmail(String email) {
        
        if (String.isEmpty(email) || !email.contains('@')) {
        return email; 
    }

    Integer atIndex = email.indexOf('@');
    String localPart = email.substring(0, atIndex);
    String domainPart = email.substring(atIndex + 1); // Exclude '@' in domain part

    if (localPart.length() > 2) {
        String firstChar = localPart.substring(0, 1); 
        String lastChar = localPart.substring(localPart.length() - 1); 
        
        String maskPattern = Label.EmailMaskPattern; // custom label
        return maskPattern
            .replace('{0}', firstChar)
            .replace('{1}', lastChar)
            .replace('{2}', domainPart);
    }

    return email; */
         
       /* Integer atIndex = email.indexOf('@');
        if (atIndex > 0) {
            String localPart = email.substring(0, atIndex);
            String domainPart = email.substring(atIndex);
            if (localPart.length() > 1) {
                localPart = localPart.substring(0, 1) + '**********';
            }
            return localPart + domainPart;
        }
        return email;*/
}