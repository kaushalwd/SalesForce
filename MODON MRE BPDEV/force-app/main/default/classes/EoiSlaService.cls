/**********************************************************************************************************************
* Name               : EoiSlaService
* Description        : Calculates EOI SLA expiry timestamps
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    15 May 2026     Calculate resident-aware SLA expiry excluding weekends
* 1.1           Prateek Bansal                    17 May 2026     SLA runs on a continuous clock; weekend exclusion removed
**********************************************************************************************************************/
public without sharing class EoiSlaService {
    private static final String RESIDENT = 'Resident';

    public static Datetime calculateExpiry(Datetime startTime, String residentStatus) {
        if (startTime == null) return null;
        return addHours(startTime, getSlaHours(residentStatus));
    }

    @TestVisible
    private static Integer getSlaHours(String residentStatus) {
        String rawHours = String.isNotBlank(residentStatus) && residentStatus.trim().equalsIgnoreCase(RESIDENT)
            ? System.Label.EOI_SLA_Hours
            : System.Label.EOI_SLA_Hours_Non_Resident;
        try {
            return Integer.valueOf(rawHours);
        } catch (Exception ex) {
            return 0;
        }
    }

    @TestVisible
    private static Datetime addHours(Datetime startTime, Integer hoursToAdd) {
        if (startTime == null || hoursToAdd == null || hoursToAdd <= 0) return startTime;
        return startTime.addHours(hoursToAdd);
    }
}