/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.web.session;

import cz.smartcontrol.query.Pager;
import cz.smartcontrol.licensing.web.commands.LicenceCommand;
import javax.servlet.http.HttpSession;
import org.springframework.ui.Model;

/**
 *
 * @author Martin
 */
public class TicketsBacking {

    private static final String NAME_SELF = "ticketsBacking";
    private static final String NAME_PAGER = "pager";
    private static final String NAME_ORDER_KEYS = "orderKeys";

    private static final String[] ORDERING_WEB_KEYS = { "number", "type", "from", "to", "price", "bill" };
    private static final String[] ORDERING_PROPERTY_NAMES = { "ticket.phoneNumber", "", "ticket.validFrom", "ticket.validTo", "ticket.price", "" };

    private Pager pager;
    private LicenceCommand ticketsCommand;

    public static TicketsBacking getInstance( HttpSession session ) {
        
        TicketsBacking ticketsBacking = (TicketsBacking)session.getAttribute( NAME_SELF );
        if( ticketsBacking == null ) {
            ticketsBacking = new TicketsBacking();
            session.setAttribute( NAME_SELF, ticketsBacking );
        }
        return ticketsBacking;
    }
    
    private TicketsBacking() {
        
        ticketsCommand = new LicenceCommand();

        pager = new Pager();
        pager.setPageSize( 20 );
        pager.setupWebRequestOrdering( ORDERING_WEB_KEYS, ORDERING_PROPERTY_NAMES );
        pager.updateByWebRequest( null, null, "from.desc" );
    }
    
    public void bindToModel( Model model ) {
        model.addAttribute( NAME_PAGER, pager );
        model.addAttribute( NAME_ORDER_KEYS, ORDERING_WEB_KEYS );
    }

    public Pager getPager() {
        return pager;
    }

    public LicenceCommand getTicketsCommand() {
        return ticketsCommand;
    }
    
}
