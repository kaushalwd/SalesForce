public class SignzyTradeLicenseWrapper {

    public Result result;
	public errorCls error;
    public class Result {
        public LicenseDetails licenseDetails;
        public OtherLicenseDetails otherLicenseDetails;
        public LicenseMembers licenseMembers;
        public LicenseActivities licenseActivities;
        public Address address;
        public Map<String, LicensePartner> licensePartners;
    }

    public class LicenseDetails {
        public String emirate;
        public String licenseNumber;
        public String parentLicenseNumber;
        public String companyName;
        public String tradeName;
        public String licensee;
        public String operatingNumber;
        public String legalType;
        public String expiryDate;
        public String issueDate;
        public String businessUnit;
        public String duNsNumber;
        public String mainLicenseNumber;
        public String registerNumber;
        public String dcciNumber;
        public String acciNumber;
        public String adcciNumber;
        public String type;
    }

    public class OtherLicenseDetails {
        public String dubaiChamberNumber;
        public String establishmentCardMohere;
        public String fedRegNumber;
        public String taxRegNumber;
        public String establishmentCardIca;
        public String establishmentDate;
        public String currentIssueDate;
        public String chamMNumber;
        public String localRegisteryNumber;
        public String cocMembershipNumber;
        public String companyFileNumber;
        public String accountNumber;
        public String vatNumber;
        public String countryOfOrigin;
    }

    public class LicenseMembers {
        // This is an empty object in the sample, but including it for future compatibility.
    }

    public class LicenseActivities {
        public List<String> activities;
    }

    public class Address {
        public String parcelId;
        public String telephone;
        public String mobileNumber;
        public String unit;
        public String unitNumber;
        public String premisesNumber;
        public String floorNumber;
        public String buildingName;
        public String buildingNumber;
        public String businessUnit;
        public String areaName;
        public String zone;
        public String address;
        public String street;
        public String mainArea;
        public String area;
        public String region;
        public String villaNumber;
        public String makaniNumber;
        public String email;
        public String propertyOwner;
        public String lessor;
        public String onwaniAddress;
        public String leaseContractNumber;
        public String contractExpiryDate;
    }

    public class LicensePartner {
        public String investorNumber;
        public String name;
        public String nationality;
        public String share;
        public String role;
        public String ownerNature;
    }
    public class errorCls{
        public decimal status;
        public String msg;
        public String responseCode;
        public String message;
    }
    public static SignzyTradeLicenseWrapper parse(String jsonString) {
        return (SignzyTradeLicenseWrapper) System.JSON.deserialize(jsonString, SignzyTradeLicenseWrapper.class);
    }
}