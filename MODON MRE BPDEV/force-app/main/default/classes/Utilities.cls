/**********************************************************************************************************************
* Name               : Utilities
* Description        : Generic utility helper class for translation and calculation tasks.
* Usage              : Called from controllers/services to format amounts into text representation.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           ActiveMinds      02 Jun 2026     Initial Draft
* 1.1           Narendra Agrawal 29 Jun 2026     Updated amountInWords to pass amount value to NumberToText as String to avoid Integer overflow
******************************************************************************************************************/
public with sharing class Utilities {
    /* amountInWords 
    *
    * This method is used to convert the amount into text
    * 
    * @usage opportunityUnitSearchController
    *
    * @param amount    amount to be converted
    * @param currencyUnit   primary currency unit
    * @param currencySubUnit    secondary unit/subunit
    * @return   string amount in words
    */
    public static string amountInWords(decimal amount, string currencyUnit, String currencySubUnit){
        String amountInWords = '';
        if(amount !=null){
            Decimal totalAmount = amount.setScale(2) ;
            String totalAmountString = String.valueOf(totalAmount);
            String beforeDecimal='';
            String afterDecimal='';
            
            //v1.1 START
            if(totalAmountString.contains('.')){
                //Passing amount value into String instead of converting into Integer. Parsing into Integer gets failed when amount value is too big and outside
                //Integer value range.
                beforeDecimal = NumberToText.convert(totalAmountString.substringBefore('.'));
                afterDecimal = NumberToText.convert(totalAmountString.substringAfter('.'));
            }else{
                beforeDecimal = NumberToText.convert(totalAmountString);
            }
            //v1.1 END
            
            if(String.isNotBlank(beforeDecimal)){
                amountInWords =  beforeDecimal + ' '+currencyUnit+' ';
            }
            if(String.isNotBlank(afterDecimal) && afterDecimal !='Zero'){
                amountInWords = amountInWords + 'and ' +afterDecimal + ' '+currencySubUnit+' ';
            }
            amountInWords = amountInWords +'Only' ;
        }
        return amountInWords.toUpperCase();
    }
}