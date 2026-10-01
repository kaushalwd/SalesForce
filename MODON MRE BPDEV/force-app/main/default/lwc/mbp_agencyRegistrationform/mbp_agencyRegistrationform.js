import { LightningElement } from 'lwc';
import {loadScript,loadStyle} from 'lightning/platformResourceLoader';
import ModonImages from "@salesforce/resourceUrl/modonImages";
import Bootstrap from "@salesforce/resourceUrl/Bootstrap";

export default class AgencyRegistrationform extends LightningElement {

logo = ModonImages+"/modonImages/brand-logo-black.png";
logowhite = ModonImages+"/modonImages/brand-logo-white.png";
backgroundImage = ModonImages+"/modonImages/bg-theme-pic.png";

get backgroundStyle() {
        return `background-image: url('${this.backgroundImage}');background-size: cover;background-repeat: no-repeat;background-position: center;`;
    }
connectedCallback() {
    Promise.all([
        loadStyle(this, Bootstrap)
    ])
    .catch(error => {
        console.error('Error loading styles', error);
    });
    }
}