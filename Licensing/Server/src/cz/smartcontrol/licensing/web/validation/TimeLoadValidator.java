package cz.smartcontrol.licensing.web.validation;

import cz.smartcontrol.licensing.web.commands.AbstractTimeFilterCommand;
import cz.smartcontrol.web.validation.ValidationUtils;
import org.springframework.validation.Errors;

/**
 *
 * @author strzinek
 */
public class TimeLoadValidator {
    
    public void validate(AbstractTimeFilterCommand timeLoadData, Errors errors) {
        if (errors.hasErrors()) {
            return;
        }

        ValidationUtils.rejectIfEmptyOrWhitespace(errors, "range", "required" );

        if( AbstractTimeFilterCommand.RANGE_DAY.equals( timeLoadData.getRange()) && !timeLoadData.validateDay()) {
            errors.rejectValue( "dayString", "management.timeload.badDayFormat" );
        }
        if( !timeLoadData.validateWeek()) {
            errors.rejectValue( "weekString", "management.timeload.badWeekFormat" );
        }
        if( !timeLoadData.validateMonth()) {
            errors.rejectValue( "monthString", "management.timeload.badMonthFormat" );
        }
    }
}
