/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.web.tools;

import java.math.BigDecimal;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import org.springframework.context.i18n.LocaleContextHolder;

/**
 *
 * @author Martin
 */
public class ExportTools {
    
//=============================================================================    
// numbers
    
    public static String toString( String prefix, long value ) {
        return "" + prefix + Long.toString( value );
    }
    
//=============================================================================    
// dates
    
    private static final String YEAR_FORMAT_CS = "yyyy";
    private static final String YEAR_FORMAT_EN = "yyyy";
    private static final String MONTH_FORMAT_CS = "MM/yyyy";
    private static final String MONTH_FORMAT_EN = "MM/yyyy";
    private static final String WEEK_FORMAT_CS = "ww/yyyy (dd.MM.)";
    private static final String WEEK_FORMAT_EN = "ww/yyyy (MM-dd)";
    private static final String DATE_FORMAT_CS = "dd.MM.yyyy";
    private static final String DATE_FORMAT_EN = "yyyy-MM-dd";
    private static final String DATE_FULL_FORMAT_CS = "d.M.yyyy '('EEEE')'";
    private static final String DATE_FULL_FORMAT_EN = "yyyy-M-d '('EEEE')'";
    private static final String DATE_TIME_FORMAT_CS = "dd.MM.yyyy HH:mm";
    private static final String DATE_TIME_FORMAT_EN = "yyyy-MM-dd HH:mm";
    private static final String DATE_TIME_FORMAT_SHORT_CS = "dd.MM. HH:mm";
    private static final String DATE_TIME_FORMAT_SHORT_EN = "MM-dd HH:mm";

    private static SimpleDateFormat dateFormatCS;
    private static SimpleDateFormat dateFormatEN;
    private static SimpleDateFormat dateFullFormatCS;
    private static SimpleDateFormat dateFullFormatEN;
    private static SimpleDateFormat dateTimeFormatCS;
    private static SimpleDateFormat dateTimeFormatEN;
    private static SimpleDateFormat dateTimeFormatShortCS;
    private static SimpleDateFormat dateTimeFormatShortEN;
    private static SimpleDateFormat weekFormatCS;
    private static SimpleDateFormat weekFormatEN;
    private static SimpleDateFormat monthFormatCS;
    private static SimpleDateFormat monthFormatEN;
    private static SimpleDateFormat yearFormatCS;
    private static SimpleDateFormat yearFormatEN;

    public static DateFormat getDateFormatter() {

        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( dateFormatCS == null ) {
                dateFormatCS = new SimpleDateFormat( DATE_FORMAT_CS, LocaleContextHolder.getLocale());
            }
            return dateFormatCS;
        
        } else {
            if( dateFormatEN == null ) {
                dateFormatEN = new SimpleDateFormat( DATE_FORMAT_EN, LocaleContextHolder.getLocale());
            }
            return dateFormatEN;

        }
    }
    
    public static DateFormat getFullDateFormatter() {
        
        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( dateFullFormatCS == null ) {
                dateFullFormatCS = new SimpleDateFormat( DATE_FULL_FORMAT_CS, LocaleContextHolder.getLocale());
            }
            return dateFullFormatCS;
        
        } else {
            if( dateFullFormatEN == null ) {
                dateFullFormatEN = new SimpleDateFormat( DATE_FULL_FORMAT_EN, LocaleContextHolder.getLocale());
            }
            return dateFullFormatEN;

        }
    }
    
    public static DateFormat getDateTimeFormatter() {

        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( dateTimeFormatCS == null ) {
                dateTimeFormatCS = new SimpleDateFormat( DATE_TIME_FORMAT_CS, LocaleContextHolder.getLocale());
            }
            return dateTimeFormatCS;
        
        } else {
            if( dateTimeFormatEN == null ) {
                dateTimeFormatEN = new SimpleDateFormat( DATE_TIME_FORMAT_EN, LocaleContextHolder.getLocale());
            }
            return dateTimeFormatEN;

        }
    }
    
    public static DateFormat getDateTimeShortFormatter() {

        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( dateTimeFormatShortCS == null ) {
                dateTimeFormatShortCS = new SimpleDateFormat( DATE_TIME_FORMAT_SHORT_CS, LocaleContextHolder.getLocale());
            }
            return dateTimeFormatShortCS;
        
        } else {
            if( dateTimeFormatShortEN == null ) {
                dateTimeFormatShortEN = new SimpleDateFormat( DATE_TIME_FORMAT_SHORT_EN, LocaleContextHolder.getLocale());
            }
            return dateTimeFormatShortEN;

        }
    }
    
    public static DateFormat getWeekFormatter() {

        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( weekFormatCS == null ) {
                weekFormatCS = new SimpleDateFormat( WEEK_FORMAT_CS, LocaleContextHolder.getLocale());
            }
            return weekFormatCS;

        } else {
            if( weekFormatEN == null ) {
                weekFormatEN = new SimpleDateFormat( WEEK_FORMAT_EN, LocaleContextHolder.getLocale());
            }
            return weekFormatEN;
            
        }
    }
    
    public static DateFormat getMonthFormatter() {
        
        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( monthFormatCS == null ) {
                monthFormatCS = new SimpleDateFormat( MONTH_FORMAT_CS, LocaleContextHolder.getLocale());
            }
            return monthFormatCS;

        } else {
            if( monthFormatEN == null ) {
                monthFormatEN = new SimpleDateFormat( MONTH_FORMAT_EN, LocaleContextHolder.getLocale());
            }
            return monthFormatEN;
            
        }
    }
    
    public static DateFormat getYearFormatter() {
        
        if( LocaleContextHolder.getLocale().getLanguage().equals( "cs" )) { 
            if( yearFormatCS == null ) {
                yearFormatCS = new SimpleDateFormat( YEAR_FORMAT_CS, LocaleContextHolder.getLocale());
            }
            return yearFormatCS;

        } else {
            if( yearFormatEN == null ) {
                yearFormatEN = new SimpleDateFormat( YEAR_FORMAT_EN, LocaleContextHolder.getLocale());
            }
            return yearFormatEN;
            
        }
    }
    
    public static String toDateString( Date value ) {
        return getDateFormatter().format( value );
    }

    public static String toDateTimeString( Date value ) {
        return getDateTimeFormatter().format( value );
    }

    public static String toDateTimeShortString( Date value ) {
        return getDateTimeShortFormatter().format( value );
    }

//=============================================================================    
// prices
    
    public static String toCurrencyString( BigDecimal value ) {
        return value.toPlainString();
    }
    
//=============================================================================    
    
}
