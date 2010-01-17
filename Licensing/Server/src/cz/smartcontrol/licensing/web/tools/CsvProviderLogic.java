package cz.smartcontrol.licensing.web.tools;

import cz.smartcontrol.licensing.business.facade.LicenceFacade;
import cz.smartcontrol.query.Pager;
import java.io.Writer;
import java.text.SimpleDateFormat;
import java.util.List;
import org.springframework.beans.BeansException;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;

/**
 *
 * @author phrncarek
 */
public class CsvProviderLogic implements CsvProvider, ApplicationContextAware {
    
    private ApplicationContext ctx;
    
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        this.ctx = applicationContext;
    }
    
    public void printCsv(Writer out, Object reportData) throws Exception
    {
        LicenceFacade licenceLogic = (LicenceFacade) ctx.getBean("licenceLogic");
        
        // header
        out.write("ticket_id;phone_number;valid_from;valid_to;price_czk;control_code;hash;incoming_sms_id;outgoing_sms_id\r\n");

        Pager pager = new Pager();
        pager.setPageSize( 1000 );
        pager.setDaoOrderBy(new String[]{ "ticket.validFrom" } );

        for(;;) {
            // List<TicketExport> tickets =
            //     tickets = (List<TicketExport>)ticketLogic.getTickets( reportData.getFilter(), pager ).getData();
            // flushTickets( out, tickets );

            if( pager.getIsOnEnd()) {
                break;
            }
            pager.setDaoPage(pager.getDaoPage()+1);
        }
    }
    
/*    
    private void flushTickets( Writer out, List<TicketExport> tickets ) throws Exception {

        SimpleDateFormat dfShort = new SimpleDateFormat("yyyy-MM-dd HH:mm");
        SimpleDateFormat dfLong = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        
        if (tickets != null) {
            for (TicketExport ticket : tickets) {
                out.write(""
                         +ticket.getTicketId()+";"
                         +"\""+ticket.getPhoneNumber()+"\";"
                         +dfShort.format(ticket.getRawValidFrom())+";"
                         +dfShort.format(ticket.getRawValidTo())+";"
                         +""+ticket.getPrice()+";"
                         +"\""+ticket.getCode()+"\";"
                         +"\""+ticket.getHash()+"\";"
                         +""+(ticket.getIncomingSms()==null ? "null" : ticket.getIncomingSms().getIncomingSmsId())+";"
                         +""+(ticket.getOutgoingSms()==null ? "null" : ticket.getOutgoingSms().getOutgoingSmsId())
                         +"\r\n");
            }
            out.flush();
        }
    }
*/

}
