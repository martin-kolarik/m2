/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

/**
 *
 * @author Martin
 */
public class DecimalValidator extends RegexValidator {
    
    public DecimalValidator() {
        
        super( "\\d+([\\.,]\\d+)?(E[+-]?\\d+)?" );
    }

}
