public class CreateUnitRequest {
    
    public String unitCode;
    public String unitId;
    public String buildingName;
    public String businessUnitName;
    public String propertyGroupName;
    public String effectiveDate;
    public String landDLDNumber;
    public String unitType;
    public String subUnitType;
    public String unitHandoverStatus;
    public String usages;
    public String unitStatus;
    public AreaDetails areaDetails;
    public String budgetZone;
    public String budgetDefinition;
    public String mollakPropertyGroupId;
    public String mollakUnitId;
    public String gisUnitId;
    
    public class AreaDetails {
        
        public Decimal approvedBUA;
        public Decimal actualBUA;
        public Decimal plotArea;
        public Decimal balconyArea;
        public Decimal gfa;
        public Decimal actualGFA;
        public Decimal sellableArea;
        
    }
    
}