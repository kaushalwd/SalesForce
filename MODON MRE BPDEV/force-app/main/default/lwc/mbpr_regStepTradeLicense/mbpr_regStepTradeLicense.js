/**
 * Component Name : mbpr_regStepTradeLicense
 * Description    : Step 2, Trade License Information.
 * Author         : Aurelix IT
 *
 * Parent is mbpr_registrationWorkspace. submitForm() emits 'success' ({id}),
 * 'error' and 'toast'.
 * The Trade License Number is entered on Step 1 (mbpr_regStepCompany) and only shown here, read-only.
 */
import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import regFormStyles from 'c/mbpr_regFormStyles';
import createRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.createRegistration';
import saveRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.saveRegistration';
import getRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.getRegistration';
import uploadFile from '@salesforce/apex/MBP_RegistrationGatewayController.uploadFile';
import getExistingFile from '@salesforce/apex/MBP_RegistrationGatewayController.getExistingFile';
import deleteFile from '@salesforce/apex/MBP_RegistrationGatewayController.deleteFile';
import getLegalStructurePicklist from '@salesforce/apex/MBP_RegistrationGatewayController.getLegalStructurePicklist';
import MBP_VatUndertakingCertificate from '@salesforce/resourceUrl/MBP_VatUndertakingCertificate';

const VALID_EXTENSIONS = ['pdf', 'jpg', 'jpeg'];
const MAX_FILE_SIZE = 2 * 1024 * 1024; // 2MB

export default class MbprRegStepTradeLicense extends NavigationMixin(LightningElement) {
    static stylesheets = [regFormStyles];

    @api objectApiName;
    @api recordId;
    @api sessionId;
    _ownSessionId;

    get session() {
        return this._ownSessionId || this.sessionId;
    }

    async saveRecord() {
        if (this.registrationRec.Id) {
            return await saveRegistration({ registrationRec: this.registrationRec, sessionId: this.session });
        }
        const opened = await createRegistration({ registrationRec: this.registrationRec });
        this._ownSessionId = opened.sessionId;
        return opened.registrationId;
    }
    @api registrationStatus;
    @api mode;

    @track registrationRec = {};
    registrationObj = {};
    initialRegistrationRec = {};
    fieldErrors = {};

    legalStructureOptions = [];
    vatCertificateOptions = [
        { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
        { label: 'VAT Undertaking Certificate', value: 'VAT Undertaking Certificate' }
    ];

    isBusy = false;

    /* BP-038 - the workspace's lock (status not Draft) or this step's own
       status check; templates keep binding disabled={isDisabled}. */
    @api locked = false;
    statusLocked = false;

    get isDisabled() {
        return Boolean(this.locked) || this.statusLocked;
    }
    registrationTypeFromParent;

    vatUploadLabel = 'VAT Registration Certificate';
    admReraLabel = 'ADM/RERA Copy';
    isShowAdmReraUpload = false;
    showVatRegNumber = false;
    showDummyVatLink = false;

    isTradeLicenseUploaded = false;
    tradeLicenseFileName;
    tradeLicenseContentVersionId = '';
    tradeLicenseContentDocumentId = '';

    isMoaUploaded = false;
    moaFileName;
    moaContentVersionId = '';
    moaContentDocumentId = '';

    isAdmReraUploaded = false;
    admReraFileName;
    admReraContentVersionId = '';
    admReraContentDocumentId = '';

    isVatUploaded = false;
    showVatFileUpload = false;
    vatFileName;
    vatContentVersionId = '';
    vatContentDocumentId = '';

    _focusFirstError = false;

    // ------------------------------------------------------------------
    // Lifecycle / prefill (legacy connectedCallback parity)
    // ------------------------------------------------------------------

    async connectedCallback() {
        this.isBusy = true;
        try {
            if (!this.recordId) {
                this.registrationRec.Status__c = 'Draft';
            } else {
                this.registrationObj = await getRegistration({ registrationId: this.recordId, sessionId: this.session });
                this.registrationTypeFromParent = this.registrationObj.Type_of_Registration__c?.trim()?.toLowerCase();
                const registrationState = this.registrationObj.State__c?.trim()?.toLowerCase();

                if (this.registrationTypeFromParent === 'uae broker') {
                    if (registrationState === 'abudhabi' || registrationState === 'abu dhabi') {
                        this.admReraLabel = 'ADM Copy';
                    } else if (registrationState === 'dubai') {
                        this.admReraLabel = 'RERA Copy';
                    } else {
                        this.admReraLabel = 'ADM/RERA Copy';
                    }
                    this.isShowAdmReraUpload = true;
                }

                if (this.registrationObj.Status__c !== 'Draft') {
                    this.statusLocked = true;
                }
            }
            this.registrationRec = { ...this.registrationRec, ...this.registrationObj };
            await this.loadLegalStructureOptions();

            this.showVatRegNumber = this.registrationRec.VAT_Certificate_Type__c === 'VAT Registration Certificate';
            this.tradeLicenseFileName = `TradeLicense_${this.registrationRec.Name}`;
            this.moaFileName = `MOA_${this.registrationRec.Name}`;
            await this.loadExistingFiles();
            this.initialRegistrationRec = { ...this.registrationRec };
        } catch (error) {
            this.notify('Failed to load registration data: ' + (error.body?.message || 'Unknown error'), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    renderedCallback() {
        if (this._focusFirstError) {
            this._focusFirstError = false;
            const firstInvalid = this.template.querySelector('.regf-field--error .regf-field__control');
            if (firstInvalid) {
                firstInvalid.focus();
            }
        }
    }

    async loadLegalStructureOptions() {
        try {
            const res = await getLegalStructurePicklist();
            this.legalStructureOptions = (res || []).map((r) => ({ label: r.label, value: r.value }));
        } catch (e) {
            this.legalStructureOptions = [];
        }
    }

    async loadExistingFiles() {
        this.isBusy = true;
        try {
            const tradeLicenseResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'TradeLicense_',
                registrationId: this.recordId,
                sessionId: this.session
            });
            if (tradeLicenseResult && tradeLicenseResult.file) {
                this.isTradeLicenseUploaded = true;
                this.tradeLicenseFileName = tradeLicenseResult.file.Title;
                this.tradeLicenseContentVersionId = tradeLicenseResult.file.Id;
                this.tradeLicenseContentDocumentId = tradeLicenseResult.file.ContentDocumentId;
            } else {
                this.isTradeLicenseUploaded = false;
                this.tradeLicenseFileName = 'TradeLicense';
                this.tradeLicenseContentVersionId = '';
                this.tradeLicenseContentDocumentId = '';
            }

            const moaResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'MOA / Local Service Agent Appointment.',
                registrationId: this.recordId,
                sessionId: this.session
            });
            if (moaResult && moaResult.file) {
                this.isMoaUploaded = true;
                this.moaFileName = moaResult.file.Title;
                this.moaContentVersionId = moaResult.file.Id;
                this.moaContentDocumentId = moaResult.file.ContentDocumentId;
            } else {
                this.isMoaUploaded = false;
                this.moaFileName = 'MOA / Local Service Agent Appointment.';
                this.moaContentVersionId = '';
                this.moaContentDocumentId = '';
            }

            const admResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'ADM_RERA_',
                registrationId: this.recordId,
                sessionId: this.session
            });
            if (admResult && admResult.file) {
                this.isAdmReraUploaded = true;
                this.admReraFileName = admResult.file.Title;
                this.admReraContentVersionId = admResult.file.Id;
                this.admReraContentDocumentId = admResult.file.ContentDocumentId;
            } else {
                this.isAdmReraUploaded = false;
                this.admReraFileName = `ADM_RERA_${this.registrationRec.Name}`;
                this.admReraContentVersionId = '';
                this.admReraContentDocumentId = '';
            }

            const vatResult = await getExistingFile({
                recordId: this.recordId,
                fileNamePrefix: 'VAT_',
                registrationId: this.recordId,
                sessionId: this.session
            });
            if (vatResult && vatResult.file) {
                this.isVatUploaded = true;
                this.vatFileName = vatResult.file.Title;
                this.vatContentVersionId = vatResult.file.Id;
                this.vatContentDocumentId = vatResult.file.ContentDocumentId;
                this.showVatFileUpload = true;
            } else {
                this.isVatUploaded = false;
                this.vatFileName = `VAT_${this.registrationRec.Name}`;
                this.vatContentVersionId = '';
                this.vatContentDocumentId = '';
                this.showVatFileUpload = false;
            }
        } catch (error) {
            this.notify('Failed to load existing files: ' + error.message, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    // ------------------------------------------------------------------
    // Template getters
    // ------------------------------------------------------------------

    get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted' && !this.isDisabled;
    }

    get selectFieldClass() {
        return 'regf-field regf-field--required';
    }

    get uploadCellClass() {
        return this.isDisabled
            ? 'regf-upload regf-upload--required regf-upload--disabled'
            : 'regf-upload regf-upload--required';
    }

    get licensingAuthorityValue() {
        return this.registrationRec.Licensing_Authority__c || '';
    }
    get issuanceDateValue() {
        return this.registrationRec.Issuance_Date__c || '';
    }
    get companyNameValue() {
        return this.registrationRec.Company_Name_as_per_Trade_License__c || '';
    }
    get expiryDateValue() {
        return this.registrationRec.Expiry_Date__c || '';
    }
    get tradeLicenseNumberValue() {
        return this.registrationRec.Trade_License_Number__c || '';
    }
    get vatNumberValue() {
        return this.registrationRec.UAE_VAT_Registration_Number__c || '';
    }

    get licensingAuthorityError() {
        return this.fieldErrors.Licensing_Authority__c || '';
    }
    get issuanceDateError() {
        return this.fieldErrors.Issuance_Date__c || '';
    }
    get companyNameError() {
        return this.fieldErrors.Company_Name_as_per_Trade_License__c || '';
    }
    get expiryDateError() {
        return this.fieldErrors.Expiry_Date__c || '';
    }
    get tradeLicenseNumberError() {
        return this.fieldErrors.Trade_License_Number__c || '';
    }
    get vatNumberError() {
        return this.fieldErrors.UAE_VAT_Registration_Number__c || '';
    }

    get licensingAuthorityClass() {
        return this.buildFieldClass('Licensing_Authority__c');
    }
    get issuanceDateClass() {
        return this.buildFieldClass('Issuance_Date__c');
    }
    get companyNameClass() {
        return this.buildFieldClass('Company_Name_as_per_Trade_License__c');
    }
    get expiryDateClass() {
        return this.buildFieldClass('Expiry_Date__c');
    }
    get tradeLicenseNumberClass() {
        // Read-only on this step, so no required marker.
        return this.fieldErrors.Trade_License_Number__c ? 'regf-field regf-field--error' : 'regf-field';
    }
    get vatNumberClass() {
        return this.buildFieldClass('UAE_VAT_Registration_Number__c');
    }

    get legalStructureSelectOptions() {
        return this.buildSelectOptions(this.legalStructureOptions, this.registrationRec.LegalStructure__c);
    }

    get vatTypeSelectOptions() {
        return this.buildSelectOptions(this.vatCertificateOptions, this.registrationRec.VAT_Certificate_Type__c);
    }

    // ------------------------------------------------------------------
    // Field handlers (legacy handleFieldChange / handleFieldChange1 /
    // handleNumericInput / VAT handlers parity)
    // ------------------------------------------------------------------

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        if (fieldName === 'Issuance_Date__c' && value) {
            const selectedDate = new Date(value);
            const currentDate = new Date();
            currentDate.setHours(0, 0, 0, 0);
            if (selectedDate > currentDate) {
                this.notify('Issuance Date cannot be a future date.', 'error');
                this.registrationRec = { ...this.registrationRec, [fieldName]: null };
                event.target.value = '';
                return;
            }
        }

        if (fieldName === 'Expiry_Date__c' && value) {
            const selectedDate = new Date(value);
            const currentDate = new Date();
            currentDate.setHours(0, 0, 0, 0);
            if (selectedDate < currentDate) {
                this.notify('Expiry Date cannot be a Past date.', 'error');
                this.registrationRec = { ...this.registrationRec, [fieldName]: null };
                event.target.value = '';
                return;
            }
        }

        this.registrationRec = { ...this.registrationRec, [fieldName]: value };
        this.clearError(fieldName);
    }

    handleVatCertificateTypeChange(event) {
        const value = event.target.value;

        // Clear VAT Number if the selected type is NOT "VAT Registration Certificate"
        if (value !== 'VAT Registration Certificate') {
            this.registrationRec = { ...this.registrationRec, UAE_VAT_Registration_Number__c: '' };
            this.clearError('UAE_VAT_Registration_Number__c');
        }

        this.registrationRec = { ...this.registrationRec, VAT_Certificate_Type__c: value };

        this.showVatRegNumber = value === 'VAT Registration Certificate';
        this.showDummyVatLink = value === 'VAT Undertaking Certificate';
        this.vatUploadLabel =
            value === 'VAT Undertaking Certificate' ? 'VAT Undertaking Certificate' : 'VAT Registration Certificate';
    }

    handleVatNumberChange(event) {
        this.registrationRec = { ...this.registrationRec, UAE_VAT_Registration_Number__c: event.target.value };
        this.clearError('UAE_VAT_Registration_Number__c');
    }

    downloadVAT() {
        const link = document.createElement('a');
        link.href = MBP_VatUndertakingCertificate;
        link.download = 'VAT_Undertaking_Certificate.docx';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    // ------------------------------------------------------------------
    // Uploads (four flows, legacy parity)
    // ------------------------------------------------------------------

    validateSelectedFile(event) {
        const input = event.target;
        const file = input.files && input.files[0];
        // Reset so re-picking the same file re-fires the change event.
        input.value = '';
        if (!file) {
            return null;
        }
        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!VALID_EXTENSIONS.includes(fileExtension)) {
            this.notify('Only .pdf and .jpg files are allowed.', 'error');
            return null;
        }
        if (file.size > MAX_FILE_SIZE) {
            this.notify('File size exceeds 2MB limit. Please upload a smaller file.', 'error');
            return null;
        }
        return { file, fileExtension };
    }

    readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    async uploadToRecord(fileName, base64Data) {
        if (this.recordId) {
            await uploadFile({ recordId: this.recordId, fileName, base64Data, registrationId: this.recordId, sessionId: this.session });
        } else {
            const recordId = await this.saveRecord();
            this.registrationRec.Id = recordId;
            this.recordId = recordId;
            await uploadFile({ recordId, fileName, base64Data, registrationId: recordId, sessionId: this.session });
        }
    }

    async handleTradeLicenseChange(event) {
        const picked = this.validateSelectedFile(event);
        if (!picked) {
            return;
        }
        this.isBusy = true;
        this.isTradeLicenseUploaded = true;
        try {
            const base64Data = await this.readAsBase64(picked.file);
            // Legacy stored the file as " TradeLicense.<ext>" with a leading space; kept.
            await this.uploadToRecord(` TradeLicense.${picked.fileExtension}`, base64Data);
            await this.loadExistingFiles();
            this.notify('Trade License Document uploaded successfully!', 'success');
        } catch (error) {
            this.isTradeLicenseUploaded = false;
            this.notify('Failed to process Trade License file: ' + (error.message || 'Unknown error'), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleMoaChange(event) {
        const picked = this.validateSelectedFile(event);
        if (!picked) {
            return;
        }
        this.isBusy = true;
        this.isMoaUploaded = true;
        try {
            const base64Data = await this.readAsBase64(picked.file);
            await this.uploadToRecord(`MOA / Local Service Agent Appointment.${picked.fileExtension}`, base64Data);
            await this.loadExistingFiles();
            this.notify('MOA Document uploaded successfully!', 'success');
        } catch (error) {
            this.isMoaUploaded = false;
            this.notify('Failed to process MOA file: ' + (error.message || 'Unknown error'), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleAdmReraUpload(event) {
        const picked = this.validateSelectedFile(event);
        if (!picked) {
            return;
        }
        this.isBusy = true;
        try {
            const base64Data = await this.readAsBase64(picked.file);
            this.admReraFileName = picked.file.name;
            await this.uploadToRecord(`ADM_RERA_Copy.${picked.fileExtension}`, base64Data);
            this.isAdmReraUploaded = true;
            await this.loadExistingFiles();
            this.notify('ADM/RERA Copy uploaded successfully!', 'success');
        } catch (error) {
            this.isAdmReraUploaded = false;
            this.notify('Failed to process ADM/RERA file: ' + (error.message || 'Unknown error'), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleVatUploadChange(event) {
        const picked = this.validateSelectedFile(event);
        if (!picked) {
            return;
        }
        this.isBusy = true;
        this.isVatUploaded = false;
        try {
            const base64Data = await this.readAsBase64(picked.file);
            const certificateType = this.registrationRec.VAT_Certificate_Type__c;
            let savedFileName = 'VAT Registration Certificate.' + picked.fileExtension;
            if (certificateType === 'VAT Registration Certificate') {
                savedFileName = 'VAT_Registration_Certificate.' + picked.fileExtension;
            } else if (certificateType === 'VAT Undertaking Certificate') {
                savedFileName = 'VAT Undertaking Certificate.' + picked.fileExtension;
            }
            this.vatFileName = savedFileName;
            this.showVatFileUpload = true;
            await this.uploadToRecord(savedFileName, base64Data);
            await this.loadExistingFiles();
            this.notify('VAT Registration Certificate uploaded successfully!', 'success');
        } catch (error) {
            this.showVatFileUpload = false;
            this.notify('Failed to process VAT file: ' + (error.message || 'Unknown error'), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    // ------------------------------------------------------------------
    // Deletes (gated on showDeleteIcon in the template)
    // ------------------------------------------------------------------

    async handleRemoveTradeLicense() {
        this.isBusy = true;
        try {
            if (this.tradeLicenseContentDocumentId) {
                await deleteFile({ contentDocumentId: this.tradeLicenseContentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.notify(`File ${this.tradeLicenseFileName} deleted`, 'success');
            }
            this.isTradeLicenseUploaded = false;
            this.tradeLicenseFileName = 'TradeLicense';
            this.tradeLicenseContentVersionId = '';
            this.tradeLicenseContentDocumentId = '';
        } catch (error) {
            this.notify(`Failed to delete ${this.tradeLicenseFileName}: ${error.body?.message}`, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleRemoveMoa() {
        this.isBusy = true;
        try {
            if (this.moaContentDocumentId) {
                await deleteFile({ contentDocumentId: this.moaContentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.notify(`File ${this.moaFileName} deleted`, 'success');
            }
            this.isMoaUploaded = false;
            this.moaFileName = 'MOA / Local Service Agent Appointment.';
            this.moaContentVersionId = '';
            this.moaContentDocumentId = '';
        } catch (error) {
            this.notify(`Failed to delete ${this.moaFileName}: ${error.body?.message}`, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleRemoveAdmRera() {
        this.isBusy = true;
        try {
            if (this.admReraContentDocumentId) {
                await deleteFile({ contentDocumentId: this.admReraContentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.notify(`File ${this.admReraFileName} deleted`, 'success');
            }
            this.isAdmReraUploaded = false;
            this.admReraFileName = `ADM/RERA${this.registrationRec?.Name || ''}`;
            this.admReraContentVersionId = '';
            this.admReraContentDocumentId = '';
        } catch (error) {
            this.notify(`Failed to delete ${this.admReraFileName}: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleRemoveVat() {
        this.isBusy = true;
        try {
            if (this.vatContentDocumentId) {
                await deleteFile({ contentDocumentId: this.vatContentDocumentId, registrationId: this.recordId, sessionId: this.session });
                this.notify(`File ${this.vatFileName} deleted`, 'success');
            }
            this.isVatUploaded = false;
            this.showVatFileUpload = false;
            this.vatFileName = 'VAT_Registration_Certificate';
            this.vatContentVersionId = '';
            this.vatContentDocumentId = '';
        } catch (error) {
            this.notify(`Failed to delete ${this.vatFileName}: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    // ------------------------------------------------------------------
    // Previews (legacy shepherd rendition URL flow)
    // ------------------------------------------------------------------

    navigateToFilePreview(contentVersionId) {
        const baseUrl = window.location.origin + '/';
        const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${contentVersionId}`;
        this[NavigationMixin.Navigate](
            {
                type: 'standard__webPage',
                attributes: { url: fileUrl }
            },
            false
        );
    }

    openTradeLicensePreviewPopup() {
        try {
            if (!this.tradeLicenseContentVersionId) {
                this.notify('No Trade License file available to preview.', 'error');
                return;
            }
            this.navigateToFilePreview(this.tradeLicenseContentVersionId);
        } catch (error) {
            this.notify('Failed to preview Trade License file: ' + (error.message || 'Unknown error'), 'error');
        }
    }

    openMoaPreviewPopup() {
        try {
            if (!this.moaContentVersionId) {
                this.notify('No MOA file available to preview.', 'error');
                return;
            }
            this.navigateToFilePreview(this.moaContentVersionId);
        } catch (error) {
            this.notify('Failed to preview MOA file: ' + (error.message || 'Unknown error'), 'error');
        }
    }

    openAdmReraPreviewPopup() {
        try {
            if (!this.admReraContentVersionId) {
                this.notify('No ADM/RERA file available to preview.', 'error');
                return;
            }
            this.navigateToFilePreview(this.admReraContentVersionId);
        } catch (error) {
            this.notify('Failed to preview ADM/RERA file: ' + (error.message || 'Unknown error'), 'error');
        }
    }

    openVatPreviewPopup() {
        try {
            if (!this.vatContentVersionId) {
                this.notify('No VAT Registration Certificate file available to preview.', 'error');
                return;
            }
            this.navigateToFilePreview(this.vatContentVersionId);
        } catch (error) {
            this.notify('Failed to preview VAT Registration Certificate: ' + (error.message || 'Unknown error'), 'error');
        }
    }

    // ------------------------------------------------------------------
    // Submit (legacy submitForm parity: two validation stages, change
    // detection, upsert, success/toast/error events)
    // ------------------------------------------------------------------

    @api async submitForm() {
        // No step veil here: the workspace shows the full-screen loader for the
        // whole of Next, and a second spinner underneath it read as a defect.
        try {
            // Stage 1 mirrors the legacy reportValidity()/checkValidity() sweep
            // over lightning-inputs; disabled inputs are exempt from constraint
            // validation, so it is skipped when the form is read-only.
            if (!this.isDisabled) {
                const stageOneErrors = {};
                const rec = this.registrationRec;
                if (!rec.Licensing_Authority__c) {
                    stageOneErrors.Licensing_Authority__c = 'Please enter Licensing Authority';
                }
                if (!rec.Issuance_Date__c) {
                    stageOneErrors.Issuance_Date__c = 'Please select Issuance Date';
                }
                if (!rec.Company_Name_as_per_Trade_License__c) {
                    stageOneErrors.Company_Name_as_per_Trade_License__c =
                        'Please enter Company Name as per Trade License';
                }
                if (!rec.Expiry_Date__c) {
                    stageOneErrors.Expiry_Date__c = 'Please select Expiry Date';
                }
                // Entered and checked on Step 1; this step can only report it missing.
                if (!rec.Trade_License_Number__c) {
                    stageOneErrors.Trade_License_Number__c =
                        'Please enter the Trade License Number in Step 1, Company Information.';
                }
                if (this.showVatRegNumber && !rec.UAE_VAT_Registration_Number__c) {
                    stageOneErrors.UAE_VAT_Registration_Number__c = 'Complete this field.';
                }

                if (Object.keys(stageOneErrors).length > 0) {
                    this.fieldErrors = { ...this.fieldErrors, ...stageOneErrors };
                    this._focusFirstError = true;
                    this.notify('Please fix the errors before proceeding.', 'error');
                    return undefined;
                }
            }

            // Stage 2: legacy requiredFields sweep + required document checks.
            const requiredFields = [
                { field: 'Licensing_Authority__c', label: 'Licensing Authority' },
                { field: 'Issuance_Date__c', label: 'Issuance Date' },
                { field: 'Company_Name_as_per_Trade_License__c', label: 'Company Name as per Trade License' },
                { field: 'Expiry_Date__c', label: 'Expiry Date' },
                { field: 'Trade_License_Number__c', label: 'Trade License Number' }
            ];
            const missingFields = [];
            const stageTwoErrors = {};
            requiredFields.forEach(({ field, label }) => {
                if (!this.registrationRec[field]) {
                    missingFields.push(label);
                    stageTwoErrors[field] = 'This field is required';
                }
            });
            if (!this.isTradeLicenseUploaded) {
                missingFields.push('Trade License Document');
            }
            if (!this.isMoaUploaded) {
                missingFields.push('MOA / Local Service Agent Appointment');
            }
            if (!this.isVatUploaded) {
                missingFields.push('VAT Registration Certificate');
            }

            if (missingFields.length > 0) {
                if (Object.keys(stageTwoErrors).length > 0) {
                    this.fieldErrors = { ...this.fieldErrors, ...stageTwoErrors };
                    this._focusFirstError = true;
                }
                this.notify(`Please fill in the following required fields: ${missingFields.join(', ')}`, 'error');
                return undefined;
            }

            let hasFieldChanges = false;
            for (const key in this.registrationRec) {
                if (this.registrationRec[key] !== this.initialRegistrationRec[key]) {
                    hasFieldChanges = true;
                    break;
                }
            }

            if (!hasFieldChanges) {
                this.dispatchEvent(
                    new CustomEvent('success', {
                        detail: { id: this.registrationRec.Id },
                        bubbles: true,
                        composed: true
                    })
                );
                this.notify('No changes were made to the Trade License information.', 'info');
                return undefined;
            }

            const recordId = await this.saveRecord();
            this.registrationRec.Id = recordId;
            this.recordId = recordId;
            this.dispatchEvent(
                new CustomEvent('success', {
                    detail: { id: recordId, sessionId: this._ownSessionId },
                    bubbles: true,
                    composed: true
                })
            );
            this.notify('Trade License information saved.', 'success');
            return recordId;
        } catch (error) {
            this.dispatchEvent(
                new CustomEvent('error', {
                    detail: { message: error.body?.message || 'Failed to save Trade License information.' },
                    bubbles: true,
                    composed: true
                })
            );
        }
        return undefined;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    buildFieldClass(field) {
        let cls = 'regf-field regf-field--required';
        if (this.fieldErrors[field]) {
            cls += ' regf-field--error';
        }
        return cls;
    }

    buildSelectOptions(options, currentValue) {
        const current = currentValue || '';
        return [
            { key: 'placeholder', label: 'Select an Option', value: '', selected: current === '' },
            ...(options || []).map((o) => ({
                key: o.value,
                label: o.label,
                value: o.value,
                selected: o.value === current
            }))
        ];
    }

    setError(field, message) {
        const next = { ...this.fieldErrors };
        if (message) {
            next[field] = message;
        } else {
            delete next[field];
        }
        this.fieldErrors = next;
    }

    clearError(field) {
        if (this.fieldErrors[field]) {
            this.setError(field, '');
        }
    }

    notify(message, variant) {
        this.dispatchEvent(
            new CustomEvent('toast', {
                detail: { message, variant },
                bubbles: true,
                composed: true
            })
        );
    }
}