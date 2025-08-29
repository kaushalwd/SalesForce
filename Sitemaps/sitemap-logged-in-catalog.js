Evergage.init({
  // Initializes the Personalization module of the Salesforce Interactions SDK
    cookieDomain: "northerntrailoutfitters.com",
    trackerUrl: "https://partnerhorizontalus.us-4.evergage.com"
}).then(() => {
   const sitemapConfig = {
    // Sitemap configuration object
    global: {
      //   listeners: [
      //   Evergage.DisplayUtils.pageElementLoaded("body").then((e) => {
      //       console.log("Page load...");
      //           SalesforceInteractions.sendEvent({
      //           interaction: {
      //           name: "Page loads..."
      //           },
      //       })
      //   })
      // ]
    }, // Object used to contain Global site object configuration
    pageTypes: [
      {
        name:"user_logged_in",
        action: "Browser Fingerprint",
        isMatch:() => {
          return SalesforceInteractions.cashDom(".preheader .user").length == 0
        },
        catalog: {
          UserBrowserData: {
            _id: "1",
            id: "1",
            userName: Evergage.cashDom(".preheader nav section:nth-of-type(3) > div > a > span").text(),
            browserFingerPrint: _ub_data()
          }
        }
      }
    ], // Array used to contain the page type object configurations
  };
  
  Evergage.initSitemap(sitemapConfig); // Initializes the Sitemap
});
function _ub_fingerprint(string) {
  var hash = 0, i, chr;
  if (string.length === 0) return hash;
  for (i = 0; i < string.length; i++) {
    chr   = string.charCodeAt(i);
    hash  = ((hash << 5) - hash) + chr;
    hash |= 0;
  }
  console.log("hash --> ", Math.abs(hash));
  return Math.abs(hash);
};

function _ub_data(){
  var canvas = document.createElement('canvas');
  var gl = canvas.getContext('webgl');

  var timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  var timezone_offset = new Date().getTimezoneOffset();
  var graphics_card = gl.getParameter(gl.RENDERER);

  let cString = "";

  if(navigator.appVersion.indexOf("Mac") != -1){
    cString = window.screen.availWidth + "x" +
    window.screen.availHeight + "_" +
    window.screen.colorDepth + "_" +
    navigator.userAgent + "_" +
    navigator.platform + "_" +
    navigator.language + "_" +
    navigator.hardwareConcurrency + "_" +
    navigator.cookieEnabled + "_" +
    timezone + "_" +
    timezone_offset + "_" +
    graphics_card
  }else{
    cString = window.screen.availWidth + "x" +
    window.screen.availHeight + "_" +
    window.screen.colorDepth + "_" +
    clientBrowser() + "_" +
    navigator.platform + "_" +
    navigator.language + "_" +
    navigator.hardwareConcurrency + "_" +
    navigator.cookieEnabled + "_" +
    timezone + "_" +
    //timezone_offset + "_" +
    graphics_card
  }

  return _ub_fingerprint(cString);
}

function clientBrowser(){
  var ua= navigator.userAgent;
  var tem; 
  var M= ua.match(/(opera|edge|edg|chrome|safari|firefox|msie|trident(?=\/))\/?\s*(\d+)/i) || [];
  if(/trident/i.test(M[1])){
      tem=  /\brv[ :]+(\d+)/g.exec(ua) || [];
      return 'IE '+(tem[1] || '');
  }
  if(M[1]=== 'Chrome'){
      tem= ua.match(/\b(OPR|Edg)\/(\d+)/);
      if(tem!= null) return tem.slice(1).join('').replace('OPR', 'Opera').replace('Edg', 'Edge');
  }
  M= M[2]? [M[1], M[2]]: [navigator.appName, navigator.appVersion, '-?'];
  if((tem= ua.match(/version\/(\d+)/i))!= null) M.splice(1, 1, tem[1]);
  return M.join('');
};
