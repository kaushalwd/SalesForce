/**
 * Wording of the Send UAE KYC (Relix) action. Kept in one module so it can move to Custom Labels later
 * without touching the component logic. Relix plan R1/R2 (docs/relix), MODON Dev, 25 Sep 2026.
 */
const LABELS = {
    title: 'Send UAE KYC (Relix)',
    working: 'Working',
    close: 'Close',
    refresh: 'Refresh',
    resend: 'Resend',
    sendAnyway: 'Send anyway',
    live: 'Live link',
    loading: 'Checking this account…',
    disabled:
        'Relix KYC is not switched on in this org, so nothing was sent. Use Send KYC Form for now, or ask your administrator.',
    sentTitle: 'UAE KYC link requested',
    sentMessage: 'UAE KYC link requested; Relix will email {0}.',
    theBuyer: 'the buyer',
    problemsIntro: 'Nothing was sent. Please fix the following and try again:',
    casesTitle: 'Current Relix cases',
    noCases: 'This account has no Relix case yet.',
    kycActive: "This buyer's KYC is still active.",
    signzyLive: 'A Signzy KYC link is still live for this buyer.',
    resendWarning:
        'Sending again emails the buyer a second link. An earlier link cannot be cancelled.',
    statusLabel: 'Status',
    sentLabel: 'Sent',
    validUntilLabel: 'Link valid until',
    reasonLabel: 'Reason',
    lastCheckedLabel: 'Last checked',
    errorTitle: 'Send UAE KYC (Relix)',
    genericError: 'Something went wrong. Please try again, or ask your administrator.'
};

export default LABELS;