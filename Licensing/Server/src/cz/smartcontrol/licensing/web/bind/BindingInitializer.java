package cz.smartcontrol.licensing.web.bind;

import cz.smartcontrol.licensing.business.facade.ManufacturerFacade;
import cz.smartcontrol.licensing.domain.Manufacturer;
import java.text.SimpleDateFormat;
import java.util.Date;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.propertyeditors.CustomDateEditor;
import org.springframework.beans.propertyeditors.StringTrimmerEditor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.web.bind.WebDataBinder;
import org.springframework.web.bind.support.WebBindingInitializer;
import org.springframework.web.context.request.WebRequest;

/**
 *
 * @author phrncarek
 * @author strzinek
 */
public class BindingInitializer implements WebBindingInitializer {
    
    public static final String DATE_FORMAT_CS = "dd.MM.yyyy";
    public static final String DATE_FORMAT_EN = "yyyy-MM-dd";
    
    @Autowired
    ManufacturerFacade manufacturerLogic;
    
    public void initBinder(WebDataBinder binder, WebRequest request) {
        SimpleDateFormat formatter;
        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            formatter = new SimpleDateFormat( DATE_FORMAT_CS );
        } else {
            formatter = new SimpleDateFormat( DATE_FORMAT_EN );
        }
        formatter.setLenient(false);
        binder.registerCustomEditor(Date.class, new CustomDateEditor(formatter, true));
        binder.registerCustomEditor(java.sql.Date.class, new SqlDateEditor(formatter, true));
        binder.registerCustomEditor(String.class, new StringTrimmerEditor(false));
        binder.registerCustomEditor(Manufacturer.class, new ManufacturerPropertyEditor( manufacturerLogic ));
    }

}
