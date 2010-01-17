package cz.smartcontrol.licensing.dao;

/**
 *
 * @author phrncarek
 */
public class DataAccessException extends Exception {
    
    public DataAccessException() {
        super();
    }

    public DataAccessException(String message) {
        super(message);
    }
    
    public DataAccessException(Throwable cause) {
        super(cause);
    }
    
    public DataAccessException(String message, Throwable cause) {
        super(message, cause);
    }
    
}
