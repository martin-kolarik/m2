/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.web.session;

import cz.smartcontrol.query.Pager;
import cz.smartcontrol.licensing.web.commands.ProductsVersionCommand;
import javax.servlet.http.HttpSession;
import org.springframework.ui.Model;

/**
 *
 * @author Martin
 */
public class ProductsVersionBacking {

    private static final String NAME_SELF = "controllerDetailBacking";
    private static final String NAME_PAGER = "pager";
    private static final String NAME_ORDER_KEYS = "orderKeys";

    private static final String[] ORDERING_WEB_KEYS = {"created", "ticket", "state", "selfsms", "checksms"};
    private static final String[] ORDERING_PROPERTY_NAMES = {"check.created", "ticket.phoneNumber", "check.status", "", "" };

    private Pager pager;
    private ProductsVersionCommand command;

    public static ProductsVersionBacking getInstance( HttpSession session ) {
        
        ProductsVersionBacking timeReportBacking = (ProductsVersionBacking)session.getAttribute( NAME_SELF );
        if( timeReportBacking == null ) {
            timeReportBacking = new ProductsVersionBacking();
            session.setAttribute( NAME_SELF, timeReportBacking );
        }
        return timeReportBacking;
    }
    
    private ProductsVersionBacking() {

        command = new ProductsVersionCommand();

        pager = new Pager();
        pager.setPageSize( 20 );
        pager.setupWebRequestOrdering( ORDERING_WEB_KEYS, ORDERING_PROPERTY_NAMES );
        pager.updateByWebRequest( null, null, "created.desc" );
    }

    public ProductsVersionCommand getProductVersionsCommand() {
        return command;
    }
    
    public void bindToModel( Model model ) {
        model.addAttribute( NAME_PAGER, pager );
        model.addAttribute( NAME_ORDER_KEYS, ORDERING_WEB_KEYS );
    }

    public Pager getPager() {
        return pager;
    }
    
}
