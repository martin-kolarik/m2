/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.web.commands;

import cz.smartcontrol.licensing.dao.filter.ProductVersionFilter;
import cz.smartcontrol.query.Result;
import cz.smartcontrol.licensing.web.tools.ExportTools;
import java.text.ParseException;
import java.util.Calendar;
import org.springframework.context.i18n.LocaleContextHolder;

/**
 *
 * @author Martin
 */
public class ProductsVersionCommand extends AbstractTimeFilterCommand {
    
    public static final String RANGE_FROM_TO = "F";    

    private String dateFrom;

    private String dateTo;

    private ProductVersionFilter filter = new ProductVersionFilter();
    
    // private ControllerExport controller;
    
    private Result result;

    public ProductsVersionCommand() {
        Calendar cal = Calendar.getInstance( LocaleContextHolder.getLocale());
        filter.setDateFrom( cal.getTime());
        cal.add( Calendar.DAY_OF_YEAR, 1 );
        filter.setDateTo( cal.getTime());

        dateFrom = ExportTools.getDateFormatter().format( filter.getDateFrom());
        dateTo = ExportTools.getDateFormatter().format( filter.getDateTo());
    }
    
    public ProductVersionFilter getFilter() {
        return filter;
    }
    
    public String getDateFromString() {
        return this.dateFrom;
    }

    public void setDateFromString( String dateFrom ) {
        this.dateFrom = dateFrom;
    }

    public boolean validateDateFrom() {

        try {
            ExportTools.getDateFormatter().parse( dateFrom );
        } catch( ParseException pe ) {
            return false;
        }
        return true;
    }

    public String getDateToString() {
        return this.dateTo;
    }

    public void setDateToString( String dateTo ) {
        this.dateTo = dateTo;
    }

    public boolean validateDateTo() {

        try {
            ExportTools.getDateFormatter().parse( dateTo );
        } catch( ParseException pe ) {
            return false;
        }
        return true;
    }

    public Result getResult() {
        return result;
    }

    public void setResult( Result result ) {
        this.result = result;
    }

    // public ControllerExport getController() {
    //     return controller;
    // }

    // public void setController( ControllerExport controller ) {
    //     this.controller = controller;
    // }

    public void setupFilter() throws ParseException {

        if( RANGE_FROM_TO.equals( getRange())) {
            filter.setDateFrom( ExportTools.getDateFormatter().parse( dateFrom ));
            filter.setDateTo( ExportTools.getDateFormatter().parse( dateTo ));
        } else {
            super.setupFilter( filter );
        }
    }

    @Override
    public String getCurrentDisplayPeriod() {
        if (RANGE_FROM_TO.equals(getRange())) {
            return dateFrom + " - " + dateTo;
                    
        } else {
            return super.getCurrentDisplayPeriod();
        }
    }
}
