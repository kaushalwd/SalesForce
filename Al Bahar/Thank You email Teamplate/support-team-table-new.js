%%[

SET @OppId = AttributeValue("Opportunity:Id")
SET @OppDate = AttributeValue("OppProduct:SRC_Date__c")
SET @AccName = Uppercase(AttributeValue("Account:Name"))
SET @AccAddress = Uppercase(AttributeValue("Account:BilllingAddress"))
SET @OppCountry = AttributeValue("Contact:Country")
SET @AccFName = AttributeValue("Contact:FirstName")
SET @AccLName = AttributeValue("Contact:LastName")
SET @AccCustName = "Customer"
SET @regEx = "([0-9]+)"
SET @regExMatchFName = RegExMatch(@AccFName, @regEx, 0, "IgnoreCase")
SET @regExMatchLName = RegExMatch(@AccLName, @regEx, 0, "IgnoreCase")
SET @UnSubLink = 'False'

IF (@AccFName == "" And @AccLName == "") Or (@AccFName == "NA" And @AccLName == "NA") Or (IsEmailAddress(@AccFName) == 'True' And IsEmailAddress(@AccLName) == 'True') Or (@regExMatchFName  != '' And @regExMatchLName  != '') Then
   SET @AccCustName = "Customer"
ELSE
     IF @AccFName != "" Or @AccLName != "" Then
       IF (IsEmailAddress(@AccFName) == 'False' And @regExMatchFName == '') And (IsEmailAddress(@AccLName) == 'False' And @regExMatchLName == '') And (Uppercase(@AccFName) != "NA" And Uppercase(@AccLName) != "NA") Then
          SET @AccCustName = Concat(ProperCase(@AccFName), " ", ProperCase(@AccLName))
       ELSEIF @AccFName != "" And (IsEmailAddress(@AccFName) == 'False' And @regExMatchFName == '' And Uppercase(@AccFName) != "NA") Then
          SET @AccCustName = ProperCase(@AccFName)
       ELSEIF @AccLName != "" And (IsEmailAddress(@AccLName) == 'False' And @regExMatchLName == '' And Uppercase(@AccLName) != "NA") Then
          SET @AccCustName = ProperCase(@AccLName)
       ENDIF
    ENDIF  
ENDIF  

IF @OppCountry == "OM" Then
 SET @companyName = "OASIS TRADING & EQUIPMENT CO. L.L.C"
 SET @companyLogo = "https://image.mkt.albahar.com/lib/fe2f11737364047b7c1770/m/1/32dbd4ba-24fd-4c97-a9b4-de5d5cbd8303.jpg"
ELSE
 SET @companyName = "MOHAMED ABDULRAHMAN AL-BAHAR L.L.C"
 SET @companyLogo = "https://image.mkt.albahar.com/lib/fe2f11737364047b7c1770/m/1/b027d73b-0882-4aef-814b-a2bc4737a3b9.jpg"
ENDIF   

SET @ItemModels = AttributeValue("OppProduct:Model")
SET @ItemModelsRows = BuildRowsetFromString(@ItemModels, ",")

SET @ItemQty = AttributeValue("OppProduct:Quantity")
SET @ItemQtyRows = BuildRowsetFromString(@ItemQty, ",")

SET @ItemRowCount = RowCount(@ItemModelsRows)

/*FOR @i=1 to @ItemRowCount Do
    SET @ItemModelRow = Row(@ItemModelsRows, @i)
    SET @ItemQtyRow = Row(@ItemQtyRows, @i)
    SET @ItemModel = Field(@ItemModelRow, 1)
    SET @ItemQty = Field(@ItemQtyRow, 1)
Next @i
*/



SET @OwnerId = Lookup("Test_Opportunity_ClosedWon", "Opportunity:OwnerId", "Opportunity:Id", @OppId)
SET @OwnerEmail = Lookup("Test_Opportunity_ClosedWon", "Opportunity:Owner_Email__c", "Opportunity:Id", @OppId)
SET @CustomerStore = Lookup("Test_Opportunity_ClosedWon", "Opportunity:Customer_Store__c", "Opportunity:Id", @OppId)

SET @SalesEngrName = ProperCase(Lookup("Test_Master_Users", "Name", "Id", @OwnerId, "IsActive", "True"))
SET @SalesEngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Id", @OwnerId, "IsActive", "True")

SET @SalesMngrName = ProperCase(Lookup("Test_Opportunity_ClosedWon", "Opportunity:Sales_Manager_Name__c", "Opportunity:Id", @OppId))
SET @SalesMngrEmail = ProperCase(Lookup("Test_Opportunity_ClosedWon", "Opportunity:Sales_Manager_E_mail__c", "Opportunity:Id", @OppId))
SET @SalesMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Email", @SalesMngrEmail, "IsActive", "True")

IF (@SalesMngrName == "" And @SalesMngrEmail == "") Then
  SET @SalesMngrName = ProperCase(Lookup("Test_Master_Users", "Name", "Customer_Store_Number__c", @CustomerStore, "IsActive", "True", "Title", "Sales Manager"))
ENDIF  

SET @ProductMngrName = ProperCase(Lookup("Test_Master_Users", "Name", "Customer_Store_Number__c", @CustomerStore, "IsActive", "True", "Title", "Product Support Marketing Manager"))
SET @ProductMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Customer_Store_Number__c", @CustomerStore, "IsActive", "True", "Title", "Product Support Marketing Manager")

SET @PartsMngrName = ProperCase(Lookup("Test_Master_Users", "Name", "Customer_Store_Number__c", @CustomerStore, "Title", "Parts Manager", "IsActive", "True"))
SET @PartsMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Customer_Store_Number__c", @CustomerStore, "Title", "Parts Manager", "IsActive", "True")

]%%