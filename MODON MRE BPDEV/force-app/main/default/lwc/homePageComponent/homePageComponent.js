import { LightningElement,wire,api } from 'lwc';
import modonLogo from '@salesforce/resourceUrl/modonLogoPlain';
import note from '@salesforce/resourceUrl/note';
import question from '@salesforce/resourceUrl/question';
import logowhite from '@salesforce/resourceUrl/logowhite';
import building from '@salesforce/resourceUrl/building';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import basePath from "@salesforce/community/basePath";
import { NavigationMixin } from 'lightning/navigation';
import buildingicon from '@salesforce/resourceUrl/buildingicon';
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';
import bedIcon from '@salesforce/resourceUrl/bed';
import bathIcon from '@salesforce/resourceUrl/washroom';
import sizeIcon from '@salesforce/resourceUrl/building';
import carIcon from '@salesforce/resourceUrl/Car';
import homeIcon from '@salesforce/resourceUrl/homeIcon';
import priceIcon from '@salesforce/resourceUrl/priceblack';
import paymentIcon from '@salesforce/resourceUrl/planblack';
import balcony from '@salesforce/resourceUrl/balcony';
import areaIcon from '@salesforce/resourceUrl/area';
import icon from '@salesforce/resourceUrl/Icon360';
import tour from '@salesforce/resourceUrl/Tour';

import companyFonts from '@salesforce/resourceUrl/CompanyFont';
import chartJsLib from '@salesforce/resourceUrl/ChartJs'; // Upload Chart.js file as static resource
import { loadScript } from 'lightning/platformResourceLoader';
import downloadIcon from '@salesforce/resourceUrl/building';
import manageIcon from '@salesforce/resourceUrl/building';
import getCurrentUserPhotoUrl from '@salesforce/apex/CommunityCustomerProfile.getCurrentUserPhotoUrl';
import FORM_FACTOR from '@salesforce/client/formFactor';

import getSalesOrdersByCustomer from '@salesforce/apex/CommunityHomeController.getSalesOrdersByCustomer';
import getSPA from '@salesforce/apex/CommunityHomeController.getSPA';
import getFloorPlan from '@salesforce/apex/CommunityHomeController.getFloorPlan';
import getPDF from '@salesforce/apex/CommunityHomeController.getPDF';
import getThisMonthsNotifications from '@salesforce/apex/CommunityHomeController.getThisMonthsNotifications';

import TWITTERXURL from '@salesforce/label/c.CP_twitterXURL';
import FACEBOOKURL from '@salesforce/label/c.CP_FaceBookUrl';
import YOUTUBEURL from '@salesforce/label/c.CP_YoutubeUrl';
import INSTAGRAMURL from '@salesforce/label/c.CP_InstagramUrl';
import LINKEDINURL from '@salesforce/label/c.CP_LinkedInUrl';
import MYPROPURL from '@salesforce/label/c.CP_MyPropertiesUrl';
import CONTACTUSURL from '@salesforce/label/c.CP_ModonContactUsUrl';
import MODONURL from '@salesforce/label/c.CP_ModonUrl';
import PROFILEURL from '@salesforce/label/c.CP_ProfileUrl';
import LOGOUTURL from '@salesforce/label/c.CP_LogoutUrl';
import MANSIONS from '@salesforce/resourceUrl/Mansions';
import HOMEPAGE from '@salesforce/label/c.Customer_Portal_URL';
import SOAPAGE from '@salesforce/label/c.Cp_SOAPage';

const FIELDS = ['User.Name','User.Contact.AccountId'];

export default class HomePageComponent extends NavigationMixin(LightningElement) {
    
    buildingicon =buildingicon;
    balcony =balcony;
    bedIcon = bedIcon;
    bathIcon = bathIcon;
    sizeIcon = sizeIcon;
    carIcon = carIcon;
    homeIcon = homeIcon;
    priceIcon = priceIcon;
    paymentIcon = paymentIcon;
    downloadIcon = downloadIcon;
    areaIcon=areaIcon;
    manageIcon = manageIcon;
    campaignIcon= icon;
    //backgroundStyle = `background-image: url(${communityBg});`;
    logoUrl = modonLogo;
    logowhiteUrl = logowhite;
    noteUrl = note;
    questionUrl = question;
    buildingUrl = building;
    MANSIONS=MANSIONS;
    userName ;
    nodata = false;
    onload=true;
    properties;
      @api recordId;
        salesOrders = [];
        isNoSalesOrders = false;
        isLoading = true;
        columns = [];
        showRecordspage = false;
        selectedSalesOrderId;
      
        contactid=null;
     menuOpen = false;
     showNotif=false;
      isMobile = false;
     isTablet = false;
     isDesktop = false;
     showSearch = false;
   // properties = [];
     allProperties = [];
     searchProjectName = '';
     searchUnitName = '';
     isLoading = false;
    connectedCallback() {
        this.isLoading = true;
        if (FORM_FACTOR === 'Large') {
            this.isDesktop = true;
        } else {
            this.isMobile = true;
        }
        this.isLoading = false;

    }
   
    get backgroundImageStyle() {
        if(this.isMobile){
            return `background-image: url(${buildingicon}); 
            object-fit: cover; 
           position: relative;`;
        }else{
            return `background-image: url(${buildingicon}); 
            background-size: cover; position: relative;`;
        }

       
    }
    chartJsInitialized = false;
    charts = {};
    renderedCallback() {
        if (this.chartJsInitialized || !this.properties) {
            return;
        }
        this.chartJsInitialized = true;

        loadScript(this, chartJsLib)
            .then(() => {
                this.initializeCharts();
            })
            .catch(error => {
                console.error('Chart.js loading failed', error);
            });
    }

    initializeCharts() {
        // Installments Charts
        // this.template.querySelectorAll('canvas.donut-chart-installments').forEach(canvas => {
        //     const propertyId = canvas.dataset.id;
        //     const property = this.properties.find(prop => prop.Id === propertyId);
    
        //     if (property) {
        //         const ctx = canvas.getContext('2d');
        //         const installmentsCompleted = property.installmentSummary?.totalPaidInstallments || 0;
        //         const installmentsNotPaid = property.installmentSummary?.totalNotPaidInstallments || 0;
        //         const installmentsTotal = installmentsCompleted + installmentsNotPaid || 1; // avoid division by zero
        //         const percentageCompleted = Math.round((installmentsCompleted / installmentsTotal) * 100);
        //         const remainingPercentage = 100 - percentageCompleted;
                
        //         const chart = new Chart(ctx, {
        //             type: 'doughnut',
        //             data: {
        //                 labels: [],
        //                 datasets: [{
        //                     data: [installmentsCompleted, installmentsNotPaid, installmentsNotPaid, installmentsNotPaid, installmentsNotPaid, installmentsNotPaid,installmentsNotPaid],
        //                     backgroundColor: ['#9d9fa1','#dbdcde', '#dbdcde','#dbdcde', '#dbdcde','#dbdcde', '#dbdcde','#dbdcde'], // green for completed, grey for remaining
        //                     borderWidth: 3
        //                 }]
        //             }, 
        //             options: {
        //                 cutout: '70%',
        //                 responsive: true,
        //                 maintainAspectRatio: false,
        //                 tooltips: { enabled: false },
        //                 plugins: {
        //                     legend: { display: false },
        //                     beforeDraw: (chart) => {
        //                         const width = chart.width;
        //                         const height = chart.height;
        //                         const ctx = chart.ctx;
        //                         ctx.restore();
        //                         const fontSize = (height / 5).toFixed(2);
        //                         ctx.font = fontSize + "px Arial";
        //                         ctx.textBaseline = "middle";
        //                         const text = percentageCompleted + "%";
        //                         const textX = Math.round((width - ctx.measureText(text).width) / 2);
        //                         const textY = height / 2;
        //                         ctx.fillText(text, textX, textY);
        //                         ctx.save();
        //                     }
        //                 }
        //             }
        //         });
    
        //         this.charts[`installments-${propertyId}`] = chart;
        //     }
        // });
        this.template.querySelectorAll('canvas.donut-chart-installments').forEach(canvas => {
            const propertyId = canvas.dataset.id;
            const property = this.properties.find(prop => prop.Id === propertyId);
        
            if (property) {
                const ctx = canvas.getContext('2d');
                const installmentsCompleted = property.installmentSummary?.totalPaidInstallments || 0;
                const installmentsNotPaid = property.installmentSummary?.totalNotPaidInstallments || 0;
                const installmentsTotal = installmentsCompleted + installmentsNotPaid || 1; // avoid division by zero
                const percentageCompleted = Math.round((installmentsCompleted / installmentsTotal) * 100);
        
                const segmentData = [];
                const segmentColors = [];
        
                // ✅ Fill Paid segments
                for (let i = 0; i < installmentsCompleted; i++) {
                    segmentData.push(1);
                    segmentColors.push('#9d9fa1'); // Paid color
                }
        
                // ✅ Fill Remaining segments
                for (let i = 0; i < installmentsNotPaid; i++) {
                    segmentData.push(1);
                    segmentColors.push('#dbdcde'); // Remaining color
                }
        
                const chart = new Chart(ctx, {
                    type: 'doughnut',
                    data: {
                        labels: [], // no per-segment labels
                        datasets: [{
                            data: segmentData,
                            backgroundColor: segmentColors,
                            borderWidth: 3
                        }]
                    },
                    options: {
                        cutout: '70%',
                        responsive: true,
                        maintainAspectRatio: false,
                        tooltips: { enabled: false },
                        plugins: {
                            legend: { display: false },
                            beforeDraw: (chart) => {
                                const width = chart.width;
                                const height = chart.height;
                                const ctx = chart.ctx;
                                ctx.restore();
                                const fontSize = (height / 5).toFixed(2);
                                ctx.font = fontSize + "px Arial";
                                ctx.textBaseline = "middle";
                                const text = percentageCompleted + "%";
                                const textX = Math.round((width - ctx.measureText(text).width) / 2);
                                const textY = height / 2;
                                ctx.fillText(text, textX, textY);
                                ctx.save();
                            }
                        }
                    }
                });
        
                this.charts[`installments-${propertyId}`] = chart;
            }
        });
    
        // Equity Charts
        this.template.querySelectorAll('canvas.donut-chart-equity').forEach(canvas => {
            const propertyId = canvas.dataset.id;
            const property = this.properties.find(prop => prop.Id === propertyId);
    
            if (property) {
                const ctx = canvas.getContext('2d');
                const equityPercentage = Math.round(property.installmentSummary.paidPercentage || 0);
                const remainingEquity = 100 - equityPercentage;
    
                const chart = new Chart(ctx, {
                    type: 'doughnut',
                    data: {
                        labels: [],
                        datasets: [{
                            data: [equityPercentage, remainingEquity],
                            backgroundColor: ['#9d9fa1','#dbdcde'], // blue for equity
                            borderWidth: 3
                        }]
                    },
                    options: {
                        cutout: '70%',
                        responsive: true,
                        maintainAspectRatio: false,
                        tooltips: { enabled: false },
                        plugins: {
                            legend: { display: false },
                            beforeDraw: (chart) => {
                                const width = chart.width;
                                const height = chart.height;
                                const ctx = chart.ctx;
                                ctx.restore();
                                const fontSize = (height / 5).toFixed(2);
                                ctx.font = fontSize + "px Arial";
                                ctx.textBaseline = "middle";
                                const text = equityPercentage + "%";
                                const textX = Math.round((width - ctx.measureText(text).width) / 2);
                                const textY = height / 2;
                                ctx.fillText(text, textX, textY);
                                ctx.save();
                            }
                        }
                    }
                });
    
                this.charts[`equity-${propertyId}`] = chart;
            }
        });
    }
    
    
    disconnectedCallback() {
        // Destroy all charts when component is removed
        Object.values(this.charts).forEach(chart => {
            chart.destroy();
        });
        this.charts = {};
    }
   
    toggleSearch() {
        this.menuOpen = false;
        this.showNotif = false;
        this.showSearch = !this.showSearch;
    }

    toggleNotif() {
        this.menuOpen = false;
        this.showSearch = false;
        this.showNotif = !this.showNotif;
    }


    handleProjectChange(event) {
        this.searchProjectName = event.target.value;
        
        this.filterProperties();
        if(this.properties.length === 0){
            this.nodata = true;
            this.onload =false;
        }else{
            this.nodata = false;
            this.onload =true;
        }
    }
    
    handleUnitChange(event) {
        this.searchUnitName = event.target.value;
        this.filterProperties();
        if(this.properties.length === 0){
            this.nodata = true;
            this.onload =false;
        }else{
            this.nodata = false;
            this.onload =true;
        }
    }

    filterProperties() {
        const projectName = this.searchProjectName.trim().toLowerCase();
        const unitName = this.searchUnitName.trim().toLowerCase();
    
        if (!projectName && !unitName) {
            this.properties = [...this.allProperties]; // show all if nothing entered
            return;
        }
    
        this.properties = this.allProperties.filter((prop) => {
            const projectMatch = projectName
                ? (prop.ProjectName || '').toLowerCase().includes(projectName)
                : true;
            const unitMatch = unitName
                ? (prop.UnitName || '').toLowerCase().includes(unitName)
                : true;
            return projectMatch && unitMatch;
        });
    }
    

    setPropertyData(data) {
        this.allProperties = data;
        this.properties = data;
    }
  
        toggleMenu() {
            this.showSearch = false;
            this.showNotif = false;
            this.menuOpen = !this.menuOpen;
        }
        @wire(getRecord, { recordId: USER_ID, fields: FIELDS })
        user({ error, data }) {
            if (data) {
                this.userName = data.fields.Name.value;
                if( data.fields.Contact.value){
                    this.contactid = data.fields.Contact.value.fields.AccountId.value;
                    if(this.contactid){
                        this.fetchacc();
                    }
                }
              this.loadImage();
            } else if (error) {
                console.error('Error fetching user:', error);
            }
        }
        loadImage(){
            getCurrentUserPhotoUrl()
                .then(result => {
                    this.avatarUrl = `data:image/jpeg;base64,${result}`;
                })
                .catch(error => {
                });
        }

        fetchacc() {
            getSalesOrdersByCustomer({ customerId: this.contactid })
                .then(result => {
                    const formattedResult = result.map(item => {
                        return {
                            ...item,
                            ImageUrl: item.ImageUrl || buildingicon,
                            formattedAmount: item.installmentSummary.nextInstallmentAmount?.toLocaleString('en-US') || '0.00',
                            formattedtotal: item.TotalAmount?.toLocaleString('en-US') || '0.00',
                            formattedsize: item.installmentSummary.balanceAmount?.toLocaleString('en-US') || '0.00',
                            TotalGrossArea: item.TotalGrossArea?.toLocaleString('en-US') || '0.00',
                            TotalArea: item.TotalArea?.toLocaleString('en-US') || '0.00'
                            
                        };
                    });
                   
                    this.allProperties = formattedResult; // store master copy
                    this.properties = [...this.allProperties]; // initialize visible list
        
                })
                .catch(error => {
                });

                    getThisMonthsNotifications()
                        .then(result => {
                            this.notifications = result;
                        })
                        .catch(error => {
                            console.error('Error loading notifications:', error);
                        });
        }
        
    
    handleMenuSelect(event) {
        
        const selectedValue =  event.target.dataset.id;// Correct way to access the selected item value

        if (selectedValue === 'logout') {
            const sitePrefix = basePath.replace("/", "");
            window.location.href = LOGOUTURL; //'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/secur/logout.jsp';
        } else if (selectedValue === 'profile') {
            window.location.href = PROFILEURL; //'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/myprofile'; // Navigate to profile settings
        } else {
            console.warn('Unknown option selected:', selectedValue);
        }
        this.menuOpen = false; // close dropdown after selection
    }
    logowhiteUrl = logowhite;
    userName ;
    contactid;
   
    handleModon(){
        const url = MODONURL; //'https://www.modon.com/';
        window.open(url,'_blank');
    }
    handleContactUs(){
        const url = CONTACTUSURL;//'https://www.modon.com/contact-us';
        window.open(url,'_blank');
    }
    handleButtonMethod(event) {
        this.isLoading = true;

        this.selectedSalesOrderId =event.target.dataset.id;
        let msg = 'ButtonName : ' + event.target.label + ' Id : ' + event.target.dataset.id;
        if(event.target.dataset.value === 'SOA'){
            getPDF({recId: this.selectedSalesOrderId})
                .then(result =>{
                    const byteCharacters = atob(result);
                    const byteNumbers = new Array(byteCharacters.length);
                    for (let i = 0; i < byteCharacters.length; i++) {
                        byteNumbers[i] = byteCharacters.charCodeAt(i);
                    }
                    const byteArray = new Uint8Array(byteNumbers);
                    const fileBlob = new Blob([byteArray], { type: 'application/pdf' });

                    // Create a download link
                    const link = document.createElement('a');
                    link.href = URL.createObjectURL(fileBlob);
                    link.target = '_blank';
                    //link.download = 'StatementOfAccount.pdf';
                    document.body.appendChild(link);
                    link.click();
                })
                .catch(error =>{
                })
        } else if(event.target.dataset.value === 'SPA'){
            getSPA({recordId : this.selectedSalesOrderId})
            .then(result => {
                if(result){
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: result
                       }
                    }, false
                );
                /*
                    let baseUrl = this.getBaseUrl();
                    const fileUrl = baseUrl+'sfc/servlet.shepherd/document/download/'+result;
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: fileUrl
                        }
                    }, false
                );*/

                }else{
                    this.handleToast('No SPA Found!','error');
                }
            })
            .catch(error => {
            })
        } else if(event.target.dataset.value === 'Floor Plan'){
             getFloorPlan({recordId : this.selectedSalesOrderId})
             .then(result => {
                if(result){
                  //  let baseUrl = this.getBaseUrl();
                   //  const fileUrl = baseUrl+'sfc/servlet.shepherd/document/download/'+result;
                     //const fileUrl = baseUrl+'sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId='
                     this[NavigationMixin.Navigate]({
                         type: 'standard__webPage',
                         attributes: {
                             url: result
                        }
                     }, false
                 );
                 }else{
                    this.handleToast('No Floor Plan Found!','error');
                 }
             })
             .catch(error => {
             })

                 /*   getDocument({ unitId: this.selectedSalesOrderId })
                    .then(result => {
                        if (result) {
                         
                    const response = fetch(url, {
                        method: 'GET',
                        credentials: 'include' // critical for portal auth cookies!
                    });
       
                    const base64Text = response.text();
                    const byteCharacters = atob(base64Text);
                    const byteArrays = [];
       
                    for (let i = 0; i < byteCharacters.length; i += 512) {
                        const slice = byteCharacters.slice(i, i + 512);
                        const byteNumbers = new Array(slice.length);
                        for (let j = 0; j < slice.length; j++) {
                            byteNumbers[j] = slice.charCodeAt(j);
                        }
                        byteArrays.push(new Uint8Array(byteNumbers));
                    }
       
                    const blob = new Blob(byteArrays, { type: 'application/pdf' }); // Or dynamic based on file type
       
                    // Trigger download
                    const link = document.createElement('a');
                    link.href = URL.createObjectURL(blob);
                    link.download = 'unit_file.pdf';
                    document.body.appendChild(link);
                    link.click();
                    link.remove();
                } else {
                        alert('No file available.');
                    }  
        })
                .catch(error => {
                }) */
           
        }
        this.isLoading = false;
    }

        handleManage(){
            window.location.href= MYPROPURL; //'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/my-properties';
        }
        getBaseUrl(){
            let baseUrl = 'https://'+location.host+'/';
            return baseUrl;
        }

        get formattedAmount() {
            return this.totalAmount ? this.totalAmount.toLocaleString('en-US') : '0.00';
        }


        handleHyperLink(event){
            const salesOrderId = event.detail.recordId;
            this.selectedSalesOrderId =salesOrderId;
            this.showRecordspage = true
            
        }

        logowhiteUrl = logowhite;
        instagramUrl = instagram;
        youtubeiconUrl = youtubeicon;
        linkediniconUrl = linkedinicon;
        facebookUrl = facebook;
        twitterxUrl = twitterx;
    
    
        handleContactUs(){
            const url = CONTACTUSURL; //'https://www.modon.com/contact-us';
            window.open(url,'_blank');
        }
        handleModon(){
            const url = MODONURL; //'https://www.modon.com/';
            window.open(url,'_blank');
        }
        handleinstagram(){
            const url = INSTAGRAMURL; //'https://www.instagram.com/modonproperties/#';
            window.open(url,'_blank');
        }
        handlelinkedin(){
            const url = LINKEDINURL; //'https://www.linkedin.com/company/modon/';
            window.open(url,'_blank');
        }

        homepage(){
            window.location.href= HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal';
            window.open(url,'_blank');
        }

        handleyoutube(){
            const url = YOUTUBEURL; //'https://www.youtube.com/channel/UCkF7MWvWZsty6udHa-ykATQ';
            window.open(url,'_blank');
        }
        handlefacebook(){
            const url = FACEBOOKURL; //'https://www.facebook.com/modonproperties';
            window.open(url,'_blank');
        }
        handletwitterx(){
            const url = TWITTERXURL; //'https://x.com/ModonProperties';
            window.open(url,'_blank');
        }
    
        handleMyProperties(event) {
            const recordId = event.target.dataset.id;
        
        // Find the record by its ID
        const selectedRecord = this.properties.find(record => record.Id === recordId);

        if (selectedRecord) {
            // Serialize and encode the record data to pass in the URL
            const encodedData = encodeURIComponent(JSON.stringify(selectedRecord));
        
            // Redirect with the encoded data in the URL
            window.location.href = MYPROPURL+`?property=${encodedData}`;
        }
    }

    handleSOA(event) {
        const recordId = event.target.dataset.id;

        // Redirect with the encoded data in the URL
        window.location.href = SOAPAGE+`?recordId=${recordId}`;
    }
    handleToast(message,variant) {
        this.template.querySelector('c-custom-toast').show(message, variant);

    }
}