package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.domain.Operator;
import cz.smartcontrol.licensing.domain.OperatorType;
import javax.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.SessionAttributes;

/**
 *
 * @author strzinek
 */
@Controller
@SessionAttributes( TicketReport.NAME_REPORT_DATA )
public class TicketReport implements OperatorSecuredArea {
    
    public static final String NAME_REPORT_DATA = "ticketReportData";
    public static final String NAME_DETAIL_DATA = "ticket";
    public static final String NAME_DETAIL_EVENTS = "events";
    
    @RequestMapping( value = "/management/csvexport.do", method = RequestMethod.POST )
    public String csvExport(HttpSession session, Model model, @ModelAttribute( NAME_REPORT_DATA ) /*TicketReportCommand*/ Object command, BindingResult result) throws Exception {

        // validate operator's permissions
        Operator op=getOperator(session);
        if( op.getType() != OperatorType.MANUFACTURER  ) {
            return "redirect:/management/ticketreport.do";
        }
            
        // new TicketReportValidator().validate(command, result);
        if( result.hasErrors()) {
            model.addAttribute( OperatorUserPrincipal.SESSION_NAME, session.getAttribute(OperatorUserPrincipal.SESSION_NAME));
            return "management/ticketreport";
        } else {
            // session.setAttribute("csvReportData", command );
            return "redirect:/management/report.csv";
        }
    }

//--------------------------------------------------------------------------------

    private Operator getOperator( HttpSession session ) {
        return ((OperatorUserPrincipal)session.getAttribute( OperatorUserPrincipal.SESSION_NAME )).getOperator();
    }
    
}
