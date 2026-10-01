@isTest
public class UpdateUnitStatusQueueableTest {
    
   

    @isTest
    static void myTestMethod(){
        Unit__c unit = new Unit__c();
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        insert unit;
        
        test.starttest();
        try{
            	UpdateUnitStatusQueueable obj = new UpdateUnitStatusQueueable(new set<String>{unit.id});
        	obj.execute(null);
        } catch(Exception e){
            
        }
        
        test.stopTest();
    }
}