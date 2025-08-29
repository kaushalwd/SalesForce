%%[

SET @OppId = AttributeValue("Opportunity:Id")
SET @OppDate = AttributeValue("OppProduct:SRC_Date__c")

SET @AccId = Lookup("Test_Opportunity_ClosedWon", "Account:Id", "Opportunity:Id", @OppId)
SET @AccName = Lookup("Test_Opportunity_ClosedWon", "Account:Name", "Opportunity:Id", @OppId)
SET @AccAddress = Lookup("Test_Opportunity_ClosedWon", "Account:BilllingAddress", "Opportunity:Id", @OppId)
SET @AccFName = Lookup("Test_Opportunity_ClosedWon", "Contact:FirstName", "Opportunity:Id", @OppId)
SET @AccLName = Lookup("Test_Opportunity_ClosedWon", "Contact:LastName", "Opportunity:Id", @OppId)
	
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


SET @ItemModels = Lookup("Test_Opportunity_ClosedWon", "OppProduct:Model", "Opportunity:Id", @OppId, "OppProduct:SRC_Date__c", @OppDate)
SET @ItemModelsRows = BuildRowsetFromString(@ItemModels, ",")

SET @ItemQty = Lookup("Test_Opportunity_ClosedWon", "OppProduct:Quantity", "Opportunity:Id", @OppId)
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

SET @SalesEngrName = Lookup("Test_Master_Users", "Name", "Id", @OwnerId, "IsActive", "True")
SET @SalesEngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Id", @OwnerId, "IsActive", "True")

SET @SalesMngrName = Lookup("Test_Master_Users", "Name", "Email", @OwnerEmail, "IsActive", "True")
SET @SalesMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Email", @OwnerEmail, "IsActive", "True")

SET @ProductMngrName = Lookup("Test_Master_Users", "Name", "Customer_Store_Number__c", @CustomerStore, "IsActive", "True", "Title", "Product Support Marketing Manager")
SET @ProductMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Customer_Store_Number__c", @CustomerStore, "IsActive", "True", "Title", "Product Support Marketing Manager")

SET @PartsMngrName = Lookup("Test_Master_Users", "Name", "Customer_Store_Number__c", @CustomerStore, "Title", "Parts Manager", "IsActive", "True",)
SET @PartsMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Customer_Store_Number__c", @CustomerStore, "Title", "Parts Manager", "IsActive", "True")

]%%