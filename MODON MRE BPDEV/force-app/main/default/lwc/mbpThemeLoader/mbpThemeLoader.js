/**
 * mbpThemeLoader
 * Shared utility that loads the Modon design system stylesheet into a
 * caller component's shadow root. Each mbp_* LWC calls:
 *
 *   import { loadTheme } from 'c/mbpThemeLoader';
 *   ...
 *   connectedCallback() {
 *     loadTheme(this);
 *     // existing init...
 *   }
 *
 * No state, no DOM, no logic — purely a thin helper.
 */
import { loadStyle } from 'lightning/platformResourceLoader';
import mbpDesignSystem from '@salesforce/resourceUrl/mbpDesignSystem';

let promiseCache = new WeakMap();

export function loadTheme(component) {
    if (!component) return Promise.resolve();
    if (promiseCache.has(component)) return promiseCache.get(component);
    const p = loadStyle(component, mbpDesignSystem + '/mbpDesignSystem.css')
        .catch(e => {
            // eslint-disable-next-line no-console
            console.error('[mbpThemeLoader] Failed to load design system:', e);
        });
    promiseCache.set(component, p);
    return p;
}