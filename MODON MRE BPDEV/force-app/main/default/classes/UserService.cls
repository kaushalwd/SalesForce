/*
* @Author : Manoj
* @CreatedDate : 31th JAN 2024
* @Description : User object service class
*/
/*****************************************************************************************************
* Version       Author      Date             Comment                                                                       
* 1.0           Manoj   31JAN2024        Initial draft
*****************************************************************************************************/
public class UserService {
    
    public static UserService instance;
    
    public UserService() {
        
    }
    
    public static UserService getInstance() {
        if(instance == null) {
            instance = new UserService();
        }
        return instance;
    }
    
    public Boolean hasBypassEmail() {
        return FeatureManagement.checkPermission('BypassEmail');
    }
    
    public Boolean hasBypassIntegration() {
        return FeatureManagement.checkPermission('BypassIntegration');
    }
    
    public Boolean hasBypassTrigger() {
        return FeatureManagement.checkPermission('BypassTrigger');
    }
    
    public List<User> getUsersByIds(Set<Id> userIds) {
        return [SELECT Id, Name, Email FROM User WHERE Id IN :userIds];
    }
}