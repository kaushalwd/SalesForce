import { LightningElement, api, track } from 'lwc';
//import { NavigationMixin } from 'lightning/navigation';
import JSZIP from '@salesforce/resourceUrl/JSZip';
import { loadScript } from 'lightning/platformResourceLoader';
import getRecordsWithImages from '@salesforce/apex/MBP_ManagePropertiesController.getRecordsWithImages';
import getDocumentsAndFilesByProject from '@salesforce/apex/MBP_ManagePropertiesController.getDocumentsAndFilesByProject';
import brochureIconFile from '@salesforce/resourceUrl/brochure_icon';
import floorPlanIconFile from '@salesforce/resourceUrl/floorplan_icon';
import genericFileIcon from '@salesforce/resourceUrl/gallary_icon';

const CIPHER_KEY = 'cipher_key_amgs_properties';

function b64urlEncode(bytes) {
    return btoa(String.fromCharCode(...bytes))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');
}

function cipherEncode(plain, key = CIPHER_KEY) {
    const p = new TextEncoder().encode(plain);
    const k = new TextEncoder().encode(key);
    const out = new Uint8Array(p.length);
    for (let i = 0; i < p.length; i++) out[i] = p[i] ^ k[i % k.length];
    return b64urlEncode(out);
}

function coerceImageMime(url) {
    if (!url || !url.startsWith('data:')) return url;
    const [head, b64] = url.split(',', 2);
    if (head.includes('application/octet-stream')) {
        if (b64?.startsWith('/9j/')) return `data:image/jpeg;base64,${b64}`;
        if (b64?.startsWith('iVBORw0')) return `data:image/png;base64,${b64}`;
        if (b64?.startsWith('R0lGOD')) return `data:image/gif;base64,${b64}`;
    }
    return url;
}

export default class MbpMarketingProperties extends LightningElement {
    @track records = [];
    @track filteredRecords = [];
    @track projectOptions = [];
    @track selectedProjectId = '';
    @track selectedProjectDetails =
        [];
    @track selectedProjectImage = '';
    @track documents = { floorPlans: [], gallery: [], Brochures: [] };
    @track viewMode = 'grid';
    @track searchKey = '';
    @track isLoading = false;
    @track loadingDocuments = false;
    @track showProjectDetails = false;
    @track projectName = '';
    @track hasUserInteracted = false;
    zipInitialized = false;
    @track selectedSections = new Set();

    _objectName; _fields = []; _filters = []; _columns = []; _readyTick = 0;

    @api get objectName() { return this._objectName; }
    set objectName(v) { this._objectName = v; this.tryRefresh(); }

    @api get fields() { return this._fields; }
    set fields(v) { this._fields = Array.isArray(v) ? v : []; this.tryRefresh(); }

    @api get filters() { return this._filters; }
    set filters(v) { this._filters = Array.isArray(v) ? v : []; this.tryRefresh(); }

    @api get columns() { return this._columns; }
    set columns(v) { this._columns = Array.isArray(v) ? v : []; this.tryRefresh(); }

    @api imageMatchField;
    @api documentMatchField;
    @api page;

    get brochureIcon() {
        return brochureIconFile || genericFileIcon;
    }

    get floorPlanIcon() {
        return floorPlanIconFile || genericFileIcon;
    }

    get galleryThumbnail() {
        return this.documents.gallery?.[0]?.files?.[0]?.thumbnailUrl || genericFileIcon;
    }

    get showProjectsList() { return !this.showProjectDetails; }
    get showEmptyState() { return !this.hasUserInteracted && !this.showProjectDetails; }
    setListView() { this.viewMode = 'list'; }
    setGridView() { this.viewMode = 'grid'; }
    get isGridView() { return this.viewMode === 'grid'; }

    get normalizedColumns() {
        const cols = Array.isArray(this._columns) ? this._columns : [];
        return cols.map(c => {
            const api = c.fieldName || c.fieldPath || 'Name';
            const key = api.replace(/\./g, '_');
            return { ...c, fieldName: key, apiName: api };
        });
    }

    get columnsList() {
        return this.normalizedColumns.length
            ? this.normalizedColumns
            : [{ label: 'Name', fieldName: 'Name', apiName: 'Name' }];
    }

    get effectiveApiFields() {
        const api = Array.isArray(this._fields) ? [...this._fields] : [];
        if (!api.includes('Name')) api.unshift('Name');
        if (!api.includes('Id')) api.push('Id');
        return api;
    }

    connectedCallback() {
        this.tryRefresh();
    }

    renderedCallback() {
        if (this.zipInitialized) return;
        this.zipInitialized = true;
        loadScript(this, JSZIP)
            .catch(error => {
                console.error('Error loading JSZip', error);
            });
    }

    tryRefresh() {
        if (!(this._objectName && Array.isArray(this._filters))) return;
        if (!Array.isArray(this._fields) || this._fields.length === 0) return;
        if (!Array.isArray(this._columns) || this._columns.length === 0) return;

        const tick = ++this._readyTick;
        Promise.resolve().then(() => { if (tick === this._readyTick) this.refreshData(); });
    }

    refreshData() {
        this.isLoading = true;
        this.searchKey = '';
        this.selectedProjectId = '';
        this.viewMode = 'grid';
        this.records = [];
        this.filteredRecords = [];
        this.projectOptions = [];
        this.showProjectDetails = false;
        this.hasUserInteracted = false;

        getRecordsWithImages({
            objectName: this._objectName,
            filters: {},
            fields: this.effectiveApiFields,
        }).then(result => {
            const wrappedRecords = Array.isArray(result) ? result : [];

            const base = wrappedRecords.map(w => {
                const rec = w.recordData || {};
                const rawUrls = Array.isArray(w.imageUrls) ? w.imageUrls : [];
                const allImageUrls = rawUrls.map(coerceImageMime);
                const firstImageUrl = allImageUrls[0] || '';

                const fieldData = this.effectiveApiFields.map(field => {
                    const label = field.replace('__c', '').replace('__r.', ' ').replace(/_/g, ' ');
                    let value = '';
                    try {
                        if (field.includes('.')) {
                            const parts = field.split('.');
                            value = rec[parts[0]]?.[parts[1]] ?? '';
                        } else {
                            value = rec[field];
                        }
                    } catch {
                        value = '';
                    }
                    return { label, value };
                });

                return { ...rec, firstImageUrl, allImageUrls, fieldData };
            });

            const flattened = this.flattenForColumns(base, this.columnsList);
            this.records = flattened.map(rec => {
                const rowData = this.columnsList.map(col => ({
                    fieldName: col.fieldName,
                    value: rec[col.fieldName] ?? ''
                }));
                return { ...rec, rowData };
            });

            this.projectOptions = [{ label: '-- Select a Project --', value: '' }].concat(
                this.records.map(rec => ({ label: rec.Name, value: rec.Id }))
            );

            this.filteredRecords = [];
        }).catch(error => {
            console.error('Error fetching records with images:', error);
        }).finally(() => {
            this.isLoading = false;
        });
    }

    flattenForColumns(records, columns) {
        const rows = JSON.parse(JSON.stringify(records));
        const cols = Array.isArray(columns) ? columns : [];

        rows.forEach(r => {
            cols.forEach(col => {
                if (col.apiName && col.apiName.includes('.')) {
                    const parts = col.apiName.split('.');
                    let v = r;
                    parts.forEach(p => v = (v && v[p]) != null ? v[p] : null);
                    r[col.fieldName] = v;
                } else if (col.apiName) {
                    r[col.fieldName] = r[col.apiName];
                }
            });
        });
        return rows;
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
        this.selectedProjectId = '';
        this.hasUserInteracted = true;
        this.applyFilters();

        if (this.searchKey && this.filteredRecords.length === 1) {
            this.loadProjectDetails(this.filteredRecords[0].Id);
        } else {
            this.showProjectDetails = false;
        }
    }

    handleProjectSelection(event) {
        this.selectedProjectId = event.detail.value;
        this.searchKey = '';
        this.hasUserInteracted = true;
        this.applyFilters();

        if (this.selectedProjectId) {
            this.loadProjectDetails(this.selectedProjectId);
        } else {
            this.showProjectDetails = false;
            this.filteredRecords = [];
        }
    }

    applyFilters() {
        let filtered = [...this.records];
        if (this.searchKey) {
            const s = this.searchKey.toLowerCase();
            filtered = filtered.filter(r => r.Name?.toLowerCase().includes(s));
        }
        if (this.selectedProjectId && !this.searchKey) {
            filtered = filtered.filter(r => r.Id === this.selectedProjectId);
        }
        this.filteredRecords = filtered;
    }

    handleCardClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this.selectedProjectId = recordId;
        this.searchKey = '';
        this.hasUserInteracted = true;
        this.loadProjectDetails(recordId);
    }

    async loadProjectDetails(projectId) {
        this.showProjectDetails = true;
        this.loadingDocuments = true;

        const selectedProject = this.records.find(rec => rec.Id === projectId);
        if (selectedProject) {
            this.projectName = selectedProject.Name;
            this.selectedProjectImage = selectedProject.firstImageUrl;

            this.selectedProjectDetails = (this.fields || []).map(field => {
                const label = field.replace('__c', '').replace('__r.', ' ').replace(/_/g, ' ');
                let value = '';
                try {
                    value = field.includes('.')
                        ? selectedProject[field.split('.')[0]]?.[field.split('.')[1]] ?? ''
                        : selectedProject[field];
                } catch {
                    value = '';
                }
                return { label, value };
            });
        }

        try {
            let docs = await getDocumentsAndFilesByProject({ projectId });

            // normalize docs
            let normalizedDocs = (docs || []).map(d => {
                let files = Array.isArray(d.files) ? d.files : [];
                return {
                    ...d,
                    files,
                    hasFiles: files.length > 0,
                    isSingleFile: files.length === 1,
                    firstFile: files.length === 1 ? files[0] : null,
                    allDownloadUrls: files.map(f => f.downloadUrl).join(',')
                };
            });

            // group by section
            let floorDocs = normalizedDocs.filter(d =>
                d.documentName?.toLowerCase().includes('floor plan')
            );
            let galleryDocs = normalizedDocs.filter(d =>
                d.documentName?.toLowerCase().includes('gallery')
            );
            let otherDocs = normalizedDocs.filter(d =>
                !d.documentName?.toLowerCase().includes('floor plan') &&
                !d.documentName?.toLowerCase().includes('gallery') &&
                !d.documentName?.toLowerCase().includes('thumbnail')
            );

            
            function aggregateDocs(name, list) {
                let allFiles = list.flatMap(d => d.files);
                return [{
                    documentId: name,
                    documentName: name,
                    files: allFiles,
                    hasFiles: allFiles.length > 0,
                    isSingleFile: allFiles.length === 1,
                    firstFile: allFiles.length === 1 ? allFiles[0] : null,
                    allDownloadUrls: allFiles.map(f => f.downloadUrl).join(',')
                }];
            }

            this.documents = {
                floorPlans: aggregateDocs('', floorDocs),
                gallery: aggregateDocs('', galleryDocs),
                Brochures: aggregateDocs('', otherDocs)
            };

        } catch (e) {
            console.error('Error loading documents:', e);
            this.documents = { floorPlans: [], gallery: [], Brochures: [] };
        } finally {
            this.loadingDocuments = false;
        }
    }

    handleBackToList() {
        this.showProjectDetails = false;
        this.selectedProjectId = '';
        this.searchKey = '';
        this.filteredRecords = [];
        this.documents = { floorPlans: [], gallery: [], Brochures: [] };
        this.hasUserInteracted = false;
    }

   /* handleDownload(event) {
        const url = event.target.dataset.url;
        if (url) {
            window.open(url, '_blank');
        } else {
            alert('Download URL not available');
        }
    }*/

   /* handleDownloadAll(event) {
        const urls = event.target.dataset.urls?.split(',') || [];
        if (urls.length === 0) {
            alert('No files available to download.');
            return;
        }
        urls.forEach(url => {
            const link = document.createElement('a');
            link.href = url;
            link.target = '_blank';
            link.download = '';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        });
    }*/

    get hasAnyFiles() {
        return (
            (this.documents.floorPlans?.[0]?.hasFiles) ||
            (this.documents.gallery?.[0]?.hasFiles) ||
            (this.documents.Brochures?.[0]?.hasFiles)
        );
    }

    
    triggerDownload(blob, name) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    
    async downloadAllFiles() {
        let allFiles = [];
        Object.values(this.documents).forEach(arr => {
            arr.forEach(d => {
                if (d.files?.length > 0) {
                    allFiles.push(...d.files);
                }
            });
        });

        if (allFiles.length === 0) {
            alert('No files available to download.');
            return;
        }

        const zip = new window.JSZip();

        for (let f of allFiles) {
            try {
                const res = await fetch(f.downloadUrl);
                const blob = await res.blob();
                const arrayBuffer = await blob.arrayBuffer();
                zip.file(f.title + '.' + f.fileExtension, arrayBuffer);
            } catch (err) {
                console.error(`Error downloading ${f.title}`, err);
            }
        }

        const content = await zip.generateAsync({ type: 'blob' });
        this.triggerDownload(content, 'Project_Files.zip');
    }

    async downloadSectionFiles(event) {
        const urls = event.target.dataset.urls?.split(',') || [];
        const section = event.target.dataset.section || 'Section';

        if (urls.length === 0) {
            alert('No files available to download.');
            return;
        }

        const zip = new window.JSZip();
        let index = 1;

        for (let url of urls) {
            try {
                const res = await fetch(url);
                const blob = await res.blob();
                const arrayBuffer = await blob.arrayBuffer();
                zip.file(`${section}_${index}.file`, arrayBuffer);
                index++;
            } catch (err) {
                console.error(`Error downloading file from ${url}`, err);
            }
        }

        const content = await zip.generateAsync({ type: 'blob' });
        this.triggerDownload(content, section + '.zip');
    }


    get isSectionSelected() {
        return {
            Brochures: this.selectedSections.has('Brochures'),
            gallery: this.selectedSections.has('gallery'),
            floorPlans: this.selectedSections.has('floorPlans')
        };
    }

    get hasSelectedSections() {
        return this.selectedSections.size > 0;
    }

    get isAllSelected() {
        return (
            this.hasBrochureFiles &&
            this.hasGalleryFiles &&
            this.hasFloorPlanFiles &&
            this.selectedSections.size === 3
        );
    }

    handleSectionCheckboxChange(event) {
        const section = event.target.dataset.section;
        if (event.target.checked) {
            this.selectedSections.add(section);
        } else {
            this.selectedSections.delete(section);
        }
        this.selectedSections = new Set(this.selectedSections); // retrack
    }

    handleSelectAllChange(event) {
        if (event.target.checked) {
            if (this.hasBrochureFiles) this.selectedSections.add('Brochures');
            if (this.hasGalleryFiles) this.selectedSections.add('gallery');
            if (this.hasFloorPlanFiles) this.selectedSections.add('floorPlans');
        } else {
            this.selectedSections.clear();
        }
        this.selectedSections = new Set(this.selectedSections); // retrack
    }

    async downloadSelectedSections() {
        if (this.selectedSections.size === 0) {
            alert('Please select at least one section.');
            return;
        }

        const zip = new window.JSZip();
        const projectFolderName = this.projectName?.replace(/\s+/g, '_') || 'Project';
        for (let section of this.selectedSections) {
            const docs = this.documents[section];
            if (docs?.length && docs[0].files?.length) {
                for (let f of docs[0].files) {
                    try {
                        const res = await fetch(f.downloadUrl);
                        const blob = await res.blob();
                        const arrayBuffer = await blob.arrayBuffer();
                        zip.file(`${projectFolderName}/${section}/${f.title}.${f.fileExtension}`, arrayBuffer);
                    } catch (err) {
                        console.error(`Error downloading ${f.title}`, err);
                    }
                }
            }
        }

        const content = await zip.generateAsync({ type: 'blob' });
        this.triggerDownload(content, `${projectFolderName}_Project.zip`);
    }


    get hasBrochureFiles() {
        return this.documents.Brochures?.[0]?.files?.length > 0;
    }

    get hasGalleryFiles() {
        return this.documents.gallery?.[0]?.files?.length > 0;
    }

    get hasFloorPlanFiles() {
        return this.documents.floorPlans?.[0]?.files?.length > 0;
    }


}