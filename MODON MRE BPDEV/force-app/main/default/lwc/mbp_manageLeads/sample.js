/**
  * Columns definition
  * :: used in examples
  */
import FORM_FACTOR from '@salesforce/client/formFactor';
export const EXAMPLES_COLUMNS_DEFINITION_BASIC = [
    {
        type: 'text',
        /*fieldName: 'column0',*/
        label: '',
        initialWidth: 10,
        cellAttributes: { class:'column-id' /*important for reponsive */}
    },
    {
        type: 'text',
        fieldName: 'leadNumber',
        label: 'Lead Number',
        initialWidth: 160,
    },
    {
        type: 'text',
        fieldName: 'column1',
        label: 'Title',
       initialWidth: 120,
    },
   
    {
        type: 'text',
        fieldName: 'column2',
        label: 'First Name',
        initialWidth: 150,
    },
    {
        type: 'text',
        fieldName: 'column3',
        label: 'Last Name',
        initialWidth: 150,
    },
    {
        type: 'text',
        fieldName: 'column4',
        label: 'Email',
         initialWidth: 250,
    },
    {
        type: 'text',
        fieldName: 'column5',
        label: 'Mobile',
        initialWidth: 200,
    },
    {
        type: 'text',
        fieldName: 'column6',
        label: 'Country',
        initialWidth: 135,
    },
    {

        label: FORM_FACTOR === 'Large' ? '' : 'View',
        fieldName: 'column7',
        type: 'button',
        initialWidth: 40,
        typeAttributes: {
            iconName: 'action:preview',

            name: 'View',
            title: '',
            disabled: false,
            value: 'test'

        },
        cellAttributes: {
            class: 'custom-grid-icon show-icon-for-child-row with-calendar-icon',
            alignment: `left`
        }
    },

    {

        label: FORM_FACTOR === 'Large' ? '' : 'Expand',
        //fieldName: 'column8',
        initialWidth: 40,
        type: 'button',
        typeAttributes: {
            iconName: 'action:download123',

            name: 'Expand',
            title: '',
            disabled: false,
            value: 'test'
        },
        cellAttributes: {
            class: 'custom-grid-icon collapse-icons noborder',
            alignment: `left`
        }
    }
];


export const EXAMPLES_DATA_BASIC = [
    {
        column1: 'title',
        column2: 'Rewis Inc',
        column3: "test",
        column4: " sdfsdf",
        column5: '837-555-0100',
        column6: 'ABCD',
        column7: '',
        column8: 'title'

    },

    {
        column1: 'title2',
        column2: 'Rewis Inc',
        column3: "test",
        column4: " sdfsdf",
        column5: '837-555-0100',
        column6: 'ABCD',
        column7: '',
        column8: 'title2',

        _children: [
            {
                column1: 'Project: Mamsha',
                column2: '',
                column3: "Unity Type: 2BHK",
                column4: "",
                column5: 'Created Date & Time: 15.30-22/01/2022',
                column6: 'Promotion: Q4 Summer Promo Summer 2021',
                column7: '',
                column8: 'Project: Mamsha',
            },

            {
                column1: 'Project: Mayan',
                column2: '',
                column3: "Unity Type: 2BHK + M",
                column4: "",
                column5: 'Created Date & Time: 15.00-22/01/2022',
                column6: 'Promotion: Q4 Summer Promo Summer 2021',
                column7: '', column8: "",
            },
        ],
    },

    {
        column1: 'title5',
        column2: 'Rewis Inc',
        column3: "test",
        column4: " sdfsdf",
        column5: '837-555-0100',
        column6: 'ABCD',
        column7: '',
        column8: 'title5',
        _children: [
            {
                column1: 'Project: Mayan',
                column2: '',
                column3: "Unity Type: 2BHK + M",
                column4: "",
                column5: 'Created Date & Time: 15.00-22/01/2022',
                column6: 'Promotion: Q4 Summer Promo Summer 2021'

            },

            {
                column1: 'Project: Mayan',
                column2: '',
                column3: "Unity Type: 2BHK + M",
                column4: "",
                column5: 'Created Date & Time: 15.00-22/01/2022',
                column6: 'Promotion: Q4 Summer Promo Summer 2021',
                column7: '',
                column8: 'title2',
            }
        ],
    },

    {
        column1: 'title7',
        column2: 'Rewis Inc',
        column3: "test",
        column4: " sdfsdf",
        column5: '837-555-0100',
        column6: 'ABCD',
        column7: '', column8: "",
        _children: [
            {
                column1: 'Project: Mayan',
                column2: '',
                column3: "Unity Type: 2BHK + M",
                column4: "",
                column5: 'Created Date & Time: 15.00-22/01/2022',
                column6: 'Promotion: Q4 Summer Promo Summer 2021',
                column7: '', column8: "",
            },
        ],
    },
];