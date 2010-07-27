package cz.smartcontrol.licensing.web.controllers.management;

import cz.smartcontrol.licensing.business.BusinessException;
import cz.smartcontrol.licensing.business.facade.OperatorFacade;
import cz.smartcontrol.licensing.domain.Operator;
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
 * @author phrncarek
 */
@Controller
public class OperatorLogin {
        
    @Autowired
    OperatorFacade operatorLogic;
    
    @RequestMapping(value="/management/login.do", method = RequestMethod.GET)
    public String setupForm(Model model) {
        LoginDataCommand loginData = new LoginDataCommand();
        model.addAttribute("loginData", loginData);
        return "management/login";
    }
    
    @RequestMapping(value="/management/login.do", method = RequestMethod.POST)
    public String processSubmit(HttpSession session, @ModelAttribute("loginData") LoginDataCommand loginData, BindingResult result) {
        new LoginValidator().validate(loginData, result);
        if (result.hasErrors()) {
            return "management/login";
        }

        try {        
            Operator operator = operatorLogic.login(loginData.getUserName(), loginData.getUserPassword());
            
            OperatorUserPrincipal userPrincipal = new OperatorUserPrincipal();
            userPrincipal.login(operator);
            session.setAttribute(OperatorUserPrincipal.SESSION_NAME, userPrincipal);
            return "redirect:timeload.do";
                
        } catch (BusinessException e) {
            result.rejectValue(null, "management.login.error.unauthorized");
        }
        
        return "management/login";
    }
    
    @RequestMapping("/management/logout.do")
    public String processLogout(HttpSession session) {
        
        if (session != null) {
            if (session.getAttribute(OperatorUserPrincipal.SESSION_NAME) != null) {
                ((OperatorUserPrincipal)session.getAttribute(OperatorUserPrincipal.SESSION_NAME)).logout();
            }
            session.invalidate();
        }
        
        return "redirect:login.do";
    }
    
}
