package cz.smartcontrol.licensing.web.controllers.manufacturer;

import cz.smartcontrol.licensing.web.controllers.*;
import cz.smartcontrol.licensing.business.BusinessException;
// import cz.smartcontrol.licensing.business.facade.BillFacade;
// import cz.smartcontrol.licensing.domain.Bill;
import javax.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 *
 * @author strzinek
 */
@Controller
public class Licence implements PublicSecuredArea {

    @Autowired
    // BillFacade billLogic;
    
    @RequestMapping("/bill.do")
    public String showBill(HttpSession session, @RequestParam(value="id", required=true) String billId,
            Model model) {
        // try {
            PublicUserPrincipal userPrincipal = (PublicUserPrincipal) session.getAttribute(PublicUserPrincipal.SESSION_NAME);

            
            Long billIdNum=null;
            try {
                billIdNum = new Long(Long.parseLong(billId));
            } catch (NumberFormatException e) {}
            
            
            // Bill bill = billLogic.getBillForCustomer(userPrincipal.getCustomer(), billIdNum);
            // model.addAttribute("bill", bill);
            // model.addAttribute("ticketCount", bill.getTickets().size());

            // if (bill == null) {
                return "bills";
            // } else {
                // return "bill";
            // }
        // } catch (BusinessException ex) {
            // return "bills";
       // }
    }
    
}
