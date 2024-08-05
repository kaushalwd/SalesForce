SalesforceInteractions.init({
    // Initializes the Personalization module of the Salesforce Interactions SDK
      cookieDomain: "northerntrailoutfitters.com",
      trackerUrl: "https://partnerhorizontalus.us-4.evergage.com"
  }).then(() => {
    const sitemapConfig = {
      // Sitemap configuration object
      global: {
        listeners: [
          SalesforceInteractions.listener("click", ".add-to-cart", () => {
            let lineItem = SalesforceInteractions.mcis.buildLineItemFromPageState("select[id*=quantity]");
            SalesforceInteractions.sendEvent({
              interaction: {
                name: SalesforceInteractions.CartInteractionName.AddToCart,
                lineItem: lineItem,
              },
            });
            console.log("lineItem --->", lineItem);
          }),
          // SalesforceInteractions.listener("click", ".pdp-checkout-button .add-to-cart", () =>{
          //   SalesforceInteractions.sendEvent({interaction: {name:'Add to Cart clicked'}})
          // }),
          // SalesforceInteractions.listener("click", ".add-to-cart", () => {
          //   let lineItem = SalesforceInteractions.mcis.buildLineItemFromPageState("select.quantity-select option:checked");
          //   console.log("Line Item", lineItem);
          //   SalesforceInteractions.sendEvent({                                                                                                                            
          //     interaction: {
          //       name: SalesforceInteractions.CartInteractionName.AddToCart,
          //       lineItem: lineItem
          //     }
          //   })
          // })
        ],
        // conentZones:[
        //   {name: "", selector: ""}
        // ]
      }, // Object used to contain Global site object configuration
      pageTypes: [
        {
          name:"product_detail",
          isMatch:() => {
            return SalesforceInteractions.cashDom("div.page[data-action='Product-Show']").length > 0
            // return SalesforceInteractions.cashDom(".preheader .user").length > 0
          },
          catalog: {
            UserData: {
              id: '10',
              userName: SalesforceInteractions.cashDom(".preheader nav section:nth-of-type(3) > div > a > span").text(),
              userHash: getUserDeviceDetails()
            }
          }
        }
      ] // Array used to contain the page type object configurations
      
    };
  
    SalesforceInteractions.initSitemap(sitemapConfig); // Initializes the Sitemap
  });
  function isMobileDevice() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }
  function clientBrowser(){
    var ua= navigator.userAgent;
    var tem; 
    var M= ua.match(/(opera|chrome|safari|firefox|msie|trident(?=\/))\/?\s*(\d+)/i) || [];
    if(/trident/i.test(M[1])){
        tem=  /\brv[ :]+(\d+)/g.exec(ua) || [];
        return 'IE '+(tem[1] || '');
    }
    if(M[1]=== 'Chrome'){
        tem= ua.match(/\b(OPR|Edge)\/(\d+)/);
        if(tem!= null) return tem.slice(1).join(' ').replace('OPR', 'Opera');
    }
    M= M[2]? [M[1], M[2]]: [navigator.appName, navigator.appVersion, '-?'];
    if((tem= ua.match(/version\/(\d+)/i))!= null) M.splice(1, 1, tem[1]);
    return M.join('');
  };
  
  function getCurrentTime(){
    const date = new Date();
    // const date = new Date(timestamp * 1000);
    return date.getDate()+"/"+(date.getMonth()+1)+"/"+date.getFullYear()+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()
     
  }
  
  // function for encryption the input message
  function encryptMsg(str, shift) {
    let encreptedStr = '';
    for (let i = 0; i < str.length; i++) {
       let charCode = str.charCodeAt(i);
        console.log("EN charCode -- ",charCode)
       if (charCode >= 65 && charCode <= 90) {
          encreptedStr += String.fromCharCode((charCode - 65 + shift) % 26 + 65);
       } else if (charCode >= 97 && charCode <= 122) {
          // lowercase letters
          encreptedStr += String.fromCharCode((charCode - 97 + shift) % 26 + 97);
       } else if (charCode >= 48 && charCode <= 57) {
          // lowercase letters
          encreptedStr += String.fromCharCode((charCode - 97 + shift) % 26 + 55);
       } else {
          // non-alphabetic characters
          encreptedStr += str.charAt(i);
       }
    }
    return encreptedStr;
  }
  
  // function for decryption the input message
  function decryptMsg(str, shiftRev) {
    let decryptedStr = '';
    for (let i = 0; i < str.length; i++) {
       let charCode = str.charCodeAt(i);
       console.log("DR charCode -- ",charCode)
       if (charCode >= 65 && charCode <= 90) {
           if(charCode >=65 && charCode <=69 )
              decryptedStr += String.fromCharCode(((charCode - 65 + shiftRev) % 26 + 91));
           else
              decryptedStr += String.fromCharCode(((charCode - 65 + shiftRev) % 26 + 65));   
       } else if (charCode >= 97 && charCode <= 122) {
           // lowercase letters
           if(charCode >= 97 && charCode <= 101 )
              decryptedStr += String.fromCharCode((charCode - 97 + shiftRev) % 26 + 123);
           else
              decryptedStr += String.fromCharCode((charCode - 97 + shiftRev) % 26 + 97);   
       } else if (charCode >= 37 && charCode <= 46) {
          // lowercase letters
          decryptedStr += String.fromCharCode((charCode - 97 + shiftRev) % 26 + 61);
       } else {
          // non-alphabetic characters
          decryptedStr += str.charAt(i);
       }
       
    }
    return decryptedStr;
  }
  
  function getUserDeviceDetails(){
    let os = "Unknown OS";
    if (navigator.appVersion.indexOf("Win") != -1) os = "Windows";
    if (navigator.appVersion.indexOf("Mac") != -1) os = "MacOS";
    if (navigator.appVersion.indexOf("X11") != -1) os = "UNIX";
    if (navigator.appVersion.indexOf("Linux") != -1) os = "Linux";
    
    let ifMobile = isMobileDevice();
     let originalString = os+navigator.platform+clientBrowser()+ifMobile
    //let originalString = 'WindowsWindows32MacInZelChrome127false';
    // ABCDEFGHIJKLMNOPQRSTUVWXYZ
    //'abcdefghijklmnopqrstuvwxyz'
    
    
    const shift = 5;
    const shiftRev = -5;
    // const encryptedString = encryptMsg(originalString, shift);
    const encryptedString = encryptMsg(originalString, shift);
    const decryptedString = decryptMsg(encryptedString, shiftRev);
    console.log("Original String ---->", originalString);
    console.log("Encrypted String ---->", encryptedString);
    console.log("Decrypted String ---->", decryptedString);
  
    //return os+"#"+navigator.platform+"#"+clientBrowser()+"#"+ifMobile+"#"+getCurrentTime();
    return encryptedString;
  }