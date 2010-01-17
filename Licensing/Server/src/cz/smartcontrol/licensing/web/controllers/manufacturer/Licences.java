package cz.smartcontrol.licensing.web.controllers.manufacturer;

import cz.smartcontrol.licensing.web.controllers.*;
import cz.smartcontrol.licensing.business.BusinessException;
import cz.smartcontrol.licensing.domain.Customer;
import cz.smartcontrol.licensing.web.commands.LicenceCommand;
import cz.smartcontrol.licensing.web.session.ProductsBacking;
import javax.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;

/**
 *
 * @author strzinek
 */
@Controller
public class Licences implements PublicSecuredArea {
    
    public static final String NAME_CUSTOMERS_DATA = "customersData";
    
    @Autowired
    // CustomerFacade customerLogic;

    @RequestMapping(value = "/customers.do", method = RequestMethod.GET)
    public String showCustomers(
            HttpSession session, Model model,
            @RequestParam( value = "items", required = false ) String pageSizeIncrement,
            @RequestParam( value = "page", required = false ) String page,
            @RequestParam( value = "order", required = false ) String orderBy ) throws Exception {

        // prepare backing
        // LicencesBacking backing = ProductsBacking.getInstance( session );
        
        // apply paging and ordering
        // backing.getPager().updateByWebRequest( pageSizeIncrement, page, orderBy );

        // do action
        // LicenceCommand command = backing.getCustomersCommand();
        // limit tickets to logged customer
        PublicUserPrincipal userPrincipal = (PublicUserPrincipal)session.getAttribute( PublicUserPrincipal.SESSION_NAME );
        // command.getFilter().setParentCustomer( userPrincipal.getCustomer());
        // Result result = customerLogic.getCustomerChildren( command.getFilter(), backing.getPager());
        // command.setResult( result );

        // prepare models
        // backing.bindToModel( model );
        // model.addAttribute( NAME_CUSTOMERS_DATA, command );
        model.addAttribute("customer", userPrincipal.getCustomer());

        return "customers";
    }

    @RequestMapping(value = "/customers.do", method = RequestMethod.POST, params = "do=Přidat tel. číslo")
    public String addCustomer(HttpSession session, 
            @ModelAttribute("customerData") LicenceCommand licenceData,  Model model) {
            
        // try {
            // Customer child = customerLogic.authenticateCustomer(customerData.getPhoneNumber(), customerData.getHashCode());
            Customer parent = ((PublicUserPrincipal) session.getAttribute( PublicUserPrincipal.SESSION_NAME )).getCustomer();
            // customerLogic.setParentCustomer(child, parent);
        
        // } catch (BusinessException e) {
        // }

        return "redirect:customers.do";
    }

}
