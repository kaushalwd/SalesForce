import { LightningElement, wire, api, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import validateSalesTeamChecklistFatima from '@salesforce/apex/DocumentChecklistController.validateSalesTeamChecklistFatima';
import sendToNextTeam from '@salesforce/apex/DocumentChecklistController.sendToNextTeam';
import getSalesOrderDetails from '@salesforce/apex/DocumentChecklistController.getSalesOrderDetails';
/* import submitChecklist from '@salesforce/apex/DocumentChecklistController.submitChecklist'; */
import getLatestChecklistMap from '@salesforce/apex/DocumentChecklistController.getLatestChecklistMap';
import getDocumentChecklistMetadata from '@salesforce/apex/DocumentChecklistController.getDocumentChecklistMetadata';
import getChecklistAccess from '@salesforce/apex/DocumentChecklistController.getChecklistAccess';

export default class SalesChecklist extends NavigationMixin(LightningElement) {
    customerName;
    salesperson;
    projectName;
    salesOrderName;
    unitNumber;
    submissionDate;
    subStatus;
    team;
    isApproval;
    isDirectSales = false;
    isReservationFormRequired = false;
    remarksMap = {};
    checklistSections = [];
    rejectionReasonMap = {};

    @track rejectionoptions = [];
    @track value = '';
    @api recordId;
    @track showRemarksModal = false;
    @track popupRemarks = '';

    get options() {
        return [
            { label: 'Approved', value: 'Approved' },
            { label: 'Rejected', value: 'Rejected' }
        ];
    }

    get canAccessCurrentTeam() {
        if (this.isOverrideUser) {
            return false;
        }
        const userId = this.currentUserId;
        const team = this.team;

        if (!team || !userId) return true;

        switch (team) {
            case 'Sales':
                return !(userId === this.salesAssociateId);
            case 'Sales Operation':
                return !(userId === this.soAssociateId);
            case 'Finance':
                return !(userId === this.financeAssociateId);
            case 'Customer Management':
                return !(userId === this.cmAssociateId);
            default:
                return true;
        }
    }


    get isRejectDisabled() {
        return ((this.team === 'Sales' && this.team !== 'Sales Operation') || this.team === 'Unknown');
    }

    get sendButtonLabel() {
        const nextTeam = this.computeNextTeam(this.team);
        return this.subStatus === 'Pending with Sales' ? `Completed` : nextTeam ? `Send to ${nextTeam}` : 'Approve';
    }

    get isSendDisabled() {
        return (this.team === 'Unknown');
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state?.c__recordId;
            if (this.recordId) {
                this.loadSalesOrder();
            }
        }
    }


    async loadSalesOrder() {
        try {
            this.isLoading = true;
            const so = await getSalesOrderDetails({ recordId: this.recordId });

            this.isDirectSales = so.Sales_Type__c === 'Direct';
            const reservationPicklist = so.Unit__r?.Phase__r?.Is_Reservation_Form_Required__c;
            this.isReservationFormRequired = reservationPicklist === 'Yes';

            if (!so) {
                this.showToast('Error', 'No Sales Order found for this record Id.', 'error');
                return;
            }
            this.customerName = so.CustomerAccount__r.Name;
            this.salesperson = so.Owner.Name;
            this.projectName = so.ProjectName__c;
            this.salesOrderName = so.Name;
            this.unitNumber = so.Unit__r.Name;
            this.team = so.Sub_Status__c ? this.getTeamFromSubStatus(so.Sub_Status__c) : null;
            this.downPaymentStatus = so.Down_Payment_Status__c;
            this.subStatus = so.Sub_Status__c;
            this.admFeesStatus = so.ADM_Fees_and_Dari__c;
            this.chequesCollected = so.Cheques_collected_No_of_cheques__c || '0';
            this.chequesReceived = so.Cheques_Rcvd_from_Sales_No_of_cheques__c || '0';
            this.accessInfo = await getChecklistAccess({ salesOrderId: this.recordId });
            this.isOverrideUser = this.accessInfo.isOverride;
            this.currentUserId = this.accessInfo.userId;
            this.salesAssociateId = this.accessInfo.salesAssociate;
            this.soAssociateId = this.accessInfo.soAssociate;
            this.financeAssociateId = this.accessInfo.financeAssociate;
            this.cmAssociateId = this.accessInfo.cmAssociate;

            const metaChecklist = await getDocumentChecklistMetadata({
                residentStatus: so.UAE_Resident_Status__c,
                isReservationRequired: reservationPicklist === 'Yes',
                salesType: so.Sales_Type__c
            });

            this.fullChecklist = this.buildChecklistSections(metaChecklist);

            if (true) {
//['Sales', 'Sales Operation', 'Customer Management', 'Finance', 'Unknown'].includes(this.team)
                try {
                    const [autoChecklist, latestResponse] = await Promise.all([
                        validateSalesTeamChecklistFatima({ salesOrderId: this.recordId }),
                        getLatestChecklistMap({ salesOrderId: this.recordId })
                    ]);
                    const latestChecklist = latestResponse?.teamChecklistMap || {};
                    this.checklistSections = this.applyAutoChecklistWithLatest(this.fullChecklist, autoChecklist, latestChecklist);
                } catch (error) {
                    const errorMsg = error?.body?.message || error?.message || JSON.stringify(error);
                    console.error('Failed to load auto/persisted checklist:', errorMsg);
                    this.showToast('Error', 'Checklist failed to load: ' + errorMsg, 'error');
                    this.checklistSections = await this.generateChecklistWithKeys(this.fullChecklist);
                }

            } else {
                this.checklistSections = await this.generateChecklistWithKeys(this.fullChecklist);
            }
        } catch (error) {
            const errMsg = this.extractErrorMessage(error);
            console.error('Approval failed:', errMsg, error);
            this.showToast('Error', errMsg, 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    buildChecklistSections(metaChecklist) {
        const sections = [];

        for (const dept in metaChecklist) {
            const items = metaChecklist[dept].map((item, index) => {
                let rejectionOptions = Array.isArray(item.rejectionReasons)
                    ? item.rejectionReasons.map(r => ({ label: r, value: r }))
                    : [];

                let optionsList = (item.allowedStatuses || ['Approved', 'Rejected'])
                    .map(sts => ({ label: sts, value: sts }));

                if (dept === 'Exceptional Approval') {
                    optionsList = [
                        { label: 'Approved', value: 'Approved' },
                        { label: 'Rejected', value: 'Rejected' },
                        { label: 'None', value: 'None' }
                    ];
                }

                return {
                    no: index + 1,
                    label: item.label,
                    itemKey: `${dept}__${item.id}__${item.label}`,
                    approvalSts: '',
                    rejectionReason: '',
                    remark: '',
                    approvedBy: '',
                    readOnly: !this.isEditableForCurrentTeam(dept),
                    disabledRejection: !this.isEditableForCurrentTeam(dept),
                    rejectionOptions,
                    options: optionsList,
                    error: {}
                };
            });

            if (items.length > 0) {
                sections.push({ title: dept, items });
            }
        }

        return sections;
    }


    extractErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && typeof error.body.message === 'string') return error.body.message;
        if (error.message) return error.message;
        try {
            return JSON.stringify(error);
        } catch (e) {
            return 'Unexpected error';
        }
    }

    getTeamFromSubStatus(subStatus) {
        const map = {
            'Pending with Sales': 'Sales',
            'Pending With Sales Team': 'Sales',
            'Pending With Sales Operation': 'Sales Operation',
            'Under Finance Verification': 'Finance',
            'Pending with CM': 'Customer Management'
        };
        return map[subStatus] || 'Unknown';
    }

    getTeamFromSection(sectionTitle) {
        return sectionTitle;
    }

    isEditableForCurrentTeam(sectionTitle) {

        const editableStatuses = [
            'Pending With Sales Team',
            'Under Finance Verification',
            'Pending with CM',
            'Pending With Sales Operation'
        ];


        if (!editableStatuses.includes(this.subStatus)) {
            return false;
        }

        if (sectionTitle === this.team) {
            if (this.isOverrideUser) return true;
            const userId = this.currentUserId;

            if (sectionTitle === 'Sales' && userId === this.salesAssociateId) return true;
            if (sectionTitle === 'Sales Operation' && userId === this.soAssociateId) return true;
            if (sectionTitle === 'Finance' && userId === this.financeAssociateId) return true;
            if (sectionTitle === 'Customer Management' && userId === this.cmAssociateId) return true;

            return false;

        }

    }



    computeNextTeam(currentTeam) {
        const order = {
            'Sales': 'Sales Operation',
            'Sales Operation': 'Finance',
            'Finance': 'Customer Management'
        };
        return order[currentTeam] || null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'SalesOrder__c',
                actionName: 'view'
            }
        });
    }

    handleChange(event) {
        const itemId = event.target.dataset.itemid;
        const fieldName = event.target.name;
        const value = event.detail.value;

        this.checklistSections = this.checklistSections.map(section => {
            const updatedItems = section.items.map(item => {
                if (item.itemKey === itemId) {
                    const updatedItem = { ...item };

                    if (fieldName === 'status') {
                        updatedItem.approvalSts = value;
                        updatedItem.rejectionReason = value === 'Approved' ? '' : updatedItem.rejectionReason;
                        updatedItem.disabledRejection = value === 'Approved';
                    }

                    if (fieldName === 'rejectionReason') {
                        updatedItem.rejectionReason = value;
                    }

                    return updatedItem;
                }

                return item;
            });

            return { ...section, items: updatedItems };
        });
    }

    handleRemarkChange(event) {
        const itemId = event.target.dataset.itemid;
        const value = event.target.value;

        this.checklistSections = this.checklistSections.map(section => {
            const updatedItems = section.items.map(item =>
                item.itemKey === itemId ? { ...item, remark: value } : item
            );
            return { ...section, items: updatedItems };
        });
    }

    async submitRemarks() {

        if (!this.popupRemarks || this.popupRemarks.trim() === '') {
            this.showToast('Error', 'Please enter remarks before submitting.', 'error');
            return;
        }


        const valid = this.validateChecklist(true);
        if (!valid) {
            this.showToast('Error', 'Please complete all required checklist items before submitting.', 'error');
            return;
        }

        try {
            await this.handleSendToNextTeam(true, 'Sales');
            this.showToast('Success', 'Remarks updated successfully.', 'success');
            this.showRemarksModal = false;
            this.handleBack();
        } catch (err) {
            this.showToast('Error', 'Failed to submit remarks.', 'error');
            console.error(err);
        }
    }


    handlePopupRemarksChange(event) {
        this.popupRemarks = event.target.value;
    }

    closeRemarksModal() {
        this.showRemarksModal = false;
        this.popupRemarks = '';
    }

    async handleApprove() {

        const currentTeam = this.team;

        if (this.subStatus === 'Pending With Sales Team' && currentTeam === 'Sales') {
            this.showRemarksModal = true;
            return;
        }
        try {
            const valid = this.validateChecklist(true);
            if (!valid) return;
            await this.handleSendToNextTeam(true, currentTeam);
            this.handleBack();
        } catch (error) {
            const errMsg = this.extractErrorMessage(error);
            console.error('Approval failed:', errMsg, error);
            this.showToast('Error', errMsg, 'error');
        }

    }

    async handleReject() {
        const valid = this.validateChecklist(false);
        if (valid) {
            try {
                await this.handleSendToNextTeam(false, this.team);
                this.handleBack();

            } catch (error) {
                const errMsg = this.extractErrorMessage(error);
                console.error('Approval failed:', errMsg, error);
                this.showToast('Error', errMsg, 'error');
            }
        }
    }

    async handleSendToNextTeam(isApproval = true, currentTeam) {
        const items = this.checklistSections.flatMap(section =>
            section.items.map(item => ({
                label: item.label,
                approvalSts: item.approvalSts,
                remark: item.remark,
                rejectionReason: item.rejectionReason,
                team: section.title
            }))
        );



        try {
            const response = await sendToNextTeam({
                salesOrderId: this.recordId,
                items,
                popupRemark: this.popupRemarks,
                isApproval
            });

            this.showToast('Success', isApproval ? 'Checklist sent.' : 'Checklist rejected.', 'success');
        } catch (error) {
            const errMsg = this.extractErrorMessage(error);
            console.error('sendToNextTeam failed:', errMsg);
            this.showToast('Error', errMsg, 'error');
        }
    }





    /*     async handleSaveDraft() {
            try {
                await this.submitChecklist(null);
                this.showToast('Draft Saved', 'Checklist has been saved as draft.', 'success');
                this.handleBack();
            } catch (error) {
                this.showToast('Error', 'Failed to save draft: ' + (error.message || error), 'error');
            }
        } */

    /* async submitChecklist(isApproval) {
        const items = this.checklistSections.flatMap(section => section.items.map(item => ({
            label: item.label,
            approvalSts: item.approvalSts,
            remark: item.remark,
            rejectionReason: item.rejectionReason,
            team: section.title
        })));

        try {
            await submitChecklist({ salesOrderId: this.recordId, isApproval, items });

            let message = 'Checklist submitted.';
            if (isApproval === true) message = 'Checklist approved successfully.';
            else if (isApproval === false) message = 'Checklist rejected successfully.';
            else message = 'Checklist saved as draft.';

            this.showToast('Success', message, 'success');
            this.checklistSections = await this.generateChecklistWithKeys(this.fullChecklist);

        } catch (error) {
            const errMsg = this.extractErrorMessage(error);
            console.error('Approval failed:', errMsg, error);
            this.showToast('Error', errMsg, 'error');
        }

    }
 */
    async generateChecklistWithKeys(sections) {
        const updatedSections = [];
        let latestChecklistMap = {};

        try {
            const response = await getLatestChecklistMap({ salesOrderId: this.recordId });
            latestChecklistMap = response.teamChecklistMap || {};
        } catch (error) {
            console.error('Failed to fetch latest checklist map:', error);
        }

        let serialCounter = 1;

        for (const section of sections) {
            const teamKey = this.getTeamFromSection(section.title);
            const teamData = latestChecklistMap[teamKey] || {};

            const newItems = section.items.map(item => {
                const latest = teamData[item.label] || {};
                let approvalSts = latest.approvalSts ?? item.approvalSts ?? '';
                let allowedStatuses = latest.allowedStatuses ?? item.allowedStatuses ?? ['Approved', 'Rejected'];
                let optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));
                let remark = latest.remark ?? item.remark ?? '';
                let rejectionReason = latest.rejectionReason ?? item.rejectionReason ?? '';
                if (section.title === 'Exceptional Approval') {
                    optionsList = [
                        { label: 'Approved', value: 'Approved' },
                        { label: 'Rejected', value: 'Rejected' },
                        { label: 'None', value: 'None' }
                    ];
                }

                if ((item.label || '').toLowerCase().includes('cheques collected')) {
                    const value = this.chequesCollected;
                    approvalSts = approvalSts || (value && value !== '0' ? 'Collected' : 'Not Collected');
                    remark = remark || value || '';
                    allowedStatuses = ['Collected', 'Not Collected'];
                    optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));

                }

                if ((item.label || '').toLowerCase().includes('cheques received from sales team')) {
                    const value = this.chequesReceived;
                    approvalSts = approvalSts || (value && value !== '0' ? 'Received' : 'Not Received');
                    remark = remark || value || '';
                    allowedStatuses = ['Received', 'Not Received'];
                    optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));

                }

                return {
                    ...item,
                    no: serialCounter++,
                    itemKey: `${section.title}__${item.id}__${item.label}`,
                    approvalSts,
                    rejectionReason: latest.rejectionReason ?? '',
                    remark: latest.remark ?? '',
                    approvedBy: latest.approvedBy ?? '',
                    readOnly: section.title === 'Sales' || !this.isEditableForCurrentTeam(section.title),
                    disabledRejection: section.title === 'Sales'
                        ? true
                        : (latest.approvalSts === 'Approved' || !this.isEditableForCurrentTeam(section.title)),
                    options: optionsList,
                    allowedStatuses,
                    error: {}
                };
            });

            updatedSections.push({ ...section, items: newItems });
        }

        return updatedSections;
    }


    applyAutoChecklistWithLatest(fullChecklist, autoChecklist, latestChecklist) {

        return fullChecklist.map(section => {
            const updatedItems = section.items.map(item => {
                const autoDto = autoChecklist[item.label];
                const latestDto = latestChecklist[section.title]?.[item.label];



                let approvalSts =
                    (autoDto?.approvalSts && autoDto.approvalSts !== '')
                        ? autoDto.approvalSts
                        : latestDto?.approvalSts || item.approvalSts || '';

                let remark =
                    (autoDto?.remark && autoDto.remark !== '')
                        ? autoDto.remark
                        : latestDto?.remark || item.remark || '';

                let rejectionReason = latestDto?.rejectionReason ?? item.rejectionReason ?? '';

                let allowedStatuses =
                    (autoDto?.allowedStatuses?.length ? autoDto.allowedStatuses
                        : latestDto?.allowedStatuses?.length ? latestDto.allowedStatuses
                            : item.allowedStatuses) || ['Approved', 'Rejected'];

                let optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));


                if (section.title === 'Exceptional Approval') {
                    optionsList = [
                        { label: 'Approved', value: 'Approved' },
                        { label: 'Rejected', value: 'Rejected' },
                        { label: 'None', value: 'None' }
                    ];
                }


                const labelLower = (item.label || '').toLowerCase();


                if (labelLower.includes('cheques collected')) {
                    const value = this.chequesCollected;
                    approvalSts = approvalSts || (value && value !== '0' ? 'Collected' : 'Not Collected');
                    remark = remark || value || '';
                    allowedStatuses = ['Collected', 'Not Collected'];
                    optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));
                }


                if (labelLower.includes('cheques received from sales team')) {
                    const value = this.chequesReceived;
                    approvalSts = approvalSts || (value && value !== '0' ? 'Received' : 'Not Received');
                    remark = remark || value || '';
                    allowedStatuses = ['Received', 'Not Received'];
                    optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));
                }


                if (labelLower === 'compliance approved') {
                    approvalSts = approvalSts || 'Not Approved';
                    allowedStatuses = ['Approved', 'Not Approved'];
                    optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));
                }


                if (labelLower === 'adm cleared' || labelLower === 'down payment cleared') {
                    approvalSts = approvalSts || 'Not Paid';
                    allowedStatuses = ['Generated', 'Collected', 'Partially Paid', 'Paid', 'Cancelled', 'Reversed'];
                    optionsList = allowedStatuses.map(sts => ({ label: sts, value: sts }));
                    remark = remark || (approvalSts === 'Paid' ? '' : 'ADM + Dari Fees not Cleared');
                }


                if (item.label === 'Mode of Payment' && autoChecklist[item.label]) {
                    allowedStatuses = autoChecklist[item.label].allowedStatuses || [];
                    optionsList = allowedStatuses.map(v => ({ label: v, value: v }));
                    approvalSts = autoChecklist[item.label].approvalSts || approvalSts;
                }


                let forceReadOnly = false;
                if (
                    (section.title === 'Customer Management' && labelLower === 'compliance approved') ||
                    (section.title === 'Sales Operation' && labelLower === 'compliance approved') ||
                    (section.title === 'Finance' && labelLower === 'down payment cleared') ||
                    (section.title === 'Finance' && labelLower === 'adm cleared') ||
                    (section.title === 'Sales' && labelLower === 'mode of payment')
                ) {
                    forceReadOnly = true;
                }


                return {
                    ...item,
                    approvalSts,
                    remark,
                    rejectionReason,
                    approvedBy: latestDto?.approvedBy || item.approvedBy || '',
                    allowedStatuses,
                    options: optionsList,
                    readOnly: forceReadOnly
                        ? true
                        : section.title === 'Sales' || !this.isEditableForCurrentTeam(section.title),
                    disabledRejection:
                        ((item.label === 'Compliance Approved' && section.title === 'Customer Management'))
                            ? true
                            : section.title === 'Sales'
                                ? true
                                : (approvalSts === 'Approved' || !this.isEditableForCurrentTeam(section.title))
                };
            });
//|| (item.label === 'Compliance Approved' && section.title === 'Sales Operation')
            return { ...section, items: updatedItems };
        });
    }




    validateChecklist(isApprovalAction) {
        const failures = [];
        let hasRejected = false;

        const currentTeam = this.team ? this.team.trim() : '';

        const updated = this.checklistSections.map(section => {
            const isCurrentTeamSection = section.title === currentTeam;

            const newItems = section.items.map(item => {
                const next = { ...item, error: { ...(item.error || {}) } };
                next.error.approvalSts = '';
                next.error.remark = '';

                const label = (item.label || '').toLowerCase();
                const isCollectedRow = label.includes('cheques collected');
                const isReceivedRow = label.includes('cheques received from sales team');
                const isExceptional = section.title === 'Exceptional Approval';
                const isCompliance = label.toLowerCase() === ('compliance approved');
                const isADMorDPPaid =
                    label.includes('down payment cleared') ||
                    label.includes('adm cleared');
                const isADMorDPStatus =
                    label.includes('down payment status') ||
                    label.includes('adm fees + dari payment status');
                const isMOP = label.includes('mode of payment');

                if (!isCurrentTeamSection) {
                    return next;
                }

                const remarkNum = (next.remark ?? '').toString().trim();
                let ok = true;
                if (isApprovalAction) {
                    if (isCollectedRow || isReceivedRow) {
                        ok = next.approvalSts !== '';
                        if (!ok) {
                            next.error.approvalSts = 'Select an Option.';
                            failures.push({ label: next.label, need: 'Non-null Value' });
                        }
                    } else if (isExceptional) {
                        ok = ['Approved', 'None'].includes(next.approvalSts);
                        if (!ok) {
                            next.error.approvalSts = 'Select Approved or None.';
                            failures.push({ label: next.label, need: 'Approved/None' });
                        }
                    } else if (isADMorDPPaid) {
                        ok = next.approvalSts === 'Paid';

                        if (!ok) {
                            next.error.approvalSts = 'Status should be "Paid".';
                            failures.push({ label: next.label, need: 'Paid' });
                        }
                    } else if (isADMorDPStatus) {
                        ok = (next.approvalSts != '') || (next.approvalSts == '');
                        if (!ok) {
                            next.error.approvalSts = 'Status should be Set.';
                            failures.push({ label: next.label, need: 'Non-Null Value' });
                        }
                    } else if (isCompliance) {
                        ok = next.approvalSts === 'Submitted' || next.approvalSts === 'Approved';
                        if (!ok) {

                            failures.push({ label: next.label, need: 'Kindly Check the "Compliance Status" before proceed!' });
                        }
                    } else if (isMOP) {
                        ok = (next.approvalSts != '');
                        if (!ok) {

                            failures.push({ label: next.label, need: 'Kindly Check the "Mode Of Payment" before proceed!' });
                        }
                    } else {
                        ok = ['Approved', 'Uploaded', 'Paid', 'Sent', 'Submitted', 'Yes','Not Required','Direct Debit'].includes(next.approvalSts);
                        if (!ok) {
                            next.error.approvalSts = 'Please Approve to Send Checklist.';
                            failures.push({ label: next.label, need: 'Approved' });
                        }
                    }
                } else {
                    const status = (next.approvalSts || '').trim();

                    /*  const isFailedCheque =
                         (isCollectedRow && status === 'Not Collected') ||
                         (isReceivedRow && status === 'Not Received' );*/

                    const isUnpaidADMorDP =
                        isADMorDPPaid && status !== 'Paid' && status !== '';

                    /*   const isInvalidDPMode =
                          isADMorDPStatus && (status === '' || status === 'None');
                   */
                    const isNonCompliant =
                        isCompliance && (status !== 'Submitted' || status !== 'Approved');
                    /* 
                        const isDocMissing =
                            label.includes('customer documents') && ['Not Uploaded', 'Partial'].includes(status);
                    
                        const isFormPending =
                            (label.includes('kyc') || label.includes('reservation form')) && status === 'Pending';
                    
                        const isNoPDC =
                            label.includes('pdc') && (status === 'No' || status === ''); */

                    const isExplicitReject = status === 'Rejected';

                    if (isUnpaidADMorDP || isNonCompliant ||
                        isExplicitReject) { /* isFailedCheque || */
                        hasRejected = true;
                    }
                }


                return next;
            });

            return { ...section, items: newItems };
        });

        this.checklistSections = updated;

        if (isApprovalAction) {
            if (failures.length) {
                const preview = failures.slice(0, 3).map(f => `• ${f.label} → ${f.need}`).join('\n');
                const extra = failures.length > 3 ? `\n(+${failures.length - 3} more)` : '';
                this.showToast(
                    'Checklist incomplete',
                    `Please resolve the following before sending:\n${preview}${extra}`,
                    'error'
                );
                return false;
            }
            console.debug('[validateChecklist] All enabled rows valid for approval');
            return true;
        } else {
            if (!hasRejected) {
                this.showToast(
                    'Reject failed',
                    'At least one checklist item must be marked as "Rejected" to proceed.',
                    'error'
                );
                return false;
            }
            return true;
        }
    }



}