<!--ampscript starts-->

%%[
    var @numOfKids
    SET @crmIdEn = "003Qs00000EKRNPIA5"
    /* SET @crmIdEn = QueryParameter("sfid") */
    /*SET @crmId = Base64Decode(@crmIdEn)*/
    SET @crmId = "003Qs00000EKRNPIA5"    
    
    /*SET @crmId = _subscriberkey*/
    IF (empty(@crmId)) THEN
    SET @crmIdEn = QueryParameter("sfid")
    SET @crmId = Base64Decode(@crmIdEn)
    SET @methodType= 'Old'
    IF (empty(@crmId)) THEN
      SET @crmId = RequestParameter("sfid")
      IF (empty(@crmId)) THEN
       SET @crmId = QueryParameter("sfid")
      ENDIF
     ENDIF
    ENDIF
    IF NOT Empty(@crmId) THEN
    SET @contactRows =
    RetrieveSalesforceObjects("Contact",
    "Salutation,FirstName,LastName,Email,Phone,Country_Code__c,BirthDate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,GenderIdentity,No_of_Kids__c,Do_you_have_kids__c,MailingCity",
    "Id","=", @crmId)
    if RowCount(@contactRows) == 1 then /* there should only be one row */
    
    
    set @contactRow = Row(@contactRows, 1)
    set @firstName = Field(@contactRow, "FirstName")
    set @lastName = Field(@contactRow, "LastName")
    set @city = Field(@contactRow, "MailingCity")
    set @gender = Field(@contactRow, "GenderIdentity")
    set @email = Field(@contactRow, "Email")
    set @title = Field(@contactRow, "Salutation")
    set @Phone = Field(@contactRow, "Phone")
    set @mobilePhoneCode = Field(@contactRow, "Country_Code__c")
    set @birthdate = Field(@contactRow, "BirthDate")
    /*set @birthdate  = Format(@birth, "dd/MM/yyyy")*/
    set @language = Field(@contactRow, "Registration_Language__c")
    set @nationality = Field(@contactRow, "Nationality__c")
    set @country = Field(@contactRow, "Residence_Country__c")
    set @married = Field(@contactRow, "Marital_Status__c")
    set @doYouHaveKids = Field(@contactRow, "Do_you_have_kids__c")
    If @doYouHaveKids == true then
     SET @childExistsYes = "checked"
    else
     SET @childExistsNo = "checked"
   ENDIF
   /*output(concat("married: ",@married))*/
    IF @married == "Married" THEN
        set @marriedStatus = "Married"
    Elseif @married == "" Then
        set @marriedStatus = ""
         /*output(concat("<br>married12: ",@married))*/
    ELSE 
    set @marriedStatus = "Single"
    ENDIF
    
    set @numOfKids = Field(@contactRow, "No_of_Kids__c")
    
    /* Fetching Children details */
    var @j
    
    SET @childDetails = RetrieveSalesforceObjects("Family_Member__c","Gender__c,Date_Of_Birth__c,First_Name__c",
    "Contact__c", "=", @crmId,
    "Relationship__c", "=", "Child")
    SET @childDetailsRowCount = Rowcount(@childDetails)
    IF @childDetailsRowCount > 0 THEN
    SET @childExistsYes = "checked"
    For @j=1 to @childDetailsRowCount do
        SET @ChildDetailsRow = Row(@childDetails, @j)
        set @childGender = Field(@ChildDetailsRow, "Gender__c")
        set @childDOB = Field(@ChildDetailsRow, "Date_Of_Birth__c")
        set @childFirstName = Field(@ChildDetailsRow, "First_Name__c")
    next @j
    ELSE
     /*SET @childExistsNo = "checked"*/
    ENDIF
    
   
   
    
    /* Fetching Guest Subscription details */
    SET @GuestDetails = RetrieveSalesforceObjects("Guest_Subscription__c","Asset__c,Sub_Asset__c, Id,Primary_reason_for_your_visit_Legoland__c,How_often_do_you_visit_Legoland__c,Like_the_most_about_Legoland__c,Offers_and_Promotions__c,Upcoming_events_for_families__c,New_rides_and_entertainment__c,New_food_and_restaurants__c,Hotels_and_resorts__c,Customer_Survey__c,Emails_are_too_frequent__c,Content_isn_t_relevant__c,I_m_no_longer_in_Dubai__c,Temporary_Pause_30_Days__c,
    Other_Please_specify__c,Reason_of_Unsubscribe__c,Email__c,WhatsApp__c,SMS__c,Status__c",
    "Contact__c", "=", @crmId,"Asset__c","=","Dubai Parks and Resorts","Sub_Asset__c","=","Legoland")
     
    SET @guestDetailsRowCount = Rowcount(@GuestDetails)
    IF @guestDetailsRowCount > 0 THEN /*Roxy*/
    
        SET @guestDetailsRow = Row(@GuestDetails, 1)
        SET @assetType = Field(@guestDetailsRow, "Asset__c")
        SET @Id = Field(@guestDetailsRow, "Id")
        set @primaryReasonForVisit = Field(@guestDetailsRow, "Primary_reason_for_your_visit_Legoland__c")
        set @likeMostAbout = Field(@guestDetailsRow, "Like_the_most_about_Legoland__c")
        set @howOftenVisit = Field(@guestDetailsRow, "How_often_do_you_visit_Legoland__c")
        set @promotionaloffersdeals = Field(@guestDetailsRow, "Offers_and_Promotions__c")
        set @annualpassvipoffers = Field(@guestDetailsRow, "Upcoming_events_for_families__c")
        set @weeklyannouncements= Field(@guestDetailsRow, "New_rides_and_entertainment__c")
        set @newproductoffering = Field(@guestDetailsRow, "New_food_and_restaurants__c")
        set @latestnews = Field(@guestDetailsRow, "Hotels_and_resorts__c")
        set @customerSurvey = Field(@guestDetailsRow, "Customer_Survey__c")
        set @emailsTooFrequent = Field(@guestDetailsRow, "Emails_are_too_frequent__c")
        set @contentIsNotRelevant = Field(@guestDetailsRow, "Content_isn_t_relevant__c")
        set @noLongerInDubai = Field(@guestDetailsRow, "I_m_no_longer_in_Dubai__c")
        set @tempPause = Field(@guestDetailsRow, "Temporary_Pause_30_Days__c")
        set @otherSpecify = Field(@guestDetailsRow, "Other_Please_specify__c")
        set @reasonForUnsub = Field(@guestDetailsRow, "Reason_of_Unsubscribe__c")
        set @emailPref = Field(@guestDetailsRow, "Email__c")
        set @WhatsAppPref = Field(@guestDetailsRow, "WhatsApp__c")
        set @smsPref = Field(@guestDetailsRow, "SMS__c")
        set @status = Field(@guestDetailsRow, "Status__c")
        
        /*Output(concat("<br>LL: ",@assetType))*/
        
    ENDIF
    Endif
    ENDIF
    
]%%

<!--ampscript ends-->

<script runat="server">
        Platform.Load("core", "1.1.2");
        //Retrieve Form fields POST values

        var submittedProfile = Platform.Request.GetFormField('submittedProfile') || "";
        var submittedCommunications = Platform.Request.GetFormField('submittedCommunications') || "";
        
        var submittedUnsub = Platform.Request.GetFormField('submittedUnsub') || "";
   

        var subscriberKey    = Platform.Request.GetFormField('crmId') || "";
        var profileSalutation = Platform.Request.GetFormField('profileSalutation') || "";
        var firstName         = Platform.Request.GetFormField('firstName') || "";
        var lastName           = Platform.Request.GetFormField('lastName') || "";
        var phone                = Platform.Request.GetFormField('phone') || "";
        var birthdate            = Platform.Request.GetFormField('birthday') || "";
        var profileLang        = Platform.Request.GetFormField('profileLang') || "";
        var profileNationality = Platform.Request.GetFormField('profileNationality') || "";
        var profileCountry     = Platform.Request.GetFormField('profileCountry') || "";
        var profileMarried     = Platform.Request.GetFormField('inlineRadioOptions') || "";
        if(profileMarried=='option2'){
            profileMarriedStatus = 'Yes';
        }
        else if(profileMarried==''){
          profileMarriedStatus = '';
        }
        else{
            profileMarriedStatus = 'No';
        }
        var profileChildren = Platform.Request.GetFormField('kidsExists') || "";
        if(profileChildren=='kids-yes'){
            profileChildrenStatus = 'Yes';
        }
        else{
            profileChildrenStatus = 'No';
        }
        var email = Platform.Request.GetFormField('email') || "";

  
  
        var listpromotions = Platform.Request.GetFormField('hearOffers') || False;
        var listannualpass = Platform.Request.GetFormField('hearEvents') || false;
        var listweeklyannouncements = Platform.Request.GetFormField('hearNews') || false;
        var listnewproductoffering = Platform.Request.GetFormField('newProduct') || false;
        var listlatestnews= Platform.Request.GetFormField('hearOtherParks') || false;
        var listCustomer = Platform.Request.GetFormField('hearSurvey') || false;
        var tempPause = Platform.Request.GetFormField('unsubTemp') || false;
        

        var unsubscribe = Platform.Request.GetFormField('submittedUnsub') || false;

        var listOfInput = [];
    listOfInput.push({Name : 'Legoland - Offers and Promotions', Status: listpromotions })
  listOfInput.push({Name : 'Legoland - Upcoming events for families', Status: listannualpass })
  listOfInput.push({Name : 'Legoland - New rides and entertainment', Status: listweeklyannouncements})
        listOfInput.push({Name : 'Legoland - New food and restaurants', Status: listnewproductoffering})
        listOfInput.push({Name : 'Legoland - Hotels and resorts', Status: listlatestnews})
        listOfInput.push({Name : 'Legoland - Customer Survey', Status: listCustomer})
 
  
  

        if (subscriberKey) {
         

            //Retrieving all the lists in Marketing Cloud
            var allPublicationLists = getAllPublicationLists();
            var list=[];
            var allPublicationListsIds = {};

            for (var i in allPublicationLists) {
                allPublicationListsIds[(allPublicationLists[i]["Name"])] = allPublicationLists[i]["ID"];
     
            }  

            var Status, res;
            var api = new Script.Util.WSProxy();

           for(var j in listOfInput){
          
                if(!(listOfInput[j].Status)){
                    Status = 'Unsubscribed';
                }
                else{
                    Status = 'Active';
                }

                res = api.updateItem("Subscriber", {
                    SubscriberKey: subscriberKey,
                    EmailAddress: email,
                    Lists: [
                        {
                            ID: allPublicationListsIds[(listOfInput[j].Name)],
                            Status: Status
                        }
                    ]
                }, 
                {
                    SaveOptions: [
                        {
                            PropertyName: '*',
                            SaveAction: 'UpdateAdd'
                        }
                    ]
                });
            }

            if(submittedProfile){
                var subscriberData = {
                    "EmailAddress": email,
                    "Attributes": {
                       "Salutation": profileSalutation,
                        "First Name": firstName,
                        "Last Name" : lastName,
                         "DOB": birthdate,
                        "Language": profileLang,
                        "Nationality": profileNationality,
                        "Married": profileMarriedStatus,
                        "Do you have Kids": profileChildrenStatus,
                        "Country of Residence": profileCountry
                    }
                };
                            
            }

            var subObj = Subscriber.Init(subscriberKey);
           
             if (unsubscribe && submittedUnsub) {
               if(!tempPause){
                var unsubscribeSatus = subObj.Unsubscribe();
                Variable.SetValue("unsubscribeSatus", unsubscribeSatus);
               }
               else{
                  var resub = {              
                     "SubscriberKey": subscriberKey,
                     "Lists": {
                       "ID": '63', 
                       "Action": "Update"
                     },
                     "Status": "Active"
                  }; 
                 var subObj = Subscriber.Init(subscriberKey);
                 var status = subObj.Update(resub); 
              for (var j in listOfInput) {
        Status = 'Active';
      res = api.updateItem("Subscriber", {
        SubscriberKey: subscriberKey,
        EmailAddress: email,
        Lists: [
          {
            ID: allPublicationListsIds[(listOfInput[j].Name)],
            Status: Status
          }
        ]
      }
        ,
        {
          SaveOptions: [
            {
              PropertyName: '*',
              SaveAction: 'UpdateAdd'
            }
          ]
        }
      );
    }
      }
    }
          
          
          
            else {
              var updateStatus = subObj.Update(subscriberData);              
            }
            function getAllPublicationLists() {
  
                var rr = Platform.Function.CreateObject("RetrieveRequest");
                Platform.Function.SetObjectProperty(rr, "ObjectType", "Publication");
                Platform.Function.SetObjectProperty(rr, "QueryAllAccounts", "True");

                Platform.Function.AddObjectArrayItem(rr, "Properties", "ID");
                Platform.Function.AddObjectArrayItem(rr, "Properties", "Name");
                Platform.Function.AddObjectArrayItem(rr, "Properties", "Category");
                Platform.Function.AddObjectArrayItem(rr, "Properties", "Client.ID");

                var reqParams = [0,0];
                var publications = Platform.Function.InvokeRetrieve(rr, reqParams);
            

                return publications;
                
            } 
        }
    </script>


<!DOCTYPE html>
                        <html lang="ar" dir="ltr">
                            <head><meta name="Hotels" content="INDEX,FOLLOW"><meta name="keywords" content=""><meta name="description" content="">
                              <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
 <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                                <title>Legoland® Dubai</title>
 <link rel="icon" type="image/x-icon" href="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/f1d77e47-c8ae-42fe-bd21-2ed9cb496bd2.png">
                                <link href='https://cloud.explore.legoland.ae/LL_bootstrap_Arabic_QA.min.css' rel='stylesheet'>
                                
                                <script type='text/javascript' src='https://cloud.explore.legoland.ae/LL_jquery_Arabic_QA.min.js'></script>
                            
                                <!-- Font special for pages-->
                                <link href="https://fonts.googleapis.com/css?family=Poppins:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i,800,800i,900,900i" rel="stylesheet">
                                <link href="https://cloud.explore.legoland.ae/LL_style_Arabic_QA.css" rel="stylesheet">
                                
                              
                               
                                <!-- Vendor CSS-->
                                <link href="https://cloud.explore.legoland.ae/LL_select2_Arabic_QA.min.css" rel="stylesheet" media="all">
                             
                                <style>
/* nav */
.card {
  max-width: 90rem;
  padding: 0;
  border: none;
  border-radius: 0.5rem;
}


.nav-link {
  color: #000;
    font-weight: 700;
    background: white;
    margin: 0 5px;
    font-size: 16px;
}
.nav-link:hover {
  color:#ffd400
}

.nav-pills .nav-link.active {
  color: #fff;
    background-color: #ffd400!important;
 
    font-weight: 700;
}

.tab-content {
  padding-bottom: 1.3rem;
}



/* 3nd card */
/* span {
  margin-left: 0.5rem;
  padding: 1px 10px;
  color: white;
  background-color: rgb(143, 143, 143);
  border-radius: 4px;
  font-weight: 600;
} */

.third {
  padding: 0 1.5rem 0 1.5rem;
}

/* label {
  font-weight: 500;
  color: rgb(104, 104, 104);
} */

.btn-success {
  float: right;
}

.form-control:focus {
  box-shadow: 0px 1px 1px rgba(0, 0, 0, 0.075) inset, 0px 0px 7px rgba(0, 0, 0, 0.2);
}
/* 
select {
  -webkit-appearance: none;
  -moz-appearance: none;
  text-indent: 1px;
  text-overflow: "";
} */

/* 1st card */

ul {
  list-style: none;
  margin-top: 1rem;

}

/* .search {
  padding: 0 1rem 0 1rem;
} */

.ccontent li .wrapp {
  padding: 0.3rem 1rem 0.001rem 1rem;
}

.ccontent li .wrapp div {
  font-weight: 600;
}

.ccontent li .wrapp p {
  font-weight: 360;
} 

.ccontent li:hover {
  background-color: rgb(117, 93, 255);
  color: white;
}

/* 2nd card */

.addinfo {
  padding: 0 1rem;
}
</style>
                              
                              
                              <script runat=server>
    Platform.Response.SetResponseHeader("Strict-Transport-Security","max-age=200");
    Platform.Response.SetResponseHeader("X-XSS-Protection","1; mode=block");
    Platform.Response.SetResponseHeader("X-Frame-Options","Deny");
    Platform.Response.SetResponseHeader("X-Content-Type-Options","nosniff");
    Platform.Response.SetResponseHeader("Referrer-Policy","strict-origin-when-cross-origin");
  Platform.Response.SetResponseHeader("Content-Security-Policy","script-src 'self' 'unsafe-inline' https://image.explore.legoland.ae; frame-ancestors 'none'");
    

</script>
                              
                              
                              
                              
                                </head>
                          
            <body onload="handleNumOfKidsChange(%%=v(@numOfKids)=%%); kidsPrepopulation(); ShowHideDivkids();">
                                   <!-- Header start -->0909
        <header>
          <div class="container">
              <div class="row align-items-center" style="margin: 0 auto;">
                  <div class="col-lg-8 col-md-8 col-sm-8 col-8">
                      <a href="https://www.legoland.com/dubai/" class="logo-link" target="_blank">
                          <img src="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/dda5f4e4-b08a-4ecb-8032-de4cf558c40d.png"
                              alt="logo">
                      </a>
                  </div>
                  <div class="col-lg-4 col-md-4 col-sm-4 col-4">

                  <a href="https://dubaiholding.com/en/who-we-are/our-companies/dubai-holding-entertainment/" class="logo-link" target="_blank">
                      <img src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/28c95259-4d4e-4178-bae2-94a56198b301.png"
                          alt="logo-dhe" class="pull-right dhe-logo" style="border-radius:5px">
                  </a>

                  </div>
              </div>
          </div>
      </header>
      <!-- Header End --><section class="banner">
        <div class="main-banner">
            <img src= "https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/e594dc8c-a1fe-46e6-a6cf-619d83e463c4.jpg" alt="banner-img" class="responsive">
                </div>
                <div class="container">
                  <h1 class="username">Hi %%=v(ProperCase(@firstName))=%% </h1>
              </div>
              </section>
                                 <div class="container card content-wrapper">
      <!-- nav options -->
      <ul class="nav nav-pills mb-3 d-flex justify-content-center" id="pills-tab" role="tablist">
        <li class="nav-item">
          <a class="nav-link active" id="my-profile-tab" data-toggle="pill" href="#my-profile" role="tab" aria-controls="my-profile" aria-selected="true"onclick="updateUrlHash('#my-profile')">الملف الشخصي</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" id="interests-tab" data-toggle="pill" href="#interests" role="tab" aria-controls="interests" aria-selected="false" onclick="updateUrlHash('#interests')">الاهتمامات</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" id="communications-tab" data-toggle="pill" href="#communications" role="tab" aria-controls="communications" aria-selected="false" onclick="updateUrlHash('#communications')">قنوات الاتصال</a>
        </li>
      </ul>

      <!-- content -->
      <div class="tab-content" id="pills-tabContent p-3">
        <!-- 1st card -->
        <div class="tab-pane fade show active" id="my-profile" role="tabpanel" aria-labelledby="my-profile-tab">
          <div class="wrapper wrapper--w1200">
            
            <form class="profile-form" action="" method="post" name="myForm" id="profile-form" autocomplete="off">
              <h4 class="pt-4 pb-4">أخبرنا عن نفسك</h4>
              <div class="row">
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">اللقب (السيد/آنسة/السيدة)</label>
                          <div class="select-wrapper hide-icon">
                          <select class="form-control" name="profileSalutation">
                                <option value=" " %%=IIF(@title=='' ,'selected', "" )=%%>اختر</option>
                                  <option value="Mr." %%=IIF(@title=='Mr.' ,'selected', "" )=%%>السيد  
                                  </option>
                                  <option value="Ms." %%=IIF(@title=='Ms.' ,'selected', "" )=%%>آنسة
                                  </option>
                                  <option value="Mrs." %%=IIF(@title=='Mrs.' ,'selected', "" )=%%>السّيدة
                                  </option>
                              </select>
                              
               
                          </div>
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">الاسم الأول<sup class="text-danger">*</sup></label>
                          <input type="text" id="firstName" name="firstName" id="fname" value="%%=v(ProperCase(@firstName))=%%"
                              class="form-control" required aria-required="true" />
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group">
                          <label for="">اسم العائلة<sup class="text-danger">*</sup></label>
                          <input type="text" id="lname" name="lastName" value="%%=v(ProperCase(@lastName))=%%"
                              class="form-control" required aria-required="true" />
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">عنوان البريد الإلكتروني<sup class="text-danger">*</sup></label>
                          <input type="email" id="email" name="email" value="%%=v(@email)=%%"
                              class="form-control" required aria-required="true" />
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12 phone_num">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">رقم الهاتف<sup class="text-danger">*</sup></label>
                         <div class="input-group mb-3">
  
                              <div class="select-wrapper hide-icon">
                              <div class="input-group-prepend">
                               
                         <input type="text"class="form-control" list="codedatalistOptions" name="lang" id="country-code"   placeholder="+971" value="%%=v(@mobilePhoneCode)=%%" required>
  
                <datalist id="codedatalistOptions">
               <option value="+93">Afghanistan </option>
        <option value="+355">Albania </option>
        <option value="+213">Algeria </option>
        <option value="+1-684">American Samoa</option>
        <option value="+376">Andorra, Principality of </option>
        <option value="+244">Angola</option>
        <option value="+1-264">Anguilla </option>
        <option value="+672">Antarctica</option>
        <option value="+1-268">Antigua and Barbuda</option>
        <option value="+54">Argentina </option>
        <option value="+374">Armenia</option>
        <option value="+297">Aruba</option>
        <option value="+61">Australia</option>
        <option value="+43">Austria</option>
        <option value="+994">Azerbaijan or Azerbaidjan</option>
  
        <option value="+1-242">Bahamas, Commonwealth of The</option>
        <option value="+973">Bahrain</option>
                  <option value="+880">Bangladesh</option>
        <option value="+1-246">Barbados </option>
        <option value="+375">Belarus</option>
        <option value="+32">Belgium </option>
        <option value="+501">Belize</option>
        <option value="+229">Benin</option>
        <option value="+1-441">Bermuda </option>
        <option value="+975">Bhutan, Kingdom of</option>
        <option value="+591">Bolivia </option>
        <option value="+387">Bosnia and Herzegovina </option>
        <option value="+267">Botswana</option>
        <option value="+074">Bouvet Island</option>
        <option value="+55">Brazil </option>
        <option value="+086">British Indian Ocean Territory</option>
        <option value="+673">Brunei </option>
        <option value="+359">Bulgaria </option>
        <option value="+226">Burkina Faso</option>
        <option value="+257">Burundi</option>
        <option value="+855">Cambodia</option>
        <option value="+237">Cameroon</option>
        <option value="+1">Canada </option>
        <option value="+238">Cape Verde </option>
        <option value="+1-345">Cayman Islands </option>
        <option value="+236">Central African Republic </option>
        <option value="+235">Chad </option>
        <option value="+56">Chile </option>
        <option value="+86">China </option>
        <option value="+53">Christmas Island </option>
        <option value="+61">Cocos Islands </option>
        <option value="+57">Colombia</option>
        <option value="+269">Comoros</option>
        <option value="+243">Congo</option>
        <option value="+242">Congo</option>
        <option value="+682">Cook Islands</option>
        <option value="+506">Costa Rica </option>
        <option value="+225">Cote D'Ivoire</option>
        <option value="+385">Croatia</option>
        <option value="+53">Cuba </option>
        <option value="+357">Cyprus </option>
        <option value="+420">Czech Republic</option>
        <option value="+112">Czechoslavakia (Former) See CZ Czech Republic or Slovakia</option>
  
        <option value="+45">Denmark </option>
        <option value="+253">Djibouti</option>
        <option value="+1-767">Dominica </option>
        <option value="+1-809 and +1-829  ">Dominican Republic </option>
  
        <option value="+670">East Timor</option>
        <option value="+593 ">Ecuador </option>
        <option value="+20">Egypt</option>
        <option value="+503">El Salvador </option>
        <option value="+240">Equatorial Guinea</option>
        <option value="+291">Eritrea</option>
        <option value="+372">Estonia</option>
        <option value="+251">Ethiopia</option>
  
        <option value="+500">Falkland Islands</option>
        <option value="+298">Faroe Islands </option>
        <option value="+679">Fiji </option>
        <option value="+358">Finland </option>
        <option value="+33">France </option>
        <option value="+594">French Guiana or French Guyana </option>
        <option value="+689">French Polynesia</option>
        <option value="+260">French Southern Territories and Antarctic Lands </option>
  
        <option value="+241">Gabon</option>
        <option value="+220">Gambia, The </option>
        <option value="+995">Georgia</option>
        <option value="+49">Germany </option>
        <option value="+233">Ghana (Former Gold Coast)</option>
        <option value="+350">Gibraltar </option>
        <option value="+826">Great Britain (United Kingdom) </option>
        <option value="+30">Greece </option>
        <option value="+299">Greenland </option>
        <option value="+1-473">Grenada </option>
        <option value="+590">Guadeloupe</option>
        <option value="+1-671">Guam</option>
        <option value="+502">Guatemala </option>
        <option value="+224">Guinea</option>
        <option value="+245">Guinea-Bissau</option>
        <option value="+592">Guyana</option>
        <option value="+509">Haiti </option>
        <option value="+334">Heard Island and McDonald Islands</option>
        <option value="+336">Holy See</option>
        <option value="+504">Honduras</option>
        <option value="+852">Hong Kong</option>
        <option value="+36">Hungary</option>
        <option value="+354">Iceland </option>
        <option value="+91">India </option>
        <option value="+62">Indonesia</option>
        <option value="+98">Iran, Islamic Republic of</option>
        <option value="+964">Iraq </option>
        <option value="+353">Ireland </option>
        <option value="+972">Israel </option>
        <option value="+39">Italy </option>
        <option value="+1-876">Jamaica </option>
        <option value="+81">Japan </option>
        <option value="+962">Jordan</option>
        <option value="+7">Kazakstan or Kazakhstan</option>
        <option value="+254">Kenya</option>
        <option value="+686">Kiribati</option>
        <option value="+850">North Korea</option>
        <option value="+82">South Korea</option>
        <option value="+965">Kuwait </option>
        <option value="+996">Kyrgyzstan</option>
        <option value="+856">Lao People's Democratic Republic (Laos)</option>
        <option value="+371">Latvia</option>
        <option value="+961">Lebanon </option>
        <option value="+266">Lesotho</option>
        <option value="+231">Liberia </option>
        <option value="+218">Libya</option>
        <option value="+423">Liechtenstein </option>
        <option value="+370">Lithuania</option>
        <option value="+352">Luxembourg </option>
        <option value="+853">Macau </option>
        <option value="+389">Macedonia</option>
        <option value="+261">Madagascar</option>
        <option value="+265">Malawi</option>
        <option value="+60">Malaysia </option>
        <option value="+960">Maldives </option>
        <option value="+223">Mali</option>
        <option value="+356">Malta </option>
        <option value="+692">Marshall Islands</option>
        <option value="+596">Martinique</option>
        <option value="+222">Mauritania </option>
        <option value="+230">Mauritius </option>
        <option value="+269">Mayotte</option>
        <option value="+52">Mexico </option>
        <option value="+691">Micronesia</option>
        <option value="+373">Moldova</option>
        <option value="+377">Monaco</option>
        <option value="+976">Mongolia</option>
        <option value="+1-664">Montserrat </option>
        <option value="+212">Morocco </option>
        <option value="+258">Mozambique</option>
        <option value="+95">Myanmar</option>
        <option value="+264">Namibia</option>
        <option value="+674">Nauru</option>
        <option value="+977">Nepal </option>
        <option value="+31">Netherlands </option>
        <option value="+599">Netherlands Antilles</option>
        <option value="+687">New Caledonia </option>
        <option value="+64">New Zealand</option>
        <option value="+505">Nicaragua </option>
        <option value="+227">Niger </option>
        <option value="+234">Nigeria </option>
        <option value="+683">Niue</option>
        <option value="+672">Norfolk Island </option>
        <option value="+1-670">Northern Mariana Islands</option>
        <option value="+578">Norway </option>
        <option value="+968">Oman</option>
        <option value="+92">Pakistan</option>
        <option value="+680">Palau</option>
        <option value="+970">Palestinian State</option>
        <option value="+507">Panama </option>
        <option value="+675">Papua New Guinea</option>
        <option value="+595">Paraguay </option>
        <option value="+51">Peru </option>
        <option value="+63">Philippines </option>
        <option value="+612">Pitcairn Island</option>
        <option value="+48">Poland </option>
        <option value="+351">Portugal </option>
        <option value="+1-787">Puerto Rico </option>
        <option value="+974 ">Qatar </option>
        <option value="+262">Reunion</option>
        <option value="+40">Romania </option>
        <option value="+7">Russia</option>
       
        <option value="+250">Rwanda</option>
        <option value="+290">Saint Helena </option>
        <option value="+1-869">Saint Kitts and Nevis</option>
        <option value="+1-758">Saint Lucia </option>
        <option value="+508">Saint Pierre and Miquelon </option>
        <option value="+1-784">Saint Vincent and the Grenadines </option>
        <option value="+685">Samoa</option>
        <option value="+378">San Marino </option>
        <option value="+239">Sao Tome and Principe </option>
        <option value="+966">Saudi Arabia </option>
        <option value="+688">Serbia, Republic of</option>
        <option value="+221">Senegal </option>
        <option value="+248">Seychelles </option>
        <option value="+232">Sierra Leone </option>
        <option value="+65">Singapore </option>
        <option value="+421">Slovakia</option>
        <option value="+386">Slovenia </option>
        <option value="+677">Solomon Islands</option>
        <option value="+252">Somalia</option>
        <option value="+27">South Africa</option>
        <option value="+239">South Georgia and the South Sandwich Islands</option>
        <option value="+34">Spain </option>
        <option value="+94">Sri Lanka </option>
        <option value="+249">Sudan</option>
        <option value="+597">Suriname</option>
        <option value="+47">Svalbard and Jan Mayen Islands </option>
        <option value="+268">Swaziland</option>
        <option value="+46">Sweden </option>
        <option value="+41">Switzerland </option>
        <option value="+963">Syria</option>
        <option value="+886">Taiwan</option>
        <option value="+992">Tajikistan</option>
        <option value="+255">Tanzania</option>
        <option value="+66">Thailand (Former Siam)</option>
        <option value="+768">Togo</option>
        <option value="+690">Tokelau </option>
        <option value="+676">Tonga</option>
        <option value="+1-868">Trinidad and Tobago </option>
        <option value="+216">Tunisia </option>
        <option value="+90">Turkey </option>
        <option value="+993">Turkmenistan</option>
        <option value="+1-649">Turks and Caicos Islands </option>
        <option value="+688">Tuvalu</option>
        <option value="+256">Uganda, Republic of</option>
        <option value="+380">Ukraine</option>
        <option value="+971">United Arab Emirates</option>
        <option value="+44">United Kingdom</option>
        <option value="+1">United States</option>
        <option value="+581">United States Minor Outlying Islands </option>
        <option value="+598">Uruguay</option>
        <option value="+998">Uzbekistan</option>
        <option value="+678">Vanuatu</option>
        <option value="+418">Vatican City State</option>
        <option value="+58">Venezuela </option>
        <option value="+84">Vietnam </option>
        <option value="+1-284">Virgin Islands, British </option>
        <option value="+1-340">Virgin Islands, United States</option>
        <option value="+681">Wallis and Futuna Islands </option>
        <option value="+732">Western Sahara</option>
        <option value="+967">Yemen </option>
        <option value="+38">Yugoslavia </option>
        <option value="+243">Zaire</option>
        <option value="+260">Zambia</option>
        <option value="+263">Zimbabwe</option>
  
              </datalist> 
            
              
                                </div>
                              </div>
  
  
                             <input name="phone" type="tel" class="form-control phone-inteltel" id="phone1"
                                      pattern="[0-9]{9,10}" title="Phone number should be between 9-10 digits" value="%%=v(@Phone)=%%" required/>
                          </div>
                      </div>
                  </div>
  
                    <div class="col-lg-4 col-md-6 col-sm-12 col-12 hidden">
                      
                  </div>
                
                  

                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">بلد الإقامة<sup class="text-danger">*</sup></label>
                          <div class="select-wrapper hide-icon profilecountry">
  
                          <select class="form-control" name="profileCountry" id="profileCountry" required>
                                <option value="">اختر الدولة</option>
                               <option value="Afghanistan" %%=IIF(@country=='Afghanistan', "selected", "")=%% >أفغانستان</option>
<option value="Aland Islands" %%=IIF(@country=='Aland Islands', 'selected', "")=%%>جزر آلاند</option>
<option value="Albania" %%=IIF(@country=='Albania', "selected", "")=%%>ألبانيا</option>
<option value="Algeria" %%=IIF(@country=='Algeria', "selected", "")=%%>الجزائر</option>
<option value="American Samoa" %%=IIF(@country=='American Samoa', "selected", "")=%%>ساموا الأمريكية</option>
<option value="Andorra" %%=IIF(@country=='Andorra', "selected", "")=%%>أندورا</option>
<option value="Angola" %%=IIF(@country=='Angola', "selected", "")=%%>أنغولا</option>
<option value="Anguilla" %%=IIF(@country=='Anguilla', "selected", "")=%%>أنغيلا</option>
<option value="Antarctica" %%=IIF(@country=='Antarctica', "selected", "")=%%>أنتاركتيكا</option>
<option value="Antigua And Barbuda" %%=IIF(@country=='Antigua And Barbuda', "selected", "")=%%>أنتيغوا وباربودا</option>
<option value="Argentina" %%=IIF(@country=='Argentina', "selected", "")=%%>الأرجنتين</option>
<option value="Armenia" %%=IIF(@country=='Armenia', "selected", "")=%%>أرمينيا</option>
<option value="Aruba" %%=IIF(@country=='Aruba', "selected", "")=%%>أروبا</option>
<option value="Australia" %%=IIF(@country=='Australia', "selected", "")=%%>أستراليا</option>
<option value="Austria" %%=IIF(@country=='Austria', "selected", "")=%%>النمسا</option>
<option value="Azerbaijan" %%=IIF(@country=='Azerbaijan', "selected", "")=%%>أذربيجان</option>
<option value="Bahamas" %%=IIF(@country=='Bahamas', "selected", "")=%%>الباهاما</option>
<option value="Bahrain" %%=IIF(@country=='Bahrain', "selected", "")=%%>البحرين</option>
<option value="Bangladesh" %%=IIF(@country=='Bangladesh', "selected", "")=%%>بنغلاديش</option>
<option value="Barbados" %%=IIF(@country=='Barbados', "selected", "")=%%>بربادوس</option>
<option value="Belarus" %%=IIF(@country=='Belarus', "selected", "")=%%>بيلاروسيا</option>
<option value="Belgium" %%=IIF(@country=='Belgium', "selected", "")=%%>بلجيكا</option>
<option value="Belize" %%=IIF(@country=='Belize', "selected", "")=%%>بليز</option>
<option value="Benin" %%=IIF(@country=='Benin', "selected", "")=%%>بنين</option>
<option value="Bermuda" %%=IIF(@country=='Bermuda', "selected", "")=%%>برمودا</option>
<option value="Bhutan" %%=IIF(@country=='Bhutan', "selected", "")=%%>بوتان</option>
<option value="Bolivia" %%=IIF(@country=='Bolivia', "selected", "")=%%>بوليفيا</option>
<option value="Bosnia and Herzegovina" %%=IIF(@country=='Bosnia and Herzegovina', "selected", "")=%%>البوسنة والهرسك</option>
<option value="Botswana"  %%=IIF(@country=='Botswana', "selected", "")=%%>بوتسوانا</option>
<option value="Bouvet Island" %%=IIF(@country=='Bouvet Island', "selected", "")=%%>جزيرة بوفيه</option>
<option value="Brazil" %%=IIF(@country=='Brazil', "selected", "")=%%>البرازيل</option>
<option value="British Indian Ocean Territory" %%=IIF(@country=='British Indian Ocean Territory', "selected", "")=%%>إقليم المحيط الهندي البريطاني</option>
<option value="Brunei Darussalam" %%=IIF(@country=='Brunei Darussalam', "selected", "")=%%>بروناي دار السلام</option>
<option value="Bulgaria" %%=IIF(@country=='Bulgaria', "selected", "")=%%>بلغاريا</option>
<option value="Burkina Faso" %%=IIF(@country=='Burkina Faso', "selected", "")=%%>بوركينا فاسو</option>
<option value="Burundi" %%=IIF(@country=='Burundi', "selected", "")=%%>بوروندي</option>
<option value="Cambodia" %%=IIF(@country=='Cambodia', "selected", "")=%%>كمبوديا</option>
<option value="Cameroon" %%=IIF(@country=='Cameroon', "selected", "")=%%>الكاميرون</option>
<option value="Canada" %%=IIF(@country=='Canada', "selected", "")=%%>كندا</option>
<option value="Canary Islands" %%=IIF(@country=='Canary Islands', "selected", "")=%%>جزر الكناري</option>
<option value="Cabo Verde" %%=IIF(@country=='Cabo Verde', "selected", "")=%%>الرأس الأخضر</option>
<option value="Caribbean Netherlands" %%=IIF(@country=='Caribbean Netherlands', "selected", "")=%%>الكاريبي هولندا</option>
<option value="Cayman Islands" %%=IIF(@country=='Cayman Islands', "selected", "")=%%>جزر كايمان</option>
<option value="Central African Republic" %%=IIF(@country=='Central African Republic', selected, "")=%%>جمهورية أفريقيا الوسطى</option>
<option value="Ceuta & Melilla" %%=IIF(@country=='Ceuta & Melilla', selected, "")=%%>سبتة ومليلية</option>
<option value="Chad" %%=IIF(@country=='Chad', "selected", "")=%%>تشاد</option>
<option value="Chile" %%=IIF(@country=='Chile', "selected", "")=%%>تشيلي</option>
<option value="China" %%=IIF(@country=='China', "selected", "")=%%>الصين</option>
<option value="Christmas Island" %%=IIF(@country=='Christmas Island', "selected", "")=%%>جزيرة كريسماس</option>
<option value="Clipperton Island" %%=IIF(@country=='Clipperton Island', "selected", "")=%%>جزيرة كليبرتون</option>
<option value="Cocos (Keeling) Islands" %%=IIF(@country=='Cocos (Keeling) Islands', "selected", "")=%%>جزر كوكوس (كيلينغ)</option>
<option value="Colombia" %%=IIF(@country=='Colombia', "selected", "")=%%>كولومبيا</option>
<option value="Commonwealth of Dominica" %%=IIF(@country=='Commonwealth of Dominica', "selected", "")=%%>دومينيكا</option>
<option value="Comoros" %%=IIF(@country=='Comoros', "selected", "")=%%>جزر القمر</option>
<option value="Congo" %%=IIF(@country=='Congo', "selected", "")=%%>الكونغو</option>
<option value="Cook Islands" %%=IIF(@country=='Cook Islands', "selected", "")=%%>جزر كوك</option>
<option value="Costa Rica" %%=IIF(@country=='Costa Rica', "selected", "")=%%>كوستاريكا</option>
<option value="Cote d'Ivoire" %%=IIF(@country=="Cote d'Ivoire", "selected", "")=%%>كوت ديفوار</option>
<option value="Croatia" %%=IIF(@country=='Croatia', "selected", "")=%%>كرواتيا</option>
<option value="Cuba" %%=IIF(@country=='Cuba', "selected", "")=%%>كوبا</option>
<option value="Curaçao" %%=IIF(@country=='Curaçao', "selected", "")=%%>كوراساو</option>
<option value="Cyprus" %%=IIF(@country=='Cyprus', "selected", "")=%%>قبرص</option>
<option value="Czech Republic" %%=IIF(@country=='Czech Republic', "selected", "")=%%>جمهورية التشيك</option>
<option value="Democratic Republic of the Congo" %%=IIF(@country=='Democratic Republic of the Congo', "selected", "")=%%>جمهورية الكونغو الديمقراطية</option>
<option value="Denmark" %%=IIF(@country=='Denmark', "selected", "")=%%>الدنمارك</option>
<option value="Djibouti" %%=IIF(@country=='Djibouti', "selected", "")=%%>جيبوتي</option>
<option value="Dominican Republic" %%=IIF(@country=='Dominican Republic', "selected", "")=%%>جمهورية الدومينيكان</option>
<option value="Ecuador" %%=IIF(@country=='Ecuador', "selected", "")=%%>الإكوادور</option>
<option value="Egypt" %%=IIF(@country=='Egypt', "selected", "")=%%>مصر</option>
<option value="El Salvador" %%=IIF(@country=='El Salvador', "selected", "")=%%>السلفادور</option>
<option value="Equatorial Guinea" %%=IIF(@country=='Equatorial Guinea', "selected", "")=%%>غينيا الاستوائية</option>
<option value="Eritrea" %%=IIF(@country=='Eritrea', "selected", "")=%%>إريتريا</option>
<option value="Estonia"  %%=IIF(@country=='Estonia', "selected", "")=%%>إستونيا</option>
<option value="Eswatini"  %%=IIF(@country=='Eswatini', "selected", "")=%%>إسواتيني</option>
<option value="Ethiopia" %%=IIF(@country=='Ethiopia', "selected", "")=%%>إثيوبيا</option>
<option value="Falkland Islands" %%=IIF(@country=='Falkland Islands', "selected", "")=%%>جزر فوكلاند</option>
<option value="Faroe Islands" %%=IIF(@country=='Faroe Islands', "selected", "")=%%>جزر فارو</option>
<option value="Fiji" %%=IIF(@country=='Fiji', "selected", "")=%%>فيجي</option>
<option value="Finland" %%=IIF(@country=='Finland', "selected", "")=%%>فنلندا</option>
<option value="France" %%=IIF(@country=='France', "selected", "")=%%>فرنسا</option>
<option value="French Guiana" %%=IIF(@country=='French Guiana', "selected", "")=%%>غويانا الفرنسية</option>
<option value="French Polynesia" %%=IIF(@country=='French Polynesia', "selected", "")=%%>بولينيزيا الفرنسية</option>
<option value="French Southern Territories" %%=IIF(@country=='French Southern Territories', "selected", "")=%%>الأقاليم الجنوبية الفرنسية</option>
<option value="Gabon" %%=IIF(@country=='Gabon', "selected", "")=%%>الغابون</option>
<option value="Gambia" %%=IIF(@country=='Gambia', "selected", "")=%%>غامبيا</option>
<option value="Georgia" %%=IIF(@country=='Georgia', "selected", "")=%%>جورجيا</option>
<option value="Germany" %%=IIF(@country=='Germany', "selected", "")=%%>ألمانيا</option>
<option value="Ghana" %%=IIF(@country=='Ghana', "selected", "")=%%>غانا</option>
<option value="Gibraltar" %%=IIF(@country=='Gibraltar', "selected", "")=%%>جبل طارق</option>
<option value="Greece" %%=IIF(@country=='Greece', "selected", "")=%%>اليونان</option>
<option value="Greenland" %%=IIF(@country=='Greenland', "selected", "")=%%>جرينلاند</option>
<option value="Grenada" %%=IIF(@country=='Grenada', "selected", "")=%%>غرينادا</option>
<option value="Guadeloupe" %%=IIF(@country=='Guadeloupe', "selected", "")=%%>غوادلوب</option>
<option value="Guam"  %%=IIF(@country=='Guam', "selected", "")=%%>غوام</option>
<option value="Guatemala" %%=IIF(@country=='Guatemala', "selected", "")=%%>غواتيمالا</option>
<option value="Guernsey" %%=IIF(@country=='Guernsey', "selected", "")=%%>غيرنزي</option>
<option value="Guinea" %%=IIF(@country=='Guinea', "selected", "")=%%>غينيا</option>
<option value="Guinea-Bissau" %%=IIF(@country=='Guinea-Bissau', "selected", "")=%%>غينيا بيساو</option>
    <option value="Guyana" %%=IIF(@country=='Guyana', "selected", "")=%%>غيانا</option>
    <option value="Haiti" %%=IIF(@country=='Haiti', "selected", "")=%%>هايتي</option>
    <option value="Heard Island and McDonald Islands" %%=IIF(@country=='Heard Island and McDonald Islands', "selected", "")=%%>جزيرة هيرد وجزر ماكدونالد</option>
    <option value="Holy See (Vatican)" %%=IIF(@country=='Holy See (Vatican)', "selected", "")=%%>الفاتيكان</option>
<option value="Honduras" %%=IIF(@country=='Honduras', "selected", "")=%%>هندوراس</option>
<option value="Hong Kong Special Administrative Region" %%=IIF(@country=='Hong Kong Special Administrative Region', "selected", "")=%%>هونغ كونغ</option>
<option value="Hungary" %%=IIF(@country=='Hungary', "selected", "")=%%>المجر</option>
<option value="Iceland" %%=IIF(@country=='Iceland', "selected", "")=%%>أيسلندا</option>
<option value="India"  %%=IIF(@country=='India', "selected", "")=%%>الهند</option>
<option value="Indonesia" %%=IIF(@country=='Indonesia', "selected", "")=%%>إندونيسيا</option>
<option value="Iran (Islamic Republic of)" %%=IIF(@country=='Iran (Islamic Republic of)', "selected", "")=%%>إيران</option>
<option value="Iraq" %%=IIF(@country=='Iraq', "selected", "")=%%>العراق</option>
<option value="Ireland" %%=IIF(@country=='Ireland', "selected", "")=%%>أيرلندا</option>
<option value="Israel" %%=IIF(@country=='Israel', "selected", "")=%%>إسرائيل</option>
<option value="Isle of Man" %%=IIF(@country=='Isle of Man', "selected", "")=%%>جزيرة مان</option>
<option value="Italy" %%=IIF(@country=='Italy', "selected", "")=%%>إيطاليا</option>
<option value="Jamaica" %%=IIF(@country=='Jamaica', "selected", "")=%%>جامايكا</option>
<option value="Japan" %%=IIF(@country=='Japan', "selected", "")=%%>اليابان</option>
<option value="Jersey" %%=IIF(@country=='Jersey', "selected", "")=%%>جيرسي</option>
<option value="Jordan" %%=IIF(@country=='Jordan', "selected", "")=%%>الأردن</option>
<option value="Kazakhstan" %%=IIF(@country=='Kazakhstan', "selected", "")=%%>كازاخستان</option>
<option value="Kenya" %%=IIF(@country=='Kenya', "selected", "")=%%>كينيا</option>
<option value="Kiribati" %%=IIF(@country=='Kiribati', "selected", "")=%%>كيريباتي</option>
<option value="Kosovo" %%=IIF(@country=='Kosovo', "selected", "")=%%>كوسوفو</option>
<option value="Kuwait" %%=IIF(@country=='Kuwait', "selected", "")=%%>الكويت</option>
<option value="Kyrgyzstan" %%=IIF(@country=='Kyrgyzstan', "selected", "")=%%>قيرغيزستان</option>
<option value="Laos People's Democratic Republic" %%=IIF(@country=='Laos People's Democratic Republic', "selected", "")=%%>لاوس</option>
<option value="Latvia" %%=IIF(@country=='Latvia', "selected", "")=%%>لاتفيا</option>
<option value="Latvia Resident" %%=IIF(@country=='Latvia Resident', "selected", "")=%%>مقيم في لاتفيا</option>
<option value="Lebanon" %%=IIF(@country=='Lebanon', "selected", "")=%%>لبنان</option>
<option value="Lesotho" %%=IIF(@country=='Lesotho', "selected", "")=%%>ليسوتو</option>
<option value="Liberia" %%=IIF(@country=='Liberia', "selected", "")=%%>ليبيريا</option>
<option value="Libya" %%=IIF(@country=='Libya', "selected", "")=%%>ليبيا</option>
<option value="Liechtenstein" %%=IIF(@country=='Liechtenstein', "selected", "")=%%>ليختنشتاين</option>
<option value="Lithuania" %%=IIF(@country=='Lithuania', "selected", "")=%%>ليتوانيا</option>
<option value="Luxembourg" %%=IIF(@country=='Luxembourg', "selected", "")=%%>لوكسمبورغ</option>
<option value="Macao" %%=IIF(@country=='Macao', "selected", "")=%%>ماكاو</option>
<option value="Madagascar" %%=IIF(@country=='Madagascar', "selected", "")=%%>مدغشقر</option>
<option value="Malawi" %%=IIF(@country=='Malawi', "selected", "")=%%>مالاوي</option>
<option value="Malaysia" %%=IIF(@country=='Malaysia', "selected", "")=%%>ماليزيا</option>
<option value="Maldives" %%=IIF(@country=='Maldives', "selected", "")=%%>المالديف</option>
<option value="Mali" %%=IIF(@country=='Mali', "selected", "")=%%>مالي</option>
<option value="Malta" %%=IIF(@country=='Malta', "selected", "")=%%>مالطا</option>
<option value="Marshall Islands" %%=IIF(@country=='Marshall Islands', "selected", "")=%%>جزر مارشال</option>
<option value="Martinique" %%=IIF(@country=='Martinique', "selected", "")=%%>مارتينيك</option>
<option value="Mauritania" %%=IIF(@country=='Mauritania', "selected", "")=%%>موريتانيا</option>
<option value="Mauritius" %%=IIF(@country=='Mauritius', "selected", "")=%%>موريشيوس</option>
<option value="Mayotte" %%=IIF(@country=='Mayotte', "selected", "")=%%>مايوت</option>
<option value="Mexico" %%=IIF(@country=='Mexico', "selected", "")=%%>المكسيك</option>
<option value="Micronesia (Federated States of)" %%=IIF(@country=='Micronesia (Federated States of)', "selected", "")=%%>ميكرونيزيا</option>
<option value="Monaco" %%=IIF(@country=='Monaco', "selected", "")=%%>موناكو</option>
<option value="Mongolia" %%=IIF(@country=='Mongolia', "selected", "")=%%>منغوليا</option>
<option value="Montenegro" %%=IIF(@country=='Montenegro', "selected", "")=%%>الجبل الأسود</option>
<option value="Montserrat" %%=IIF(@country=='Montserrat', "selected", "")=%%>مونتسرات</option>
<option value="Morocco" %%=IIF(@country=='Morocco', "selected", "")=%%>المغرب</option>
<option value="Mozambique" %%=IIF(@country=='Mozambique', "selected", "")=%%>موزمبيق</option>
<option value="Myanmar" %%=IIF(@country=='Myanmar', "selected", "")=%%>ميانمار</option>
<option value="Namibia" %%=IIF(@country=='Namibia', "selected", "")=%%>ناميبيا</option>
<option value="Nauru" %%=IIF(@country=='Nauru', "selected", "")=%%>ناورو</option>
<option value="Nepal" %%=IIF(@country=='Nepal', "selected", "")=%%>نيبال</option>
<option value="Netherlands Antilles" %%=IIF(@country=='Netherlands Antilles', "selected", "")=%%>جزر الأنتيل الهولندية</option>
<option value="Netherlands" %%=IIF(@country=='Netherlands', "selected", "")=%%>هولندا</option>
<option value="New Caledonia" %%=IIF(@country=='New Caledonia', "selected", "")=%%>كاليدونيا الجديدة</option>
<option value="New Zealand" %%=IIF(@country=='New Zealand', "selected", "")=%%>نيوزيلندا</option>
<option value="Nicaragua" %%=IIF(@country=='Nicaragua', "selected", "")=%%>نيكاراغوا</option>
<option value="Niger" %%=IIF(@country=='Niger', "selected", "")=%%>النيجر</option>
<option value="Nigeria" %%=IIF(@country=='Nigeria', "selected", "")=%%>نيجيريا</option>
<option value="Niue" %%=IIF(@country=='Niue', "selected", "")=%%>نيوي</option>
<option value="Norfolk Island" %%=IIF(@country=='Norfolk Island', "selected", "")=%%>جزيرة نورفولك</option>
<option value="North Korea" %%=IIF(@country=='North Korea', "selected", "")=%%>كوريا الشمالية</option>
<option value="Northern Mariana Islands" %%=IIF(@country=='Northern Mariana Islands', "selected", "")=%%>جزر ماريانا الشمالية</option>
<option value="Norway" %%=IIF(@country=='Norway', "selected", "")=%%>النرويج</option>
<option value="Oman" %%=IIF(@country=='Oman', "selected", "")=%%>عمان</option>
<option value="Pakistan" %%=IIF(@country=='Pakistan', "selected", "")=%%>باكستان</option>
<option value="Palau" %%=IIF(@country=='Palau', "selected", "")=%%>بالاو</option>
<option value="Panama" %%=IIF(@country=='Panama', "selected", "")=%%>بنما</option>
<option value="Papua new Guinea" %%=IIF(@country=='Papua new Guinea', "selected", "")=%%>بابوا غينيا الجديدة</option>
<option value="Paraguay" %%=IIF(@country=='Paraguay', "selected", "")=%%>باراغواي</option>
<option value="Peru" %%=IIF(@country=='Peru', "selected", "")=%%>بيرو</option>
<option value="Philippines" %%=IIF(@country=='Philippines', "selected", "")=%%>الفلبين</option>
<option value="Pitcairn" %%=IIF(@country=='Pitcairn', "selected", "")=%%>بيتكيرن</option>
<option value="Poland" %%=IIF(@country=='Poland', "selected", "")=%%>بولندا</option>
<option value="Portugal" %%=IIF(@country=='Portugal', "selected", "")=%%>البرتغال</option>
<option value="Puerto Rico" %%=IIF(@country=='Puerto Rico', "selected", "")=%%>بورتوريكو</option>
<option value="Qatar" %%=IIF(@country=='Qatar', "selected", "")=%%>قطر</option>
<option value="Republic of Korea" %%=IIF(@country=='Republic of Korea', "selected", "")=%%>جمهورية كوريا</option>
<option value="Republic of Macedonia" %%=IIF(@country=='Republic of Macedonia', "selected", "")=%%>جمهورية مقدونيا</option>
<option value="Republic of Moldova" %%=IIF(@country=='Republic of Moldova', "selected", "")=%%>جمهورية مولدوفا</option>
<option value="Republic of Somaliland" %%=IIF(@country=='Republic of Somaliland', "selected", "")=%%>جمهورية أرض الصومال</option>
<option value="Reunion" %%=IIF(@country=='Reunion', "selected", "")=%%>ريونيون</option>
<option value="Romania" %%=IIF(@country=='Romania', "selected", "")=%%>رومانيا</option>
<option value="Russian Federation" %%=IIF(@country=='Russian Federation', "selected", "")=%%>الاتحاد الروسي</option>
<option value="Rwanda" %%=IIF(@country=='Rwanda', "selected", "")=%%>رواندا</option>
<option value="Saint Helena" %%=IIF(@country=='Saint Helena', "selected", "")=%%>سانت هيلينا</option>
<option value="Saint Kitts And Nevis" %%=IIF(@country=='Saint Kitts And Nevis', "selected", "")=%%>سانت كيتس ونيفيس</option>
<option value="Saint Lucia" %%=IIF(@country=='Saint Lucia', "selected", "")=%%>سانت لوسيا</option>
<option value="Saint Pierre and Miquelon" %%=IIF(@country=='Saint Pierre and Miquelon', "selected", "")=%%>سانت بيير وميكلون</option>
<option value="Saint Vincent And The Grenadines" %%=IIF(@country=='Saint Vincent And The Grenadines', "selected", "")=%%>سانت فنسنت والغرينادين</option>
<option value="Saint Barthelemy" %%=IIF(@country=='Saint Barthelemy', "selected", "")=%%>سانت بارتيليمي</option>
<option value="Saint Martin (French part)" %%=IIF(@country=='Saint Martin (French part)', "selected", "")=%%>سانت مارتن (الجزء الفرنسي)</option>
<option value="Samoa" %%=IIF(@country=='Samoa', "selected", "")=%%>ساموا</option>
<option value="San Marino" %%=IIF(@country=='San Marino', "selected", "")=%%>سان مارينو</option>
<option value="Sao Tome and Principe" %%=IIF(@country=='Sao Tome and Principe', "selected", "")=%%>ساو تومي وبرينسيبي</option>
<option value="Saudi Arabia" %%=IIF(@country=='Saudi Arabia', "selected", "")=%%>المملكة العربية السعودية</option>
<option value="Senegal" %%=IIF(@country=='Senegal', "selected", "")=%%>السنغال</option>
<option value="Serbia" %%=IIF(@country=='Serbia', "selected", "")=%%>صربيا</option>
<option value="Seychelles" %%=IIF(@country=='Seychelles', "selected", "")=%%>سيشل</option>
<option value="Sierra Leone" %%=IIF(@country=='Sierra Leone', "selected", "")=%%>سيراليون</option>
<option value="Singapore" %%=IIF(@country=='Singapore', "selected", "")=%%>سنغافورة</option>
<option value="Sint Maarten" %%=IIF(@country=='Sint Maarten', "selected", "")=%%>سينت مارتن</option>
<option value="Slovakia" %%=IIF(@country=='Slovakia', "selected", "")=%%>سلوفاكيا</option>
<option value="Slovenia" %%=IIF(@country=='Slovenia', "selected", "")=%%>سلوفينيا</option>
<option value="Solomon Islands" %%=IIF(@country=='Solomon Islands', "selected", "")=%%>جزر سليمان</option>
<option value="Somalia" %%=IIF(@country=='Somalia', "selected", "")=%%>الصومال</option>
<option value="South Africa" %%=IIF(@country=='South Africa', 'selected', "")=%%>جنوب أفريقيا</option>
<option value="South Georgia and the South Sandwich Islands" %%=IIF(@country=='South Georgia and the South Sandwich Islands', "selected", "")=%%>جورجيا الجنوبية وجزر ساندويتش الجنوبية</option>
<option value="South Sudan" %%=IIF(@country=='South Sudan', "selected", "")=%%>جنوب السودان</option>
<option value="Spain" %%=IIF(@country=='Spain', "selected", "")=%%>إسبانيا</option>
<option value="Sri Lanka" %%=IIF(@country=='Sri Lanka', "selected", "")=%%>سريلانكا</option>
<option value="State of Palestine" %%=IIF(@country=='State of Palestine', "selected", "")=%%>دولة فلسطين</option>
<option value="Sudan" %%=IIF(@country=='Sudan', "selected", "")=%%>السودان</option>
<option value="Suriname" %%=IIF(@country=='Suriname', "selected", "")=%%>سورينام</option>
<option value="Svalbard And Jan Mayen" %%=IIF(@country=='Svalbard And Jan Mayen', "selected", "")=%%>سفالبارد ويان ماين</option>
<option value="Swaziland" %%=IIF(@country=='Swaziland', "selected", "")=%%>سوازيلاند</option>
<option value="Sweden" %%=IIF(@country=='Sweden', "selected", "")=%%>السويد</option>
<option value="Switzerland" %%=IIF(@country=='Switzerland', "selected", "")=%%>سويسرا</option>
<option value="Syrian Arab Republic" %%=IIF(@country=='Syrian Arab Republic', "selected", "")=%%>الجمهورية العربية السورية</option>
<option value="Taiwan" %%=IIF(@country=='Taiwan', "selected", "")=%%>تايوان</option>
<option value="Tajikistan" %%=IIF(@country=='Tajikistan', "selected", "")=%%>طاجيكستان</option>
<option value="Thailand" %%=IIF(@country=='Thailand', "selected", "")=%%>تايلاند</option>
<option value="Timor-Leste" %%=IIF(@country=='Timor-Leste', "selected", "")=%%>تيمور الشرقية</option>
<option value="Togo" %%=IIF(@country=='Togo', "selected", "")=%%>توغو</option>
<option value="Tokelau" %%=IIF(@country=='Tokelau', "selected", "")=%%>توكلاو</option>
<option value="Tonga" %%=IIF(@country=='Tonga', "selected", "")=%%>تونغا</option>
<option value="Trinidad And Tobago" %%=IIF(@country=='Trinidad And Tobago', "selected", "")=%%>ترينيداد وتوباغو</option>
<option value="Tunisia" %%=IIF(@country=='Tunisia', "selected", "")=%%>تونس</option>
<option value="Turkey" %%=IIF(@country=='Turkey', "selected", "")=%%>تركيا</option>
<option value="Turkmenistan" %%=IIF(@country=='Turkmenistan', "selected", "")=%%>تركمانستان</option>
<option value="Turks And Caicos Islands" %%=IIF(@country=='Turks And Caicos Islands', "selected", "")=%%>جزر تركس وكايكوس</option>
<option value="Tuvalu" %%=IIF(@country=='Tuvalu', "selected", "")=%%>توفالو</option>
<option value="Uganda" %%=IIF(@country=='Uganda', "selected", "")=%%>أوغندا</option>
<option value="Ukraine" %%=IIF(@country=='Ukraine', "selected", "")=%%>أوكرانيا</option>
<option value="United Arab Emirates" %%=IIF(@country=='United Arab Emirates', "selected", "")=%%>الإمارات العربية المتحدة</option>
<option value="United Kingdom (UK)" %%=IIF(@country=='United Kingdom (UK)', "selected", "")=%%>المملكة المتحدة (بريطانيا)</option>
<option value="United Republic of Tanzania" %%=IIF(@country=='United Republic of Tanzania', "selected", "")=%%>جمهورية تنزانيا المتحدة</option>
<option value="United States of America" %%=IIF(@country=='United States of America', "selected", "")=%%>الولايات المتحدة الأمريكية</option>
<option value="United States Minor Outlying Islands" %%=IIF(@country=='United States Minor Outlying Islands', "selected", "")=%%>جزر الولايات المتحدة الصغيرة النائية</option>
<option value="Uruguay" %%=IIF(@country=='Uruguay', "selected", "")=%%>أوروغواي</option>
<option value="Uzbekistan" %%=IIF(@country=='Uzbekistan', "selected", "")=%%>أوزبكستان</option>
<option value="Vanuatu" %%=IIF(@country=='Vanuatu', "selected", "")=%%>فانواتو</option>
<option value="Venezuela" %%=IIF(@country=='Venezuela', "selected", "")=%%>فنزويلا</option>
<option value="Viet Nam" %%=IIF(@country=='Viet Nam', "selected", "")=%%>فيتنام</option>
<option value="Virgin Islands, British" %%=IIF(Replace(@country, ",", "") == 'Virgin Islands British', "selected", "")=%%>جزر فيرجن البريطانية</option>
<option value="Virgin Islands, U.S." %%=IIF(Replace(@country, ",", "") == 'Virgin Islands U.S.', "selected", "")=%%>جزر فيرجن الأمريكية</option>
<option value="Wallis And Futuna" %%=IIF(@country=='Wallis And Futuna', "selected", "")=%%>واليس وفوتونا</option>
<option value="Western Sahara" %%=IIF(@country=='Western Sahara', "selected", "")=%%>الصحراء الغربية</option>
<option value="Yemen" %%=IIF(@country=='Yemen', "selected", "")=%%>اليمن</option>
<option value="Zambia" %%=IIF(@country=='Zambia', "selected", "")=%%>زامبيا</option>
<option value="Zimbabwe" %%=IIF(@country=='Zimbabwe', "selected", "")=%%>زمبابوي</option>
<option value="Others" %%=IIF(@country=='Others', "selected", "")=%%>آخرون</option>

                     </select>
                   
                          </div>
                      </div>
                  </div>

                 <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group">
                      <label for="">المدينة (المقيمين في دولة الإمارات العربية المتحدة فقط)</label>
                        <div class="select-wrapper hide-icon custom-">
                        <select class="form-control" name="city" id="city">
                               <option value="" %%=IIF(@city=='', "selected", "")=%% selected>اختر المدينة</option>
                               <option value="Ajman" %%=IIF(@city=='Ajman', "selected", "")=%%>عجمان</option>
                               <option value="Abu Dhabi" %%=IIF(@city=='Abu Dhabi', "selected", "")=%%>أبو ظبي</option>
                               <option value="Fujairah" %%=IIF(@city=='Fujairah', "selected", "")=%%>الفجيرة</option>
                               <option value="Dubai" %%=IIF(@city=='Dubai', "selected", "")=%%>دبي</option>
                               <option value="Ras Al Khaimah" %%=IIF(@city=='Ras Al Khaimah', "selected", "")=%%>رأس الخيمة</option>
                               <option value="Sharjah" %%=IIF(@city=='Sharjah', "selected", "")=%%>الشارقة</option>
                               <option value="Umm AL Quwain" %%=IIF(@city=='Umm AL Quwain', "selected", "")=%%>أم القيوين</option>
                            </select>
                         
                        </div>
                    </div>
                </div>
                
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group" data-aos="fade-up"
                        data-aos-anchor-placement="bottom-bottom">
                        <label for="">الجنسية (المقيمين في دولة الإمارات العربية المتحدة فقط)</label>
                        <div class="select-wrapper hide-icon">
                        <select class="form-control" name="profileNationality" id="nationality">
                            <option value="">اختر الجنسية</option>
                            <option value="Afghanistan" %%=IIF(@nationality=='Afghanistan', "selected", "")=%% >أفغانستان</option>
                            <option value="Aland Islands" %%=IIF(@nationality=='Aland Islands', 'selected', "")=%%>جزر آلاند</option>
                            <option value="Albania" %%=IIF(@nationality=='Albania', "selected", "")=%%>ألبانيا</option>
                            <option value="Algeria" %%=IIF(@nationality=='Algeria', "selected", "")=%%>الجزائر</option>
                            <option value="American Samoa" %%=IIF(@nationality=='American Samoa', "selected", "")=%%>ساموا الأمريكية</option>
                            <option value="Andorra" %%=IIF(@nationality=='Andorra', "selected", "")=%%>أندورا</option>
                            <option value="Angola" %%=IIF(@nationality=='Angola', "selected", "")=%%>أنغولا</option>
                            <option value="Anguilla" %%=IIF(@nationality=='Anguilla', "selected", "")=%%>أنغيلا</option>
                            <option value="Antarctica" %%=IIF(@nationality=='Antarctica', "selected", "")=%%>أنتاركتيكا</option>
                            <option value="Antigua And Barbuda" %%=IIF(@nationality=='Antigua And Barbuda', "selected", "")=%%>أنتيغوا وباربودا</option>
                            <option value="Argentina" %%=IIF(@nationality=='Argentina', "selected", "")=%%>الأرجنتين</option>
                            <option value="Armenia" %%=IIF(@nationality=='Armenia', "selected", "")=%%>أرمينيا</option>
                            <option value="Aruba" %%=IIF(@nationality=='Aruba', "selected", "")=%%>أروبا</option>
                            <option value="Australia" %%=IIF(@nationality=='Australia', "selected", "")=%%>أستراليا</option>
                            <option value="Austria" %%=IIF(@nationality=='Austria', "selected", "")=%%>النمسا</option>
                            <option value="Azerbaijan" %%=IIF(@nationality=='Azerbaijan', "selected", "")=%%>أذربيجان</option>
                            <option value="Bahamas" %%=IIF(@nationality=='Bahamas', "selected", "")=%%>الباهاما</option>
                            <option value="Bahrain" %%=IIF(@nationality=='Bahrain', "selected", "")=%%>البحرين</option>
                            <option value="Bangladesh" %%=IIF(@nationality=='Bangladesh', "selected", "")=%%>بنغلاديش</option>
                            <option value="Barbados" %%=IIF(@nationality=='Barbados', "selected", "")=%%>بربادوس</option>
                            <option value="Belarus" %%=IIF(@nationality=='Belarus', "selected", "")=%%>بيلاروسيا</option>
                            <option value="Belgium" %%=IIF(@nationality=='Belgium', "selected", "")=%%>بلجيكا</option>
                            <option value="Belize" %%=IIF(@nationality=='Belize', "selected", "")=%%>بليز</option>
                            <option value="Benin" %%=IIF(@nationality=='Benin', "selected", "")=%%>بنين</option>
                            <option value="Bermuda" %%=IIF(@nationality=='Bermuda', "selected", "")=%%>برمودا</option>
                            <option value="Bhutan" %%=IIF(@nationality=='Bhutan', "selected", "")=%%>بوتان</option>
                            <option value="Bolivia" %%=IIF(@nationality=='Bolivia', "selected", "")=%%>بوليفيا</option>
                            <option value="Bosnia and Herzegovina" %%=IIF(@nationality=='Bosnia and Herzegovina', "selected", "")=%%>البوسنة والهرسك</option>
                            <option value="Botswana"  %%=IIF(@nationality=='Botswana', "selected", "")=%%>بوتسوانا</option>
                            <option value="Bouvet Island" %%=IIF(@nationality=='Bouvet Island', "selected", "")=%%>جزيرة بوفيه</option>
                            <option value="Brazil" %%=IIF(@nationality=='Brazil', "selected", "")=%%>البرازيل</option>
                            <option value="British Indian Ocean Territory" %%=IIF(@nationality=='British Indian Ocean Territory', "selected", "")=%%>إقليم المحيط الهندي البريطاني</option>
                            <option value="Brunei Darussalam" %%=IIF(@nationality=='Brunei Darussalam', "selected", "")=%%>بروناي دار السلام</option>
                            <option value="Bulgaria" %%=IIF(@nationality=='Bulgaria', "selected", "")=%%>بلغاريا</option>
                            <option value="Burkina Faso" %%=IIF(@nationality=='Burkina Faso', "selected", "")=%%>بوركينا فاسو</option>
                            <option value="Burundi" %%=IIF(@nationality=='Burundi', "selected", "")=%%>بوروندي</option>
                            <option value="Cambodia" %%=IIF(@nationality=='Cambodia', "selected", "")=%%>كمبوديا</option>
                            <option value="Cameroon" %%=IIF(@nationality=='Cameroon', "selected", "")=%%>الكاميرون</option>
                            <option value="Canada" %%=IIF(@nationality=='Canada', "selected", "")=%%>كندا</option>
                            <option value="Canary Islands" %%=IIF(@nationality=='Canary Islands', "selected", "")=%%>جزر الكناري</option>
                            <option value="Cabo Verde" %%=IIF(@nationality=='Cabo Verde', "selected", "")=%%>الرأس الأخضر</option>
                            <option value="Caribbean Netherlands" %%=IIF(@nationality=='Caribbean Netherlands', "selected", "")=%%>الكاريبي هولندا</option>
                            <option value="Cayman Islands" %%=IIF(@nationality=='Cayman Islands', "selected", "")=%%>جزر كايمان</option>
                            <option value="Central African Republic" %%=IIF(@nationality=='Central African Republic', selected, "")=%%>جمهورية أفريقيا الوسطى</option>
                            <option value="Ceuta & Melilla" %%=IIF(@nationality=='Ceuta & Melilla', selected, "")=%%>سبتة ومليلية</option>
                            <option value="Chad" %%=IIF(@nationality=='Chad', "selected", "")=%%>تشاد</option>
                            <option value="Chile" %%=IIF(@nationality=='Chile', "selected", "")=%%>تشيلي</option>
                            <option value="China" %%=IIF(@nationality=='China', "selected", "")=%%>الصين</option>
                            <option value="Christmas Island" %%=IIF(@nationality=='Christmas Island', "selected", "")=%%>جزيرة كريسماس</option>
                            <option value="Clipperton Island" %%=IIF(@nationality=='Clipperton Island', "selected", "")=%%>جزيرة كليبرتون</option>
                            <option value="Cocos (Keeling) Islands" %%=IIF(@nationality=='Cocos (Keeling) Islands', "selected", "")=%%>جزر كوكوس (كيلينغ)</option>
                            <option value="Colombia" %%=IIF(@nationality=='Colombia', "selected", "")=%%>كولومبيا</option>
                            <option value="Commonwealth of Dominica" %%=IIF(@nationality=='Commonwealth of Dominica', "selected", "")=%%>دومينيكا</option>
                            <option value="Comoros" %%=IIF(@nationality=='Comoros', "selected", "")=%%>جزر القمر</option>
                            <option value="Congo" %%=IIF(@nationality=='Congo', "selected", "")=%%>الكونغو</option>
                            <option value="Cook Islands" %%=IIF(@nationality=='Cook Islands', "selected", "")=%%>جزر كوك</option>
                            <option value="Costa Rica" %%=IIF(@nationality=='Costa Rica', "selected", "")=%%>كوستاريكا</option>
                            <option value="Cote d'Ivoire" %%=IIF(@nationality=="Cote d'Ivoire", "selected", "")=%%>كوت ديفوار</option>
                            <option value="Croatia" %%=IIF(@nationality=='Croatia', "selected", "")=%%>كرواتيا</option>
                            <option value="Cuba" %%=IIF(@nationality=='Cuba', "selected", "")=%%>كوبا</option>
                            <option value="Curaçao" %%=IIF(@nationality=='Curaçao', "selected", "")=%%>كوراساو</option>
                            <option value="Cyprus" %%=IIF(@nationality=='Cyprus', "selected", "")=%%>قبرص</option>
                            <option value="Czech Republic" %%=IIF(@nationality=='Czech Republic', "selected", "")=%%>جمهورية التشيك</option>
                            <option value="Democratic Republic of the Congo" %%=IIF(@nationality=='Democratic Republic of the Congo', "selected", "")=%%>جمهورية الكونغو الديمقراطية</option>
                            <option value="Denmark" %%=IIF(@nationality=='Denmark', "selected", "")=%%>الدنمارك</option>
                            <option value="Djibouti" %%=IIF(@nationality=='Djibouti', "selected", "")=%%>جيبوتي</option>
                            <option value="Dominican Republic" %%=IIF(@nationality=='Dominican Republic', "selected", "")=%%>جمهورية الدومينيكان</option>
                            <option value="Ecuador" %%=IIF(@nationality=='Ecuador', "selected", "")=%%>الإكوادور</option>
                            <option value="Egypt" %%=IIF(@nationality=='Egypt', "selected", "")=%%>مصر</option>
                            <option value="El Salvador" %%=IIF(@nationality=='El Salvador', "selected", "")=%%>السلفادور</option>
                            <option value="Equatorial Guinea" %%=IIF(@nationality=='Equatorial Guinea', "selected", "")=%%>غينيا الاستوائية</option>
                            <option value="Eritrea" %%=IIF(@nationality=='Eritrea', "selected", "")=%%>إريتريا</option>
                            <option value="Estonia"  %%=IIF(@nationality=='Estonia', "selected", "")=%%>إستونيا</option>
                            <option value="Eswatini"  %%=IIF(@nationality=='Eswatini', "selected", "")=%%>إسواتيني</option>
                            <option value="Ethiopia" %%=IIF(@nationality=='Ethiopia', "selected", "")=%%>إثيوبيا</option>
                            <option value="Falkland Islands" %%=IIF(@nationality=='Falkland Islands', "selected", "")=%%>جزر فوكلاند</option>
                            <option value="Faroe Islands" %%=IIF(@nationality=='Faroe Islands', "selected", "")=%%>جزر فارو</option>
                            <option value="Fiji" %%=IIF(@nationality=='Fiji', "selected", "")=%%>فيجي</option>
                            <option value="Finland" %%=IIF(@nationality=='Finland', "selected", "")=%%>فنلندا</option>
                            <option value="France" %%=IIF(@nationality=='France', "selected", "")=%%>فرنسا</option>
                            <option value="French Guiana" %%=IIF(@nationality=='French Guiana', "selected", "")=%%>غويانا الفرنسية</option>
                            <option value="French Polynesia" %%=IIF(@nationality=='French Polynesia', "selected", "")=%%>بولينيزيا الفرنسية</option>
                            <option value="French Southern Territories" %%=IIF(@nationality=='French Southern Territories', "selected", "")=%%>الأقاليم الجنوبية الفرنسية</option>
                            <option value="Gabon" %%=IIF(@nationality=='Gabon', "selected", "")=%%>الغابون</option>
                            <option value="Gambia" %%=IIF(@nationality=='Gambia', "selected", "")=%%>غامبيا</option>
                            <option value="Georgia" %%=IIF(@nationality=='Georgia', "selected", "")=%%>جورجيا</option>
                            <option value="Germany" %%=IIF(@nationality=='Germany', "selected", "")=%%>ألمانيا</option>
                            <option value="Ghana" %%=IIF(@nationality=='Ghana', "selected", "")=%%>غانا</option>
                            <option value="Gibraltar" %%=IIF(@nationality=='Gibraltar', "selected", "")=%%>جبل طارق</option>
                            <option value="Greece" %%=IIF(@nationality=='Greece', "selected", "")=%%>اليونان</option>
                            <option value="Greenland" %%=IIF(@nationality=='Greenland', "selected", "")=%%>جرينلاند</option>
                            <option value="Grenada" %%=IIF(@nationality=='Grenada', "selected", "")=%%>غرينادا</option>
                            <option value="Guadeloupe" %%=IIF(@nationality=='Guadeloupe', "selected", "")=%%>غوادلوب</option>
                            <option value="Guam"  %%=IIF(@nationality=='Guam', "selected", "")=%%>غوام</option>
                            <option value="Guatemala" %%=IIF(@nationality=='Guatemala', "selected", "")=%%>غواتيمالا</option>
                            <option value="Guernsey" %%=IIF(@nationality=='Guernsey', "selected", "")=%%>غيرنزي</option>
                            <option value="Guinea" %%=IIF(@nationality=='Guinea', "selected", "")=%%>غينيا</option>
                            <option value="Guinea-Bissau" %%=IIF(@nationality=='Guinea-Bissau', "selected", "")=%%>غينيا بيساو</option>
                                <option value="Guyana" %%=IIF(@nationality=='Guyana', "selected", "")=%%>غيانا</option>
                                <option value="Haiti" %%=IIF(@nationality=='Haiti', "selected", "")=%%>هايتي</option>
                                <option value="Heard Island and McDonald Islands" %%=IIF(@nationality=='Heard Island and McDonald Islands', "selected", "")=%%>جزيرة هيرد وجزر ماكدونالد</option>
                                <option value="Holy See (Vatican)" %%=IIF(@nationality=='Holy See (Vatican)', "selected", "")=%%>الفاتيكان</option>
                            <option value="Honduras" %%=IIF(@nationality=='Honduras', "selected", "")=%%>هندوراس</option>
                            <option value="Hong Kong Special Administrative Region" %%=IIF(@nationality=='Hong Kong Special Administrative Region', "selected", "")=%%>هونغ كونغ</option>
                            <option value="Hungary" %%=IIF(@nationality=='Hungary', "selected", "")=%%>المجر</option>
                            <option value="Iceland" %%=IIF(@nationality=='Iceland', "selected", "")=%%>أيسلندا</option>
                            <option value="India"  %%=IIF(@nationality=='India', "selected", "")=%%>الهند</option>
                            <option value="Indonesia" %%=IIF(@nationality=='Indonesia', "selected", "")=%%>إندونيسيا</option>
                            <option value="Iran (Islamic Republic of)" %%=IIF(@nationality=='Iran (Islamic Republic of)', "selected", "")=%%>إيران</option>
                            <option value="Iraq" %%=IIF(@nationality=='Iraq', "selected", "")=%%>العراق</option>
                            <option value="Ireland" %%=IIF(@nationality=='Ireland', "selected", "")=%%>أيرلندا</option>
                            <option value="Israel" %%=IIF(@nationality=='Israel', "selected", "")=%%>إسرائيل</option>
                            <option value="Isle of Man" %%=IIF(@nationality=='Isle of Man', "selected", "")=%%>جزيرة مان</option>
                            <option value="Italy" %%=IIF(@nationality=='Italy', "selected", "")=%%>إيطاليا</option>
                            <option value="Jamaica" %%=IIF(@nationality=='Jamaica', "selected", "")=%%>جامايكا</option>
                            <option value="Japan" %%=IIF(@nationality=='Japan', "selected", "")=%%>اليابان</option>
                            <option value="Jersey" %%=IIF(@nationality=='Jersey', "selected", "")=%%>جيرسي</option>
                            <option value="Jordan" %%=IIF(@nationality=='Jordan', "selected", "")=%%>الأردن</option>
                            <option value="Kazakhstan" %%=IIF(@nationality=='Kazakhstan', "selected", "")=%%>كازاخستان</option>
                            <option value="Kenya" %%=IIF(@nationality=='Kenya', "selected", "")=%%>كينيا</option>
                            <option value="Kiribati" %%=IIF(@nationality=='Kiribati', "selected", "")=%%>كيريباتي</option>
                            <option value="Kosovo" %%=IIF(@nationality=='Kosovo', "selected", "")=%%>كوسوفو</option>
                            <option value="Kuwait" %%=IIF(@nationality=='Kuwait', "selected", "")=%%>الكويت</option>
                            <option value="Kyrgyzstan" %%=IIF(@nationality=='Kyrgyzstan', "selected", "")=%%>قيرغيزستان</option>
                            <option value="Laos People's Democratic Republic" %%=IIF(@nationality=='Laos People's Democratic Republic', "selected", "")=%%>لاوس</option>
                            <option value="Latvia" %%=IIF(@nationality=='Latvia', "selected", "")=%%>لاتفيا</option>
                            <option value="Latvia Resident" %%=IIF(@nationality=='Latvia Resident', "selected", "")=%%>مقيم في لاتفيا</option>
                            <option value="Lebanon" %%=IIF(@nationality=='Lebanon', "selected", "")=%%>لبنان</option>
                            <option value="Lesotho" %%=IIF(@nationality=='Lesotho', "selected", "")=%%>ليسوتو</option>
                            <option value="Liberia" %%=IIF(@nationality=='Liberia', "selected", "")=%%>ليبيريا</option>
                            <option value="Libya" %%=IIF(@nationality=='Libya', "selected", "")=%%>ليبيا</option>
                            <option value="Liechtenstein" %%=IIF(@nationality=='Liechtenstein', "selected", "")=%%>ليختنشتاين</option>
                            <option value="Lithuania" %%=IIF(@nationality=='Lithuania', "selected", "")=%%>ليتوانيا</option>
                            <option value="Luxembourg" %%=IIF(@nationality=='Luxembourg', "selected", "")=%%>لوكسمبورغ</option>
                            <option value="Macao" %%=IIF(@nationality=='Macao', "selected", "")=%%>ماكاو</option>
                            <option value="Madagascar" %%=IIF(@nationality=='Madagascar', "selected", "")=%%>مدغشقر</option>
                            <option value="Malawi" %%=IIF(@nationality=='Malawi', "selected", "")=%%>مالاوي</option>
                            <option value="Malaysia" %%=IIF(@nationality=='Malaysia', "selected", "")=%%>ماليزيا</option>
                            <option value="Maldives" %%=IIF(@nationality=='Maldives', "selected", "")=%%>المالديف</option>
                            <option value="Mali" %%=IIF(@nationality=='Mali', "selected", "")=%%>مالي</option>
                            <option value="Malta" %%=IIF(@nationality=='Malta', "selected", "")=%%>مالطا</option>
                            <option value="Marshall Islands" %%=IIF(@nationality=='Marshall Islands', "selected", "")=%%>جزر مارشال</option>
                            <option value="Martinique" %%=IIF(@nationality=='Martinique', "selected", "")=%%>مارتينيك</option>
                            <option value="Mauritania" %%=IIF(@nationality=='Mauritania', "selected", "")=%%>موريتانيا</option>
                            <option value="Mauritius" %%=IIF(@nationality=='Mauritius', "selected", "")=%%>موريشيوس</option>
                            <option value="Mayotte" %%=IIF(@nationality=='Mayotte', "selected", "")=%%>مايوت</option>
                            <option value="Mexico" %%=IIF(@nationality=='Mexico', "selected", "")=%%>المكسيك</option>
                            <option value="Micronesia (Federated States of)" %%=IIF(@nationality=='Micronesia (Federated States of)', "selected", "")=%%>ميكرونيزيا</option>
                            <option value="Monaco" %%=IIF(@nationality=='Monaco', "selected", "")=%%>موناكو</option>
                            <option value="Mongolia" %%=IIF(@nationality=='Mongolia', "selected", "")=%%>منغوليا</option>
                            <option value="Montenegro" %%=IIF(@nationality=='Montenegro', "selected", "")=%%>الجبل الأسود</option>
                            <option value="Montserrat" %%=IIF(@nationality=='Montserrat', "selected", "")=%%>مونتسرات</option>
                            <option value="Morocco" %%=IIF(@nationality=='Morocco', "selected", "")=%%>المغرب</option>
                            <option value="Mozambique" %%=IIF(@nationality=='Mozambique', "selected", "")=%%>موزمبيق</option>
                            <option value="Myanmar" %%=IIF(@nationality=='Myanmar', "selected", "")=%%>ميانمار</option>
                            <option value="Namibia" %%=IIF(@nationality=='Namibia', "selected", "")=%%>ناميبيا</option>
                            <option value="Nauru" %%=IIF(@nationality=='Nauru', "selected", "")=%%>ناورو</option>
                            <option value="Nepal" %%=IIF(@nationality=='Nepal', "selected", "")=%%>نيبال</option>
                            <option value="Netherlands Antilles" %%=IIF(@nationality=='Netherlands Antilles', "selected", "")=%%>جزر الأنتيل الهولندية</option>
                            <option value="Netherlands" %%=IIF(@nationality=='Netherlands', "selected", "")=%%>هولندا</option>
                            <option value="New Caledonia" %%=IIF(@nationality=='New Caledonia', "selected", "")=%%>كاليدونيا الجديدة</option>
                            <option value="New Zealand" %%=IIF(@nationality=='New Zealand', "selected", "")=%%>نيوزيلندا</option>
                            <option value="Nicaragua" %%=IIF(@nationality=='Nicaragua', "selected", "")=%%>نيكاراغوا</option>
                            <option value="Niger" %%=IIF(@nationality=='Niger', "selected", "")=%%>النيجر</option>
                            <option value="Nigeria" %%=IIF(@nationality=='Nigeria', "selected", "")=%%>نيجيريا</option>
                            <option value="Niue" %%=IIF(@nationality=='Niue', "selected", "")=%%>نيوي</option>
                            <option value="Norfolk Island" %%=IIF(@nationality=='Norfolk Island', "selected", "")=%%>جزيرة نورفولك</option>
                            <option value="North Korea" %%=IIF(@nationality=='North Korea', "selected", "")=%%>كوريا الشمالية</option>
                            <option value="Northern Mariana Islands" %%=IIF(@nationality=='Northern Mariana Islands', "selected", "")=%%>جزر ماريانا الشمالية</option>
                            <option value="Norway" %%=IIF(@nationality=='Norway', "selected", "")=%%>النرويج</option>
                            <option value="Oman" %%=IIF(@nationality=='Oman', "selected", "")=%%>عمان</option>
                            <option value="Pakistan" %%=IIF(@nationality=='Pakistan', "selected", "")=%%>باكستان</option>
                            <option value="Palau" %%=IIF(@nationality=='Palau', "selected", "")=%%>بالاو</option>
                            <option value="Panama" %%=IIF(@nationality=='Panama', "selected", "")=%%>بنما</option>
                            <option value="Papua new Guinea" %%=IIF(@nationality=='Papua new Guinea', "selected", "")=%%>بابوا غينيا الجديدة</option>
                            <option value="Paraguay" %%=IIF(@nationality=='Paraguay', "selected", "")=%%>باراغواي</option>
                            <option value="Peru" %%=IIF(@nationality=='Peru', "selected", "")=%%>بيرو</option>
                            <option value="Philippines" %%=IIF(@nationality=='Philippines', "selected", "")=%%>الفلبين</option>
                            <option value="Pitcairn" %%=IIF(@nationality=='Pitcairn', "selected", "")=%%>بيتكيرن</option>
                            <option value="Poland" %%=IIF(@nationality=='Poland', "selected", "")=%%>بولندا</option>
                            <option value="Portugal" %%=IIF(@nationality=='Portugal', "selected", "")=%%>البرتغال</option>
                            <option value="Puerto Rico" %%=IIF(@nationality=='Puerto Rico', "selected", "")=%%>بورتوريكو</option>
                            <option value="Qatar" %%=IIF(@nationality=='Qatar', "selected", "")=%%>قطر</option>
                            <option value="Republic of Korea" %%=IIF(@nationality=='Republic of Korea', "selected", "")=%%>جمهورية كوريا</option>
                            <option value="Republic of Macedonia" %%=IIF(@nationality=='Republic of Macedonia', "selected", "")=%%>جمهورية مقدونيا</option>
                            <option value="Republic of Moldova" %%=IIF(@nationality=='Republic of Moldova', "selected", "")=%%>جمهورية مولدوفا</option>
                            <option value="Republic of Somaliland" %%=IIF(@nationality=='Republic of Somaliland', "selected", "")=%%>جمهورية أرض الصومال</option>
                            <option value="Reunion" %%=IIF(@nationality=='Reunion', "selected", "")=%%>ريونيون</option>
                            <option value="Romania" %%=IIF(@nationality=='Romania', "selected", "")=%%>رومانيا</option>
                            <option value="Russian Federation" %%=IIF(@nationality=='Russian Federation', "selected", "")=%%>الاتحاد الروسي</option>
                            <option value="Rwanda" %%=IIF(@nationality=='Rwanda', "selected", "")=%%>رواندا</option>
                            <option value="Saint Helena" %%=IIF(@nationality=='Saint Helena', "selected", "")=%%>سانت هيلينا</option>
                            <option value="Saint Kitts And Nevis" %%=IIF(@nationality=='Saint Kitts And Nevis', "selected", "")=%%>سانت كيتس ونيفيس</option>
                            <option value="Saint Lucia" %%=IIF(@nationality=='Saint Lucia', "selected", "")=%%>سانت لوسيا</option>
                            <option value="Saint Pierre and Miquelon" %%=IIF(@nationality=='Saint Pierre and Miquelon', "selected", "")=%%>سانت بيير وميكلون</option>
                            <option value="Saint Vincent And The Grenadines" %%=IIF(@nationality=='Saint Vincent And The Grenadines', "selected", "")=%%>سانت فنسنت والغرينادين</option>
                            <option value="Saint Barthelemy" %%=IIF(@nationality=='Saint Barthelemy', "selected", "")=%%>سانت بارتيليمي</option>
                            <option value="Saint Martin (French part)" %%=IIF(@nationality=='Saint Martin (French part)', "selected", "")=%%>سانت مارتن (الجزء الفرنسي)</option>
                            <option value="Samoa" %%=IIF(@nationality=='Samoa', "selected", "")=%%>ساموا</option>
                            <option value="San Marino" %%=IIF(@nationality=='San Marino', "selected", "")=%%>سان مارينو</option>
                            <option value="Sao Tome and Principe" %%=IIF(@nationality=='Sao Tome and Principe', "selected", "")=%%>ساو تومي وبرينسيبي</option>
                            <option value="Saudi Arabia" %%=IIF(@nationality=='Saudi Arabia', "selected", "")=%%>المملكة العربية السعودية</option>
                            <option value="Senegal" %%=IIF(@nationality=='Senegal', "selected", "")=%%>السنغال</option>
                            <option value="Serbia" %%=IIF(@nationality=='Serbia', "selected", "")=%%>صربيا</option>
                            <option value="Seychelles" %%=IIF(@nationality=='Seychelles', "selected", "")=%%>سيشل</option>
                            <option value="Sierra Leone" %%=IIF(@nationality=='Sierra Leone', "selected", "")=%%>سيراليون</option>
                            <option value="Singapore" %%=IIF(@nationality=='Singapore', "selected", "")=%%>سنغافورة</option>
                            <option value="Sint Maarten" %%=IIF(@nationality=='Sint Maarten', "selected", "")=%%>سينت مارتن</option>
                            <option value="Slovakia" %%=IIF(@nationality=='Slovakia', "selected", "")=%%>سلوفاكيا</option>
                            <option value="Slovenia" %%=IIF(@nationality=='Slovenia', "selected", "")=%%>سلوفينيا</option>
                            <option value="Solomon Islands" %%=IIF(@nationality=='Solomon Islands', "selected", "")=%%>جزر سليمان</option>
                            <option value="Somalia" %%=IIF(@nationality=='Somalia', "selected", "")=%%>الصومال</option>
                            <option value="South Africa" %%=IIF(@nationality=='South Africa', 'selected', "")=%%>جنوب أفريقيا</option>
                            <option value="South Georgia and the South Sandwich Islands" %%=IIF(@nationality=='South Georgia and the South Sandwich Islands', "selected", "")=%%>جورجيا الجنوبية وجزر ساندويتش الجنوبية</option>
                            <option value="South Sudan" %%=IIF(@nationality=='South Sudan', "selected", "")=%%>جنوب السودان</option>
                            <option value="Spain" %%=IIF(@nationality=='Spain', "selected", "")=%%>إسبانيا</option>
                            <option value="Sri Lanka" %%=IIF(@nationality=='Sri Lanka', "selected", "")=%%>سريلانكا</option>
                            <option value="State of Palestine" %%=IIF(@nationality=='State of Palestine', "selected", "")=%%>دولة فلسطين</option>
                            <option value="Sudan" %%=IIF(@nationality=='Sudan', "selected", "")=%%>السودان</option>
                            <option value="Suriname" %%=IIF(@nationality=='Suriname', "selected", "")=%%>سورينام</option>
                            <option value="Svalbard And Jan Mayen" %%=IIF(@nationality=='Svalbard And Jan Mayen', "selected", "")=%%>سفالبارد ويان ماين</option>
                            <option value="Swaziland" %%=IIF(@nationality=='Swaziland', "selected", "")=%%>سوازيلاند</option>
                            <option value="Sweden" %%=IIF(@nationality=='Sweden', "selected", "")=%%>السويد</option>
                            <option value="Switzerland" %%=IIF(@nationality=='Switzerland', "selected", "")=%%>سويسرا</option>
                            <option value="Syrian Arab Republic" %%=IIF(@nationality=='Syrian Arab Republic', "selected", "")=%%>الجمهورية العربية السورية</option>
                            <option value="Taiwan" %%=IIF(@nationality=='Taiwan', "selected", "")=%%>تايوان</option>
                            <option value="Tajikistan" %%=IIF(@nationality=='Tajikistan', "selected", "")=%%>طاجيكستان</option>
                            <option value="Thailand" %%=IIF(@nationality=='Thailand', "selected", "")=%%>تايلاند</option>
                            <option value="Timor-Leste" %%=IIF(@nationality=='Timor-Leste', "selected", "")=%%>تيمور الشرقية</option>
                            <option value="Togo" %%=IIF(@nationality=='Togo', "selected", "")=%%>توغو</option>
                            <option value="Tokelau" %%=IIF(@nationality=='Tokelau', "selected", "")=%%>توكلاو</option>
                            <option value="Tonga" %%=IIF(@nationality=='Tonga', "selected", "")=%%>تونغا</option>
                            <option value="Trinidad And Tobago" %%=IIF(@nationality=='Trinidad And Tobago', "selected", "")=%%>ترينيداد وتوباغو</option>
                            <option value="Tunisia" %%=IIF(@nationality=='Tunisia', "selected", "")=%%>تونس</option>
                            <option value="Turkey" %%=IIF(@nationality=='Turkey', "selected", "")=%%>تركيا</option>
                            <option value="Turkmenistan" %%=IIF(@nationality=='Turkmenistan', "selected", "")=%%>تركمانستان</option>
                            <option value="Turks And Caicos Islands" %%=IIF(@nationality=='Turks And Caicos Islands', "selected", "")=%%>جزر تركس وكايكوس</option>
                            <option value="Tuvalu" %%=IIF(@nationality=='Tuvalu', "selected", "")=%%>توفالو</option>
                            <option value="Uganda" %%=IIF(@nationality=='Uganda', "selected", "")=%%>أوغندا</option>
                            <option value="Ukraine" %%=IIF(@nationality=='Ukraine', "selected", "")=%%>أوكرانيا</option>
                            <option value="United Arab Emirates" %%=IIF(@nationality=='United Arab Emirates', "selected", "")=%%>الإمارات العربية المتحدة</option>
                            <option value="United Kingdom (UK)" %%=IIF(@nationality=='United Kingdom (UK)', "selected", "")=%%>المملكة المتحدة (بريطانيا)</option>
                            <option value="United Republic of Tanzania" %%=IIF(@nationality=='United Republic of Tanzania', "selected", "")=%%>جمهورية تنزانيا المتحدة</option>
                            <option value="United States of America" %%=IIF(@nationality=='United States of America', "selected", "")=%%>الولايات المتحدة الأمريكية</option>
                            <option value="United States Minor Outlying Islands" %%=IIF(@nationality=='United States Minor Outlying Islands', "selected", "")=%%>جزر الولايات المتحدة الصغيرة النائية</option>
                            <option value="Uruguay" %%=IIF(@nationality=='Uruguay', "selected", "")=%%>أوروغواي</option>
                            <option value="Uzbekistan" %%=IIF(@nationality=='Uzbekistan', "selected", "")=%%>أوزبكستان</option>
                            <option value="Vanuatu" %%=IIF(@nationality=='Vanuatu', "selected", "")=%%>فانواتو</option>
                            <option value="Venezuela" %%=IIF(@nationality=='Venezuela', "selected", "")=%%>فنزويلا</option>
                            <option value="Viet Nam" %%=IIF(@nationality=='Viet Nam', "selected", "")=%%>فيتنام</option>
                            <option value="Virgin Islands, British" %%=IIF(Replace(@nationality, ",", "") == 'Virgin Islands British', "selected", "")=%%>جزر فيرجن البريطانية</option>
                            <option value="Virgin Islands, U.S." %%=IIF(Replace(@nationality, ",", "") == 'Virgin Islands U.S.', "selected", "")=%%>جزر فيرجن الأمريكية</option>
                            <option value="Wallis And Futuna" %%=IIF(@nationality=='Wallis And Futuna', "selected", "")=%%>واليس وفوتونا</option>
                            <option value="Western Sahara" %%=IIF(@nationality=='Western Sahara', "selected", "")=%%>الصحراء الغربية</option>
                            <option value="Yemen" %%=IIF(@nationality=='Yemen', "selected", "")=%%>اليمن</option>
                            <option value="Zambia" %%=IIF(@nationality=='Zambia', "selected", "")=%%>زامبيا</option>
                            <option value="Zimbabwe" %%=IIF(@nationality=='Zimbabwe', "selected", "")=%%>زمبابوي</option>
                            <option value="Others" %%=IIF(@nationality=='Others', "selected", "")=%%>آخرون</option>
                        </select>
                 
                        </div>
                    </div>
                </div>
  
                   <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group">
                        <label for="">الجنس</label>
                        <div class="select-wrapper hide-icon custom-">

                          <!-- Priyanka 23 Feb, Added ampscript for gender -->
                          <select class="form-control" name="gender" id="gender">
                               <option value=" " selected>اختر</option>
                               <option value="Female" %%=IIF(@gender=='Female', "selected", "")=%%>أنثى</option>
                                <option value="Male" %%=IIF(@gender=='Male', "selected", "")=%%>ذكر</option> 
                            </select>
                         
                        </div>
                    </div>
                </div>
          
              <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group">
                        <label class="label">تاريخ الميلاد</label>
                        <div class="bdate">
                          <input class="form-control" type="date" name="birthday" max="getToday();" value="%%=v(@birthdate)=%%" id="birthday">
                
                 <input type="hidden" id="hiddenDate">
                      </div>
                    
                      </div>
                  </div>
                <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">اختيار اللغة</label>
                          <div class="select-wrapper hide-icon custom-">
  
                          <select class="form-control" name="profilelang">
                                 <option value=" " %%=IIF(@language==' ', "selected", "")=%%>اختر</option>
                                 <option value="English" %%=IIF(@language=='English', "selected", "")=%%>English</option>
                                  <option value="Arabic" %%=IIF(@language=='Arabic', "selected", "")=%%>العربية</option> 
                              </select>
                           
                          </div>
                      </div>
                  </div>
                 
              </div>
              <!-- Family details section start -->
              <h4 class="pt-4 pb-4">أخبرنا المزيد عن عائلتك</h4>
              <!-- marital status new -->
              <div class="col-lg-4 col-md-6 col-sm-12 col-12" style="padding-left:0;">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">الحالة الاجتماعية</label>
                          <div class="select-wrapper hide-icon">
                          <select class="form-control" name="maritalstatus">
                            <option value="">اختر</option>
                            <option value="Single" %%=IIF(@marriedStatus=='Single', "selected", "")=%%>أعزب  
                            </option>
                            <option value="Married" %%=IIF(@marriedStatus=='Married', "selected", "")=%%>متزوج
                            </option>
                            </select>
                              
               
                          </div>
                      </div>
                  </div>
              <!-- Marital status section start 
              <div class="form-group" data-aos="fade-up" data-aos-anchor-placement="bottom-bottom">
                <label for="">هل لديك أطفال؟</label>
                <div class="radio-wrapper">
                  <div class="form-check form-check-inline">
                    <input class="form-check-input" type="radio" name="inlineRadioOptions" id="inlineRadio1" value="option1" %%=IIF(@marriedStatus=='Single', 'checked', '')=%%>
                    <label class="form-check-label" for="inlineRadio1">Single</label>
                  </div>
                  <div class="form-check form-check-inline">
                    <input class="form-check-input" type="radio" name="inlineRadioOptions" id="inlineRadio2" value="option2" %%=IIF(@marriedStatus=='Married', 'checked', '')=%%>
                    <label class="form-check-label" for="inlineRadio2">Married</label>
                  </div>
                </div>
              </div>
    <!-- Marital status section end -->
  
      <!-- Kids section start -->
      <div class="form-group pt-2 pb-4">
        <label for="">هل لديك أطفال؟</label>
        <div class="radio-wrapper">
            <div class="form-check form-check-inline">
                <input class="form-check-input" type="radio" name="kidsExists" id="kids"
                    value="kids-yes" onclick="ShowHideDivkids()" %%=v(@childExistsYes)=%%>
                <label class="form-check-label" for="kids">نعم</label>
            </div>
            <div class="form-check form-check-inline">
                <input class="form-check-input" type="radio" name="kidsExists"
                    id="nokids" value="kids-no" onclick="ShowHideDivkids()" %%=v(@childExistsNo)=%%>
                <label class="form-check-label" for="nokids">لا</label>
            </div>
        </div>
    </div>
    <div id="dvKids" style=%%=IIF(@childExistsYes=='checked', "display:block;","display:none;")=%%>
      <div class="box-form-wrapper"  id="Dvkids">
          <div class="row">
              <div class="col-lg-4 col-md-4 col-sm-12 col-12">
                  <div class="form-group">
                      <label for="numOfKids">هل لديك أطفال؟</label>
                      <div class="select-wrapper">
  
                          <select class="form-control selectpicker" name="state" id="numOfKids" onclick="kidsPrepopulation();">
                              <option value="0" %%=IIF(@numOfKids==0, "selected", "")=%%>Select</option>
                              <option value="1" %%=IIF(@numOfKids==1, "selected", "")=%%>1</option>
                              <option value="2" %%=IIF(@numOfKids==2, "selected", "")=%%>2</option>
                              <option value="3" %%=IIF(@numOfKids==3, "selected", "")=%%>3</option>
                              <option value="4" %%=IIF(@numOfKids==4, "selected", "")=%%>4</option>
                              <option value="5" %%=IIF(@numOfKids==5, "selected", "")=%%>5</option>
                              <option value="6" %%=IIF(@numOfKids==6, "selected", "")=%%>6</option>
                              <option value="7" %%=IIF(@numOfKids==7, "selected", "")=%%>7</option>
                              <option value="8" %%=IIF(@numOfKids==8, "selected", "")=%%>8</option>
                              <option value="9" %%=IIF(@numOfKids==9, "selected", "")=%%>9</option>
                              <option value="10" %%=IIF(@numOfKids==10, "selected", "")=%%>10</option>
                          </select>
                         
  
                      </div>
                  </div>
                  </br>
  
              </div>
            </div>
              <div class="kids-info" id="kids-info">
                <div id="kidsTable" width="100%">
                  
                </div>
              </div>
      
      <p class="disclaimer" style="font-size:12px;"> <i>نطلب تاريخ ميلاد طفلك لكي نتمكن من إرسال تهاني عيد ميلاده، بالإضافة إلى اطلاعك على أحدث الفعاليات والعروض الترويجية.</i></p>
      </div>
  
  </div>
          %%[

    /*SET @crmIdEn = "0036M00004SEQwKQAX"*/
   /* SET @crmIdEn = QueryParameter("sfid")
    SET @crmIdJS = Base64Decode(@crmIdEn) */        /*...........uncommented.................*/

SET @crmId = _subscriberkey
IF (empty(@crmId)) THEN
    SET @crmIdEn = QueryParameter("sfid")
    SET @crmId = Base64Decode(@crmIdEn)
    IF (empty(@crmId)) THEN
      SET @crmId = RequestParameter("sfid")
      IF (empty(@crmId)) THEN
       SET @crmId = QueryParameter("sfid")
      ENDIF
     ENDIF
    ENDIF



    IF NOT EMPTY(@crmId) THEN              /*...........uncommented.................*/
    /*IF NOT EMPTY(@crmIdEn) THEN */  
        /* Fetching Children details */
        
       
        var @j
        SET @childDetails = RetrieveSalesforceObjects("Family_Member__c","Gender__c,Date_Of_Birth__c,First_Name__c,ID,Last_Name__c,Deleted_kid__c",
        "Contact__c", "=", @crmId,
        "Relationship__c", "=", "Child")
        SET @childDetailsRowCount = Rowcount(@childDetails)
       
        IF @childDetailsRowCount > 0 THEN
       
            For @j=1 to @childDetailsRowCount do
                SET @childDetailsRow = Row(@childDetails, @j)
                set @deleted = Field(@childDetailsRow, "Deleted_kid__c")
                
                if @deleted == false then 
                
                SET @ChildFirstName = Field(@childDetailsRow, "First_Name__c")         
               set @childGender = Field(@childDetailsRow, "Gender__c")
                set @childDOB = Field(@childDetailsRow, "Date_Of_Birth__c")
                set @childFirstName = Field(@childDetailsRow, "First_Name__c")
                set @childLastName = Field(@childDetailsRow, "Last_Name__c")
                set @childRecID = Field(@childDetailsRow, "ID")
                
      
          
            IF NOT EMPTY(@childFirstName) AND NOT EMPTY(@childLastName) THEN
               SET @childFullName = Concat(ProperCase(@childFirstName)," ",ProperCase(@childLastName))
            ELSEIF NOT EMPTY(@childFirstName) AND EMPTY(@childLastName) THEN
               SET @childFullName = ProperCase(@childFirstName)
            ELSEIF EMPTY(@childFirstName) AND NOT EMPTY(@childLastName) THEN
               SET @childFullName = ProperCase(@childLastName)
            ELSE
               SET @childFullName = ""
           ENDIF 
          
           set @count = Subtract(@j, 1)
           
     
     
    
    ]%%
       

    <input type="hidden" id="kidName%%=v(@count)=%%" name="kidName%%=v(@count)=%%" value="%%=v(@childFullName)=%%">
    <input type="hidden" id="kidDOB%%=v(@count)=%%" name="kidDOB%%=v(@count)=%%" value="%%=v(@childDOB)=%%">
    <input type="hidden" id="kidGen%%=v(@count)=%%" name="kidGen%%=v(@count)=%%" value="%%=v(ProperCase(@childGender))=%%">
    <input type="hidden" id="kidRecId%%=v(@count)=%%" name="kidRecId%%=v(@count)=%%" value="%%=v(@childRecID)=%%">
    <input type="hidden" id="deletedKid%%=v(@count)=%%" name="deletedKid%%=v(@count)=%%" value="%%=v(@childRecID)=%%">
            
          
         
    %%[
    endif
           next @j 
          
        ENDIF
    ENDIF   
    ]%%
              <div class="submit-button">
          
              <button type="submit" class="btn btn-success"id="profile-submit" name="button">حفظ</button>
 
          </div>
          
          <input name="submittedProfile" type="hidden" value="true">
                         <input name="crmId" id="crmId" type="hidden" value="%%=v(@crmId)=%%"><br>
            <input name="numberOfKids" type="hidden" value="%%=v(@numOfKids)=%%"><br>      
              </form>
        
          %%[
                                IF RequestParameter("submittedProfile")==true then
                                        SET @sfid = RequestParameter("crmId")

                                        SET @profileSalutation = RequestParameter("profileSalutation")
                                        SET @firstName = RequestParameter("firstName")
                                        set @numOfKids = RequestParameter("numberOfKids")
                                        SET @lastName = RequestParameter("lastName")
                                        set @gender = RequestParameter("gender")
                                        set @city = RequestParameter("city")
                                        SET @email = RequestParameter("email")
                                        SET @phone = RequestParameter("phone")
                                        if RequestParameter("lang") == '' then
                                         SET @phonecode = '+971'
                                        endif
                                        if RequestParameter("lang") != '' then
                                         SET @phonecode = RequestParameter("lang")
                                        endif
                                        SET @birthdate = RequestParameter("birthday")
                                        SET @profileLang = RequestParameter("profileLang")
                                        SET @profileNationality = RequestParameter("profileNationality")
                                        SET @profileCountry = RequestParameter("profileCountry")
                                        
                                        SET @profileMarriedBox = RequestParameter("maritalstatus")
                                       
                                        /*Child Selected values*/
                                        SET @profilekidsValue = RequestParameter("state")
                                        SET @profileKidsBox = RequestParameter("kidsExists")
                                        IF @profileKidsBox == 'kids-yes' THEN
                                            SET @kidsStatus = 'True'
                                            SET @doYouHaveKids = 'True'
                                        ELSE
                                            SET @kidsStatus = 'False'
                                            SET @doYouHaveKids = 'False'
                                        ENDIF

                                        IF Empty(@profilekidsValue) THEN
                                           SET @profilekidsValue = 0
                                        ENDIF
                                        
                                        /*Output(Concat("Birthdate after: ", @birthdate))
                                        set @bdate = FormatDate(@birthdate,"s")
                                        Output(Concat("Birthdate v1: ", @bdate))
                                        set @format = Format(@bdate, "d", "Date")
                                        Output(Concat("Birthdate v2: ", @format))*/
                                        
                                        IF NOT Empty(@sfid) THEN
                                        
                                     
                                        IF Empty(@birthdate) THEN
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "fieldsToNull", "BirthDate"
                                            )
                                       ELSE
                                           SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "BirthDate", @birthdate
                                            )
                                        ENDIF
                                        
                                      IF Empty(@profileMarriedBox) THEN
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "fieldsToNull", "Marital_Status__c"
                                            )
                                       ELSE
                                           SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "Marital_Status__c", @profileMarriedBox
                                            )
                                      ENDIF 
                                        
                                      IF Empty(@profileNationality) THEN
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "fieldsToNull", "Nationality__c"
                                            )
                                       ELSE
                                           SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "Nationality__c", @profileNationality
                                            )
                                        ENDIF

                                        
                                        IF Empty(@phone) THEN
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "fieldsToNull", "Phone"
                                            )
                                        ELSE
                                           SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "Phone", @phone
                                            )
                                        ENDIF
                                        IF Empty(@phonecode) THEN
                                        SET @phonecode = "+971"
                                        ENDIF
                                        IF Empty(@city) THEN
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "fieldsToNull", "MailingCity"
                                            )
                                       ELSE
                                           SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "MailingCity", @city
                                            )
                                        ENDIF
                                        
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "Salutation", @profileSalutation,
                                            "FirstName", @firstName,
                                            "LastName", @lastName, 
                                            "Email", @email,
                                            "Country_Code__c", @phonecode,
                                            "Registration_Language__c", @profileLang,
                                            "GenderIdentity", @gender,
                                            "Nationality__c", @profileNationality,
                                            "Residence_Country__c", @profileCountry,
                                            "Do_you_have_kids__c", @doYouHaveKids 
                                            )
                                       
                                 
                                    /*Creating and Updating child records based on value selected above*/
       
                                       
                                        IF @profilekidsValue > 0 AND  @profileKidsBox == 'kids-yes' THEN
                                        
                                          /*RETRIVAL OF ALL CRM KID ID AND CREATE STRING*/
                                       
                                       var @CRMIdList
                                       SET @childIDs = RetrieveSalesforceObjects("Family_Member__c","ID",
                                                           "Contact__c", "=", @sfid,
                                                           "Relationship__c", "=", "Child")
                                                            SET @childIDRowCount = Rowcount(@childIDs)
                                                            
                                                            IF @childIDRowCount > 0 THEN
                                                            
                                                            For @p=1 to @childIDRowCount do
                                                            
                                                            SET @childIDRow = Row(@childIDs, @p)
                                                            set @KidID = Field(@childIDRow, "ID")
                                                            Set @CRMIdList = CONCAT(@CRMIdList, @KidID, ",")
               
    
                                                            next @p
      
                                                            ENDIF
                               
                                                            
                                                            
                                                            
                                        
                                            FOR @k=1 to @profilekidsValue do
                                            set @u = Subtract(@k, 1)
                                                SET @kidGender = Concat("gender",@u)
                                                SET @kidGenderVal = RequestParameter(@kidGender)
                                                SET @kidName = Concat("kidsName",@u)
                                                SET @kidNameval = RequestParameter(@kidName)
                                                IF IndexOf(@kidNameval, " ") > 0 THEN
                                                      Set @kidFirstName = Substring(@kidNameval,1, Subtract(IndexOf(@kidNameval," "),1))
                                                      set @kidLastName = Substring(@kidNameval,Add(indexOf(@kidNameval, " "),1))
                                                    else
                                                       SET @kidFirstName = @kidNameval
                                                       SET @kidLastName = ""
                                                ENDIF
                                                SET @kidDOB = Concat("kids-birthday",@u)
                                                SET @kidDOBVal = RequestParameter(@kidDOB)
                                                SET @kidRecId = Concat("kidRecId",@u)
                                                SET @kidRecIdVal = RequestParameter(@kidRecId)
                                                
                                                IF Not Empty(@kidRecIdVal) THEN
                                                
                                                
                                                SET @childIDs = RetrieveSalesforceObjects("Family_Member__c","ID",
                                                           "id", "=", @kidRecIdVal,
                                                           "Relationship__c", "=", "Child")
                                                            SET @childIDRowCount = Rowcount(@childIDs)
                                                            
                                                            IF @childIDRowCount > 0 THEN
                                                            
                                                            For @p=1 to @childIDRowCount do
                                              
                                              
                                                
                                                   IF EMPTY(@kidDOBVal) THEN
                                                          SET @updateKidRecord = UpdateSingleSalesforceObject(
                                                          "Family_Member__c", @kidRecIdVal,
                                                          "First_Name__c", @kidFirstName,
                                                          "Last_Name__c" , @kidLastName,
                                                          "Gender__c", @kidGenderVal,
                                                          "Name", @kidNameval,
                                                          "fieldsToNull", "Date_Of_Birth__c"
                                                          )
                                                   ELSE
                                                         SET @updateKidRecord = UpdateSingleSalesforceObject(
                                                          "Family_Member__c", @kidRecIdVal,
                                                          "First_Name__c", @kidFirstName,
                                                          "Last_Name__c" , @kidLastName,
                                                          "Gender__c", @kidGenderVal,
                                                          "Date_Of_Birth__c", @kidDOBVal,
                                                          "Name", @kidNameval
                                                          )
                                                   ENDIF
                                                   IF EMPTY(@kidGenderVal) THEN
                                                          SET @updateKidRecord = UpdateSingleSalesforceObject(
                                                          "Family_Member__c", @kidRecIdVal,
                                                          "First_Name__c", @kidFirstName,
                                                          "Last_Name__c" , @kidLastName,
                                                          "Name", @kidNameval,
                                                          "fieldsToNull", "Gender__c"
                                                          )
                                                   ELSE
                                                         SET @updateKidRecord = UpdateSingleSalesforceObject(
                                                          "Family_Member__c", @kidRecIdVal,
                                                          "First_Name__c", @kidFirstName,
                                                          "Last_Name__c" , @kidLastName,
                                                          "Gender__c", @kidGenderVal,
                                                          "Name", @kidNameval
                                                          )
                                                   ENDIF
                                                   next @p
      
                                                            ENDIF
                                                ELSE
                                                    IF EMPTY(@kidDOBVal) THEN
                                                    
                                                    set @numOfKids = Add(@numOfKids, 1)
                                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                                                         "Contact", @sfid,
                                                                         "Number_of_kids__c", @numOfKids
                                                                        )
                                                    
                                                     SET @newKidRecord = CreateSalesforceObject("Family_Member__c", 6,
                                                          "First_Name__c", @kidFirstName,
                                                          "Last_Name__c" , @kidLastName,
                                                          "Gender__c", @kidGenderVal,
                                                          "Relationship__c", "Child",
                                                          "Contact__c", @sfid,
                                                          "Name", @kidNameval,
                                                          "fieldsToNull", "Date_Of_Birth__c")
                                                   ELSE
                                                    SET @newKidRecord = CreateSalesforceObject("Family_Member__c", 7,
                                                          "First_Name__c", @kidFirstName,
                                                          "Last_Name__c" , @kidLastName,
                                                          "Gender__c", @kidGenderVal,
                                                         "Date_Of_Birth__c", @kidDOBVal, 
                                                          "Relationship__c", "Child",
                                                          "Contact__c", @sfid,
                                                          "Name", @kidNameval)
                                                   ENDIF
                                                ENDIF
                                            next @k
                                        ENDIF
                                        
                                        /* made changes for "no" kids selection on 14 feb */
                                        
                                        IF @profilekidsValue > 0 AND  @profileKidsBox == 'kids-no' THEN
                                              
                                              
                                              SET @childIDs = RetrieveSalesforceObjects("Family_Member__c","id","Contact__c", "=", @sfid,"Relationship__c", "=", "Child")
                                              /*Output(Concat("childIDs: ", @childIDs, "<br>"))*/
                                              SET @childIDRowCount = Rowcount(@childIDs)
                                              /*Output(Concat("childIDRowCount: ", @childIDRowCount, "<br>"))*/
                                              For @n=1 to @childIDRowCount do
                                                  SET @childIDRow = Row(@childIDs, @n)
                                                  set @KidID = Field(@childIDRow, "ID")
                                                  /*Output(Concat("number of kids v1: ", @numOfKids))*/
                                                  SET @updatedeletedKidRecord = UpdateSingleSalesforceObject(
                                                  "Family_Member__c", @KidID,
                                                  "Deleted_kid__c", "True"
                                                  )
                                                  /*Output(Concat("updatedeletedKidRecord: ", @updatedeletedKidRecord, "<br>"))*/
                                             next @n
                                             SET @childIDRowCount = Rowcount(@childIDs)
                                                  SET @updateNoOfKidRecord = UpdateSingleSalesforceObject("Contact", @sfid,"Number_of_kids__c", @childIDRowCount)
                                                  /*Output(Concat("updateNoOfKidRecord: ", @updateNoOfKidRecord, "<br>"))*/
                                    endif 
                                                                                
                                        
                                        
                                   endif
            
                                   set @interests = '#interests'
                                   if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","ProfilePage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.legoland.ae/LLQA_CPC_Arabic?sfid=", Base64Encode(@sfid), "#interests"))
                                   ELSE
                                      Redirect(CONCAT(CloudPagesURL(2852),@interests))
                                   ENDIF
                                   
                                   
                                   endif

                                        
        
        ]%%
        
         
       
        
        
            </div>
        </div>
                <!-- 2nd card Interest tab-->
           %%[
                                   
                                   set @primaryReasonString = BuildRowsetFromString(@primaryReasonForVisit,";")
                                   set @primaryReasonCount = rowCount(@primaryReasonString)
                                   
                                   if @primaryReasonCount > 0 then
                                      for @i = 1 to @primaryReasonCount do
                                           
                                           SET @val = Field(Row(@primaryReasonString,@i),1)
                                           
                                           IF @val == "Fun family activities" THEN
                                           SET @funFamilyActivities = "checked"
                                           ELSEIF @val == "It's on my Dubai bucket list" THEN
                                           SET @dubaiBucketList = "checked"
                                           ELSEIF @val == "I love rides and theme parks" THEN
                                           SET @themePark = "checked"
                                           ELSEIF @val == "I want to celebrate my birthday" THEN
                                           SET @celebrateBirthday = "checked"
                                           ELSEIF @val == "I am a regular (Annual Pass member)" THEN       
                                           SET @annualPassMember = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
   
                                  set @likeMostString = BuildRowsetFromString(@likeMostAbout,";")
                                  set @likeMostCount = rowCount(@likeMostString)
                                  
                                  if @likeMostCount > 0 then
                                      for @i = 1 to @likeMostCount do
                                           
                                           SET @val = Field(Row(@likeMostString,@i),1)
                                           
                                           IF @val == "The rides" THEN
                                           SET @rides = "checked"
                                           ELSEIF @val == "Live entertainment" THEN
                                           SET @liveEntertainment = "checked"
                                           ELSEIF @val == "Food and restaurants" THEN
                                           SET @foodAndRestaurants = "checked"
                                           ELSEIF @val == "Events" THEN
                                           SET @freeEvents = "checked"
                                           ELSEIF @val == "Hotels and resorts" THEN       
                                           SET @hotelsAndResorts = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
                    
                    
         ]%% 
        <div class="tab-pane fade interest-tab-content" id="interests" role="tabpanel" aria-labelledby="interests-tab">
          
            <div class="wrapper wrapper--w700">
              
              <form class="interest-form" action="" method="post" name="myForm" id="interest-form" autocomplete="off" >
              
               
                 
                   <div class="form-group">
                    <h4 class="pt-4 pb-3">ما هو السبب الرئيسي لزيارتك إلى دبي باركس™  آند ريزورتس؟</h4>
                    <div class="radio-wrapper primary-reason radio-width">
                        <div class="form-check form-check">
                          <label class="form-check-label" for="reason1">أنشطة عائلية ممتعة</label>
                            <input class="form-check-input" type="checkbox" name="reason1" id="reason1" %%=v(@funFamilyActivities)=%% >                                
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="reason2">انها ضمن قائمة الأشياء التي اريد القيام بها في دبي</label>
                          <input class="form-check-input" type="checkbox" name="reason2" id="reason2" %%=v(@dubaiBucketList)=%% >  
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="reason3">أحب الجولات والمتنزهات</label>
                          <input class="form-check-input" type="checkbox" name="reason3" id="reason3" %%=v(@themePark)=%% >  
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="reason4">أريد أن أحتفل بعيد ميلادي</label>
                          <input class="form-check-input" type="checkbox" name="reason4" id="reason4" %%=v(@celebrateBirthday)=%% >  
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="reason5">انا زائر منتضم (عضو الاشتراك السنوي</label>
                          <input class="form-check-input" type="checkbox" name="reason5" id="reason5" %%=v(@annualPassMember)=%% >  
                        </div>
                    </div>
                    

                    <h4 class="pt-4 pb-3">بالعادة كم مرة تقوم بزيارة دبي باركس™ آند ريزورتس؟</h4>
                    <div class="radio-wrapper often-visit radio-width">
                      <div class="form-check form-check">
                        <label class="form-check-label" for="visit1">كل أسبوع</label>
                          <input class="form-check-input" type="radio" name="visit" id="visit1"value="Every week" %%=IIF(@howOftenVisit=='Every week', 'checked', '')=%% >                            
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="visit2">كل شهر</label>
                        <input class="form-check-input" type="radio" name="visit" id="visit2" value="Every month" %%=IIF(@howOftenVisit=='Every month', 'checked', '')=%% >
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="visit3">مرة كل سنة</label>
                        <input class="form-check-input" type="radio" name="visit" id="visit3" value="Once a year" %%=IIF(@howOftenVisit=='Once a year', 'checked', '')=%% >
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="visit4">مرتين في السنة</label>
                        <input class="form-check-input" type="radio" name="visit" id="visit4" value="Two times per year" %%=IIF(@howOftenVisit=='Two times per year', 'checked', '')=%% >
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="visit5">كل سنتين</label>
                        <input class="form-check-input" type="radio" name="visit" id="visit5" value="Every two years" %%=IIF(@howOftenVisit=='Every two years', 'checked', '')=%% >
                      </div>
                  </div>

                  <h4 class="pt-4 pb-3">ما هو أكثر شيء يعجبك في دبي باركس™ آند ريزورتس؟</h4>
                  <div class="radio-wrapper like-most radio-width">
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like1">الجولات</label>
                        <input class="form-check-input" type="checkbox" name="like1" id="like1" %%=v(@rides)=%% >                            
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like2">الفعاليات الترفهيه الحية </label>
                      <input class="form-check-input" type="checkbox" name="like2" id="like2" %%=v(@liveEntertainment)=%% >
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like3">المأكواتت والمطاعم </label>
                      <input class="form-check-input" type="checkbox" name="like3" id="like3" %%=v(@foodAndRestaurants)=%%  >
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like4">الفعاليات</label>
                      <input class="form-check-input" type="checkbox" name="like4" id="like4" %%=v(@freeEvents)=%% >
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like5">الفنادق والمنتجعات</label>
                      <input class="form-check-input" type="checkbox" name="like5" id="like5" %%=v(@hotelsAndResorts)=%%  >
                    </div>
                
                </div>

                
          

                 </div>
               <input name="submittedInterests" type="hidden" value="true"><br>
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%"><br>
                <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
            
              
                 <div class="text-end">
                  <button type="submit" class="btn btn-success"id="interest-submit" name="button">حفظ</button>  
                 </div> 
                </form>
                 </div>  
            

               %%[
        IF RequestParameter("submittedInterests") == "true" then
          SET @sfid = RequestParameter("crmId")
          SET @guestId = RequestParameter("guestId")
          
           SET @primaryReasonToVisitValue = CONCAT(
          Iif(RequestParameter("reason1") == "on", "Fun family activities;", ""),
          Iif(RequestParameter("reason2") == "on", "It's on my Dubai bucket list;", ""),
          Iif(RequestParameter("reason3") == "on", "I love rides and theme parks;", ""),
          Iif(RequestParameter("reason4") == "on", "I want to celebrate my birthday;", ""),
          Iif(RequestParameter("reason5") == "on", "I am a regular (Annual Pass member)", ""),
        )  
         if not Empty(@primaryReasonToVisitValue) then
          SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "Primary_reason_for_your_visit_Legoland__c", @primaryReasonToVisitValue)
          else
            SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "Primary_reason_for_your_visit_Legoland__c")

         endif
        
         SET @oftenVisitValue = RequestParameter("visit")
         
         IF @oftenVisitValue == 'every week' THEN
        SET @OftenVisitUpdation = 'every week'
        ELSEIF @oftenVisitValue == 'every month' THEN
        SET @OftenVisitUpdation = 'every month'
        ELSEIF @oftenVisitValue == 'once a year' THEN
        SET @OftenVisitUpdation = 'once a year'
        ELSEIF @oftenVisitValue == 'two times per year' THEN
        SET @OftenVisitUpdation = 'two times per year'
        ELSEIF @oftenVisitValue == 'every two years' THEN
        SET @OftenVisitUpdation = 'every two years'
        ENDIF
         
          SET @likeMostAboutPreferences = CONCAT(
          Iif(RequestParameter("like1") == "on", "The rides;", ""),
          Iif(RequestParameter("like2") == "on", "Live entertainment;", ""),
          Iif(RequestParameter("like3") == "on", "Food and restaurants;", ""),
          Iif(RequestParameter("like4") == "on", "Events;", ""),
          Iif(RequestParameter("like5") == "on", "Hotels and resorts", ""),
        )  
    
    
        if not Empty(@likeMostAboutPreferences) then
          SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "Like_the_most_about_Legoland__c", @likeMostAboutPreferences)
          else
            SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "Like_the_most_about_Legoland__c")

         endif
          IF NOT Empty(@sfid) THEN
   

                SET @updateRecords = UpdateSingleSalesforceObject(
                "Guest_Subscription__c", @guestId, 
                "How_often_do_you_visit_Legoland__c", @OftenVisitUpdation
                )

                
          ENDIF
         
    
    set @communications = '#communications'
                                   if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","InterestPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   
                                   if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.legoland.ae/LLQA_CPC_Arabic?sfid=", Base64Encode(@sfid), "#communications"))
                                   ELSE
                                      Redirect(CONCAT(CloudPagesURL(2852),@communications))
                                   ENDIF
    
      ENDIF
]%%
          
        

              
        </div>
        <!-- Interest Tab End -->

        <!-- 3rd card Communication tab start-->
        <div class="tab-pane fade preferences-tab-content" id="communications" role="tabpanel" aria-labelledby="communications-tab">
          <div class="wrapper wrapper--w700">
            <form class="preferences-form" action="" method="post">
               <!-- Second -->
                 <div class="hear-about radio-wrapper radio-width">
               <h4 class="pt-4 pb-3">ما الذي تريد أن تسمع عنه؟</h4>
               <div class="form-check">
               <label class="form-check-label" for="informCheck11">
                   العروض والحملات الترويجية
                   </label>
                   <input class="form-check-input" type="checkbox" value="%%=v(@promotionaloffersdeals)=%%" id="informCheck11"  name="hearOffers" %%=IIF(@promotionaloffersdeals =='True' ,'checked', "" )=%% >
               </div>
               <div class="form-check">
                   <label class="form-check-label" for="informCheck12">
                   الفعاليات القادمة للعائلات
                   </label>
                   <input class="form-check-input" type="checkbox" value="%%=v(@annualpassvipoffers)=%%" id="informCheck12"  name="hearEvents" %%=IIF(@annualpassvipoffers =='True' ,'checked', "" )=%%>
               </div>
               <div class="form-check">
                   <label class="form-check-label" for="informCheck13">
                    جولات وانشطة ترفيهية جديدة
                   </label>
                   <input class="form-check-input" type="checkbox" value="%%=v(@weeklyannouncements)=%%" id="informCheck13"  name="hearNews" %%=IIF(@weeklyannouncements =='True' ,'checked', "" )=%%>
               </div>
               <div class="form-check">
                   <label class="form-check-label" for="informCheck14">
                    مأكواتت و مطاعم جديدة
                   </label>
                   <input class="form-check-input" type="checkbox" value="%%=v(@newproductoffering)=%%" id="informCheck14"  name="newProduct" %%=IIF(@newproductoffering =='True' ,'checked', "" )=%%>
                </div>
               <div class="form-check">
                <label class="form-check-label" for="informCheck15">
                 الفنادق والمنتجعات
                </label>
                <input class="form-check-input" type="checkbox" value="%%=v(@latestnews)=%%" id="informCheck15"  name="hearOtherParks" %%=IIF(@latestnews =='True' ,'checked', "" )=%%>
            </div>
                    <div class="form-check">
                <label class="form-check-label" for="informCheck16">
                 استبيان العملاء
                </label>
                <input class="form-check-input" type="checkbox" value="%%=v(@customerSurvey)=%%" id="informCheck16"  name="hearSurvey" %%=IIF(@customerSurvey =='True' ,'checked', "" )=%%>
            </div>
             </div>
 
             <div class="com-btn mt-5">
              <button type="submit" class="btn btn-orange"id="communications-submit" name="button">حفظ</button>

          </div>
              <input name="submittedCommunications" type="hidden" value="true">
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
              <input name="guestId" id="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
           </form>
            <hr>
            %%[
                                IF RequestParameter("submittedCommunications")==true then
                                
                                    SET @sfid = RequestParameter("crmId")
                                    SET @guestId = RequestParameter("guestId")
                                    
                                    set @Updatedpromotionaloffersdeals =  RequestParameter("hearOffers")
                                    set @Updatedannualpassvipoffers=  RequestParameter("hearEvents")
                                    set @Updatedweeklyannouncements =  RequestParameter("hearNews")
                                    set @Updatednewproductoffering =  RequestParameter("newProduct")
                                    set @Updatedlatestnews =  RequestParameter("hearOtherParks")
                                    set @UpdatedcustomerSurvey =  RequestParameter("hearSurvey")
                                    
                                    IF NOT Empty(@sfid) THEN
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Offers_and_Promotions__c", IIF(EMPTY(@Updatedpromotionaloffersdeals), 'False', 'True'), 
                                    "Upcoming_events_for_families__c", IIF(EMPTY(@Updatedannualpassvipoffers), 'False', 'True'),
                                    "New_rides_and_entertainment__c", IIF(EMPTY(@Updatedweeklyannouncements), 'False', 'True'),
                                    "New_food_and_restaurants__c", IIF(EMPTY(@Updatednewproductoffering), 'False', 'True'),
                                    "Hotels_and_resorts__c", IIF(EMPTY(@Updatedlatestnews), 'False', 'True'),
                                    "Customer_Survey__c",IIF(EMPTY(@UpdatedcustomerSurvey), 'False', 'True')
                                )
                                
                                
                                set @thankYouPage = '#ThankYou'
                                if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                               
                               if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.legoland.ae/ThankYou_LL_Arabic_QA?sfid=", Base64Encode(@sfid), "#ThankYou"))
                               ELSE
                                      Redirect(CONCAT(CloudPagesURL(2844),@thankYouPage))
                              ENDIF
                                

                                ENDIF
                                ENDIF
                        ]%%
            
            
   <!--channel preference block-->

   <form class="preferences-form" action="" method="post">
    <!-- Second -->
        <div class="channel radio-wrapper radio-width">
        <h4 class="pt-4 pb-3">كيف يمكننا التواصل؟</h4>
            <div class="form-check">
                <label class="form-check-label" for="emailPref">
                البريد الإلكتروني
                </label>
                <input class="form-check-input" type="checkbox" id="emailPref" name="EmailPref" %%=IIF(@emailPref =='True' ,'checked', "" )=%% >
            </div>
            <div class="form-check">
            <label class="form-check-label" for="WhatsAppPref">
                    عن طريق التطبيق واتساب.
                </label>
                <input class="form-check-input" type="checkbox" id="WhatsAppPref" name="WhatsAppPref" %%=IIF(@WhatsAppPref =='True' ,'checked', "" )=%%>
            </div>
            <div class="form-check">
                <label class="form-check-label" for="smsPref">
                    رسالة قصيرة
                </label>
                <input class="form-check-input" type="checkbox" id="smsPref" name="smsPref" 
                        %%=IIF(@smsPref=='True' ,'checked', "" )=%%>
            </div>
        </div>
   
        <div class="pref-btn mt-5">
            <button type="button" name="button" class="btn btn-orange channelPreference-btn"
                onclick="channelPreference()" id="channelPreferencess">حفظ</button>
          
          <input name="submittedChannelPref" type="hidden" value="true">
            <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br> 
        </div>
  </form>
<!-- thank you pop up -->
  <div class="box-form mt-5" id="channel-preference" style="display:none;">
   
        <span class="close-buttonCM" style="
            text-align: right;
            font-size: 30px;
            position: relative;
            right: 15px;
            top: 0;
            cursor: pointer;                                                           
            color:#ffd400;">×</span>
        <div class="container">
            <div class="unsubscribe-wrapper form group">
                <div class="thanYou-img mb-2">
                    <img src="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/738f6fca-b293-4bd7-8786-8535af6bde1b.png" alt="" class="banner-bg-img">
                </div>
                <div class="thankYou-text">

                    <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">لقد تم تحديث تفضيلات اشتراك القناة الخاصة بك بنجاح.</p>  
                  <p style="display: %%=IIF(@status == "Unsubscribed", "block", "none")=%%;font-size:16px; line-height:18px; color:#000000; font-weight: bold;padding-top: 0;">تم تحديث خيارات اشتراكك على قنوات التواصل بنجاح .إذا كنت ترغب في استلام اتصالاتنا مجددا، يرجى الاشتراك عبر <a href="https://www.dubaiparksandresorts.com/en/legoland-dubai" style=
"color:#212529;text-decoration: underline;" target="_blank">موقعنا الإلكتروني</a></p>
                </div>
            </div>
        </div>                      
    </div>
 <!-- channel preference block end -->
            
            
            <div class="mt-5 pl-2" style="font-size: 16px;">
            <p>إذا كنت ترغب في إلغاء الاشتراك من كافة منصات تواصل دبي باركس آند ريزورتس، يرجى الضغط على "إلغاء الاشتراك".</p>
            </div>
           <div class="unsrb-btn mt-5">
      <button type="button" name="button" class="btn btn-orange unsubscribe-btn"
          onclick="unsubscribeClick()" id="unsubscribeClick">إلغاء الاشتراك</button>
  </div>
   <!-- unsubscribe Reason options -->
           <div class="box-form mt-5" id="unsubscribe-reason">
               <form class="comment-form radio-wrapper radio-width" action="" method="post">
                 <span class="close-button" style="
text-align: right;
font-size: 30px;
position: relative;
left: 100%;
top: 0;
cursor: pointer;                                                           
color:#ffd400;">×</span>
                  <div class="container">
      <div class="unsubscribe-wrapper form group">
        <div class="thanYou-img mb-2">
            <img src="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/738f6fca-b293-4bd7-8786-8535af6bde1b.png" alt="" class="banner-bg-img">
        </div>
      <div class="thankYou-text">
       
            <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">لقد تم إلغاء اشتراكك بنجاح</p>  
      </div>
    
    </div>
    </div>                      
           
                   <div class="orange-notice">
                   من المؤسف أن نراك تذهب
                    </div>
                   <p style="font-size: 18px;">أخبارنا عن سبب إلغاء اشتراكك لمساعدتنا على تحسين خدماتنا</p>
                   <div class="form-check mb-2">
                       <label class="form-check-label" for="chck1">الرسائل الإلكترونية متكررة للغاية</label>
                       <input class="form-check-input" type="checkbox" id="chck1" value="False" name="unsubFreq" %%=IIF(@emailsTooFrequent =='True' ,'checked', "" )=%%>
                   </div>
                   <div class="form-check mb-2">
                   <label class="form-check-label" for="chck2">المحتوى ليس له صلة</label>
                       <input class="form-check-input" type="checkbox" id="chck2" value="False" name="unsubRelevance" %%=IIF(@contentIsNotRelevant =='True' ,'checked', "" )=%%>
                   </div>
                   <div class="form-check mb-2">
                   <label class="form-check-label" for="chck3">لست مقيماً في دبي</label>
                       <input class="form-check-input" type="checkbox" id="chck3" value="False" name="unsubNoDubai" %%=IIF(@noLongerInDubai =='True' ,'checked', "" )=%%>
                   </div>
                   <div class="form-check">
                   <label class="form-check-label" for="chck4">توقف مؤقت لمدة 30 يوما</label>
                    <input class="form-check-input" type="checkbox" id="chck4" value="False" name="unsubTemp" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                </div>
                   <div class="form-check mt-2">
                   <label class="form-check-label" for="myCheck1">أسباب أخرى (يرجى تحديد السبب)</label>
                       <input class="form-check-input" type="checkbox" id="myCheck1" value="False"
                           onclick="addbox1()" name="unsubOther" %%=IIF(@otherSpecify =='True' ,'checked', "" )=%%>
                   </div>
                   <textarea name="nameReason" rows="6" cols="80" id="area1"
                       class="form-control mt-3" value="%%=v(@reasonForUnsub)=%%" placeholder="Tell us more">%%=v(@reasonForUnsub)=%%</textarea>
                    
                   <div class="com-btn mt-5">
                    <button type="submit" class="btn btn-orange"id="communications-submitbtn" name="button">حفظ</button>
      <input name="submittedUnsub" type="hidden" value="true">
                               <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br> 
                </div>
             </form>
                   %%[
             
                                IF RequestParameter("submittedUnsub")==true then
                                    SET @sfid = RequestParameter("crmId")
                                    SET @guestId = RequestParameter("guestId")

                                    SET @unsubTempBox = RequestParameter("unsubTemp")
                                    SET @unsubFreqBox = RequestParameter("unsubFreq")
                                    SET @unsubRelevanceBox = RequestParameter("unsubRelevance")
                                    SET @unsubNoDubaiBox = RequestParameter("unsubNoDubai")
                                    SET @unsubOtherBox = RequestParameter("unsubOther")
                                    SET @unsubOtherComments = RequestParameter("nameReason")
                                    SET @currentDate = Now()

                                    IF NOT Empty(@sfid) THEN
                                    
                                    IF NOT Empty(@unsubTempBox) THEN
                                    
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Temporary_Pause_30_Days__c", 'true',
                                    "Emails_are_too_frequent__c",'false',
                                    "Content_isn_t_relevant__c",'false',
                                    "I_m_no_longer_in_Dubai__c",'false',
                                    "Other_Please_specify__c",'false',
                                    "fieldsToNull","Reason_of_Unsubscribe__c",
                                    "Status__c", "Subscribed",
                                    "Offers_and_Promotions__c","True",
                                    "Upcoming_events_for_families__c","True",
                                    "New_rides_and_entertainment__c","True",
                                    "New_food_and_restaurants__c","True",
                                    "Hotels_and_resorts__c","True",
                                    "Customer_Survey__c","True",
                                    "Email__c","True",
                                    "WhatsApp__c","True",
                                    "SMS__c","True",
                                    )
                                    
                                    ENDIF
                                    
                                    IF Empty(@unsubTempBox) THEN
                                    

                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Temporary_Pause_30_Days__c", IIF(Empty(@unsubTempBox), 'false', 'true'),
                                    "Emails_are_too_frequent__c", IIF(Empty(@unsubFreqBox), 'false', 'true'),
                                    "Content_isn_t_relevant__c",IIF(Empty(@unsubRelevanceBox), 'false', 'true'),
                                    "I_m_no_longer_in_Dubai__c", IIF(Empty(@unsubNoDubaiBox), 'false', 'true'),
                                    "Other_Please_specify__c", IIF(Empty(@unsubOtherBox), 'false', 'true'),
                                    "Reason_of_Unsubscribe__c", @unsubOtherComments,
                                    "Status__c", "Unsubscribed"
                                    )
                                    ENDIF
                                   
                                   SET @contactRows = RetrieveSalesforceObjects("Contact", "Email", "Id", "=", @sfid)
                                IF RowCount(@contactRows) == 1 then
                                   SET @contactRow = Row(@contactRows, 1)
                                   SET @emailContact = Field(@contactRow, "Email")
                                ENDIF
                                    
                                     IF NOT Empty(@unsubTempBox) THEN
                                     SET @s = upsertData("ENT.TempPauseHandle_QA", 1, "SubscriberKey", @guestId, "Email",
                                                            @emailContact,"DateAdded",@currentDate,"ContactId",@sfid, "UnsubscribeType","Individual","Asset","LL")
                                    ENDIF
                                    
                                    
                                    IF Empty(@unsubTempBox) THEN
                                    set @rowFound = LookupRows("ENT.TempPauseHandle_QA","SubscriberKey", @guestId)
                                    set @count = rowcount(@rowFound)
                                    if @count > 0 then
                                    set @deleteCount = DeleteData("ENT.TempPauseHandle_QA","Email", @emailContact)
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Temporary_Pause_30_Days__c", IIF(Empty(@unsubTempBox), 'False', 'True'), 
                                    "Emails_are_too_frequent__c", IIF(Empty(@unsubFreqBox), 'False', 'True'),
                                    "Content_isn_t_relevant__c",IIF(Empty(@unsubRelevanceBox), 'False', 'True'),
                                    "I_m_no_longer_in_Dubai__c", IIF(Empty(@unsubNoDubaiBox), 'False', 'True'),
                                    "Other_Please_specify__c", IIF(Empty(@unsubOtherBox), 'False', 'True'),
                                    "Reason_of_Unsubscribe__c", @unsubOtherComments
                                    )
                                    /*if a sub. comes back and uncheck temp pause*/
                                    endif
                                    ENDIF
            
                                  set @thankYouPage = '#ThankYou'
                                    if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                    /*Redirect(CONCAT(CloudPagesURL(2844),@thankYouPage))*/
                                    if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.legoland.ae/ThankYou_LL_Arabic_QA?sfid=", Base64Encode(@sfid), "#ThankYou"))
                                     ELSE
                                            Redirect(CONCAT(CloudPagesURL(2844),@thankYouPage))
                                    ENDIF
                                    
                                ENDIF
                                ENDIF

                        ]%%

           </div>

            <div class="mt-5 pl-2" style="font-size: 16px;">
              <p>إذا كنت ترغب في إلغاء اشتراكك من جميع رسائل التسويق لدبي القابضة للترفيه، التي تشمل جميع <a href="https://eur03.safelinks.protection.outlook.com/?url=https%3A%2F%2Fprivacy.dubaiholding.com%2Fen%2Fdata-controllers-list%2Fdubai-holding-entertainment-llc&data=05%7C02%7CFlorian.Aubat%40dhentertainment.ae%7C7a65fcdf90e541785a7e08dccb397be0%7Ceee3385e742f4e2eb130e496ed7d6a49%7C0%7C0%7C638608694981992397%7CUnknown%7CTWFpbGZsb3d8eyJWIjoiMC4wLjAwMDAiLCJQIjoiV2luMzIiLCJBTiI6Ik1haWwiLCJXVCI6Mn0%3D%7C0%7C%7C%7C&sdata=E6lS0jEueeMxMg2p79r%2FDVLTu9sUuqDypjndDyEIwZU%3D&reserved=0" style="color:#212529;text-decoration: underline;" target="_blank">علامتنا </a> التجارية، يرجى الضغط على "إلغاء الاشتراك في الكل </p></p>

            </div>
            <div class="unsrb-all-btn mt-5">
              <button type="button" name="button" class="btn btn-orange unsubscribe-all-btn" id="unsubscribeAllClick" onclick="unsubscribeAllClick()">إلغاء اشتراك الكل</button>
          </div>
          

             
                  <!-- Unsubscribe All reason options -->
           <div class="box-form mt-5" id="unsubscribe-all-reason">
             
            <form class="comment-form radio-wrapper radio-width" action="" method="post">
              <span class="close-buttonAll" style="text-align: right;font-size: 30px;position: relative;left: 100%;top: 0;cursor: pointer;color:#ffd400;">×</span>
               <div class="container">
      <div class="unsubscribe-wrapper form group">
        <div class="thanYou-img mb-2">
            <img src="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/738f6fca-b293-4bd7-8786-8535af6bde1b.png" alt="" class="banner-bg-img">
        </div>
      <div class="thankYou-text">
       
            <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">لقد تم إلغاء اشتراكك بنجاح</p>  
      </div>
    
    </div>
    </div>                      
         
                <div class="orange-notice">
                من المؤسف أن نراك تذهب

                </div>
                <p style="font-size: 18px;">أخبارنا عن سبب إلغاء اشتراكك لمساعدتنا على تحسين خدماتنا</p>
             <div class="form-check mb-2">
                       <label class="form-check-label" for="chck_1">الرسائل الإلكترونية متكررة للغاية</label>
                       <input class="form-check-input" type="checkbox" id="chck_1" value="False" name="unsubFreq" %%=IIF(@emailsTooFrequent =='True' ,'checked', "" )=%%>
                   </div>
                   <div class="form-check mb-2">
                        <label class="form-check-label" for="chck_2">المحتوى ليس له صلة</label>
                       <input class="form-check-input" type="checkbox" id="chck_2" value="False" name="unsubRelevance" %%=IIF(@contentIsNotRelevant =='True' ,'checked', "" )=%%>
                   </div>
                   <div class="form-check mb-2">
                        <label class="form-check-label" for="chck_3">لست مقيماً في دبي</label>
                       <input class="form-check-input" type="checkbox" id="chck_3" value="False" name="unsubNoDubai" %%=IIF(@noLongerInDubai =='True' ,'checked', "" )=%%>
                   </div>
                   <div class="form-check">
                   <label class="form-check-label" for="chck_4">توقف مؤقت لمدة 30 يوما</label>
                    <input class="form-check-input" type="checkbox" id="chck_4" value="False" name="unsubAllTemp" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                </div>
                   <div class="form-check mt-2">
                   <label class="form-check-label" for="myCheck_1">أسباب أخرى (يرجى تحديد السبب)</label>
                       <input class="form-check-input" type="checkbox" id="myCheck_1" value="False"
                           onclick="addbox_1()" name="unsubOther" %%=IIF(@otherSpecify =='True' ,'checked', "" )=%%>
                   </div>
                   <textarea name="nameReason" rows="6" cols="80" id="area_1"
                       class="form-control mt-3" value="%%=v(@reasonForUnsub)=%%" placeholder="Tell us more">%%=v(@reasonForUnsub)=%%</textarea>
                <div class="com-btn mt-5">
                 <button type="submit" class="btn btn-orange"id="communications-submitbtn1" name="button">حفظ</button>
<input name="unsubAll" type="hidden" value="true">
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
             </div>
               </form>
             
           %%[
                                IF RequestParameter("unsubAll") == true then
                                SET @sfid = RequestParameter("crmId")
                                SET @guestId = RequestParameter("guestId")

                                SET @unsubTempBox = RequestParameter("unsubAllTemp")
                                SET @unsubFreqBox = RequestParameter("unsubFreq")
                                SET @unsubRelevanceBox = RequestParameter("unsubRelevance")
                                SET @unsubNoDubaiBox = RequestParameter("unsubNoDubai")
                                SET @unsubOtherBox = RequestParameter("unsubOther")
                                SET @unsubOtherComments = RequestParameter("nameReason")
                                SET @currentDate = Now()
                                SET @contactRows = RetrieveSalesforceObjects("Contact", "Email", "Id", "=", @sfid)
                                IF RowCount(@contactRows) == 1 then
                                   SET @contactRow = Row(@contactRows, 1)
                                   SET @emailContact = Field(@contactRow, "Email")
                                ENDIF
                                
                                IF NOT Empty(@unsubTempBox) THEN
                                   /* Subscribe from all guest subscriptions */
                                    SET @GD = RetrieveSalesforceObjects("Guest_Subscription__c", "Id", "Contact__c", "=", @sfid)
                                    SET @GDRowCount = RowCount(@GD)

                                    IF @GDRowCount > 0 THEN
                                        FOR @i = 1 TO @GDRowCount DO
                                            SET @GDRow = Row(@GD, @i)
                                            SET @GDID = Field(@GDRow, "Id")

                                            /* Update Status__c to "Unsubscribed" */
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                                "Guest_Subscription__c", @GDID,
                                                "Temporary_Pause_30_Days__c", 'true',
                                                "Emails_are_too_frequent__c",'false',
                                                "Content_isn_t_relevant__c",'false',
                                                "I_m_no_longer_in_Dubai__c",'false',
                                                "Other_Please_specify__c",'false',
                                                "fieldsToNull","Reason_of_Unsubscribe__c",
                                                "Status__c", "Subscribed",
                                                "Email__c","True",
                                                "WhatsApp__c","True",
                                                "SMS__c","True",
                                            )
                                        NEXT @i
                                    ENDIF
                                    
                                    /*Upsert data in Temp pause*/
                                    SET @s = upsertData("ENT.TempPauseHandle_QA", 1, "SubscriberKey", @guestId, "Email", @emailContact,"DateAdded",@currentDate,"ContactId",@sfid,"UnsubscribeType","All","Asset","LL")
                                    
                                    /*Upsert data in resub DE to resubscriber contact on enterprise level*/
                                    
                                    SET @resub = upsertData("ENT.UnsubscribeHandle_QA", 1, "SubscriberKey", @sfid, "EmailAddress", @emailContact, "SubsciberStatus", "Active", "Temp_30_Days", "True","Frequency","False","Relevance","False","Not_In_Dubai","False","Other","False")
                                    /*output(concat("<br>resub: ",@resub))*/
                                    
                                      
                                 ELSE
                                 
                                    /* Unsubscribe from all guest subscriptions */
                                        SET @GD = RetrieveSalesforceObjects("Guest_Subscription__c", "Id", "Contact__c", "=", @sfid)
                                        SET @GDRowCount = RowCount(@GD)

                                        IF @GDRowCount > 0 THEN
                                            FOR @i = 1 TO @GDRowCount DO
                                                SET @GDRow = Row(@GD, @i)
                                                SET @GDID = Field(@GDRow, "Id")

                                                /* Update Status__c to "Unsubscribed" */
                                                SET @updateRecord = UpdateSingleSalesforceObject(
                                                    "Guest_Subscription__c", @GDID,
                                                    "Temporary_Pause_30_Days__c", IIF(Empty(@unsubTempBox), 'False', 'True'), 
                                                    "Emails_are_too_frequent__c", IIF(Empty(@unsubFreqBox), 'False', 'True'),
                                                    "Content_isn_t_relevant__c",IIF(Empty(@unsubRelevanceBox), 'False', 'True'),
                                                    "I_m_no_longer_in_Dubai__c", IIF(Empty(@unsubNoDubaiBox), 'False', 'True'),
                                                    "Other_Please_specify__c", IIF(Empty(@unsubOtherBox), 'False', 'True'),
                                                    "Reason_of_Unsubscribe__c", @unsubOtherComments,
                                                    "Status__c", "Unsubscribed"
                                                )
                                            NEXT @i
                                        ENDIF
                                        SET @resub = upsertData("ENT.UnsubscribeHandle_QA", 1, "SubscriberKey", @sfid, "EmailAddress", @emailContact, "Frequency", IIF(Empty(@unsubFreqBox), 'False', 'True'),"Relevance", IIF(Empty(@unsubRelevanceBox), 'False', 'True'),"Not_In_Dubai", IIF(Empty(@unsubNoDubaiBox), 'False', 'True'),"Other", IIF(Empty(@unsubOtherBox), 'False', 'True'),"Temp_30_Days","False")
                                        set @rowFound = LookupRows("ENT.TempPauseHandle_QA","SubscriberKey", @sfid)
                                        set @count = rowcount(@rowFound)
                                        if @count > 0 then
                                           set @deleteCount = DeleteData("ENT.TempPauseHandle_QA","Email", @emailContact)
                                        ENDIF
                                    
                                ENDIF
                              
                              if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                              
                              if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.legoland.ae/ThankYou_LL_Arabic_QA?sfid=", Base64Encode(@sfid), "#ThankYou"))
                                     ELSE
                                            Redirect(CONCAT(CloudPagesURL(2844),@thankYouPage))
                                    ENDIF
                              
                              
                              ENDIF

                        ]%%
             
        </div>
          
           
          
                  
          </div>
        </div>
      </div>
    </div>
<!-- loader start -->
   <div class="loader1" id="loding-wrap1">
<div class="loaderimg1">Loading...</div>
</div>
        <!-- laoder end -->     

<!-- footer start -->
  <footer>
                <div class="container">
                    <div class="row">
                        <div class="col-lg-3 col-md-3 col-sm-12 col-12">
                             <a alias="DPR_link" class="logo-footer"href="https://www.dubaiparksandresorts.com/en" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/4e7abcfd-4466-4353-b1fe-03e7b1ea36ee.png"></a>
                        </div>
                        <div class="col-lg-2 col-md-2 col-sm-12 col-12 custom-height">
                            <h4>معلومات</h4>
                            <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                                <p><a alias="BuyTickets" href="https://www.dubaiparksandresorts.com/en/booking/tickets" target="_blank">شراء التذاكر</a></p>
                            </div>
                            <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                                <p><a alias="AnnualPass" href="https://www.dubaiparksandresorts.com/en/booking/annual-pass#594" target="_blank">تذكرة سنوية</a></p>
                            </div>
                            <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                              <p><a alias="Offers" href="https://www.dubaiparksandresorts.com/en/booking/tickets" target="_blank">العروض</a></p>
                          </div>
                          <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                            <p><a alias="Experience" href="https://www.dubaiparksandresorts.com/en/booking/annual-pass#594" target="_blank">الخبرات</a></p>
                        </div>
                        <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                          <p><a alias="ContactUs" href="https://www.dubaiparksandresorts.com/en/contact-us" target="_blank">اتصل بنا</a></p>
                      </div>
                        </div>
                        <div class="col-lg-2 col-md-2 col-sm-12 col-12 custom-height">
                          <h4>قانوني</h4>
                          <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                              <p><a alias="Disclaimer" href="https://www.dubaiparksandresorts.com/en/terms-conditions" target="_blank">إخلاء المسؤولية</a></p>
                          </div>
                          <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                              <p><a alias="PrivacyPloicy" href="https://privacy.dubaiholding.com/privacy-notice/customers---dubai-holding-entertainment-llc" target="_blank">سياسة الخصوصية</a></p>
                          </div>
                          <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                            <p><a alias="TermsAndCondition" href="https://www.dubaiparksandresorts.com/en/terms-conditions" target="_blank">الشروط والأحكام</a></p>
                        </div>
                        <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                          <p><a alias="CookiePolicy" href="https://www.dubaiparksandresorts.com/en/cookie-policy" target="_blank">إشعار ملفات تعريف الارتباط</a></p>
                      </div>
                      <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                        <p><a alias="CopyrightAndTrademark" href="https://www.dubaiparksandresorts.com/en/copyright-trademark" target="_blank">حقوق الطبع والنشر والعلامة التجارية</a></p>
                    </div>
                      </div>
                      <div class="col-lg-2 col-md-2 col-sm-12 col-12 custom-height">
                        <h4>مكافآت تيكيت</h4>
                        <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                            <p><a alias="Tickit_iOS" href="https://apps.apple.com/us/app/tickit-rewards/id1597908032?_branch_match_id=1053619853588783593&utm_source=Tickit&utm_medium=Website&_branch_referrer=H4sIAAAAAAAAA8soKSkottLXL8lMzs4s0UssKNDLyczL1g8B8%2BPDU5OKM0tS412c4jP9gwHIgL%2FmLQAAAA%3D%3D" target="_blank">تحميل تيكيت لنظام iOS</a></p>
                        </div>
                        <div class="col-lg-12 col-md-12 col-sm-12 col-12">
                            <p> <a alias="Tickit_Android" href="https://play.google.com/store/apps/details?id=ae.tickit.primary&_branch_match_id=1053619853588783593&utm_source=Tickit&utm_medium=Website&_branch_referrer=H4sIAAAAAAAAA8soKSkottLXL8lMzs4s0UssKNDLyczL1g8B8%2BPDU5OKM0tS412c4h3zUoryM1MAFKNCBjEAAAA%3D&pli=1" target="_blank">تحميل تيكيت لنظام أندرويد</a></p>
                        </div>
                      
                    </div>
                        <div class="col-lg-3 col-md-3 col-sm-12 col-12">
                            
                            <ul class="social-media-ul">
                               <li><a alias="fb" conversion="false" data-linkto="https://" href="https://www.facebook.com/LEGOLANDDubai" target="_blank" title=""><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/90185405-937c-4d2f-b4ce-2fb03eea25af.png"></a>
                                </li>
                                <li> <a alias="Insta" conversion="false" data-linkto="https://" href="https://www.instagram.com/legolanddubai/" target="_blank" title=""><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/63c4ca71-5917-4a09-a0b5-b19cddb9a796.png"></a>

                                </li>
                                <li> <a alias="Tiktok" conversion="false" data-linkto="https://" href="https://www.tiktok.com/@legolanddubai?_t=8mAnKyaBuLq&_r=1" target="_blank" title=""><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/68336ff0-6304-4b6b-ab54-4191ce055806.png"></a>

                                </li>
                                <li class="youtube"> <a alias="Youtube" conversion="false" data-linkto="https://" href="https://www.youtube.com/c/legolanddubai" target="_blank" title=""><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/834b098b-afd8-41eb-bfe1-2e6faadc1fdf.png" ></a>
                                </li>
                               
                            </ul>
                        </div>
                    </div>
                    <div class="row footer-row-2">
                      <div class="col-lg-8 col-md-8 col-sm-12 col-12 ">
                        <p style="color: rgb(238, 238, 238); font-size: 10px; font-family: Arial, Helvetica, sans-serif; font-weight: normal;  text-align: left;line-height:12px">
                        ©2024 مجموعة LEGO. جميع الحقوق محفوظة. ©2024 DWA LLC. جميع الحقوق محفوظة. ©2024 CPII. جميع الحقوق محفوظة.©2024 SPAI. جميع الحقوق محفوظة. ©2024 GHI. الفيلم © 2024 Lions Gate Ent. Inc. جميع الحقوق محفوظة.© متنزهات ومنتجعات دبي 2024. جميع الحقوق محفوظة.</p>
                      </div>
                    <div class="col-lg-2 col-md-2 col-sm-12 col-12 custom-height">
                      <h4>شركاء فخورون</h4>
                      <ul class="proud-partners">
                      <li class="pp">
                        <img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/0cd6669a-0b94-46ef-b812-aa4db9ab5160.png" style="width: 25px;" width="25">
                      </li>
                      <li class="pp">
                        <img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/9510b497-9225-48b5-8da7-353c3e067265.png" style="width: 25px;" width="25">
                      </li>
                      <li class="pp">
                        <img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/098b4878-065f-4be8-9d42-03ae2e2b1b00.png" style="width: 27px;" width="27">
                      </li>
                    </ul>
                  </div>
               
                  <div class="col-lg-2 col-md-2 col-sm-12 col-12 custom-height">
                   
                    <ul class="tripadvisor">
                    <li>
                      <a alias="TripadvisorMG" conversion="false" data-linkto="https://" target="_blank"> <img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/5c4e9b8b-9a5f-43f2-bf78-29e35774d5c9.png"></a>
                    </li>
                    <li>
                      <a alias="TripadvisorLL" conversion="false" data-linkto="https://"  target="_blank"> <img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/3b3680f0-21b8-4724-afc3-40578cd3165c.png"></a>
                    </li>
                   
                  </ul>
                </div>
                    </div>
                    <hr style="border-top: 1px solid #fff;">
                    <div class="row business-units">
                      <div class="col-lg-2 col-md-2 col-sm-4 col-4 ">
                        <a alias="Motiongate" href="https://www.dubaiparksandresorts.com/en/discover/motiongate/zones" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/80e21d4a-8015-4a88-8e53-9b6a8a2589f6.png"></a>
                      </div>
                      <div class="col-lg-2 col-md-2 col-sm-4 col-4 ">
                        <a alias="realmadrid" href="https://www.dubaiparksandresorts.com/en/realmadridworld" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/3ddd3b78-7e49-43f9-9977-680b228951d4.png" ></a>
                      </div>
                      <div class="col-lg-2 col-md-2 col-sm-4 col-4 ">
                        <a alias="Legoland" href="https://www.dubaiparksandresorts.com/en/discover/legoland/zones" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/a3fb0c99-87d8-4e23-ba20-31b4fb4350a3.png" ></a>
                      </div>
                      <div class="col-lg-2 col-md-2 col-sm-4 col-4 ">
                        <a alias="RiverLand" href="https://www.dubaiparksandresorts.com/en/discover/riverland/zones" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/127b8eec-1fde-4ccb-8930-2944082d420e.png" ></a>
                      </div>
                      <div class="col-lg-2 col-md-2 col-sm-4 col-4 ">
                        <a alias="NeonGalaxy" href="https://www.dubaiparksandresorts.com/en/discover/neongalaxy/zones" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/4032e27f-d4fe-48f8-8b0d-1832651bba8b.png" ></a>
                      </div>
                      <div class="col-lg-2 col-md-2 col-sm-4 col-4 ">
                        <a alias="Jumpx" href="https://www.dubaiparksandresorts.com/en/jumpx" target="_blank"><img alt="" data-assetid="" src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/37fbc2d9-e6f9-462b-adad-c6f7aa7f6703.png" ></a>
                      </div>
                    </div>
                </div>
            </footer>
      <!-- footer End -->                     
    <!-- Vendor JS-->
     <script src="https://cloud.explore.legoland.ae/LL_bootstrap_Arabic_QA.min.js"></script>
    <script src="https://cloud.explore.legoland.ae/LL_select2_Arabic_QA.min.js"></script>
    <script src="https://cloud.explore.legoland.ae/LL_moment_Arabic_QA.min.js"></script>
  

    <!-- Main JS-->
    <script src="https://cloud.explore.legoland.ae/LL_custom_Arabic_QA.js"></script>
   
  <script>
  $("#profileCountry").select2();
                          </script>
                           <script>
      $( document ).ready(function() {
    $('#customRange3').on('input', function(){
         v = $('#customRange3').val();
         console.log(v);
         $('div.price').text(v);
    });
});
function ShowHideDivkids() {
    var chkYes = document.getElementById("kids");
    var dvKids = document.getElementById("dvKids");
    dvKids.style.display = chkYes.checked ? "block" : "none";
  
  }
    </script>
    <script>
    $(".birthkid").daterangepicker();
 $("#numOfKids").change(function() {
    var numOfKids = parseInt($(this).val());
    handleNumOfKidsChange(numOfKids);
    if(numOfKids=='0'){
      $(".disclaimer").css("display","none")
    }
 });

function handleNumOfKidsChange(numOfKids) {
    var existingRows = $("#kidsTable .row").length;
    if (numOfKids > existingRows) {
       $(".disclaimer").css("display", "block");
      for (var i = existingRows; i < numOfKids; i++) {
        $("#kidsTable").append(`
        <div class="row"><div class="col-lg-4 col-md-4 col-sm-12 col-12">
                           <div class="form-group">
                        <label for="">اسم الطفل</label>
                        <input type="text" id="kidsName${i}" name="kidsName${i}" value=""
                            class="form-control nameKids" />
                    </div>
                          </div>
                            <div class="col-lg-3 col-md-3 col-sm-12 col-12">
                      <div class="form-group">
                        <label class="label">تاريخ ميلاد الطفل</label>
                        <div class="bdate">
                          <input class="form-control" type="date"  name="kids-birthday${i}" id="kids-birthday${i}"  value="" class="kbday">
                
                
                      </div>
                    
                      </div>
                  </div>
                

                          <div class="col-lg-3 col-md-3 col-sm-12 col-12">
                            <div class="form-group">
                              <label for="">جنس الطفل</label>
                              <div class="select-wrapper">
                                <select class="form-control" name="gender${i}" id="gender${i}">
                                  <option value="">اختر</option>
                                  <option value="Male">ذكر</option>
                                  <option value="Female">أنثى</option>
                           
                                </select>
                                
                              </div>
                            </div>
                            
                          </div><div class="col-lg-2 col-md-2 col-sm-12 col-12"><button class="btn btn-primary del" id="${i}" value="" onclick="kidsDeletion(this);">حذف</button></div></div>
        `);
        //Future date restricting Validation


    var today = new Date().toJSON().slice(0, 10);
    var date = $('input[type=date]');
    date.attr('max', today);
    
      }
      $(".birthkid").each(function() {
      var daterangepicker = $(this).data("daterangepicker");
      if (daterangepicker) {
        daterangepicker.remove();
      }
        
       

      $(this).daterangepicker({
        opens: "top",
        maxDate: moment(),
            "singleDatePicker": true,
            "showDropdowns": true,
            "autoUpdateInput": false,
            locale: {
                format: 'DD/MM/YYYY'
            },
        }); // Reinitialize daterangepicker for all fields with 'daterange' class
    });
    } else if (numOfKids < existingRows) {
      for (var i = existingRows; i > numOfKids; i--) {
        $("#kidsTable .row:last-child").remove();
     
      }
    }
    //if(numOfKids > 0){
    //$(".nameKids").attr("required",true);
  //}
}


    </script>
                          
                      
                          
                          
                          
                          <script>
        
      function kidsPrepopulation(){
        console.log('inside fun08')
        var rowCount = document.getElementById('numOfKids').value; 
        console.log('row count - ' , rowCount)
        for(var i=0;i<=rowCount; i++){
          if(document.getElementById('kidName'+i) && document.getElementById('kidsName'+i)){
            document.getElementById('kidsName'+i).value = document.getElementById('kidName'+i).value;
          }
          if(document.getElementById('kids-birthday'+i) && document.getElementById('kidDOB'+i)){
            document.getElementById('kids-birthday'+i).value = document.getElementById('kidDOB'+i).value;
          }
          if(document.getElementById('kidGen'+i) && document.getElementById('gender'+i)){
            document.getElementById('gender'+i).value = document.getElementById('kidGen'+i).value;
          }
          if(document.getElementById('del'+i) && document.getElementById(i)){
            document.getElementById(i).value = document.getElementById('del'+i).value;
          }


        }
      }
// Get today's date in the format YYYY-MM-DD
function getToday() {
  const today = new Date();
  const year = today.getFullYear();
  let month = today.getMonth() + 1;
  let day = today.getDate();

  // Add leading zero if month or day is less than 10
  if (month < 10) {
    month = `0${month}`;
  }
  if (day < 10) {
    day = `0${day}`;
  }

  return `${year}-${month}-${day}`;
}

// Set the max attribute of the date input to today's date
document.getElementById('birthday').setAttribute('max', getToday());
 $('.kbday').attr('max', getToday());

// Delete row functionality
$(document).on("click", ".del", function() {
  var rowIndex = $(this).data("rowindex");
  console.log('deleted');
  /*var attrName = $(this).attr('name').substr(-1);
  console.log(attrName);
    $("#kidName".concat(attrName)).remove();
    $("#kidDOB".concat(attrName)).remove();
    $("#kidGen".concat(attrName)).remove();
    $("#kidRecId".concat(attrName)).remove();*/
  

  $(this).closest(".row").remove();
  console.log('deleted 1');
  // Update the numOfKids dropdown value after changes
  $("#numOfKids").val($("#kidsTable .row").length).trigger('change');
  console.log('deleted 2');
 
});
    </script>
                          
                                <script>
                          
                            var deletedKidsListArr = '';
                             function kidsDeletion(param){
                               var subsKey = document.getElementById('crmId').value;
                               var numOfKids = document.getElementById('numOfKids').value;
                                  console.log("numOfKids:------- ",numOfKids)
                               var id = param.id;
                               console.log("Deleted Kid Id:------- ",id)
                               var idFromHidden = document.getElementById('deletedKid'+ id).value;
                               document.getElementById(id).value = idFromHidden;
                               deletedKidsListArr = idFromHidden 
                            var counter=1
                               for(i=0; i<numOfKids; i++){
                                 console.log("loops -----------: ",i)
                                 if(i>=id){
                                   
                                   if(i ==  (numOfKids-1) && id==i){
                                     console.log("inside last -----------: ",i)
                                     document.getElementById('kidName'+ id).remove();
                                     document.getElementById('kidDOB'+ id).remove();
                                     document.getElementById('kidGen'+ id).remove();
                                     document.getElementById('kidRecId'+ id).remove();
                                     document.getElementById('deletedKid'+ id).remove();
                                   }
                                   else{
                                     console.log("counter===", counter);
                                   if(i<(numOfKids-1)){
                                   //For HTML Elements
                                           var nextElementName = document.getElementById('kidsName'+ counter); 
                                           nextElementName.id = 'kidsName' + i;
                                           nextElementName.name = 'kidsName' + i;

                                           var nextElementBirthday = document.getElementById('kids-birthday'+ counter); 
                                           nextElementBirthday.id = 'kids-birthday' + i;
                                           nextElementBirthday.name = 'kids-birthday' + i;

                                           var nextElementGender = document.getElementById('gender'+ counter); 
                                           nextElementGender.id = 'gender' + i;
                                           nextElementGender.name = 'gender' + i;

                                           var nextElementDelButton = document.getElementById(counter); 
                                           nextElementDelButton.id = i;
                                   }
                                   //For hidden pre-population elements
                                   
                                   
                                   //This should only work once when var i and deleted id are equal
                                   if(i==id){
                                     console.log("inside last ifffffff -----------: ",i)
                                     document.getElementById('kidName'+ id).remove();
                                     document.getElementById('kidDOB'+ id).remove();
                                     document.getElementById('kidGen'+ id).remove();
                                     document.getElementById('kidRecId'+ id).remove();
                                     document.getElementById('deletedKid'+ id).remove();
                                   }
                                   
                                   //Update ids of hidden elements
                                     if(i<(numOfKids-1)){
                                         var hiddenElementName = document.getElementById('kidName'+ counter); 
                                         hiddenElementName.id = 'kidName' + i;
                                         hiddenElementName.name = 'kidName' + i;

                                         var hiddenElementBirthday = document.getElementById('kidDOB'+ counter); 
                                         hiddenElementBirthday.id = 'kidDOB' + i;
                                         hiddenElementBirthday.name = 'kidDOB' + i;

                                         var hiddenElementGender = document.getElementById('kidGen'+ counter); 
                                         hiddenElementGender.id = 'kidGen' + i;
                                         hiddenElementGender.name = 'kidGen' + i;

                                         var hiddenElementKidRecId = document.getElementById('kidRecId' + counter); 
                                         hiddenElementKidRecId.id = 'kidRecId' + i;
                                         hiddenElementKidRecId.name = 'kidRecId' + i;

                                         var hiddenElementDeletedKid = document.getElementById('deletedKid' + counter); 
                                         hiddenElementDeletedKid.id = 'deletedKid' + i;
                                         hiddenElementDeletedKid.name = 'deletedKid' + i;
                                     }
                                   }
                                 }
                                 counter++;
                               }
                var dataToSend = {
                    arr: deletedKidsListArr,
                    subskey: subsKey,
                    numOfKids: numOfKids
                };

                $.ajax({
                    url: 'https://cloud.explore.legoland.ae/LL_KidsDelete_Arabic_QA', // Replace with your CloudPage URL
                    method: 'POST',
                    data: dataToSend,
                    success: function(response) {
                        console.log('SFMC Code Resource called successfully.');
                        console.log('Response:', response);
                        // Handle success response here
                    },
                    error: function(xhr, status, error) {
                        console.error('Error calling SFMC Code Resource.');
                        console.error('Status:', status);
                        console.error('Error:', error);
                        // Handle error here
                    }
                });
                            }
                          </script>
                          <script>
      function updateUrlHash(hash) {
        if (history.pushState) {
          history.pushState(null, null, hash);
        } else {
          location.hash = hash;
        }
      }
        
      var hashvalue = window.location.hash;
         console.log("hash==",hash);
         var value= hash.split("&");
         var hash=value[0];
         console.log("hash=====",hash);
      hash && $('ul.nav a[href="' + hash + '"]').tab('show');
    
      $('.nav-tabs a').click(function (e) {
        $(this).tab('show');
        var scrollmem = $('body').scrollTop();
        window.location.hash = this.hash;
        $('html,body').scrollTop(scrollmem);
      });
                            
                            
                            
                            //To call channel management code from BU resource
      $("#channelPreferencess").click(function(e) {
        console.log('Inside channel management()')
        var guestId = document.getElementById('guestId').value;
        var subsKey = document.getElementById('crmId').value;
         var emailPref = document.getElementById('emailPref');
        var whatsAppPref = document.getElementById('WhatsAppPref');
        var smsPref = document.getElementById('smsPref');
        var fName = document.getElementById('firstName').value;
        var lName = document.getElementById('lname').value;
        var gEmail = document.getElementById('email').value;
        console.log('emailPref: ',emailPref.checked);
        console.log('whatsAppPref: ',whatsAppPref.checked);
    /* if( emailPref.checked !='undefined'){
         var emailPref = 'False';
         console.log('emailPref----===----: ');
        }
        else{
           var emailPref = 'True';
        }
        if( whatsAppPref.checked!='undefined'){
          var whatsAppPref = 'False';
          
        }
        else{
           var whatsAppPref = 'True';
        }*/
         console.log('emailPref---------: ',emailPref.checked);
        console.log('whatsAppPref---------: ',whatsAppPref.checked);
        console.log('guestId: ',guestId);
        console.log('subsKey: ',subsKey);
        console.log('emailPref: ',emailPref);
        console.log('whatsAppPref: ',whatsAppPref);
                var dataToSend = {
                    guestId: guestId,
                    subsKey: subsKey,
                    firstName: fName,
                    lastName: lName,
                    email: gEmail,
                    emailPref: emailPref.checked,
                    whatsAppPref: whatsAppPref.checked,
                     smsPref : smsPref.checked
                };

                $.ajax({
                    url: 'https://cloud.explore.legoland.ae/LL_Arabic_QA_ChannelPreference', // Replace with your CloudPage URL
                    method: 'POST',
                    data: dataToSend,
                    success: function(response) {
                        console.log('SFMC channel management Code Resource called successfully.');
                        console.log('Response:', response);
                        // Handle success response here
                    },
                    error: function(xhr, status, error) {
                        console.error('Error calling SFMC channel management Code Resource.');
                        console.error('Status:', status);
                        console.error('Error=========:', error);
                        // Handle error here
                    }
                });
            });
                
                            
                            
                            
      
      //To call unsub code from BU resource by Bhavya
      $("#unsubscribeClick").click(function(e) {
        console.log('Inside unsubscribeClick()')
        var guestId = document.getElementById('guestId').value;
        var subsKey = document.getElementById('crmId').value;

                var dataToSend = {
                    guestId: guestId,
                    subsKey: subsKey
                };

                $.ajax({
                    url: 'https://cloud.explore.legoland.ae/LL_UnsubscribeFromBU_Arabic_QA', // Replace with your CloudPage URL
                    method: 'POST',
                    data: dataToSend,
                    success: function(response) {
                        console.log('SFMC Code Resource called successfully.');
                        console.log('Response:', response);
                        // Handle success response here
                    },
                    error: function(xhr, status, error) {
                        console.error('Error calling SFMC Code Resource.');
                        console.error('Status:', status);
                        console.error('Error:', error);
                        // Handle error here
                    }
                });
            });
      
      $("#unsubscribeAllClick").click(function(e) {
        console.log('Inside unsubscribeAllClick()')
        var subsKey = document.getElementById('crmId').value;
        var guestId = document.getElementById('guestId').value;

                var dataToSend = {
                    guestId: guestId,
                    subsKey: subsKey
                };

                $.ajax({
                    url: 'https://cloud.explore.legoland.ae/LL_UnsubscribeFromAllBU_Arabic_QA', // Replace with your CloudPage URL
                    method: 'POST',
                    data: dataToSend,
                    success: function(response) {
                        console.log('SFMC Code Resource called successfully.');
                        console.log('Response:', response);
                        // Handle success response here
                    },
                    error: function(xhr, status, error) {
                        console.error('Error calling SFMC Code Resource.');
                        console.error('Status:', status);
                        console.error('Error:', error);
                        // Handle error here
                    }
                });
            });
    
      </script>
    
                         
                                </body>
                            </html>