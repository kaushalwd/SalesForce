/**
 * RelixBatchErrorTrigger - hands BatchApexErrorEvent messages to RelixDocumentBatch.onBatchErrors, so a
 * document download that died on an uncatchable limit counts an attempt instead of being retried for ever.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Review fix L-01 (docs/relix). One line by design: the handler ignores events of
 *                                    every batch class but RelixDocumentBatch, and holds all logic and tests.
 */
trigger RelixBatchErrorTrigger on BatchApexErrorEvent (after insert) {
    RelixDocumentBatch.onBatchErrors(Trigger.new);
}