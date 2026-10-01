import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import fetchInitData from '@salesforce/apex/UnitBlockTimerController.getUnitDetails';
import UnitBlockDurationDefault from '@salesforce/label/c.UnitBlockDurationDefault';

export default class unitBlockTimerContainer extends NavigationMixin(LightningElement) {

    @api recordId;
    @track respWrap={};

    @track sentBlockUntil;
    @track sentBlockStart;
    graphicMode = true;
    loadingComplete = false;

    connectedCallback(){
        this.fetchInitDataCallout();
    }

    fetchInitDataCallout(){

        var requestWrap = {
           recordId: this.recordId
        };

        fetchInitData({requestWrapParam:JSON.stringify(requestWrap)}).then(result => {
            this.respWrap = result;

            this.sentBlockStart = new Date(result.createdDate);
            this.sentBlockUntil = new Date(this.sentBlockStart.getTime() + Number(UnitBlockDurationDefault)*60000);

            this.loadingComplete = true;

        }).catch(() => {});

    }

}