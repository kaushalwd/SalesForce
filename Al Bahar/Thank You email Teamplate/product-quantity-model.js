<table width="600" border="0" cellspacing="0" cellpadding="0" align="center">
  <tbody>
    <tr>
      <td width="300" bgcolor="#ffffff" valign="middle" style="text-align: left; padding: 20px; font-family: sans-serif; font-size: 15px; color:#000000">
       <table width="300" align="center" cellpadding="5" cellspacing="0" border="1">
         <thead>
         <tr>
           <td width="50%" bgcolor="#ffffff" align="center"><strong>Quantity</strong></td>
           <td width="50%" bgcolor="#ffffff" align="center"><strong>Model</strong></td>     
         </tr>
         </thead>
         <tbody>
           <!--%%[
             IF @ItemRowCount > 0 Then
               FOR @i=1 to @ItemRowCount Do
                SET @ItemModelRow = Row(@ItemModelsRows, @i)
                SET @ItemQtyRow = Row(@ItemQtyRows, @i)
                SET @ItemModel = Field(@ItemModelRow, 1)
                SET @ItemQty = Field(@ItemQtyRow, 1)
             ]%%-->
              <tr>
               <td width="50%" bgcolor="#ffffff" align="center">%%=v(@ItemQty)=%%</td>
               <td width="50%" bgcolor="#ffffff" align="center">%%=v(@ItemModel)=%%</td>       
             </tr>  
             <!--%%[
              Next @i
             
             ELSE
              SET @ItemModel = Lookup("Test_Opportunity_ClosedWon", "OppProduct:Model", "Opportunity:Id", @OppId)
               SET @ItemQty = Lookup("Test_Opportunity_ClosedWon", "OppProduct:Quantity", "Opportunity:Id", @OppId)
            ]%%-->
            <tr>
             <td width="50%" bgcolor="#ffffff" align="center">%%=v(@ItemQty)=%%</td>
             <td width="50%" bgcolor="#ffffff" align="center">%%=v(@ItemModel)=%%</td>       
           </tr>  
            <!--%%[                 
             ENDIF
            ]%%-->
         </tbody>
       </table>
      </td>
    </tr>     
  </tbody>
</table>