/**********************************************************************************************************************
* Name               : TriggerControl                                                        
* Description        : This class contains main Bypass the triiger methods 
* Usage              : Used across Triggers and classes.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                   Date            Comment                                                                       
* 1.0           Manoj   	            20 Feb 2026     Initial Draft       
* 2.0			Manoj					10 Feb 2026		Update Bypass
* 3.0			Manoj					10 May 2026		add Account Bypass
* 4.0			Manoj					27 Jun 2026		Add Status Update
***********************************************************************************************************************/
public class TriggerControl {
    public static Boolean bypassTransferTrigger = false;
    public static Boolean BypassCancelledTrigger = false; // 2.0
    public static Boolean BypassAccountTrigger = false; // 3.0
	public static Boolean bypassReceiptStatus =false; //4.0
    public static Boolean bypassReceiptTrigger = false; //5.0
}