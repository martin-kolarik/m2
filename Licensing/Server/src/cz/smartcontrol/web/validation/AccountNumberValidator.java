/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

/**
 *
 * @author Martin
 */
public class AccountNumberValidator extends RegexValidator {
    
    public AccountNumberValidator() {

        super( "(\\d+-)?\\d+/\\d{4}" );
    }

}
