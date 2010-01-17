package cz.smartcontrol.licensing.web.controllers;

import cz.smartcontrol.licensing.business.BusinessException;
import cz.smartcontrol.licensing.business.facade.OperatorFacade;
import cz.smartcontrol.licensing.domain.Customer;
import cz.smartcontrol.licensing.web.commands.LoginDataCommand;
import cz.smartcontrol.licensing.web.validation.LoginValidator;
import javax.servlet.http.HttpSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

/**
 *
 * @author strzinek
 */
@Controller
public class PublicLogin {
    
    private static final String CODE_SENT = "codeSent";
    
    @Autowired
    OperatorFacade operatorLogic;

    @RequestMapping(value="/login.do", method = RequestMethod.GET)
    public String setupForm(Model model) {
        LoginDataCommand loginData = new LoginDataCommand();
        model.addAttribute("loginData", loginData);
        return "login";
    }
    
    // TODO: correct way would be to process submit param according to locale
    @RequestMapping(value="/login.do", method = RequestMethod.POST, params="submit=Přihlásit")
    public String processSubmit(HttpSession session, @ModelAttribute("loginData") LoginDataCommand loginData, BindingResult result) {
        new LoginValidator().validate(loginData, result);
        if( result.hasErrors())
        {
            return "login";
        }
        
        // try {        
            // Customer c = operatorLogic.authenticateCustomer(loginData.getPhoneNumber(), loginData.getHash());
            
            PublicUserPrincipal userPrincipal = new PublicUserPrincipal();
            // userPrincipal.login(c);
            session.setAttribute(PublicUserPrincipal.SESSION_NAME, userPrincipal);
            // session.setAttribute(PublicTickets.NAME_TICKETS_DATA, null);
            // return "redirect:tickets.do";
                
        // } catch (BusinessException e) {
        //    result.rejectValue(null, "public.login.error.unauthorized");
        // }
        return "login";
        
    }
    
    // TODO: correct way would be to process submit param according to locale
    @RequestMapping(value="/login.do", method = RequestMethod.POST, params="submit=Odeslat")
    public String processSendAccessCode(HttpSession session, @ModelAttribute("loginData") LoginDataCommand loginData, BindingResult result) {
        // new LoginValidator().validateSend(loginData, result);
        if (result.hasErrors()) {
            return "login";
        }

        // test if not already sent
        if (session.getAttribute(CODE_SENT)==Boolean.TRUE) {
            // loginData.setCodeSent(Boolean.TRUE);
            result.rejectValue(null, "public.login.error.hashCodeAlreadySent");            
            return "login";
        }
        
        // try {
            // operatorLogic.sendHashCodeBySms(loginData.getPhoneNumber());
        
            // loginData.setCodeSent(Boolean.TRUE);
            session.setAttribute(CODE_SENT, Boolean.TRUE);
            result.rejectValue(null, "public.login.info.hashCodeSent");
            return "login";
            
        // } catch (BusinessException e) {
        //     result.rejectValue("phoneNumber", "public.login.error.invalidPhoneNumber");
        // }
        
        // return "login";

    }
  
    @RequestMapping(value="/logout.do")
    public String processLogout(HttpSession session) {
        if (session != null) {
            if (session.getAttribute(PublicUserPrincipal.SESSION_NAME) != null) {
                ((PublicUserPrincipal)session.getAttribute(PublicUserPrincipal.SESSION_NAME)).logout();
            }
            session.invalidate();
        }
        
        return "redirect:login.do";
    }
    
    
}
