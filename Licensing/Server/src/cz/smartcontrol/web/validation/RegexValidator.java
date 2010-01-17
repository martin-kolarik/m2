/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.web.validation;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 *
 * @author Martin
 */
public class RegexValidator implements Validator {

    private Pattern pattern;
    
    public RegexValidator( String pattern ) {

         this.pattern = Pattern.compile( pattern );
    }
    
    public boolean supports( Class target ) {

        return String.class.isAssignableFrom( target );
    }
    
    public boolean validate( Object target ) {
        
        if( target == null || !supports( target.getClass())) {
            return false;
        }
        
        Matcher matcher = pattern.matcher( (String)target );
        return matcher.matches();
    }

}
