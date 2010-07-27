package cz.smartcontrol.licensing.web.controllers;

import javax.servlet.http.HttpSession;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;

/**
 *
 * @author strzinek
 */
@Controller
public class ErrorPage {
    
    @RequestMapping("/errorPage.do")
    public String errorPage(HttpSession session, Model model) {

        return "errorPage";
    }
}