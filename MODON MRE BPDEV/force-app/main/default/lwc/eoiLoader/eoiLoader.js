/**
 * eoiLoader — the EOI site's one busy indicator: the Modon O as a vector
 * spinner on a blocking overlay (same mark as the console's mscLoader, in the
 * site's light palette). Blocking is the point: while any server call is in
 * flight no button anywhere on the page can start a second process. Owns no
 * state; the host mounts and unmounts it on its busy flag.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiLoader extends LightningElement {
    /** Optional. A long wait should say what it is doing. */
    @api label;
}