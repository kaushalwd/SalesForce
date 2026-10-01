import { LightningElement, track, api } from 'lwc';
import { loadTheme } from 'c/mbpThemeLoader';
import getGroundedAIResponse from '@salesforce/apex/MBP_aiClass.getGroundedAIResponse';

// ── Lightweight, safe Markdown → HTML ────────────────────────────────
// Everything is HTML-escaped FIRST, so model output can never inject markup.
// Then we apply a small, known set of markdown constructs.
function esc(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}
function inline(t) {
    return esc(t)
        .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
        .replace(/`([^`]+)`/g, '<code>$1</code>');
}
function splitCells(row) {
    return row.replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
}
function renderTable(rows) {
    if (!rows.length) return '';
    const header = splitCells(rows[0]);
    let start = 1;
    if (rows[1] && /^\|?[\s:|-]+$/.test(rows[1])) start = 2; // skip |:---|---| separator
    let h = '<div class="md-table-wrap"><table class="md-table"><thead><tr>';
    h += header.map((c) => `<th>${inline(c)}</th>`).join('');
    h += '</tr></thead><tbody>';
    for (let r = start; r < rows.length; r++) {
        h += '<tr>' + splitCells(rows[r]).map((c) => `<td>${inline(c)}</td>`).join('') + '</tr>';
    }
    return h + '</tbody></table></div>';
}
function markdownToHtml(raw) {
    const lines = String(raw || '').replace(/\r/g, '').split('\n');
    let html = '';
    let i = 0;
    const isList = (t) => /^[*-]\s+/.test(t);
    const isHead = (t) => /^#{1,6}\s+/.test(t);
    while (i < lines.length) {
        const t = lines[i].trim();
        if (t === '') { i++; continue; }

        // Table
        if (t.startsWith('|')) {
            const tbl = [];
            while (i < lines.length && lines[i].trim().startsWith('|')) { tbl.push(lines[i].trim()); i++; }
            html += renderTable(tbl);
            continue;
        }
        // Heading
        const h = t.match(/^(#{1,6})\s+(.*)/);
        if (h) { html += `<div class="md-h md-h${h[1].length}">${inline(h[2])}</div>`; i++; continue; }
        // Unordered list
        if (isList(t)) {
            const items = [];
            while (i < lines.length && isList(lines[i].trim())) {
                items.push(lines[i].trim().replace(/^[*-]\s+/, ''));
                i++;
            }
            html += '<ul class="md-ul">' + items.map((it) => `<li>${inline(it)}</li>`).join('') + '</ul>';
            continue;
        }
        // Paragraph (gather consecutive plain lines)
        const para = [];
        while (i < lines.length) {
            const lt = lines[i].trim();
            if (lt === '' || lt.startsWith('|') || isList(lt) || isHead(lt)) break;
            para.push(lt);
            i++;
        }
        html += `<p class="md-p">${para.map(inline).join('<br>')}</p>`;
    }
    return html;
}

export default class MbpAiAssistant extends LightningElement {
    @api firstName = 'there';

    @track queryText = '';
    @track messages = [];        // { id, role, text, isUser, isAssistant, html, time }
    @track isLoading = false;
    @track showScrollDown = false;

    // Custom toast (premium) state
    @track showToast = false;
    @track toastMessage = '';
    @track toastType = '';

    _seq = 0;
    _titleTimer;
    _autoScroll = true;          // pin to bottom unless the user scrolls up

    // Quick prompts aligned to what the grounded assistant can actually answer.
    suggestions = [
        { id: '1', label: '⊞  Show my recent leads',      text: 'Show my recent leads and their status' },
        { id: '2', label: '↗  Summarise my pipeline',     text: 'Summarise my opportunities pipeline' },
        { id: '3', label: '$  My commission summary',     text: 'What is my commission summary and payout?' },
        { id: '4', label: '⌂  My agency & agents',        text: 'Show my agency details and my agents' }
    ];

    // ── Derived state ────────────────────────────────────────────────
    get hasConversation() {
        return this.messages.length > 0;
    }
    // Empty state is vertically centered (hero); once a conversation starts the
    // page fills the viewport so the thread grows and the ask bar pins to bottom.
    get pageClass() {
        return this.hasConversation ? 'ai-page ai-page--chat' : 'ai-page';
    }
    get inputDisabled() {
        return this.isLoading;
    }
    get sendDisabled() {
        return this.isLoading || !this.queryText.trim();
    }
    get toastClass() {
        return `mbp-toast mbp-toast--${this.toastType}`;
    }
    get greeting() {
        const h = new Date().getHours();
        if (h < 12) return 'Good morning';
        if (h < 18) return 'Good afternoon';
        return 'Good evening';
    }

    // ── Lifecycle ────────────────────────────────────────────────────
    connectedCallback() {
        loadTheme(this);

        // Reclaim the browser tab title from any Experience Cloud /
        // page-metadata setter that runs after us.
        const targetTitle = 'AI Assistant · Modon Brokers';
        const set = () => { try { if (document.title !== targetTitle) document.title = targetTitle; } catch (e) {} };
        set();
        let i = 0;
        this._titleTimer = setInterval(() => {
            set();
            if (++i > 30) clearInterval(this._titleTimer); // ~6s of guarding
        }, 200);
        document.addEventListener('visibilitychange', set);
    }

    disconnectedCallback() {
        if (this._titleTimer) clearInterval(this._titleTimer);
        if (this._recognition) { try { this._recognition.stop(); } catch (e) {} }
    }

    renderedCallback() {
        // Inject rich (markdown) HTML into assistant bubbles. LWC won't manage
        // the children of an lwc:dom="manual" node, so we set innerHTML once.
        const richNodes = this.template.querySelectorAll('.ai-bubble--rich');
        richNodes.forEach((node) => {
            if (node.dataset.rendered) return;
            const msg = this.messages.find((m) => m.id === node.dataset.id);
            if (msg && msg.html != null) {
                node.innerHTML = msg.html;
                node.dataset.rendered = 'true';
            }
        });

        // Keep the conversation pinned to the latest message — but only if the
        // user hasn't scrolled up to read earlier content.
        const thread = this.template.querySelector('.ai-thread');
        if (thread && this._autoScroll) thread.scrollTop = thread.scrollHeight;
    }

    // ── Input handlers ───────────────────────────────────────────────
    handleInput(e) {
        this.queryText = e.target.value;
    }

    handleKeydown(e) {
        // Enter sends the message.
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            if (this.queryText.trim()) this.handleSend();
        }
    }

    handleChip(e) {
        this.queryText = e.currentTarget.dataset.prompt || '';
        this.handleSend();
    }

    // ── Scroll affordance ────────────────────────────────────────────
    handleThreadScroll(e) {
        const el = e.target;
        const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
        this._autoScroll = nearBottom;
        this.showScrollDown = !nearBottom;
    }

    scrollToBottom() {
        const thread = this.template.querySelector('.ai-thread');
        if (thread) thread.scrollTop = thread.scrollHeight;
        this._autoScroll = true;
        this.showScrollDown = false;
    }

    // ── Core conversation turn ───────────────────────────────────────
    handleSend() {
        const text = this.queryText.trim();
        if (!text) {
            this.showCustomToast('Please enter a question', 'error');
            return;
        }
        if (this.isLoading) return;

        // 1. Capture prior turns BEFORE adding the new message (history for the
        //    GENERAL path; the grounded path ignores it server-side).
        const historyJson = JSON.stringify(
            this.messages.map((m) => ({ role: m.role, text: m.text }))
        );

        // 2. Push the user's message and clear the input.
        this.pushMessage('user', text);
        this.queryText = '';
        this._autoScroll = true;
        this.isLoading = true;

        // 3. Call Apex. The orchestrator classifies intent, fetches the broker's
        //    real records (PII tokenized), grounds Gemini, and restores values.
        getGroundedAIResponse({ question: text, historyJson })
            .then((result) => {
                this.isLoading = false;
                const answer = (result || '').trim();

                if (!answer || answer.startsWith('ERROR:')) {
                    const msg = answer ? answer.replace(/^ERROR:\s*/, '') : 'No response received';
                    this.pushMessage('assistant', 'Sorry — I couldn’t complete that. Please try again.');
                    this.showCustomToast(msg, 'error');
                    return;
                }

                this.pushMessage('assistant', answer);
            })
            .catch((error) => {
                this.isLoading = false;
                // eslint-disable-next-line no-console
                console.error('[mbp_aiAssistant] Apex error:', JSON.stringify(error));
                const msg = error?.body?.message || 'Something went wrong';
                this.pushMessage('assistant', 'Sorry — something went wrong reaching the assistant.');
                this.showCustomToast(msg, 'error');
            });
    }

    // ── Copy an answer to the clipboard ──────────────────────────────
    handleCopy(e) {
        const id = e.currentTarget.dataset.id;
        const msg = this.messages.find((m) => m.id === id);
        if (!msg) return;
        const text = msg.text || '';
        try {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text);
            } else {
                const ta = document.createElement('textarea');
                ta.value = text;
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
            }
            this.showCustomToast('Copied to clipboard', 'success');
        } catch (err) {
            this.showCustomToast('Could not copy', 'error');
        }
    }

    // ── Voice input (Web Speech API) ─────────────────────────────────
    handleVoice() {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition) {
            this.showCustomToast('Voice input is not supported in this browser', 'error');
            return;
        }
        if (this._listening) {
            try { this._recognition.stop(); } catch (e) {}
            return;
        }

        const rec = new SpeechRecognition();
        rec.lang = 'en-US';
        rec.interimResults = false;
        rec.maxAlternatives = 1;

        rec.onresult = (ev) => {
            const transcript = ev.results?.[0]?.[0]?.transcript || '';
            this.queryText = transcript;
        };
        rec.onerror = () => this.showCustomToast('Could not capture audio', 'error');
        rec.onend = () => { this._listening = false; };

        this._recognition = rec;
        this._listening = true;
        try { rec.start(); } catch (e) { this._listening = false; }
    }

    handleAttach() {
        // Attachments are not wired to a backend yet.
        this.showCustomToast('Attachments are coming soon', 'error');
    }

    handleClear() {
        this.messages = [];
        this.queryText = '';
        this.showScrollDown = false;
        this._autoScroll = true;
    }

    // ── Helpers ──────────────────────────────────────────────────────
    pushMessage(role, text) {
        const isUser = role === 'user';
        this.messages = [
            ...this.messages,
            {
                id: `m${this._seq++}`,
                role,
                text,
                isUser,
                isAssistant: !isUser,
                // Assistant replies are rendered as rich (markdown) HTML.
                html: isUser ? null : markdownToHtml(text),
                time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                cssClass: isUser ? 'ai-msg ai-msg--user' : 'ai-msg ai-msg--assistant'
            }
        ];
    }

    showCustomToast(message, type) {
        this.toastMessage = message;
        this.toastType = type;
        this.showToast = true;
        clearTimeout(this._toastTimer);
        this._toastTimer = setTimeout(() => { this.showToast = false; }, 3500);
    }
}