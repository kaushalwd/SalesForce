/**
* Description: LWC for Sales order dropdown Customer 360 dashboard
* Author: Chaitanya N
* Name: SalesOrderDropdown
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import getSalesOrders from '@salesforce/apex/SalesOrderController.getSalesOrders';
import { NavigationMixin } from 'lightning/navigation';

export default class SalesOrderDropdown extends NavigationMixin(LightningElement) {
  @api recordId;
  @track projects = [];

  @api startDate;
  @api endDate;
  @track hasData = false;
  @api projectName;
  @api unitName;
  @track showProjectModal = false;
  @track selectedProject = null;       
  @track modalKey = 0;
  portalHost;
  movedWrapper;
  originalParent;
  originalNextSibling;


renderedCallback() {
  if (this.showProjectModal) {
    requestAnimationFrame(() => this.moveWrapperToBody());
  }
}

moveWrapperToBody() {
  const wrapper = this.template.querySelector('[data-portal-wrapper]');
  if (!wrapper) return;

  // create portal host once per open
  if (!this.portalHost) {
    this.portalHost = document.createElement('div');
    this.portalHost.style.position = 'fixed';
    this.portalHost.style.inset = '0';
    this.portalHost.style.zIndex = '9999999';
    document.body.appendChild(this.portalHost);
  }

  // store original location only once
  if (!this.originalParent) {
    this.originalParent = wrapper.parentNode;
    this.originalNextSibling = wrapper.nextSibling;
  }

  // already moved
  if (wrapper.parentNode === this.portalHost) return;

  this.movedWrapper = wrapper;
  this.portalHost.appendChild(wrapper);

  // lock background scroll
  document.body.style.overflow = 'hidden';
}

restoreWrapper() {
  try {
    // IMPORTANT: put wrapper back BEFORE removing portal host
    if (this.movedWrapper && this.originalParent) {
      if (this.originalNextSibling) {
        this.originalParent.insertBefore(this.movedWrapper, this.originalNextSibling);
      } else {
        this.originalParent.appendChild(this.movedWrapper);
      }
    }

    // unlock scroll
    document.body.style.overflow = '';

    // remove portal host after wrapper is restored
    if (this.portalHost) {
      this.portalHost.remove();
      this.portalHost = null;
    }

    // cleanup refs
    this.movedWrapper = null;
    this.originalParent = null;
    this.originalNextSibling = null;
  } catch (e) {
    document.body.style.overflow = '';
  }
}

closeProjectModal(event) {
  if (event) event.stopPropagation();

  // restore first, then flip state
  this.restoreWrapper();
  this.showProjectModal = false;
  this.selectedProject = null;
}

disconnectedCallback() {
  this.restoreWrapper();
}



formatAmount(value) {
  const num = Number(value);
  if (Number.isNaN(num)) return '0.00';

  // Example: 12000000 -> 12,000,000.00
  return num.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  });
}


  @wire(getSalesOrders, { 
    accountId: '$recordId', 
    startDateOptional: '$startDate', 
    endDateOptional: '$endDate', 
    projectNameOptional: '$projectName',  
    unitNameOptional: '$unitName' 
  })
  wiredSalesOrders({ error, data }) {
    
    if (data && data.length > 0) {
      this.hasData = true;
      const projectMap = {};

      data.forEach(order => {
        const projectName = order.ProjectName__c || 'Unknown Project';
        if (!projectMap[projectName]) {
          projectMap[projectName] = {
            projectName,
            salesOrders: [],
            unitNames: new Set(),
            totalAmount: 0,
            totalPaid: 0,
            totalOutstanding: 0,
            totalFuture: 0
          };
        }

        const totalAmt = order.TotalAmount__c || 0;
        const paidAmt = order.PaidAmount__c || 0;        // collected
        const outstandingAmt = order.OutstandingAmount__c || 0;
        const futureAmt = order.FutureAmount__c || 0;


        
        const hasJointOwners = order.HasJointOwners || false;
        const jointOwnersList = order.JointOwners ? JSON.parse(JSON.stringify(order.JointOwners)) : [];
        let totalJointPercentage = 0;
        jointOwnersList.forEach(j => {
          const perc = j.OwnershipPercentage__c ? parseFloat(j.OwnershipPercentage__c) : 0;
          totalJointPercentage += perc;
        });

        if (totalJointPercentage > 100) totalJointPercentage = 100;
        let remainingPercentage = 100 - totalJointPercentage;

        if (hasJointOwners && remainingPercentage > 0.01) {
          jointOwnersList.push({
            JointOwnerAccount__c: order.CustomerAccount__c,
            JointOwnerAccount__r: { Name: order.CustomerAccount__r?.Name || 'Primary Account' },
            RelationshipType__c: 'Primary',
            RelationshipSubType__c: 'Main Owner',
            OwnershipPercentage__c: parseFloat(remainingPercentage.toFixed(2)),
            Opportunity__r: { Name: order.Opportunity__r?.Name || 'N/A' },
            SalesOrder__c: order.Id
          });
        }

        const status = order.Unit__r?.Status__c || 'N/A';
        let unitStatusClass = 'status-tag default';
        switch (status.toLowerCase()) {
          case 'available':
            unitStatusClass = 'status-tag available';
            break;
          case 'sold':
            unitStatusClass = 'status-tag sold';
            break;
          case 'ccmd':
            unitStatusClass = 'status-tag ccmd';
            break;
          case 'reserved':
            unitStatusClass = 'status-tag reserved';
            break;
          case 'unreleased':
            unitStatusClass = 'status-tag unreleased';
            break;
          case 'blocked for upgrade':
            unitStatusClass = 'status-tag blocked';
            break;
          case 'handed over':
            unitStatusClass = 'status-tag handed';
            break;
        }

        let imageUrl = order.Unit__r?.ImageURL || null;
        if (imageUrl && !imageUrl.startsWith('http')) {
          const baseUrl = 'https://' + window.location.hostname;
          imageUrl = `${baseUrl}${imageUrl}`;
        }

        if (!imageUrl) {
          console.warn('%c No Image for Unit:', 'color: orange; font-weight: bold;', order.Unit_Name__c || '(Unknown Unit)');
        }

        projectMap[projectName].salesOrders.push({
          id: order.Id,
          name: order.Name,
          imageUrl: imageUrl,
          totalAmount: this.formatAmount(totalAmt),
          totalPaid: this.formatAmount(paidAmt),
          //outstanding: this.formatAmount(pendingAmt),
          outstanding: this.formatAmount(outstandingAmt),
          future: this.formatAmount(futureAmt),
          paymentPlan: order.PaymentPlan__r?.Name || 'No Plan',
          unitName: order.Unit_Name__c || 'N/A',
          unitStatus: status,
          unitStatusClass,
          unitClassification: order.Unit__r?.UnitClassification__c || 'N/A',
          hasJointOwners,
          ownerTypeLabel: hasJointOwners ? 'Joint Owner' : 'Primary Owner',
          ownerTagClass: hasJointOwners ? 'owner-tag joint' : 'owner-tag primary',

          primaryOwner: order.CustomerAccount__r?.Name || 'N/A',
          accountId: order.CustomerAccount__c,

          unitId: order.Unit__c,
          jointOwners: jointOwnersList,
          isExpanded: false
        });

        const lastAdded = projectMap[projectName].salesOrders[projectMap[projectName].salesOrders.length - 1];
        
        projectMap[projectName].unitNames.add(order.Unit_Name__c);
        projectMap[projectName].totalAmount += totalAmt;
        projectMap[projectName].totalPaid += paidAmt;
        projectMap[projectName].totalOutstanding += outstandingAmt;
      projectMap[projectName].totalFuture += futureAmt;
      });

      this.projects = Object.values(projectMap).map((project, index) => {
        const firstOrderWithImage = project.salesOrders.find(o => o.imageUrl);
        const imageUrl = firstOrderWithImage ? firstOrderWithImage.imageUrl : null;

        return {
          ...project,
          projectKey: `${project.projectName}-${index}`, 
          imageUrl,
          salesOrderCount: project.salesOrders.length,
          unitCount: project.unitNames.size,
          //outstanding: this.formatAmount(project.totalAmount - project.totalPaid),
          totalAmount: this.formatAmount(project.totalAmount),
          totalPaid: this.formatAmount(project.totalPaid),
          outstanding: this.formatAmount(project.totalOutstanding),
          future: this.formatAmount(project.totalFuture),
          isExpanded: false,
          iconName: 'utility:chevronright'
        };
      });


      //this.updateVisibleProjects();
    } else {
      console.warn('%c⚠️ No data returned from Apex', 'color: orange; font-weight: bold;');
      this.hasData = false;
    }

    if (error) {
      console.error('%c❌ Error loading sales orders:', 'color: red; font-weight: bold;', error);
      this.hasData = false;
    }
  }

  

  navigateToAccount(event) {
  event.stopPropagation(); 
  const accId = event.currentTarget.dataset.id;
  if (!accId) return;

  const baseUrl = window.location.origin;
  window.open(`${baseUrl}/lightning/r/Account/${accId}/view`, '_blank');
}

navigateToUnit(event) {
  event.stopPropagation(); 
  const unitId = event.currentTarget.dataset.id;
  if (!unitId) return;

  const baseUrl = window.location.origin;
  window.open(`${baseUrl}/lightning/r/Unit__c/${unitId}/view`, '_blank');
}


  

  handleProjectToggle(event) {
    const projectName = event.currentTarget.dataset.project;
    
    this.projects = this.projects.map(proj => {
      if (proj.projectName === projectName) {
        const expanded = !proj.isExpanded;
        return { ...proj, isExpanded: expanded, iconName: expanded ? 'utility:chevrondown' : 'utility:chevronright' };
      }
      return proj;
    });
    //this.updateVisibleProjects();
  }

  handleOrderExpand(event) {
    const orderId = event.currentTarget.dataset.id;
    const projectName = event.currentTarget.dataset.project;
    
    const projectsCopy = JSON.parse(JSON.stringify(this.projects));
    const proj = projectsCopy.find(p => p.projectName === projectName);

    proj.salesOrders.forEach(o => {
      o.isExpanded = (o.id === orderId) ? !o.isExpanded : false;
    });

    this.projects = [...projectsCopy];
    //this.updateVisibleProjects();
  }
  openProjectModal(event) {
  event.stopPropagation();

  const projectKey = event.currentTarget.dataset.project;

  const found = (this.projects || []).find(p => p.projectKey === projectKey);

  if (!found) {
    this.selectedProject = null;
    this.showProjectModal = false;
    return;
  }

 
  const cloned = JSON.parse(JSON.stringify(found));

 
  cloned.salesOrders = (cloned.salesOrders || []).map(o => ({ ...o, isExpanded: false }));

  this.selectedProject = cloned;
  this.showProjectModal = false;
  this.modalKey++;

  requestAnimationFrame(() => {
    this.showProjectModal = true;
  });
}



  handleModalOrderExpand(event) {
  event.stopPropagation(); // 

  const orderId = event.currentTarget.dataset.id;

  const updatedOrders = (this.selectedProject.salesOrders || []).map(o => ({
    ...o,
    isExpanded: o.id === orderId ? !o.isExpanded : false
  }));

  this.selectedProject = { ...this.selectedProject, salesOrders: updatedOrders };
}

  stopModalClose(event) {
    event.stopPropagation();
  }




handleOrderLinkClick(event) {
  event.stopPropagation();
  this.navigateToOrder(event);
}



}