import { LightningElement, api, wire } from 'lwc';
import getLimitUsage from '@salesforce/apex/LogLimitsController.getLimitUsage';

export default class LogLimits extends LightningElement {
    @api recordId;
    limitsWithStyle;
    error;

    @wire(getLimitUsage, { logId: '$recordId' })
    wiredLimits({ error, data }) {
        if (data) {
            this.limitsWithStyle = data
                .filter(limit => limit.current > 0)
                .map(limit => ({
                    ...limit,
                    percentage: Number(limit.percentage).toFixed(2),
                    progressBarClass: this.getProgressBarClass(limit.percentage),
                    style: `width: ${limit.percentage}%`
                }));
            this.error = undefined;
        } else if (error) {
            console.error('Error received:', error);
            this.error = error;
            this.limitsWithStyle = undefined;
        }
    }

    getProgressBarClass(percentage) {
        if (percentage <= 25) return 'slds-progress-bar__value progress-bar-green';
        if (percentage <= 75) return 'slds-progress-bar__value progress-bar-yellow';
        return 'slds-progress-bar__value progress-bar-red';
    }

    // Add a getter to help debug in the template
    get hasLimits() {
        return this.limitsWithStyle && this.limitsWithStyle.length > 0;
    }
}