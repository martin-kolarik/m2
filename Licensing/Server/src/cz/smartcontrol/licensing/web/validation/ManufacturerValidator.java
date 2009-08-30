package cz.smartcontrol.licensing.web.validation;

import cz.smartcontrol.licensing.web.commands.ManufacturerDetailCommand;
import org.springframework.validation.Errors;

/**
 *
 * @author strzinek
 */
public class ManufacturerValidator {
    
    public void validate(ManufacturerDetailCommand manufacturer, Errors errors)
    {
        if( errors.hasErrors())
        {
            return;
        }
    }
}
