/**
* Description: LWC for a timer used to show time remaining for blocked Units
* Author: Yazan Saeed
* Name: unitBlockTimer
* Created Date: 06th February 2024
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 06th Feb 2024     Yazan Saeed         V1.0                Initial Version
**************************************************************************************************
*/

import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import UnitBlockDurationWarning from '@salesforce/label/c.UnitBlockDurationWarning';

export default class unitBlockTimer extends NavigationMixin(LightningElement) {

    @api recordId;
    @track respWrap={};

    @api receivedblockuntil //DateTime of the time the Unit will be blocked until
    @api receiveblockstart //DateTime of the time the Unit block started
    @api graphicMode = false;  //Variable to control display - Timer as digits or graphic

    timerReference;
    timer = "00:00:00";
    @track showTimesUpModal = false;
    ringValue = Number(100);
    @track timerWarning = true;
    variant = 'expired';

    connectedCallback(){
        this.setTimer();
    }

    //Get the Unit unblock time, subtract the current time, call secondToHms to convert to proper format
    setTimer(){

        const blockedUntilTime = new Date(this.receivedblockuntil);
        const blockedFromTime  = new Date(this.receiveblockstart);

        if(blockedUntilTime >= new Date().getTime()){
            this.timerRef = window.setInterval(()=>{
                
                const secsDiff      = blockedUntilTime.getTime() - new Date().getTime();
                const secsFromStart = blockedUntilTime.getTime() - blockedFromTime.getTime();                
                if (this.graphicMode){
                    this.ringValue = Math.floor(Number(secsDiff/secsFromStart) * 100);
                }
                this.timer = this.secondToHms(Math.floor(secsDiff/1000));
                /*if(secsDiff <= Number(UnitBlockDurationWarning) * 60000 && this.timerWarning == false){
                    this.timerWarning = true;
                    this.variant = 'expired';
                }*/
                if(secsDiff >= Number(UnitBlockDurationWarning) * 60000 && this.timerWarning == true){
                    this.variant = 'base-autocomplete';
                    this.timerWarning = false;
                }else if(secsDiff <= Number(UnitBlockDurationWarning) * 60000 && this.timerWarning == false){
                    this.timerWarning = true;
                    this.variant = 'expired';
                }
                if(secsDiff <= 0){
                    this.timesUpHandler();
                }
            }, 1000)
        }
    }
    
    //Convert the Convert the seconds difference into Hours:Minutes:Seconds (Hms)
    secondToHms(secondsDiff){

        secondsDiff  = Number(secondsDiff)

        const hour   = Math.floor(secondsDiff / 3600);
        const minute = Math.floor(secondsDiff % 3600 / 60);
        const second = Math.floor(secondsDiff % 3600 % 60);

        const hourDisplay   = Math.floor(hour   / 10) > 0 ? hour + (":") : "0" + hour + ":";
        const minuteDisplay = Math.floor(minute / 10) > 0 ? minute + (":") : "0" + minute + ":";
        const secondDisplay = Math.floor(second / 10) > 0 ? second : "0" + second;
        return hourDisplay + minuteDisplay + secondDisplay; 
    }
    
    //Clear the interval, show the popup
    timesUpHandler(){
        window.clearInterval(this.timerRef);
        this.timer = "00:00:00";
        this.ringValue = 0;
        this.showTimesUpModal = true;
    }

    //Handler for actions that come from HTML
    actionHandler(event){

        const {label} = event.target;
        if(label === "OK"){
            this.closeModalHandler();
        }
    }

    //Close the popup
    closeModalHandler(){
        this.showTimesUpModal = false;
    }

}