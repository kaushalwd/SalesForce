trigger UserTrigger on User (after insert, after update) {
    try {
        new UserTriggerHandler().run('User');} catch(Exception e) {throw e;}
}