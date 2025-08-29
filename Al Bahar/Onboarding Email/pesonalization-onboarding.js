%%[

SET @OppId = AttributeValue("Opportunity:Id")

SET @AccId = Lookup("Test_Opportunity_ClosedWon", "Account:Id", "Opportunity:Id", @OppId)
SET @AccName = Lookup("Test_Opportunity_ClosedWon", "Account:Name", "Opportunity:Id", @OppId)
SET @AccAddress = Lookup("Test_Opportunity_ClosedWon", "Account:BilllingAddress", "Opportunity:Id", @OppId)
SET @AccFName = Lookup("Test_Opportunity_ClosedWon", "Contact:FirstName", "Opportunity:Id", @OppId)
SET @AccLName = Lookup("Test_Opportunity_ClosedWon", "Contact:LastName", "Opportunity:Id", @OppId)

SET @OppCountry = Lookup("Test_Master_Account", "BillingCountry", "Id", @AccId)

IF @OppCountry == "OM" Then
 SET @CompanyName = "OASIS TRADING & EQUIPMENT CO. L.L.C"
 SET @CompanyLogo = "https://image.mkt.albahar.com/lib/fe2f11737364047b7c1770/m/1/32dbd4ba-24fd-4c97-a9b4-de5d5cbd8303.jpg"
ELSE
 SET @CompanyName = "MOHAMED ABDULRAHMAN AL-BAHAR L.L.C"
 SET @CompanyLogo = "https://image.mkt.albahar.com/lib/fe2f11737364047b7c1770/m/1/b027d73b-0882-4aef-814b-a2bc4737a3b9.jpg"
ENDIF 

Var @AccCustName

IF (@AccFName == @AccLName) And @AccFName != "" Then
    SET @AccCustName = @AccFName
ELSEIF @AccFName != "" And @AccLName != "" Then
    SET @AccCustName = Concat(@AccFName, " ", @AccLName)
ELSEIF @AccFName != "" Then
    SET @AccCustName = @AccFName
ELSEIF @AccLName != "" Then
    SET @AccCustName = @AccLName
ELSE
    SET @AccCustName = "Customer"    
ENDIF
    

SET @ItemModel = Lookup("Test_Opportunity_ClosedWon", "OppProduct:Model", "Opportunity:Id", @OppId)
SET @ItemQty = Lookup("Test_Opportunity_ClosedWon", "OppProduct:Quantity", "Opportunity:Id", @OppId)

]%%