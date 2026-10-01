public class SignzyFlowRequestWrapper {
    public String flowId;
    public String userId;
    public UserInfo userInfo;
    public ProcessingConfig processingConfig;
    
    public class UserInfo {
        public String phoneNumber;
        public String dateOfBirth;
        public String emailAddress;
        public String externalReferenceId;
        public NameCls name;
        public AddressCls address;
        public IDInfoCls id;
        
    }
    
    public class NameCls {
        public String firstName;
        public String lastName;
    }
    
    public class AddressCls {
        public String street;
        public String street2;
        public String city;
        public String region;
        public String postalCode;
        public String country;
    }
    
    public class IDInfoCls {
        public String idType;
        public String idType2;
        public String country;
    }
    public class ProcessingConfig {
        public String callbackUrl;
        public String authKeyForCallback;
        public Integer redirectTime;
        public String successRedirectUrl;
        public String failureRedirectUrl;
        public Integer journeyLinkValidity;
        public integer journeySessionExpiry;
        public string language;
    }
}