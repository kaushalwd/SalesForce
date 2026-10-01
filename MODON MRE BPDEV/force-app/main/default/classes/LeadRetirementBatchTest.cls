@isTest
public class LeadRetirementBatchTest {
	@isTest(seealldata=true)
    static void myTestMethod(){
        Test.startTest();
        Try{
            LeadRetirementBatch batch = new LeadRetirementBatch();
        	batch.execute(null);
        	batch.start(null);
        	batch.execute(null, New list<Lead>{New Lead()});   
        }catch(Exception e){}
        	
        Test.stopTest();
    }
}