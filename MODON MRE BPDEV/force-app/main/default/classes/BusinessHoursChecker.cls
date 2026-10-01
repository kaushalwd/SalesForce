public class BusinessHoursChecker {
    public class Result {
        @InvocableVariable
        public Boolean isWithinBusinessHours;
    }

    @InvocableMethod
    public static List<Result> isWithinDefaultBusinessHours() {
        // Get the default business hours
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        Boolean isWithin = BusinessHours.isWithin(bh.Id, System.now());
        Result result = new Result();
        result.isWithinBusinessHours = isWithin;
        return new List<Result> {result};
    }
}