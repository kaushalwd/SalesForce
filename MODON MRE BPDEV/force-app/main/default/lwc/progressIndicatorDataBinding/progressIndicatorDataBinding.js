import { api,track, LightningElement } from 'lwc';

export default class ProgressIndicatorDataBinding extends LightningElement {
    
    @api status;
    @api stepId;
    @api isOpen;
    @api clientStep;
    @api loopTaskNo;
    @api stepLoop;
    @api stepSummary;
    @api passedGroup;
    @api currentGroup;
    @api renderStepName;
    @api isTimelineBadge;
    @api nextstep;
    @api taskId;
    @api renderCheckIcon;
    @api timelineBadgeData;
    ispassed = false;
    connectedCallback(){
    }
    
    get timelineBadgeCss(){
        if( !this.passedGroup && !this.ispassed){
            return 'timeline-badge selected';
        }
        else if( this.passedGroup && this.ispassed){
            return 'timeline-badge';
        }
        else {   
            this.ispassed=true;
            return 'timeline-badge before';   
        }
    }

    get stepNameCss(){
        if( this.nextstep ){
            return 'clientStepColor';
        }else if( !this.isOpen && !this.nextstep){
            return 'txtcolor';
        }else{
            return '';
        }
    }

    get showCheckIcon(){
        if( this.renderCheckIcon && !this.isOpen && this.status != null && this.status != '' ){
            return true;
        }else{
            return false;
        }
    }

    handleClick(){
        let response = { stepId : this.stepId, isOpen : this.isOpen };
        let customEvent = new CustomEvent( 'handleclick', { detail : response } );
        this.dispatchEvent( customEvent );
    }
}