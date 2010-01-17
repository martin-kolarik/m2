/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

/**
 *
 * @author Martin
 */
public interface Validator {

    public boolean supports( Class target );
    
    public boolean validate( Object target );

}
