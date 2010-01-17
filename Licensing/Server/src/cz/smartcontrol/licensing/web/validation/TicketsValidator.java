package cz.smartcontrol.licensing.web.validation;

import cz.smartcontrol.licensing.web.commands.LicenceCommand;
import org.springframework.validation.Errors;

/**
 *
 * @author strzinek
 */
public class TicketsValidator {

    public void validate(LicenceCommand reportData, Errors errors) {
        if (errors.hasErrors()) {
            return;
        }
        if( !reportData.validateMonth()) {
            errors.rejectValue( "monthString", "management.ticketreport.badMonthFormat" );
        }
    }
}
