@isTest
public class CaseSharingManagerTest {
@isTest
    static void shareCaseWithUserTest() {
        Map<String, Id> ids = TestDataFactory.createTestData();

    	// Fetch test data Ids
	    Id testCaseId = ids.get('TestCase');  
        Id managerUserId = ids.get('ManagerUser');
    	Id callCenterUserId = ids.get('UserPragathi');
    	Id frontLinerUserId = ids.get('FrontLinerUser');
        String accessLevel = 'Read';
        CaseSharingManager.shareCaseWithUser(testCaseId,managerUserId,accessLevel);
        accessLevel = 'Edit';
        CaseSharingManager.shareCaseWithUser(testCaseId,callCenterUserId,accessLevel);
        accessLevel = 'All';
        CaseSharingManager.shareCaseWithUser(testCaseId,frontLinerUserId,accessLevel);
        
        CaseSharingManager.removeCaseShare(testCaseId,frontLinerUserId);
        
        String newAccessLevel = 'Read';
        CaseSharingManager.updateCaseShareAccess(testCaseId,callCenterUserId,newAccessLevel);
        
        newAccessLevel = 'Edit';
        CaseSharingManager.updateCaseShareAccess(testCaseId,callCenterUserId,newAccessLevel);
        
        newAccessLevel = 'All';
        CaseSharingManager.updateCaseShareAccess(testCaseId,callCenterUserId,newAccessLevel);
    }
}