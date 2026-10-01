import { LightningElement, track, wire, api } from 'lwc';
import homeIcon from '@salesforce/resourceUrl/homeblack';
import priceIcon from '@salesforce/resourceUrl/priceblack';
import paymentIcon from '@salesforce/resourceUrl/planblack';
import buildingicon from '@salesforce/resourceUrl/buildingicon';
import bedIcon from '@salesforce/resourceUrl/bed';
import bathIcon from '@salesforce/resourceUrl/washroom';
import sizeIcon from '@salesforce/resourceUrl/building';
import areaIcon from '@salesforce/resourceUrl/area'
import carIcon from '@salesforce/resourceUrl/Car';
import balcony from '@salesforce/resourceUrl/balcony';
import outdoor from '@salesforce/resourceUrl/outdoor';
import school from '@salesforce/resourceUrl/school';
import basketball from '@salesforce/resourceUrl/basketball';
import bike from '@salesforce/resourceUrl/bike';
import walk from '@salesforce/resourceUrl/walk';
import swim from '@salesforce/resourceUrl/swim';
import gym from '@salesforce/resourceUrl/gym';
import community from '@salesforce/resourceUrl/community';
import getImageUrls from '@salesforce/apex/CommunityHomeController.getImageUrls';
import makeCallout  from '@salesforce/apex/CommunityHomeController.makeCallout';

import modonLogo from '@salesforce/resourceUrl/modonLogoPlain';
import note from '@salesforce/resourceUrl/note';
import question from '@salesforce/resourceUrl/question';
import logowhite from '@salesforce/resourceUrl/logowhite';
import building from '@salesforce/resourceUrl/building';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import basePath from "@salesforce/community/basePath";
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';

import FORM_FACTOR from '@salesforce/client/formFactor';
import downloadIcon from '@salesforce/resourceUrl/building';
import manageIcon from '@salesforce/resourceUrl/building';
import { NavigationMixin } from 'lightning/navigation';

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
import PROPURL from '@salesforce/label/c.CP_MyPropertiesUrl';
import HOMEPAGE from '@salesforce/label/c.Customer_Portal_URL';

import { CurrentPageReference } from 'lightning/navigation';

export default class Propertydetailslisting extends NavigationMixin(LightningElement) {
    @track property=[]; 
    @api recordId;
    balcony =balcony;
    @track dpgurl;
    @track error;
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
    //backgroundStyle = `background-image: url(${communityBg});`;
    logoUrl = modonLogo;
    logowhiteUrl = logowhite;
    noteUrl = note;
    questionUrl = question;
    buildingUrl = building;
    heroSectionStyle = "background-image: url('images/prop2.png');";
    homeIcon = homeIcon;
    priceIcon = priceIcon;
    paymentIcon = paymentIcon;    
    get backgroundImageStyle() {
        return `background-image: url(${buildingicon}); 
                background-size: cover; 
                background-position: center; 
                height: 25%; 
                width: 100%; 
                z-index: 0; 
                border-radius: 0.5rem;`;
    }
    villaIconUrl = homeIcon;
    priceIconUrl =priceIcon;
    paymentPlanIconUrl = paymentIcon;
    bedImageUrl = bedIcon;
    areaImageUrl = areaIcon;
    bathImageUrl = bathIcon;
    sizeIconUrl = sizeIcon;
    carImageUrl = carIcon;
    balconyImageUrl = balcony;
    outdoor = outdoor;
    school = school;
    basketball = basketball;
    bike = bike;
    walk = walk;
    swim = swim;
    gym = gym;
    logowhiteUrl = logowhite;
    instagramUrl = instagram;
    youtubeiconUrl = youtubeicon;
    linkediniconUrl = linkedinicon;
    facebookUrl = facebook;
    twitterxUrl = twitterx;
    community = community;
    menuOpen = false;
    amenities = [
        { label: 'Community Center', icon: community },
        { label: 'Gym', icon: gym },
        { label: 'Swimming Pool', icon: swim },
        { label: 'Pedestrian Paths', icon: walk },
        { label: 'Cycle Routes', icon: bike },
        { label: 'Basketball Court', icon: basketball },
        { label: 'Schools', icon: school },
        { label: 'Outdoor Play Area', icon: outdoor }
      ];

      galleryImages = [];

      isMobile = false;
     isTablet = false;
     isDesktop = false;

    connectedCallback() {
        if (FORM_FACTOR === 'Large' || FORM_FACTOR === 'Medium') {
            this.isDesktop = true;
        } else {
            this.isMobile = true;
        }
        this.fetchDPGUrl();
    }
      toggleMenu() {
        this.menuOpen = !this.menuOpen;
    }
    fetchDPGUrl() {
        makeCallout({
            param1: this.property.ProjectName,
            param2: this.property.UnitName
        })
        .then(result => {
            if (result.dpgurl) {
                this.dpgurl = result.dpgurl;
            } else {
                this.error = result.error;
            }
        })
        .catch(err => {
            this.error = 'Callout failed: ' + (err.body?.message || err.message);
        });
    }
    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state.property) {
            // Decode and parse the recordData from the URL
            const decodedData = decodeURIComponent(currentPageReference.state.property);

                // Parse the JSON string into a JavaScript object
                const parsedData = JSON.parse(decodedData);

                // Convert the object into an array of key-value pairs
                this.property = parsedData;
                this.recordId= this.property.Id;
        }
    }

    @wire(getImageUrls, { unitId: '$recordId' })
    wiredImages({ error, data }) {
        if (data) {
            this.galleryImages = data;
        } else if (error) {
            console.error('Error fetching attachments:', error);
        }
    }
    // Example of handling interactions (like dragging in the gallery)
    handleGalleryDrag(event) {
        let mouseDown = false;
        let startX, scrollLeft;
        const slider = this.template.querySelector('.gallery');

        const startDragging = (e) => {
            mouseDown = true;
            startX = e.pageX - slider.offsetLeft;
            scrollLeft = slider.scrollLeft;
        }

        const stopDragging = () => {
            mouseDown = false;
        }

        const move = (e) => {
            e.preventDefault();
            if (!mouseDown) { return; }
            const x = e.pageX - slider.offsetLeft;
            const scroll = x - startX;
            slider.scrollLeft = scrollLeft - scroll;
        }

        // Add event listeners for drag behavior
        slider.addEventListener('mousemove', move, false);
        slider.addEventListener('mousedown', startDragging, false);
        slider.addEventListener('mouseup', stopDragging, false);
        slider.addEventListener('mouseleave', stopDragging, false);
    }

    handleMyProperties(event) {
        const recordId = event.target.dataset.id;
    
    // Find the record by its ID
    const selectedRecord = this.properties.find(record => record.Id === recordId);

    if (selectedRecord) {
        // Serialize and encode the record data to pass in the URL
        const encodedData = encodeURIComponent(JSON.stringify(selectedRecord));
    
        // Redirect with the encoded data in the URL
        window.location.href = PROPURL+`?property=${encodedData}`;
    }
}
handleToast(message,variant) {
    this.template.querySelector('c-custom-toast').show(message, variant);

}
  
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
handleMyProperties(){
    window.location.href= MYPROPURL; //'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/my-properties';
}
handleyoutube(){
    const url = YOUTUBEURL; //'https://www.youtube.com/channel/UCkF7MWvWZsty6udHa-ykATQ';
    window.open(url,'_blank');
}
handlefacebook(){
    const url = FACEBOOKURL; //'https://www.facebook.com/modonproperties';
    window.open(url,'_blank');
}
homepage(){
    const url = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/';
        window.open(url,'_blank');
}
handletwitterx(){
    const url = TWITTERXURL; //'https://x.com/ModonProperties';
    window.open(url,'_blank');
}

    handleManage(){
        window.location.href= PROPURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/my-properties';
    }
    getBaseUrl(){
        let baseUrl = 'https://'+location.host+'/';
        return baseUrl;
    }

    get formattedAmount() {
        return this.totalAmount ? this.totalAmount.toLocaleString('en-US') : '0.00';
    }

    handleMenuSelect(event) {
        const selectedValue =  event.target.dataset.id;// Correct way to access the selected item value

        if (selectedValue === 'logout') {
            const sitePrefix = basePath.replace("/", "");
            window.location.href = LOGOUTURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/secur/logout.jsp';
        } else if (selectedValue === 'profile') {
            window.location.href = PROFILEURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/myprofile'; // Navigate to profile settings
        } else if (selectedValue === 'home') {
            window.location.href = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/'; // Navigate to profile settings
        } else {
            console.warn('Unknown option selected:', selectedValue);
        }
    }
}