

<!--ampscript starts-->

%%[

 var @numOfKids
    SET @crmId = _subscriberkey
  
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
    
    /* owner - Priyanka 
    date - 23 Feb
    City added */
    
    /*SET @contactRows =
    RetrieveSalesforceObjects("Contact",
  "Salutation,FirstName,LastName,Email,Phone,Country_Code__c,Birthdate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,No_of_Kids__c,GenderIdentity,MailingCity,Do_you_have_kids__c",
    "Id","=", @crmId )*/
    SET @gfContactRows = RetrieveSalesforceObjects("Contact",
  "Id,Salutation,FirstName,LastName,Email,Phone,Country_Code__c,Birthdate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,No_of_Kids__c,GenderIdentity,MailingCity,Do_you_have_kids__c,GV_ContactId__c",
    "Id","=", @crmId )
SET @bfContactRows =RetrieveSalesforceObjects("Contact",
  "Id,Salutation,FirstName,LastName,Email,Phone,Country_Code__c,Birthdate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,No_of_Kids__c,GenderIdentity,MailingCity,Do_you_have_kids__c,GV_ContactId__c",
    "GV_ContactId__c","=", @crmId )
    
       IF RowCount(@gfContactRows) == 1 THEN 
        set @contactRow = Row(@gfContactRows, 1) 
        /*output(concat("<br>contactRowIf ",@contactRow)) */
        ELSEIF RowCount(@bfContactRows) == 1 THEN 
        set @contactRow = Row(@bfContactRows, 1) 
        /*output(concat("<br>contactRowElse ",@contactRow)) */
        ENDIF 
        
    if not empty(@contactRow) then /* there should only be one row */
    
    set @crmId = Field(@contactRow, "Id")
    set @GVContactId = Field(@contactRow, "GV_ContactId__c")
    set @firstName = Field(@contactRow, "FirstName")
    set @lastName = Field(@contactRow, "LastName")
    set @city = Field(@contactRow, "MailingCity")
    set @gender = Field(@contactRow, "GenderIdentity")
    set @email = Field(@contactRow, "Email")
    set @title = Field(@contactRow, "Salutation")
    set @Phone = Field(@contactRow, "Phone")
    set @mobilePhoneCode = Field(@contactRow, "Country_Code__c")
    set @birthdate = Field(@contactRow, "Birthdate")
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
    IF @married == "Married" THEN
        set @marriedStatus = "Married"
    Elseif @married == "" Then
        set @marriedStatus = ""
    ELSE 
    set @marriedStatus = "Single"
    ENDIF
    
    set @numOfKids = Field(@contactRow, "No_of_Kids__c")
    
    /* Fetching Children details */
    var @j
        
    SET @childDetails = RetrieveSalesforceObjects("Family_Member__c","Gender__c,Date_Of_Birth__c,First_Name__c",
    "Contact__c", "=", @crmId,
    "Relationship__c", "=", "Child") /*.............changed crmiden..............*/
    SET @childDetailsRowCount = Rowcount(@childDetails)
    IF @childDetailsRowCount > 0 THEN
    //SET @childExistsYes = "checked"
    For @j=1 to @childDetailsRowCount do
        SET @ChildDetailsRow = Row(@childDetails, @j)
        set @childGender = Field(@ChildDetailsRow, "Gender__c")
        set @childDOB = Field(@ChildDetailsRow, "Date_Of_Birth__c")
        set @childFirstName = Field(@ChildDetailsRow, "First_Name__c")
    next @j
    ELSE
     //SET @childExistsNo = "checked"
    ENDIF
    
   
   
    
    /* Fetching Guest Subscription details */
SET @GuestDetails = RetrieveSalesforceObjects("Guest_Subscription__c","Asset__c,Sub_Asset__c,Id,Cultural_shows__c,Dance_Troupes__c,Kids_Shows__c,Stunt_Shows__c,Street_Performances__c,ENTALL__c,Classical_Orchestras__c,DJ__c,Pop_Groups__c,Rock_Brands__c,LIVEALL__c,Bargains__c,Malls__c,Markets__c,Unique_Buys__c,Souveneirs__c,SHOPALL__c,Arcade_Games__c,Fast_Rides__c,Fairground_Rides__c,
Skill_Games__c,Horror_Scary_Rides__c,GAMEALL__c,Cafes__c,Casual_Dining__c,Celebrity_Chefs__c,Fast_Food__c,Fine_Dining__c,Street_Food__c,DININGALL__c,Reason_to_Visit__c,Reason_to_Visit2__c,
Social_Media__c,Search_Engines__c,Other_Online_Channels__c,Friends_Family__c,ENTOTHERS__c,Events_Shows_and_Concerts__c,Offers_and_Promotions__c,VIP_Packs_and_Premium_Experiences__c,
Global_Village_Latest_News__c,Email__c,SMS__c,Whatsapp__c,Push_Notification__c,I_am_not_interested_in_recieveing_commun__c, Your_messages_are_too_frequent__c,The_communication_is_not_relevant__c,I_m_no_longer_in_Dubai__c, SUBOTHERS__c, Reason_of_Unsubscribe__c,Communication_Entertainment_Comments__c,Reason_to_Visit3__c",
    "Contact__c", "=", @crmId,"Asset__c","=","Global Village","Sub_Asset__c","=","Global Village")
    
    SET @guestDetailsRowCount = Rowcount(@GuestDetails)
    IF @guestDetailsRowCount > 0 THEN /*Roxy*/
    
        SET @guestDetailsRow = Row(@GuestDetails, 1)
        SET @assetType = Field(@guestDetailsRow, "Asset__c")
        SET @Id = Field(@guestDetailsRow, "Id")
        set @entCultural = Field(@guestDetailsRow, "Cultural_shows__c")
set @entDanceTroupes = Field(@guestDetailsRow, "Dance_Troupes__c")
set @entKidsShow = Field(@guestDetailsRow, "Kids_Shows__c")
set @entStunt = Field(@guestDetailsRow, "Stunt_Shows__c")
set @entStreet = Field(@guestDetailsRow, "Street_Performances__c")
set @entAll = Field(@guestDetailsRow, "ENTALL__c")

set @musicClassical = Field(@guestDetailsRow, "Classical_Orchestras__c")
set @musicDJ = Field(@guestDetailsRow, "DJ__c")
set @musicPop = Field(@guestDetailsRow, "Pop_Groups__c")
set @musicRock = Field(@guestDetailsRow, "Rock_Brands__c")
set @musicAll = Field(@guestDetailsRow, "LIVEALL__c")

set @shopBargain = Field(@guestDetailsRow, "Bargains__c")
set @shopMall = Field(@guestDetailsRow, "Malls__c")
set @shopMarket = Field(@guestDetailsRow, "Markets__c")
set @shopUnique = Field(@guestDetailsRow, "Unique_Buys__c")
set @shopSouveinrs = Field(@guestDetailsRow, "Souveneirs__c")
set @shopAll = Field(@guestDetailsRow, "SHOPALL__c")

set @gameArcade = Field(@guestDetailsRow, "Arcade_Games__c")
set @gameFastRides = Field(@guestDetailsRow, "Fast_Rides__c")
set @gameFairgroundRides = Field(@guestDetailsRow, "Fairground_Rides__c")
set @gameSkill = Field(@guestDetailsRow, "Skill_Games__c")
set @gameHorror = Field(@guestDetailsRow, "Horror_Scary_Rides__c")
set @gameAll = Field(@guestDetailsRow, "GAMEALL__c")

set @dineCafe = Field(@guestDetailsRow, "Cafes__c")
set @dineCasual = Field(@guestDetailsRow, "Casual_Dining__c")
set @dineCelebChefs = Field(@guestDetailsRow, "Celebrity_Chefs__c")
set @dineFastFood = Field(@guestDetailsRow, "Fast_Food__c")
set @dineFine = Field(@guestDetailsRow, "Fine_Dining__c")
set @dineStreetFood = Field(@guestDetailsRow, "Street_Food__c")
set @dineAll = Field(@guestDetailsRow, "DININGALL__c")

set @reasonToVisit1 = Field(@guestDetailsRow, "Reason_to_Visit__c")
set @reasonToVisit2 = Field(@guestDetailsRow, "Reason_to_Visit2__c")
set @reasonToVisit3 = Field(@guestDetailsRow, "Reason_to_Visit3__c")

set @updatesSocial = Field(@guestDetailsRow, "Social_Media__c")
set @updatesSearch = Field(@guestDetailsRow, "Search_Engines__c")
set @updatesOtherOnline = Field(@guestDetailsRow, "Other_Online_Channels__c")
set @updatesFF = Field(@guestDetailsRow, "Friends_Family__c")
set @updatesOther = Field(@guestDetailsRow, "ENTOTHERS__c")
set @updatesOtherComments = Field(@guestDetailsRow, "Communication_Entertainment_Comments__c")

set @hearEvents = Field(@guestDetailsRow, "Events_Shows_and_Concerts__c")
set @hearOffers = Field(@guestDetailsRow, "Offers_and_Promotions__c")
set @hearVIP = Field(@guestDetailsRow, "VIP_Packs_and_Premium_Experiences__c")
set @hearLatest = Field(@guestDetailsRow, "Global_Village_Latest_News__c")

set @emailPref = Field(@guestDetailsRow, "Email__c")
set @smsPref = Field(@guestDetailsRow, "SMS__c")
set @WhatsAppPref = Field(@guestDetailsRow, "Whatsapp__c")

set @unsubnoCommThisSeason = Field(@guestDetailsRow, "I_am_not_interested_in_recieveing_commun__c")
set @unsubTooFrequent = Field(@guestDetailsRow, "Your_messages_are_too_frequent__c")
set @unsubNoRelevant = Field(@guestDetailsRow, "The_communication_is_not_relevant__c")
set @unsubNotInDubai = Field(@guestDetailsRow, "I_m_no_longer_in_Dubai__c")
set @unsubOthers = Field(@guestDetailsRow, "SUBOTHERS__c")
set @unsubComments = Field(@guestDetailsRow, "Reason_of_Unsubscribe__c")



/* Entertainment and Shows */
IF @entCultural == 'True' THEN
    SET @entCulturalBox = 'checked'
ELSEIF @entAll == 'True' THEN
    SET @entCulturalBox = 'checked'
    SET @entAllBox = 'checked'
ELSE 
    SET @entCulturalBox= ''
ENDIF

IF @entDanceTroupes == 'True' THEN
    SET @entDanceTroupesBox = 'checked'
ELSEIF @entAll == 'True' THEN
    SET @entDanceTroupesBox = 'checked'
    SET @entAllBox = 'checked'
ELSE 
    SET @entDanceTroupesBox= ''
ENDIF

IF @entKidsShow == 'True' THEN
    SET @entKidsShowBox = 'checked'
ELSEIF @entAll == 'True' THEN
    SET @entKidsShowBox = 'checked'
    SET @entAllBox = 'checked'
ELSE 
    SET @entKidsShowBox= ''
ENDIF

IF @entStunt == 'True' THEN
    SET @entStuntBox = 'checked'
ELSEIF @entAll == 'True' THEN
    SET @entStuntBox = 'checked'
    SET @entAllBox = 'checked'
ELSE 
    SET @entStuntBox= ''
ENDIF

IF @entStreet == 'True' THEN
    SET @entStreetBox = 'checked'
ELSEIF @entAll == 'True' THEN
    SET @entStreetBox = 'checked'
    SET @entAllBox = 'checked'
ELSE 
    SET @entStreetBox= ''
ENDIF

IF @entAll == 'True' THEN
    SET @entAllBox = 'checked'
ELSE 
    SET @entAllBox= ''
ENDIF

/* Live Music */
IF @musicClassical == 'True' THEN
    SET @musicClassicalBox = 'checked'
ELSEIF @musicAll == 'True' THEN
    SET @musicClassicalBox = 'checked'
    SET @musicAllBox = 'checked'
ELSE 
    SET @musicClassicalBox = ''
ENDIF

IF @musicDJ == 'True' THEN
    SET @musicDJBox = 'checked'
ELSEIF @musicAll == 'True' THEN
    SET @musicDJBox = 'checked'
    SET @musicAllBox = 'checked'
ELSE 
    SET @musicDJBox = ''
ENDIF

IF @musicPop == 'True' THEN
    SET @musicPopBox = 'checked'
ELSEIF @musicAll == 'True' THEN
    SET @musicPopBox = 'checked'
    SET @musicAllBox = 'checked'
ELSE 
    SET @musicPopBox = ''
ENDIF

IF @musicRock == 'True' THEN
    SET @musicRockBox = 'checked'
ELSEIF @musicAll == 'True' THEN
    SET @musicRockBox = 'checked'
    SET @musicAllBox = 'checked'
ELSE 
    SET @musicRockBox= ''
ENDIF

IF @musicAll == 'True' THEN
    SET @musicAllBox = 'checked'
ELSE 
    SET @musicAllBox = ''
ENDIF

/* Shopping */
IF @shopBargain == 'True' THEN
    SET @shopBargainBox = 'checked'
ELSEIF @shopAll == 'True' THEN
    SET @shopBargainBox = 'checked'
    SET @shopAllBox = 'checked'
ELSE 
    SET @shopBargainBox = ''
ENDIF

IF @shopMall == 'True' THEN
    SET @shopMallBox = 'checked'
ELSEIF @shopAll == 'True' THEN
    SET @shopMallBox = 'checked'
    SET @shopAllBox = 'checked'
ELSE 
    SET @shopMallBox = ''
ENDIF

IF @shopMarket == 'True' THEN
    SET @shopMarketBox = 'checked'
ELSEIF @shopAll == 'True' THEN
    SET @shopMarketBox = 'checked'
    SET @shopAllBox = 'checked'
ELSE 
    SET @shopMarketBox = ''
ENDIF

IF @shopUnique == 'True' THEN
    SET @shopUniqueBox = 'checked'
ELSEIF @shopAll == 'True' THEN
    SET @shopUniqueBox = 'checked'
    SET @shopAllBox = 'checked'
ELSE 
    SET @shopUniqueBox= ''
ENDIF

IF @shopSouveinrs == 'True' THEN
    SET @shopSouveinrsBox = 'checked'
ELSEIF @shopAll == 'True' THEN
    SET @shopSouveinrsBox = 'checked'
    SET @shopAllBox = 'checked'
ELSE 
    SET @shopSouveinrsBox= ''
ENDIF

IF @shopAll == 'True' THEN
    SET @shopAllBox = 'checked'
ELSE 
    SET @shopAllBox = ''
ENDIF

/* Ride And Games */
IF @gameArcade == 'True' THEN
    SET @gameArcadeBox = 'checked'
ELSEIF @gameAll == 'True' THEN
    SET @gameArcadeBox = 'checked'
    SET @gameAllBox = 'checked'
ELSE 
    SET @gameArcadeBox = ''
ENDIF

IF @gameFastRides == 'True' THEN
    SET @gameFastRidesBox = 'checked'
ELSEIF @gameAll == 'True' THEN
    SET @gameFastRidesBox = 'checked'
    SET @gameAllBox = 'checked'
ELSE 
    SET @gameFastRidesBox = ''
ENDIF

IF @gameFairgroundRides == 'True' THEN
    SET @gameFairgroundRidesBox = 'checked'
ELSEIF @gameAll == 'True' THEN
    SET @gameFairgroundRidesBox = 'checked'
    SET @gameAllBox = 'checked'
ELSE 
    SET @gameFairgroundRidesBox = ''
ENDIF

IF @gameSkill == 'True' THEN
    SET @gameSkillBox = 'checked'
ELSEIF @gameAll == 'True' THEN
    SET @gameSkillBox = 'checked'
    SET @gameAllBox = 'checked'
ELSE 
    SET @gameSkillBox = ''
ENDIF

IF @gameHorror == 'True' THEN
    SET @gameHorrorBox = 'checked'
ELSEIF @gameAll == 'True' THEN
    SET @gameHorrorBox = 'checked'
    SET @gameAllBox = 'checked'
ELSE 
    SET @gameHorrorBox = ''
ENDIF

IF @gameAll == 'True' THEN
    SET @gameAllBox = 'checked'
ELSE 
    SET @gameAllBox = ''
ENDIF

/* Dining */
IF @dineCafe == 'True' THEN
    SET @dineCafeBox = 'checked'
ELSEIF @dineAll == 'True' THEN
    SET @dineCafeBox = 'checked'
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineCafeBox = ''
ENDIF

IF @dineCasual == 'True' THEN
    SET @dineCasualBox = 'checked'
ELSEIF @dineAll == 'True' THEN
    SET @dineCasualBox = 'checked'
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineCasualBox = ''
ENDIF

IF @dineCelebChefs == 'True' THEN
    SET @dineCelebChefsBox = 'checked'
ELSEIF @dineAll == 'True' THEN
    SET @dineCelebChefsBox = 'checked'
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineCelebChefsBox = ''
ENDIF

IF @dineFastFood == 'True' THEN
    SET @dineFastFoodBox = 'checked'
ELSEIF @dineAll == 'True' THEN
    SET @dineFastFoodBox = 'checked'
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineFastFoodBox = ''
ENDIF

IF @dineFine == 'True' THEN
    SET @dineFineBox = 'checked'
ELSEIF @dineAll == 'True' THEN
    SET @dineFineBox = 'checked'
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineFineBox = ''
ENDIF

IF @dineStreetFood == 'True' THEN
    SET @dineStreetFoodBox = 'checked'
ELSEIF @dineAll == 'True' THEN
    SET @dineStreetFoodBox = 'checked'
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineStreetFoodBox = ''
ENDIF

IF @dineAll == 'True' THEN
    SET @dineAllBox = 'checked'
ELSE 
    SET @dineAllBox = ''
ENDIF

/* Reasons */
IF @reasonToVisit1 == 'To keep my kids entertained' THEN
    SET @visitReasonSelected1 = 'ranking'
ELSEIF @reasonToVisit1 == 'To hangout with friends' THEN
    SET @visitReasonSelected1 = 'ranking1'
ELSEIF @reasonToVisit1 == 'To enjoy the lively atmosphere' THEN
    SET @visitReasonSelected1 = 'ranking2'
ELSEIF @reasonToVisit1 == "It's a tourist attraction" THEN
    SET @visitReasonSelected1 = 'ranking3'
ELSEIF @reasonToVisit1 == 'To entertain guests' THEN
    SET @visitReasonSelected1 = 'ranking4'
ELSEIF @reasonToVisit1 == 'For great shows and events' THEN
    SET @visitReasonSelected1 = 'ranking5'
ELSEIF @reasonToVisit1 == 'To shop for unique cultural items' THEN
    SET @visitReasonSelected1 = 'ranking6'
ELSEIF @reasonToVisit1 == 'The carnaval experience' THEN
    SET @visitReasonSelected1 = 'ranking7'
ELSEIF @reasonToVisit1 == 'To celebrate special occasions' THEN
    SET @visitReasonSelected1 = 'ranking8'
ELSEIF @reasonToVisit1 == 'For its international cuisine' THEN
    SET @visitReasonSelected1 = 'ranking9'
ELSEIF @reasonToVisit1 == 'For some quality family time' THEN
    SET @visitReasonSelected1 = 'ranking10'
ENDIF

IF @reasonToVisit2 == 'To keep my kids entertained' THEN
    SET @visitReasonSelected2 = 'ranking'
ELSEIF @reasonToVisit2 == 'To hangout with friends' THEN
    SET @visitReasonSelected2 = 'ranking1'
ELSEIF @reasonToVisit2 == 'To enjoy the lively atmosphere' THEN
    SET @visitReasonSelected2 = 'ranking2'
ELSEIF @reasonToVisit2 == "It's a tourist attraction" THEN
    SET @visitReasonSelected2 = 'ranking3'
ELSEIF @reasonToVisit2 == 'To entertain guests' THEN
    SET @visitReasonSelected2 = 'ranking4'
ELSEIF @reasonToVisit2 == 'For great shows and events' THEN
    SET @visitReasonSelected2 = 'ranking5'
ELSEIF @reasonToVisit2 == 'To shop for unique cultural items' THEN
    SET @visitReasonSelected2 = 'ranking6'
ELSEIF @reasonToVisit2 == 'The carnaval experience' THEN
    SET @visitReasonSelected2 = 'ranking7'
ELSEIF @reasonToVisit2 == 'To celebrate special occasions' THEN
    SET @visitReasonSelected2 = 'ranking8'
ELSEIF @reasonToVisit2 == 'For its international cuisine' THEN
    SET @visitReasonSelected2 = 'ranking9'
ELSEIF @reasonToVisit2 == 'For some quality family time' THEN
    SET @visitReasonSelected2 = 'ranking10'
ENDIF

IF @reasonToVisit3 == 'To keep my kids entertained' THEN
    SET @visitReasonSelected3 = 'ranking'
ELSEIF @reasonToVisit3 == 'To hangout with friends' THEN
    SET @visitReasonSelected3 = 'ranking1'
ELSEIF @reasonToVisit3 == 'To enjoy the lively atmosphere' THEN
    SET @visitReasonSelected3 = 'ranking2'
ELSEIF @reasonToVisit3 == "It's a tourist attraction" THEN
    SET @visitReasonSelected3 = 'ranking3'
ELSEIF @reasonToVisit3 == 'To entertain guests' THEN
    SET @visitReasonSelected3 = 'ranking4'
ELSEIF @reasonToVisit3 == 'For great shows and events' THEN
    SET @visitReasonSelected3 = 'ranking5'
ELSEIF @reasonToVisit3 == 'To shop for unique cultural items' THEN
    SET @visitReasonSelected3 = 'ranking6'
ELSEIF @reasonToVisit3 == 'The carnaval experience' THEN
    SET @visitReasonSelected3 = 'ranking7'
ELSEIF @reasonToVisit3 == 'To celebrate special occasions' THEN
    SET @visitReasonSelected3 = 'ranking8'
ELSEIF @reasonToVisit3 == 'For its international cuisine' THEN
    SET @visitReasonSelected3 = 'ranking9'
ELSEIF @reasonToVisit3 == 'For some quality family time' THEN
    SET @visitReasonSelected3 = 'ranking10'
ENDIF
Endif
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
   

        var subscriberKey = Platform.Request.GetFormField('crmId') || "";
        var profileSalutation = Platform.Request.GetFormField('profileSalutation') || "";
        var firstName = Platform.Request.GetFormField('firstName') || "";
        var lastName = Platform.Request.GetFormField('lastName') || "";
        var phone = Platform.Request.GetFormField('phone') || "";
        var city = Platform.Request.GetFormField('city') || "";
        var birthdate = Platform.Request.GetFormField('birthday') || "";
        var profileLang = Platform.Request.GetFormField('profileLang') || "";
        var profileNationality = Platform.Request.GetFormField('profileNationality') || "";
        var profileCountry = Platform.Request.GetFormField('profileCountry') || "";
        var profileMarried = Platform.Request.GetFormField('inlineRadioOptions') || "";
        if(profileMarried=='option2'){
            profileMarriedStatus = 'Yes';
        }
        else{
            profileMarriedStatus = 'No';
        }
        var profileChildren = Platform.Request.GetFormField('kidsExists') || "";
        if(profileChildren=='kids-yes'){
            profileChildrenStatus = 'Yes';
        }
        else if(profileMarried==''){
          profileMarriedStatus = '';
        }
        else{
            profileChildrenStatus = 'No';
        }
        var email = Platform.Request.GetFormField('email') || "";

  
  
        var listOffers = Platform.Request.GetFormField('hearOffers') || False;
        var listEvents = Platform.Request.GetFormField('hearEvents') || false;
        var listRides = Platform.Request.GetFormField('newRides') || false;
        var listFood = Platform.Request.GetFormField('newFood') || false;
        var listHotels = Platform.Request.GetFormField('hotelsResorts') || false;
        var listCustomer = Platform.Request.GetFormField('cutomerSurvey') || false;
        var tempPause = Platform.Request.GetFormField('unsubTemp');

        var unsubscribe = Platform.Request.GetFormField('submittedUnsub') || false;

        var listOfInput = [];
        listOfInput.push({Name : 'Dubai Parks and Resorts - Offers and Promotions', Status: listOffers})
        listOfInput.push({Name : 'DPR - Upcoming events for families', Status: listEvents})
        listOfInput.push({Name : 'DPR - New rides and entertainment', Status: listRides})
        listOfInput.push({Name : 'DPR - New food and restaurants', Status: listFood})
        listOfInput.push({Name : 'DPR - Hotels and resorts', Status: listHotels})
        listOfInput.push({Name : 'DPR - Customer Survey', Status: listCustomer})
 
  
  

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
      if (!tempPause) {
        var unsubscribeSatus = subObj.Unsubscribe();
        Variable.SetValue("unsubscribeSatus", unsubscribeSatus);
      }
      else {
        /* 21st feb
        Priyanka
        DHE- 3644
        added the code for resubscribing to all the publication list of current Bu */
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
                        <html lang="ar" dir="ltr">
                            <head>
                              <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
     <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                                <title>Global Village</title>
 <link rel="icon" type="image/x-icon" href="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/7a114a43-1bec-400c-8b8d-6b527f658a77.png">
                                <link href='https://cloud.explore.globalvillage.ae/GV_QA_ARbootstrap.min.css' rel='stylesheet'>
                                
                                <script type='text/javascript' src='https://cloud.explore.globalvillage.ae/jqueryV2.min_gv_ar_qa'></script>
                                <link href="https://cloud.explore.globalvillage.ae/material-design-iconic-font.min_AR_GV_QA" rel="stylesheet" media="all">
                                <link href="https://cloud.explore.globalvillage.ae/font-awesome.min_gv_ar_qa" rel="stylesheet" media="all">
                                <!-- Font special for pages-->
                                <link href="https://fonts.googleapis.com/css?family=Poppins:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i,800,800i,900,900i" rel="stylesheet">
                                <link href="https://cloud.explore.globalvillage.ae/Style_GV_AR_QA" rel="stylesheet">
                                
                              
                                <link href="https://cloud.explore.dubaiholdingentertainment.com/font_gv_ar_qa">
                                <!-- Vendor CSS-->
                                <link href="https://cloud.explore.globalvillage.ae/select2.min_gv_ar_qa" rel="stylesheet" media="all">
                                <link href="https://cloud.explore.globalvillage.ae/daterangepicker_gv_ar_qa" rel="stylesheet" media="all">
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
  color:#20295c
}

.nav-pills .nav-link.active {
  color: #fff;
    background-color: #20295c;
 
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
  float: left;
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
  Platform.Response.SetResponseHeader("Content-Security-Policy","script-src 'self' 'unsafe-inline' https://cloud.explore.globalvillage.ae; frame-ancestors 'none'");
    

</script>
                                </head>
                          
            <body onload="handleNumOfKidsChange(%%=v(@numOfKids)=%%); kidsPrepopulation(); ShowHideDivkids(); validateForm();">
              
                                   <!-- Header start -->
        <header>
          <div class="container">
              <div class="row align-items-center" style="margin: 0 auto;">
                  <div class="col-lg-8 col-md-8 col-sm-8 col-8">
                      <a href="https://www.dubaiparksandresorts.com/en" class="logo-link" target="_blank">
                          <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/b477579f-ab92-4f97-949e-7a2c79695d1d.png"
                              alt="GVlogo">
                      </a>
                  </div>
                  <div class="col-lg-4 col-md-4 col-sm-4 col-4">

                  <a href="%%=RedirectTo(Concat("https://cloud.explore.globalvillage.ae/SANDBOX_GV_AR_CPC?sfid=",Base64Encode(@crmId)))=%%" class="lang-switcher" id="langSwitcher" onclick="dynamicLangSwitcher();" style="text-decoration: underline;">العربية</a>

                  </div>
              </div>
          </div>
      </header>
      <!-- Header End --><section class="banner">
                                  <div class="main-banner">
                                    <img src= "http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/2/0831cc5c-dbb7-4cd0-ac66-bb6d3311cf06.jpg" alt="banner-img" class="responsive" id="desktop-img">
                                     <img src= "http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/2/0831cc5c-dbb7-4cd0-ac66-bb6d3311cf06.jpg" alt="banner-img" class="responsive" id="mob-img">
                                        </div>
                                        <div class="container">
                                          <h1 class="username">Hi %%=v(ProperCase(@firstName))=%% </h1>
                                      </div>
                                      </section>

                                 <div class="container card content-wrapper">
      <!-- nav options -->
      <ul class="nav nav-pills mb-3 d-flex justify-content-center" id="pills-tab" role="tablist">
        <li class="nav-item">
          <a class="nav-link active" id="my-profile-tab" data-toggle="pill" href="#my-profile" role="tab" aria-controls="my-profile" aria-selected="true"onclick="updateUrlHash('#my-profile')"> الملف الشخصي</a>
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
              <p>عالم أكثر روعة في انتظاركم في القرية العالمية، ولكن التجارب والأمور المفضلة تختلف من شخص لآخر وكلما تعرفنا إليكم
                    أكثر، قمنا بتصميم وتخصيص تجربتكم لتناسبكم بشكل أفضل. يمكنكم مساعدتنا في ذلك، عبر تخصيص بضع دقائق لتعرّوفنا
                    باهتماماتكم وتفضيلاتكم، ثم دعوا الباقي علينا!
              </p>
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
                               
                         <input type="text"class="form-control" list="codedatalistOptions" name="lang" id="country-code"  placeholder="+971" value="%%=v(@mobilePhoneCode)=%%" required>
  
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
                <!--Hidden field to store Deleted Kids IDs-->
                <input class="form-control" type="hidden" name="DeletedKidsId"  value="" id="DeletedKidsId">
                 

               <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                      <div class="form-group" data-aos="fade-up"
                          data-aos-anchor-placement="bottom-bottom">
                          <label for="">بلد الإقامة<sup class="text-danger">*</sup></label>
                          <div class="select-wrapper profilecountry">
  
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
<option value="Republic of Moldova" %%=IIF(@country=='Republic of Moldova', "selected", "")=%%>مولدوفا</option>
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
<option value="Saint-Barthelemy" %%=IIF(@country=='Saint-Barthelemy', "selected", "")=%%>سانت بارتيليمي</option>
<option value="Saint-Martin (French part)" %%=IIF(@country=='Saint-Martin (French part)', "selected", "")=%%>سانت مارتن (الجزء الفرنسي)</option>
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
<option value="Wallis And Futuna Islands" %%=IIF(@country=='Wallis And Futuna Islands', "selected", "")=%%>جزر واليس وفوتونا</option>
<option value="Western Sahara" %%=IIF(@country=='Western Sahara', "selected", "")=%%>الصحراء الغربية</option>
<option value="Yemen" %%=IIF(@country=='Yemen', "selected", "")=%%>اليمن</option>
<option value="Zambia" %%=IIF(@country=='Zambia', "selected", "")=%%>زامبيا</option>
<option value="Zimbabwe" %%=IIF(@country=='Zimbabwe', "selected", "")=%%>زمبابوي</option>





  
                     </select>
                   
                          </div>
                      </div>
                  </div>

                  <div class="col-lg-4 col-md-6 col-sm-12 col-12">
                    <div class="form-group">
                      <label for="">المدينة (<b style="
    font-size: 11px;">المقيمين في دولة الإمارات العربية المتحدة فقط</b>)</label>
                        <div class="select-wrapper hide-icon custom-">
                          
                          <!-- Priyanka 23 Feb, added ampscript for city -->

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
                        <label for="">الجنسية (<b style="
    font-size: 11px;">المقيمين في دولة الإمارات العربية المتحدة فقط</b>)</label>
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
<option value="Republic of Moldova" %%=IIF(@nationality=='Republic of Moldova', "selected", "")=%%>مولدوفا</option>
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
<option value="Saint-Barthelemy" %%=IIF(@nationality=='Saint-Barthelemy', "selected", "")=%%>سانت بارتيليمي</option>
<option value="Saint-Martin (French part)" %%=IIF(@nationality=='Saint-Martin (French part)', "selected", "")=%%>سانت مارتن (الجزء الفرنسي)</option>
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
<option value="Wallis And Futuna Islands" %%=IIF(@nationality=='Wallis And Futuna Islands', "selected", "")=%%>جزر واليس وفوتونا</option>
<option value="Western Sahara" %%=IIF(@nationality=='Western Sahara', "selected", "")=%%>الصحراء الغربية</option>
<option value="Yemen" %%=IIF(@nationality=='Yemen', "selected", "")=%%>اليمن</option>
<option value="Zambia" %%=IIF(@nationality=='Zambia', "selected", "")=%%>زامبيا</option>
<option value="Zimbabwe" %%=IIF(@nationality=='Zimbabwe', "selected", "")=%%>زمبابوي</option>



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
                               <option value=" " selected>Select</option>
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
                          <input class="form-control" type="date" name="birthday"  value="%%=v(@birthdate)=%%" id="birthday">
                
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
                <label for="">Marital Status
                </label>
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
      <div class="form-group pt-4">
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
                      <label for="numOfKids">هل لديك أطفال؟ </label>
                      <div class="select-wrapper">
  
                          <select class="form-control selectpicker" name="state" id="numOfKids" onclick="kidsPrepopulation();">
                              <option value="0" %%=IIF(@numOfKids==0, "selected", "")=%%>اختر</option>
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
                  
  
              </div>
            </div>
              <div class="kids-info" id="kids-info">
                <div id="kidsTable" width="100%">
                  
                </div>
              </div>
      
  <p class="disclaimer" style="font-size:12px;"><i>نطلب تاريخ ميلاد طفلك لكي نتمكن من إرسال تهاني عيد ميلاده، بالإضافة إلى اطلاعك على أحدث الفعاليات والعروض الترويجية.</i></p>
      </div>
  
  </div>
          
         

                          %%[

    /*SET @crmIdEn = "0036M00004ZS6Y4QAL"*/
   /* SET @crmIdEn = QueryParameter("sfid")
    SET @crmIdJS = Base64Decode(@crmIdEn) */
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
SET @gfContactRows = RetrieveSalesforceObjects("Contact",
  "Id,Salutation,FirstName,LastName,Email,Phone,Country_Code__c,Birthdate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,No_of_Kids__c,GenderIdentity,MailingCity,Do_you_have_kids__c,GV_ContactId__c",
    "Id","=", @crmId )
SET @bfContactRows =RetrieveSalesforceObjects("Contact",
  "Id,Salutation,FirstName,LastName,Email,Phone,Country_Code__c,Birthdate,Registration_Language__c,Nationality__c,Marital_Status__c,Residence_Country__c,No_of_Kids__c,GenderIdentity,MailingCity,Do_you_have_kids__c,GV_ContactId__c",
    "GV_ContactId__c","=", @crmId )
    
       IF RowCount(@gfContactRows) == 1 THEN 
        set @contactRow = Row(@gfContactRows, 1) 
        /*output(concat("<br>contactRowIf ",@contactRow)) */
        ELSEIF RowCount(@bfContactRows) == 1 THEN 
        set @contactRow = Row(@bfContactRows, 1) 
        /*output(concat("<br>contactRowElse ",@contactRow)) */
        ENDIF 
        
    if not empty(@contactRow) then /* there should only be one row */
    
    set @crmId = Field(@contactRow, "Id")
    
    endif
    IF NOT EMPTY(@crmId) THEN                /*...........uncommented.................*/
    /*IF NOT EMPTY(@crmIdEn) THEN*/
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
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
            <input name="emails" type="hidden" value="%%=v(@email)=%%">
            <input name="numberOfKids" type="hidden" value="%%=v(@numOfKids)=%%">
              </form>
        
         %%[
         var @sfid
                                IF RequestParameter("submittedProfile")==true then
                                        SET @sfid = RequestParameter("crmId")
                                        SET @emailContact = RequestParameter("emails")  
                                        SET @profileSalutation = RequestParameter("profileSalutation")
                                        SET @firstName = RequestParameter("firstName")
                                        SET @lastName = RequestParameter("lastName")
                                        set @gender = RequestParameter("gender")
                                        set @city = RequestParameter("city")
                                        set @numOfKids = RequestParameter("numberOfKids")
                                        /* variable to fetch the deleted kids Ids from hidden field */
                                        SET @deletedKidsId = RequestParameter("DeletedKidsId")
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
                                        /*IF @profileMarriedBox == 'option2' THEN
                                            SET @marriedStatus = 'Married'
                                        Elseif @profileMarriedBox == '' Then
                                            set @marriedStatus = ''
                                        ELSE
                                            SET @marriedStatus = 'Single'
                                        ENDIF*/
                                        
                                        
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
                                        
                                      
                                        
                                        IF NOT Empty(@sfid) THEN
                                        
                                     
                                        IF Empty(@birthdate) THEN
                                            SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "fieldsToNull", "Birthdate"
                                            )
                                       ELSE
                                           SET @updateRecord = UpdateSingleSalesforceObject(
                                            "Contact", @sfid,
                                            "Birthdate", @birthdate
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
                                        /*Redirect(Concat("https://cloud.explore.globalvillage.ae/EN_CPC?sfid=", Base64Encode(@sfid), "#Form2"))*/
                                        /*Redirect(Concat("https://cloud.explore.globalvillage.ae/index_dpr_dev?sfid=", Base64Encode(@sfid), "#interests"))*/
                                        
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
                                      Redirect(Concat("https://cloud.explore.globalvillage.ae/GVQA_CPC?sfid=", Base64Encode(@sfid), "#interests"))
                                   ELSE
                                      Redirect(CONCAT(CloudPagesURL(3269),@interests))
                                   ENDIF
                                   
                                   endif

        ]%%
       
        
        
            </div>
        </div>
        <!-- 2nd card Interest tab-->
                                   
                               
        <div class="tab-pane fade interest-tab-content" id="interests" role="tabpanel" aria-labelledby="interests-tab">
          
            <div class="wrapper wrapper--w700">
              
              <form class="interest-form" action="" method="post" name="myForm" id="interest-form" autocomplete="off" >
              <h4 class="pt-4 pb-3">ما هي مجالات اهتمامك؟<sup class="text-danger">*</sup>
              </h4>
              <div class="row interest-top-row">
                <!-- yellow box -->
                <div class="col-lg-2 col-md-4 col-sm-6 col-12">
                  <div class="cards yellow-cards cards-select">
                    <div class="cards-img">
                      <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/11c2b50b-4196-4ac3-9b17-9d89e47e9db5.png"
                           class="cards-img-top" alt="">
                      <h6>ترفيه وعروض</h6>
                    </div>
                    <div class="cards-body">
                      <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="%%=IIF(@entCulturalBox =='checked', 'True', 'False')=%%"
                               id="box-check1" %%=v(@entCulturalBox)=%% name="culturalShow" data-id="box-custom">
                        <label class="form-check-label" for="box-check1">
                          عروض ثقافية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="%%=IIF(@entDanceTroupesBox =='checked', 'True', 'False')=%%"
                               id="box-check2" %%=v(@entDanceTroupesBox)=%% name="DanceTroupesBox" data-id="box-custom">
                        <label class="form-check-label" for="box-check2">
                          فرق رقص
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@entKidsShowBox =='checked', 'True', 'False')=%%"
                               id="box-check3" %%=v(@entKidsShowBox)=%% name="KidsShowBox">
                        <label class="form-check-label" for="box-check3">
                          عروض أطفال
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@entStuntBox =='checked', 'True', 'False')=%%"
                               id="box-check4" %%=v(@entStuntBox)=%% name="StuntBox">
                        <label class="form-check-label" for="box-check4">
                          عروض شيقة
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@entStreetBox =='checked', 'True', 'False')=%%"
                               id="box-check6" %%=v(@entStreetBox)=%% name="StreetBox">
                        <label class="form-check-label" for="box-check6">
                          عروض متجولة
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input select-all" id="select-all-yellow"type="checkbox" value="%%=IIF(@entAllBox =='checked', 'True', 'False')=%%"
                               id="concert-check100" %%=v(@entAllBox)=%% name="entAll">
                        <label class="form-check-label" for="select-all-yellow">
                          اختر الكل
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- blue box -->
                <div class="col-lg-2 col-md-4 col-sm-6 col-12">
                  <div class="cards blue-cards cards-select">
                    <div class="cards-img">
                      <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/54d8c02f-7981-4079-86c3-4efa099aa11d.png"
                           class="cards-img-top" alt="">
                      <h6>حفلات موسيقية</h6>
                    </div>
                    <div class="cards-body">
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@musicClassicalBox =='checked', 'True', 'False')=%%"
                               id="concert-check1" %%=v(@musicClassicalBox)=%% name="ClassicalBox">
                        <label class="form-check-label" for="concert-check1">
                          أوركسترات كلاسيكية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@musicDJBox =='checked', 'True', 'False')=%%"
                               id="concert-check2" %%=v(@musicDJBox)=%% name="DJBox">
                       <label class="form-check-label" for="concert-check2">
                                منسقو الموسيقى (دي جي)
                              </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@musicPopBox =='checked', 'True', 'False')=%%"
                               id="concert-check3" %%=v(@musicPopBox)=%% name="PopBox">
                        <label class="form-check-label" for="concert-check3">
                          فرق بوب
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@musicRockBox =='checked', 'True', 'False')=%%"
                               id="concert-check4" %%=v(@musicRockBox)=%% name="RockBox">
                        <label class="form-check-label" for="concert-check4">
                          فرق موسيقى الروك
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input select-all" id="select-all-blue" type="checkbox" value="%%=IIF(@musicAllBox =='checked', 'True', 'False')=%%"
                               id="concert-check5" %%=v(@musicAllBox)=%% name="musicAll">
                        <label class="form-check-label" for="select-all-blue">
                          اختر الكل
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- red box -->
                <div class="col-lg-2 col-md-4 col-sm-6 col-12">
                  <div class="cards red-cards cards-select">
                    <div class="cards-img">
                      <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/e7f938b3-1ff7-4073-bb76-ee87b83aa128.png"
                           class="cards-img-top" alt="">
                      <h6>تسوق</h6>
                    </div>
                    <div class="cards-body">
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@shopBargainBox =='checked', 'True', 'False')=%%"
                               id="shop-check2" %%=v(@shopBargainBox)=%% name="shopBargain">
                        <label class="form-check-label" for="shop-check2">
                         صفقات
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@shopMallBox =='checked', 'True', 'False')=%%"
                               id="shop-check3" %%=v(@shopMallBox)=%% name="shopMall">
                        <label class="form-check-label" for="shop-check3">
                         مولات
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@shopMarketBox =='checked', 'True', 'False')=%%"
                               id="shop-check4" %%=v(@shopMarketBox)=%% name="shopMarket">
                        <label class="form-check-label" for="shop-check4">
                          أسواق
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@shopUniqueBox =='checked', 'True', 'False')=%%"
                               id="shop-check5" %%=v(@shopUniqueBox)=%% name="shopUnique">
                        <label class="form-check-label" for="shop-check5">
                          مشتريات استثنائية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@shopSouveinrsBox =='checked', 'True', 'False')=%%" %%=v(@shopSouveinrsBox)=%%
                               id="shop-check7" name="shopSouvenirs">
                        <label class="form-check-label" for="shop-check7">
                          هدايا تذكارية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input select-all" id="select-all-red" type="checkbox" value="%%=IIF(@shopAllBox =='checked', 'True', 'False')=%%"
                               id="shop-check6" %%=v(@shopAllBox)=%% name="shopAll">
                        <label class="form-check-label" for="select-all-red">
                          اختر الكل
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- skyblue box -->
                <div class="col-lg-2 col-md-4 col-sm-6 col-12">
                  <div class="cards skyblue-cards cards-select">
                    <div class="cards-img">
                      <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/2af06df4-79d6-4616-a714-bdbe4e08ba77.png"
                           class="cards-img-top" alt="">
                      <h6>جولات وألعاب</h6>
                    </div>
                    <div class="cards-body">
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@gameArcadeBox =='checked', 'True', 'False')=%%"
                               id="carnival-check1" %%=v(@gameArcadeBox)=%% name="gameArcade">
                        <label class="form-check-label" for="carnival-check1">
                          ألعاب فيديو
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@gameFastRidesBox =='checked', 'True', 'False')=%%"
                               id="carnival-check2" %%=v(@gameFastRidesBox)=%% name="gameFastRides">
                        <label class="form-check-label" for="carnival-check2">
                          ألعاب سريعة
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@gameFairgroundRidesBox =='checked', 'True', 'False')=%%"
                               id="carnival-check3" %%=v(@gameFairgroundRidesBox)=%% name="gameFairgroundRides">
                        <label class="form-check-label" for="carnival-check3">
                          ألعاب موسمية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@gameSkillBox =='checked', 'True', 'False')=%%"
                               id="carnival-check5" %%=v(@gameSkillBox)=%% name="gameSkill">
                        <label class="form-check-label" for="carnival-check5">
                          ألعاب مهارية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@gameHorrorBox =='checked', 'True', 'False')=%%"
                               id="carnival-check6" %%=v(@gameHorrorBox)=%% name="gameHorror">
                        <label class="form-check-label" for="carnival-check6">ألعاب الرعب والمخيفة</label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input select-all" id="select-all-skyblue" type="checkbox" value="%%=IIF(@gameAllBox =='checked', 'True', 'False')=%%"
                               id="carnival-check7" %%=v(@gameAllBox)=%% name="gameAll">
                        <label class="form-check-label" for="select-all-skyblue">
                          اختر الكل
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- orange box -->
                <div class="col-lg-2 col-md-4 col-sm-6 col-12">
                  <div class="cards orange-cards cards-select">
                    <div class="cards-img">
                      <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/370fd1a9-2b4c-47a3-a3ef-8a473a4c00fc.png"
                           class="cards-img-top" alt="">
                      <h6>مطاعم</h6>
                    </div>
                    <div class="cards-body">
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@dineCafeBox =='checked', 'True', 'False')=%%"
                               id="dining-check1" %%=v(@dineCafeBox)=%% name="dineCafe">
                        <label class="form-check-label" for="dining-check1">
                          مقاهي
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@dineCasualBox =='checked', 'True', 'False')=%%"
                               id="dining-check2" %%=v(@dineCasualBox)=%% name="dineCasual">
                        <label class="form-check-label" for="dining-check2">
                          مطاعم عادية
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@dineCelebChefsBox =='checked', 'True', 'False')=%%"
                               id="dining-check3" %%=v(@dineCelebChefsBox)=%% name="dineCelebChefs">
                        <label class="form-check-label" for="dining-check3">
                          طهاة عالميون
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@dineFastFoodBox =='checked', 'True', 'False')=%%"
                               id="dining-check4" %%=v(@dineFastFoodBox)=%% name="dineFastFood">
                        <label class="form-check-label" for="dining-check4">
                          وجبات سريعة
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@dineFineBox =='checked', 'True', 'False')=%%"
                               id="dining-check5" %%=v(@dineFineBox)=%% name="dineFine">
                        <label class="form-check-label" for="dining-check5">
                          مطاعم فاخرة
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input" data-id="box-custom" type="checkbox" value="%%=IIF(@dineStreetFoodBox =='checked', 'True', 'False')=%%"
                               id="dining-check6" %%=v(@dineStreetFoodBox)=%% name="dineStreetFood">
                        <label class="form-check-label" for="dining-check6">
                          مطاعم متجولة
                        </label>
                      </div>
                      <div class="form-check">
                        <input class="form-check-input select-all" id="select-all-orange" type="checkbox" value="%%=IIF(@dineAllBox =='checked', 'True', 'False')=%%"
                               id="dining-check7" %%=v(@dineAllBox)=%% name="dineAll">
                        <label class="form-check-label" for="select-all-orange">
                          اختر الكل
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- green box -->
                <!-- <div class="col-lg-2 col-md-4 col-sm-6 col-12">
<div class="card green-card card-select">
<div class="card-img">
<img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/f11b7eb1-5c7e-4e67-9f54-fc2386e00b1a.png" class="card-img-top" alt="">
<h6>Other attraction</h6>
</div>
<div class="card-body">
<div class="form-check">
<input class="form-check-input" type="checkbox" value="" id="other-check1">
<label class="form-check-label" for="other-check1">
Ripley's Believe It or not!
</label>
</div>
<div class="form-check">
<input class="form-check-input" type="checkbox" value="" id="other-check2">
<label class="form-check-label" for="other-check2">
Seasonal attractions
</label>
</div>
<div class="form-check">
<input class="form-check-input" type="checkbox" value="" id="other-check3">
<label class="form-check-label" for="other-check3">
Arts & crafts
</label>
</div>
<div class="form-check">
<input class="form-check-input select-all" type="checkbox" value="" id="other-check4">
<label class="form-check-label" for="other-check4">
Select all
</label>
</div>
</div>
</div>
</div>-->
              </div>
              <h4 class="pt-4 pb-3">ما هو أكثر ما يدفعك لزيارة القرية العالمية؟
                <sup class="text-danger">*</sup>
              </h4>
              <h3 class="custom-heading">(اختر ثلاثة أسباب وقم بترتيبها حسب الأهمية)
              </h3>
              <div class="row">
                <div class="check-list">
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="To keep my kids entertained">للترفيه عن أطفالي
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy">
                          <input type="radio" name="ranking" class="super-happy"
                                 id="super-happy" value="1"  %%=IIF(@visitReasonSelected1=='ranking', 'checked', '')=%% />
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512" >
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3"/>
                          </svg>
                        </label>
                        <label for="happy">
                          <input type="radio" name="ranking" class="happy" id="happy"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral">
                          <input type="radio" name="ranking" class="neutral" id="neutral"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="To hangout with friends">لقضاء أوقات ممتعة مع أصدقائي<
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy1">
                          <input type="radio" name="ranking1" class="super-happy"
                                 id="super-happy1" value="1" %%=IIF(@visitReasonSelected1=='ranking1', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy1">
                          <input type="radio" name="ranking1" class="happy" id="happy1"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking1', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral1">
                          <input type="radio" name="ranking1" class="neutral" id="neutral1"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking1', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="To enjoy the lively atmosphere">للاستمتاع بأجواء نابضة بالحياة
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy2">
                          <input type="radio" name="ranking2" class="super-happy"
                                 id="super-happy2" value="1" %%=IIF(@visitReasonSelected1=='ranking2', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy2">
                          <input type="radio" name="ranking2" class="happy" id="happy2"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking2', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral2">
                          <input type="radio" name="ranking2" class="neutral" id="neutral2"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking2', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="It's a tourist attraction">لأنها وجهة سياحية
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy3">
                          <input type="radio" name="ranking3" class="super-happy"
                                 id="super-happy3" value="1" %%=IIF(@visitReasonSelected1=='ranking3', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy3">
                          <input type="radio" name="ranking3" class="happy" id="happy3"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking3', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral3">
                          <input type="radio" name="ranking3" class="neutral" id="neutral3"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking3', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="To entertain guests">للترفيه عن الضيوف
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy4">
                          <input type="radio" name="ranking4" class="super-happy"
                                 id="super-happy4" value="1" %%=IIF(@visitReasonSelected1=='ranking4', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy4">
                          <input type="radio" name="ranking4" class="happy" id="happy4"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking4', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral4">
                          <input type="radio" name="ranking4" class="neutral" id="neutral4"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking4', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="For great shows and events">لأروع الفعاليات والعروض
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy5">
                          <input type="radio" name="ranking5" class="super-happy"
                                 id="super-happy5" value="1" %%=IIF(@visitReasonSelected1=='ranking5', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy5">
                          <input type="radio" name="ranking5" class="happy" id="happy5"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking5', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral5">
                          <input type="radio" name="ranking5" class="neutral" id="neutral5"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking5', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="To shop for unique cultural items">لشراء مقتنيات ثقافية فريدة
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy6">
                          <input type="radio" name="ranking6" class="super-happy"
                                 id="super-happy6" value="1" %%=IIF(@visitReasonSelected1=='ranking6', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy6">
                          <input type="radio" name="ranking6" class="happy" id="happy6"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking6', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral6">
                          <input type="radio" name="ranking6" class="neutral" id="neutral6"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking6', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="The carnaval experience">تجربة الكرنفال
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy7">
                          <input type="radio" name="ranking7" class="super-happy"
                                 id="super-happy7" value="1" %%=IIF(@visitReasonSelected1=='ranking7', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy7">
                          <input type="radio" name="ranking7" class="happy" id="happy7"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking7', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral7">
                          <input type="radio" name="ranking7" class="neutral" id="neutral7"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking7', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="To celebrate special occasions">للاحتفال بالمناسبات الخاصة
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy8">
                          <input type="radio" name="ranking8" class="super-happy"
                                 id="super-happy8" value="1" %%=IIF(@visitReasonSelected1=='ranking8', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy8">
                          <input type="radio" name="ranking8" class="happy" id="happy8"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking8', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral8">
                          <input type="radio" name="ranking8" class="neutral" id="neutral8"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking8', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="For its international cuisine">من أجل الاستمتاع بالمطاعم العالمية
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy9">
                          <input type="radio" name="ranking9" class="super-happy"
                                 id="super-happy9" value="1" %%=IIF(@visitReasonSelected1=='ranking9', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy9">
                          <input type="radio" name="ranking9" class="happy" id="happy9"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking9', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral9">
                          <input type="radio" name="ranking9" class="neutral" id="neutral9"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking9', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <div class="form-check .form-check-inline">
                    <div class="ranking-container">
                      <div class="ranking-text col-6">
                        <p id="For some quality family time">لقضاء أوقات عائلية سعيدة
                        </p>
                      </div>
                      <div class="ranking col-6">
                        <label for="super-happy10">
                          <input type="radio" name="ranking10" class="super-happy"
                                 id="super-happy10" value="1" %%=IIF(@visitReasonSelected1=='ranking10', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 256 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M160 64c0-11.8-6.5-22.6-16.9-28.2s-23-5-32.9 1.6l-96 64C-.5 111.2-4.4 131 5.4 145.8s29.7 18.7 44.4 8.9L96 123.8V416H32c-17.7 0-32 14.3-32 32s14.3 32 32 32h96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32H160V64z"
                                  stroke="green" stroke-width="3" />
                          </svg>
                        </label>
                        <label for="happy10">
                          <input type="radio" name="ranking10" class="happy" id="happy10"
                                 value="2" %%=IIF(@visitReasonSelected2=='ranking10', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 320 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M142.9 96c-21.5 0-42.2 8.5-57.4 23.8L54.6 150.6c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L40.2 74.5C67.5 47.3 104.4 32 142.9 32C223 32 288 97 288 177.1c0 38.5-15.3 75.4-42.5 102.6L109.3 416H288c17.7 0 32 14.3 32 32s-14.3 32-32 32H32c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9L200.2 234.5c15.2-15.2 23.8-35.9 23.8-57.4c0-44.8-36.3-81.1-81.1-81.1z" />
                          </svg>
                        </label>
                        <label for="neutral10">
                          <input type="radio" name="ranking10" class="neutral" id="neutral10"
                                 value="3" %%=IIF(@visitReasonSelected3=='ranking10', 'checked', '')=%%/>
                          <svg xmlns="http://www.w3.org/2000/svg"
                               viewBox="0 0 448 512">
                            <!--! Font Awesome Pro 6.2.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2022 Fonticons, Inc. -->
                            <path
                                  d="M64 64c0-17.7 14.3-32 32-32H336c13.2 0 25 8.1 29.8 20.4s1.5 26.3-8.2 35.2L226.3 208H248c75.1 0 136 60.9 136 136s-60.9 136-136 136H169.4c-42.4 0-81.2-24-100.2-61.9l-1.9-3.8c-7.9-15.8-1.5-35 14.3-42.9s35-1.5 42.9 14.3l1.9 3.8c8.1 16.3 24.8 26.5 42.9 26.5H248c39.8 0 72-32.2 72-72s-32.2-72-72-72H144c-13.2 0-25-8.1-29.8-20.4s-1.5-26.3 8.2-35.2L253.7 96H96C78.3 96 64 81.7 64 64z" />
                          </svg>
                        </label>
                      </div>
                    </div>
                  </div>
                  <input type="radio" name="group" class="no_option" value="null"
                         style="display:none">
                </div>
              </div>
              <input type="hidden" value="%%=v(@reasonToVisit1)=%%" id="selID1" name="selID1">
              <input type="hidden" value="%%=v(@reasonToVisit2)=%%" id="selID2" name="selID2">
              <input type="hidden" value="%%=v(@reasonToVisit3)=%%" id="selID3" name="selID3">
              <input name="submittedInterests" type="hidden" value="true">
              <br>
              <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
              <input name="guestId" type="hidden" id="guestId" value="%%=v(@Id)=%%"><br>
              <br>
                <div class="submit-button">
          
              <button type="submit" class="btn btn-success"id="profile-submit" name="button">حفظ</button>
 
          </div>
              
            </form>
                 </div>   
            
              
         %%[
                              IF RequestParameter("submittedInterests")==true then
                                SET @sfid = RequestParameter("crmId")
                                SET @guestId = RequestParameter("guestId")

                                SET @entCulturalBox = RequestParameter("culturalShow")
                                SET @entDanceTroupesBox = RequestParameter("DanceTroupesBox")
                                SET @entKidsShowBox = RequestParameter("KidsShowBox")
                                SET @entStuntBox = RequestParameter("StuntBox")
                                SET @entStreetBox = RequestParameter("StreetBox")
                                SET @entAllBox = RequestParameter("entAll") 
                                
                                SET @musicClassicalBox = RequestParameter("ClassicalBox")
                                SET @musicDJBox = RequestParameter("DJBox")
                                SET @musicPopBox = RequestParameter("PopBox")
                                SET @musicRockBox = RequestParameter("RockBox")
                                SET @musicAllBox = RequestParameter("musicAll")

                                SET @shopBargainBox = RequestParameter("shopBargain")
                                SET @shopMallBox = RequestParameter("shopMall")
                                SET @shopMarketBox = RequestParameter("shopMarket")
                                SET @shopUniqueBox = RequestParameter("shopUnique")
                                SET @shopSouvenirsBox = RequestParameter("shopSouvenirs")
                                SET @shopAllBox = RequestParameter("shopAll")

                                SET @gameArcadeBox = RequestParameter("gameArcade")
                                SET @gameFastRidesBox = RequestParameter("gameFastRides")
                                SET @gameFairgroundRidesBox = RequestParameter("gameFairgroundRides")
                                SET @gameSkillBox = RequestParameter("gameSkill")
                                SET @gameHorrorBox = RequestParameter("gameHorror")
                                SET @gameAllBox = RequestParameter("gameAll")

                                SET @dineCafeBox = RequestParameter("dineCafe")
                                SET @dineCasualBox = RequestParameter("dineCasual")
                                SET @dineCelebChefsBox = RequestParameter("dineCelebChefs")
                                SET @dineFastFoodBox = RequestParameter("dineFastFood")
                                SET @dineFineBox = RequestParameter("dineFine")
                                SET @dineStreetFoodBox = RequestParameter("dineStreetFood")
                                SET @dineAllBox = RequestParameter("dineAll")

                                /*Setting Variables to null always before fetching values*/
                                SET @reasonToVisit1 = RequestParameter("selID1")
                                SET @reasonToVisit2 = RequestParameter("selID2")
                                SET @reasonToVisit3 = RequestParameter("selID3")

                                IF NOT Empty(@sfid) THEN

                                SET @updateRecord = UpdateSingleSalesforceObject(
                                "Guest_Subscription__c", @guestId,
                                "Cultural_shows__c", IIF(EMPTY(@entCulturalBox), 'False', 'True'), 
                                "Dance_Troupes__c", IIF(EMPTY(@entDanceTroupesBox), 'False', 'True'),
                                "Kids_Shows__c", IIF(EMPTY(@entKidsShowBox), 'False', 'True'),
                                "Stunt_Shows__c", IIF(EMPTY(@entStuntBox), 'False', 'True'),
                                "Street_Performances__c",IIF(EMPTY(@entStreetBox), 'False', 'True'),
                                "ENTALL__c", IIF(EMPTY(@entAllBox), 'False', 'True'),

                                "Classical_Orchestras__c", IIF(EMPTY(@musicClassicalBox), 'False', 'True'), 
                                "DJ__c", IIF(EMPTY(@musicDJBox), 'False', 'True'),
                                "Pop_Groups__c", IIF(EMPTY(@musicPopBox), 'False', 'True'),
                                "Rock_Brands__c", IIF(EMPTY(@musicRockBox), 'False', 'True'),
                                "LIVEALL__c", IIF(EMPTY(@musicAllBox), 'False', 'True'),

                                "Bargains__c", IIF(EMPTY(@shopBargainBox), 'False', 'True'), 
                                "Malls__c", IIF(EMPTY(@shopMallBox), 'False', 'True'),
                                "Markets__c", IIF(EMPTY(@shopMarketBox), 'False', 'True'),
                                "Unique_Buys__c", IIF(EMPTY(@shopUniqueBox), 'False', 'True'),
                                "Souveneirs__c", IIF(EMPTY(@shopSouvenirsBox), 'False', 'True'),
                                "SHOPALL__c", IIF(EMPTY(@shopAllBox), 'False', 'True'),

                                "Arcade_Games__c", IIF(EMPTY(@gameArcadeBox), 'False', 'True'), 
                                "Fast_Rides__c", IIF(EMPTY(@gameFastRidesBox), 'False', 'True'),
                                "Fairground_Rides__c", IIF(EMPTY(@gameFairgroundRidesBox), 'False', 'True'),
                                "Skill_Games__c", IIF(EMPTY(@gameSkillBox), 'False', 'True'),
                                "Horror_Scary_Rides__c", IIF(EMPTY(@gameHorrorBox), 'False', 'True'),
                                "GAMEALL__c", IIF(EMPTY(@gameAllBox), 'False', 'True'),

                                "Cafes__c", IIF(EMPTY(@dineCafeBox), 'False', 'True'), 
                                "Casual_Dining__c", IIF(EMPTY(@dineCasualBox), 'False', 'True'),
                                "Celebrity_Chefs__c", IIF(EMPTY(@dineCelebChefsBox), 'False', 'True'),
                                "Fast_Food__c", IIF(EMPTY(@dineFastFoodBox), 'False', 'True'),
                                "Fine_Dining__c", IIF(EMPTY(@dineFineBox), 'False', 'True'),
                                "Street_Food__c", IIF(EMPTY(@dineStreetFoodBox), 'False', 'True'),
                                "DININGALL__c", IIF(EMPTY(@dineAllBox), 'False', 'True'),

                                "Reason_to_Visit__c", IIF(EMPTY(@reasonToVisit1), " ", @reasonToVisit1),
                                "Reason_to_Visit2__c", IIF(EMPTY(@reasonToVisit2), " ", @reasonToVisit2),
                                "Reason_to_Visit3__c", IIF(EMPTY(@reasonToVisit3), " ", @reasonToVisit3)
                            )
                            
                             SET @contactRows = RetrieveSalesforceObjects("Contact","Email","Id","=", @sfid )
                                        if RowCount(@contactRows) == 1 then /* there should only be one row */
                                          set @contactRow = Row(@contactRows, 1)
                                          set @emailContact = Field(@contactRow, "Email")
                                        ENDIF
                            
                            set @communications = '#communications'
                                   if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","InterestPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.globalvillage.ae/GVQA_CPC?sfid=", Base64Encode(@sfid), "#communications"))
                                   ELSE
                                      Redirect(CONCAT(CloudPagesURL(3269),@communications))
                                   ENDIF
                                   endif
                            
                            ENDIF
                            ENDIF
]%%

              
        </div>
        <!-- Interest Tab End -->

        <!-- 3rd card Communication tab start-->
        <div class="tab-pane fade preferences-tab-content" id="communications" role="tabpanel" aria-labelledby="communications-tab">
          <div class="wrapper wrapper--w700">
            <form class="preferences-form" action="" method="post">
               <div class="entertainment-updates">
                <h4 class="pt-4 pb-3">من أين تحصل على آخر مستجدات الترفيه؟
                </h4>
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" value="%%=v(@updatesSocial)=%%" id="informCheck1" %%=IIF(@updatesSocial =='True' ,'checked', "" )=%% name="updatesSocial">
                  <label class="form-check-label" for="informCheck1">
                    وسائط التواصل الاجتماعي
                  </label>
                </div>
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" value="%%=v(@updatesSearch)=%%" id="informCheck2" %%=IIF(@updatesSearch =='True' ,'checked', "" )=%% name="updatesSearch">
                  <label class="form-check-label" for="informCheck2">
                    محركات البحث
                  </label>
                </div>
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" value="%%=v(@updatesOtherOnline)=%%" id="informCheck3" %%=IIF(@updatesOtherOnline =='True' ,'checked', "" )=%% name="updatesOtherOnline">
                  <label class="form-check-label" for="informCheck3">
                    قنوات أخرى عبر الإنترنت
                  </label>
                </div>
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" value="%%=v(@updatesFF)=%%" id="informCheck4" %%=IIF(@updatesFF =='True' ,'checked', "" )=%% name="updatesFF">
                  <label class="form-check-label" for="informCheck4">
                    أصدقاء/عائلة
                  </label>
                </div>
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" value="%%=v(@updatesOther)=%%" id="myCheck"
                         onclick="addbox()" %%=IIF(@updatesOther =='True' ,'checked', "" )=%% name="updatesOther">
                  <label class="form-check-label" for="myCheck">
                    أخرى - أخبرنا المزيد
                  </label>
                </div>
                <textarea name="updatesOtherComments" rows="6" cols="10" id="area" class="form-control mt-2"
                          placeholder="أخبرنا المزيد" style="%%=IIF(Empty(@updatesOtherComments), "display:none;" , "display:block;")=%%">%%=v(@updatesOtherComments)=%%</textarea>
              </div>
              <!-- Second -->
                 <div class="hear-about">
               <h4 class="pt-4 pb-3">ما هي الأخبار التي تثير اهتمامك؟</h4>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@offersAndPromotions)=%%" id="hearEvents"  name="hearEvents" %%=IIF(@offersAndPromotions =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck11">
                    فعاليات، عروض وحفلات
                   </label>
               </div>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@upcomingEventsAndFamilies)=%%" id="hearOffers"  name="hearOffers" %%=IIF(@upcomingEventsAndFamilies =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck12">
                    عروض وتخفيضات
                   </label>
               </div>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@newRidesAndEntertainement)=%%" id="hearVIP"  name="hearVIP" %%=IIF(@newRidesAndEntertainement =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck13">
                    باقات كبار الشخصيات وتجارب فخمة
                   </label>
               </div>
               <div class="form-check">
                   <input class="form-check-input" type="checkbox" value="%%=v(@newFoodAndRestaurants)=%%" id="hearLatest"  name="hearLatest" %%=IIF(@newFoodAndRestaurants =='True' ,'checked', "" )=%%>
                   <label class="form-check-label" for="informCheck14">
                    آخر مستجدات القرية العالمية
                   </label>
               </div>
             </div>
 
             <div class="com-btn mt-5">
              <button type="submit" class="btn btn-orange"id="communications-submit" name="button">حفظ</button>

          </div>
               <input name="submittedCommunications" type="hidden" value="true">
                                <input name="crmId" id="crmId" type="hidden" value="%%=v(@crmId)=%%">
              <input name="guestId" id="guestId" type="hidden" value="%%=v(@Id)=%%">
              <input name="emails" type="hidden" value="%%=v(@email)=%%"><br>
           </form>
            <hr>
          
            
               
             %%[
                            IF RequestParameter("submittedCommunications")==true then
                                SET @sfid = RequestParameter("crmId")
                                SET @guestId = RequestParameter("guestId")
                                SET @emailContact = RequestParameter("emails")
                                SET @updatesSocialBox = RequestParameter("updatesSocial")
                                SET @updatesSearchBox = RequestParameter("updatesSearch")
                                SET @updatesOtherOnlineBox = RequestParameter("updatesOtherOnline")
                                SET @updatesFFBox = RequestParameter("updatesFF")
                                SET @updatesOtherBox = RequestParameter("updatesOther")
                                SET @updatesOtherComments = RequestParameter("updatesOtherComments")

                                If(Empty(@updatesOtherComments) OR Empty(@updatesOtherBox)) THEN 
                                    SET @updatesOtherCommentsText = ' '
                                ELSE
                                    SET @updatesOtherCommentsText = @updatesOtherComments
                                ENDIF
                                
                                SET @hearEventsBox = RequestParameter("hearEvents")
                                SET @hearOffersBox = RequestParameter("hearOffers")
                                SET @hearVIPBox = RequestParameter("hearVIP")
                                SET @hearLatestBox = RequestParameter("hearLatest")
                                
                                
                                IF NOT Empty(@sfid) THEN
                                SET @updateRecord = UpdateSingleSalesforceObject(
                                "Guest_Subscription__c", @guestId,
                                "Social_Media__c", IIF(EMPTY(@updatesSocialBox), 'False', 'True'), 
                                "Search_Engines__c", IIF(EMPTY(@updatesSearchBox), 'False', 'True'),
                                "Other_Online_Channels__c", IIF(EMPTY(@updatesOtherOnlineBox), 'False', 'True'),
                                "Friends_Family__c", IIF(EMPTY(@updatesFFBox), 'False', 'True'),
                                "ENTOTHERS__c",IIF(EMPTY(@updatesOtherBox), 'False', 'True'),
                                "Communication_Entertainment_Comments__c",@updatesOtherCommentsText,

                                "Events_Shows_and_Concerts__c", IIF(EMPTY(@hearEventsBox), 'False', 'True'), 
                                "Offers_and_Promotions__c", IIF(EMPTY(@hearOffersBox), 'False', 'True'),
                                "VIP_Packs_and_Premium_Experiences__c", IIF(EMPTY(@hearVIPBox), 'False', 'True'),
                                "Global_Village_Latest_News__c", IIF(EMPTY(@hearLatestBox), 'False', 'True')
                            )
                            
                             
                            
                                   if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   if @methodType== 'Old' then
                                     Redirect(Concat("https://cloud.explore.globalvillage.ae/ThankYou_GV_QA?sfid=", Base64Encode(@sfid)))
                                   ELSE
                                      Redirect(CloudPagesURL(3276))
                                   ENDIF
                                   endif

                                
                            ENDIF
                            ENDIF
]%%
            
              <!--channel preference block-->
                    <form class="channel-preferences-form" action="" method="post">
                        <!-- Third -->
                        <div class="channel">
                            <h4 class="pt-4 pb-3">كيف تفضل التواصل معك؟</h4>
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="emailPref" name="emailPref" %%=IIF(@emailPref=='True' ,'checked', "" )=%%>
                                <label class="form-check-label" for="emailPref">
                                    البريد الإلكتروني
                                </label>
                            </div>
                          <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="smsPref" %%=IIF(@smsPref=='True' ,'checked', "" )=%% name="smsPref">
                            <label class="form-check-label" for="smsPref">الرسائل النصية</label>
                          </div>
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="WhatsAppPref" name="WhatsAppPref" %%=IIF(@WhatsAppPref=='True' ,'checked', "" )=%%>
                                <label class="form-check-label" for="WhatsAppPref">
                                    واتساب
                                </label>
                            </div>
                        </div>
                        <div class="pref-btn mt-5">
                            <button type="button" name="button" class="btn btn-orange channelPreference-btn" id="channel-submit" onclick="channelPreference()">حفظ</button>
                        </div>
                        <input name="submittedChannelPref" type="hidden" value="true">
                        <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
                        <input name="guestId" type="hidden" value="%%=v(@Id)=%%"><br>
                    </form>
                    <!-- thank you pop up -->
                    <div class="box-form mt-5" id="channel-preference">
                        <span class="close-buttonCM" style=" text-align: right; font-size: 30px; position: relative; left: 100%; top: 0; cursor: pointer; color:#ee5f02;">×</span>
                        <div class="container">
                            <div class="channelpreference-wrapper">
                                <div class="thanYou-img mb-2">
                                    <img src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/50e3c436-f935-4b74-8c1b-2936089ef986.png" alt="" class="banner-bg-img">
                                </div>
                                <div class="thankYou-text">
                                    <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold; padding-bottom:3rem;">لقد تم تحديث تفضيلات اشتراك القناة الخاصة بك بنجاح.</p>
                                </div>
                            </div>
                        </div>
                    </div>
                    <!-- channel preference block end -->

            
            
            <div class="mt-5 pl-2" style="font-size: 16px;">
              <p>إدارة اشتراكات إشعارات الدفع من خلال تطبيق الهاتف المحمول الخاص بنا. إذا كنت ترغب في إلغاء الاشتراك من جميع اتصالات القرية العالمية بدبي، فيرجى النقر فوق "إلغاء الاشتراك".</p>
            </div>
           <div class="unsrb-btn mt-5">
      <button type="button" name="button" class="btn btn-orange unsubscribe-btn"
          onclick="unsubscribeClick()" id="unsubscribeClick">إلغاء الاشتراك</button>
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
color:#ee5f02;">×</span>
                  <div class="container">
      <div class="unsubscribe-wrapper form group">
        <div class="thanYou-img mb-2">
           <img src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/50e3c436-f935-4b74-8c1b-2936089ef986.png" alt="" class="banner-bg-img">
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

                       <input class="form-check-input" type="checkbox" id="chck1" value="False" name="unsubFreq" %%=IIF(@emailsTooFrequent =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck1">الرسائل الإلكترونية متكررة للغاية</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck2" value="False" name="unsubRelevance" %%=IIF(@contentIsNotRelevant =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck2">المحتوى ليس له صلة</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck3" value="False" name="unsubNoDubai" %%=IIF(@noLongerInDubai =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck3">لست مقيماً في دبي</label>
                   </div>
                   <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="chck4" value="False" name="unsubTemp" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                    <label class="form-check-label" for="chck4">توقف مؤقت لمدة 30 يوما</label>
                </div>
                 <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="chck4" value="False" name="unsubTempSeason" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                    <label class="form-check-label" for="chck4">قمت بإلغاء الاشتراك مؤقتاً، سأعود مجدداً الموسم المقبل</label>
                </div>
                 
                   <div class="form-check mt-2">
                       <input class="form-check-input" type="checkbox" id="myCheck1" value="False"
                           onclick="addbox1()" name="unsubOther" %%=IIF(@otherSpecify =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="myCheck1">أسباب أخرى (يرجى تحديد السبب)</label>
                   </div>
                   <textarea name="nameReason" rows="6" cols="80" id="area1"
                       class="form-control mt-3" value="%%=v(@reasonForUnsub)=%%" placeholder="أخبرنا المزيد">%%=v(@reasonForUnsub)=%%</textarea>
                    
                   <div class="com-btn mt-5">
                    <button type="submit" class="btn btn-orange"id="communications-submitbtn" name="button">حفظ</button>
      <input name="submittedUnsub" type="hidden" value="true">
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%">
             <input name="emails" type="hidden" value="%%=v(@email)=%%"><br>
                </div>
             </form>
             %%[
             
                                IF RequestParameter("submittedUnsub")==true then
                                  SET @sfid = RequestParameter("crmId")
                                    SET @guestId = RequestParameter("guestId")
                                    SET @emailContact = RequestParameter("emails")
                                    SET @unsubTempBox = RequestParameter("unsubTemp")
                                    SET @unsubTempSeasonBox = RequestParameter("unsubTempSeason")
                                    SET @unsubFreqBox = RequestParameter("unsubFreq")
                                    SET @unsubRelevanceBox = RequestParameter("unsubRelevance")
                                    SET @unsubNoDubaiBox = RequestParameter("unsubNoDubai")
                                    SET @unsubOtherBox = RequestParameter("unsubOther")
                                    SET @unsubOtherComments = RequestParameter("nameReason")
                                    SET @currentDate = Now()
                                    IF NOT Empty(@sfid) THEN
                                    IF NOT Empty(@unsubTempSeasonBox) THEN
                                    /* made changes on 14 feb - add pub list to resub in CRM */
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                        "Guest_Subscription__c", @guestId,
                                        "Status__c", 'Subscribed',
                                        "Temporary_Pause_30_Days__c", 'False', 
                                        "I_am_not_interested_in_recieveing_commun__c", 'True', 
                                        "Emails_are_too_frequent__c",'False',
                                        "Content_isn_t_relevant__c",'False',
                                        "I_m_no_longer_in_Dubai__c",'False',
                                        "Other_Please_specify__c",'False',
                                        "fieldsToNull","Reason_of_Unsubscribe__c",
                                        "Events_Shows_and_Concerts__c","True",
                                        "Offers_and_Promotions__c","True",
                                        "VIP_Packs_and_Premium_Experiences__c","True",
                                        "Global_Village_Latest_News__c","True",
                                        "Email__c","True",
                                        "WhatsApp__c","True",
                                        "SMS__c","True"
                                        )
                                    ELSEIF NOT Empty(@unsubTempBox) THEN
                                        SET @updateRecord = UpdateSingleSalesforceObject(
                                        "Guest_Subscription__c", @guestId,
                                        "Status__c", 'Subscribed',
                                        "Temporary_Pause_30_Days__c", 'True', 
                                        "I_am_not_interested_in_recieveing_commun__c", 'False', 
                                        "Emails_are_too_frequent__c",'False',
                                        "Content_isn_t_relevant__c",'False',
                                        "I_m_no_longer_in_Dubai__c",'False',
                                        "Other_Please_specify__c",'False',
                                        "fieldsToNull","Reason_of_Unsubscribe__c",
                                        "Events_Shows_and_Concerts__c","True",
                                        "Offers_and_Promotions__c","True",
                                        "VIP_Packs_and_Premium_Experiences__c","True",
                                        "Global_Village_Latest_News__c","True",
                                        "Email__c","True",
                                        "WhatsApp__c","True",
                                        "SMS__c","True"
                                        )
                                    ELSE
                                        SET @updateRecord = UpdateSingleSalesforceObject(
                                        "Guest_Subscription__c", @guestId,
                                        "Status__c", 'Unsubscribed',
                                        "Temporary_Pause_30_Days__c", IIF(Empty(@unsubTempBox), 'false', 'true'),
                                        "I_am_not_interested_in_recieveing_commun__c", IIF(Empty(@unsubTempSeasonBox), 'false', 'true'),
                                        "Emails_are_too_frequent__c", IIF(Empty(@unsubFreqBox), 'false', 'true'),
                                        "Content_isn_t_relevant__c",IIF(Empty(@unsubRelevanceBox), 'false', 'true'),
                                        "I_m_no_longer_in_Dubai__c", IIF(Empty(@unsubNoDubaiBox), 'false', 'true'),
                                        "Other_Please_specify__c", IIF(Empty(@unsubOtherBox), 'false', 'true'),
                                        "Reason_of_Unsubscribe__c", @unsubOtherComments,
                                        )
                                    ENDIF
                                     IF NOT Empty(@unsubTempBox) THEN
                                     SET @s = upsertData("ENT.TempPauseHandle_QA", 1, "SubscriberKey", @guestId, "Email",
                                                            @emailContact,"DateAdded",@currentDate,"ContactId",@sfid, "UnsubscribeType","Individual","Asset","DPR")
                                    ENDIF
                                    IF Empty(@unsubTempBox) THEN
                                    set @rowFound = LookupRows("ENT.TempPauseHandle_QA","SubscriberKey", @guestId)
                                    set @count = rowcount(@rowFound)
                                    if @count > 0 then
                                    set @deleteCount = DeleteData("ENT.TempPauseHandle_QA","Email", @emailContact)
                                    SET @updateRecord = UpdateSingleSalesforceObject(
                                    "Guest_Subscription__c", @guestId,
                                    "Temporary_Pause_30_Days__c", IIF(Empty(@unsubTempBox), 'False', 'True'), 
                                    "I_am_not_interested_in_recieveing_commun__c", IIF(Empty(@unsubTempSeasonBox), 'False', 'True'), 
                                    "Emails_are_too_frequent__c", IIF(Empty(@unsubFreqBox), 'False', 'True'),
                                    "Content_isn_t_relevant__c",IIF(Empty(@unsubRelevanceBox), 'False', 'True'),
                                    "I_m_no_longer_in_Dubai__c", IIF(Empty(@unsubNoDubaiBox), 'False', 'True'),
                                    "Other_Please_specify__c", IIF(Empty(@unsubOtherBox), 'False', 'True'),
                                    "Reason_of_Unsubscribe__c", @unsubOtherComments
                                    )
                                    /*if a sub. comes back and uncheck temp pause*/
                                    endif
                                    ENDIF
                                   /*Redirect(Concat("https://cloud.explore.dubaiparksandresorts.com/Bhavya_ThankYou_QA?sfid=", Base64Encode(@sfid), "#ThankYou"))*/
                                    set @thankYouPage = '#ThankYou'
                                    if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                       Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                    /*Redirect(CONCAT(CloudPagesURL(2737),@thankYouPage))*/
                                    if @methodType== 'Old' then
                                      Redirect(Concat("https://cloud.explore.globalvillage.ae/ThankYou_GV_QA?sfid=", Base64Encode(@sfid), "#ThankYou"))
                                     ELSE
                                            Redirect(CONCAT(CloudPagesURL(3276),@thankYouPage))
                                    ENDIF
                                ENDIF
                                ENDIF

                        ]%%

           </div>

            <div class="mt-5 pl-2" style="font-size: 16px;">
              <p>إذا كنت ترغب في إلغاء اشتراكك من جميع رسائل التسويق لدبي القابضة للترفيه، التي تشمل جميع<a style="color:#7773b6" href="https://privacy.dubaiholding.com/ar/data-controllers-list/dubai-holding-entertainment-llc" target="_blank">علامتنا الت</a> جارية، يرجى الضغط على "إلغاء الاشتراك في الكل</p>
            </div>
            <div class="unsrb-all-btn mt-5">
              <button type="button" name="button" class="btn btn-orange unsubscribe-all-btn" onclick="unsubscribeAllClick()" id="unsubscribeAllClick">إلغاء الاشتراك الكل</button>
          </div>
               <!-- <input name="submittedCommunications" type="hidden" value="true">
               <input name="crmId" type="hidden" value=""> -->



  <!-- <input name="submittedCommunications" type="hidden" value="true">
  <input name="crmId" type="hidden" value=""> -->
             
                  <!-- Unsubscribe All reason options -->
           <div class="box-form mt-5" id="unsubscribe-all-reason">
             
            <form class="comment-form" action="" method="post">
              <span class="close-buttonAll" style="
text-align: right;
font-size: 30px;
position: relative;
left: 100%;
top: 0;
cursor: pointer;                                                           
color:#ee5f02;">×</span>
              <div class="container">
      <div class="unsubscribe-wrapper form group">
        <div class="thanYou-img mb-2">
           <img src="https://image.explore.dubaiparksandresorts.com/lib/fe3a117373640479751473/m/1/50e3c436-f935-4b74-8c1b-2936089ef986.png" alt="" class="banner-bg-img">
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

                       <input class="form-check-input" type="checkbox" id="chck_1" value="False" name="unsubFreq" %%=IIF(@emailsTooFrequent =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck_1">الرسائل الإلكترونية متكررة للغاية</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck_2" value="False" name="unsubRelevance" %%=IIF(@contentIsNotRelevant =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck_2">المحتوى ليس له صلة</label>
                   </div>
                   <div class="form-check mb-2">
                       <input class="form-check-input" type="checkbox" id="chck_3" value="False" name="unsubNoDubai" %%=IIF(@noLongerInDubai =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="chck_3">لست مقيماً في دبي</label>
                   </div>
                   <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="chck_4" value="False" name="unsubAllTemp" %%=IIF(@tempPause =='True' ,'checked', "" )=%%>
                    <label class="form-check-label" for="chck_4">توقف مؤقت لمدة 30 يوما</label>
                </div>
                   <div class="form-check mt-2">
                       <input class="form-check-input" type="checkbox" id="myCheck_1" value="False"
                           onclick="addbox_1()" name="unsubOther" %%=IIF(@otherSpecify =='True' ,'checked', "" )=%%>
                       <label class="form-check-label" for="myCheck_1">أسباب أخرى (يرجى تحديد السبب)</label>
                   </div>
                   <textarea name="nameReason" rows="6" cols="80" id="area_1"
                       class="form-control mt-3" value="%%=v(@reasonForUnsub)=%%" placeholder="أخبرنا المزيد">%%=v(@reasonForUnsub)=%%</textarea>
                    
                 
          
            
                <div class="com-btn mt-5">
                 <button type="submit" class="btn btn-orange"id="communications-submitbtn1" name="button">حفظ</button>
   <input name="unsubAll" type="hidden" value="true">
                                <input name="crmId" type="hidden" value="%%=v(@crmId)=%%">
             <input name="guestId" type="hidden" value="%%=v(@Id)=%%">
             <input name="emails" type="hidden" value="%%=v(@email)=%%"><br>
             </div>
               </form>
             %%[
                                IF RequestParameter("unsubAll") == true then
                                 SET @sfid = RequestParameter("crmId")
                                SET @guestId = RequestParameter("guestId")
                                SET @unsubTempBox = RequestParameter("unsubTemp")
                                SET @unsubFreqBox = RequestParameter("unsubFreq")
                                SET @unsubRelevanceBox = RequestParameter("unsubRelevance")
                                SET @unsubNoDubaiBox = RequestParameter("unsubNoDubai")
                                SET @unsubOtherBox = RequestParameter("unsubOther")
                                SET @unsubOtherComments = RequestParameter("name")
                               IF NOT Empty(@sfid) THEN
                                IF Empty(@unsubTempBox) THEN
                                        SET @updateRecord = UpdateSingleSalesforceObject(
                                        "Guest_Subscription__c", @guestId,
                                        "Status__c", 'Unsubscribed',
                                        "I_am_not_interested_in_recieveing_commun__c", IIF(Empty(@unsubTempBox), 'False', 'True'), 
                                        "Your_messages_are_too_frequent__c", IIF(Empty(@unsubFreqBox), 'False', 'True'),
                                        "The_communication_is_not_relevant__c",IIF(Empty(@unsubRelevanceBox), 'False', 'True'),
                                        "I_m_no_longer_in_Dubai__c", IIF(Empty(@unsubNoDubaiBox), 'False', 'True'),
                                        "SUBOTHERS__c", IIF(Empty(@unsubOtherBox), 'False', 'True'),
                                        "Reason_of_Unsubscribe__c", @unsubOtherComments
                                        )
                                    ELSE
                                        SET @updateRecord = UpdateSingleSalesforceObject(
                                        "Guest_Subscription__c", @guestId,
                                        "Status__c", 'Subscribed',
                                        "I_am_not_interested_in_recieveing_commun__c", IIF(Empty(@unsubTempBox), 'False', 'True'),
                                        "Your_messages_are_too_frequent__c",'False',
                                        "The_communication_is_not_relevant__c",'False',
                                        "I_m_no_longer_in_Dubai__c", 'False',
                                        "SUBOTHERS__c", 'False',
                                        "Reason_of_Unsubscribe__c", ' '
                                        )
                                    ENDIF
                                    
                                     SET @contactRows = RetrieveSalesforceObjects("Contact","Email","Id","=", @sfid )
                                        if RowCount(@contactRows) == 1 then /* there should only be one row */
                                          set @contactRow = Row(@contactRows, 1)
                                          set @emailContact = Field(@contactRow, "Email")
                                        ENDIF
                                 
                                 if empty(@sfid) OR IsNull(@sfid) then
                                      Set @ampError = '00 - NO SUBSCRIBER KEY FOUND'
                                   ELSE
                                      Set @ampError = ''
                                   ENDIF
                                   Set @p= InsertData("PreferencesLog_Test","SubscriberKey",@sfid,"EmailAddress",@emailContact,"Submission","CommunicationPage","AMPError",@ampError,"FirstName",@firstName,"LastName",@lastName)
                                   if @methodType== 'Old' then
                                     /*Redirect(Concat("https://cloud.explore.globalvillage.ae/ThankYou_GV_QA?sfid=", Base64Encode(@sfid)))*/
                                   ELSE
                                      Redirect(CloudPagesURL(3276))
                                   ENDIF
                                   endif
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
<div class="footer-strip">
  <div class="container">
    <div class="row">
      <div class="col-lg-3 col-md-3 col-sm-12 col-3 custom-width">
        <img src="https://www.globalvillage.ae/themes/custom/global_village/images/icons/time.svg"
             alt="">
        <p>
          <span>الموسم 29</span>
        </p>
      </div>
      <div class="col-lg-9 col-md-9 col-sm-12 col-9 custom-width2">
        <p>أكتوبر 2024 - أبريل 2025</p>
      </div>
    </div>
  </div>
</div>
<!-- footer start -->
 <footer>
  <div class="container">
    <div class="row"  id="newpage">
      <div class="col-lg-3 col-md-3 col-sm-12 col-12">
        <a href="https://www.globalvillage.ae/en" target="_blank" class="logo-footer">
          <img src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/c533b664-eeec-4cc2-9fae-70593e22fb1d.png"
               alt="">
        </a>
      </div>
      <div class="col-lg-3 col-md-3 col-sm-12 col-12">
        <h4>روابط سريعة</h4>
        <div class="col-lg-12 col-md-12 col-sm-12 col-12">
          <p>
            <a href="https://www.globalvillage.ae/en/about-us" target="_blank">عن القرية العالمية</a>
          </p>
        </div>
        <div class="col-lg-12 col-md-12 col-sm-12 col-12">
          <p>
            <a href="https://www.globalvillage.ae/en/blogs" target="_blank">المدونة</a>
          </p>
        </div>
      </div>
      <div class="col-lg-3 col-md-3 col-sm-12 col-12">
        <h4>تواصل معنا</h4>
        <p>تحتاج مساعدة؟ تواصل معنا عبر الهاتف
          <br>
          <a href="tel:043624114">043624114</a> أو البريد الإلكتروني
          <a href="mailto:info@globalvillage.ae" class="mail-us" id="mailto" target="_blank">info@globalvillage.ae</a>
        </p>
    <div class="mt-1 feedbackform">
      <a href="https://www.globalvillage.ae/en/contact-us" target="_blank"target="_blank"  name="button" class="btn">تواصل معنا</a>
    </div>
  </div>
  <div class="col-lg-3 col-md-3 col-sm-12 col-12">
    <h4>ابق على اتصال</h4>
    <ul class="social-media-ul">
      <li>
        <a href="https://www.facebook.com/GlobalVillageAE/" target="_blank"><img
                                                                 src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/c6221d91-0355-4bb1-8874-fbc79512fd9d.png"></a>
      </li>
      <li>
        <a href="https://twitter.com/GlobalVillageAE"  target="_blank"><img
                                                           src="https://image.explore.globalvillage.ae/lib/fe3c117373640479751471/m/1/084ef481-5045-489b-8b71-ab15f6786995.png"></a>
      </li>
      <li>
        <a href="https://www.instagram.com/globalvillageuae/" target="_blank"><img
                                                                   src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/487c6679-3df1-4ddc-9f21-56c6a88b0c3c.png"></a>
      </li>
      <li>
        <a href="https://www.youtube.com/user/GlobalVillageAE" target="_blank"><img
                                                                    src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/a0cf961e-9dd7-45a0-bf96-0d8680d38787.png"></a>
      </li>
      <li>
        <a href="https://protect-eu.mimecast.com/s/OVzlC4k7xiBNBJ2OfLwmZI?domain=t.snapchat.com"  target="_blank"><img
                                                                                                      src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/4390d6c9-61bf-4a19-b16b-71fa2510167c.png"></a>
      </li>
      <li>
        <a href="https://protect-eu.mimecast.com/s/bZPZC5l5yfZmZ0P7tQ_9Wk?domain=tiktok.com" target="_blank"><img
                                                                                                  src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/4094f73a-2708-406e-aa07-5d9cf77c5168.png"></a>
      </li>
      <li>
        <a href="https://www.linkedin.com/company/global-village-dubai/" target="_blank"><img
                                                                              src="http://image.explore.globalvillage.ae/lib/fe2d11737364047c701278/m/1/5ddd154e-4449-4d03-adc3-1dbb0798d40d.png"></a>
      </li>
    </ul>
  </div>
  </div>
<div class="row">
  <div class="col-lg-12">
    <div class="footer-links">
      <div class="region region-copyright">
        <ul class="clearfix">
          <li class="menu-item">
            <a href="https://globalvillage.ae/en/privacy-notice"
               rel="noopener" target="_blank">الخصوصية</a>
          </li>
          <li class="menu-item">
            <a href="https://www.globalvillage.ae/en/terms-use" target="_blank" data-drupal-link-system-path="node/8758"> الشروط والأحكام</a>
          </li>
          <li class="menu-item">
           <a href="https://www.globalvillage.ae/ar/entry-terms-conditions" target="_blank" data-drupal-link-system-path="node/8758">
قواعد وإرشادات الوجهة</a>
          </li>
          <li class="menu-item">
           <a href="https://www.globalvillage.ae/en/cookies-notice" target="_blank" rel="noopener">
إشعار ملفات تعريف الارتباط</a>
          </li>
        </ul>
      </div>
    </div>
  </div>
</div>
</div>
</footer>
      <!-- footer End -->                     
    <!-- Vendor JS-->
     <script src="https://cloud.explore.globalvillage.ae/bootstrap.bundle.min_gv_ar_qa"></script>
    <script src="https://cloud.explore.globalvillage.ae/select2.min.js_gv_ar_qa"></script>
    <script src="https://cloud.explore.globalvillage.ae/moment.min_gv_ar_qa"></script>
    <script src="https://cloud.explore.dubaiparksandresorts.com/daterangepicker.js_DPR_Prod"></script>

    <!-- Main JS-->
    
    <script src="https://cloud.explore.globalvillage.ae/global_gv_ar_qa"></script>
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
    
 $("#numOfKids").change(function() {
    var numOfKids = parseInt($(this).val());
   console.log("in the number of kids");
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
        
        console.log('inside fun22')
   
        var rowCount = document.getElementById('numOfKids').value; 
        console.log('rowCount-------  ',rowCount)
       
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
       /* console.log('deleted kids Id-----------',document.getElementById('DeletedKidsId').value)
        var delIdBs=document.getElementById('DeletedKidsId').value;
        //var rowCount = document.getElementById('numOfKids').value; 
        var delId=delIdBs.split(",");
        console.log('delId spliteeed-----------  ',delId)
        var delIdLength= delId.length;
        console.log('delIdLength-----------',delIdLength)
        document.getElementById('DeletedKidsId').value  ="";
        var check
        for (var i=0;i<=delIdLength; i++){
          check = 0;
          console.log('Initial check value-----------  ',check)
          console.log('del Id-----------  ',delId[i])
          for (var j=0;j<=rowCount; j++){
          if(delId[i]= j){
            console.log('del Id innermost if-----------  ',delId[i])
            check =1;
            break;
            }  
          }
          console.log('Before check If-----------  ',check)
          if(check == 0){
            console.log('after check If del id-----------  ',delId[i])
          if(document.getElementById('DeletedKidsId').value  == ""){
                                 document.getElementById('DeletedKidsId').value=delId[i];
                               }
                               else{
                                 document.getElementById('DeletedKidsId').value= document.getElementById('DeletedKidsId').value + ','+delId[i];
              }
        }
          console.log('Updated deleted kids Id-----------',document.getElementById('DeletedKidsId').value)
        }
        console.log('row count - ' , rowCount)*/

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
                    url: 'https://cloud.explore.dubaiparksandresorts.com/DPR_KidsDelete', // Replace with your CloudPage URL
                    method: 'POST',
                    data: dataToSend,
                    success: function(response) {
                        console.log('SFMC Code Resource called successfully.');
                        console.log('Response:', response);
                      //var myElement = document.getElementById('kidsTable')
                      /*var myElement = document.querySelector('#kidsTable');
                      var child = myElement.childNodes;
                      console.log('child: ', child);
                      
                      for (var chil of child) {
                          console.log('After Deletion: ', chil.id);
                        }*/
                       

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
         console.log("hash==",hashvalue);
         var value= hashvalue.split("&");
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
        
        var dataToSend = {
            guestId: guestId,
            subsKey: subsKey,
            emailPref: emailPref.checked,
            whatsAppPref: whatsAppPref.checked
        };

        $.ajax({
            url: 'https://cloud.explore.globalvillage.ae/GV_QA_ChannelPreference', // Replace with your CloudPage URL
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
      
      
      //To call unsub code from BU resource
      $("#unsubscribeClick").click(function(e) {
        console.log('Inside unsubscribeClick()')
        var guestId = document.getElementById('guestId').value;
        var subsKey = document.getElementById('crmId').value;

                var dataToSend = {
                    guestId: guestId,
                    subsKey: subsKey
                };

                $.ajax({
                    url: 'https://cloud.explore.globalvillage.ae/UnsubscribeFromBU_QA', // Replace with your CloudPage URL
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
      
      
      //To call unsub code from all BU resource
      $("#unsubscribeAllClick").click(function(e) {
        console.log('Inside unsubscribeAllClick()')
        var subsKey = document.getElementById('crmId').value;
        var guestId = document.getElementById('guestId').value;

                var dataToSend = {
                    guestId: guestId,
                    subsKey: subsKey
                };

                $.ajax({
                    url: 'https://cloud.explore.globalvillage.ae/UnsubscribeFromAllBU_QA', // Replace with your CloudPage URL
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
          <script>
                 // <!--for display box on unsubscribe button click-->
function channelPreference() {
    document.getElementById("channel-preference").style.display = "block";
}
$('.close-buttonCM').click(function(e) { 
    document.getElementById("channel-preference").style.display = "none";
});
   
$('.channelPreference-btn').click(function(e) { 
    document.getElementById("unsubscribe-reason").style.display = "none";
    document.getElementById("unsubscribe-all-reason").style.display = "none";
});

// <!--for display box on unsubscribe button click-->
function unsubscribeClick() {
    document.getElementById("unsubscribe-reason").style.display = "block";
console.log("hey in js custom");
}

$('.close-button').click(function(e) {
    document.getElementById("unsubscribe-reason").style.display = "none";
});

$('.unsubscribe-btn').click(function(e) {
    document.getElementById("channel-preference").style.display = "none";
    document.getElementById("unsubscribe-all-reason").style.display = "none";
});

// <!--for display box on unsubscribe all button click-->
function unsubscribeAllClick() {
    document.getElementById("unsubscribe-all-reason").style.display = "block";
}

$('.close-buttonAll').click(function(e) {
    document.getElementById("unsubscribe-all-reason").style.display = "none";
});

$('.unsubscribe-all-btn').click(function(e) {
    document.getElementById("channel-preference").style.display = "none";
    document.getElementById("unsubscribe-reason").style.display = "none";
});


// <!--for display Textarea on other checkbox click-->
function addbox1() {
    if (document.getElementById("myCheck1").checked) {
      document.getElementById("area1").style.display = "block";
    } else {
      document.getElementById("area1").style.display = "none";
    }
  }
  addbox1();

// <!--for display Textarea on other checkbox click-->
function addbox_1() {
    if (document.getElementById("myCheck_1").checked) {
      document.getElementById("area_1").style.display = "block";
    } else {
      document.getElementById("area_1").style.display = "none";
    }
  }
  addbox_1();

// <!--Make Email non- editable if not empty-->
   if ($("input[type=email]").val().length > 0){
    $("input[type=email]").prop('disabled', true);
  }
// <!--Make country code field required if phone field not empty-->
//  $('#phone1').on('input', function() {
//  var phoneValue = $(this).val();
  //if (phoneValue !== '') {
  //$("#country-code").attr("required",true);
//}
//else{
// $("#country-code").attr("required",false);
//}
  //})


  // for valid value
var inputs = document.querySelectorAll('input[list]');
for (var i = 0; i < inputs.length; i++) {
  inputs[i].addEventListener('input', function() {
    var optionFound = false,
      datalist = this.list;

    if (this.value === '') {
      // If the value is empty, clear the custom validity message
      this.setCustomValidity('');
    } else {
      for (var j = 0; j < datalist.options.length; j++) {
        if (this.value == datalist.options[j].value) {
          optionFound = true;
          break;
        }
      }

      if (optionFound) {
        this.setCustomValidity('');
      } else {
        this.setCustomValidity('Please select a valid value.');
      }
    }
  });
}
//Future date restricting Validation


    var today = new Date().toJSON().slice(0, 10);
    var date = $('input[type=date]');
    date.attr('max', today);
    
  

// for making radio required for interest page Q.1
function validateForm1() {
  var checkboxes = document.querySelectorAll('.interest-form .primary-reason .form-check-input');
var checing = document.getElementById('reason1');
  var atLeastOneChecked = Array.from(checkboxes).some(function(checkbox) {
    return checkbox.checked;
  });

  if (!atLeastOneChecked) {
   
    checing.setAttribute('required', 'required');
    return false;
  }


  return true; 
}

// for Making radio funtionality if it have different names for Q.1

$(".primary-reason input[type=radio]").click(function(event) {
  
  $(".primary-reason input[type=radio]").prop("checked", false);
  $(this).prop("checked", true);
  var checing = document.getElementById('reason1');
  checing.removeAttribute('required');
 
});

 // for making radio required for interest page Q.2
 function validateForm2() {
  var checkboxes = document.querySelectorAll('.interest-form .often-visit .form-check-input');
var checing = document.getElementById('visit1');
  var atLeastOneChecked = Array.from(checkboxes).some(function(checkbox) {
    return checkbox.checked;
  });

  if (!atLeastOneChecked) {
   
    checing.setAttribute('required', 'required');
    return false;
  }


  return true; 
}

// for Making radio funtionality if it have different names for Q.2

$(".often-visit input[type=radio]").click(function(event) {
  
  $(".often-visit input[type=radio]").prop("checked", false);
  $(this).prop("checked", true);
  var checing = document.getElementById('visit1');
  checing.removeAttribute('required');
 
});

// for making radio required for interest page Q.3
function validateForm3() {
  var checkboxes = document.querySelectorAll('.interest-form .like-most .form-check-input');
var checing = document.getElementById('like1');
  var atLeastOneChecked = Array.from(checkboxes).some(function(checkbox) {
    return checkbox.checked;
  });

  if (!atLeastOneChecked) {
   
    checing.setAttribute('required', 'required');
    return false;
  }


  return true; 
}

// for Making radio funtionality if it have different names for Q.3

$(".like-most input[type=radio]").click(function(event) {
  
  $(".like-most input[type=radio]").prop("checked", false);
  $(this).prop("checked", true);
  var checing = document.getElementById('like1');
  checing.removeAttribute('required');
 
});
//for page refresh show from top

window.onbeforeunload = function () {
  window.scrollTo(0, 0);
}


//Loader Script


      $('form').submit(function(event) {

        $(".loader1").show();
  
        setTimeout(function() {
          $(".loader1").hide();   
        }, 20000);
      });

  
   
 // Function to toggle the disabled attribute of #nationality
        function toggleNationalityField() {
            var value = $("#profileCountry").val();
            $("#nationality").prop('disabled', value !== "United Arab Emirates");
        }
    
        // Initially set the disabled attribute based on the selected option
        toggleNationalityField();
        if ($("#profileCountry").val() !== "United Arab Emirates") {
          $("#nationality").val('');
      }
  
        // Add an event listener to #profileCountry
        $("#profileCountry").on("change", function() {
            // Call the function to toggle the disabled attribute
            toggleNationalityField();
                // Reset nationality field if the selected country is not UAE
        if ($(this).val() !== "United Arab Emirates") {
            $("#nationality").val('');
        }
        });
  
    // Function to toggle the disabled attribute of #city
        function toggleCityField() {
          var value = $("#profileCountry").val();
          $("#city").prop('disabled', value !== "United Arab Emirates");
      }
  
      // Initially set the disabled attribute based on the selected option
      toggleCityField();
      if ($("#profileCountry").val() !== "United Arab Emirates") {
        $("#city").val('');
    }

      // Add an event listener to #profileCountry
      $("#profileCountry").on("change", function() {
          // Call the function to toggle the disabled attribute
          toggleCityField();
              // Reset nationality field if the selected country is not UAE
      if ($(this).val() !== "United Arab Emirates") {
          $("#city").val('');
      }
      });
  
    

  
         
          </script>                
                         
                                </body>
                            </html>
