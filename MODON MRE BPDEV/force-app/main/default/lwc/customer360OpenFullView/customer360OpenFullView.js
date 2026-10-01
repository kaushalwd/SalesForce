/**
* Description: LWC for Customer 360 dashboard
* Author: Chaitanya N
* Name: Customer360Dashboard
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 25/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Customer360OpenFullView extends NavigationMixin(LightningElement) {
  @api recordId;

  // Quick Action entry point (recordId is ready here)
  @api async invoke() {
    if (!this.recordId) {
      // fallback safety
      // eslint-disable-next-line no-alert
      alert('Record Id not found. Please refresh and try again.');
      return;
    }

    const url = await this[NavigationMixin.GenerateUrl]({
      type: 'standard__component',
      attributes: {
        componentName: 'c__customer360Dashboard'
      },
      state: {
        c__recordId: this.recordId
      }
    });

    window.open(url, '_blank');
  }
}