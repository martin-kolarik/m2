package cz.smartcontrol.licensing.web.validation;

import cz.smartcontrol.licensing.web.commands.LoginDataCommand;
import org.springframework.util.StringUtils;
import org.springframework.validation.Errors;

/**
 *
 * @author phrncarek
 */
public class LoginValidator {
    
    public void validate(LoginDataCommand loginData, Errors errors) {
        String userName = loginData.getUserName();
        String userPassword = loginData.getUserPassword();
        if (!StringUtils.hasText(userName)) {
            errors.rejectValue("userName", "required", "required");
        }
    }
}
