import { LightningElement, api } from 'lwc';

export default class CustomToast extends LightningElement {
    visible = false;
    message = '';
    variant = 'info';
    iconName = 'utility:info';

    @api
    show(messageText, variant = 'info') {
        this.message = messageText;
        this.variant = variant;

        switch (variant) {
            case 'success':
                this.iconName = 'utility:success';
                break;
            case 'error':
                this.iconName = 'utility:error';
                break;
            case 'warning':
                this.iconName = 'utility:warning';
                break;
            default:
                this.iconName = 'utility:info';
        }

        this.visible = true;

        clearTimeout(this.timer);
        this.timer = setTimeout(() => {
            this.visible = false;
        }, 3000);
    }
get toastStyle() {
    switch (this.variant) {
        case 'success':
            return 'background-color: #34C759; color: white; box-shadow: 0 8px 24px rgba(52, 199, 89, 0.4);';
        case 'error':
            return 'background-color: #FF3B30; color: white; box-shadow: 0 8px 24px rgba(255, 59, 48, 0.4);';
        case 'warning':
            return 'background-color: #FFCC00; color: black; box-shadow: 0 8px 24px rgba(255, 204, 0, 0.3);';
        case 'info':
        default:
            return 'background-color: #007AFF; color: white; box-shadow: 0 8px 24px rgba(0, 122, 255, 0.4);';
    }
}

    
}