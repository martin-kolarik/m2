package cz.smartcontrol.licensing.web.validation;

import cz.smartcontrol.licensing.web.commands.ProductsVersionCommand;
import org.springframework.validation.Errors;

/**
 *
 * @author strzinek
 */
public class ControllerChecksValidator {
    
    public void validate(ProductsVersionCommand reportData, Errors errors) {
        if (errors.hasErrors()) {
            return;
        }

        if( ProductsVersionCommand.RANGE_DAY.equals( reportData.getRange()) && !reportData.validateDay()) {
            errors.rejectValue( "dayString", "management.controllerchecks.badDayFormat" );
        }
        if( !reportData.validateWeek()) {
            errors.rejectValue( "weekString", "management.controllerchecks.badWeekFormat" );
        }
        if( !reportData.validateMonth()) {
            errors.rejectValue( "monthString", "management.controllerchecks.badMonthFormat" );
        }
        if( ProductsVersionCommand.RANGE_FROM_TO.equals( reportData.getRange())) {
            if( !reportData.validateDateFrom()) {
                errors.rejectValue( "dateFromString", "management.controllerchecks.badDateFromFormat" );
            }
            if( !reportData.validateDateTo()) {
                errors.rejectValue( "dateToString", "management.controllerchecks.badDateToFormat" );
            }
        }
    }
}
