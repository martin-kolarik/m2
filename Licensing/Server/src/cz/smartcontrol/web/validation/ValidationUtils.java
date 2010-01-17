/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

import org.springframework.validation.Errors;

/**
 *
 * @author Martin
 */
public class ValidationUtils extends org.springframework.validation.ValidationUtils {
    
    private static IntValidator intValidator = new IntValidator();
    
    private static DecimalValidator decimalValidator = new DecimalValidator();
    
    private static EmailValidator emailValidator = new EmailValidator();
    
    private static PhoneNumberValidator phoneNumberValidator = new PhoneNumberValidator();
    
    private static AccountNumberValidator accountNumberValidator = new AccountNumberValidator();
    
    public static boolean validateLength( Errors errors, int minLength, int maxLength, String field, String errorMessageKey ) {
        
        Object data = errors.getFieldValue( field );
        if( data == null ) {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }

        int length = data.toString().length();
        if( length < minLength || length > maxLength ) {
            errors.rejectValue( field, errorMessageKey );
            return false;
        } else {
            return true;
        }
    }
    
    public static boolean validateInt( Errors errors, String field, String errorMessageKey ) {

        if( intValidator.validate( errors.getFieldValue( field ))) {
            return true;
        } else {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }
    }
        
    public static boolean validateDecimal( Errors errors, String field, String errorMessageKey ) {

        if( decimalValidator.validate( errors.getFieldValue( field ))) {
            return true;
        } else {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }
    }
        
    public static boolean validateEmail( Errors errors, String field, String errorMessageKey ) {
        
        if( emailValidator.validate( errors.getFieldValue( field ))) {
            return true;
        } else {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }
    }
    
    public static boolean validatePhoneNumber( Errors errors, String field, String errorMessageKey ) {

        if( phoneNumberValidator.validate( errors.getFieldValue( field ))) {
            return true;
        } else {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }
    }
    
    public static boolean validateAccountNumber( Errors errors, boolean allowEmpty, String field, String errorMessageKey ) {

        Object value = errors.getFieldValue( field );
        if( allowEmpty && ( value == null || value.toString().equals("")) ) {
            return true;
        } else if( accountNumberValidator.validate( value )) {
            return true;
        } else {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }
    }
        
    public static boolean validateRegexp( Errors errors, String pattern, String field, String errorMessageKey ) {

        RegexValidator regexValidator = new RegexValidator( pattern );
        if( regexValidator.validate( errors.getFieldValue( field ))) {
            return true;
        } else {
            errors.rejectValue( field, errorMessageKey );
            return false;
        }
    }
        
}
