<!--%%[
  IF (@SalesMngrName != "" OR @SalesEngrName != "" OR @ProductMngrName != "" OR @PartsMngrName != "") Then  
]%%-->
<table align="center" border="0" cellpadding="0" cellspacing="0" width="600">
 
  <tr>
   <td bgcolor="#ffffff" style="text-align: left; padding: 20px; font-family: sans-serif; font-size: 10px; color:#000000" valign="middle" width="500">
    <p>
     <b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Please note the contact details of our team waiting to support you.</b></p><table align="center" border="1" cellpadding="5" cellspacing="0" width="500">
     <!--%%[
            IF (@SalesMngrName == @SalesEngrName And @SalesMngrName != "") Then  
        ]%%-->
      <tr>
       <td bgcolor="#f5f5f5" width="40%">
        Sales Manager</td><td bgcolor="#f5f5f5" width="40%">
        %%=v(@SalesMngrName)=%%</td><td bgcolor="#f5f5f5" width="20%">
        %%=v(@SalesMngrPhone)=%%</td></tr><!--%%[
            ELSE

                IF @SalesEngrName != "" Then
        ]%%--><tr>
       <td bgcolor="#e5e5e5" width="35%">
        Sales Engineer</td><td bgcolor="#e5e5e5" width="35%">
        %%=v(@SalesEngrName)=%%</td><td bgcolor="#e5e5e5" width="25%">
        %%=v(@SalesEngrPhone)=%%</td></tr><!--%%[
                ENDIF

                IF @SalesMngrName != "" Then
                ]%%--><tr>
       <td bgcolor="#f5f5f5" width="40%">
        Sales Manager</td><td bgcolor="#f5f5f5" width="40%">
        %%=v(@SalesMngrName)=%%</td><td bgcolor="#f5f5f5" width="20%">
        %%=v(@SalesMngrPhone)=%%</td></tr><!--%%[
                    ENDIF
            ENDIF

            IF @ProductMngrName != "" Then
        ]%%--><tr>
       <td bgcolor="#e5e5e5" width="40%">
        Product Support Manager</td><td bgcolor="#e5e5e5" width="40%">
        %%=v(@ProductMngrName)=%%</td><td bgcolor="#e5e5e5" width="20%">
        %%=v(@ProductMngrPhone)=%%</td></tr><!--%%[
             ENDIF
             
             IF @PartsMngrName != "" Then
         ]%%--><tr>
       <td bgcolor="#f5f5f5" width="40%">
        Parts Manager</td><td bgcolor="#f5f5f5" width="40%">
        %%=v(@PartsMngrName)=%%</td><td bgcolor="#f5f5f5" width="20%">
        %%=v(@PartsMngrPhone)=%%</td></tr><!--%%[
             ENDIF
         ]%%--></table></td></tr></table>

<!--%%[
  ENDIF
]%%-->         