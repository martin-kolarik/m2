/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.web.session;

import cz.smartcontrol.query.Pager;
import cz.smartcontrol.licensing.web.commands.ProductsCommand;
import javax.servlet.http.HttpSession;
import org.springframework.ui.Model;

/**
 *
 * @author Martin
 */
public class ProductsBacking {

    private static final String NAME_SELF = "customersBacking";
    private static final String NAME_PAGER = "pager";
    private static final String NAME_ORDER_KEYS = "orderKeys";

    private static final String[] ORDERING_WEB_KEYS = { "phoneNumber", "added" };
    private static final String[] ORDERING_PROPERTY_NAMES = { "customer.phoneNumber", "customer.parentSet" };

    private Pager pager;
    private ProductsCommand productsCommand;

    public static ProductsBacking getInstance( HttpSession session ) {
        
        ProductsBacking customersBacking = (ProductsBacking)session.getAttribute( NAME_SELF );
        if( customersBacking == null ) {
            customersBacking = new ProductsBacking();
            session.setAttribute( NAME_SELF, customersBacking );
        }
        return customersBacking;
    }
    
    private ProductsBacking() {
        
        productsCommand = new ProductsCommand();

        pager = new Pager();
        pager.setPageSize( 20 );
        pager.setupWebRequestOrdering( ORDERING_WEB_KEYS, ORDERING_PROPERTY_NAMES );
        pager.updateByWebRequest( null, null, "added" );
    }
    
    public void bindToModel( Model model ) {
        model.addAttribute( NAME_PAGER, pager );
        model.addAttribute( NAME_ORDER_KEYS, ORDERING_WEB_KEYS );
    }

    public Pager getPager() {
        return pager;
    }

    public ProductsCommand getProductsCommand() {
        return productsCommand;
    }
    
}
