/**
 * @description       : 
 * @author            : Manoj
 * @group             : 
 * @last modified on  : 01-29-2026
 * @last modified by  : Manoj
**/
import { LightningElement, api, wire } from 'lwc';
import getProjects from '@salesforce/apex/ProjectPhasePicklistController.getProjects';
import getPhases from '@salesforce/apex/ProjectPhasePicklistController.getPhases';

export default class ProjectPhasePicklist extends LightningElement {

   _entityName;

    @api
    get entityName() {
        return this._entityName;
    }
    set entityName(value) {
        this._entityName = value;

        if (value) {
            this.loadProjects();
        }
    }
    
    @api selectedProjectId;
    @api selectedPhaseId;

    projectOptions = [];
    phaseOptions = [];

  

     //  Imperative Apex call
    async loadProjects() {
        try {
            const data = await getProjects({ EntityName: this.entityName });
            if (Array.isArray(data) && [...data].length > 0) {
                this.projectOptions = [...data].map(p => ({
                    label: p.Name,
                    value: p.Id
                }));
            } else {
                this.projectOptions = [];
                console.warn('No projects returned');
            }

        } catch (error) {
            console.error('Error loading projects', error);
        }
    }
    handleProjectChange(event) {
       // this.entityName = event.detail.value;
        this.selectedProjectId = event.detail.value;
        this.selectedPhaseId = null;

        getPhases({ projectId: this.selectedProjectId })
            .then(data => {
                this.phaseOptions = data.map(ph => ({
                    label: ph.Name,
                    value: ph.Id
                }));
            });
    }

    handlePhaseChange(event) {
        this.selectedPhaseId = event.detail.value;
    }
}