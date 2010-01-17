package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.web.tools.CsvProvider;
import javax.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

/**
 *
 * @author strzinek
 */
@Controller
@RequestMapping("/management/report.csv")
public class Report implements OperatorSecuredArea {
    
    @Autowired
    private CsvProvider csvProvider;
    
    @RequestMapping(method = RequestMethod.GET)
    public String report(Model model, HttpSession session) {

        // TicketReportCommand csvReportData = (TicketReportCommand)session.getAttribute("csvReportData");
        // if (csvReportData == null)
        // {
        //     return "redirect:/management/management.do";
        // }
            
        model.addAttribute("csvProvider", csvProvider);
        // model.addAttribute("csvReportData", csvReportData);
        return "management/report";
    }
}