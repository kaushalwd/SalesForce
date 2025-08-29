
%%[

    /*SET @sfid = QueryParameter("sfid")
    set @decodeSFID = Base64Decode(@sfid)
    set @id = Base64Encode(@decodeSFID)*/
    SET @id = _subscriberkey
    IF (empty(@id)) THEN
        SET @idEn = QueryParameter("sfid")
        SET @id = Base64Decode(@idEn)
        IF (empty(@id)) THEN
          SET @id = RequestParameter("sfid")
          IF (empty(@id)) THEN
           SET @id = QueryParameter("sfid")
          ENDIF
         ENDIF
        ENDIF
    
        
        /*set @id = Base64Encode(@decodeSFID)*/
        if empty(@idEn) or IsNull(@idEn) then
          set @link= "%%=RedirectTo(CloudPagesURL(2852))=%%"
        else
          Set @link = Concat("https://cloud.explore.legoland.ae/LLQA_CPC_Arabic?sfid=",@idEn)
        endif
    
    
    SET @contactRows = RetrieveSalesforceObjects("Guest_Subscription__c","Status__c",
    "Contact__c", "=", @id,"Asset__c","=","Dubai Parks and Resorts","Sub_Asset__c","=","Legoland")
    
    /* Check if there are any rows returned */
    IF RowCount(@contactRows) > 0 THEN
    /* Get the first row */
    SET @contactRow = Row(@contactRows, 1)
    
    /* Get values from the fields */
    SET @status = Field(@contactRow, "Status__c")
    ENDIF
    
    SET @hideDiv = false
    IF @status == "Unsubscribed" Then
    SET @hideDiv = true
    
    ENDIF
    
    
    
    SET @contactRow =
        RetrieveSalesforceObjects("Contact",
      "FirstName",
        "Id","=", @id )
        if RowCount(@contactRows) == 1 then 
        set @contactRow = Row(@contactRow, 1)
        set @firstName = Field(@contactRow, "FirstName")
        endif
    ]%%
    
    
    
    <!DOCTYPE html>
                            <html>
                              <head><meta name="ROBOTS" content="INDEX,FOLLOW"><meta name="keywords" content=""><meta name="description" content="">
                                <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                                  <title>Legoland Dubai</title>
    <link rel="icon" type="image/x-icon" href="https://image.explore.globalvillage.ae/lib/fe3511737364047c7c1571/m/1/d581cc9a-20d5-45ab-a7c3-ba9cad9d2503.png">
                                  <link href='https://cloud.explore.legoland.ae/LL_boostrap_QA.min.css' rel='stylesheet'>
                                  
                                  <script type='text/javascript' src='https://cloud.explore.legoland.ae/LL_jquery_QA.min.js'></script>
                               
                                  <!-- Font special for pages-->
                                  <link href="https://fonts.googleapis.com/css?family=Poppins:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i,800,800i,900,900i" rel="stylesheet">
                                   <link href="https://cloud.explore.legoland.ae/LL_style_QA.css" rel="stylesheet">
                                  
                                
                                 
                                  <!-- Vendor CSS-->
                                  <link href="https://cloud.explore.legoland.ae/LL_select2_QA.min.css" rel="stylesheet" media="all">
                                  <!-- <link href="https://cloud.explore.globalvillage.ae/daterangepicker_dpr_dev" rel="stylesheet" media="all"> -->
                 <style>
                    /* thank you page css */
    body {
      direction:rtl;
    }
    .logo-link {
      text-align:right
    }
    .thanYou-img img{
      max-width: 10%;
      display: block;
      margin-left: auto;
      margin-right: auto;
    }
    .thanks-wrapper{
      margin: 50px 0 50px 0;
    }
    .unsubscribe-wrapper{
      margin: 50px 0 50px 0; 
    }
    .thankYou-text h2, .thankYou-text p{
      text-align: center;
    }
    .back-to-profile a{
      font-size: 16px;
      text-decoration: none;
      padding: 12px 25px;
    }
    .back-btn{
      background: #FFD400;
      color: #fff;
      font-size: 16px;
      text-align: right;
      font-weight: bold;
    }
    .back-to-profile a:hover{
      background: transparent;
      color: #FFD400;
      border: 2px solid #FFD400 ;
    }
    .back-to-profile {
      max-width: 800px;
      text-align: left;
    }
                 </style>
                                
                                
                                <script runat=server>
        Platform.Response.SetResponseHeader("Strict-Transport-Security","max-age=200");
        Platform.Response.SetResponseHeader("X-XSS-Protection","1; mode=block");
        Platform.Response.SetResponseHeader("X-Frame-Options","Deny");
        Platform.Response.SetResponseHeader("X-Content-Type-Options","nosniff");
        Platform.Response.SetResponseHeader("Referrer-Policy","strict-origin-when-cross-origin");
      Platform.Response.SetResponseHeader("Content-Security-Policy","script-src 'self' 'unsafe-inline' https://image.explore.legoland.ae https://cloud.explore.globalvillage.ae; frame-ancestors 'none'");
    </script>
                                
                                
                                
    </head>
    <body>
    <header>
    <div class="container">
        <div class="row align-items-center pt-0" style="margin: 0 auto;">
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
                  <h1 class="username">Hi %%=v(ProperCase(@firstName))=%%</h1>
              </div>
              </section>
    <!-- content section -->
    <form class="comment-form">
        <div class="container">
          <div style="display: %%=IIF(NOT @hideDiv, 'block', 'none')=%%;" class="thanks-wrapper form group">
            <div class="thanYou-img mb-2">
                <img src="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/738f6fca-b293-4bd7-8786-8535af6bde1b.png" alt="" class="banner-bg-img">
            </div>
          <div class="thankYou-text">
            <h2><strong>شكرا لك</strong></h2>
                <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">لقد قمنا بحفظ تفضيلاتك ونتطلع إلى خدمتك بشكل أفضل.</p>  
          </div>
          <div class="mt-5 back-to-profile">
            <a href="%%=RedirectTo(@link)=%%" name="button" class="btn back-btn">العودة إلى صفحتك الشخصية</a>
          </div>
        </div>
        </div>
        </form>
                                  
           <div class="container">
          <div style="display: %%=IIF(@hideDiv, 'block', 'none')=%%;" class="unsubscribe-wrapper form group">
            <div class="thanYou-img mb-2">
                <img src="https://image.explore.legoland.ae/lib/fe30117373640479741375/m/1/738f6fca-b293-4bd7-8786-8535af6bde1b.png" alt="" class="banner-bg-img">
            </div>
          <div class="thankYou-text">
           
                <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">شكراً على تعليقاتك لمساعدتنا على تحسين خدماتنا.</p>  
          </div>
        
        </div>
        </div>                      
                                  
                                  
    <!-- content section end -->
                                         
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
                                  console.log("i31");
                                  </script>
    </body>
    </html>