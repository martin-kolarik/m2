/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.web.session;

import cz.smartcontrol.query.Pager;
import cz.smartcontrol.licensing.web.commands.ManufacturersCommand;
import javax.servlet.http.HttpSession;
import org.springframework.ui.Model;

/**
 *
 * @author Martin
 */
public class ManufacturersBacking {

    private static final String NAME_SELF = "manufacturersBacking";
    private static final String NAME_PAGER = "pager";
    private static final String NAME_ORDER_KEYS = "orderKeys";

    private static final String[] ORDERING_WEB_KEYS = { "phoneNumber" };
    private static final String[] ORDERING_PROPERTY_NAMES = { "manufacturer.phoneNumber" };

    private Pager pager;
    private ManufacturersCommand manufacturersCommand;

    public static ManufacturersBacking getInstance( HttpSession session ) {
        
        ManufacturersBacking manufacturersBacking = (ManufacturersBacking)session.getAttribute( NAME_SELF );
        if( manufacturersBacking == null ) {
            manufacturersBacking = new ManufacturersBacking();
            session.setAttribute( NAME_SELF, manufacturersBacking );
        }
        return manufacturersBacking;
    }
    
    private ManufacturersBacking() {
        
        manufacturersCommand = new ManufacturersCommand();

        pager = new Pager();
        pager.setPageSize( 20 );
        pager.setupWebRequestOrdering( ORDERING_WEB_KEYS, ORDERING_PROPERTY_NAMES );
        pager.updateByWebRequest( null, null, "phoneNumber" );
    }
    
    public void bindToModel( Model model ) {
        model.addAttribute( NAME_PAGER, pager );
        model.addAttribute( NAME_ORDER_KEYS, ORDERING_WEB_KEYS );
    }

    public Pager getPager() {
        return pager;
    }

    public ManufacturersCommand getManufacturersCommand() {
        return manufacturersCommand;
    }
    
}
