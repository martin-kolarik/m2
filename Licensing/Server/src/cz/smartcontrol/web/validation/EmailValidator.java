/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

/**
 *
 * @author Martin
 */
public class EmailValidator extends RegexValidator {
    
    public EmailValidator() {

        super( ".+@.+\\.[a-zA-Z]{2,}" );
    }
    
}
