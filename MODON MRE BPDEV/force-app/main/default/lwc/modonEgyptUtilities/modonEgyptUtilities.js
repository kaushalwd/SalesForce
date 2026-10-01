/**
* @description       : Generic Utilities for Modon Egypt LWCs
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 03-03-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   03-03-2026   Milin Kapatel      Initial Version
* 1.1   14-04-2026   Milin Kapatel      Imported Constants from constant file
**/
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CONSTANTS } from 'c/modonEgyptConstants';



const DEBOUNCERS = {};
export const showSuccessToast = (title, message) => {
    dispatchEvent(
        new ShowToastEvent({
            title: title,
            message: message,
            variant: 'success',
        })
    );
}

export const showErrorToast = (title, message) => {
    dispatchEvent(
        new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error',
            mode: CONSTANTS.MANAGE_INVENTORY_TOAST_STICKY
        })
    );
}

export const isArrayEmpty = (arr) => {
    return !(arr) || arr?.length === 0;
}

export const isArrayNotEmpty = (arr) => {
    return arr && arr?.length > 0;
}

export const isStringEqual = (str, otherStr) => {
    return str === otherStr || str == otherStr; 
}

export const isStringEmpty = (str) => {
    return str === null || str === undefined || str?.length === 0;
}

export const isStringContainsIgnoreCase = (str, otherStr) => {
    return str?.toString()?.toLowerCase()?.includes(otherStr);
}

export const debounce = (key, func, delay) => {
    clearTimeout(DEBOUNCERS[key]);
    DEBOUNCERS[key] = setTimeout(func, delay);
}


export const processBucketRecords = (records) => {
    if (!Array.isArray(records)) {
        return;
    }

    const seenAccounts = new Map();
    const output = [];
    let idx = 0;

    for (const rec of records) {
        // defensive access: handle both rec.Account and rec.Account?.Name
        const accountName = rec && rec.Account && rec.Account.Name ? String(rec.Account.Name).trim() : null;

        if (accountName) {
            const key = accountName.toLowerCase();
            if (!seenAccounts.has(key)) {
                // first time we see this account name: push a grouped item
                output.push({
                    Name: accountName,
                    Id: rec.Id || null,
                    userId: rec.Id || null,
                    profileName: rec?.Profile?.Name || CONSTANTS.EMPTY_STRING,
                    _key: `acct-${idx++}-${_safeKey(accountName)}`
                });
                seenAccounts.set(key, true);
            }
        } else {
            // no account name: keep the record as-is (display original Name)
            output.push({
                ...rec,
                _key: `rec-${idx++}-${_safeKey(rec && rec.Id ? rec.Id : Math.random())}`
            });
        }
    }

    return output;
}

// helper to sanitize keys for uniqueness and readability
const _safeKey = (value) => {
    return String(value).replace(/\s+/g, '-').replace(/[^a-zA-Z0-9-_]/g, CONSTANTS.EMPTY_STRING).toLowerCase();
}