%%[

SET @OppId = AttributeValue("Opportunity:Id")

SET @AccId = Lookup("Test_Opportunity_ClosedWon", "Account:Id", "Opportunity:Id", @OppId)
SET @AccName = Lookup("Test_Master_Account", "Name", "Id", @AccId)
SET @ContactId = Lookup("Test_Opportunity_ClosedWon", "ContactKey", "Opportunity:Id", @OppId)

SET @AccStreet = Lookup("Test_Master_Account", "BillingStreet", "Id", @AccId)
SET @AccCity = Lookup("Test_Master_Account", "BillingCity", "Id", @AccId)
SET @AccState = Lookup("Test_Master_Account", "BillingState", "Id", @AccId)
SET @AccCountry = Lookup("Test_Master_Account", "BillingCountry", "Id", @AccId)

SET @AccAddress = Concat(@AccStreet, ", ", @AccState, ", ", @AccCountry)

SET @AccFName = Lookup("Test_Master_Contact", "FirstName", "Id", @ContactId)
SET @AccLName = Lookup("Test_Master_Contact", "LastName", "Id", @ContactId)
/*SET @AccCustName = "Customer"*/
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

 
SET @MachineSourceDate = Lookup("Test_Opportunity_ClosedWon", "OppProduct:SRC_Date__c", "Opportunity:Id", @OppId)
SET @ItemRows = LookupRows("Test_Master_OpportunityLineItem", "OpportunityId", @OppId, "SRC_Date__c", @MachineSourceDate, "Account__c", @AccId)
SET @ItemRowCount = RowCount(@ItemRows)


/*
FOR @i=1 to @ItemRowCount Do
    SET @ItemRow = Row(@ItemRows, @i)
    SET @ItemQty = Field(@ItemRow, "Quantity")
    SET @ItemModel = Field(@ItemRow, "Model__c")
Next @i
*/



SET @SalesEngrName = Lookup("Test_Master_Users", "Name", "Id", @AccId, "IsActive", "True")
SET @SalesEngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Id", @AccId, "IsActive", "True")

SET @OwnerId = Lookup("Test_Opportunity_ClosedWon", "Opportunity:OwnerId", "Opportunity:Id", @OppId)
SET @OwnerEmail = Lookup("Test_Opportunity_ClosedWon", "Opportunity:Owner_Email__c", "Opportunity:Id", @OppId)

SET @SalesMngrName = Lookup("Test_Master_Users", "Name", "Email", @OwnerEmail, "IsActive", "True")
SET @SalesMngrPhone = Lookup("Test_Master_Users", "MobilePhone", "Email", @OwnerEmail, "IsActive", "True")

SET @ProductMngrName = Lookup("Test_Master_Users", "Name", "AccountId", @AccountId, "IsActive", "True", "Title", "Product Support Marketing Manager")
SET @ProductMngrPhone = Lookup("Test_Master_Users", "Customer_Store_Number__c", "AccountId", @AccountId, "IsActive", "True", "Title", "Product Support Marketing Manager")

SET @PartsMngrName = Lookup("Test_Master_Users", "Name", "AccountId", @AccountId, "Title", "Parts Manager", "IsActive", "True",)
SET @PartsMngrPhone = Lookup("Test_Master_Users", "Customer_Store_Number__c", "AccountId", @AccountId, "Title", "Parts Manager", "IsActive", "True")

]%%