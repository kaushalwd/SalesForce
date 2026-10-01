/**
 * RelixSignalTrigger - hands Relix_Signal__e events to RelixSignalHandler.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. One line by design: all logic and all tests live in
 *                                    the handler.
 */
trigger RelixSignalTrigger on Relix_Signal__e (after insert) {
    RelixSignalHandler.handle(Trigger.new);
}