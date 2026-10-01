import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import upsertRegistrationRecord from '@salesforce/apex/MBP_RegistrationFormController.upsertRegistrationRecord';
import getRegistrationById from '@salesforce/apex/MBP_RegistrationFormController.getRegistrationById';
import uploadFile from '@salesforce/apex/MBP_RegistrationFormController.uploadFile';
import VATLetterTemplate from '@salesforce/resourceUrl/VATLetterTemplate';
import getExistingFile from '@salesforce/apex/MBP_RegistrationFormController.getExistingFile';
import deleteFile from '@salesforce/apex/MBP_RegistrationFormController.deleteFile';
import validateDuplicateTradeLicenseNumber from '@salesforce/apex/MBP_RegistrationFormController.validateDuplicateTradeLicenseNumber';


export default class TradeLicenseForm2 extends NavigationMixin(LightningElement) {
    @track activeSections = ['Trade License Information', 'Document Uploads'];
    @track registrationObj = {};
    @track registrationRec = {};
    @api recordId;
    @track vatUploadLabel = 'VAT Registration Certificate';
    vatLetterTemplate = VATLetterTemplate;
    @track isDisabled = false;
    @track isTradeLicenseUploaded = false;
    @track tradeLicenseFileName;
    @track tradeLicenseContentVersionId = '';
    @track tradeLicenseContentDocumentId = '';
    @track tradeLicenseData = null;
    @track isMoaUploaded = false;
    @track moaFileName;
    @track moaContentVersionId = '';
    @track moaContentDocumentId = '';
    @track moaData = null;
    @track initialRegistrationRec = {};
    @track isLoading = false;
 @track vatCertificateType = '';
 @track vatCertificateOptions = [
   
    { label: 'VAT Registration Certificate', value: 'VAT Registration Certificate' },
     
    { label: 'VAT Undertaking Certificate', value: 'VAT Undertaking Certificate' }
];

  @api mode;
    @api registrationStatus;
  
    
admReraData;
@track isVatUploaded = false;
@track showVatFileUpload = false;
@track vatFileName;
@track vatContentVersionId;
@track admReraLabel = 'ADM/RERA Copy';
@track registrationObj;
@track registrationTypeFromParent;
@track isDisabled = false;
@track vatContentDocumentId;
@track isAdmReraUploaded = false;
@track admReraFileName;
@track admReraContentVersionId='';
@track admReraContentDocumentId;
@track showDummyVatLink = false;
    
    @track showVatRegNumber = false;
    @track showGenerateVatUndertaking = false;
    @track uaeVatNumber = '';
    async connectedCallback() {
        this.isLoading = true;
        try{
            if (!this.recordId) {
                this.registrationRec.Status__c = 'Draft';
            } else {
               this.registrationObj = await getRegistrationById({ recordId: this.recordId });

this.registrationTypeFromParent = this.registrationObj.Type_of_Registration__c?.trim()?.toLowerCase();
const registrationState = this.registrationObj.State__c?.trim()?.toLowerCase();
 

   



if (this.registrationTypeFromParent === 'uae broker') {
    if (registrationState === 'abudhabi' || registrationState === 'abu dhabi') {
        this.admReraLabel = 'ADM Copy';
        this.isShowAdmReraUpload = true;
    } else if (registrationState === 'dubai') {
        this.admReraLabel = 'RERA Copy';
        this.isShowAdmReraUpload = true;
    }
    else {
        this.admReraLabel = 'ADM/RERA Copy';
        this.isShowAdmReraUpload = true;
    }
}

              
                if (this.registrationObj.Status__c !== 'Draft') {
                    this.isDisabled = true;
                }
            }
            this.registrationRec = { ...this.registrationRec, ...this.registrationObj };
         this.showVatRegNumber = this.registrationRec.VAT_Certificate_Type__c === 'VAT Registration Certificate';
            this.tradeLicenseFileName = `TradeLicense_${this.registrationRec.Name}`;
            this.moaFileName = `MOA_${this.registrationRec.Name}`;
            await this.loadExistingFiles();
            this.initialRegistrationRec = { ...this.registrationRec};
        }catch(error) {
            console.error('Error loading registration data:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load registration data: ' + (error.body?.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
        
    }


handleVatCertificateTypeChange(event) {
    const value = event.detail.value;

    // Clear VAT Number if the selected type is NOT "VAT Registration Certificate"
    if (value !== 'VAT Registration Certificate') {
        this.registrationRec = {
            ...this.registrationRec,
            UAE_VAT_Registration_Number__c: ''
        };
    }

    // Update only the VAT Certificate Type
    this.registrationRec = {
        ...this.registrationRec,
        VAT_Certificate_Type__c: value
    };

    // Update UI flags
    this.showVatRegNumber = value === 'VAT Registration Certificate';
    this.showDummyVatLink = value === 'VAT Undertaking Certificate';

    this.vatUploadLabel = value === 'VAT Undertaking Certificate' 
        ? 'VAT Undertaking Certificate' 
        : 'VAT Registration Certificate';
}

 async downloadVAT() {

        let a = document.createElement("a");
        a.href = VATLetterTemplate;
        a.download = 'VAT Letter Template.pdf';
        a.click();
    }

handleVatNumberChange(event) {
    this.registrationRec = {
        ...this.registrationRec,
        UAE_VAT_Registration_Number__c: event.detail.value
    };
}




handleFieldChange1(event) {
    const fieldName = event.target.name;
    const value = event.detail?.value ?? event.target.value;

    this.registrationRec = { ...this.registrationRec, [fieldName]: value };

   if (fieldName === 'Trade_License_Number__c') {
    const tradeInput = this.template.querySelector('[data-id="TradeLicense"]');

    if (value && value.trim().length > 0) {
        validateDuplicateTradeLicenseNumber({ licenseNumber: value.trim() })
            .then((result) => {
                let message = '';

                if (result === 'REGISTRATION_AND_ACCOUNT') {
                    message = 'There is already a Registration and an Account with this Trade License Number.';
                } else if (result === 'REGISTRATION') {
                    message = 'There is already a Registration with this Trade License Number.';
                } else if (result === 'ACCOUNT') {
                    message = 'There is already an Account with this Trade License Number.';
                }

                tradeInput.setCustomValidity(message);
                tradeInput.reportValidity();
            })
            .catch((error) => {
                tradeInput.setCustomValidity('Error checking Trade License. Try again.');
                tradeInput.reportValidity();
                console.error('Apex error:', error);
            });
    } else {
        tradeInput.setCustomValidity('');
        tradeInput.reportValidity();
    }
}


    // Include any other field-specific logic here as needed...
}

    handleNumericInput(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        // Allow only digits
        if (value && !/^[a-zA-Z0-9]*$/.test(value)) {
            // Reset the field value
            this.registrationRec = { ...this.registrationRec, [fieldName]: '' };
            // Update the UI
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.value = '';
                inputField.setCustomValidity('Please enter only letters and numbers');
                inputField.reportValidity();
            }
        } else {
            this.registrationRec = { ...this.registrationRec, [fieldName]: value };
            // Clear any custom validity error
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.setCustomValidity('');
                inputField.reportValidity();
            }
        }
    }
 get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted';
    }
   
       handleFieldChange(event) {
    const fieldName = event.target.name;
    const value = event.detail?.value ?? event.target.value;

    // Validate Issuance Date to prevent future dates
    if (fieldName === 'Issuance_Date__c' && value) {
        const selectedDate = new Date(value);
        const currentDate = new Date();
        currentDate.setHours(0, 0, 0, 0); // Normalize to compare dates only

        if (selectedDate > currentDate) {
            console.error('Validation failed: Issuance Date is in the future.');

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Issuance Date cannot be a future date.',
                    variant: 'error'
                })
            );

            // Reset the field value
            this.registrationRec = { ...this.registrationRec, [fieldName]: null };

            // Update the UI
            const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
            if (inputField) {
                inputField.value = null;
            } else {
                console.warn('Input field not found in template for:', fieldName);
            }

            return;
        }
    }
        if (fieldName === 'Expiry_Date__c' && value) {
            const selectedDate = new Date(value);
            const currentDate = new Date();
            currentDate.setHours(0, 0, 0, 0); // Normalize to compare dates only
            if (selectedDate < currentDate) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Expiry Date cannot be a Past date.',
                        variant: 'error'
                    })
                );
                // Reset the field value
                this.registrationRec = { ...this.registrationRec, [fieldName]: null };
                // Update the UI
                const inputField = this.template.querySelector(`lightning-input[name="${fieldName}"]`);
                if (inputField) {
                    inputField.value = null;
                }
                return;
            }
        }
        this.registrationRec = { ...this.registrationRec, [fieldName]: value };
       
    }

  async loadExistingFiles() {
    this.isLoading = true;
    try {
        // Load Trade License file
        const tradeLicenseResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'TradeLicense_'
        });

        if (tradeLicenseResult && tradeLicenseResult.file) {
            this.isTradeLicenseUploaded = true;
            this.tradeLicenseFileName = tradeLicenseResult.file.Title;
            this.tradeLicenseContentVersionId = tradeLicenseResult.file.Id;
            this.tradeLicenseContentDocumentId = tradeLicenseResult.file.ContentDocumentId;
        } else {
            this.isTradeLicenseUploaded = false;
            this.tradeLicenseFileName = `TradeLicense`;
            this.tradeLicenseContentVersionId = '';
            this.tradeLicenseContentDocumentId = '';
        }

        // Load MOA file
        const moaResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'MOA / Local Service Agent Appointment.'
        });

        if (moaResult && moaResult.file) {
            this.isMoaUploaded = true;
            this.moaFileName = moaResult.file.Title;
            this.moaContentVersionId = moaResult.file.Id;
            this.moaContentDocumentId = moaResult.file.ContentDocumentId;
        } else {
            this.isMoaUploaded = false;
            this.moaFileName = `MOA / Local Service Agent Appointment.`;
            this.moaContentVersionId = '';
            this.moaContentDocumentId = '';
        }

        // Load ADM/RERA file
        const admResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'ADM_RERA_'
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

        // Load VAT Certificate file
        const vatResult = await getExistingFile({
            recordId: this.recordId,
            fileNamePrefix: 'VAT_'
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
        console.error('Error loading existing files:', JSON.stringify(error));
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to load existing files: ' + error.message,
                variant: 'error'
            })
        );
    } finally {
        this.isLoading = false;
    }
}


    async handleVatUploadChange(event) {
    this.isLoading = true;

    const file = event.target.files[0];
    if (!file) {
        this.isLoading = false;
        return;
    }
this.isVatUploaded = false;
this.showVatFileUpload=true;
    const validExtensions = ['pdf', 'jpg', 'jpeg'];
    const fileExtension = file.name.split('.').pop().toLowerCase();

    if (!validExtensions.includes(fileExtension)) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Only .pdf and .jpg files are allowed.',
                variant: 'error'
            })
        );
        this.isLoading = false;
        return;
    }

    const maxSize = 5242880; // 5MB
    if (file.size > maxSize) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'File size exceeds 5MB limit. Please upload a smaller file.',
                variant: 'error'
            })
        );
        this.isLoading = false;
        return;
    }

    try {
        const reader = new FileReader();
        const base64Data = await new Promise((resolve, reject) => {
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
        let certificateType = this.registrationRec.VAT_Certificate_Type__c;
        let savedFileName = 'VAT Registration Certificate.' + fileExtension;

        if (certificateType === 'VAT Registration Certificate') {
            savedFileName = 'VAT_Registration_Certificate.' + fileExtension;
        } else if (certificateType === 'VAT Undertaking Certificate') {
            savedFileName = 'VAT Undertaking Certificate.' + fileExtension;
        }

       this.vatFileName = savedFileName; // For display
       this.vatData = {
            filename: savedFileName,
            base64: base64Data
        };
        if (this.recordId) {
            await uploadFile({
                recordId: this.recordId,
                fileName: this.vatData.filename,
                base64Data: this.vatData.base64
            });
        } else {
            const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
            this.registrationRec.Id = recordId;

            await uploadFile({
                recordId: this.registrationRec.Id,
                fileName: this.vatData.filename,
                base64Data: this.vatData.base64
            });
        }

        this.showVatFileUpload = true;
        await this.loadExistingFiles();

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'VAT Registration Certificate uploaded successfully!',
                variant: 'success'
            })
        );

    } catch (error) {
        this.showVatFileUpload = false;
        this.vatData = null;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to process VAT file: ' + (error.message || 'Unknown error'),
                variant: 'error'
            })
        );
    } finally {
        this.isLoading = false;
    }
}

async handleAdmReraUpload(event) {
    this.isLoading = true;

    const file = event.target.files[0];
    if (!file) {
        this.isLoading = false;
        return;
    }

    const validExtensions = ['pdf', 'jpg', 'jpeg'];
    const fileExtension = file.name.split('.').pop().toLowerCase();

    if (!validExtensions.includes(fileExtension)) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Only .pdf and .jpg files are allowed.',
                variant: 'error'
            })
        );
        this.isLoading = false;
        return;
    }

    const maxSize = 5242880; // 5MB
    if (file.size > maxSize) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'File size exceeds 5MB limit. Please upload a smaller file.',
                variant: 'error'
            })
        );
        this.isLoading = false;
        return;
    }

    try {
        const reader = new FileReader();
        const base64Data = await new Promise((resolve, reject) => {
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });

        
        this.admReraFileName = file.name;
        this.admReraData = {
            filename: `ADM_RERA_Copy.${fileExtension}`,
            base64: base64Data
        };

        if (this.recordId) {
            await uploadFile({
                recordId: this.recordId,
                fileName: this.admReraData.filename,
                base64Data: this.admReraData.base64
            });
        } else {
            const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
            this.registrationRec.Id = recordId;

            await uploadFile({
                recordId: this.registrationRec.Id,
                fileName: this.admReraData.filename,
                base64Data: this.admReraData.base64
            });
        }

        this.isAdmReraUploaded = true;
        await this.loadExistingFiles();

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'ADM/RERA Copy uploaded successfully!',
                variant: 'success'
            })
        );

    } catch (error) {
        this.isAdmReraUploaded = false;
        this.admReraData = null;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to process ADM/RERA file: ' + (error.message || 'Unknown error'),
                variant: 'error'
            })
        );
    } finally {
        this.isLoading = false;
    }
}

    async handleTradeLicenseChange(event) {
        this.isLoading = true;
        const file = event.target.files[0];
        if (!file){
            this.isLoading = false;
            return;
        }
        // Validate file extension and MIME type
        const validExtensions = ['pdf', 'jpg', 'jpeg'];
        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!validExtensions.includes(fileExtension)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Only .pdf and .jpg files are allowed.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880; // 5MB
        if (file.size > maxSize) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'File size exceeds 5MB limit. Please upload a smaller file.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        this.isTradeLicenseUploaded = true;
        try {
            const reader = new FileReader();
            const base64Data = await new Promise((resolve, reject) => {
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = () => reject(reader.error);
                reader.readAsDataURL(file);
            });

            this.tradeLicenseData = {
                filename: ` TradeLicense.${fileExtension}`,
                base64: base64Data
            };

            if (this.recordId) {
                const uploadResult = await uploadFile({
                    recordId: this.recordId,
                    fileName: this.tradeLicenseData.filename,
                    base64Data: this.tradeLicenseData.base64
                });

                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Trade License Document uploaded successfully!',
                        variant: 'success'
                    })
                );
            } else {
                const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
                this.registrationRec.Id = recordId;
                const uploadResult = await uploadFile({
                    recordId: this.registrationRec.Id,
                    fileName: this.tradeLicenseData.filename,
                    base64Data: this.tradeLicenseData.base64
                });

                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Trade License Document uploaded successfully!',
                        variant: 'success'
                    })
                );
            }
        } catch (error) {
            this.isTradeLicenseUploaded = false;
            this.tradeLicenseData = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to process Trade License file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
    }

    async handleMoaChange(event) {
        this.isLoading = true;
        const file = event.target.files[0];
        if (!file){
            this.isLoading = false;
            return;
        }
        // Validate file extension and MIME type
        const validExtensions = ['pdf', 'jpg', 'jpeg'];
        const fileExtension = file.name.split('.').pop().toLowerCase();
        if (!validExtensions.includes(fileExtension)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Only .pdf and .jpg files are allowed.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        const maxSize = 5242880; // 5MB
        if (file.size > maxSize) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'File size exceeds 5MB limit. Please upload a smaller file.',
                    variant: 'error'
                })
            );
            this.isLoading = false;
            return;
        }

        this.isMoaUploaded = true;
        try {
            const reader = new FileReader();
            const base64Data = await new Promise((resolve, reject) => {
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = () => reject(reader.error);
                reader.readAsDataURL(file);
            });

            this.moaData = {
                filename: `MOA / Local Service Agent Appointment.${fileExtension}`,
                base64: base64Data
            };

            if (this.recordId) {
                const uploadResult = await uploadFile({
                    recordId: this.recordId,
                    fileName: this.moaData.filename,
                    base64Data: this.moaData.base64
                });

                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'MOA Document uploaded successfully!',
                        variant: 'success'
                    })
                );
            } else {
                const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
                this.registrationRec.Id = recordId;
                const uploadResult = await uploadFile({
                    recordId: this.registrationRec.Id,
                    fileName: this.moaData.filename,
                    base64Data: this.moaData.base64
                });
                
                await this.loadExistingFiles();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'MOA Document uploaded successfully!',
                        variant: 'success'
                    })
                );
            }
        } catch (error) {
            this.isMoaUploaded = false;
            this.moaData = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to process MOA file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
    }

    async handleRemoveTradeLicense() {
        this.isLoading = true;
        try {
            if (this.tradeLicenseContentDocumentId) {
                await deleteFile({ contentDocumentId: this.tradeLicenseContentDocumentId });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `File ${this.tradeLicenseFileName} deleted`,
                        variant: 'success'
                    })
                );
            }
            this.isTradeLicenseUploaded = false;
            this.tradeLicenseFileName = `TradeLicense`;
            this.tradeLicenseContentVersionId = '';
            this.tradeLicenseContentDocumentId = '';
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: `Failed to delete ${this.tradeLicenseFileName}: ${error.body?.message}`,
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
    }
async handleRemoveVat() {
    this.isLoading = true;
    try {
        if (this.vatContentDocumentId) {
            await deleteFile({ contentDocumentId: this.vatContentDocumentId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `File ${this.vatFileName} deleted`,
                    variant: 'success'
                })
            );
        }

        // Reset VAT file state
        this.isVatUploaded = false;
        this.showVatFileUpload = false;
        this.vatFileName = `VAT_Registration_Certificate`;
        this.vatContentVersionId = '';
        this.vatContentDocumentId = '';

    } catch (error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: `Failed to delete ${this.vatFileName}: ${error.body?.message || error.message}`,
                variant: 'error'
            })
        );
    } finally {
        this.isLoading = false;
    }
}

    async handleRemoveMoa() {
        this.isLoading = true;
        try {
            if (this.moaContentDocumentId) {
                await deleteFile({ contentDocumentId: this.moaContentDocumentId });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `File ${this.moaFileName} deleted`,
                        variant: 'success'
                    })
                );
            }
            this.isMoaUploaded = false;
            this.moaFileName = `MOA / Local Service Agent Appointment.`;
            this.moaContentVersionId = '';
            this.moaContentDocumentId = '';
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: `Failed to delete ${this.moaFileName}: ${error.body?.message}`,
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false;
        }
    }
    async handleRemoveAdmRera() {
    this.isLoading = true;
    try {
        if (this.admReraContentDocumentId) {
            await deleteFile({ contentDocumentId: this.admReraContentDocumentId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `File ${this.admReraFileName} deleted`,
                    variant: 'success'
                })
            );
        }

        // Reset the ADM/RERA state
        this.isAdmReraUploaded = false;
        this.admReraFileName = `ADM/RERA${this.registrationRec?.Name || ''}`;
        this.admReraContentVersionId = '';
        this.admReraContentDocumentId = '';

    } catch (error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: `Failed to delete ${this.admReraFileName}: ${error.body?.message || error.message}`,
                variant: 'error'
            })
        );
    } finally {
        this.isLoading = false;
    }
}

    async openTradeLicensePreviewPopup() {
        try {
            if (!this.tradeLicenseContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No Trade License file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.tradeLicenseContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handleTradeLicensePreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview Trade License file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }

    async openVatPreviewPopup() {
    try {
        if (!this.vatContentVersionId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No VAT Registration Certificate file available to preview.',
                    variant: 'error'
                })
            );
            return;
        }

        const baseUrl = window.location.origin + '/';
        const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.vatContentVersionId}`;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: fileUrl
            }
        }, false);

    } catch (error) {
        console.error('Error in openVatPreviewPopup:', JSON.stringify(error));
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to preview VAT Registration Certificate: ' + (error.message || 'Unknown error'),
                variant: 'error'
            })
        );
    }
}
async openAdmReraPreviewPopup() {
    try {
        if (!this.admReraContentVersionId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No ADM/RERA file available to preview.',
                    variant: 'error'
                })
            );
            return;
        }

        const baseUrl = window.location.origin + '/';
        const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.admReraContentVersionId}`;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: fileUrl
            }
        }, false);

    } catch (error) {
        console.error('Error in openAdmReraPreviewPopup:', JSON.stringify(error));
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to preview ADM/RERA file: ' + (error.message || 'Unknown error'),
                variant: 'error'
            })
        );
    }
}

    async openMoaPreviewPopup() {
        try {
            if (!this.moaContentVersionId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'No MOA file available to preview.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Construct the file preview URL
            const baseUrl = window.location.origin + '/';
            const fileUrl = `${baseUrl}sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${this.moaContentVersionId}`;

            // Navigate to the file preview URL
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: fileUrl
                }
            }, false);
        } catch (error) {
            console.error('Error in handleMoaPreview:', JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to preview MOA file: ' + (error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }

    @api async submitForm() {
        this.isLoading = true;
        try {
// 1. Check all input fields' validity (email, phone, etc.)
        const allInputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;

        allInputs.forEach(input => {
            input.reportValidity();
            if (!input.checkValidity()) {
                isValid = false;
            }
        });

        if (!isValid) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please fix the errors before proceeding.',
                variant: 'error'
            }));
            return;
        }
            const requiredFields = [
                { field: 'Licensing_Authority__c', label: 'Licensing Authority' },
                { field: 'Issuance_Date__c', label: 'Issuance Date' },
                { field: 'Company_Name_as_per_Trade_License__c', label: 'Company Name as per Trade License' },
                { field: 'Expiry_Date__c', label: 'Expiry Date' },
                { field: 'Trade_License_Number__c', label: 'Trade License Number' }
            ];

            // Check for missing required fields and highlight them
            const missingFields = [];
            requiredFields.forEach(({ field, label }) => {
                if (!this.registrationRec[field]) {
                    missingFields.push(label);
                    const inputField = this.template.querySelector(`lightning-input[name="${field}"]`);
                    if (inputField) {
                        inputField.setCustomValidity('This field is required');
                        inputField.reportValidity();
                    }
                }
            });

            // Check for required file uploads
            if (!this.isTradeLicenseUploaded) {
                missingFields.push('Trade License Document');
            }
            if (!this.isMoaUploaded) {
                missingFields.push('MOA / Local Service Agent Appointment');
            }
            if (!this.isVatUploaded) {
                missingFields.push('VAT Registration Certificate');
            }

            // If there are missing fields, show error toast and stop submission
            if (missingFields.length > 0) {
                const errorMessage = `Please fill in the following required fields: ${missingFields.join(', ')}`;
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: { title: 'Error', message: errorMessage, variant: 'error' },
                    bubbles: true,
                    composed: true
                }));
                this.isLoading = false;
                return;
            }

            // Check for field changes
            let hasFieldChanges = false;
            for (const key in this.registrationRec) {
                if (this.registrationRec[key] !== this.initialRegistrationRec[key]) {
                    hasFieldChanges = true;
                    break;
                }
            }

            if (!hasFieldChanges ){
                this.dispatchEvent(new CustomEvent('success',{
                    detail: { id: this.registrationRec.Id },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: { title: 'Info', message: 'No changes were made to the Trade License information.', variant: 'info' },
                    bubbles: true,
                    composed: true
                }));
            }else if(hasFieldChanges){
                const recordId = await upsertRegistrationRecord({ registrationRec: this.registrationRec });
                this.registrationRec.Id = recordId;
                this.dispatchEvent(new CustomEvent('success', {
                    detail: { id: recordId },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchEvent(new CustomEvent('toast', {
                    detail: { title: 'Success', message: 'Trade License information saved.', variant: 'success' },
                    bubbles: true,
                    composed: true
                }));
                return recordId;
            }
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: error.body?.message || 'Failed to save Trade License information.' },
                bubbles: true,
                composed: true
            }));
        }finally {
            this.isLoading = false;
        }
    }
}