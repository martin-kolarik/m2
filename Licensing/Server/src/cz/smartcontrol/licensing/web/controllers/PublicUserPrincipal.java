package cz.smartcontrol.licensing.web.controllers;

import cz.smartcontrol.licensing.domain.Customer;

/**
 *
 * @author phrncarek
 */
public class PublicUserPrincipal {
    
    public static final String SESSION_NAME = "userPrincipal";
    
    private Customer customer;
    
    public void login(Customer customer) {
        this.customer = customer;
    }
    
    public void logout() {
        customer = null;
    }
    
    public boolean isUserLoggedIn() {
        return (customer != null);
    }
    
    public Customer getCustomer() {
        return customer;           
            
    }
        
}
