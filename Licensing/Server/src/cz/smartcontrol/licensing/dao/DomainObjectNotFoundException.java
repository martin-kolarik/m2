package cz.smartcontrol.licensing.dao;

import java.io.Serializable;

/**
 *
 * @author phrncarek
 */
public class DomainObjectNotFoundException extends DataAccessException {
    
    public DomainObjectNotFoundException(Class c, Serializable pk) {
        super("Domain object " + c.getName() + " #" + pk + " cannot be found.");
    }

    public DomainObjectNotFoundException(Class c, String additionalInfo) {
        super("Domain object " + c.getName() + " (" + additionalInfo + ") cannot be found.");
    }
    
}
