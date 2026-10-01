import { UNIT_SEARCH_BASE_COLUMNS } from "c/modonEgyptConstants";

export const CONSTANTS = {
  EMPTY_STRING: '',

  FLEX_PLAN_AMOUNT_TOLERANCE: 0.01,

  FLEX_PLAN_COLUMNS: [
    ...UNIT_SEARCH_BASE_COLUMNS,
    {
      label: 'QTR',
      fieldName: 'quarter',
      type: 'number',
      hideDefaultActions: true
    },
    {
      label: 'PV Factor',
      fieldName: 'pvFactor',
      type: 'number',
      typeAttributes: {
        maximumFractionDigits: '4',
        minimumFractionDigits: '4'
    },
      hideDefaultActions: true
    },
    {
      label: 'PV Amount',
      fieldName: 'pvAmountText',
      type: 'text',
      hideDefaultActions: true
    }
  ],

  FLEX_PLAN_SPINNER_ALT_CALCULATING: 'Calculating Plan',

  FLEX_PLAN_METHOD_LABEL_BY_AMOUNT: 'By Fixed Installment Amount',
  FLEX_PLAN_METHOD_LABEL_BY_YEARS: 'By Fixed Duration (Years)',
  FLEX_PLAN_METHOD_LABEL_BY_INSTALLMENTS: 'By Fixed Installment Count',

  FLEX_PLAN_METHOD_VALUE_AMOUNT: 'By Amount',
  FLEX_PLAN_METHOD_VALUE_YEARS: 'By Years',
  FLEX_PLAN_METHOD_VALUE_INSTALLMENTS: 'By Installments',

  FLEX_PLAN_FREQUENCY_OPTIONS: [
    { label: 'Quarterly', value: 'Quarterly' },
    { label: 'Semi-Annual', value: 'Semi-Annual' },
    { label: 'Annual', value: 'Annual' }
  ],

  FLEX_PLAN_MAINTENANCE_MAX_STARTING_INSTALLMENT_BY_FREQ: {
    'Quarterly': 32,
    'Semi-Annual': 16,
    'Annual': 8
  },

  FLEX_PLAN_FREQUENCY_QUARTERLY: 'Quarterly',

  FLEX_PLAN_LABEL_CURRENCY: 'Currency',
  FLEX_PLAN_LABEL_INSTALLMENT_FREQUENCY: 'Installment Frequency',
  FLEX_PLAN_LABEL_DOWN_PAYMENT_MODE: 'Down Payment Mode',
  FLEX_PLAN_LABEL_DOWN_PAYMENT_PERCENT: 'Down Payment (%)',
  FLEX_PLAN_LABEL_DOWN_PAYMENT_AMOUNT: 'Down Payment Amount',
  FLEX_PLAN_DOWN_PAYMENT_MODE_PERCENT: 'Percent',
  FLEX_PLAN_DOWN_PAYMENT_MODE_AMOUNT: 'Amount',
  FLEX_PLAN_DOWN_PAYMENT_MODE_OPTIONS: [
    { label: 'Downpayment %', value: 'Percent' },
    { label: 'Downpayment Amount', value: 'Amount' }
  ],
  FLEX_PLAN_LABEL_EXACT_BOOKING_DATE: 'Exact Booking Date',
  FLEX_PLAN_LABEL_MAINTENANCE_STARTING_INSTALLMENT: 'Maintenance Starting Installment Number',
  FLEX_PLAN_LABEL_TOTAL_MAINTENANCE_INSTALLMENT_COUNT: 'Total Count of Maintenance Installment',

  FLEX_PLAN_LABEL_EACH_INSTALLMENT_AMOUNT: 'Each Installment Amount',
  FLEX_PLAN_LABEL_TOTAL_NUMBER_OF_YEARS: 'Total Number of Years',
  FLEX_PLAN_LABEL_TOTAL_INSTALLMENT_COUNT: 'Total Installment Count',
  FLEX_PLAN_LABEL_MAINTENANCE_PERCENTAGE: 'Maintenance Percentage (%)',

  FLEX_PLAN_BUTTON_LABEL_GENERATE: 'Generate Payment Plan',

  FLEX_PLAN_CARD_TITLE_UNIT_BASE_PRICE_8_YEARS: 'Unit Base Price (8 Years)',
  FLEX_PLAN_CARD_TITLE_TOTAL_PAYABLE_AMOUNT: 'Total Payable Amount',
  FLEX_PLAN_CARD_TITLE_DISCOUNT_VS_8_YEAR: 'Discount (vs 8-Year Plan)',
  FLEX_PLAN_CARD_TITLE_PRESENT_VALUE: 'Present Value (PV)',
  FLEX_PLAN_CARD_TITLE_TOTAL_MAINTENANCE_AMOUNT: 'Total Maintenance Amount',

  FLEX_PLAN_TABLE_HEADER_INSTALLMENT_NUM: 'Installment #',
  FLEX_PLAN_TABLE_HEADER_MILESTONE: 'Milestone',
  FLEX_PLAN_TABLE_HEADER_INSTALLMENT_PCT: 'Installment Percentage',
  FLEX_PLAN_TABLE_HEADER_MAINTENANCE_FEES: 'Maintenance Fees',
  FLEX_PLAN_TABLE_HEADER_INSTALLMENT_AMOUNT: 'Installment Amount',
  FLEX_PLAN_TABLE_HEADER_QTR: 'QTR',
  FLEX_PLAN_TABLE_HEADER_PV_FACTOR: 'PV Factor',
  FLEX_PLAN_TABLE_HEADER_PV_AMOUNT: 'PV Amount',
  FLEX_PLAN_TABLE_HEADER_INSTALLMENT_DATE: 'Installment Date',

  FLEX_PLAN_PLAN_TYPE_FLEXIBLE: 'Flexible',


  FLEX_PLAN_CURRENCY_EGP: 'EGP',
  FLEX_PLAN_CURRENCY_USD: 'USD',
  FLEX_PLAN_CURRENCY_AED: 'AED',

  FLEX_PLAN_NUMBER_4: '4',
  FLEX_PLAN_NUMBER_8: '8',
  FLEX_PLAN_NUMBER_32: '32',
  FLEX_PLAN_NUMBER_10: '10',

  // Events shared with Payment Plan Manager
  FLEX_PLAN_EVENT_PROCEED_BUTTON_DISABLE: 'disableproceedbuttonevent',
  FLEX_PLAN_EVENT_FLEX_PLAN_READY: 'flexibleplanready',

  FLEX_PLAN_ERROR_FALLBACK_MSG: 'Unknown Error',
  FLEX_PLAN_ERROR_TITLE_GENERATE: 'Error Generating Flexible Payment Plan',
  FLEX_PLAN_ERROR_GET_ACTIVE_CURRENCIES_TITLE: 'Error Getting Active CurrencyIsoCodes.',
  FLEX_PLAN_ERROR_INVALID_DP_INPUT_TITLE: 'Invalid Down Payment %',
  FLEX_PLAN_ERROR_INVALID_DP_INPUT_MESSAGE: 'Please enter the Down Payment Percentage between 1% and 100%.',
  FLEX_PLAN_ERROR_INVALID_DP_INPUT_RANGE_MESSAGE: 'Please enter the Down Payment percentage between {0}% and {1}%.',
  FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_TITLE: 'Invalid Down Payment Amount',
  FLEX_PLAN_ERROR_INVALID_DP_AMOUNT_INPUT_MESSAGE: 'Please enter the Down Payment Amount greater than zero.',
  FLEX_PLAN_ERROR_INVALID_MIN_DP_AMOUNT_INPUT_MESSAGE: 'Please enter the Down Payment amount greater than or equal to {0} for {1}.',
  FLEX_PLAN_ERROR_LOAD_DP_BENCHMARKS_TITLE: 'Error loading standard down payment',
  FLEX_PLAN_ERROR_INVALID_AMOUNT_INPUT_TITLE: 'Invalid Each Installment Amount',
  FLEX_PLAN_ERROR_INVALID_AMOUNT_INPUT_MESSAGE: 'Please enter the Each Installment Amount greater than 0.',
  FLEX_PLAN_ERROR_INVALID_NUM_OF_YEARS_INPUT_TITLE: 'Invalid Total Number of Years',
  FLEX_PLAN_ERROR_INVALID_NUM_OF_YEARS_INPUT_MESSAGE: 'Please enter the Total Number of Years greater than 0.',
  FLEX_PLAN_ERROR_INVALID_NUM_OF_INSTALL_INPUT_TITLE: 'Invalid Total Installment Count',
  FLEX_PLAN_ERROR_INVALID_NUM_OF_INSTALL_INPUT_MESSAGE: 'Please enter the Total Installment Count greater than 0.',
  FLEX_PLAN_ERROR_INVALID_CURRENCY_INPUT_TITLE: 'Invalid Currency',
  FLEX_PLAN_ERROR_INVALID_CURRENCY_INPUT_MESSAGE: 'Please select the Currency from dropdown.',
  FLEX_PLAN_ERROR_INVALID_FREQUENCY_INPUT_TITLE: 'Invalid Frequency',
  FLEX_PLAN_ERROR_INVALID_FREQUENCY_INPUT_MESSAGE: 'Please select the Frequency from dropdown.',
  FLEX_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_TITLE: 'Invalid Exact Booking Date',
  FLEX_PLAN_ERROR_INVALID_EXACT_BOOKING_DATE_INPUT_MESSAGE: 'Please enter the Exact Booking Date of Today or in the past.',
  FLEX_PLAN_ERROR_INVALID_MAINT_START_TITLE: 'Invalid Maintenance Starting Installment',
  FLEX_PLAN_ERROR_INVALID_MAINT_START_MESSAGE: 'Please enter a whole number from 1 to {0} for the selected payment frequency.',
  FLEX_PLAN_ERROR_INVALID_MAINT_COUNT_TITLE: 'Invalid Maintenance Installment Count',
  FLEX_PLAN_ERROR_INVALID_MAINT_COUNT_MESSAGE: 'Please enter a whole number from 1 to {0}.',
};