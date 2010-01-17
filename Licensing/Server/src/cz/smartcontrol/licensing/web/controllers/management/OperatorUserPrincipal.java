package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.domain.Operator;

/**
 *
 * @author slovak
 */
public class OperatorUserPrincipal {
    
    public static final String SESSION_NAME = "operatorUserPrincipal";
    
    private Operator operator;
    
    public void login(Operator operator) {
        this.operator = operator;
    }
    
    public void logout() {
        operator = null;
    }
    
    public boolean isUserLoggedIn() {
        return (operator != null);
    }
    
    public Operator getOperator() {
        return operator;           
            
    }
    
}
