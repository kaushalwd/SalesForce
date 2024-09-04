
<!--ampscript starts-->

%%[
    var @numOfKids
    /*SET @crmIdEn = "0036M00004ZS6Y4QAL"
    SET @crmIdEn = QueryParameter("sfid")*/
    /* output(concat("<br>crmIdEn: ",@crmIdEn)) 
    SET @crmId = Base64Decode(@crmIdEn)*/
    SET @crmId = _subscriberkey
    /*output(concat("<br>crmId: ",@crmId))*/
    IF (empty(@crmId)) THEN
    SET @crmIdEn = QueryParameter("sfid")
    SET @crmId = Base64Decode(@crmIdEn)
    SET @methodType= 'Old'
    /*output(concat("<br>crmId:==== ",@crmId))*/
    IF (empty(@crmId)) THEN
      SET @crmId = RequestParameter("sfid")
      IF (empty(@crmId)) THEN
       SET @crmId = QueryParameter("sfid")
      ENDIF
     ENDIF
    ENDIF
    IF NOT Empty(@crmId) THEN
    
    /* owner - Priyanka 
    date - 14 March
    City added */
    
    SET @contactRows =
    RetrieveSalesforceObjects("Contact",
    "Salutation,FirstName,LastName,Email,Phone,Country_Code__c,BirthDate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,No_of_Kids__c,GenderIdentity,MailingCity,Do_you_have_kids__c",
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
    SET @GuestDetails = RetrieveSalesforceObjects("Guest_Subscription__c","Asset__c, Id,Email__c,WhatsApp__c,What_are_your_preferred_movie_genres__c,What_is_your_preferred_cinema_hall__c,What_is_your_preferred_cinema_experience__c,Preferred_date_time_to_watch_movies__c,Group_size_with_which_you_visit_RC_usual__c,Promotional_Offers_and_Deal__c,Annual_Pass_VIP_Offers_News_and_Info__c,Weekly_Announcements_and_News__c,New_Product_Offering_Announcements__c,Latest_news_about_other_DHE_parks__c,Customer_Survey__c,Emails_are_too_frequent__c,Content_isn_t_relevant__c,I_m_no_longer_in_Dubai__c,Temporary_Pause_30_Days__c,
    Other_Please_specify__c,Reason_of_Unsubscribe__c",
    "Contact__c", "=", @crmId,"Asset__c","=","Roxy Cinemas","Sub_Asset__c","=","Roxy Cinemas")
     
    SET @guestDetailsRowCount = Rowcount(@GuestDetails)
    IF @guestDetailsRowCount > 0 THEN /*Roxy*/
    
        SET @guestDetailsRow = Row(@GuestDetails, 1)
        SET @assetType = Field(@guestDetailsRow, "Asset__c")
        SET @Id = Field(@guestDetailsRow, "Id")
        set @emailPref = Field(@guestDetailsRow, "Email__c")
        set @WhatsAppPref = Field(@guestDetailsRow, "WhatsApp__c")
        set @preferredmoviegenres = Field(@guestDetailsRow, "What_are_your_preferred_movie_genres__c")
        set @preferredcinemahall = Field(@guestDetailsRow, "What_is_your_preferred_cinema_hall__c")
        set @preferredcinemaexperience = Field(@guestDetailsRow, "What_is_your_preferred_cinema_experience__c")
        set @preferreddatetimetowatchmovies = Field(@guestDetailsRow, "Preferred_date_time_to_watch_movies__c")
        set @typicalgroupsize = Field(@guestDetailsRow, "Group_size_with_which_you_visit_RC_usual__c")
        set @promotionaloffersdeals = Field(@guestDetailsRow, "Promotional_Offers_and_Deal__c")
        set @annualpassvipoffers = Field(@guestDetailsRow, "Annual_Pass_VIP_Offers_News_and_Info__c")
        set @weeklyannouncements= Field(@guestDetailsRow, "Weekly_Announcements_and_News__c")
        set @newproductoffering = Field(@guestDetailsRow, "New_Product_Offering_Announcements__c")
        set @latestnews = Field(@guestDetailsRow, "Latest_news_about_other_DHE_parks__c")
        set @customerSurvey = Field(@guestDetailsRow, "Customer_Survey__c")
        set @emailsTooFrequent = Field(@guestDetailsRow, "Emails_are_too_frequent__c")
        set @contentIsNotRelevant = Field(@guestDetailsRow, "Content_isn_t_relevant__c")
        set @noLongerInDubai = Field(@guestDetailsRow, "I_m_no_longer_in_Dubai__c")
        set @tempPause = Field(@guestDetailsRow, "Temporary_Pause_30_Days__c")
        set @otherSpecify = Field(@guestDetailsRow, "Other_Please_specify__c")
        set @reasonForUnsub = Field(@guestDetailsRow, "Reason_of_Unsubscribe__c")
        
        
     
    
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
        var city = Platform.Request.GetFormField('city') || "";
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
        
        //console.log("listCustomer: ",listCustomer);
        var unsubscribe = Platform.Request.GetFormField('submittedUnsub') || false;

        var listOfInput = [];
    listOfInput.push({Name : 'Roxy Cinemas - Offers and Promotions', Status: listpromotions })
  listOfInput.push({Name : 'Roxy Cinemas - Plus,Annual Pass,VIP Offers,News', Status: listannualpass })
  listOfInput.push({Name : 'Roxy Cinemas - Weekly, Bi-weekly Announcements', Status: listweeklyannouncements})
        listOfInput.push({Name : 'Roxy Cinemas - New Product,Offering Announcements', Status: listnewproductoffering})
        listOfInput.push({Name : 'Roxy Cinemas - Latest news about other DHE parks', Status: listlatestnews})
        listOfInput.push({Name : 'Roxy Cinemas - Customer Survey', Status: listCustomer})
 
  
  

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
                        "Country of Residence": profileCountry,
                        "City of Residence": city
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
                  /* Nitik 06th Mar24, added the code for resubscribing to all the publication list of current Bu */
                var resubAll = {
                  "SubscriberKey": subscriberKey,
                  "Lists": {
                    "ID": '63',
                    "Action": "Update"
                  },
                  "Status": "Active"
                };
                var subObj = Subscriber.Init(subscriberKey);
                var status = subObj.Update(resubAll);

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
                        <html>
                            <head><meta name="ROBOTS" content="INDEX,FOLLOW"><meta name="keywords" content=""><meta name="description" content="">
                              <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
 <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                                <title>Roxy Cinemas Dubai</title>
 <link rel="icon" type="image/x-icon" href="https://image.explore.globalvillage.ae/lib/fe3511737364047c7c1571/m/1/53dcf053-1dc2-484c-a770-2ffbf46b39bd.png">
                                <link href='https://cloud.explore.theroxycinemas.com/roxyqa_bootstrap.min.css' rel='stylesheet'>
                                
                                <script type='text/javascript' src='https://cloud.explore.theroxycinemas.com/roxyqa_jquery.min.js'></script>
                             
                                <!-- Font special for pages-->
                                <link href="https://fonts.googleapis.com/css?family=Poppins:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i,800,800i,900,900i" rel="stylesheet">
                                <link href="https://cloud.explore.theroxycinemas.com/roxyqa_style.css" rel="stylesheet">
                                
                              
                               
                                <!-- Vendor CSS-->
                                <link href="https://cloud.explore.theroxycinemas.com/roxyqa_select2min.css" rel="stylesheet" media="all">
                                <!-- <link href="https://cloud.explore.globalvillage.ae/daterangepicker_dpr_dev" rel="stylesheet" media="all"> -->
                                <style>
/* nav */
.card {
  max-width: 90rem;
  padding: 0;
  border: none;
  border-radius: 0.5rem;
}


.nav-link {
  color: #343838;
    font-weight: 700;
    background: white;
    margin: 0 5px;
    font-size: 16px;
}
.nav-link:hover {
  color:#ce5a5e
}

.nav-pills .nav-link.active {
  color: #fff;
    background-color: #ce5a5e !important;
 
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
  Platform.Response.SetResponseHeader("Content-Security-Policy","script-src 'self' 'unsafe-inline' https://image.explore.theroxycinemas.com https://cloud.explore.globalvillage.ae; frame-ancestors 'none'");
</script>
                                </head>
                          
            <body onload="handleNumOfKidsChange(%%=v(@numOfKids)=%%); kidsPrepopulation(); ShowHideDivkids();">
              
                                   <!-- Header start -->
        <header>
          <div class="container">
              <div class="row align-items-center" style="margin: 0 auto;">
                  <div class="col-lg-8 col-md-8 col-sm-8 col-8">
                      <a href="https://www.theroxycinemas.com/" class="logo-link" target="_blank">
                          <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/1bf2be87-c4e8-42e1-b02b-3e7250c91045.png"
                              alt="logo">
                      </a>
                  </div>
                  <div class="col-lg-4 col-md-4 col-sm-4 col-4">

                  <a href="https://dubaiholding.com/en/who-we-are/our-companies/dubai-holding-entertainment/" class="logo-link" target="_blank">
                      <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/dc021595-6370-4bf0-b6e7-6fb034df7ac8.png"
                          alt="logo-dhe" class="pull-right dhe-logo">
                  </a>

                  </div>
              </div>
          </div>
      </header>
      <!-- Header End --><section class="banner">
                                  <div class="main-banner">
                                    <img src= "https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/8f75698e-c26d-4a85-a775-12277994ce57.jpg" alt="banner-img" class="responsive">
                                        </div>
                                        <div class="container">
                                          <h1 class="username">Hi %%=v(ProperCase(@firstName))=%% </h1>
                                      </div>
                                      </section>
                                 <div class="container card content-wrapper">
      <!-- nav options -->
      <ul class="nav nav-pills mb-3 d-flex justify-content-center" id="pills-tab" role="tablist">
        <li class="nav-item">
          <a class="nav-link active" id="my-profile-tab" data-toggle="pill" href="#my-profile" role="tab" aria-controls="my-profile" aria-selected="true"onclick="updateUrlHash('#my-profile')"> MY PROFILE</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" id="interests-tab" data-toggle="pill" href="#interests" role="tab" aria-controls="interests" aria-selected="false" onclick="updateUrlHash('#interests')">INTERESTS</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" id="communications-tab" data-toggle="pill" href="#communications" role="tab" aria-controls="communications" aria-selected="false" onclick="updateUrlHash('#communications')">COMMUNICATIONS</a>
        </li>
      </ul>

      <!-- content -->
      <div class="tab-content" id="pills-tabContent p-3">
        <!-- 1st card -->
        <div class="tab-pane fade show active" id="my-profile" role="tabpanel" aria-labelledby="my-profile-tab">
          <div class="wrapper wrapper--w1200">
            
            <form class="profile-form" action="" method="post" name="myForm" id="profile-form" autocomplete="off">
              <h4 class="pt-4 pb-4">Tell us about yourself</h4>
              <div class="row">
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">Title (Mr./Ms./Mrs.)</label>
                          <div class="select-wrapper hide-icon">
                              <select class="form-control" name="profileSalutation">
                                <option value=" " %%=IIF(@title=='' ,'selected', "" )=%%>Select</option>
                                  <option value="Mr." %%=IIF(@title=='Mr.' ,'selected', "" )=%%>Mr.  
                                  </option>
                                  <option value="Ms." %%=IIF(@title=='Ms.' ,'selected', "" )=%%>Ms.
                                  </option>
                                  <option value="Mrs." %%=IIF(@title=='Mrs.' ,'selected', "" )=%%>Mrs.
                                  </option>
                              </select>
                              
               
                          </div>
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">First Name<sup class="text-danger">*</sup></label>
                          <input type="text" id="firstName" name="firstName" id="fname" value="%%=v(ProperCase(@firstName))=%%"
                              class="form-control" required aria-required="true" />
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group">
                          <label for="">Last Name<sup class="text-danger">*</sup></label>
                          <input type="text" id="lname" name="lastName" value="%%=v(ProperCase(@lastName))=%%"
                              class="form-control" required aria-required="true" />
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">Email Address<sup class="text-danger">*</sup></label>
                          <input type="email" id="email" name="email" value="%%=v(@email)=%%"
                              class="form-control" required aria-required="true" />
                      </div>
                  </div>
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12 phone_num">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">Phone<sup class="text-danger">*</sup></label>
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
                <!--Nitik 05th Mar24, Hidden field to store Deleted Kids IDs-->
                <input class="form-control" type="hidden" name="DeletedKidsId"  value="" id="DeletedKidsId">
                  

                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">Country of Residence<sup class="text-danger">*</sup></label>
                          <div class="select-wrapper hide-icon profilecountry">
  
                              <select class="form-control" name="profileCountry" id="profileCountry" required>
                                <option value="">Select Country</option>
                             <option value="Afghanistan" %%=IIF(@country=='Afghanistan', "selected", "")=%% >Afghanistan</option>
                              <option value="Aland Islands" %%=IIF(@country=='Aland Islands', 'selected', "")=%%>Aland Islands</option>
                              <option value="Albania" %%=IIF(@country=='Albania', "selected", "")=%%>Albania</option>
                              <option value="Algeria" %%=IIF(@country=='Algeria', "selected", "")=%%>Algeria</option>
                              <option value="American Samoa" %%=IIF(@country=='American Samoa', "selected", "")=%%>American Samoa</option>
                              <option value="Andorra" %%=IIF(@country=='Andorra', "selected", "")=%%>Andorra</option>
                              <option value="Angola" %%=IIF(@country=='Angola', "selected", "")=%%>Angola</option>
                              <option value="Anguilla" %%=IIF(@country=='Anguilla', "selected", "")=%%>Anguilla</option>
                              <option value="Antarctica" %%=IIF(@country=='Antarctica', "selected", "")=%%>Antarctica</option>
                              <option value="Antigua And Barbuda" %%=IIF(@country=='Antigua And Barbuda', "selected", "")=%%>Antigua And Barbuda</option>
                              <option value="Argentina" %%=IIF(@country=='Argentina', "selected", "")=%%>Argentina</option>
                              <option value="Armenia" %%=IIF(@country=='Armenia', "selected", "")=%%>Armenia</option>
                              <option value="Aruba" %%=IIF(@country=='Aruba', "selected", "")=%%>Aruba</option>
                              <option value="Australia" %%=IIF(@country=='Australia', "selected", "")=%%>Australia</option>
                              <option value="Austria" %%=IIF(@country=='Austria', "selected", "")=%%>Austria</option>
                              <option value="Azerbaijan" %%=IIF(@country=='Azerbaijan', "selected", "")=%%>Azerbaijan</option>
                              <option value="Bahamas The" %%=IIF(@country=='Bahamas The', "selected", "")=%%>Bahamas The</option>
                              <option value="Bahrain" %%=IIF(@country=='Bahrain', "selected", "")=%%>Bahrain</option>
                              <option value="Bangladesh" %%=IIF(@country=='Bangladesh', "selected", "")=%%>Bangladesh</option>
                              <option value="Barbados" %%=IIF(@country=='Barbados', "selected", "")=%%>Barbados</option>
                              <option value="Belarus" %%=IIF(@country=='Belarus', "selected", "")=%%>Belarus</option>
                              <option value="Belgium" %%=IIF(@country=='Belgium', "selected", "")=%%>Belgium</option>
                              <option value="Belize" %%=IIF(@country=='Belize', "selected", "")=%%>Belize</option>
                              <option value="Benin" %%=IIF(@country=='Benin', "selected", "")=%%>Benin</option>
                              <option value="Bermuda" %%=IIF(@country=='Bermuda', "selected", "")=%%>Bermuda</option>
                              <option value="Bhutan" %%=IIF(@country=='Bhutan', "selected", "")=%%>Bhutan</option>
                              <option value="Bolivia" %%=IIF(@country=='Bolivia', "selected", "")=%%>Bolivia</option>
                              <option value="Bonaire Sint Eustatius and Saba" %%=IIF(@country=='Bonaire Sint Eustatius and Saba', "selected", "")=%%>Bonaire, Sint Eustatius
                                  and Saba</option>
                              <option value="Bosnia and Herzegovina" %%=IIF(@country=='Bosnia and Herzegovina', "selected", "")=%%>Bosnia and Herzegovina</option>
                              <option value="Botswana"  %%=IIF(@country=='Botswana', "selected", "")=%%>Botswana</option>
                              <option value="Bouvet Island" %%=IIF(@country=='Bouvet Island', "selected", "")=%%>Bouvet Island</option>
                              <option value="Brazil" %%=IIF(@country=='Brazil', "selected", "")=%%>Brazil</option>
                              <option value="British Indian Ocean Territory" %%=IIF(@country=='British Indian Ocean Territory', "selected", "")=%%>British Indian Ocean
                                  Territory</option>
                              <option value="Brunei" %%=IIF(@country=='Brunei', "selected", "")=%%>Brunei</option>
                              <option value="Bulgaria" %%=IIF(@country=='Bulgaria', "selected", "")=%%>Bulgaria</option>
                              <option value="Burkina Faso" %%=IIF(@country=='Burkina Faso', "selected", "")=%%>>Burkina Faso</option>
                              <option value="Burundi" %%=IIF(@country=='Burundi', "selected", "")=%%>Burundi</option>
                              <option value="Cambodia" %%=IIF(@country=='Cambodia', "selected", "")=%%>Cambodia</option>
                              <option value="Cameroon" %%=IIF(@country=='Cameroon', "selected", "")=%%>Cameroon</option>
                              <option value="Canada" %%=IIF(@country=='Canada', "selected", "")=%%>Canada</option>
                              <option value="Cape Verde" %%=IIF(@country=='Cape Verde', "selected", "")=%%>Cape Verde</option>
                              <option value="Cayman Islands" %%=IIF(@country=='Cayman Islands', "selected", "")=%%>Cayman Islands</option>
                              <option value="Central African Republic" %%=IIF(@country=='Central African Republic', selected, "")=%%>Central African Republic
                              </option>
                              <option value="Chad" %%=IIF(@country=='Chad', "selected", "")=%%>Chad</option>
                              <option value="Chile" %%=IIF(@country=='Chile', "selected", "")=%%>Chile</option>
                              <option value="China" %%=IIF(@country=='China', "selected", "")=%%>China</option>
                              <option value="Christmas Island" %%=IIF(@country=='Christmas Island', "selected", "")=%%>Christmas Island</option>
                              <option value="Cocos (Keeling) Islands" %%=IIF(@country=='Cocos (Keeling) Islands', "selected", "")=%%>Cocos (Keeling) Islands</option>
                              <option value="Colombia" %%=IIF(@country=='Colombia', "selected", "")=%%>Colombia</option>
                              <option value="Comoros" %%=IIF(@country=='Comoros', "selected", "")=%%>Comoros</option>
                              <option value="Congo" %%=IIF(@country=='Congo', "selected", "")=%%>Congo</option>
                              <option value="Congo The Democratic Republic Of The" %%=IIF(@country=='Congo The Democratic Republic Of The', "selected", "")=%%>Congo The
                                  Democratic Republic Of The</option>
                              <option value="Cook Islands" %%=IIF(@country=='Cook Islands', "selected", "")=%%>Cook Islands</option>
                              <option value="Costa Rica" %%=IIF(@country=='Costa Rica', "selected", "")=%%>Costa Rica</option>
                              <option value="Cote D'Ivoire (Ivory Coast)" %%=IIF(@country=="Cote D'Ivoire (Ivory Coast)", "selected", "")=%%>Cote D'Ivoire (Ivory Coast)
                              </option>
                              <option value="Croatia (Hrvatska)" %%=IIF(@country=='Croatia (Hrvatska)', "selected", "")=%%>Croatia (Hrvatska)</option>
                              <option value="Cuba" %%=IIF(@nationality=='Cuba', "selected", "")=%%>Cuba</option>
                              <option value="CuraÃ§ao" %%=IIF(@country=='CuraÃ§ao', "selected", "")=%%>CuraÃ§ao</option>
                              <option value="Cyprus" %%=IIF(@country=='Cyprus', "selected", "")=%%>Cyprus</option>
                              <option value="Czech Republic" %%=IIF(@country=='Czech Republic', "selected", "")=%%>Czech Republic</option>
                              <option value="Denmark" %%=IIF(@country=='Denmark', "selected", "")=%%>Denmark</option>
                              <option value="Djibouti" %%=IIF(@country=='Djibouti', "selected", "")=%%>Djibouti</option>
                              <option value="Dominica" %%=IIF(@country=='Dominica', "selected", "")=%%>Dominica</option>
                              <option value="Dominican Republic" %%=IIF(@country=='Dominican Republic', "selected", "")=%%>Dominican Republic</option>
                              <option value="East Timor" %%=IIF(@country=='East Timor', "selected", "")=%%>East Timor</option>
                              <option value="Ecuador" %%=IIF(@country=='Ecuador', "selected", "")=%%>Ecuador</option>
                              <option value="Egypt" %%=IIF(@country=='Egypt', "selected", "")=%%>Egypt</option>
                              <option value="El Salvador" %%=IIF(@country=='El Salvador', "selected", "")=%%>El Salvador</option>
                              <option value="Equatorial Guinea" %%=IIF(@country=='Equatorial Guinea', "selected", "")=%%>Equatorial Guinea</option>
                              <option value="Eritrea" %%=IIF(@country=='Eritrea', "selected", "")=%%>Eritrea</option>
                              <option value="Estonia"  %%=IIF(@country=='Estonia', "selected", "")=%%>Estonia</option>
                              <option value="Ethiopia" %%=IIF(@country=='Ethiopia', "selected", "")=%%>Ethiopia</option>
                              <option value="Falkland Islands" %%=IIF(@country=='Falkland Islands', "selected", "")=%%>Falkland Islands</option>
                              <option value="Faroe Islands" %%=IIF(@country=='Faroe Islands', "selected", "")=%%>Faroe Islands</option>
                              <option value="Fiji Islands" %%=IIF(@country=='Fiji Islands', "selected", "")=%%>Fiji Islands</option>
                              <option value="Finland" %%=IIF(@country=='Finland', "selected", "")=%%>Finland</option>
                              <option value="France" %%=IIF(@country=='France', "selected", "")=%%>France</option>
                              <option value="French Guiana" %%=IIF(@country=='French Guiana', "selected", "")=%%>French Guiana</option>
                              <option value="French Polynesia" %%=IIF(@country=='French Polynesia', "selected", "")=%%>French Polynesia</option>
                              <option value="French Southern Territories" %%=IIF(@country=='French Southern Territories', "selected", "")=%%>French Southern Territories
                              </option>
                              <option value="Gabon" %%=IIF(@country=='Gabon', "selected", "")=%%>Gabon</option>
                              <option value="Gambia The" %%=IIF(@country=='Gambia The', "selected", "")=%%>Gambia The</option>
                              <option value="Georgia" %%=IIF(@country=='Georgia', "selected", "")=%%>Georgia</option>
                              <option value="Germany" %%=IIF(@country=='Germany', "selected", "")=%%>Germany</option>
                              <option value="Ghana" %%=IIF(@country=='Ghana', "selected", "")=%%>Ghana</option>
                              <option value="Gibraltar" %%=IIF(@country=='Gibraltar', "selected", "")=%%>Gibraltar</option>
                              <option value="Greece" %%=IIF(@country=='Greece', "selected", "")=%%>Greece</option>
                              <option value="Greenland" %%=IIF(@country=='Greenland', "selected", "")=%%>Greenland</option>
                              <option value="Grenada" %%=IIF(@country=='Grenada', "selected", "")=%%>Grenada</option>
                              <option value="Guadeloupe" %%=IIF(@country=='Guadeloupe', "selected", "")=%%>Guadeloupe</option>
                              <option value="Guam"  %%=IIF(@country=='Guam', "selected", "")=%%>Guam</option>
                              <option value="Guatemala" %%=IIF(@country=='Guatemala', "selected", "")=%%>Guatemala</option>
                              <option value="Guernsey and Alderney" %%=IIF(@country=='Guernsey and Alderney', "selected", "")=%%>Guernsey and Alderney</option>
                              <option value="Guinea" %%=IIF(@country=='Guinea', "selected", "")=%%>Guinea</option>
                              <option value="Guinea-Bissau" %%=IIF(@country=='Guinea-Bissau', "selected", "")=%%>Guinea-Bissau</option>
                              <option value="Guyana" %%=IIF(@country=='Guyana', "selected", "")=%%>Guyana</option>
                              <option value="Haiti" %%=IIF(@country=='Haiti', "selected", "")=%%>Haiti</option>
                              <option value="Heard Island and McDonald Islands" %%=IIF(@country=='Heard Island and McDonald Islands', "selected", "")=%%>Heard Island and
                                  McDonald Islands</option>
                              <option value="Honduras" %%=IIF(@country=='Honduras', "selected", "")=%%>Honduras</option>
                              <option value="Hong Kong S.A.R." %%=IIF(@country=='Hong Kong S.A.R.', "selected", "")=%%>Hong Kong S.A.R.</option>
                              <option value="Hungary" %%=IIF(@country=='Hungary', "selected", "")=%%>Hungary</option>
                              <option value="Iceland" %%=IIF(@country=='Iceland', "selected", "")=%%>Iceland</option>
                              <option value="India"  %%=IIF(@country=='India', "selected", "")=%%>India</option>
                              <option value="Indonesia" %%=IIF(@country=='Indonesia', "selected", "")=%%>Indonesia</option>
                              <option value="Iran" %%=IIF(@country=='Iran', "selected", "")=%%>Iran</option>
                              <option value="Iraq" %%=IIF(@country=='Iraq', "selected", "")=%%>Iraq</option>
                              <option value="Ireland" %%=IIF(@country=='Ireland', "selected", "")=%%>Ireland</option>
                              <option value="Israel" %%=IIF(@country=='Israel', "selected", "")=%%>Israel</option>
                              <option value="Italy" %%=IIF(@country=='Italy', "selected", "")=%%>Italy</option>
                              <option value="Jamaica" %%=IIF(@country=='Jamaica', "selected", "")=%%>Jamaica</option>
                              <option value="Japan" %%=IIF(@country=='Japan', "selected", "")=%%>Japan</option>
                              <option value="Jersey" %%=IIF(@country=='Jersey', "selected", "")=%%>Jersey</option>
                              <option value="Jordan" %%=IIF(@country=='Jordan', "selected", "")=%%>Jordan</option>
                              <option value="Kazakhstan" %%=IIF(@country=='Kazakhstan', "selected", "")=%%>Kazakhstan</option>
                              <option value="Kenya"  %%=IIF(@country=='Kenya', "selected", "")=%%>Kenya</option>
                              <option value="Kiribati" %%=IIF(@country=='Kiribati', "selected", "")=%%>Kiribati</option>
                              <option value="Korea North" %%=IIF(@country=='Korea North', "selected", "")=%%>Korea North</option>
                              <option value="Korea South" %%=IIF(@country=='Korea South', "selected", "")=%%>Korea South</option>
                              <option value="Kosovo" %%=IIF(@country=='Kosovo', "selected", "")=%%>Kosovo</option>
                              <option value="Kuwait" %%=IIF(@country=='Kuwait', "selected", "")=%%>Kuwait</option>
                              <option value="Kyrgyzstan" %%=IIF(@country=='Kyrgyzstan', "selected", "")=%%>Kyrgyzstan</option>
                              <option value="Laos"  %%=IIF(@country=='Laos', "selected", "")=%%>Laos</option>
                              <option value="Latvia" %%=IIF(@country=='Latvia', 'selected', "")=%%>Latvia</option>
                              <option value="Lebanon" %%=IIF(@country=='Lebanon', "selected", "")=%%>Lebanon</option>
                              <option value="Lesotho" %%=IIF(@country=='Lesotho', "selected", "")=%%>Lesotho</option>
                              <option value="Liberia" %%=IIF(@country=='Liberia', "selected", "")=%%>Liberia</option>
                              <option value="Libya" %%=IIF(@country=='Libya', "selected", "")=%%>Libya</option>
                              <option value="Liechtenstein" %%=IIF(@country=='Liechtenstein', "selected", "")=%%>Liechtenstein</option>
                              <option value="Lithuania" %%=IIF(@country=='Lithuania', "selected", "")=%%>Lithuania</option>
                              <option value="Luxembourg" %%=IIF(@country=='Luxembourg', "selected", "")=%%>Luxembourg</option>
                              <option value="Macau S.A.R." %%=IIF(@country=='Macau S.A.R.', "selected", "")=%%>Macau S.A.R.</option>
                              <option value="Macedonia" %%=IIF(@country=='Macedonia', "selected", "")=%%>Macedonia</option>
                              <option value="Madagascar"  %%=IIF(@country=='Madagascar', "selected", "")=%%>Madagascar</option>
                              <option value="Malawi" %%=IIF(@country=='Malawi', "selected", "")=%%>Malawi</option>
                              <option value="Malaysia" %%=IIF(@country=='Malaysia', 'selected', "")=%%>Malaysia</option>
                              <option value="Maldives" %%=IIF(@country=='Maldives', "selected", "")=%%>Maldives</option>
                              <option value="Mali" %%=IIF(@country=='Mali', "selected", "")=%%>Mali</option>
                              <option value="Malta" %%=IIF(@country=='Malta', "selected", "")=%%>Malta</option>
                              <option value="Man (Isle of)" %%=IIF(@country=='Man (Isle of)', "selected", "")=%%>Man (Isle of)</option>
                              <option value="Marshall Islands" %%=IIF(@country=='Marshall Islands', "selected", "")=%%>Marshall Islands</option>
                              <option value="Martinique" %%=IIF(@country=='Martinique', "selected", "")=%%>Martinique</option>
                              <option value="Mauritania" %%=IIF(@country=='Mauritania', "selected", "")=%%>Mauritania</option>
                              <option value="Mauritius" %%=IIF(@country=='Mauritius', "selected", "")=%%>Mauritius</option>
                              <option value="Mayotte" %%=IIF(@country=='Mayotte', "selected", "")=%%>Mayotte</option>
                              <option value="Mexico" %%=IIF(@country=='Mexico', "selected", "")=%%>Mexico</option>
                              <option value="Micronesia" %%=IIF(@country=='Micronesia', "selected", "")=%%>Micronesia</option>
                              <option value="Moldova" %%=IIF(@country=='Moldova', "selected", "")=%%>Moldova</option>
                              <option value="Monaco" %%=IIF(@country=='Monaco', "selected", "")=%%>Monaco</option>
                              <option value="Mongolia" %%=IIF(@country=='Mongolia', "selected", "")=%%>Mongolia</option>
                              <option value="Montenegro" %%=IIF(@country=='Montenegro', "selected", "")=%%>Montenegro</option>
                              <option value="Montserrat"  %%=IIF(@country=='Montserrat', "selected", "")=%%>Montserrat</option>
                              <option value="Morocco" %%=IIF(@country=='Morocco', "selected", "")=%%>Morocco</option>
                              <option value="Mozambique" %%=IIF(@country=='Mozambique', "selected", "")=%%>Mozambique</option>
                              <option value="Myanmar" %%=IIF(@country=='Myanmar', "selected", "")=%%>Myanmar</option>
                              <option value="Namibia" %%=IIF(@country=='Namibia', "selected", "")=%%>Namibia</option>
                              <option value="Nauru" %%=IIF(@country=='Nauru', "selected", "")=%%>Nauru</option>
                              <option value="Nepal" %%=IIF(@country=='Nepal', "selected", "")=%%>Nepal</option>
                              <option value="Netherlands The" %%=IIF(@country=='Netherlands The', "selected", "")=%%>Netherlands The</option>
                              <option value="New Caledonia" %%=IIF(@country=='New Caledonia', "selected", "")=%%>New Caledonia</option>
                              <option value="New Zealand" %%=IIF(@country=='New Zealand', "selected", "")=%%>New Zealand</option>
                              <option value="Nicaragua" %%=IIF(@country=='Nicaragua', "selected", "")=%%>Nicaragua</option>
                              <option value="Niger" %%=IIF(@country=='Niger', "selected", "")=%%>Niger</option>
                              <option value="Nigeria" %%=IIF(@country=='Nigeria', "selected", "")=%%>Nigeria</option>
                              <option value="Niue" %%=IIF(@country=='Niue', "selected", "")=%%>Niue</option>
                              <option value="Norfolk Island" %%=IIF(@country=='Norfolk Island', "selected", "")=%%>Norfolk Island</option>
                              <option value="Northern Mariana Islands" %%=IIF(@country=='Northern Mariana Islands', "selected", "")=%%>Northern Mariana Islands
                              </option>
                              <option value="Norway" %%=IIF(@country=='Norway', "selected", "")=%%>Norway</option>
                              <option value="Oman" %%=IIF(@country=='Oman', "selected", "")=%%>Oman</option>
                              <option value="Pakistan" %%=IIF(@country=='Pakistan', "selected", "")=%%>Pakistan</option>
                              <option value="Palau" %%=IIF(@country=='Palau', "selected", "")=%%>Palau</option>
                              <option value="Palestinian Territory Occupied" %%=IIF(@country=='Palestinian Territory Occupied', "selected", "")=%%>Palestinian Territory
                                  Occupied</option>
                              <option value="Panama" %%=IIF(@country=='Panama', "selected", "")=%%>Panama</option>
                              <option value="Papua new Guinea" %%=IIF(@country=='Papua new Guinea', "selected", "")=%%>Papua new Guinea</option>
                              <option value="Paraguay" %%=IIF(@country=='Paraguay', "selected", "")=%%>Paraguay</option>
                              <option value="Peru" %%=IIF(@country=='Peru', "selected", "")=%%>Peru</option>
                              <option value="Philippines" %%=IIF(@country=='Philippines', "selected", "")=%%>Philippines</option>
                              <option value="Pitcairn Island" %%=IIF(@country=='Pitcairn Island', "selected", "")=%%>Pitcairn Island</option>
                              <option value="Poland" %%=IIF(@country=='Poland', "selected", "")=%%>Poland</option>
                              <option value="Portugal" %%=IIF(@country=='Portugal', "selected", "")=%%>Portugal</option>
                              <option value="Puerto Rico" %%=IIF(@country=='Puerto Rico', "selected", "")=%%>Puerto Rico</option>
                              <option value="Qatar" %%=IIF(@country=='Qatar', "selected", "")=%%>Qatar</option>
                              <option value="Reunion" %%=IIF(@country=='Reunion', "selected", "")=%%>Reunion</option>
                              <option value="Romania" %%=IIF(@country=='Romania', "selected", "")=%%>Romania</option>
                              <option value="Russia" %%=IIF(@country=='Russia', "selected", "")=%%>Russia</option>
                              <option value="Rwanda"  %%=IIF(@country=='Rwanda', "selected", "")=%%>Rwanda</option>
                              <option value="Saint Helena" %%=IIF(@country=='Saint Helena', "selected", "")=%%>Saint Helena</option>
                              <option value="Saint Kitts And Nevis" %%=IIF(@country=='Saint Kitts And Nevis', "selected", "")=%%>Saint Kitts And Nevis</option>
                              <option value="Saint Lucia" %%=IIF(@country=='Saint Lucia', "selected", "")=%%>Saint Lucia</option>
                              <option value="Saint Pierre and Miquelon"  %%=IIF(@country=='Saint Pierre and Miquelon', "selected", "")=%%>Saint Pierre and Miquelon
                              </option>
                              <option value="Saint Vincent And The Grenadines" %%=IIF(@country=='Saint Vincent And The Grenadines', "selected", "")=%%>Saint Vincent And The
                                  Grenadines</option>
                              <option value="Saint-Barthelemy" %%=IIF(@country=='Saint-Barthelemy', "selected", "")=%%>Saint-Barthelemy</option>
                              <option value="Saint-Martin (French part)" %%=IIF(@country=='Saint-Martin (French part)', "selected", "")=%%>Saint-Martin (French part)
                              </option>
                              <option value="Samoa" %%=IIF(@country=='Samoa', "selected", "")=%%>Samoa</option>
                              <option value="San Marino" %%=IIF(@country=='San Marino', "selected", "")=%%>San Marino</option>
                              <option value="Sao Tome and Principe" %%=IIF(@country=='Sao Tome and Principe', "selected", "")=%%>Sao Tome and Principe</option>
                              <option value="Saudi Arabia" %%=IIF(@country=='Saudi Arabia', "selected", "")=%%>Saudi Arabia</option>
                              <option value="Senegal" %%=IIF(@country=='Senegal', "selected", "")=%%>Senegal</option>
                              <option value="Serbia" %%=IIF(@country=='Serbia', "selected", "")=%%>Serbia</option>
                              <option value="Seychelles" %%=IIF(@country=='Seychelles', "selected", "")=%%>Seychelles</option>
                              <option value="Sierra Leone" %%=IIF(@country=='Sierra Leone', "selected", "")=%%>Sierra Leone</option>
                              <option value="Singapore" %%=IIF(@country=='Singapore', "selected", "")=%%>Singapore</option>
                              <option value="Sint Maarten (Dutch part)" %%=IIF(@country=='Sint Maarten (Dutch part)', "selected", "")=%%>Sint Maarten (Dutch part)
                              </option>
                              <option value="Slovakia" %%=IIF(@country=='Slovakia', "selected", "")=%%>Slovakia</option>
                              <option value="Slovenia" %%=IIF(@country=='Slovenia', "selected", "")=%%>Slovenia</option>
                              <option value="Solomon Islands" %%=IIF(@country=='Solomon Islands', "selected", "")=%%>Solomon Islands</option>
                              <option value="Somalia" %%=IIF(@country=='Somalia', "selected", "")=%%>Somalia</option>
                              <option value="South Africa" %%=IIF(@country=='South Africa', 'selected', "")=%%>South Africa</option>
                              <option value="South Georgia" %%=IIF(@country=='South Georgia', "selected", "")=%%>South Georgia</option>
                              <option value="South Sudan" %%=IIF(@country=='South Sudan', "selected", "")=%%>South Sudan</option>
                              <option value="Spain" %%=IIF(@country=='Spain', "selected", "")=%%>Spain</option>
                              <option value="Sri Lanka" %%=IIF(@country=='Sri Lanka', "selected", "")=%%>Sri Lanka</option>
                              <option value="Sudan" %%=IIF(@country=='Sudan', "selected", "")=%%>Sudan</option>
                              <option value="Suriname" %%=IIF(@country=='Suriname', "selected", "")=%%>Suriname</option>
                              <option value="Svalbard And Jan Mayen Islands" %%=IIF(@country=='Svalbard And Jan Mayen Islands', "selected", "")=%%>Svalbard And Jan Mayen
                                  Islands</option>
                              <option value="Swaziland" %%=IIF(@country=='Swaziland', "selected", "")=%%>Swaziland</option>
                              <option value="Sweden" %%=IIF(@country=='Sweden', "selected", "")=%%>Sweden</option>
                              <option value="Switzerland" %%=IIF(@country=='Switzerland', "selected", "")=%%>Switzerland</option>
                              <option value="Syria" %%=IIF(@country=='Syria', "selected", "")=%%>Syria</option>
                              <option value="Taiwan" %%=IIF(@country=='Taiwan', "selected", "")=%%>Taiwan</option>
                              <option value="Tajikistan" %%=IIF(@country=='Tajikistan', "selected", "")=%%>Tajikistan</option>
                              <option value="Tanzania" %%=IIF(@country=='Tanzania', "selected", "")=%%>Tanzania</option>
                              <option value="Thailand" %%=IIF(@country=='Thailand', "selected", "")=%%>Thailand</option>
                              <option value="Togo" %%=IIF(@country=='Togo', "selected", "")=%%>Togo</option>
                              <option value="Tokelau" %%=IIF(@country=='Tokelau', "selected", "")=%%>Tokelau</option>
                              <option value="Tonga" %%=IIF(@country=='Tonga', "selected", "")=%%>Tonga</option>
                              <option value="Trinidad And Tobago" %%=IIF(@country=='Trinidad And Tobago', "selected", "")=%%>Trinidad And Tobago</option>
                              <option value="Tunisia" %%=IIF(@country=='Tunisia', "selected", "")=%%>Tunisia</option>
                              <option value="Turkey"  %%=IIF(@country=='Turkey', "selected", "")=%%>Turkey</option>
                              <option value="Turkmenistan" %%=IIF(@country=='Turkmenistan', "selected", "")=%%>Turkmenistan</option>
                              <option value="Turks And Caicos Islands" %%=IIF(@country=='Turks And Caicos Islands', "selected", "")=%%>Turks And Caicos Islands
                              </option>
                              <option value="Tuvalu" %%=IIF(@country=='Tuvalu', "selected", "")=%%>Tuvalu</option>
                              <option value="Uganda" %%=IIF(@country=='Uganda', "selected", "")=%%>Uganda</option>
                              <option value="Ukraine" %%=IIF(@country=='Ukraine', "selected", "")=%%>Ukraine</option>
                              <option value="United Arab Emirates" %%=IIF(@country=='United Arab Emirates', "selected", "")=%%>United Arab Emirates</option>
                              <option value="United Kingdom" %%=IIF(@country=='United Kingdom', "selected", "")=%%>United Kingdom</option>
                              <option value="United States" %%=IIF(@country=='United States', "selected", "")=%%>United States</option>
                              <option value="United States Minor Outlying Islands" %%=IIF(@country=='United States Minor Outlying Islands', "selected", "")=%%>United States Minor
                                  Outlying Islands</option>
                              <option value="Uruguay" %%=IIF(@country=='Uruguay', "selected", "")=%%>Uruguay</option>
                              <option value="Uzbekistan" %%=IIF(@country=='Uzbekistan', "selected", "")=%%>Uzbekistan</option>
                              <option value="Vanuatu" %%=IIF(@country=='Vanuatu', "selected", "")=%%>Vanuatu</option>
                              <option value="Vatican City State (Holy See)" %%=IIF(@country=='Vatican City State (Holy See)', "selected", "")=%%>Vatican City State (Holy
                                  See)</option>
                              <option value="Venezuela" %%=IIF(@country=='Venezuela', "selected", "")=%%>Venezuela</option>
                              <option value="Vietnam" %%=IIF(@country=='Vietnam', "selected", "")=%%>Vietnam</option>
                              <option value="Virgin Islands (British)" %%=IIF(@country=='Virgin Islands (British)', "selected", "")=%%>Virgin Islands (British)
                              </option>
                              <option value="Virgin Islands (US)" %%=IIF(@country=='Virgin Islands (US)', "selected", "")=%%>Virgin Islands (US)</option>
                              <option value="Wallis And Futuna Islands" %%=IIF(@country=='Wallis And Futuna Islands', "selected", "")=%%>Wallis And Futuna Islands
                              </option>
                              <option value="Western Sahara" %%=IIF(@country=='Western Sahara', "selected", "")=%%>Western Sahara</option>
                              <option value="Yemen" %%=IIF(@country=='Yemen', "selected", "")=%%>Yemen</option>
                              <option value="Zambia" %%=IIF(@country=='Zambia', "selected", "")=%%>Zambia</option>
                              <option value="Zimbabwe" %%=IIF(@country=='Zimbabwe', "selected", "")=%%>Zimbabwe</option>
  
  
  
                     </select>
                   
                          </div>
                      </div>
                  </div>

                 <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group">
                        <label for="">City (<b>UAE Residents only</b>)</label>
                        <div class="select-wrapper hide-icon custom-">

                          <!-- Priyanka 14 March, added ampscript for city -->
                             <select class="form-control" name="City" id="city">
                               <option value="" %%=IIF(@city=='', "selected", "")=%% selected>Select City</option>
                               <option value="Ajman" %%=IIF(@city=='Ajman', "selected", "")=%%>Ajman</option>
                               <option value="Abu Dhabi" %%=IIF(@city=='Abu Dhabi', "selected", "")=%%>Abu Dhabi</option>
                               <option value="Fujairah" %%=IIF(@city=='Fujairah', "selected", "")=%%>Fujairah</option>
                               <option value="Dubai" %%=IIF(@city=='Dubai', "selected", "")=%%>Dubai</option>
                               <option value="Ras Al Khaimah" %%=IIF(@city=='Ras Al Khaimah', "selected", "")=%%>Ras Al Khaimah</option>
                               <option value="Sharjah" %%=IIF(@city=='Sharjah', "selected", "")=%%>Sharjah</option>
                               <option value="Umm AL Quwain" %%=IIF(@city=='Umm AL Quwain', "selected", "")=%%>Umm AL Quwain</option>
                            </select>
                         
                        </div>
                    </div>
                </div>
                
                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group" data-aos="fade-up"
                        data-aos-anchor-placement="bottom-bottom">
                        <label for="">Nationality (<b>UAE Residents only</b>)</label>
                        <div class="select-wrapper hide-icon">
                          <select class="form-control" name="profileNationality" id="nationality">
                            <option value="">Select Nationality</option>
                              <option value="Afghanistan" %%=IIF(@nationality=='Afghanistan', "selected", "")=%% >Afghanistan</option>
                              <option value="Aland Islands" %%=IIF(@nationality=='Aland Islands', 'selected', "")=%%>Aland Islands</option>
                              <option value="Albania" %%=IIF(@nationality=='Albania', "selected", "")=%%>Albania</option>
                              <option value="Algeria" %%=IIF(@nationality=='Algeria', "selected", "")=%%>Algeria</option>
                              <option value="American Samoa" %%=IIF(@nationality=='American Samoa', "selected", "")=%%>American Samoa</option>
                              <option value="Andorra" %%=IIF(@nationality=='Andorra', "selected", "")=%%>Andorra</option>
                              <option value="Angola" %%=IIF(@nationality=='Angola', "selected", "")=%%>Angola</option>
                              <option value="Anguilla" %%=IIF(@nationality=='Anguilla', "selected", "")=%%>Anguilla</option>
                              <option value="Antarctica" %%=IIF(@nationality=='Antarctica', "selected", "")=%%>Antarctica</option>
                              <option value="Antigua And Barbuda" %%=IIF(@nationality=='Antigua And Barbuda', "selected", "")=%%>Antigua And Barbuda</option>
                              <option value="Argentina" %%=IIF(@nationality=='Argentina', "selected", "")=%%>Argentina</option>
                              <option value="Armenia" %%=IIF(@nationality=='Armenia', "selected", "")=%%>Armenia</option>
                              <option value="Aruba" %%=IIF(@nationality=='Aruba', "selected", "")=%%>Aruba</option>
                              <option value="Australia" %%=IIF(@nationality=='Australia', "selected", "")=%%>Australia</option>
                              <option value="Austria" %%=IIF(@nationality=='Austria', "selected", "")=%%>Austria</option>
                              <option value="Azerbaijan" %%=IIF(@nationality=='Azerbaijan', "selected", "")=%%>Azerbaijan</option>
                              <option value="Bahamas The" %%=IIF(@nationality=='Bahamas The', "selected", "")=%%>Bahamas The</option>
                              <option value="Bahrain" %%=IIF(@nationality=='Bahrain', "selected", "")=%%>Bahrain</option>
                              <option value="Bangladesh" %%=IIF(@nationality=='Bangladesh', "selected", "")=%%>Bangladesh</option>
                              <option value="Barbados" %%=IIF(@nationality=='Barbados', "selected", "")=%%>Barbados</option>
                              <option value="Belarus" %%=IIF(@nationality=='Belarus', "selected", "")=%%>Belarus</option>
                              <option value="Belgium" %%=IIF(@nationality=='Belgium', "selected", "")=%%>Belgium</option>
                              <option value="Belize" %%=IIF(@nationality=='Belize', "selected", "")=%%>Belize</option>
                              <option value="Benin" %%=IIF(@nationality=='Benin', "selected", "")=%%>Benin</option>
                              <option value="Bermuda" %%=IIF(@nationality=='Bermuda', "selected", "")=%%>Bermuda</option>
                              <option value="Bhutan" %%=IIF(@nationality=='Bhutan', "selected", "")=%%>Bhutan</option>
                              <option value="Bolivia" %%=IIF(@nationality=='Bolivia', "selected", "")=%%>Bolivia</option>
                              <option value="Bonaire Sint Eustatius and Saba" %%=IIF(@nationality=='Bonaire Sint Eustatius and Saba', "selected", "")=%%>Bonaire, Sint Eustatius
                                  and Saba</option>
                              <option value="Bosnia and Herzegovina" %%=IIF(@nationality=='Bosnia and Herzegovina', "selected", "")=%%>Bosnia and Herzegovina</option>
                              <option value="Botswana"  %%=IIF(@nationality=='Botswana', "selected", "")=%%>Botswana</option>
                              <option value="Bouvet Island" %%=IIF(@nationality=='Bouvet Island', "selected", "")=%%>Bouvet Island</option>
                              <option value="Brazil" %%=IIF(@nationality=='Brazil', "selected", "")=%%>Brazil</option>
                              <option value="British Indian Ocean Territory" %%=IIF(@nationality=='British Indian Ocean Territory', "selected", "")=%%>British Indian Ocean
                                  Territory</option>
                              <option value="Brunei" %%=IIF(@nationality=='Brunei', "selected", "")=%%>Brunei</option>
                              <option value="Bulgaria" %%=IIF(@nationality=='Bulgaria', "selected", "")=%%>Bulgaria</option>
                              <option value="Burkina Faso" %%=IIF(@nationality=='Burkina Faso', "selected", "")=%%>>Burkina Faso</option>
                              <option value="Burundi" %%=IIF(@nationality=='Burundi', "selected", "")=%%>Burundi</option>
                              <option value="Cambodia" %%=IIF(@nationality=='Cambodia', "selected", "")=%%>Cambodia</option>
                              <option value="Cameroon" %%=IIF(@nationality=='Cameroon', "selected", "")=%%>Cameroon</option>
                              <option value="Canada" %%=IIF(@nationality=='Canada', "selected", "")=%%>Canada</option>
                              <option value="Cape Verde" %%=IIF(@nationality=='Cape Verde', "selected", "")=%%>Cape Verde</option>
                              <option value="Cayman Islands" %%=IIF(@nationality=='Cayman Islands', "selected", "")=%%>Cayman Islands</option>
                              <option value="Central African Republic" %%=IIF(@nationality=='Central African Republic', selected, "")=%%>Central African Republic
                              </option>
                              <option value="Chad" %%=IIF(@nationality=='Chad', "selected", "")=%%>Chad</option>
                              <option value="Chile" %%=IIF(@nationality=='Chile', "selected", "")=%%>Chile</option>
                              <option value="China" %%=IIF(@nationality=='China', "selected", "")=%%>China</option>
                              <option value="Christmas Island" %%=IIF(@nationality=='Christmas Island', "selected", "")=%%>Christmas Island</option>
                              <option value="Cocos (Keeling) Islands" %%=IIF(@nationality=='Cocos (Keeling) Islands', "selected", "")=%%>Cocos (Keeling) Islands</option>
                              <option value="Colombia" %%=IIF(@nationality=='Colombia', "selected", "")=%%>Colombia</option>
                              <option value="Comoros" %%=IIF(@nationality=='Comoros', "selected", "")=%%>Comoros</option>
                              <option value="Congo" %%=IIF(@nationality=='Congo', "selected", "")=%%>Congo</option>
                              <option value="Congo The Democratic Republic Of The" %%=IIF(@nationality=='Congo The Democratic Republic Of The', "selected", "")=%%>Congo The
                                  Democratic Republic Of The</option>
                              <option value="Cook Islands" %%=IIF(@nationality=='Cook Islands', "selected", "")=%%>Cook Islands</option>
                              <option value="Costa Rica" %%=IIF(@nationality=='Costa Rica', "selected", "")=%%>Costa Rica</option>
                              <option value="Cote D'Ivoire (Ivory Coast)" %%=IIF(@nationality=="Cote D'Ivoire (Ivory Coast)", "selected", "")=%%>Cote D'Ivoire (Ivory Coast)
                              </option>
                              <option value="Croatia (Hrvatska)" %%=IIF(@nationality=='Croatia (Hrvatska)', "selected", "")=%%>Croatia (Hrvatska)</option>
                              <option value="Cuba" %%=IIF(@nationality=='Cuba', "selected", "")=%%>Cuba</option>
                              <option value="CuraÃ§ao" %%=IIF(@nationality=='CuraÃ§ao', "selected", "")=%%>CuraÃ§ao</option>
                              <option value="Cyprus" %%=IIF(@nationality=='Cyprus', "selected", "")=%%>Cyprus</option>
                              <option value="Czech Republic" %%=IIF(@nationality=='Czech Republic', "selected", "")=%%>Czech Republic</option>
                              <option value="Denmark" %%=IIF(@nationality=='Denmark', "selected", "")=%%>Denmark</option>
                              <option value="Djibouti" %%=IIF(@nationality=='Djibouti', "selected", "")=%%>Djibouti</option>
                              <option value="Dominica" %%=IIF(@nationality=='Dominica', "selected", "")=%%>Dominica</option>
                              <option value="Dominican Republic" %%=IIF(@nationality=='Dominican Republic', "selected", "")=%%>Dominican Republic</option>
                              <option value="East Timor" %%=IIF(@nationality=='East Timor', "selected", "")=%%>East Timor</option>
                              <option value="Ecuador" %%=IIF(@nationality=='Ecuador', "selected", "")=%%>Ecuador</option>
                              <option value="Egypt" %%=IIF(@nationality=='Egypt', "selected", "")=%%>Egypt</option>
                              <option value="El Salvador" %%=IIF(@nationality=='El Salvador', "selected", "")=%%>El Salvador</option>
                              <option value="Equatorial Guinea" %%=IIF(@nationality=='Equatorial Guinea', "selected", "")=%%>Equatorial Guinea</option>
                              <option value="Eritrea" %%=IIF(@nationality=='Eritrea', "selected", "")=%%>Eritrea</option>
                              <option value="Estonia"  %%=IIF(@nationality=='Estonia', "selected", "")=%%>Estonia</option>
                              <option value="Ethiopia" %%=IIF(@nationality=='Ethiopia', "selected", "")=%%>Ethiopia</option>
                              <option value="Falkland Islands" %%=IIF(@nationality=='Falkland Islands', "selected", "")=%%>Falkland Islands</option>
                              <option value="Faroe Islands" %%=IIF(@nationality=='Faroe Islands', "selected", "")=%%>Faroe Islands</option>
                              <option value="Fiji Islands" %%=IIF(@nationality=='Fiji Islands', "selected", "")=%%>Fiji Islands</option>
                              <option value="Finland" %%=IIF(@nationality=='Finland', "selected", "")=%%>Finland</option>
                              <option value="France" %%=IIF(@nationality=='France', "selected", "")=%%>France</option>
                              <option value="French Guiana" %%=IIF(@nationality=='French Guiana', "selected", "")=%%>French Guiana</option>
                              <option value="French Polynesia" %%=IIF(@nationality=='French Polynesia', "selected", "")=%%>French Polynesia</option>
                              <option value="French Southern Territories" %%=IIF(@nationality=='French Southern Territories', "selected", "")=%%>French Southern Territories
                              </option>
                              <option value="Gabon" %%=IIF(@nationality=='Gabon', "selected", "")=%%>Gabon</option>
                              <option value="Gambia The" %%=IIF(@nationality=='Gambia The', "selected", "")=%%>Gambia The</option>
                              <option value="Georgia" %%=IIF(@nationality=='Georgia', "selected", "")=%%>Georgia</option>
                              <option value="Germany" %%=IIF(@nationality=='Germany', "selected", "")=%%>Germany</option>
                              <option value="Ghana" %%=IIF(@nationality=='Ghana', "selected", "")=%%>Ghana</option>
                              <option value="Gibraltar" %%=IIF(@nationality=='Gibraltar', "selected", "")=%%>Gibraltar</option>
                              <option value="Greece" %%=IIF(@nationality=='Greece', "selected", "")=%%>Greece</option>
                              <option value="Greenland" %%=IIF(@nationality=='Greenland', "selected", "")=%%>Greenland</option>
                              <option value="Grenada" %%=IIF(@nationality=='Grenada', "selected", "")=%%>Grenada</option>
                              <option value="Guadeloupe" %%=IIF(@nationality=='Guadeloupe', "selected", "")=%%>Guadeloupe</option>
                              <option value="Guam"  %%=IIF(@nationality=='Guam', "selected", "")=%%>Guam</option>
                              <option value="Guatemala" %%=IIF(@nationality=='Guatemala', "selected", "")=%%>Guatemala</option>
                              <option value="Guernsey and Alderney" %%=IIF(@nationality=='Guernsey and Alderney', "selected", "")=%%>Guernsey and Alderney</option>
                              <option value="Guinea" %%=IIF(@nationality=='Guinea', "selected", "")=%%>Guinea</option>
                              <option value="Guinea-Bissau" %%=IIF(@nationality=='Guinea-Bissau', "selected", "")=%%>Guinea-Bissau</option>
                              <option value="Guyana" %%=IIF(@nationality=='Guyana', "selected", "")=%%>Guyana</option>
                              <option value="Haiti" %%=IIF(@nationality=='Haiti', "selected", "")=%%>Haiti</option>
                              <option value="Heard Island and McDonald Islands" %%=IIF(@nationality=='Heard Island and McDonald Islands', "selected", "")=%%>Heard Island and
                                  McDonald Islands</option>
                              <option value="Honduras" %%=IIF(@nationality=='Honduras', "selected", "")=%%>Honduras</option>
                              <option value="Hong Kong S.A.R." %%=IIF(@nationality=='Hong Kong S.A.R.', "selected", "")=%%>Hong Kong S.A.R.</option>
                              <option value="Hungary" %%=IIF(@nationality=='Hungary', "selected", "")=%%>Hungary</option>
                              <option value="Iceland" %%=IIF(@nationality=='Iceland', "selected", "")=%%>Iceland</option>
                              <option value="India"  %%=IIF(@nationality=='India', "selected", "")=%%>India</option>
                              <option value="Indonesia" %%=IIF(@nationality=='Indonesia', "selected", "")=%%>Indonesia</option>
                              <option value="Iran" %%=IIF(@nationality=='Iran', "selected", "")=%%>Iran</option>
                              <option value="Iraq" %%=IIF(@nationality=='Iraq', "selected", "")=%%>Iraq</option>
                              <option value="Ireland" %%=IIF(@nationality=='Ireland', "selected", "")=%%>Ireland</option>
                              <option value="Israel" %%=IIF(@nationality=='Israel', "selected", "")=%%>Israel</option>
                              <option value="Italy" %%=IIF(@nationality=='Italy', "selected", "")=%%>Italy</option>
                              <option value="Jamaica" %%=IIF(@nationality=='Jamaica', "selected", "")=%%>Jamaica</option>
                              <option value="Japan" %%=IIF(@nationality=='Japan', "selected", "")=%%>Japan</option>
                              <option value="Jersey" %%=IIF(@nationality=='Jersey', "selected", "")=%%>Jersey</option>
                              <option value="Jordan" %%=IIF(@nationality=='Jordan', "selected", "")=%%>Jordan</option>
                              <option value="Kazakhstan" %%=IIF(@nationality=='Kazakhstan', "selected", "")=%%>Kazakhstan</option>
                              <option value="Kenya"  %%=IIF(@nationality=='Kenya', "selected", "")=%%>Kenya</option>
                              <option value="Kiribati" %%=IIF(@nationality=='Kiribati', "selected", "")=%%>Kiribati</option>
                              <option value="Korea North" %%=IIF(@nationality=='Korea North', "selected", "")=%%>Korea North</option>
                              <option value="Korea South" %%=IIF(@nationality=='Korea South', "selected", "")=%%>Korea South</option>
                              <option value="Kosovo" %%=IIF(@nationality=='Kosovo', "selected", "")=%%>Kosovo</option>
                              <option value="Kuwait" %%=IIF(@nationality=='Kuwait', "selected", "")=%%>Kuwait</option>
                              <option value="Kyrgyzstan" %%=IIF(@nationality=='Kyrgyzstan', "selected", "")=%%>Kyrgyzstan</option>
                              <option value="Laos"  %%=IIF(@nationality=='Laos', "selected", "")=%%>Laos</option>
                              <option value="Latvia" %%=IIF(@nationality=='Latvia', 'selected', "")=%%>Latvia</option>
                              <option value="Lebanon" %%=IIF(@nationality=='Lebanon', "selected", "")=%%>Lebanon</option>
                              <option value="Lesotho" %%=IIF(@nationality=='Lesotho', "selected", "")=%%>Lesotho</option>
                              <option value="Liberia" %%=IIF(@nationality=='Liberia', "selected", "")=%%>Liberia</option>
                              <option value="Libya" %%=IIF(@nationality=='Libya', "selected", "")=%%>Libya</option>
                              <option value="Liechtenstein" %%=IIF(@nationality=='Liechtenstein', "selected", "")=%%>Liechtenstein</option>
                              <option value="Lithuania" %%=IIF(@nationality=='Lithuania', "selected", "")=%%>Lithuania</option>
                              <option value="Luxembourg" %%=IIF(@nationality=='Luxembourg', "selected", "")=%%>Luxembourg</option>
                              <option value="Macau S.A.R." %%=IIF(@nationality=='Macau S.A.R.', "selected", "")=%%>Macau S.A.R.</option>
                              <option value="Macedonia" %%=IIF(@nationality=='Macedonia', "selected", "")=%%>Macedonia</option>
                              <option value="Madagascar"  %%=IIF(@nationality=='Madagascar', "selected", "")=%%>Madagascar</option>
                              <option value="Malawi" %%=IIF(@nationality=='Malawi', "selected", "")=%%>Malawi</option>
                              <option value="Malaysia" %%=IIF(@nationality=='Malaysia', 'selected', "")=%%>Malaysia</option>
                              <option value="Maldives" %%=IIF(@nationality=='Maldives', "selected", "")=%%>Maldives</option>
                              <option value="Mali" %%=IIF(@nationality=='Mali', "selected", "")=%%>Mali</option>
                              <option value="Malta" %%=IIF(@nationality=='Malta', "selected", "")=%%>Malta</option>
                              <option value="Man (Isle of)" %%=IIF(@nationality=='Man (Isle of)', "selected", "")=%%>Man (Isle of)</option>
                              <option value="Marshall Islands" %%=IIF(@nationality=='Marshall Islands', "selected", "")=%%>Marshall Islands</option>
                              <option value="Martinique" %%=IIF(@nationality=='Martinique', "selected", "")=%%>Martinique</option>
                              <option value="Mauritania" %%=IIF(@nationality=='Mauritania', "selected", "")=%%>Mauritania</option>
                              <option value="Mauritius" %%=IIF(@nationality=='Mauritius', "selected", "")=%%>Mauritius</option>
                              <option value="Mayotte" %%=IIF(@nationality=='Mayotte', "selected", "")=%%>Mayotte</option>
                              <option value="Mexico" %%=IIF(@nationality=='Mexico', "selected", "")=%%>Mexico</option>
                              <option value="Micronesia" %%=IIF(@nationality=='Micronesia', "selected", "")=%%>Micronesia</option>
                              <option value="Moldova" %%=IIF(@nationality=='Moldova', "selected", "")=%%>Moldova</option>
                              <option value="Monaco" %%=IIF(@nationality=='Monaco', "selected", "")=%%>Monaco</option>
                              <option value="Mongolia" %%=IIF(@nationality=='Mongolia', "selected", "")=%%>Mongolia</option>
                              <option value="Montenegro" %%=IIF(@nationality=='Montenegro', "selected", "")=%%>Montenegro</option>
                              <option value="Montserrat"  %%=IIF(@nationality=='Montserrat', "selected", "")=%%>Montserrat</option>
                              <option value="Morocco" %%=IIF(@nationality=='Morocco', "selected", "")=%%>Morocco</option>
                              <option value="Mozambique" %%=IIF(@nationality=='Mozambique', "selected", "")=%%>Mozambique</option>
                              <option value="Myanmar" %%=IIF(@nationality=='Myanmar', "selected", "")=%%>Myanmar</option>
                              <option value="Namibia" %%=IIF(@nationality=='Namibia', "selected", "")=%%>Namibia</option>
                              <option value="Nauru" %%=IIF(@nationality=='Nauru', "selected", "")=%%>Nauru</option>
                              <option value="Nepal" %%=IIF(@nationality=='Nepal', "selected", "")=%%>Nepal</option>
                              <option value="Netherlands The" %%=IIF(@nationality=='Netherlands The', "selected", "")=%%>Netherlands The</option>
                              <option value="New Caledonia" %%=IIF(@nationality=='New Caledonia', "selected", "")=%%>New Caledonia</option>
                              <option value="New Zealand" %%=IIF(@nationality=='New Zealand', "selected", "")=%%>New Zealand</option>
                              <option value="Nicaragua" %%=IIF(@nationality=='Nicaragua', "selected", "")=%%>Nicaragua</option>
                              <option value="Niger" %%=IIF(@nationality=='Niger', "selected", "")=%%>Niger</option>
                              <option value="Nigeria" %%=IIF(@nationality=='Nigeria', "selected", "")=%%>Nigeria</option>
                              <option value="Niue" %%=IIF(@nationality=='Niue', "selected", "")=%%>Niue</option>
                              <option value="Norfolk Island" %%=IIF(@nationality=='Norfolk Island', "selected", "")=%%>Norfolk Island</option>
                              <option value="Northern Mariana Islands" %%=IIF(@nationality=='Northern Mariana Islands', "selected", "")=%%>Northern Mariana Islands
                              </option>
                              <option value="Norway" %%=IIF(@nationality=='Norway', "selected", "")=%%>Norway</option>
                              <option value="Oman" %%=IIF(@nationality=='Oman', "selected", "")=%%>Oman</option>
                              <option value="Pakistan" %%=IIF(@nationality=='Pakistan', "selected", "")=%%>Pakistan</option>
                              <option value="Palau" %%=IIF(@nationality=='Palau', "selected", "")=%%>Palau</option>
                              <option value="Palestinian Territory Occupied" %%=IIF(@nationality=='Palestinian Territory Occupied', "selected", "")=%%>Palestinian Territory
                                  Occupied</option>
                              <option value="Panama" %%=IIF(@nationality=='Panama', "selected", "")=%%>Panama</option>
                              <option value="Papua new Guinea" %%=IIF(@nationality=='Papua new Guinea', "selected", "")=%%>Papua new Guinea</option>
                              <option value="Paraguay" %%=IIF(@nationality=='Paraguay', "selected", "")=%%>Paraguay</option>
                              <option value="Peru" %%=IIF(@nationality=='Peru', "selected", "")=%%>Peru</option>
                              <option value="Philippines" %%=IIF(@nationality=='Philippines', "selected", "")=%%>Philippines</option>
                              <option value="Pitcairn Island" %%=IIF(@nationality=='Pitcairn Island', "selected", "")=%%>Pitcairn Island</option>
                              <option value="Poland" %%=IIF(@nationality=='Poland', "selected", "")=%%>Poland</option>
                              <option value="Portugal" %%=IIF(@nationality=='Portugal', "selected", "")=%%>Portugal</option>
                              <option value="Puerto Rico" %%=IIF(@nationality=='Puerto Rico', "selected", "")=%%>Puerto Rico</option>
                              <option value="Qatar" %%=IIF(@nationality=='Qatar', "selected", "")=%%>Qatar</option>
                              <option value="Reunion" %%=IIF(@nationality=='Reunion', "selected", "")=%%>Reunion</option>
                              <option value="Romania" %%=IIF(@nationality=='Romania', "selected", "")=%%>Romania</option>
                              <option value="Russia" %%=IIF(@nationality=='Russia', "selected", "")=%%>Russia</option>
                              <option value="Rwanda"  %%=IIF(@nationality=='Rwanda', "selected", "")=%%>Rwanda</option>
                              <option value="Saint Helena" %%=IIF(@nationality=='Saint Helena', "selected", "")=%%>Saint Helena</option>
                              <option value="Saint Kitts And Nevis" %%=IIF(@nationality=='Saint Kitts And Nevis', "selected", "")=%%>Saint Kitts And Nevis</option>
                              <option value="Saint Lucia" %%=IIF(@nationality=='Saint Lucia', "selected", "")=%%>Saint Lucia</option>
                              <option value="Saint Pierre and Miquelon"  %%=IIF(@nationality=='Saint Pierre and Miquelon', "selected", "")=%%>Saint Pierre and Miquelon
                              </option>
                              <option value="Saint Vincent And The Grenadines" %%=IIF(@nationality=='Saint Vincent And The Grenadines', "selected", "")=%%>Saint Vincent And The
                                  Grenadines</option>
                              <option value="Saint-Barthelemy" %%=IIF(@nationality=='Saint-Barthelemy', "selected", "")=%%>Saint-Barthelemy</option>
                              <option value="Saint-Martin (French part)" %%=IIF(@nationality=='Saint-Martin (French part)', "selected", "")=%%>Saint-Martin (French part)
                              </option>
                              <option value="Samoa" %%=IIF(@nationality=='Samoa', "selected", "")=%%>Samoa</option>
                              <option value="San Marino" %%=IIF(@nationality=='San Marino', "selected", "")=%%>San Marino</option>
                              <option value="Sao Tome and Principe" %%=IIF(@nationality=='Sao Tome and Principe', "selected", "")=%%>Sao Tome and Principe</option>
                              <option value="Saudi Arabia" %%=IIF(@nationality=='Saudi Arabia', "selected", "")=%%>Saudi Arabia</option>
                              <option value="Senegal" %%=IIF(@nationality=='Senegal', "selected", "")=%%>Senegal</option>
                              <option value="Serbia" %%=IIF(@nationality=='Serbia', "selected", "")=%%>Serbia</option>
                              <option value="Seychelles" %%=IIF(@nationality=='Seychelles', "selected", "")=%%>Seychelles</option>
                              <option value="Sierra Leone" %%=IIF(@nationality=='Sierra Leone', "selected", "")=%%>Sierra Leone</option>
                              <option value="Singapore" %%=IIF(@nationality=='Singapore', "selected", "")=%%>Singapore</option>
                              <option value="Sint Maarten (Dutch part)" %%=IIF(@nationality=='Sint Maarten (Dutch part)', "selected", "")=%%>Sint Maarten (Dutch part)
                              </option>
                              <option value="Slovakia" %%=IIF(@nationality=='Slovakia', "selected", "")=%%>Slovakia</option>
                              <option value="Slovenia" %%=IIF(@nationality=='Slovenia', "selected", "")=%%>Slovenia</option>
                              <option value="Solomon Islands" %%=IIF(@nationality=='Solomon Islands', "selected", "")=%%>Solomon Islands</option>
                              <option value="Somalia" %%=IIF(@nationality=='Somalia', "selected", "")=%%>Somalia</option>
                              <option value="South Africa" %%=IIF(@nationality=='South Africa', 'selected', "")=%%>South Africa</option>
                              <option value="South Georgia" %%=IIF(@nationality=='South Georgia', "selected", "")=%%>South Georgia</option>
                              <option value="South Sudan" %%=IIF(@nationality=='South Sudan', "selected", "")=%%>South Sudan</option>
                              <option value="Spain" %%=IIF(@nationality=='Spain', "selected", "")=%%>Spain</option>
                              <option value="Sri Lanka" %%=IIF(@nationality=='Sri Lanka', "selected", "")=%%>Sri Lanka</option>
                              <option value="Sudan" %%=IIF(@nationality=='Sudan', "selected", "")=%%>Sudan</option>
                              <option value="Suriname" %%=IIF(@nationality=='Suriname', "selected", "")=%%>Suriname</option>
                              <option value="Svalbard And Jan Mayen Islands" %%=IIF(@nationality=='Svalbard And Jan Mayen Islands', "selected", "")=%%>Svalbard And Jan Mayen
                                  Islands</option>
                              <option value="Swaziland" %%=IIF(@nationality=='Swaziland', "selected", "")=%%>Swaziland</option>
                              <option value="Sweden" %%=IIF(@nationality=='Sweden', "selected", "")=%%>Sweden</option>
                              <option value="Switzerland" %%=IIF(@nationality=='Switzerland', "selected", "")=%%>Switzerland</option>
                              <option value="Syria" %%=IIF(@nationality=='Syria', "selected", "")=%%>Syria</option>
                              <option value="Taiwan" %%=IIF(@nationality=='Taiwan', "selected", "")=%%>Taiwan</option>
                              <option value="Tajikistan" %%=IIF(@nationality=='Tajikistan', "selected", "")=%%>Tajikistan</option>
                              <option value="Tanzania" %%=IIF(@nationality=='Tanzania', "selected", "")=%%>Tanzania</option>
                              <option value="Thailand" %%=IIF(@nationality=='Thailand', "selected", "")=%%>Thailand</option>
                              <option value="Togo" %%=IIF(@nationality=='Togo', "selected", "")=%%>Togo</option>
                              <option value="Tokelau" %%=IIF(@nationality=='Tokelau', "selected", "")=%%>Tokelau</option>
                              <option value="Tonga" %%=IIF(@nationality=='Tonga', "selected", "")=%%>Tonga</option>
                              <option value="Trinidad And Tobago" %%=IIF(@nationality=='Trinidad And Tobago', "selected", "")=%%>Trinidad And Tobago</option>
                              <option value="Tunisia" %%=IIF(@nationality=='Tunisia', "selected", "")=%%>Tunisia</option>
                              <option value="Turkey"  %%=IIF(@nationality=='Turkey', "selected", "")=%%>Turkey</option>
                              <option value="Turkmenistan" %%=IIF(@nationality=='Turkmenistan', "selected", "")=%%>Turkmenistan</option>
                              <option value="Turks And Caicos Islands" %%=IIF(@nationality=='Turks And Caicos Islands', "selected", "")=%%>Turks And Caicos Islands
                              </option>
                              <option value="Tuvalu" %%=IIF(@nationality=='Tuvalu', "selected", "")=%%>Tuvalu</option>
                              <option value="Uganda" %%=IIF(@nationality=='Uganda', "selected", "")=%%>Uganda</option>
                              <option value="Ukraine" %%=IIF(@nationality=='Ukraine', "selected", "")=%%>Ukraine</option>
                              <option value="United Arab Emirates" %%=IIF(@nationality=='United Arab Emirates', "selected", "")=%%>United Arab Emirates</option>
                              <option value="United Kingdom" %%=IIF(@nationality=='United Kingdom', "selected", "")=%%>United Kingdom</option>
                              <option value="United States" %%=IIF(@nationality=='United States', "selected", "")=%%>United States</option>
                              <option value="United States Minor Outlying Islands" %%=IIF(@nationality=='United States Minor Outlying Islands', "selected", "")=%%>United States Minor
                                  Outlying Islands</option>
                              <option value="Uruguay" %%=IIF(@nationality=='Uruguay', "selected", "")=%%>Uruguay</option>
                              <option value="Uzbekistan" %%=IIF(@nationality=='Uzbekistan', "selected", "")=%%>Uzbekistan</option>
                              <option value="Vanuatu" %%=IIF(@nationality=='Vanuatu', "selected", "")=%%>Vanuatu</option>
                              <option value="Vatican City State (Holy See)" %%=IIF(@nationality=='Vatican City State (Holy See)', "selected", "")=%%>Vatican City State (Holy
                                  See)</option>
                              <option value="Venezuela" %%=IIF(@nationality=='Venezuela', "selected", "")=%%>Venezuela</option>
                              <option value="Vietnam" %%=IIF(@nationality=='Vietnam', "selected", "")=%%>Vietnam</option>
                              <option value="Virgin Islands (British)" %%=IIF(@nationality=='Virgin Islands (British)', "selected", "")=%%>Virgin Islands (British)
                              </option>
                              <option value="Virgin Islands (US)" %%=IIF(@nationality=='Virgin Islands (US)', "selected", "")=%%>Virgin Islands (US)</option>
                              <option value="Wallis And Futuna Islands" %%=IIF(@nationality=='Wallis And Futuna Islands', "selected", "")=%%>Wallis And Futuna Islands
                              </option>
                              <option value="Western Sahara" %%=IIF(@nationality=='Western Sahara', "selected", "")=%%>Western Sahara</option>
                              <option value="Yemen" %%=IIF(@nationality=='Yemen', "selected", "")=%%>Yemen</option>
                              <option value="Zambia" %%=IIF(@nationality=='Zambia', "selected", "")=%%>Zambia</option>
                              <option value="Zimbabwe" %%=IIF(@nationality=='Zimbabwe', "selected", "")=%%>Zimbabwe</option>



                  </select>
                 
                        </div>
                    </div>
                </div>
  
                 
          
           <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group">
                        <label for="">Gender</label>
                        <div class="select-wrapper hide-icon custom-">

                             <select class="form-control" name="gender" id="gender">
                               <option value=" " selected>Select</option>
                               <option value="Female" %%=IIF(@gender=='Female', "selected", "")=%%>Female</option>
                                <option value="Male" %%=IIF(@gender=='Male', "selected", "")=%%>Male</option> 
                            </select>
                         
                        </div>
                    </div>
                </div>
                 
                <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group">
                        <label class="label">Birthday</label>
                        <div class="bdate">
                          <input class="form-control" type="date" name="birthday"  value="%%=v(@birthdate)=%%" id="birthday">
                
                 <input type="hidden" id="hiddenDate">
                      </div>
                    
                      </div>
                  </div>
                
       <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">Language Preference</label>
                          <div class="select-wrapper hide-icon custom-">
  
                               <select class="form-control" name="profilelang">
                                 <option value=" " %%=IIF(@language==' ', "selected", "")=%%>Select</option>
                                 <option value="English" %%=IIF(@language=='English', "selected", "")=%%>English</option>
                                  <option value="Arabic" %%=IIF(@language=='Arabic', "selected", "")=%%>Arabic</option> 
                              </select>
                           
                          </div>
                      </div>
                  </div>
                
              </div>
              <!-- Family details section start -->
              <h4 class="pt-4 pb-4">Tell us a bit more about your family</h4>
               <!-- marital status new -->
              <div class="col-lg-4 col-md-6 col-sm-12 col-12" style="padding-left:0;">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">Marital Status</label>
                          <div class="select-wrapper hide-icon">
                              <select class="form-control" name="maritalstatus">
                                <option value="">Select</option>
                                  <option value="single"%%=IIF(@marriedStatus=='Single', "selected", "")=%%>Single  
                                  </option>
                                  <option value="Married" %%=IIF(@marriedStatus=='Married', "selected", "")=%%>Married
                                  </option>
                                  
                              </select>
                              
               
                          </div>
                      </div>
                  </div>
              <!-- Marital status section start -
              <div class="form-group" data-aos="fade-up" data-aos-anchor-placement="bottom-bottom">
                <label for="">Marital Status
                </label>
                <div class="radio-wrapper radio_adjust">
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
      <div class="form-group pt-4">
        <label for="">Do you have Children?</label>
        <div class="radio-wrapper radio_adjust">
            <div class="form-check form-check-inline">
                <input class="form-check-input" type="radio" name="kidsExists" id="kids"
                    value="kids-yes" onclick="ShowHideDivkids()" %%=v(@childExistsYes)=%%>
                <label class="form-check-label" for="kids">Yes</label>
            </div>
            <div class="form-check form-check-inline">
                <input class="form-check-input" type="radio" name="kidsExists"
                    id="nokids" value="kids-no" onclick="ShowHideDivkids()" %%=v(@childExistsNo)=%%>
                <label class="form-check-label" for="nokids">No</label>
            </div>
        </div>
    </div>
    <div id="dvKids" style=%%=IIF(@childExistsYes=='checked', "display:block;","display:none;")=%%>
      <div class="box-form-wrapper"  id="Dvkids">
          <div class="row">
              <div class="col-lg-4 col-md-4 col-sm-12 col-12">
                  <div class="form-group">
                      <label for="numOfKids">Number of Children? </label>
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
      
    <p class="disclaimer" style="font-size: 12px;"> <i>We request your child’s date of birth to send them birthday greetings and keep you informed about relevant events and promotions.</i></p>
      </div>
  
  </div>
            
                              %%[
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
                
          /*Output(concat("child detail : ", @ChildFirstName))*/
          
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
          
              <button type="submit" class="btn btn-success"id="profile-submit" name="button">Save</button>
 
          </div>
          
         <input name="submittedProfile" type="hidden" value="true"><br>
                                <input name="crmId" id="crmId" type="hidden" value="%%=v(@crmId)=%%"><br>
            <input name="guestId" id="guestId" type="hidden" value="%%=v(@Id)=%%">
            <input name="emails" type="hidden" value="%%=v(@email)=%%">
            <input name="numberOfKids" type="hidden" value="%%=v(@numOfKids)=%%"><br>
              </form>
          %%[
                                IF RequestParameter("submittedProfile")==true then
                                        SET @sfid = RequestParameter("crmId")
                                        SET @emailContact = RequestParameter("emails")  
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
                                        SET @numOfKids = RequestParameter("numberOfKids")
                                        /* Nitik 5th Mar24, variable to fetch the deleted kids Ids from hidden field */
                                        SET @deletedKidsId = RequestParameter("DeletedKidsId")

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
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "Salutation", @profileSalutation,
                                            "FirstName", @firstName,
                                            "LastName", @lastName, 
                                            "Email", @email,
                                            "MailingCity", @city,
                                            "Country_Code__c", @phonecode,
                                            "Registration_Language__c", @profileLang,
                                            "GenderIdentity", @gender,
                                            "Nationality__c", @profileNationality,
                                            "Residence_Country__c", @profileCountry,
                                            "Do_you_have_kids__c", @doYouHaveKids
                                            )
                                        
                                        
                                            
                                     
                                 
                                      /*Creating and Updating child records based on value selected above*/
       /* Update by Priyanka on 18th March */
                                        
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
                                        
                                        
                                        /* Nitik 05th Mar24, changes for "no" kids selection */
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
                                   
                                                                          /*Redirect(Concat("https://cloud.explore.theroxycinemas.com/roxyqa_cpc?sfid=", Base64Encode(@sfid), "#interests"))*/
                                                                          
                                   set @interests = '#interests'
                                   if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","ProfilePage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.theroxycinemas.com/roxyqa_cpc?sfid=", Base64Encode(@sfid), "#interests"))
                                   ELSE
                                      Redirect(CONCAT(CloudPagesURL(2729),@interests))
                                   ENDIF
                                   endif

                                        
        
        ]%%
        
         
       
        
        
            </div>
        </div>
        <!-- 2nd card Interest tab-->
            %%[
                                 
                                   set @preferredmoviegenresString = BuildRowsetFromString(@preferredmoviegenres,";")
                                   set @preferredmoviegenresCount = rowCount(@preferredmoviegenresString)
                                   
                                   if @preferredmoviegenresCount > 0 then
                                      for @i = 1 to @preferredmoviegenresCount do
                                           
                                           SET @val = Field(Row(@preferredmoviegenresString,@i),1)
                                           
                                           IF @val == "Action/Adventure" THEN
                                           SET @actionAdventure = "checked"
                                           ELSEIF @val == "Comedy" THEN
                                           SET @comedy = "checked"
                                           ELSEIF @val == "Drama/Romance" THEN
                                           SET @dramaRomance = "checked"
                                           ELSEIF @val == "Science Fiction/Fantasy" THEN
                                           SET @scienceFictionFantasy = "checked"
                                           ELSEIF @val == "Horror" THEN       
                                           SET @Horror = "checked"
                                           ELSEIF @val == "Animation" THEN       
                                           SET @Animation = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
                    
                                  set @preferredcinemahallString = BuildRowsetFromString(@preferredcinemahall,";")
                                  set @preferredcinemahallCount = rowCount(@preferredcinemahallString)
                                  
                                  if @preferredcinemahallCount > 0 then
                                      for @i = 1 to @preferredcinemahallCount do
                                           
                                           SET @val = Field(Row(@preferredcinemahallString,@i),1)
                                           
                                           IF @val == "Dubai Hills Mall" THEN
                                           SET @dubaiHills = "checked"
                                           ELSEIF @val == "Al Khawaneej" THEN
                                           SET @alKhawaneej = "checked"
                                           ELSEIF @val == "The Beach" THEN
                                           SET @beach = "checked"
                                           ELSEIF @val == "City Walk" THEN
                                           SET @cityWalk = "checked"
                                           ELSEIF @val == "Boxpark" THEN
                                           SET @boxpark = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
                                   
                                  set @preferredcinemaexperienceString = BuildRowsetFromString(@preferredcinemaexperience,";")
                                  set @preferredcinemaexperienceCount = rowCount(@preferredcinemaexperienceString)
                                  
                                  if @preferredcinemaexperienceCount > 0 then
                                      for @i = 1 to @preferredcinemaexperienceCount do
                                           
                                           SET @val = Field(Row(@preferredcinemaexperienceString,@i),1)
                                           
                                           IF @val == "Silver" THEN
                                           SET @silver = "checked"
                                           ELSEIF @val == "Gold" THEN
                                           SET @gold = "checked"
                                           ELSEIF @val == "Platinum" THEN
                                           SET @platinum = "checked"
                                           ELSEIF @val == "Xtreme" THEN
                                           SET @Xtreme = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
                                 
                                 set @preferreddatetimetowatchmoviesString = BuildRowsetFromString(@preferreddatetimetowatchmovies,";")
                                  set @preferreddatetimetowatchmoviesCount = rowCount(@preferreddatetimetowatchmoviesString)
                                  
                                  if @preferreddatetimetowatchmoviesCount > 0 then
                                      for @i = 1 to @preferreddatetimetowatchmoviesCount do
                                           
                                           SET @val = Field(Row(@preferreddatetimetowatchmoviesString,@i),1)
                                           
                                           IF @val == "Weekdays (Monday to Thursday)" THEN
                                           SET @weekdays = "checked"
                                           ELSEIF @val == "Weekends (Friday to Sunday)" THEN
                                           SET @weekends = "checked"
                                           ELSEIF @val == "Matinee Shows (Before 5 PM)" THEN
                                           SET @matineeShows = "checked"
                                           ELSEIF @val == "Evening Shows (After 5 PM)" THEN
                                           SET @eveningShows = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
                                   
                                   set @typicalgroupsizeString = BuildRowsetFromString(@typicalgroupsize,";")
                                  set @typicalgroupsizeCount = rowCount(@typicalgroupsizeString)
                                  
                                  if @typicalgroupsizeCount > 0 then
                                      for @i = 1 to @typicalgroupsizeCount do
                                           
                                           SET @val = Field(Row(@typicalgroupsizeString,@i),1)
                                           
                                           IF @val == "Alone" THEN
                                           SET @alone = "checked"
                                           ELSEIF @val == "Small Group (2-4 people)" THEN
                                           SET @smallGroup = "checked"
                                           ELSEIF @val == "Medium Group (5-8 people)" THEN
                                           SET @mediumGroup = "checked"
                                           ELSEIF @val == "Large Group (9 or more people)" THEN
                                           SET @largeGroup = "checked"
                                           ENDIF
                                           
                                      next @i
                                   endif
                    
                                   ]%%                                    
           
        <div class="tab-pane fade interest-tab-content" id="interests" role="tabpanel" aria-labelledby="interests-tab">
          
            <div class="wrapper wrapper--w700">
              
              <form class="interest-form" action="" method="post" name="myForm" id="interest-form" autocomplete="off" >
              
               
                 
                  <div class="form-group">
                    <h4 class="pt-4 pb-3">What are your preferred movie genres?</h4>
                    <div class="radio-wrapper movie-genre radio-width">
                        <div class="form-check form-check">
                          <label class="form-check-label" for="genre1">Action/Adventure</label>
                            <input class="form-check-input" type="checkbox" name="genre1" id="genre1" %%=v(@actionAdventure)=%% >                              
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="genre2">Comedy</label>
                          <input class="form-check-input" type="checkbox" name="genre2" id="genre2" %%=v(@comedy)=%% >  
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="genre3">Drama/Romance</label>
                          <input class="form-check-input" type="checkbox" name="genre3" id="genre3" %%=v(@dramaRomance)=%% >  
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="genre4">Science Fiction/Fantasy</label>
                          <input class="form-check-input" type="checkbox" name="genre4" id="genre4" %%=v(@scienceFictionFantasy)=%% >  
                        </div>
                        <div class="form-check form-check">
                          <label class="form-check-label" for="genre5">Horror</label>
                          <input class="form-check-input" type="checkbox" name="genre5" id="genre5" %%=v(@Horror)=%% >  
                        </div>
                       <div class="form-check form-check">
                          <label class="form-check-label" for="genre6">Animation</label>
                          <input class="form-check-input" type="checkbox" name="genre6" id="genre6" %%=v(@Animation)=%%>  
                        </div>
                    </div>
                    

                    <h4 class="pt-4 pb-3">What is your preferred cinema location?</h4>
                    <div class="radio-wrapper Cinema-hall radio-width">
                      <div class="form-check form-check">
                        <label class="form-check-label" for="hall1">Dubai Hills Mall</label>
                          <input class="form-check-input" type="checkbox" name="hall1" id="hall1" %%=v(@dubaiHills)=%% >                              
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="hall2">Al Khawaneej</label>
                        <input class="form-check-input" type="checkbox" name="hall2" id="hall2" %%=v(@alKhawaneej)=%% >  
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="hall3">The Beach</label>
                        <input class="form-check-input" type="checkbox" name="hall3" id="hall3" %%=v(@beach)=%% >  
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="hall4">City Walk</label>
                        <input class="form-check-input" type="checkbox" name="hall4" id="hall4" %%=v(@cityWalk)=%% >  
                      </div>
                      <div class="form-check form-check">
                        <label class="form-check-label" for="hall5">Boxpark</label>
                        <input class="form-check-input" type="checkbox" name="hall5" id="hall5" %%=v(@boxpark)=%% >  
                      </div>
                  </div>

                  <h4 class="pt-4 pb-3">What is your preferred cinema experience?</h4>
                  <div class="radio-wrapper preffered-cinema radio-width">
                    <div class="form-check form-check">
                      <label class="form-check-label" for="silver">Silver</label>
                        <input class="form-check-input" type="checkbox" name="Ptime1" id="silver" %%=v(@silver)=%% >                              
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="gold">Gold</label>
                      <input class="form-check-input" type="checkbox" name="Ptime2" id="gold" %%=v(@gold)=%% >  
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="platinum">Platinum</label>
                      <input class="form-check-input" type="checkbox" name="Ptime3" id="platinum" %%=v(@platinum)=%% >  
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="Xtreme">Xtreme</label>
                      <input class="form-check-input" type="checkbox" name="Ptime4" id="Xtreme" %%=v(@Xtreme)=%% >  
                    </div>
                </div>

                  <h4 class="pt-4 pb-3">What is your preferred date/time to watch movies?</h4>
                  <div class="radio-wrapper preffered-time radio-width">
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like1">Weekdays (Monday to Thursday)</label>
                        <input class="form-check-input" type="checkbox" name="like1" id="like1" %%=v(@weekdays)=%% >  
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like2">Weekends (Friday to Sunday)</label>
                      <input class="form-check-input" type="checkbox" name="like2" id="like2" %%=v(@weekends)=%% >  
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like3">Matinee Shows (Before 5 PM)</label>
                      <input class="form-check-input" type="checkbox" name="like3" id="like3" %%=v(@matineeShows)=%% >  
                    </div>
                    <div class="form-check form-check">
                      <label class="form-check-label" for="like4">Evening Shows (After 5 PM)</label>
                      <input class="form-check-input" type="checkbox" name="like4" id="like4" %%=v(@eveningShows)=%% >  
                    </div>
                </div>

                <h4 class="pt-4 pb-3">What is the typical group size with which you visit Roxy Cinemas usually?</h4>
                <div class="radio-wrapper group-size radio-width">
                  <div class="form-check form-check">
                    <label class="form-check-label" for="size1">Alone</label>
                      <input class="form-check-input" type="checkbox" name="size1" id="size1" %%=v(@alone)=%% >  
                  </div>
                  <div class="form-check form-check">
                    <label class="form-check-label" for="size2">Small Group (2-4 people)</label>
                    <input class="form-check-input" type="checkbox" name="size2" id="size2" %%=v(@smallGroup)=%% >  
                  </div>
                  <div class="form-check form-check">
                    <label class="form-check-label" for="size3">Medium Group (5-8 people)</label>
                    <input class="form-check-input" type="checkbox" name="size3" id="size3" %%=v(@mediumGroup)=%% >  
                  </div>
                  <div class="form-check form-check">
                    <label class="form-check-label" for="size4">Large Group (9 or more people)</label>
                    <input class="form-check-input" type="checkbox" name="size4" id="size4" %%=v(@largeGroup)=%% >  
                  </div>
              </div>                
          

                 </div>
               <input name="submittedInterests" type="hidden" value="true"><br>
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%"><br>
                <input name="emails" type="hidden" value="%%=v(@email)=%%">
                <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
            
              
                 <div class="text-end">
                  <button type="submit" class="btn btn-success"id="interest-submit" name="button">Save</button>  
                 </div> 
                </form>
                 </div>   
            
              
           %%[
IF RequestParameter("submittedInterests") == "true" then
    SET @sfid = RequestParameter("crmId")
    SET @guestId = RequestParameter("guestId")
     SET @emailContact = RequestParameter("emails")  
     SET @preferredmoviegenresValue = CONCAT(
          Iif(RequestParameter("genre1") == "on", "Action/Adventure;", ""),
          Iif(RequestParameter("genre2") == "on", "Comedy;", ""),
          Iif(RequestParameter("genre3") == "on", "Drama/Romance;", ""),
          Iif(RequestParameter("genre4") == "on", "Science Fiction/Fantasy;", ""),
          Iif(RequestParameter("genre5") == "on", "Horror;", ""),
          Iif(RequestParameter("genre6") == "on", "Animation", ""),
        )  
         if not Empty(@preferredmoviegenresValue) then
          SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "What_are_your_preferred_movie_genres__c", @preferredmoviegenresValue)
          else
            SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "What_are_your_preferred_movie_genres__c")

         endif
         
    SET @preferredcinemahallValue = CONCAT(
          Iif(RequestParameter("hall1") == "on", "Dubai Hills Mall;", ""),
          Iif(RequestParameter("hall2") == "on", "Al Khawaneej;", ""),
          Iif(RequestParameter("hall3") == "on", "The Beach;", ""),
          Iif(RequestParameter("hall4") == "on", "City Walk;", ""),
          Iif(RequestParameter("hall5") == "on", "Boxpark", ""),
    )  
    if not Empty(@preferredcinemahallValue) then
       SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "What_is_your_preferred_cinema_hall__c", @preferredcinemahallValue)
    else
        SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "What_is_your_preferred_cinema_hall__c")

    endif
    
    SET @preferredcinemaexperienceValue = CONCAT(
          Iif(RequestParameter("Ptime1") == "on", "Silver;", ""),
          Iif(RequestParameter("Ptime2") == "on", "Gold;", ""),
          Iif(RequestParameter("Ptime3") == "on", "Platinum;", ""),
          Iif(RequestParameter("Ptime4") == "on", "Xtreme", "")
    )  
    if not Empty(@preferredcinemaexperienceValue) then
       SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "What_is_your_preferred_cinema_experience__c", @preferredcinemaexperienceValue)
    else
        SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "What_is_your_preferred_cinema_experience__c")

    endif
    
    SET @preferreddatetimetowatchmoviesValue = CONCAT(
          Iif(RequestParameter("like1") == "on", "Weekdays (Monday to Thursday);", ""),
          Iif(RequestParameter("like2") == "on", "Weekends (Friday to Sunday);", ""),
          Iif(RequestParameter("like3") == "on", "Matinee Shows (Before 5 PM);", ""),
          Iif(RequestParameter("like4") == "on", "Evening Shows (After 5 PM)", "")
    )  
    if not Empty(@preferreddatetimetowatchmoviesValue) then
       SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "Preferred_date_time_to_watch_movies__c", @preferreddatetimetowatchmoviesValue)
    else
        SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "Preferred_date_time_to_watch_movies__c")

    endif
    
    SET @typicalgroupsizeValue = CONCAT(
          Iif(RequestParameter("size1") == "on", "Alone;", ""),
          Iif(RequestParameter("size2") == "on", "Small Group (2-4 people);", ""),
          Iif(RequestParameter("size3") == "on", "Medium Group (5-8 people);", ""),
          Iif(RequestParameter("size4") == "on", "Large Group (9 or more people)", "")
    )  
    if not Empty(@typicalgroupsizeValue) then
       SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "Group_size_with_which_you_visit_RC_usual__c", @typicalgroupsizeValue)
    else
        SET @updateRecord = UpdateSingleSalesforceObject(
              "Guest_Subscription__c", @guestId,
              "fieldsToNull", "Group_size_with_which_you_visit_RC_usual__c")

    endif
    
  
    
   /*Redirect(Concat("https://cloud.explore.theroxycinemas.com/roxyqa_cpc?sfid=", Base64Encode(@sfid), "#communications"))*/
   set @communications = '#communications'
   if empty(@sfid) OR IsNull(@sfid) then
       Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
   ELSE
       Set @ampError = ''
   ENDIF
   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","InterestPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   
   if @methodType== 'Old' then
      Redirect(Concat("https://cloud.explore.theroxycinemas.com/roxyqa_cpc?sfid=", Base64Encode(@sfid), "#communications"))
   ELSE
      Redirect(CONCAT(CloudPagesURL(2729),@communications))
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
                 <div class="hear-about">
               <h4 class="pt-4 pb-3">What would you like to hear about?</h4>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@promotionaloffersdeals)=%%" id="informCheck11"  name="hearOffers" %%=IIF(@promotionaloffersdeals =='True' ,'checked', "" )=%% >
                   <label class="form-check-label" for="informCheck11">
                    Promotional offers and deals
                   </label>
               </div>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@annualpassvipoffers)=%%" id="informCheck12"  name="hearEvents" %%=IIF(@annualpassvipoffers =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck12">
                    Roxy Plus/Annual Pass/VIP Offers information
                   </label>
               </div>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@weeklyannouncements)=%%" id="informCheck13"  name="hearNews" %%=IIF(@weeklyannouncements =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck13">
                    Weekly announcements, news and events
                   </label>
               </div>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@newproductoffering)=%%" id="informCheck14"  name="newProduct" %%=IIF(@newproductoffering =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck14">
                    New product launches
                   </label>
               </div>
               <div class="form-check">
                <input class="form-check-input" type="checkbox" value="%%=v(@latestnews)=%%" id="informCheck15"  name="hearOtherParks" %%=IIF(@latestnews =='True' ,'checked', "" )=%%>
                <label class="form-check-label" for="informCheck15">
                  Latest news about other Dubai Holding Entertainment theme parks
                </label>
            </div>
            <div class="form-check">
              <input class="form-check-input" type="checkbox" value="%%=v(@customerSurvey)=%%" id="informCheck16"  name="hearSurvey" %%=IIF(@customerSurvey =='True' ,'checked', "" )=%%>
              <label class="form-check-label" for="informCheck16">
                Customer surveys
              </label>
          </div>
             </div>
 
             <div class="com-btn mt-5">
              <button type="submit" class="btn btn-orange"id="communications-submit" name="button">Save</button>

          </div>
              <input name="submittedCommunications" type="hidden" value="true">
              <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
              <input name="guestId" type="hidden" id="guestId" value="%%=v(@Id)=%%"><br>
              <input name="emails" type="hidden" value="%%=v(@email)=%%">
           </form>
            <hr>
          
            
             %%[
                                IF RequestParameter("submittedCommunications")==true then
                                SET @sfid = RequestParameter("crmId")
                                    SET @guestId = RequestParameter("guestId")
                                    SET @emailContact = RequestParameter("emails")  
                                    set @Updatedpromotionaloffersdeals =  RequestParameter("hearOffers")
                                    set @Updatedannualpassvipoffers=  RequestParameter("hearEvents")
                                    set @Updatedweeklyannouncements =  RequestParameter("hearNews")
                                    set @Updatednewproductoffering =  RequestParameter("newProduct")
                                    set @Updatedlatestnews =  RequestParameter("hearOtherParks")
                                    set @UpdatedcustomerSurvey =  RequestParameter("hearSurvey")
                           
                                    

                                    IF NOT Empty(@sfid) THEN
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Promotional_Offers_and_Deal__c", IIF(EMPTY(@Updatedpromotionaloffersdeals), 'False', 'True'), 
                                    "Annual_Pass_VIP_Offers_News_and_Info__c", IIF(EMPTY(@Updatedannualpassvipoffers), 'False', 'True'),
                                    "Weekly_Announcements_and_News__c", IIF(EMPTY(@Updatedweeklyannouncements), 'False', 'True'),
                                    "New_Product_Offering_Announcements__c", IIF(EMPTY(@Updatednewproductoffering), 'False', 'True'),
                                    "Latest_news_about_other_DHE_parks__c", IIF(EMPTY(@Updatedlatestnews), 'False', 'True'),
                                    "Customer_Survey__c",IIF(EMPTY(@UpdatedcustomerSurvey), 'False', 'True')
                                )
                              
                                /*Redirect(Concat("https://cloud.explore.theroxycinemas.com/thankyou_roxy_qa?sfid=", Base64Encode(@sfid)))*/
                                set @thankYouPage = '#ThankYou'
                                if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                               
                               if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.theroxycinemas.com/thankyou_roxy_qa?sfid=", Base64Encode(@sfid), "#ThankYou"))
                               ELSE
                                      Redirect(CONCAT(CloudPagesURL(2722),@thankYouPage))
                              ENDIF
                                ENDIF

                                ENDIF
                        ]%%
            
          <!--channel preference block-->
          <form class="preferences-form" action="" method="post">
            <!-- Second -->
            <div class="hear-about">
              <h4 class="pt-4 pb-3">How should we get in touch?
              </h4>
              <div class="form-check">
                <input class="form-check-input" type="checkbox" id="emailPref" name="emailPref" %%=IIF(@emailPref =='True' ,'checked', "" )=%%>
                <label class="form-check-label" for="emailPref">Email</label>
              </div>
              <div class="form-check">
                <input class="form-check-input" type="checkbox" id="WhatsAppPref" name="WhatsAppPref" %%=IIF(@WhatsAppPref =='True' ,'checked', "" )=%%>
                <label class="form-check-label" for="WhatsAppPref">WhatsApp</label>
              </div>
            </div>
            <div class="pref-btn mt-5">
              <button type="button" name="button" class="btn btn-orange channelPreference-btn"
                      onclick="channelPreference()" id="channel-submit">Save</button>
              <input name="submittedChannelPref" type="hidden" value="true">
              <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
              <input name="guestId" type="hidden" value="%%=v(@Id)=%%">
              <br>
            </div>
          </form>
          <!-- thank you pop up -->
          <div class="box-form mt-5" id="channel-preference" style="display:none;">
            <span class="close-buttonCM" style="
                                                text-align: right;
                                                font-size: 30px;
                                                position: relative;
                                                left: 94%;
                                                top: 0;
                                                cursor: pointer;
                                                color:#ce5a5e;">×</span>
            <div class="container">
              <div class="unsubscribe-wrapper form group">
                <div class="thanYou-img mb-2">
                  <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/6909e80c-a127-4526-a4a9-89b823125a7f.png" alt="" class="banner-bg-img">
                </div>
                <div class="thankYou-text">
                  <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold; padding-bottom:3rem;">Your channel subscription preferences have been successfully updated.
                  </p>
                </div>
              </div>
            </div>
          </div>
          <!-- channel preference block end -->

            
            
            <div class="mt-5 pl-2" style="font-size: 16px;">
              <p>To manage SMS subscriptions, please refer to the opt-out feature from the latest SMS message. If you wish to unsubscribe from all Roxy Cinemas communications please click on ‘Unsubscribe’.</p>
            </div>
           <div class="unsrb-btn mt-5">
      <button type="button" name="button" class="btn btn-orange unsubscribe-btn"
          onclick="unsubscribeClick()" id="unsubscribeClick" >Unsubscribe</button>
  </div>
   <!-- unsubscribe Reason options -->
           <div class="box-form mt-5" id="unsubscribe-reason">
               <form class="comment-form" action="" method="post">
                 <span class="close-button" style="
text-align: right;
font-size: 30px;
position: relative;
left: 100%;
top: 0;
cursor: pointer;                                                           
color:#ce5a5e;">×</span>
                 <div class="container">
      <div class="unsubscribe-wrapper form group">
        <div class="thanYou-img mb-2">
             <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/6909e80c-a127-4526-a4a9-89b823125a7f.png" alt="" class="banner-bg-img">
        </div>
      <div class="thankYou-text">
       
            <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">You’ve been successfully unsubscribed. </p>  
      </div>
    
    </div>
    </div>          
                   <div class="orange-notice">
                       Sorry to see you go!

                   </div>
                   <p style="font-size: 18px;">Please help us get better by telling us why  you're unsubscribing:</p>
                   <div class="form-check mb-2">

                       <input class="form-check-input" type="checkbox" id="chck1" value="False" name="unsubFreq" %%=IIF(@emailsTooFrequent =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck1">Emails are too frequent</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck2" value="False" name="unsubRelevance" %%=IIF(@contentIsNotRelevant =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck2">Content isn't relevant</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck3" value="False" name="unsubNoDubai"  %%=IIF(@noLongerInDubai =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck3">I'm no longer in Dubai</label>
                   </div>
                   <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="chck4" value="False" name="unsubTemp" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                    <label class="form-check-label" for="chck4">Temporary Pause (30 Days)</label>
                </div>
                   <div class="form-check mt-2">
                       <input class="form-check-input" type="checkbox" id="myCheck1" value="False"
                           onclick="addbox1()" name="unsubOther"  %%=IIF(@otherSpecify =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="myCheck1">Other (Please specify)</label>
                   </div>
                   <textarea name="nameReason" rows="6" cols="80" id="area1"
                       class="form-control mt-3" value="%%=v(@reasonForUnsub)=%%" placeholder="Tell us more">%%=v(@reasonForUnsub)=%%</textarea>
                    
                   <div class="com-btn mt-5">
                    <button type="submit" class="btn btn-orange"id="communications-submitbtn" name="button">Save</button>
                      <input name="submittedUnsub" type="hidden" value="true">
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
                      <input name="emails" type="hidden" value="%%=v(@email)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
    
                </div>
             </form>
            
             
              %%[
             
                                IF RequestParameter("submittedUnsub")==true then
                                  SET @sfid = RequestParameter("crmId")
                                    SET @guestId = RequestParameter("guestId")
                                    SET @emailContact = RequestParameter("emails")  
                                    SET @unsubTempBox = RequestParameter("unsubTemp")
                                    SET @unsubFreqBox = RequestParameter("unsubFreq")
                                    SET @unsubRelevanceBox = RequestParameter("unsubRelevance")
                                    SET @unsubNoDubaiBox = RequestParameter("unsubNoDubai")
                                    SET @unsubOtherBox = RequestParameter("unsubOther")
                                    SET @unsubOtherComments = RequestParameter("nameReason")
                                    SET @currentDate = Now()
                                    
                                    IF NOT Empty(@sfid) THEN
                                    
                                    IF NOT Empty(@unsubTempBox) THEN
                                    
                                    /* Nitik 06th Mar24 - add pub list to resub in CRM */
                                    
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Temporary_Pause_30_Days__c", 'true',
                                    "Emails_are_too_frequent__c",'false',
                                    "Content_isn_t_relevant__c",'false',
                                    "I_m_no_longer_in_Dubai__c",'false',
                                    "Other_Please_specify__c",'false',
                                    "fieldsToNull","Reason_of_Unsubscribe__c",
                                    "Status__c", "Subscribed",
                                    "Promotional_Offers_and_Deal__c", "True",
                                    "Annual_Pass_VIP_Offers_News_and_Info__c", "True",
                                    "Weekly_Announcements_and_News__c", "True",
                                    "New_Product_Offering_Announcements__c", "True",
                                    "Latest_news_about_other_DHE_parks__c", "True",
                                    "Customer_Survey__c", "True",
                                    "Email__c", 'True',
                                    "WhatsApp__c", 'True',
                                    "SMS__c",'True'
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
                                    "Status__c", "Unsubscribed",
                                    "Email__c", 'false',
                                    "WhatsApp__c", 'false',
                                    "SMS__c",'false'
                                    )
                                    ENDIF
                                   
                                 
                                  
                             
                                    
                                    
                                    
                                    
                                     IF NOT Empty(@unsubTempBox) THEN
                                     SET @s = upsertData("ENT.TempPauseHandle_QA", 1, "SubscriberKey", @guestId, "Email",
                                                            @emailContact,"DateAdded",@currentDate,"ContactId",@sfid, "UnsubscribeType","Individual","Asset","Roxy")
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
                                    "Reason_of_Unsubscribe__c", @unsubOtherComments,
                                    "Email__c", 'false',
                                    "WhatsApp__c", 'false',
                                    "SMS__c",'false'
                                    )
                                    /*if a sub. comes back and uncheck temp pause*/
                                    endif
                                    ENDIF
            
                                   /*Redirect(Concat("https://cloud.explore.theroxycinemas.com/thankyou_roxy_qa?sfid=", Base64Encode(@sfid), "#ThankYou"))*/
                                   set @thankYouPage = '#ThankYou'
                                   /* if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)*/
                                    /*Redirect(CONCAT(CloudPagesURL(2722),@thankYouPage))*/
                                    if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.theroxycinemas.com/thankyou_roxy_qa?sfid=", Base64Encode(@sfid), "#ThankYou"))
                                     ELSE
                                            Redirect(CONCAT(CloudPagesURL(2722),@thankYouPage))
                                    ENDIF
                                ENDIF

                                ENDIF

                        ]%%
             

           </div>

            <div class="mt-5 pl-2" style="font-size: 16px;">
              <p>If you wish to unsubscribe from all Dubai Holding Entertainment communications which include Dubai Parks™ and Resorts, Roxy Cinemas, The Green Planet™, MOTIONGATE™ Dubai, Global Village Dubai, LEGOLAND® Dubai and Real Madrid World, please click on ‘Unsubscribe all’.</p>
            </div>
            <div class="unsrb-all-btn mt-5">
              <button type="button" name="button" class="btn btn-orange unsubscribe-all-btn" onclick="unsubscribeAllClick()" id="unsubscribeAllClick">Unsubscribe All</button>
          </div>
           
           
                  <!-- Unsubscribe All reason options -->
           <div class="box-form mt-5" id="unsubscribe-all-reason">
             
            <form class="comment-form" action="" method="post">
              <span class="close-buttonAll" style="text-align: right; font-size: 30px; position: relative; left: 100%; top: 0; cursor: pointer; color:#ce5a5e;">×</span>
              <div class="container">
      <div class="unsubscribe-wrapper form group">
        <div class="thanYou-img mb-2">
             <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/6909e80c-a127-4526-a4a9-89b823125a7f.png" alt="" class="banner-bg-img">
        </div>
      <div class="thankYou-text">
       
            <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">You’ve been successfully unsubscribed. </p>  
      </div>
    
    </div>
    </div>     
                <div class="orange-notice">
                    Sorry to see you go!

                </div>
                <p style="font-size: 18px;">Please help us get better by telling us why  you're unsubscribing:</p>
                 <div class="form-check mb-2">

                       <input class="form-check-input" type="checkbox" id="chck_1" value="False" name="unsubFreq" %%=IIF(@emailsTooFrequent =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck_1">Emails are too frequent</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck_2" value="False" name="unsubRelevance" %%=IIF(@contentIsNotRelevant =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck_2">Content isn't relevant</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck_3" value="False" name="unsubNoDubai" %%=IIF(@noLongerInDubai =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck_3">I'm no longer in Dubai</label>
                   </div>
                   <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="chck_4" value="False" name="unsubAllTemp" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                    <label class="form-check-label" for="chck_4">Temporary Pause (30 Days)</label>
                </div>
                   <div class="form-check mt-2">
                       <input class="form-check-input" type="checkbox" id="myCheck_1" value="False"
                           onclick="addbox_1()" name="unsubOther" %%=IIF(@otherSpecify =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="myCheck_1">Other (Please specify)</label>
                   </div>
                   <textarea name="nameReason" rows="6" cols="80" id="area_1"
                       class="form-control mt-3" value="%%=v(@reasonForUnsub)=%%" placeholder="Tell us more">%%=v(@reasonForUnsub)=%%</textarea>
                    
                 
          
            
                <div class="com-btn mt-5">
                 <button type="submit" class="btn btn-orange"id="communications-submitbtn1" name="button">Save</button>
   <input name="unsubAll" type="hidden" value="true">
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
              <input name="emails" type="hidden" value="%%=v(@email)=%%">
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
                                                "Status__c", "Subscribed"
                                            )
                                        NEXT @i
                                    ENDIF
                                    
                                    /*Upsert data in Temp pause*/
                                    SET @s = upsertData("ENT.TempPauseHandle_QA", 1, "SubscriberKey", @guestId, "Email", @emailContact,"DateAdded",@currentDate,"ContactId",@sfid,"UnsubscribeType","All","Asset","Roxy")
                                    
                                    /*Upsert data in resub DE to resubscriber contact on enterprise level*/
                                    
                                    SET @resub = upsertData("ENT.UnsubscribeHandle_QA", 1, "SubscriberKey", @sfid, "EmailAddress", @emailContact, "SubsciberStatus", "Active","Temp_30_Days", "True","Frequency","False","Relevance","False","Not_In_Dubai","False","Other","False","Asset","Roxy")
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
                                        
                                        /* Nitik 6th Mar24, change for storing unsub reason in DE */
                                        
                                        SET @resub = upsertData("ENT.UnsubscribeHandle_QA", 1, "SubscriberKey", @sfid, "EmailAddress", @emailContact, "Frequency", IIF(Empty(@unsubFreqBox), 'False', 'True'),"Relevance", IIF(Empty(@unsubRelevanceBox), 'False', 'True'),"Not_In_Dubai", IIF(Empty(@unsubNoDubaiBox), 'False', 'True'),"Other", IIF(Empty(@unsubOtherBox), 'False', 'True'),"Temp_30_Days","False","Asset","Roxy")
                                        set @rowFound = LookupRows("ENT.TempPauseHandle_QA","SubscriberKey", @sfid)
                                        set @count = rowcount(@rowFound)
                                        if @count > 0 then
                                           set @deleteCount = DeleteData("ENT.TempPauseHandle_QA","Email", @emailContact)
                                        ENDIF
                                    
                                ENDIF
                                                                     

                              /* Redirect to the thank you page */
                              /* Redirect(Concat("https://cloud.explore.theroxycinemas.com/thankyou_roxy_qa?sfid=", Base64Encode(@sfid)))*/
                              set @thankYouPage = '#ThankYou'
                              if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                              
                              if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.theroxycinemas.com/thankyou_roxy_qa?sfid=", Base64Encode(@sfid), "#ThankYou"))
                              ELSE
                                      Redirect(CONCAT(CloudPagesURL(2722),@thankYouPage))
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
    <table width="180" style="width:180px;" cellspacing="0" cellpadding="0" border="0" align="center">
      <tbody>
      <tr>
          
      <td align="center">
      <a href="https://www.facebook.com/The-ROXY-Cinemas-275846796118635/" alias="Fb"  target="_blank"><img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/e4f05efd-047e-4c2e-8c0b-c57d0f438735.png" alt="" style="padding: 0; margin: 0;" width="42" align="center"></a>
      </td>
     
      <td align="center">
      <a href="https://www.instagram.com/theroxycinemas/" alias="Insta" target="_blank"><img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/11080598-6151-42b4-939a-2e87e1632683.png" alt="" style="padding: 0; margin: 0;" width="42" align="center"></a>
      </td>
          
      <td align="center">
      <a href="https://www.youtube.com/@theroxycinemas" alias="youtube" target="_blank"><img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/5775fd17-fb3e-439f-96fa-53bdb043be75.png" alt="" style="padding: 0; margin: 0;" width="38" align="center"></a>
      </td>
      </tr>
      </tbody>
      </table> 
  
      <p style="font-size:13px; line-height:18px; font-family:'Roboto', sans-serif; font-weight:normal; padding: 20px 20px; margin: 0; color:#fff; text-align:center; font-weight: bold;">
          DOWNLOAD ROXY CINEMAS APP WITH
      </p>
      <table width="180" style="width:180px;" cellspacing="0" cellpadding="10" border="0" align="center">
        <tbody>
        <tr>
          
        <td>
       <a href="https://play.google.com/store/apps/details?id=org.roxycinemas.com" alias="gplay" target="_blank"> <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/2adcb31f-b938-44bd-8a59-0a562f2d70bc.png" alt="" style="padding: 0; margin: 0; border-radius: 10px;" width="150" align="center"></a>
        </td>
          
        <td>
          <a href="https://appsto.re/in/WL9Jkb.i" alias="applePlay" target="_blank"> <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/3ece993f-fe01-4b55-9b5d-2c3bf71d0cce.png" alt="" style="padding: 0px; margin: 0; border-radius: 10px;" width="150" align="center">
        </td>
          
   
        
          
        </tr>
        </tbody>
        </table>
        <p style="font-size:13px; line-height:18px; font-family:'Roboto', sans-serif; font-weight:normal; padding: 20px 20px 0 20px; margin: 0; color:#fff; text-align:center; font-weight: bold;">
          OUR PARTENERS
      </p>
      <table width="180" style="width:180px;" cellspacing="0" cellpadding="0" border="0" align="center">
        <tbody>
        <tr align="center">
          
          <td>
                 <img src="https://image.explore.theroxycinemas.com/lib/fe37117373640479751476/m/1/cdb2bf9d-a3c4-403a-a39a-268904422f55.png" alt="" style="padding: 0px; margin: 0 auto; width:120px" width="120" align="center">
          </td>
          </tr>
        </tbody></table>
        <p style="font-size:10px; line-height:18px; font-family:'Roboto', sans-serif; font-weight:normal; padding: 10px 10px 15px 10px; margin: 0; color: #fff;; text-align:center;">
          Copyright 2024 &copy; Roxy Cinemas. All Rights Reserved. <a alias="Terms &amp;amp; Conditions Apply." conversion="false" data-linkto="http://" href="https://www.theroxycinemas.com/terms-of-use" style="color:#FFFFFF;text-decoration:underline;" title="Terms &amp; Conditions" target="_blank">Terms &amp; Conditions</a> Apply.  <a href="https://www.theroxycinemas.com/privacy-notice" class="text-center" style="color:#fff; text-decoration: underline;" target="_blank">Privacy policy</a> 
      </p>
   
      </footer>
      <!-- footer End -->                     
    <!-- Vendor JS-->
     <script src="https://cloud.explore.theroxycinemas.com/roxyqa_bootstrap.min.js"></script>
    <script src="https://cloud.explore.theroxycinemas.com/roxyqa_select2.min.js"></script>
    <script src="https://cloud.explore.theroxycinemas.com/roxyqa_moment.min.js"></script>
    <script src="https://cloud.explore.theroxycinemas.com/roxyqa_daterangepicker_js"></script>

    <!-- Main JS-->
    <script src="https://cloud.explore.theroxycinemas.com/roxyqa_custom.js"></script>
    <script src="https://cloud.explore.theroxycinemas.com/roxyqa_global.js"></script>
                          
                          
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
                        <label for="">Child's Name</label>
                        <input type="text" id="kidsName${i}" name="kidsName${i}" value=""
                            class="form-control nameKids" />
                    </div>
                          </div>
                            <div class="col-lg-3 col-md-3 col-sm-12 col-12">
                      <div class="form-group">
                        <label class="label">Child's Birthday</label>
                        <div class="bdate">
                          <input class="form-control" type="date"  name="kids-birthday${i}" id="kids-birthday${i}"  value="" class="kbday">
                
                
                      </div>
                    
                      </div>
                  </div>
                

                          <div class="col-lg-3 col-md-3 col-sm-12 col-12">
                            <div class="form-group">
                              <label for="">Child's Gender</label>
                              <div class="select-wrapper">
                                <select class="form-control" name="gender${i}" id="gender${i}">
                                  <option value="">Select</option>
                                   <option value="Male">Male</option>
                                  <option value="Female">Female</option>
                                 
                                  
                           
                                </select>
                                
                              </div>
                            </div>
                            
                          </div><div class="col-lg-2 col-md-2 col-sm-12 col-12"><button class="btn btn-primary del" id="${i}" value="" onclick="kidsDeletion(this);">Delete</button></div></div>
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
        console.log('inside fun2')
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
          if(document.getElementById('deletedKid'+i) && document.getElementById(i)){
            document.getElementById(i).value = document.getElementById('deletedKid'+i).value;
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
                               console.log('deleted 1', subsKey);
                               var numOfKids = document.getElementById('numOfKids').value;
                               var id = param.id;
                               
                                  //Nitik 5th Mar 24, Storing the deleted kid id's in the hidden field
                               //commented by priyanka on 18th march 
                               
                                 /* if(document.getElementById('DeletedKidsId').value  ==""){
                                   document.getElementById('DeletedKidsId').value=id;
                                  }
                                  else{
                                   document.getElementById('DeletedKidsId').value= document.getElementById('DeletedKidsId').value + ','+id;
                                  }*/
                               
                               
                                  var idFromHidden = document.getElementById('deletedKid' + id).value;
                                  document.getElementById(id).value = idFromHidden;
                                  deletedKidsListArr = idFromHidden

                               
                               /* edited by priyanka on 18 march */

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
                    url: 'https://cloud.explore.theroxycinemas.com/Roxy_KidsDelete_QA', // Replace with your CloudPage URL
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
      $("#channel-submit").click(function(e) {
        console.log('Inside channel management()')
        var guestId = document.getElementById('guestId').value;
        var subsKey = document.getElementById('crmId').value;
        var emailPref = document.getElementById('emailPref');
        var whatsAppPref = document.getElementById('WhatsAppPref');
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
                    whatsAppPref: whatsAppPref.checked
                };

                $.ajax({
                    url: 'https://cloud.explore.theroxycinemas.com/Roxy_QA_ChannelPreference', // Replace with your CloudPage URL
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
                    url: 'https://cloud.explore.theroxycinemas.com/RoxyUnsubscribe_QA', // Replace with your CloudPage URL
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
        console.log('Inside unsubscribeAllClick()');
        var subsKey = document.getElementById("crmId").value;
       //var guestId = "a5LP8000000gKQXMA2";
        var guestId =document.getElementById("guestId").value;
         console.log(subsKey);
         console.log(guestId);
        
                var dataToSend = {
                    guestId: guestId,
                    subsKey: subsKey
                };

                $.ajax({
                    url: 'https://cloud.explore.theroxycinemas.com/Roxy_UnsubscribeAll_QA', // Replace with your CloudPage URL
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