%%[

    /*SET @sfid = QueryParameter("sfid")
    set @decodeSFID = Base64Decode(@sfid)
    set @id = Base64Encode(@decodeSFID)*/
      SET @id = _subscriberkey
      /*output(concat("Id: ",@Id))*/
      IF (empty(@id)) THEN
        SET @idEn = QueryParameter("sfid")
        SET @id = Base64Decode(@idEn)
        /*output(concat("decodeSFID:- ",@decodeSFID))*/
        IF (empty(@id)) THEN
          SET @id = RequestParameter("sfid")
          /*output(concat("Id:-- ",@Id))*/
          IF (empty(@id)) THEN
           SET @id = QueryParameter("sfid")
           /*output(concat("Id:--- ",@Id))*/
          ENDIF
         ENDIF
        ENDIF
        /*set @id = Base64Encode(@decodeSFID)*/
        if empty(@idEn) or IsNull(@idEn) then
          set @link= "%%=RedirectTo(CloudPagesURL(3632))=%%"
        else
          Set @link = Concat("https://cloud.explore.theviewpalm.ae/TV_CPC_Arabic_QA?sfid=",@idEn)
        endif
        
    
    SET @contactRows = RetrieveSalesforceObjects("Guest_Subscription__c","Status__c",
    "Contact__c", "=", @id,"Asset__c","=","The View","Sub_Asset__c","=","The View")
    
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
                            <html lang="ar" dir="rtl">
                              <head><meta name="ROBOTS" content="INDEX,FOLLOW"><meta name="keywords" content=""><meta name="description" content="">
                                <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                                  <title>The View</title>
    <link rel="icon" type="image/x-icon" href="https://image.explore.globalvillage.ae/lib/fe3511737364047c7c1571/m/1/2ac2dd06-ae44-4b91-b8e1-6e998ac0d3e2.png">
                                    <link href='https://cloud.explore.theviewpalm.ae/ARbootstrap_TV_QA.min.css' rel='stylesheet'>
                                    
                                    <script type='text/javascript' src='https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_jquery.min.js'></script>
                                 
                                    <!-- Font special for pages-->
                                    <link href="https://fonts.googleapis.com/css?family=Poppins:100,100i,200,200i,300,300i,400,400i,500,500i,600,600i,700,700i,800,800i,900,900i" rel="stylesheet">
                                    <link href="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_style" rel="stylesheet">
                                    
                                  
                                   
                                    <!-- Vendor CSS-->
                                    <link href="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_select2.min.css" rel="stylesheet" media="all">
                                    <!-- <link href="https://cloud.explore.globalvillage.ae/daterangepicker_dpr_dev" rel="stylesheet" media="all"> -->
                                 
                 <style>
                    /* thank you page css */
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
      background: #00AF87;
      color: #fff;
      font-size: 16px;
      text-align: right;
      font-weight: bold;
    }
    .back-to-profile a:hover{
      background: transparent;
      color: #00AF87;
      border: 2px solid #00AF87 ;
    }
    .back-to-profile {
      max-width: 900px;
      text-align: left;
    }
                 </style>
    <script runat=server>
        Platform.Response.SetResponseHeader("Strict-Transport-Security","max-age=200");
        Platform.Response.SetResponseHeader("X-XSS-Protection","1; mode=block");
        Platform.Response.SetResponseHeader("X-Frame-Options","Deny");
        Platform.Response.SetResponseHeader("X-Content-Type-Options","nosniff");
        Platform.Response.SetResponseHeader("Referrer-Policy","strict-origin-when-cross-origin");
      Platform.Response.SetResponseHeader("Content-Security-Policy","script-src 'self' 'unsafe-inline' https://cloud.explore.theviewpalm.ae https://cloud.explore.globalvillage.ae; frame-ancestors 'none'");
    </script>
                                </head>
                                <body dir="rtl">
                                    <header>
                                        <div class="container">
                                            <div class="row align-items-center" style="margin: 0 auto;">
                                                <div class="col-lg-8 col-md-8 col-sm-8 col-8">
                                                  <a href="https://thegreenplanetdubai.com/ar" class="logo-link" target="_blank">
                                                    <img src="https://image.explore.theviewpalm.ae/lib/fe3111737364047a741c70/m/1/dd4a83b1-587c-41fb-a21b-9361b1029cbe.png" alt="logo">
                                                </a>
                                                </div>
                                                <div class="col-lg-4 col-md-4 col-sm-4 col-4">
                              
                                                <a href="https://dubaiholding.com/ar/who-we-are/our-companies/dubai-holding-entertainment/" class="logo-link" target="_blank">
                                                    <img src="https://image.explore.thegreenplanetdubai.com/lib/fe3b117373640479751472/m/1/35c6e6ff-9c10-42cd-867f-98cbecf3627d.png"
                                                        alt="logo-dhe" class="pull-right dhe-logo">
                                                </a>
                              
                                                </div>
                                            </div>
                                        </div>
                                   
                                       <div class="lang-switcher-text">
                <a href="https://cloud.explore.theviewpalm.ae/TV_ThankYou_QA" class="language-toggle-link"  id="langSwitcher" onclick="dynamicLangSwitcher();"  style="text-decoration: underline;">ENGLISH</a>
              </div>
                                    </header>
                                    <!-- Header End --><section class="banner">
                                      <div class="main-banner">
                                        <img src= "https://image.explore.theviewpalm.ae/lib/fe3111737364047a741c70/m/1/179510b2-fc0d-4833-b4b1-80c84bed4ce7.png" alt="banner-img" class="responsive">
                                            </div>
                                            <div class="container">
                                            <h1 class="username">مرحباً %%=v(ProperCase(@firstName))=%%</h1>
                                          </div>
                                          </section>
    <!-- content section -->
    <form class="comment-form">
        <div class="container">
          <div style="display: %%=IIF(NOT @hideDiv, 'block', 'none')=%%;" class="thanks-wrapper form group">
            <div class="thanYou-img mb-2">
                <img src="https://image.explore.theviewpalm.ae/lib/fe3111737364047a741c70/m/1/ae919054-260b-4edd-bab5-92bdc7412f60.png" alt="" class="banner-bg-img">
            </div>
          <div class="thankYou-text">
            <h2><strong>شكرا لك</strong></h2>
                <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">لقد قمنا بحفظ تفضيلاتك ونتطلع إلى خدمتك بشكل أفضل.</p>  
          </div>
          <div class="mt-5 back-to-profile">
            <a href="%%=RedirectTo(@link)=%%" name="button" class="btn back-btn">العودة إلى صفحتك الشخصية </a>
          </div>
        </div>
        </div>
        </form>
                                  
           <div class="container">
          <div style="display: %%=IIF(@hideDiv, 'block', 'none')=%%;" class="unsubscribe-wrapper form group">
            <div class="thanYou-img mb-2">
                <img src="https://image.explore.thegreenplanetdubai.com/lib/fe3b117373640479751472/m/1/274f476f-7123-4c2d-b8e7-aa0cce3c2cc3.png" alt="" class="banner-bg-img">
            </div>
          <div class="thankYou-text">
           
                <p style="font-size:16px; line-height:18px; color:#000000; font-weight: bold;">شكراً على تعليقاتك لمساعدتنا على تحسين خدماتنا.</p>  
          </div>
        
        </div>
        </div>                      
                                  
                                  
    <!-- content section end -->
                                         
    <!-- footer 2 start -->
    <footer>
       <div class="footer-container">
          <div class="footer-links-section">
             <ul class="general-links">
                <li>
                   <div class="content">
                      <a href="tel:8008438439" target="_blank" class="icon " style="margin-right: 15px;">
                      <img class="icon" src='https://www.theviewpalm.ae/ResourcePackages/TheView/assets/src/Assets/images/Call_Icon.svg' alt='' title='Footer_Call_Icon' style="width: 150%;"/>
                      </a>
                      <div class="description">
                         <span class="title">داخل دولة الإمارات العربية المتحدة</span>
                         <a href="tel:8008438439" target="_blank">800 THEVIEW</a>
                      </div>
                   </div>
                </li>
                <li>
                   <div class="content">
                      <a href="tel:+97144278484" target="_blank" class="icon ">
                      <img class="icon" src='https://www.theviewpalm.ae/images/thepointelibraries/contact-icons/footer_globe_icon.svg?sfvrsn=1a45f0d2_1' alt='' title='Footer_Globe_Icon' />
                      </a>
                      <div class="description">
                         <span class="title">خارج دولة الإمارات العربية المتحدة</span>
                         <a href="tel:+97144278484" target="_blank">+971-4-4278484</a>
                      </div>
                   </div>
                </li>
                <li>
                   <div class="content">
                      <a href="mailto:info@theviewpalm.ae" target="_blank" class="icon ">
                      <img class="icon" src='https://www.theviewpalm.ae/images/thepointelibraries/contact-icons/footer_email_icon.svg?sfvrsn=352855bb_1' alt='' title='Footer_Email_Icon' />
                      </a>
                      <div class="description">
                         <span class="title">للاستفسارات العامة</span>
                         <a href="mailto:info@theviewpalm.ae" target="_blank">تواصل معنا</a>
                      </div>
                   </div>
                </li>
                <li>
                   <div class="content">
                      <a href="mailto:sales@palmexperience.com" class="icon ">
                      <img class="icon" src='https://www.theviewpalm.ae/images/thepointelibraries/contact-icons/footer_email_icon.svg?sfvrsn=352855bb_1' alt='' title='Footer_Email_Icon' />
                      </a>
                      <div class="description">
                         <span class="title">للحجوزات الجماعية والفعاليات</span>
                         <a href="mailto:sales@palmexperience.com" target="_blank">تواصل معنا</a>
                      </div>
                   </div>
                </li>
             </ul>
             <ul class="social-links">
                <li>
                   <a href="https://www.facebook.com/TheViewPalm/" target="_blank">
                   <img src='https://www.theviewpalm.ae/images/thepointelibraries/social-icons/facebook.svg?sfvrsn=781d6ab8_1' alt='' title='Facebook'>
                   </a>
                </li>
                <li>
                   <a href="https://www.instagram.com/theviewpalm/" target="_blank">
                   <img src='https://www.theviewpalm.ae/images/thepointelibraries/social-icons/instagram.svg?sfvrsn=9651d908_1' alt='' title='Instagram'>
                   </a>
                </li>
                <li>
                   <a href="https://www.tripadvisor.com/Attraction_Review-g295424-d23302976-Reviews-The_View_at_The_Palm-Dubai_Emirate_of_Dubai.html" target="_blank">
                   <img src='https://www.theviewpalm.ae/images/thepointelibraries/social-icons/tripadvisor.svg?sfvrsn=405bd732_1' alt='' title='Tripadvisor'>
                   </a>
                </li>
             </ul>
          </div>
          <div class="copyright-section">
             <div class="copyright-text">حقوق الطبع والنشر .2024 جميع الحقوق محفوظة لذي فيو نخلة جميرا.</div>
             <ul>
                <li class="footer-nav-item">
                   <a target="_self" href="https://www.google.com/maps/place/The+View+at+the+Palm/@25.1137006,55.1372063,17z/data=!3m1!4b1!4m6!3m5!1s0x3e5f6b13906bb90b:0x20050f2f23d1482d!8m2!3d25.1137006!4d55.1397812!16s%2Fg%2F11s4z1jh7n?entry=ttu">الأسئلة الشائعة</a>
                </li>
                <li class="footer-nav-item">
                   <a target="_self" href="https://www.theviewpalm.ae/en/terms-conditions">الشروط والأحكام</a>
                </li>
                <li class="footer-nav-item">
                   <a target="_self" href="https://privacy.dubaiholding.com/en/privacy-notice/customers---dubai-holding-entertainment-llc">سياسة الخصوصية</a>
                </li>
             </ul>
          </div>
       </div>
    </footer>
            
            <!-- footer End -->                            
         <!-- Vendor JS-->
         <script src="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_bootstrap.min.js"></script>
        <script src="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_select2.min.js"></script>
        <script src="https://cloud.explore.theviewpalm.ae/TV_QA_Arabic_moment.min.js"></script>
        <script src="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_daterangepicker.js"></script>
    
        <!-- Main JS-->
        <script src="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_custom.js"></script>
        <script src="https://cloud.explore.theviewpalm.ae/TV_Arabic_QA_global.js"></script>
                                  
                                  <script>
                                  console.log("i1");
                                  </script>
                                  <script>
          function dynamicLangSwitcher() {
        console.log('INSIDE');
    
        var currentUrl = window.location.href;
        var qsIndex = currentUrl.indexOf('?');
        var hashIndex = currentUrl.indexOf('#');
        
        var queryString = qsIndex !== -1 ? currentUrl.substring(qsIndex, hashIndex !== -1 ? hashIndex : currentUrl.length) : '';
        var hashFragment = hashIndex !== -1 ? currentUrl.substring(hashIndex) : '';
    
        console.log('Current Query String (qs):', queryString);
        console.log('Current Hash Fragment:', hashFragment);
    
        var newLangUrl = document.getElementById('langSwitcher').href;
    
        if (queryString) {
            if (newLangUrl.indexOf('?') !== -1) {
                newLangUrl += '&' + queryString.substring(1);
            } else {
                newLangUrl += queryString;
            }
        }
    
        if (hashFragment) {
            newLangUrl += hashFragment;
        }
    
        console.log('Updated URL:', newLangUrl);
    
        document.getElementById('langSwitcher').href = newLangUrl;
    }
        </script>
                              
    </body>
    </html>