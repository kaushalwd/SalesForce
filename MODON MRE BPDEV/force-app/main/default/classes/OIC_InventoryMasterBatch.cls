/**
 * @description       : OIC_InventoryMasterBatch
 *                      - Builds SOQL dynamically for UNIT and SALESORDER filter profiles
 *                      - Callouts enabled via Database.AllowsCallouts
 *
 * @author            : Manoj
 * @Created           : 25-04-2026
 * --------------------------------------------------------------------------------------------------------------------
 * Version   Author    Date          Comment
 * 1.0       Manoj     25-04-2026    Initial Draft
 * 2.0       Manoj	   25-05-2026	 Add New mapping 
 * 3.0  	 Karunakar	13, Aug 2026	Excluding Test Units
 ********************************************************************************************************************/
global class OIC_InventoryMasterBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private String       queryFilter;    
    private String       projectName;
    private Date createRunDate = null;
    private Set<String> processIds;
    public String       dynamicQuery;
   	/**
     * Description : Initializes batch defaulting filter      
     *               type to Unit with no extra criteria.     
     */
    global OIC_InventoryMasterBatch() {
        this.queryFilter     = 'Unit';        
    }
	/**
     * Description : Initializes batch with filter type,     
     *               project, date, and ID scope params.     
     */
    global OIC_InventoryMasterBatch(String filterType, String projectName, Date createRunDate, Set<String> processIds) {
        this.queryFilter     = filterType;
        this.projectName     = projectName;
        this.createRunDate   =createRunDate; 
        this.processIds = processIds;
    }

    /**
     * Description : Builds dynamic SOQL for Unit or SO      
     *               scope based on the active filter type.  
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
		List<String> excludeStatuses  = new List<String>{ 'Modon - Egypt' };
        String SOstatusExcludeLst = System.Label.SO_Status_List;
        String MIREExcludelst = System.Label.MIRE_Exclude_List;
        String ModeofpaymentValues = System.Label.ModeofpaymentValues;
		list<String> SOList = new List<String>();
        for (String c : SOstatusExcludeLst.split(',')) SOList.add(c.trim());

        
        List<String> MIREList = new List<String>();
        for (String c2 : MIREExcludelst.split(',')) {
            if (c2 != null && c2.contains('^')) {
                MIREList.add(c2.replace('^', ',').trim());
            } else {
                MIREList.add(c2.trim());
            }
        }
        // Assign today's date to a local variable and bind that instead.
        Date targetDate = (createRunDate != null) ? createRunDate : Date.today();
        // Solution: build a full-day range — >= start of day AND < start of next day.
        DateTime  startOfDay  = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
        
        DateTime endOfDay   = DateTime.newInstance(targetDate.addDays(-30), Time.newInstance(0, 0, 0, 0));
        if (queryFilter == 'Unit') {

            // Query directly on Unit__c — only fields that live on Unit__c itself
            // 2.0 
            dynamicQuery =
                'SELECT Id, Name, ApprovalStatus__c, Opportunity__c,Status__c, GrossFloorAreaGFA__c,LastModifiedDate,Status_Change_Time__c, ' +
                'TotalGrossSellableAreaGSA__c, Description__c, UnitClassification__c,Category__c, TotalArea__c,' +
                'PlotAreasqm__c, BasePrice__c, Unit_Launch_Date__c, Number_of_Bedrooms__c, Project_Launch_Date__c, ' +
                'ADGMUnitNumber__c, PlotNo__c, Pass_id__c, Type__c, BuildingNo__c, ' +
                'Building_Name__c, Unit_Sold_Date__c, TotalPrice__c,' +
                'Phase__r.Project__r.ProjectNumber__c, Phase__r.EntityName__c, ' +
                'Phase__r.Name, Phase__r.Project__r.Name ' +
                'FROM Unit__c ' +
                'WHERE Phase__r.Project__r.Name NOT IN : MIREList AND Opportunity__c = null and Status__c != \'Sold\' AND (NOT NAME LIKE \'%TEST%\')';
            	
                    if (processIds != null && !processIds.isEmpty()) {
                        dynamicQuery += ' AND Id IN :processIds';
                    }
                    if (projectName != null) {
                        dynamicQuery += ' AND Phase__r.Project__r.Name = :projectName';
                    }
            		System.debug('72------ ' + dynamicQuery);
                    if(processIds == null && projectName == null){
                        dynamicQuery += ' AND LastModifiedDate <= :startOfDay'; //2.0
                    }
			//dynamicQuery += ' Limit 1';
            System.debug('77----' + dynamicQuery);
           

        } else if (queryFilter == 'SalesOrder') {
			//2.0
            dynamicQuery =
                'SELECT Id,Name, Status__c, CustomerAccount__c, CustomerAccount__r.Name, ' +
                'Phase_Name__c, TotalAmount__c, Totalpaidamount__c, ' +
                'Down_Payment_Status__c, SPAStatus__c, SPACustomerSignedDate__c,Discount_Amount__c,Sales_Commission__c, ' +
                'ProjectName__c, Source_Entity__c,Indirect_Commission_Amount__c,Discount_on_ADM_fee_Amount__c,External_Commission_Amount__c, ' +
                'Unit__c, ' +
                'Unit__r.LastModifiedDate, Unit__r.GrossFloorAreaGFA__c,Unit__r.Building_Name__c, Unit__r.AED_SQM__c, ' +
                'Unit__r.TotalGrossSellableAreaGSA__c, Unit__r.Description__c, ' +
                'Unit__r.UnitClassification__c, Unit__r.PlotAreasqm__c, Unit__r.BasePrice__c, ' +
                'Unit__r.Unit_Launch_Date__c, Unit__r.Status__c, Unit__r.Name, ' +
                'Unit__r.ADGMUnitNumber__c, Unit__r.PlotNo__c, Unit__r.Pass_id__c, ' +
                'Unit__r.Type__c, Unit__r.BuildingNo__c, Unit__r.TotalPrice__c, ' +
                'Unit__r.Phase__r.Project__r.ProjectNumber__c, ' +
                'Unit__r.Phase__r.EntityName__c, Unit__r.Project_Launch_Date__c, Unit__r.Number_of_Bedrooms__c, ' +
                'Unit__r.Building_No__c, Unit__r.Unit_Sold_Date__c, Unit__r.ApprovalStatus__c,Unit__r.Category__c, Unit__r.TotalArea__c ' +
                'FROM SalesOrder__c ' +
                'WHERE Status__c NOT IN : SOList ' +
                'AND ProjectName__c NOT IN : MIREList ' +
                'AND Source_Entity__c NOT IN :excludeStatuses ' ;
            
            if (processIds != null && !processIds.isEmpty()) {
                        dynamicQuery += ' AND Id IN :processIds';
                    }
                    if(projectName != null ){
                        dynamicQuery += ' AND ProjectName__c = :projectName';
                    }
                    if(createRunDate != null){
                        dynamicQuery += ' AND SOCreationDate__c >: createRunDate';
                    }else {
                        dynamicQuery += ' AND SOCreationDate__c <= :targetDate'; //2.0
                    }
        }

        System.debug('OIC_InventoryMasterBatch [' + queryFilter + '] Final Query: ' + dynamicQuery);
        return Database.getQueryLocator(dynamicQuery);
    }

    /**
     * Description : Invokes inventory master callout for    
     *               each batch scope of SObject records.    
     */
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            if (!scope.isEmpty()) {
                OIC_ManageInventoryMaster.getPropertyMaster(scope, queryFilter);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'OIC_InventoryMasterBatch.execute() Error: ' + ex.getMessage() +
                '\nStack: ' + ex.getStackTraceString());
        }
    }

    /**
     * Description : Logs batch completion message and       
     *               the final dynamic query that was used.  
     */
    global void finish(Database.BatchableContext bc) {
        System.debug('OIC_InventoryMasterBatch [' + queryFilter + '] complete.');
        System.debug('Query used: ' + dynamicQuery);
    }
}