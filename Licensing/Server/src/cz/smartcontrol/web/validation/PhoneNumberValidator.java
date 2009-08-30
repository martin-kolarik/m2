/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

/**
 *
 * @author Martin
 */
public class PhoneNumberValidator extends RegexValidator {
    
    public PhoneNumberValidator() {

        super( "\\+[0-9]{9,}" );
    }

}
