package cz.smartcontrol.licensing.dao;

/**
 *
 * @author phrncarek
 */
public class DataIntegrityViolationException extends DataAccessException {
    
    public DataIntegrityViolationException(Throwable cause) {
        super(cause);
    }
    
}
