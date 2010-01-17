/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

/**
 *
 * @author Martin
 */
public class IntValidator extends RegexValidator {
    
    public IntValidator() {

        super( "\\d+" );
    }

}
