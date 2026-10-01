import { LightningElement, wire, track } from 'lwc';
import { refreshApex }    from '@salesforce/apex';
import getSalesOrders     from '@salesforce/apex/SalesOrderCMAAssignController.getSalesOrders';
import assignCMAssociate  from '@salesforce/apex/SalesOrderCMAAssignController.assignCMAssociate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LABEL_JSON         from '@salesforce/label/c.SO_CM_Associate_Fields';

const CFG         = JSON.parse(LABEL_JSON);
const COL_DEFS    = CFG.Columns;
const FILTER_DEFS = CFG.Filters;
const COL_APIS    = COL_DEFS.map(c => c.field);

export default class SalesOrderCMAAssign extends LightningElement {

    columns        = [];
    previewColumns = [];

    @track rows = [];
    originalRows = [];

    dynamicFilterValues = {};
    selectedDynFilters  = {};

    scopeFilter  = 'All';
    searchKey    = '';
    selectedRowIds = [];

    isModalOpen      = false;
    selectedUserId   = null;
    overrideExisting = true;

    wiredResult;
    error;


    scopeOptions = [
        { label:'All Sales Orders', value:'All' },
        { label:'Unassigned Sales Orders', value:'Unassigned' },
        { label:'Assigned Sales Orders',   value:'Assigned' }
    ];

   
    get assignBtnDisabled() { return !this.selectedRowIds.length; }
    get confirmDisabled()   { return !(this.selectedUserId && this.selectedRowIds.length); }

    get dynamicFilters() {
        return FILTER_DEFS.map(f => ({
            api    : f.field,
            label  : f.name,
            value  : this.selectedDynFilters[f.field] || '',
            options: this.buildPickOpts(this.dynamicFilterValues[f.field] || [])
        }));
    }

   

   
    constructor() {
        super();
        console.debug('[JS] ctor');
        this.columns        = this.makeColumns(false);
        this.previewColumns = this.makeColumns(true);
    }
    connectedCallback() {
        const preload = document.createElement('lightning-record-edit-form');
        preload.objectApiName = 'SalesOrder__c';
        preload.style.display = 'none';
        preload.appendChild(Object.assign(
            document.createElement('lightning-input-field'),
            { fieldName:'Customer_Management_Associate__c' }
        ));
        this.template.appendChild(preload);
    }

   
    makeColumns(isPreview){
         if (isPreview){
        const base = [
            { label:'Sales Order', fieldName:'soUrl', type:'url',
              typeAttributes:{ label:{ fieldName:'Name' }, target:'_blank' } },
            { label:'Unit Name',   fieldName:'Unit_Name__c', type:'text' },
            { label:'Customer',    fieldName:'CustomerAccount__r.Name', type:'text' },
            { label:'CM Associate',fieldName:'Customer_Management_Associate__r.Name', type:'text' }
        ];
       
        return base.map(col => ({
            ...col,
            cellAttributes:{ style:{ fieldName:'cellStyle' } }
        }));
    }
        
        return COL_DEFS.map(d=>{
            const p=d.field;
            if(p==='Name'){
                return { label:d.name, fieldName:'soUrl', type:'url',
                         typeAttributes:{ label:{ fieldName:'Name' }, target:'_blank' },
                         sortable:true };
            }
            if(p.includes('.')){
                const rel=p.split('.')[0];
                return { label:d.name, fieldName:`${rel}Url`, type:'url',
                         typeAttributes:{ label:{ fieldName:p }, target:'_blank' },
                         sortable:true };
            }
            return { label:d.name, fieldName:p, type:'text', sortable:true };
        });
    }

   
    buildPickOpts(vals=[]){
        return [{ label:'All', value:'' }, ...vals.map(v=>({ label:v, value:v }))];
    }


    get previewRows(){
        return this.rows
            .filter(r => this.selectedRowIds.includes(r.Id))
            .map(r => ({
                ...r,
                cellStyle : r.Customer_Management_Associate__c ? 'background:#FDECEA;color:#C23934' : 'background:#e2fee2;color:#006400'
            }));
    }
   
    enrich(src){
        const r={ Id:src.Id, soUrl:'/'+src.Id, ...src };
        COL_APIS.forEach(p=>{
            if(!p.includes('.')) return;
            const [rel,sub]=p.split('.');
            const obj=src[rel];
            r[p]=obj?obj[sub]:'';
            r[`${rel}Url`]=obj?'/'+obj.Id:'';
        });
        return r;
    }

   
    @wire(getSalesOrders,{ scopeFilter:'$scopeFilter', searchKey:'$searchKey' })
    wired({error,data}){
        if(error){ this.error=error; return; }
        if(!data){ return; }
        this.originalRows        = data.rows.map(r=>this.enrich(r));
        this.dynamicFilterValues = data.filterValues;
        this.applyFilter();              
    }

   
     handleScopeChange(e){
        this.scopeFilter = e.detail.value;
       
        this.applyFilter();
    }
    handleDynFilter(e){
        this.selectedDynFilters[e.currentTarget.dataset.api]=e.detail.value;
        this.applyFilter();
    }
    handleSearchInput(e){
        clearTimeout(this._t);
        const txt = (e.target.value || '').trim();
    
        this._t = setTimeout(() => {
            this.searchKey = txt.toLowerCase();
            this.applyFilter();
        }, 200);
    }
    handleRowSel(e){ this.selectedRowIds=e.detail.selectedRows.map(r=>r.Id); }

    openModal(){ this.isModalOpen=true; }
    closeModal(){ this.isModalOpen=false; }

    handleAssociateChange(e){
        const v=e.detail.value;
        this.selectedUserId=Array.isArray(v)?v[0]:v;
    }
        handleOverrideToggle(e){ this.overrideExisting=e.target.checked; }

        handleAssign() {
        assignCMAssociate({
            orderIds:        this.selectedRowIds,
            associateId:     this.selectedUserId,
            overrideExisting:this.overrideExisting
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({ title:'Success', variant:'success', message:'Updated.' })
            );

            this.closeModal();
            this.selectedRowIds = [];
            this.selectedUserId = null;

            return refreshApex(this.wiredResult);
        })
    
        .then(() => {
            setTimeout(() => window.location.reload(), 800);
        })
        .catch(err => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title   :'Error',
                    variant :'error',
                    message : err.body ? err.body.message : err.message
                })
            );
        });
    }

    
    applyFilter(){
        const term   = (this.searchKey || '').trim();            
        const active = Object.entries(this.selectedDynFilters)
                            .filter(([,v]) => v);

        this.rows = this.originalRows.filter(rec => {

        
            if (active.some(([fld,val]) => rec[fld] !== val)) return false;

            if (term){
        const t = term.toLowerCase();
        const hit = Object.values(rec).some(v => {
            return typeof v === 'string' && v.toLowerCase().includes(t);
        });
        if (!hit) return false;
    }
            return true;
        });
    }

    handleSearchKeyUp(e){
        clearTimeout(this._t);
        const txt = (e.target.value || '').trim().toLowerCase();

    
        this._t = setTimeout(() => {
            this.searchKey = txt;     
            this.applyFilter();
        }, 180);
    }
}